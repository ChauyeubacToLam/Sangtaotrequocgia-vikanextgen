# Vika Competition Evaluation Tool (`tools/eval/`)

Standard-library Python 3 tool that compares Vika exercise session logs (`docs/reference/session-log-schema.md`, schema 1) against video-based coach labels (CSV) and generates CSV tables plus a paste-ready Vietnamese Markdown summary (`summary.md`) for the competition submission.

No third-party packages are required (Python 3.9+ standard library only).

---

## Directory Contents

- `evaluate.py` — Single-file CLI entry point.
- `test_evaluate.py` — `unittest` suite covering synthetic scenarios, edge cases, input recovery, and end-to-end CLI execution.
- `camera_safety.py` — Separate CLI for the provoked bad-camera trials (`KE_HOACH_THU_SO_LIEU.md` section 5): `--trials an_toan_camera.csv --logs <dir> --out <dir>` writes `camera_safety.csv` and `camera_safety_summary.md` (detection, prompt kind, latency, reps/faults logged during the bad window, recovery). Checked by `test_camera_safety.py`.
- `fault_catalog.csv` — The fault codes of all 24 kept exercises, read from the app source on 2026-11-23: `exercise_id, exercise_vi, unit (rep|hold), hold_s, fault, kind (form|status), description_vi`. `evaluate.py` loads it by default; `kind=status` codes (`bird_dog` `MissingBody`, `Plank`) are app states, not form faults, and are dropped from app reps silently.
- `clips.py` — Video side of the study: `suggest` (predict each set's beep time in a camera video from one beep found by ear), `conditions` (append a `session_conditions.csv` row per set log), `cut` (one muted clip per set with a random name, plus a separate `clip_key.csv`), `merge` (coach sheets keyed by `clip_id` back to the 10-column label CSV), `overlay` (short excerpts of `wrong_detections.csv` with `HLV: … / AI: …` burned in). `cut` and `overlay` need `ffmpeg` on PATH (`winget install Gyan.FFmpeg`). Checked by `test_clips.py`.
- `p00_gate.py` — Checks the P00 trial logs (`--logs <dir>`): per set, rep count against `--target` (default 10; `--hold-target` 3 for hold exercises) ± `--tolerance` 1, sync beep present, fault codes all in `fault_catalog.csv`, fault cues with audio in `ai`. Lists exercises with no log yet. Exit code 1 while any exercise fails or is missing.
- `HUONG_DAN_GAN_NHAN.md` — Vietnamese instruction sheet for the video-labelling coaches, all 24 exercises. Section 3 mirrors `fault_catalog.csv`; `test_catalog_eval.py` fails if they drift apart.
- `coach_labels_template.csv` — Spreadsheet-friendly CSV template with example rows across `squat`, `push_up`, `glute_bridge`, and `plank`.
- `cue_fault_map.csv` — Optional mapping from Vika voice cue keys (`key`) to canonical fault IDs (`fault`) when `cue` log events omit `"fault"`. Covers the 24 exercises.
- `fixtures/` — Hand-written synthetic schema-1 logs and coach labels used for end-to-end testing.

---

## How to Run

### Basic command
```bash
python tools/eval/evaluate.py \
  --logs <path-to-json-logs-dir> \
  --labels <path-to-coach-labels.csv> \
  --out <path-to-output-dir>
```

### Recommended command (with optional voice-cue mapping or multiple coach CSVs)
```bash
python tools/eval/evaluate.py \
  --logs path/to/logs \
  --labels path/to/coach1.csv path/to/coach2.csv \
  --cue-map tools/eval/cue_fault_map.csv \
  --out path/to/eval_output
```

### Optional CLI flags
- `--labels <csv_or_dir> [...]`: Accepts one CSV file, multiple CSV files (e.g. one spreadsheet per coach), or a directory of `.csv` files (automatically excluding `--out`, `--cue-map`, and `coach_labels_template.csv`). Supports UTF-8 with or without Excel BOM (`\ufeff`), comma/tab/semicolon column delimiters, decimal commas (`12,4`), `"1.0"`/`"0.0"` integer cells, and `mm:ss` timestamps (`1:05.2`).
- `--cue-map <csv>`: Optional CSV with columns `key,fault` (and optional `exercise_id`) used only when a `cue` event in a set log omits `"fault"`. Rows with `fault` set to `none` (or empty) explicitly mark non-fault cues (e.g. rep counts, setup prompts, praise).
- `--tolerance-s <float>`: Time-matching tolerance in seconds when `video_t_s` and `sync_beep_t_ms` are present (default: `2.5`).
- `--primary-coach <coach_id>`: Reference coach ID to prefer on sets double-labelled by two coaches when computing App-vs-Coach tables (default: the coach who labelled the most sets overall, tie-broken alphabetically).
- `--catalog <csv|none>`: Fault catalog to measure against. Default: `fault_catalog.csv` next to `evaluate.py` (24 exercises). `none` keeps the built-in 4-exercise table the unit tests use.
- `--conditions <csv>`: Optional `session_conditions.csv`: `participant_id, condition, exercise_id, set_index`, then one column per recording factor (`camera_angle`, `lux`, `clothing`, `body_type`, `device`, `location`, any others; `note` is ignored). Adds `fault_detection_by_condition.csv` and summary section 3.3. Labelled sets missing from the file are warned and left out of that table only. `clips.py conditions` writes the skeleton.
- `--form-faults-only`: Optional flag that excludes non-form-affecting soft warnings on app `rep` events (faults emitted when `rep.correct == true` or `rep.data["fault_affects_form"][f] == false`). By default (`false`), `rep.faults` is evaluated verbatim per `session-log-schema.md`.

### Running the test suite
```bash
python -m unittest discover -s tools/eval -p "test_*.py" -v
```

---

## Video workflow (`clips.py`)

```bash
python tools/eval/clips.py suggest --logs logs/P01 --video P01_camB.mp4 --anchor P01,ai,squat,1 --anchor-beep-s 42.6 --out beep_times.csv
python tools/eval/clips.py cut --beeps beep_times.csv --video-dir videos --out-dir coach_clips --key private/clip_key.csv
python tools/eval/clips.py merge --key private/clip_key.csv --sheets C1_sheet.csv C2_sheet.csv --out labels.csv
python tools/eval/evaluate.py --logs logs --labels labels.csv --conditions session_conditions.csv --cue-map tools/eval/cue_fault_map.csv --out eval_out
python tools/eval/clips.py overlay --wrong eval_out/wrong_detections.csv --key private/clip_key.csv --clips-dir coach_clips --out-dir wrong_clips
```

`suggest` uses the phone clock in the logs (`started_at_utc + sync_beep_t_ms`), so one beep found by ear per
camera video places every other set of that session; check two or three by ear. `cut` only cuts sets not yet in
the key, so it can run after each participant. Coach sheets list `clip_id` and `exercise_id` only; coaches add one
row per rep and never see the participant or the condition. `clip_key.csv` must stay out of the coach folder
(`cut` refuses otherwise). Because each clip starts at the beep, a coach's time from the start of the clip is the
`video_t_s` that `evaluate.py` expects.

## Measured Exercises and Canonical Fault IDs

The full 24-exercise list is `fault_catalog.csv`. The table below is the built-in fallback used with `--catalog none`.

| `exercise_id` | Archetype | Canonical `fault` IDs (exact case) | Notes |
|---|---|---|---|
| `squat` | Rep-counted | `depth`, `trunk`, `heel`, `tempo`, `sync` | All lowercase. |
| `push_up` | Rep-counted | `sag`, `depth`, `tempo` | Schema 1 combines both hip sagging and hip piking under `sag`. |
| `glute_bridge` | Rep-counted | `hip_extension`, `hyperextension`, `knee_angle`, `speed_control`, `neck_head` | All lowercase. |
| `plank` | 15 s holds | `Back`, `Neck`, `Knees` | One `rep` = one completed 15 s hold. Capitalized in Dart `FaultRecord.type` (case-only typos in CSV are auto-normalized with a warning). |

---

## Coach Label CSV Format

Header (exact 10 columns):
```csv
coach_id,participant_id,condition,exercise_id,set_index,rep_n,video_t_s,counted,faults,note
```

- `coach_id`: Rater identifier (e.g. `C1`, `C2`).
- `participant_id`: Participant identifier matching the app log (e.g. `P07`).
- `condition`: `ai` or `control`.
- `exercise_id`: `squat`, `push_up`, `glute_bridge`, or `plank`.
- `set_index`: 1-based set number of that exercise within the session.
- `rep_n`: Coach's sequential attempt number within the set (`1, 2, ...`). For an observed set with zero attempts/completed holds at all, a single sentinel row with `rep_n = 0` and `counted = 0` marks the set as reviewed with zero valid reps.
- `video_t_s`: Seconds from the app's audible start sound (`sync_beep`) in the video to the end of that rep/hold. May be empty.
- `counted`: `1` if the coach considers the rep/15 s hold valid; `0` if incomplete/invalid (e.g. half rep, broken plank hold `< 15 s`).
- `faults`: `;`-separated canonical fault IDs for that exercise; empty if clean.
- `note`: Free-text note.

---

## Exact Definitions (Quotable in the Competition Report)

1. **Valid coach rep vs uncounted attempt:** Only rows with `counted = 1` are coach-valid reps (`coach_valid_reps`) eligible for pairing with app `rep` events. Rows with `counted = 0` (`rep_n >= 1`) are recorded separately as `coach_uncounted_attempts`; if the app stayed silent on a `counted = 0` attempt, it is not a missed rep, whereas if the app emitted a `rep` event during a `counted = 0` attempt, that unmatched app `rep` is counted as a `phantom` rep.
2. **Rep matching (time with order fallback):** Within each `(participant_id, condition, exercise_id, set_index)`, coach rows are first checked for ascending `rep_n` order (if a spreadsheet export scrambled row order, `rep_n_out_of_order` is warned and `rep_n` order is restored), and coach-valid reps and app `rep` events are matched in strictly increasing sequence order. When `sync_beep_t_ms` is non-null in the set log and `video_t_s` is present, app rep time is `app_rel_t_s = (t_ms - sync_beep_t_ms) / 1000.0` and pairs are chosen by dynamic programming to (a) maximize the number of matched pairs with `|video_t_s - app_rel_t_s| <= 2.5 s`, (b) minimize total absolute time difference `sum(|Δt|)` (computed in integer microseconds), and (c) break exact ties in favor of earlier rep indices `(i, j)`. When only a subset of coach rows carry `video_t_s`, untimed rows are constrained within the monotonic time window `[prev_timed - tol, next_timed + tol]` of their neighboring timed rows so an untimed row never pairs backwards across earlier timed rows; when `sync_beep_t_ms` is `null` or all `video_t_s` cells are blank, reps are paired 1-to-1 in sequential order.
3. **Missed and phantom counts:** Every unmatched coach-valid rep (`counted = 1`) is a `missed` count (`coach_valid_reps = matched + missed`). Every unmatched app `rep` event is a `phantom` count (`app_reps = matched + phantom`). Neither is dropped.
4. **Reference coach on multi-coach sets:** When two coaches label the same set, App-vs-Coach tables evaluate each physical set once against a single reference coach (`--primary-coach`, or by default the coach who labelled the largest number of sets overall, tie-broken alphabetically by `coach_id`) so physical sets and reps are never double-counted. All shared sets are evaluated pairwise in `coach_agreement.csv`.
5. **Unjudged reps:** an app `rep` with `data.form_judged == false` (the user tapped "Bỏ qua cảnh báo", so the app counted without judging) stays in counting accuracy but is left out of every fault metric (5, 6, wrong detections, app-label cue correction). `fault_detection.csv` reports how many per exercise in `n_unjudged_reps`.
   **Participant bootstrap:** `precision_boot95_*` and `recall_boot95_*` resample participants with replacement (2000 times, seed 20261124) and take the 2.5 and 97.5 percentiles, because reps of one person are not independent. Empty with fewer than 2 participants.
   **Per-fault Precision, Recall, false-alarm rates, and 95% Wilson CIs:** Computed over `N = n_matched_reps` for each `(exercise_id, fault_id)` (plus `ANY_FAULT`, defined as having `>= 1` fault on the rep). `Precision = TP / (TP + FP)` over `n_app_positive = TP + FP` reps; `Recall = TP / (TP + FN)` over `n_coach_positive = TP + FN` reps; false-positive rate on coach-negative reps `FPR = FP / (FP + TN)` over `n_coach_negative = FP + TN` reps; false-alarm rate per matched rep = `FP / N`; and false-discovery rate `1 - Precision = FP / (TP + FP)`. Proportions are accompanied by two-sided 95% Wilson score confidence intervals (`z = 1.959964`) and surfaced both in Section 3.1 and in a dedicated Section 7.4 false-alarm summary in `summary.md`.
6. **Per-exercise confusion matrix:** Over `n_matched_reps` for an exercise, each matched rep is assigned to exactly one row (the coach's sorted `;`-joined fault set, or `clean` if empty) and one column (the app's sorted `;`-joined fault set, or `clean` if empty). Rows and columns always include `clean` plus every canonical single fault ID of that exercise, plus any multi-fault combination observed at least once, so cell counts are exact integers summing strictly to `n_matched_reps`.
7. **Inter-coach agreement and Cohen's kappa (`κ`):** On sets labelled by both `coach_a` and `coach_b`, each coach's `counted = 1` reps are aligned with the same time-then-order matcher (`±2.5 s`); when both coaches omit `video_t_s` on a set and enumerate the same attempt sequence `rep_n`, alignment preserves shared `rep_n` attempts where both coaches marked `counted = 1` so a `counted` disagreement on one attempt does not shift later reps. For each fault over `N` matched valid reps, observed agreement is `p_o = (a + d) / N`, chance agreement is `p_e = ((a+b)/N)*((a+c)/N) + ((c+d)/N)*((b+d)/N)`, and `κ = (p_o - p_e) / (1 - p_e)` (computed via exact integer numerators/denominators). When `1 - p_e == 0` (zero variance / 0% or 100% prevalence in both raters), `p_o = 1.0` and `κ` is reported as undefined (`undefined_degenerate_marginals`).
8. **Unseen time and reason breakdown:** Headline unseen fraction per exercise and overall is `sum(summary.unseen_ms) / sum(summary.active_ms)` across valid set logs (if a malformed log reports `unseen_ms > active_ms`, it is warned and clamped to `active_ms`). Event-level reason durations sum `unseen_start .. unseen_end` intervals by `(phase, reason)`; for `phase = "active"`, any overlap with `pause_start .. pause_end` is subtracted, and any trailing unclosed `unseen_start` is closed at `set_complete.t_ms` (or `frames.duration_ms` / last event `t_ms` if the user quit).
9. **Correction after a spoken cue:** Evaluated per `cue` event that resolves to a canonical fault `F` (from `cue.fault` in the log, or via `--cue-map` when `cue.fault` is missing). Spoken cues (`played = true`) and suppressed cues (`played = false`, e.g. in `control`) are strictly separated and never pooled together. When a live mid-rep cue is emitted inside an active `fault_start(F) .. fault_end(F)` span whose triggering in-progress rep completes at `fault_end.t_ms`, the evaluation cutoff is advanced to `fault_end.t_ms` so the triggering rep itself is not scored as "next 1". Subsequent app reps are app `rep` events with `rep.t_ms > cutoff_t_ms`; subsequent coach reps are coach-valid reps occurring strictly after any coach rep matched to an app rep with `rep.t_ms <= cutoff_t_ms` and after any unmatched timed coach rep with `video_t_s <= cutoff_rel_t_s` (including any earlier untimed missed rows preceding that timed prior row). A cue is corrected on **next 1** if `>= 1` subsequent rep exists and `F` is absent on the 1st subsequent rep; it is corrected on **both of next 2** if `>= 2` subsequent reps exist and `F` is absent on both the 1st and 2nd subsequent reps.
10. **With vs without feedback (`ai` vs `control`):** Per participant, coach-labelled fault rate in each condition is `faulty_valid_reps / valid_reps` (proportion of `counted = 1` reps with `>= 1` coach-labelled fault; total fault instances per rep is also reported). Per-exercise paired differences compare participants with `>= 1` valid rep of that exercise in both conditions; the `overall` within-participant paired difference `diff = rate_ai_common - rate_control_common` is computed strictly over `paired_exercises` (exercises performed with `>= 1` valid rep in **both** `ai` and `control` by that participant, with exact `paired_control_*` and `paired_ai_*` rep/fault counts reported alongside total counts) to prevent cross-exercise confounding when an exercise is missing in one condition: `diff < -1e-9` is `improved`, `diff > +1e-9` is `worsened`, and `|diff| <= 1e-9` is `same`. Two-sided exact binomial sign-test `p`-values are always printed alongside `n_non_tied` and `n_paired`.
11. **Candidate success and failure sets:** Among sets with `>= 1` spoken fault cue (`played = true`) and `>= 1` subsequent rep: a **success** candidate is a `(set, fault)` where at least one spoken cue for `F` is followed immediately by a rep without `F` (ranked with coach-verified sets, confirmed `F` on the preceding/triggering rep, and 0 remaining faults across all subsequent reps first); a **failure** candidate is a `(set, fault)` where `F` is present on every subsequent rep after the cue(s) (ranked with coach-verified sets and repeated cues `played_cue_count >= 2` first).
12. **Satisfaction and frame rate:** Session satisfaction aggregates integer scores `1..5` from `kind = "session"` logs by `condition` (`ai`, `control`, `overall`), reporting `n_sessions_total`, `n_responses`, `n_missing`, mean, SD, median, and `1..5` counts. Frame rate aggregates arithmetic mean and minimum (worst) of `frames.mean_fps` and `frames.min_fps_1s` (plus worst `frames.max_gap_ms` and the offending log filename) per exercise and overall, excluding zero-duration (`duration_ms <= 0`) or sub-1-second (`duration_ms < 1000` with 0 reps and no `set_complete`) aborted logs from `mean_fps` and excluding sub-1-second logs (`duration_ms < 1000`, non-paused total `< 1000 ms`, or maximum contiguous non-paused stretch `< 1000 ms` across `pause_start..pause_end` with `min_fps_1s == 0`) where zero whole 1-second windows elapsed from `min_fps_1s`.

---

## Output Files Reference (`--out <dir>`)

| File | Contents |
|---|---|
| `summary.md` | Paste-ready Vietnamese report: input warnings at top, definitions, and all tables with sample sizes. |
| `validation_issues.csv` | Every recoverable input warning/error with `file`, `line`, `code`, Vietnamese message, and English message. |
| `rep_matching.csv` | Every `matched`, `missed`, and `phantom` rep across paired sets with timestamps and fault sets. |
| `counting_accuracy.csv` | Per-exercise and overall `coach_valid_reps`, `coach_uncounted_attempts`, `app_reps`, `matched`, `missed`, `phantom`. |
| `fault_detection.csv` | Per-exercise and per-fault (`+ ANY_FAULT`) `TP, FP, FN, TN`, Precision + 95% Wilson CI, Recall + 95% Wilson CI, `false_positive_rate` + 95% Wilson CI, `fp_per_matched_rep`, and sample counts, plus `n_participants`, `n_unjudged_reps`, and participant-bootstrap 95% intervals for Precision and Recall. |
| `fault_detection_by_condition.csv` | Only with `--conditions`: the same counts, Precision and Recall with Wilson CIs, per `(factor, level, exercise_id, fault_id)`. |
| `confusion_matrices.csv` | Tidy per-exercise confusion matrix cells (`exercise_id, n_matched_reps, coach_label, app_label, count`). Rendered as 2D grids in `summary.md`. |
| `wrong_detections.csv` | Clip-finder index of every matched rep where coach and app fault sets disagree (`participant_id`, `set_index`, `coach_rep_n`, `app_rep_n`, `video_t_s`, `app_rel_t_s`, `log_file`, `false_positives`, `false_negatives`). |
| `coach_agreement.csv` | Pairwise coach agreement (`percent_agreement`, `cohen_kappa`, contingency counts, sample sizes) per exercise and fault. |
| `unseen_time.csv` | Per-exercise and overall `active_ms`, `unseen_ms`, `unseen_over_active_ratio`, and `paused_ms`. |
| `unseen_reasons.csv` | Duration and share breakdown of `unseen_start .. unseen_end` events by `exercise_id`, `phase`, and `reason`. |
| `cue_mapping_summary.csv` | Audit of `played=true` and `played=false` cues mapped from log `fault`, `--cue-map`, explicit non-faults, and unmapped cues. |
| `cue_correction.csv` | Next-1 and next-2 fault absence rates (with 95% Wilson CIs and sample counts) by coach labels and app labels, separated by `played=true` vs `played=false`. |
| `ai_vs_control_participants.csv` | Per-participant total and paired-exercise (`paired_control_*`, `paired_ai_*`) coach-labelled fault rates in `control` and `ai`, paired difference, and `improved`/`worsened`/`same` outcome. |
| `ai_vs_control_summary.csv` | Per-exercise and overall pooled rates, paired differences, `improved`/`worsened`/`same` counts, and sample-size-annotated sign test. |
| `cue_candidates.csv` | Ranked `success` and `failure` candidate sets for qualitative video examples. |
| `satisfaction.csv` | Mean, SD, median, missing count, and `1..5` score distribution by condition. |
| `frame_rate.csv` | Mean and worst `mean_fps`, `min_fps_1s`, and `max_gap_ms` per exercise with worst-case log filenames. |
| `fault_reports.csv` | One row per (`ai` set, app-detected or user-reported fault): `reported` (user tapped "Báo sai", from the session log's `fault_reports`), app detections of that fault on matched reps, how many the reference coach confirmed, and `verdict` (`app_false_alarm` = coach saw it on none, `coach_confirmed` = on all, `mixed`, `no_matched_rep`, `unlabelled`). Summarised in `summary.md` section 6.3, reported vs not reported. |
