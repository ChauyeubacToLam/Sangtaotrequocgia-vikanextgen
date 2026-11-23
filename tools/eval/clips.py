#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
from datetime import datetime, timezone
import json
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
from typing import Iterable, Optional, Sequence

SetKey = tuple[str, str, str, int]

BEEP_COLUMNS = (
    "video_file",
    "participant_id",
    "condition",
    "exercise_id",
    "set_index",
    "beep_s",
    "end_s",
)
KEY_COLUMNS = (
    "clip_id",
    "clip_file",
    "video_file",
    "participant_id",
    "condition",
    "exercise_id",
    "set_index",
    "beep_s",
    "end_s",
)
SHEET_COLUMNS = (
    "coach_id",
    "clip_id",
    "exercise_id",
    "rep_n",
    "video_t_s",
    "counted",
    "faults",
    "note",
)
LABEL_COLUMNS = (
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
CONDITION_COLUMNS = (
    "participant_id",
    "condition",
    "exercise_id",
    "set_index",
    "camera_angle",
    "lux",
    "clothing",
    "body_type",
    "device",
    "location",
    "note",
)
DEFAULT_CLIP_LEN_S = 120.0
END_MARGIN_S = 2.0
FFMPEG_HINT = "ffmpeg not found. Install it (winget install Gyan.FFmpeg) and open a new terminal."


def read_rows(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        return []
    with path.open("r", encoding="utf-8-sig", newline="") as fh:
        return [{(k or "").strip(): (v or "").strip() for k, v in r.items()} for r in csv.DictReader(fh)]


def write_rows(path: Path, columns: Sequence[str], rows: Iterable[dict], append: bool = False) -> None:
    exists = path.is_file() and path.stat().st_size > 0
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a" if append else "w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(columns), extrasaction="ignore")
        if not (append and exists):
            w.writeheader()
        for r in rows:
            w.writerow(r)


def set_key(row: dict) -> SetKey:
    return (
        str(row["participant_id"]).strip().upper(),
        str(row["condition"]).strip().lower(),
        str(row["exercise_id"]).strip().lower(),
        int(float(row["set_index"])),
    )


def load_set_logs(logs_dir: Path) -> list[dict]:
    out = []
    for p in sorted(logs_dir.rglob("*.json")):
        try:
            obj = json.loads(p.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        if isinstance(obj, dict) and obj.get("kind") == "exercise_set":
            obj["_file"] = p.name
            out.append(obj)
    return out


def log_key(obj: dict) -> SetKey:
    return (
        str(obj.get("participant_id", "")).strip().upper(),
        str(obj.get("condition", "")).strip().lower(),
        str(obj.get("exercise_id", "")).strip().lower(),
        int(obj.get("set_index", 0)),
    )


def beep_utc_s(obj: dict) -> Optional[float]:
    beep = obj.get("sync_beep_t_ms")
    started = obj.get("started_at_utc")
    if not isinstance(beep, (int, float)) or not isinstance(started, str):
        return None
    t0 = datetime.fromisoformat(started.replace("Z", "+00:00")).astimezone(timezone.utc)
    return t0.timestamp() + beep / 1000.0


def set_length_s(obj: dict) -> Optional[float]:
    dur = (obj.get("frames") or {}).get("duration_ms")
    beep = obj.get("sync_beep_t_ms")
    if not isinstance(dur, (int, float)) or not isinstance(beep, (int, float)):
        return None
    return max(0.0, (dur - beep) / 1000.0)


def suggest_beeps(
    logs: Sequence[dict], video_file: str, anchor: SetKey, anchor_beep_s: float
) -> tuple[list[dict], list[str]]:
    by_key = {log_key(o): o for o in logs}
    if anchor not in by_key:
        raise SystemExit(f"Anchor set {anchor} not found in logs.")
    anchor_obj = by_key[anchor]
    anchor_utc = beep_utc_s(anchor_obj)
    if anchor_utc is None:
        raise SystemExit(f"Anchor set {anchor} has no sync beep in its log.")
    session = anchor_obj.get("session_id")
    rows: list[dict] = []
    skipped: list[str] = []
    for key, obj in sorted(by_key.items(), key=lambda kv: beep_utc_s(kv[1]) or 0.0):
        if obj.get("session_id") != session:
            continue
        utc = beep_utc_s(obj)
        if utc is None:
            skipped.append(f"{obj['_file']}: no sync beep")
            continue
        beep_s = anchor_beep_s + (utc - anchor_utc)
        if beep_s < 0:
            skipped.append(f"{obj['_file']}: beep before the video starts")
            continue
        length = set_length_s(obj)
        end_s = beep_s + (length if length is not None else DEFAULT_CLIP_LEN_S) + END_MARGIN_S
        rows.append(
            {
                "video_file": video_file,
                "participant_id": key[0],
                "condition": key[1],
                "exercise_id": key[2],
                "set_index": key[3],
                "beep_s": f"{beep_s:.2f}",
                "end_s": f"{end_s:.2f}",
            }
        )
    return rows, skipped


def condition_rows(logs: Sequence[dict], existing: Iterable[SetKey]) -> list[dict]:
    seen = set(existing)
    rows = []
    for obj in logs:
        key = log_key(obj)
        if key in seen:
            continue
        seen.add(key)
        rows.append(
            {
                "participant_id": key[0],
                "condition": key[1],
                "exercise_id": key[2],
                "set_index": key[3],
                "device": f"{obj.get('platform', '')} {obj.get('os_version', '')}".strip(),
            }
        )
    return sorted(rows, key=lambda r: (r["participant_id"], r["exercise_id"], r["condition"], r["set_index"]))


def new_clip_id(taken: set[str]) -> str:
    while True:
        cid = "c" + secrets.token_hex(4)
        if cid not in taken:
            taken.add(cid)
            return cid


def cut_command(ffmpeg: str, src: Path, dst: Path, start_s: float, end_s: float) -> list[str]:
    return [
        ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
        "-ss", f"{start_s:.3f}", "-i", str(src), "-t", f"{max(0.1, end_s - start_s):.3f}",
        "-an", "-map_metadata", "-1", "-c:v", "libx264", "-preset", "veryfast", "-crf", "23",
        str(dst),
    ]


def ffmpeg_path(text: str) -> str:
    return text.replace("\\", "/").replace(":", "\\:")


def overlay_command(
    ffmpeg: str, src: Path, dst: Path, start_s: float, end_s: float, text_file: Path, font: Optional[Path]
) -> list[str]:
    font_part = f"fontfile='{ffmpeg_path(str(font))}':" if font else ""
    draw = (
        f"drawtext={font_part}textfile='{ffmpeg_path(str(text_file))}':"
        "fontcolor=white:fontsize=h/18:line_spacing=8:box=1:boxcolor=black@0.6:boxborderw=12:x=24:y=24"
    )
    start = max(0.0, start_s)
    return [
        ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
        "-ss", f"{start:.3f}", "-i", str(src), "-t", f"{max(0.1, end_s - start):.3f}",
        "-vf", draw, "-an", "-c:v", "libx264", "-preset", "veryfast", "-crf", "23", str(dst),
    ]


def merge_labels(
    key_rows: Sequence[dict[str, str]], sheet_rows: Sequence[dict[str, str]]
) -> tuple[list[dict], list[str]]:
    by_clip = {r["clip_id"]: r for r in key_rows}
    out: list[dict] = []
    problems: list[str] = []
    for i, r in enumerate(sheet_rows, start=2):
        if not r.get("rep_n", "").strip():
            continue
        clip = by_clip.get(r.get("clip_id", "").strip())
        if clip is None:
            problems.append(f"row {i}: unknown clip_id {r.get('clip_id')!r}")
            continue
        ex = r.get("exercise_id", "").strip().lower()
        if ex and ex != clip["exercise_id"].lower():
            problems.append(f"row {i}: clip {clip['clip_id']} is {clip['exercise_id']}, sheet says {ex}")
            continue
        out.append(
            {
                "coach_id": r.get("coach_id", "").strip(),
                "participant_id": clip["participant_id"],
                "condition": clip["condition"],
                "exercise_id": clip["exercise_id"],
                "set_index": clip["set_index"],
                "rep_n": r.get("rep_n", "").strip(),
                "video_t_s": r.get("video_t_s", "").strip(),
                "counted": r.get("counted", "").strip(),
                "faults": r.get("faults", "").strip(),
                "note": r.get("note", "").strip(),
            }
        )
    return out, problems


def overlay_text(row: dict[str, str]) -> str:
    coach = row.get("coach_faults") or "clean"
    app = row.get("app_faults") or "clean"
    return (
        f"{row['exercise_id']}  {row['participant_id']}  set {row['set_index']}  rep {row.get('coach_rep_n', '')}\n"
        f"HLV: {coach}\n"
        f"AI:  {app}"
    )


def require_ffmpeg() -> str:
    exe = shutil.which("ffmpeg")
    if exe is None:
        raise SystemExit(FFMPEG_HINT)
    return exe


def cmd_suggest(a: argparse.Namespace) -> int:
    parts = [p.strip() for p in a.anchor.split(",")]
    if len(parts) != 4:
        raise SystemExit("--anchor must be participant,condition,exercise_id,set_index")
    anchor: SetKey = (parts[0].upper(), parts[1].lower(), parts[2].lower(), int(parts[3]))
    rows, skipped = suggest_beeps(load_set_logs(Path(a.logs)), a.video, anchor, a.anchor_beep_s)
    out = Path(a.out)
    have = {(r["video_file"], set_key(r)) for r in read_rows(out)}
    fresh = [r for r in rows if (r["video_file"], set_key(r)) not in have]
    write_rows(out, BEEP_COLUMNS, fresh, append=True)
    print(f"Added {len(fresh)} row(s) to {out}. Check 2-3 of them by ear before cutting.")
    for s in skipped:
        print(f"  skipped {s}")
    return 0


def cmd_conditions(a: argparse.Namespace) -> int:
    out = Path(a.out)
    existing = [set_key(r) for r in read_rows(out)]
    rows = condition_rows(load_set_logs(Path(a.logs)), existing)
    write_rows(out, CONDITION_COLUMNS, rows, append=True)
    print(f"Added {len(rows)} set row(s) to {out}. Fill camera_angle, lux, clothing, body_type, location.")
    return 0


def cmd_cut(a: argparse.Namespace) -> int:
    key_path = Path(a.key)
    out_dir = Path(a.out_dir)
    if out_dir.resolve() in key_path.resolve().parents:
        raise SystemExit("--key must not be inside --out-dir: coaches would see who is in each clip.")
    key_rows = read_rows(key_path)
    done = {(r["video_file"], set_key(r)) for r in key_rows}
    taken = {r["clip_id"] for r in key_rows}
    todo = [r for r in read_rows(Path(a.beeps)) if (r["video_file"], set_key(r)) not in done]
    if not todo:
        print("Nothing new to cut.")
        return 0
    ffmpeg = require_ffmpeg()
    out_dir.mkdir(parents=True, exist_ok=True)
    added: list[dict] = []
    for r in todo:
        src = Path(a.video_dir) / r["video_file"]
        if not src.is_file():
            print(f"  missing video {src}", file=sys.stderr)
            continue
        beep = float(r["beep_s"])
        end = float(r["end_s"]) if r.get("end_s") else beep + DEFAULT_CLIP_LEN_S
        cid = new_clip_id(taken)
        dst = out_dir / f"{cid}.mp4"
        proc = subprocess.run(cut_command(ffmpeg, src, dst, beep, end), capture_output=True, text=True)
        if proc.returncode != 0:
            print(f"  ffmpeg failed on {r['video_file']} at {beep}s: {proc.stderr.strip()}", file=sys.stderr)
            continue
        k = set_key(r)
        added.append(
            {
                "clip_id": cid,
                "clip_file": dst.name,
                "video_file": r["video_file"],
                "participant_id": k[0],
                "condition": k[1],
                "exercise_id": k[2],
                "set_index": k[3],
                "beep_s": f"{beep:.2f}",
                "end_s": f"{end:.2f}",
            }
        )
        write_rows(key_path, KEY_COLUMNS, [added[-1]], append=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    sheet = out_dir / f"coach_sheet_{stamp}.csv"
    write_rows(
        sheet,
        SHEET_COLUMNS,
        sorted(({"clip_id": r["clip_id"], "exercise_id": r["exercise_id"]} for r in added), key=lambda r: r["clip_id"]),
    )
    print(f"Cut {len(added)} clip(s) into {out_dir}. Key: {key_path}. Coach sheet: {sheet}")
    return 0


def cmd_merge(a: argparse.Namespace) -> int:
    key_rows = read_rows(Path(a.key))
    sheet_rows: list[dict[str, str]] = []
    for p in a.sheets:
        sheet_rows.extend(read_rows(Path(p)))
    rows, problems = merge_labels(key_rows, sheet_rows)
    write_rows(Path(a.out), LABEL_COLUMNS, rows)
    print(f"Wrote {len(rows)} label row(s) to {a.out}.")
    for pr in problems:
        print(f"  {pr}", file=sys.stderr)
    return 1 if problems else 0


def cmd_overlay(a: argparse.Namespace) -> int:
    by_set = {set_key(r): r for r in read_rows(Path(a.key))}
    wrong = read_rows(Path(a.wrong))
    if a.limit:
        wrong = wrong[: a.limit]
    ffmpeg = require_ffmpeg()
    out_dir = Path(a.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    font = Path(a.font) if a.font and Path(a.font).is_file() else None
    made = 0
    for r in wrong:
        k = set_key(r)
        clip = by_set.get(k)
        t_raw = r.get("video_t_s") or r.get("app_rel_t_s")
        if clip is None or not t_raw:
            print(f"  no clip or time for {k} rep {r.get('coach_rep_n')}", file=sys.stderr)
            continue
        t = float(t_raw)
        name = f"{k[2]}_{k[0]}_{k[1]}_s{k[3]}_r{r.get('coach_rep_n', '')}"
        text_file = out_dir / f"{name}.txt"
        text_file.write_text(overlay_text(r), encoding="utf-8")
        cmd = overlay_command(
            ffmpeg, Path(a.clips_dir) / clip["clip_file"], out_dir / f"{name}.mp4",
            t - a.before_s, t + a.after_s, text_file, font,
        )
        proc = subprocess.run(cmd, capture_output=True, text=True)
        text_file.unlink(missing_ok=True)
        if proc.returncode != 0:
            print(f"  ffmpeg failed on {name}: {proc.stderr.strip()}", file=sys.stderr)
            continue
        made += 1
    print(f"Wrote {made} excerpt(s) to {out_dir}.")
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Cut, blind, merge and annotate coach-label video clips.")
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("suggest", help="Predict every set's beep time in one camera video from one anchor beep.")
    s.add_argument("--logs", required=True, help="Directory with the app's set logs.")
    s.add_argument("--video", required=True, help="Camera video file name, as it appears in --video-dir.")
    s.add_argument(
        "--anchor", required=True,
        help="participant,condition,exercise_id,set_index of a set whose beep you found by ear.",
    )
    s.add_argument("--anchor-beep-s", required=True, type=float, help="Seconds into the video where that beep is heard.")
    s.add_argument("--out", default="beep_times.csv", help="beep_times.csv to append to.")
    s.set_defaults(func=cmd_suggest)

    c = sub.add_parser("conditions", help="Append one session_conditions.csv row per set log, factors left blank.")
    c.add_argument("--logs", required=True)
    c.add_argument("--out", default="session_conditions.csv")
    c.set_defaults(func=cmd_conditions)

    k = sub.add_parser("cut", help="Cut one muted, randomly named clip per set, starting at its beep.")
    k.add_argument("--beeps", required=True, help="beep_times.csv")
    k.add_argument("--video-dir", required=True)
    k.add_argument("--out-dir", required=True, help="Folder given to the coaches.")
    k.add_argument("--key", required=True, help="clip_key.csv, kept away from the coaches.")
    k.set_defaults(func=cmd_cut)

    m = sub.add_parser("merge", help="Turn coach sheets keyed by clip_id into evaluate.py label CSV.")
    m.add_argument("--key", required=True)
    m.add_argument("--sheets", required=True, nargs="+")
    m.add_argument("--out", required=True)
    m.set_defaults(func=cmd_merge)

    o = sub.add_parser("overlay", help="Short excerpts of wrong detections with 'HLV: ... / AI: ...' burned in.")
    o.add_argument("--wrong", required=True, help="wrong_detections.csv from evaluate.py")
    o.add_argument("--key", required=True)
    o.add_argument("--clips-dir", required=True)
    o.add_argument("--out-dir", required=True)
    o.add_argument("--before-s", type=float, default=4.0)
    o.add_argument("--after-s", type=float, default=1.5)
    o.add_argument("--limit", type=int, default=0)
    o.add_argument("--font", default="C:/Windows/Fonts/arial.ttf")
    o.set_defaults(func=cmd_overlay)
    return p


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
