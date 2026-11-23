#!/usr/bin/env python3
"""Evaluate Vika exercise session logs against video-based coach labels.

Standard-library-only CLI entry point:
    python tools/eval/evaluate.py --logs <dir> --labels <csv> --out <dir> [--cue-map <csv>]

Reads app JSON logs (schema 1, docs/reference/session-log-schema.md) and coach
CSV labels, validates inputs with file-and-line diagnostics, computes rep
matching, counting accuracy, per-fault precision/recall with 95% Wilson CIs,
per-exercise confusion matrices, wrong-detection clip index, inter-coach
agreement (Cohen's kappa), unseen-time breakdown, cue-correction rates,
paired AI-vs-control comparisons, candidate success/failure sets, session
satisfaction, and frame-rate summaries.
"""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import csv
from dataclasses import dataclass, field
import json
import math
from pathlib import Path
import random
import re
import statistics
import sys
from typing import Any, Iterable, Optional, Sequence

# ---------------------------------------------------------------------------
# Domain constants (grounded in docs/reference/session-log-schema.md & Vika exercises)
# ---------------------------------------------------------------------------

KNOWN_CONDITIONS: tuple[str, ...] = ("ai", "control")

# Canonical fault IDs per exercise, preserving the exact FaultRecord.type casing
# emitted by the four measured exercises in Vika.
KNOWN_EXERCISES: dict[str, tuple[str, ...]] = {
    "squat": ("depth", "trunk", "heel", "tempo", "sync"),
    "push_up": ("sag", "depth", "tempo"),
    "glute_bridge": (
        "hip_extension",
        "hyperextension",
        "knee_angle",
        "speed_control",
        "neck_head",
    ),
    "plank": ("Back", "Neck", "Knees"),
}

EXERCISE_NAMES_VI: dict[str, str] = {
    "squat": "Squat",
    "push_up": "Chống đẩy (Push-Up)",
    "glute_bridge": "Cầu mông (Glute Bridge)",
    "plank": "Plank (giữ 15 giây)",
}

STATUS_FAULTS: dict[str, frozenset[str]] = {}

DEFAULT_CATALOG_PATH: Path = Path(__file__).resolve().parent / "fault_catalog.csv"
BOOTSTRAP_RESAMPLES: int = 2000
BOOTSTRAP_SEED: int = 20261124
CONDITION_KEY_COLUMNS: tuple[str, ...] = (
    "participant_id",
    "condition",
    "exercise_id",
    "set_index",
)

REQUIRED_LABEL_COLUMNS: tuple[str, ...] = (
    "coach_id",
    "participant_id",
    "condition",
    "exercise_id",
    "set_index",
    "rep_n",
    "video_t_s",
    "counted",
    "faults",
    "note",
)

DEFAULT_TIME_TOLERANCE_S: float = 2.5
WILSON_Z_95: float = 1.959963984540054
FLOAT_TIE_EPS: float = 1e-9

IGNORED_DIRECTORY_CSV_NAMES: frozenset[str] = frozenset(
    {
        "coach_labels_template.csv",
        "cue_fault_map.csv",
        "validation_issues.csv",
        "rep_matching.csv",
        "counting_accuracy.csv",
        "fault_detection.csv",
        "confusion_matrices.csv",
        "wrong_detections.csv",
        "coach_agreement.csv",
        "unseen_time.csv",
        "unseen_reasons.csv",
        "cue_mapping_summary.csv",
        "cue_correction.csv",
        "ai_vs_control_participants.csv",
        "ai_vs_control_summary.csv",
        "cue_candidates.csv",
        "satisfaction.csv",
        "frame_rate.csv",
        "fault_reports.csv",
        "fault_catalog.csv",
        "session_conditions.csv",
        "beep_times.csv",
        "clip_key.csv",
        "fault_detection_by_condition.csv",
    }
)


# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------


@dataclass
class ValidationIssue:
    severity: str  # "warning" or "error"
    code: str
    file: str
    line: int
    message_en: str
    message_vi: str


@dataclass
class AppRep:
    event_index: int
    n: int
    t_ms: int
    rel_t_s: Optional[float]
    correct: bool
    faults: tuple[str, ...]
    data: dict[str, Any]
    form_judged: bool = True


@dataclass
class AppCue:
    event_index: int
    t_ms: int
    rel_t_s: Optional[float]
    key: str
    played: bool
    raw_fault: Optional[str]
    resolved_fault: Optional[str] = None
    mapping_source: str = "unmapped"  # "log", "cue_map", "explicit_non_fault", "unmapped"


@dataclass
class LiveFaultSpan:
    fault_id: str
    start_ms: int
    end_ms: int
    start_event_index: int


@dataclass
class UnseenInterval:
    phase: str  # "setup" or "active"
    reason: str
    start_ms: int
    end_ms: int
    effective_ms: int


@dataclass
class SetLog:
    file_path: str
    file_name: str
    session_id: str
    participant_id: str
    condition: str
    exercise_id: str
    set_index: int
    started_at_utc: str
    sync_beep_t_ms: Optional[int]
    mean_fps: Optional[float]
    min_fps_1s: Optional[float]
    max_gap_ms: Optional[float]
    frames_total: Optional[int]
    frames_duration_ms: Optional[int]
    max_non_paused_window_ms: Optional[int]
    active_ms: int
    unseen_ms: int
    paused_ms: int
    summary_reps: Optional[int]
    summary_good_reps: Optional[int]
    has_set_complete: bool
    reps: list[AppRep] = field(default_factory=list)
    cues: list[AppCue] = field(default_factory=list)
    live_fault_spans: list[LiveFaultSpan] = field(default_factory=list)
    unseen_intervals: list[UnseenInterval] = field(default_factory=list)

    @property
    def set_key(self) -> tuple[str, str, str, int]:
        return (self.participant_id, self.condition, self.exercise_id, self.set_index)


@dataclass
class SessionLog:
    file_path: str
    file_name: str
    session_id: str
    participant_id: str
    condition: str
    satisfaction: Optional[int]
    files: list[str] = field(default_factory=list)
    fault_reports: list[tuple[str, int, str, str]] = field(default_factory=list)


@dataclass
class CoachRow:
    file_path: str
    file_name: str
    line: int
    coach_id: str
    participant_id: str
    condition: str
    exercise_id: str
    set_index: int
    rep_n: int
    video_t_s: Optional[float]
    counted: int
    faults: tuple[str, ...]
    note: str

    @property
    def set_key(self) -> tuple[str, str, str, int]:
        return (self.participant_id, self.condition, self.exercise_id, self.set_index)


@dataclass
class MatchedRepPair:
    set_key: tuple[str, str, str, int]
    session_id: str
    log_file: str
    coach_id: str
    status: str  # "matched", "missed", "phantom"
    coach_rep: Optional[CoachRow]
    app_rep: Optional[AppRep]
    match_method: str  # "time", "order", "unmatched"
    time_diff_s: Optional[float]


# ---------------------------------------------------------------------------
# Statistical & formatting helpers
# ---------------------------------------------------------------------------


def wilson_ci(k: int, n: int, z: float = WILSON_Z_95) -> tuple[Optional[float], Optional[float]]:
    """Compute two-sided Wilson score interval for k successes in n trials."""
    if n <= 0:
        return (None, None)
    k = max(0, min(k, n))
    p = k / n
    z2 = z * z
    denom = 1.0 + z2 / n
    center = (p + z2 / (2.0 * n)) / denom
    radicand = max(0.0, (p * (1.0 - p)) / n + (z2 / (4.0 * n * n)))
    half = (z * math.sqrt(radicand)) / denom
    return (max(0.0, center - half), min(1.0, center + half))


def cohen_kappa_binary(
    both_pos: int, a_only: int, b_only: int, both_neg: int
) -> tuple[Optional[float], Optional[float], str]:
    """Return (observed_agreement, kappa, note) for binary ratings over N items."""
    n = both_pos + a_only + b_only + both_neg
    if n <= 0:
        return (None, None, "no_shared_reps")
    p_o = (both_pos + both_neg) / n
    # Exact integer numerator/denominator avoids floating-point -0.000 cancellation
    a_pos = both_pos + a_only
    b_pos = both_pos + b_only
    a_neg = b_only + both_neg
    b_neg = a_only + both_neg
    expected_num = a_pos * b_pos + a_neg * b_neg
    denom = n * n - expected_num
    if denom == 0:
        return (p_o, None, "undefined_degenerate_marginals")
    numer = n * (both_pos + both_neg) - expected_num
    kappa = numer / denom
    if abs(kappa) < 1e-12:
        kappa = 0.0
    return (p_o, kappa, "")


def exact_sign_test_two_sided(n_pos: int, n_neg: int) -> Optional[float]:
    """Exact two-sided binomial sign test p-value for paired directional counts."""
    m = n_pos + n_neg
    if m <= 0:
        return None
    k = min(n_pos, n_neg)
    tail = sum(math.comb(m, i) for i in range(k + 1)) / (2**m)
    return min(1.0, 2.0 * tail)


def fmt_float(val: Optional[float], digits: int = 4) -> str:
    if val is None or (isinstance(val, float) and (math.isnan(val) or math.isinf(val))):
        return ""
    clean_val = 0.0 if abs(val) < 1e-12 else val
    return f"{clean_val:.{digits}f}"


def fmt_pct_vi(val: Optional[float], digits: int = 1) -> str:
    if val is None:
        return "—"
    clean_val = 0.0 if abs(val) < 1e-12 else val
    return f"{clean_val * 100:.{digits}f}%"


def fmt_num_vi(val: Optional[float], digits: int = 2) -> str:
    if val is None:
        return "—"
    clean_val = 0.0 if abs(val) < 1e-12 else val
    return f"{clean_val:.{digits}f}"


def _md_cell(val: Any) -> str:
    return str(val).replace("\r", " ").replace("\n", " ").replace("|", "\\|")


def format_fault_set(faults: Iterable[str]) -> str:
    cleaned = sorted(set(faults))
    return ";".join(cleaned)


def format_fault_label_display(faults: Iterable[str]) -> str:
    s = format_fault_set(faults)
    return s if s else "clean"


# ---------------------------------------------------------------------------
# JSON line-locator & ID canonicalization helpers
# ---------------------------------------------------------------------------


def find_json_line(
    raw_text: str,
    key: str,
    value: Any = None,
    start_line: int = 1,
    end_line: Optional[int] = None,
) -> int:
    """Best-effort 1-based line lookup for a JSON key/value pair within [start_line, end_line]."""
    lines = raw_text.splitlines()
    if not lines:
        return 1
    lo = max(1, min(start_line, len(lines)))
    hi = len(lines) if end_line is None else max(lo, min(end_line, len(lines)))

    if value is not None:
        candidates: list[str] = []
        try:
            candidates.append(json.dumps(value, ensure_ascii=False))
            candidates.append(json.dumps(value, ensure_ascii=False, separators=(",", ":")))
        except TypeError:
            pass
        for encoded_val in candidates:
            pattern = re.compile(rf'"{re.escape(key)}"\s*:\s*{re.escape(encoded_val)}')
            for idx in range(lo, hi + 1):
                if pattern.search(lines[idx - 1]):
                    return idx
        # Multi-line array/scalar fallback: locate key line, then value token inside the slice
        if isinstance(value, str):
            tok_pat = re.compile(re.escape(json.dumps(value, ensure_ascii=False)))
            key_pat = re.compile(rf'"{re.escape(key)}"\s*:')
            for idx in range(lo, hi + 1):
                if key_pat.search(lines[idx - 1]):
                    for sub_idx in range(idx, hi + 1):
                        if tok_pat.search(lines[sub_idx - 1]):
                            return sub_idx
                    return idx

    key_pattern = re.compile(rf'"{re.escape(key)}"\s*:')
    for idx in range(lo, hi + 1):
        if key_pattern.search(lines[idx - 1]):
            return idx
    return lo


def _locate_event_line_spans(raw_text: str) -> list[tuple[int, int]]:
    """Locate 1-based (start_line, end_line) for each top-level element of the 'events' array."""
    m = re.search(r'"events"\s*:\s*\[', raw_text)
    if not m:
        return []
    pos = m.end() - 1  # points to '['
    n = len(raw_text)

    # Precompute newline offsets for fast char-offset -> 1-based line conversion
    nl_offsets: list[int] = [i for i, ch in enumerate(raw_text) if ch == "\n"]

    def _line_at(offset: int) -> int:
        # binary search count of '\n' strictly before offset
        lo_i, hi_i = 0, len(nl_offsets)
        while lo_i < hi_i:
            mid = (lo_i + hi_i) // 2
            if nl_offsets[mid] < offset:
                lo_i = mid + 1
            else:
                hi_i = mid
        return lo_i + 1

    spans: list[tuple[int, int]] = []
    in_str = False
    esc = False
    array_depth = 0
    elem_start: Optional[int] = None
    brace_depth = 0

    for i in range(pos, n):
        ch = raw_text[i]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
            continue

        if ch == '"':
            in_str = True
            if array_depth == 1 and brace_depth == 0 and elem_start is None:
                elem_start = i
        elif ch == "[":
            if array_depth == 1 and brace_depth == 0 and elem_start is None:
                elem_start = i
            array_depth += 1
        elif ch == "]":
            if array_depth == 1:
                if elem_start is not None:
                    spans.append((_line_at(elem_start), _line_at(i)))
                    elem_start = None
                break
            array_depth -= 1
        elif ch == "{":
            if array_depth == 1 and brace_depth == 0 and elem_start is None:
                elem_start = i
            brace_depth += 1
        elif ch == "}":
            brace_depth = max(0, brace_depth - 1)
            if array_depth == 1 and brace_depth == 0 and elem_start is not None:
                spans.append((_line_at(elem_start), _line_at(i)))
                elem_start = None
        elif ch == "," and array_depth == 1 and brace_depth == 0:
            if elem_start is not None:
                spans.append((_line_at(elem_start), _line_at(i)))
                elem_start = None
        elif not ch.isspace() and array_depth == 1 and brace_depth == 0 and elem_start is None:
            elem_start = i

    return spans


class IdCanonicalizer:
    """Detects IDs differing only by case, spaces, or separators and maps them to one canonical ID."""

    def __init__(self, kind_en: str, kind_vi: str) -> None:
        self.kind_en = kind_en
        self.kind_vi = kind_vi
        # norm_key -> (canonical_str, first_file, first_line)
        self._seen: dict[str, tuple[str, str, int]] = {}
        self._warned_pairs: set[tuple[str, str, str, int]] = set()

    @staticmethod
    def _norm(raw: str) -> str:
        return re.sub(r"[\s_-]+", "", raw).casefold()

    def register_preferred(self, raw: str, file_name: str, line: int) -> None:
        """Seed canonical spelling (e.g. clean trimmed uppercase from logs) if unseen."""
        stripped = raw.strip()
        if not stripped or stripped != raw or any(ch.isspace() for ch in stripped):
            return
        key = self._norm(stripped)
        if key not in self._seen:
            self._seen[key] = (stripped, file_name, line)

    def resolve(
        self,
        raw: str,
        file_name: str,
        line: int,
        issues: list[ValidationIssue],
        issue_code: str,
    ) -> str:
        norm_key = self._norm(raw)
        clean_candidate = re.sub(r"\s+", "", raw.strip())
        if norm_key not in self._seen:
            canonical = clean_candidate
            self._seen[norm_key] = (canonical, file_name, line)
            if raw != canonical:
                issues.append(
                    ValidationIssue(
                        severity="warning",
                        code=issue_code,
                        file=file_name,
                        line=line,
                        message_en=(
                            f"{self.kind_en} {raw!r} contains extra spaces; "
                            f"normalized to {canonical!r}."
                        ),
                        message_vi=(
                            f"{self.kind_vi} {raw!r} có khoảng trắng thừa; "
                            f"đã chuẩn hóa thành {canonical!r}."
                        ),
                    )
                )
            return canonical

        canonical, first_file, first_line = self._seen[norm_key]
        if raw != canonical:
            sig = (raw, canonical, file_name, line)
            if sig not in self._warned_pairs:
                self._warned_pairs.add(sig)
                issues.append(
                    ValidationIssue(
                        severity="warning",
                        code=issue_code,
                        file=file_name,
                        line=line,
                        message_en=(
                            f"{self.kind_en} {raw!r} differs only by case, spaces, or separators from "
                            f"{canonical!r} (first seen at {first_file}:{first_line}); "
                            f"normalized to {canonical!r}."
                        ),
                        message_vi=(
                            f"{self.kind_vi} {raw!r} chỉ khác chữ hoa/thường, khoảng trắng hoặc dấu gạch "
                            f"so với {canonical!r} (gặp lần đầu tại {first_file}:{first_line}); "
                            f"đã gộp về {canonical!r}."
                        ),
                    )
                )
        return canonical


def resolve_known_token(
    raw: str,
    valid_tokens: Sequence[str],
    kind_en: str,
    kind_vi: str,
    file_name: str,
    line: int,
    issues: list[ValidationIssue],
    unknown_code: str,
    case_code: str,
    extra_hint_en: str = "",
    extra_hint_vi: str = "",
) -> Optional[str]:
    """Validate an exercise_id, condition, or fault_id with case/space/separator recovery."""
    exact_set = set(valid_tokens)
    if raw in exact_set:
        return raw

    norm_map = {re.sub(r"[\s_-]+", "", tok).casefold(): tok for tok in valid_tokens}
    norm_raw = re.sub(r"[\s_-]+", "", raw).casefold()
    if norm_raw in norm_map:
        canonical = norm_map[norm_raw]
        issues.append(
            ValidationIssue(
                severity="warning",
                code=case_code,
                file=file_name,
                line=line,
                message_en=(
                    f"{kind_en} {raw!r} differs by case, spaces, or separators from canonical "
                    f"{canonical!r}; normalized to {canonical!r}."
                ),
                message_vi=(
                    f"{kind_vi} {raw!r} khác chữ hoa/thường, khoảng trắng hoặc dấu gạch so với "
                    f"mã chuẩn {canonical!r}; đã chuẩn hóa thành {canonical!r}."
                ),
            )
        )
        return canonical

    valid_list = ", ".join(valid_tokens)
    issues.append(
        ValidationIssue(
            severity="warning",
            code=unknown_code,
            file=file_name,
            line=line,
            message_en=(
                f"Unknown {kind_en.lower()} {raw!r} (expected one of: {valid_list})."
                + (f" {extra_hint_en}" if extra_hint_en else "")
            ),
            message_vi=(
                f"{kind_vi} không hợp lệ {raw!r} (chỉ chấp nhận: {valid_list})."
                + (f" {extra_hint_vi}" if extra_hint_vi else "")
            ),
        )
    )
    return None


def parse_video_time_seconds(
    raw: str, file_name: str, line: int, issues: list[ValidationIssue]
) -> Optional[float]:
    """Parse video_t_s supporting plain seconds ('12.4', '12,4') and 'mm:ss(.d)'."""
    s = raw.strip()
    if not s:
        return None
    normalized = s.replace(",", ".")
    val: Optional[float] = None
    if ":" in normalized:
        parts = normalized.split(":")
        try:
            if len(parts) == 2:
                minutes = int(parts[0])
                seconds = float(parts[1])
                if minutes >= 0 and 0.0 <= seconds < 60.0:
                    val = minutes * 60.0 + seconds
            elif len(parts) == 3:
                hours = int(parts[0])
                minutes = int(parts[1])
                seconds = float(parts[2])
                if hours >= 0 and 0 <= minutes < 60 and 0.0 <= seconds < 60.0:
                    val = hours * 3600.0 + minutes * 60.0 + seconds
        except ValueError:
            val = None
    else:
        try:
            val = float(normalized)
        except ValueError:
            val = None

    if val is None or math.isnan(val) or math.isinf(val):
        issues.append(
            ValidationIssue(
                severity="warning",
                code="invalid_video_t_s",
                file=file_name,
                line=line,
                message_en=(
                    f"Invalid video_t_s value {raw!r}; treated as empty and falling back "
                    f"to order matching if needed."
                ),
                message_vi=(
                    f"Giá trị video_t_s {raw!r} không đọc được thành số giây; "
                    f"đã coi như để trống."
                ),
            )
        )
        return None
    if "," in s:
        issues.append(
            ValidationIssue(
                severity="warning",
                code="decimal_comma_video_t_s",
                file=file_name,
                line=line,
                message_en=f"video_t_s {raw!r} used a comma decimal separator; parsed as {val:.3f}s.",
                message_vi=f"video_t_s {raw!r} dùng dấu phẩy thập phân; đã đọc thành {val:.3f} giây.",
            )
        )
    return val


# ---------------------------------------------------------------------------
# Cue-to-fault mapping loader
# ---------------------------------------------------------------------------


class CueFaultMapper:
    """Optional mapping from (exercise_id, cue_key) or cue_key -> canonical fault_id."""

    def __init__(self) -> None:
        self.by_exercise_key: dict[tuple[str, str], Optional[str]] = {}
        self.by_key: dict[str, Optional[str]] = {}
        self.loaded: bool = False

    def lookup(self, exercise_id: str, key: str) -> tuple[bool, Optional[str]]:
        """Return (found, fault_id_or_none_for_explicit_non_fault)."""
        if not self.loaded:
            return (False, None)
        if (exercise_id, key) in self.by_exercise_key:
            return (True, self.by_exercise_key[(exercise_id, key)])
        if key in self.by_key:
            return (True, self.by_key[key])
        if key.strip().isdigit():
            return (True, None)
        return (False, None)


def _read_text_forgiving(path: Path, issues: list[ValidationIssue]) -> str:
    raw_bytes = path.read_bytes()
    try:
        return raw_bytes.decode("utf-8-sig")
    except UnicodeDecodeError:
        issues.append(
            ValidationIssue(
                severity="warning",
                code="non_utf8_encoding",
                file=path.name,
                line=1,
                message_en=(
                    f"File {path.name!r} is not valid UTF-8; decoded with cp1252 fallback. "
                    f"Save CSV as 'CSV UTF-8' in Excel to preserve Vietnamese accents."
                ),
                message_vi=(
                    f"Tệp {path.name!r} không phải mã hóa UTF-8 chuẩn; đã đọc tạm bằng bảng mã dự phòng. "
                    f"Nên lưu tệp dưới dạng 'CSV UTF-8' trong Excel."
                ),
            )
        )
        return raw_bytes.decode("cp1252", errors="replace")


def load_cue_map(path: Path, issues: list[ValidationIssue]) -> CueFaultMapper:
    mapper = CueFaultMapper()
    text = _read_text_forgiving(path, issues)
    lines = text.splitlines()
    if not lines:
        issues.append(
            ValidationIssue(
                severity="warning",
                code="empty_cue_map",
                file=path.name,
                line=1,
                message_en=f"Cue mapping file {path.name!r} is empty.",
                message_vi=f"Tệp ánh xạ lời nhắc {path.name!r} đang trống.",
            )
        )
        return mapper

    delimiter = ","
    for cand in (",", "\t", ";"):
        cols = [c.strip().lower() for c in lines[0].split(cand)]
        if ("key" in cols or "cue_key" in cols) and ("fault" in cols or "fault_id" in cols):
            delimiter = cand
            break

    reader = csv.reader(lines, delimiter=delimiter)
    try:
        header = next(reader)
    except StopIteration:
        return mapper
    norm_header = [c.strip().lower() for c in header]
    key_col = (
        norm_header.index("key")
        if "key" in norm_header
        else (norm_header.index("cue_key") if "cue_key" in norm_header else -1)
    )
    fault_col = (
        norm_header.index("fault")
        if "fault" in norm_header
        else (norm_header.index("fault_id") if "fault_id" in norm_header else -1)
    )
    ex_col = norm_header.index("exercise_id") if "exercise_id" in norm_header else -1
    if key_col < 0 or fault_col < 0:
        issues.append(
            ValidationIssue(
                severity="error",
                code="invalid_cue_map_header",
                file=path.name,
                line=1,
                message_en=(
                    f"Cue mapping file {path.name!r} must have 'key' and 'fault' columns "
                    f"(found: {header})."
                ),
                message_vi=(
                    f"Tệp ánh xạ lời nhắc {path.name!r} phải có cột 'key' và 'fault' "
                    f"(hiện có: {header})."
                ),
            )
        )
        return mapper

    mapper.loaded = True
    all_faults: list[str] = []
    for faults in KNOWN_EXERCISES.values():
        for f in faults:
            if f not in all_faults:
                all_faults.append(f)

    for row in reader:
        line_no = reader.line_num
        if not row or all(not c.strip() for c in row):
            continue
        max_needed = max(key_col, fault_col, ex_col)
        if len(row) <= max_needed:
            row = list(row) + [""] * (max_needed + 1 - len(row))
        cue_key = row[key_col].strip()
        if not cue_key or cue_key.startswith("#"):
            continue
        raw_fault = row[fault_col].strip()
        raw_ex = row[ex_col].strip() if ex_col >= 0 else ""

        ex_id: Optional[str] = None
        if raw_ex:
            ex_id = resolve_known_token(
                raw_ex,
                tuple(KNOWN_EXERCISES.keys()),
                "Exercise ID",
                "Mã bài tập",
                path.name,
                line_no,
                issues,
                "unknown_exercise_id",
                "case_space_exercise_id",
            )
            if ex_id is None:
                continue

        if raw_fault == "" or raw_fault.lower() in {"none", "non_fault", "-"}:
            resolved_fault = None
        else:
            valid_pool = KNOWN_EXERCISES[ex_id] if ex_id else tuple(all_faults)
            resolved_fault = resolve_known_token(
                raw_fault,
                valid_pool,
                "Fault ID",
                "Mã lỗi",
                path.name,
                line_no,
                issues,
                "unknown_fault_id",
                "case_space_fault_id",
            )
            if resolved_fault is None:
                continue

        if ex_id:
            mapper.by_exercise_key[(ex_id, cue_key)] = resolved_fault
        else:
            mapper.by_key[cue_key] = resolved_fault

    return mapper


def read_fault_catalog(path: Path) -> tuple[
    dict[str, tuple[str, ...]], dict[str, frozenset[str]], dict[str, str]
]:
    form: dict[str, list[str]] = {}
    status: dict[str, set[str]] = defaultdict(set)
    names: dict[str, str] = {}
    with path.open("r", encoding="utf-8-sig", newline="") as fh:
        for row in csv.DictReader(fh):
            ex_id = (row.get("exercise_id") or "").strip()
            fault = (row.get("fault") or "").strip()
            if not ex_id or not fault:
                continue
            name_vi = (row.get("exercise_vi") or "").strip()
            if name_vi:
                names.setdefault(ex_id, name_vi)
            if (row.get("kind") or "form").strip().lower() == "status":
                status[ex_id].add(fault)
            else:
                form.setdefault(ex_id, [])
                if fault not in form[ex_id]:
                    form[ex_id].append(fault)
    return (
        {ex: tuple(fs) for ex, fs in form.items()},
        {ex: frozenset(fs) for ex, fs in status.items()},
        names,
    )


def apply_fault_catalog(path: Path) -> None:
    form, status, names = read_fault_catalog(path)
    KNOWN_EXERCISES.clear()
    KNOWN_EXERCISES.update(form)
    STATUS_FAULTS.clear()
    STATUS_FAULTS.update(status)
    for ex_id, name_vi in names.items():
        EXERCISE_NAMES_VI.setdefault(ex_id, name_vi)


def load_session_conditions(
    path: Path,
    participant_canon: "IdCanonicalizer",
    issues: list[ValidationIssue],
) -> tuple[dict[tuple[str, str, str, int], dict[str, str]], list[str]]:
    by_set: dict[tuple[str, str, str, int], dict[str, str]] = {}
    with path.open("r", encoding="utf-8-sig", newline="") as fh:
        reader = csv.DictReader(fh)
        header = [h.strip() for h in (reader.fieldnames or [])]
        missing = [c for c in CONDITION_KEY_COLUMNS if c not in header]
        if missing:
            issues.append(
                ValidationIssue(
                    severity="error",
                    code="invalid_conditions_header",
                    file=path.name,
                    line=1,
                    message_en=f"session_conditions.csv is missing columns {missing}; ignored.",
                    message_vi=f"session_conditions.csv thiếu cột {missing}; đã bỏ qua tệp.",
                )
            )
            return {}, []
        factors = [h for h in header if h not in CONDITION_KEY_COLUMNS and h != "note"]
        for row in reader:
            line_no = reader.line_num
            row = {(k or "").strip(): (v or "").strip() for k, v in row.items()}
            raw_pid = row.get("participant_id", "")
            try:
                s_idx = int(float(row.get("set_index", "")))
            except ValueError:
                issues.append(
                    ValidationIssue(
                        severity="warning",
                        code="invalid_conditions_row",
                        file=path.name,
                        line=line_no,
                        message_en="Row has no valid set_index; skipped.",
                        message_vi="Dòng không có set_index hợp lệ; đã bỏ qua.",
                    )
                )
                continue
            if not raw_pid:
                continue
            pid = participant_canon.resolve(
                raw_pid, path.name, line_no, issues, "case_space_participant_id"
            )
            key = (
                pid,
                row.get("condition", "").lower(),
                row.get("exercise_id", "").lower(),
                s_idx,
            )
            by_set[key] = {f: row.get(f, "") for f in factors if row.get(f, "")}
    return by_set, factors


# ---------------------------------------------------------------------------
# Log directory loader
# ---------------------------------------------------------------------------


