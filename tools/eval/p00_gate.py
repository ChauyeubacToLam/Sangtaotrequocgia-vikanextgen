#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
import sys
from typing import Optional, Sequence

from clips import load_set_logs

EVAL_DIR = Path(__file__).resolve().parent
APP_CATALOG = EVAL_DIR.parents[1] / "assets" / "data" / "exercise_catalog.json"
MAIN_EXERCISES = ("squat", "push_up", "glute_bridge", "plank")
COLUMNS = (
    "exercise_id",
    "condition",
    "set_index",
    "file",
    "target",
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


def read_catalog(path: Path) -> dict[str, set[str]]:
    known: dict[str, set[str]] = {}
    with path.open("r", encoding="utf-8-sig", newline="") as fh:
        for r in csv.DictReader(fh):
            known.setdefault(r["exercise_id"].strip(), set()).add(r["fault"].strip())
    return known


def read_set_targets(path: Path) -> dict[str, int]:
    rows = json.loads(path.read_text(encoding="utf-8"))
    return {str(r["catalogId"]): int(r["reps"]) for r in rows if r.get("reps")}


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
        "target": target,
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
    p.add_argument("--app-catalog", default=str(APP_CATALOG),
                   help="App exercise catalog; its reps field is the per-set target (holds per set for hold exercises).")
    p.add_argument("--participant", default="P00",
                   help="Only check set logs of this participant id; empty = all. "
                        "Only the newest set of each exercise and condition is checked, so a retest replaces it.")
    p.add_argument("--tolerance", type=int, default=1)
    p.add_argument("--out", default=None, help="Optional CSV output.")
    a = p.parse_args(argv)

    known = read_catalog(Path(a.catalog))
    targets = read_set_targets(Path(a.app_catalog))
    pid = a.participant.strip().upper()
    logs = [o for o in load_set_logs(Path(a.logs)) if not pid or str(o.get("participant_id", "")).upper() == pid]
    if not logs:
        print(f"No set log with participant_id {pid or '(any)'} in {a.logs}. Check Cài đặt nghiên cứu on the phone.")
        return 1
    latest: dict[tuple[str, str], dict] = {}
    started = lambda o: isinstance(o.get("sync_beep_t_ms"), (int, float))
    for o in sorted(logs, key=lambda o: (started(o), str(o.get("started_at_utc", "")))):
        latest[(str(o.get("exercise_id", "")), str(o.get("condition", "")))] = o
    rows = [check_set(o, known, targets.get(ex, 0), a.tolerance) for (ex, _), o in latest.items()]
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
            f"{r['exercise_id']:<20} {r['condition']:<8} set {r['set_index']}  reps {r['reps']:>2}/{r['target']:<2}  "
            f"cues {r['fault_cues_played']}/{r['fault_cues_played'] + r['fault_cues_silent']}  "
            f"codes [{r['fault_codes']}]  {r['verdict']}"
        )
    tested = {r["exercise_id"] for r in rows}
    missing = sorted(set(known) - tested)
    ai_tested = {r["exercise_id"] for r in rows if r["condition"] == "ai"}
    failed = sorted({r["exercise_id"] for r in rows if r["verdict"] != "PASS"})
    control_tested = {r["exercise_id"] for r in rows if r["condition"] == "control"}
    no_control = [ex for ex in MAIN_EXERCISES if ex not in control_tested]
    print()
    print(f"Exercises with a log: {len(tested)}/{len(known)}; with an ai set: {len(ai_tested)}")
    if missing:
        print("No log yet: " + ", ".join(missing))
    if no_control:
        print("No control set yet: " + ", ".join(no_control))
    if failed:
        print("Failing: " + ", ".join(failed))
    print("Still check by eye: the voice actually sounded, and the plank names sag vs pike correctly.")
    return 0 if not missing and not failed and not no_control else 1


if __name__ == "__main__":
    sys.exit(main())
