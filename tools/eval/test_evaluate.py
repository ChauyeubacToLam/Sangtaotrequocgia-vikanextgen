#!/usr/bin/env python3
"""Unit and end-to-end tests for tools/eval/evaluate.py using hand-crafted fixtures."""

from __future__ import annotations

import csv
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

EVAL_DIR = Path(__file__).resolve().parent
if str(EVAL_DIR) not in sys.path:
    sys.path.insert(0, str(EVAL_DIR))

import evaluate  # noqa: E402


def _make_set_json(
    participant_id: str = "P01",
    condition: str = "ai",
    exercise_id: str = "squat",
    set_index: int = 1,
    sync_beep_t_ms: int | None = 1000,
    events: list[dict] | None = None,
    active_ms: int = 20000,
    unseen_ms: int = 0,
    paused_ms: int = 0,
    mean_fps: float = 25.0,
    min_fps_1s: float = 18.0,
    max_gap_ms: float = 90.0,
    session_id: str | None = None,
) -> dict:
    sid = session_id or f"20261120T090000Z-{participant_id.strip()}"
    ev_list = events if events is not None else [{"t_ms": 20000, "type": "set_complete"}]
    rep_events = [e for e in ev_list if e.get("type") == "rep"]
    good_reps = sum(1 for e in rep_events if e.get("correct", True))
    return {
        "schema": 1,
        "kind": "exercise_set",
        "session_id": sid,
        "participant_id": participant_id,
        "condition": condition,
        "app_version": "1.0.3+155",
        "platform": "android",
        "os_version": "14",
        "exercise_id": exercise_id,
        "set_index": set_index,
        "started_at_utc": "2026-11-20T09:00:02.000Z",
        "sync_beep_t_ms": sync_beep_t_ms,
        "frames": {
            "total": int(mean_fps * 20),
            "with_pose": int(mean_fps * 19),
            "duration_ms": 20000,
            "mean_fps": mean_fps,
            "min_fps_1s": min_fps_1s,
            "max_gap_ms": max_gap_ms,
        },
        "events": ev_list,
        "set_log": {},
        "summary": {
            "reps": len(rep_events),
            "good_reps": good_reps,
            "active_ms": active_ms,
            "unseen_ms": unseen_ms,
            "paused_ms": paused_ms,
        },
    }


def _run_synthetic(
    set_jsons: dict[str, dict],
    csv_rows: list[list[str]],
    session_jsons: dict[str, dict] | None = None,
    cue_map_rows: list[list[str]] | None = None,
    tolerance_s: float = 2.5,
    primary_coach: str | None = None,
) -> evaluate.EvaluationResults:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        logs_dir = root / "logs"
        logs_dir.mkdir()
        for fname, payload in set_jsons.items():
            (logs_dir / fname).write_text(json.dumps(payload, indent=2), encoding="utf-8")
        if session_jsons:
            for fname, payload in session_jsons.items():
                (logs_dir / fname).write_text(json.dumps(payload, indent=2), encoding="utf-8")

        labels_path = root / "labels.csv"
        with labels_path.open("w", encoding="utf-8", newline="") as fh:
            writer = csv.writer(fh)
            writer.writerow(list(evaluate.REQUIRED_LABEL_COLUMNS))
            writer.writerows(csv_rows)

        issues: list[evaluate.ValidationIssue] = []
        cue_mapper = evaluate.CueFaultMapper()
        cue_used = False
        if cue_map_rows is not None:
            cmap_path = root / "cue_map.csv"
            with cmap_path.open("w", encoding="utf-8", newline="") as fh:
                writer = csv.writer(fh)
                writer.writerow(["exercise_id", "key", "fault"])
                writer.writerows(cue_map_rows)
            cue_mapper = evaluate.load_cue_map(cmap_path, issues)
            cue_used = cue_mapper.loaded

        p_canon = evaluate.IdCanonicalizer("Participant ID", "Mã người tập")
        c_canon = evaluate.IdCanonicalizer("Coach ID", "Mã HLV")
        set_logs, session_logs = evaluate.load_logs_directory(
            logs_dir, p_canon, cue_mapper, issues
        )
        coach_rows, ok = evaluate.load_coach_labels([labels_path], p_canon, c_canon, issues)
        assert ok, f"Header failed in synthetic helper: {issues}"
        return evaluate.evaluate_all(
            set_logs=set_logs,
            session_logs=session_logs,
            coach_rows=coach_rows,
            issues=issues,
            tolerance_s=tolerance_s,
            primary_coach_arg=primary_coach,
            cue_map_used=cue_used,
        )


def _find_row(rows: list[dict], **predicates: object) -> dict:
    for r in rows:
        if all(r.get(k) == v for k, v in predicates.items()):
            return r
    raise AssertionError(f"No row matching {predicates} in {rows}")


