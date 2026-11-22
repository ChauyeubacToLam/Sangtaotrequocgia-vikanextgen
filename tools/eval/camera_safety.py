from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
import statistics
import sys
from typing import Any, Optional

EXPECTED_REASONS: dict[str, set[str]] = {
    "1": {"bodyInFrame"},
    "2": {"paused", "searching"},
    "3": {"lighting"},
    "4": {"phoneLandscape", "phonePortrait"},
    "5": {"turnSide", "faceCamera"},
    "6": {"bodyInFrame", "lighting", "paused", "searching"},
}

TRIAL_COLUMNS = ("tester_id", "exercise_id", "set_index", "scenario", "trial",
                 "start_video_t_s", "end_video_t_s", "note")
OUT_COLUMNS = ("tester_id", "exercise_id", "set_index", "scenario", "trial", "log_file",
               "detected", "reasons", "right_prompt", "latency_s", "reps_in_window",
               "faults_in_window", "recovery_s", "problem")


def judging_timeline(events: list[dict[str, Any]]) -> list[tuple[int, bool, Optional[str]]]:
    activated = paused = False
    unseen: Optional[str] = None
    out: list[tuple[int, bool, Optional[str]]] = []
    for ev in events:
        typ, t = ev.get("type"), ev.get("t_ms")
        if not isinstance(t, int):
            continue
        if typ == "activated":
            activated = True
        elif typ == "pause_start":
            paused, activated = True, False
        elif typ == "pause_end":
            paused = False
        elif typ == "unseen_start":
            unseen = str(ev.get("reason") or "unknown")
            if ev.get("phase") == "setup":
                activated = False
        elif typ == "unseen_end":
            unseen = None
        else:
            continue
        judging = activated and not paused and unseen is None
        reason = None if judging else ("paused" if paused else unseen or "notActivated")
        out.append((t, judging, reason))
    return out


def state_at(timeline: list[tuple[int, bool, Optional[str]]], t_ms: int) -> tuple[bool, Optional[str]]:
    judging, reason = False, "notActivated"
    for t, j, r in timeline:
        if t > t_ms:
            break
        judging, reason = j, r
    return judging, reason


def analyse_trial(set_log: dict[str, Any], start_s: float, end_s: float,
                  scenario: str) -> dict[str, Any]:
    beep = set_log.get("sync_beep_t_ms")
    if not isinstance(beep, int):
        return {"problem": "no sync_beep_t_ms in log"}
    events = [e for e in set_log.get("events", []) if isinstance(e, dict)]
    start_ms, end_ms = beep + round(start_s * 1000), beep + round(end_s * 1000)
    timeline = judging_timeline(events)

    judging_at_start, start_reason = state_at(timeline, start_ms - 1)
    stops = [(t, r) for t, j, r in timeline if start_ms <= t <= end_ms and not j]
    reasons = sorted({r for _, r in stops if r} | ({start_reason} if not judging_at_start else set()))
    detected = (not judging_at_start) or bool(stops)
    latency = (stops[0][0] - start_ms) / 1000 if judging_at_start and stops else None

    recovery = None
    judging_at_end, _ = state_at(timeline, end_ms)
    if judging_at_end:
        recovery = 0.0
    else:
        back = next((t for t, j, _ in timeline if t > end_ms and j), None)
        if back is not None:
            recovery = (back - end_ms) / 1000

    in_window = [e for e in events if isinstance(e.get("t_ms"), int) and start_ms <= e["t_ms"] <= end_ms]
    return {
        "detected": "yes" if detected else "no",
        "reasons": ";".join(reasons),
        "right_prompt": "yes" if set(reasons) & EXPECTED_REASONS.get(scenario, set()) else "no",
        "latency_s": "" if latency is None else f"{latency:.2f}",
        "reps_in_window": sum(1 for e in in_window if e.get("type") == "rep"),
        "faults_in_window": sum(1 for e in in_window if e.get("type") == "fault_start"),
        "recovery_s": "" if recovery is None else f"{recovery:.2f}",
        "problem": "" if judging_at_start else "app was not judging when the trial started",
    }


