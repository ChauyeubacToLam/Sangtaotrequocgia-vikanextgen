#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
from pathlib import Path
import sys
from typing import Optional, Sequence

from clips import load_set_logs

EVAL_DIR = Path(__file__).resolve().parent
COLUMNS = (
    "exercise_id",
    "condition",
    "set_index",
    "file",
    "reps",
    "reps_ok",
    "has_sync_beep",
    "set_complete",
    "fault_codes",
    "unknown_codes",
    "fault_cues_played",
    "fault_cues_silent",
    "verdict",
)


def read_catalog(path: Path) -> tuple[dict[str, set[str]], set[str]]:
    known: dict[str, set[str]] = {}
    holds: set[str] = set()
    with path.open("r", encoding="utf-8-sig", newline="") as fh:
        for r in csv.DictReader(fh):
            ex = r["exercise_id"].strip()
            known.setdefault(ex, set()).add(r["fault"].strip())
            if r.get("unit", "").strip() == "hold":
                holds.add(ex)
    return known, holds


def check_set(obj: dict, known: dict[str, set[str]], target: int, tolerance: int) -> dict:
    ex = str(obj.get("exercise_id", ""))
    events = [e for e in obj.get("events", []) if isinstance(e, dict)]
    reps = [e for e in events if e.get("type") == "rep"]
    codes: set[str] = set()
    for e in reps:
        faults = e.get("faults")
        if isinstance(faults, list):
            codes.update(str(f) for f in faults if f)
    fault_cues = [e for e in events if e.get("type") == "cue" and e.get("fault")]
    played = sum(1 for e in fault_cues if e.get("played") is True)
    silent = len(fault_cues) - played
    unknown = sorted(codes - known.get(ex, set()))
    cond = str(obj.get("condition", ""))
    problems = []
    reps_ok = abs(len(reps) - target) <= tolerance
    if not reps_ok:
        problems.append(f"{len(reps)} reps")
    has_beep = isinstance(obj.get("sync_beep_t_ms"), (int, float))
    if not has_beep:
        problems.append("no beep")
    if ex not in known:
        problems.append("exercise not in catalog")
    if unknown:
        problems.append("codes not in catalog")
    if cond == "ai" and silent and not played:
        problems.append("fault cues have no audio")
    return {
        "exercise_id": ex,
        "condition": cond,
        "set_index": obj.get("set_index", ""),
        "file": obj.get("_file", ""),
        "reps": len(reps),
        "reps_ok": "yes" if reps_ok else "NO",
        "has_sync_beep": "yes" if has_beep else "NO",
        "set_complete": "yes" if any(e.get("type") == "set_complete" for e in events) else "no",
        "fault_codes": ";".join(sorted(codes)),
        "unknown_codes": ";".join(unknown),
        "fault_cues_played": played,
        "fault_cues_silent": silent,
        "verdict": "PASS" if not problems else "FAIL: " + ", ".join(problems),
    }


def main(argv: Optional[Sequence[str]] = None) -> int:
    p = argparse.ArgumentParser(description="P00 gate: check each exercise's trial set log before the study.")
    p.add_argument("--logs", required=True, help="Directory with the P00 set logs.")
    p.add_argument("--catalog", default=str(EVAL_DIR / "fault_catalog.csv"))
    p.add_argument("--target", type=int, default=10, help="Reps the tester performed per set.")
    p.add_argument("--hold-target", type=int, default=3, help="Holds the tester performed per set of a hold exercise.")
    p.add_argument("--tolerance", type=int, default=1)
    p.add_argument("--out", default=None, help="Optional CSV output.")
    a = p.parse_args(argv)

    known, holds = read_catalog(Path(a.catalog))
    rows = [
        check_set(o, known, a.hold_target if o.get("exercise_id") in holds else a.target, a.tolerance)
        for o in load_set_logs(Path(a.logs))
    ]
    rows.sort(key=lambda r: (r["exercise_id"], r["condition"], str(r["set_index"])))
    if a.out:
        with Path(a.out).open("w", encoding="utf-8", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=list(COLUMNS))
            w.writeheader()
            w.writerows(rows)

    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    for r in rows:
        print(
            f"{r['exercise_id']:<20} {r['condition']:<8} set {r['set_index']}  reps {r['reps']:>2}  "
            f"cues {r['fault_cues_played']}/{r['fault_cues_played'] + r['fault_cues_silent']}  "
            f"codes [{r['fault_codes']}]  {r['verdict']}"
        )
    tested = {r["exercise_id"] for r in rows}
    missing = sorted(set(known) - tested)
    ai_tested = {r["exercise_id"] for r in rows if r["condition"] == "ai"}
    failed = sorted({r["exercise_id"] for r in rows if r["verdict"] != "PASS"})
    print()
    print(f"Exercises with a log: {len(tested)}/{len(known)}; with an ai set: {len(ai_tested)}")
    if missing:
        print("No log yet: " + ", ".join(missing))
    if failed:
        print("Failing: " + ", ".join(failed))
    print("Still check by eye: the voice actually sounded, and the plank names sag vs pike correctly.")
    return 0 if not missing and not failed else 1


if __name__ == "__main__":
    sys.exit(main())
