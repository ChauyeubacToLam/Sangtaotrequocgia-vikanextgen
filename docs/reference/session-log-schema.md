# Vika session log, schema 1

Written 2026-11-18. This is the contract between the app (which writes these files) and
`tools/eval/` (which reads them). Both sides are being built at the same time from this document, so
neither may change a field name or a meaning without the other. Examples use made-up values.

## Why it looks like this

The judges asked for three things that all need per-event data: precision and recall of each form
fault against coach-labelled video, the time during which the app could not see the user well enough
to judge, and whether a spoken correction was followed by a corrected rep. The app records **events**
(one per rep, per spoken cue, per change of state), never per-frame data, so that recording costs
nothing on a slow phone. Everything is kept in memory during a set and written once when the set
ends.

## Files

One file per exercise set, plus one per workout session. UTF-8 JSON, one object per file.

- Set file: `vika_<session_id>_<seq>_<exercise_id>_set<set_index>.json`. `seq` is a two-digit
  counter of sets within the session (`01`, `02`, …) so files sort in the order they were performed.
- Session file: `vika_<session_id>_session.json`.

`session_id` is `<UTC start, yyyyMMddTHHmmssZ>-<participant_id>`, for example
`20261120T091500Z-P07`. When no participant id is set, `participant_id` is `anon`.

## Set file

```json
{
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
  "sync_beep_t_ms": 5120,
  "frames": {
    "total": 2710,
    "with_pose": 2650,
    "duration_ms": 110000,
    "mean_fps": 24.6,
    "min_fps_1s": 11,
    "max_gap_ms": 310
  },
  "events": [
    {"t_ms": 0, "type": "unseen_start", "phase": "setup", "reason": "holdStill"},
    {"t_ms": 5120, "type": "unseen_end"},
    {"t_ms": 5120, "type": "activated"},
    {"t_ms": 8400, "type": "rep", "n": 1, "correct": true, "faults": [], "data": {}},
    {"t_ms": 11950, "type": "rep", "n": 2, "correct": false, "faults": ["depth"], "data": {}},
    {"t_ms": 12100, "type": "cue", "key": "squat.depth", "played": true, "fault": "depth"},
    {"t_ms": 20300, "type": "unseen_start", "phase": "active", "reason": "bodyInFrame"},
    {"t_ms": 22800, "type": "unseen_end"},
    {"t_ms": 30100, "type": "fault_start", "fault": "Back", "message": "Hông hơi chùng"},
    {"t_ms": 33400, "type": "fault_end", "fault": "Back", "message": "Hông hơi chùng"},
    {"t_ms": 41000, "type": "pause_start"},
    {"t_ms": 47000, "type": "pause_end"},
    {"t_ms": 110000, "type": "set_complete"}
  ],
  "set_log": {},
  "summary": {
    "reps": 10,
    "good_reps": 7,
    "active_ms": 98000,
    "unseen_ms": 2500,
    "paused_ms": 6000
  }
}
```

### Top-level fields

| Field | Meaning |
|---|---|
| `schema` | Always `1` for this document. |
| `condition` | `"ai"`: normal feedback. `"control"`: the app judged and recorded but gave no feedback. |
| `exercise_id` | The id the set was launched with, the same key the catalog uses. |
| `set_index` | 1-based set number of this exercise within the session. |
| `started_at_utc` | Wall-clock time of the first frame of the set, ISO 8601, UTC, milliseconds. |
| `sync_beep_t_ms` | `t_ms` at which the start sound was requested, or `null` if none played. A coach's video time is aligned to the log through this sound. |
| `frames.total` | Frames the app handled in this set, with or without a detected pose. |
| `frames.mean_fps` | `total` divided by `duration_ms`, in frames per second. |
| `frames.min_fps_1s` | Fewest frames handled in any whole one-second window while the app was not paused. |
| `frames.max_gap_ms` | Longest time between two consecutive handled frames while not paused. |
| `set_log` | The exercise's own set totals (`ExerciseLogger.setLogs`), copied as they are. |
| `summary.active_ms` | Time the exercise was activated and not paused. |
| `summary.unseen_ms` | Part of `active_ms` covered by `unseen_start` … `unseen_end` with `phase` `"active"`. |

