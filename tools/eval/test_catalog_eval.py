from __future__ import annotations

import csv
import json
from pathlib import Path
import sys
import tempfile
import unittest

EVAL_DIR = Path(__file__).resolve().parent
if str(EVAL_DIR) not in sys.path:
    sys.path.insert(0, str(EVAL_DIR))

import evaluate
from test_evaluate import _find_row, _make_set_json


def _rep(n: int, t_ms: int, faults: list[str], judged: bool = True) -> dict:
    data: dict = {"fault_types": faults}
    if not judged:
        data["form_judged"] = False
    return {
        "t_ms": t_ms,
        "type": "rep",
        "n": n,
        "correct": not faults,
        "faults": faults,
        "data": data,
    }


def _read(path: Path) -> list[dict]:
    with path.open("r", encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


class TestCatalogAndConditions(unittest.TestCase):
    def _run(self, conditions_rows: list[list[str]] | None = None) -> Path:
        root = Path(tempfile.mkdtemp())
        logs = root / "logs"
        logs.mkdir()
        for pid in ("P01", "P02"):
            events = [
                _rep(1, 5000, ["alignment"]),
                _rep(2, 9000, ["MissingBody"]),
                _rep(3, 13000, [], judged=False),
                {"t_ms": 20000, "type": "set_complete"},
            ]
            payload = _make_set_json(pid, "ai", "bird_dog", 1, events=events)
            (logs / f"vika_{pid}_01_bird_dog_set1.json").write_text(
                json.dumps(payload), encoding="utf-8"
            )
        labels = root / "labels.csv"
        with labels.open("w", encoding="utf-8", newline="") as fh:
            w = csv.writer(fh)
            w.writerow(list(evaluate.REQUIRED_LABEL_COLUMNS))
            for pid in ("P01", "P02"):
                w.writerow(["C1", pid, "ai", "bird_dog", "1", "1", "4.0", "1", "alignment", ""])
                w.writerow(["C1", pid, "ai", "bird_dog", "1", "2", "8.0", "1", "", ""])
                w.writerow(["C1", pid, "ai", "bird_dog", "1", "3", "12.0", "1", "alignment", ""])
        argv = ["--logs", str(logs), "--labels", str(labels), "--out", str(root / "out")]
        if conditions_rows is not None:
            cond = root / "session_conditions.csv"
            with cond.open("w", encoding="utf-8", newline="") as fh:
                w = csv.writer(fh)
                w.writerow(["participant_id", "condition", "exercise_id", "set_index", "lux", "note"])
                w.writerows(conditions_rows)
            argv += ["--conditions", str(cond)]
        self.assertEqual(evaluate.main(argv), 0)
        return root / "out"

    def test_catalog_adds_exercise_drops_status_codes_and_unjudged_reps(self) -> None:
        out = self._run()
        issues = _read(out / "validation_issues.csv")
        self.assertFalse([i for i in issues if i["code"] == "unknown_exercise_id"])
        self.assertFalse([i for i in issues if "MissingBody" in i["message_en"]])

        counting = _find_row(_read(out / "counting_accuracy.csv"), exercise_id="bird_dog")
        self.assertEqual(int(counting["matched"]), 6)

        fd = _find_row(_read(out / "fault_detection.csv"), exercise_id="bird_dog", fault_id="alignment")
        self.assertEqual(int(fd["n_matched_reps"]), 4)
        self.assertEqual(int(fd["n_unjudged_reps"]), 2)
        self.assertEqual(int(fd["tp"]), 2)
        self.assertEqual(int(fd["fn"]), 0)
        self.assertEqual(int(fd["fp"]), 0)
        self.assertEqual(int(fd["n_participants"]), 2)
        self.assertEqual(float(fd["recall_boot95_low"]), 1.0)

        summary = (out / "summary.md").read_text(encoding="utf-8")
        self.assertIn("form_judged = false", summary)
        self.assertNotIn("#### Bài `squat`", summary)
        self.assertNotIn("3.3. Độ chính xác theo điều kiện quay", summary)
        self.assertIn("heel", evaluate.KNOWN_EXERCISES["squat"])

    def test_per_condition_table(self) -> None:
        out = self._run(
            [
                ["P01", "ai", "bird_dog", "1", "low", ""],
                ["P02", "ai", "bird_dog", "1", "high", ""],
            ]
        )
        rows = _read(out / "fault_detection_by_condition.csv")
        low = _find_row(rows, factor="lux", level="low", exercise_id="bird_dog", fault_id="alignment")
        self.assertEqual(int(low["n_participants"]), 1)
        self.assertEqual(int(low["n_matched_reps"]), 2)
        self.assertEqual(int(low["tp"]), 1)
        summary = (out / "summary.md").read_text(encoding="utf-8")
        self.assertIn("3.3. Độ chính xác theo điều kiện quay", summary)

    def test_set_missing_from_conditions_is_warned(self) -> None:
        out = self._run([["P01", "ai", "bird_dog", "1", "low", ""]])
        codes = [i["code"] for i in _read(out / "validation_issues.csv")]
        self.assertIn("set_without_conditions", codes)


class TestFaultCatalogFile(unittest.TestCase):
    def test_catalog_covers_the_21_studied_exercises(self) -> None:
        form, status, names = evaluate.read_fault_catalog(evaluate.DEFAULT_CATALOG_PATH)
        self.assertEqual(len(form), 21)
        self.assertEqual(status, {"bird_dog": frozenset({"MissingBody", "Plank"})})
        self.assertEqual(form["plank"], ("Back", "Neck", "Knees"))
        self.assertEqual(set(names), set(form))

    def test_label_guide_lists_every_form_fault_under_its_exercise(self) -> None:
        guide = (EVAL_DIR / "HUONG_DAN_GAN_NHAN.md").read_text(encoding="utf-8")
        sections = guide.split("\n### 3.")[1:]
        by_ex = {s.split("`", 2)[1]: s for s in sections}
        form, status, _ = evaluate.read_fault_catalog(evaluate.DEFAULT_CATALOG_PATH)
        self.assertEqual(set(by_ex), set(form))
        for ex_id, faults in form.items():
            for fault in faults:
                self.assertIn(f"| `{fault}` |", by_ex[ex_id], f"{ex_id}.{fault}")
            for code in status.get(ex_id, ()):
                self.assertNotIn(f"| `{code}` |", by_ex[ex_id])

    def test_cue_map_has_no_unknown_faults_under_the_catalog(self) -> None:
        saved = dict(evaluate.KNOWN_EXERCISES)
        try:
            evaluate.apply_fault_catalog(evaluate.DEFAULT_CATALOG_PATH)
            issues: list[evaluate.ValidationIssue] = []
            evaluate.load_cue_map(EVAL_DIR / "cue_fault_map.csv", issues)
            self.assertEqual(issues, [])
        finally:
            evaluate.KNOWN_EXERCISES.clear()
            evaluate.KNOWN_EXERCISES.update(saved)
            evaluate.STATUS_FAULTS.clear()


if __name__ == "__main__":
    unittest.main()
