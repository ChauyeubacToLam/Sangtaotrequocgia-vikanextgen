from __future__ import annotations

import csv
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

EVAL_DIR = Path(__file__).resolve().parent
if str(EVAL_DIR) not in sys.path:
    sys.path.insert(0, str(EVAL_DIR))

import clips


def _log(ex: str, set_index: int, started: str, beep_ms: int, dur_ms: int, session: str = "S1") -> dict:
    return {
        "schema": 1,
        "kind": "exercise_set",
        "session_id": session,
        "participant_id": "P01",
        "condition": "ai",
        "platform": "android",
        "os_version": "14",
        "exercise_id": ex,
        "set_index": set_index,
        "started_at_utc": started,
        "sync_beep_t_ms": beep_ms,
        "frames": {"duration_ms": dur_ms},
        "events": [],
    }


class TestSuggestAndConditions(unittest.TestCase):
    def test_beeps_follow_log_clock_from_one_anchor(self) -> None:
        logs = [
            dict(_log("squat", 1, "2026-11-24T08:00:00.000Z", 3000, 63000), _file="a.json"),
            dict(_log("plank", 1, "2026-11-24T08:05:00.000Z", 2500, 92500), _file="b.json"),
            dict(_log("lunge", 1, "2026-11-24T08:01:00.000Z", 1000, 9000, session="S2"), _file="c.json"),
        ]
        rows, skipped = clips.suggest_beeps(logs, "camB.mp4", ("P01", "ai", "squat", 1), 10.0)
        self.assertEqual(skipped, [])
        by_ex = {r["exercise_id"]: r for r in rows}
        self.assertEqual(set(by_ex), {"squat", "plank"})
        self.assertEqual(by_ex["squat"]["beep_s"], "10.00")
        self.assertEqual(by_ex["squat"]["end_s"], "72.00")
        self.assertEqual(by_ex["plank"]["beep_s"], "309.50")
        self.assertEqual(by_ex["plank"]["end_s"], "401.50")

    def test_beep_before_video_start_is_skipped(self) -> None:
        logs = [
            dict(_log("squat", 1, "2026-11-24T08:00:00.000Z", 0, 1000), _file="a.json"),
            dict(_log("plank", 1, "2026-11-24T08:05:00.000Z", 0, 1000), _file="b.json"),
        ]
        rows, skipped = clips.suggest_beeps(logs, "v.mp4", ("P01", "ai", "plank", 1), 5.0)
        self.assertEqual([r["exercise_id"] for r in rows], ["plank"])
        self.assertEqual(len(skipped), 1)

    def test_condition_rows_skip_sets_already_listed(self) -> None:
        logs = [_log("squat", 1, "2026-11-24T08:00:00Z", 0, 1), _log("squat", 2, "2026-11-24T08:02:00Z", 0, 1)]
        rows = clips.condition_rows(logs, [("P01", "ai", "squat", 1)])
        self.assertEqual([(r["set_index"], r["device"]) for r in rows], [(2, "android 14")])