def load_set_logs(logs_dir: Path) -> dict[tuple[str, str, int], list[tuple[Path, dict[str, Any]]]]:
    found: dict[tuple[str, str, int], list[tuple[Path, dict[str, Any]]]] = {}
    for path in sorted(logs_dir.rglob("*.json")):
        try:
            obj = json.loads(path.read_text(encoding="utf-8-sig"))
        except (OSError, ValueError):
            continue
        if not isinstance(obj, dict) or obj.get("kind") != "exercise_set":
            continue
        key = (str(obj.get("participant_id", "")).strip().upper(),
               str(obj.get("exercise_id", "")).strip(), obj.get("set_index"))
        found.setdefault(key, []).append((path, obj))
    return found


def _num(cell: str) -> float:
    return float(cell.strip().replace(",", "."))


def run(trials_csv: Path, logs_dir: Path) -> list[dict[str, Any]]:
    logs = load_set_logs(logs_dir)
    rows: list[dict[str, Any]] = []
    with trials_csv.open(encoding="utf-8-sig", newline="") as fh:
        for raw in csv.DictReader(fh):
            row = {k: (raw.get(k) or "").strip() for k in TRIAL_COLUMNS}
            out: dict[str, Any] = {k: row[k] for k in OUT_COLUMNS if k in row}
            try:
                key = (row["tester_id"].upper(), row["exercise_id"], int(row["set_index"]))
                start_s, end_s = _num(row["start_video_t_s"]), _num(row["end_video_t_s"])
            except ValueError:
                rows.append({**out, "problem": "bad set_index or time cell"})
                continue
            candidates = logs.get(key, [])
            if not candidates:
                rows.append({**out, "problem": "no set log for tester/exercise/set"})
                continue
            path, set_log = max(candidates, key=lambda c: str(c[1].get("started_at_utc", "")))
            out["log_file"] = path.name
            out.update(analyse_trial(set_log, start_s, end_s, row["scenario"]))
            if len(candidates) > 1:
                out["problem"] = (out.get("problem") or "") + f" ({len(candidates)} logs matched, used latest)"
            rows.append(out)
    return rows


def summarise(rows: list[dict[str, Any]]) -> str:
    lines = [
        "| Tình huống | Số lần thử | App dừng chấm | Nhắc đúng loại | Độ trễ phát hiện (trung vị, s) "
        "| Rep/lỗi bị ghi trong lúc xấu | Thời gian hồi phục (trung vị, s) |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    for scen in sorted({r.get("scenario", "") for r in rows}):
        grp = [r for r in rows if r.get("scenario") == scen and "detected" in r]
        if not grp:
            continue
        lat = [float(r["latency_s"]) for r in grp if r.get("latency_s")]
        rec = [float(r["recovery_s"]) for r in grp if r.get("recovery_s")]
        n = len(grp)
        lines.append(
            f"| {scen} | {n} | {sum(r['detected'] == 'yes' for r in grp)}/{n} "
            f"| {sum(r['right_prompt'] == 'yes' for r in grp)}/{n} "
            f"| {f'{statistics.median(lat):.2f}' if lat else '—'} "
            f"| {sum(r['reps_in_window'] for r in grp)} rep, {sum(r['faults_in_window'] for r in grp)} lỗi "
            f"| {f'{statistics.median(rec):.2f}' if rec else '—'} ({len(rec)}/{n} hồi phục) |"
        )
    skipped = [r for r in rows if "detected" not in r]
    if skipped:
        lines.append("")
        lines.append(f"Bỏ qua {len(skipped)} dòng không đọc được, xem cột `problem` trong `camera_safety.csv`.")
    return "\n".join(lines) + "\n"


def main(argv: Optional[list[str]] = None) -> int:
    ap = argparse.ArgumentParser(description="Camera-safety trial table (KE_HOACH_THU_SO_LIEU.md section 5).")
    ap.add_argument("--trials", type=Path, required=True)
    ap.add_argument("--logs", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args(argv)
    if not args.trials.is_file() or not args.logs.is_dir():
        print("--trials must be a CSV file and --logs a directory", file=sys.stderr)
        return 2
    rows = run(args.trials, args.logs)
    args.out.mkdir(parents=True, exist_ok=True)
    with (args.out / "camera_safety.csv").open("w", encoding="utf-8-sig", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=OUT_COLUMNS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    (args.out / "camera_safety_summary.md").write_text(summarise(rows), encoding="utf-8")
    print(f"{len(rows)} trials -> {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