def _compute_overlap_ms(start_ms: int, end_ms: int, intervals: Sequence[tuple[int, int]]) -> int:
    if end_ms <= start_ms:
        return 0
    total = 0
    for s, e in intervals:
        lo = max(start_ms, s)
        hi = min(end_ms, e)
        if hi > lo:
            total += hi - lo
    return total


def _merge_intervals(intervals: Sequence[tuple[int, int]]) -> list[tuple[int, int]]:
    valid = sorted((s, e) for s, e in intervals if e > s)
    if not valid:
        return []
    merged = [valid[0]]
    for s, e in valid[1:]:
        prev_s, prev_e = merged[-1]
        if s <= prev_e:
            merged[-1] = (prev_s, max(prev_e, e))
        else:
            merged.append((s, e))
    return merged


def load_logs_directory(
    logs_dir: Path,
    participant_canon: IdCanonicalizer,
    cue_mapper: CueFaultMapper,
    issues: list[ValidationIssue],
    form_faults_only: bool = False,
    out_dir: Optional[Path] = None,
) -> tuple[dict[tuple[str, str, str, int], SetLog], list[SessionLog]]:
    """Load and validate all JSON set and session logs in logs_dir."""
    raw_set_logs: list[SetLog] = []
    raw_session_logs: list[SessionLog] = []

    resolved_logs = logs_dir.resolve()
    resolved_out = out_dir.resolve() if out_dir is not None else None
    exclude_out_subtree = (
        resolved_out is not None and resolved_logs in resolved_out.parents
    )
    json_paths: list[Path] = []
    for p in sorted(logs_dir.rglob("*")):
        if not p.is_file() or p.suffix.lower() != ".json":
            continue
        if exclude_out_subtree:
            rp = p.resolve()
            if rp == resolved_out or resolved_out in rp.parents:
                continue
        json_paths.append(p)

    # Pass 1: parse JSON objects and seed clean participant IDs from logs first
    parsed_files: list[tuple[Path, str, dict[str, Any]]] = []
    for path in json_paths:
        rel_name = str(path.relative_to(logs_dir)).replace("\\", "/")
        raw_text = _read_text_forgiving(path, issues)
        try:
            obj = json.loads(raw_text)
        except json.JSONDecodeError as exc:
            issues.append(
                ValidationIssue(
                    severity="error",
                    code="invalid_json",
                    file=rel_name,
                    line=exc.lineno,
                    message_en=f"Malformed JSON file ({exc.msg}); skipped this file.",
                    message_vi=f"Tệp JSON bị lỗi cú pháp ({exc.msg}); đã bỏ qua tệp này.",
                )
            )
            continue

        if not isinstance(obj, dict):
            issues.append(
                ValidationIssue(
                    severity="error",
                    code="invalid_json_root",
                    file=rel_name,
                    line=1,
                    message_en="JSON root must be an object; skipped this file.",
                    message_vi="Nội dung gốc của tệp JSON phải là một đối tượng (object); đã bỏ qua tệp này.",
                )
            )
            continue

        raw_pid = obj.get("participant_id")
        if isinstance(raw_pid, str) and raw_pid.strip():
            participant_canon.register_preferred(
                raw_pid, rel_name, find_json_line(raw_text, "participant_id", raw_pid)
            )
        parsed_files.append((path, raw_text, obj))

    # Pass 2: validate and convert each parsed JSON object
    for path, raw_text, obj in parsed_files:
        rel_name = str(path.relative_to(logs_dir)).replace("\\", "/")
        schema_ver = obj.get("schema")
        if schema_ver != 1:
            issues.append(
                ValidationIssue(
                    severity="warning",
                    code="unexpected_schema",
                    file=rel_name,
                    line=find_json_line(raw_text, "schema", schema_ver),
                    message_en=f"Expected schema=1, found {schema_ver!r}; reading conservatively.",
                    message_vi=f"Kỳ vọng schema=1 nhưng gặp {schema_ver!r}; vẫn đọc theo cấu trúc schema 1.",
                )
            )

        kind = obj.get("kind")
        if kind == "session":
            sess = _parse_session_log(path, rel_name, raw_text, obj, participant_canon, issues)
            if sess is not None:
                raw_session_logs.append(sess)
        elif kind == "exercise_set":
            set_log = _parse_set_log(
                path,
                rel_name,
                raw_text,
                obj,
                participant_canon,
                cue_mapper,
                issues,
                form_faults_only=form_faults_only,
            )
            if set_log is not None:
                raw_set_logs.append(set_log)
        else:
            issues.append(
                ValidationIssue(
                    severity="warning",
                    code="unknown_log_kind",
                    file=rel_name,
                    line=find_json_line(raw_text, "kind", kind),
                    message_en=f"Unknown log kind {kind!r} (expected 'exercise_set' or 'session'); skipped.",
                    message_vi=f"Loại tệp log {kind!r} không xác định (chỉ nhận 'exercise_set' hoặc 'session'); đã bỏ qua.",
                )
            )

    # Deduplicate any repeated session logs by (participant_id, condition, session_id)
    grouped_sessions: dict[tuple[str, str, str], list[SessionLog]] = defaultdict(list)
    for s in raw_session_logs:
        grouped_sessions[(s.participant_id, s.condition, s.session_id)].append(s)

    session_logs: list[SessionLog] = []
    for (pid, cond, sid), s_cands in grouped_sessions.items():
        if len(s_cands) == 1:
            session_logs.append(s_cands[0])
            continue
        s_sorted = sorted(
            s_cands,
            key=lambda s: (s.satisfaction is not None, len(s.files), s.file_name),
            reverse=True,
        )
        chosen_s = s_sorted[0]
        others_s = ", ".join(c.file_name for c in s_sorted[1:])
        issues.append(
            ValidationIssue(
                severity="warning",
                code="duplicate_session_log",
                file=chosen_s.file_name,
                line=1,
                message_en=(
                    f"Multiple session logs found for ({pid}, {cond}, session {sid!r}): "
                    f"kept {chosen_s.file_name!r} and ignored [{others_s}]."
                ),
                message_vi=(
                    f"Có nhiều tệp phiên tập trùng cho ({pid}, {cond}, phiên {sid!r}): "
                    f"đã giữ {chosen_s.file_name!r} và bỏ qua [{others_s}]."
                ),
            )
        )
        session_logs.append(chosen_s)

    # Deduplicate any repeated (participant_id, condition, exercise_id, set_index)
    session_listed_files: set[str] = set()
    for s in session_logs:
        for f in s.files:
            session_listed_files.add(Path(f).name)

    grouped: dict[tuple[str, str, str, int], list[SetLog]] = defaultdict(list)
    for sl in raw_set_logs:
        grouped[sl.set_key].append(sl)

    final_sets: dict[tuple[str, str, str, int], SetLog] = {}
    for key, candidates in grouped.items():
        if len(candidates) == 1:
            final_sets[key] = candidates[0]
            continue

        # Prefer: completed set -> non-empty reps -> listed in session.files -> latest started_at_utc -> filename
        candidates_sorted = sorted(
            candidates,
            key=lambda s: (
                s.has_set_complete,
                len(s.reps) > 0,
                Path(s.file_name).name in session_listed_files,
                s.started_at_utc,
                s.file_name,
            ),
            reverse=True,
        )
        chosen = candidates_sorted[0]
        others = ", ".join(c.file_name for c in candidates_sorted[1:])
        pid, cond, ex_id, s_idx = key
        issues.append(
            ValidationIssue(
                severity="warning",
                code="duplicate_set_log",
                file=chosen.file_name,
                line=1,
                message_en=(
                    f"Multiple set logs found for ({pid}, {cond}, {ex_id}, set {s_idx}): "
                    f"kept {chosen.file_name!r} and ignored [{others}]."
                ),
                message_vi=(
                    f"Có nhiều tệp log trùng cho ({pid}, {cond}, {ex_id}, hiệp {s_idx}): "
                    f"đã giữ {chosen.file_name!r} và bỏ qua [{others}]."
                ),
            )
        )
        final_sets[key] = chosen

    return (final_sets, session_logs)


def _parse_session_log(
    path: Path,
    rel_name: str,
    raw_text: str,
    obj: dict[str, Any],
    participant_canon: IdCanonicalizer,
    issues: list[ValidationIssue],
) -> Optional[SessionLog]:
    raw_pid = obj.get("participant_id")
    if not isinstance(raw_pid, str) or not raw_pid.strip():
        issues.append(
            ValidationIssue(
                severity="warning",
                code="missing_participant_id",
                file=rel_name,
                line=find_json_line(raw_text, "participant_id"),
                message_en="Session log missing non-empty participant_id; skipped.",
                message_vi="Tệp phiên tập thiếu participant_id; đã bỏ qua.",
            )
        )
        return None
    pid_line = find_json_line(raw_text, "participant_id", raw_pid)
    pid = participant_canon.resolve(
        raw_pid,
        rel_name,
        pid_line,
        issues,
        "case_space_participant_id",
    )
    if pid.casefold() == "anon":
        issues.append(
            ValidationIssue(
                severity="warning",
                code="anonymous_participant_id",
                file=rel_name,
                line=pid_line,
                message_en=(
                    "Session log uses default participant_id 'anon' (no participant ID was set "
                    "on the phone before recording); verify which participant this session belongs to."
                ),
                message_vi=(
                    "Tệp phiên tập đang dùng participant_id mặc định 'anon' (chưa nhập mã người tập "
                    "trên điện thoại trước khi quay); hãy kiểm tra phiên này thuộc người tập nào."
                ),
            )
        )

    raw_cond = obj.get("condition")
    if not isinstance(raw_cond, str):
        issues.append(
            ValidationIssue(
                severity="warning",
                code="unknown_condition",
                file=rel_name,
                line=find_json_line(raw_text, "condition"),
                message_en=f"Session log missing valid condition ({raw_cond!r}); skipped.",
                message_vi=f"Tệp phiên tập thiếu điều kiện 'ai'/'control' hợp lệ ({raw_cond!r}); đã bỏ qua.",
            )
        )
        return None
    cond = resolve_known_token(
        raw_cond,
        KNOWN_CONDITIONS,
        "Condition",
        "Điều kiện tập",
        rel_name,
        find_json_line(raw_text, "condition", raw_cond),
        issues,
        "unknown_condition",
        "case_space_condition",
    )
    if cond is None:
        return None

    raw_sat = obj.get("satisfaction")
    sat: Optional[int] = None
    if raw_sat is not None:
        if isinstance(raw_sat, int) and not isinstance(raw_sat, bool) and 1 <= raw_sat <= 5:
            sat = raw_sat
        else:
            issues.append(
                ValidationIssue(
                    severity="warning",
                    code="invalid_satisfaction",
                    file=rel_name,
                    line=find_json_line(raw_text, "satisfaction", raw_sat),
                    message_en=(
                        f"Invalid satisfaction value {raw_sat!r} (expected integer 1..5 or null); "
                        f"treated as missing."
                    ),
                    message_vi=(
                        f"Điểm hài lòng {raw_sat!r} không hợp lệ (chỉ nhận số nguyên 1..5 hoặc null); "
                        f"đã coi như bỏ trống."
                    ),
                )
            )

    raw_files = obj.get("files")
    files_list = [str(x) for x in raw_files] if isinstance(raw_files, list) else []
    session_id = str(obj.get("session_id") or path.stem)

    fault_reports: list[tuple[str, int, str, str]] = []
    raw_reports = obj.get("fault_reports")
    for rep in raw_reports if isinstance(raw_reports, list) else []:
        ok = (
            isinstance(rep, dict)
            and isinstance(rep.get("exercise_id"), str)
            and isinstance(rep.get("set_index"), int)
            and not isinstance(rep.get("set_index"), bool)
            and isinstance(rep.get("file"), str)
            and isinstance(rep.get("fault"), str)
            and rep["fault"].strip()
        )
        if not ok:
            issues.append(
                ValidationIssue(
                    severity="warning",
                    code="invalid_fault_report",
                    file=rel_name,
                    line=find_json_line(raw_text, "fault_reports"),
                    message_en=f"Malformed fault_reports entry {rep!r}; skipped.",
                    message_vi=f"Mục fault_reports không hợp lệ {rep!r}; đã bỏ qua.",
                )
            )
            continue
        fault_reports.append(
            (rep["exercise_id"].strip(), rep["set_index"], rep["file"], rep["fault"].strip())
        )

    return SessionLog(
        file_path=str(path),
        file_name=rel_name,
        session_id=session_id,
        participant_id=pid,
        condition=cond,
        satisfaction=sat,
        files=files_list,
        fault_reports=fault_reports,
    )


def _parse_set_log(
    path: Path,
    rel_name: str,
    raw_text: str,
    obj: dict[str, Any],
    participant_canon: IdCanonicalizer,
    cue_mapper: CueFaultMapper,
    issues: list[ValidationIssue],
    form_faults_only: bool = False,
) -> Optional[SetLog]:
    raw_pid = obj.get("participant_id")
    if not isinstance(raw_pid, str) or not raw_pid.strip():
        issues.append(
            ValidationIssue(
                severity="warning",
                code="missing_participant_id",
                file=rel_name,
                line=find_json_line(raw_text, "participant_id"),
                message_en="Set log missing non-empty participant_id; skipped.",
                message_vi="Tệp log hiệp tập thiếu participant_id; đã bỏ qua.",
            )
        )
        return None
    pid_line = find_json_line(raw_text, "participant_id", raw_pid)
    pid = participant_canon.resolve(
        raw_pid,
        rel_name,
        pid_line,
        issues,
        "case_space_participant_id",
    )
    if pid.casefold() == "anon":
        issues.append(
            ValidationIssue(
                severity="warning",
                code="anonymous_participant_id",
                file=rel_name,
                line=pid_line,
                message_en=(
                    "Set log uses default participant_id 'anon' (no participant ID was set "
                    "on the phone before recording); verify which participant this set belongs to."
                ),
                message_vi=(
                    "Tệp log hiệp tập đang dùng participant_id mặc định 'anon' (chưa nhập mã người tập "
                    "trên điện thoại trước khi quay); hãy kiểm tra hiệp này thuộc người tập nào."
                ),
            )
        )

    raw_cond = obj.get("condition")
    if not isinstance(raw_cond, str):
        issues.append(
            ValidationIssue(
                severity="warning",
                code="unknown_condition",
                file=rel_name,
                line=find_json_line(raw_text, "condition"),
                message_en=f"Set log has invalid condition {raw_cond!r}; skipped.",
                message_vi=f"Tệp log có condition không hợp lệ {raw_cond!r}; đã bỏ qua.",
            )
        )
        return None
    cond = resolve_known_token(
        raw_cond,
        KNOWN_CONDITIONS,
        "Condition",
        "Điều kiện tập",
        rel_name,
        find_json_line(raw_text, "condition", raw_cond),
        issues,
        "unknown_condition",
        "case_space_condition",
    )
    if cond is None:
        return None

    raw_ex = obj.get("exercise_id")
    if not isinstance(raw_ex, str):
        issues.append(
            ValidationIssue(
                severity="warning",
                code="unknown_exercise_id",
                file=rel_name,
                line=find_json_line(raw_text, "exercise_id"),
                message_en=f"Set log has non-string exercise_id {raw_ex!r}; skipped.",
                message_vi=f"Tệp log có exercise_id không hợp lệ {raw_ex!r}; đã bỏ qua.",
            )
        )
        return None
    ex_id = resolve_known_token(
        raw_ex,
        tuple(KNOWN_EXERCISES.keys()),
        "Exercise ID",
        "Mã bài tập",
        rel_name,
        find_json_line(raw_text, "exercise_id", raw_ex),
        issues,
        "unknown_exercise_id",
        "case_space_exercise_id",
    )
    if ex_id is None:
        return None

    raw_set_idx = obj.get("set_index")
    if not isinstance(raw_set_idx, int) or isinstance(raw_set_idx, bool) or raw_set_idx < 1:
        issues.append(
            ValidationIssue(
                severity="warning",
                code="invalid_set_index",
                file=rel_name,
                line=find_json_line(raw_text, "set_index", raw_set_idx),
                message_en=f"Set log has invalid set_index {raw_set_idx!r} (expected >= 1); skipped.",
                message_vi=f"Tệp log có set_index {raw_set_idx!r} không hợp lệ (cần số nguyên >= 1); đã bỏ qua.",
            )
        )
        return None

    raw_beep = obj.get("sync_beep_t_ms")
    sync_beep_t_ms: Optional[int] = None
    if raw_beep is not None:
        if isinstance(raw_beep, (int, float)) and not isinstance(raw_beep, bool):
            sync_beep_t_ms = int(round(raw_beep))
        else:
            issues.append(
                ValidationIssue(
                    severity="warning",
                    code="invalid_sync_beep",
                    file=rel_name,
                    line=find_json_line(raw_text, "sync_beep_t_ms", raw_beep),
                    message_en=f"Invalid sync_beep_t_ms {raw_beep!r}; treated as null.",
                    message_vi=f"Giá trị sync_beep_t_ms {raw_beep!r} không hợp lệ; đã coi như null.",
                )
            )

    frames_obj = obj.get("frames") if isinstance(obj.get("frames"), dict) else {}
    mean_fps = _opt_num(frames_obj.get("mean_fps"))
    min_fps_1s = _opt_num(frames_obj.get("min_fps_1s"))
    max_gap_ms = _opt_num(frames_obj.get("max_gap_ms"))
    frames_total_num = _opt_num(frames_obj.get("total"))
    frames_dur_num = _opt_num(frames_obj.get("duration_ms"))
    frames_total = int(frames_total_num) if frames_total_num is not None else None
    frames_duration_ms = int(frames_dur_num) if frames_dur_num is not None else None

    summary_obj = obj.get("summary") if isinstance(obj.get("summary"), dict) else {}
    active_num = _opt_num(summary_obj.get("active_ms"))
    unseen_num = _opt_num(summary_obj.get("unseen_ms"))
    paused_num = _opt_num(summary_obj.get("paused_ms"))
    sum_reps_num = _opt_num(summary_obj.get("reps"))
    sum_good_num = _opt_num(summary_obj.get("good_reps"))

    if active_num is None or unseen_num is None:
        issues.append(
            ValidationIssue(
                severity="warning",
                code="missing_summary_fields",
                file=rel_name,
                line=find_json_line(raw_text, "summary"),
                message_en="Set log summary missing active_ms or unseen_ms; defaulting missing values to 0.",
                message_vi="Phần summary của tệp log thiếu active_ms hoặc unseen_ms; đã gán mặc định bằng 0.",
            )
        )
    active_ms = max(0, int(round(active_num or 0)))
    unseen_ms = max(0, int(round(unseen_num or 0)))
    paused_ms = max(0, int(round(paused_num or 0)))
    if unseen_ms > active_ms:
        issues.append(
            ValidationIssue(
                severity="warning",
                code="unseen_exceeds_active_ms",
                file=rel_name,
                line=find_json_line(raw_text, "unseen_ms", unseen_num),
                message_en=(
                    f"summary.unseen_ms ({unseen_ms}) exceeds summary.active_ms ({active_ms}); "
                    f"clamped to {active_ms} ms."
                ),
                message_vi=(
                    f"summary.unseen_ms ({unseen_ms}) lớn hơn summary.active_ms ({active_ms}); "
                    f"đã giới hạn về {active_ms} ms."
                ),
            )
        )
        unseen_ms = active_ms

    raw_events = obj.get("events")
    if not isinstance(raw_events, list):
        issues.append(
            ValidationIssue(
                severity="warning",
                code="missing_events",
                file=rel_name,
                line=find_json_line(raw_text, "events"),
                message_en="Set log missing events list; skipped.",
                message_vi="Tệp log thiếu danh sách events; đã bỏ qua.",
            )
        )
        return None

    # Validate non-decreasing t_ms order; sort stably if out of order
    indexed_events: list[tuple[int, int, dict[str, Any]]] = []
    prev_t = -1
    out_of_order = False
    for idx, ev in enumerate(raw_events):
        if not isinstance(ev, dict):
            continue
        t_val = _opt_num(ev.get("t_ms"))
        if t_val is None:
            continue
        t_int = int(round(t_val))
        if t_int < prev_t:
            out_of_order = True
        prev_t = max(prev_t, t_int)
        indexed_events.append((t_int, idx, ev))

    if out_of_order:
        issues.append(
            ValidationIssue(
                severity="warning",
                code="events_out_of_order",
                file=rel_name,
                line=find_json_line(raw_text, "events"),
                message_en="Events in set log were not in non-decreasing t_ms order; sorted stably by t_ms.",
                message_vi="Các sự kiện trong tệp log không xếp tăng dần theo t_ms; đã sắp xếp lại theo t_ms.",
            )
        )
        indexed_events.sort(key=lambda item: (item[0], item[1]))

    valid_faults_for_ex = KNOWN_EXERCISES[ex_id]
    push_up_hint_en = (
        "Note: push_up combines sagging and piking under 'sag'." if ex_id == "push_up" else ""
    )
    push_up_hint_vi = (
        "Lưu ý: bài push_up gộp cả võng lưng và nhổng mông vào mã 'sag'."
        if ex_id == "push_up"
        else ""
    )

    event_line_spans = _locate_event_line_spans(raw_text)
    norm_fault_lookup = {
        re.sub(r"[\s_-]+", "", tok).casefold(): tok for tok in valid_faults_for_ex
    }

    reps: list[AppRep] = []
    cues: list[AppCue] = []
    raw_unseen_spans: list[tuple[str, str, int, int]] = []
    raw_pause_spans: list[tuple[int, int]] = []
    raw_live_fault_spans: list[tuple[str, int, int, int]] = []
    open_live_faults: dict[tuple[str, str], tuple[int, int]] = {}
    open_unseen: Optional[tuple[str, str, int]] = None
    open_pause_start: Optional[int] = None
    has_set_complete = False
    set_complete_t_ms: Optional[int] = None
    last_event_t_ms = 0

    for seq_idx, (t_ms, orig_idx, ev) in enumerate(indexed_events):
        last_event_t_ms = max(last_event_t_ms, t_ms)
        ev_type = ev.get("type")
        if not isinstance(ev_type, str):
            continue

        if orig_idx < len(event_line_spans):
            ev_lo_ln, ev_hi_ln = event_line_spans[orig_idx]
        else:
            ev_lo_ln, ev_hi_ln = 1, None

        rel_t_s = ((t_ms - sync_beep_t_ms) / 1000.0) if sync_beep_t_ms is not None else None

        if ev_type == "rep":
            n_num = _opt_num(ev.get("n"))
            rep_n = int(round(n_num)) if n_num is not None else (len(reps) + 1)
            raw_correct = ev.get("correct", True)
            if isinstance(raw_correct, bool):
                correct = raw_correct
            elif isinstance(raw_correct, str) and raw_correct.strip().lower() in {"true", "false"}:
                correct = raw_correct.strip().lower() == "true"
            else:
                correct = bool(raw_correct)
            data_map = ev.get("data") if isinstance(ev.get("data"), dict) else {}
            affects_map = (
                data_map.get("fault_affects_form")
                if isinstance(data_map.get("fault_affects_form"), dict)
                else None
            )
            affects_norm_map = (
                {
                    re.sub(r"[\s_-]+", "", str(ak)).casefold(): av
                    for ak, av in affects_map.items()
                }
                if affects_map is not None
                else None
            )

            raw_fault_list = ev.get("faults")
            clean_faults: list[str] = []
            soft_marked_faults: list[str] = []
            if isinstance(raw_fault_list, list):
                for rf in raw_fault_list:
                    if not isinstance(rf, str) or not rf.strip():
                        continue
                    if rf.strip() in STATUS_FAULTS.get(ex_id, ()):
                        continue
                    resolved = resolve_known_token(
                        rf,
                        valid_faults_for_ex,
                        f"Fault ID for {ex_id}",
                        f"Mã lỗi của bài {ex_id}",
                        rel_name,
                        find_json_line(
                            raw_text,
                            "faults",
                            rf,
                            start_line=ev_lo_ln,
                            end_line=ev_hi_ln,
                        ),
                        issues,
                        "unknown_fault_id",
                        "case_space_fault_id",
                        extra_hint_en=push_up_hint_en,
                        extra_hint_vi=push_up_hint_vi,
                    )
                    if resolved is None:
                        continue
                    is_marked_soft = False
                    if affects_map is not None:
                        aff_val = affects_map.get(rf, affects_map.get(resolved))
                        if aff_val is None and affects_norm_map is not None:
                            aff_val = affects_norm_map.get(
                                re.sub(r"[\s_-]+", "", resolved).casefold()
                            )
                        if aff_val is False:
                            is_marked_soft = True
                    if form_faults_only:
                        if correct or is_marked_soft:
                            continue
                    elif is_marked_soft and resolved not in soft_marked_faults:
                        soft_marked_faults.append(resolved)
                    if resolved not in clean_faults:
                        clean_faults.append(resolved)

            if correct and clean_faults:
                issues.append(
                    ValidationIssue(
                        severity="warning",
                        code="rep_correct_with_faults",
                        file=rel_name,
                        line=find_json_line(
                            raw_text, "n", rep_n, start_line=ev_lo_ln, end_line=ev_hi_ln
                        ),
                        message_en=(
                            f"App rep n={rep_n} has correct=true alongside non-empty "
                            f"faults={clean_faults} (likely soft/sub-threshold FaultRecords "
                            f"included in fault_types; pass --form-faults-only to exclude "
                            f"non-form-affecting warnings)."
                        ),
                        message_vi=(
                            f"Lần tập n={rep_n} của ứng dụng ghi correct=true nhưng vẫn có "
                            f"faults={clean_faults} (có thể do lỗi mức cảnh báo nhẹ vẫn được "
                            f"đưa vào fault_types; có thể thêm cờ --form-faults-only để loại trừ "
                            f"cảnh báo nhẹ không làm hỏng form)."
                        ),
                    )
                )
            elif (not correct) and soft_marked_faults:
                issues.append(
                    ValidationIssue(
                        severity="warning",
                        code="rep_soft_faults_included",
                        file=rel_name,
                        line=find_json_line(
                            raw_text, "n", rep_n, start_line=ev_lo_ln, end_line=ev_hi_ln
                        ),
                        message_en=(
                            f"App rep n={rep_n} (correct=false) includes non-form-affecting "
                            f"warning fault(s) {soft_marked_faults} (data.fault_affects_form=false) "
                            f"alongside form-breaking fault(s); pass --form-faults-only to exclude "
                            f"non-form-affecting warnings."
                        ),
                        message_vi=(
                            f"Lần tập n={rep_n} của ứng dụng (correct=false) có kèm mã cảnh báo nhẹ "
                            f"không làm hỏng form {soft_marked_faults} (data.fault_affects_form=false) "
                            f"bên cạnh lỗi chính; có thể thêm cờ --form-faults-only để loại trừ "
                            f"cảnh báo nhẹ."
                        ),
                    )
                )

            reps.append(
                AppRep(
                    event_index=seq_idx,
                    n=rep_n,
                    t_ms=t_ms,
                    rel_t_s=rel_t_s,
                    correct=correct,
                    faults=tuple(sorted(clean_faults)),
                    data=data_map,
                    form_judged=data_map.get("form_judged") is not False,
                )
            )

        elif ev_type == "cue":
            key_str = str(ev.get("key") or "")
            raw_played = ev.get("played", False)
            if isinstance(raw_played, bool):
                played = raw_played
            elif isinstance(raw_played, str) and raw_played.strip().lower() in {"true", "false"}:
                played = raw_played.strip().lower() == "true"
            else:
                played = bool(raw_played)
            raw_fault_val = ev.get("fault")
            raw_fault_str = (
                raw_fault_val.strip()
                if isinstance(raw_fault_val, str) and raw_fault_val.strip()
                else None
            )
            resolved_fault: Optional[str] = None
            mapping_source = "unmapped"
            if raw_fault_str is not None and raw_fault_str in STATUS_FAULTS.get(ex_id, ()):
                mapping_source = "explicit_non_fault"
            elif raw_fault_str is not None:
                resolved_fault = resolve_known_token(
                    raw_fault_str,
                    valid_faults_for_ex,
                    f"Cue fault ID for {ex_id}",
                    f"Mã lỗi của lời nhắc ({ex_id})",
                    rel_name,
                    find_json_line(
                        raw_text, "fault", raw_fault_val, start_line=ev_lo_ln, end_line=ev_hi_ln
                    ),
                    issues,
                    "unknown_fault_id",
                    "case_space_fault_id",
                    extra_hint_en=push_up_hint_en,
                    extra_hint_vi=push_up_hint_vi,
                )
                if resolved_fault is not None:
                    mapping_source = "log"
            else:
                found, mapped_fault = cue_mapper.lookup(ex_id, key_str)
                if found:
                    if mapped_fault is None:
                        mapping_source = "explicit_non_fault"
                    elif mapped_fault in valid_faults_for_ex:
                        resolved_fault = mapped_fault
                        mapping_source = "cue_map"
                    else:
                        issues.append(
                            ValidationIssue(
                                severity="warning",
                                code="cue_map_fault_invalid_for_exercise",
                                file=rel_name,
                                line=find_json_line(
                                    raw_text, "key", key_str, start_line=ev_lo_ln, end_line=ev_hi_ln
                                ),
                                message_en=(
                                    f"Cue key {key_str!r} mapped to fault {mapped_fault!r}, "
                                    f"which is not a valid fault for exercise {ex_id!r}; left unmapped."
                                ),
                                message_vi=(
                                    f"Khóa lời nhắc {key_str!r} ánh xạ sang lỗi {mapped_fault!r} "
                                    f"không thuộc bài {ex_id!r}; giữ ở trạng thái chưa ánh xạ."
                                ),
                            )
                        )

            cues.append(
                AppCue(
                    event_index=seq_idx,
                    t_ms=t_ms,
                    rel_t_s=rel_t_s,
                    key=key_str,
                    played=played,
                    raw_fault=raw_fault_str,
                    resolved_fault=resolved_fault,
                    mapping_source=mapping_source,
                )
            )

        elif ev_type == "fault_start":
            raw_f = ev.get("fault")
            if isinstance(raw_f, str) and raw_f.strip():
                canon_f = norm_fault_lookup.get(re.sub(r"[\s_-]+", "", raw_f).casefold())
                if canon_f is not None:
                    msg_s = str(ev.get("message") or "")
                    pair_key = (canon_f, msg_s)
                    if pair_key not in open_live_faults:
                        open_live_faults[pair_key] = (t_ms, seq_idx)

        elif ev_type == "fault_end":
            raw_f = ev.get("fault")
            if isinstance(raw_f, str) and raw_f.strip():
                canon_f = norm_fault_lookup.get(re.sub(r"[\s_-]+", "", raw_f).casefold())
                if canon_f is not None:
                    msg_s = str(ev.get("message") or "")
                    pair_key = (canon_f, msg_s)
                    if pair_key in open_live_faults:
                        s_ms, s_seq = open_live_faults.pop(pair_key)
                        raw_live_fault_spans.append((canon_f, s_ms, t_ms, s_seq))
                    else:
                        # Fallback if message was omitted on fault_end
                        fallback_key = next(
                            (k for k in open_live_faults if k[0] == canon_f), None
                        )
                        if fallback_key is not None:
                            s_ms, s_seq = open_live_faults.pop(fallback_key)
                            raw_live_fault_spans.append((canon_f, s_ms, t_ms, s_seq))

        elif ev_type == "unseen_start":
            if open_unseen is not None:
                prev_phase, prev_reason, prev_start = open_unseen
                raw_unseen_spans.append((prev_phase, prev_reason, prev_start, t_ms))
            phase = str(ev.get("phase") or "active")
            reason = str(ev.get("reason") or "unknown")
            open_unseen = (phase, reason, t_ms)

        elif ev_type == "unseen_end":
            if open_unseen is not None:
                prev_phase, prev_reason, prev_start = open_unseen
                raw_unseen_spans.append((prev_phase, prev_reason, prev_start, t_ms))
                open_unseen = None

        elif ev_type == "pause_start":
            if open_pause_start is None:
                open_pause_start = t_ms

        elif ev_type == "pause_end":
            if open_pause_start is not None:
                raw_pause_spans.append((open_pause_start, t_ms))
                open_pause_start = None

        elif ev_type == "set_complete":
            has_set_complete = True
            set_complete_t_ms = t_ms

        else:
            # Per schema: "A reader must ignore event types and fields it does not know."
            pass

    end_anchor_ms = (
        set_complete_t_ms
        if set_complete_t_ms is not None
        else (frames_duration_ms if frames_duration_ms is not None else last_event_t_ms)
    )
    end_anchor_ms = max(end_anchor_ms, last_event_t_ms)

    for (canon_f, _msg_s), (s_ms, s_seq) in open_live_faults.items():
        raw_live_fault_spans.append((canon_f, s_ms, end_anchor_ms, s_seq))

    # Merge contiguous/overlapping live fault spans for the same fault within a single rep attempt
    spans_by_fault: dict[str, list[tuple[int, int, int]]] = defaultdict(list)
    for canon_f, s_ms, e_ms, s_seq in raw_live_fault_spans:
        spans_by_fault[canon_f].append((s_ms, max(s_ms, e_ms), s_seq))

    live_fault_spans: list[LiveFaultSpan] = []
    for canon_f, f_spans in sorted(spans_by_fault.items()):
        f_spans.sort(key=lambda x: (x[0], x[2], x[1]))
        merged_f: list[LiveFaultSpan] = []
        for s_ms, e_ms, s_seq in f_spans:
            if merged_f:
                prev = merged_f[-1]
                crossed_rep = any(prev.end_ms <= r.t_ms <= s_ms for r in reps)
                if s_ms <= prev.end_ms and not crossed_rep:
                    merged_f[-1] = LiveFaultSpan(
                        fault_id=canon_f,
                        start_ms=prev.start_ms,
                        end_ms=max(prev.end_ms, e_ms),
                        start_event_index=min(prev.start_event_index, s_seq),
                    )
                    continue
            merged_f.append(
                LiveFaultSpan(
                    fault_id=canon_f,
                    start_ms=s_ms,
                    end_ms=e_ms,
                    start_event_index=s_seq,
                )
            )
        live_fault_spans.extend(merged_f)

    if open_pause_start is not None:
        raw_pause_spans.append((open_pause_start, end_anchor_ms))
    if open_unseen is not None:
        prev_phase, prev_reason, prev_start = open_unseen
        raw_unseen_spans.append((prev_phase, prev_reason, prev_start, end_anchor_ms))

    merged_pauses = _merge_intervals(raw_pause_spans)
    max_non_paused_window_ms: Optional[int] = None
    if frames_duration_ms is not None:
        if frames_duration_ms <= 0:
            max_non_paused_window_ms = 0
        else:
            cursor_ms = 0
            best_win_ms = 0
            for p_s, p_e in merged_pauses:
                if p_s >= frames_duration_ms:
                    break
                clamped_s = max(cursor_ms, p_s)
                if clamped_s > cursor_ms:
                    best_win_ms = max(best_win_ms, clamped_s - cursor_ms)
                cursor_ms = max(cursor_ms, min(frames_duration_ms, p_e))
            if frames_duration_ms > cursor_ms:
                best_win_ms = max(best_win_ms, frames_duration_ms - cursor_ms)
            max_non_paused_window_ms = best_win_ms

    unseen_intervals: list[UnseenInterval] = []
    for phase, reason, s_ms, e_ms in raw_unseen_spans:
        raw_dur = max(0, e_ms - s_ms)
        if phase == "active":
            paused_overlap = _compute_overlap_ms(s_ms, e_ms, merged_pauses)
            eff_dur = max(0, raw_dur - paused_overlap)
        else:
            eff_dur = raw_dur
        unseen_intervals.append(
            UnseenInterval(
                phase=phase,
                reason=reason,
                start_ms=s_ms,
                end_ms=e_ms,
                effective_ms=eff_dur,
            )
        )

    summary_reps_int = int(round(sum_reps_num)) if sum_reps_num is not None else None
    if summary_reps_int is not None and summary_reps_int != len(reps):
        issues.append(
            ValidationIssue(
                severity="warning",
                code="summary_reps_mismatch",
                file=rel_name,
                line=find_json_line(raw_text, "reps", sum_reps_num),
                message_en=(
                    f"summary.reps={summary_reps_int} does not match count of rep events "
                    f"({len(reps)}); rep events are used for matching and counting."
                ),
                message_vi=(
                    f"summary.reps={summary_reps_int} không khớp với số sự kiện rep thực tế "
                    f"({len(reps)}); kịch bản sử dụng các sự kiện rep để đối sánh."
                ),
            )
        )

    event_active_unseen_ms = sum(
        iv.effective_ms for iv in unseen_intervals if iv.phase == "active"
    )
    if active_num is not None and unseen_num is not None and abs(event_active_unseen_ms - unseen_ms) > 50:
        issues.append(
            ValidationIssue(
                severity="warning",
                code="unseen_ms_mismatch",
                file=rel_name,
                line=find_json_line(raw_text, "unseen_ms", unseen_num),
                message_en=(
                    f"summary.unseen_ms={unseen_ms} differs from active unseen events total "
                    f"({event_active_unseen_ms} ms)."
                ),
                message_vi=(
                    f"summary.unseen_ms={unseen_ms} lệch so với tổng thời lượng sự kiện "
                    f"unseen ở pha active ({event_active_unseen_ms} ms)."
                ),
            )
        )

    return SetLog(
        file_path=str(path),
        file_name=rel_name,
        session_id=str(obj.get("session_id") or path.stem),
        participant_id=pid,
        condition=cond,
        exercise_id=ex_id,
        set_index=raw_set_idx,
        started_at_utc=str(obj.get("started_at_utc") or ""),
        sync_beep_t_ms=sync_beep_t_ms,
        mean_fps=mean_fps,
        min_fps_1s=min_fps_1s,
        max_gap_ms=max_gap_ms,
        frames_total=frames_total,
        frames_duration_ms=frames_duration_ms,
        max_non_paused_window_ms=max_non_paused_window_ms,
        active_ms=active_ms,
        unseen_ms=unseen_ms,
        paused_ms=paused_ms,
        summary_reps=summary_reps_int,
        summary_good_reps=int(round(sum_good_num)) if sum_good_num is not None else None,
        has_set_complete=has_set_complete,
        reps=reps,
        cues=cues,
        live_fault_spans=live_fault_spans,
        unseen_intervals=unseen_intervals,
    )