class TestMergeAndCut(unittest.TestCase):
    KEY = [
        {"clip_id": "c1", "clip_file": "c1.mp4", "participant_id": "P03", "condition": "control",
         "exercise_id": "plank", "set_index": "1"},
    ]

    def test_merge_maps_clip_back_to_set_and_skips_blank_starter_rows(self) -> None:
        sheet = [
            {"coach_id": "C1", "clip_id": "c1", "exercise_id": "plank", "rep_n": "", "counted": ""},
            {"coach_id": "C1", "clip_id": "c1", "exercise_id": "plank", "rep_n": "1",
             "video_t_s": "15.2", "counted": "1", "faults": "Back", "note": ""},
        ]
        rows, problems = clips.merge_labels(self.KEY, sheet)
        self.assertEqual(problems, [])
        self.assertEqual(len(rows), 1)
        self.assertEqual(
            (rows[0]["participant_id"], rows[0]["condition"], rows[0]["set_index"], rows[0]["faults"]),
            ("P03", "control", "1", "Back"),
        )

    def test_merge_reports_unknown_clip_and_wrong_exercise(self) -> None:
        sheet = [
            {"clip_id": "zz", "exercise_id": "plank", "rep_n": "1"},
            {"clip_id": "c1", "exercise_id": "squat", "rep_n": "1"},
        ]
        rows, problems = clips.merge_labels(self.KEY, sheet)
        self.assertEqual(rows, [])
        self.assertEqual(len(problems), 2)

    def test_cut_writes_key_apart_and_sheet_without_identities(self) -> None:
        root = Path(tempfile.mkdtemp())
        (root / "videos").mkdir()
        (root / "videos" / "camB.mp4").write_bytes(b"x")
        beeps = root / "beep_times.csv"
        clips.write_rows(beeps, clips.BEEP_COLUMNS, [
            {"video_file": "camB.mp4", "participant_id": "P01", "condition": "ai",
             "exercise_id": "squat", "set_index": 1, "beep_s": "10.00", "end_s": "70.00"},
            {"video_file": "camB.mp4", "participant_id": "P01", "condition": "control",
             "exercise_id": "squat", "set_index": 1, "beep_s": "90.00", "end_s": "150.00"},
        ])
        argv = ["cut", "--beeps", str(beeps), "--video-dir", str(root / "videos"),
                "--out-dir", str(root / "coach"), "--key", str(root / "private" / "clip_key.csv")]
        calls = []

        def fake_run(cmd, **kwargs):
            calls.append(cmd)
            return mock.Mock(returncode=0, stderr="")

        with mock.patch.object(clips, "require_ffmpeg", return_value="ffmpeg"), \
                mock.patch.object(clips.subprocess, "run", side_effect=fake_run):
            self.assertEqual(clips.main(argv), 0)
            self.assertEqual(clips.main(argv), 0)
        self.assertEqual(len(calls), 2)
        self.assertIn("-an", calls[0])
        key = clips.read_rows(root / "private" / "clip_key.csv")
        self.assertEqual({r["condition"] for r in key}, {"ai", "control"})
        sheets = sorted((root / "coach").glob("coach_sheet_*.csv"))
        text = sheets[0].read_text(encoding="utf-8")
        self.assertNotIn("P01", text)
        self.assertNotIn("control", text)
        with sheets[0].open(encoding="utf-8") as fh:
            self.assertEqual(next(csv.reader(fh)), list(clips.SHEET_COLUMNS))

    def test_cut_refuses_key_inside_coach_folder(self) -> None:
        root = Path(tempfile.mkdtemp())
        argv = ["cut", "--beeps", str(root / "b.csv"), "--video-dir", str(root),
                "--out-dir", str(root / "coach"), "--key", str(root / "coach" / "clip_key.csv")]
        with self.assertRaises(SystemExit):
            clips.main(argv)


class TestP00Gate(unittest.TestCase):
    def test_verdicts(self) -> None:
        import p00_gate

        known = {"plank": {"Back", "Neck", "Knees"}}
        good = {
            "exercise_id": "plank", "condition": "ai", "set_index": 1, "sync_beep_t_ms": 500,
            "events": [{"type": "rep", "faults": ["Back"]}] * 3
            + [{"type": "cue", "fault": "Back", "played": True}, {"type": "set_complete"}],
        }
        self.assertEqual(p00_gate.check_set(good, known, 3, 0)["verdict"], "PASS")
        bad = dict(good, sync_beep_t_ms=None, events=[
            {"type": "rep", "faults": ["Hip"]},
            {"type": "cue", "fault": "Back", "played": False},
        ])
        verdict = p00_gate.check_set(bad, known, 3, 0)["verdict"]
        for part in ("1 reps", "no beep", "codes not in catalog", "fault cues have no audio"):
            self.assertIn(part, verdict)


class TestFfmpegArgs(unittest.TestCase):
    def test_windows_paths_are_escaped_for_drawtext(self) -> None:
        self.assertEqual(clips.ffmpeg_path("C:\\Windows\\Fonts\\arial.ttf"), "C\\:/Windows/Fonts/arial.ttf")
        cmd = clips.overlay_command("ffmpeg", Path("in.mp4"), Path("out.mp4"), -2.0, 3.0,
                                    Path("t.txt"), Path("C:/Windows/Fonts/arial.ttf"))
        self.assertEqual(cmd[cmd.index("-ss") + 1], "0.000")
        self.assertIn("fontfile='C\\:/Windows/Fonts/arial.ttf'", cmd[cmd.index("-vf") + 1])

    def test_overlay_text_says_clean_when_no_fault(self) -> None:
        text = clips.overlay_text({"exercise_id": "plank", "participant_id": "P02", "set_index": "1",
                                   "coach_rep_n": "3", "coach_faults": "Back", "app_faults": ""})
        self.assertIn("HLV: Back", text)
        self.assertIn("AI:  clean", text)


if __name__ == "__main__":
    unittest.main()
