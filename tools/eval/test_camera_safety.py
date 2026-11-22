from __future__ import annotations

import json
from pathlib import Path
import sys
import tempfile
import unittest

EVAL_DIR = Path(__file__).resolve().parent
if str(EVAL_DIR) not in sys.path:
    sys.path.insert(0, str(EVAL_DIR))

import camera_safety


class TestCameraSafety(unittest.TestCase):
    def test_detection_latency_leak_and_recovery(self) -> None:
        events = [
            {"t_ms": 1000, "type": "activated"},
            {"t_ms": 3000, "type": "rep", "n": 1, "correct": True, "faults": [], "data": {}},
            {"t_ms": 6500, "type": "unseen_start", "phase": "active", "reason": "bodyInFrame"},
            {"t_ms": 7000, "type": "rep", "n": 2, "correct": True, "faults": [], "data": {}},
            {"t_ms": 9000, "type": "unseen_end"},
            {"t_ms": 12000, "type": "pause_start"},
            {"t_ms": 14000, "type": "pause_end"},
            {"t_ms": 14000, "type": "unseen_start", "phase": "setup", "reason": "holdStill"},
            {"t_ms": 17000, "type": "unseen_end"},
            {"t_ms": 17000, "type": "activated"},
        ]
        set_log = {"schema": 1, "kind": "exercise_set", "participant_id": "T01",
                   "exercise_id": "squat", "set_index": 1, "sync_beep_t_ms": 1000,
                   "started_at_utc": "2026-11-21T09:00:00.000Z", "events": events}
        trials = (
            "tester_id,exercise_id,set_index,scenario,trial,start_video_t_s,end_video_t_s,note\n"
            "T01,squat,1,1,1,5.0,7.5,\n"
            "T01,squat,1,2,1,\"10,5\",12.5,\n"
            "T01,squat,2,3,1,1,2,\n"
        )
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "logs").mkdir()
            (root / "logs" / "s.json").write_text(json.dumps(set_log), encoding="utf-8")
            (root / "trials.csv").write_text(trials, encoding="utf-8")
            rows = camera_safety.run(root / "trials.csv", root / "logs")

        out_of_frame, gone, missing = rows
        self.assertEqual(out_of_frame["detected"], "yes")
        self.assertEqual(out_of_frame["reasons"], "bodyInFrame")
        self.assertEqual(out_of_frame["right_prompt"], "yes")
        self.assertEqual(out_of_frame["latency_s"], "0.50")
        self.assertEqual(out_of_frame["reps_in_window"], 1)
        self.assertEqual(out_of_frame["recovery_s"], "0.50")
        self.assertEqual(out_of_frame["problem"], "")

        self.assertEqual(gone["reasons"], "paused")
        self.assertEqual(gone["right_prompt"], "yes")
        self.assertEqual(gone["latency_s"], "0.50")
        self.assertEqual(gone["recovery_s"], "3.50")

        self.assertIn("no set log", missing["problem"])
        md = camera_safety.summarise(rows)
        self.assertIn("| 1 | 1 | 1/1 | 1/1 | 0.50 | 1 rep, 0 lỗi | 0.50 (1/1 hồi phục) |", md)


if __name__ == "__main__":
    unittest.main()