def _opt_num(val: Any) -> Optional[float]:
    if isinstance(val, (int, float)) and not isinstance(val, bool):
        f = float(val)
        if not math.isnan(f) and not math.isinf(f):
            return f
    return None


# ---------------------------------------------------------------------------
# Coach labels CSV loader
# ---------------------------------------------------------------------------


def collect_label_files(
    label_inputs: Sequence[Path],
    out_dir: Optional[Path] = None,
    cue_map_path: Optional[Path] = None,
) -> list[Path]:
    resolved_out = out_dir.resolve() if out_dir is not None else None
    resolved_cue = cue_map_path.resolve() if cue_map_path is not None else None
    paths: list[Path] = []
    seen_resolved: set[Path] = set()
    for p in label_inputs:
        if p.is_dir():
            resolved_dir = p.resolve()
            exclude_out_subtree = (
                resolved_out is not None and resolved_dir in resolved_out.parents
            )
            for c in sorted(p.rglob("*")):
                if not c.is_file() or c.suffix.lower() != ".csv":
                    continue
                rc = c.resolve()
                if exclude_out_subtree and (
                    rc == resolved_out or resolved_out in rc.parents
                ):
                    continue
                if resolved_cue is not None and rc == resolved_cue:
                    continue
                if c.name.lower() in IGNORED_DIRECTORY_CSV_NAMES:
                    continue
                if rc not in seen_resolved:
                    seen_resolved.add(rc)
                    paths.append(c)
        else:
            rp = p.resolve()
            if rp not in seen_resolved:
                seen_resolved.add(rp)
                paths.append(p)
    return paths


def load_coach_labels(
    label_paths: Sequence[Path],
    participant_canon: IdCanonicalizer,
    coach_canon: IdCanonicalizer,
    issues: list[ValidationIssue],
) -> tuple[list[CoachRow], bool]:
    """Load coach label CSV(s). Returns (rows, header_valid_at_least_once)."""
    all_rows: list[CoachRow] = []
    seen_rep_keys: dict[tuple[str, str, str, str, int, int], tuple[str, int]] = {}
    any_valid_header = False

    basename_counts = Counter(p.name for p in label_paths)
    for path in label_paths:
        if basename_counts[path.name] == 1:
            file_name = path.name
        else:
            parent_name = path.resolve().parent.name
            file_name = (
                f"{parent_name}/{path.name}"
                if parent_name
                else str(path).replace("\\", "/")
            )
        text = _read_text_forgiving(path, issues)
        lines = text.splitlines()
        if not lines or all(not ln.strip() for ln in lines):
            issues.append(
                ValidationIssue(
                    severity="error",
                    code="empty_labels_csv",
                    file=file_name,
                    line=1,
                    message_en=f"Coach label CSV {file_name!r} is empty.",
                    message_vi=f"Tệp nhãn HLV {file_name!r} đang trống.",
                )
            )
            continue

        # Find first non-empty line to detect delimiter deterministically
        first_non_empty_idx = next(i for i, ln in enumerate(lines) if ln.strip())
        header_line = lines[first_non_empty_idx]
        delimiter = ","
        for cand in (",", "\t", ";"):
            cand_cols = [c.strip().lower() for c in next(csv.reader([header_line], delimiter=cand))]
            if all(req in cand_cols for req in REQUIRED_LABEL_COLUMNS):
                delimiter = cand
                break

        if delimiter != ",":
            issues.append(
                ValidationIssue(
                    severity="warning",
                    code="non_comma_csv_delimiter",
                    file=file_name,
                    line=first_non_empty_idx + 1,
                    message_en=f"CSV {file_name!r} uses delimiter {delimiter!r} instead of ','; parsed automatically.",
                    message_vi=f"Tệp CSV {file_name!r} dùng dấu phân cách cột {delimiter!r} thay vì dấu phẩy ','; đã tự động đọc.",
                )
            )

        reader = csv.reader(lines, delimiter=delimiter)
        header_row: Optional[list[str]] = None
        header_line_num = 1
        for row in reader:
            if row and any(c.strip() for c in row):
                header_row = row
                header_line_num = reader.line_num
                break

        if header_row is None:
            continue

        norm_cols = [c.strip().lower() for c in header_row]
        missing_cols = [req for req in REQUIRED_LABEL_COLUMNS if req not in norm_cols]
        if missing_cols:
            issues.append(
                ValidationIssue(
                    severity="error",
                    code="invalid_labels_header",
                    file=file_name,
                    line=header_line_num,
                    message_en=(
                        f"CSV {file_name!r} is missing required columns {missing_cols} "
                        f"(found: {header_row})."
                    ),
                    message_vi=(
                        f"Tệp CSV {file_name!r} thiếu các cột bắt buộc {missing_cols} "
                        f"(hiện có: {header_row})."
                    ),
                )
            )
            continue

        any_valid_header = True
        effective_header_len = len(norm_cols)
        while effective_header_len > 0 and norm_cols[effective_header_len - 1] == "":
            effective_header_len -= 1
        col_idx = {col: norm_cols.index(col) for col in REQUIRED_LABEL_COLUMNS}

        for row in reader:
            line_no = reader.line_num
            if not row or all(not c.strip() for c in row):
                continue
            raw_row_cells = list(row)
            orig_row_len = len(raw_row_cells)

            # Recover unquoted Vietnamese decimal comma in video_t_s (e.g. ...,12,0,1,depth,)
            if (
                delimiter == ","
                and len(raw_row_cells) > effective_header_len
                and col_idx["counted"] == col_idx["video_t_s"] + 1
                and col_idx["faults"] == col_idx["video_t_s"] + 2
                and len(raw_row_cells) > col_idx["faults"]
            ):
                vt_idx = col_idx["video_t_s"]
                vt_left = raw_row_cells[vt_idx].strip()
                vt_right = raw_row_cells[vt_idx + 1].strip()
                shifted_cnt = raw_row_cells[vt_idx + 2].strip()
                if (
                    re.fullmatch(r"\d+(?::\d{1,2})?", vt_left)
                    and re.fullmatch(r"\d{1,3}", vt_right)
                    and shifted_cnt.lower().replace(",", ".")
                    in {"0", "1", "0.0", "1.0", "true", "false", "yes", "no", "y", "n"}
                ):
                    merged_vt = f"{vt_left},{vt_right}"
                    raw_row_cells = (
                        raw_row_cells[:vt_idx]
                        + [merged_vt]
                        + raw_row_cells[vt_idx + 2 :]
                    )
                    issues.append(
                        ValidationIssue(
                            severity="warning",
                            code="extra_csv_columns",
                            file=file_name,
                            line=line_no,
                            message_en=(
                                f"Row has {orig_row_len} columns (header has {effective_header_len}): "
                                f"unquoted decimal comma in video_t_s split {merged_vt!r} across two "
                                f"columns; recombined into {merged_vt!r} (use '.' for decimals in CSV)."
                            ),
                            message_vi=(
                                f"Dòng có {orig_row_len} cột (tiêu đề có {effective_header_len} cột): "
                                f"dấu phẩy thập phân không đặt trong ngoặc kép ở cột video_t_s làm tách "
                                f"{merged_vt!r} thành hai cột; đã gộp lại thành {merged_vt!r} (nên dùng dấu chấm '.')."
                            ),
                        )
                    )

            cur_row_len = len(raw_row_cells)
            if cur_row_len < len(norm_cols):
                row = raw_row_cells + [""] * (len(norm_cols) - cur_row_len)
            else:
                row = raw_row_cells
            extra_cells = (
                [c.strip() for c in row[effective_header_len:]]
                if cur_row_len > effective_header_len
                else []
            )

            raw_coach = row[col_idx["coach_id"]]
            raw_pid = row[col_idx["participant_id"]]
            raw_cond = row[col_idx["condition"]]
            raw_ex = row[col_idx["exercise_id"]]
            raw_set = row[col_idx["set_index"]].strip()
            raw_rep = row[col_idx["rep_n"]].strip()
            raw_video_t = row[col_idx["video_t_s"]]
            raw_counted = row[col_idx["counted"]].strip()
            raw_faults = row[col_idx["faults"]]
            note = row[col_idx["note"]].strip()

            if not raw_coach.strip():
                issues.append(
                    ValidationIssue(
                        severity="warning",
                        code="missing_coach_id",
                        file=file_name,
                        line=line_no,
                        message_en="Row is missing coach_id; skipped row.",
                        message_vi="Dòng thiếu coach_id; đã bỏ qua dòng này.",
                    )
                )
                continue
            if not raw_pid.strip():
                issues.append(
                    ValidationIssue(
                        severity="warning",
                        code="missing_participant_id",
                        file=file_name,
                        line=line_no,
                        message_en="Row is missing participant_id; skipped row.",
                        message_vi="Dòng thiếu participant_id; đã bỏ qua dòng này.",
                    )
                )
                continue

            coach_id = coach_canon.resolve(
                raw_coach, file_name, line_no, issues, "case_space_coach_id"
            )
            pid = participant_canon.resolve(
                raw_pid, file_name, line_no, issues, "case_space_participant_id"
            )

            cond = resolve_known_token(
                raw_cond,
                KNOWN_CONDITIONS,
                "Condition",
                "Điều kiện tập",
                file_name,
                line_no,
                issues,
                "unknown_condition",
                "case_space_condition",
            )
            if cond is None:
                continue

            ex_id = resolve_known_token(
                raw_ex,
                tuple(KNOWN_EXERCISES.keys()),
                "Exercise ID",
                "Mã bài tập",
                file_name,
                line_no,
                issues,
                "unknown_exercise_id",
                "case_space_exercise_id",
            )
            if ex_id is None:
                continue

            # Detect unquoted extra delimiters that shifted columns past effective header length
            if cur_row_len > effective_header_len:
                valid_ex_fault_norms = {
                    re.sub(r"[\s_-]+", "", tok).casefold(): tok
                    for tok in KNOWN_EXERCISES[ex_id]
                }
                recovered_faults: list[str] = []
                tail_cells = [row[col_idx["note"]], *row[effective_header_len:]]
                consumed_tail = 0
                if (
                    col_idx["faults"] == effective_header_len - 2
                    and col_idx["note"] == effective_header_len - 1
                    and raw_faults.strip()
                ):
                    for tc in tail_cells:
                        tc_s = tc.strip()
                        if not tc_s:
                            break
                        semi_parts = [p.strip() for p in tc_s.split(";") if p.strip()]
                        if not semi_parts:
                            break
                        matched_parts: list[str] = []
                        all_parts_valid = True
                        for sp in semi_parts:
                            sp_norm = re.sub(r"[\s_-]+", "", sp).casefold()
                            if sp_norm in valid_ex_fault_norms:
                                matched_parts.append(valid_ex_fault_norms[sp_norm])
                            else:
                                all_parts_valid = False
                                break
                        if not all_parts_valid:
                            break
                        recovered_faults.extend(matched_parts)
                        consumed_tail += 1

                if recovered_faults:
                    joined_rec = ";".join(recovered_faults)
                    raw_faults = f"{raw_faults};{joined_rec}" if raw_faults.strip() else joined_rec
                    rem_note_parts = [c.strip() for c in tail_cells[consumed_tail:] if c.strip()]
                    note = ", ".join(rem_note_parts)
                    rec_disp = (
                        repr(recovered_faults[0])
                        if len(recovered_faults) == 1
                        else repr(recovered_faults)
                    )
                    issues.append(
                        ValidationIssue(
                            severity="warning",
                            code="extra_csv_columns",
                            file=file_name,
                            line=line_no,
                            message_en=(
                                f"Row has {orig_row_len} columns (header has {effective_header_len}): "
                                f"unquoted {delimiter!r} split fault(s) {rec_disp} past the faults column; "
                                f"recovered into faults (use ';' between multiple faults)."
                            ),
                            message_vi=(
                                f"Dòng có {orig_row_len} cột (tiêu đề có {effective_header_len} cột): "
                                f"dấu {delimiter!r} không đặt trong ngoặc kép làm mã lỗi {rec_disp} "
                                f"bị đẩy lệch cột; đã khôi phục vào cột faults (hãy dùng ';' giữa các lỗi)."
                            ),
                        )
                    )
                elif any(extra_cells) or (
                    cur_row_len > len(norm_cols) and bool(raw_faults.strip()) and bool(note)
                ):
                    if col_idx["note"] == effective_header_len - 1:
                        note = ", ".join(c.strip() for c in tail_cells if c.strip())
                    shown_extra = extra_cells if any(extra_cells) else [note]
                    issues.append(
                        ValidationIssue(
                            severity="warning",
                            code="extra_csv_columns",
                            file=file_name,
                            line=line_no,
                            message_en=(
                                f"Row has {orig_row_len} columns (header has {effective_header_len}) with "
                                f"shifted/extra values {shown_extra!r}; check for unquoted {delimiter!r} "
                                f"or a misspelled fault ID in faults or note."
                            ),
                            message_vi=(
                                f"Dòng có {orig_row_len} cột (tiêu đề có {effective_header_len} cột) có dữ liệu "
                                f"lệch/dư {shown_extra!r}; hãy kiểm tra dấu {delimiter!r} thừa hoặc mã lỗi gõ sai "
                                f"chính tả trong cột faults hoặc note."
                            ),
                        )
                    )

            set_index = _parse_int_cell(
                raw_set,
                field_name="set_index",
                min_val=1,
                file_name=file_name,
                line=line_no,
                issues=issues,
                invalid_code="invalid_set_index",
                invalid_msg_en=f"Invalid set_index {raw_set!r} (expected integer >= 1); skipped row.",
                invalid_msg_vi=f"set_index {raw_set!r} không hợp lệ (cần số nguyên >= 1); đã bỏ qua dòng này.",
            )
            if set_index is None:
                continue

            counted = _parse_counted(raw_counted, file_name, line_no, issues)
            if counted is None:
                continue

            rep_n = _parse_int_cell(
                raw_rep,
                field_name="rep_n",
                min_val=0,
                file_name=file_name,
                line=line_no,
                issues=issues,
                invalid_code="invalid_rep_n",
                invalid_msg_en=(
                    f"Invalid rep_n {raw_rep!r} (expected integer >= 1, or 0 with "
                    f"counted=0 for an empty set); skipped row."
                ),
                invalid_msg_vi=(
                    f"rep_n {raw_rep!r} không hợp lệ (cần số nguyên >= 1, hoặc 0 đi kèm "
                    f"counted=0 cho hiệp không có lần tập nào); đã bỏ qua dòng này."
                ),
            )
            if rep_n is None:
                continue
            if rep_n == 0 and counted != 0:
                issues.append(
                    ValidationIssue(
                        severity="warning",
                        code="invalid_rep_n",
                        file=file_name,
                        line=line_no,
                        message_en=(
                            f"Invalid rep_n {raw_rep!r} with counted={counted} "
                            f"(rep_n=0 is only valid with counted=0 for an empty set); skipped row."
                        ),
                        message_vi=(
                            f"rep_n {raw_rep!r} đi kèm counted={counted} không hợp lệ "
                            f"(rep_n=0 chỉ dùng với counted=0 cho hiệp trống); đã bỏ qua dòng này."
                        ),
                    )
                )
                continue

            dup_key = (coach_id, pid, cond, ex_id, set_index, rep_n)
            if dup_key in seen_rep_keys:
                first_file, first_line = seen_rep_keys[dup_key]
                issues.append(
                    ValidationIssue(
                        severity="warning",
                        code="duplicate_label_row",
                        file=file_name,
                        line=line_no,
                        message_en=(
                            f"Duplicated coach row for ({coach_id}, {pid}, {cond}, {ex_id}, "
                            f"set {set_index}, rep_n {rep_n}) — already seen at "
                            f"{first_file}:{first_line}; skipped duplicate."
                        ),
                        message_vi=(
                            f"Dòng nhãn bị trùng cho ({coach_id}, {pid}, {cond}, {ex_id}, "
                            f"hiệp {set_index}, rep_n {rep_n}) — đã xuất hiện tại "
                            f"{first_file}:{first_line}; đã bỏ qua dòng trùng."
                        ),
                    )
                )
                continue
            seen_rep_keys[dup_key] = (file_name, line_no)

            video_t_s = parse_video_time_seconds(raw_video_t, file_name, line_no, issues)

            # Parse ';' separated faults (also recover if ',' was accidentally used inside quoted cell)
            valid_faults_for_ex = KNOWN_EXERCISES[ex_id]
            push_up_hint_en = (
                "Note: push_up combines sagging and piking under 'sag'."
                if ex_id == "push_up"
                else ""
            )
            push_up_hint_vi = (
                "Lưu ý: bài push_up gộp cả võng lưng và nhổng mông vào mã 'sag'."
                if ex_id == "push_up"
                else ""
            )
            clean_faults: list[str] = []
            fault_cell = raw_faults.strip()
            if fault_cell:
                raw_tokens = re.split(r"[;,]", fault_cell)
                if "," in fault_cell and ";" not in fault_cell:
                    issues.append(
                        ValidationIssue(
                            severity="warning",
                            code="comma_in_faults_cell",
                            file=file_name,
                            line=line_no,
                            message_en=(
                                f"Faults cell {raw_faults!r} used ',' instead of ';'; "
                                f"split on ',' automatically."
                            ),
                            message_vi=(
                                f"Cột faults {raw_faults!r} dùng dấu ',' thay vì ';'; "
                                f"đã tự động tách lỗi."
                            ),
                        )
                    )
                for tok in raw_tokens:
                    if not tok.strip():
                        continue
                    resolved = resolve_known_token(
                        tok,
                        valid_faults_for_ex,
                        f"Fault ID for {ex_id}",
                        f"Mã lỗi của bài {ex_id}",
                        file_name,
                        line_no,
                        issues,
                        "unknown_fault_id",
                        "case_space_fault_id",
                        extra_hint_en=push_up_hint_en,
                        extra_hint_vi=push_up_hint_vi,
                    )
                    if resolved is not None and resolved not in clean_faults:
                        clean_faults.append(resolved)

            all_rows.append(
                CoachRow(
                    file_path=str(path),
                    file_name=file_name,
                    line=line_no,
                    coach_id=coach_id,
                    participant_id=pid,
                    condition=cond,
                    exercise_id=ex_id,
                    set_index=set_index,
                    rep_n=rep_n,
                    video_t_s=video_t_s,
                    counted=counted,
                    faults=tuple(sorted(clean_faults)),
                    note=note,
                )
            )

    # Check sequence monotonicity within each (coach_id, set_key) and restore rep_n order if scrambled
    by_coach_set: dict[tuple[str, tuple[str, str, str, int]], list[CoachRow]] = defaultdict(list)
    for r in all_rows:
        by_coach_set[(r.coach_id, r.set_key)].append(r)

    dropped_row_ids: set[int] = set()
    for (coach_id, set_key), rows in list(by_coach_set.items()):
        if any(r.rep_n == 0 for r in rows) and any(r.rep_n > 0 for r in rows):
            for zrow in [r for r in rows if r.rep_n == 0]:
                dropped_row_ids.add(id(zrow))
                issues.append(
                    ValidationIssue(
                        severity="warning",
                        code="zero_rep_with_nonempty_set",
                        file=zrow.file_name,
                        line=zrow.line,
                        message_en=(
                            f"Coach {coach_id} set {set_key} has empty-set marker rep_n=0 alongside "
                            f"rep_n>=1 rows; ignored redundant rep_n=0 row."
                        ),
                        message_vi=(
                            f"Hiệp {set_key} của HLV {coach_id} vừa có dòng đánh dấu hiệp trống rep_n=0 "
                            f"vừa có các dòng rep_n>=1; đã bỏ qua dòng rep_n=0 dư thừa."
                        ),
                    )
                )
            rows = [r for r in rows if r.rep_n > 0]
            by_coach_set[(coach_id, set_key)] = rows

        prev_rep_n = -1
        out_of_order = False
        for r in rows:
            if r.rep_n < prev_rep_n:
                out_of_order = True
                issues.append(
                    ValidationIssue(
                        severity="warning",
                        code="rep_n_out_of_order",
                        file=r.file_name,
                        line=r.line,
                        message_en=(
                            f"Coach {coach_id} rep_n={r.rep_n} appears after rep_n={prev_rep_n} "
                            f"in set {set_key}; sorted rows in this set by rep_n."
                        ),
                        message_vi=(
                            f"Nhãn của HLV {coach_id} có rep_n={r.rep_n} đứng sau dòng có "
                            f"rep_n={prev_rep_n} trong hiệp {set_key}; đã sắp xếp lại các dòng theo thứ tự rep_n."
                        ),
                    )
                )
            prev_rep_n = max(prev_rep_n, r.rep_n)

        if out_of_order:
            rows = sorted(rows, key=lambda item: (item.rep_n, item.line))
            by_coach_set[(coach_id, set_key)] = rows

        prev_t: Optional[float] = None
        for r in rows:
            if r.video_t_s is not None:
                if prev_t is not None and r.video_t_s < prev_t:
                    issues.append(
                        ValidationIssue(
                            severity="warning",
                            code="non_monotonic_video_t_s",
                            file=r.file_name,
                            line=r.line,
                            message_en=(
                                f"video_t_s={r.video_t_s}s is earlier than previous rep's "
                                f"video_t_s={prev_t}s in set {set_key}; check for a timestamp typo."
                            ),
                            message_vi=(
                                f"video_t_s={r.video_t_s}s nhỏ hơn thời điểm của rep trước ({prev_t}s) "
                                f"trong hiệp {set_key}; hãy kiểm tra xem có gõ nhầm giây không."
                            ),
                        )
                    )
                prev_t = r.video_t_s

    group_iters = {k: iter(v) for k, v in by_coach_set.items()}
    reordered_rows = [
        next(group_iters[(r.coach_id, r.set_key)])
        for r in all_rows
        if id(r) not in dropped_row_ids
    ]
    return (reordered_rows, any_valid_header)