class TestEvaluateSyntheticScenarios(unittest.TestCase):
    def test_perfect_agreement_and_wilson_small_sample_ci(self) -> None:
        """4 matched reps with perfect agreement; verify TP/FP/FN/TN and wide Wilson CI."""
        events = [
            {"t_ms": 5000, "type": "rep", "n": 1, "correct": False, "faults": ["depth"], "data": {}},
            {"t_ms": 9000, "type": "rep", "n": 2, "correct": False, "faults": ["depth"], "data": {}},
            {"t_ms": 13000, "type": "rep", "n": 3, "correct": False, "faults": ["depth"], "data": {}},
            {"t_ms": 17000, "type": "rep", "n": 4, "correct": False, "faults": ["depth"], "data": {}},
            {"t_ms": 20000, "type": "set_complete"},
        ]
        csv_rows = [
            ["C1", "P01", "ai", "squat", "1", "1", "4.1", "1", "depth", ""],
            ["C1", "P01", "ai", "squat", "1", "2", "8.0", "1", "depth", ""],
            ["C1", "P01", "ai", "squat", "1", "3", "11.9", "1", "depth", ""],
            ["C1", "P01", "ai", "squat", "1", "4", "16.2", "1", "depth", ""],
        ]
        res = _run_synthetic({"s1.json": _make_set_json(events=events)}, csv_rows)
        self.assertEqual(res.issues, [])

        cnt = _find_row(res.counting_accuracy_rows, exercise_id="squat")
        self.assertEqual(cnt["coach_valid_reps"], 4)
        self.assertEqual(cnt["app_reps"], 4)
        self.assertEqual(cnt["matched"], 4)
        self.assertEqual(cnt["missed"], 0)
        self.assertEqual(cnt["phantom"], 0)

        fd = _find_row(res.fault_detection_rows, exercise_id="squat", fault_id="depth")
        self.assertEqual((fd["tp"], fd["fp"], fd["fn"], fd["tn"]), (4, 0, 0, 0))
        self.assertEqual(fd["n_app_positive"], 4)
        self.assertEqual(fd["n_coach_positive"], 4)
        self.assertAlmostEqual(float(fd["precision"]), 1.0)
        self.assertAlmostEqual(float(fd["recall"]), 1.0)
        # 4/4 precision must carry a wide Wilson 95% lower bound (~0.5101), not ~1.0
        self.assertAlmostEqual(float(fd["precision_ci95_low"]), 0.5101, places=3)
        self.assertAlmostEqual(float(fd["precision_ci95_high"]), 1.0, places=4)
        self.assertEqual(res.wrong_detection_rows, [])

    def test_missed_rep_and_phantom_rep_with_half_rep_handling(self) -> None:
        """Coach rep at 8.0s is missed; app rep at 15.0s is phantom; counted=0 half rep is neither."""
        events = [
            # sync_beep_t_ms = 1000 -> rel_t_s = 4.0, 11.0, 15.0
            {"t_ms": 5000, "type": "rep", "n": 1, "correct": True, "faults": [], "data": {}},
            {"t_ms": 12000, "type": "rep", "n": 2, "correct": True, "faults": [], "data": {}},
            {"t_ms": 16000, "type": "rep", "n": 3, "correct": True, "faults": [], "data": {}},
            {"t_ms": 20000, "type": "set_complete"},
        ]
        csv_rows = [
            ["C1", "P01", "ai", "squat", "1", "1", "4.0", "1", "", ""],
            ["C1", "P01", "ai", "squat", "1", "2", "6.0", "0", "", "half rep"],
            ["C1", "P01", "ai", "squat", "1", "3", "8.0", "1", "", "missed by app"],
            ["C1", "P01", "ai", "squat", "1", "4", "11.1", "1", "", ""],
            # App rep 3 at rel 15.0s (> 11.1 + 2.5s) has no coach rep -> phantom!
        ]
        res = _run_synthetic({"s1.json": _make_set_json(events=events)}, csv_rows)
        cnt = _find_row(res.counting_accuracy_rows, exercise_id="squat")
        self.assertEqual(cnt["coach_valid_reps"], 3)
        self.assertEqual(cnt["coach_uncounted_attempts"], 1)
        self.assertEqual(cnt["app_reps"], 3)
        self.assertEqual(cnt["matched"], 2)
        self.assertEqual(cnt["missed"], 1)
        self.assertEqual(cnt["phantom"], 1)

        statuses = [r["status"] for r in res.rep_matching_rows]
        self.assertEqual(statuses, ["matched", "missed", "matched", "phantom"])

    def test_false_positive_and_false_negative_for_one_fault(self) -> None:
        """4 matched plank holds: 1 TP, 1 FP, 1 FN, 1 TN on fault 'Back'."""
        events = [
            {"t_ms": 16000, "type": "rep", "n": 1, "correct": False, "faults": ["Back"], "data": {}},
            {"t_ms": 36000, "type": "rep", "n": 2, "correct": False, "faults": ["Back"], "data": {}},
            {"t_ms": 56000, "type": "rep", "n": 3, "correct": True, "faults": [], "data": {}},
            {"t_ms": 76000, "type": "rep", "n": 4, "correct": True, "faults": [], "data": {}},
            {"t_ms": 80000, "type": "set_complete"},
        ]
        csv_rows = [
            ["C1", "P02", "ai", "plank", "1", "1", "15.0", "1", "Back", "TP"],
            ["C1", "P02", "ai", "plank", "1", "2", "35.0", "1", "", "FP"],
            ["C1", "P02", "ai", "plank", "1", "3", "55.0", "1", "Back", "FN"],
            ["C1", "P02", "ai", "plank", "1", "4", "75.0", "1", "", "TN"],
        ]
        res = _run_synthetic(
            {"plank.json": _make_set_json(participant_id="P02", exercise_id="plank", events=events)},
            csv_rows,
        )
        fd = _find_row(res.fault_detection_rows, exercise_id="plank", fault_id="Back")
        self.assertEqual((fd["tp"], fd["fp"], fd["fn"], fd["tn"]), (1, 1, 1, 1))
        self.assertAlmostEqual(float(fd["precision"]), 0.5)
        self.assertAlmostEqual(float(fd["recall"]), 0.5)

        # Confusion matrix for plank must sum to 4 and show (clean -> Back)=1, (Back -> clean)=1
        n_matched, _labels, grid = res.confusion_grids["plank"]
        self.assertEqual(n_matched, 4)
        self.assertEqual(sum(grid.values()), 4)
        self.assertEqual(grid[("Back", "Back")], 1)
        self.assertEqual(grid[("clean", "Back")], 1)
        self.assertEqual(grid[("Back", "clean")], 1)
        self.assertEqual(grid[("clean", "clean")], 1)

        # Wrong detections must contain exactly reps 2 (FP) and 3 (FN)
        self.assertEqual(len(res.wrong_detection_rows), 2)
        self.assertEqual(res.wrong_detection_rows[0]["false_positives"], "Back")
        self.assertEqual(res.wrong_detection_rows[1]["false_negatives"], "Back")

    def test_labels_without_times_fallback_to_order(self) -> None:
        """Empty video_t_s falls back to sequential order matching cleanly."""
        events = [
            {"t_ms": 5000, "type": "rep", "n": 1, "correct": True, "faults": [], "data": {}},
            {"t_ms": 9000, "type": "rep", "n": 2, "correct": False, "faults": ["sag"], "data": {}},
            {"t_ms": 20000, "type": "set_complete"},
        ]
        csv_rows = [
            ["C1", "P03", "ai", "push_up", "1", "1", "", "1", "", ""],
            ["C1", "P03", "ai", "push_up", "1", "2", "", "1", "sag", ""],
            ["C1", "P03", "ai", "push_up", "1", "3", "", "1", "", "trailing missed"],
        ]
        res = _run_synthetic(
            {"pu.json": _make_set_json(participant_id="P03", exercise_id="push_up", events=events)},
            csv_rows,
        )
        cnt = _find_row(res.counting_accuracy_rows, exercise_id="push_up")
        self.assertEqual((cnt["matched"], cnt["missed"], cnt["phantom"]), (2, 1, 0))
        methods = [r["match_method"] for r in res.rep_matching_rows]
        self.assertEqual(methods, ["order", "order", "unmatched"])
        fd = _find_row(res.fault_detection_rows, exercise_id="push_up", fault_id="sag")
        self.assertEqual((fd["tp"], fd["fp"], fd["fn"], fd["tn"]), (1, 0, 0, 1))

    def test_two_coaches_who_disagree_cohen_kappa_and_no_double_count(self) -> None:
        """Verify exact Cohen's kappa, degenerate marginals handling, and single-set counting."""
        events = [
            {"t_ms": 5000, "type": "rep", "n": 1, "correct": False, "faults": ["depth"], "data": {}},
            {"t_ms": 9000, "type": "rep", "n": 2, "correct": False, "faults": ["depth"], "data": {}},
            {"t_ms": 13000, "type": "rep", "n": 3, "correct": True, "faults": [], "data": {}},
            {"t_ms": 17000, "type": "rep", "n": 4, "correct": True, "faults": [], "data": {}},
            {"t_ms": 20000, "type": "set_complete"},
        ]
        # Over 4 reps on 'depth':
        # Rep 1: C1=depth, C2=depth (++)
        # Rep 2: C1=depth, C2=clean (+-)
        # Rep 3: C1=clean, C2=clean (--)
        # Rep 4: C1=clean, C2=clean (--)
        # => a=1, b=1, c=0, d=2, N=4
        # p_o = 3/4 = 0.75
        # p_e = (2/4)*(1/4) + (2/4)*(3/4) = 2/16 + 6/16 = 0.50
        # kappa = (0.75 - 0.50) / (1 - 0.50) = 0.50
        csv_rows = [
            ["C1", "P04", "ai", "squat", "1", "1", "4.0", "1", "depth", ""],
            ["C1", "P04", "ai", "squat", "1", "2", "8.0", "1", "depth", ""],
            ["C1", "P04", "ai", "squat", "1", "3", "12.0", "1", "", ""],
            ["C1", "P04", "ai", "squat", "1", "4", "16.0", "1", "", ""],
            ["C2", "P04", "ai", "squat", "1", "1", "4.1", "1", "depth", ""],
            ["C2", "P04", "ai", "squat", "1", "2", "8.1", "1", "", ""],
            ["C2", "P04", "ai", "squat", "1", "3", "12.1", "1", "", ""],
            ["C2", "P04", "ai", "squat", "1", "4", "16.1", "1", "", ""],
        ]
        res = _run_synthetic(
            {"sq.json": _make_set_json(participant_id="P04", events=events)},
            csv_rows,
        )
        # Physical set must be counted ONCE (4 reps, not 8) in counting_accuracy
        cnt = _find_row(res.counting_accuracy_rows, exercise_id="squat")
        self.assertEqual(cnt["matched"], 4)

        agr_depth = _find_row(res.coach_agreement_rows, exercise_id="squat", fault_id="depth")
        self.assertAlmostEqual(float(agr_depth["percent_agreement"]), 0.75)
        self.assertAlmostEqual(float(agr_depth["cohen_kappa"]), 0.50)
        self.assertEqual(agr_depth["kappa_note"], "")

        # Fault 'heel' was never seen by either coach -> degenerate marginals, no crash
        agr_heel = _find_row(res.coach_agreement_rows, exercise_id="squat", fault_id="heel")
        self.assertAlmostEqual(float(agr_heel["percent_agreement"]), 1.0)
        self.assertEqual(agr_heel["cohen_kappa"], "")
        self.assertEqual(agr_heel["kappa_note"], "undefined_degenerate_marginals")

    def test_cue_correction_and_control_suppressed_cues_and_cue_map(self) -> None:
        """Test cue followed by correction, cue not corrected, played=false control cues,
        cue-map lookup, unmapped count, and coach video_t_s human lag safety.
        """
        # Set 1 (ai): cue for 'depth' at 5150ms (after rep 1 at 5000ms; note coach marked rep 1
        # slightly late at rel 4.3s > 4.15s!), followed by 2 clean reps -> corrected next1 & next2!
        # Also has cue for 'heel' (via cue-map, no fault field in JSON) NOT corrected on next rep,
        # and an unmapped cue 'mystery.audio'.
        ai_events = [
            {"t_ms": 5000, "type": "rep", "n": 1, "correct": False, "faults": ["depth"], "data": {}},
            {"t_ms": 5150, "type": "cue", "key": "squat.depth", "played": True, "fault": "depth"},
            {"t_ms": 9000, "type": "rep", "n": 2, "correct": False, "faults": ["heel"], "data": {}},
            {"t_ms": 9100, "type": "cue", "key": "squat.heel", "played": True},  # mapped via cue_map
            {"t_ms": 9200, "type": "cue", "key": "mystery.audio", "played": True},  # unmapped
            {"t_ms": 13000, "type": "rep", "n": 3, "correct": False, "faults": ["heel"], "data": {}},
            {"t_ms": 13100, "type": "cue", "key": "squat.heel", "played": True},  # repeated!
            {"t_ms": 17000, "type": "rep", "n": 4, "correct": False, "faults": ["heel"], "data": {}},
            {"t_ms": 20000, "type": "set_complete"},
        ]
        # Set 2 (control): played=False cues must NOT be mixed into played=True spoken cues!
        ctrl_events = [
            {"t_ms": 5000, "type": "rep", "n": 1, "correct": False, "faults": ["depth"], "data": {}},
            {"t_ms": 5100, "type": "cue", "key": "squat.depth", "played": False, "fault": "depth"},
            {"t_ms": 9000, "type": "rep", "n": 2, "correct": False, "faults": ["depth"], "data": {}},
            {"t_ms": 13000, "type": "rep", "n": 3, "correct": False, "faults": ["depth"], "data": {}},
            {"t_ms": 20000, "type": "set_complete"},
        ]
        csv_rows = [
            # Notice rep 1 coach video_t_s = 4.3s > cue rel_t_s = 4.15s; anchor rule must skip rep 1!
            ["C1", "P05", "ai", "squat", "1", "1", "4.3", "1", "depth", ""],
            ["C1", "P05", "ai", "squat", "1", "2", "8.0", "1", "heel", ""],
            ["C1", "P05", "ai", "squat", "1", "3", "12.0", "1", "heel", ""],
            ["C1", "P05", "ai", "squat", "1", "4", "16.0", "1", "heel", ""],
            ["C1", "P05", "control", "squat", "1", "1", "4.0", "1", "depth", ""],
            ["C1", "P05", "control", "squat", "1", "2", "8.0", "1", "depth", ""],
            ["C1", "P05", "control", "squat", "1", "3", "12.0", "1", "depth", ""],
        ]
        cue_map_rows = [
            ["squat", "squat.heel", "heel"],
        ]
        res = _run_synthetic(
            {
                "ai.json": _make_set_json(participant_id="P05", condition="ai", events=ai_events),
                "ctrl.json": _make_set_json(
                    participant_id="P05", condition="control", events=ctrl_events
                ),
            },
            csv_rows,
            cue_map_rows=cue_map_rows,
        )

        # Cue mapping audit
        self.assertEqual(res.cue_mapping_summary["played_total"], 4)
        self.assertEqual(res.cue_mapping_summary["played_from_log_fault"], 1)
        self.assertEqual(res.cue_mapping_summary["played_from_cue_map"], 2)
        self.assertEqual(res.cue_mapping_summary["played_unmapped"], 1)
        self.assertEqual(res.cue_mapping_summary["unmapped_played_keys"], {"mystery.audio": 1})

        # Spoken 'depth' cue (played=true): corrected on next1 (1/1) and next2 (1/1), untouched by control!
        c_depth_true = _find_row(
            res.cue_correction_rows, played="true", exercise_id="squat", fault_id="depth"
        )
        self.assertEqual(c_depth_true["n_cues"], 1)
        self.assertEqual(c_depth_true["corrected_next1_coach"], 1)
        self.assertEqual(c_depth_true["corrected_next2_coach"], 1)

        # Spoken 'heel' cues (played=true): 2 cues; first has 2 reps after (0 corrected), second has 1 rep after (0 corrected)
        c_heel_true = _find_row(
            res.cue_correction_rows, played="true", exercise_id="squat", fault_id="heel"
        )
        self.assertEqual(c_heel_true["n_cues"], 2)
        self.assertEqual(c_heel_true["n_with_next1_coach"], 2)
        self.assertEqual(c_heel_true["corrected_next1_coach"], 0)
        self.assertEqual(c_heel_true["n_with_next2_coach"], 1)
        self.assertEqual(c_heel_true["corrected_next2_coach"], 0)

        # Suppressed 'depth' cue in control (played=false): reported separately with 0/1 corrected
        c_depth_false = _find_row(
            res.cue_correction_rows, played="false", exercise_id="squat", fault_id="depth"
        )
        self.assertEqual(c_depth_false["n_cues"], 1)
        self.assertEqual(c_depth_false["corrected_next1_coach"], 0)

        # Candidate sets: 'depth' in ai is a success; 'heel' in ai (cue_repeated=True) is a failure!
        succ = _find_row(res.cue_candidate_rows, candidate_type="success")
        self.assertEqual(succ["fault_id"], "depth")
        fail = _find_row(res.cue_candidate_rows, candidate_type="failure")
        self.assertEqual(fail["fault_id"], "heel")
        self.assertTrue(fail["cue_repeated"])
        self.assertEqual(fail["played_cue_count"], 2)

    def test_validation_warnings_and_recovery(self) -> None:
        """Verify plain-word warnings with file & line for unknown exercise/fault, missing log/labels,
        duplicated rows, and case/space participant_id differences.
        """
        s_valid = _make_set_json(
            participant_id="P07",
            condition="ai",
            exercise_id="squat",
            events=[
                {"t_ms": 5000, "type": "rep", "n": 1, "correct": True, "faults": [], "data": {}},
                {"t_ms": 20000, "type": "set_complete"},
            ],
        )
        s_no_labels = _make_set_json(
            participant_id="P07",
            condition="control",
            exercise_id="squat",
            events=[{"t_ms": 20000, "type": "set_complete"}],
        )
        s_bad_ex = _make_set_json(
            participant_id="P07",
            condition="ai",
            exercise_id="burpee",
        )
        csv_rows = [
            # Participant ID differs by case & spaces (' p07 '), unknown fault 'valgus' alongside valid 'depth'
            ["C1", " p07 ", "ai", "squat", "1", "1", "4.0", "1", "depth;valgus", ""],
            # Duplicate row for (C1, P07, ai, squat, 1, rep 1)
            ["C1", "P07", "ai", "squat", "1", "1", "4.0", "1", "depth", "dup"],
            # Unknown exercise in CSV
            ["C1", "P07", "ai", "lunge", "1", "1", "4.0", "1", "", ""],
            # Labels without matching log
            ["C1", "P07", "ai", "plank", "2", "1", "15.0", "1", "back", "lowercase back"],
        ]
        res = _run_synthetic(
            {
                "valid.json": s_valid,
                "unlabelled.json": s_no_labels,
                "bad_ex.json": s_bad_ex,
            },
            csv_rows,
        )
        codes = {iv.code for iv in res.issues}
        self.assertIn("case_space_participant_id", codes)
        self.assertIn("unknown_fault_id", codes)
        self.assertIn("duplicate_label_row", codes)
        self.assertIn("unknown_exercise_id", codes)
        self.assertIn("labels_without_log", codes)
        self.assertIn("log_without_labels", codes)
        self.assertIn("case_space_fault_id", codes)

        # Despite recoverable errors, ' p07 ' normalized to 'P07' and matched valid.json!
        cnt = _find_row(res.counting_accuracy_rows, exercise_id="squat")
        self.assertEqual(cnt["matched"], 1)

    def test_unseen_pause_overlap_paired_conditions_satisfaction_and_fps(self) -> None:
        """Verify unseen interval pause clipping, paired AI-vs-control outcomes, satisfaction & FPS."""
        # Active unseen 5000..10000 overlapped by pause 8000..12000 -> 3000ms effective active unseen!
        events = [
            {"t_ms": 5000, "type": "unseen_start", "phase": "active", "reason": "bodyInFrame"},
            {"t_ms": 8000, "type": "pause_start"},
            {"t_ms": 10000, "type": "unseen_end"},
            {"t_ms": 12000, "type": "pause_end"},
            {"t_ms": 16000, "type": "rep", "n": 1, "correct": True, "faults": [], "data": {}},
            {"t_ms": 20000, "type": "set_complete"},
        ]
        s_ai = _make_set_json(
            participant_id="P10",
            condition="ai",
            exercise_id="glute_bridge",
            events=events,
            active_ms=15000,
            unseen_ms=3000,
            paused_ms=4000,
            mean_fps=29.0,
            min_fps_1s=21.0,
        )
        s_ctrl = _make_set_json(
            participant_id="P10",
            condition="control",
            exercise_id="glute_bridge",
            events=[
                {"t_ms": 6000, "type": "rep", "n": 1, "correct": False, "faults": ["neck_head"], "data": {}},
                {"t_ms": 20000, "type": "set_complete"},
            ],
            active_ms=15000,
            unseen_ms=0,
            mean_fps=19.0,
            min_fps_1s=11.0,
        )
        sessions = {
            "sess_ai.json": {
                "schema": 1,
                "kind": "session",
                "session_id": "S1",
                "participant_id": "P10",
                "condition": "ai",
                "satisfaction": 5,
                "files": [],
            },
            "sess_ai2.json": {
                "schema": 1,
                "kind": "session",
                "session_id": "S2",
                "participant_id": "P10",
                "condition": "ai",
                "satisfaction": None,
                "files": [],
            },
            "sess_ctrl.json": {
                "schema": 1,
                "kind": "session",
                "session_id": "S3",
                "participant_id": "P10",
                "condition": "control",
                "satisfaction": 3,
                "files": [],
            },
        }
        csv_rows = [
            ["C1", "P10", "ai", "glute_bridge", "1", "1", "15.0", "1", "", ""],
            ["C1", "P10", "control", "glute_bridge", "1", "1", "5.0", "1", "neck_head", ""],
        ]
        res = _run_synthetic({"ai.json": s_ai, "ctrl.json": s_ctrl}, csv_rows, session_jsons=sessions)

        ut = _find_row(res.unseen_time_rows, exercise_id="glute_bridge")
        self.assertAlmostEqual(float(ut["unseen_over_active_ratio"]), 3000 / 30000)
        ur = _find_row(
            res.unseen_reason_rows,
            exercise_id="glute_bridge",
            phase="active",
            reason="bodyInFrame",
        )
        self.assertEqual(ur["duration_ms"], 3000)

        avc = _find_row(res.ai_vs_control_summary_rows, exercise_id="overall")
        self.assertEqual(avc["n_paired_participants"], 1)
        self.assertEqual(avc["n_improved"], 1)
        self.assertAlmostEqual(float(avc["mean_paired_diff_ai_minus_control"]), -1.0)

        sat_ai = _find_row(res.satisfaction_rows, condition="ai")
        self.assertEqual((sat_ai["n_sessions_total"], sat_ai["n_responses"], sat_ai["n_missing"]), (2, 1, 1))
        self.assertAlmostEqual(float(sat_ai["mean_satisfaction"]), 5.0)

        fps = _find_row(res.frame_rate_rows, exercise_id="glute_bridge")
        self.assertAlmostEqual(float(fps["mean_of_mean_fps"]), 24.0)
        self.assertAlmostEqual(float(fps["worst_mean_fps"]), 19.0)
        self.assertAlmostEqual(float(fps["worst_min_fps_1s"]), 11.0)

    def test_empty_set_marker_zero_reps_with_phantom_app_rep(self) -> None:
        """Coach marks rep_n=0, counted=0 for an empty set; app's 1 rep becomes a phantom count."""
        s1 = _make_set_json(
            participant_id="P11",
            condition="ai",
            exercise_id="plank",
            events=[
                {"t_ms": 16000, "type": "rep", "n": 1, "correct": True, "faults": [], "data": {}},
                {"t_ms": 20000, "type": "set_complete"},
            ],
        )
        csv_rows = [
            ["C1", "P11", "ai", "plank", "1", "0", "", "0", "", "no completed 15s hold"],
        ]
        res = _run_synthetic({"p.json": s1}, csv_rows)
        codes = {iv.code for iv in res.issues}
        self.assertNotIn("log_without_labels", codes)
        cnt = _find_row(res.counting_accuracy_rows, exercise_id="plank")
        self.assertEqual(cnt["coach_valid_reps"], 0)
        self.assertEqual(cnt["coach_uncounted_attempts"], 0)
        self.assertEqual(cnt["app_reps"], 1)
        self.assertEqual(cnt["matched"], 0)
        self.assertEqual(cnt["phantom"], 1)

    def test_null_sync_beep_falls_back_to_order_and_same_frame_cue_skips_current_rep(self) -> None:
        """sync_beep_t_ms=None falls back to order with warning; cue at same t_ms as rep 1 checks rep 2."""
        events = [
            {"t_ms": 5000, "type": "rep", "n": 1, "correct": False, "faults": ["depth"], "data": {}},
            {"t_ms": 5000, "type": "cue", "key": "squat.depth", "played": True, "fault": "depth"},
            {"t_ms": 9000, "type": "rep", "n": 2, "correct": True, "faults": [], "data": {}},
            {"t_ms": 20000, "type": "set_complete"},
        ]
        s1 = _make_set_json(sync_beep_t_ms=None, events=events)
        csv_rows = [
            ["C1", "P01", "ai", "squat", "1", "1", "4.0", "1", "depth", ""],
            ["C1", "P01", "ai", "squat", "1", "2", "8.0", "1", "", ""],
        ]
        res = _run_synthetic({"s.json": s1}, csv_rows)
        self.assertIn("missing_sync_beep_fallback_order", {iv.code for iv in res.issues})
        cnt = _find_row(res.counting_accuracy_rows, exercise_id="squat")
        self.assertEqual(cnt["matched"], 2)

        # Cue at t_ms=5000 must evaluate rep 2 (clean), NOT rep 1 (depth) at the same t_ms=5000
        cue_row = _find_row(
            res.cue_correction_rows, played="true", exercise_id="squat", fault_id="depth"
        )
        self.assertEqual(cue_row["n_with_next1_app"], 1)
        self.assertEqual(cue_row["corrected_next1_app"], 1)
        self.assertEqual(cue_row["n_with_next1_coach"], 1)
        self.assertEqual(cue_row["corrected_next1_coach"], 1)

    def test_dp_tie_breaking_prefers_earliest_index_and_clamps_unseen_ms(self) -> None:
        """Equidistant time candidates pick earliest index; unseen_ms > active_ms is clamped."""
        # Coach at 10.0s is equidistant (1.0s) from app reps at 9.0s and 11.0s -> must pick app rep 1 (9.0s)
        events = [
            {"t_ms": 5000, "type": "unseen_start", "phase": "active", "reason": "lighting"},
            # No unseen_end and no set_complete (user quit at duration_ms=20000)
            {"t_ms": 10000, "type": "rep", "n": 1, "correct": True, "faults": [], "data": {}},
            {"t_ms": 12000, "type": "rep", "n": 2, "correct": False, "faults": ["heel"], "data": {}},
        ]
        s1 = _make_set_json(sync_beep_t_ms=1000, events=events, active_ms=10000, unseen_ms=15000)
        csv_rows = [
            ["C1", "P01", "ai", "squat", "1", "1", "10.0", "1", "", ""],
        ]
        res = _run_synthetic({"s.json": s1}, csv_rows)
        self.assertIn("unseen_exceeds_active_ms", {iv.code for iv in res.issues})
        ut = _find_row(res.unseen_time_rows, exercise_id="squat")
        self.assertLessEqual(float(ut["unseen_over_active_ratio"]), 1.0)

        matched_row = _find_row(res.rep_matching_rows, status="matched")
        self.assertEqual(matched_row["app_rep_n"], 1)
        phantom_row = _find_row(res.rep_matching_rows, status="phantom")
        self.assertEqual(phantom_row["app_rep_n"], 2)

    def test_excel_bom_decimal_comma_mmss_corrupt_json_and_duplicate_set_logs(self) -> None:
        """Verify BOM CSV, '12,4' decimal comma, '1:05.0' mm:ss, corrupt JSON recovery, and multi-CSV."""
        with tempfile.TemporaryDirectory() as tmp:
            # Include Vietnamese characters in directory name to test Windows console UTF-8 safety
            root = Path(tmp) / "Thử_nghiệm_Vika"
            logs_dir = root / "logs"
            logs_dir.mkdir(parents=True)

            # Broken JSON file
            (logs_dir / "corrupt.json").write_text("{bad json\nline 2", encoding="utf-8")

            # Aborted duplicate set log vs completed set log for (P01, ai, squat, 1)
            aborted = _make_set_json(
                events=[{"t_ms": 5000, "type": "rep", "n": 1, "correct": True, "faults": [], "data": {}}]
            )
            completed = _make_set_json(
                sync_beep_t_ms=1000,
                events=[
                    {"t_ms": 13400, "type": "rep", "n": 1, "correct": True, "faults": [], "data": {}},
                    {"t_ms": 66000, "type": "rep", "n": 2, "correct": False, "faults": ["trunk"], "data": {}},
                    {"t_ms": 70000, "type": "set_complete"},
                ],
            )
            (logs_dir / "01_aborted.json").write_text(json.dumps(aborted), encoding="utf-8")
            (logs_dir / "02_completed.json").write_text(json.dumps(completed), encoding="utf-8")

            # UTF-8 with BOM CSV + decimal comma '12,4' + mm:ss '1:05.0' + Vietnamese bad fault token
            c1_csv = root / "c1_bom.csv"
            c1_text = (
                "coach_id,participant_id,condition,exercise_id,set_index,rep_n,video_t_s,counted,faults,note\n"
                'C1,P01,ai,squat,1,1,"12,4",1,lỗi_lạ,dấu phẩy thập phân\n'
                "C1,P01,ai,squat,1,2,1:05.0,1,trunk,định dạng phút giây\n"
            )
            c1_csv.write_bytes(c1_text.encode("utf-8-sig"))

            c2_csv = root / "c2.csv"
            c2_csv.write_text(
                "coach_id,participant_id,condition,exercise_id,set_index,rep_n,video_t_s,counted,faults,note\n"
                "C2,P01,ai,squat,1,1,12.4,1,,\n"
                "C2,P01,ai,squat,1,2,65.0,1,trunk,\n",
                encoding="utf-8",
            )

            out_dir = root / "out"
            rc = evaluate.main(
                [
                    "--logs",
                    str(logs_dir),
                    "--labels",
                    str(c1_csv),
                    str(c2_csv),
                    "--out",
                    str(out_dir),
                ]
            )
            self.assertEqual(rc, 0)
            with (out_dir / "counting_accuracy.csv").open("r", encoding="utf-8") as fh:
                ca = list(csv.DictReader(fh))
            sq = _find_row(ca, exercise_id="squat")
            self.assertEqual(int(sq["matched"]), 2)
            with (out_dir / "validation_issues.csv").open("r", encoding="utf-8") as fh:
                v_codes = {r["code"] for r in csv.DictReader(fh)}
            self.assertIn("invalid_json", v_codes)
            self.assertIn("duplicate_set_log", v_codes)
            self.assertIn("decimal_comma_video_t_s", v_codes)
            self.assertIn("unknown_fault_id", v_codes)

    def test_live_mid_rep_cue_advances_cutoff_past_triggering_rep_and_respects_rep_start_reminder(
        self,
    ) -> None:
        """Live mid-rep cues emitted inside fault_start..fault_end evaluate subsequent reps
        after the triggering rep completes, while rep-start *_reminder cues evaluate the
        rep they precede and aborted live-fault attempts evaluate the next completed rep.
        """
        events = [
            # 1) Live mid-rep cue on rep 1: fault_start(7200) -> cue(7200) -> fault_end(8500) + rep 1(8500, trunk)
            {"t_ms": 7200, "type": "fault_start", "fault": "trunk"},
            {"t_ms": 7200, "type": "cue", "key": "squat.trunk", "played": True, "fault": "trunk"},
            {"t_ms": 8500, "type": "fault_end", "fault": "trunk"},
            {"t_ms": 8500, "type": "rep", "n": 1, "correct": False, "faults": ["trunk"], "data": {}},
            # Reps 2 & 3 are clean -> trunk live cue MUST be 100% corrected on next1 and next2!
            {"t_ms": 12000, "type": "rep", "n": 2, "correct": True, "faults": [], "data": {}},
            {"t_ms": 15500, "type": "rep", "n": 3, "correct": True, "faults": [], "data": {}},
            # 2) Rep-start reminder cue for 'depth' (no active fault_start) before rep 4 (which still has depth)
            {"t_ms": 16000, "type": "cue", "key": "squat.depth_reminder", "played": True},
            {"t_ms": 19000, "type": "rep", "n": 4, "correct": False, "faults": ["depth"], "data": {}},
            # 3) Aborted live fault 'heel' (fault_start -> cue -> fault_end with NO rep at 19800), then clean rep 5
            {"t_ms": 19200, "type": "fault_start", "fault": "heel"},
            {"t_ms": 19200, "type": "cue", "key": "squat.heel", "played": True, "fault": "heel"},
            {"t_ms": 19800, "type": "fault_end", "fault": "heel"},
            {"t_ms": 23000, "type": "rep", "n": 5, "correct": True, "faults": [], "data": {}},
            {"t_ms": 25000, "type": "set_complete"},
        ]
        csv_rows = [
            ["C1", "P01", "ai", "squat", "1", "1", "7.5", "1", "trunk", ""],
            ["C1", "P01", "ai", "squat", "1", "2", "11.0", "1", "", ""],
            ["C1", "P01", "ai", "squat", "1", "3", "14.5", "1", "", ""],
            ["C1", "P01", "ai", "squat", "1", "4", "18.0", "1", "depth", ""],
            ["C1", "P01", "ai", "squat", "1", "5", "22.0", "1", "", ""],
        ]
        cue_map_rows = [["squat", "squat.depth_reminder", "depth"]]
        res = _run_synthetic(
            {"s.json": _make_set_json(events=events, active_ms=25000)},
            csv_rows,
            cue_map_rows=cue_map_rows,
        )

        # 1) Live mid-rep 'trunk' cue must skip triggering rep 1 and score 1/1 on next1 & next2
        c_trunk = _find_row(
            res.cue_correction_rows, played="true", exercise_id="squat", fault_id="trunk"
        )
        self.assertEqual(c_trunk["n_with_next1_app"], 1)
        self.assertEqual(c_trunk["corrected_next1_app"], 1)
        self.assertEqual(c_trunk["n_with_next2_app"], 1)
        self.assertEqual(c_trunk["corrected_next2_app"], 1)
        self.assertEqual(c_trunk["corrected_next1_coach"], 1)
        self.assertEqual(c_trunk["corrected_next2_coach"], 1)

        # 2) Rep-start 'depth_reminder' cue must evaluate rep 4 -> 0/1 corrected
        c_depth = _find_row(
            res.cue_correction_rows, played="true", exercise_id="squat", fault_id="depth"
        )
        self.assertEqual(c_depth["n_with_next1_app"], 1)
        self.assertEqual(c_depth["corrected_next1_app"], 0)
        self.assertEqual(c_depth["corrected_next1_coach"], 0)

        # 3) Aborted live 'heel' attempt must evaluate rep 5 -> 1/1 corrected
        c_heel = _find_row(
            res.cue_correction_rows, played="true", exercise_id="squat", fault_id="heel"
        )
        self.assertEqual(c_heel["n_with_next1_app"], 1)
        self.assertEqual(c_heel["corrected_next1_app"], 1)
        self.assertEqual(c_heel["corrected_next1_coach"], 1)

    def test_partial_timestamp_matching_respects_chronological_neighbor_bounds(self) -> None:
        """Untimed coach rows between timed anchors must never match backwards before earlier timed rows."""
        # Case A: Coach = [8.0, None, 15.0], App = [1.0, 11.5, 15.0], tol = 2.5
        res_a = evaluate.match_timed_or_ordered(
            [8.0, None, 15.0], [1.0, 11.5, 15.0], tolerance_s=2.5, can_use_time=True
        )
        self.assertEqual(res_a, [(1, 1, "order", None), (2, 2, "time", 0.0)])

        # Verify end-to-end rep_matching_rows preserve monotonic order
        events = [
            {"t_ms": 2000, "type": "rep", "n": 1, "correct": True, "faults": [], "data": {}},
            {"t_ms": 12500, "type": "rep", "n": 2, "correct": False, "faults": ["depth"], "data": {}},
            {"t_ms": 16000, "type": "rep", "n": 3, "correct": True, "faults": [], "data": {}},
            {"t_ms": 20000, "type": "set_complete"},
        ]
        csv_rows = [
            ["C1", "P01", "ai", "squat", "1", "1", "8.0", "1", "", "missed"],
            ["C1", "P01", "ai", "squat", "1", "2", "", "1", "depth", "untimed after 8.0s"],
            ["C1", "P01", "ai", "squat", "1", "3", "15.0", "1", "", ""],
        ]
        eval_res = _run_synthetic({"s.json": _make_set_json(events=events)}, csv_rows)
        statuses = [
            (r["status"], r["coach_rep_n"], r["app_rep_n"]) for r in eval_res.rep_matching_rows
        ]
        self.assertEqual(
            statuses,
            [
                ("phantom", "", 1),
                ("missed", 1, ""),
                ("matched", 2, 2),
                ("matched", 3, 3),
            ],
        )

        # Case B: Coach = [10.0, None], App = [8.5, 10.0], tol = 2.5
        # Timed DP matches 10.0 <-> 10.0 (|Δt| = 0.0) rather than shifting 10.0 -> 8.5
        res_b = evaluate.match_timed_or_ordered(
            [10.0, None], [8.5, 10.0], tolerance_s=2.5, can_use_time=True
        )
        self.assertEqual(res_b, [(0, 1, "time", 0.0)])

    def test_ai_vs_control_overall_pairs_common_exercises_and_rejects_disjoint_pairing(
        self,
    ) -> None:
        """Within-participant overall paired difference must compare common exercises only,
        preventing Simpson's paradox from single-condition exercises and disjoint-exercise pairing.
        """
        # P20: squat improved from 2/4 (50%) in control to 1/4 (25%) in ai (-25% diff),
        #      plus plank ONLY in ai with 2/2 (100% fault).
        #      Pooled naive diff would be (3/6 - 2/4) = 0% (or worse if 3/3 = +25%!),
        #      whereas exercise-matched paired diff on common exercise 'squat' is -0.25 (improved)!
        # P21: squat ONLY in ai (0/2 = 0%) and plank ONLY in control (2/2 = 100%) -> disjoint!
        csv_rows = [
            ["C1", "P20", "control", "squat", "1", "1", "4.0", "1", "depth", ""],
            ["C1", "P20", "control", "squat", "1", "2", "8.0", "1", "depth", ""],
            ["C1", "P20", "control", "squat", "1", "3", "12.0", "1", "", ""],
            ["C1", "P20", "control", "squat", "1", "4", "16.0", "1", "", ""],
            ["C1", "P20", "ai", "squat", "1", "1", "4.0", "1", "depth", ""],
            ["C1", "P20", "ai", "squat", "1", "2", "8.0", "1", "", ""],
            ["C1", "P20", "ai", "squat", "1", "3", "12.0", "1", "", ""],
            ["C1", "P20", "ai", "squat", "1", "4", "16.0", "1", "", ""],
            ["C1", "P20", "ai", "plank", "1", "1", "15.0", "1", "Back", ""],
            ["C1", "P20", "ai", "plank", "1", "2", "32.0", "1", "Back", ""],
            ["C1", "P20", "ai", "plank", "1", "3", "49.0", "1", "Back", ""],
            # P21 disjoint exercises across conditions
            ["C1", "P21", "ai", "squat", "1", "1", "4.0", "1", "", ""],
            ["C1", "P21", "ai", "squat", "1", "2", "8.0", "1", "", ""],
            ["C1", "P21", "control", "plank", "1", "1", "15.0", "1", "Back", ""],
            ["C1", "P21", "control", "plank", "1", "2", "32.0", "1", "Back", ""],
        ]
        set_jsons = {
            "p20_ctrl_sq.json": _make_set_json("P20", "control", "squat"),
            "p20_ai_sq.json": _make_set_json("P20", "ai", "squat"),
            "p20_ai_pl.json": _make_set_json("P20", "ai", "plank"),
            "p21_ai_sq.json": _make_set_json("P21", "ai", "squat"),
            "p21_ctrl_pl.json": _make_set_json("P21", "control", "plank"),
        }
        res = _run_synthetic(set_jsons, csv_rows)

        p20 = _find_row(res.ai_vs_control_participant_rows, participant_id="P20")
        self.assertEqual(p20["paired_exercises"], "squat")
        self.assertEqual(p20["exercises_balanced"], "false")
        self.assertAlmostEqual(float(p20["paired_diff_ai_minus_control"]), -0.25)
        self.assertEqual(p20["outcome"], "improved")

        p21 = _find_row(res.ai_vs_control_participant_rows, participant_id="P21")
        self.assertEqual(p21["paired_exercises"], "")
        self.assertEqual(p21["paired_diff_ai_minus_control"], "")
        self.assertEqual(p21["outcome"], "incomplete_pair")

        overall = _find_row(res.ai_vs_control_summary_rows, exercise_id="overall")
        self.assertEqual(overall["n_paired_participants"], 1)
        self.assertEqual(overall["n_improved"], 1)
        self.assertAlmostEqual(float(overall["mean_paired_diff_ai_minus_control"]), -0.25)

    def test_extra_csv_columns_unquoted_comma_float_integers_and_separator_normalization(
        self,
    ) -> None:
        """Unquoted extra CSV commas emit warning + recover shifted fault; '1.0' ints and
        space/hyphen exercise/fault names normalize cleanly with warnings.
        """
        events_sq = [
            {"t_ms": 5000, "type": "rep", "n": 1, "correct": False, "faults": ["depth", "heel"], "data": {}},
            {"t_ms": 20000, "type": "set_complete"},
        ]
        events_gb = [
            {"t_ms": 6000, "type": "rep", "n": 1, "correct": False, "faults": ["hip_extension"], "data": {}},
            {"t_ms": 20000, "type": "set_complete"},
        ]
        # Row 1 has 11 columns because user typed unquoted `depth,heel` in faults!
        # Row 2 uses `glute-bridge`, `"1.0"` for set_index/rep_n/counted, and `hip extension` with space!
        csv_rows = [
            ["C1", "P01", "ai", "squat", "1", "1", "4.0", "1", "depth", "heel", ""],
            ["C1", "P01", "ai", "glute-bridge", "1.0", "1.0", "5.0", "1.0", "hip extension", ""],
            ["C1", "P01", "ai", "Push Up", "1.0", "1.0", "6.0", "0.0", "", "half rep"],
        ]
        res = _run_synthetic(
            {
                "sq.json": _make_set_json("P01", "ai", "squat", events=events_sq),
                "gb.json": _make_set_json("P01", "ai", "glute_bridge", events=events_gb),
                "pu.json": _make_set_json("P01", "ai", "push_up"),
            },
            csv_rows,
        )
        codes = {iv.code for iv in res.issues}
        self.assertIn("extra_csv_columns", codes)
        self.assertIn("coerced_float_integer", codes)
        self.assertIn("coerced_counted", codes)
        self.assertIn("case_space_exercise_id", codes)
        self.assertIn("case_space_fault_id", codes)

        # Verify 'heel' was recovered from the shifted 10th column -> TP=1, FN=0!
        fd_heel = _find_row(res.fault_detection_rows, exercise_id="squat", fault_id="heel")
        self.assertEqual((fd_heel["tp"], fd_heel["fp"], fd_heel["fn"]), (1, 0, 0))

        # Verify 'hip extension' normalized to 'hip_extension' on 'glute_bridge' -> TP=1!
        fd_gb = _find_row(
            res.fault_detection_rows, exercise_id="glute_bridge", fault_id="hip_extension"
        )
        self.assertEqual((fd_gb["tp"], fd_gb["fp"], fd_gb["fn"]), (1, 0, 0))

    def test_directory_label_scan_excludes_output_dir_cue_map_and_template_csv(self) -> None:
        """Running --labels <dir> --out <dir>/results twice must ignore generated CSVs,
        cue_fault_map.csv, and coach_labels_template.csv.
        """
        with tempfile.TemporaryDirectory() as tmp:
            eval_data = Path(tmp) / "eval_data"
            logs_dir = eval_data / "logs"
            out_dir = eval_data / "results"
            logs_dir.mkdir(parents=True)

            s1 = _make_set_json(
                "P01",
                "ai",
                "squat",
                events=[
                    {"t_ms": 5000, "type": "rep", "n": 1, "correct": True, "faults": [], "data": {}},
                    {"t_ms": 20000, "type": "set_complete"},
                ],
            )
            (logs_dir / "s1.json").write_text(json.dumps(s1), encoding="utf-8")

            # Real coach CSV
            (eval_data / "coach_c1.csv").write_text(
                "coach_id,participant_id,condition,exercise_id,set_index,rep_n,video_t_s,counted,faults,note\n"
                "C1,P01,ai,squat,1,1,4.0,1,,\n",
                encoding="utf-8",
            )
            # Copy template CSV (contains fake P07 rows!) and cue_fault_map.csv into same folder
            (eval_data / "coach_labels_template.csv").write_text(
                (EVAL_DIR / "coach_labels_template.csv").read_text(encoding="utf-8"),
                encoding="utf-8",
            )
            cmap_copy = eval_data / "cue_fault_map.csv"
            cmap_copy.write_text(
                (EVAL_DIR / "cue_fault_map.csv").read_text(encoding="utf-8"),
                encoding="utf-8",
            )

            argv = [
                "--logs",
                str(logs_dir),
                "--labels",
                str(eval_data),
                "--cue-map",
                str(cmap_copy),
                "--out",
                str(out_dir),
            ]
            # Run 1 writes 16 CSVs into eval_data/results/
            self.assertEqual(evaluate.main(argv), 0)
            # Run 2 scans eval_data recursively again when eval_data/results/*.csv already exist!
            self.assertEqual(evaluate.main(argv), 0)

            with (out_dir / "validation_issues.csv").open("r", encoding="utf-8") as fh:
                issues = list(csv.DictReader(fh))
            self.assertEqual(issues, [])

    def test_untimed_inter_coach_agreement_aligns_by_attempt_rep_n_when_counted_differs(
        self,
    ) -> None:
        """Untimed multi-coach sets with identical attempt rep_n align by rep_n even when
        one coach marks attempt 2 as counted=0, and zero kappa never formats as '-0.000'.
        """
        events = [
            {"t_ms": 5000, "type": "rep", "n": 1, "correct": False, "faults": ["depth"], "data": {}},
            {"t_ms": 13000, "type": "rep", "n": 2, "correct": False, "faults": ["trunk"], "data": {}},
            {"t_ms": 17000, "type": "rep", "n": 3, "correct": True, "faults": [], "data": {}},
            {"t_ms": 20000, "type": "set_complete"},
        ]
        csv_rows = [
            # Coach C1 marks attempt 2 counted=0; Coach C2 marks attempt 2 counted=1
            ["C1", "P01", "ai", "squat", "1", "1", "", "1", "depth", ""],
            ["C1", "P01", "ai", "squat", "1", "2", "", "0", "", "half rep"],
            ["C1", "P01", "ai", "squat", "1", "3", "", "1", "trunk", ""],
            ["C1", "P01", "ai", "squat", "1", "4", "", "1", "", ""],
            ["C2", "P01", "ai", "squat", "1", "1", "", "1", "depth", ""],
            ["C2", "P01", "ai", "squat", "1", "2", "", "1", "", "borderline"],
            ["C2", "P01", "ai", "squat", "1", "3", "", "1", "trunk", ""],
            ["C2", "P01", "ai", "squat", "1", "4", "", "1", "", ""],
        ]
        res = _run_synthetic({"s.json": _make_set_json(events=events)}, csv_rows)
        agr_trunk = _find_row(res.coach_agreement_rows, exercise_id="squat", fault_id="trunk")
        self.assertEqual(agr_trunk["n_matched_valid_reps"], 3)
        self.assertAlmostEqual(float(agr_trunk["percent_agreement"]), 1.0)
        self.assertAlmostEqual(float(agr_trunk["cohen_kappa"]), 1.0)

        # Verify exact zero in cohen_kappa_binary (previously -1e-16 -> '-0.000')
        p_o, kap, note = evaluate.cohen_kappa_binary(0, 0, 1, 2)
        self.assertAlmostEqual(p_o, 2.0 / 3.0)
        self.assertEqual(kap, 0.0)
        self.assertEqual(note, "")
        self.assertFalse(math.copysign(1.0, kap) < 0)

    def test_candidate_ranking_session_dedup_set_dedup_priority_and_form_faults_only(
        self,
    ) -> None:
        """Verify candidate ranking prefers coach-confirmed prior fault, session dedup,
        set dedup preferring has_set_complete over session.files, --form-faults-only, and
        multi-line JSON exact event line diagnostics.
        """
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            logs_dir = root / "logs"
            (logs_dir / "sub").mkdir(parents=True)

            # Set A (P01): False-positive cue after clean rep 1, followed by clean rep 2
            s_fp = _make_set_json(
                "P01",
                "ai",
                "squat",
                events=[
                    {"t_ms": 5000, "type": "rep", "n": 1, "correct": False, "faults": ["depth"], "data": {}},
                    {"t_ms": 5100, "type": "cue", "key": "squat.depth", "played": True, "fault": "depth"},
                    {"t_ms": 9000, "type": "rep", "n": 2, "correct": True, "faults": [], "data": {}},
                    {"t_ms": 13000, "type": "rep", "n": 3, "correct": True, "faults": [], "data": {}},
                    {"t_ms": 20000, "type": "set_complete"},
                ],
            )
            # Set B (P02): Coach-confirmed 'depth' on rep 1, cue, then 2 clean reps -> MUST rank first!
            # Also include a second event with bad fault on multi-line JSON to verify line number!
            s_true = _make_set_json(
                "P02",
                "ai",
                "squat",
                events=[
                    {"t_ms": 5000, "type": "rep", "n": 1, "correct": False, "faults": ["depth"], "data": {}},
                    {"t_ms": 5100, "type": "cue", "key": "squat.depth", "played": True, "fault": "depth"},
                    {"t_ms": 9000, "type": "rep", "n": 2, "correct": True, "faults": ["bogus_fault"], "data": {}},
                    {"t_ms": 13000, "type": "rep", "n": 3, "correct": True, "faults": [], "data": {}},
                    {"t_ms": 20000, "type": "set_complete"},
                ],
            )
            # Set C (P03 plank): Duplicate aborted 0-rep set listed in session.files vs completed 1-hold set
            # where completed hold has soft warning (correct=True, faults=['Back'])
            s_aborted = _make_set_json("P03", "ai", "plank", events=[])
            s_plank_complete = _make_set_json(
                "P03",
                "ai",
                "plank",
                events=[
                    {
                        "t_ms": 16000,
                        "type": "rep",
                        "n": 1,
                        "correct": True,
                        "faults": ["Back"],
                        "data": {"fault_affects_form": {"Back": False}},
                    },
                    {"t_ms": 20000, "type": "set_complete"},
                ],
            )
            sess_payload = {
                "schema": 1,
                "kind": "session",
                "session_id": "S-DUP",
                "participant_id": "P03",
                "condition": "ai",
                "satisfaction": 4,
                "files": ["plank_aborted.json"],
            }

            (logs_dir / "p01.json").write_text(json.dumps(s_fp, indent=2), encoding="utf-8")
            p02_text = json.dumps(s_true, indent=2)
            (logs_dir / "p02.json").write_text(p02_text, encoding="utf-8")
            expected_bogus_line = next(
                idx for idx, ln in enumerate(p02_text.splitlines(), 1) if "bogus_fault" in ln
            )
            (logs_dir / "plank_aborted.json").write_text(json.dumps(s_aborted), encoding="utf-8")
            (logs_dir / "plank_complete.json").write_text(
                json.dumps(s_plank_complete), encoding="utf-8"
            )
            (logs_dir / "session.json").write_text(json.dumps(sess_payload), encoding="utf-8")
            (logs_dir / "sub" / "session_copy.json").write_text(
                json.dumps(sess_payload), encoding="utf-8"
            )

            labels_csv = root / "labels.csv"
            labels_csv.write_text(
                "coach_id,participant_id,condition,exercise_id,set_index,rep_n,video_t_s,counted,faults,note\n"
                "C1,P01,ai,squat,1,1,4.0,1,,FP on rep 1\n"
                "C1,P01,ai,squat,1,2,8.0,1,,\n"
                "C1,P01,ai,squat,1,3,12.0,1,,\n"
                "C1,P02,ai,squat,1,1,4.0,1,depth,True fault on rep 1\n"
                "C1,P02,ai,squat,1,2,8.0,1,,\n"
                "C1,P02,ai,squat,1,3,12.0,1,,\n"
                "C1,P03,ai,plank,1,1,15.0,1,,clean hold\n",
                encoding="utf-8",
            )

            out_default = root / "out_default"
            self.assertEqual(
                evaluate.main(
                    ["--logs", str(logs_dir), "--labels", str(labels_csv), "--out", str(out_default)]
                ),
                0,
            )
            # Default mode keeps soft warning 'Back' -> 1 FP on plank; --form-faults-only filters it -> 0 FP!
            out_strict = root / "out_strict"
            self.assertEqual(
                evaluate.main(
                    [
                        "--logs",
                        str(logs_dir),
                        "--labels",
                        str(labels_csv),
                        "--form-faults-only",
                        "--out",
                        str(out_strict),
                    ]
                ),
                0,
            )

            with (out_default / "fault_detection.csv").open("r", encoding="utf-8") as fh:
                fd_def = _find_row(list(csv.DictReader(fh)), exercise_id="plank", fault_id="Back")
            with (out_strict / "fault_detection.csv").open("r", encoding="utf-8") as fh:
                fd_str = _find_row(list(csv.DictReader(fh)), exercise_id="plank", fault_id="Back")
            self.assertEqual(int(fd_def["fp"]), 1)
            self.assertEqual(int(fd_str["fp"]), 0)

            # Candidate ranking: P02 (coach-confirmed prior fault) must rank #1 ahead of P01 (FP cue)
            with (out_default / "cue_candidates.csv").open("r", encoding="utf-8") as fh:
                cands = [r for r in csv.DictReader(fh) if r["candidate_type"] == "success"]
            self.assertEqual(cands[0]["participant_id"], "P02")

            # Session deduplication: S-DUP counted once (n_sessions_total == 1)
            with (out_default / "satisfaction.csv").open("r", encoding="utf-8") as fh:
                sat = _find_row(list(csv.DictReader(fh)), condition="ai")
            self.assertEqual(int(sat["n_sessions_total"]), 1)

            # Exact multi-line JSON line number for bogus_fault on rep 2
            with (out_default / "validation_issues.csv").open("r", encoding="utf-8") as fh:
                v_rows = list(csv.DictReader(fh))
            codes = {r["code"] for r in v_rows}
            self.assertIn("duplicate_session_log", codes)
            bogus_issue = _find_row(v_rows, code="unknown_fault_id")
            self.assertTrue(
                abs(int(bogus_issue["line"]) - expected_bogus_line) <= 7,
                f"Expected line near {expected_bogus_line}, got {bogus_issue['line']}",
            )

    def test_out_of_order_rep_n_recovery_timed_and_untimed_and_redundant_zero_rep(self) -> None:
        """Excel-sorted out-of-order rep_n rows emit rep_n_out_of_order, restore rep_n order
        before matching (no false missed/phantom or bogus non_monotonic_video_t_s), while
        genuine timestamp inversions vs rep_n still warn and redundant rep_n=0 is ignored.
        """
        sq_events = [
            {"t_ms": 5000, "type": "rep", "n": 1, "correct": True, "faults": [], "data": {}},
            {"t_ms": 9000, "type": "rep", "n": 2, "correct": True, "faults": [], "data": {}},
            {"t_ms": 13000, "type": "rep", "n": 3, "correct": False, "faults": ["depth"], "data": {}},
            {"t_ms": 20000, "type": "set_complete"},
        ]
        pu_events = [
            {"t_ms": 5000, "type": "rep", "n": 1, "correct": True, "faults": [], "data": {}},
            {"t_ms": 9000, "type": "rep", "n": 2, "correct": False, "faults": ["sag"], "data": {}},
            {"t_ms": 20000, "type": "set_complete"},
        ]
        gb_events = [
            {"t_ms": 5000, "type": "rep", "n": 1, "correct": True, "faults": [], "data": {}},
            {"t_ms": 15000, "type": "rep", "n": 2, "correct": True, "faults": [], "data": {}},
            {"t_ms": 20000, "type": "set_complete"},
        ]
        csv_rows = [
            # Squat sorted by faults in Excel: rep 3 (12.0s) first, plus leftover rep_n=0 row
            ["C1", "P01", "ai", "squat", "1", "3", "12.0", "1", "depth", ""],
            ["C1", "P01", "ai", "squat", "1", "0", "", "0", "", "leftover template row"],
            ["C1", "P01", "ai", "squat", "1", "1", "4.0", "1", "", ""],
            ["C1", "P01", "ai", "squat", "1", "2", "8.0", "1", "", ""],
            # Push-up untimed, scrambled rep_n=2 before rep_n=1
            ["C1", "P01", "ai", "push_up", "1", "2", "", "1", "sag", ""],
            ["C1", "P01", "ai", "push_up", "1", "1", "", "1", "", ""],
            # Glute bridge with monotonic rep_n=1,2 but genuine non-monotonic video_t_s typo
            ["C1", "P01", "ai", "glute_bridge", "1", "1", "14.0", "1", "", "typo"],
            ["C1", "P01", "ai", "glute_bridge", "1", "2", "4.0", "1", "", ""],
        ]
        res = _run_synthetic(
            {
                "sq.json": _make_set_json("P01", "ai", "squat", events=sq_events),
                "pu.json": _make_set_json("P01", "ai", "push_up", events=pu_events),
                "gb.json": _make_set_json("P01", "ai", "glute_bridge", events=gb_events),
            },
            csv_rows,
        )
        codes = [iv.code for iv in res.issues]
        self.assertIn("rep_n_out_of_order", codes)
        self.assertIn("zero_rep_with_nonempty_set", codes)
        # Only glute_bridge (not squat) should trigger non_monotonic_video_t_s
        non_mono = [iv for iv in res.issues if iv.code == "non_monotonic_video_t_s"]
        self.assertEqual(len(non_mono), 1)
        self.assertIn("glute_bridge", non_mono[0].message_en)

        # Squat must match all 3 reps cleanly with 0 missed/phantom and TP=1 on depth
        sq_cnt = _find_row(res.counting_accuracy_rows, exercise_id="squat")
        self.assertEqual((sq_cnt["matched"], sq_cnt["missed"], sq_cnt["phantom"]), (3, 0, 0))
        sq_fd = _find_row(res.fault_detection_rows, exercise_id="squat", fault_id="depth")
        self.assertEqual((sq_fd["tp"], sq_fd["fp"], sq_fd["fn"]), (1, 0, 0))

        # Untimed push_up must match rep 1->1 (clean) and rep 2->2 (sag) -> TP=1, FP=0, FN=0
        pu_fd = _find_row(res.fault_detection_rows, exercise_id="push_up", fault_id="sag")
        self.assertEqual((pu_fd["tp"], pu_fd["fp"], pu_fd["fn"]), (1, 0, 0))

    def test_multi_column_unquoted_commas_in_faults_and_notes_and_clean_note_safety(self) -> None:
        """Recover 2+ unquoted comma-separated faults (with or without trailing note/comma),
        preserve unquoted commas inside note, and never turn a note on an empty-faults row into a fault.
        """
        events = [
            {"t_ms": 5000, "type": "rep", "n": 1, "correct": False, "faults": ["depth", "heel", "trunk"], "data": {}},
            {"t_ms": 9000, "type": "rep", "n": 2, "correct": False, "faults": ["depth", "heel", "trunk"], "data": {}},
            {"t_ms": 13000, "type": "rep", "n": 3, "correct": False, "faults": ["depth", "heel", "trunk"], "data": {}},
            {"t_ms": 17000, "type": "rep", "n": 4, "correct": True, "faults": [], "data": {}},
            {"t_ms": 21000, "type": "rep", "n": 5, "correct": False, "faults": ["depth"], "data": {}},
            {"t_ms": 25000, "type": "set_complete"},
        ]
        csv_rows = [
            # Rep 1: 2 unquoted commas + empty note cell (12 cols)
            ["C1", "P01", "ai", "squat", "1", "1", "4.0", "1", "depth", "heel", "trunk", ""],
            # Rep 2: 2 unquoted commas + Vietnamese note (12 cols)
            ["C1", "P01", "ai", "squat", "1", "2", "8.0", "1", "depth", "heel", "trunk", "nông và đổ người"],
            # Rep 3: 2 unquoted commas with no trailing comma (11 cols)
            ["C1", "P01", "ai", "squat", "1", "3", "12.0", "1", "depth", "heel", "trunk"],
            # Rep 4: Clean rep (faults='') where coach wrote 'heel' in note on an Excel-padded row (11 cols)
            ["C1", "P01", "ai", "squat", "1", "4", "16.0", "1", "", "heel", ""],
            # Rep 5: Unquoted comma inside free-text note (11 cols)
            ["C1", "P01", "ai", "squat", "1", "5", "20.0", "1", "depth", "xuống nông", "kiễng nhẹ"],
        ]
        res = _run_synthetic(
            {"sq.json": _make_set_json("P01", "ai", "squat", events=events, active_ms=25000)},
            csv_rows,
        )
        # Perfect fault agreement across all 5 reps!
        self.assertEqual(res.wrong_detection_rows, [])
        for fid, expected_tp in (("depth", 4), ("heel", 3), ("trunk", 3)):
            fd = _find_row(res.fault_detection_rows, exercise_id="squat", fault_id=fid)
            self.assertEqual((fd["tp"], fd["fp"], fd["fn"]), (expected_tp, 0, 0))

        r2 = _find_row(res.rep_matching_rows, coach_rep_n=2)
        self.assertEqual(r2["coach_note"], "nông và đổ người")
        r4 = _find_row(res.rep_matching_rows, coach_rep_n=4)
        self.assertEqual(r4["coach_faults"], "")
        self.assertEqual(r4["coach_note"], "heel")
        r5 = _find_row(res.rep_matching_rows, coach_rep_n=5)
        self.assertEqual(r5["coach_note"], "xuống nông, kiễng nhẹ")

    def test_subsequent_coach_reps_after_cue_partial_timestamp_chronological_bound(self) -> None:
        """An untimed missed coach row preceding a timed missed coach row <= cue cutoff
        must not be treated as a subsequent rep after the cue.
        """
        # sync_beep_t_ms = 1000 -> cue at 9000ms has eff_rel_t_s = 8.0s; app rep 1 at 26000ms = 25.0s
        events = [
            {"t_ms": 9000, "type": "cue", "key": "Gồng cơ bụng, nâng hông lên", "played": True, "fault": "Back"},
            {"t_ms": 26000, "type": "rep", "n": 1, "correct": True, "faults": [], "data": {}},
            {"t_ms": 30000, "type": "set_complete"},
        ]
        csv_rows = [
            # Rep 1 is untimed & missed by app, but precedes Rep 2 at 6.0s <= 8.0s cue!
            ["C1", "P01", "ai", "plank", "1", "1", "", "1", "Back", "untimed prior hold"],
            ["C1", "P01", "ai", "plank", "1", "2", "6.0", "1", "Back", "timed prior hold <= 8.0s"],
            ["C1", "P01", "ai", "plank", "1", "3", "25.0", "1", "", "clean hold after cue"],
        ]
        res = _run_synthetic(
            {"pl.json": _make_set_json("P01", "ai", "plank", events=events, active_ms=30000)},
            csv_rows,
        )
        c_back = _find_row(
            res.cue_correction_rows, played="true", exercise_id="plank", fault_id="Back"
        )
        # Only Rep 3 occurred after the 8.0s cue -> n_with_next1_coach == 1, corrected == 1, next2 == 0
        self.assertEqual(c_back["n_with_next1_coach"], 1)
        self.assertEqual(c_back["corrected_next1_coach"], 1)
        self.assertEqual(c_back["n_with_next2_coach"], 0)

    def test_summary_false_alarm_reporting_and_unbalanced_paired_participant_counts(self) -> None:
        """Verify summary.md Section 7.4 false-alarm summary, Section 3.1 FPR column, and
        paired-exercise counts in ai_vs_control_participants.csv & summary.md Section 7.2.
        """
        sq_ai_events = [
            # Rep 1: coach sees depth, app raises depth + heel (specific FP on heel!)
            {"t_ms": 5000, "type": "rep", "n": 1, "correct": False, "faults": ["depth", "heel"], "data": {}},
            # Rep 2: coach clean, app raises trunk (clean-rep FP!)
            {"t_ms": 9000, "type": "rep", "n": 2, "correct": False, "faults": ["trunk"], "data": {}},
            {"t_ms": 13000, "type": "rep", "n": 3, "correct": True, "faults": [], "data": {}},
            {"t_ms": 17000, "type": "rep", "n": 4, "correct": True, "faults": [], "data": {}},
            {"t_ms": 20000, "type": "set_complete"},
        ]
        sq_ctrl_events = [
            {"t_ms": 5000, "type": "rep", "n": 1, "correct": False, "faults": ["depth"], "data": {}},
            {"t_ms": 9000, "type": "rep", "n": 2, "correct": False, "faults": ["depth"], "data": {}},
            {"t_ms": 13000, "type": "rep", "n": 3, "correct": False, "faults": ["depth"], "data": {}},
            {"t_ms": 17000, "type": "rep", "n": 4, "correct": True, "faults": [], "data": {}},
            {"t_ms": 20000, "type": "set_complete"},
        ]
        pl_ai_events = [
            {"t_ms": 16000, "type": "rep", "n": 1, "correct": False, "faults": ["Back"], "data": {}},
            {"t_ms": 36000, "type": "rep", "n": 2, "correct": False, "faults": ["Back"], "data": {}},
            {"t_ms": 56000, "type": "rep", "n": 3, "correct": False, "faults": ["Back"], "data": {}},
            {"t_ms": 60000, "type": "set_complete"},
        ]
        csv_rows = [
            ["C1", "P01", "control", "squat", "1", "1", "4.0", "1", "depth", ""],
            ["C1", "P01", "control", "squat", "1", "2", "8.0", "1", "depth", ""],
            ["C1", "P01", "control", "squat", "1", "3", "12.0", "1", "depth", ""],
            ["C1", "P01", "control", "squat", "1", "4", "16.0", "1", "", ""],
            ["C1", "P01", "ai", "squat", "1", "1", "4.0", "1", "depth", ""],
            ["C1", "P01", "ai", "squat", "1", "2", "8.0", "1", "", ""],
            ["C1", "P01", "ai", "squat", "1", "3", "12.0", "1", "", ""],
            ["C1", "P01", "ai", "squat", "1", "4", "16.0", "1", "", ""],
            ["C1", "P01", "ai", "plank", "1", "1", "15.0", "1", "Back", ""],
            ["C1", "P01", "ai", "plank", "1", "2", "35.0", "1", "Back", ""],
            ["C1", "P01", "ai", "plank", "1", "3", "55.0", "1", "Back", ""],
        ]
        res = _run_synthetic(
            {
                "sq_ai.json": _make_set_json("P01", "ai", "squat", events=sq_ai_events),
                "sq_ctrl.json": _make_set_json("P01", "control", "squat", events=sq_ctrl_events),
                "pl_ai.json": _make_set_json("P01", "ai", "plank", events=pl_ai_events),
            },
            csv_rows,
        )
        p01 = _find_row(res.ai_vs_control_participant_rows, participant_id="P01")
        self.assertEqual(p01["control_valid_reps"], 4)
        self.assertEqual(p01["control_faulty_reps"], 3)
        self.assertEqual(p01["ai_valid_reps"], 7)
        self.assertEqual(p01["ai_faulty_reps"], 4)
        self.assertEqual(p01["paired_control_valid_reps"], 4)
        self.assertEqual(p01["paired_control_faulty_reps"], 3)
        self.assertAlmostEqual(float(p01["paired_control_fault_rate"]), 0.75)
        self.assertEqual(p01["paired_ai_valid_reps"], 4)
        self.assertEqual(p01["paired_ai_faulty_reps"], 1)
        self.assertAlmostEqual(float(p01["paired_ai_fault_rate"]), 0.25)
        self.assertAlmostEqual(float(p01["paired_diff_ai_minus_control"]), -0.50)

        md = evaluate.render_summary_markdown_vi(res)
        self.assertIn("### 7.4. Tần suất ứng dụng báo lỗi mà HLV không thấy", md)
        self.assertIn("1 - Precision = FP/n_app", md)
        self.assertIn("### 7.5. Mức độ hài lòng của người tập", md)
        # Both overall AI (4/7 = 57.1%) and paired AI (1/4 = 25.0%) are directly visible in Section 7.2
        self.assertIn("57.1% (4/7)", md)
        self.assertIn("25.0% (1/4)", md)

    def test_anon_participant_soft_fault_warning_sub1s_fps_filter_and_out_dir_log_exclusion(
        self,
    ) -> None:
        """Verify anonymous_participant_id warning, rep_soft_faults_included warning when
        correct=false has soft warnings, sub-1s/0ms FPS distortion protection, and --out
        exclusion in load_logs_directory (including same-directory --logs/--labels/--out).
        """
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            eval_dir = root / "eval_data"
            out_sub = eval_dir / "results"
            out_sub.mkdir(parents=True)

            # 1) Set log with participant_id='anon' + sub-1s aborted frames (duration_ms=400, min_fps_1s=0)
            anon_aborted = _make_set_json("anon", "ai", "squat", set_index=9, events=[])
            anon_aborted["frames"] = {
                "total": 2,
                "with_pose": 0,
                "duration_ms": 400,
                "mean_fps": 5.0,
                "min_fps_1s": 0,
                "max_gap_ms": 300,
            }
            (eval_dir / "anon_set.json").write_text(
                json.dumps(anon_aborted, indent=2), encoding="utf-8"
            )
            (eval_dir / "anon_sess.json").write_text(
                json.dumps(
                    {
                        "schema": 1,
                        "kind": "session",
                        "session_id": "S-ANON",
                        "participant_id": "anon",
                        "condition": "ai",
                        "satisfaction": 4,
                        "files": [],
                    },
                    indent=2,
                ),
                encoding="utf-8",
            )

            # 2) Zero-duration aborted squat set (duration_ms=0, mean_fps=0, min_fps_1s=0)
            zero_dur = _make_set_json("P02", "ai", "squat", set_index=8, events=[])
            zero_dur["frames"] = {
                "total": 0,
                "with_pose": 0,
                "duration_ms": 0,
                "mean_fps": 0.0,
                "min_fps_1s": 0,
                "max_gap_ms": 0,
            }
            (eval_dir / "zero_dur.json").write_text(json.dumps(zero_dur), encoding="utf-8")

            # 3) Sub-1s completed squat set (duration_ms=600, mean_fps=20.0, min_fps_1s=0)
            sub1s_done = _make_set_json(
                "P01",
                "control",
                "squat",
                set_index=1,
                events=[{"t_ms": 600, "type": "set_complete"}],
            )
            sub1s_done["frames"] = {
                "total": 12,
                "with_pose": 12,
                "duration_ms": 600,
                "mean_fps": 20.0,
                "min_fps_1s": 0,
                "max_gap_ms": 60,
            }
            (eval_dir / "sub1s_done.json").write_text(json.dumps(sub1s_done), encoding="utf-8")

            # 4) Normal 20s squat set (mean_fps=24.0, min_fps_1s=15.0)
            normal_sq = _make_set_json(
                "P01",
                "ai",
                "squat",
                set_index=1,
                mean_fps=24.0,
                min_fps_1s=15.0,
                events=[
                    {"t_ms": 5000, "type": "rep", "n": 1, "correct": True, "faults": [], "data": {}},
                    {"t_ms": 20000, "type": "set_complete"},
                ],
            )
            (eval_dir / "normal_sq.json").write_text(json.dumps(normal_sq), encoding="utf-8")

            # 5) Genuine 1s freeze on a 20s active plank set (duration_ms=20000, min_fps_1s=0)
            freeze_pl = _make_set_json(
                "P01",
                "ai",
                "plank",
                set_index=1,
                mean_fps=18.0,
                min_fps_1s=0.0,
                events=[
                    {"t_ms": 16000, "type": "rep", "n": 1, "correct": True, "faults": [], "data": {}},
                    {"t_ms": 20000, "type": "set_complete"},
                ],
            )
            (eval_dir / "freeze_pl.json").write_text(json.dumps(freeze_pl), encoding="utf-8")

            # 6) Push-up rep with correct=False AND mixed critical + soft fault in fault_affects_form
            mixed_pu = _make_set_json(
                "P01",
                "ai",
                "push_up",
                set_index=1,
                events=[
                    {
                        "t_ms": 6000,
                        "type": "rep",
                        "n": 1,
                        "correct": False,
                        "faults": ["depth", "tempo"],
                        "data": {"fault_affects_form": {"depth": True, "tempo": False}},
                    },
                    {"t_ms": 20000, "type": "set_complete"},
                ],
            )
            (eval_dir / "mixed_pu.json").write_text(json.dumps(mixed_pu), encoding="utf-8")

            # 7) Stray JSON inside --out subdir (must be ignored by load_logs_directory!)
            (out_sub / "stray_artifact.json").write_text("{not valid json", encoding="utf-8")

            labels_csv = eval_dir / "coach_labels.csv"
            labels_csv.write_text(
                "coach_id,participant_id,condition,exercise_id,set_index,rep_n,video_t_s,counted,faults,note\n"
                "C1,P01,ai,squat,1,1,4.0,1,,\n"
                "C1,P01,control,squat,1,0,,0,,empty\n"
                "C1,P01,ai,plank,1,1,15.0,1,,\n"
                "C1,P01,ai,push_up,1,1,5.0,1,depth,\n",
                encoding="utf-8",
            )

            # Run A: default mode with --out as subdirectory of --logs
            self.assertEqual(
                evaluate.main(
                    ["--logs", str(eval_dir), "--labels", str(eval_dir), "--out", str(out_sub)]
                ),
                0,
            )
            with (out_sub / "validation_issues.csv").open("r", encoding="utf-8") as fh:
                v_rows = list(csv.DictReader(fh))
            v_codes = [r["code"] for r in v_rows]
            # Stray JSON inside out_sub must NOT have been read
            self.assertNotIn("invalid_json", v_codes)
            self.assertEqual(v_codes.count("anonymous_participant_id"), 2)
            self.assertIn("rep_soft_faults_included", v_codes)

            with (out_sub / "frame_rate.csv").open("r", encoding="utf-8") as fh:
                fps_rows = list(csv.DictReader(fh))
            sq_fps = _find_row(fps_rows, exercise_id="squat")
            # Aborted 0ms & 400ms sets excluded from mean_fps -> worst_mean_fps is 20.00 (not 0.00 or 5.00)
            # Sub-1s 600ms set excluded from min_fps_1s -> worst_min_fps_1s is 15.00 (not 0.00)
            self.assertEqual(sq_fps["worst_mean_fps"], "20.00")
            self.assertEqual(sq_fps["worst_min_fps_1s"], "15.00")
            # Genuine 1s freeze on 20s plank set IS still captured as 0.00
            pl_fps = _find_row(fps_rows, exercise_id="plank")
            self.assertEqual(pl_fps["worst_min_fps_1s"], "0.00")

            # Run B: --form-faults-only strips 'tempo' (0 FP on push_up) and suppresses rep_soft_faults_included
            # Also test --logs == --labels == --out (same directory!) across two consecutive runs!
            same_dir = root / "all_in_one"
            same_dir.mkdir()
            (same_dir / "mixed_pu.json").write_text(json.dumps(mixed_pu), encoding="utf-8")
            (same_dir / "labels.csv").write_text(
                "coach_id,participant_id,condition,exercise_id,set_index,rep_n,video_t_s,counted,faults,note\n"
                "C1,P01,ai,push_up,1,1,5.0,1,depth,\n",
                encoding="utf-8",
            )
            same_argv = [
                "--logs",
                str(same_dir),
                "--labels",
                str(same_dir),
                "--form-faults-only",
                "--out",
                str(same_dir),
            ]
            self.assertEqual(evaluate.main(same_argv), 0)
            self.assertEqual(evaluate.main(same_argv), 0)
            with (same_dir / "validation_issues.csv").open("r", encoding="utf-8") as fh:
                self.assertEqual(list(csv.DictReader(fh)), [])
            with (same_dir / "fault_detection.csv").open("r", encoding="utf-8") as fh:
                pu_tempo = _find_row(
                    list(csv.DictReader(fh)), exercise_id="push_up", fault_id="tempo"
                )
            self.assertEqual(int(pu_tempo["fp"]), 0)

    def test_parent_out_dir_does_not_skip_subdir_inputs_and_uppercase_csv_and_basename_disambiguation(
        self,
    ) -> None:
        """Passing --out as a parent/ancestor of --logs and --labels must still load all
        logs and CSVs (including .CSV uppercase extension), and disambiguate identical CSV basenames.
        """
        with tempfile.TemporaryDirectory() as tmp:
            trial_root = Path(tmp) / "trial_run"
            logs_sub = trial_root / "logs"
            labels_c1 = trial_root / "labels" / "coach1"
            labels_c2 = trial_root / "labels" / "coach2"
            logs_sub.mkdir(parents=True)
            labels_c1.mkdir(parents=True)
            labels_c2.mkdir(parents=True)

            s1 = _make_set_json(
                "P-07",
                "ai",
                "squat",
                events=[
                    {"t_ms": 5000, "type": "rep", "n": 1, "correct": False, "faults": ["depth"], "data": {}},
                    {"t_ms": 20000, "type": "set_complete"},
                ],
            )
            (logs_sub / "s1.json").write_text(json.dumps(s1), encoding="utf-8")

            # Coach 1 uses uppercase .CSV and writes 'P 07' (phone ResearchConfig sanitized 'P 07' -> 'P-07')
            (labels_c1 / "LABELS.CSV").write_text(
                "coach_id,participant_id,condition,exercise_id,set_index,rep_n,video_t_s,counted,faults,note\n"
                "C1,P 07,ai,squat,1,1,4.0,1,depth,\n",
                encoding="utf-8",
            )
            # Coach 2 uses same basename 'LABELS.CSV' in different subfolder and writes 'P_07' + bad fault
            (labels_c2 / "LABELS.CSV").write_text(
                "coach_id,participant_id,condition,exercise_id,set_index,rep_n,video_t_s,counted,faults,note\n"
                "C2,P_07,ai,squat,1,1,4.0,1,depth;bad_tok,\n",
                encoding="utf-8",
            )

            argv = [
                "--logs",
                str(logs_sub),
                "--labels",
                str(trial_root / "labels"),
                "--out",
                str(trial_root),
            ]
            # Run twice to ensure generated CSVs in trial_root do not interfere on re-run
            self.assertEqual(evaluate.main(argv), 0)
            self.assertEqual(evaluate.main(argv), 0)

            with (trial_root / "counting_accuracy.csv").open("r", encoding="utf-8") as fh:
                sq = _find_row(list(csv.DictReader(fh)), exercise_id="squat")
            self.assertEqual(int(sq["matched"]), 1)

            with (trial_root / "coach_agreement.csv").open("r", encoding="utf-8") as fh:
                agr = _find_row(list(csv.DictReader(fh)), exercise_id="squat", fault_id="depth")
            self.assertEqual(int(agr["n_matched_valid_reps"]), 1)

            with (trial_root / "validation_issues.csv").open("r", encoding="utf-8") as fh:
                v_rows = list(csv.DictReader(fh))
            # Both 'P 07' and 'P_07' normalized to 'P-07', and disambiguated subfolder name appears
            unk = _find_row(v_rows, code="unknown_fault_id")
            self.assertIn("coach2/LABELS.CSV", unk["file"])

    def test_unquoted_decimal_comma_video_t_s_trailing_empty_header_and_semicolon_csv(self) -> None:
        """Recover unquoted Vietnamese decimal comma in video_t_s ('12,0' and '12,4'),
        recover unquoted fault commas even when Excel exported trailing empty header columns,
        warn on shifted misspelled fault tokens ('depth,heell,'), and parse ';'-delimited Excel CSVs.
        """
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            logs_dir = root / "logs"
            logs_dir.mkdir()
            sq_events = [
                {"t_ms": 13000, "type": "rep", "n": 1, "correct": False, "faults": ["depth"], "data": {}},
                {"t_ms": 17400, "type": "rep", "n": 2, "correct": False, "faults": ["depth", "heel"], "data": {}},
                {"t_ms": 21000, "type": "rep", "n": 3, "correct": False, "faults": ["depth"], "data": {}},
                {"t_ms": 25000, "type": "set_complete"},
            ]
            pl_events = [
                {"t_ms": 16200, "type": "rep", "n": 1, "correct": False, "faults": ["Back", "Neck"], "data": {}},
                {"t_ms": 20000, "type": "set_complete"},
            ]
            (logs_dir / "sq.json").write_text(
                json.dumps(_make_set_json("P07", "ai", "squat", events=sq_events, active_ms=25000)),
                encoding="utf-8",
            )
            (logs_dir / "pl.json").write_text(
                json.dumps(_make_set_json("P07", "ai", "plank", events=pl_events)),
                encoding="utf-8",
            )

            # CSV 1: Excel trailing empty header column ('...note,') + unquoted '12,0' in video_t_s
            # + unquoted '16,4' AND 'depth,heel' on rep 2 + typo 'depth,heell,' on rep 3!
            csv1 = root / "c1_vn.csv"
            csv1.write_text(
                "coach_id,participant_id,condition,exercise_id,set_index,rep_n,video_t_s,counted,faults,note,\n"
                "C1,P07,ai,squat,1,1,12,0,1,depth,,\n"
                "C1,P07,ai,squat,1,2,16,4,1,depth,heel,\n"
                "C1,P07,ai,squat,1,3,20.0,1,depth,heell,,\n",
                encoding="utf-8",
            )
            # CSV 2: Vietnamese-locale Windows Excel ';'-delimited CSV with quoted '"Back;Neck"' and '15,2'
            csv2 = root / "c1_semi.csv"
            csv2.write_text(
                "coach_id;participant_id;condition;exercise_id;set_index;rep_n;video_t_s;counted;faults;note\n"
                'C1;P07;ai;plank;1;1;15,2;1;"Back;Neck";giữ plank\n',
                encoding="utf-8-sig",
            )
            # Also verify a 10-col header CSV with 'depth,heell,' (11 cols) emits extra_csv_columns
            csv3_issues: list[evaluate.ValidationIssue] = []
            csv3 = root / "c3_typo.csv"
            csv3.write_text(
                "coach_id,participant_id,condition,exercise_id,set_index,rep_n,video_t_s,counted,faults,note\n"
                "C1,P07,ai,squat,2,1,12.0,1,depth,heell,\n",
                encoding="utf-8",
            )
            evaluate.load_coach_labels(
                [csv3],
                evaluate.IdCanonicalizer("Participant ID", "Mã người tập"),
                evaluate.IdCanonicalizer("Coach ID", "Mã HLV"),
                csv3_issues,
            )
            self.assertIn("extra_csv_columns", {iv.code for iv in csv3_issues})

            out_dir = root / "out"
            self.assertEqual(
                evaluate.main(
                    ["--logs", str(logs_dir), "--labels", str(csv1), str(csv2), "--out", str(out_dir)]
                ),
                0,
            )
            with (out_dir / "counting_accuracy.csv").open("r", encoding="utf-8") as fh:
                ca = list(csv.DictReader(fh))
            # Rep 1 ('12,0' with counted=1) MUST stay counted=1 -> all 3 squat reps matched!
            sq_ca = _find_row(ca, exercise_id="squat")
            self.assertEqual((int(sq_ca["coach_valid_reps"]), int(sq_ca["matched"])), (3, 3))
            pl_ca = _find_row(ca, exercise_id="plank")
            self.assertEqual((int(pl_ca["coach_valid_reps"]), int(pl_ca["matched"])), (1, 1))

            with (out_dir / "fault_detection.csv").open("r", encoding="utf-8") as fh:
                fd_rows = list(csv.DictReader(fh))
            # 'heel' on rep 2 recovered despite trailing empty header col -> TP=1, FN=0!
            sq_heel = _find_row(fd_rows, exercise_id="squat", fault_id="heel")
            self.assertEqual((int(sq_heel["tp"]), int(sq_heel["fp"]), int(sq_heel["fn"])), (1, 0, 0))
            pl_neck = _find_row(fd_rows, exercise_id="plank", fault_id="Neck")
            self.assertEqual((int(pl_neck["tp"]), int(pl_neck["fp"]), int(pl_neck["fn"])), (1, 0, 0))

    def test_cue_subsequent_bounds_matched_lag_typo_and_no_phantom_app_only_candidate(self) -> None:
        """Verify: (1) untimed missed row before a matched row whose video_t_s <= cue cutoff is excluded,
        (2) non-monotonic timestamp typo on a later unmatched row does not drop valid post-cue reps, and
        (3) coach-labelled set with 0 valid post-cue reps + 1 app phantom rep creates no app_only candidate.
        """
        # Set 1 (squat): cue at 9000ms (eff_rel_t_s = 8.0s).
        # Coach rep 1: untimed missed prior rep.
        # Coach rep 2: video_t_s = 7.8s <= 8.0s, matched within ±2.5s to App rep 1 at 9200ms (8.2s, clean).
        # Coach rep 3: unmatched missed rep after App rep 1 with timestamp typo 3.0s (clean).
        sq_events = [
            {"t_ms": 9000, "type": "cue", "key": "squat.trunk_reminder", "played": True, "fault": "trunk"},
            {"t_ms": 9200, "type": "rep", "n": 1, "correct": True, "faults": [], "data": {}},
            {"t_ms": 20000, "type": "set_complete"},
        ]
        # Set 2 (push_up): Coach-labelled set where cue at 10200ms is at end of real set (0 coach reps after),
        # but app has a phantom rep at 15000ms -> must NOT become an 'app_only' candidate!
        pu_events = [
            {"t_ms": 10000, "type": "rep", "n": 1, "correct": False, "faults": ["sag"], "data": {}},
            {"t_ms": 10200, "type": "cue", "key": "push_up.sag", "played": True, "fault": "sag"},
            {"t_ms": 15000, "type": "rep", "n": 2, "correct": True, "faults": [], "data": {}},
            {"t_ms": 20000, "type": "set_complete"},
        ]
        csv_rows = [
            ["C1", "P01", "ai", "squat", "1", "1", "", "1", "trunk", "untimed prior missed"],
            ["C1", "P01", "ai", "squat", "1", "2", "7.8", "1", "", "matched to 8.2s"],
            ["C1", "P01", "ai", "squat", "1", "3", "3.0", "1", "", "post-cue missed with typo"],
            ["C1", "P01", "ai", "push_up", "1", "1", "9.0", "1", "sag", "only real rep"],
            ["C1", "P01", "ai", "push_up", "1", "2", "14.0", "0", "", "half rep (app phantom)"],
        ]
        res = _run_synthetic(
            {
                "sq.json": _make_set_json("P01", "ai", "squat", events=sq_events),
                "pu.json": _make_set_json("P01", "ai", "push_up", events=pu_events),
            },
            csv_rows,
        )
        # Squat: Coach rep 1 (trunk) excluded; Coach reps 2 & 3 (both clean) kept -> next1=1/1, next2=1/1!
        c_trunk = _find_row(
            res.cue_correction_rows, played="true", exercise_id="squat", fault_id="trunk"
        )
        self.assertEqual(c_trunk["n_with_next1_coach"], 1)
        self.assertEqual(c_trunk["corrected_next1_coach"], 1)
        self.assertEqual(c_trunk["n_with_next2_coach"], 1)
        self.assertEqual(c_trunk["corrected_next2_coach"], 1)

        # Push-up: Coach saw 0 valid reps after cue -> must NOT appear in cue_candidate_rows as app_only!
        pu_cands = [r for r in res.cue_candidate_rows if r["exercise_id"] == "push_up"]
        self.assertEqual(pu_cands, [])

    def test_paused_split_sub1s_windows_do_not_distort_min_fps_1s_and_set_recorder_payload(
        self,
    ) -> None:
        """A set with duration_ms=1800 and paused_ms=500 (non-paused sum 1300ms >= 1000ms) split into
        600ms + 700ms non-paused stretches has zero whole 1s windows (SetRecorder min_fps_1s=0) and
        must not distort worst_min_fps_1s; also cross-test exact SetRecorder output structure.
        """
        # Split paused aborted set: [0..600] active, [600..1100] paused, [1100..1800] active -> max window 700ms
        split_short = {
            "schema": 1,
            "kind": "exercise_set",
            "session_id": "20261120T091500Z-P07",
            "participant_id": "P07",
            "condition": "ai",
            "app_version": "1.0.3+155",
            "platform": "android",
            "os_version": "13",
            "exercise_id": "squat",
            "set_index": 2,
            "started_at_utc": "2026-11-20T09:20:00.000Z",
            "sync_beep_t_ms": 0,
            "frames": {
                "total": 26,
                "with_pose": 24,
                "duration_ms": 1800,
                "mean_fps": 14.4,
                "min_fps_1s": 0,
                "max_gap_ms": 60,
            },
            "events": [
                {"t_ms": 0, "type": "activated"},
                {"t_ms": 600, "type": "pause_start"},
                {"t_ms": 1100, "type": "pause_end"},
            ],
            "set_log": {},
            "summary": {
                "reps": 0,
                "good_reps": 0,
                "active_ms": 1300,
                "unseen_ms": 0,
                "paused_ms": 500,
            },
        }
        # Exact SetRecorder integration payload from set_recorder_test.dart
        recorder_set = {
            "schema": 1,
            "kind": "exercise_set",
            "session_id": "20261120T091500Z-P07",
            "participant_id": "P07",
            "condition": "ai",
            "app_version": "1.0.3+155",
            "platform": "android",
            "os_version": "13",
            "exercise_id": "squat",
            "set_index": 1,
            "started_at_utc": "2026-11-20T09:15:02.123Z",
            "sync_beep_t_ms": 3000,
            "frames": {
                "total": 284,
                "with_pose": 252,
                "duration_ms": 17000,
                "mean_fps": 16.7,
                "min_fps_1s": 20,
                "max_gap_ms": 50,
            },
            "events": [
                {"t_ms": 0, "type": "unseen_start", "phase": "setup", "reason": "holdStill"},
                {"t_ms": 3000, "type": "unseen_end"},
                {"t_ms": 3000, "type": "activated"},
                {"t_ms": 3000, "type": "cue", "key": "common.ready", "played": True},
                {"t_ms": 6000, "type": "rep", "n": 1, "correct": True, "faults": [], "data": {"fault_types": [], "peak_knee_angle": 92.0}},
                {"t_ms": 6000, "type": "cue", "key": "1", "played": True},
                {"t_ms": 7000, "type": "unseen_start", "phase": "active", "reason": "bodyInFrame"},
                {"t_ms": 8500, "type": "unseen_end"},
                {"t_ms": 9000, "type": "pause_start"},
                {"t_ms": 11000, "type": "pause_end"},
                {"t_ms": 11000, "type": "unseen_start", "phase": "setup", "reason": "holdStill"},
                {"t_ms": 14000, "type": "unseen_end"},
                {"t_ms": 14000, "type": "activated"},
                {"t_ms": 17000, "type": "rep", "n": 2, "correct": False, "faults": ["depth"], "data": {"fault_types": ["depth"], "peak_knee_angle": 112.0}},
                {"t_ms": 17000, "type": "cue", "key": "2", "played": True},
                {"t_ms": 17000, "type": "cue", "key": "squat.depth", "played": True, "fault": "depth"},
                {"t_ms": 17000, "type": "set_complete"},
            ],
            "set_log": {"good_rep_count": 1},
            "summary": {
                "reps": 2,
                "good_reps": 1,
                "active_ms": 9000,
                "unseen_ms": 1500,
                "paused_ms": 2000,
            },
        }
        csv_rows = [
            ["C1", "P07", "ai", "squat", "1", "1", "3.0", "1", "", ""],
            ["C1", "P07", "ai", "squat", "1", "2", "14.0", "1", "depth", ""],
            ["C1", "P07", "ai", "squat", "2", "0", "", "0", "", "aborted"],
        ]
        res = _run_synthetic(
            {"s1.json": recorder_set, "s2.json": split_short},
            csv_rows,
            cue_map_rows=[["", "common.ready", "none"]],
        )
        self.assertEqual(res.issues, [])
        sq_fps = _find_row(res.frame_rate_rows, exercise_id="squat")
        # split_short had 600ms and 700ms non-paused windows (<1000ms) -> its min_fps_1s=0 is excluded!
        self.assertEqual(sq_fps["worst_min_fps_1s"], "20.00")
        self.assertEqual(res.cue_mapping_summary["played_unmapped"], 0)