### Time

Every `t_ms` is an integer number of milliseconds since the first frame of the set. It is taken from
the frame timestamp the exercise already reads once per frame, so all events produced while handling
one frame carry the same `t_ms`. Events are in non-decreasing `t_ms` order.

### Events

| `type` | Extra fields | Emitted when |
|---|---|---|
| `activated` | none | The exercise goes from not activated to activated: at the start, and again after every resume. |
| `rep` | `n`, `correct`, `faults`, `data` | A new `RepLog` appears in the exercise's logger. `n` is its `repNumber`, `correct` its `correctForm`, `data` its `data` map copied as it is, and `faults` is `data["fault_types"]` if that is a list, else `[]`. For hold exercises one `rep` is one completed hold. |
| `cue` | `key`, `played`, optional `fault` | The voice coach asks the sink to play a key. `played` is false when the key was suppressed (control condition) or has no audio. `fault` is the fault id that triggered the cue, present only when the coach knows it at that point. |
| `unseen_start` | `phase`, `reason` | The exercise's guidance signal becomes non-null, or changes kind. `reason` is the kind's name (`bodyInFrame`, `lighting`, `turnSide`, `searching`, …). `phase` is `"setup"` before activation and `"active"` after. |
| `unseen_end` | none | The guidance signal becomes null, or changes kind (then it is followed at the same `t_ms` by a new `unseen_start`). |
| `fault_start` / `fault_end` | `fault`, `message` | A (type, message) pair enters or leaves the exercise's `liveFaults`. Used mainly by hold exercises, where a fault has a duration. |
| `pause_start` / `pause_end` | none | The exercise's paused state turns on or off. |
| `phase` | `from`, `to`, `m`, `fb` | While activated and not paused, the exercise's `currentPhaseKey` changes (`from` is null on the first one). `m` is a snapshot of the exercise's `debugData` on that frame, primitives only: numbers rounded to 2 decimals, booleans, and strings up to 24 characters. `fb` is the frame's feedback map (Vietnamese strings, e.g. `Result`/`Error` when an attempt is not counted). Added 2026-11-21 to diagnose rep counting from device tests. |
| `set_complete` | none | The set ended. Always the last event of a set that finished; absent if the user quit. |
| `guidance_skipped` | `reason` | The user tapped "Bỏ qua cảnh báo" on a `turnSide`, `faceCamera` or `lighting` prompt (offered after it has shown for 5 s). From then until the set ends, frames where that prompt would fire keep counting reps but do not judge form: they still produce `unseen_start` with that `reason`, `liveFaults` read as empty, and a rep landing after such a frame has `data.form_judged = false`, `faults = []`, `correct = true`. Added 2026-11-23. Readers computing precision/recall must drop reps with `form_judged == false`. |

A reader must ignore event types and fields it does not know.

`fault` ids are the exercise's own (`depth`, `sag`, `Back`, …). Some ids cover two opposite faults
(Push-Up logs both sagging and piking as `sag`); schema 1 does not split them. `message` on
`fault_start` is the Vietnamese text the user would see and does distinguish them.

## Session file

```json
{
  "schema": 1,
  "kind": "session",
  "session_id": "20261120T091500Z-P07",
  "participant_id": "P07",
  "condition": "ai",
  "started_at_utc": "2026-11-20T09:15:00.000Z",
  "ended_at_utc": "2026-11-20T09:31:40.000Z",
  "satisfaction": 4,
  "fault_reports": [
    {"exercise_id": "squat", "set_index": 1,
     "file": "vika_20261120T091500Z-P07_01_squat_set1.json", "fault": "heel"}
  ],
  "files": ["vika_20261120T091500Z-P07_01_squat_set1.json"]
}
```

`satisfaction` is the user's answer to one question at the end of the session, an integer 1 to 5, or
`null` if it was not asked or was skipped.

`fault_reports` (added 2026-11-20) lists the faults the user marked "Báo sai" on the rest screen
after a set, in the `ai` condition only. The set log is already written by then, so the report
lives here and points at the set by `file`. It is empty when nothing was reported. Since
2026-11-20 the last set of an exercise also gets a rest screen in the `ai` condition, so every set
can be reported.