def _parse_int_cell(
    raw: str,
    field_name: str,
    min_val: int,
    file_name: str,
    line: int,
    issues: list[ValidationIssue],
    invalid_code: str,
    invalid_msg_en: str,
    invalid_msg_vi: str,
) -> Optional[int]:
    s = raw.strip()
    try:
        val = int(s)
        if val >= min_val:
            return val
    except ValueError:
        norm = s.replace(",", ".")
        try:
            fval = float(norm)
            if not math.isnan(fval) and not math.isinf(fval) and fval == int(fval):
                ival = int(fval)
                if ival >= min_val:
                    issues.append(
                        ValidationIssue(
                            severity="warning",
                            code="coerced_float_integer",
                            file=file_name,
                            line=line,
                            message_en=(
                                f"{field_name}={raw!r} formatted as decimal; coerced to integer {ival}."
                            ),
                            message_vi=(
                                f"{field_name}={raw!r} đang ở dạng số thập phân; đã chuyển thành số nguyên {ival}."
                            ),
                        )
                    )
                    return ival
        except ValueError:
            pass

    issues.append(
        ValidationIssue(
            severity="warning",
            code=invalid_code,
            file=file_name,
            line=line,
            message_en=invalid_msg_en,
            message_vi=invalid_msg_vi,
        )
    )
    return None


def _parse_counted(
    raw: str, file_name: str, line: int, issues: list[ValidationIssue]
) -> Optional[int]:
    if raw == "1":
        return 1
    if raw == "0":
        return 0
    low = raw.lower().replace(",", ".")
    if low in {"true", "yes", "y", "1.0"}:
        issues.append(
            ValidationIssue(
                severity="warning",
                code="coerced_counted",
                file=file_name,
                line=line,
                message_en=f"counted={raw!r} coerced to 1 (use 1 or 0).",
                message_vi=f"counted={raw!r} đã được chuyển thành 1 (nên ghi 1 hoặc 0).",
            )
        )
        return 1
    if low in {"false", "no", "n", "0.0"}:
        issues.append(
            ValidationIssue(
                severity="warning",
                code="coerced_counted",
                file=file_name,
                line=line,
                message_en=f"counted={raw!r} coerced to 0 (use 1 or 0).",
                message_vi=f"counted={raw!r} đã được chuyển thành 0 (nên ghi 1 hoặc 0).",
            )
        )
        return 0
    issues.append(
        ValidationIssue(
            severity="warning",
            code="invalid_counted",
            file=file_name,
            line=line,
            message_en=f"Invalid counted value {raw!r} (expected 1 or 0); skipped row.",
            message_vi=f"Giá trị cột counted {raw!r} không hợp lệ (chỉ nhận 1 hoặc 0); đã bỏ qua dòng này.",
        )
    )
    return None


# ---------------------------------------------------------------------------
# Order-preserving time + fallback sequence matching
# ---------------------------------------------------------------------------


def _dp_time_match(
    left_times: Sequence[float],
    right_times: Sequence[float],
    tolerance_s: float,
) -> list[tuple[int, int]]:
    """Optimal order-preserving matching maximizing pairs within tolerance_s,
    then minimizing total |dt| (in integer microseconds), then preferring
    lexicographically earliest index pairs (i, j).
    """
    m = len(left_times)
    k = len(right_times)
    if m == 0 or k == 0:
        return []

    tol_us = int(round(tolerance_s * 1_000_000))
    left_us = [int(round(t * 1_000_000)) for t in left_times]
    right_us = [int(round(t * 1_000_000)) for t in right_times]

    # dp[i][j] = (matched_count, -sum_abs_err_us)
    dp: list[list[tuple[int, int]]] = [[(0, 0)] * (k + 1) for _ in range(m + 1)]
    choice: list[list[int]] = [[0] * k for _ in range(m)]
    # choice codes: 1 = match(i, j), 2 = skip_right(j), 3 = skip_left(i)

    for i in range(m - 1, -1, -1):
        li = left_us[i]
        for j in range(k - 1, -1, -1):
            best_score = dp[i + 1][j]
            best_act = 3  # skip_left

            skip_r_score = dp[i][j + 1]
            if skip_r_score >= best_score:
                best_score = skip_r_score
                best_act = 2  # skip_right

            err_us = abs(li - right_us[j])
            if err_us <= tol_us:
                sub_cnt, sub_neg_err = dp[i + 1][j + 1]
                match_score = (sub_cnt + 1, sub_neg_err - err_us)
                if match_score >= best_score:
                    best_score = match_score
                    best_act = 1  # match preferred on exact tie -> earliest (i, j)

            dp[i][j] = best_score
            choice[i][j] = best_act

    pairs: list[tuple[int, int]] = []
    i, j = 0, 0
    while i < m and j < k:
        act = choice[i][j]
        if act == 1:
            pairs.append((i, j))
            i += 1
            j += 1
        elif act == 2:
            j += 1
        else:
            i += 1
    return pairs


def match_timed_or_ordered(
    left_times: Sequence[Optional[float]],
    right_times: Sequence[Optional[float]],
    can_use_time: bool,
    tolerance_s: float,
) -> list[tuple[int, int, str, Optional[float]]]:
    """Match two ordered rep sequences using time when available, else order.

    Returns list of (left_idx, right_idx, method, abs_time_diff_s).
    """
    m = len(left_times)
    k = len(right_times)
    if m == 0 or k == 0:
        return []

    timed_left = [(idx, t) for idx, t in enumerate(left_times) if t is not None]
    timed_right = [(idx, t) for idx, t in enumerate(right_times) if t is not None]

    if not can_use_time or not timed_left or not timed_right:
        n_pair = min(m, k)
        return [(idx, idx, "order", None) for idx in range(n_pair)]

    raw_time_pairs = _dp_time_match(
        [t for _, t in timed_left],
        [t for _, t in timed_right],
        tolerance_s=tolerance_s,
    )
    anchors: list[tuple[int, int]] = [
        (timed_left[li][0], timed_right[rj][0]) for li, rj in raw_time_pairs
    ]

    if len(timed_left) == m and len(timed_right) == k:
        return [
            (li, rj, "time", abs((left_times[li] or 0.0) - (right_times[rj] or 0.0)))
            for li, rj in anchors
        ]

    # Partial timestamps: within each gap between timed anchors, pair items in order
    # whenever at least one side lacks a timestamp (never force-pair two timed items
    # that exceeded tolerance_s, and never match an untimed item across an earlier/later
    # timed neighbor's ±tolerance_s chronological window).
    tol_us = int(round(tolerance_s * 1_000_000))
    left_us: list[Optional[int]] = [
        int(round(t * 1_000_000)) if t is not None else None for t in left_times
    ]
    right_us: list[Optional[int]] = [
        int(round(t * 1_000_000)) if t is not None else None for t in right_times
    ]

    def _neighbor_bounds(seq_us: list[Optional[int]]) -> list[tuple[Optional[int], Optional[int]]]:
        n_len = len(seq_us)
        prev_t: list[Optional[int]] = [None] * n_len
        next_t: list[Optional[int]] = [None] * n_len
        last_seen: Optional[int] = None
        for idx_i in range(n_len):
            prev_t[idx_i] = last_seen
            if seq_us[idx_i] is not None:
                last_seen = seq_us[idx_i]
        next_seen: Optional[int] = None
        for idx_i in range(n_len - 1, -1, -1):
            next_t[idx_i] = next_seen
            if seq_us[idx_i] is not None:
                next_seen = seq_us[idx_i]
        bounds: list[tuple[Optional[int], Optional[int]]] = []
        for idx_i in range(n_len):
            lo_b = (prev_t[idx_i] - tol_us) if prev_t[idx_i] is not None else None
            hi_b = (next_t[idx_i] + tol_us) if next_t[idx_i] is not None else None
            if lo_b is not None and hi_b is not None and lo_b > hi_b:
                # Non-monotonic typo in input timestamps; relax conflicting bound
                bounds.append((None, None))
            else:
                bounds.append((lo_b, hi_b))
        return bounds

    left_bounds = _neighbor_bounds(left_us)
    right_bounds = _neighbor_bounds(right_us)

    def _can_order_pair(li: int, rj: int) -> bool:
        if left_us[li] is not None and right_us[rj] is not None:
            return False
        if right_us[rj] is not None:
            lo_b, hi_b = left_bounds[li]
            if lo_b is not None and right_us[rj] < lo_b:
                return False
            if hi_b is not None and right_us[rj] > hi_b:
                return False
        if left_us[li] is not None:
            lo_b, hi_b = right_bounds[rj]
            if lo_b is not None and left_us[li] < lo_b:
                return False
            if hi_b is not None and left_us[li] > hi_b:
                return False
        return True

    results: list[tuple[int, int, str, Optional[float]]] = [
        (li, rj, "time", abs((left_times[li] or 0.0) - (right_times[rj] or 0.0)))
        for li, rj in anchors
    ]
    sentinel_anchors = [(-1, -1)] + anchors + [(m, k)]
    for idx_a in range(len(sentinel_anchors) - 1):
        l_lo, r_lo = sentinel_anchors[idx_a]
        l_hi, r_hi = sentinel_anchors[idx_a + 1]
        l_idxs = list(range(l_lo + 1, l_hi))
        r_idxs = list(range(r_lo + 1, r_hi))
        gm = len(l_idxs)
        gk = len(r_idxs)
        if gm == 0 or gk == 0:
            continue
        gdp = [[0] * (gk + 1) for _ in range(gm + 1)]
        gchoice = [[0] * gk for _ in range(gm)]
        for gi in range(gm - 1, -1, -1):
            for gj in range(gk - 1, -1, -1):
                b_sc = gdp[gi + 1][gj]
                b_ac = 3
                if gdp[gi][gj + 1] >= b_sc:
                    b_sc = gdp[gi][gj + 1]
                    b_ac = 2
                if _can_order_pair(l_idxs[gi], r_idxs[gj]):
                    m_sc = gdp[gi + 1][gj + 1] + 1
                    if m_sc >= b_sc:
                        b_sc = m_sc
                        b_ac = 1
                gdp[gi][gj] = b_sc
                gchoice[gi][gj] = b_ac
        gi, gj = 0, 0
        while gi < gm and gj < gk:
            ac = gchoice[gi][gj]
            if ac == 1:
                results.append((l_idxs[gi], r_idxs[gj], "order", None))
                gi += 1
                gj += 1
            elif ac == 2:
                gj += 1
            else:
                gi += 1

    results.sort(key=lambda item: (item[0], item[1]))
    return results


def match_coach_and_app_set(
    set_log: SetLog,
    coach_id: str,
    valid_coach_reps: Sequence[CoachRow],
    tolerance_s: float,
    issues: list[ValidationIssue],
) -> list[MatchedRepPair]:
    """Pair valid coach reps (counted == 1) with app rep events for one set."""
    any_coach_time = any(c.video_t_s is not None for c in valid_coach_reps)
    all_coach_time = bool(valid_coach_reps) and all(c.video_t_s is not None for c in valid_coach_reps)

    if any_coach_time and set_log.sync_beep_t_ms is None:
        first_line = next(c.line for c in valid_coach_reps if c.video_t_s is not None)
        first_file = next(c.file_name for c in valid_coach_reps if c.video_t_s is not None)
        issues.append(
            ValidationIssue(
                severity="warning",
                code="missing_sync_beep_fallback_order",
                file=set_log.file_name,
                line=1,
                message_en=(
                    f"Coach labels ({first_file}:{first_line}) include video_t_s, but "
                    f"sync_beep_t_ms is null in {set_log.file_name!r}; falling back to order matching."
                ),
                message_vi=(
                    f"Nhãn HLV ({first_file}:{first_line}) có ghi video_t_s nhưng "
                    f"sync_beep_t_ms là null trong {set_log.file_name!r}; chuyển sang ghép theo thứ tự."
                ),
            )
        )
    elif any_coach_time and not all_coach_time and set_log.sync_beep_t_ms is not None:
        first_missing = next(c for c in valid_coach_reps if c.video_t_s is None)
        issues.append(
            ValidationIssue(
                severity="warning",
                code="partial_video_t_s",
                file=first_missing.file_name,
                line=first_missing.line,
                message_en=(
                    f"Set {set_log.set_key} mixes timed and untimed coach reps; "
                    f"timed reps matched within ±{tolerance_s}s and untimed reps matched by order in gaps."
                ),
                message_vi=(
                    f"Hiệp {set_log.set_key} có cả dòng ghi giây và dòng để trống video_t_s; "
                    f"các dòng có giây được ghép theo ±{tolerance_s}s, dòng trống ghép theo thứ tự."
                ),
            )
        )

    can_use_time = set_log.sync_beep_t_ms is not None and any_coach_time
    matched_indices = match_timed_or_ordered(
        [c.video_t_s for c in valid_coach_reps],
        [a.rel_t_s for a in set_log.reps],
        can_use_time=can_use_time,
        tolerance_s=tolerance_s,
    )

    c_to_match = {ci: (ai, method, dt) for ci, ai, method, dt in matched_indices}
    matched_app_set = {ai for _, ai, _, _ in matched_indices}

    # Build chronological combined output preserving relative sequence
    records: list[MatchedRepPair] = []
    next_app_idx = 0
    for ci, c_rep in enumerate(valid_coach_reps):
        if ci in c_to_match:
            ai, method, dt = c_to_match[ci]
            while next_app_idx < ai:
                if next_app_idx not in matched_app_set:
                    records.append(
                        MatchedRepPair(
                            set_key=set_log.set_key,
                            session_id=set_log.session_id,
                            log_file=set_log.file_name,
                            coach_id=coach_id,
                            status="phantom",
                            coach_rep=None,
                            app_rep=set_log.reps[next_app_idx],
                            match_method="unmatched",
                            time_diff_s=None,
                        )
                    )
                next_app_idx += 1
            records.append(
                MatchedRepPair(
                    set_key=set_log.set_key,
                    session_id=set_log.session_id,
                    log_file=set_log.file_name,
                    coach_id=coach_id,
                    status="matched",
                    coach_rep=c_rep,
                    app_rep=set_log.reps[ai],
                    match_method=method,
                    time_diff_s=dt,
                )
            )
            next_app_idx = ai + 1
        else:
            # Flush any unmatched app reps that demonstrably occurred before this missed coach rep
            if can_use_time and c_rep.video_t_s is not None:
                while (
                    next_app_idx < len(set_log.reps)
                    and next_app_idx not in matched_app_set
                    and (set_log.reps[next_app_idx].rel_t_s is not None)
                    and (set_log.reps[next_app_idx].rel_t_s or 0.0) < c_rep.video_t_s
                ):
                    records.append(
                        MatchedRepPair(
                            set_key=set_log.set_key,
                            session_id=set_log.session_id,
                            log_file=set_log.file_name,
                            coach_id=coach_id,
                            status="phantom",
                            coach_rep=None,
                            app_rep=set_log.reps[next_app_idx],
                            match_method="unmatched",
                            time_diff_s=None,
                        )
                    )
                    next_app_idx += 1
            records.append(
                MatchedRepPair(
                    set_key=set_log.set_key,
                    session_id=set_log.session_id,
                    log_file=set_log.file_name,
                    coach_id=coach_id,
                    status="missed",
                    coach_rep=c_rep,
                    app_rep=None,
                    match_method="unmatched",
                    time_diff_s=None,
                )
            )

    while next_app_idx < len(set_log.reps):
        if next_app_idx not in matched_app_set:
            records.append(
                MatchedRepPair(
                    set_key=set_log.set_key,
                    session_id=set_log.session_id,
                    log_file=set_log.file_name,
                    coach_id=coach_id,
                    status="phantom",
                    coach_rep=None,
                    app_rep=set_log.reps[next_app_idx],
                    match_method="unmatched",
                    time_diff_s=None,
                )
            )
        next_app_idx += 1

    return records


# ---------------------------------------------------------------------------
# Reference-coach selection & full evaluation pipeline
# ---------------------------------------------------------------------------


def select_reference_coach_per_set(
    coach_sets: dict[tuple[str, str, str, int], dict[str, list[CoachRow]]],
    primary_coach_arg: Optional[str],
    issues: list[ValidationIssue],
) -> tuple[dict[tuple[str, str, str, int], str], Optional[str]]:
    """Choose exactly one reference coach per physical set to prevent double-counting."""
    set_counts_by_coach: Counter[str] = Counter()
    for _skey, by_coach in coach_sets.items():
        for cid in by_coach:
            set_counts_by_coach[cid] += 1

    if not set_counts_by_coach:
        return ({}, None)

    ranked_coaches = sorted(
        set_counts_by_coach.keys(),
        key=lambda cid: (-set_counts_by_coach[cid], cid),
    )

    preferred = ranked_coaches[0]
    if primary_coach_arg:
        norm_arg = IdCanonicalizer._norm(primary_coach_arg)
        matched_cid = next(
            (cid for cid in ranked_coaches if IdCanonicalizer._norm(cid) == norm_arg),
            None,
        )
        if matched_cid is not None:
            preferred = matched_cid
        else:
            issues.append(
                ValidationIssue(
                    severity="warning",
                    code="unknown_primary_coach",
                    file="<cli>",
                    line=1,
                    message_en=(
                        f"--primary-coach {primary_coach_arg!r} not found among coaches "
                        f"{ranked_coaches}; using {preferred!r}."
                    ),
                    message_vi=(
                        f"--primary-coach {primary_coach_arg!r} không có trong danh sách HLV "
                        f"{ranked_coaches}; sử dụng {preferred!r}."
                    ),
                )
            )

    chosen_per_set: dict[tuple[str, str, str, int], str] = {}
    for skey, by_coach in sorted(coach_sets.items()):
        if preferred in by_coach:
            chosen_per_set[skey] = preferred
        else:
            chosen_per_set[skey] = sorted(
                by_coach.keys(), key=lambda cid: (-set_counts_by_coach[cid], cid)
            )[0]

    return (chosen_per_set, preferred)


@dataclass
class EvaluationResults:
    issues: list[ValidationIssue]
    tolerance_s: float
    cue_map_used: bool
    preferred_coach: Optional[str]
    multi_coach_set_count: int
    rep_matching_rows: list[dict[str, Any]]
    counting_accuracy_rows: list[dict[str, Any]]
    fault_detection_rows: list[dict[str, Any]]
    confusion_matrix_rows: list[dict[str, Any]]
    confusion_grids: dict[str, tuple[int, list[str], dict[tuple[str, str], int]]]
    wrong_detection_rows: list[dict[str, Any]]
    coach_agreement_rows: list[dict[str, Any]]
    unseen_time_rows: list[dict[str, Any]]
    unseen_reason_rows: list[dict[str, Any]]
    cue_mapping_summary: dict[str, Any]
    cue_correction_rows: list[dict[str, Any]]
    ai_vs_control_participant_rows: list[dict[str, Any]]
    ai_vs_control_summary_rows: list[dict[str, Any]]
    cue_candidate_rows: list[dict[str, Any]]
    satisfaction_rows: list[dict[str, Any]]
    frame_rate_rows: list[dict[str, Any]]
    fault_report_rows: list[dict[str, Any]] = field(default_factory=list)
    fault_condition_rows: list[dict[str, Any]] = field(default_factory=list)
    condition_factors: list[str] = field(default_factory=list)
    unjudged_rep_count: int = 0


def _canon_fault_id(exercise_id: str, raw: str) -> str:
    lookup = {
        re.sub(r"[\s_-]+", "", tok).casefold(): tok
        for tok in KNOWN_EXERCISES.get(exercise_id, ())
    }
    return lookup.get(re.sub(r"[\s_-]+", "", raw).casefold(), raw)


def _build_fault_reports(
    set_logs: dict[tuple[str, str, str, int], SetLog],
    session_logs: Sequence[SessionLog],
    coach_sets: dict[tuple[str, str, str, int], dict[str, list[CoachRow]]],
    all_pairs_by_set: dict[tuple[str, str, str, int], list[MatchedRepPair]],
    issues: list[ValidationIssue],
) -> list[dict[str, Any]]:
    by_file = {Path(sl.file_name).name: sl for sl in set_logs.values()}
    reported: set[tuple[tuple[str, str, str, int], str]] = set()
    for sess in session_logs:
        for ex_id, s_idx, fname, fault in sess.fault_reports:
            sl = by_file.get(Path(fname).name) or set_logs.get(
                (sess.participant_id, sess.condition, ex_id, s_idx)
            )
            if sl is None:
                issues.append(
                    ValidationIssue(
                        severity="warning",
                        code="fault_report_without_set_log",
                        file=sess.file_name,
                        line=1,
                        message_en=f"fault_reports points at {fname!r}, which is not among the set logs; skipped.",
                        message_vi=f"fault_reports trỏ tới {fname!r} nhưng không có tệp log hiệp đó; đã bỏ qua.",
                    )
                )
                continue
            reported.add((sl.set_key, _canon_fault_id(sl.exercise_id, fault)))

    keys = set(reported)
    for skey, sl in set_logs.items():
        if sl.condition == "ai":
            for rep in sl.reps:
                for f in rep.faults:
                    keys.add((skey, f))

    rows: list[dict[str, Any]] = []
    for skey, fault in sorted(keys):
        sl = set_logs[skey]
        hits = [
            p
            for p in all_pairs_by_set.get(skey, [])
            if p.status == "matched" and p.app_rep and p.coach_rep and fault in p.app_rep.faults
        ]
        confirmed = sum(1 for p in hits if fault in p.coach_rep.faults)
        absent = len(hits) - confirmed
        if skey not in coach_sets:
            verdict = "unlabelled"
        elif not hits:
            verdict = "no_matched_rep"
        elif confirmed == 0:
            verdict = "app_false_alarm"
        elif absent == 0:
            verdict = "coach_confirmed"
        else:
            verdict = "mixed"
        pid, cond, ex_id, s_idx = skey
        rows.append(
            {
                "participant_id": pid,
                "condition": cond,
                "exercise_id": ex_id,
                "set_index": s_idx,
                "log_file": sl.file_name,
                "fault": fault,
                "reported": 1 if (skey, fault) in reported else 0,
                "app_matched_reps_with_fault": len(hits),
                "coach_confirmed": confirmed,
                "coach_absent": absent,
                "verdict": verdict,
            }
        )
    return rows


def evaluate_all(
    set_logs: dict[tuple[str, str, str, int], SetLog],
    session_logs: Sequence[SessionLog],
    coach_rows: Sequence[CoachRow],
    issues: list[ValidationIssue],
    tolerance_s: float = DEFAULT_TIME_TOLERANCE_S,
    primary_coach_arg: Optional[str] = None,
    cue_map_used: bool = False,
    conditions: Optional[dict[tuple[str, str, str, int], dict[str, str]]] = None,
    condition_factors: Sequence[str] = (),
) -> EvaluationResults:
    if not set_logs and not session_logs and coach_rows:
        issues.insert(
            0,
            ValidationIssue(
                severity="error",
                code="no_valid_logs",
                file="<logs_dir>",
                line=1,
                message_en=(
                    "No valid app set or session JSON logs were found in --logs; "
                    "only coach-only metrics could be computed."
                ),
                message_vi=(
                    "Không tìm thấy tệp JSON log hợp lệ nào trong thư mục --logs; "
                    "chỉ tính được các chỉ số nội bộ từ nhãn HLV."
                ),
            ),
        )

    # Group coach rows by set_key -> coach_id -> list[CoachRow]
    coach_sets: dict[tuple[str, str, str, int], dict[str, list[CoachRow]]] = defaultdict(
        lambda: defaultdict(list)
    )
    for r in coach_rows:
        coach_sets[r.set_key][r.coach_id].append(r)

    # Cross-check set coverage: labels without log & log without labels
    for skey in sorted(coach_sets.keys()):
        if skey not in set_logs:
            first_coach = sorted(coach_sets[skey].keys())[0]
            first_row = coach_sets[skey][first_coach][0]
            pid, cond, ex_id, s_idx = skey
            issues.append(
                ValidationIssue(
                    severity="warning",
                    code="labels_without_log",
                    file=first_row.file_name,
                    line=first_row.line,
                    message_en=(
                        f"Set ({pid}, {cond}, {ex_id}, set {s_idx}) has coach labels "
                        f"but no matching app set log."
                    ),
                    message_vi=(
                        f"Hiệp ({pid}, {cond}, {ex_id}, hiệp {s_idx}) có nhãn HLV "
                        f"nhưng không tìm thấy tệp log ứng dụng tương ứng."
                    ),
                )
            )

    for skey in sorted(set_logs.keys()):
        if skey not in coach_sets:
            sl = set_logs[skey]
            pid, cond, ex_id, s_idx = skey
            issues.append(
                ValidationIssue(
                    severity="warning",
                    code="log_without_labels",
                    file=sl.file_name,
                    line=1,
                    message_en=(
                        f"App set log ({pid}, {cond}, {ex_id}, set {s_idx}) has no coach labels."
                    ),
                    message_vi=(
                        f"Tệp log ({pid}, {cond}, {ex_id}, hiệp {s_idx}) chưa có nhãn của HLV."
                    ),
                )
            )

    chosen_coach_per_set, preferred_coach = select_reference_coach_per_set(
        coach_sets, primary_coach_arg, issues
    )
    multi_coach_set_count = sum(1 for by_c in coach_sets.values() if len(by_c) >= 2)

    # ------------------------------------------------------------------
    # 1 & 2. Rep matching & Counting accuracy (over sets with BOTH log and labels)
    # ------------------------------------------------------------------
    paired_sets = sorted(set(set_logs.keys()) & set(coach_sets.keys()))
    all_pairs_by_set: dict[tuple[str, str, str, int], list[MatchedRepPair]] = {}
    rep_matching_rows: list[dict[str, Any]] = []

    for skey in paired_sets:
        sl = set_logs[skey]
        ref_cid = chosen_coach_per_set[skey]
        c_rows = coach_sets[skey][ref_cid]
        valid_c_rows = [r for r in c_rows if r.counted == 1]
        pairs = match_coach_and_app_set(sl, ref_cid, valid_c_rows, tolerance_s, issues)
        all_pairs_by_set[skey] = pairs

        for p in pairs:
            pid, cond, ex_id, s_idx = p.set_key
            rep_matching_rows.append(
                {
                    "participant_id": pid,
                    "condition": cond,
                    "exercise_id": ex_id,
                    "set_index": s_idx,
                    "session_id": p.session_id,
                    "log_file": p.log_file,
                    "coach_id": p.coach_id,
                    "status": p.status,
                    "match_method": p.match_method,
                    "coach_rep_n": p.coach_rep.rep_n if p.coach_rep else "",
                    "app_rep_n": p.app_rep.n if p.app_rep else "",
                    "video_t_s": fmt_float(p.coach_rep.video_t_s, 3) if p.coach_rep else "",
                    "app_rel_t_s": fmt_float(p.app_rep.rel_t_s, 3) if p.app_rep else "",
                    "app_t_ms": p.app_rep.t_ms if p.app_rep else "",
                    "time_diff_s": fmt_float(p.time_diff_s, 3),
                    "coach_faults": format_fault_set(p.coach_rep.faults) if p.coach_rep else "",
                    "app_faults": format_fault_set(p.app_rep.faults) if p.app_rep else "",
                    "coach_note": p.coach_rep.note if p.coach_rep else "",
                }
            )

    counting_accuracy_rows = _build_counting_accuracy(
        paired_sets, set_logs, coach_sets, chosen_coach_per_set, all_pairs_by_set
    )

    # ------------------------------------------------------------------
    # 3 & 4. Fault detection, Wilson CIs, Confusion matrices, Wrong detections
    # ------------------------------------------------------------------
    (
        fault_detection_rows,
        confusion_matrix_rows,
        confusion_grids,
        wrong_detection_rows,
    ) = _build_fault_detection_and_wrong(paired_sets, all_pairs_by_set)

    # ------------------------------------------------------------------
    # 5. Agreement between coaches (Cohen's kappa)
    # ------------------------------------------------------------------
    coach_agreement_rows = _build_coach_agreement(coach_sets, tolerance_s)

    # ------------------------------------------------------------------
    # 6. Unseen time & reason breakdown
    # ------------------------------------------------------------------
    unseen_time_rows, unseen_reason_rows = _build_unseen_time(set_logs)

    # ------------------------------------------------------------------
    # 7a & 7c. Correction after a cue + Success/Failure candidate sets
    # ------------------------------------------------------------------
    cue_mapping_summary, cue_correction_rows, cue_candidate_rows = _build_cue_analysis(
        set_logs, coach_sets, chosen_coach_per_set, all_pairs_by_set
    )

    # ------------------------------------------------------------------
    # 7b. With vs Without feedback (coach-labelled fault rate in ai vs control)
    # ------------------------------------------------------------------
    ai_vs_control_participant_rows, ai_vs_control_summary_rows = _build_ai_vs_control(
        coach_sets, chosen_coach_per_set, issues
    )

    # ------------------------------------------------------------------
    # 7d. Satisfaction from session files
    # ------------------------------------------------------------------
    satisfaction_rows = _build_satisfaction(session_logs)

    # ------------------------------------------------------------------
    # 8. Frame rate summary
    # ------------------------------------------------------------------
    frame_rate_rows = _build_frame_rate(set_logs)

    fault_report_rows = _build_fault_reports(
        set_logs, session_logs, coach_sets, all_pairs_by_set, issues
    )

    fault_condition_rows: list[dict[str, Any]] = []
    if conditions is not None:
        fault_condition_rows = _build_fault_detection_by_condition(
            paired_sets, all_pairs_by_set, conditions, condition_factors, issues
        )

    return EvaluationResults(
        fault_report_rows=fault_report_rows,
        fault_condition_rows=fault_condition_rows,
        condition_factors=list(condition_factors),
        unjudged_rep_count=sum(
            1 for sl in set_logs.values() for r in sl.reps if not r.form_judged
        ),
        issues=issues,
        tolerance_s=tolerance_s,
        cue_map_used=cue_map_used,
        preferred_coach=preferred_coach,
        multi_coach_set_count=multi_coach_set_count,
        rep_matching_rows=rep_matching_rows,
        counting_accuracy_rows=counting_accuracy_rows,
        fault_detection_rows=fault_detection_rows,
        confusion_matrix_rows=confusion_matrix_rows,
        confusion_grids=confusion_grids,
        wrong_detection_rows=wrong_detection_rows,
        coach_agreement_rows=coach_agreement_rows,
        unseen_time_rows=unseen_time_rows,
        unseen_reason_rows=unseen_reason_rows,
        cue_mapping_summary=cue_mapping_summary,
        cue_correction_rows=cue_correction_rows,
        ai_vs_control_participant_rows=ai_vs_control_participant_rows,
        ai_vs_control_summary_rows=ai_vs_control_summary_rows,
        cue_candidate_rows=cue_candidate_rows,
        satisfaction_rows=satisfaction_rows,
        frame_rate_rows=frame_rate_rows,
    )