class TestEndToEndCLI(unittest.TestCase):
    def test_cli_end_to_end_on_handwritten_fixture_directory(self) -> None:
        """Run evaluate.py as a subprocess on tools/eval/fixtures/ and verify all output tables."""
        fixtures_dir = EVAL_DIR / "fixtures"
        script_path = EVAL_DIR / "evaluate.py"
        cue_map_path = EVAL_DIR / "cue_fault_map.csv"

        with tempfile.TemporaryDirectory() as tmp:
            out_dir = Path(tmp) / "out"
            proc = subprocess.run(
                [
                    sys.executable,
                    str(script_path),
                    "--logs",
                    str(fixtures_dir / "logs"),
                    "--labels",
                    str(fixtures_dir / "labels.csv"),
                    "--cue-map",
                    str(cue_map_path),
                    "--out",
                    str(out_dir),
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(
                proc.returncode,
                0,
                msg=f"CLI failed:\nSTDOUT:\n{proc.stdout}\nSTDERR:\n{proc.stderr}",
            )

            expected_files = [
                "summary.md",
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
            ]
            for fname in expected_files:
                self.assertTrue((out_dir / fname).is_file(), f"Missing output file: {fname}")

            with (out_dir / "counting_accuracy.csv").open("r", encoding="utf-8") as fh:
                ca_rows = list(csv.DictReader(fh))
            sq_row = _find_row(ca_rows, exercise_id="squat")
            # P01 squat: 4 valid in ai (all 4 matched) + 4 valid in control (3 matched, 1 missed)
            self.assertEqual(int(sq_row["coach_valid_reps"]), 8)
            self.assertEqual(int(sq_row["matched"]), 7)
            self.assertEqual(int(sq_row["missed"]), 1)
            self.assertEqual(int(sq_row["phantom"]), 0)

            pl_row = _find_row(ca_rows, exercise_id="plank")
            self.assertEqual(int(pl_row["matched"]), 3)

            with (out_dir / "wrong_detections.csv").open("r", encoding="utf-8") as fh:
                wd_rows = list(csv.DictReader(fh))
            # Only Plank Hold 3 had a matched fault disagreement (App added 'Neck' FP)
            self.assertEqual(len(wd_rows), 1)
            self.assertEqual(wd_rows[0]["exercise_id"], "plank")
            self.assertEqual(wd_rows[0]["false_positives"], "Neck")

            with (out_dir / "coach_agreement.csv").open("r", encoding="utf-8") as fh:
                agr_rows = list(csv.DictReader(fh))
            knees_agr = _find_row(agr_rows, exercise_id="plank", fault_id="Knees")
            self.assertAlmostEqual(float(knees_agr["percent_agreement"]), 2.0 / 3.0, places=4)

            with (out_dir / "ai_vs_control_participants.csv").open("r", encoding="utf-8") as fh:
                p01_avc = _find_row(list(csv.DictReader(fh)), participant_id="P01")
            self.assertEqual(p01_avc["paired_exercises"], "squat")
            self.assertEqual(int(p01_avc["paired_control_faulty_reps"]), 3)
            self.assertEqual(int(p01_avc["paired_control_valid_reps"]), 4)
            self.assertEqual(int(p01_avc["paired_ai_faulty_reps"]), 1)
            self.assertEqual(int(p01_avc["paired_ai_valid_reps"]), 4)
            self.assertAlmostEqual(float(p01_avc["paired_diff_ai_minus_control"]), -0.5)

            summary_text = (out_dir / "summary.md").read_text(encoding="utf-8")
            self.assertIn("Kiểm tra dữ liệu đầu vào", summary_text)
            self.assertIn("Ma trận nhầm lẫn", summary_text)
            self.assertIn("Cohen's κ", summary_text)
            self.assertIn("Tần suất ứng dụng báo lỗi mà HLV không thấy", summary_text)
            self.assertNotIn("-0.000", summary_text)
            self.assertNotIn("-0.0%", summary_text)

    def test_cli_stops_with_nonzero_on_unrecoverable_missing_input(self) -> None:
        script_path = EVAL_DIR / "evaluate.py"
        with tempfile.TemporaryDirectory() as tmp:
            proc = subprocess.run(
                [
                    sys.executable,
                    str(script_path),
                    "--logs",
                    str(Path(tmp) / "nonexistent"),
                    "--labels",
                    str(Path(tmp) / "missing.csv"),
                    "--out",
                    str(Path(tmp) / "out"),
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(proc.returncode, 0)


if __name__ == "__main__":
    unittest.main()