def _build_counting_accuracy(
    paired_sets: Sequence[tuple[str, str, str, int]],
    set_logs: dict[tuple[str, str, str, int], SetLog],
    coach_sets: dict[tuple[str, str, str, int], dict[str, list[CoachRow]]],
    chosen_coach_per_set: dict[tuple[str, str, str, int], str],
    all_pairs_by_set: dict[tuple[str, str, str, int], list[MatchedRepPair]],
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    totals = {
        "n_sets": 0,
        "coach_valid_reps": 0,
        "coach_uncounted_attempts": 0,
        "app_reps": 0,
        "matched": 0,
        "missed": 0,
        "phantom": 0,
    }

    for ex_id in KNOWN_EXERCISES:
        ex_sets = [skey for skey in paired_sets if skey[2] == ex_id]
        n_sets = len(ex_sets)
        c_valid = 0
        c_uncounted = 0
        a_reps = 0
        matched = 0
        missed = 0
        phantom = 0
        for skey in ex_sets:
            ref_cid = chosen_coach_per_set[skey]
            c_list = coach_sets[skey][ref_cid]
            c_valid += sum(1 for r in c_list if r.counted == 1)
            c_uncounted += sum(1 for r in c_list if r.counted == 0 and r.rep_n > 0)
            a_reps += len(set_logs[skey].reps)
            for p in all_pairs_by_set[skey]:
                if p.status == "matched":
                    matched += 1
                elif p.status == "missed":
                    missed += 1
                elif p.status == "phantom":
                    phantom += 1

        totals["n_sets"] += n_sets
        totals["coach_valid_reps"] += c_valid
        totals["coach_uncounted_attempts"] += c_uncounted
        totals["app_reps"] += a_reps
        totals["matched"] += matched
        totals["missed"] += missed
        totals["phantom"] += phantom

        rows.append(
            {
                "exercise_id": ex_id,
                "n_sets": n_sets,
                "coach_valid_reps": c_valid,
                "coach_uncounted_attempts": c_uncounted,
                "app_reps": a_reps,
                "matched": matched,
                "missed": missed,
                "phantom": phantom,
                "recall_count_rate": fmt_float(matched / c_valid if c_valid > 0 else None),
                "miss_rate": fmt_float(missed / c_valid if c_valid > 0 else None),
                "phantom_rate": fmt_float(phantom / a_reps if a_reps > 0 else None),
            }
        )

    c_tot = totals["coach_valid_reps"]
    a_tot = totals["app_reps"]
    rows.append(
        {
            "exercise_id": "overall",
            "n_sets": totals["n_sets"],
            "coach_valid_reps": c_tot,
            "coach_uncounted_attempts": totals["coach_uncounted_attempts"],
            "app_reps": a_tot,
            "matched": totals["matched"],
            "missed": totals["missed"],
            "phantom": totals["phantom"],
            "recall_count_rate": fmt_float(totals["matched"] / c_tot if c_tot > 0 else None),
            "miss_rate": fmt_float(totals["missed"] / c_tot if c_tot > 0 else None),
            "phantom_rate": fmt_float(totals["phantom"] / a_tot if a_tot > 0 else None),
        }
    )
    return rows


def _judged_matched_pairs(
    set_keys: Sequence[tuple[str, str, str, int]],
    all_pairs_by_set: dict[tuple[str, str, str, int], list[MatchedRepPair]],
) -> tuple[list[MatchedRepPair], int]:
    judged: list[MatchedRepPair] = []
    unjudged = 0
    for skey in set_keys:
        for p in all_pairs_by_set.get(skey, ()):
            if p.status != "matched" or p.coach_rep is None or p.app_rep is None:
                continue
            if p.app_rep.form_judged:
                judged.append(p)
            else:
                unjudged += 1
    return judged, unjudged


def _fault_flags(p: MatchedRepPair, fault_id: str) -> tuple[bool, bool]:
    assert p.coach_rep is not None and p.app_rep is not None
    if fault_id == "ANY_FAULT":
        return len(p.coach_rep.faults) > 0, len(p.app_rep.faults) > 0
    return fault_id in p.coach_rep.faults, fault_id in p.app_rep.faults


def _confusion_counts(
    pairs: Sequence[MatchedRepPair], fault_id: str
) -> tuple[int, int, int, int]:
    tp = fp = fn = tn = 0
    for p in pairs:
        c_has, a_has = _fault_flags(p, fault_id)
        if c_has and a_has:
            tp += 1
        elif a_has:
            fp += 1
        elif c_has:
            fn += 1
        else:
            tn += 1
    return tp, fp, fn, tn


def _percentile(sorted_vals: Sequence[float], q: float) -> float:
    pos = q * (len(sorted_vals) - 1)
    lo = math.floor(pos)
    hi = min(lo + 1, len(sorted_vals) - 1)
    return sorted_vals[lo] + (sorted_vals[hi] - sorted_vals[lo]) * (pos - lo)


def _participant_bootstrap_ci(
    pairs: Sequence[MatchedRepPair],
    fault_id: str,
    n_resamples: int = BOOTSTRAP_RESAMPLES,
) -> tuple[Optional[float], Optional[float], Optional[float], Optional[float]]:
    by_pid: dict[str, list[int]] = {}
    for p in pairs:
        rec = by_pid.setdefault(p.set_key[0], [0, 0, 0])
        c_has, a_has = _fault_flags(p, fault_id)
        if c_has and a_has:
            rec[0] += 1
        elif a_has:
            rec[1] += 1
        elif c_has:
            rec[2] += 1
    counts = [by_pid[pid] for pid in sorted(by_pid)]
    n = len(counts)
    if n < 2:
        return None, None, None, None
    rng = random.Random(BOOTSTRAP_SEED)
    precs: list[float] = []
    recs: list[float] = []
    for _ in range(n_resamples):
        tp = fp = fn = 0
        for _ in range(n):
            c = counts[rng.randrange(n)]
            tp += c[0]
            fp += c[1]
            fn += c[2]
        if tp + fp > 0:
            precs.append(tp / (tp + fp))
        if tp + fn > 0:
            recs.append(tp / (tp + fn))
    precs.sort()
    recs.sort()
    p_lo = _percentile(precs, 0.025) if precs else None
    p_hi = _percentile(precs, 0.975) if precs else None
    r_lo = _percentile(recs, 0.025) if recs else None
    r_hi = _percentile(recs, 0.975) if recs else None
    return p_lo, p_hi, r_lo, r_hi


def _build_fault_detection_by_condition(
    paired_sets: Sequence[tuple[str, str, str, int]],
    all_pairs_by_set: dict[tuple[str, str, str, int], list[MatchedRepPair]],
    conditions: dict[tuple[str, str, str, int], dict[str, str]],
    factors: Sequence[str],
    issues: list[ValidationIssue],
) -> list[dict[str, Any]]:
    missing = [s for s in paired_sets if s not in conditions]
    if missing:
        sample = ", ".join(f"{s[0]}/{s[1]}/{s[2]}/{s[3]}" for s in missing[:5])
        issues.append(
            ValidationIssue(
                severity="warning",
                code="set_without_conditions",
                file="session_conditions.csv",
                line=1,
                message_en=(
                    f"{len(missing)} labelled set(s) have no row in session_conditions.csv "
                    f"(e.g. {sample}); they are left out of the per-condition table."
                ),
                message_vi=(
                    f"{len(missing)} hiệp đã gán nhãn chưa có dòng trong session_conditions.csv "
                    f"(ví dụ {sample}); không đưa vào bảng theo điều kiện."
                ),
            )
        )
    rows: list[dict[str, Any]] = []
    for factor in factors:
        levels = sorted(
            {conditions[s][factor] for s in paired_sets if factor in conditions.get(s, {})}
        )
        for level in levels:
            level_sets = [s for s in paired_sets if conditions.get(s, {}).get(factor) == level]
            for ex_id, canonical_faults in KNOWN_EXERCISES.items():
                ex_sets = [s for s in level_sets if s[2] == ex_id]
                pairs, _ = _judged_matched_pairs(ex_sets, all_pairs_by_set)
                if not pairs:
                    continue
                n_participants = len({p.set_key[0] for p in pairs})
                for fault_id in list(canonical_faults) + ["ANY_FAULT"]:
                    tp, fp, fn, tn = _confusion_counts(pairs, fault_id)
                    prec = tp / (tp + fp) if tp + fp > 0 else None
                    prec_lo, prec_hi = wilson_ci(tp, tp + fp)
                    rec = tp / (tp + fn) if tp + fn > 0 else None
                    rec_lo, rec_hi = wilson_ci(tp, tp + fn)
                    rows.append(
                        {
                            "factor": factor,
                            "level": level,
                            "exercise_id": ex_id,
                            "fault_id": fault_id,
                            "n_participants": n_participants,
                            "n_sets": len(ex_sets),
                            "n_matched_reps": len(pairs),
                            "tp": tp,
                            "fp": fp,
                            "fn": fn,
                            "tn": tn,
                            "n_app_positive": tp + fp,
                            "precision": fmt_float(prec),
                            "precision_ci95_low": fmt_float(prec_lo),
                            "precision_ci95_high": fmt_float(prec_hi),
                            "n_coach_positive": tp + fn,
                            "recall": fmt_float(rec),
                            "recall_ci95_low": fmt_float(rec_lo),
                            "recall_ci95_high": fmt_float(rec_hi),
                        }
                    )
    return rows


def _build_fault_detection_and_wrong(
    paired_sets: Sequence[tuple[str, str, str, int]],
    all_pairs_by_set: dict[tuple[str, str, str, int], list[MatchedRepPair]],
) -> tuple[
    list[dict[str, Any]],
    list[dict[str, Any]],
    dict[str, tuple[int, list[str], dict[tuple[str, str], int]]],
    list[dict[str, Any]],
]:
    fault_rows: list[dict[str, Any]] = []
    cm_rows: list[dict[str, Any]] = []
    cm_grids: dict[str, tuple[int, list[str], dict[tuple[str, str], int]]] = {}
    wrong_rows: list[dict[str, Any]] = []

    for ex_id, canonical_faults in KNOWN_EXERCISES.items():
        ex_sets = [skey for skey in paired_sets if skey[2] == ex_id]
        matched_pairs, n_unjudged = _judged_matched_pairs(ex_sets, all_pairs_by_set)
        n_matched = len(matched_pairs)
        n_participants = len({p.set_key[0] for p in matched_pairs})
        n_sets_with_matches = sum(
            1
            for skey in ex_sets
            if any(p.status == "matched" for p in all_pairs_by_set[skey])
        )

        # Per-fault binary confusion & Wilson CIs
        for fault_id in list(canonical_faults) + ["ANY_FAULT"]:
            tp, fp, fn, tn = _confusion_counts(matched_pairs, fault_id)
            boot_p_lo, boot_p_hi, boot_r_lo, boot_r_hi = _participant_bootstrap_ci(
                matched_pairs, fault_id
            )

            n_app_pos = tp + fp
            n_coach_pos = tp + fn
            n_coach_neg = fp + tn
            prec = tp / n_app_pos if n_app_pos > 0 else None
            prec_lo, prec_hi = wilson_ci(tp, n_app_pos)
            rec = tp / n_coach_pos if n_coach_pos > 0 else None
            rec_lo, rec_hi = wilson_ci(tp, n_coach_pos)
            fp_per_rep = fp / n_matched if n_matched > 0 else None
            fpr = fp / n_coach_neg if n_coach_neg > 0 else None
            fpr_lo, fpr_hi = wilson_ci(fp, n_coach_neg)

            fault_rows.append(
                {
                    "exercise_id": ex_id,
                    "fault_id": fault_id,
                    "n_sets": n_sets_with_matches,
                    "n_matched_reps": n_matched,
                    "tp": tp,
                    "fp": fp,
                    "fn": fn,
                    "tn": tn,
                    "n_app_positive": n_app_pos,
                    "precision": fmt_float(prec),
                    "precision_ci95_low": fmt_float(prec_lo),
                    "precision_ci95_high": fmt_float(prec_hi),
                    "n_coach_positive": n_coach_pos,
                    "recall": fmt_float(rec),
                    "recall_ci95_low": fmt_float(rec_lo),
                    "recall_ci95_high": fmt_float(rec_hi),
                    "n_coach_negative": n_coach_neg,
                    "false_positive_rate": fmt_float(fpr),
                    "false_positive_rate_ci95_low": fmt_float(fpr_lo),
                    "false_positive_rate_ci95_high": fmt_float(fpr_hi),
                    "fp_per_matched_rep": fmt_float(fp_per_rep),
                    "n_participants": n_participants,
                    "n_unjudged_reps": n_unjudged,
                    "precision_boot95_low": fmt_float(boot_p_lo),
                    "precision_boot95_high": fmt_float(boot_p_hi),
                    "recall_boot95_low": fmt_float(boot_r_lo),
                    "recall_boot95_high": fmt_float(boot_r_hi),
                }
            )

        # Confusion matrix per exercise over exact label-sets:
        # Always includes "clean" + every canonical fault ID, plus any observed multi-fault combo.
        base_labels = ["clean"] + list(canonical_faults)
        extra_combos: set[str] = set()
        cell_counts: Counter[tuple[str, str]] = Counter()
        for p in matched_pairs:
            assert p.coach_rep is not None and p.app_rep is not None
            c_lbl = format_fault_label_display(p.coach_rep.faults)
            a_lbl = format_fault_label_display(p.app_rep.faults)
            if c_lbl not in base_labels:
                extra_combos.add(c_lbl)
            if a_lbl not in base_labels:
                extra_combos.add(a_lbl)
            cell_counts[(c_lbl, a_lbl)] += 1

        axis_labels = base_labels + sorted(extra_combos)
        grid_dict: dict[tuple[str, str], int] = {}
        for c_lbl in axis_labels:
            for a_lbl in axis_labels:
                cnt = cell_counts[(c_lbl, a_lbl)]
                grid_dict[(c_lbl, a_lbl)] = cnt
                cm_rows.append(
                    {
                        "exercise_id": ex_id,
                        "n_matched_reps": n_matched,
                        "coach_label": c_lbl,
                        "app_label": a_lbl,
                        "count": cnt,
                    }
                )
        cm_grids[ex_id] = (n_matched, axis_labels, grid_dict)

        # Wrong detections list
        for p in matched_pairs:
            assert p.coach_rep is not None and p.app_rep is not None
            c_set = set(p.coach_rep.faults)
            a_set = set(p.app_rep.faults)
            if c_set != a_set:
                pid, cond, _, s_idx = p.set_key
                fps_list = sorted(a_set - c_set)
                fns_list = sorted(c_set - a_set)
                wrong_rows.append(
                    {
                        "participant_id": pid,
                        "condition": cond,
                        "exercise_id": ex_id,
                        "set_index": s_idx,
                        "session_id": p.session_id,
                        "log_file": p.log_file,
                        "coach_id": p.coach_id,
                        "coach_rep_n": p.coach_rep.rep_n,
                        "app_rep_n": p.app_rep.n,
                        "video_t_s": fmt_float(p.coach_rep.video_t_s, 3),
                        "app_rel_t_s": fmt_float(p.app_rep.rel_t_s, 3),
                        "app_t_ms": p.app_rep.t_ms,
                        "coach_faults": format_fault_label_display(c_set),
                        "app_faults": format_fault_label_display(a_set),
                        "false_positives": ";".join(fps_list),
                        "false_negatives": ";".join(fns_list),
                        "coach_note": p.coach_rep.note,
                    }
                )

    return (fault_rows, cm_rows, cm_grids, wrong_rows)


def _build_coach_agreement(
    coach_sets: dict[tuple[str, str, str, int], dict[str, list[CoachRow]]],
    tolerance_s: float,
) -> list[dict[str, Any]]:
    # Group shared sets by ordered coach pair (coach_a < coach_b) and exercise_id
    pair_ex_sets: dict[tuple[str, str, str], list[tuple[str, str, str, int]]] = defaultdict(list)
    for skey, by_coach in sorted(coach_sets.items()):
        coaches = sorted(by_coach.keys())
        if len(coaches) < 2:
            continue
        ex_id = skey[2]
        for i in range(len(coaches)):
            for j in range(i + 1, len(coaches)):
                pair_ex_sets[(coaches[i], coaches[j], ex_id)].append(skey)

    rows: list[dict[str, Any]] = []
    for (coach_a, coach_b, ex_id), skeys in sorted(pair_ex_sets.items()):
        matched_coach_reps: list[tuple[CoachRow, CoachRow]] = []
        a_only_valid = 0
        b_only_valid = 0
        for skey in skeys:
            attempts_a = [r for r in coach_sets[skey][coach_a] if r.rep_n > 0]
            attempts_b = [r for r in coach_sets[skey][coach_b] if r.rep_n > 0]
            valid_a = [r for r in attempts_a if r.counted == 1]
            valid_b = [r for r in attempts_b if r.counted == 1]
            can_time = any(r.video_t_s is not None for r in valid_a) and any(
                r.video_t_s is not None for r in valid_b
            )
            if (
                not can_time
                and attempts_a
                and [r.rep_n for r in attempts_a] == [r.rep_n for r in attempts_b]
            ):
                for ra, rb in zip(attempts_a, attempts_b):
                    if ra.counted == 1 and rb.counted == 1:
                        matched_coach_reps.append((ra, rb))
                    elif ra.counted == 1:
                        a_only_valid += 1
                    elif rb.counted == 1:
                        b_only_valid += 1
            else:
                m_idx = match_timed_or_ordered(
                    [r.video_t_s for r in valid_a],
                    [r.video_t_s for r in valid_b],
                    can_use_time=can_time,
                    tolerance_s=tolerance_s,
                )
                for ia, ib, _method, _dt in m_idx:
                    matched_coach_reps.append((valid_a[ia], valid_b[ib]))
                a_only_valid += len(valid_a) - len(m_idx)
                b_only_valid += len(valid_b) - len(m_idx)

        n_matched = len(matched_coach_reps)
        for fault_id in list(KNOWN_EXERCISES[ex_id]) + ["ANY_FAULT"]:
            both_pos = a_only = b_only = both_neg = 0
            for ra, rb in matched_coach_reps:
                if fault_id == "ANY_FAULT":
                    ha = len(ra.faults) > 0
                    hb = len(rb.faults) > 0
                else:
                    ha = fault_id in ra.faults
                    hb = fault_id in rb.faults
                if ha and hb:
                    both_pos += 1
                elif ha and (not hb):
                    a_only += 1
                elif (not ha) and hb:
                    b_only += 1
                else:
                    both_neg += 1

            p_o, kappa, note = cohen_kappa_binary(both_pos, a_only, b_only, both_neg)
            rows.append(
                {
                    "coach_a": coach_a,
                    "coach_b": coach_b,
                    "exercise_id": ex_id,
                    "fault_id": fault_id,
                    "n_shared_sets": len(skeys),
                    "n_matched_valid_reps": n_matched,
                    "coach_a_unmatched_valid_reps": a_only_valid,
                    "coach_b_unmatched_valid_reps": b_only_valid,
                    "both_positive": both_pos,
                    "coach_a_only_positive": a_only,
                    "coach_b_only_positive": b_only,
                    "both_negative": both_neg,
                    "percent_agreement": fmt_float(p_o),
                    "cohen_kappa": fmt_float(kappa),
                    "kappa_note": note,
                }
            )

    return rows


def _build_unseen_time(
    set_logs: dict[tuple[str, str, str, int], SetLog],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    time_rows: list[dict[str, Any]] = []
    reason_rows: list[dict[str, Any]] = []

    tot_sets = 0
    tot_active = 0
    tot_unseen = 0
    tot_paused = 0

    for ex_id in KNOWN_EXERCISES:
        ex_logs = [sl for sl in set_logs.values() if sl.exercise_id == ex_id]
        n_sets = len(ex_logs)
        act_ms = sum(sl.active_ms for sl in ex_logs)
        uns_ms = sum(sl.unseen_ms for sl in ex_logs)
        pau_ms = sum(sl.paused_ms for sl in ex_logs)

        tot_sets += n_sets
        tot_active += act_ms
        tot_unseen += uns_ms
        tot_paused += pau_ms

        time_rows.append(
            {
                "exercise_id": ex_id,
                "n_sets": n_sets,
                "active_ms": act_ms,
                "unseen_ms": uns_ms,
                "unseen_over_active_ratio": fmt_float(uns_ms / act_ms if act_ms > 0 else None),
                "paused_ms": pau_ms,
            }
        )

        # Breakdown by (phase, reason) from events
        reason_stats: dict[tuple[str, str], dict[str, Any]] = defaultdict(
            lambda: {"sets": set(), "events": 0, "duration_ms": 0}
        )
        phase_totals: Counter[str] = Counter()
        for sl in ex_logs:
            for iv in sl.unseen_intervals:
                st = reason_stats[(iv.phase, iv.reason)]
                st["sets"].add(sl.file_name)
                st["events"] += 1
                st["duration_ms"] += iv.effective_ms
                phase_totals[iv.phase] += iv.effective_ms

        for (phase, reason), st in sorted(
            reason_stats.items(), key=lambda kv: (kv[0][0], -kv[1]["duration_ms"], kv[0][1])
        ):
            dur = st["duration_ms"]
            p_tot = phase_totals[phase]
            reason_rows.append(
                {
                    "exercise_id": ex_id,
                    "phase": phase,
                    "reason": reason,
                    "n_sets_with_reason": len(st["sets"]),
                    "n_total_sets": n_sets,
                    "event_count": st["events"],
                    "duration_ms": dur,
                    "share_of_active_ms": fmt_float(
                        dur / act_ms if (phase == "active" and act_ms > 0) else None
                    ),
                    "share_of_phase_unseen_ms": fmt_float(dur / p_tot if p_tot > 0 else None),
                }
            )

    time_rows.append(
        {
            "exercise_id": "overall",
            "n_sets": tot_sets,
            "active_ms": tot_active,
            "unseen_ms": tot_unseen,
            "unseen_over_active_ratio": fmt_float(
                tot_unseen / tot_active if tot_active > 0 else None
            ),
            "paused_ms": tot_paused,
        }
    )

    # Overall reason breakdown across all exercises
    overall_reason_stats: dict[tuple[str, str], dict[str, Any]] = defaultdict(
        lambda: {"sets": set(), "events": 0, "duration_ms": 0}
    )
    overall_phase_totals: Counter[str] = Counter()
    for sl in set_logs.values():
        for iv in sl.unseen_intervals:
            st = overall_reason_stats[(iv.phase, iv.reason)]
            st["sets"].add(sl.file_name)
            st["events"] += 1
            st["duration_ms"] += iv.effective_ms
            overall_phase_totals[iv.phase] += iv.effective_ms

    for (phase, reason), st in sorted(
        overall_reason_stats.items(), key=lambda kv: (kv[0][0], -kv[1]["duration_ms"], kv[0][1])
    ):
        dur = st["duration_ms"]
        p_tot = overall_phase_totals[phase]
        reason_rows.append(
            {
                "exercise_id": "overall",
                "phase": phase,
                "reason": reason,
                "n_sets_with_reason": len(st["sets"]),
                "n_total_sets": tot_sets,
                "event_count": st["events"],
                "duration_ms": dur,
                "share_of_active_ms": fmt_float(
                    dur / tot_active if (phase == "active" and tot_active > 0) else None
                ),
                "share_of_phase_unseen_ms": fmt_float(dur / p_tot if p_tot > 0 else None),
            }
        )

    return (time_rows, reason_rows)


def _cue_effective_cutoff_t_ms(cue: AppCue, set_log: SetLog, fault_id: str) -> int:
    """Return the timestamp cutoff after which subsequent reps begin for a fault cue.

    For post-rep cues, feedforward '*_reminder' cues, and hold-break cues, this is cue.t_ms.
    For live mid-rep cues spoken while a fault_start..fault_end span for fault_id is open on
    the currently in-progress rep, that in-progress rep already recorded fault_id before the
    cue played and triggered the cue; advancing the cutoff to that rep's completion t_ms
    ensures 'next 1' and 'next 2' evaluate the actual subsequent reps after the cue.
    """
    if cue.key.strip().lower().endswith("_reminder"):
        return cue.t_ms
    future_reps = [r for r in set_log.reps if r.t_ms > cue.t_ms]
    if not future_reps:
        return cue.t_ms
    in_prog_rep = future_reps[0]
    prev_rep_t_ms = max((r.t_ms for r in set_log.reps if r.t_ms <= cue.t_ms), default=-1)
    for span in set_log.live_fault_spans:
        if span.fault_id != fault_id:
            continue
        if (
            span.start_ms > prev_rep_t_ms
            and span.start_ms <= cue.t_ms
            and span.end_ms >= in_prog_rep.t_ms
        ):
            return in_prog_rep.t_ms
    return cue.t_ms


def _subsequent_coach_reps_after_cue(
    cue: AppCue,
    set_log: SetLog,
    valid_coach_reps: Sequence[CoachRow],
    set_pairs: Sequence[MatchedRepPair],
    cutoff_t_ms: Optional[int] = None,
) -> list[CoachRow]:
    """Identify coach-valid reps occurring strictly after cutoff_t_ms (defaults to cue.t_ms).

    Uses matched app->coach anchors so post-rep cues (e.g. 150 ms after rep 2) and live mid-rep
    cues never grab the triggering coach rep even if the coach's video_t_s had human reaction lag.
    """
    eff_t_ms = cue.t_ms if cutoff_t_ms is None else cutoff_t_ms
    eff_rel_t_s = (
        (eff_t_ms - set_log.sync_beep_t_ms) / 1000.0
        if set_log.sync_beep_t_ms is not None
        else cue.rel_t_s
    )
    coach_obj_to_idx = {id(cr): idx for idx, cr in enumerate(valid_coach_reps)}
    last_prior_coach_idx = -1
    for p in set_pairs:
        if p.status == "matched" and p.app_rep is not None and p.coach_rep is not None:
            if p.app_rep.t_ms <= eff_t_ms:
                c_idx = coach_obj_to_idx.get(id(p.coach_rep), -1)
                if c_idx > last_prior_coach_idx:
                    last_prior_coach_idx = c_idx

    matched_coach_ids = {
        id(p.coach_rep)
        for p in set_pairs
        if p.status == "matched" and p.coach_rep is not None
    }

    first_future_matched_idx = next(
        (
            idx
            for idx in range(last_prior_coach_idx + 1, len(valid_coach_reps))
            if id(valid_coach_reps[idx]) in matched_coach_ids
        ),
        len(valid_coach_reps),
    )
    cutoff_unmatched_idx = last_prior_coach_idx
    if eff_rel_t_s is not None:
        saw_future_timed = False
        for idx in range(last_prior_coach_idx + 1, first_future_matched_idx):
            cr = valid_coach_reps[idx]
            if cr.video_t_s is not None:
                if cr.video_t_s <= eff_rel_t_s:
                    cutoff_unmatched_idx = idx
                else:
                    saw_future_timed = True
                    break
        if (
            not saw_future_timed
            and first_future_matched_idx < len(valid_coach_reps)
            and valid_coach_reps[first_future_matched_idx].video_t_s is not None
            and valid_coach_reps[first_future_matched_idx].video_t_s <= eff_rel_t_s
        ):
            cutoff_unmatched_idx = first_future_matched_idx - 1

    return list(valid_coach_reps[cutoff_unmatched_idx + 1 :])


def _prior_fault_rank(
    cutoff_t_ms: int,
    set_log: SetLog,
    valid_coach_reps: Optional[Sequence[CoachRow]],
    c_seq: Optional[Sequence[CoachRow]],
    fault_id: str,
) -> int:
    """Rank whether the rep preceding/triggering a cue actually exhibited fault_id.

    0 = coach confirmed fault_id on the immediately preceding valid rep (strongest video clip),
    1 = app recorded fault_id on the preceding rep (or cue preceded rep 1, e.g. hold-break),
    2 = preceding rep existed and neither coach nor app recorded fault_id on it.
    """
    prior_app = [r for r in set_log.reps if r.t_ms <= cutoff_t_ms]
    if valid_coach_reps is not None and c_seq is not None:
        n_prior_c = len(valid_coach_reps) - len(c_seq)
        if n_prior_c > 0 and fault_id in valid_coach_reps[n_prior_c - 1].faults:
            return 0
    if not prior_app or fault_id in prior_app[-1].faults:
        return 1
    return 2


def _build_cue_analysis(
    set_logs: dict[tuple[str, str, str, int], SetLog],
    coach_sets: dict[tuple[str, str, str, int], dict[str, list[CoachRow]]],
    chosen_coach_per_set: dict[tuple[str, str, str, int], str],
    all_pairs_by_set: dict[tuple[str, str, str, int], list[MatchedRepPair]],
) -> tuple[dict[str, Any], list[dict[str, Any]], list[dict[str, Any]]]:
    # Audit cue mapping across all set logs
    mapping_counts = {
        "played_total": 0,
        "played_from_log_fault": 0,
        "played_from_cue_map": 0,
        "played_explicit_non_fault": 0,
        "played_unmapped": 0,
        "suppressed_total": 0,
        "suppressed_from_log_fault": 0,
        "suppressed_from_cue_map": 0,
        "suppressed_explicit_non_fault": 0,
        "suppressed_unmapped": 0,
    }
    unmapped_played_keys: Counter[str] = Counter()
    unmapped_all_keys: Counter[str] = Counter()

    # Individual evaluated fault-cue instances
    # bucket key: (played_bool, exercise_id, fault_id)
    @dataclass
    class _CueEvalBucket:
        n_cues: int = 0
        n_next1_coach: int = 0
        ok_next1_coach: int = 0
        n_next2_coach: int = 0
        ok_next2_coach: int = 0
        n_next1_app: int = 0
        ok_next1_app: int = 0
        n_next2_app: int = 0
        ok_next2_app: int = 0

        def add(
            self,
            c_next: Optional[list[CoachRow]],
            a_next: list[AppRep],
            fault_id: str,
        ) -> None:
            self.n_cues += 1
            if len(a_next) >= 1:
                self.n_next1_app += 1
                if fault_id not in a_next[0].faults:
                    self.ok_next1_app += 1
            if len(a_next) >= 2:
                self.n_next2_app += 1
                if (fault_id not in a_next[0].faults) and (fault_id not in a_next[1].faults):
                    self.ok_next2_app += 1

            if c_next is not None:
                if len(c_next) >= 1:
                    self.n_next1_coach += 1
                    if fault_id not in c_next[0].faults:
                        self.ok_next1_coach += 1
                if len(c_next) >= 2:
                    self.n_next2_coach += 1
                    if (fault_id not in c_next[0].faults) and (fault_id not in c_next[1].faults):
                        self.ok_next2_coach += 1

    buckets: dict[tuple[bool, str, str], _CueEvalBucket] = defaultdict(_CueEvalBucket)
    candidate_records: list[tuple[int, dict[str, Any]]] = []

    for skey in sorted(set_logs.keys()):
        sl = set_logs[skey]
        has_coach = skey in coach_sets
        valid_c_reps: Optional[list[CoachRow]] = None
        set_pairs: Sequence[MatchedRepPair] = ()
        if has_coach:
            ref_cid = chosen_coach_per_set[skey]
            valid_c_reps = [r for r in coach_sets[skey][ref_cid] if r.counted == 1]
            set_pairs = all_pairs_by_set.get(skey, ())

        # Track per-(set, fault) played cues for candidate success/failure sets
        played_cues_by_fault: dict[str, list[AppCue]] = defaultdict(list)

        for cue in sl.cues:
            prefix = "played" if cue.played else "suppressed"
            mapping_counts[f"{prefix}_total"] += 1
            if cue.mapping_source == "log":
                mapping_counts[f"{prefix}_from_log_fault"] += 1
            elif cue.mapping_source == "cue_map":
                mapping_counts[f"{prefix}_from_cue_map"] += 1
            elif cue.mapping_source == "explicit_non_fault":
                mapping_counts[f"{prefix}_explicit_non_fault"] += 1
            else:
                mapping_counts[f"{prefix}_unmapped"] += 1
                unmapped_all_keys[cue.key] += 1
                if cue.played:
                    unmapped_played_keys[cue.key] += 1

            if cue.resolved_fault is None:
                continue

            fault_id = cue.resolved_fault
            cutoff_ms = _cue_effective_cutoff_t_ms(cue, sl, fault_id)
            a_next = [r for r in sl.reps if r.t_ms > cutoff_ms and r.form_judged]
            c_next = (
                _subsequent_coach_reps_after_cue(
                    cue, sl, valid_c_reps, set_pairs, cutoff_t_ms=cutoff_ms
                )
                if valid_c_reps is not None
                else None
            )

            buckets[(cue.played, sl.exercise_id, fault_id)].add(c_next, a_next, fault_id)
            buckets[(cue.played, sl.exercise_id, "ALL_FAULTS")].add(c_next, a_next, fault_id)
            buckets[(cue.played, "overall", "ALL_FAULTS")].add(c_next, a_next, fault_id)

            if cue.played:
                played_cues_by_fault[fault_id].append(cue)

        # Evaluate candidate success / failure sets for spoken (played=True) fault cues
        for fault_id, f_cues in sorted(played_cues_by_fault.items()):
            first_cue = f_cues[0]
            first_cutoff_ms = _cue_effective_cutoff_t_ms(first_cue, sl, fault_id)
            a_after_first = [r for r in sl.reps if r.t_ms > first_cutoff_ms and r.form_judged]
            c_after_first = (
                _subsequent_coach_reps_after_cue(
                    first_cue, sl, valid_c_reps, set_pairs, cutoff_t_ms=first_cutoff_ms
                )
                if valid_c_reps is not None
                else None
            )

            # Check per-cue whether ANY spoken cue in this set was followed by a clean next rep
            # (and whether all remaining reps after that cue stayed clean).
            best_success_cue: Optional[tuple[AppCue, int, int, int, bool, int]] = None
            if c_after_first is not None and len(c_after_first) >= 1:
                basis = "coach"
                n_after_first = len(c_after_first)
                c_fault_after_first = sum(1 for r in c_after_first if fault_id in r.faults)
                a_fault_after_first = sum(1 for r in a_after_first if fault_id in r.faults)
                never_corrected = True
                for cue_i in f_cues:
                    cut_i = _cue_effective_cutoff_t_ms(cue_i, sl, fault_id)
                    c_seq = _subsequent_coach_reps_after_cue(
                        cue_i, sl, valid_c_reps, set_pairs, cutoff_t_ms=cut_i
                    )
                    a_seq = [r for r in sl.reps if r.t_ms > cut_i and r.form_judged]
                    if len(c_seq) >= 1 and fault_id not in c_seq[0].faults:
                        never_corrected = False
                        c_rem_faults = sum(1 for r in c_seq if fault_id in r.faults)
                        a_rem_faults = sum(1 for r in a_seq if fault_id in r.faults)
                        sustained = c_rem_faults == 0
                        p_rank = _prior_fault_rank(cut_i, sl, valid_c_reps, c_seq, fault_id)
                        cand_tuple = (cue_i, len(c_seq), c_rem_faults, a_rem_faults, sustained, p_rank)
                        if best_success_cue is None or (
                            (not cand_tuple[4], cand_tuple[5], cand_tuple[2])
                            < (not best_success_cue[4], best_success_cue[5], best_success_cue[2])
                        ):
                            best_success_cue = cand_tuple
                    elif any(fault_id not in r.faults for r in c_seq):
                        never_corrected = False
            elif c_after_first is None and len(a_after_first) >= 1:
                basis = "app_only"
                n_after_first = len(a_after_first)
                c_fault_after_first = -1
                a_fault_after_first = sum(1 for r in a_after_first if fault_id in r.faults)
                never_corrected = True
                for cue_i in f_cues:
                    cut_i = _cue_effective_cutoff_t_ms(cue_i, sl, fault_id)
                    a_seq = [r for r in sl.reps if r.t_ms > cut_i and r.form_judged]
                    if len(a_seq) >= 1 and fault_id not in a_seq[0].faults:
                        never_corrected = False
                        a_rem_faults = sum(1 for r in a_seq if fault_id in r.faults)
                        sustained = a_rem_faults == 0
                        p_rank = _prior_fault_rank(cut_i, sl, None, None, fault_id)
                        cand_tuple = (cue_i, len(a_seq), -1, a_rem_faults, sustained, p_rank)
                        if best_success_cue is None or (
                            (not cand_tuple[4], cand_tuple[5], cand_tuple[3])
                            < (not best_success_cue[4], best_success_cue[5], best_success_cue[3])
                        ):
                            best_success_cue = cand_tuple
                    elif any(fault_id not in r.faults for r in a_seq):
                        never_corrected = False
            else:
                continue

            pid, cond, ex_id, s_idx = skey
            if best_success_cue is not None:
                scue, n_rem, c_rem_f, a_rem_f, _sustained, p_rank = best_success_cue
                candidate_records.append(
                    (
                        p_rank,
                        {
                            "candidate_type": "success",
                            "participant_id": pid,
                            "condition": cond,
                            "exercise_id": ex_id,
                            "set_index": s_idx,
                            "session_id": sl.session_id,
                            "log_file": sl.file_name,
                            "fault_id": fault_id,
                            "played_cue_count": len(f_cues),
                            "cue_repeated": len(f_cues) >= 2,
                            "first_cue_t_ms": scue.t_ms,
                            "first_cue_rel_t_s": fmt_float(scue.rel_t_s, 3),
                            "reps_after_first_cue": n_rem,
                            "faulty_reps_after_coach": c_rem_f if c_rem_f >= 0 else "",
                            "faulty_reps_after_app": a_rem_f,
                            "basis": basis,
                        },
                    )
                )
            elif never_corrected:
                p_rank_fail = _prior_fault_rank(
                    first_cutoff_ms, sl, valid_c_reps, c_after_first, fault_id
                )
                candidate_records.append(
                    (
                        p_rank_fail,
                        {
                            "candidate_type": "failure",
                            "participant_id": pid,
                            "condition": cond,
                            "exercise_id": ex_id,
                            "set_index": s_idx,
                            "session_id": sl.session_id,
                            "log_file": sl.file_name,
                            "fault_id": fault_id,
                            "played_cue_count": len(f_cues),
                            "cue_repeated": len(f_cues) >= 2,
                            "first_cue_t_ms": first_cue.t_ms,
                            "first_cue_rel_t_s": fmt_float(first_cue.rel_t_s, 3),
                            "reps_after_first_cue": n_after_first,
                            "faulty_reps_after_coach": (
                                c_fault_after_first if c_fault_after_first >= 0 else ""
                            ),
                            "faulty_reps_after_app": a_fault_after_first,
                            "basis": basis,
                        },
                    )
                )

    # Sort candidates: coach-verified first; genuine prior fault first; for success, 0 remaining
    # faults & more reps first; for failure, cue_repeated=True & higher cue_count first.
    candidate_records.sort(
        key=lambda item: (
            0 if item[1]["candidate_type"] == "success" else 1,
            0 if item[1]["basis"] == "coach" else 1,
            item[0],
            (
                (
                    int(item[1]["faulty_reps_after_coach"])
                    if item[1]["faulty_reps_after_coach"] != ""
                    else int(item[1]["faulty_reps_after_app"])
                )
                if item[1]["candidate_type"] == "success"
                else 0
            ),
            -(1 if item[1]["cue_repeated"] else 0) if item[1]["candidate_type"] == "failure" else 0,
            -int(item[1]["played_cue_count"]) if item[1]["candidate_type"] == "failure" else 0,
            -int(item[1]["reps_after_first_cue"]),
            item[1]["participant_id"],
            item[1]["exercise_id"],
            int(item[1]["set_index"]),
        )
    )
    candidate_rows = [rec for _pr, rec in candidate_records]

    # Format cue_correction_rows: spoken (played=True) first, then suppressed (played=False)
    cue_rows: list[dict[str, Any]] = []
    ordered_keys: list[tuple[bool, str, str]] = []
    for played_flag in (True, False):
        for ex_id, faults in KNOWN_EXERCISES.items():
            for f_id in list(faults) + ["ALL_FAULTS"]:
                if (played_flag, ex_id, f_id) in buckets:
                    ordered_keys.append((played_flag, ex_id, f_id))
        if (played_flag, "overall", "ALL_FAULTS") in buckets or played_flag is True:
            ordered_keys.append((played_flag, "overall", "ALL_FAULTS"))

    for played_flag, ex_id, f_id in ordered_keys:
        b = buckets[(played_flag, ex_id, f_id)]
        r_c1 = b.ok_next1_coach / b.n_next1_coach if b.n_next1_coach > 0 else None
        c1_lo, c1_hi = wilson_ci(b.ok_next1_coach, b.n_next1_coach)
        r_c2 = b.ok_next2_coach / b.n_next2_coach if b.n_next2_coach > 0 else None
        c2_lo, c2_hi = wilson_ci(b.ok_next2_coach, b.n_next2_coach)

        r_a1 = b.ok_next1_app / b.n_next1_app if b.n_next1_app > 0 else None
        a1_lo, a1_hi = wilson_ci(b.ok_next1_app, b.n_next1_app)
        r_a2 = b.ok_next2_app / b.n_next2_app if b.n_next2_app > 0 else None
        a2_lo, a2_hi = wilson_ci(b.ok_next2_app, b.n_next2_app)

        cue_rows.append(
            {
                "played": "true" if played_flag else "false",
                "exercise_id": ex_id,
                "fault_id": f_id,
                "n_cues": b.n_cues,
                "n_with_next1_coach": b.n_next1_coach,
                "corrected_next1_coach": b.ok_next1_coach,
                "rate_next1_coach": fmt_float(r_c1),
                "ci95_low_next1_coach": fmt_float(c1_lo),
                "ci95_high_next1_coach": fmt_float(c1_hi),
                "n_with_next2_coach": b.n_next2_coach,
                "corrected_next2_coach": b.ok_next2_coach,
                "rate_next2_coach": fmt_float(r_c2),
                "ci95_low_next2_coach": fmt_float(c2_lo),
                "ci95_high_next2_coach": fmt_float(c2_hi),
                "n_with_next1_app": b.n_next1_app,
                "corrected_next1_app": b.ok_next1_app,
                "rate_next1_app": fmt_float(r_a1),
                "ci95_low_next1_app": fmt_float(a1_lo),
                "ci95_high_next1_app": fmt_float(a1_hi),
                "n_with_next2_app": b.n_next2_app,
                "corrected_next2_app": b.ok_next2_app,
                "rate_next2_app": fmt_float(r_a2),
                "ci95_low_next2_app": fmt_float(a2_lo),
                "ci95_high_next2_app": fmt_float(a2_hi),
            }
        )

    mapping_summary = {
        **mapping_counts,
        "unmapped_played_keys": dict(unmapped_played_keys.most_common()),
        "unmapped_all_keys": dict(unmapped_all_keys.most_common()),
    }
    return (mapping_summary, cue_rows, candidate_rows)


def _build_ai_vs_control(
    coach_sets: dict[tuple[str, str, str, int], dict[str, list[CoachRow]]],
    chosen_coach_per_set: dict[tuple[str, str, str, int], str],
    issues: Optional[list[ValidationIssue]] = None,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    _ = issues
    # Collect coach-valid reps per (participant_id, condition, exercise_id)
    # Using the single reference coach per set
    stats: dict[tuple[str, str, str], dict[str, int]] = defaultdict(
        lambda: {"sets": 0, "reps": 0, "faulty_reps": 0, "fault_instances": 0}
    )
    participants: set[str] = set()

    for skey, by_coach in sorted(coach_sets.items()):
        pid, cond, ex_id, _s_idx = skey
        ref_cid = chosen_coach_per_set[skey]
        valid_rows = [r for r in by_coach[ref_cid] if r.counted == 1]
        participants.add(pid)
        for scope_ex in (ex_id, "overall"):
            cell = stats[(pid, cond, scope_ex)]
            cell["sets"] += 1
            cell["reps"] += len(valid_rows)
            cell["faulty_reps"] += sum(1 for r in valid_rows if len(r.faults) > 0)
            cell["fault_instances"] += sum(len(r.faults) for r in valid_rows)

    participant_rows: list[dict[str, Any]] = []
    overall_paired_diffs_by_pid: dict[str, float] = {}
    for pid in sorted(participants):
        ctrl = stats[(pid, "control", "overall")]
        ai = stats[(pid, "ai", "overall")]
        c_rate = ctrl["faulty_reps"] / ctrl["reps"] if ctrl["reps"] > 0 else None
        a_rate = ai["faulty_reps"] / ai["reps"] if ai["reps"] > 0 else None
        c_fpr = ctrl["fault_instances"] / ctrl["reps"] if ctrl["reps"] > 0 else None
        a_fpr = ai["fault_instances"] / ai["reps"] if ai["reps"] > 0 else None

        ctrl_exs = [ex for ex in KNOWN_EXERCISES if stats[(pid, "control", ex)]["reps"] > 0]
        ai_exs = [ex for ex in KNOWN_EXERCISES if stats[(pid, "ai", ex)]["reps"] > 0]
        common_exs = [ex for ex in KNOWN_EXERCISES if ex in ctrl_exs and ex in ai_exs]

        c_common_reps = 0
        c_common_faulty = 0
        c_common_rate: Optional[float] = None
        a_common_reps = 0
        a_common_faulty = 0
        a_common_rate: Optional[float] = None
        diff: Optional[float] = None
        outcome = "incomplete_pair"
        if common_exs:
            c_common_reps = sum(stats[(pid, "control", ex)]["reps"] for ex in common_exs)
            c_common_faulty = sum(stats[(pid, "control", ex)]["faulty_reps"] for ex in common_exs)
            a_common_reps = sum(stats[(pid, "ai", ex)]["reps"] for ex in common_exs)
            a_common_faulty = sum(stats[(pid, "ai", ex)]["faulty_reps"] for ex in common_exs)
            c_common_rate = c_common_faulty / c_common_reps
            a_common_rate = a_common_faulty / a_common_reps
            diff = a_common_rate - c_common_rate
            overall_paired_diffs_by_pid[pid] = diff
            if diff < -FLOAT_TIE_EPS:
                outcome = "improved"
            elif diff > FLOAT_TIE_EPS:
                outcome = "worsened"
            else:
                outcome = "same"

        participant_rows.append(
            {
                "participant_id": pid,
                "paired_exercises": ";".join(common_exs),
                "exercises_balanced": "true" if (common_exs and ctrl_exs == ai_exs) else "false",
                "control_sets": ctrl["sets"],
                "control_valid_reps": ctrl["reps"],
                "control_faulty_reps": ctrl["faulty_reps"],
                "control_fault_rate": fmt_float(c_rate),
                "control_faults_per_rep": fmt_float(c_fpr),
                "ai_sets": ai["sets"],
                "ai_valid_reps": ai["reps"],
                "ai_faulty_reps": ai["faulty_reps"],
                "ai_fault_rate": fmt_float(a_rate),
                "ai_faults_per_rep": fmt_float(a_fpr),
                "paired_control_valid_reps": c_common_reps,
                "paired_control_faulty_reps": c_common_faulty,
                "paired_control_fault_rate": fmt_float(c_common_rate),
                "paired_ai_valid_reps": a_common_reps,
                "paired_ai_faulty_reps": a_common_faulty,
                "paired_ai_fault_rate": fmt_float(a_common_rate),
                "paired_diff_ai_minus_control": fmt_float(diff),
                "outcome": outcome,
            }
        )

    summary_rows: list[dict[str, Any]] = []
    for scope_ex in list(KNOWN_EXERCISES.keys()) + ["overall"]:
        ai_pids = [p for p in sorted(participants) if stats[(p, "ai", scope_ex)]["reps"] > 0]
        ctrl_pids = [p for p in sorted(participants) if stats[(p, "control", scope_ex)]["reps"] > 0]
        ai_reps = sum(stats[(p, "ai", scope_ex)]["reps"] for p in ai_pids)
        ai_faulty = sum(stats[(p, "ai", scope_ex)]["faulty_reps"] for p in ai_pids)
        ctrl_reps = sum(stats[(p, "control", scope_ex)]["reps"] for p in ctrl_pids)
        ctrl_faulty = sum(stats[(p, "control", scope_ex)]["faulty_reps"] for p in ctrl_pids)

        paired_diffs: list[float] = []
        n_imp = n_wor = n_same = 0
        for p in sorted(participants):
            if scope_ex == "overall":
                if p not in overall_paired_diffs_by_pid:
                    continue
                d = overall_paired_diffs_by_pid[p]
            else:
                cr = stats[(p, "control", scope_ex)]["reps"]
                ar = stats[(p, "ai", scope_ex)]["reps"]
                if cr <= 0 or ar <= 0:
                    continue
                d = (stats[(p, "ai", scope_ex)]["faulty_reps"] / ar) - (
                    stats[(p, "control", scope_ex)]["faulty_reps"] / cr
                )
            paired_diffs.append(d)
            if d < -FLOAT_TIE_EPS:
                n_imp += 1
            elif d > FLOAT_TIE_EPS:
                n_wor += 1
            else:
                n_same += 1

        n_paired = len(paired_diffs)
        mean_diff = statistics.mean(paired_diffs) if n_paired > 0 else None
        sd_diff = statistics.stdev(paired_diffs) if n_paired >= 2 else None
        median_diff = statistics.median(paired_diffs) if n_paired > 0 else None
        sign_p = exact_sign_test_two_sided(n_imp, n_wor)

        summary_rows.append(
            {
                "exercise_id": scope_ex,
                "n_participants_control": len(ctrl_pids),
                "control_valid_reps": ctrl_reps,
                "control_faulty_reps": ctrl_faulty,
                "pooled_control_fault_rate": fmt_float(
                    ctrl_faulty / ctrl_reps if ctrl_reps > 0 else None
                ),
                "n_participants_ai": len(ai_pids),
                "ai_valid_reps": ai_reps,
                "ai_faulty_reps": ai_faulty,
                "pooled_ai_fault_rate": fmt_float(ai_faulty / ai_reps if ai_reps > 0 else None),
                "n_paired_participants": n_paired,
                "mean_paired_diff_ai_minus_control": fmt_float(mean_diff),
                "sd_paired_diff": fmt_float(sd_diff),
                "median_paired_diff": fmt_float(median_diff),
                "n_improved": n_imp,
                "n_worsened": n_wor,
                "n_same": n_same,
                "sign_test_n_non_tied": n_imp + n_wor,
                "sign_test_p_two_sided": fmt_float(sign_p),
            }
        )

    return (participant_rows, summary_rows)


def _build_satisfaction(session_logs: Sequence[SessionLog]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for cond_scope in ("ai", "control", "overall"):
        sub = [
            s
            for s in session_logs
            if (cond_scope == "overall" or s.condition == cond_scope)
        ]
        vals = [s.satisfaction for s in sub if s.satisfaction is not None]
        dist = Counter(vals)
        n_resp = len(vals)
        rows.append(
            {
                "condition": cond_scope,
                "n_sessions_total": len(sub),
                "n_responses": n_resp,
                "n_missing": len(sub) - n_resp,
                "mean_satisfaction": fmt_float(statistics.mean(vals) if n_resp > 0 else None),
                "sd_satisfaction": fmt_float(statistics.stdev(vals) if n_resp >= 2 else None),
                "median_satisfaction": fmt_float(statistics.median(vals) if n_resp > 0 else None),
                "count_1": dist[1],
                "count_2": dist[2],
                "count_3": dist[3],
                "count_4": dist[4],
                "count_5": dist[5],
            }
        )
    return rows


def _build_frame_rate(set_logs: dict[tuple[str, str, str, int], SetLog]) -> list[dict[str, Any]]:
    def _has_valid_mean_fps(sl: SetLog) -> bool:
        if sl.mean_fps is None:
            return False
        if sl.frames_duration_ms is not None:
            if sl.frames_duration_ms <= 0:
                return False
            if sl.frames_duration_ms < 1000 and not sl.has_set_complete and not sl.reps:
                return False
        if sl.frames_total == 0 and sl.mean_fps <= 0 and not sl.has_set_complete and not sl.reps:
            return False
        return True

    def _has_valid_min1s_fps(sl: SetLog) -> bool:
        if sl.min_fps_1s is None or not _has_valid_mean_fps(sl):
            return False
        if sl.frames_duration_ms is not None:
            # min_fps_1s measures whole 1-second non-paused windows (schema line 89).
            if sl.frames_duration_ms < 1000:
                return False
            if (sl.frames_duration_ms - sl.paused_ms) < 1000 and sl.min_fps_1s <= 0:
                return False
            if (
                sl.max_non_paused_window_ms is not None
                and sl.max_non_paused_window_ms < 1000
                and sl.min_fps_1s <= 0
            ):
                return False
        return True

    def _has_valid_gap(sl: SetLog) -> bool:
        if sl.max_gap_ms is None:
            return False
        if sl.frames_duration_ms is not None:
            if sl.frames_duration_ms <= 0:
                return False
            if sl.frames_duration_ms < 1000 and not sl.has_set_complete and not sl.reps:
                return False
        return True

    rows: list[dict[str, Any]] = []
    for scope in list(KNOWN_EXERCISES.keys()) + ["overall"]:
        sub = [
            sl
            for sl in set_logs.values()
            if (scope == "overall" or sl.exercise_id == scope)
        ]
        mean_pairs = [(sl.mean_fps, sl.file_name) for sl in sub if _has_valid_mean_fps(sl) and sl.mean_fps is not None]
        min1s_pairs = [(sl.min_fps_1s, sl.file_name) for sl in sub if _has_valid_min1s_fps(sl) and sl.min_fps_1s is not None]
        gaps = [sl.max_gap_ms for sl in sub if _has_valid_gap(sl) and sl.max_gap_ms is not None]

        avg_mean_fps = statistics.mean(v for v, _ in mean_pairs) if mean_pairs else None
        worst_mean_pair = min(mean_pairs, key=lambda x: (x[0], x[1])) if mean_pairs else None
        avg_min1s = statistics.mean(v for v, _ in min1s_pairs) if min1s_pairs else None
        worst_min1s_pair = min(min1s_pairs, key=lambda x: (x[0], x[1])) if min1s_pairs else None
        worst_gap = max(gaps) if gaps else None

        rows.append(
            {
                "exercise_id": scope,
                "n_sets_total": len(sub),
                "n_sets_with_fps": len(mean_pairs),
                "mean_of_mean_fps": fmt_float(avg_mean_fps, 2),
                "worst_mean_fps": fmt_float(worst_mean_pair[0], 2) if worst_mean_pair else "",
                "worst_mean_fps_file": worst_mean_pair[1] if worst_mean_pair else "",
                "mean_of_min_fps_1s": fmt_float(avg_min1s, 2),
                "worst_min_fps_1s": fmt_float(worst_min1s_pair[0], 2) if worst_min1s_pair else "",
                "worst_min_fps_1s_file": worst_min1s_pair[1] if worst_min1s_pair else "",
                "worst_max_gap_ms": fmt_float(worst_gap, 1) if worst_gap is not None else "",
            }
        )
    return rows


# ---------------------------------------------------------------------------
# Output writers (CSV tables + Vietnamese summary.md)
# ---------------------------------------------------------------------------


def _write_csv(path: Path, fieldnames: Sequence[str], rows: Sequence[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()
        for r in rows:
            writer.writerow(r)


def write_all_outputs(out_dir: Path, res: EvaluationResults) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)

    _write_csv(
        out_dir / "validation_issues.csv",
        ("severity", "code", "file", "line", "message_vi", "message_en"),
        [
            {
                "severity": iv.severity,
                "code": iv.code,
                "file": iv.file,
                "line": iv.line,
                "message_vi": iv.message_vi,
                "message_en": iv.message_en,
            }
            for iv in res.issues
        ],
    )

    _write_csv(
        out_dir / "rep_matching.csv",
        (
            "participant_id",
            "condition",
            "exercise_id",
            "set_index",
            "session_id",
            "log_file",
            "coach_id",
            "status",
            "match_method",
            "coach_rep_n",
            "app_rep_n",
            "video_t_s",
            "app_rel_t_s",
            "app_t_ms",
            "time_diff_s",
            "coach_faults",
            "app_faults",
            "coach_note",
        ),
        res.rep_matching_rows,
    )

    _write_csv(
        out_dir / "counting_accuracy.csv",
        (
            "exercise_id",
            "n_sets",
            "coach_valid_reps",
            "coach_uncounted_attempts",
            "app_reps",
            "matched",
            "missed",
            "phantom",
            "recall_count_rate",
            "miss_rate",
            "phantom_rate",
        ),
        res.counting_accuracy_rows,
    )

    _write_csv(
        out_dir / "fault_detection.csv",
        (
            "exercise_id",
            "fault_id",
            "n_sets",
            "n_matched_reps",
            "tp",
            "fp",
            "fn",
            "tn",
            "n_app_positive",
            "precision",
            "precision_ci95_low",
            "precision_ci95_high",
            "n_coach_positive",
            "recall",
            "recall_ci95_low",
            "recall_ci95_high",
            "n_coach_negative",
            "false_positive_rate",
            "false_positive_rate_ci95_low",
            "false_positive_rate_ci95_high",
            "fp_per_matched_rep",
            "n_participants",
            "n_unjudged_reps",
            "precision_boot95_low",
            "precision_boot95_high",
            "recall_boot95_low",
            "recall_boot95_high",
        ),
        res.fault_detection_rows,
    )

    if res.condition_factors:
        _write_csv(
            out_dir / "fault_detection_by_condition.csv",
            (
                "factor",
                "level",
                "exercise_id",
                "fault_id",
                "n_participants",
                "n_sets",
                "n_matched_reps",
                "tp",
                "fp",
                "fn",
                "tn",
                "n_app_positive",
                "precision",
                "precision_ci95_low",
                "precision_ci95_high",
                "n_coach_positive",
                "recall",
                "recall_ci95_low",
                "recall_ci95_high",
            ),
            res.fault_condition_rows,
        )

    _write_csv(
        out_dir / "confusion_matrices.csv",
        ("exercise_id", "n_matched_reps", "coach_label", "app_label", "count"),
        res.confusion_matrix_rows,
    )

    _write_csv(
        out_dir / "wrong_detections.csv",
        (
            "participant_id",
            "condition",
            "exercise_id",
            "set_index",
            "session_id",
            "log_file",
            "coach_id",
            "coach_rep_n",
            "app_rep_n",
            "video_t_s",
            "app_rel_t_s",
            "app_t_ms",
            "coach_faults",
            "app_faults",
            "false_positives",
            "false_negatives",
            "coach_note",
        ),
        res.wrong_detection_rows,
    )

    _write_csv(
        out_dir / "coach_agreement.csv",
        (
            "coach_a",
            "coach_b",
            "exercise_id",
            "fault_id",
            "n_shared_sets",
            "n_matched_valid_reps",
            "coach_a_unmatched_valid_reps",
            "coach_b_unmatched_valid_reps",
            "both_positive",
            "coach_a_only_positive",
            "coach_b_only_positive",
            "both_negative",
            "percent_agreement",
            "cohen_kappa",
            "kappa_note",
        ),
        res.coach_agreement_rows,
    )

    _write_csv(
        out_dir / "unseen_time.csv",
        (
            "exercise_id",
            "n_sets",
            "active_ms",
            "unseen_ms",
            "unseen_over_active_ratio",
            "paused_ms",
        ),
        res.unseen_time_rows,
    )

    _write_csv(
        out_dir / "unseen_reasons.csv",
        (
            "exercise_id",
            "phase",
            "reason",
            "n_sets_with_reason",
            "n_total_sets",
            "event_count",
            "duration_ms",
            "share_of_active_ms",
            "share_of_phase_unseen_ms",
        ),
        res.unseen_reason_rows,
    )

    _write_csv(
        out_dir / "cue_mapping_summary.csv",
        (
            "played_total",
            "played_from_log_fault",
            "played_from_cue_map",
            "played_explicit_non_fault",
            "played_unmapped",
            "suppressed_total",
            "suppressed_from_log_fault",
            "suppressed_from_cue_map",
            "suppressed_explicit_non_fault",
            "suppressed_unmapped",
        ),
        [
            {
                k: res.cue_mapping_summary[k]
                for k in (
                    "played_total",
                    "played_from_log_fault",
                    "played_from_cue_map",
                    "played_explicit_non_fault",
                    "played_unmapped",
                    "suppressed_total",
                    "suppressed_from_log_fault",
                    "suppressed_from_cue_map",
                    "suppressed_explicit_non_fault",
                    "suppressed_unmapped",
                )
            }
        ],
    )

    _write_csv(
        out_dir / "cue_correction.csv",
        (
            "played",
            "exercise_id",
            "fault_id",
            "n_cues",
            "n_with_next1_coach",
            "corrected_next1_coach",
            "rate_next1_coach",
            "ci95_low_next1_coach",
            "ci95_high_next1_coach",
            "n_with_next2_coach",
            "corrected_next2_coach",
            "rate_next2_coach",
            "ci95_low_next2_coach",
            "ci95_high_next2_coach",
            "n_with_next1_app",
            "corrected_next1_app",
            "rate_next1_app",
            "ci95_low_next1_app",
            "ci95_high_next1_app",
            "n_with_next2_app",
            "corrected_next2_app",
            "rate_next2_app",
            "ci95_low_next2_app",
            "ci95_high_next2_app",
        ),
        res.cue_correction_rows,
    )

    _write_csv(
        out_dir / "ai_vs_control_participants.csv",
        (
            "participant_id",
            "paired_exercises",
            "exercises_balanced",
            "control_sets",
            "control_valid_reps",
            "control_faulty_reps",
            "control_fault_rate",
            "control_faults_per_rep",
            "ai_sets",
            "ai_valid_reps",
            "ai_faulty_reps",
            "ai_fault_rate",
            "ai_faults_per_rep",
            "paired_control_valid_reps",
            "paired_control_faulty_reps",
            "paired_control_fault_rate",
            "paired_ai_valid_reps",
            "paired_ai_faulty_reps",
            "paired_ai_fault_rate",
            "paired_diff_ai_minus_control",
            "outcome",
        ),
        res.ai_vs_control_participant_rows,
    )

    _write_csv(
        out_dir / "ai_vs_control_summary.csv",
        (
            "exercise_id",
            "n_participants_control",
            "control_valid_reps",
            "control_faulty_reps",
            "pooled_control_fault_rate",
            "n_participants_ai",
            "ai_valid_reps",
            "ai_faulty_reps",
            "pooled_ai_fault_rate",
            "n_paired_participants",
            "mean_paired_diff_ai_minus_control",
            "sd_paired_diff",
            "median_paired_diff",
            "n_improved",
            "n_worsened",
            "n_same",
            "sign_test_n_non_tied",
            "sign_test_p_two_sided",
        ),
        res.ai_vs_control_summary_rows,
    )

    _write_csv(
        out_dir / "cue_candidates.csv",
        (
            "candidate_type",
            "participant_id",
            "condition",
            "exercise_id",
            "set_index",
            "session_id",
            "log_file",
            "fault_id",
            "played_cue_count",
            "cue_repeated",
            "first_cue_t_ms",
            "first_cue_rel_t_s",
            "reps_after_first_cue",
            "faulty_reps_after_coach",
            "faulty_reps_after_app",
            "basis",
        ),
        res.cue_candidate_rows,
    )

    _write_csv(
        out_dir / "satisfaction.csv",
        (
            "condition",
            "n_sessions_total",
            "n_responses",
            "n_missing",
            "mean_satisfaction",
            "sd_satisfaction",
            "median_satisfaction",
            "count_1",
            "count_2",
            "count_3",
            "count_4",
            "count_5",
        ),
        res.satisfaction_rows,
    )

    _write_csv(
        out_dir / "frame_rate.csv",
        (
            "exercise_id",
            "n_sets_total",
            "n_sets_with_fps",
            "mean_of_mean_fps",
            "worst_mean_fps",
            "worst_mean_fps_file",
            "mean_of_min_fps_1s",
            "worst_min_fps_1s",
            "worst_min_fps_1s_file",
            "worst_max_gap_ms",
        ),
        res.frame_rate_rows,
    )

    _write_csv(
        out_dir / "fault_reports.csv",
        (
            "participant_id",
            "condition",
            "exercise_id",
            "set_index",
            "log_file",
            "fault",
            "reported",
            "app_matched_reps_with_fault",
            "coach_confirmed",
            "coach_absent",
            "verdict",
        ),
        res.fault_report_rows,
    )

    summary_md = render_summary_markdown_vi(res)
    (out_dir / "summary.md").write_text(summary_md, encoding="utf-8")


def _fmt_boot_pair_vi(r: dict[str, Any]) -> str:
    def one(lo: Any, hi: Any) -> str:
        lo_f = _opt_float_str(lo)
        hi_f = _opt_float_str(hi)
        if lo_f is None or hi_f is None:
            return "—"
        return f"[{lo_f * 100:.1f}%; {hi_f * 100:.1f}%]"

    return (
        f"P {one(r.get('precision_boot95_low'), r.get('precision_boot95_high'))} / "
        f"R {one(r.get('recall_boot95_low'), r.get('recall_boot95_high'))}"
    )


def _opt_float_str(s: Any) -> Optional[float]:
    if s is None or s == "":
        return None
    try:
        return float(s)
    except (TypeError, ValueError):
        return None


def _fmt_rate_with_ci_vi(
    rate_s: Any, lo_s: Any, hi_s: Any, num: int, den: int
) -> str:
    r = _opt_float_str(rate_s)
    lo = _opt_float_str(lo_s)
    hi = _opt_float_str(hi_s)
    if r is None or lo is None or hi is None or den == 0:
        return f"— (0/{den})"
    if abs(r) < 1e-12:
        r = 0.0
    if abs(lo) < 1e-12:
        lo = 0.0
    if abs(hi) < 1e-12:
        hi = 0.0
    return f"{r * 100:.1f}% [{lo * 100:.1f}%–{hi * 100:.1f}%] ({num}/{den})"


def render_summary_markdown_vi(res: EvaluationResults) -> str:
    lines: list[str] = []
    lines.append("# Báo cáo đánh giá thực nghiệm Vika (Đối chiếu Log Ứng dụng & Nhãn Huấn luyện viên)")
    lines.append("")

    # 0. Validation warnings at the very top
    lines.append("## 0. Kiểm tra dữ liệu đầu vào")
    lines.append("")
    if not res.issues:
        lines.append("- Không phát hiện vấn đề dữ liệu đầu vào nào.")
    else:
        lines.append(
            f"Phát hiện **{len(res.issues)}** cảnh báo/lỗi có thể phục hồi "
            f"(chi tiết đầy đủ trong `validation_issues.csv`). Kịch bản đã tiếp tục chạy trên phần dữ liệu hợp lệ:"
        )
        lines.append("")
        for iv in res.issues:
            tag = "LỖI" if iv.severity == "error" else "CẢNH BÁO"
            lines.append(f"- **[{tag}]** `{_md_cell(iv.file)}:{iv.line}` — {_md_cell(iv.message_vi)}")
    lines.append("")

    if res.multi_coach_set_count > 0 and res.preferred_coach:
        lines.append(
            f"> **Ghi chú đa giám khảo:** Có **{res.multi_coach_set_count}** hiệp tập được gán nhãn bởi "
            f"từ 2 HLV trở lên. Để không nhân đôi cỡ mẫu trong các bảng Đối chiếu Ứng dụng – HLV, "
            f"mỗi hiệp vật lý dùng nhãn của HLV tham chiếu chính **`{_md_cell(res.preferred_coach)}`**; "
            f"toàn bộ các cặp nhãn trùng hiệp được dùng trong Mục 5 (Độ đồng thuận giữa các HLV)."
        )
        lines.append("")

    # 1. Definitions
    lines.append("## 1. Định nghĩa và quy tắc tính toán")
    lines.append("")
    lines.append(
        f"- **Đơn vị lần tập (`rep`):** Với `squat`, `push_up`, `glute_bridge`, 1 `rep` là 1 lần thực hiện "
        f"động tác hoàn chỉnh. Với `plank`, 1 `rep` là 1 lần giữ tư thế hoàn chỉnh đủ 15 giây. "
        f"Các dòng HLV ghi `counted = 1` là lần tập hợp lệ; `counted = 0` là lần thử dở dang/không tính."
    )
    lines.append(
        f"- **Ghép cặp lần tập (Matching):** Trong cùng `(participant_id, condition, exercise_id, set_index)`, "
        f"các lần tập hợp lệ của HLV (`counted = 1`) được ghép giữ nguyên thứ tự thời gian với sự kiện `rep` của "
        f"ứng dụng. Khi có cả `video_t_s` và `sync_beep_t_ms`, thời gian ứng dụng được tính bằng "
        f"`(t_ms - sync_beep_t_ms) / 1000` giây và ghép tối ưu trong dung sai **±{res.tolerance_s:.1f} giây** "
        f"(tối đa hóa số cặp khớp, sau đó tối thiểu hóa tổng sai lệch thời gian `|Δt|`, nếu vẫn hòa thì ưu tiên lần tập sớm hơn). "
        f"Khi chỉ một phần dòng có thời gian, các dòng bỏ trống được ràng buộc trong khoảng thời gian của hai mốc lân cận "
        f"rồi ghép theo thứ tự; khi thiếu toàn bộ mốc thời gian thì chuyển sang ghép theo thứ tự xuất hiện. "
        f"Lần tập HLV không có `rep` ứng dụng là **bỏ sót (missed)**; "
        f"`rep` ứng dụng không có lần tập HLV hợp lệ là **đếm ma (phantom)**."
    )
    lines.append(
        "- **Precision, Recall, tỷ lệ báo lỗi thừa & khoảng tin cậy:** Tính trên các lần tập **đã ghép cặp (`matched`)** cho từng mã lỗi. "
        "`Precision = TP / (TP + FP)` (`n_app_pos = TP + FP`), `Recall = TP / (TP + FN)` "
        "(`n_coach_pos = TP + FN`), tỷ lệ báo lỗi giả trên các lần tập không có lỗi đó theo HLV "
        "`FPR = FP / (FP + TN)` (`n_coach_neg = FP + TN`), tần suất báo lỗi thừa trên tổng rep khớp `FP / N`, "
        "và tỷ lệ báo nhầm trong các lần ứng dụng báo lỗi `1 - Precision = FP / (TP + FP)`, kèm **khoảng tin cậy Wilson 95%** hai phía."
    )
    lines.append(
        "- **Ma trận nhầm lẫn theo bài tập:** Mỗi lần tập đã ghép cặp được phân vào đúng một hàng (tập lỗi của HLV, "
        "hoặc `clean` nếu không có lỗi) và một cột (tập lỗi của ứng dụng, hoặc `clean`), bảo toàn tổng số lần tập bằng đúng `n_matched_reps`."
    )
    lines.append(
        "- **Sửa lỗi sau lời nhắc (`cue`):** Chỉ tính các sự kiện `cue` thực sự phát âm thanh (`played = true`) làm lời nhắc bằng giọng nói "
        "(các sự kiện `played = false` ở điều kiện đối chứng `control` được tách riêng để đối chiếu). "
        "Với lời nhắc phát ngay trong lúc đang thực hiện một lần tập có lỗi trực tiếp (`fault_start..fault_end`), mốc đánh giá được đặt ngay sau khi lần tập đang dở đó kết thúc. "
        "Một lời nhắc mang mã lỗi `F` được coi là **được sửa ở lần kế tiếp (next 1)** nếu lần tập kế tiếp sau mốc đánh giá không còn lỗi `F`, "
        "và **được sửa ở cả 2 lần kế tiếp (next 2)** nếu cả 2 lần tập kế tiếp đều không còn lỗi `F`."
    )
    lines.append(
        "- **So sánh Có phản hồi (`ai`) và Không phản hồi (`control`):** Tỷ lệ lỗi trên mỗi lần tập của từng người được tính bằng "
        "`số lần tập hợp lệ có ít nhất 1 lỗi (theo HLV) / tổng số lần tập hợp lệ (theo HLV)`. "
        "Để tránh sai lệch trộn bài tập khi một bài chỉ xuất hiện ở một điều kiện, chênh lệch ghép cặp tổng thể của từng người "
        "(`tỷ_lệ_ai - tỷ_lệ_control`) chỉ tính trên các bài tập người đó có ít nhất 1 lần tập hợp lệ ở **cả hai** điều kiện "
        "(giá trị âm nghĩa là giảm lỗi khi có phản hồi Vika)."
    )
    lines.append(
        "- **Tốc độ khung hình (FPS):** Thống kê trung bình và mức thấp nhất của `frames.mean_fps` và `frames.min_fps_1s` theo bài tập; "
        "loại trừ các tệp thoát sớm có `duration_ms <= 0` hoặc chưa đủ cửa sổ 1 giây nguyên vẹn (`duration_ms < 1000 ms`) khỏi phép tính `min_fps_1s`."
    )
    lines.append("")

    # 2. Counting accuracy
    lines.append("## 2. Độ chính xác đếm số lần tập / lần giữ tư thế")
    lines.append("")
    lines.append(
        "| Bài tập | Số hiệp (`n_sets`) | Lần hợp lệ HLV | Lần thử HLV không tính (`counted=0`) | Lần ứng dụng đếm | Khớp (`matched`) | Bỏ sót (`missed`) | Đếm ma (`phantom`) |"
    )
    lines.append("|---|---:|---:|---:|---:|---:|---:|---:|")
    for r in res.counting_accuracy_rows:
        ex_lbl = (
            "**Tổng cộng**"
            if r["exercise_id"] == "overall"
            else f"`{r['exercise_id']}` ({EXERCISE_NAMES_VI.get(r['exercise_id'], r['exercise_id'])})"
        )
        lines.append(
            f"| {ex_lbl} | {r['n_sets']} | {r['coach_valid_reps']} | "
            f"{r['coach_uncounted_attempts']} | {r['app_reps']} | {r['matched']} | "
            f"{r['missed']} | {r['phantom']} |"
        )
    lines.append("")

    # 3. Fault detection & Confusion matrices
    lines.append("## 3. Độ chính xác phát hiện lỗi tư thế & Ma trận nhầm lẫn")
    lines.append("")
    lines.append("### 3.1. Precision, Recall (khoảng tin cậy Wilson 95%) và tần suất báo lỗi thừa")
    lines.append("")
    if res.unjudged_rep_count:
        lines.append(
            f"> {res.unjudged_rep_count} rep có `form_judged = false` (người tập đã bấm \"Bỏ qua cảnh báo\", "
            "ứng dụng chỉ đếm, không chấm) được loại khỏi precision/recall; số rep này vẫn tính trong độ chính xác đếm."
        )
        lines.append("")
    lines.append(
        "> Cột bootstrap: khoảng 95% khi lấy mẫu lại theo **người tập** "
        f"({BOOTSTRAP_RESAMPLES} lần, hạt giống {BOOTSTRAP_SEED}), vì các rep của cùng một người không độc lập. "
        "Để trống khi chỉ có 1 người."
    )
    lines.append("")
    no_data_ex = [
        r["exercise_id"]
        for r in res.fault_detection_rows
        if r["fault_id"] == "ANY_FAULT" and int(r["n_matched_reps"]) == 0
    ]
    if no_data_ex:
        lines.append(
            "Chưa có rep khớp giữa ứng dụng và HLV (bỏ khỏi bảng dưới): "
            + ", ".join(f"`{ex}`" for ex in no_data_ex)
            + "."
        )
        lines.append("")
    lines.append(
        "| Bài tập | Mã lỗi | Số người | Số lần khớp (`N`) | TP | FP (App báo, HLV không thấy) | FN | TN | Precision [CI 95%] (`TP/n_app`) | Recall [CI 95%] (`TP/n_hlv`) | Precision / Recall [bootstrap theo người] | Báo lỗi giả trên rep không lỗi HLV (`FP/(FP+TN)`) | Báo lỗi thừa / rep (`FP/N`) |"
    )
    lines.append("|---|---|---:|---:|---:|---:|---:|---:|---|---|---|---|---|")
    for r in res.fault_detection_rows:
        if int(r["n_matched_reps"]) == 0:
            continue
        fault_disp = "**Bất kỳ lỗi nào (`ANY_FAULT`)**" if r["fault_id"] == "ANY_FAULT" else f"`{r['fault_id']}`"
        prec_cell = _fmt_rate_with_ci_vi(
            r["precision"],
            r["precision_ci95_low"],
            r["precision_ci95_high"],
            int(r["tp"]),
            int(r["n_app_positive"]),
        )
        rec_cell = _fmt_rate_with_ci_vi(
            r["recall"],
            r["recall_ci95_low"],
            r["recall_ci95_high"],
            int(r["tp"]),
            int(r["n_coach_positive"]),
        )
        n_m = int(r["n_matched_reps"])
        fp_cnt = int(r["fp"])
        fpr_cell = _fmt_rate_with_ci_vi(
            r["false_positive_rate"],
            r["false_positive_rate_ci95_low"],
            r["false_positive_rate_ci95_high"],
            fp_cnt,
            int(r["n_coach_negative"]),
        )
        fp_rate_s = (
            f"{(_opt_float_str(r['fp_per_matched_rep']) or 0.0) * 100:.1f}% ({fp_cnt}/{n_m})"
            if n_m > 0
            else "— (0/0)"
        )
        boot_cell = _fmt_boot_pair_vi(r)
        lines.append(
            f"| `{r['exercise_id']}` | {fault_disp} | {r.get('n_participants', '')} | {n_m} | {r['tp']} | {fp_cnt} | "
            f"{r['fn']} | {r['tn']} | {prec_cell} | {rec_cell} | {boot_cell} | {fpr_cell} | {fp_rate_s} |"
        )
    lines.append("")

    lines.append("### 3.2. Ma trận nhầm lẫn theo từng bài tập (Hàng = Nhãn HLV, Cột = Nhãn Ứng dụng)")
    lines.append("")
    for ex_id in KNOWN_EXERCISES:
        n_matched, axis_labels, grid = res.confusion_grids[ex_id]
        if n_matched == 0:
            continue
        lines.append(
            f"#### Bài `{ex_id}` ({EXERCISE_NAMES_VI.get(ex_id, ex_id)}) — Cỡ mẫu `N = {n_matched}` lần tập khớp"
        )
        lines.append("")
        header_cols = " | ".join(f"App: `{lbl}`" for lbl in axis_labels)
        sep_cols = " | ".join("---:" for _ in axis_labels)
        lines.append(f"| Nhãn HLV \\ App | {header_cols} | Tổng HLV |")
        lines.append(f"|---| {sep_cols} |---:|")
        for c_lbl in axis_labels:
            row_vals = [grid[(c_lbl, a_lbl)] for a_lbl in axis_labels]
            row_sum = sum(row_vals)
            vals_str = " | ".join(str(v) for v in row_vals)
            lines.append(f"| **`{c_lbl}`** | {vals_str} | **{row_sum}** |")
        col_sums = [sum(grid[(c_lbl, a_lbl)] for c_lbl in axis_labels) for a_lbl in axis_labels]
        col_sums_str = " | ".join(f"**{v}**" for v in col_sums)
        lines.append(f"| **Tổng App** | {col_sums_str} | **{n_matched}** |")
        lines.append("")

    if res.condition_factors:
        lines.append("### 3.3. Độ chính xác theo điều kiện quay (`session_conditions.csv`)")
        lines.append("")
        lines.append(
            "Mỗi dòng là một mức của một yếu tố (góc máy, ánh sáng, quần áo, thiết bị…). "
            "Chỉ hiện `ANY_FAULT` của mọi bài và từng lỗi của plank; đủ các lỗi có trong "
            "`fault_detection_by_condition.csv`."
        )
        lines.append("")
        lines.append(
            "| Yếu tố | Mức | Bài tập | Mã lỗi | Số người | `N` | TP | FP | FN | Precision [CI 95%] | Recall [CI 95%] |"
        )
        lines.append("|---|---|---|---|---:|---:|---:|---:|---:|---|---|")
        for r in res.fault_condition_rows:
            if r["fault_id"] != "ANY_FAULT" and r["exercise_id"] != "plank":
                continue
            prec_cell = _fmt_rate_with_ci_vi(
                r["precision"], r["precision_ci95_low"], r["precision_ci95_high"],
                int(r["tp"]), int(r["n_app_positive"]),
            )
            rec_cell = _fmt_rate_with_ci_vi(
                r["recall"], r["recall_ci95_low"], r["recall_ci95_high"],
                int(r["tp"]), int(r["n_coach_positive"]),
            )
            lines.append(
                f"| {r['factor']} | {r['level']} | `{r['exercise_id']}` | `{r['fault_id']}` | "
                f"{r['n_participants']} | {r['n_matched_reps']} | {r['tp']} | {r['fp']} | {r['fn']} | "
                f"{prec_cell} | {rec_cell} |"
            )
        lines.append("")

    # 4. Wrong detections
    lines.append("## 4. Danh sách các lần phát hiện sai giữa Ứng dụng và HLV")
    lines.append("")
    lines.append(
        f"Tổng số lần tập đã ghép cặp có bất đồng nhãn lỗi: **{len(res.wrong_detection_rows)}** "
        f"(danh sách đầy đủ trong `wrong_detections.csv`)."
    )
    lines.append("")
    if res.wrong_detection_rows:
        max_preview = 30
        lines.append(
            "| Người tập | ĐK | Bài tập | Hiệp | Rep (HLV / App) | Giây video (`video_t_s`) | Giây App sau beep | Nhãn HLV | Nhãn App | FP (App thừa) | FN (App sót) | Tệp log |"
        )
        lines.append("|---|---|---|---:|---|---:|---:|---|---|---|---|---|")
        for r in res.wrong_detection_rows[:max_preview]:
            vt = r["video_t_s"] if r["video_t_s"] != "" else "—"
            at = r["app_rel_t_s"] if r["app_rel_t_s"] != "" else "—"
            fp_s = f"`{r['false_positives']}`" if r["false_positives"] else "—"
            fn_s = f"`{r['false_negatives']}`" if r["false_negatives"] else "—"
            lines.append(
                f"| `{_md_cell(r['participant_id'])}` | `{r['condition']}` | `{r['exercise_id']}` | "
                f"{r['set_index']} | {r['coach_rep_n']} / {r['app_rep_n']} | {vt} | {at} | "
                f"`{r['coach_faults']}` | `{r['app_faults']}` | {fp_s} | {fn_s} | `{_md_cell(r['log_file'])}` |"
            )
        if len(res.wrong_detection_rows) > max_preview:
            lines.append("")
            lines.append(
                f"*Hiển thị {max_preview}/{len(res.wrong_detection_rows)} dòng đầu tiên; xem toàn bộ trong `wrong_detections.csv`.*"
            )
    lines.append("")

    # 5. Coach agreement
    lines.append("## 5. Độ đồng thuận giữa các Huấn luyện viên (Ceiling / Cohen's κ)")
    lines.append("")
    if not res.coach_agreement_rows:
        lines.append(
            "- Không có hiệp tập nào được gán nhãn trùng bởi từ 2 HLV trở lên nên không tính hệ số đồng thuận Cohen's κ."
        )
    else:
        lines.append(
            "| Cặp HLV | Bài tập | Mã lỗi | Số hiệp trùng | Số lần khớp (`N`) | Cùng có (`++`) | Chỉ HLV A (`+-`) | Chỉ HLV B (`-+`) | Cùng không (`--`) | Đồng thuận (%) | Cohen's κ |"
        )
        lines.append("|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|")
        for r in res.coach_agreement_rows:
            agr_s = fmt_pct_vi(_opt_float_str(r["percent_agreement"]))
            kap = _opt_float_str(r["cohen_kappa"])
            if kap is not None:
                if abs(kap) < 1e-12:
                    kap = 0.0
                kap_s = f"{kap:.3f}"
            elif r["kappa_note"] == "undefined_degenerate_marginals":
                kap_s = "KĐ (biên suy biến)"
            else:
                kap_s = "—"
            f_disp = "**`ANY_FAULT`**" if r["fault_id"] == "ANY_FAULT" else f"`{r['fault_id']}`"
            lines.append(
                f"| `{_md_cell(r['coach_a'])}` vs `{_md_cell(r['coach_b'])}` | `{r['exercise_id']}` | {f_disp} | "
                f"{r['n_shared_sets']} | {r['n_matched_valid_reps']} | {r['both_positive']} | "
                f"{r['coach_a_only_positive']} | {r['coach_b_only_positive']} | {r['both_negative']} | "
                f"{agr_s} | {kap_s} |"
            )
    lines.append("")

    # 6. Unseen time
    lines.append("## 6. Thời gian ứng dụng không nhìn rõ người tập (Unseen Time)")
    lines.append("")
    lines.append("### 6.1. Tổng hợp `summary.unseen_ms / summary.active_ms` theo bài tập")
    lines.append("")
    lines.append(
        "| Bài tập | Số hiệp (`n_sets`) | Thời gian hoạt động (`active_ms`) | Thời gian khuất/mờ (`unseen_ms`) | Tỷ lệ `unseen / active` | Thời gian tạm dừng (`paused_ms`) |"
    )
    lines.append("|---|---:|---:|---:|---:|---:|")
    for r in res.unseen_time_rows:
        ex_lbl = "**Tổng cộng**" if r["exercise_id"] == "overall" else f"`{r['exercise_id']}`"
        ratio_s = fmt_pct_vi(_opt_float_str(r["unseen_over_active_ratio"]))
        lines.append(
            f"| {ex_lbl} | {r['n_sets']} | {r['active_ms']} ms | {r['unseen_ms']} ms | "
            f"{ratio_s} | {r['paused_ms']} ms |"
        )
    lines.append("")

    lines.append("### 6.2. Phân rã nguyên nhân không nhìn rõ (`reason`) từ chuỗi sự kiện")
    lines.append("")
    active_reasons = [r for r in res.unseen_reason_rows if r["phase"] == "active"]
    setup_reasons = [r for r in res.unseen_reason_rows if r["phase"] != "active"]
    if not active_reasons and not setup_reasons:
        lines.append("- Không ghi nhận sự kiện `unseen_start` nào trong các tệp log.")
    else:
        lines.append(
            "| Bài tập | Pha (`phase`) | Nguyên nhân (`reason`) | Số hiệp gặp | Số lần xuất hiện | Tổng thời lượng (ms) | Tỷ trọng trên `active_ms` | Tỷ trọng trong pha |"
        )
        lines.append("|---|---|---|---:|---:|---:|---:|---:|")
        for r in res.unseen_reason_rows:
            ex_lbl = "**Tổng cộng**" if r["exercise_id"] == "overall" else f"`{r['exercise_id']}`"
            sh_act = fmt_pct_vi(_opt_float_str(r["share_of_active_ms"]))
            sh_ph = fmt_pct_vi(_opt_float_str(r["share_of_phase_unseen_ms"]))
            lines.append(
                f"| {ex_lbl} | `{_md_cell(r['phase'])}` | `{_md_cell(r['reason'])}` | "
                f"{r['n_sets_with_reason']}/{r['n_total_sets']} | {r['event_count']} | "
                f"{r['duration_ms']} ms | {sh_act} | {sh_ph} |"
            )
    lines.append("")

    lines.append("### 6.3. Nút \"Báo sai\" của người tập so với nhãn HLV (điều kiện `ai`)")
    lines.append("")
    lines.append(
        "Mỗi dòng của `fault_reports.csv` là một cặp (hiệp, lỗi app phát hiện). \"App báo thừa\" nghĩa là "
        "trên các rep đã khớp mà app gắn lỗi đó, HLV không thấy lỗi ở rep nào."
    )
    lines.append("")
    if not res.fault_report_rows:
        lines.append("- Không có cặp (hiệp, lỗi) nào ở điều kiện `ai`.")
    else:
        lines.append(
            "| Nhóm | Số cặp (hiệp, lỗi) | Đối chiếu được với HLV | App báo thừa (Wilson 95%) | Một phần | HLV thấy lỗi |"
        )
        lines.append("|---|---:|---:|---:|---:|---:|")
        for flag, label in ((1, "Người tập bấm Báo sai"), (0, "Không bấm")):
            grp = [r for r in res.fault_report_rows if r["reported"] == flag]
            judged = [
                r for r in grp if r["verdict"] in ("app_false_alarm", "mixed", "coach_confirmed")
            ]
            k = sum(1 for r in judged if r["verdict"] == "app_false_alarm")
            lo, hi = wilson_ci(k, len(judged))
            rate = (k / len(judged)) if judged else None
            mixed = sum(1 for r in judged if r["verdict"] == "mixed")
            conf = sum(1 for r in judged if r["verdict"] == "coach_confirmed")
            lines.append(
                f"| {label} | {len(grp)} | {len(judged)} | "
                f"{_fmt_rate_with_ci_vi(rate, lo, hi, k, len(judged))} | {mixed} | {conf} |"
            )
    lines.append("")

    # 7. Does feedback help
    lines.append("## 7. Đánh giá hiệu quả phản hồi của Vika")
    lines.append("")
    ms = res.cue_mapping_summary
    lines.append("### 7.1. Sửa lỗi ngay sau lời nhắc giọng nói (`cue`)")
    lines.append("")
    lines.append(
        f"- **Kiểm toán ánh xạ mã lỗi trên sự kiện `cue`:** "
        f"Trong **{ms['played_total']}** sự kiện `cue` đã phát âm thanh (`played = true`), có "
        f"**{ms['played_from_log_fault']}** sự kiện có sẵn trường `fault` trong log, "
        f"**{ms['played_from_cue_map']}** sự kiện được ánh xạ qua tệp `--cue-map`, "
        f"**{ms['played_explicit_non_fault']}** sự kiện được đánh dấu không phải lỗi tư thế, và "
        f"**{ms['played_unmapped']}** sự kiện **không ánh xạ được sang mã lỗi** "
        f"(tổng tính cả `played = false`: **{ms['played_unmapped'] + ms['suppressed_unmapped']}** sự kiện không ánh xạ được trên "
        f"**{ms['played_total'] + ms['suppressed_total']}** sự kiện `cue`)."
    )
    if ms["unmapped_played_keys"]:
        top_unmapped = ", ".join(
            f"`{_md_cell(k)}` ({cnt})" for k, cnt in list(ms["unmapped_played_keys"].items())[:10]
        )
        lines.append(f"- Các khóa `key` (`played = true`) chưa ánh xạ sang mã lỗi: {top_unmapped}.")
    if not res.cue_map_used and ms["played_unmapped"] > 0:
        lines.append(
            "- *Gợi ý:* Có sự kiện `cue` thiếu trường `fault` khi chưa truyền `--cue-map`; "
            "hãy chạy kèm `--cue-map tools/eval/cue_fault_map.csv` để ánh xạ khóa giọng nói sang mã lỗi."
        )
    lines.append("")
    lines.append(
        "| Đã phát (`played`) | Bài tập | Mã lỗi | Tổng số `cue` | Sửa ở rep kế tiếp — Theo HLV (`k/n`) | Sửa ở cả 2 rep kế tiếp — Theo HLV (`k/n`) | Sửa ở rep kế tiếp — Theo App (`k/n`) | Sửa ở cả 2 rep kế tiếp — Theo App (`k/n`) |"
    )
    lines.append("|---|---|---|---:|---|---|---|---|")
    for r in res.cue_correction_rows:
        pl_lbl = "Có phát (`true`)" if r["played"] == "true" else "Ẩn/Đối chứng (`false`)"
        ex_lbl = "**Tổng cộng**" if r["exercise_id"] == "overall" else f"`{r['exercise_id']}`"
        c1 = _fmt_rate_with_ci_vi(
            r["rate_next1_coach"],
            r["ci95_low_next1_coach"],
            r["ci95_high_next1_coach"],
            int(r["corrected_next1_coach"]),
            int(r["n_with_next1_coach"]),
        )
        c2 = _fmt_rate_with_ci_vi(
            r["rate_next2_coach"],
            r["ci95_low_next2_coach"],
            r["ci95_high_next2_coach"],
            int(r["corrected_next2_coach"]),
            int(r["n_with_next2_coach"]),
        )
        a1 = _fmt_rate_with_ci_vi(
            r["rate_next1_app"],
            r["ci95_low_next1_app"],
            r["ci95_high_next1_app"],
            int(r["corrected_next1_app"]),
            int(r["n_with_next1_app"]),
        )
        a2 = _fmt_rate_with_ci_vi(
            r["rate_next2_app"],
            r["ci95_low_next2_app"],
            r["ci95_high_next2_app"],
            int(r["corrected_next2_app"]),
            int(r["n_with_next2_app"]),
        )
        lines.append(
            f"| {pl_lbl} | {ex_lbl} | `{r['fault_id']}` | {r['n_cues']} | "
            f"{c1} | {c2} | {a1} | {a2} |"
        )
    lines.append("")

    # 7.2 AI vs Control
    lines.append("### 7.2. So sánh có phản hồi (`ai`) và không phản hồi (`control`) theo nhãn HLV")
    lines.append("")
    lines.append("#### Tổng hợp theo bài tập và toàn bộ")
    lines.append("")
    lines.append(
        "| Phạm vi | Tỷ lệ rep lỗi `control` (`lỗi/tổng`, `n_người`) | Tỷ lệ rep lỗi `ai` (`lỗi/tổng`, `n_người`) | Số người đủ cặp (`n_paired`) | Chênh lệch ghép cặp TB `ai - control` | Trung vị `ai - control` | Cải thiện / Tệ hơn / Giữ nguyên | Kiểm định dấu hai phía (kèm cỡ mẫu) |"
    )
    lines.append("|---|---|---|---:|---:|---:|---|---|")
    for r in res.ai_vs_control_summary_rows:
        ex_lbl = "**Toàn bộ bài tập**" if r["exercise_id"] == "overall" else f"`{r['exercise_id']}`"
        c_rt = _opt_float_str(r["pooled_control_fault_rate"])
        a_rt = _opt_float_str(r["pooled_ai_fault_rate"])
        c_cell = (
            f"{c_rt * 100:.1f}% ({r['control_faulty_reps']}/{r['control_valid_reps']}, n={r['n_participants_control']})"
            if c_rt is not None
            else f"— (0/0, n={r['n_participants_control']})"
        )
        a_cell = (
            f"{a_rt * 100:.1f}% ({r['ai_faulty_reps']}/{r['ai_valid_reps']}, n={r['n_participants_ai']})"
            if a_rt is not None
            else f"— (0/0, n={r['n_participants_ai']})"
        )
        md = _opt_float_str(r["mean_paired_diff_ai_minus_control"])
        med = _opt_float_str(r["median_paired_diff"])
        if md is not None and abs(md) < 1e-12:
            md = 0.0
        if med is not None and abs(med) < 1e-12:
            med = 0.0
        md_s = f"{md * 100:+.1f} điểm %" if md is not None else "—"
        med_s = f"{med * 100:+.1f} điểm %" if med is not None else "—"
        pval = _opt_float_str(r["sign_test_p_two_sided"])
        n_paired = int(r["n_paired_participants"])
        n_nontied = int(r["sign_test_n_non_tied"])
        p_cell = (
            f"p = {pval:.4f} (n_đổi = {n_nontied}, n_cặp = {n_paired})"
            if pval is not None
            else f"— (n_đổi = 0, n_cặp = {n_paired})"
        )
        lines.append(
            f"| {ex_lbl} | {c_cell} | {a_cell} | {n_paired} | {md_s} | {med_s} | "
            f"{r['n_improved']} / {r['n_worsened']} / {r['n_same']} | {p_cell} |"
        )
    lines.append("")

    if res.ai_vs_control_participant_rows:
        lines.append("#### Chi tiết theo từng người tập")
        lines.append("")
        lines.append(
            "| Người tập | Bài tập đủ cặp | Tất cả bài `control` (`lỗi/tổng`) | Tất cả bài `ai` (`lỗi/tổng`) | Bài đủ cặp `control` (`lỗi/tổng`) | Bài đủ cặp `ai` (`lỗi/tổng`) | Chênh lệch ghép cặp `ai - control` | Kết luận |"
        )
        lines.append("|---|---|---|---|---|---|---:|---|")
        outcome_vi = {
            "improved": "Cải thiện (giảm lỗi)",
            "worsened": "Tệ hơn (tăng lỗi)",
            "same": "Giữ nguyên",
            "incomplete_pair": "Thiếu bài tập chung",
        }
        any_unbalanced = False
        for r in res.ai_vs_control_participant_rows:
            c_v = int(r["control_valid_reps"])
            a_v = int(r["ai_valid_reps"])
            pc_v = int(r["paired_control_valid_reps"])
            pa_v = int(r["paired_ai_valid_reps"])
            c_rt = fmt_pct_vi(_opt_float_str(r["control_fault_rate"]))
            a_rt = fmt_pct_vi(_opt_float_str(r["ai_fault_rate"]))
            pc_rt = fmt_pct_vi(_opt_float_str(r["paired_control_fault_rate"]))
            pa_rt = fmt_pct_vi(_opt_float_str(r["paired_ai_fault_rate"]))
            all_c_cell = f"{c_rt} ({r['control_faulty_reps']}/{c_v})" if c_v > 0 else "— (0/0)"
            all_a_cell = f"{a_rt} ({r['ai_faulty_reps']}/{a_v})" if a_v > 0 else "— (0/0)"
            p_c_cell = (
                f"{pc_rt} ({r['paired_control_faulty_reps']}/{pc_v})" if pc_v > 0 else "— (0/0)"
            )
            p_a_cell = f"{pa_rt} ({r['paired_ai_faulty_reps']}/{pa_v})" if pa_v > 0 else "— (0/0)"
            df = _opt_float_str(r["paired_diff_ai_minus_control"])
            if df is not None and abs(df) < 1e-12:
                df = 0.0
            df_s = f"{df * 100:+.1f} điểm %" if df is not None else "—"
            paired_ex_s = f"`{r['paired_exercises']}`" if r["paired_exercises"] else "—"
            if r["paired_exercises"] and r["exercises_balanced"] == "false":
                any_unbalanced = True
                paired_ex_s += " *"
            lines.append(
                f"| `{_md_cell(r['participant_id'])}` | {paired_ex_s} | {all_c_cell} | "
                f"{all_a_cell} | {p_c_cell} | {p_a_cell} | {df_s} | "
                f"{outcome_vi.get(r['outcome'], r['outcome'])} |"
            )
        if any_unbalanced:
            lines.append("")
            lines.append(
                "*(\\*) Người tập có danh mục bài tập không cân bằng giữa `control` và `ai`; "
                "hai cột `Bài đủ cặp control` và `Bài đủ cặp ai` thể hiện đúng phân số dùng để tính `Chênh lệch ghép cặp ai - control`.*"
            )
        lines.append("")

    # 7.3 Candidate sets
    lines.append("### 7.3. Các hiệp tiêu biểu để minh họa (Một thành công & Một thất bại)")
    lines.append("")
    succ = [r for r in res.cue_candidate_rows if r["candidate_type"] == "success"]
    fail = [r for r in res.cue_candidate_rows if r["candidate_type"] == "failure"]
    if not succ and not fail:
        lines.append("- Chưa có hiệp tập nào đủ điều kiện (có lời nhắc lỗi `played = true` và còn ít nhất 1 lần tập phía sau).")
    else:
        lines.append(
            "| Phân loại | Người tập | ĐK | Bài tập | Hiệp | Mã lỗi nhắc | Số lần nhắc | Mốc `cue` đầu (ms) | Số rep sau `cue` | Rep còn lỗi (HLV / App) | Cơ sở xác nhận | Tệp log |"
        )
        lines.append("|---|---|---|---|---:|---|---:|---:|---:|---|---|---|")
        for r in succ[:5] + fail[:5]:
            cat_vi = (
                "Thành công (sửa được lỗi)"
                if r["candidate_type"] == "success"
                else (
                    "Thất bại (nhắc lặp lại, không sửa)"
                    if r["cue_repeated"]
                    else "Thất bại (nhắc 1 lần, không sửa)"
                )
            )
            c_after = r["faulty_reps_after_coach"] if r["faulty_reps_after_coach"] != "" else "—"
            lines.append(
                f"| {cat_vi} | `{_md_cell(r['participant_id'])}` | `{r['condition']}` | `{r['exercise_id']}` | "
                f"{r['set_index']} | `{r['fault_id']}` | {r['played_cue_count']} | "
                f"{r['first_cue_t_ms']} | {r['reps_after_first_cue']} | "
                f"{c_after} / {r['faulty_reps_after_app']} | `{r['basis']}` | `{_md_cell(r['log_file'])}` |"
            )
    lines.append("")

    # 7.4 False-alarm rate (app raises a fault the coach does not see)
    lines.append("### 7.4. Tần suất ứng dụng báo lỗi mà HLV không thấy (Báo lỗi thừa — False Alarms)")
    lines.append("")
    any_fault_rows = [r for r in res.fault_detection_rows if r["fault_id"] == "ANY_FAULT"]
    total_matched_all = sum(int(r["n_matched_reps"]) for r in any_fault_rows)
    if total_matched_all <= 0:
        lines.append("- Chưa có lần tập ghép cặp nào để thống kê tần suất báo lỗi thừa.")
    else:
        reps_with_specific_fp = sum(
            1 for r in res.wrong_detection_rows if r["false_positives"]
        )
        sp_lo, sp_hi = wilson_ci(reps_with_specific_fp, total_matched_all)
        sp_str = _fmt_rate_with_ci_vi(
            reps_with_specific_fp / total_matched_all,
            sp_lo,
            sp_hi,
            reps_with_specific_fp,
            total_matched_all,
        )
        total_coach_clean = sum(int(r["n_coach_negative"]) for r in any_fault_rows)
        clean_flagged = sum(int(r["fp"]) for r in any_fault_rows)
        cl_lo, cl_hi = wilson_ci(clean_flagged, total_coach_clean)
        cl_str = _fmt_rate_with_ci_vi(
            clean_flagged / total_coach_clean if total_coach_clean > 0 else None,
            cl_lo,
            cl_hi,
            clean_flagged,
            total_coach_clean,
        )
        lines.append(
            f"- **Trên tổng số lần tập khớp (`N = {total_matched_all}`):** Ứng dụng báo ít nhất 1 mã lỗi "
            f"mà HLV không thấy ở **{sp_str}** lần tập."
        )
        lines.append(
            f"- **Trên các lần tập HLV chấm hoàn toàn chuẩn không lỗi (`n_hlv_sạch = {total_coach_clean}`):** "
            f"Ứng dụng báo nhầm có lỗi ở **{cl_str}** lần tập."
        )
        lines.append("")
        lines.append(
            "| Bài tập | Mã lỗi | Số lần khớp (`N`) | FP (App báo, HLV không thấy) | Trên rep không lỗi HLV (`FP/(FP+TN)`) [CI 95%] | Trên tổng rep khớp (`FP/N`) | Trong các lần App báo lỗi (`1 - Precision = FP/n_app`) |"
        )
        lines.append("|---|---|---:|---:|---|---|---|")
        for r in res.fault_detection_rows:
            n_m = int(r["n_matched_reps"])
            if n_m <= 0:
                continue
            fault_disp = (
                "**Bất kỳ lỗi nào (`ANY_FAULT`)**"
                if r["fault_id"] == "ANY_FAULT"
                else f"`{r['fault_id']}`"
            )
            fp_cnt = int(r["fp"])
            n_app_pos = int(r["n_app_positive"])
            fpr_cell = _fmt_rate_with_ci_vi(
                r["false_positive_rate"],
                r["false_positive_rate_ci95_low"],
                r["false_positive_rate_ci95_high"],
                fp_cnt,
                int(r["n_coach_negative"]),
            )
            fp_n_cell = f"{(_opt_float_str(r['fp_per_matched_rep']) or 0.0) * 100:.1f}% ({fp_cnt}/{n_m})"
            fdr_lo, fdr_hi = wilson_ci(fp_cnt, n_app_pos)
            fdr_cell = _fmt_rate_with_ci_vi(
                fp_cnt / n_app_pos if n_app_pos > 0 else None,
                fdr_lo,
                fdr_hi,
                fp_cnt,
                n_app_pos,
            )
            lines.append(
                f"| `{r['exercise_id']}` | {fault_disp} | {n_m} | {fp_cnt} | "
                f"{fpr_cell} | {fp_n_cell} | {fdr_cell} |"
            )
    lines.append("")

    # 7.5 Satisfaction
    lines.append("### 7.5. Mức độ hài lòng của người tập (`satisfaction` thang 1–5)")
    lines.append("")
    lines.append(
        "| Điều kiện | Tổng số phiên (`n_sessions`) | Số phản hồi (`n_responses`) | Bỏ trống | Trung bình ± ĐLC | Trung vị | Phân phối điểm (1 / 2 / 3 / 4 / 5) |"
    )
    lines.append("|---|---:|---:|---:|---|---:|---|")
    for r in res.satisfaction_rows:
        cond_lbl = "**Tổng cộng**" if r["condition"] == "overall" else f"`{r['condition']}`"
        m = _opt_float_str(r["mean_satisfaction"])
        sd = _opt_float_str(r["sd_satisfaction"])
        med = _opt_float_str(r["median_satisfaction"])
        if m is None:
            m_cell = "—"
        elif sd is not None:
            m_cell = f"{m:.2f} ± {sd:.2f}"
        else:
            m_cell = f"{m:.2f}"
        med_s = f"{med:.1f}" if med is not None else "—"
        dist_s = f"{r['count_1']} / {r['count_2']} / {r['count_3']} / {r['count_4']} / {r['count_5']}"
        lines.append(
            f"| {cond_lbl} | {r['n_sessions_total']} | {r['n_responses']} | {r['n_missing']} | "
            f"{m_cell} | {med_s} | {dist_s} |"
        )
    lines.append("")

    # 8. Frame rate
    lines.append("## 8. Tốc độ khung hình xử lý (Frame Rate — FPS)")
    lines.append("")
    lines.append(
        "| Bài tập | Số hiệp có FPS (`n_sets`) | `mean_fps` trung bình | `mean_fps` thấp nhất (tệp) | `min_fps_1s` trung bình | `min_fps_1s` thấp nhất (tệp) | Khoảng trễ khung lớn nhất (`max_gap_ms`) |"
    )
    lines.append("|---|---:|---:|---|---:|---|---:|")
    for r in res.frame_rate_rows:
        ex_lbl = "**Tổng cộng**" if r["exercise_id"] == "overall" else f"`{r['exercise_id']}`"
        wm = (
            f"{r['worst_mean_fps']} (`{_md_cell(r['worst_mean_fps_file'])}`)"
            if r["worst_mean_fps"] != ""
            else "—"
        )
        w1 = (
            f"{r['worst_min_fps_1s']} (`{_md_cell(r['worst_min_fps_1s_file'])}`)"
            if r["worst_min_fps_1s"] != ""
            else "—"
        )
        wg = f"{r['worst_max_gap_ms']} ms" if r["worst_max_gap_ms"] != "" else "—"
        lines.append(
            f"| {ex_lbl} | {r['n_sets_with_fps']}/{r['n_sets_total']} | "
            f"{r['mean_of_mean_fps'] or '—'} | {wm} | {r['mean_of_min_fps_1s'] or '—'} | "
            f"{w1} | {wg} |"
        )
    lines.append("")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Compare Vika app session logs (schema 1 JSON) against video-based coach "
            "labels (CSV) and write report CSV tables plus Vietnamese summary.md."
        )
    )
    parser.add_argument(
        "--logs",
        required=True,
        help="Directory containing Vika JSON set and session log files.",
    )
    parser.add_argument(
        "--labels",
        required=True,
        nargs="+",
        help="One or more coach label CSV files (or a directory of CSV files).",
    )
    parser.add_argument(
        "--out",
        required=True,
        help="Output directory where CSV tables and summary.md will be written.",
    )
    parser.add_argument(
        "--cue-map",
        default=None,
        help="Optional CSV mapping cue 'key' (and optional 'exercise_id') to 'fault' ID.",
    )
    parser.add_argument(
        "--tolerance-s",
        type=float,
        default=DEFAULT_TIME_TOLERANCE_S,
        help=f"Time matching tolerance in seconds when video_t_s is present (default: {DEFAULT_TIME_TOLERANCE_S}).",
    )
    parser.add_argument(
        "--primary-coach",
        default=None,
        help="Optional coach_id to prefer for App-vs-Coach tables when multiple coaches labelled the same set.",
    )
    parser.add_argument(
        "--catalog",
        default=None,
        help=(
            "Fault catalog CSV (exercise_id, fault, kind, ...). Defaults to fault_catalog.csv "
            "next to this script when it exists; pass 'none' to keep the built-in 4 exercises."
        ),
    )
    parser.add_argument(
        "--conditions",
        default=None,
        help=(
            "Optional session_conditions.csv (participant_id, condition, exercise_id, set_index, "
            "then one column per recording factor) for a per-condition precision/recall table."
        ),
    )
    parser.add_argument(
        "--form-faults-only",
        action="store_true",
        default=False,
        help=(
            "Ignore non-form-affecting soft warnings on app 'rep' events "
            "(faults recorded when correct=true or data.fault_affects_form[f]=false)."
        ),
    )
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    saved = (dict(KNOWN_EXERCISES), dict(STATUS_FAULTS), dict(EXERCISE_NAMES_VI))
    try:
        return _main(argv)
    finally:
        for target, original in zip((KNOWN_EXERCISES, STATUS_FAULTS, EXERCISE_NAMES_VI), saved):
            target.clear()
            target.update(original)


def _main(argv: Optional[Sequence[str]] = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        try:
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    if hasattr(sys.stderr, "reconfigure"):
        try:
            sys.stderr.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass

    parser = build_arg_parser()
    args = parser.parse_args(argv)

    logs_dir = Path(args.logs)
    if not logs_dir.exists() or not logs_dir.is_dir():
        print(
            f"ERROR: --logs directory does not exist or is not a folder: {logs_dir}",
            file=sys.stderr,
        )
        return 2

    raw_label_paths = [Path(p) for p in args.labels]
    missing_label_inputs = [p for p in raw_label_paths if not p.exists()]
    if missing_label_inputs:
        for mp in missing_label_inputs:
            print(f"ERROR: --labels path does not exist: {mp}", file=sys.stderr)
        return 2

    if args.tolerance_s < 0 or math.isnan(args.tolerance_s):
        print(f"ERROR: --tolerance-s must be non-negative (got {args.tolerance_s}).", file=sys.stderr)
        return 2

    out_dir = Path(args.out)
    cue_map_path: Optional[Path] = None
    if args.cue_map is not None:
        cue_map_path = Path(args.cue_map)
        if not cue_map_path.exists() or not cue_map_path.is_file():
            print(f"ERROR: --cue-map file does not exist: {cue_map_path}", file=sys.stderr)
            return 2

    if args.catalog is None:
        catalog_path: Optional[Path] = DEFAULT_CATALOG_PATH if DEFAULT_CATALOG_PATH.is_file() else None
    elif args.catalog.strip().lower() == "none":
        catalog_path = None
    else:
        catalog_path = Path(args.catalog)
        if not catalog_path.is_file():
            print(f"ERROR: --catalog file does not exist: {catalog_path}", file=sys.stderr)
            return 2
    if catalog_path is not None:
        apply_fault_catalog(catalog_path)

    conditions_path: Optional[Path] = None
    if args.conditions is not None:
        conditions_path = Path(args.conditions)
        if not conditions_path.is_file():
            print(f"ERROR: --conditions file does not exist: {conditions_path}", file=sys.stderr)
            return 2

    label_files = collect_label_files(
        raw_label_paths, out_dir=out_dir, cue_map_path=cue_map_path
    )
    if not label_files:
        print("ERROR: No CSV files found in --labels input.", file=sys.stderr)
        return 2

    issues: list[ValidationIssue] = []
    cue_mapper = CueFaultMapper()
    if cue_map_path is not None:
        cue_mapper = load_cue_map(cue_map_path, issues)

    participant_canon = IdCanonicalizer("Participant ID", "Mã người tập")
    coach_canon = IdCanonicalizer("Coach ID", "Mã HLV")

    set_logs, session_logs = load_logs_directory(
        logs_dir,
        participant_canon,
        cue_mapper,
        issues,
        form_faults_only=args.form_faults_only,
        out_dir=out_dir,
    )
    coach_rows, any_valid_header = load_coach_labels(
        label_files, participant_canon, coach_canon, issues
    )

    if not any_valid_header:
        print(
            "ERROR: Could not parse any valid coach label CSV header. "
            f"Expected columns: {', '.join(REQUIRED_LABEL_COLUMNS)}",
            file=sys.stderr,
        )
        for iv in issues:
            print(f"  [{iv.severity.upper()}] {iv.file}:{iv.line} — {iv.message_en}", file=sys.stderr)
        return 2

    if not set_logs and not session_logs and not coach_rows:
        print(
            "ERROR: Nothing sensible can be computed — zero valid logs and zero valid coach label rows.",
            file=sys.stderr,
        )
        for iv in issues:
            print(f"  [{iv.severity.upper()}] {iv.file}:{iv.line} — {iv.message_en}", file=sys.stderr)
        return 2

    conditions: Optional[dict[tuple[str, str, str, int], dict[str, str]]] = None
    condition_factors: list[str] = []
    if conditions_path is not None:
        conditions, condition_factors = load_session_conditions(
            conditions_path, participant_canon, issues
        )

    results = evaluate_all(
        set_logs=set_logs,
        session_logs=session_logs,
        coach_rows=coach_rows,
        issues=issues,
        tolerance_s=args.tolerance_s,
        primary_coach_arg=args.primary_coach,
        cue_map_used=(cue_map_path is not None and cue_mapper.loaded),
        conditions=conditions,
        condition_factors=condition_factors,
    )

    write_all_outputs(out_dir, results)

    # Blunt console summary for non-programmers
    print(f"Done. Wrote evaluation tables and summary.md to: {out_dir}")
    print(
        f"  Loaded: {len(set_logs)} valid set logs, {len(session_logs)} session logs, "
        f"{len(coach_rows)} coach label rows."
    )
    if results.issues:
        print(
            f"  ATTENTION: {len(results.issues)} input issue(s) found "
            f"(listed at top of {out_dir / 'summary.md'}):",
            file=sys.stderr,
        )
        for iv in results.issues[:25]:
            print(
                f"    - [{iv.severity.upper()}] {iv.file}:{iv.line}: {iv.message_en}",
                file=sys.stderr,
            )
        if len(results.issues) > 25:
            print(
                f"    ... and {len(results.issues) - 25} more in {out_dir / 'validation_issues.csv'}",
                file=sys.stderr,
            )
    else:
        print("  Input validation: 0 issues.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
