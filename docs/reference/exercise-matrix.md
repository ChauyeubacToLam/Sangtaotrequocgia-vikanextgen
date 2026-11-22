# Exercise matrix

Per-exercise reference derived from a full read of the exercise source. Batches 1 to 4 were all
written 2026-11-16 and together cover all 40 exercise directories. Every threshold cites `file:line`. Nothing here was executed: no tests, no
analyzer, no device run. Statements about runtime behaviour are derived from reading the code and are
marked "by reading" where they are a conclusion and not a quoted value.

## Scope

- **Batch 1**: the ten numbered directories under `lib/exercise/`, in numeric order: `1.Bird Dog`,
  `2.Sit-Up`, `3.High Plank`, `4.Mountain Climber`, `5.Superman`, `7.Plank Shoulder Tap`,
  `8.Leg Raises (Supine)`, `9.Reverse Crunch`, `10.Vup`, `12.Dead Bug`. All 68 files read in full.
- **Batch 2**: `plank`, `14.Bear Plank`, `13.Plank Up-Down`, `side_plank_dip`, `squat`, `push up`,
  `wall_push_up`, `glute bridge`, `lunge`, `walking_lunge`. All 70 files read in full, plus
  `lib/utils/hold_seconds_accumulator.dart`, `lib/exercise/hold/rep_counted_hold_exercise.dart`
  (re-read), and the entries for these ten in `assets/data/exercise_catalog.json` and
  `lib/models/exercise_definition.dart`. Batch 2 sections carry a **Catalog** line; batch 1 sections
  do not.
- **Batch 3**: `curl_up`, `jumping jack`, `Jump_Squat`, `cossack_squat`, `russian_twist`,
  `standing_knee_to_elbow`, `tricep_dip`, `step_back_burpee`, `warrior_1`, `Cobra`. All 71 files
  read in full, plus `lib/utils/hold_seconds_accumulator.dart` (re-read), the entries for these ten
  in `assets/data/exercise_catalog.json` and `lib/models/exercise_definition.dart`, and the helper
  line ranges listed under "What was not read". Batch 3 sections carry a **Catalog** line.
- **Batch 4**: `Sphinx_Pose`, `bow_pose`, `butterfly_stretch`, `seated_forward_fold`,
  `downward_dog`, `low_lunge`, `raised_arms`, `prayer_pose`, `ashtanga_namaskara`,
  `surya_namaskar`. All 59 files read in full, plus `lib/exercise/hold/rep_counted_hold_exercise.dart`
  and `lib/exercise/hold/timer_metric.dart` (re-read), the entries for these ten in
  `assets/data/exercise_catalog.json` and `lib/models/exercise_definition.dart`, and the helper line
  ranges listed under "What was not read". Batch 4 sections carry a **Catalog** line and end with a
  **Cross-cutting checks** paragraph.
- Batch 1 sections now also carry a **Catalog** line (added with batch 4, from the catalog JSON and
  `exercise_definition.dart`). All four batches cite the catalog at each entry's `definitionId`
  line.
- No exercise directory is left uncovered.

## Summary index

One row per exercise, built from what each section says (not re-derived from code). Columns:
- **Archetype**: rep, hold (own machine), hold (`RepCountedHoldExercise`, "RCH"), or sequence.
- **View / orientation**: the camera view `checkSafety` accepts and the declared phone orientation
  ("portrait (default)" = no override, base default).
- **Form flag**: `isFormChecked` in `assets/data/exercise_catalog.json`.
- **Faults**: distinct fault types the code can log (rows that are only severity bands of one type
  count once; break ids, live-only text and rejection-only anti-cheat tables are not counted).
- **Dedicated test**: a test file under `test/exercise/` named for the exercise; "shared" means it
  is only exercised by multi-exercise test files.
- **Dead / perfect**: number of fault types, count keys, seconds keys or report lines the section
  records as never firing, structurally zero, always perfect, or firing only in a narrow
  ("nearly", "probably") case. For batch 3 this is taken from the batch 3 pattern table below.

| # | Exercise | Archetype | View / orientation | Form flag | Faults | Dedicated test | Dead / perfect |
|---|---|---|---|---|---|---|---|
| 1 | Bird Dog | rep (1.5 s top hold) | side / landscape | true | 9 | no | 1 |
| 2 | Sit-Up | rep | side / landscape | true | 3 | yes | 2 |
| 3 | High Plank | hold (RCH) | side / landscape | true | 3 | yes | 0 |
| 4 | Mountain Climber | rep | side / landscape | true | 3 | yes (counter only) | 0 |
| 5 | Superman | rep | side / landscape | true | 5 | no | 1 |
| 6 | Plank Shoulder Tap | rep | side / landscape | true | 4 | no | 1 |
| 7 | Leg Raises | rep | side / landscape | true | 5 | no | 2 |
| 8 | Reverse Crunch | rep | side / landscape | false | 4 | no | 1 |
| 9 | V-Up | rep | side (not enforced) / landscape | true | 5 | yes | 1 |
| 10 | Dead Bug | rep | side / landscape | true | 6 | yes | 1 |
| 11 | Plank (forearm) | hold (own) | side / landscape | true | 3 | yes | 0 |
| 12 | Bear Plank | hold (RCH) | side / landscape | true | 5 | shared | 0 |
| 13 | Plank Up-Down | rep (3 s holds) | side / landscape | true | 4 | yes | 1 |
| 14 | Side Plank | hold (RCH) | side / portrait + landscape | true | 3 | yes | 4 |
| 15 | Squat | rep | side (angled accepted) / portrait | true | 5 | yes | 0 |
| 16 | Push-Up | rep | side (angled accepted) / landscape | true | 3 | yes | 1 |
| 17 | Wall Push-Up | rep | side / portrait (default) | true | 9 | yes | 2 |
| 18 | Glute Bridge | rep | side / landscape | true | 5 | yes | 2 |
| 19 | Lunge | rep | side (angled accepted) / portrait | true | 4 | no | 2 |
| 20 | Walking Lunge | rep | side / portrait | true | 4 | yes | 1 |
| 21 | McGill Curl-Up | rep | side (angled accepted) / landscape | true | 4 | yes | 0 |
| 22 | Jumping Jack | rep | front (angled accepted) / portrait | true | 3 | no | 2 |
| 23 | Jump Squat | rep | side / portrait | true | 4 | yes | 0 |
| 24 | Cossack Squat | rep | front / portrait | true | 6 | yes | 1 |
| 25 | Russian Twist | rep | front / portrait + landscape | false | 5 | yes | 3 |
| 26 | Standing Knee-to-Elbow | rep | front / portrait | false | 3 | yes | 1 |
| 27 | Tricep Dip (Floor) | rep | side (angled accepted) / landscape | true | 0 (4 unwired) | yes | 4 |
| 28 | Step-Back Burpee | rep | side (angled accepted) / landscape | true | 4 | no | 1 |
| 29 | Warrior I | hold (own) | side / portrait (default) | true | 5 | yes | 0 |
| 30 | Cobra | hold (own) | side / portrait (default) | true | 7 | yes | 3 |
| 31 | Sphinx Pose | hold (RCH) | side / landscape | true | 5 | shared | 2 |
| 32 | Bow Pose | rep (timed hold inside) | side / landscape | true | 4 | no | 1 |
| 33 | Butterfly Stretch | hold (RCH) | front / portrait + landscape | false | 4 | yes | 0 |
| 34 | Seated Forward Fold | hold (RCH) | side / landscape | true | 4 | yes | 0 |
| 35 | Downward Dog | hold (own) | side / portrait (default) | false | 3 | shared | 0 |
| 36 | Low Lunge | hold (own) | side / portrait (default) | false | 2 | shared | 1 |
| 37 | Raised Arms | hold (own) | side / portrait (default) | false | 4 | shared | 4 |
| 38 | Prayer Pose | hold (own) | side / portrait (default) | false | 1 | no | 1 |
| 39 | Ashtanga Namaskara | rep (500 ms recognition) | side / portrait (default) | false | 2 | shared | 1 |
| 40 | Surya Namaskar | sequence (12 poses per round) | side / landscape | false | 0 (7 safety codes) | shared | 2 |

Totals: 30 of 40 `isFormChecked: true`; 17 with no dedicated test file ("no" or "shared"); 29
with at least one dead or always-perfect item. The column is a count, not a severity: several of the most
consequential problems (Downward Dog never restarting a hold, Ashtanga counting repeated reps from
one hold, Low Lunge's knee fault firing on every set's first hold) are not "dead" items and score 0
or 1 here.

## Shared conventions used below

- **Confident landmark** means `presence >= 0.7` and `visibility >= 0.3`
  (`lib/exercise/exercise_base.dart:249-302`).
- **Activation**: every exercise must hold its start position for 3 s before `checkingPose` runs
  (`HOLD_STILL_REQUIRED_DURATION`, `exercise_base.dart:371`).
- **Debounce N** means `Debouncer(requiredFrames: N)`: the condition must be true on N consecutive
  frames, and a single false frame resets the count (`lib/utils/debouncer.dart:12-23`).
  "No debounce" means a single frame is enough.
- **Side view** means `cameraFacing` is `left` or `right`. `left` means the body's left landmarks
  have the smaller `z` (closer to the camera) on the majority of six joint pairs
  (`exercise_base.dart:678-705`, `:707-736`).
- **Orientation**: all ten batch 1 exercises, and Plank, Bear Plank, Plank Up-Down, Push-Up and
  Glute Bridge, declare landscape only. Squat, Wall Push-Up, Lunge and Walking Lunge are portrait
  only; Side Plank allows portrait and both landscapes. The base default is portrait
  (`exercise_base.dart:286-287`). Batch 3: Curl-Up, Tricep Dip and Step-Back Burpee are landscape
  only; Jumping Jack, Jump Squat, Cossack Squat and Standing Knee-to-Elbow declare portrait only;
  Warrior I and Cobra declare nothing and so get the portrait default; Russian Twist allows portrait
  and both landscapes. Batch 4: Sphinx, Bow Pose, Seated Forward Fold and Surya Namaskar are
  landscape only; Butterfly allows portrait and both landscapes; Downward Dog, Low Lunge, Raised
  Arms, Prayer Pose and Ashtanga Namaskara declare nothing and get the portrait default.
- **Camera view**: batch 1 and 2 are all side view. Batch 3 adds four **front-view** exercises
  (Jumping Jack, Cossack Squat, Russian Twist, Standing Knee-to-Elbow) that use both body sides at
  once. Side-view exercises that do not use `SideTrackedExerciseMixin` call `getSideLandmark`, which
  returns the right landmark when facing right and the left one otherwise, including when angled
  (`exercise_base.dart:817-826`). Batch 4 adds one front-view exercise (Butterfly Stretch); the
  other nine are side view. Sphinx picks its side by landmark likelihood instead of `cameraFacing`.
- **`StickyDebouncer`** (`lib/utils/debouncer.dart:38-63`) keeps a current state, returns it on
  every call, and flips only after `requiredFrames` consecutive contrary frames. It **starts in
  `currentState = true` unless the caller passes false** (`:43`), and `reset()` only zeroes the
  frame counter, not the state (`:61-63`). "Sticky N" below means this class. See finding 11.
- **`calculateAngle` vs `calculateAngleNormalized`** (`pose_math_helpers.dart:187-229`): the
  normalised version folds the result into 0-180; `calculateAngle` returns |atan2 difference| in
  0-360. "Unnormalised" below means the latter. See finding 12.
- **Torso** is the shoulder-to-hip pixel distance. Normalised values ("0.15 torso") are divided by it.
- **Horizontal angle** is `calculateAbsoluteHorizontalAngle`: 0 deg = flat, 90 deg = vertical, sign
  discarded (`lib/utils/pose_math_helpers.dart:299-306`). **Trunk lean** is
  `convertClockAngleToTrunkLean`, positive forward, and 0 for any facing other than left/right
  (`pose_math_helpers.dart:331-365`).
- Image Y grows downward, so "lifted" means Y decreased.
- **Counts the rep?** column: "yes" means the rep still counts and is only marked bad form;
  "rejected" means the attempt is thrown away. Hold exercises use "Counts the hold?".
- **Shared hold-time accumulator** (`lib/utils/hold_seconds_accumulator.dart`), used for
  `good_seconds` and `*_seconds` by Plank and every `RepCountedHoldExercise`. A frame gap is added
  only if it is between 10 and 250 ms (`:25-26`, `:61-62`); the first frame after `resetTick()` only
  arms the clock (`:57-59`). The gap is added to every key that is faulting on that frame (`:68-75`)
  and to `good_seconds` only if nothing is faulting (`:77-79`). No caller in batches 1-2 passes
  `goodBlockingKeys`; in batch 3 Warrior I passes `trunk_lean_seconds` and `arm_seconds`, so its
  other fault keys do not reduce `good_seconds` (`:66-79`). Batch 3's Warrior I and Cobra also use
  this accumulator, with their own hold state machines. Batch 4: Sphinx, Butterfly and Seated
  Forward Fold use it through `RepCountedHoldExercise`; Bow Pose and Downward Dog use it directly,
  and Downward Dog passes `goodBlockingKeys = spine_round_seconds` (`downward_dog.dart:404-412`).
  The four "entry / holding / exit" exercises of batch 4 (Low Lunge, Raised Arms, Prayer Pose,
  Ashtanga) and Surya Namaskar do not use it. By reading, on a device delivering pose frames slower
  than 4 per second no good or fault seconds accumulate at all.
- **`RepCountedHoldExercise` frame order** (re-read in batch 4,
  `hold/rep_counted_hold_exercise.dart:170-198`): sample, state machine, then metrics and the hold
  timer on the post-transition phase. The timer (`hold/timer_metric.dart:23-56`) arms on entering
  `holding` and adds a frame gap only on later `holding` frames, so a hold that flips between
  `holding` and `dropping` every frame earns no time.

## Cross-cutting findings

Batch 1 recorded findings 1-5; each now states whether it holds for batch 2. Findings 6-8 are new
in batch 2. Every finding now also states whether it holds for batch 3; findings 9-10 are new in
batch 3, and the table after them checks the four wrong-feedback patterns per batch 3 exercise.
Batch 4 adds a "Batch 4" paragraph to findings 1-10, new findings 11-14, and a batch 4 pattern
table; each batch 4 section also ends with its own "Cross-cutting checks" paragraph.

1. **Exercises overwrite `scaleFactor`.** All ten batch 1 exercises assign `scaleFactor` directly
   every frame inside `checkingPose` / `samplePose` (for example `bird_dog.dart:371`,
   `sit_up.dart:234`, `high_plank.dart:363`). `scaleFactor` is a plain field
   (`exercise_base.dart:309`), so by reading, these writes replace the base class's smoothed value
   (`exercise_base.dart:758-760`) with the raw per-frame distance.
   **Batch 2: holds for five of ten.** Raw overwrite every frame: Bear Plank
   (`bear_plank.dart:169`), Plank Up-Down (`plank_up_down.dart:259`), Side Plank
   (`side_plank_dip.dart:169`, set to 1.0 on degenerate geometry), Squat (`squat.dart:386`), Push-Up
   (`push_up.dart:315`). Does not hold: Glute Bridge and Lunge read the base class's smoothed value
   (`glute_bridge.dart:311`, `:457`, `:470`; `lunge.dart:378`), Wall Push-Up only uses it as a
   fallback (`wall_push_up.dart:819`), Plank and Walking Lunge never use it (`plank.dart:487`
   computes a local scale; Walking Lunge normalizes by thigh length).
   **Batch 3: holds for four of ten.** Raw overwrite every frame: Jumping Jack with the shoulder
   width (`jumping_jack.dart:282-283`), Jump Squat (`jump_squat.dart:258`), Cossack Squat with the
   shoulder X-distance (`cossack_squat.dart:242`), Russian Twist with the shoulder width
   (`russian_twist.dart:249`). In the three front-view ones the overwrite also changes what the
   field means (shoulder width instead of torso length). Does not hold: Curl-Up
   (`curl_up.dart:417`), Step-Back Burpee (`step_back_burpee.dart:220-224`), Warrior I
   (`warrior_one.dart:297`, `:384`) and Cobra (`cobra.dart:299-304`) read the base value; Standing
   Knee-to-Elbow and Tricep Dip never use it.
   **Batch 4: holds for three of ten**, all `RepCountedHoldExercise` subclasses: Sphinx
   (`sphinx_stretch.dart:254`), Seated Forward Fold (`seated_forward_fold.dart:196`) with the raw
   shoulder-hip distance, and Butterfly with max(torso height, shoulder width)
   (`butterfly_stretch.dart:206`). Does not hold: Downward Dog passes the base value only as a
   fallback for its own start-position scale (`downward_dog.dart:254`, `:370`); Bow Pose, Low Lunge,
   Raised Arms, Prayer Pose, Ashtanga and Surya compute a local torso length and never touch the
   field.
2. **Metrics see different states on a transition frame.** Batch 1: Bird Dog, Sit-Up, Mountain
   Climber, Superman, Plank Shoulder Tap and Leg Raises build the metric context before the state
   machine runs (metrics see the pre-transition state); High Plank, Reverse Crunch, V-Up and Dead Bug
   hand metrics the post-transition state.
   **Batch 2: holds.** Pre-transition: Plank Up-Down (`plank_up_down.dart:301-312` vs `:324`), Squat
   (`squat.dart:399-411` vs `:435`), Push-Up (`push_up.dart:319-327` vs `:372`), Wall Push-Up
   (`wall_push_up.dart:802-823` vs `:840`), Glute Bridge (`glute_bridge.dart:463-476` vs `:494`),
   Lunge (`lunge.dart:369-382` vs `:494`). Post-transition: Walking Lunge (`walking_lunge.dart:397-415`),
   Bear Plank and Side Plank (shared hold machine, `hold/rep_counted_hold_exercise.dart:180-185`).
   Plank builds its context first (`plank.dart:223-230` vs `:251`) but its metrics never read the
   state and only run when the post-transition state is `holding` (`:265`).
   **Batch 3: holds.** Pre-transition: Curl-Up (`curl_up.dart:412-426` vs `:485`), Jumping Jack
   (`jumping_jack.dart:309-321` vs `:401`), Step-Back Burpee (`step_back_burpee.dart:234-244` vs
   `:254`), Warrior I (`warrior_one.dart:396-410` vs `:431`). Post-transition: Jump Squat
   (`jump_squat.dart:278` vs `:281-289`), Cossack Squat (`cossack_squat.dart:278-297` vs `:348-361`),
   Russian Twist (`russian_twist.dart:262` vs `:264-294`), Standing Knee-to-Elbow
   (`standing_knee_to_elbow.dart:337` vs `:348-363`), Cobra (`cobra.dart:309` vs `:312-332`). Tricep
   Dip runs no metrics. Several batch 3 exercises evaluate faults inside `onStateTransition`, which
   runs in the state machine before that frame's `update` (Jump Squat, Cossack, Step-Back Burpee,
   Cobra).
   **Batch 4: holds.** Pre-transition: Bow Pose (`bow_pose.dart:222-233` vs `:235`). Mixed, like
   Plank: Ashtanga builds its context first (`ashtanga_namaskara.dart:256-275` vs `:277`) but runs
   metrics only when the post-transition state is `recognized` or `holding` (`:283-289`).
   Post-transition: Sphinx, Butterfly and Seated Forward Fold (shared hold machine), Low Lunge
   (`low_lunge.dart:241-268`), Raised Arms (`raised_arms.dart:223-250`), Prayer Pose
   (`prayer_pose.dart:227-250`); Downward Dog decides an abort before running metrics
   (`downward_dog.dart:379-396`). Surya Namaskar runs no metrics. This ordering is what makes two
   batch 4 faults unreachable: the state machine leaves the state on the same frame the metric
   would log (Raised Arms `LumbarOverextension` and `ArmsLow`, Bow Pose chest `LiftForm`).
3. **Some `*_fails_count` keys are structurally zero.** Batch 1: `faultsCount` is only incremented
   by `resetAndCountFault()`, and several exercises call plain `reset()` on rejected attempts, so
   faults that reject the attempt never reach their count key.
   **Batch 2: the rejection pattern does not recur** (rejections are counted in their own keys:
   `push_up_guard_rejects_count`, `rejected_shallow_attempts_count`; Wall Push-Up rejections are not
   counted at all). **But keys are still structurally zero for a second reason, already seen in
   batch 1's Sit-Up `rom`: the fault threshold equals the gate a rep must pass to count**, or the fault
   is never emitted. By reading: Push-Up `depth_fails_count` (`depth_metric.dart:94-113` vs
   `push_up.dart:546`), Plank Up-Down `arm_extension_fails_count` (`arm_extension_metric.dart:18-38`),
   Lunge "Not deep enough" (`lunge_depth_metric.dart:85-87`), Walking Lunge
   `front_knee_fails_count` (never faulted, `front_knee_control_metric.dart:12-23`), Side Plank's three
   `*_seconds` keys (1-frame exit debounce). Wall Push-Up's depth and lockout checks are empty
   functions (`wall_push_up.dart:994-1018`). Each of these reports a perfect score in the summary.
   **Batch 3: holds, in three forms.** (a) Not wired: Tricep Dip never calls its metrics, so all
   four keys are 0 and every rep is `correctForm = true` (`tricep_dip.dart:60-64`, `:295-297`).
   (b) Never faults: Standing Knee-to-Elbow `cross_rom_fails_count`
   (`metrics/cross_rom_metric.dart:8-31`); Cobra `CrashDescent` / `FastDescent` (no key, but they
   would fail the hold; `cobra.dart:476-499`); Jumping Jack's rep-end arm checks and "Chân quá hẹp"
   (gated out by the open state). (c) The batch 1 rejection pattern returns in Russian Twist: a half
   twist with a `knee`, `rom`, `too_upright` or `too_low` fault is rejected and its metrics
   `reset()` without counting, so `knee_wobble_fails_count` and `rom_fails_count` can never rise
   (`russian_twist.dart:403-408`, `:458-475`). Nearly zero: Cossack `depth_shallow` (only for a
   bottom entered at 115-120 deg). The opposite also happens: Curl-Up, Jump Squat, Step-Back Burpee,
   Jumping Jack (`tempo_fast`) and Cossack (`torso`) count records with `affectsForm: false` in
   their `*_fails_count`, so a warning lowers the report score.
   **Batch 4: holds, mostly through a third mechanism: a state-machine exit that is checked first
   and is at least as easy to trigger as the fault.** By reading: Raised Arms
   `lumbar_backbend_fails_count` (exit at back lean > 25 for 20 frames precedes the > 28 fault,
   `raised_arms.dart:311-313`, `:326`; `metrics/lumbar_backbend_metric.dart:46-52`) and `ArmsLow`
   (break at > 50 for 8 frames precedes > 65 for 10); Bow Pose chest `LiftForm` (hold exit at < 0.05
   for 3 frames precedes < 0.04 for 6, `bow_pose.dart:325-328`, `metrics/lift_form_metric.dart:55`).
   Hard-coded zero: Sphinx `hip_seconds` (`sphinx_stretch.dart:394`). Never different: Surya
   `missed_poses` and `blank_poses` (`surya_namaskar.dart:666-681`, `:713-721`). Probably unreachable
   thresholds: Sphinx `NeckShrug` (0.10 torso), Low Lunge `KneeTravel` (1.05 torso, longer than a
   shin), Prayer `PostureStack` (0.75 torso), Ashtanga `hip` (15 sticky frames inside a 500 ms
   window). The batch 1 rejection pattern returns in the four entry/holding/exit exercises (Low
   Lunge, Raised Arms, Prayer, Ashtanga): a rejected hold calls `reset()` without counting. The
   opposite also happens: Low Lunge `knee_travel_fails_count` and Prayer `posture_stack_fails_count`
   are inflated to at least 1 by finding 11.
4. **`*Config.MAX_REP` is not the real target.** Batch 1: every one is unreferenced.
   **Batch 2: partly.** `PlankConfig.MAX_REP = 12` in Plank Up-Down is unreferenced
   (`metrics/plank_up_down_metric_base.dart:12`). `SquatConfig.MAX_REP` (15), `LungeConfig.MAX_REP` (15)
   and `WalkingLungeConfig.MAX_REP` (20) are constructor defaults (`squat.dart:95`, `lunge.dart:65`,
   `walking_lunge.dart:69`), but every definition passes the catalog value through `_withReps`, which
   asserts it is non-null (`exercise_definition.dart:50-57`), so the defaults only apply to direct
   constructor calls (tests). The other six have no `MAX_REP`. Plank's hold length (15 s) is a
   constant the catalog cannot change (catalog seconds is null, `exercise_catalog.json:202`).
   **Batch 3: partly.** Unreferenced: `TricepDipConfig.MAX_REP = 15` (`tricep_dip.dart:21`),
   `BurpeeConfig.MAX_REP = 15` (`step_back_burpee.dart:19`). Constructor defaults only reached by
   direct calls: `RussianTwistConfig.MAX_REP = 20` (`russian_twist.dart:27`, `:77`),
   `StandingKneeToElbowConfig.MAX_REP = 30` "15 per side" (`standing_knee_to_elbow.dart:23`,
   `:49`). The other six have none. Hold lengths are constants the catalog cannot change: Warrior I
   20 s (`warrior_one.dart:39`; catalog seconds null, `exercise_catalog.json:438`; the definition
   copy says 30 s) and Cobra 15 s (`cobra.dart:19`; catalog seconds null, `:64`).
   **Batch 4: partly.** Unreferenced: `LowLungeConfig.MAX_REP = 2` (`low_lunge.dart:14`),
   `RaisedArmsConfig.MAX_REP = 1` (`raised_arms.dart:15`), `PrayerPoseConfig.MAX_REP = 1`
   (`prayer_pose.dart:13`), `AshtangaConfig.MAX_REP = 1` (`ashtanga_namaskara.dart:23`). Constructor
   default only: `BowPoseConfig.MAX_REP = 10` (`bow_pose.dart:15`, `:33`). Hold lengths the catalog
   cannot change (catalog seconds null for all): Bow Pose 15 s (a literal,
   `metrics/hold_duration_metric.dart:46`), Downward Dog 20 s (`downward_dog.dart:62`; file header
   says 30), Low Lunge 20 s, Raised Arms 12 s, Prayer Pose 8 s, Ashtanga's 500 ms recognition window,
   Surya's 5 s per pose. Sphinx, Butterfly and Seated Forward Fold do take the catalog's 30 s. Three
   definitions describe a different volume from the catalog: Sphinx and Seated Forward Fold "3 × 15
   giây" vs 1 x 30 s, Bow Pose "10 × 15 giây" vs 3 holds (`exercise_definition.dart:1113`, `:1044`,
   `:882`).
5. **No accuracy evidence.** Batch 1: no measurement, fixture recording, or calibration note;
   comments often disagree with values. **Batch 2: holds**, and comment/value disagreements are the
   norm (listed per exercise; Wall Push-Up disagrees in almost every metric). Several thresholds are
   self-described as unvalidated: "adjust after empirical testing" / "verify sign mapping"
   (`plank/metrics/trunk_alignment_metric.dart:14`, `plank_metric_base.dart:21`), "ESTIMATE — PT
   review before ship" (`wall_push_up/metrics/body_line.dart:21`), "Not canonical — tune on device"
   (`glute_bridge_neck_head.dart:37-41`).
   **Batch 3: holds.** Comment/value disagreements appear in all ten exercises. Self-described as unvalidated: "Week 1-4 launch defaults; tighten per spec
   threshold table" and "ESTIMATE — tune on device" (`warrior_1/warrior_one.dart:35`, `:42`),
   "Beginner thresholds" (Cobra metrics, e.g. `Cobra/metrics/cobra_elbow_metric.dart:14`),
   "tạm dùng mức chênh lệch tương đối" (`Jump_Squat/jump_squat.dart:27-28`). Russian Twist's test
   fixture reaches its trunk-angle gate with a sideways body offset that a real front view would not
   produce (see that section).
   **Batch 4: holds.** Self-described as unvalidated: all three Downward Dog metrics, "THRESHOLDS
   (ESTIMATE — pending PT review)" (`downward_dog/metrics/spine_round_metric.dart:17`,
   `shoulder_shrug_metric.dart:22`, `leg_straightness_metric.dart:17`). The only calibration note in
   the batch is a single "reference capture" for Seated Forward Fold (hip 35, knee 159, spine 151,
   ankle 132 deg; `seated_forward_fold/metrics/seated_forward_metric_base.dart:8-9`). Comment/value
   disagreements in Sphinx (neck), Butterfly (asymmetry, tilt, debounce), Downward Dog (all three
   metrics and the start gate), among others; listed per section.
6. **Opposite head-direction conventions for the same `cameraFacing` (new).** For a prone or
   standing body, Plank (`plank.dart:25-26`), Lunge (`lunge.dart:101-104`) and Walking Lunge
   (`walking_lunge.dart:310-318`) treat facing left as "head / front toward smaller X"; Push-Up treats
   it as toward larger X (`push_up.dart:36-37`). The shared helper `convertClockAngleToTrunkLean`
   also uses the smaller-X convention (facing left: shoulder at clock 270-360 = forward,
   `pose_math_helpers.dart:331-346`), so every exercise that takes a signed trunk lean from it
   inherits Plank's side of the conflict. The unit tests encode both
   (`plank_anti_cheat_test.dart:29-30`, `:107`; `push_up_anti_cheat_test.dart:35-36`, `:129`). By
   geometry, with `left` meaning the left side is nearer the camera, an unmirrored image puts the
   head toward smaller X, which would make Push-Up the inverted one; a mirrored image would invert
   the other three. Mirroring was not traced. Whichever is wrong reads a level body as ~180 deg off
   (Plank: never starts; Push-Up: a `sag` fault every rep) or swaps front and back legs (Lunge,
   Walking Lunge). Separately, every signed trunk deviation (Plank, Push-Up) flips sign between the
   two facings because the image is mirrored but the sign is not.
   FIXED 2026-11-17 (Plank and Push-Up only): traced; with the left side nearer (smaller z) the
   head/front is toward smaller X in the image MediaPipe receives, for both cameras, portrait and
   landscape, mirrored or not, so Plank's side (and the shared helper, Lunge, Walking Lunge, Warrior
   I, Cobra) is right and Push-Up was inverted. Push-Up changed; Plank and Push-Up negate the
   deviation for facing right. Not changed: the batch 4 users of Push-Up's old side (Low Lunge,
   Prayer Pose, Surya lunge steps), which are hidden. See docs/scratch/kept-exercises-report-batch-A.md.
   **Batch 3: two more exercises take Plank's side; none takes Push-Up's.** Warrior I picks the
   front leg as the smaller-X ankle when facing left (`warrior_one.dart:136-139`) and reads a signed
   trunk lean from the shared helper (`:356-359`); its test encodes this (facing left, front ankle
   at x=125, back at x=330). Cobra targets clock 270 for facing left and 90 for facing right
   (`cobra.dart:26-27`). If the convention is inverted, Warrior I swaps front and back legs and the
   hold never starts, and Cobra's start and hold gates read a level trunk as ~180 deg off. The
   second half of the finding also recurs: Cobra's neck angle is a clock difference with no
   per-facing sign, so neck extension reads positive facing left and negative facing right
   (`metrics/cobra_cervical_metric.dart:50-59`). Not sensitive to facing: Curl-Up (`abs` dx/dy),
   Jump Squat (`abs` of the trunk lean, `jump_squat.dart:256-257`), Step-Back Burpee (unsigned
   angles), Tricep Dip (Y only). The four front-view exercises have no facing constants, but
   Cossack Squat's `knee_valgus` assigns "inward" by anatomical leg and X sign
   (`metrics/knee_valgus_metric.dart:15-22`), so it depends on image mirroring in the same way;
   Standing Knee-to-Elbow's valgus uses distances to the hip midline and does not.
   **Batch 4: both sides recur, now inside single exercises.** Push-Up's side (facing left = front
   toward larger X): Low Lunge's front leg (`low_lunge.dart:548-550`), Prayer Pose's forward sign
   (`prayer_pose.dart:500-502`, `metrics/posture_stack_metric.dart:70-72`), and Surya's low-lunge
   steps (`surya_namaskar/pose_recognizers.dart:540-542`, `safety_overrides.dart:325-327`). Plank's
   side: Raised Arms' back-lean sign (`raised_arms.dart:479-482`), and Surya's raised-arms back lean,
   forward fold (shared helper) and Cobra steps (`pose_recognizers.dart:567-573`, `:343-357`).
   **Surya Namaskar uses both conventions in one continuous sequence**, during which the user faces
   one way; on any device either its lunge steps or its Cobra step is inverted, which by reading
   stalls the flow at that step indefinitely. Low Lunge and Raised Arms, written in the same style,
   also disagree with each other. Low Lunge's chest-lift target (0 deg for facing right, 180
   otherwise, `low_lunge.dart:521-525`) fits neither: "upright" is clock 0 in both facings. Not
   sensitive to facing: Sphinx (side by likelihood, unsigned angles), Bow Pose, Butterfly (front),
   Seated Forward Fold, Downward Dog, Ashtanga (but see finding 12 for its neck angle).
7. **Calibrated clean-rep overrides (new).** Squat and Walking Lunge compare one frame against
   constants with 3-4 significant digits (`squat.dart:33-41`, `walking_lunge.dart:30-37`) and, on a
   match, delete every fault of the rep (`squat.dart:485-492`, `walking_lunge.dart:660-665`). Lunge
   has the same machinery but discards the result (`lunge.dart:425-428`). Nothing in the repo says
   where the constants come from. A labeled-video evaluation should log whether the override fired.
   FIXED 2026-11-17 (Squat only): override removed. Walking Lunge (hidden) still erases faults.
   **Batch 3: no active override.** Cossack Squat has the same machinery (left knee 172.1, right
   knee 179.6, torso clock 329.3, valgus 0.160) and, like Lunge, discards the result
   (`cossack_squat.dart:28-35`, `:455-459`). No other batch 3 exercise erases the faults of a counted
   rep. Faults are discarded only with attempts that are not counted (Jump Squat's < 350 ms reps,
   `jump_squat.dart:344-350`; Russian Twist's rejected halves; Standing Knee-to-Elbow's cancelled
   attempts). The reverse leak exists: Standing Knee-to-Elbow (cycle < 500 ms,
   `standing_knee_to_elbow.dart:471-478`) and Cobra (abandoned hold, `cobra.dart:429-433`) keep the
   faults of a discarded attempt and attach them to the next counted rep or hold.
   **Batch 4: no override.** No exercise erases the faults of a counted rep or hold. Faults are
   discarded with attempts that are not counted: rejected holds in Low Lunge, Raised Arms, Prayer
   Pose and Ashtanga (`reset()` without counting), no-pose frames in the same four, Downward Dog's
   aborted hold (`downward_dog.dart:664-666`), and the base pause/re-hold in the three
   `RepCountedHoldExercise` subclasses. Leak forward: Bow Pose, where a `Connection` fault from an
   abandoned `ascending` stays in the metric until the next completed rep; Butterfly, whose metrics
   also run (and log) in `dropping`, which belongs to the same hold.
8. **Languages and units (new).** Squat and Lunge store English fault messages ("Leaned too
   forward", "Too deep! Come up a bit"); only their voice lines are Vietnamese. Glute Bridge's state
   machine and Squat's `sync` metric use raw pixels per frame, so their behaviour depends on camera
   distance and resolution. Debounces count frames, not milliseconds, so they also depend on frame
   rate.
   FIXED 2026-11-17 (Squat strings only): Squat's messages and live text are Vietnamese. Lunge is
   batch B; pixel units and frame-count debounces are unchanged.
   **Batch 3: holds.** English logged messages: Warrior I (all, e.g. "Trunk collapsing forward
   (>30°)", `metrics/trunk_lean_metric.dart:94`), Cobra (all, e.g. "Elbow locked out",
   `metrics/cobra_elbow_metric.dart:55`); English result text "Good Rep!" / "Fix Form" in Cossack
   Squat (`cossack_squat.dart:462`), Standing Knee-to-Elbow (`:524`) and Tricep Dip (`:298`). Pixel
   gates: Jump Squat "moving up" 2 px/frame (`jump_squat.dart:383`), Cossack hip direction 3 px
   (`cossack_squat.dart:281`, `:397`), Warrior I stillness 2.5 px/frame (`warrior_one.dart:43`,
   `:685-687`), Russian Twist minimum shoulder width 40 px (`russian_twist.dart:50`). Cobra's descent
   metric is the only one in the file that uses timestamps for speed
   (`metrics/cobra_descent_metric.dart:67-72`).
   **Batch 4: holds.** English logged messages: Downward Dog (all three, e.g. "Spine rounding —
   lumbar flexion detected", `metrics/spine_round_metric.dart:113`), Low Lunge, Raised Arms, Prayer
   Pose and Ashtanga (all, e.g. "Neck cranked back"). Vietnamese: Sphinx, Bow Pose, Butterfly,
   Seated Forward Fold, Surya. Pixel units: Downward Dog's start stillness, 6 px per frame
   (`downward_dog.dart:65`, `:304-311`); Butterfly's `max_knee_separation`, pushed and shown in raw
   pixels (`butterfly_stretch.dart:349`); Bow Pose's 10 px torso floor. Frame-count windows:
   Butterfly's stillness lookback of 10 frames. Unlike batches 1-3, several batch 4 exercises do use
   timestamps for speed: hip or shoulder velocity in torso lengths per second (Seated Forward Fold,
   Low Lunge, Raised Arms, Prayer, Ashtanga).
9. **Wall-clock holds that keep running after the pose is lost (new in batch 3).** Warrior I and
   Cobra time a hold as `frameTimestampMs - holdStart` and end it only when 15 or 20 s have passed
   (`warrior_one.dart:606-609`, `:693-696`; `cobra.dart:427-428`, `:502-505`). Warrior I never
   leaves `hold` for a bad pose; Cobra leaves only if the trunk returns to within 35 deg of
   horizontal. Standing up mid-hold therefore still credits the hold. Only a frame with no skeleton
   resets Warrior I (`warrior_one.dart:665-676`). By contrast Plank and the `RepCountedHoldExercise`
   family pause the clock. Their `good_seconds` come from the frame-gap accumulator, so they can be
   lower than the credited time, but `total_seconds` is set to the target, not the time held
   (`warrior_one.dart:215-216`, `cobra.dart:203`).
   **Batch 4: does not hold; the opposite problem appears.** Every batch 4 wall-clock hold ends the
   hold when the pose is lost: Downward Dog after 6 frames out of shape, Low Lunge, Raised Arms and
   Prayer Pose after 8 frames (hold not counted), Bow Pose on leaving `hold` (the rep still counts
   with a `HoldDuration` fault). The three `RepCountedHoldExercise` subclasses and Surya pause the
   clock. But **Downward Dog cannot restart after an abort**: `hold` is only entered from
   `onExerciseActivated`, which a pause/resume re-hold does not call (`downward_dog.dart:186`,
   `:548-552`; `exercise_base.dart:864-866`), so one no-pose frame ends counting for the session.
   `total_seconds` is again the target, not the time held (Bow Pose `bow_pose.dart:146`, Downward
   Dog `downward_dog.dart:169`, and the three RCH exercises).
10. **Setup copy that contradicts `checkSafety` (new in batch 3; one case in batch 2).** Five
   definitions offer "Đặt camera đối diện hoặc nghiêng góc 45 độ." for exercises whose
   `checkSafety` rejects one of those views: Jump Squat, Step-Back Burpee and Tricep Dip (front
   rejected), Cossack Squat and Standing Knee-to-Elbow (angled rejected)
   (`exercise_definition.dart:1001`, `:1180`, `:1205`, `:977`, `:1155`). Walking Lunge (batch 2) has
   the same copy and rejects both. Three of them (Jump Squat, Cossack, Step-Back Burpee) still show
   the placeholder subtitle "Chưa có mô tả". A user following the copy can stay stuck on a
   `turnSide` / `faceCamera` prompt; a labelled-video protocol should state the camera position
   the code expects.
   **Batch 4: does not hold for the camera.** Butterfly's copy asks for a front camera and its code
   requires front; the other nine ask for a side view and require one. Six batch 4 definitions are
   placeholders, "Bản xem trước của bài tập ..." with generic setup tips and `targetMuscles: ['Toàn
   thân']`: Downward Dog, Ashtanga, Low Lunge, Prayer Pose, Raised Arms, Surya
   (`exercise_definition.dart:1294`, `:1317`, `:1340`, `:1363`, `:1386`, `:1247`). The volume copy of
   Sphinx, Seated Forward Fold and Bow Pose disagrees with the catalog (finding 4).
11. **`StickyDebouncer` starts true (new in batch 4).** Its default `currentState` is true
   (`lib/utils/debouncer.dart:43`), so a fault debouncer built without `currentState: false` reports
   the fault from the very first frame until `requiredFrames` clean frames have passed, and
   `reset()` does not restore the state (`:61-63`), so this happens once per exercise instance.
   Batch 4, by reading: Low Lunge `KneeTravel` (all three debouncers,
   `low_lunge/metrics/knee_travel_metric.dart:20-23`) is logged with `affectsForm: true` on the first
   frame of each set's first hold; Prayer Pose `PostureStack`
   (`prayer_pose/metrics/posture_stack_metric.dart:25-26`) is logged on the first frame of the first
   hold. The batch 4 authors set `currentState: false` everywhere else (Raised Arms, Ashtanga, Low
   Lunge cervical, Prayer shoulders), and Prayer resets its own exit debouncer to false explicitly
   (`prayer_pose.dart:449-450`), so the two omissions look accidental. **Batches 1-3, by grep only:**
   the same default is used by the batch 3 Cobra fault debouncers (`Cobra/metrics/cobra_elbow_metric.dart:22-23`,
   `cobra_cervical_metric.dart:25-26`, `cobra_elevation_metric.dart:22-23`,
   `cobra_hand_placement_metric.dart:24-26`), which the Cobra section lists as "sticky N" without
   noting the start state; how those metrics consume the result was not re-read, so whether Cobra
   logs `ElbowLockout`, `HipLift` or `HandsTooFar` on its first frames is unverified. The other
   default-true uses are direction or side smoothing (Squat, Push-Up, Curl-Up, the base
   left/right debouncer), where a true start is a design choice, not a fault.
12. **Unnormalised joint angles (new in batch 4; one case in batch 2).** `calculateAngle` returns
   0-360 (`pose_math_helpers.dart:212-229`). For a three-point angle near a straight line, a bend
   toward one image side reads 180 - x and toward the other 180 + x; near the +/-180 branch cut the
   value jumps. A "< threshold" test therefore only fires for one direction of bend, i.e. for one
   `cameraFacing`. Batch 2 recorded this for Lunge's lumbar angle. Batch 4, by reading: Raised Arms
   neck and elbow (`raised_arms.dart:493-509`), Ashtanga neck (`ashtanga_namaskara.dart:246-252`),
   Surya's low-lunge front knee and Cobra elbow (`pose_recognizers.dart:204-208`,
   `safety_overrides.dart:178-182`; the latter can block Surya's step 7 in one facing). By grep it is
   also used in Plank (head/neck, knee), Glute Bridge hip extension, Curl-Up neck pulling and Warrior
   I (back knee, back straight, cervical); those sections were not re-checked for this effect.
13. **A copy-paste hold skeleton (new in batch 4).** Low Lunge, Raised Arms, Prayer Pose and
   Ashtanga share one structure (entry / holding (or recognized) / exit), and share its defects:
   activation jumps straight into the hold without calling `super.onExerciseActivated()`; the
   calibration baselines are collected only during the base 3 s activation, cleared on the first
   return to `entry` and never refilled (so later holds run without them), and in all four the
   baselines are passed to the metrics and never read; a no-pose frame restarts the hold; a rejected
   hold resets its metrics without counting and no key counts rejections; every logged message is
   English and the local `FaultRecord` class has no voice field; none declares an orientation, so all
   are portrait only. Holds after the first need only 4-10 still frames, not the 3 s hold-still.
14. **`isFormChecked` does not switch form checking off (new in batch 4).** By grep, the catalog flag
   is read only by the recommendation and launch services (`lib/services/workout_launch_service.dart:250`,
   `lib/services/recommendation/recommendation_engine.dart:346`,
   `lib/services/recommendation/program_plan_mapper.dart:155`, `:229`); no exercise class reads it.
   So an exercise with `isFormChecked: false` still logs whatever faults its code has. Flag and code
   disagree for Reverse Crunch (`curl`, `arms` have `affectsForm: true`), Russian Twist and Standing
   Knee-to-Elbow (batch 3: faults that reject or mark bad form), and in batch 4 for Butterfly,
   Downward Dog, Low Lunge and Ashtanga (each has an `affectsForm: true` fault) and nominally Raised
   Arms (its `affectsForm: true` fault is unreachable). They agree for Prayer Pose and Surya
   Namaskar (no form-affecting fault). In the other direction, Tricep Dip is `true` with no wired
   checks (batch 3).

**Batch 4 pattern check.** Same four patterns, per batch 4 exercise (details and `file:line` in each
section's "Cross-cutting checks").

| Exercise | Fault never fires / perfect card | Wipes a counted hold's or rep's faults | Single-frame fault or transition | Facing convention |
|---|---|---|---|---|
| Sphinx Pose | `hip_seconds` report line; `NeckShrug` probably | no | hold entry and exit (1-frame debounces); spine 172-175 flaps | insensitive (side by likelihood) |
| Bow Pose | chest `LiftForm` | no | none (3-frame state debounce) | camera side; insensitive |
| Butterfly Stretch | none | no | none | front view, none |
| Seated Forward Fold | none | no | exit (`releasedEarly`) is one frame | camera side; insensitive |
| Downward Dog | none, but no hold can restart after an abort | aborted hold's faults discarded | one no-pose frame aborts the hold | camera side; insensitive |
| Low Lunge | real `KneeTravel` probably | rejected holds discarded | `KneeTravel` logged on first frame (finding 11); no-pose frame | Push-Up's; chest target fits neither |
| Raised Arms | `LumbarOverextension`, `ArmsLow`; neck and elbow one-way | rejected holds discarded | no-pose frame | Plank's |
| Prayer Pose | real `PostureStack` probably | rejected holds discarded | `PostureStack` logged on first frame; no-pose frame | Push-Up's |
| Ashtanga Namaskara | `hip` (frame-rate dependent) | rejected attempts discarded | no-pose frame | insensitive; neck angle facing-dependent |
| Surya Namaskar | `missed_poses`, `blank_poses` | n/a (no faults) | none | both, in one sequence |

**Batch 3 pattern check.** The four patterns that produced wrong feedback in batches 1-2, checked
per exercise (details and `file:line` in each section). "Single frame" lists faults or transitions
with no debounce.

| Exercise | Fault never fires / perfect card | Wipes a counted rep's faults | Single-frame fault or transition | Facing convention |
|---|---|---|---|---|
| Curl-Up | no; but `knee_extension` disabled when the start knee is >= 145 | no | all faults; a near-zero curl counts as clean | insensitive |
| Jumping Jack | rep-end elevation and "Chân quá hẹp" checks | no | rep-end checks, `tempo_fast` | front view, none |
| Jump Squat | no; `takeoff_depth` skipped if launching is skipped | no | transition-time faults (state-debounced) | insensitive (`abs`) |
| Cossack Squat | `depth_shallow` nearly; shallow rejection unreachable | no (override discarded) | every transition and fault; `torso` fires on near-vertical jitter | front view; valgus mirror-dependent |
| Russian Twist | `knee_wobble`, `rom` counts; `arm_swinging` nearly | no (rejected halves discarded) | every transition and fault | front view, none |
| Standing Knee-to-Elbow | `cross_rom_fails_count` | no (faults leak forward instead) | every fault; touch exit, cancel | front view, none |
| Tricep Dip | all four keys, all three cards | n/a (no faults) | ascending to seated abort | insensitive |
| Step-Back Burpee | `squat_hinge` only when steppingBack is skipped | no | four transitions | insensitive |
| Warrior I | no | no | hold exit is time only | Plank's |
| Cobra | `CrashDescent`, `FastDescent`; neck check facing right | no (faults leak forward) | hold exit is time only | Plank's; neck sign per facing |

---

## 1. Bird Dog

Source: `lib/exercise/1.Bird Dog/` (7 files).

**Catalog.** `bird_dog` (definition `bird__dog`): 3 sets, 8 reps, `isFormChecked: true`
(`assets/data/exercise_catalog.json:26`). Definition: `BirdDog(maxRep: reps)` via `_withReps`
(`exercise_definition.dart:525-526`).

**Archetype.** Rep-based with a required 1.5 s hold at the top of each rep. Side view, landscape.

**Start position** (`bird_dog.dart:158-206`, constants `:21-25`). Either body side must have
shoulder, hip, knee, ankle and wrist all confident, and:
- wrist not above shoulder, knee not above hip (face-down check, `:172-173`)
- knee angle (hip-knee-ankle) 30 to 150 deg
- arm angle (hip-shoulder-wrist) 30 to 150 deg
- trunk horizontal angle at most 30 deg

**Stop** (`:209-212`). `repCount >= maxRep`, or 90 s after the first active frame
(`TIMEOUT_MS = 90000`, `:19`, `:229`).

**checkSafety** (`:149-155`). Not side view returns `turnSide`. No landmark check here. Inside
`checkingPose` both shoulders, hips, knees, ankles and wrists (10 landmarks) must be confident
(`:239-254`); if not, the frame is skipped and an in-progress attempt is rejected as `MissingBody`.

**Rep counting** (`:456-487`). The "active" leg is the one with the larger knee angle and the active
arm the one with the larger arm angle (`:291-292`).

| Transition | Condition | Debounce |
|---|---|---|
| neutral to extending | active knee > 110 (`:27`) | 2 |
| extending to hold_extended | active knee > 145 and active arm > 135 (`:28-29`) | 3 |
| extending to neutral (abort) | active knee < 120 (`:31`) | none |
| hold_extended to returning | active knee < 138 (`:30`) | 2 |
| returning to neutral | active knee < 120 | 3 |

The rep is counted when neutral is reached from returning (`:441-446`, `:517`).

**Anti-cheat** (all reject the attempt and increment `invalidAttemptCount`, `:596-611`):
- Leaving the hold before 1.5 s (`:472-479`, `bird_dog_metric_base.dart:11`).
- Same-side arm and leg (`:614-623`). Physical side is resolved with `isPhysicalLeftSide` and frozen
  at the peak of the rep (`:311-333`).
- Same arm or same leg as the previous counted rep (`:625-640`).
- Support knee straighter than 150 deg while not neutral, treated as drifting into a plank (`:337-351`).
- Losing any of the 10 landmarks mid-rep (`:253-268`).

**Faults.**

| Type | Vietnamese message / voice | Metric and threshold | Debounce | Counts the rep? |
|---|---|---|---|---|
| `lumbar` | "Đưa chân quá cao gây võng lưng" / "Hạ chân xuống ngang thân." | ankle above hip and (leg horizontal minus trunk horizontal) > 35 deg; warning band from 18 (`metrics/lumbar_extension_metric.dart:12`, `:25`, `:42-43`) | 5 (`:10`) | yes |
| `alignment` | "Tay/Chân duỗi chưa thẳng với mặt đất" / "Vươn dài tay và chân." | active arm or active leg horizontal angle > 35 deg; warning from 25 (`metrics/alignment_metric.dart:28-29`, `:36`) | none | yes |
| `head` | "Đầu cúi quá thấp" / "Nâng đầu nhẹ, mắt nhìn xuống thảm." | (ear Y minus shoulder Y) > 0.15 torso (`metrics/alignment_metric.dart:63`) | none | yes |
| `trunk` | "Hông bị lệch/sụt" / "Siết bụng, giữ hông cân bằng." | hip Y moved > 0.15 torso from its value at the start of the extension; warning from 0.10 (`metrics/trunk_stability_metric.dart:46`, `:55`) | none | yes |
| `hold` | "Giữ chưa đủ 1.5s (x.xs)" / "Giữ 1 phẩy 5 giây ở điểm cao nhất." | hold < 1.5 s (`bird_dog.dart:475`) | 2 (state) | rejected |
| `opposite_side` | "Không cùng tay cùng chân" / "Giơ tay và chân đối diện." | same physical side (`bird_dog.dart:614`) | none | rejected |
| `alternate` | "Chưa luân phiên tay và chân" / "Đổi sang bên còn lại." | repeats previous rep's arm or leg (`bird_dog.dart:631`) | none | rejected |
| `Plank` | "Sai tư thế, đang chuyển sang plank" / "Chống hai tay và hai gối. Tay dưới vai, gối dưới hông, lưng phẳng." | support knee > 150 deg (`bird_dog.dart:337`) | none | rejected |
| `MissingBody` | "Mất mốc cơ thể" / "Giữ cả người trong khung hình." | any of 10 landmarks missing or unconfident (`bird_dog.dart:253`) | none | rejected |

The four metric faults are only recorded while in `hold_extended`. All have `affectsForm: true`.

**Tests.** No dedicated test. Shared: `exercise_logging_alignment_test.dart` (max_rep denominator),
`report_builder_key_contract_test.dart`, `report_builder_registry_test.dart`.

**Unverified, stale, or suspicious.**
- Report copy says 2 s ("Giữ đủ 2s", "Mục tiêu: >2.0s", `bird_dog_report_builder.dart:32-33`, `:41`,
  `:90`). The code enforces 1.5 s.
  FIXED 2026-11-17: copy says 1,5 giây; the never-faulted tempo is no longer praised.
- Comment "ĐỒNG HỒ ĐẾM NGƯỢC 5S" (`bird_dog.dart:424`) refers to a 5 s countdown that no longer exists.
  FIXED 2026-11-17: comment corrected.
- Comment "ML Kit Label có thể bị sai" (`:290`) records that left/right labels are distrusted; the
  physical-side workaround has no test.
- `TempoMetric.evaluateRep` (`metrics/tempo_metric.dart:54-68`) duplicates the short-hold rejection
  already done by the state machine. By reading, it cannot fire on a completed rep.
- Rejected attempts go through `_resetRepState()` with `countFaults: true` (`:610`, `:650-658`), so
  faults from rejected attempts are added to the `*_fails_count` totals.
  FIXED 2026-11-17: rejected attempts reset without counting (`bird_dog_form_test.dart`).
- The ear landmark used for `head` is not confidence-checked and falls back to the shoulder
  (`:364-369`), which silently disables the check.
  CONFIRMED 2026-11-17, not changed: report only.
- Fault types `Plank` and `MissingBody` are not in `_voiceFaultIds` (`:36-44`).

---

## 2. Sit-Up

Source: `lib/exercise/2.Sit-Up/` (7 files).

**Catalog.** `situp` (definition `sit__up`): 3 sets, 10 reps, `isFormChecked: true`
(`assets/data/exercise_catalog.json:312`). Definition: `SitUp(maxRep: reps)` via `_withReps`
(`exercise_definition.dart:678-679`).

**Archetype.** Rep-based. Side view, landscape. Uses `SideTrackedExerciseMixin` with shoulder, hip,
knee, ankle (`sit_up.dart:112-129`).

**Start position** (`:166-188`, constants `:24-27`). Tracked-side shoulder, hip, knee, ankle
confident; trunk horizontal angle at most 18 deg; knee angle 60 to 115 deg.

**Stop** (`:191`). `repCount >= maxRep` or 90 s (`TIMEOUT_MS`, `:21`).

**checkSafety** (`:152-163`). Not side view returns `turnSide`. Camera-side bundle (shoulder, hip,
knee, ankle, all confident, with fallback to the other side) missing returns `bodyInFrame`.

**Rep counting** (`:288-314`). KHS = knee-hip-shoulder angle (smaller = more curled).

| Transition | Condition | Debounce |
|---|---|---|
| lying to rising | trunk horizontal > 30 (`:29`) | 2 |
| rising to upright | KHS <= 105 (`:32`) | 2 |
| rising or lowering to lying | trunk horizontal < 22 (`:36`) | 2 |
| rising to lowering | min KHS this rep <= 142 and KHS > min + 15 (`:31`, `:34`) | 2 |
| upright to lowering | KHS > 110 (`:33`) | 2 |

A rep counts when lying is reached from lowering, or directly from rising if the minimum KHS reached
142 deg or lower (`:269-279`). A full upright sit is not required.

**Anti-cheat.** None beyond the 142 deg "countable top" gate. A curl that never reaches 142 returns
to lying without a rep and without resetting metrics, so its faults carry into the next rep (by
reading, `:269-283`).

**Faults.**

| Type | Vietnamese message / voice | Metric and threshold | Debounce | Counts the rep? |
|---|---|---|---|---|
| `jerking` | "Dùng lực giật/quăng người" / "Lên từ từ, đừng giật thân người!" | shoulder upward speed > 2.0 torso/s, only in the first 500 ms of rising (`metrics/jerking_metric.dart:36`, `:50`) | none | yes |
| `stability` | "Nhấc chân khỏi sàn" / "Hạ chân xuống" | ankle moved > 0.22 torso from its position at the start of the rep (`metrics/stability_metric.dart:39`) | none | yes |
| `rom` | "Chưa lên cao nhất: X độ" / "Cố gắng cuộn người cao hơn nữa" | min KHS > 142 (`metrics/rom_metric.dart:4`, `:31-32`) | none | yes |

Lowering speed is measured but deliberately never faulted (`metrics/tempo_metric.dart:32-36`).

**Tests.** `sit_up_partial_rom_test.dart` (3 tests): no fault or cue at any lowering speed; a
controlled partial sit-up counts without an upright torso; leaving the upright state and lowering to
the floor counts. Shared: report builder contract and registry tests.

**Unverified, stale, or suspicious.**
- Comments say the spec wants trunk < 10 deg and knee 100 deg (`sit_up.dart:23`, `:26`); the code
  uses 18 and 115.
- The `rom` fault threshold (142) equals the counting gate (142). By reading, a counted rep can never
  carry a `rom` fault, so `rom_fails_count` stays 0.
  CONFIRMED 2026-11-17, not changed: threshold left; the "Full ROM" card that could only show 100% is removed.
- `SitUpReportBuilder.buildDetailCards` filters on `'ROM'` and `'Jerking'`
  (`sit_up_report_builder.dart:62`, `:69`) but the fault types are `'rom'` and `'jerking'`. By
  reading, both detail cards always show 100%.
  FIXED 2026-11-17: filters on `jerking` (`sit_up_report_test.dart`).
- The lowering-time card shows "Mục tiêu: >1.5s" (`sit_up_report_builder.dart:102`) although
  lowering speed is unrestricted.
  FIXED 2026-11-17: target removed; the never-faulted tempo is no longer praised.
- Comment cites `SitUpSafetyGateScreen` for pain screening (`sit_up.dart:160-161`). No class with
  that name exists in `lib/`.
- A leftover comment about an `atan2` fix sits at the end of the class with no code under it (`:370`).

---

## 3. High Plank

Source: `lib/exercise/3.High Plank/` (7 files) on top of `lib/exercise/hold/` (3 files, also read).

**Catalog.** `high_plank` (definition `high__plank`): 1 set, 3 reps, 20 s, `isFormChecked: true`
(`assets/data/exercise_catalog.json:114`). The definition asserts that seconds is supplied and
builds `HighPlank(maxHolds: reps ?? 1, holdSeconds: seconds ?? 1)`, target type seconds
(`exercise_definition.dart:709-718`), so the catalog set is 3 holds of 20 s.

**Archetype.** Hold-based, reps of holds via `RepCountedHoldExercise`. Side view, landscape.
Constructor takes `maxHolds` and `holdSeconds` (`high_plank.dart:62-66`).

**Start position** (`:236-302`). The better-scoring side (sum of shoulder, hip, ankle likelihood,
`:201-212`) must have shoulder, elbow, wrist, hip, knee, ankle confident, and:
- body horizontal: shoulder-ankle dx > 1.2 x dy (`:256`)
- wrist at least 0.45 torso below shoulder (`:267`)
- floor support (`:503-518`): wrist-ankle Y gap <= 0.55 torso, wrist >= 0.35 torso below shoulder,
  ankle >= 0.06 torso below hip (`:18-20`). Failing shows "Hãy chống tay trên sàn, không tập plank
  trên tường."
- elbow angle >= 140, body angle (shoulder-hip-ankle) >= 150, knee angle >= 135 (`:15-17`)
- arm-to-body angle (hip-shoulder-wrist) between 40 and 140 (`:299`)

**Stop.** `repCount >= maxHolds` (`hold/rep_counted_hold_exercise.dart:139`). There is no timeout.

**checkSafety** (`high_plank.dart:167-181`). Not side view returns `turnSide` and cancels re-arm.
Chosen side missing any of the six landmarks, or any unconfident, returns `bodyInFrame`, drops an
active hold with break id `wall_guard`, and cancels re-arm.

**Hold counting** (`hold/rep_counted_hold_exercise.dart:281-309`). Phases: setup, holding, dropping,
resting, reArming.
- setup or dropping to holding: inside the outer entry ring for 4 frames (`high_plank.dart:96`).
- holding to dropping: outside the outer exit ring for 2 frames (`:99`).
- holding to resting: accumulated holding time >= `holdSeconds`. This increments `repCount`
  (`rep_counted_hold_exercise.dart:293`, `:329-330`).
- resting to reArming: after 5 s (`:30`), also advanced on frames with no pose (`:142-148`).
- reArming to holding: inside the outer entry ring continuously for 3 s (`:299-306`).

Time only accumulates in `holding`, and only for frame gaps inside the shared accumulator's
min/max window (`hold/timer_metric.dart:52-55`). A drop pauses the clock and the same hold resumes
(`rep_counted_hold_exercise.dart:235-237`). A pause/resume re-hold discards the partial hold
(`:157-167`).

**Anti-cheat: outer ring** (`high_plank.dart:38-47`, applied `:414-425`).

| | Entry (all must hold) | Exit (any one breaks) |
|---|---|---|
| body angle | >= 115 | < 105 |
| elbow angle | >= 100 | < 90 |
| knee angle | >= 100 | < 90 |
| hip deviation | < 0.38 | >= 0.45 |
| torso tilt | <= 40 deg | > 55 deg |

Plus the floor-support check every frame (`:364-377`), which blocks wall planks.

**Faults.** Hip deviation is hip Y minus the shoulder-ankle line at the hip's X, over torso; positive
= sag (`:391-393`). Faults are recorded only in `holding`. None is debounced. None stops the clock;
each accumulates into a `*_seconds` key.

| Type (log key) | Vietnamese message / voice | Metric and threshold |
|---|---|---|
| `Sagging` (`sagging`, `sagging_seconds`) | "Võng lưng gây áp lực cột sống" / "Siết chặt bụng, nâng hông lên một chút" | hip deviation > 0.18 (`metrics/sagging_metric.dart:23`, `high_plank.dart:34`) |
| `Piked` (`piked`, `piked_seconds`) | "Chổng mông làm mất tác dụng bài tập" / "Hạ thấp mông xuống bằng với vai" | body angle < 140 and hip deviation < -0.05 (`metrics/piked_hip_metric.dart:28-29`, `high_plank.dart:31`) |
| `BentElbow` (`elbow`, `elbow_seconds`) | "Khuỷu tay bị gập" / "Duỗi thẳng cánh tay ra" | elbow angle < 140 (`metrics/elbow_metric.dart:32`, `high_plank.dart:25`) |
| `wall_guard` (live only) | "Mất tư thế plank" | outer exit ring, lost landmarks, or wall guard (`high_plank.dart:151-163`) |

Live overlay labels are shorter: "Võng lưng", "Khuỷu tay bị gập", "Hông nâng quá cao" (`:125-148`).

**Tests.** `high_plank_hold_model_test.dart` (8 tests): outer-ring break pauses and resumes the same
hold; pause reactivation discards the partial hold; timer drops out-of-window frame gaps; inner sag
is coached without pausing earned time; outer gate admits deep sag but drops an upright body;
completed holds become reps with rest between; rest drains before a break-resettable 3 s re-arm;
rest advances on the wall clock without a pose frame. `hold_time_logging_oracle_test.dart`:
`good_seconds` excludes elbow-fault frames. `exercise_logging_alignment_test.dart`: fault seconds
published without duplicate count keys. (`plank_up_down_hold_test.dart` only mentions the
`high_plank` state of Plank Up-Down; it does not exercise High Plank.)

**Unverified, stale, or suspicious.**
- `metrics/elbow_metric.dart:28-31` describes thresholds of 160 and 150 deg; the constants are 140
  and 130.
- `DROPPING_SAG_DEVIATION = 0.18` is commented "> 12%" (`high_plank.dart:34`).
- Unreferenced constants: `HOLDING_BODY_THRESHOLD`, `HOLDING_KNEE_THRESHOLD`,
  `HOLDING_SAG_DEVIATION`, `DROPPING_ARM_ANGLE`, `DROPPING_KNEE_ANGLE` (`:24-33`).
- Start position uses a hard-coded 0.45 torso wrist drop (`:267`) while the floor-support helper uses
  0.35 (`:19`).
- The three metrics' `reset()` set `faultsCount = 0` (for example `metrics/sagging_metric.dart:48`),
  so `faultsCount` is always 0. Scoring uses `*_seconds`, so this is cosmetic.
- Report card target is hard-coded "Mục tiêu: 30.0s" (`high_plank_report_builder.dart:79`)
  regardless of `maxHolds x holdSeconds`.
- Side selection uses landmark likelihood, not `cameraFacing`, unlike the other exercises here.

---

## 4. Mountain Climber

Source: `lib/exercise/4.Mountain Climber/` (5 files).

**Catalog.** `mountain_climber` (definition `mountain__climber`): 3 sets, 16 reps,
`isFormChecked: true` (`assets/data/exercise_catalog.json:191`). Definition:
`MountainClimber(maxRep: reps)` via `_withReps` (`exercise_definition.dart:749-750`).

**Archetype.** Rep-based, one rep per knee drive. Side view, landscape.

**Start position** (`mountain_climber.dart:144-205`). Landmarks as in checkSafety, and:
- elbow angle > 140 (`metrics/mountain_climber_metric_base.dart:27`)
- trunk angle (shoulder, hip, ankle of the farther-back leg) between 145 and 180 (`:28`)

Each passing frame also calibrates both knee counters from the resting knee-to-shoulder distance
(`mountain_climber.dart:193-202`).

**Stop** (`:212-220`). `repCount >= maxRep` or more than 90 s (`MAX_DURATION_MS`, base `:24`).

**checkSafety** (`:127-137`). Not side view returns `turnSide`. Otherwise `bodyInFrame` unless
(`:452-507`):
- camera-side shoulder, elbow, wrist, hip, ankle are confident (0.7 / 0.3), and
- both hips, both knees, both ankles pass a relaxed gate of presence >= 0.25 and visibility >= 0.05
  (`:25-26`, `:509-512`).

**Rep counting** (`KneePeakRepCounter`, base `:116-256`). Distance d = knee-to-shoulder over torso,
tracked raw and with an EMA (alpha 0.45, `:52`).
- Zone threshold from calibration: min(0.86 x rest, rest - 0.12), floored at 0.45, and 0.8 x rest
  if that is not below rest (`:225-241`, constants `:37-39`). Uncalibrated default 1.25 (`:40`).
- Enter zone: raw d or EMA d <= threshold, or knee angle <= 150 (`:165-167`, `:53`).
- Exit zone: (raw d >= threshold + 0.14 and EMA d >= threshold) or (knee angle >= 145 and raw d >=
  0.9 x threshold) (`:168-172`, `:43-44`, `:54`).
- Countable tuck: min d in zone <= 1.05 x threshold or min knee angle <= 150, with at least 1 zone
  frame (`:190-197`, `:56-57`).
- A rep is emitted on zone exit if countable and 420 ms have passed since that leg's last rep
  (`:201-214`, `:47`).

**Anti-cheat** (`mountain_climber.dart:300-378`).
- Both knees in a deep tuck for 4 consecutive frames rejects and resets both counters and both
  metrics; shows "Không tính rep" / "Luân phiên từng gối" (`:300-314`, base `:58`). Deep tuck = raw
  d <= 0.85 x threshold or knee angle <= 132 (base `:147-150`).
- Any two accepted reps must be at least 260 ms apart (`:364-367`, base `:48`).
- Two reps on the same leg must be at least 850 ms apart, otherwise ignored and counted in
  `same_side_rejects_count` (`:369-373`, base `:49`).

**Faults.** All `affectsForm: true`. None rejects the rep.

| Type | Vietnamese message / voice | Metric and threshold | Debounce |
|---|---|---|---|
| `rom` | "Co gối trái quá ngắn" or "Co gối phải quá ngắn" / "Co gối sâu hơn về phía ngực" | peak d > 0.85 x zone threshold (`metrics/knee_drive_rom_metric.dart:62-64`, base `:55`) | none |
| `trunk_sag` | "Giữ thẳng lưng, siết chặt cơ bụng" (message and voice) | trunk angle (shoulder-hip-camera-side ankle) < 138 (`metrics/trunk_stability_metric.dart:44-45`, base `:31`) | 3 (`:16`) |
| `trunk_bounce` | "Giữ hông cố định, không nảy mông" (message and voice) | hip Y moved > 0.25 torso from the first-frame baseline (`metrics/trunk_stability_metric.dart:51-52`, base `:32`) | 4 (`:17`) |

`trunk_bounce` is only evaluated on frames where `trunk_sag` is not active (`else if`, `:72`).

**Tests.** `mountain_climber_counter_test.dart` (3 tests, `KneePeakRepCounter` only): counts a fast
drive with a single tuck frame; uses knee flexion as a fallback when distance is shallow; does not
count repeated jitter inside one drive. Nothing tests the exercise class, the cooldowns, the
double-knee rejection, or the metrics. Shared: logging alignment, report builder contract, registry.

**Unverified, stale, or suspicious.**
- `// TODO(voice): fast-movement policy variant — see tier3 note 1` (`mountain_climber.dart:51`).
- `ClimberState.knee_driving_out` is declared and labelled but never assigned (`:432-446`).
  FIXED 2026-11-17: removed.
- Comment "250 ms = tối đa 4 rep/s" on a 420 ms constant, and "Increased from 280" on a value of 260
  (base `:46-48`).
  FIXED 2026-11-17: cooldown comments corrected.
- Comment "~10 cm / scale" on `HIP_BOUNCE_NORM = 0.25` is an untested estimate (base `:32`).
- Comment says calibration averages 3 frames; the code assigns the latest frame (`:193-196`).
  FIXED 2026-11-17: comment corrected.
- The hip-bounce baseline is the hip Y on the first active frame and is never refreshed during the
  set (`metrics/trunk_stability_metric.dart:19-21`, `:39`), so any body shift along the mat becomes
  a permanent bounce fault. By reading; not verified.
  FIXED 2026-11-17: confirmed (a one-time 0.3-torso shift faulted 5 of 5 later reps); the baseline is re-taken on the first frame of each rep, no new threshold (`mountain_climber_trunk_test.dart`).
- The report builder has no detail cards.

---

## 5. Superman

Source: `lib/exercise/5.Superman/` (7 files).

**Catalog.** `superman`: 3 sets, 10 reps, `isFormChecked: true`
(`assets/data/exercise_catalog.json:367`). Definition: `Superman(maxRep: reps)` via `_withReps`
(`exercise_definition.dart:779-780`).

**Archetype.** Rep-based with a short hold at the top. Side view, landscape.

**Start position** (`superman.dart:239-260`). Camera-side shoulder, hip, wrist, ankle confident, and:
- prone, not supine (`:132-193`): rejects if the nose is more than 0.2 torso above the ear (`:151`),
  or if heel and toe both have likelihood > 0.3 and the toe is more than 0.15 torso above the heel
  (`:183-189`)
- not lying on the side: shoulder Y difference <= 0.35 torso (`:206`)
- torso flat: shoulder-hip Y difference < 0.25 torso (`:252`)

The hip Y at this moment is stored as the grounding baseline (`:255-257`).

**Stop** (`:263-270`). `repCount >= maxRep` or more than 120 s
(`MAX_DURATION_MS`, `metrics/superman_metric_base.dart:19`).

**checkSafety** (`:120-129`). Not side view returns `turnSide`. Camera-side shoulder, hip, wrist,
ankle missing or unconfident returns `bodyInFrame`.

**Rep counting** (`:354-383`). Arm elevation = lower of (shoulder Y minus wrist Y) on the two sides
over torso; leg elevation = lower of (hip Y minus ankle Y). If any of the four landmarks involved is
missing or unconfident the elevation is 0 (`:212-236`).

| Transition | Condition | Debounce |
|---|---|---|
| setup to lifting | arm and leg elevation > 0.03 (`base:12`) | 3 |
| lifting to hold | arm and leg elevation > 0.045 (`base:13`) | 2 |
| lifting to setup (abort) | arm and leg elevation <= 0.035 (`base:14`) | none |
| hold to lowering | arm or leg elevation <= 0.03 | 3 |
| lowering to setup | arm and leg elevation <= 0.035 | 2 |

The rep is counted on lowering to setup (`:380`, `:414`). Every completed cycle counts.

**Anti-cheat.** Rolling supine or onto the side mid-rep returns to setup and clears the attempt
(`:283-291`). Both sides must lift (minimum of left and right).

**Faults.** All `affectsForm: true`. None rejects the rep.

| Type | Vietnamese message / voice | Metric and threshold | Debounce |
|---|---|---|---|
| `elevation_arm` | "Nâng tay cao hơn!" / "Nâng tay lên cao hơn" | arm elevation < 0.03 while in hold (`metrics/limb_elevation_metric.dart:14`) | none |
| `elevation_leg` | "Nâng chân cao hơn!" / "Nâng chân lên cao hơn" | leg elevation < 0.03 while in hold (`metrics/limb_elevation_metric.dart:27`) | none |
| `hip` | "Không nhấc hông khỏi sàn!" / "Lấy hông làm điểm tựa, đừng nhấc hông lên" | hip risen > 0.03 torso above the start baseline while in hold (`metrics/hip_grounding_metric.dart:15`) | none |
| `hold` | "Giữ tư thế lâu hơn!" / "Giữ lại 2 giây ở điểm cao nhất, không giật cục" | hold < 1000 ms (`metrics/hold_time_metric.dart:35`, `base:15`) | none |
| `lumbar` | "Hạ thấp tay chân xuống, không uốn cong lưng quá gắt!" (message and voice) | trunk horizontal angle > 35 deg, checked in every state (`metrics/lumbar_extension_metric.dart:23-24`, `base:17`) | 3 (`:10`) |

**Tests.** No dedicated test. Shared: logging alignment, report builder contract, registry.

**Unverified, stale, or suspicious.**
- **Probable defect, by reading only.** Leaving the hold requires arm or leg elevation <= 0.03 for 3
  consecutive frames (`superman.dart:376`), and during those frames the metrics still see the `hold`
  state. `LimbElevationMetric` faults on elevation < 0.03 in `hold` with no debounce. So every rep
  that is lowered normally appears to pick up `elevation_arm` or `elevation_leg` and be logged as
  bad form. No test covers Superman; this needs a device check or a unit test before trusting form
  scores.
  FIXED 2026-11-17: confirmed by a test (a clean rep logged both elevation faults); a dip below 0.03 in hold is a fault only if the hold continues (`superman_form_test.dart`).
- Hold minimum is 1 s in code but the voice line says 2 seconds and the report card says "Mục tiêu:
  2.0s" (`metrics/hold_time_metric.dart:40`, `superman_report_builder.dart:93`).
  FIXED 2026-11-17: card "Mục tiêu: ≥1.0s", voice "1 giây".
- `hip_grounding_metric.dart:14` says the threshold reuses `LIFT_THRESHOLD` "làm ngưỡng tham khảo,
  bạn có thể chỉnh tuỳ specs", i.e. a placeholder value.
- `_rejectedAttempts` is logged as `rejected_attempts_count` but never incremented (`:73`, `:452`).
  FIXED 2026-11-17: incremented when a lift is abandoned before the hold or the user rolls mid-rep.
- `SupermanConfig.SPINE_NEUTRAL_RANGE` is unreferenced (`base:16`).
- Ear and foot landmarks in the prone check use raw `likelihood`, not the shared confidence gate.

---

## 7. Plank Shoulder Tap

Source: `lib/exercise/7.Plank Shoulder Tap/` (7 files).

**Catalog.** `plank_shoulder_tap` (definition `plank__shoulder__tap`): 3 sets, 16 reps,
`isFormChecked: true` (`assets/data/exercise_catalog.json:213`). Definition:
`PlankShoulderTap(maxRep: reps)` via `_withReps` (`exercise_definition.dart:810-811`).

**Archetype.** Rep-based, one rep per tap. Side view, landscape.

**Start position** (`plank_shoulder_tap.dart:123-186`). Side view, camera-side shoulder, hip, ankle,
wrist confident (falls back to the other side, `:371-376`), and:
- trunk angle (shoulder-hip-ankle) between 160 and 180
  (`metrics/plank_shoulder_tap_metric_base.dart:13`)
- both knee angles >= 150 (`:183`); a leg whose landmarks are absent defaults to 180 and passes, and
  these landmarks are not confidence-checked (`:139-162`)
- body horizontal: shoulder-ankle dx > 1.2 x dy (`:166`)

**Stop** (`:189-197`). `repCount >= maxRep` or more than 90 s (`base:10`).

**checkSafety** (`:91-99`). Not side view returns `turnSide` (front and angled both map to
`turnSide`, `:431-443`). Side bundle missing returns `bodyInFrame`.

**Rep counting** (`:281-305`). Only the camera-side wrist is tracked. Lift = wrist rise above its
resting Y over torso; dist = wrist-to-shoulder over torso. No debouncers.

| Transition | Condition |
|---|---|
| base to lifting | lift >= 0.08 and dist < 0.78 (`base:16`, `:18`) |
| lifting to tap | lift >= 0.08 and dist <= 0.62 (`base:17`) |
| lifting to base (rejected) | lift <= 0.06 (`base:19`) |
| tap to returning | dist > 0.72 or lift < 0.06 (`plank_shoulder_tap.dart:298-300`) |
| returning to base | lift <= 0.06, rep counted |

**Anti-cheat.** A lift that returns without reaching tap distance is rejected, shows "Không tính",
and increments `rejected_tap_attempts` (`:294-296`, `:352-357`). Nothing else.

**Faults.**

| Type | Vietnamese message / voice | Metric and threshold | Debounce | affectsForm |
|---|---|---|---|---|
| `hip_rotation` | "Hông bị vặn xoắn hoặc rớt xuống" / "Giữ hông cố định khi nhấc tay." | mid-hip Y moved > 0.22 torso, or hip width (X) changed > 0.16 torso, versus the base-state baseline (`metrics/hip_rotation_metric.dart:54-56`, `base:21-22`) | 3 (`:10`) | true |
| `trunk` | "Mất trục lưng thẳng" / "Thẳng lưng lên, siết mông và cơ lõi" | trunk angle < 150, checked in every state (`metrics/trunk_alignment_metric.dart:21`, `base:23`) | 4 (`:10`) | true |
| `tap` | "Không chạm tới vai" / "Chạm tay dứt khoát lên vai." | tap state never reached (`metrics/clear_tap_metric.dart:40`) | none | true |
| `tempo` | "Tập giật cục, quá nhanh" / "Chậm lại! Kiểm soát nhịp độ khi nhấc tay" | lift start to rep end < 0.35 s (`metrics/tap_tempo_metric.dart:37`, `base:24`) | none | false |

**Tests.** No dedicated test. Shared: logging alignment, report builder contract, registry.

**Unverified, stale, or suspicious.**
- Alternation is not enforced. `lastTappedSide` is written and never read (`:103`, `:331`), and
  `currentTappingSide` is derived from the camera side, not from which hand moved (`:233-235`). By
  reading, taps with the far hand are not observed at all, so a set may count only every other tap.
- By reading, `tap_fails_count` is always 0: a counted rep always passed through `tap`, and rejected
  attempts call `reset()` without counting (`:362-368`).
- The trunk fault feedback is "Võng lưng/Chổng mông!" but the check only catches angles below 150,
  not which direction (`metrics/trunk_alignment_metric.dart:24`).
- The state machine has no debounce, unlike every other rep exercise in this batch.

---

## 8. Leg Raises (Supine)

Source: `lib/exercise/8.Leg Raises (Supine)/` (8 files).

**Catalog.** `leg_raises` (definition `leg__raises`): 3 sets, 10 reps, `isFormChecked: true`
(`assets/data/exercise_catalog.json:147`). Definition: `LegRaise(maxRep: reps)` via `_withReps`
(`exercise_definition.dart:839-840`).

**Archetype.** Rep-based. Side view, landscape.

**Start position** (`leg_raise.dart:342-365`). At least one side with shoulder, hip, knee, ankle
confident. When both sides are valid the code takes the larger hip angle, the smaller knee angle and
the smaller trunk angle (`:242-248`). Required:
- hip flexion angle (shoulder-hip-knee) >= 155 (`metrics/leg_raise_metric_base.dart:12`)
- knee angle >= 140 (`base:13`)
- trunk horizontal angle <= 55 (`base:26`)
- at least one arm (shoulder, hip, elbow, wrist confident) visible, with elbow angle >= 135 and
  wrist-to-hip <= 0.95 torso (`base:29-30`). Prompts: "Giữ hai tay thẳng sát hông trong khung hình."
  and "Duỗi thẳng hai tay và khép sát hông."

**Stop** (`:368`). `repCount >= maxRep` or 90 s (`base:9`).

**checkSafety** (`:121-160`). Not side view returns `turnSide`. Neither side having shoulder, hip,
knee, ankle confident returns `bodyInFrame`.

**Rep counting** (`:480-511`). Hip flexion angle: 180 = legs flat, smaller = legs raised.

| Transition | Condition | Debounce |
|---|---|---|
| lying to raising | hip flexion < 160 (`base:16`) | 2 |
| raising to top | hip flexion <= 135 (`base:17`) | 2 |
| top to lowering | hip flexion > 145 (`base:18`) | 2 |
| lowering to lying | hip flexion > 150 (`base:19`) | 2 |
| any to lying (forced) | trunk horizontal > 55, shows "Lưng không chạm sàn" | none |

The cycle completes on lowering to lying (`:506-510`).

**Anti-cheat.**
- Sitting up (trunk > 55 deg) cancels the attempt (`:485-495`).
- A `knee` or `arms` fault makes the attempt not count: "Không tính rep", `invalidAttemptCount`
  incremented, no rep log written (`:539-548`).

**Faults.** All `affectsForm: true`.

| Type | Vietnamese message / voice | Metric and threshold | Debounce | Counts the rep? |
|---|---|---|---|---|
| `pelvic` | "Khung chậu bất ổn / Võng lưng" / "Võng lưng! Đừng hạ chân quá sâu nếu bạn không giữ được lưng sát sàn!" | hip risen > 0.05 torso above its per-rep baseline, lowering phase only (`metrics/pelvic_stability_metric.dart:41`, `:49`) | 3 (`:11`) | yes |
| `rom` | "Lên chưa đủ cao (Góc đỉnh: X°)" / "Nâng chân lên vuông góc với trần nhà" | minimum hip flexion > 100, or never measured (`metrics/rom_metric.dart:38`) | none | yes |
| `tempo` | "Thả rơi chân quá nhanh (Xs)" / "Từ từ thôi! Hạ chân chậm lại để giữ an toàn cho thắt lưng!" | lowering phase < 1.2 s (`metrics/tempo_metric.dart:51-52`, `base:22`) | none | yes |
| `knee` | "Gập gối làm giảm áp lực cơ bụng" / "Cố gắng duỗi thẳng gối ra nhé" | knee angle < 140 outside lying (`metrics/knee_straightness_metric.dart:35-36`) | 3 (`:11`) | rejected |
| `arms` | "Không thấy rõ tay", "Khuỷu tay đang gập" or "Tay rời xa hông" / "Duỗi thẳng tay và khép sát hông" | arms not visible, elbow < 135, or wrist-to-hip > 0.95 torso (`metrics/arm_position_metric.dart:43-48`) | 3 (`:10`) | rejected |

The spoken line is remapped by keyword in `_voiceScriptMessage` (`leg_raise.dart:596-614`) to one
of: "Ép lưng dưới xuống sàn", "Nâng và hạ chân rõ hơn", "Duỗi thẳng đầu gối", "Hạ chân chậm lại",
"Duỗi tay sát hông".

**Tests.** No dedicated test. Shared: `exercise_logging_alignment_test.dart` (score-zero exercises
publish `max_rep` and `good_rep_count`), report builder contract, registry.

**Unverified, stale, or suspicious.**
- `// NOTE UI: Cần hiển thị Pop-up Safety Gate "Có tiền sử đau thắt lưng không?" trước.`
  (`leg_raise.dart:162`). No such gate was found in this directory; the rest of `lib/` was not
  searched for it beyond the name `SafetyGate`.
- Tempo comments say "fault if < 2.0s" (`base:21`, `metrics/tempo_metric.dart:50`) and the report
  card says "Mục tiêu: >2.0s" (`leg_raise_report_builder.dart:111`). The code faults below 1.2 s;
  the 1.5 s constant is only a display band.
  FIXED 2026-11-17: card says "Mục tiêu: ≥1.2s"; comments corrected.
- `knee_straightness_metric.dart:31` says ">= 160 độ"; the threshold is 140.
  FIXED 2026-11-17: comment corrected.
- The ROM gate allows a rep to reach `top` at 135 deg but faults anything above 100, so reps between
  100 and 135 always count with a `rom` fault.
  CONFIRMED 2026-11-17, not changed: report only.
- By reading, `knee_fails_count` and `arm_position_fails_count` are always 0: those faults reject
  the attempt, and rejected attempts call `reset()` without counting (`:572-578`). The "Độ dẻo chân"
  card therefore always shows 100%.
  FIXED 2026-11-17: both keys now count rejected attempts; the card shows that count; they are no longer praised as a share of reps.
- There is no path from `raising` back to `lying` other than sitting up. A partial raise that never
  reaches 135 leaves the state in `raising` with metrics still accumulating until the next full
  raise. By reading; not verified.
  FIXED 2026-11-17: confirmed; raising returns to lying above 150 with no rep and metrics reset (`leg_raise_form_test.dart`).
- `MAX_TRUNK_ANGLE = 55` is used both as the start gate and the "back on the floor" gate, which is
  very loose for a supine exercise.
- `checkingPose` picks left-side landmarks first for `scaleFactor`, hip Y and ankle Y regardless of
  camera side or confidence (`:402-415`).
  FIXED 2026-11-17: camera side first, other side as fallback.
- `ArmPositionMetric` uses `LegRaiseFaultPriority.bentKnee` as its priority
  (`metrics/arm_position_metric.dart:73`).

---

## 9. Reverse Crunch

Source: `lib/exercise/9.Reverse Crunch/` (7 files).

**Catalog.** `reverse_crunch` (definition `reverse__crunch`): 3 sets, 10 reps, **`isFormChecked:
false`** (`assets/data/exercise_catalog.json:268`, `:270`). Definition: `ReverseCrunch(maxRep: reps)`
via `_withReps` (`exercise_definition.dart:868-869`). The flag does not reach the class (finding
14): `curl` and `arms` below still have `affectsForm: true`.

**Archetype.** Rep-based. Side view, landscape. Uses `SideTrackedExerciseMixin` with shoulder, hip,
knee, ankle (`reverse_crunch.dart:33-50`).

**Start position** (`:242-267`, definition `:527-533`). Tracked side confident, and the setup pose:
- knee angle between 60 and 130 (`metrics/reverse_crunch_metric_base.dart:13-16`)
- trunk horizontal angle <= 28 (`base:17`)
- thigh horizontal angle >= 50 (`base:18`)
- shin horizontal angle <= 40 (`base:19`)

Arm position only produces a hint at this stage; it does not block the start (`:258-264`).

**Stop** (`:270-278`). `repCount >= maxRep` or more than 90 s (`base:10`).

**checkSafety** (`:154-166`). Not side view returns `turnSide`. Side bundle missing returns
`bodyInFrame`. A third branch for `CameraFacing.front` is unreachable (`:162-164`).

**Rep counting** (`:342-392`). Baseline trunk-knee angle (shoulder-hip-knee) and hip Y are captured
on every lying frame that is in the setup pose (`:292-294`). Hip lift = baseline hip Y minus hip Y,
over torso. Contraction = angle drop >= 7 deg and hip lift >= 0.02 on the same frame
(`:535-537`, `base:25-28`).

| Transition | Condition | Debounce |
|---|---|---|
| lying to curling | out of setup pose, and (angle drop >= 6 or hip lift >= 0.03) (`base:20-22`) | 2 |
| curling to top | contraction seen this rep | 2 |
| top to lowering | back in setup pose, or hip lift fell 0.012 below its peak, or angle rose 5 above its minimum (`base:29-30`) | 2 |
| lowering to lying | setup pose | 2 |
| curling to lying | setup pose; counted only if countable | 2 |

Countable = contraction seen and peak hip lift >= 0.02 (`:426-428`).

**Anti-cheat.** An attempt that returns to setup without a contraction is rejected ("Không tính
rep", `rejected_attempts_count`, `:430-435`). The hips must leave the floor.

**Faults.**

| Type | Vietnamese message / voice | Metric and threshold | Debounce | affectsForm |
|---|---|---|---|---|
| `curl` | "Hông chưa nhấc khỏi sàn" / "Co gối về ngực và cuộn hông nhấc lên khỏi thảm." | max angle drop < 7 or max hip lift < 0.02 (`metrics/pelvic_curl_metric.dart:57-58`) | none | true |
| `tempo` | "Hạ hông quá nhanh" / "Hạ hông từ từ có kiểm soát, đừng thả rơi tự do!" | lowering phase < 1.0 s (`metrics/eccentric_tempo_metric.dart:40`, `base:39`) | none | false |
| `momentum` | "Duỗi chân quá sớm để lấy đà" / "Co gối về ngực trước, rồi mới duỗi chân lên ở đỉnh." | while curling and before contraction: knee angle >= 135 with hip lift < 0.02 on any frame (`metrics/swinging_momentum_metric.dart:24-27`, `base:35`) | none | false |
| `arms` | "Khuỷu tay đang gập" or "Tay rời xa hông" / "Duỗi thẳng tay và khép sát hông" | elbow < 135 or wrist-to-hip > 0.95 torso, only when an arm is visible (`metrics/arm_position_metric.dart:36-41`, `base:42-43`) | 3 (`:10`) | true |

None of the four rejects the rep.

**Tests.** No dedicated test. Shared: logging alignment, report builder contract, registry.

**Unverified, stale, or suspicious.**
- Comments cite "Y Khoa (McGill & Sarti) thresholds" (`base:24`) with no reference and values that
  disagree with their own comments: `LIFT_START_ANGLE_DROP = 6.0` says 5 deg (`base:20-21`),
  `PELVIC_CURL_ANGLE_MIN_DROP = 7.0` says "> 15 độ" (`base:25-26`).
- The `curl` fault tests the same two quantities as the countability gate, against a separately kept
  baseline (`metrics/pelvic_curl_metric.dart:22`). By reading it can only fire when the two baselines
  differ, so it is close to dead.
- Report tip says lower "trong 2 giây" (`reverse_crunch_report_builder.dart:31`); the fault is at 1 s.
- Unreferenced: `KNEE_SWING_TOLERANCE`, `PEAK_EXIT_LEG_VERTICAL_MIN`,
  `PEAK_EXIT_KNEE_EXTENSION_MIN` (`base:33-38`). `isLegThrustPeak` and `trunkKneeVelocity` are
  computed every frame and passed to metrics, but no metric reads them.
- `ArmPositionMetric` has no state gate, so arm faults raised while lying between reps attach to the
  next rep. By reading.
- `ArmPositionMetric` uses `CrunchVoicePriority.pelvicCurl` as its priority
  (`metrics/arm_position_metric.dart:62`).

---

## 10. V-Up

Source: `lib/exercise/10.Vup/` (8 files).

**Catalog.** `vup` (definition `v__up`): 3 sets, 6 reps, `isFormChecked: true`
(`assets/data/exercise_catalog.json:400`). Definition: `VUp(maxRep: reps)` via `_withReps`
(`exercise_definition.dart:554-555`).

**Archetype.** Rep-based. Landscape. Uses `SideTrackedExerciseMixin` with shoulder, wrist, hip, knee,
ankle (`v_up.dart:38-59`). Side view is assumed by the geometry but not enforced (see checkSafety).

**Start position** (`:175-181`, definition `:581-586`). Tracked side confident, at least one full
side (shoulder, hip, knee, ankle) confident, and "strict lying":
- body angle (shoulder-hip-ankle) >= 145 (`metrics/v_up_metric_base.dart:15`)
- knee angle >= 135 (`base:16`)
- trunk horizontal <= 35 and leg horizontal <= 35 (`base:17-18`)
- shoulder, knee, ankle all within 0.55 torso of hip height (`base:19`)
- wrist-to-ankle distance >= 1.30 torso, i.e. arms overhead (`base:20`)

**Stop** (`:184`). `repCount >= maxRep` or 90 s (`base:11`).

**checkSafety** (`:161-165`). Always returns null. This exercise never emits `turnSide`,
`bodyInFrame` or any other guidance signal. If landmarks are missing, `checkingPose` returns early,
showing "Không nhìn rõ toàn thân" in one of the two cases (`:218-226`).
  CONFIRMED 2026-11-17, not changed: confirmed by reading; side view is not enforced.

**Rep counting** (`:285-371`). A flat baseline (shoulder Y, ankle Y, body angle, wrist-ankle
distance) is captured after 3 consecutive strict-lying frames (`base:23`). Lifts are measured from
it.

| Transition | Condition | Debounce |
|---|---|---|
| lying to rising | baseline captured, not strict lying, body angle <= baseline - 5 and < 165, shoulder lift >= 0.08, ankle lift >= 0.08, knee >= 130 (`:308-317`, `base:24-25`, `:35-36`) | 2 |
| rising to v_position | strict V (below) | 2 |
| rising to lying (abort) | strict lying again | 2 |
| v_position to lowering | body angle > minimum this rep + 5 | 2 |
| lowering to lying | strict lying and body angle >= 145 (`base:37`) | 2 |

Strict V (`:592-598`): body angle <= 145, knee >= 130, trunk and leg each >= 8 deg off horizontal,
shoulder and ankle lift each >= 0.08 torso, and arms reaching (wrist-ankle <= 1.85 torso, or closed
by >= 0.25 torso from baseline) (`base:26-35`).

**Anti-cheat.**
- No rep can start without a fresh flat baseline, and the baseline is cleared after every rep or
  rejection (`:373-380`, `:440-444`).
- Shoulders and ankles must both lift, so a sit-up with legs pinned or a leg raise alone does not
  enter `rising`.
- On return, `_isRepCountable` re-checks the peak values (`:420-438`); failure rejects with "Không
  tính rep".
- A `knee` fault disqualifies the rep (`:487-497`).

**Faults.**

| Type | Vietnamese message / voice | Metric and threshold | Debounce | affectsForm | Counts the rep? |
|---|---|---|---|---|---|
| `sync` | "Mất đồng bộ thân trên và chi dưới" / "Hãy nâng cả tay và chân CÙNG LÚC để bảo vệ lưng!" | during rising, one of shoulder or ankle lifted > 0.15 torso while the other is < 0.05 (`metrics/sync_elevation_metric.dart:46-47`) | none | false | yes |
| `rom` | "Chưa gập đủ sâu (Góc nhỏ nhất: X°)" / "Cố gắng rướn tay chạm vào mũi chân nhé" | min body angle > 135 and min wrist-ankle distance > 1.45 torso (`metrics/v_shape_rom_metric.dart:34-38`, `base:27`, `:31`) | none | false | yes |
| `jerking` | "Dùng lực quán tính để giật lên" / "Dùng cơ bụng để cuộn lên, không giật lấy đà!" | shoulder or ankle upward speed > 4.5 torso/s during rising (`metrics/jerking_metric.dart:42`, `base:40`) | 3 (`base:41`) | true | yes |
| `tempo` | "Thả rơi tự do ở pha hạ (Xs)" / "Hạ chậm lại! Việc nhả cơ chậm sẽ xây dựng cơ bụng rất tốt." | lowering phase < 1.0 s (`metrics/tempo_metric.dart:31`) | none | true | yes |
| `knee` | "Gập gối làm mất lực đòn bẩy" / "Nhớ giữ thẳng gối trong suốt quá trình gập nhé" | knee angle < 130 outside lying (`metrics/knee_extension_metric.dart:21-22`) | 3 (`:10`) | true | rejected |

**Tests.** `v_up_anti_cheat_test.dart` (6 tests): start position requires flat full-body extension;
no count when starting already in a V and only lying down; no count for a sit-up toe touch with legs
pinned; no count for a bent-knee tuck; counts a complete controlled V-up from a flat baseline;
counts a moderate V-up without an extreme toe-touch angle. `v_up_report_builder_test.dart` (1 test):
`tempo_fails_count` is coachable and praiseable. Shared: report builder contract, registry.

**Unverified, stale, or suspicious.**
- `onExerciseActivated` does not call `super.onExerciseActivated()` (`v_up.dart:167-172`), so by
  reading the base session stopwatch is not restarted (`exercise_base.dart:905-909`). Reverse Crunch
  does call super.
  FIXED 2026-11-17: super call added (session stopwatch; nothing in V-Up reads it).
- When a `knee` fault disqualifies the rep, a `RepLog` is still written with the unchanged
  `repCount` as its number (`:510-520`), so rep logs can outnumber counted reps and repeat a number.
  FIXED 2026-11-17: confirmed (logs numbered 1, 1, 2); a disqualified attempt writes no `RepLog` (`v_up_form_test.dart`).
- By reading, `knee_fails_count` is always 0 for the same reason as Leg Raises (`:524-530`).
  FIXED 2026-11-17: counts knee-disqualified attempts.
- Comment "A single ML Kit position jump must not be classified as momentum" (`base:39`) explains the
  4.5 torso/s threshold; no data backs the number.
- Tempo fault is at 1.0 s but the report tip recommends 2 to 3 s
  (`v_up_report_builder.dart:32`).
  FIXED 2026-11-17: tip says "ít nhất 1 giây".
- Unreferenced: `TOP_WRIST_ANKLE_CLOSURE_MIN` (`base:32`). `bothArmsLifted` and `bothLegsLifted` are
  computed and passed around but never read.

---

## 12. Dead Bug

Source: `lib/exercise/12.Dead Bug/` (8 files).

**Catalog.** `dead_bug` (definition `dead__bug`): 3 sets, 8 reps, `isFormChecked: true`
(`assets/data/exercise_catalog.json:81`). Definition: `DeadBug(maxRep: reps)` via `_withReps`
(`exercise_definition.dart:583-584`).

**Archetype.** Rep-based with a hold phase that has no minimum duration. Side view, landscape.

**Start position** (`dead_bug.dart:156-198`). Both shoulders, hips, wrists and knees present (no
confidence check), and:
- both wrists above their shoulders and both knees above their hips (face-up check, `:177-178`)
- average arm angle (hip-shoulder-wrist) between 40 and 140 (`:24-25`)
- average hip angle (shoulder-hip-knee) between 40 and 140

**Stop** (`:201`). `repCount >= maxRep` or 90 s (`:21`).

**checkSafety** (`:145-152`). Not side view returns `turnSide`. No landmark check. `checkingPose`
silently skips the frame unless both shoulders, hips, wrists, knees and ankles (10 landmarks) are
confident (`:311-334`).

**Rep counting** (`:447-465`). Four arm/leg pairings are scored as min(arm angle, hip angle); the
"active pair" is the pairing with the highest score (`:227-287`). Larger = more extended.

| Transition | Condition | Debounce |
|---|---|---|
| setup to extending | active pair angle > 108 (`:28`) | 2 |
| extending to hold | active pair angle > 138 (`:29`) | 2 |
| extending to setup (abort) | active pair angle < 108 (`:31`) | none |
| hold to returning | active pair angle < 128 (`:30`) | 2 |
| returning to setup | active pair angle < 108 | 2 |

The rep is counted when setup is reached from returning (`:426-430`, `:480`). Every completed cycle
counts.

**Anti-cheat.** None that rejects. Same-side and non-alternating reps are counted and only marked bad
form (the helper is named `_blockingFaultFor` but does not block, `:476-489`).

**Faults.** All `affectsForm: true`. None rejects the rep.

| Type | Vietnamese message / voice | Metric and threshold | Debounce |
|---|---|---|---|
| `anti_extension` | "Lưng bị cong khỏi mặt sàn" / "Lưng bị cong! Hãy gồng bụng ép chặt thắt lưng xuống sàn!" | left hip risen > 0.05 torso above its per-rep baseline, during extending or hold (`metrics/anti_extension_metric.dart:44`) | 3 (`:11`) |
| `opposite_side` | "Không duỗi cùng tay cùng chân" / "Duỗi tay và chân đối diện" (exercise); "Chuyển động cùng bên" / "Sai nhịp! Hãy hạ tay và chân ĐỐI DIỆN nhau." (metric) | active arm and leg on the same physical side (`dead_bug.dart:518`, `metrics/coordination_metric.dart:26-41`) | none |
| `alternate` | "Chưa luân phiên bên" / "Đổi sang tay và chân còn lại" (exercise); "Không luân phiên đổi bên" / "Nhớ đổi bên sau mỗi lần nhé" (metric) | same arm or leg as the previous rep (`dead_bug.dart:529-533`, `metrics/coordination_metric.dart:45`) | none |
| `floor_contact` | "Tay hoặc chân chạm sàn" / "Giữ tay và chân lơ lửng, đừng chạm sàn" | any of the four limb angles >= 165 during extending or hold; warning from 155 (`metrics/floor_contact_metric.dart:8`, `:28`, `:39`) | 3 (`:12`) |
| `stable_limbs` | "Chi trụ bị kéo xê dịch" / "Giữ cố định tay và chân còn lại vuông góc nhé!" | with at least one limb > 118, a limb not counted as extending is > 135 (`metrics/stable_limbs_metric.dart:27-39`) | 5 (`:10`) |
| `tempo` | "Thả rơi tay/chân nhanh (Xs)" / "Hạ tay chân chậm lại khoảng 2 giây để kích hoạt cơ bụng sâu!" | extending phase < 0.8 s (`metrics/tempo_metric.dart:47`) | none |

**Tests.** `dead_bug_alternation_test.dart` (4 tests): start position accepts tabletop arms and legs;
counts two reps when opposite arm and leg alternate; counts a repeated side but marks it as form
correction; counts floor contact but marks it as form correction. Shared: logging alignment, report
builder contract, registry.

**Unverified, stale, or suspicious.**
- `// NOTE UI: Cần hiển thị Pop-up Safety Gate "Đau thắt lưng cấp tính không?" trước.`
  (`dead_bug.dart:154`). No such gate was found in this directory.
- By reading, `stable_limbs` cannot fire: a limb is "extending" above 118, and a support limb faults
  above 135 only if it is not extending, which requires it to be at most 118. The two conditions
  exclude each other (`metrics/stable_limbs_metric.dart:27-39`). The inline comments name 125 and
  115, matching neither constant.
  FIXED 2026-11-17: support limbs are now the arm and leg outside the active pair; fault when either is > 135 for 5 frames (`dead_bug_form_test.dart`).
- Tempo comment says "< 1.5s là quá nhanh", the voice line says about 2 s, the report card says
  "Mục tiêu: >1.5s" (`dead_bug_report_builder.dart:117`); the code faults below 0.8 s.
  FIXED 2026-11-17: card "Mục tiêu: ≥0.8s", comment and voice line corrected.
- The hold has no minimum time and no hold fault, although the phase label is "Giữ tĩnh!" and
  `liveHoldSeconds` is exposed.
- Coordination is implemented twice, in the exercise (`_lastPhysicalLeftArm`) and in
  `CoordinationMetric` (`_lastWasLeftArm`), with different copy. The metric's memory is not cleared
  by `reset()` (`metrics/coordination_metric.dart:62-66`).
- An aborted extension calls `_resetRepState()`, which uses `resetAndCountFault()`
  (`dead_bug.dart:454-457`, `:552-559`), so faults from attempts that never became reps are added to
  the `*_fails_count` totals.
  FIXED 2026-11-17: aborted extensions reset without counting.
- `scaleFactor` and the hip baseline always use the left shoulder and left hip, regardless of which
  side faces the camera (`:337`, `:416`).
  FIXED 2026-11-17: camera-side shoulder and hip.
- The start position does not confidence-check its landmarks, unlike `checkingPose`.

---

## Plank (forearm)

Source: `lib/exercise/plank/` (6 files).

**Catalog.** `plank`: 1 set, 3 reps, seconds null, `isFormChecked: true`
(`assets/data/exercise_catalog.json:202`). The definition builds `Plank(maxRep: reps)`
(`lib/models/exercise_definition.dart:325-326`), so "reps" is the number of holds. Hold length is
not configurable: `HOLD_DURATION = 15.0` s, rest 5 s (`plank.dart:18-19`).

**Archetype.** Hold-based, its own implementation (not `RepCountedHoldExercise`). Side view,
landscape only (`:50-54`). Voice is a dedicated `PlankVoiceCoach` (`:93`, not read).

**Start position** (`:120-123`, `:677-682`). Side: the camera side, falling back to the other side;
if facing is not left/right, the side with the higher hip likelihood (`:533-565`). Shoulder, hip,
ear, knee, ankle, elbow and wrist on that side must all be confident (`:474-485`), and:
- trunk deviation (below) within +/-35 deg (`:29`, `:667-668`)
- body angle (shoulder-hip-ankle) >= 160 (`:32`)
- knee angle (hip-knee-ankle) >= 140 (`:34`)
- elbow angle (shoulder-elbow-wrist) <= 125, i.e. on forearms (`:35`)
- not standing: hip at most 0.5 torso above the floor, floor = foot index Y, else heel Y, else knee Y
  (`:22`, `:519-520`)

**Stop** (`:128`). `repCount >= maxRep`. There is no timeout.

**checkSafety** (`:157-203`). Not side view returns `turnSide`. Camera-side shoulder, hip, ear or
knee missing returns `bodyInFrame`. Shoulder, hip or ear unconfident returns `lighting`. Ankle missing,
or ankle or knee unconfident, returns `bodyInFrame`. Elbow and wrist are not checked here, only in
the geometry builder (`:474-485`).

**Hold counting** (`:309-352`). States setup, holding, resting.
- setup to holding: hold pose on 2 consecutive frames (`:75`, `:311`, `:327`). The hold pose is the
  start pose with body angle >= 150 instead of 160 (`:33`, `:684-689`).
- holding to setup: hold pose false on a single frame (`:334`, raw value, not the debouncer), any of
  the seven landmarks unconfident (`:211-213`), or a no-pose frame (`:459-461`). `_holdStartMs` is
  cleared (`:376`), so the next hold restarts from 0.
- holding to resting: wall-clock time since the hold began >= 15 s (`:337`, `:618-621`); `repCount`
  += 1 (`:409`).
- resting to holding: rest >= 5 s and hold pose confirmed on 2 frames (`:346`).

Hold time is wall clock from the first holding frame, not `HoldSecondsAccumulator`. The accumulator
only feeds `good_seconds` and the fault-second keys (see "Shared hold-time accumulator" under Shared
conventions).

**Anti-cheat.** The elbow gate rejects a high plank, the knee gate a knee plank, the floor check a
standing body (`:674-689`). Any single-frame break restarts the hold from 0.

**Faults.** Metrics run only in `holding` (`:265-269`). Each metric logs a `FaultRecord` with
`affectsForm: false`; at hold end `finalizeHold` sets `affectsForm: true` when the metric was
faulting on more than 45% of the hold's frames (`metrics/trunk_alignment_metric.dart:35`, `:157-159`;
`metrics/head_neck_metric.dart:42`, `:169-171`; `metrics/knee_extension_metric.dart:33`,
`:118-120`). The hold is always counted. Every debounced faulting frame also adds seconds to the
time key (`plank.dart:271-278`). The records carry no `voiceMessage`.

| Type (log key) | Live text / logged message | Metric and threshold | Debounce | Counts the hold? |
|---|---|---|---|---|
| `Back`, sag (`trunk_seconds`) | "Gồng cơ bụng!" / "Hông hơi chùng"; error: "Lưng võng quá!" / "Hông chùng quá mức" | trunk deviation > +8 warning, > +12 error (`plank.dart:38-39`, `metrics/trunk_alignment_metric.dart:84-87`) | 5 (`:46`) | yes |
| `Back`, pike (`trunk_seconds`) | "Hơi cao hông" / "Hông hơi cao"; error: "Hông quá cao!" / "Hông quá cao" | trunk deviation < -4 warning, < -8 error (`plank.dart:40-41`, `metrics/trunk_alignment_metric.dart:90-94`) | 5 (`:47`) | yes |
| `Neck`, drop (`neck_seconds`) | "Đầu hơi cúi" / "Đầu hơi cúi"; error: "Đừng cúi đầu!" / "Cúi đầu quá mức" | 180 minus neck angle (ear-shoulder-hip) > 16 warning, > 30 error (`metrics/head_neck_metric.dart:38-39`, `:95-99`) | 8 (`:53`) | yes |
| `Neck`, lift (`neck_seconds`) | "Đầu hơi ngẩng" / "Đầu hơi ngẩng"; error: "Đừng ngẩng đầu!" / "Ngẩng đầu quá mức" | same magnitudes, opposite sign (`:102-106`) | 8 (`:54`) | yes |
| `Knees` (`knee_seconds`) | "Thẳng gối ra" / "Đầu gối hơi gập"; error: "Gối gập quá nhiều!" / "Đầu gối gập quá nhiều" | knee angle < 158 warning, < 145 error (`metrics/knee_extension_metric.dart:25`, `:28`, `:75-77`) | 8 (`:43`) | yes |

Trunk deviation = clock angle of the hip-to-shoulder vector minus 270 (facing left) or 90 (facing
right), wrapped to +/-180 (`plank.dart:490-496`, `lib/utils/pose_math_helpers.dart:244-268`,
`:372-378`). Sag is checked before pike with `else if` (`trunk_alignment_metric.dart:97-116`).
Sag/pike bigger than the body-angle gate (< 150) or the 35 deg trunk gate ends the hold instead of
being logged. Knee angles between 140 and 145 are the only "error" band that keeps the hold.

When a hold breaks, one voice line is chosen (`plank.dart:381-404`): "Chống bằng cẳng tay", "Thẳng
đầu gối ra", "Hạ hông xuống, giữ thân thẳng", "Gồng cơ bụng, nâng hông lên", "Giữ thân người
thẳng"; on a no-pose frame "Giữ cả người trong khung hình" (`:460`). Setup prompts: "Chống bằng cẳng
tay để vào Plank", "Giữ thân người thẳng như plank", "Thẳng đầu gối ra" (`:315-323`).

**Tests.** `plank_anti_cheat_test.dart` (2 tests): start position requires forearm plank geometry;
hold timer resets when the user leaves the forearm plank. Nothing tests the three metrics, their
thresholds or the sag/pike sign. `test/services/plank_voice_coach_test.dart` and
`test/voice/policy_voice_coach_wiring_test.dart` mention Plank (not opened).

**Unverified, stale, or suspicious.**
- **Sag and pike are mirrored between the two facings, by reading.** For the same posture
  (shoulders higher than hips) the hip-to-shoulder clock angle is above 270 when facing left and
  below 90 when facing right, so `trunkDeviation` is positive in one view and negative in the other.
  The sign is not flipped per facing (`plank.dart:492-496`). For one of the two facings, sag is
  logged as pike and pike as sag, against asymmetric thresholds (8/12 vs 4/8). The code itself says
  "verify sign mapping" (`metrics/plank_metric_base.dart:21`, `metrics/trunk_alignment_metric.dart:83`,
  `pose_math_helpers.dart:370-371`). No test covers it.
  FIXED 2026-11-17: deviation is multiplied by -1 for facing right, so positive = sag in both
  facings (`plank.dart` `_buildForearmPlankGeometry`); `plank_form_test.dart` feeds one posture in
  both facings.
- Plank's 270/90 targets are the opposite of Push-Up's for the same `cameraFacing`; see the first
  bullet under Push-Up. If Plank's convention is the wrong one, a level trunk reads ~180 deg off and
  the start gate never passes.
  FIXED 2026-11-17: traced; Plank's side is the right one (MediaPipe labels left/right from the
  image it receives, so mirroring does not flip the relation). Push-Up was changed instead.
- The trunk metric is the shoulder-hip line against the image horizontal, not the hip against the
  shoulder-ankle line. A forearm plank holds the shoulders above the hips, and phone roll adds
  directly, so a neutral plank is not 0 deg. By reading; no calibration in the repo.
- Neck angle uses `calculateAngle`, which returns the absolute `atan2` difference without folding it
  into 0-180 (`pose_math_helpers.dart:212-229`). The magnitude |180 - angle| is correct, but whether
  it lands above or below 180 depends on which vector crosses the +/-180 branch cut, so the
  drop/lift label is unreliable (comment admits it, `metrics/head_neck_metric.dart:19-20`). By
  reading.
  FIXED 2026-11-17: magnitude from `calculateAngleNormalized`, label from whether the ear is below
  or above the hip->shoulder line in image Y; same label in both facings (tested).
- Comment values disagree with code: trunk header 8-15 warning, > 15 error, > 30% fault time
  (`metrics/trunk_alignment_metric.dart:14-20`) vs 8/12 (sag), 4/8 (pike), 45%; neck header 10/20
  (`metrics/head_neck_metric.dart:22-27`) vs 16/30; knee header 170/160
  (`metrics/knee_extension_metric.dart:14-17`) vs 158/145; class comment and definition say 3 x 10 s
  (`plank.dart:15`, `exercise_definition.dart:310`, `:316`) vs 15 s.
  FIXED 2026-11-17: comments state 8/12, 4/8, 45%, 16/30, 158/145; class comment and definition
  copy say 15 s.
- When `checkSafety` returns a signal the frame is skipped (`exercise_base.dart:550-553`) but the
  state stays `holding` and the wall clock keeps running, so a short `lighting` or `bodyInFrame` spell
  still counts toward the 15 s. Losing elbow or wrist confidence, which only the geometry builder
  checks, instead resets the hold to 0. By reading.
  FIXED 2026-11-17: confirmed by test; the hold clock now pauses over frames skipped by
  `checkSafety` and over a presence-gate pause (`onPauseReactivationStarted`).
- `total_seconds` is pushed as `maxRep x 15` regardless of time actually held (`plank.dart:140`), and
  the report's clean ratio divides by it (`plank_report_builder.dart:62-63`).
  FIXED 2026-11-17: `total_seconds` is the evaluated time spent in `holding` (completed and broken
  holds); the card reads "Trên Ns đã giữ" instead of "Mục tiêu".
- `RepContext.kneeAngle` is documented as null when the ankle is hidden
  (`metrics/plank_metric_base.dart:27-28`), but the geometry requires a confident ankle and
  `checkingPose` forces `_ankleAvailable = true` (`plank.dart:218`), so the knee skip at `:267` is
  dead.
  FIXED 2026-11-17: `_ankleAvailable` and the skip are removed; the doc comment says Plank always
  provides the angle.
- `_spoken10` and `_spoken5` are written and never read (`:284-289`).
  FIXED 2026-11-17: removed.

---

## 14. Bear Plank

Source: `lib/exercise/14.Bear Plank/` (6 files) on top of `lib/exercise/hold/` (re-read for this
batch).

**Catalog.** `bear_plank`: 1 set, 3 reps, 15 s, `isFormChecked: true`
(`assets/data/exercise_catalog.json:15`). The definition builds
`BearPlank(maxHolds: reps ?? 1, holdSeconds: seconds ?? 15)`
(`exercise_definition.dart:645-648`), target type seconds.

**Archetype.** Hold-based, reps of holds via `RepCountedHoldExercise`. Side view, landscape only
(`bear_plank.dart:38-42`). Entry debounce 3 frames, exit debounce 5 (`:63`, `:66`; base defaults 4
and 2, `hold/rep_counted_hold_exercise.dart:51-52`).

**Start position** (`:133-144`). One side with shoulder, hip, knee, ankle, wrist all confident
(`:360-423`; left is preferred when its hip likelihood is at least the right's, regardless of
`cameraFacing`), and knee angle (hip-knee-ankle) between 50 and 135
(`metrics/bear_plank_metric_base.dart:14-15`). Nothing else: no hover, horizontal-body or
on-all-fours check at this stage.

**Stop.** `repCount >= maxHolds` (`hold/rep_counted_hold_exercise.dart:139`). No timeout.

**checkSafety** (`bear_plank.dart:118-130`). Not side view returns `turnSide` and cancels re-arm. No
side with the five landmarks confident returns `bodyInFrame`, drops an active hold to `dropping`
with break id `wall_guard`, and cancels re-arm.

**Hold counting.** Shared machine (`hold/rep_counted_hold_exercise.dart:281-309`, described under
High Plank). Bear-specific gate, "hovering form" (`bear_plank.dart:188-190`):
- knee height above the floor > 0.035 and <= 0.50 torso (`base:12-13`), floor Y = the wrist-ankle
  line evaluated at the knee's X (`:172-180`)
- knee angle < 155 (`base:16`)

Entry: hovering form on 3 consecutive frames. Exit to `dropping` (clock paused, same hold resumes):
not hovering on 5 consecutive frames. A hold completes, and `repCount` increments, when accumulated
holding time reaches `holdSeconds`. Rest 5 s, re-arm 3 s.

**Anti-cheat.** Knees on the floor, knees too high, or legs straightened (knee >= 155) all leave
the hover gate and stop the clock. Nothing checks the arms or the trunk before the hold starts.

**Faults.** Metrics only act in `holding` (mapped to `BearState.hovering`, `:317-328`); each check
is a single-frame comparison with **no debounce**, and each `FaultRecord` has `affectsForm: true`
(`metrics/*.dart`). One faulting frame anywhere in a hold is enough to make the hold
`correctForm = false` (`hold/rep_counted_hold_exercise.dart:336-337`). No fault stops the clock;
each faulting frame adds to its `*_seconds` key (`bear_plank.dart:241-245`). Log types are remapped
(`:330-338`).

| Type (log type, seconds key) | Vietnamese message / voice | Metric and threshold | Debounce | Counts the hold? |
|---|---|---|---|---|
| `KneeTouchingFloor` (`knee_hover`, `knee_seconds`) | "Gối đang chạm sàn, nâng gối lên!" / "Nâng gối lên khỏi mặt sàn" | knee height < 0.035 torso (`metrics/knee_hover_metric.dart:11`, `base:12`) | none | yes |
| `ButtTooHigh` (`hip_high`, `knee_seconds`) | "Mông vổng quá cao, hạ xuống!" / "Hạ mông xuống, giữ lưng phẳng" | knee height > 0.50 torso (`metrics/knee_hover_metric.dart:23`, `base:13`) | none | yes |
| `BackSagging` (`back_sag`, `back_seconds`) | "Lưng bị võng, giữ lưng phẳng!" / "Siết cơ bụng, giữ lưng thẳng, đừng để lưng bị võng!" | (shoulder Y - hip Y) > 0.20 torso, i.e. shoulder lower than hip (`metrics/flat_back_metric.dart:12`, `base:17`, `bear_plank.dart:186`) | none | yes |
| `BackArching` (`back_arch`, `back_seconds`) | "Lưng gù lên, hạ lưng phẳng!" / "Lưng đang gù, hạ lưng xuống cho phẳng" | (shoulder Y - hip Y) < -0.26 torso, i.e. hip lower than shoulder (`metrics/flat_back_metric.dart:26`, `base:18`) | none | yes |
| `WeightForward` (`weight`, `weight_seconds`) | "Vai đang chúi quá trước cổ tay!" / "Đẩy lùi hông về sau, giữ vai nằm ngay trên cổ tay" | \|shoulder X - wrist X\| > 0.32 torso (`metrics/weight_distribution_metric.dart:11`, `base:19`, `bear_plank.dart:187`) | none | yes |
| `wall_guard` (break id) | none | lost landmarks or outer-gate exit (`hold/rep_counted_hold_exercise.dart:54`, `:291`) | 5 (exit) | clock paused |

**Tests.** `hold_time_logging_oracle_test.dart`: inner back/weight faults keep the hold clock
running. `hold_voice_scale_migration_test.dart`: Bear reuses the hover gate, logs snake-case faults
and preserves report keys. `exercise_logging_alignment_test.dart`: hold exercises publish fault
seconds without duplicate count keys. Registry test maps `bear_plank` / `bear__plank` to
`BearPlankReportBuilder`. No test covers the thresholds themselves.

**Unverified, stale, or suspicious.**
- **No debounce and single-frame form failure.** Unlike Plank (45% of hold time) every Bear fault
  marks the whole hold as bad form on one frame. Landmark jitter at a threshold is enough.
- **The knee fault races the exit gate, by reading.** The knee fault band (< 0.035 or > 0.50) is the
  same band that makes `outsideOuterExit` true, and the exit needs 5 frames, so every drop caused by
  knee height logs a knee fault during the 1-4 frames before it, and the hold is marked bad form.
- The back metric is the shoulder-to-hip height difference, which measures trunk tilt, not spinal
  curvature. "Sagging" fires when the shoulders are below the hips (hips high) and "Arching"
  ("gù") when the hips are below the shoulders. By reading, the labels do not describe what is
  measured; a sagging lumbar spine with level shoulders and hips is not detected.
- `WeightForward` uses the absolute X offset, so shoulders behind the wrists also fire "chúi quá
  trước cổ tay".
- The start position only checks knee angle 50-135; kneeling with knees on the floor, or sitting,
  satisfies it. By reading.
- `scaleFactor` is overwritten with the raw shoulder-hip distance every sampled frame (`:169`).
- Report card "Thời gian giữ chuẩn" uses a hard-coded 30 s target and turns green at 30000 ms
  (`bear_plank_report_builder.dart:103`, `:128`), while the default set is 3 x 15 s.
  `timeout_triggered` is always pushed as false (`bear_plank.dart:306`), so the "Hết giờ" label can
  never show.
- The report tip says lifting the knees "cao quá 10cm" is the fault
  (`bear_plank_report_builder.dart:39`); the code's limit is 0.50 torso with no cm calibration.
- Unreferenced: `BearConfig.TARGET_HOVER_MS`, `MAX_SESSION_MS` (`base:20-21`), `maxSeconds` (`:35`),
  `_exerciseStartTimeMs` (set at `:158`, never read). No report card for `back_seconds`.

---

## 13. Plank Up-Down

Source: `lib/exercise/13.Plank Up-Down/` (7 files).

**Catalog.** `plank_up_down`: 3 sets, 8 reps, `isFormChecked: true`
(`assets/data/exercise_catalog.json:224`). Definition: `PlankUpDown(maxRep: reps)`
(`exercise_definition.dart:614-615`).

**Archetype.** Rep-based, with a required 3 s hold in forearm plank and in high plank
(`HOLD_DURATION_MS = 3000`, `metrics/plank_up_down_metric_base.dart:14`). Side view, landscape only
(`plank_up_down.dart:28-32`). Defines its own `PlankConfig` and `PlankState`, unrelated to the ones
in `plank/`.

**Start position** (`:139-203`). One side with shoulder, hip, knee, ankle, elbow, wrist all
confident; the side is chosen by hip likelihood, not `cameraFacing`. If only one side is valid its
elbow angle is used for both arms (`:183-197`). Required: body angle (shoulder-hip-ankle) >= 160
(`base:18`) and both elbow angles <= 120 (`base:26`). Knee angle is not checked here.

**Stop** (`:552`). `repCount >= maxRep`, or 90 s after the first active frame (`base:13`,
`:208-215`).

**checkSafety** (`:129-135`). Not side view returns `turnSide`. Nothing else. `checkingPose`
silently returns when neither side has the six landmarks confident (`:248`).

**Rep counting** (`:333-389`). Any frame with knee angle < 140 (`base:22`) shows "Thẳng đầu gối
ra!", resets the current hold, and freezes the state machine for that frame (`:335-339`).

| Transition | Condition | Debounce |
|---|---|---|
| forearm_plank to pushing_up | forearm hold of 3 s done, and either elbow > 95 (`base:27`) | 2 |
| pushing_up to high_plank | both elbows > 150 (`base:28`) | 2 |
| high_plank to lowering | high-plank hold of 3 s done, and either elbow < 145 (`base:29`) | 2 |
| lowering to forearm_plank | both elbows < 120 (`base:26`) | 2 |

Hold gate (`:391-429`): in forearm_plank both elbows <= 120, in high_plank both >= 150, held
continuously for 3 s; leaving the pose restarts the 3 s. The rep is counted in forearm_plank once
the forearm hold after a high plank is complete (`:348-351`), so each rep, including the first and
the last, needs a 3 s forearm hold, and the counter only increments 3 s after the user is back down.

**Anti-cheat.** Bent knees freeze counting. A rep needs both 3 s holds and both elbows over 150.
There is no abort path: from `pushing_up` or `lowering` the only exits are forward.

**Faults.** All metrics run on every frame in every state (`:327-330`) with the pre-transition state
(the context is built at `:301-312`, before the state machine at `:324`). None rejects the rep.
`_completeRep(countRep: false)` and its "Không tính" text are never called (`:502`, `:537-540`).

| Type | Vietnamese message / voice | Metric and threshold | Debounce | affectsForm |
|---|---|---|---|---|
| `trunk` | "Sụt hông, mất liên kết Core" / "Sụt hông! Gồng chặt cơ bụng, đừng để lưng bị võng!" (live "Sụt hông! Gồng chặt cơ bụng") | body angle (shoulder-hip-ankle) < 150, any state (`metrics/trunk_alignment_metric.dart:19`, `base:19`) | 3 (`:10`) | true |
| `hip_rotation` | "Hông mất ổn định khi đổi tay" / "Giữ hông cố định, không lắc lư khi đẩy người!" (live "Lắc hông quá nhiều") | (max hip Y - min hip Y) since the last counted rep, over the current torso length, > 0.22 (`metrics/hip_rotation_metric.dart:20-28`, `base:32`) | none | true |
| `arm_extension` | "Chưa duỗi thẳng tay ở High Plank" / "Đẩy thẳng tay lên!" | on high_plank to lowering, both elbows were never >= 150 while in high_plank (`metrics/arm_extension_metric.dart:18-38`) | none | true |
| `alternating` | "Không đổi tay dẫn khi đẩy lên" / "Bạn nên đổi tay dẫn đẩy lên để cân bằng lực cơ." | lead arm (first pushing_up frame with one elbow > 100 and the other <= 110) equals the previous rep's lead arm (`metrics/alternating_lead_arm_metric.dart:23-54`) | none | false |

Set-log keys: `trunk_sagging_fails_count`, `hip_rotation_fails_count`, `arm_extension_fails_count`
(number of counted reps with that fault), `left_lead_count`, `right_lead_count` (`:555-566`). There
is no key for `alternating`.

**Tests.** `plank_up_down_hold_test.dart` (1 test): requires 3 second holds at high and forearm
plank before counting a rep. Registry test maps `plank_up_down` to `PlankUpDownReportBuilder`.
`test/voice/policy_voice_coach_wiring_test.dart` mentions the slug (not opened). Nothing tests the
four metrics.

**Unverified, stale, or suspicious.**
- **`arm_extension` cannot fire, by reading.** Leaving high_plank requires the 3 s high-plank hold,
  which requires both elbows >= 150 on every frame of those 3 s; the metric sets
  `_reachedFullExtension` on any such frame (`metrics/arm_extension_metric.dart:18-22`). So
  `arm_extension_fails_count` is structurally 0 and the "Duỗi tay" praise is always earned.
- **`hip_rotation` measures vertical hip travel over the whole rep**, not rotation. Going from
  forearms to hands raises the hips by design, and the range is accumulated from forearm hold through
  high plank and back (`metrics/hip_rotation_metric.dart:20-25`). By reading, a correct rep can exceed
  0.22 torso; not measured. No debounce, so a single outlier frame sets the range.
- `trunk` uses the unsigned body angle, so hips piked high also fire "Sụt hông". The 150 threshold
  equals the body-angle gate other planks use for "out of position".
- Lead-arm detection in a side view relies on the far arm's elbow angle; when only one side is
  confident both "elbows" are the same arm (`plank_up_down.dart:265-279`), so the lead arm cannot be
  told apart and the first branch (left) wins when both pass. By reading.
- `scaleFactor` is overwritten with the raw shoulder-hip distance every frame (`:259`).
- `PlankConfig.MAX_REP = 12` is unreferenced (`base:12`). Comment "15% chiều dài lưng" sits on
  0.22 (`base:32`).
- `_resetHoldTimer` on a bent-knee frame also clears a completed forearm hold, so a knee wobble after
  the hold forces another full 3 s (`:476-480`).

---

## Side Plank (`side_plank_dip`)

Source: `lib/exercise/side_plank_dip/` (7 files).

**Catalog.** `side_plank_dip` (definition `side__plank_with__hip__dip`, English name "Side Plank"):
3 sets, 1 rep, 15 s, `isFormChecked: true` (`assets/data/exercise_catalog.json:301`). Definition:
`SidePlankDip(maxHolds: reps ?? 1, holdSeconds: seconds ?? 15)`
(`exercise_definition.dart:1095-1098`), target type seconds.

**Archetype.** Static side-plank hold via `RepCountedHoldExercise`. Despite the class name, hip-dip
rep counting "is intentionally removed" (`side_plank_dip.dart:35-38`). Side view; portrait and both
landscapes allowed (`:59-64`), the only exercise in either batch that allows portrait. Entry and exit
debounce are both 1 frame (`:70`, `:73`).

**Start position** (`:142-152`). Both elbows, both shoulders, both hips and both ankles present and
confident (`:317-330`). The support side is the one whose elbow is lower in the image (`:332`).
Required:
- body angle (support shoulder-hip-ankle) >= 155 (`:9`, `:374`)
- |support shoulder X - support elbow X| <= 0.55 torso (`:10`, `:368-376`)

Each passing frame stores the shoulder and hip X-widths as the rotation baseline (`:149-150`).

**Stop.** `repCount >= maxHolds`. No timeout.

**checkSafety** (`:127-139`). Not side view returns `turnSide` and cancels re-arm. Any of the eight
landmarks missing or unconfident returns `bodyInFrame`, drops an active hold to `dropping`
(`wall_guard`) and cancels re-arm.

**Hold counting.** Shared machine. The gate is "form clean" = body straight, shoulder aligned and
rotation stable (`:179-184`): any one failing on a single frame pauses the clock, and one clean frame
resumes it. Rotation is stable when current/baseline X-width is between 0.60 and 1.55 for both
shoulders and hips (`:12-13`, `:380-402`); the check is skipped when the baseline width is under
0.05 torso (`:11`, `:386-388`).

**Faults.** The three faults are the three gate conditions. A fault is "seen" in `holding` or
`dropping` (`:194-198`) and every seen fault marks the hold `correctForm = false`. Records have
`affectsForm: true` and no `voiceMessage` (`:224-249`). None rejects the hold.

| Type (count key, seconds key) | Hold-summary message / live text | Metric and threshold | Debounce | Counts the hold? |
|---|---|---|---|---|
| `shoulder` (`shoulder_align_fails_count`, `shoulder_seconds`) | "Khuỷu tay trụ lệch khỏi vai" / "Đặt khuỷu tay trụ ngay dưới vai." | shoulder-elbow X offset > 0.55 torso (`:10`, `:375-376`) | 1 (exit gate) | yes, clock paused |
| `rotation` (`rotation_fails_count`, `rotation_seconds`) | "Thân người bị xoay" / "Giữ ngực và hông không đổ về trước hoặc sau." | shoulder or hip X-width ratio < 0.60 or > 1.55 vs baseline (`:12-13`, `:389-391`) | 1 | yes, clock paused |
| `amplitude` (`dip_depth_fails_count`, `body_line_seconds`) | "Thân người mất đường thẳng" / "Nâng hông để vai, hông và cổ chân thành một đường thẳng." | body angle < 155 (`:9`, `:374`) | 1 | yes, clock paused |

`*_fails_count` = number of holds in which the fault was seen (`:251-261`, `:284-286`).

**Tests.** `side_plank_hold_test.dart` (2 tests): a full static hold logs one engine rep; the strict
reused gate emits `amplitude` and preserves report keys. Registry test maps `side_plank_dip` and
`side__plank_with__hip__dip` to `SidePlankDipReportBuilderV2`.

**Unverified, stale, or suspicious.**
- **The `*_seconds` keys are structurally 0, by reading.** With a 1-frame exit debounce, the first
  faulting frame moves the phase to `dropping` before the accumulator runs, and the accumulator only
  runs in `holding` (`hold/rep_counted_hold_exercise.dart:180-195`). So `shoulder_seconds`,
  `rotation_seconds` and `body_line_seconds` stay 0 and `good_seconds` equals all held time.
  FIXED 2026-11-17: confirmed by test; the subclass now adds the 10-250 ms frame gaps that end on
  a faulting `dropping` frame to the three keys itself (`side_plank_dip.dart` `updateFormMetrics`);
  when the clock stops is unchanged. "Score always perfect" NOT REPRODUCED 2026-11-17: the report
  builder is rep-based (`isSecondBased` false), so the score is clean holds / holds, and one
  faulting frame already marks the hold bad (`side_plank_hold_test.dart` pins `good_rep_count` 0).
- A single jittery frame both pauses the clock and marks the whole hold bad form; there is no
  debounce anywhere in this exercise.
- The rotation baseline is the last frame that passed the start check, and it is skipped when the
  baseline X-width is below 0.05 torso. When the shoulders are stacked vertically in the image (chest
  facing the camera) that width is near 0, so rotation is likely never checked. By reading.
  CONFIRMED 2026-11-17 by reading, not changed (needs a device). Also: trunk rotation about the
  body's long axis moves the shoulders in depth and Y, not X, so the X-width ratio is a weak proxy
  even when the check runs.
- The `amplitude` / `dip_depth_fails_count` names come from the removed hip-dip version; they now
  mean "body line broken". Report praise says "rep" for holds (`side_plank_dip_report_builder_v2.dart:33-35`).
  FIXED 2026-11-17: praise says "lần giữ"; the shoulder tip no longer says "hạ hông" and the
  body-line tip no longer says only "hông hạ" (the fault is any shoulder-hip-ankle angle < 155).
  Key names unchanged.
- Dead code: `metrics/anti_rotation_metric.dart`, `metrics/hip_amplitude_metric.dart`,
  `metrics/shoulder_alignment_metric.dart` and `SidePlankState` are not imported by the exercise;
  `report/side_plank_dip_report_builder.dart` is marked "DEAD LEGACY" (`:7-8`). Their thresholds
  (twist 0.7/1.3, shallow bottom 150, shoulder offset 10/18) are not live.
  CONFIRMED 2026-11-17 by grep, not deleted: `metrics/anti_rotation_metric.dart`,
  `metrics/hip_amplitude_metric.dart`, `metrics/shoulder_alignment_metric.dart`,
  `metrics/side_plank_dip_metric_base.dart` (defines `SidePlankState`) and
  `report/side_plank_dip_report_builder.dart` are referenced only by each other.
- `scaleFactor` is overwritten every sampled frame, with 1.0 on degenerate geometry (`:169`,
  `:353-360`). `SidePlankConfig.MAX_FRAME_DELTA_MS` and `maxSeconds` are unreferenced (`:14`, `:45`).

---

## Squat

Source: `lib/exercise/squat/` (8 files).

**Catalog.** `squat`: 3 sets, 8 reps, `isFormChecked: true` (`assets/data/exercise_catalog.json:334`).
Definition: `Squat(maxRep: reps)` (`exercise_definition.dart:296-297`); the onboarding assessment
uses `Squat(maxRep: reps ?? 5)` (`:171`). Constructor default `SquatConfig.MAX_REP = 15`
(`squat.dart:29`, `:95`).

**Archetype.** Rep-based. **Portrait only** (`:74-77`), side view. `SideTrackedExerciseMixin` with
hip, shoulder, knee, ankle, foot index and heel (`:166-191`). Voice: `PolicyVoiceCoach` with the
legacy squat slug and fault ids (`:219-251`).

**Start position** (`:297-321`). Tracked side present, and:
- trunk (hip-to-shoulder) within 25 deg of vertical (`:307-309`)
- knee angle >= baseline - 2 (`:28`, `:317`). The baseline starts at 155 (`:30`, `:199-200`) and is
  overwritten with the current knee angle on every passing frame (`:318`).

**Stop** (`:350`). `repCount >= maxRep`. No timeout.

**checkSafety** (`:356-369`). Only `CameraFacing.front` returns `turnSide`; angled is accepted.
Tracked side missing returns `bodyInFrame`; any of the six landmarks unconfident returns `lighting`.

**Rep counting** (`:685-724`). Direction comes from a frame buffer that compares only the last two
frames against a 2 deg gate (`:42-43`, `lib/utils/frame_buffer.dart:34-46`) and a `StickyDebouncer`
(`:196`).

| Transition | Condition | Debounce |
|---|---|---|
| standing to descending | direction not increasing and (baseline - knee angle) > 28 (`:44-45`, `:697-701`) | sticky direction |
| descending to bottom | knee <= 115 (`:31`, `:714-717`) | 2 |
| descending to ascending | direction increasing (`:702-703`) | sticky direction |
| bottom to ascending | one frame whose buffered knee angle is increasing (`:707-711`) | none |
| descending or ascending to standing | knee > baseline and not a descending frame (`:718-723`) | 2 |

On the frame standing is reached (`:438-441`, `:464-572`): if the previous state was descending the
attempt is discarded with "Xuống thấp hơn nhé" and metrics reset without counting; otherwise the rep
counts. Reaching `bottom` is not required to count; it only decides the `depth` fault.

**Calibrated clean-rep override** (`:485-492`, `:593-640`). At rep completion, if the rep reached
bottom, the bottom-hold progress is >= 0.80 (`:41`), and the **standing frame** has knee angle
171.2 +/- 12, trunk deviation from vertical 17.43 +/- 12, trunk lean 17.43 +/- 12 and heel lift
3.081 +/- 8% of torso (`:33-40`), then all faults of the rep are cleared, it is logged as clean, and
the metrics reset without counting faults.

**Anti-cheat.** A descent that never turns into an ascent is not counted. Nothing else.

**Faults.** Metrics run only outside `standing` (`:445-450`) with the pre-transition state (context
built at `:399-411`, state machine at `:435`). `affectsForm: true` on every record. None rejects the
rep. Messages and live text are **English**; the voice line is the only Vietnamese.
FIXED 2026-11-17: every logged message, live text, phase status and result text is Vietnamese;
fault type ids unchanged (`squat_form_test.dart`).

| Type | Logged message / voice | Metric and threshold | Debounce |
|---|---|---|---|
| `depth` | "Too Shallow (Missed Depth)" / "Xuống thấp hơn" | rep counted without ever entering `bottom` (knee <= 115 for 2 frames while descending) (`metrics/squat_depth_metric.dart:90-106`) | 2 (state) |
| `trunk`, forward | "Leaned too forward" / no voice (live "Chest up!") | trunk lean > 60 deg (`metrics/trunk_lean_metric.dart:16`, `:81`) | 3 (`:22`, `:35-36`) |
| `trunk`, backward | "Leaned backward" / no voice (live "Don't lean back!") | trunk lean < -0.02 deg (`metrics/trunk_lean_metric.dart:25`, `:82`) | 5 (`:37`) |
| `heel` | "Heels lifting" / "Giữ gót chân" | (foot index Y - heel Y) / torso >= 0.18 (`metrics/heel_rise_metric.dart:19`, `:58`, `:66`) | 5 (`:32`) |
| `tempo` | "Dropped too fast (Xs)" or "Descent a bit fast (Xs)" / "Chậm lại" | descent (descending to bottom) < 0.20 s or < 0.30 s (`metrics/tempo_metric.dart:37-38`, `:186-204`) | none |
| `tempo` | "Bounced at bottom (Xs hold)" / "Chậm lại" | bottom to ascending < 0.35 s (`metrics/tempo_metric.dart:42`, `:207-217`) | none |
| `tempo` | "No eccentric control (ratio X)" / "Chậm lại" | descent / ascent < 0.35 (`metrics/tempo_metric.dart:47`, `:220-229`) | none |
| `sync` | "Hips rising much faster than shoulders" (live "Drive chest up!"), no voice | hip/shoulder upward speed ratio > 1.0, first 20 ascending frames, 3-frame window (`metrics/hip_shoulder_sync.dart:38`, `:44`, `:165-172`) | 3 (`:50`) |
| `sync` | "Hips rising a bit faster than shoulders" (live "Try to keep chest up"), no voice | ratio > 0.85 (`metrics/hip_shoulder_sync.dart:35`, `:173-179`) | 3 |
| `sync` | "Shoulders stalled while hips rose" (live "Drive chest up!"), no voice | shoulder speed < 0.6 and hip speed > 0.6 per frame (`metrics/hip_shoulder_sync.dart:47`, `:148-157`) | 3 |

Trunk lean is `convertClockAngleToTrunkLean`, positive forward (`squat.dart:391-392`,
`pose_math_helpers.dart:331-365`). Only the first `sync` message per rep is logged (`:187-189`).
Set-log keys: `heel_fails_count`, `depth_fails_count`, `trunk_lean_fails_count`, `tempo_fails_count`,
`hip_shoulder_sync_fails_count` = counted reps with that fault (`squat.dart:328-333`).

**Tests.** `squat_rep_peak_tracking_test.dart`: running rep peaks match a manual scan and keep trunk
lean correlated. `squat_side_selection_test.dart` (4 tests): valid with only the right side visible
and orientation angled; valid with the left side visible and orientation undefined; tracked side can
switch when the opposite side becomes clearer; camera facing uses z-score depth to switch sides.
`squat_report_builder_test.dart`: fault tips expose watch and next copy. Outside `test/exercise/`:
`test/services/squat_post_rep_voice_test.dart`, `test/voice/policy_voice_coach_wiring_test.dart`,
`test/screens/exercise_experience_catalog_target_test.dart` (not opened). Nothing tests the fault
thresholds or the clean-rep override.

**Unverified, stale, or suspicious.**
- **The clean-rep override erases faults based on the final standing frame, by reading.** It does
  not look at the rep's depth, lean or tempo; it compares the frame where standing was detected
  against constants that look fitted to one recording (171.2, 17.43, 3.081). At that point the
  ascent has started, so `bottomHoldProgress` is null and the progress gate reduces to "bottom hold
  >= 0.35 s" (`squat.dart:282-291`, `:602-603`, `metrics/tempo_metric.dart:266-271`). A rep that
  reached bottom and paused 0.35 s, then finishes with 5-29 deg of forward lean, is logged clean whatever
  `trunk`, `heel`, `tempo` or `sync` fired during it. Not covered by any test.
  FIXED 2026-11-17: confirmed by test (a heel fault was erased); the override, its `CLEAN_REP_*`
  constants and helpers are removed. Rep completion is otherwise unchanged.
- **`sync` "a bit faster" is logged as a form fault at ratio > 0.85**, i.e. when the hips rise at
  85% of the shoulders' speed or more. Hips and shoulders rising together give a ratio near 1.0. The
  header's own adjustment ("Expand Good to 0.8-1.4", `metrics/hip_shoulder_sync.dart:21-22`) is not
  applied. Speeds are raw image units per frame, not normalized by torso or frame rate
  (`:132-141`), so 0.6 means different things on different devices. By reading.
- `tempo` "Descent a bit fast" (0.20-0.30 s) is a near-miss in the live UI but is logged with
  `affectsForm: true` (`metrics/tempo_metric.dart:195-203`, `:254-260`).
- `trunk` backward fires at -0.02 deg, i.e. any backward value for 5 frames. In an angled view
  `convertClockAngleToTrunkLean` returns 0 (`pose_math_helpers.dart:364`), so trunk lean is never
  checked and the clean-rep override can never match, and angled views pass `checkSafety`.
- `heel` header says "INFORMATIONAL ONLY — does NOT mark correctForm = false"
  (`metrics/heel_rise_metric.dart:8-10`); the record has `affectsForm: true` (`:86`). Comment "3
  frames" on a 5-frame debouncer (`:31-32`).
  FIXED 2026-11-17 (comments only): the header now says the record marks bad form and the debounce
  comment says 5 frames. `affectsForm` is unchanged (owner decision).
- The standing threshold is "knee > baseline" with no tolerance (`squat.dart:718`), where baseline is
  the knee angle on the last start-position frame. If the user stood very straight during setup, the
  rep may not close. By reading.
- A direction flip during the descent moves the state to `ascending` before `bottom`; going deeper
  afterwards cannot enter `bottom`, so the rep is logged "Too Shallow". By reading.
- `bottom` to `ascending` has no debounce, so a single noisy frame ends the bottom hold and can
  trigger "Bounced at bottom".
- Leaving `standing` needs at least one frame whose knee angle dropped more than 2 deg since the
  previous frame. A descent slower than 2 deg per frame reads as "stable" throughout; by reading it
  then never leaves `standing` and no rep is counted. Depends on frame rate; not measured.
- `scaleFactor` is overwritten with the raw shoulder-hip distance every frame (`:386`).
- Report tip "giữ 2 giây trước khi lên" (`squat_report_builder.dart:34`) vs a 0.35 s bottom hold.
  `SQUAT_BOTTOM_ANGLE_THRESHOLD[0] = 70` only drives the live text "Deep Squat!".
  FIXED 2026-11-17: tip now says "dừng ở đáy khoảng 0,35 giây"; the live text is now "Xuống rất sâu!".

---

## Push-Up

Source: `lib/exercise/push up/` (6 files).

**Catalog.** `push_up`: 3 sets, 10 reps, `isFormChecked: true` (`assets/data/exercise_catalog.json:246`).
Definition: `PushUp(maxRep: reps)` (`exercise_definition.dart:409-410`).

**Archetype.** Rep-based. Side view, landscape only (`push_up.dart:219-223`).
`SideTrackedExerciseMixin` with shoulder, elbow, wrist, hip, knee, ankle required and heel, foot
index optional (included only when confident) (`:143-180`). Voice: `PolicyVoiceCoach`, slug
`push_up`, fault ids `depth`, `tempo`, `sag` (`:70-74`, `:192-216`).

**Start position** (`:245-257`, `:871-924`), "high plank setup":
- horizontal: |shoulder X - ankle X| > 1.2 x |shoulder Y - ankle Y| (`:856-857`)
- floor support (`:914-924`): support Y = the **smallest** (highest in the image) of wrist, heel and
  foot Y (`:846`); wrist within 0.40 torso of it, wrist >= 0.50 torso below the shoulder, support >=
  0.10 torso below the hip (`:50-52`)
- elbow (shoulder-elbow-wrist) >= 155 (`:47`)
- shoulder-hip-knee >= 160 (`:48`); hip-knee-ankle >= 150 (`:49`)
- arm-to-body (hip-shoulder-wrist) 40 to 140 (`:904`)

Each failure has its own Vietnamese prompt (`:872-909`), shown while in `plank` (`:358-360`).
Passing frames capture the wrist and heel Y anti-cheat baselines and the top elbow baseline
(`:793-797`). The top baseline is max(elbow, 160) and is refreshed on every clean plank frame with
elbow >= 160 (`:350-358`, `:799-805`).

**Stop** (`:262`). `repCount >= maxRep`. No timeout.

**checkSafety** (`:288-303`). Only `CameraFacing.front` returns `turnSide`. Tracked side missing
returns `bodyInFrame`; any returned landmark unconfident returns `lighting`.

**Rep counting** (`:533-589`). Direction from a frame buffer comparing the last two frames against a
2 deg gate (`:40`, `lib/utils/frame_buffer.dart:34-46`) and a 2-frame `StickyDebouncer` (`:125`).
As with Squat, a descent slower than 2 deg per frame never leaves `plank` (by reading).

| Transition | Condition | Debounce |
|---|---|---|
| plank to descending | not extending, and (top baseline - elbow) > 30 (`:41`, `:543-545`) | sticky 2 |
| descending to ascending, and back | direction flips (`:575-579`) | sticky 2 |
| descending to bottom | elbow <= 115 (`:33`, `:546-547`) | 2 |
| bottom to ascending | one extending frame (`:584-585`) | none |
| descending or ascending to plank | elbow >= top baseline - 8 and not a bending frame (`:42`, `:548-552`) | 2 |

On return to `plank` (`:394-490`): a rejected cycle is not counted ("Lần này chưa tính nhé" plus the
reason, `push_up_guard_rejects_count` += 1); a cycle that never reached `bottom` is not counted
("Xuống thấp hơn nhé"); otherwise the rep counts.

**Anti-cheat** (all reject the cycle, `:647-745`):

| Reject type | Vietnamese reason | Condition | Debounce |
|---|---|---|---|
| `BodyLine` | "Giữ vai, hông, gối, cổ chân thẳng hàng" | shoulder-hip-knee < 150 or hip-knee-ankle < 150 (`:56`, `:926-936`) | 4 (`:127`) |
| `Wrist` | "Giữ cổ tay ở cùng vị trí, không đổi sang chống tường" | \|wrist Y - start baseline\| > max(0.22 torso, 18 px) (`:59-60`, `:943-946`) | 5 (`:128`) |
| `Heel` | "Giữ chân ở cùng vị trí, không nâng hoặc đổi điểm chống" | \|heel Y - start baseline\| > max(0.28 torso, 24 px); heel falls back to ankle (`:61-62`, `:814`) | 5 (`:129`) |
| `KneeMotion` | "Di chuyển cả thân người, không chỉ gập khuỷu tay" | descending with elbow bent > 30 while shoulder, hip and knee Y are all stable and unmoved from the rep start (gate max(0.015 torso, 1.5 px)) (`:43-44`, `:714-728`) | 5 (`:130`) |
| `KneeMotion` | same | entering `bottom` without any body movement seen this rep (`:615-622`) | none |

**Faults.** Metrics run outside `plank` (`:383-387`) with the pre-transition state (context at
`:319-327`, state machine at `:372`). None rejects the rep.

| Type | Vietnamese message / voice | Metric and threshold | Debounce | affectsForm |
|---|---|---|---|---|
| `sag` | "Hông hơi chùng" / "Siết cơ bụng" | trunk deviation > +12 (`metrics/trunk_alignment_metric.dart:35`, `:78-80`) | 5 (`:54`) | true |
| `sag` | "Hông hơi võng" / "Siết cơ bụng" | > +16 (`:36`, `:81`) | 5 | true |
| `sag` | "Lưng võng quá mức — nguy hiểm" / "Siết cơ bụng" (live "DỪNG LẠI! Lưng võng quá nhiều!") | > +25 (`:37`, `:82`) | 5 | true |
| `sag` (pike) | "Hông hơi cao" / "Hạ hông xuống" | deviation < -6 (`:41`, `:85-87`) | 5 (`:55`) | true |
| `sag` (pike) | "Hông quá cao" / "Hạ hông xuống" | < -10 (`:42`, `:88-89`) | 5 | true |
| `depth` | "Hơi nông (X°)" / no voice | min elbow > 115 (`metrics/depth_metric.dart:106-113`) | none | false |
| `depth` | "Quá nông (X°)" / no voice | min elbow > 125 (`metrics/depth_metric.dart:27`, `:94-101`) | none | true |
| `tempo` | "Hạ hơi nhanh (Xs)" / no voice | descent (descending to bottom) < 0.6 s (`metrics/tempo_metric.dart:25`, `:119-121`) | none | true |
| `tempo` | "Thả rơi quá nhanh (Xs)" / no voice | descent < 0.3 s (`metrics/tempo_metric.dart:26`, `:115-117`) | none | true |

Trunk deviation = hip-to-shoulder clock angle minus 90 (facing left) or 270 (facing right), wrapped
(`push_up.dart:36-37`, `:823-830`). Set-log keys `trunk_alignment_fails_count`,
`depth_fails_count`, `tempo_fails_count` = counted reps with that fault (`:266-270`).

**Tests.** `push_up_anti_cheat_test.dart` (5 tests): start position requires a full high plank with
knees off the floor; counts a full-body push-up with elbow ROM and knee travel; rejects elbow-only
motion while the body stays pinned; rejects a rep when wrist height drifts; rejects a rep when heel
height drifts. Nothing tests `sag`, `depth` or `tempo`.

**Unverified, stale, or suspicious.**
- **Plank and Push-Up use opposite head-direction conventions for the same `cameraFacing`.** Plank
  targets 270 for left and 90 for right (`plank.dart:25-26`); Push-Up targets 90 for left and 270 for
  right (`push_up.dart:36-37`). The unit tests encode both: the plank test uses facing right with the
  shoulder at higher X than the hip (`plank_anti_cheat_test.dart:29-30`, `:107`), the push-up test
  facing left with the same layout (`push_up_anti_cheat_test.dart:35-36`, `:129`). For a given user
  and camera at most one can be right. In the other, a level trunk reads as about 180 deg off: Plank
  would never pass its 35 deg start gate; Push-Up would log `sag` ("Lưng võng quá mức" or "Hông quá
  cao", depending on which side of 180 the angle falls) on every rep. Which one is wrong depends on
  `detectCameraFacing`'s z-vote and on image mirroring, not traced here. On top of this, the
  sag/pike sign mirrors between the two facings exactly as described under Plank.
  FIXED 2026-11-17: Push-Up was the inverted one (its constants were flipped in c38d613 together
  with a right-side-only test fixture labelled facing left). Now 270 for left, 90 for right, and the
  deviation is negated for facing right so positive = sag; the anti-cheat fixture is labelled facing
  right; `push_up_form_test.dart` checks one posture in both facings.
- **`depth` cannot fire on a counted rep, by reading.** A rep only counts after `bottom`, which needs
  elbow <= 115 on 2 frames while descending; the metric records the minimum on those frames, so the
  minimum is always <= 115 and both depth checks (> 115, > 125) fail. `depth_fails_count` is
  structurally 0. Shallow reps are instead not counted ("Xuống thấp hơn nhé").
  FIXED 2026-11-17: confirmed by test; the report builder no longer praises, tips or pain-maps depth,
  and `depth_fails_count` is no longer pushed (contract test updated).
- Support Y is the minimum (highest point) of wrist, heel and foot (`:846`), so the floor check
  requires all three to be below the hip; the names `kneeSupportClearance` and `hipSupportClearance`
  are computed but never used for a decision (`:865-866`).
- `tempo` "Hạ hơi nhanh" (0.3-0.6 s) is logged with `affectsForm: true`; the header says "Do NOT
  penalize slow descents" and frames tempo as coaching (`metrics/tempo_metric.dart:13-17`). Descent
  is timed only to `bottom`, so with no bottom there is no tempo check.
- `bottom` to `ascending` has no debounce.
- Comment ranges disagree with code: depth "80°-100°" / "100°-110°" / "> 110°"
  (`metrics/depth_metric.dart:22`, `:26`, `:29`) vs 115 / 125.
  FIXED 2026-11-17: comments say 80-115 / 115-125 / > 125.
- `scaleFactor` is overwritten every frame with the raw torso length (`:315`).
- Unreferenced: `ACTIVE_SHOULDER_ABOVE_WRIST_RATIO`, `ACTIVE_KNEE_SUPPORT_CLEARANCE_RATIO`
  (`:57-58`). In debug mode the exercise writes a CSV trace to disk (`:977-1035`).
  FIXED 2026-11-17: both constants removed.

---

## Wall Push-Up

Source: `lib/exercise/wall_push_up/` (9 files).

**Catalog.** `wall_pushup` (definition `wall_push_up`): 3 sets, 10 reps, `isFormChecked: true`
(`assets/data/exercise_catalog.json:422`). Definition: `WallPushUp(maxRep: reps)`
(`exercise_definition.dart:1284-1285`); onboarding assessment `WallPushUp(maxRep: reps ?? 5)`
(`:200`).

**Archetype.** Rep-based. Side view. No `supportedOrientations` override, so **portrait only** (base
default, `exercise_base.dart:286-287`). Voice: `PolicyVoiceCoach`, slug `wall_push_up`, fault ids
`body_line`, `foot`, `heel`, `shoulder`, `elbow`, `head`, `cervical`, `hand`, `tempo`
(`wall_push_up.dart:316-326`, `:433-463`).

**Start position** (`:485-610`). Camera-side shoulder, hip, elbow, wrist and ankle present (not
confidence-checked), and:
- shoulder above hip (`:533`)
- shoulder-to-ankle line at least 25 deg off horizontal (`:62`, `:538-546`): "Đứng nghiêng người vào
  tường, không chống đẩy dưới sàn."
- |wrist Y - shoulder Y| <= 0.55 torso (`:64`, `:548-553`): "Đặt tay ngang vai hoặc lệch nhẹ, không
  quá cao hoặc quá thấp."
- elbow >= 135 (`:60`); body line (shoulder-hip-ankle) >= 128 (`:61`)
- heel and foot index confident (else "Giữ gót và mũi chân rõ trong khung hình.") and **heel raised**:
  (foot index Y - heel Y) / torso >= 0.01 (`:65`, `:565-576`, `:1102-1116`), else "Kiễng gót chân lên,
  dồn lực vào mũi chân."

Passing frames store per-metric baselines (shrug ratio, forward-head angle, neck tilt, foot anchor,
wrist anchor, torso length); they are pushed into the metrics at activation (`:578-627`).

**Stop** (`:632`). `repCount >= maxRep`. No timeout.

**checkSafety** (`:659-694`). Not side view returns `turnSide`. Camera-side shoulder, elbow, wrist
or hip missing returns `bodyInFrame`; any of them unconfident returns `lighting`.

**Rep counting** (`:1067-1085`), elbow angle only:

| Transition | Condition | Debounce |
|---|---|---|
| standing to descending | elbow < 135 (`:54`) | 2 (`:338`) |
| descending to bottom | elbow <= 132 (`:56`) | none |
| bottom to ascending | elbow > 136 (`:57`) | none |
| ascending or descending to standing | elbow > 138 (`:53`) | none |

On return to standing (`:843-947`) the attempt is not counted ("Lần này chưa tính nhé") when:
- the minimum elbow this rep is missing or > 132: "Chưa xuống đủ sâu — gập khuỷu tay rõ hơn." /
  voice "Xuống thấp hơn" (`:1021-1024`)
- the shoulder-to-foot line was under 20 deg from horizontal for 4 frames during the rep: "Đây chưa
  giống Wall Push Up — hãy đứng nghiêng người vào tường." / voice "Đứng nghiêng vào tường" (`:63`,
  `:339-340`, `:950-959`, `:1030-1032`)

**Faults.** Metrics run outside `standing` (`:950-963`) with the pre-transition state (context at
`:802-823`, state machine at `:840`). None rejects the rep.

| Type (count key) | Vietnamese message / voice | Metric and threshold | Debounce | affectsForm |
|---|---|---|---|---|
| `body_line` (`body_line_fails_count`) | "Vai-hông-chân hơi lệch" / "Giữ thân thẳng" | shoulder-hip-foot anchor angle 140 to < 150 (`metrics/body_line.dart:31-32`, `:63-65`) | 8 (`:43`) | false |
| `body_line` | "Vai-hông-chân lệch khỏi đường thẳng" / "Giữ thân thẳng" | angle < 140 | 10 (`:44`) | true |
| `shoulder` (`shoulder_shrug_fails_count`) | "Vai hơi nhún" / "Hạ vai xuống" | (baseline - current ear-shoulder/torso) / baseline > 0.18 (`metrics/shoulder_shrug.dart:27`, `:61-67`) | 10 (`:38`) | false |
| `shoulder` | "Nhún vai quá mức" / "Hạ vai xuống" | shrink > 0.28 (`:28`) | 12 (`:39`) | true |
| `head` (`forward_head_fails_count`) | "Đầu hơi đưa về trước" / "Kéo cằm về" | baseline minus ear-shoulder-hip angle > 18 (`metrics/forward_head.dart:23`, `:56-61`) | 12 (`:35`) | false |
| `head` | "Đầu đưa về trước nhiều" / "Kéo cằm về" | deviation > 28 (`:24`) | 12 | false |
| `elbow` (`elbow_flare_fails_count`) | "Khuỷu tay hơi rộng" / "Ép khuỷu tay vào" | hip-shoulder-elbow > 65, descending or bottom, elbow < 140 (`metrics/elbow_flare.dart:28`, `:32`, `:54-69`) | 8 (`:42`) | false |
| `elbow` | "Khuỷu tay mở rộng — hại vai" / "Ép khuỷu tay vào" | > 82 (`:29`) | 8 | true |
| `cervical` (`cervical_extension_fails_count`) | "Cổ hơi ngửa" / "Giữ cổ thẳng" | baseline minus nose-ear-shoulder angle > 22, descending or bottom (`metrics/cervical_extension.dart:28`, `:58-70`) | 10 (`:39`) | false |
| `cervical` | "Ngửa cổ nhìn lên" / "Giữ cổ thẳng" | > 35 (`:29`) | 10 | false |
| `foot` (`foot_stationary_fails_count`) | "Chân hơi di chuyển" / "Giữ chân cố định" | horizontal foot-anchor drift > 0.30 torso (`metrics/foot_stationary.dart:26`, `:77-100`) | 8 (`:37`) | false |
| `foot` | "Chân di chuyển khi tập" / "Giữ chân cố định" | drift > 0.45 torso (`:27`) | 10 (`:38`) | true |
| `heel` (counted in `foot_stationary_fails_count`) | "Gót chân chưa kiễng" / "Kiễng gót chân lên" | (foot index Y - heel Y) / torso < 0.01 (`metrics/foot_stationary.dart:125-143`, `wall_push_up.dart:65`) | 6 (`:39`) | true |
| `hand` (`wall_contact_fails_count`) | "Tay bị di chuyển — giữ tay cố định trên tường." / "Chống tay vào tường" | wrist drift relative to the foot anchor (or the image, if no foot) > 0.14 setup torso (`metrics/wall_contact.dart:20`, `:80-97`, `:126-128`) | 8 (`:30`) | true |
| `tempo` (`tempo_fails_count`) | "Hạ quá nhanh (Xs)" / "Chậm lại" | descending to bottom < 0.3 s (`wall_push_up.dart:221`, `:284-300`) | none | false |

The foot anchor is the average of whichever of ankle, heel and foot index are present, without a
confidence check (`:768`, `:1118-1130`).

**Tests.** `wall_push_up_anti_cheat_test.dart` (4 tests): start position rejects floor-like
push-ups; counts only after a full bottom-to-standing rep; counts a rep but records coaching when the
wall hand drifts; counts a rep when the body line bends. Outside `test/exercise/`:
`test/services/recommendation/fitness_test_scoring_test.dart`,
`test/screens/exercise_experience_catalog_target_test.dart`,
`test/voice/policy_voice_coach_wiring_test.dart` (not opened).

**Unverified, stale, or suspicious.**
- **Raised heels are required.** The start gate refuses flat feet and, during reps, flat heels for 6
  frames log `heel` with `affectsForm: true`. A wall push-up with heels down is marked bad form on
  every rep. Whether this is the intended exercise standard was not found in code comments; it is
  the threshold a coach would most likely disagree with. The `heel` faults roll into
  `foot_stationary_fails_count`, so the report's "Chân đứng yên" figure mixes stepping and heels.
  FIXED 2026-11-17: owner default applied: flat heels pass the start gate and are no longer logged; `foot_stationary` stepping check unchanged.
- Almost every comment disagrees with its constant: body line 155/145 (`metrics/body_line.dart:21-24`)
  vs 150/140; shrug "12% / 18%" written next to 0.18 / 0.28 (`metrics/shoulder_shrug.dart:13-17`,
  `:27-28`); forward head 12/18 (`metrics/forward_head.dart:11-16`) vs 18/28; cervical 15/25
  (`metrics/cervical_extension.dart:17-21`) vs 22/35; elbow flare 55/70 and "elbowAngle < 150°"
  (`metrics/elbow_flare.dart:14-21`) vs 65/82 and 140; foot 20%/30% (`metrics/foot_stationary.dart:13-16`)
  vs 0.30/0.45; wall contact 8% (`metrics/wall_contact.dart:9-11`) vs 0.14; tempo "0.5s"
  (`wall_push_up.dart:216`) vs 0.3; start "elbow angle > 155°" (`:555`) vs 135.
  FIXED 2026-11-17: metric headers, start-elbow and tempo comments now match the constants.
- The depth (Check 6) and lockout (Check 8) evaluations are empty: `_evaluateDepth` and
  `_evaluateLockout` contain only comments (`:994-1018`), so `DEPTH_GOOD_MAX`, `DEPTH_SHALLOW_MAX`,
  `LOCKOUT_GOOD_MIN`, `LOCKOUT_WARN_MIN` (`:73-80`) have no effect.
  FIXED 2026-11-17: empty functions and their constants removed; no report card presented them.
- The "Chưa đẩy tay thẳng về vị trí ban đầu." rejection is unreachable: it needs elbow <= 138 on the
  frame that entered standing, which requires elbow > 138 (`:1026-1028`, `:1080`).
  FIXED 2026-11-17: confirmed unreachable and removed.
- The state machine has a 132/136/138 deg hysteresis with no debounce after entry, so noise around
  those values can flip states. By reading.
- `onExerciseActivated` does not call `super.onExerciseActivated()` (`:614-627`), as V-Up in batch 1.
  FIXED 2026-11-17: super call added; it starts the base session stopwatch (`elapsedMs`), which nothing in Wall Push-Up reads.
- `scaleFactor` is not written here; it is only a fallback when the shoulder-hip distance is 0
  (`:819`).
- `shoulderHandClosure` and `bodyFootAngle` are computed for debug only (`metrics/wall_contact.dart:99-111`,
  `metrics/foot_stationary.dart:87-93`).

---

## Glute Bridge

Source: `lib/exercise/glute bridge/` (7 files).

**Catalog.** `glute_bridge`: 3 sets, 10 reps, `isFormChecked: true`
(`assets/data/exercise_catalog.json:103`). Definition: `GluteBridge(maxRep: reps)`
(`exercise_definition.dart:438-439`).

**Archetype.** Rep-based. Side view, landscape only (`glute_bridge.dart:252-256`).
`SideTrackedExerciseMixin` with shoulder, hip, knee, ankle required and ear optional (`:142-167`).
Voice: `PolicyVoiceCoach`, slug `glute_bridge`, fault ids `hip_extension`, `hyperextension`,
`knee_angle`, `speed_control`, `neck_head` (`:85-91`, `:201-243`).

**Start position** (`:285-320`). Tracked side present, and:
- shoulder-to-hip line within 28 deg of horizontal (`:53`, `:297-299`)
- knee angle (hip-knee-ankle) 60 to 160 (`:56-57`)
- |hip Y - shoulder Y| <= 0.55 x `scaleFactor`, or 55 px if `scaleFactor` is 0 (`:60-61`, `:311-314`)

The hip Y of the last passing frame is the rep baseline (`:317`).

**Stop** (`:326-328`). `repCount >= maxRep`. No timeout.

**checkSafety** (`:350-386`). Not side view returns `turnSide`. If the tracked bundle is complete,
null. Otherwise camera-side shoulder, hip or knee missing returns `bodyInFrame`, unconfident returns
`lighting`; if only the ankle is the problem it returns null and `checkingPose` silently skips the
frame (`:397-398`).

**Rep counting** (`:602-665`). Driven by hip-Y velocity averaged over 5 frame-to-frame differences,
in pixels per frame scaled to 30 fps (`:534-549`). Negative = rising.

| Transition | Condition | Debounce |
|---|---|---|
| bottom to ascending | velocity < -1.8 px/frame (`:30`) | 3 (`:123`) |
| ascending to topHold | \|velocity\| < 2.0 (`:32`) and hip > 0.07 x `scaleFactor` above baseline (`:36`) | 5 (`:124`) |
| ascending to descending | velocity > 1.8 (`:31`) and hip elevated | 3 (`:125`) |
| ascending to bottom (abort, no rep) | at rest and hip within 0.12 x `scaleFactor` of baseline (`:42`) | 3 (`:126`) |
| topHold to descending | velocity > 1.8 | 3 |
| descending to bottom, **rep counted** | at rest and within 0.12 of baseline (`:654-656`) | 3 |
| descending to ascending, **rep counted** | velocity < -1.8 (`:659-661`) | 3 |

Every cycle that got 0.07 torso above baseline counts. There is no top-hold minimum time.

**Anti-cheat.** Only the 0.07 torso elevation gate.

**Faults.** `update` runs outside `bottom`, `onBottomFrame` in `bottom` (`:499-507`), with the
pre-transition state (context at `:463-476`, state machine at `:494`). Peak values are a one-frame
snapshot at the highest hip point during ascending or topHold (`:446-454`). None rejects the rep. No
fault record carries a `voiceMessage` except `hip_extension`.

| Type (count key) | Vietnamese message / voice | Metric and threshold | Debounce | affectsForm |
|---|---|---|---|---|
| `hip_extension` (`hip_extension_fails_count`) | "Cố gắng nâng hông thêm một chút" / "Nâng hông cao hơn" | peak shoulder-hip-knee angle < 152 (`metrics/glute_bridge_hip_extension.dart:36`, `:131-141`) | none (peak frame) | false |
| `hip_extension` | "Nâng hông cao hơn — co mông tối đa" / "Nâng hông cao hơn" | peak angle < 140 (`:37`) | none | true |
| `hyperextension` (`hip_extension_fails_count`) | "Không ưỡn lưng — ép lưng vào sàn" | hip above the shoulder-knee line by > 0.045 of the shoulder-knee length, during ascending or topHold (`:43`, `:79-98`) | 6 (`:46`) | true |
| `hyperextension` | same | same value on the peak frame (`:119-128`) | none | true |
| `knee_angle` (`knee_angle_fails_count`) | "Di chân ra xa hông hơn — duỗi gối nhiều hơn" | peak-frame knee angle < 55 (`metrics/glute_bridge_knee_angle.dart:41`, `:112-119`) | none | true |
| `knee_angle` | "Di chân ra xa hông thêm để giảm áp lực hamstring" | 55 to < 85 (`:35`, `:120-127`) | none | false |
| `knee_angle` | "Di chân lại gần hông một chút" | > 145 (`:39`, `:128-137`) | none | false |
| `speed_control` (`speed_control_fails_count`) | "Hạ hông quá nhanh — siết cơ lõi để kiểm soát" | peak descent velocity / `scaleFactor` >= 0.15 per 30-fps frame (`metrics/glute_bridge_speed_control.dart:46`, `:159-166`) | none | true |
| `speed_control` | "Kiểm soát tốc độ hạ hông để bảo vệ lưng" | >= 0.08 on 5 consecutive descending frames (`:45`, `:49`, `:101-109`, `:167-174`) | 5 | false |
| `speed_control` | "Hạ hông chậm lại — mục tiêu kiểm soát gấp đôi thời gian nâng" | eccentric / concentric duration < 1.3 and no velocity fault (`:41`, `:181-198`) | none | false |
| `neck_head` (`neck_head_fails_count`) | "Giữ đầu và cổ trên sàn khi thực hiện bài tập" | (shoulder Y - ear Y, else nose Y) > 0.14 x `scaleFactor`, every phase including bottom (`metrics/glute_bridge_neck_head.dart:42`, `:85-114`) | 10 (`:50`) | true |

**Tests.** `glute_bridge_hip_extension_metric_test.dart` (10 tests across hip extension, knee
angle, speed control): pins the thresholds 152/140, 85/55/145 and 1.3, and checks the soft/hard
split of each band directly on the metric classes. `glute_bridge_guidance_signal_test.dart` (4
tests): `turnSide` when not side-on; `bodyInFrame` when core landmarks miss; `lighting` on low
confidence; far-side occlusion still proceeds. `glute_bridge_voice_policy_test.dart`: old faults are
not replayed before the current set. `exercise_logging_alignment_test.dart` covers its score keys.
Nothing tests the state machine, the hyperextension deviation sign, `neck_head`, or the velocity
units. Further mentions in `test/voice/` and `test/services/recommendation/` were not opened.

**Unverified, stale, or suspicious.**
- `scaleFactor` is not written here; the exercise reads the base class's smoothed value
  (`exercise_base.dart:556-560` documents that Glute Bridge depends on it).
- State-machine velocities are pixels per frame, not normalized by body size (`:30-32`), so the
  same movement crosses 1.8 px/frame at different speeds depending on camera distance and
  resolution. The `speed_control` velocities, by contrast, are divided by `scaleFactor`.
- **`speed_control` velocity faults are probably unreachable, by reading.** 0.15 torso per 30-fps
  frame is 4.5 torso/s averaged over 5 frames, i.e. more than a whole bridge's hip travel inside one
  5-frame window; 0.08 for 5 frames is similar. In practice only the duration-ratio branch
  (`affectsForm: false`) can fire. Not measured.
- `neck_head` runs in `bottom` too, so a head lift while resting between reps is attached to the
  next rep (faults reset only at rep completion, `:749-751`). If neither ear nor nose is confident,
  head Y falls back to shoulder Y and the check cannot fire (`:410-414`). Comment records the 0.14
  value as a device "feel-tune", "Not canonical" (`metrics/glute_bridge_neck_head.dart:37-41`).
  FIXED 2026-11-17: confirmed by test; `onBottomFrame` no longer evaluates and restarts the 10-frame
  debounce, so resting frames neither log nor count toward the next rep. 0.14 unchanged.
- The knee-angle header says feet too far means hamstring dominance and feet too close means quad
  dominance (`metrics/glute_bridge_knee_angle.dart:6-7`), but its own cited EMG numbers say the more
  acute knee has more hamstring activity (`:9-11`), and the < 55 branch is commented "legs nearly
  straight — pure hamstring" (`:113`) when < 55 is a very bent knee. The messages ("move feet
  further" below 85, "closer" above 145) follow the geometry, not the comments.
- `hip_extension`, `knee_angle` and the peak hyperextension check read one frame (highest hip), so a
  single noisy frame decides them.
- The speed-control message says "gấp đôi thời gian nâng" (twice the lift time); the code
  threshold is 1.3x (`:41`, `:195`).
  FIXED 2026-11-17: message says "thời gian hạ nên dài ít nhất 1,3 lần thời gian nâng".
- Comments disagree with code: start knee "70–150°" (`glute_bridge.dart:280`, `:301`) vs 60-160;
  the state-machine header counts the rep at topHold to descending (`:598-599`), the code counts it
  on leaving descending. Unreferenced: `HORIZONTAL_CLOCK_LEFT`, `HORIZONTAL_CLOCK_RIGHT`,
  `HORIZONTAL_TOLERANCE` (`:48-52`).
  FIXED 2026-11-17: comments say 60–160° and count the rep on leaving `descending` (to bottom or
  straight into the next ascent); the three constants are removed.
- REST (|v| < 2.0) overlaps the ascending/descending thresholds (|v| > 1.8), so a frame between 1.8
  and 2.0 px/frame is both "moving" and "at rest".

---

## Lunge

Source: `lib/exercise/lunge/` (7 files).

**Catalog.** `lunge`: 3 sets, 10 reps, `isFormChecked: true` (`assets/data/exercise_catalog.json:169`).
Definition: `Lunge(maxRep: reps)` (`exercise_definition.dart:353-354`). Constructor default
`LungeConfig.MAX_REP = 15` (`lunge.dart:22`, `:65`).

**Archetype.** Rep-based, stationary lunge. Side view, **portrait only** (`:57-61`). Voice:
`PolicyVoiceCoach`, slug `lunge`, fault ids `depth`, `trunk`, `lumbar`, `heel` (`:50-55`,
`:158-179`).

**Lead leg** (`:89-110`). With facing left the left leg leads if its ankle has the smaller X; with
facing right, the larger X. A 5-frame `StickyDebouncer` starting at "left" smooths it; it is locked
from the start of a descent until standing (`:635-645`). In angled or front views the previous
value is kept.

**Start position** (`:280-316`). `cameraFacing` left or right; camera-side shoulder, hip, knee
present; trunk (hip-to-shoulder) within 25 deg of vertical; shoulder-hip-knee angle >= 155
(`:23`, `:311-313`), measured with the unnormalized `calculateAngle`. The comment says "Legs roughly
straight" but no knee angle is checked.

**Stop** (`:201`). `repCount >= maxRep`. No timeout.

**checkSafety** (`:221-275`). Only `CameraFacing.front` returns `turnSide`. Any of 12 landmarks
missing (both hips, shoulders, knees, ankles, foot indices, heels) returns `bodyInFrame`; any of them
unconfident returns `lighting`.

**Rep counting** (`:613-629`). Lead knee angle (hip-knee-ankle), **no debounce on any transition**.

| Transition | Condition |
|---|---|
| standing to descending | lead knee < 145 (`:24`) |
| descending to bottom | 55 <= lead knee <= 125 (`:25`) |
| bottom to ascending | lead knee > 125 (`:26`) |
| ascending or descending to standing | lead knee > 155 (`:23`) |

On the frame after standing is reached (`:401-491`): if `bottom` was never entered the attempt is
discarded ("Không tính", `rejected_shallow_attempts_count`); otherwise the rep counts.

**Anti-cheat.** Only the bottom gate.

**Faults.** Metrics run outside `standing` (`:497-501`) with the pre-transition state (context at
`:369-382`, state machine at `:494`). All `affectsForm: true`. None rejects the rep. Logged messages
are **English**.
  FIXED 2026-11-17: every logged message and the result text are Vietnamese (`lunge_form_test.dart`).

| Type (count key) | Logged message / voice (live text) | Metric and threshold | Debounce |
|---|---|---|---|
| `depth` (`depth_fails_count`) | "Too deep! Come up a bit" / none ("Quá sâu! Đứng lên một chút") | lead knee < 55 on any frame, or minimum < 55 at completion (`metrics/lunge_depth_metric.dart:24`, `:57-60`, `:89-92`) | none |
| `depth` | "Not deep enough" / "Xuống thấp hơn" | minimum lead knee > 125 at completion (`:21`, `:85-87`) | none |
| `trunk` (`trunk_lean_fails_count`) | "Chest up! Core collapse" / none ("Nâng ngực lên!") | trunk lean >= 56 deg (`metrics/lunge_trunk_lean_metric.dart:25`, `:68-69`) | 12 (`:40`) |
| `trunk` | "Don't lean back!" / none ("Đừng ngả ra sau!") | trunk lean < -10 (`:28`, `:75`) | 8 (`:42`) |
| `heel` (`heel_lift_fails_count`) | "Heel slightly lifting" / "Giữ gót chân" ("Gót hơi nhấc — ấn gót xuống") | (lead foot index Y - lead heel Y) / `scaleFactor` > 0.10, descending or bottom (`metrics/lunge_heel_lift_metric.dart:22`, `:51-82`) | 12 (`:36`) |
| `heel` | "Keep your heel down!" / "Giữ gót chân" ("Giữ gót chân chạm sàn!") | ratio > 0.16 (`:25`, `:63-71`) | 12 (`:37`) |
| `lumbar` (`lumbar_proxy_fails_count`) | "Lower back arching! Brace core!" / none ("Lưng đang võng! Gồng cơ bụng!") | in `bottom`: shoulder-hip-trail-knee angle < 125 and trunk lean < 5 (`metrics/lunge_lumbar_proxy_metric.dart:31`, `:35`, `:60-84`) | 8 (`:46`) |

Trunk lean 45-55 deg is live text only ("Hơi gập người, giữ lưng thẳng"); the lumbar angle 125-145
shows "Siết cơ bụng, giữ thẳng hàng" without a fault.

**Tests.** No dedicated test. `exercise_logging_alignment_test.dart` covers its score keys
(`Lunge(maxRep: 5)`); report builder contract and registry tests.

**Unverified, stale, or suspicious.**
- **"Not deep enough" cannot fire on a counted rep, by reading.** A rep only counts after entering
  `bottom` (lead knee <= 125), and the depth metric records that frame, so the minimum is always
  <= 125. Shallow attempts are discarded instead. `depth_fails_count` can only come from "Too deep".
  FIXED 2026-11-17: confirmed; the dead branch is removed and the `depth_fails_count` tip now describes "too deep", the only depth fault a counted rep can carry.
- **The lumbar check only works for one facing, by reading.** It uses the unnormalized
  `calculateAngle` (`lunge.dart:361-364`, `pose_math_helpers.dart:212-229`), so the same posture
  reads about 180 + x in one facing and 180 - x in the other; the calibration constant 203.1
  (`lunge.dart:35`) shows values above 180 occur. In the facing that reads above 180 the value never
  drops below 125, so `lumbar` cannot fire there.
  FIXED 2026-11-17: confirmed (facing right read 180 + x); the angle is now normalised and `lumbar` fires in both facings (`lunge_form_test.dart`).
- Lead/trail assignment depends on the same `cameraFacing`-to-head-direction assumption discussed
  under Push-Up. If it is inverted, the trail leg is treated as the lead: depth is read from the
  back knee and the naturally raised back heel triggers `heel` on every rep. Not verified.
  NOT REPRODUCED 2026-11-17: batch A traced facing left = front toward smaller X, which is what Lunge already uses; selection unchanged.
- The state machine has no debounce, so a single noisy lead-knee frame across 125, 145 or 155 moves
  the state; a one-frame dip into 55-125 makes a shallow attempt count.
  CONFIRMED 2026-11-17, not changed: report only, per the batch B prompt.
- "Too deep" is logged from a single frame below 55 with no debounce (`metrics/lunge_depth_metric.dart:57-60`).
- `_matchesCalibratedCleanRep` is computed and its result discarded (`lunge.dart:425-428`), unlike
  Squat; the `CLEAN_REP_*` constants only feed debug output.
  FIXED 2026-11-17: method, helpers and `CLEAN_REP_*` constants removed.
- Comments disagree with code: trunk "≥ 40°", "31° – 39°", "< 0°" (`metrics/lunge_trunk_lean_metric.dart:67-75`)
  vs 56, 45-55, -10; debounce comments "10 frames", "5 frames" vs 12 and 8 (`:39-42`); heel
  "ratio > 0.08" / "0.05 – 0.08" (`metrics/lunge_heel_lift_metric.dart:62`, `:72`) vs 0.16 / 0.10;
  lumbar header "< 140°", "trunk lean < 10°" (`metrics/lunge_lumbar_proxy_metric.dart:12-15`) and
  "≥ 160°" (`:27`) vs 125, 5, 145; depth "110° – 140°" on 150 (`metrics/lunge_depth_metric.dart:26-27`).
  FIXED 2026-11-17: comments now state 56 / 46-55 / -10, 12 / 8 frames, 0.16 / 0.10, 125 / 5 / 145, 125-150.
- In an angled view (accepted by `checkSafety`) trunk lean is always 0, so `trunk` and `lumbar` are
  effectively disabled.
- `scaleFactor` is read from the base class, not overwritten (`lunge.dart:378`).

---

## Walking Lunge

Source: `lib/exercise/walking_lunge/` (7 files).

**Catalog.** `walking_lunge` (definition `walking__lunge`): 3 sets, 10 reps, `isFormChecked: true`
(`assets/data/exercise_catalog.json:411`). Definition: `WalkingLunge(maxRep: reps)`
(`exercise_definition.dart:1237-1238`); subtitle "Chưa có mô tả", description "Bản xem trước của bài
tập Walking Lunge." (`:1222-1223`). Constructor default `MAX_REP = 20` "10 per leg"
(`walking_lunge.dart:23`, `:69`); with the catalog's 10, by reading that is 10 lunges total.

**Archetype.** Rep-based, one rep per lunge step. Side view, **portrait only** (`:63-66`).
`SideTrackedExerciseMixin` with hip, shoulder, knee, ankle, foot index (`:99-120`). Voice:
`PolicyVoiceCoach`, slug `walking_lunge`, fault ids `hold`, `rear_depth`, `torso`, `step_length`
(`:55-60`, `:132-157`).

**Start position** (`:214-252`). Facing left or right, tracked side present, camera-side knee angle
>= 160 ("Hãy đứng thẳng để bắt đầu."). A bounding-box check is described in comments and not
implemented (`:222-239`).

**Stop** (`:188`). `repCount >= maxRep`. No timeout.

**checkSafety** (`:203-211`). Not side view returns `turnSide`; tracked bundle missing returns
`bodyInFrame`. In `checkingPose`, both knees and both ankles must be confident, otherwise the state is
forced to `standing` with "Chưa nhìn thấy hết toàn bộ 2 chân! Hãy lùi lại." (`:272-288`); tracked
bundle missing forces `standing` with "Không thấy rõ người! ..." (`:257-265`). A foot, shoulder or
hip within 4% of the image width from either edge shows "Quay đầu lại và tiếp tục!" (`:26`,
`:294-304`, `:738-745`).

**Front leg** (`:310-318`). Recomputed every frame from ankle X and facing (facing left: smaller X
is front), with no debounce and no lock.

**Rep counting** (`:457-537`). Step = |front ankle X - rear ankle X| / front thigh length
(`metrics/walking_metric_base.dart:23-24`). Hip direction compares only the last two frames with a
3 px gate (`:459`, `lib/utils/frame_buffer.dart:34-46`). No debounce anywhere.

| Transition | Condition |
|---|---|
| standing to stepping | step > 0.45 (`:24`) or front knee < 160 |
| stepping to descending | hip Y increased > 3 px since the previous frame |
| stepping to standing (false start) | step < 0.42 (`:25`) and both knees > 160 |
| descending to bottom | (front knee <= 100 or hip rising) and depth confirmed: front knee <= 140, rear knee <= 150 (`:27-28`, `:539-542`) |
| descending to stepping | same trigger, depth not confirmed, front > 140 and rear > 145 (`:482-483`) |
| bottom to pulling_through | depth confirmed, >= 450 ms in bottom (`:29`), and (hip rising or front knee > 120) |
| pulling_through to standing, **rep counted** | front and rear knee > 150 and step < 0.45 (`:511-516`) |
| pulling_through to stepping, **rep counted** | step > 0.45 and both knees > 140 (`:517-523`) |
| pulling_through to descending, **rep counted** | hip falling, step > 0.45 and step growing (`:524-530`) |

**Calibrated clean-rep override** (`:561-601`, `:660-665`). At rep completion, if the last bottom
frame had step length 25.16 +/- 18 **pixels**, front knee 94.5 +/- 18, normalized step 0.111 +/- 0.12
and knee-over-toe -2.81 +/- 1.2 thigh lengths (`:30-37`), all faults are cleared and the rep is clean.

**Faults.** Metrics run outside `standing` with the post-transition state (the context is rebuilt
when the state changed, `:397-421`). None rejects the rep.

| Type (count key) | Vietnamese message / voice | Metric and threshold | Debounce | affectsForm |
|---|---|---|---|---|
| `hold` (no count key) | "Chưa giữ đủ 2 giây!" / "Phải giữ đủ 2 giây!" | bottom to pulling_through after < 2000 ms in bottom (`:610-627`) | none | true |
| `torso` (`torso_lean_fails_count`) | "Lưng bị gập quá nhiều. Hãy giữ thân thẳng đứng." / "Giữ lưng thẳng lên!" | \|trunk lean\| > 35 deg on any non-standing frame (`metrics/torso_verticality_metric.dart:5-6`, `:21-34`) | none | true |
| `rear_depth` (`rear_depth_fails_count`) | "Đầu gối sau chưa đủ sâu! Hạ sát mặt đất hơn." / "Hạ gối thấp xuống!" | in bottom, \|front foot Y - rear knee Y\| / thigh > 0.25 (`metrics/rear_knee_depth_metric.dart:5`, `:30-50`) | none | false |
| `step_length` (`step_consistency_fails_count`) | "Sải bước không đều! Hãy cố gắng duy trì độ dài bước chân ổn định." / "Giữ sải bước đều nhau!" | at bottom entry, \|step - first rep's step\| / first rep's step > 0.25 (`metrics/step_length_metric.dart:6`, `:19-45`, `walking_lunge.dart:492`) | none | false |
| `front_knee` (`front_knee_fails_count`) | none | knee-over-toe is computed for debug only and never faulted (`metrics/front_knee_control_metric.dart:12-23`) | n/a | n/a |

**Tests.** `walking_lunge_step_length_test.dart` (1 test): knee travel does not reject a short
walking-lunge step. Registry test maps `walking_lunge` / `walking__lunge` / "Walking Lunge" to
`WalkingLungeReportBuilder`. Nothing tests the state machine or any fault.

**Unverified, stale, or suspicious.**
- **Setup text contradicts the code.** The definition tells the user "Đặt camera đối diện hoặc
  nghiêng góc 45 độ." (`exercise_definition.dart:1230`), but front and angled views return `turnSide`
  and never start (`walking_lunge.dart:204-207`, `:215-218`).
- **A walking lunge travels across the frame in a side view.** The exercise only warns at the frame
  edge ("Quay đầu lại và tiếp tục!"); when the tracked bundle or either leg is lost the state is
  forced back to `standing`, discarding the rep in progress (`:257-288`). By reading, a 10-rep set
  needs the user to turn around repeatedly; not tested.
- `front_knee_fails_count` is structurally 0, yet the report shows an "An toàn Khớp gối" card and
  the praise "không vượt mũi chân" from it, and the tip says the knee went past the toes
  (`walking_lunge_report_builder.dart:23-25`, `:43-44`, `:88-95`).
- `hold` has no set-log count key, so it does not appear in report scores; it only marks the rep
  bad form. The bottom state can be left after 450 ms, so every hold between 0.45 and 2 s counts
  with this fault.
- `torso` is a single-frame check on the absolute lean, so backward lean also fires and one noisy
  frame in any active state fails the rep. The comment on 35 says "use 20" (`:5-6`).
- The step-length reference is the first evaluated step of the exercise and is never reset
  (`metrics/step_length_metric.dart:5`, `:26-29`; `reset()` does not clear it). Comment "15%
  tolerance" on 0.25 (`:6`).
- The clean-rep override needs an ankle separation of 7-43 px and <= 0.23 thigh lengths at the
  bottom, i.e. feet almost together; by reading it rarely matches a real lunge, but when it does it
  erases every fault, including `hold` and `torso`.
- Front/rear legs are reassigned every frame from ankle X, so they can swap mid-rep when the feet
  pass each other; it depends on the same facing-to-direction assumption as Lunge.
- `processPose` is overridden to call `poseSmoother.smoothing(landmarks)` and store the result in a
  field that is never read, then calls `super.processPose`, which smooths the same frame again
  (`walking_lunge.dart:727-736`, `exercise_base.dart:509`). By reading, the One Euro filter is fed
  every frame twice. Effect not traced.
- `scaleFactor` is not written here.

---

## McGill Curl-Up (`curl_up`)

Source: `lib/exercise/curl_up/` (6 files).

**Catalog.** `mcgill_curlup` (definition `curl_up`, English name "McGill Curl-Up"): 3 sets, 6 reps,
`isFormChecked: true` (`assets/data/exercise_catalog.json:180`). Definition: `CurlUp(maxRep: reps)`
via `_withReps` (`exercise_definition.dart:467-468`). The definition card says "12 reps" (`:458`) and
its Vietnamese copy has no diacritics ("Core on dinh va gap than co kiem soat", `:450-464`).

**Archetype.** Rep-based. Side view, **landscape only** (`curl_up.dart:262-266`).
`SideTrackedExerciseMixin` with ear, shoulder, hip, knee required and ankle optional (`:211-236`).
Voice: `PolicyVoiceCoach`, slug `curl_up`, fault ids `knee_extension`, `neck_pull`, `trunk_high`,
`trunk_low` (`:81-86`, `:135-162`).

**Start position** (`:286-340`). Tracked side present, and:
- if the ankle is confident: knee angle (hip-knee-ankle) <= 170 (`KNEE_MAX_AT_START`, `:60`, `:305`).
  The comment says "interior angle ≤ 100° required" (`:59`).
- trunk horizontal angle (shoulder-hip, `abs(dy)`/`abs(dx)`, `:708-717`) <= 12 deg, hard-coded (`:311`)
- torso >= 2.5 px (`:317`)
- |hip Y - knee Y| / torso >= 0.03 (`BENT_KNEE_ELEVATION`, `:57`, `:318-319`)
- |ear Y - hip Y| / torso <= 0.55 (`EAR_HIP_VERTICAL_MAX`, `:64`, `:322-323`)

Each passing frame overwrites the baselines: shoulder-hip-knee, ear-shoulder-hip, knee angle (null
if the ankle is hidden) and the state-machine trunk baseline (`:326-337`).

**Stop** (`:359`). `repCount >= maxRep`. No timeout.

**checkSafety** (`:364-377`). Only `CameraFacing.front` returns `turnSide`; angled is accepted.
Tracked bundle missing returns `bodyInFrame`; any returned landmark unconfident returns `lighting`.

**Rep counting** (`:646-689`). Signal: trunk elevation = trunk horizontal angle minus the
state-machine baseline. The baseline is refreshed on every resting frame whose trunk angle changed
less than 0.8 deg since the previous frame (`:75`, `:447-452`). Direction comes from the frame buffer
(last two frames, 0.8 deg gate) and a 2-frame `StickyDebouncer` (`:243-244`).

| Transition | Condition | Debounce |
|---|---|---|
| resting to ascending | non-stable frame, not returning, elevation > 2.0 deg (`ASCEND_DELTA_THRESHOLD`, `:53`, `:663-669`), knee not displaced | sticky direction 2 |
| ascending to descending | returning (`:671-673`) | sticky 2 |
| descending to ascending | not returning (`:675-677`) | sticky 2 |
| descending to resting, **rep counted** | elevation <= 5.0 deg (`REST_TOLERANCE`, `:54`), not an increasing frame, knee not displaced (`:683-688`) | 2 (`:67`, `:240-241`) |

The rep is counted on the frame resting is reached (`:488-492`, `:517-518`); metrics do not run on
that frame. There is no minimum elevation: any curl that rises more than 2 deg above the baseline and
comes back counts. The comment on the constants says "4° entry" and "3° rest tolerance" (`:51-52`)
against 2.0 and 5.0.

**Anti-cheat.** Knee displacement: |knee angle - knee baseline| > 40 deg (`KNEE_DISPLACEMENT_MAX`,
`:72`, `:464-469`), through a 10-frame `StickyDebouncer` (`:250-251`), blocks both entering
`ascending` and closing the rep. The knee baseline is also refreshed on stable resting frames
(`:453-459`). With the ankle hidden the displacement is fed `false` (`:471-473`). The trunk signal
itself is knee-independent (`:27-30`).

**Faults.** Metrics run on non-resting frames (`:500-503`); resting frames only refine baselines.
The context is built before the state machine (`:412-426` vs `:485`), so `ctx.curlUpState` (used
only as the fault's phase label) is the pre-transition state. Each metric logs a warning record
(`affectsForm: false`, no voice) and upgrades it in place to an error. None rejects the rep. No
fault has a debounce: one frame over the threshold logs it.

| Type (count key) | Vietnamese message / voice (live text) | Metric and threshold | Debounce | affectsForm |
|---|---|---|---|---|
| `trunk_high` (`trunk_elev_fails_count`) | "Lên quá cao — chỉ cần nâng vai khỏi sàn" / "Chỉ nâng vai" ("🔴 Lên quá cao!") | trunk elevation > 26 deg vs the metric's own baseline (`metrics/curl_up_trunk_elevation.dart:50`, `:134-137`, `:158-170`) | none | true |
| `trunk_high` | "Hơi cao — giữ biên độ ngắn để bảo vệ lưng" / none ("⚠️ Hơi cao") | > 18 deg (`:53`, `:138-141`, `:173-183`) | none | false |
| `trunk_low` | "Cuộn chưa đủ — nâng cao vai hơn" / "Cuộn cao hơn" | peak elevation < 3 deg at rep completion (`:56`, `:188-210`) | none | false |
| `neck_pull` (`neck_pull_fails_count`) | "Kéo cổ quá mạnh — giữ đầu trung tính" / "Không kéo cổ" ("🔴 Đừng kéo cổ!") | ear-shoulder-hip angle at least 24 deg below baseline (`metrics/curl_up_neck_pulling.dart:57`, `:143-150`, `:169-181`) | none | true |
| `neck_pull` | "Hơi căng cổ — giữ đầu thẳng hàng với lưng" / none ("⚠️ Giữ cổ thẳng") | >= 18 deg below baseline (`:54`, `:151-154`, `:184-195`) | none | false |
| `knee_extension` (`knee_ext_fails_count`) | "Chân duỗi thẳng — co gối lại" / "Giữ gối gập" ("🔴 Chân thẳng quá!") | knee angle >= 168 (`metrics/curl_up_knee_extension.dart:31`, `:111-114`, `:138-150`) | none | true |
| `knee_extension` | "Gối hơi thẳng — co thêm để giữ tư thế McGill" / none ("⚠️ Co gối thêm") | knee angle >= 155 (`:34`, `:115-118`, `:153-163`) | none | false |

Baselines: trunk elevation uses its own baseline, set on the first resting frame and then refreshed
only by resting frames within 2 deg of it (`metrics/curl_up_trunk_elevation.dart:58`, `:105-112`);
neck uses the last start-position frame's angle, else an average of 5 resting frames, fixed for the
set (`metrics/curl_up_neck_pulling.dart:107-125`); knee uses the first resting frame with a visible
ankle (`metrics/curl_up_knee_extension.dart:82-87`). A knee deviation > 25 deg from its baseline
only shows the live chip "⚠️ Đưa chân về 90°" (`:40`, `:119-125`). `*_fails_count` = reps in which the
metric logged any record, warnings included (`metrics/curl_up_metric_base.dart:169-174`;
`curl_up.dart:346-348`).

**Tests.** `curl_up_orientation_test.dart` (uncommitted changes in this checkout): the `CurlUp`
group has 3 tests (start position accepts the bent knee above or below the hip; the first ascent
starts when the shoulder lift appears in either direction; a fixed rep logs peak telemetry from
running scalars); the other 4 tests cover `VikaImageOrientation`, not curl-up logic.
`curl_up_voice_policy_test.dart` (1 test): metric faults are not replayed while preparing the next
set. Shared: report builder contract and registry tests. Nothing tests a fault threshold or the knee
displacement gate.

**Unverified, stale, or suspicious.**
- **The knee-extension fault is disabled for anyone who starts with a fairly straight leg, by
  reading.** If the knee baseline is >= 145 the metric returns "good" on every frame
  (`metrics/curl_up_knee_extension.dart:103-107`), and the start gate admits knees up to 170
  (`curl_up.dart:305`). The header and config comments assume a "≤ 100° start"
  (`metrics/curl_up_knee_extension.dart:16-19`, `:37-39`). The "good" string on that path is
  mojibake (`'âœ… Gá»‘i tá»‘t'`, `:105`). With the ankle hidden, the metric and the displacement gate
  are both skipped.
  FIXED 2026-11-17: mojibake string fixed. CONFIRMED 2026-11-17, not changed: the >= 145 disable and the 170 start gate.
- **A rep with almost no curl counts as a clean rep, by reading.** Counting needs only > 2 deg above
  the state-machine baseline; `trunk_low` (< 3 deg) has `affectsForm: false`, so such a rep is
  `correctForm = true` (`curl_up.dart:527`). Landmark jitter of a few degrees that rises for one
  frame and falls for two could count a phantom rep. Not measured.
  CONFIRMED 2026-11-17, not changed: measured: uniform +-2 deg jitter counts 0 reps in 10 s, +-3 deg counts 1-4 clean phantom reps (`curl_up_form_test.dart`); fix proposed in docs/scratch/kept-exercises-report-batch-B.md.
- `*_fails_count` includes warnings with `affectsForm: false`, including `trunk_low`, so the report's
  "Biên độ cuộn" score mixes "too shallow" coaching with the `trunk_high` error.
  CONFIRMED 2026-11-17, not changed: report only.
- Comments disagree with code: trunk header ">45° error, 30–45° warning, <15° shallow"
  (`metrics/curl_up_trunk_elevation.dart:33-37`) vs 26 / 18 / 3; neck header "> 15° error, 12-15°
  warning" (`metrics/curl_up_neck_pulling.dart:37-40`) vs 24 / 18; knee header "≥ 175° error,
  165–175° warning" and "drift > 15°" (`metrics/curl_up_knee_extension.dart:10-16`) vs 168 / 155 /
  25.
- The state machine and the trunk metric keep separate trunk baselines with different refresh rules
  (`curl_up.dart:447-452` vs `metrics/curl_up_trunk_elevation.dart:105-112`), so the elevation that
  counts the rep and the one that grades it can differ.
- The trunk angle uses `abs(dy)` (`curl_up.dart:712`). If the camera tilt puts the lying shoulder
  lower than the hip in the image, the angle first falls toward 0 as the user curls and only then
  rises, so elevation is underestimated by up to twice the tilt (up to 12 deg passes the start
  gate). By reading.
- `trunk_high` and `neck_pull` errors fire from a single frame.
- `scaleFactor` is read from the base class (`:417`) and not written. No metric uses it.

---

## Jumping Jack

Source: `lib/exercise/jumping jack/` (6 files).

**Catalog.** `jumping_jack`: 3 sets, 20 reps, `isFormChecked: true`
(`assets/data/exercise_catalog.json:136`). Definition: `JumpingJack(maxRep: reps)` via `_withReps`
(`exercise_definition.dart:382-383`); the card says "30 reps" (`:373`).

**Archetype.** Rep-based, two states (closed, open). **Front view, portrait only**
(`jumping_jack.dart:44-47`). Both sides used at once; no `SideTrackedExerciseMixin`. Voice:
`PolicyVoiceCoach`, slug `jumping_jack`, fault ids `arms`, `legs`, `tempo_fast` (`:37-41`, `:84-105`).

**Start position** (`:123-190`). Both shoulders, hips, knees and ankles present (confidence not
re-checked here); using left/right midpoints: trunk within 25 deg of vertical (`:174-179`) and
midpoint knee angle (hip-knee-ankle) >= 155 (`:182-187`). Both values are hard-coded.

**Stop** (`:195`). `repCount >= maxRep`. No timeout.

**checkSafety** (`:211-251`). `cameraFacing` left or right returns `faceCamera`; angled is accepted.
Any of 10 landmarks (both shoulders, elbows, wrists, hips, ankles) missing returns `bodyInFrame`;
either shoulder, wrist or ankle unconfident returns `lighting` (elbows and hips are not
confidence-checked). `checkingPose` also needs the nose and silently skips the frame without it
(`:268-280`).

**Geometry** (`:282-304`). Scale = shoulder width in pixels. Arm "elevation" is the hip-shoulder-wrist
angle (`:292-295`): about 0 with the arm at the side, 90 at shoulder height, 180 overhead. The
context's comment describes it as "from horizontal, 90° = overhead"
(`metrics/jumping_jack_metric_base.dart:44-49`). Ankle spread = ankle distance / shoulder width.

**Rep counting** (`:425-444`).

| Transition | Condition | Debounce |
|---|---|---|
| closed to open | spread > 1.0 (`:26`) and average elevation > 90 (`:28`) and both wrists above the nose | 2 (`:62`) |
| open to closed | spread < 0.65 (`:27`) and average elevation < 110 (`:29`) and both wrists below their shoulders | 2 (`:63`) |

The rep is counted on the first frame after closed is reached (`:333-335`); that frame does not run
the state machine or `update`. Metrics see the pre-transition state (context built at `:309-321`,
state machine at `:401`).

**Anti-cheat.** Only the open gate (arms overhead and feet apart at once). Nothing checks that the
user jumps.

**Faults.** No rep is rejected. `*_fails_count` = reps with any record of that type (`:199-201`,
`metrics/jumping_jack_metric_base.dart:110-113`).

| Type (count key) | Message / voice (live text) | Metric and threshold | Debounce | affectsForm |
|---|---|---|---|---|
| `arms` (`arm_fails_count`) | "Tay chưa đủ cao" / none ("Vươn tay cao hơn!") | while state is `open`: min(left, right) elevation < 20 (`metrics/arm_extension_metric.dart:37`, `:105-119`) | 3 (`:61`) | true |
| `arms` | "Khuỷu tay gập nhiều" / none ("Duỗi thẳng tay!") | while `open` and elevation >= 45: min elbow angle < 105 (`:44-48`, `:128-142`) | 3 (`:62`) | true |
| `arms` | "Tay quá thấp (X°)" / "Tay chưa đủ cao (X°)", no voice | at rep end: min of the two per-arm peak elevations < 20 / < 45 (`:33`, `:37`, `:154-166`) | none | true |
| `legs` (`leg_fails_count`) | "Chân chưa đủ rộng" / "Mở chân rộng hơn" ("Mở chân rộng hơn!") | while `open`: spread < 0.75 (`metrics/leg_spread_metric.dart:36`, `:81-91`) | 3 (`:49`) | true |
| `legs` | "Chân quá hẹp (X×)" / "Chân chưa đủ rộng (X×)", no voice | at rep end: peak spread < 0.75 / < 1.25 (`:32`, `:36`, `:106-114`) | none | true |
| `tempo_fast` (`tempo_fails_count`) | "Quá nhanh (Xs)" / none ("Chậm lại, giữ form!") | closed-to-closed time < 0.5 s; first rep not timed (`metrics/tempo_metric.dart:41`, `:118-147`) | none | false |

Live-only tempo text: > 2.0 s "Nhanh hơn một chút!", 1.5-2.0 s "Nhanh hơn chút!", 0.5-0.8 s "Hơi
nhanh!" (`metrics/tempo_metric.dart:148-160`). Rhythm stdev and fatigue are computed but only set
unused flags (`:162-195`). The per-rep top voice line is chosen by type order arms, legs, tempo
(`jumping_jack.dart:446-468`).

**Tests.** No dedicated test. `exercise_logging_alignment_test.dart` builds `JumpingJack(maxRep: 6)`
(`:68`); report builder key contract and registry tests (MET 8.0). Nothing tests the state machine or
a fault.

**Unverified, stale, or suspicious.**
- **The `legs` fault probably fires on ordinary reps, by reading.** The open-phase check keeps
  running until the closed debounce completes. While the feet come together, spread passes through
  0.75-0.65 and below 0.65 while the state is still `open` (the closed transition also needs the
  wrists below the shoulders and takes 2 frames, then metrics on that frame still see `open`). Three
  consecutive frames under 0.75 in that window log "Chân chưa đủ rộng" with voice, on a rep whose
  open position was wide. The same window can log the `arms` "< 20" fault if the arms reach the
  sides before the feet close. Needs a recording to confirm.
  FIXED 2026-11-17: confirmed by a test (a 1.6x wide rep logged `legs`); open-phase checks now run only while the frame still meets the open gate.
- **The rep-end elevation checks cannot fire, by reading.** A rep needs `open`, which needs both
  wrists above the nose; with the hip below the shoulder that puts each arm's hip-shoulder-wrist
  angle well above 90, and the peaks include those frames, so neither peak can stay under 45.
  Likewise the rep-end "Chân quá hẹp" (< 0.75) cannot fire because `open` needs spread > 1.0; only
  "Chân chưa đủ rộng" (1.0-1.25) can.
  FIXED 2026-11-17: rep-end arm checks and "Chân quá hẹp" removed; the open-phase low-arm and narrow-leg branches, unreachable once gated, removed too.
- Comments disagree with code: arm header "Good > 60°, warning 30-60°, error < 30°, elbows 150° /
  120°" (`metrics/arm_extension_metric.dart:14-17`) vs 45 / 20 / 135 / 105; leg header "Good >= 1.5,
  warning 1.0-1.5, error < 1.0" (`metrics/leg_spread_metric.dart:14-17`) vs 1.25 / 0.75. The
  elevation thresholds look written for the "from horizontal" scale the comments describe, not the
  hip-shoulder-wrist scale the code uses.
  FIXED 2026-11-17: arm and leg headers and the elevation-scale comment corrected.
- `tempo_fast` has `affectsForm: false` but still feeds `tempo_fails_count` and the "Nhịp" score.
  "Too slow" is never logged.
  CONFIRMED 2026-11-17, not changed: owner decision, see docs/scratch/kept-exercises-report-batch-B.md.
- Shoulder width shrinks when the user turns, which inflates the spread ratio; angled views pass
  `checkSafety`.
- `scaleFactor` is overwritten every frame with the raw shoulder width (`:282-283`). No metric reads
  it.

---

## Jump Squat

Source: `lib/exercise/Jump_Squat/` (7 files).

**Catalog.** `jump_squat` (definition `jump__squat`): 3 sets, 12 reps, `isFormChecked: true`
(`assets/data/exercise_catalog.json:125`). Definition: `JumpSquat(maxRep: reps)` via `_withReps`
(`exercise_definition.dart:1008-1009`); subtitle "Chưa có mô tả", description "Bản xem trước của bài
tập Jump Squat." (`:993-994`).

**Archetype.** Rep-based, five states (standing, squatting, launching, airborne, landing). Side view,
**portrait only** (`jump_squat.dart:46-49`). One side via `getSideLandmark`: right landmarks when
facing right, otherwise left (`exercise_base.dart:817-826`). Voice: `PolicyVoiceCoach`, slug
`jump_squat`, fault ids `landing_stiff`, `landing_depth`, `trunk`, `takeoff_depth` (`:38-43`,
`:90-111`).

**Start position** (`:134-190`). Nose, shoulder, hip, knee, ankle and foot index present and
confident (else "Hãy đứng xa ra để AI nhìn thấy toàn thân (từ đầu đến chân)"); knee angle
(hip-knee-ankle) >= 170, hard-coded (`:184`). Captures the floor baseline (support Y = the
**largest**, i.e. lowest in the image, of ankle, foot index and, if confident, heel, `:424-434`) and
the standing hip Y.

**Stop** (`:193`). `repCount >= maxRep`. No timeout.

**checkSafety** (`:206-212`). Not side view returns `turnSide`. No landmark check. In `checkingPose`,
a missing or unconfident shoulder, hip, knee, ankle or foot index skips the frame silently
(`:242-250`).

**Rep counting** (`:370-422`). While standing with knee >= 170 and feet grounded, the floor and hip
baselines follow an EMA with weight 0.08 (`:436-459`). Foot-lift threshold = max(0.07 x lower-leg
length, 0.04 x torso) (`:29-30`, `:461-466`); hip-lift threshold = 0.05 x torso (`:31`). "Moving up"
= hip Y decreased by more than 2.0 **pixels** since the previous frame (`:383`). Transitions are an
`else if` chain, so at most one per frame.

| Transition | Condition | Debounce |
|---|---|---|
| standing to squatting (starts the rep clock) | knee < 140 (`:25`, `:394-397`) | 2 (`:63`) |
| squatting to launching | moving up and knee > 90 (`:398-403`) | 2 (`:64`) |
| squatting or launching to airborne | support lift > foot threshold and hip lift > hip threshold (`:389-390`, `:404-409`) | 2 (`:65`) |
| airborne to landing | support lift <= 0.55 x foot threshold (`:32`, `:391-392`, `:410-413`) | 2 (`:66`) |
| landing to standing | knee > 150 (`:24`), not moving up, feet on ground (`:414-421`) | 2 (`:67`) |

On reaching standing from landing (`:299-358`): if less than 350 ms passed since squatting began
(`MIN_REP_DURATION_MS`, `:33`, `:468-472`) the rep is not counted ("Không tính rep", "Chuyển động quá
nhanh, AI không xác nhận được rep.") and the metrics are `reset()` without counting their faults;
otherwise the rep counts.

**Anti-cheat.** The airborne gate needs both the feet and the hip to rise, so a calf raise or a foot
flick alone does not count (tested). The 350 ms minimum rep duration. Rejections are not counted in
any key.

**Faults.** The context is built after the state machine (`:278` vs `:281-289`), so metrics see the
post-transition state; their `onStateTransition` hooks run inside the state machine, before
`update` on the same frame (`:508-519`). None rejects the rep. `*_fails_count` = counted reps with
any record of that metric, warnings included (`:197-200`,
`metrics/jump_squat_metric_base.dart:50-53`).

| Type (count key) | Vietnamese message / voice (live text) | Metric and threshold | Debounce | affectsForm |
|---|---|---|---|---|
| `landing_stiff` (`stiff_landing_fails_count`) | "Tiếp đất chân quá thẳng (X°)! Nguy hiểm khớp gối." / "Trùng gối sâu hơn khi tiếp đất" ("Tiếp đất quá cứng, trùng gối sâu hơn ngay.") | minimum knee angle during `landing` > 145, evaluated on landing to standing (`metrics/landing_knee_flexion_metric.dart:15`, `:56-83`) | none (state 2) | true |
| `landing_depth` (same key) | "Tiếp đất chưa đủ sâu (X°). Hãy trùng gối thêm!" / "Trùng gối thêm khi tiếp đất" | minimum > 105 (`:14`, `:84-93`) | none | false |
| `takeoff_depth` (`shallow_dip_fails_count`) | "Lấy đà quá nông (X°). Hạ hông sâu hơn!" / "Hạ hông sâu hơn rồi mới bật nhảy" ("Lấy đà nông quá, hạ hông sâu hơn rồi mới bật.") | minimum knee angle during `squatting` > 125, evaluated on squatting to launching (`metrics/take_off_depth_metric.dart:14`, `:49-64`) | none | true |
| `trunk` (`trunk_lean_fails_count`) | "Lưng rạp úp quá mức khi tiếp đất (X°)! Giữ ngực cao." / "Nâng ngực lên khi tiếp đất" ("Nâng ngực lên, đừng rạp lưng khi tiếp đất.") | maximum \|trunk lean\| during `landing` > 60, evaluated on landing to standing (`metrics/landing_trunk_alignment_metric.dart:12`, `:48-62`) | none | true |

Trunk lean is `abs(convertClockAngleToTrunkLean(...))` (`jump_squat.dart:255-257`), so its sign, and
with it the facing convention of finding 6, does not matter here.

**Tests.** `jump_squat_anti_cheat_test.dart` (4 tests, facing left): start position captures a
standing floor and hip baseline; a calf raise or foot flick is not counted as airborne; a clear jump
squat with hip lift and controlled landing counts; a jump launched from a shallow dip counts and is
faulted. Also `exercise_logging_alignment_test.dart`, report builder key contract and registry
tests. Nothing tests the landing or trunk faults or the 350 ms rejection.

**Unverified, stale, or suspicious.**
- **`takeoff_depth` is skipped when the jump goes straight from squatting to airborne, by reading.**
  The fault is only evaluated on the squatting-to-launching transition, and `airborne` is also
  reachable directly from `squatting` (`:404-407`). Launching needs two frames of hip rising more
  than 2 px per frame with knee > 90; a fast dip-and-jump at a low frame rate can skip it, and the
  shallow take-off is then never faulted.
  FIXED 2026-11-17: evaluated on squatting to airborne as well (`jump_squat_form_test.dart`).
- **There is no way back from `squatting` or `launching` to `standing`.** A squat without a jump, or
  a jump below the airborne thresholds, leaves the machine waiting; the next detected jump closes a
  rep whose take-off depth and rep clock come from the earlier squat. By reading.
  FIXED 2026-11-17: confirmed; squatting/launching return to standing (knee > 150, not rising, feet grounded, 2 frames) with no rep and metrics reset.
- `landing_depth` has `affectsForm: false` but still feeds `stiff_landing_fails_count`, so a soft
  but not deep landing (105-145 deg) lowers the "Tiếp đất êm" score.
  CONFIRMED 2026-11-17, not changed: owner decision, see docs/scratch/kept-exercises-report-batch-B.md.
- Comments disagree with code: landing "<= 60 độ" safe and "> 90" stiff
  (`metrics/landing_knee_flexion_metric.dart:6-8`) vs 105 / 145; take-off "> 90 độ" shallow
  (`metrics/take_off_depth_metric.dart:5`) vs 125; trunk "> 45 độ" (`metrics/landing_trunk_alignment_metric.dart:6`,
  `:12`) vs 60. The stiff-landing record says "Hủy rep" (`:80`) but the rep still counts.
  FIXED 2026-11-17: comments corrected; "Hủy rep" was a code comment, not user text, and now says the rep still counts.
- `_evaluateLanding` takes the type `RepContext` as an argument and ignores it (`:62-68`); harmless.
- Pixel-based "moving up" (2 px/frame) depends on resolution, distance and frame rate (finding 8).
- `scaleFactor` is overwritten every frame with the raw shoulder-hip distance (`:258`) and then used
  for the airborne thresholds.
- The definition's setup tip "Đặt camera đối diện hoặc nghiêng góc 45 độ." (`exercise_definition.dart:1001`)
  contradicts `checkSafety`, which only accepts side views.
  FIXED 2026-11-17: camera hint asks for a side view; subtitle and description are no longer placeholders.
- `jump_squat_report_builder.dart` is marked "DEAD LEGACY" (`:8-9`); live reports use
  `JumpSquatReportBuilderV2`.

---

## Cossack Squat

Source: `lib/exercise/cossack_squat/` (8 files).

**Catalog.** `cossack_squat` (definition `cossack__squat`): 3 sets, 8 reps, `isFormChecked: true`
(`assets/data/exercise_catalog.json:70`). Definition: `CossackSquat(maxRep: reps)` via `_withReps`
(`exercise_definition.dart:984-985`); subtitle "Chưa có mô tả", camera hint "Đặt camera đối diện hoặc
nghiêng góc 45 độ." (`:969-977`).

**Archetype.** Rep-based, alternating sides. **Front view, portrait only**
(`cossack_squat.dart:49-52`). Voice: `PolicyVoiceCoach`, slug `cossack_squat`, fault ids `heel`,
`knee_valgus`, `straight_leg`, `torso`, `depth_deep`, `depth_shallow` (`:39-46`, `:88-113`).

**Start position** (`:175-221`). Facing front; both ankles, shoulders, hips, knees present; ankle
X-distance >= 1.5 x shoulder X-distance (else "Hãy bước 2 chân rộng hơn nữa (gấp 1.5 - 2 lần vai).",
`:198-206`); both knee angles >= 165 (else "Hãy đứng thẳng cả hai chân.", `:209-218`). Comment says
"> 170 degrees" (`:208`).

**Stop** (`:133`). `repCount >= maxRep`. No timeout.

**checkSafety** (`:147-172`). Anything but `CameraFacing.front` returns `faceCamera`. Any of 10
landmarks (both shoulders, hips, knees, ankles, foot indices) missing **or unconfident** returns
`bodyInFrame` (no `lighting` signal). Heels are optional and never confidence-checked.

**Rep counting** (`:278-297`, `:393-420`). Scale = shoulder X-distance in pixels (`:242`). Hip
direction is the mid-hip Y of the last two frames against a 3 px gate (`:280-281`, `:397`,
`lib/utils/frame_buffer.dart:34-52`). **No transition is debounced.**

| Transition | Condition |
|---|---|
| standing to descending, working leg chosen | mid-hip Y increased > 3 px and one knee angle is > 10 deg smaller than the other; that leg is the working leg (`:280-294`) |
| descending to bottom | working knee <= 110 (`:25`), or hip Y decreasing and working knee <= 120 (`:401-406`) |
| bottom to ascending | hip Y **increasing** (moving down) or working knee > 120 (`:409-412`) |
| ascending to standing, **rep counted** | both knees > 150 (`:27`, `:415-418`) |

On reaching standing (`:299-322`): if `bottom` was never reached the attempt is discarded ("Không
tính", `_rejectedShallowAttempts`) and metrics `reset()`; otherwise the rep counts.

**Anti-cheat.** Only the bottom gate, which is unreachable (see below).

**Faults.** Metrics run only outside `standing` (`:364-369`) with the post-transition state (context
built at `:348-361`, after the state machine at `:278-297`). Each metric keeps at most one record per
type per rep (`metrics/cossack_metric_base.dart:56-60`). None rejects the rep. **No fault is
debounced.** `*_fails_count` = counted reps with any record of that metric (`:137-141`,
`metrics/cossack_metric_base.dart:67-72`).

| Type (count key) | Vietnamese message / voice (live text) | Metric and threshold | Debounce | affectsForm |
|---|---|---|---|---|
| `knee_valgus` (`knee_valgus_fails_count`) | "Đẩy đầu gối ra ngoài, đừng để gối chụm vào trong." / "Đẩy đầu gối ra ngoài." | inward drift = (working knee X - ankle X) / scale, negated for the left leg, > 0.14 (`metrics/knee_valgus_metric.dart:5`, `:15-24`) | none | true |
| `heel` (`heel_lift_fails_count`) | "Gót chân trụ phải chạm sàn. Nếu không làm được, hãy squat nông lại!" / "Hạ gót chân xuống!" ("Hạ gót chân xuống, giữ bàn chân trụ chạm sàn.") | (working foot index Y - heel Y) / scale > 0.08; 0 if the heel is missing (`metrics/heel_lift_metric.dart:5`, `:24-37`; `cossack_squat.dart:265-267`) | none | true |
| `straight_leg` (`straight_leg_fails_count`) | "Bạn đang thu hẹp tư thế, mất tác dụng kéo giãn cơ khép. Hãy giữ thẳng chân còn lại." / "Giữ thẳng chân duỗi!" | other knee angle < 145 (`metrics/straight_leg_metric.dart:5-6`, `:24-37`) | none | true |
| `torso` (`torso_lean_fails_count`) | "Tránh rạp ngực hoàn toàn xuống đất. Cố gắng giữ lưng thẳng hơn." / "Nâng ngực lên!" | mid-hip to mid-shoulder **clock angle** (0-360) > 65 (`metrics/torso_verticality_metric.dart:5-6`, `:21-34`) | none | false |
| `depth_deep` (`depth_fails_count`) | "Xuống quá sâu, có thể gây áp lực lên khớp gối." / none ("Xuống quá sâu, kiểm soát lại biên độ gối.") | in `bottom`, working knee < 50 (`metrics/working_depth_metric.dart:5`, `:33-47`) | none | false |
| `depth_shallow` (same key) | "Squat chưa đủ sâu! Cố gắng hạ hông thấp hơn." / "Xuống sâu hơn chút nữa!" | on reaching standing, working knee never <= 115 in a non-standing frame (`:6-7`, `:29-31`, `:52-69`) | none | true |

**Calibrated clean rep (discarded).** `_matchesCalibratedCleanRep` compares the standing frame with
left knee 172.1 +/- 12, right knee 179.6 +/- 12, torso clock angle 329.3 +/- 18 and valgus norm
0.160 +/- 0.12 (`:28-35`), and its result is ignored (`:455-459`), as in Lunge. It only writes debug
values.

**Tests.** `cossack_squat_feedback_test.dart` (3 tests): heel lift, knee valgus and straight leg
metrics each publish live feedback (metric-level, not the state machine). Also report builder key
contract test. Not in `report_builder_registry_test.dart` (by grep). Nothing tests counting,
`torso` or depth.

**Unverified, stale, or suspicious.**
- **`torso` fires on almost every rep, by reading.** It compares a 0-360 clock angle against 65
  (`metrics/torso_verticality_metric.dart:21`), but an upright trunk reads about 0, and any tilt of
  the shoulders toward smaller X reads 300-359 (`pose_math_helpers.dart:244-265`); the calibration
  constant 329.3 shows such values occur in a rep the authors considered clean. One frame of
  leftward tilt, or jitter across 0/360, logs the fault. It has `affectsForm: false`, so the rep
  stays good, but `torso_lean_fails_count` and the "Lưng thẳng" score are wrong, and the voice line
  "Nâng ngực lên!" is triggered.
- **The shallow-attempt rejection is unreachable, by reading.** `standing` is only reachable from
  `ascending`, which is only reachable from `bottom`, which sets `_reachedBottomThisRep`
  (`:415-418`, `:409-412`, `:432-433`). A descent that never reaches bottom has no exit from
  `descending`; the machine waits there until the knee next goes <= 110-120. `depth_shallow` can
  only fire for a bottom entered at 115-120 via the hip-rising path, so `depth_fails_count` is
  nearly structurally 0.
- **The bottom-to-ascending hip test is inverted.** The comment says "Ascending if hip starts moving
  up", the code checks `increasing` Y, which is moving down (`:408-409`; the standing branch's
  comment confirms increasing Y = going down, `:280-281`). A hip still sinking more than 3 px in one
  frame at the bottom moves the state to `ascending`.
- **`knee_valgus` direction depends on image mirroring**, which was not traced (see finding 6). With
  the user's left leg on the image's right (unmirrored), knee X < ankle X is inward and the sign is
  right; in a mirrored image the check fires when the knee pushes **out**, the opposite of the cue.
- Leaving `standing` needs the mid-hip to drop more than 3 px between two frames; a slow descent
  never starts a rep. Pixels per frame depend on distance, resolution and frame rate (finding 8).
- `frameBuffer` is never cleared in this exercise, so it grows for the whole set (by reading; the
  base class creates it without `maxLength`, `exercise_base.dart:312`, `frame_buffer.dart:17-28`).
- The result text is English ("Good Rep!" / "Fix Form", `:462`).
- `scaleFactor` is overwritten every frame with the shoulder X-distance (`:242`).
- The definition offers a 45 degree view, which `checkSafety` rejects with `faceCamera`.

---

## Russian Twist

Source: `lib/exercise/russian_twist/` (7 files).

**Catalog.** `russian_twist` (definition `russian__twist`): 3 sets, 16 reps, **`isFormChecked:
false`** (`assets/data/exercise_catalog.json:279`, `:281`). Definition: `RussianTwist(maxRep: reps)`
via `_withReps` (`exercise_definition.dart:1033-1034`); card "20 reps" (`:1025`); camera hint "Đặt
camera chính diện trước mặt.", setup "Ngồi ngả lưng ra sau khoảng 45 độ" (`:1026-1031`); no
`videoAsset`. Constructor default `MAX_REP = 20` (`russian_twist.dart:27`, `:77`).

**Archetype.** Rep-based; one rep = two half twists to opposite sides. **Front view**; portrait and
both landscapes allowed (`:70-74`). Voice: `PolicyVoiceCoach`, slug `russian_twist`, fault ids
`knee`, `too_upright`, `too_low`, `rom` (`:62-67`, `:117-139`).

**Signals** (`:247-255`, `:518-570`). Scale = shoulder distance in pixels; frames under 40 px are
skipped (`:50`, `:248`). Wrist offset = (leading wrist X - mid-shoulder X) / scale, where the
leading wrist is whichever wrist has the higher likelihood + presence + visibility on that frame,
or the mid-shoulder if both wrists are missing; wrist confidence is never checked. Trunk angle =
`atan2(|dx|, |dy|)` of the mid-shoulder to mid-hip line, i.e. degrees **from vertical** (`:522-536`).

**Start position** (`:194-234`). Shoulders, hips and knees present and confident; trunk angle
between 32 and 72 (`:33-34`; above 72 shows "Ngả lưng ra sau khoảng 35-60 độ, không ngồi thẳng
lưng.", below 32 "Nâng thân lên một chút, đừng nằm quá thấp khi chuẩn bị."); scale >= 40 px;
|wrist offset| <= 0.12 ("Đưa hai tay về giữa ngực trước khi bắt đầu.", `:41`, `:218-224`).

**Stop** (`:159`). `repCount >= maxRep`. No timeout.

**checkSafety** (`:174-191`). Anything but `CameraFacing.front` returns `faceCamera`. Any of the six
landmarks missing or unconfident returns `bodyInFrame`. `checkingPose` calls `checkSafety` again
and publishes the signal itself (`:238-242`).

**Rep counting** (`:328-373`). Delta = wrist offset minus the center offset, which is the wrist
offset on the first active frame and is never updated afterwards (`:333-337`). Direction change
uses the last two frames against a 0.015 gate (`:46`, `:329-332`). **No transition is debounced.**

| Transition | Condition |
|---|---|
| center_setup to twisting (direction set) | delta >= +0.12 (forward) or <= -0.12 (backward) (`:41`, `:336-344`) |
| twisting to max_point | \|delta\| >= 0.28 (`:42`, `:346-347`) |
| twisting or max_point to returning | one frame moving back toward center (`:348-354`, `:365-373`) |
| returning to center_setup, half twist completed | \|delta\| <= 0.06 (`:43`, `:355-360`) |

At each half twist (`:396-478`): if any fault of a blocking type (`rom`, `knee`, `too_upright`,
`too_low`, `:90-95`) was logged, the half is rejected ("Không tính", `rejected_attempts_count` += 1);
else if it went the same direction as the last accepted half, it is rejected as "Vui lòng vặn luân
phiên 2 hướng!"; else it is accepted, and every second accepted half counts a rep. Metrics are
`reset()` after every half and `resetAndCountFault()` only after a half that completes a rep.

**Anti-cheat.** Alternation and the four blocking faults, which reject the half twist.

**Faults.** The context is built after the state machine (`:262` vs `:264-294`), so metrics see the
post-transition state. Each metric keeps at most one record per type per half
(`metrics/russian_metric_base.dart:114-118`). No fault is debounced.

| Type (count key) | Vietnamese message / voice | Metric and threshold | Debounce | Effect |
|---|---|---|---|---|
| `knee` (`knee_wobble_fails_count`) | "Giữ đầu gối ổn định, đừng dùng chân lấy đà." / "Giữ chân vững nhé." | mid-knee moved > 0.32 x scale from its position on the last `center_setup` frame (`metrics/knee_anchoring_metric.dart:12`, `:19-46`) | none | rejects the half |
| `too_upright` (no key) | "Không tính: hãy ngả lưng ra sau để siết bụng, không ngồi thẳng 90 độ." / "Ngả lưng ra sau!" | trunk angle > 72 outside `center_setup` (`metrics/spinal_flexion_metric.dart:20-32`) | none | rejects the half |
| `too_low` (no key) | "Không tính: nâng thân lên một chút, đừng nằm quá thấp khi vặn." / "Nâng thân lên!" | trunk angle < 32 outside `center_setup` (`:33-45`) | none | rejects the half |
| `rom` (`rom_fails_count`) | "Vặn chưa đủ sâu, tay cần đi dứt khoát qua hai hướng." / "Vặn sâu hơn nhé." | on entering `returning`, peak \|delta\| during twisting/max_point < 0.28 (`metrics/twist_rom_metric.dart:29-52`) | none | rejects the half |
| `arm_swinging` (`thoracic_fails_count`) | "Đừng chỉ vung tay, hãy xoay cả vai và ngực theo hướng tay." / "Xoay cả vai theo tay." | in `max_point`: \|wrist X - mid-shoulder X at setup\| / scale < 0.02 (`metrics/thoracic_rotation_metric.dart:17`, `:29-50`) | none | affectsForm false |

**Tests.** `russian_twist_anti_cheat_test.dart` (5 tests, facing front): safety requires the front
camera; start position requires a leaned-back torso and centered hands; one rep counts when twisting
to both sides; consecutive reps count across alternating twists; shallow twists that miss ROM are
not counted. Also `exercise_logging_alignment_test.dart` and the report builder key contract test.

**Unverified, stale, or suspicious.**
- **The trunk-angle gate probably cannot be met by a real front-view user, by reading.** Leaning
  back away from a camera in front of the user moves the shoulders along the camera axis; the
  shoulder midpoint stays above the hip midpoint in the image, so `atan2(|dx|, |dy|)` stays near 0.
  The start gate needs 32-72 deg, and `too_low` (< 32) rejects every half twist. The test fixture
  gets 45 deg by placing the hip midpoint 100 px **sideways** from the shoulder midpoint
  (`russian_twist_anti_cheat_test.dart` header comment and `_frontPose`), which corresponds to a
  sideways lean, not a lean back. Needs a device check before any evaluation of this exercise.
- **All three report cards are structurally (or nearly) 100%, by reading.** Halves with a blocking
  fault are rejected and their metrics `reset()` without counting, so `knee_wobble_fails_count` and
  `rom_fails_count` can never increase (`:403-408`, `:458-475`). `thoracic_fails_count` counts only
  the second half of each rep, and `arm_swinging` needs the wrist to sit within 0.02 shoulder widths
  of the setup midline while the wrist offset is >= 0.28 from center, which needs the shoulders to
  move opposite to the hands. The check's logic is the reverse of its comment ("arm-only swings stay
  close to center"): an arm-only swing moves the wrist far from the setup midline and passes.
- Rejected halves are reported only through `rejected_attempts_count` and `setFeedback`; the
  reason (knee, ROM, posture) is not in any count key.
- The leading wrist can switch between the left and right wrist from one frame to the next, and with
  both wrists missing the offset reads 0 (center), which can complete a half twist. By reading.
- The center offset is fixed from the first active frame for the whole set; if the user's hands
  rest off-center later, deltas are biased.
- The trunk-angle message for < 32 says "lying too low" although < 32 from vertical means more
  upright; the context comment calls the value "from the horizontal axis"
  (`metrics/russian_metric_base.dart:54-56`, `metrics/spinal_flexion_metric.dart:8-11`), the code
  measures from vertical (`russian_twist.dart:530-534`).
- `RussianRepContext.kneeDriftRatio` is always 0.0 and `shoulderRotationOffset` is unused by every
  metric (`:286-287`).
- `scaleFactor` is overwritten every frame with the shoulder distance (`:249`).
- `isFormChecked: false` in the catalog; the flag does not reach the exercise class (finding 14),
  so the four blocking faults still reject half twists.

---

## Standing Knee-to-Elbow

Source: `lib/exercise/standing_knee_to_elbow/` (7 files).

**Catalog.** `standing_knee_to_elbow` (definition `standing__knee_to__elbow`): 3 sets, 16 reps,
**`isFormChecked: false`** (`assets/data/exercise_catalog.json:345`, `:347`). Definition:
`StandingKneeToElbow(maxRep: reps)` via `_withReps` (`exercise_definition.dart:1163-1164`); the
description says "Luân phiên kéo gối lên chạm khuỷu tay đối diện" and camera hint "Đặt camera đối
diện hoặc nghiêng góc 45 độ." (`:1147-1155`). Constructor default `MAX_REP = 30` "15 per side"
(`standing_knee_to_elbow.dart:23`, `:49`).

**Archetype.** Rep-based, one rep per knee drive. **Front view, portrait only** (`:43-46`). Voice:
`PolicyVoiceCoach`, slug `standing_kte`, fault ids `core_drive`, `knee_valgus`, `pelvic_drop`
(`:36-40`, `:95-116`).

**Start position** (`:157-216`). Facing front; both hips, knees, ankles, shoulders, elbows present
(not confidence-checked here); both knee angles >= 165 ("Hãy đứng thẳng cả 2 chân."); shoulder Y
difference / shoulder X-distance <= 0.15 ("Giữ 2 vai thăng bằng.", comment says "< 10%", `:198-199`);
each elbow no more than 0.35 torso below its shoulder ("Nâng hai khuỷu tay lên gần ngang vai.",
`:204-207`). Captures the two cross-body elbow-to-knee distances and X-gaps (`:210-213`). Torso here
is the **left** shoulder-to-hip Y distance (`:196`, also `:261`).

**Stop** (`:136`). `repCount >= maxRep`. No timeout.

**checkSafety** (`:149-154`). Anything but `CameraFacing.front` returns `faceCamera`. No landmark
check; `checkingPose` silently skips any frame where one of the 10 landmarks is missing or
unconfident (`:231-256`).

**Lifting leg** (`:286-304`). In `standing_base`, the leg whose knee is more than 0.12 torso higher
than the other becomes the lifting leg; it is then fixed until the state returns to base. Nothing
requires alternating legs.

**Rep counting** (`:395-481`). "Knee lifted" = lifting knee Y < standing knee Y - 0.12 torso
(`:24`, `:405-407`). While at base with knees level, the cross-body baselines are refreshed
(`:267-275`).

| Transition | Condition | Debounce |
|---|---|---|
| base re-armed after a rep or cancel | \|knee Y difference\| <= 0.10 torso | 4 (`:72`, `:409-415`) |
| standing_base to approaching | knee lifted | 2 (`:69`, `:416-422`) |
| approaching to touch | >= 120 ms in approaching (`:30`), knee lifted, elbow-knee distance shrank >= 0.20 torso **and** X-gap shrank >= 0.08 torso vs the base (`:27-28`, `:427-441`) | 2 (`:70`) |
| approaching to standing_base (cancel) | lifting knee back within 0.10 torso (`:25`) without the cross approach (`:442-448`) | none |
| touch to returning | >= 120 ms in touch (`:31`) and (distance grew > 0.08 torso above its minimum or knee below 0.22 torso lift) (`:26`, `:29`, `:449-466`) | none |
| returning to standing_base, **rep counted** | knee back within 0.10 torso and the cycle took >= 500 ms (`:32`, `:467-479`) | 3 (`:71`) |

A cancelled attempt shows "Không tính rep" / "Đưa gối chạm khuỷu tay đối diện trước khi hạ chân."
and resets the metrics (`:483-496`). A cycle shorter than 500 ms returns to base without counting.

**Anti-cheat.** The relative cross approach (distance and X-gap), the minimum dwell times, the 500 ms
cycle and the 4-frame base re-arm. Tested against camera-cover-like landmark jumps.

**Faults.** The context is built after the state machine (`:337` vs `:348-363`). In
`standing_base` only `CoreDriveMetric.update` runs (to capture the setup shoulder); otherwise all
four run (`:365-371`). One record per type per rep (`metrics/standing_kte_metric_base.dart:61-65`).
None rejects the rep. **No fault is debounced.**

| Type (count key) | Vietnamese message / voice | Metric and threshold | Debounce | affectsForm |
|---|---|---|---|---|
| `knee_valgus` (`knee_valgus_fails_count`) | "Gồng chặt chân trụ! Mở đầu gối ra, đừng để sụp vào trong!" / "Mở gối chân trụ ra!" | approaching or touch: \|standing knee X - ankle X\| / hip width > 0.25 and the knee is closer to the hip midline than the ankle (`metrics/knee_valgus_metric.dart:5`, `:26-50`) | none | true |
| `pelvic_drop` (`pelvic_drop_fails_count`) | "Rớt hông bên chân giơ lên! Gồng chặt cơ mông chân trụ." / "Giữ hông thăng bằng!" | approaching or touch: hip-line tilt > 25 deg and the lifting hip is lower (`metrics/pelvic_drop_metric.dart:6`, `:12-39`) | none | true |
| `core_drive` (`core_drive_fails_count`) | "Hãy nhấc cao đùi lên! Đừng bẻ gập cổ và lưng chúi xuống!" / "Nhấc đùi cao lên!" | touch: lifting knee below lifting hip and lifting-side shoulder dropped > 0.45 torso from the last base frame (`metrics/core_drive_metric.dart:5-6`, `:14-37`) | none | true |
| (none) (`cross_rom_fails_count`) | — | `CrossRomMetric` only records a minimum distance; it never adds a fault (`metrics/cross_rom_metric.dart:8-31`) | n/a | n/a |

**Tests.** `standing_knee_to_elbow_state_test.dart` (4 tests): counts only a complete lift,
cross-touch and controlled return; camera-cover-like landmark jumps cannot create reps; an early
return exposes a no-count coaching correction; a clear relative cross-body approach counts without
literal contact. Also the report builder key contract test. Nothing tests a fault.

**Unverified, stale, or suspicious.**
- **`cross_rom_fails_count` is structurally 0**, so the "Biên độ chạm chéo" detail card
  (`standing_knee_to_elbow_report_builder.dart:80-106`) and the "Chạm chéo" praise always show a
  perfect score. The comment says the absolute gate was removed on purpose
  (`metrics/cross_rom_metric.dart:25-27`); the card was not.
- **Faults survive a too-fast cycle, by reading.** When returning completes in under 500 ms the rep
  is skipped but the metrics are neither reset nor counted (`:471-478`), so their faults are carried
  into the next counted rep.
- No alternation check although the definition and voice copy describe alternating sides; a user
  can do all reps on one leg.
- `core_drive` requires the knee **below** the hip, the opposite of what "Nhấc đùi cao lên" asks
  for, and a shoulder drop of 0.45 torso; comment says "> 30%" (`metrics/core_drive_metric.dart:5-6`).
  Probably rare. By reading.
- Comments disagree with code: `knee_valgus` "15% of hip width" vs 0.25
  (`metrics/knee_valgus_metric.dart:5`); shoulder level "< 10%" vs 0.15.
- Torso length is the left side's shoulder-hip Y distance only (`:196`, `:261`); if the left
  shoulder or hip is mislocated every ratio in the exercise scales with it.
- `knee_valgus` uses distances to the hip midline, so it does not depend on image mirroring.
- `scaleFactor` is not written or read here.
- The definition offers a 45 degree view, which `checkSafety` rejects with `faceCamera`.

---

## Tricep Dip (Floor) (`tricep_dip`)

Source: `lib/exercise/tricep_dip/` (7 files).

**Catalog.** `tricep_dip` (definition `tricep__dip_(_floor)`): 3 sets, 10 reps, `isFormChecked:
true` (`assets/data/exercise_catalog.json:389`). Definition: `TricepDip(maxRep: reps)` via
`_withReps` (`exercise_definition.dart:1213-1214`); description "mỗi lần nhấc mông đủ cao được tính
một rep" (`:1198`); camera hint "Đặt camera đối diện hoặc nghiêng góc 45 độ." but setup tip "Ngồi
nghiêng với camera" (`:1205-1208`). `TricepDipConfig.MAX_REP = 15` is unreferenced
(`tricep_dip.dart:21`).
  FIXED 2026-11-17: camera hint now asks for a side view; result text is Vietnamese.

**Archetype.** Rep-based, counted on the hip lift. Side view, **landscape only** (`:40-44`).
`SideTrackedExerciseMixin` with shoulder, elbow, wrist, hip, ankle required and ear optional
(`:67-96`). Voice: `PolicyVoiceCoach`, slug `tricep_dip`, fault ids `extension`, `hip_thrust`,
`shrug`, `rom` (`:32-37`, `:102-119`). State names describe a bar dip, not the floor movement:
`setup_top` = seated on the floor, `ascending` = hip rising, `bottom` = hip lifted, `descending` =
hip lowering (labels at `:125-136`).

**Start position** (`:163-197`). Not front view; tracked bundle present; scale = shoulder-hip
distance. Wrist and ankle Y within 0.55 torso of each other ("Đặt bàn tay và bàn chân cùng chống chắc
xuống sàn.", `:22`, `:178-185`); hip height above the wrist-ankle ground line between -0.10 and 0.65
torso ("Ngồi để mông chạm sàn trước khi bắt đầu.", `:23-24`, `:186-191`). Captures the setup hip Y and
scale.

**Stop** (`:139`). `repCount >= maxRep`. No timeout.

**checkSafety** (`:153-160`). Only `CameraFacing.front` returns `turnSide`; angled is accepted.
Tracked bundle missing returns `bodyInFrame`. No `lighting` signal.

**Rep counting** (`:247-278`). Hip lift = (setup hip Y - hip Y) / setup scale; "grounded" = wrist
and ankle Y within 0.55 torso (`:216-219`). Elbow angle is never computed.

| Transition | Condition | Debounce |
|---|---|---|
| setup_top to ascending | grounded and lift >= 0.16 (`:25`, `:252-256`) | 2 (`:54`) |
| ascending to bottom, **rep counted** | grounded and lift >= 0.22 (`:26`, `:257-261`) | 2 (`:55`) |
| ascending to setup_top | lift <= 0.07 (`:28`, `:262-263`) | none |
| bottom to descending | lift <= 0.12 (`:27`, `:265-268`) | 2 (`:56`) |
| descending to setup_top | grounded and lift <= 0.07; setup hip Y moves 20% toward the current hip Y (`:270-276`) | 2 (`:57`) |

**Anti-cheat.** Hands and feet must stay on one ground line, and the user must return to seated
before the next lift (tested). Nothing checks that the elbows bend.

CHANGED 2026-11-21 (device test, `docs/field-test-log.md` 5.11): the hip-lift table above is gone.
Reps are counted on the camera-side elbow angle: below 150 starts the descent, at or below 120 is the
bottom, at or above 130 starts the push, at or above 150 counts the rep (2 frames each, hands and feet
still grounded). The hips may stay off the floor between reps; a hip lift with straight arms is not a
rep. Rep logs carry `min_elbow_angle` and `top_elbow_angle`.

**Faults.** **None are evaluated.** The four metric objects are created (`:60-64`) but no code calls
their `update` or `onStateTransition`; `_completeRep` builds an empty fault list (`:295-297`), so every
rep is logged with `correctForm = true`, and `liveFaults` is not overridden. The table lists what
the unwired metrics would check.

| Type (count key) | Vietnamese message / voice | Metric and threshold (not live) | affectsForm |
|---|---|---|---|
| `hip_thrust` (`hip_thrust_fails_count`) | "Đừng chỉ đẩy hông! Hãy gập khuỷu tay của bạn lại!" / "Gập khuỷu tay lại, đừng chỉ đẩy hông!" | in descending, hip Y moved > 0.45 forearm while elbow changed < 16 deg (`metrics/hip_thrust_metric.dart:5-8`, `:43-54`) | true |
| `rom` (`rom_fails_count`) | "Gập tay sâu hơn cho đến khi mông gần chạm sàn." / "Xuống sâu hơn chút nữa!" | bottom to ascending without elbow <= 145 (`metrics/tricep_rom_metric.dart:5-6`, `:39-53`) | false |
| `extension` (`extension_fails_count`) | "Chưa duỗi thẳng tay hoàn toàn! Hãy đẩy thẳng tay lên để siết cơ." / "Đẩy thẳng tay lên!" | ascending to descending transition (`metrics/full_extension_metric.dart:31-46`) | false |
| `shrug` (`shrugging_fails_count`) | "Ưỡn ngực, hạ vai xuống, cách xa mang tai!" / "Hạ vai xuống!" | \|ear Y - shoulder Y\| / forearm < 0.35 (`metrics/scapular_elevation_metric.dart:5-6`, `:26-45`) | false |

**Tests.** `tricep_dip_floor_setup_test.dart` (2 tests): starts seated on the floor and counts when
the hip is lifted; requires a return to the seated setup before another lift. Also report builder
key contract and registry tests.

**Unverified, stale, or suspicious.**
- **Form checking is not wired: every rep is a good rep and all three detail cards
  (`tricep_dip_report_builder.dart:78-111`) show 100%, while the catalog says `isFormChecked:
  true`.** This is the clearest case in the file of a report card that cannot show a fault.
  FIXED 2026-11-17: `isFormChecked: false` in the catalog JSON and `supabase/seed.sql`; detail cards, praise, tips and pain mapping removed; the four always-zero keys are no longer pushed.
- **A hip lift with straight arms counts as a dip, by reading.** Counting uses only hip height; a
  user who bridges the hips up with the legs scores reps. The metric that would catch it
  (`hip_thrust`) is unwired.
  CONFIRMED 2026-11-17, not changed: report only.
- Even if wired, the metrics assume a bar-dip state machine: `extension` fires on ascending to
  descending, a transition this machine cannot make (`metrics/full_extension_metric.dart:27-33`
  comments show the author unsure), and `rom` waits for bottom to ascending, which also cannot
  happen.
- Comments disagree with values: hip thrust "30% of forearm" / "less than 10 degrees" vs 0.45 / 16;
  ROM "> 130 at bottom" vs 145.
- The setup hip Y drifts toward wherever the user sits after each rep (`:274-275`).
- `scaleFactor` is not written; the exercise uses its own `_setupScale`.

---

## Step-Back Burpee

Source: `lib/exercise/step_back_burpee/` (6 files).

**Catalog.** `step_back_burpee` (definition `step__back__burpee`): 3 sets, 8 reps, `isFormChecked:
true` (`assets/data/exercise_catalog.json:356`). Definition: `StepBackBurpee(maxRep: reps)` via
`_withReps` (`exercise_definition.dart:1187-1188`); subtitle "Chưa có mô tả", description "Bản xem
trước của bài tập Step-Back Burpee.", camera hint "Đặt camera đối diện hoặc nghiêng góc 45 độ."
(`:1172-1180`). `BurpeeConfig.MAX_REP = 15` is unreferenced (`step_back_burpee.dart:19`).

**Archetype.** Rep-based, six states (standing, squattingDown, steppingBack, highPlank,
steppingForward, standingUp). Side view, **landscape only** (`:35-39`). One side via
`getSideLandmark` (right landmarks when facing right, else left). Voice: `PolicyVoiceCoach`, slug
`step_back_burpee`, fault ids `squat_hinge`, `squat_depth`, `plank_sag`, `plank_extension`
(`:27-32`, `:67-89`).

**Start position** (`:113-153`). Shoulder, hip, ankle, wrist, knee present with ML Kit
`likelihood >= 0.5` (not the shared `isLandmarkConfident` rule, `:142-146`); body angle
(shoulder-hip-ankle) >= 155 (`:20`, `:151`).

**Stop** (`:156`). `repCount >= maxRep`. No timeout.

**checkSafety** (`:167-172`). Only `CameraFacing.front` returns `turnSide`; angled is accepted (and
then uses the left side). No landmark check, and `checkingPose` only checks for null landmarks
(`:201-206`); unconfident landmarks are used as they are.

**Signals** (`:209-229`). Knee, body (shoulder-hip-ankle), hip (shoulder-hip-knee), elbow and
shoulder-to-arm (hip-shoulder-wrist) angles; wrist-ankle X-distance and wrist-minus-shoulder Y, both
divided by the base class's `scaleFactor` (raw shoulder-hip distance if that is 0).

**Rep counting** (`:309-357`). `isStandingStraight` = body angle > 155 on 3 consecutive frames
(`:48`, `:331-332`). `isHighPlank` (3 frames, `:47`, `:322-329`) = wrist-ankle X > 0.55 torso
(`:23`), body angle > 135, wrist 0.25-1.60 torso below the shoulder, shoulder-to-arm angle 25-155.
The branches are an `else if` chain.

| Transition | Condition | Debounce |
|---|---|---|
| standing to squattingDown | not `isStandingStraight` (one frame <= 155 breaks the 3-frame run) | none |
| squattingDown to steppingBack | knee < 120 and body < 120 and wrist-ankle X > 0.2 (`:319`, `:336-339`) | none |
| squattingDown or steppingBack to highPlank | `isHighPlank` | 3 |
| highPlank to steppingForward | not `isHighPlank` and wrist-ankle X < 0.605 (`:345-348`) | none |
| steppingForward to standingUp | body angle > 100 (`:349-350`) | none |
| standingUp to standing, **rep counted** | `isStandingStraight` (`:351-352`, `:264-306`) | 3 |
| any other state to standing (abort, no rep) | `isStandingStraight` (`:353-356`) | 3 |

**Anti-cheat.** A rep must pass through `highPlank` (the only way into `standingUp`). Stepping back
is not required (`squattingDown` can go straight to `highPlank`), and nothing distinguishes a
step-back from a jump-back.

**Faults.** The context is built before the state machine (`:234-244` vs `:254`), so metrics see the
pre-transition state; the evaluating `onStateTransition` hooks run inside the state machine. None
rejects the rep. No fault record in this exercise carries a `voiceMessage`. `spine_fails_count` and
`plank_form_fails_count` = counted reps with any record of that metric, warnings included
(`:160-161`, `metrics/step_back_burpee_metric_base.dart:62-65`).

| Type (count key) | Vietnamese message (live text) | Metric and threshold | Debounce | affectsForm |
|---|---|---|---|---|
| `squat_hinge` (`spine_fails_count`) | "Lỗi nguy hiểm: Cúi gập lưng với chân thẳng. Hãy trùng gối!" ("Trùng gối xuống! Đừng cúi lưng.") | on entering `highPlank`: minimum knee angle during squattingDown/steppingBack > 160 (`metrics/squat_hinge_metric.dart:14`, `:51-62`) | none | true |
| `squat_depth` (same key) | "Hạ hông và gập gối sâu hơn nữa khi chạm đất." | same, minimum > 115 (`:13`, `:63-70`) | none | false |
| `plank_sag` (`plank_form_fails_count`) | "Lưng bị gập quá mức khi nằm!" ("Gồng bụng! Đang võng lưng.") | on leaving `highPlank` for steppingForward: minimum body angle in highPlank < 140 (`metrics/plank_form_metric.dart:12`, `:65-75`) | none | true |
| `plank_extension` (same key) | "Chân chưa duỗi thẳng hết cỡ khi nằm xuống." ("Bước chân lùi xa hơn nữa!") | same, maximum hip angle in highPlank < 145 (`:14`, `:78-86`) | none | false |

`SAG_WARNING = 150` and `ARM_BENT_WARNING = 135` are unused; the bent-arm check was removed "because
lying fully on the floor the arms must bend" (`metrics/plank_form_metric.dart:11`, `:15`, `:88`).

**Tests.** No dedicated test. Report builder key contract and registry tests only. Nothing tests the
state machine or any fault.

**Unverified, stale, or suspicious.**
- **`squat_hinge` can only fire when the steppingBack state was skipped, by reading.** Entering
  `steppingBack` needs knee < 120 (`:319`, `:336-337`), so a rep that passed through it has a
  minimum knee angle under 120 and cannot exceed 160. The stiff-leg fault needs the user to go from
  squattingDown straight to `highPlank` while the knee never dropped to 160 in those frames.
- **The plank posture is contradictory.** The comment says "lie fully on the floor: shoulder must
  come down near the wrist (small Y distance)" (`:321`), the code requires the wrist 0.25-1.60 torso
  **below** the shoulder (a straight-arm high plank), and the plank metric drops the bent-arm check
  because "lying fully on the floor the arms must bend". Which posture a coach should label as
  correct is not settled in the code.
- `plank_sag` uses the unsigned shoulder-hip-ankle angle, so a pike lowers it exactly like a sag and
  logs "Lưng bị gập quá mức khi nằm!".
- `spine_fails_count` holds only the squat faults (including the `squat_depth` warning); `plank_sag`
  goes to `plank_form_fails_count`, although the V2 report tip for `spine_fails_count` mentions the
  plank (`step_back_burpee_report_builder_v2.dart:14-18`).
- Several transitions are single-frame (standing to squattingDown, squattingDown to steppingBack,
  highPlank to steppingForward, steppingForward to standingUp).
- Comment "PHẢI gập gối (< 100 độ)" (`metrics/squat_hinge_metric.dart:7`) vs 115.
- Landmark confidence is never checked after activation.
- `scaleFactor` is read from the base class (`:220-224`), not written.
- `report/step_back_burpee_report_builder.dart` is marked "DEAD LEGACY" (`:7-8`).
- The definition offers a front or 45 degree view; front returns `turnSide`.

---

## Warrior I (`warrior_1`)

Source: `lib/exercise/warrior_1/` (8 files).

**Catalog.** `warrior_one`: 1 set, 2 reps, `isFormChecked: true`
(`assets/data/exercise_catalog.json:433`). Definition: `WarriorOne(maxHolds: reps)` via `_withReps`
(`exercise_definition.dart:497-498`); the description says "mỗi bên 30 giây" and the card "2 × 30s"
(`:480`, `:486`). A separate onboarding definition `warrior_one_assessment` uses
`WarriorOne(maxHolds: reps ?? 1)` (`:210-232`).

**Archetype.** Static hold with its own entry/hold/exit machine (not `RepCountedHoldExercise`); one
"rep" per side. Side view. Does not override `supportedOrientations`, so portrait only (base default,
`exercise_base.dart:286-287`). Does not override `createVoiceCoach` and does not pass `targetReps`
to the base constructor (`warrior_one.dart:79`); which voice coach runs was not traced. Hold length
`HOLD_DURATION = 20.0` s per side (`:39`).

**Front and back leg** (`:130-166`). Facing left: the leg whose ankle has the smaller X is the front
leg; facing right: the larger X. 5-frame `StickyDebouncer` starting at "left in front", locked when
the hold starts and unlocked for the next side. This is Plank's and Lunge's convention (finding 6);
the stress test encodes it (facing left, left ankle at x=125, right ankle at x=330). Torso, head
and arm landmarks come from `getSideLandmark` (camera side).

**Start position** (`:264-302`). Facing left or right; camera-side shoulder above hip; \|trunk lean\|
<= 40 deg (`:49`, `:292-294`); ankle distance / `scaleFactor` >= 0.65 (`:52`, `:297-299`; comment
says "> 0.8", `:296`).

**Stop** (`:204`). `repCount >= maxHolds`. No timeout.

**checkSafety** (`:234-259`). Not left/right returns `turnSide`. Any of 8 landmarks (both hips,
shoulders, knees, ankles) missing returns `bodyInFrame`; any unconfident returns `lighting`.
`checkingPose` also needs the camera-side ear, elbow and wrist and silently skips frames without
them (`:339-351`); their confidence is not checked except the wrist for the elbow sub-check.

**Hold counting** (`:593-624`).

| Transition | Condition | Debounce |
|---|---|---|
| entry to hold (captures trunk and cervical baselines, locks front leg) | still (hip Y moved < 2.5 **px** per frame, `:43`, `:682-691`) and front knee <= 165, back knee >= 140, arm-from-vertical <= 60 (`:55-57`, `:388-393`) | 10-frame sticky still gate (`:46`, `:101-102`) |
| hold to exit, **hold counted** | wall-clock time since the hold started >= 20 s (`:606-609`, `:693-696`) | none |
| exit to entry (next side) | `repCount < maxHolds`; shows "Đổi chân! Đưa chân kia ra trước." (`:612-622`) | none |

A frame with no skeleton during `hold` drops back to entry and discards the hold
(`processNoPoseFrame`, `:665-676`). Nothing else interrupts it.

**Anti-cheat.** Only the entry gate. Once the hold has started, the 20 s run on the wall clock
whatever the pose (see below). The side switch is prompted but not checked.

**Faults.** Metrics run only in `hold`, with the context built before the state machine (`:396-410`
vs `:431`), so on the first hold frame they see `entry` and skip. Hold seconds use the shared
accumulator with `goodBlockingKeys = trunk_lean_seconds, arm_seconds` (`:460-470`), so
`good_seconds` excludes only trunk-lean and arm-fault frames; cervical, back-knee and back-straight
frames still count as good (`lib/utils/hold_seconds_accumulator.dart:66-79`). `total_seconds` is
`maxHolds x 20` regardless of the time actually held (`:215-216`). Only `trunk_lean` has
`affectsForm: true`; the hold always counts.

| Type (seconds key) | Message (English) / voice (Vietnamese live text) | Metric and threshold | Debounce | affectsForm |
|---|---|---|---|---|
| `trunk_lean` (`trunk_lean_seconds`) | "Trunk collapsing forward (>30°)" / "Đứng thẳng hơn" ("Cẩn thận lưng! Đứng thẳng hơn, đừng gập quá nhiều.") | signed trunk lean > 30 (`metrics/trunk_lean_metric.dart:40`, `:84-96`) | 8 (`:55`) | true |
| `cervical_danger` (`cervical_seconds`) | "Head thrown back (cervical hyperextension)" / "Đừng ngửa đầu ra sau" ("Cẩn thận cổ nhé! ...") | ear-shoulder-hip angle, One-Euro plus 7-frame median, < 125 (`metrics/cervical_safety_metric.dart:40`, `:85-105`) | sticky 20 (`:59-60`) | false |
| `Arms` (`arm_seconds`) | "Arms hanging forward — reach overhead" / "Vươn tay cao hơn" ("Vươn tay cao hơn nhé!") | wrist-from-shoulder angle from vertical > 55 (`metrics/arm_position_metric.dart:30`, `:77-88`) | 10 (`:48`) | false |
| `Arms` (same) | "Elbows bent — straighten the arms" / "Duỗi thẳng tay" | arm <= 45 from vertical, wrist confident, elbow < 135 (`:27`, `:37`, `:95-108`) | 10 (`:49`) | false |
| `back_knee` (`back_knee_seconds`) | "Back knee bent / floppy" / "Duỗi thẳng chân sau" ("Duỗi thẳng chân sau hơn nhé! ...") | back knee angle < 130 (`metrics/back_knee_metric.dart:29`, `:63-75`) | 10 (`:41`) | false |
| `Spine` (`back_straight_seconds`) | "Hunched back — open chest and straighten spine" / "Thẳng lưng lên, mở rộng ngực" ("Lưng đang bị gù! ...") | ear-shoulder-hip angle < 130 (`metrics/back_straight_metric.dart:21`, `:58-73`; angle from `warrior_one.dart:377-378`) | 10 (`:32`) | false |

The front-knee depth and stance checks ("Check 3", "Check 4") only reach comments; they produce no
fault, text or log (`warrior_one.dart:511-528`, `:558-569`).

**Tests.** `warrior_one_stress_test.dart` (5 tests, facing left): the registry resolves the Warrior
I launch names; safety and start gates reject bad framing before activation; a stable good hold
completes one side without form faults; a sustained trunk collapse fails the hold; coaching-only arm
and back-knee faults do not fail the hold. Also report builder key contract and registry tests.

**Unverified, stale, or suspicious.**
- **The hold timer keeps running after the user leaves the pose, by reading.** Hold time is
  `frameTimestampMs - _holdStartMs` (`:693-696`), and the only exit from `hold` is reaching 20 s.
  Dropping the arms, straightening the front knee or standing up does not pause or end it; frames
  missing the ear, elbow or wrist are skipped while the clock runs. Only a frame with no skeleton
  at all resets the hold. A coach labelling "held for 20 s" against the app's count should expect
  holds the app credits that were not held.
- **One signal, two opposite cues.** `cervical_danger` ("head thrown back") and `Spine` ("hunched,
  head forward") both threshold the same unsigned ear-shoulder-hip angle (`:361-362`, `:377-378`),
  which cannot tell forward from backward. Any posture under 125 deg fires both, telling the user
  "Đừng ngửa đầu ra sau" and "Thẳng lưng lên, mở rộng ngực" together.
- **Head-direction convention (finding 6).** If facing left actually means front toward larger X,
  the front and back legs swap: the "front knee <= 165" entry gate reads the straight back leg and
  the hold never starts; and forward trunk lean reads negative, so `trunk_lean` would only fire for
  leaning back.
- The side switch is not checked: `_resetForNextSide` clears the front-leg detection (`:648-663`)
  but nothing requires the other leg to lead, so both holds can be on the same side.
- Hold length is 20 s in code vs 30 s per side in the definition copy.
- Comments disagree with code: trunk "good 10-25, warning 25-30, error > 30" with `GOOD_MAX = 35`
  above `ERROR_THRESHOLD = 30` (`metrics/trunk_lean_metric.dart:16-19`, `:30-40`); cervical "Good
  ≥ 140°" vs 125 (`metrics/cervical_safety_metric.dart:25-28`); arm "too low > 60°", "too bent <
  130°" vs 55 / 135 (`metrics/arm_position_metric.dart:15-17`); back knee "Good ≥ 160°, warning
  150-160, < 150 fault" vs 145 / 130 (`metrics/back_knee_metric.dart:13-16`, `:28-30`); still gate
  "normalized units / sec ... ESTIMATE" on a pixels-per-frame value (`warrior_one.dart:41-43`).
- Fault types are inconsistent (`Arms`, `Spine` capitalised; one `Arms` type for two different
  faults) and logged messages are English.
- `scaleFactor` is read from the base class (`:297`, `:384`), not written.

---

## Cobra

Source: `lib/exercise/Cobra/` (9 files).

**Catalog.** `cobra` (definition `cobra_`): 1 set, 3 reps, `isFormChecked: true`
(`assets/data/exercise_catalog.json:59`). Definition: `Cobra(maxRep: reps)` via `_withReps`
(`exercise_definition.dart:960-961`); description "3 lần giữ × 15 giây", setup "đặt camera thấp
ngang thân" (`:943`, `:953`).

**Archetype.** Static hold with its own setup/holding/resting machine (not
`RepCountedHoldExercise`); one "rep" per 15 s hold (`cobra.dart:19`). Side view. Does not override
`supportedOrientations`, so portrait only (base default), unlike Plank. Does not override
`createVoiceCoach` or `liveFaults` and does not pass `targetReps` (`:47`). The metrics use their own
`FaultRecord` class with no `voiceMessage` or `priority` (`metrics/cobra_metric_base.dart:51-63`);
all logged messages are English.

**Head direction.** Horizontal trunk targets are clock 270 for facing left and 90 for facing right
(`:26-27`), i.e. head toward smaller X when facing left: Plank's convention (finding 6).

**Start position** (`:116-145`). Camera-side shoulder and hip present; trunk within 35 deg of the
facing's horizontal target (`:30`, `:131-139`; comment says "within 25°", `:130`). Every passing
frame feeds the calibration (hip Y, trunk length, and the ear-relative neck angle when ear
likelihood >= 0.5); after 20 samples the baselines are averaged and frozen for the set
(`:36`, `:148-185`). Samples are never cleared, so frames from earlier, abandoned activations count.

**Stop** (`:193`). `repCount >= maxRep`. No timeout.

**checkSafety** (`:221-246`). Not left/right returns `turnSide`; camera-side shoulder or hip missing
returns `bodyInFrame`, unconfident returns `lighting`. No other landmark is required; elbow, wrist,
ear and knee may be null and the metrics then skip.

**Hold counting** (`:400-445`). Cobra position = not standing and trunk raised more than 18 deg
past horizontal (clock > 288 facing left, < 72 facing right; `:33`, `:402-413`; comment "at least
25 degrees", `:32`). Standing = (floor Y - hip Y) / `scaleFactor` > 0.5, where floor Y is the
**left** foot index, else right foot index, heel, knee or hip (`:23`, `:294-305`).

| Transition | Condition | Debounce |
|---|---|---|
| setup to holding (wall-clock start) | cobra position | 2 (`:61`) |
| holding to resting, **hold counted** | wall clock since hold start >= 15 s (`:427-428`) | none |
| holding to setup (hold abandoned, not counted) | not cobra position **and** trunk within 35 deg of horizontal (`:429-433`) | 3 (`:62`) |
| resting to holding | >= 5 s since rest began (`:20`) and cobra position (`:436-442`) | 2 |

**Anti-cheat.** Only the cobra-position entry gate. The user does not have to lower between holds:
staying up through the 5 s rest starts the next hold.

**Faults.** Hand placement runs in every state including setup; the others run outside setup
(`:336-345`). The context is built after the state machine (`:309` vs `:312-332`). Seconds keys use
the shared accumulator without `goodBlockingKeys` (`:347-356`); `total_seconds` = `maxRep x 15`
whatever was held (`:203`). At hold completion the hold's correctness is computed from the faults,
but the per-hold `setFeedback` entry gets an empty fault map and the `RepLog` has empty data
(`:489-495`), so no per-hold fault list is recorded.

| Type (seconds key) | Logged message (live text) | Metric and threshold | Debounce | affectsForm |
|---|---|---|---|---|
| `ElbowLockout` (`elbow_flexion_seconds`) | "Elbow locked out" ("⚠️ Khuỷu tay duỗi quá thẳng!") | shoulder-elbow-wrist >= 170 (`metrics/cobra_elbow_metric.dart:17`, `:51-56`) | sticky 8 (`:22`) | true |
| `HandsTooFar` (`hand_placement_seconds`) | "Hands placed too far forward" ("⚠️ Tay đặt quá xa!") | \|wrist X - shoulder X\| / trunk >= 0.60 (`metrics/cobra_hand_placement_metric.dart:19`, `:46-57`) | sticky 12 (`:24`) | true |
| `NeckHyperextension` (`cervical_neutrality_seconds`) | "Neck hyperextension" ("⚠️ Đầu ngửa quá nhiều!") | (shoulder-to-ear clock - hip-to-shoulder clock) > 60, ear likelihood >= 0.5 (`metrics/cobra_cervical_metric.dart:18-19`, `:44-70`) | sticky 8 (`:24-25`) | true |
| `HipLift` (`pelvic_grounding_seconds`) | "Hip significantly lifted" ("⚠️ Hông nâng quá cao!") | (baseline hip Y - hip Y) / baseline trunk >= 0.28, hip likelihood >= 0.4 (`metrics/cobra_elevation_metric.dart:16-17`, `:41-69`) | sticky 15 (`:23`) | true |
| `CrashDescent` (no key) | "Crash descent" ("⚠️ Hạ quá nhanh!") | shoulder Y speed >= 2.8 trunk/s on 5 frames during descent (`metrics/cobra_descent_metric.dart:14-15`, `:77-83`) | 5 frames | true |
| `FastDescent` (no key) | "Descent too fast overall" | back within 5 deg of horizontal < 0.8 s after descent began (`:96-103`) | none | true |
| `UnstableHold` (no key) | "Giữ tư thế chưa ổn định (SD=X°)" | at hold end, SD of trunk deviation > 18 (`metrics/cobra_hold_stability_metric.dart:17`, `:66-88`) | none | false |

Live-only bands: elbow 140-170 "Cong khuỷu tay thêm chút"; hands >= 0.50 "Kéo tay về gần vai hơn",
<= 0.04 "Tay đặt hơi gần, đẩy ra chút"; neck > 45 "Hạ đầu xuống chút", < -30 "Ngẩng đầu lên chút";
hip lift >= 0.18 "Ép hông xuống sàn hơn".

**Tests.** `cobra_logging_regression_test.dart` (3 tests, facing right): Cobra publishes seconds keys
after metric faults; the hold stability fail count increments under real hold wobble; the report
builder scores timed holds from seconds. Also report builder key contract and registry tests.

**Unverified, stale, or suspicious.**
- **The neck check depends on facing, by reading.** The cervical angle is a raw clock difference
  with no per-facing sign (`metrics/cobra_cervical_metric.dart:50-59`). Facing left, lifting the
  head moves both clocks toward 360 and extension reads positive. Facing right, the clocks move
  toward 0 and extension reads **negative**: `NeckHyperextension` (> 60) cannot fire, and an
  extended head instead shows "Ngẩng đầu lên chút" (lift your head), the opposite cue. The
  calibrated neck baseline is computed and never used.
- **`CrashDescent` and `FastDescent` can never be logged, by reading.** Descent starts only once the
  trunk drops 5 deg below the peak tracked during `holding`, and is measured only outside `holding`
  and outside `setup` (`:338-345`; `metrics/cobra_descent_metric.dart:41-57`). On holding to
  resting, `_onHoldComplete` runs `resetAndCountFault()`, which clears the peak
  (`cobra.dart:476-499`, `metrics/cobra_descent_metric.dart:139-147`); on holding to setup the
  metric stops running. Either way no descent is ever measured.
- **The hold timer does not stop when the user leaves the pose**, unless they lie back down to
  within 35 deg of horizontal. Standing up or kneeling mid-hold keeps the 15 s wall clock running
  and the hold counts. By reading.
- An abandoned hold (holding to setup) does not reset the metrics, so its faults carry into the next
  completed hold; its accumulated good and fault seconds also stay in the set totals.
- The pelvic baseline needs 20 passing start-position frames; at a low frame rate the 3 s
  activation may not collect them and `HipLift` is then silent for the whole set
  (`metrics/cobra_elevation_metric.dart:47-50`). Comments say 0.18 / 0.12 for values 0.28 / 0.18
  (`:64`, `:71`). The file is named `cobra_elevation_metric.dart` but defines `CobraPelvicMetric`.
- Comments disagree with code elsewhere: elbow warning "140-160°" (`metrics/cobra_elbow_metric.dart:57`)
  vs 140-170; cervical error "(>45°)" vs 60 (`metrics/cobra_cervical_metric.dart:65`).
- `CobraConfig.COBRA_OVEREXTENSION_MAX` and `COBRA_ELBOW_LOCKOUT_MIN` are unreferenced within
  `Cobra/` (`:38-39`). (Correction from batch 4: Surya Namaskar's safety overrides read both,
  `surya_namaskar/safety_overrides.dart:184-185`.)
- Standing detection reads the left foot whichever side faces the camera.
- `scaleFactor` is read from the base class (`:299-304`), not written.

---

## Sphinx Pose

Source: `lib/exercise/Sphinx_Pose/` (6 files) on top of `lib/exercise/hold/` (re-read for this
batch).

**Catalog.** `sphinx` (definition `sphinx_`, "Sphinx Pose"): 1 set, 1 rep, 30 s,
`isFormChecked: true` (`assets/data/exercise_catalog.json:323`). Definition:
`SphinxStretch(maxHolds: reps ?? 1, holdSeconds: seconds ?? 30)` (`exercise_definition.dart:1130-1133`),
target type seconds. The definition's description and duration say "3 lần giữ × 15 giây" / "3 × 15s"
(`:1113`, `:1119`), which disagrees with the catalog's 1 x 30 s.

**Archetype.** Hold-based, reps of holds via `RepCountedHoldExercise`. Side view, landscape only
(`sphinx_stretch.dart:58-63`). Entry and exit debounce are both **1 frame** (`:68-72`; base defaults
4 and 2).

**Side selection** (`:446-480`). A side qualifies when its shoulder, hip and ankle are all confident;
the side with the larger likelihood sum wins, left on a tie. `cameraFacing` is not used.

**Start position** (`:133-195`). A side qualifies, and either:
- body angle (shoulder-hip-ankle) >= 140 (`metrics/sphinx_metric_base.dart:8`, `:153-158`), which
  returns true immediately, so lying flat on the floor passes; or
- elbow, wrist and knee confident, elbow angle (shoulder-elbow-wrist) 45 to 165 and spine angle
  (shoulder-hip-knee) 105 to 172 (`:176-194`, base `:9-10`, `:21-22`).

By reading, the first branch passes for any prone body including a sphinx (whose shoulder-hip-ankle
angle is far above 140), so the second branch and its confidence check almost never run.

**Stop.** `repCount >= maxHolds` (`hold/rep_counted_hold_exercise.dart:139`). No timeout.

**checkSafety** (`:117-130`). Not side view returns `turnSide` and cancels re-arm. No side with
shoulder, hip and ankle confident returns `bodyInFrame`, drops an active hold to `dropping`
(`wall_guard`) and cancels re-arm. Elbow, wrist, knee and ear are only checked for presence: if any
is missing `samplePose` returns null and the hold is interrupted (`:244-252`,
`hold/rep_counted_hold_exercise.dart:172-177`); low confidence is not checked.

**Hold counting.** Shared machine (described under High Plank), with:
- entry ("inside outer entry"): elbow 45 to 155 and spine 105 to 175 (`:291-294`, base `:9-10`)
- exit to `dropping` ("outside outer exit"): elbow > 165 or spine > 172 (`:295-296`, base `:21-22`)

A hold completes, and `repCount` increments, when accumulated holding time reaches `holdSeconds`
(30 s from the catalog). Rest 5 s, re-arm 3 s. The live "Time" text from `HoldTempoMetric` shows
"x.xs / 30s" with a hard-coded 30 (`metrics/hold_tempo_metric.dart:41-42`, base `:12`) whatever
`holdSeconds` is, and it times segments by wall clock, not by the shared accumulator.

**Anti-cheat.** Elbow > 165 (straight-arm Cobra) or spine > 172 (lying flat) pauses the clock on a
single frame. Nothing checks that the pelvis stays on the floor: `Ad_Hip_Ground_Tol` is unreferenced
(base `:11`).

**Faults.** `updateFormMetrics` runs metrics in `holding` and `dropping` (`:319-324`) with the
post-transition phase, but the arm and neck metrics act only when the mapped state is
`isometricHold`, i.e. `holding` (`metrics/elbow_angle_metric.dart:31-34`,
`metrics/neck_shoulder_metric.dart:40-43`). Each record has `affectsForm: true`, and one record per
type per hold is kept (`elbow_angle_metric.dart:93-95`, `neck_shoulder_metric.dart:105`). A single
record marks the hold `correctForm = false` (`hold/rep_counted_hold_exercise.dart:336-337`). No fault
stops the clock; faulting frames add to `straight_arm_seconds` (any arm fault) or
`shrug_neck_seconds` (shrug or neck extension) (`:326-329`). Log types are remapped (`:420-428`).

| Type (log type, seconds key) | Vietnamese message / voice (live text) | Metric and threshold | Debounce | Counts the hold? |
|---|---|---|---|---|
| `StraightArm` (`straight_arm`, `straight_arm_seconds`) | "Lỗi đẩy thẳng tay" / "Gập cùi chỏ lại" ("Gập khuỷu tay lại!") | elbow angle > 155 (`metrics/elbow_angle_metric.dart:46-47`, base `:9`) | 4 (`:11`) | yes |
| `Forearm` (`forearm`, `straight_arm_seconds`) | "Cẳng tay không song song sàn" / "Hạ cẳng tay xuống sàn" ("Hạ cẳng tay xuống sàn!") | elbow-to-wrist horizontal angle > 55 (`:60-61`, base `:19`) | 4 (`:12`) | yes |
| `UpperArm` (`upper_arm`, `straight_arm_seconds`) | "Cánh tay không vuông góc sàn" / "Chống tay vuông góc với sàn" ("Cánh tay phải vuông góc!") | shoulder-to-elbow horizontal angle < 55 (`:70-71`, base `:20`) | 4 (`:13`) | yes |
| `NeckShrug` (`shrug`, `shrug_neck_seconds`) | "Lỗi rụt vai" / "Thẳng vai ra" ("Thẳng vai!") | ear-to-shoulder distance / `scaleFactor` < 0.10 (`metrics/neck_shoulder_metric.dart:52-57`, base `:13`) | 6 (`:15`) | yes |
| `NeckHyper` (`neck`, `shrug_neck_seconds`) | "Lỗi ngửa cổ" / "Hạ cằm xuống nhìn xuống thảm" ("Hạ cằm xuống!") | ear-shoulder-hip angle < 110 (`:83-84`, base `:18`) | 6 (`:16`) | yes |
| `wall_guard` (break id) | none | exit gate, lost side, or missing landmark | 1 | clock paused |

The three arm checks are an `else if` chain (`elbow_angle_metric.dart:46-84`): at most one arm
fault per frame, and the lower branches' debouncers are not updated while a higher one fires. An
elbow below 45 only shows "Đẩy ngực lên!", with no fault. The straight-arm fault can only exist in
the 155-165 band: above 165 the exit gate fires first and the metric sees `dropping`.

`HoldTempoMetric` also computes a "stability score" from the variance of the spine angle over the
hold's frames: 100 - 10 x variance / 35, floored at 0 (`metrics/hold_tempo_metric.dart:67-86`, base
`:14`). It is not a fault.

**Tests.** `hold_voice_scale_migration_test.dart` (2 Sphinx tests): the engine timer logs
`straight_arm` and preserves report keys; the three arm branches stay voice-distinct. The
straight-arm pose in that test has an elbow angle of about 160 deg (in the 155-165 band), and the
test asserts `hip_seconds == 0.0` (`:46`, `:183`). `exercise_logging_alignment_test.dart`: the hold
publishes `max_rep` and no `target_rep`. Report builder key contract and registry tests. Nothing
tests the neck metric, the start position or the entry/exit thresholds.

**Unverified, stale, or suspicious.**
- **`hip_seconds` is always 0 and its report line is always perfect.** `onSetComplete` pushes
  `hip_seconds = 0.0` (`sphinx_stretch.dart:394`); there is no hip metric (`Ad_Hip_Ground_Tol` and
  `SphinxFaultVoicePriority.hipLift` are unreferenced, base `:11`, `:60`). The report still praises
  "Hông giữ ổn định trong c/t giây" and maps lower-back pain to that key
  (`sphinx_report_builder.dart:11`, `:33`, `:40`). The test pins the zero.
  FIXED 2026-11-17: `hip_seconds` is no longer pushed, and the tip, praise and lower-back pain
  mapping are removed from the builder; the tests that pinned the zero now pin its absence.
- **`NeckShrug` probably cannot fire, by reading.** It needs the ear within 0.10 shoulder-hip
  lengths of the shoulder. In a side view the ear sits several times that distance from the
  shoulder, and shrugging moves it only slightly. Not measured.
  CONFIRMED 2026-11-17 by reading, not changed: in the test fixture the ear sits 0.50 torso from
  the shoulder; a shrug would have to remove ~80% of that. Report only.
- **`NeckHyper` is set far from its comment.** The comment says neutral is ~160-170 and "< 140 là
  ngửa" (base `:16-17`); the code uses 110, i.e. roughly 50-60 deg of neck extension beyond neutral.
  By reading it fires rarely.
  CONFIRMED 2026-11-17 by reading, not changed: the test fixture's neutral head reads 180 deg;
  reaching < 110 needs about 70 deg of extension. Report only; the "< 140" comment now says 110.
- **Spine 172-175 flaps every frame, by reading.** Such a frame is both inside the entry (<= 175)
  and outside the exit (> 172). With 1-frame debounces the phase alternates `holding` / `dropping`
  each frame; the timer arms on entry and is cleared on exit before a frame gap can be added
  (`hold/timer_metric.dart:23-33`, `:46-55`), so a nearly flat posture earns no time and shows
  "Thoát thế" every other frame.
  FIXED 2026-11-17: confirmed by test; the spine exit now uses the entry limit (> 175 instead of
  > 172), `sphinx_stretch.dart` `samplePose`. `Am_Exit_Spine_Angle` (172) now only bounds the
  start position's second branch.
- Any single frame past an exit threshold pauses the clock (1-frame exit debounce).
- The elbow, wrist, knee and ear used every frame are not confidence-checked (`:209-252`); a
  low-confidence ear feeds both neck checks.
  FIXED 2026-11-17: `samplePose` returns null (hold interrupted, as for a missing landmark) when
  any of the four is not `isLandmarkConfident`.
- The `ascending` state is never produced by `_legacyStateFor` (`:407-418`), so the "Tiếp tục gập
  tay" coaching branch (`elbow_angle_metric.dart:39-43`) is dead.
- `scaleFactor` is overwritten with the raw shoulder-hip distance every sampled frame (`:254`).
- Report: "Góc tay" = 100 - 20 x `straight_arm_seconds` (`sphinx_report_builder.dart:58-60`), so 5 s
  of any arm fault reads 0%. `active_hold_time` and `stability_score` describe only the last hold
  (`sphinx_stretch.dart:372-373`, `:390-391`).
- `_instructionSet`, `_shrugInstructionSet`, `_hyperInstructionSet` are written and never read.

**Cross-cutting checks.** Cannot fire / always perfect: the `hip_seconds` report line (certain);
`NeckShrug` (probable). Fault wipe: only the base pause/re-hold, which discards the partial hold
with its faults (`hold/rep_counted_hold_exercise.dart:157-167`). Single-frame: hold entry and exit
(1-frame debounces); faults are debounced 4 or 6. Left/right: no per-facing constants; the side is
chosen by likelihood and all angles are unsigned.

---

## Bow Pose

Source: `lib/exercise/bow_pose/` (7 files).

**Catalog.** `bow_pose` (definition `bow_`, "Bow Pose"): 1 set, 3 reps, seconds null,
`isFormChecked: true` (`assets/data/exercise_catalog.json:37`). Definition: `BowPose(maxRep: reps)`
through `_withReps` (`exercise_definition.dart:899-900`), target type reps. The definition text says
"10 lần giữ × 15 giây" / "10 × 15s" (`:882`, `:888`); the constructor default is
`BowPoseConfig.MAX_REP = 10` (`bow_pose.dart:15`, `:33`), which only applies to direct constructor
calls. With the catalog's 3, a set is 3 lifts.

**Archetype.** Rep-based with a timed hold inside each rep: one rep = one lift into the bow, a hold,
and a return to lying flat. Its own state machine (not `RepCountedHoldExercise`). Side view,
landscape only (`:26-30`). Voice: a dedicated `BowPoseVoiceCoach` (`:65`, not read).

**Side.** `getSideLandmark` returns the right-side landmark when `cameraFacing` is `right` and the
left-side one otherwise (`exercise_base.dart:817-826`), i.e. the camera side.

**Start position** (`:95-133`). Camera-side shoulder, hip, knee and ankle confident, and lying flat:
|shoulder Y - hip Y| <= 0.35 torso and |hip Y - knee Y| <= 0.35 torso (`:123-126`), knee angle
(hip-knee-ankle) >= 150 (`:128-130`, a literal, not `KNEE_SETUP_ANGLE`).

**Stop** (`:136`). `repCount >= maxRep`. No timeout.

**checkSafety** (`:160-166`). Not side view returns `turnSide`. Nothing else. In `checkingPose` the
frame is silently skipped (and the hold-seconds tick reset) when any of camera-side shoulder, hip,
knee, ankle, wrist is missing, when shoulder, hip, knee or ankle has `likelihood < 0.5`, or when the
wrist is not confident (`:191-206`). The 0.5 likelihood gate is not the shared confidence gate.

**Rep counting** (`:305-341`). Quantities (`:208-218`): torso = shoulder-hip distance (floored at
10 px); wrist-ankle = wrist-to-ankle distance / torso; chest lift = (hip Y - shoulder Y) / torso;
thigh lift = (hip Y - knee Y) / hip-knee distance; knee angle = hip-knee-ankle. One shared
`Debouncer(requiredFrames: 3)` (`:44`) counts consecutive frames on which the current state's
target differs from the current state.

| Transition | Condition | Debounce |
|---|---|---|
| prone to setup | knee angle < 150 (`:17`, `:310`); shoulder Y baseline refreshed every prone frame (`:309`) | 3 |
| setup to ascending | wrist-ankle < 0.35 (`metrics/connection_metric.dart:5`) and shoulder Y more than 0.02 torso above the prone baseline (`:314-316`) | 3 |
| ascending to hold | chest lift > 0.05 and thigh lift > 0.0 (`:18-19`, `:321-324`) | 3 |
| hold to descending | chest lift < 0.05 or wrist-ankle > 0.65 (`:20`, `:325-328`) | 3 |
| descending to prone, **rep counted** | knee angle > 150 (`:329-331`, `:238-240`) | 3 |

There is no abort path: `setup` and `ascending` can only move forward. Every completed cycle
counts, whatever the hold length.

**Anti-cheat.** The grab gate (wrist near the ankle) and a shoulder rise of 0.02 torso before
`ascending`; chest and thigh must rise before `hold`. A short hold is counted and only marked bad
form.

**Faults.** The metric context is built before the state machine (`:222-235`), so on a transition
frame the metrics see the pre-transition state; metrics run whenever the post-transition state is
not `prone` (`:278-280`). At rep completion `evaluateRep` runs, every record of the rep is
collected, `correctForm` is false if any has `affectsForm: true` (`:242-249`), and the metrics reset
(`:271`). Faulting frames in `hold` add to `connection_seconds` and `lift_form_seconds`
(`:281-288`). None rejects the rep.

| Type | Vietnamese message / voice (live text) | Metric and threshold | Debounce | affectsForm |
|---|---|---|---|---|
| `Connection` | "Mất kết nối tay - chân" / "Nắm chắc cổ chân" ("Tuột tay rồi!") | wrist-ankle > 0.60 in `ascending` or `hold` (`metrics/connection_metric.dart:6`, `:33-37`) | 5 (`:15`) | true |
| `LiftForm` (thigh) | "Đùi chạm sàn" / "Nâng cao đùi" ("Kéo đùi lên cao!") | thigh lift < 0.012 in `hold` (`metrics/lift_form_metric.dart:6`, `:45-50`) | 6 (`:16`) | true |
| `LiftForm` (chest) | "Ngực chưa mở" / "Ưỡn ngực lên" ("Mở căng lồng ngực!") | chest lift < 0.04 in `hold` (`:5`, `:44`, `:55-58`) | 6 (`:17`) | true |
| `HoldDuration` | "Giữ quá ngắn (Xs < 15s)" / no voice | longest hold of the rep < 15 s, wall clock from `hold` entry (`metrics/hold_duration_metric.dart:23-41`, `:46-52`) | none (once per rep) | true |
| `Stability` | "Tư thế bị rung lắc nhiều (Score: X%)" / no voice | score = 100 x (1 - std dev of shoulder Y / torso over hold frames / 0.05) < 50, with at least 10 hold frames (`metrics/stability_metric.dart:28-57`) | none (once per rep) | false |

The spoken post-rep line is chosen by keyword in `_topVoiceMessage` (`:357-379`): "Nắm chân chắc
hơn", "Giữ lâu hơn một chút", "Mở ngực thêm một chút", "Nâng đùi cao hơn nếu lưng vẫn thoải mái",
"Giữ người yên hơn".

**Tests.** No dedicated file in `test/exercise/`. `exercise_logging_alignment_test.dart`:
`BowPose(maxRep: 2)` publishes squat-style score keys. Report builder key contract and registry
tests. Outside `test/exercise/`: `test/services/bow_pose_voice_assets_test.dart` and
`test/services/bow_pose_voice_coach_test.dart` (not opened). Nothing tests the state machine or any
threshold.

**Unverified, stale, or suspicious.**
- **The chest `LiftForm` fault cannot fire, by reading.** Chest lift < 0.04 also satisfies the hold
  exit (< 0.05). Every frame that advances the 6-frame chest debouncer also advances the 3-frame
  state debouncer, so the state leaves `hold` on the third such frame and the metric (which only
  checks in `hold`) never reaches six. "Ngực chưa mở" and the "Mở ngực thêm một chút" voice line are
  unreachable.
- **`Connection` only catches a narrow band during the hold, by reading.** The hold exits at
  wrist-ankle > 0.65 after 3 frames and the fault needs > 0.60 for 5 frames, so a clean release ends
  the rep without a fault; during the hold the fault needs the hand to hover in 0.60-0.65 first. In
  `ascending`, which has no exit, it can fire freely.
- **A hold of any length counts.** A 1 s bow is a rep with a `HoldDuration` fault; the 15 s is a
  literal (`metrics/hold_duration_metric.dart:46`), not `HOLD_TARGET_SECONDS`.
- No abort from `setup` or `ascending`. By reading, a `Connection` fault raised in an abandoned
  `ascending` stays in the metric and attaches to the next completed rep.
- Hold entry needs only thigh lift > 0.0, i.e. the knee anywhere above the hip line; camera height
  alone can satisfy it. Chest lift 0.05 torso is small. Not measured.
- Chest lift and thigh lift are raw image-Y differences, so phone roll changes them directly.
- `checkSafety` never returns `bodyInFrame` or `lighting`; lost landmarks silently freeze the state
  machine with no prompt.
- `total_seconds` = `maxRep x 15` regardless of time held (`:146`); the "Giữ sạch" card divides by
  it (`bow_pose_report_builder.dart:53-56`). Hold seconds only accrue in `hold`.
- `scaleFactor` is not used; the torso length is local and floored at 10 px (`:208-209`).

**Cross-cutting checks.** Cannot fire: the chest `LiftForm` fault (by reading). Fault wipe: none;
metrics reset only after the rep log is written (`:262-271`). Single-frame: no state transition is
single-frame (shared 3-frame debounce); `HoldDuration` and `Stability` are evaluated once at rep
end. Left/right: camera side via `getSideLandmark`; no head-direction constant, all measures are
image-Y differences or unsigned angles.

---

## Butterfly Stretch

Source: `lib/exercise/butterfly_stretch/` (7 files) on top of `lib/exercise/hold/`.

**Catalog.** `butterfly` (definition `butterfly__stretch`, "Butterfly"): 1 set, 1 rep, 30 s,
**`isFormChecked: false`** (`assets/data/exercise_catalog.json:48`, `:50`). Definition:
`ButterflyStretch(maxHolds: reps ?? 1, holdSeconds: seconds ?? 30)`
(`exercise_definition.dart:925-928`), target type seconds; camera hint "Đặt camera chính diện"
(`:917`). The description promises tracking of "độ mở của hai gối, lưng thẳng và vị trí bàn chân"
(`:910`).

**Flag versus code.** Despite `isFormChecked: false`, the class runs three form metrics whose
records all have `affectsForm: true`, and any one of them marks the hold bad form
(`hold/rep_counted_hold_exercise.dart:336-337`). By grep, the flag is read only by the
recommendation and launch services (`lib/services/workout_launch_service.dart:250`,
`recommendation/recommendation_engine.dart:346`, `recommendation/program_plan_mapper.dart:155`,
`:229`), never by an exercise class, so it does not switch form checking off.

**Archetype.** Hold-based via `RepCountedHoldExercise`. **Front view.** Portrait and both
landscapes (`butterfly_stretch.dart:59-64`). Entry debounce 10 frames, exit 5 (`:85-89`).

**Landmarks** (`:416-424`, `:439-515`). Both knees, ankles, shoulders, hips and heels (10) must be
present and confident on every frame used.

**Start position** (`:132-165`). `cameraFacing == front`, the 10 landmarks confident, and:
- shoulder width (X) >= 10 px (`:140`)
- ankle X gap <= 0.6 shoulder width (`:142-143`)
- knee X gap >= 0.8 shoulder width (`:145-146`)
- heel midpoint to hip midpoint <= 0.95 x max(torso height, shoulder width)
  (`metrics/foot_placement_metric.dart:5`, `:152-163`)
- torso height (shoulder-to-hip Y) / shoulder width >= 0.48 (`metrics/posture_metric.dart:7`, `:164`)

**Stop.** `repCount >= maxHolds`. No timeout.

**checkSafety** (`:167-179`). Not front returns `faceCamera` and cancels re-arm. Any of the 10
landmarks missing or unconfident returns `bodyInFrame`, drops an active hold (`wall_guard`) and
cancels re-arm.

**Hold counting** (`:219-258`). The gate is **knee stillness only**: yChange = average knee Y now
minus average knee Y up to 10 frames ago, over torso height.
- entry: |yChange| < 0.04 (`:17`, `:255-256`) for 10 frames
- exit to `dropping`: yChange < -0.04, i.e. knees rose more than 0.04 torso within 10 frames
  (`:19`, `:257`) for 5 frames

Rest 5 s, re-arm 3 s, hold length `holdSeconds` (30 s). The live text "x.xs / 30s" uses
`holdSeconds` (`:290-291`).

**Anti-cheat.** Only at activation (the start-position shape). After that, by reading, any still
front-facing pose with the 10 landmarks visible earns hold time: knee opening, foot position and
posture are not part of the gate. `MIN_KNEE_SEPARATION_NORM = 0.70`, `MAX_ANKLE_SEPARATION_NORM`
and `STRETCH_THRESHOLD` are unreferenced (`:16`, `:18`, `:20`).

**Faults.** Metrics run in `holding` and `dropping` (`:280-288`) and none of them checks the state,
so faults raised while dropping are also attached to the hold. Records are kept once per phase and
type and have no voice message (the local `FaultRecord` has no voice field,
`metrics/butterfly_metric_base.dart:44-54`). Faulting frames in `holding` add to `knee_seconds`,
`posture_seconds`, `foot_placement_seconds` (`:295-299`). None stops the clock.

| Type (log type, seconds key) | Logged message (live text) | Metric and threshold | Debounce | Counts the hold? |
|---|---|---|---|---|
| `Knee` (`knee`, `knee_seconds`) | "Hai gối không đều (Asymmetry)" ("Lệch gối!") | \|left knee Y - right knee Y\| / torso height > 0.25 (`metrics/knee_separation_metric.dart:7`, `:42-53`) | 7 (`:18`) | yes |
| `PostureCollapse` (`posture`, `posture_seconds`) | "Gập người/gù lưng khi giữ tư thế" ("Giữ lưng thẳng, không gập người xuống!") | torso height / shoulder width < 0.48 (`metrics/posture_metric.dart:7`, `:45-47`) | 7 (`:17`) | yes |
| `Posture` (`shoulder`, `posture_seconds`) | "Nghiêng/Lệch vai" ("Lệch vai!") | \|left shoulder Y - right shoulder Y\| / torso height > 0.18, only when not collapsed (`:6`, `:38-49`, `:62`) | 7 (`:16`) | yes |
| `FootPlacement` (`foot`, `foot_placement_seconds`) | "Gót chân đặt quá xa hông" ("Kéo gót chân lại gần hông!") | heel midpoint to hip midpoint / max(torso height, shoulder width) > 0.95 (`metrics/foot_placement_metric.dart:5`, `:47-50`) | 5 (`:14`) | yes |
| `wall_guard` (break id) | none | knees rising, or landmarks lost | 5 | clock paused |

**Tests.** `butterfly_stretch_test.dart` (6 tests): a full hold logs one rep and preserves every
report key; the foot metric emits a snake_case live fault without freezing hold time; measured
shoulder tilt routes the shoulder audio identity; start position rejects far feet and a collapsed
posture; upright and landscape orientations are supported; safety rejects a missing or
low-confidence hip or heel. Report builder key contract and registry tests. Nothing tests the
stillness gate or the knee-asymmetry and collapse thresholds.

**Unverified, stale, or suspicious.**
- **The hold gate measures stillness, not the pose.** See Anti-cheat. Sitting still with legs
  straight or crossed earns the full hold after a correct start; only `FootPlacement` (heels far
  from the hips) would mark it.
  CONFIRMED 2026-11-17 by reading, not changed (report only). `isFormChecked` is still false in
  `assets/data/exercise_catalog.json` and `supabase/seed.sql` (pinned by `butterfly_report_test.dart`).
- **Knee opening is never measured during the hold.** `knee` is a left/right height asymmetry, yet
  the report tip says "hai gối chưa mở đều hoặc còn cao" and the praise "Hai gối mở đều xuống sàn"
  (`butterfly_stretch_report_builder.dart:27`, `:42-43`). A user whose knees stay high but level is
  praised for open knees.
  FIXED 2026-11-17: the knee label, tip and praise now describe one knee higher than the other.
- `max_knee_separation` is pushed in raw pixels (`:349`, `metrics/knee_separation_metric.dart:36-38`),
  and the "Độ mở gối tối đa" card shows that pixel value against `miniBarMax: 200`
  (`butterfly_stretch_report_builder.dart:58-65`), so it depends on camera distance and resolution.
  FIXED 2026-11-17: the "Độ mở gối tối đa" card is removed (no camera-independent scale to show
  it against); the key is still pushed in pixels.
- The "Thời gian Hold" card divides by `ButterflyConfig.TARGET_HOLD_SECONDS = 20`
  (`butterfly_stretch.dart:15`, report `:73`) while the catalog hold is 30 s.
  FIXED 2026-11-17: the card divides by the set's `total_seconds` (maxHolds x holdSeconds); the
  constant is removed.
- `PostureCollapse` needs the visible torso height to fall below about half the shoulder width,
  which by reading is a deep fold; a rounded back with an upright trunk does not change it.
- Comments disagree with code: asymmetry "> 15px per 100px" vs 0.25
  (`metrics/knee_separation_metric.dart:5-7`), "debouncer 5 frames" vs 7 (`:17-18`), tilt "> 10%" vs
  0.18 (`metrics/posture_metric.dart:5-6`).
  FIXED 2026-11-17: the three comments now state 0.25, 7 frames and 0.18.
- `metrics/hold_duration_metric.dart` is not instantiated anywhere (dead file);
  `ButterflyState.stretching` is never used.
- The stillness lookback is 10 frames, so the gate's time window depends on frame rate.
- `scaleFactor` is overwritten every sampled frame with max(torso height, shoulder width) (`:206`).

**Cross-cutting checks.** Cannot fire / always perfect: none found by reading; the `knee` praise
is mislabelled rather than structurally perfect. Fault wipe: only the base pause/re-hold. 
Single-frame: none (entry 10, exit 5, faults 5-7 frames). Left/right: front view; every measure is
an absolute left-right difference, so mirroring does not matter and there is no facing constant.

---

## Seated Forward Fold

Source: `lib/exercise/seated_forward_fold/` (7 files) on top of `lib/exercise/hold/`.

**Catalog.** `seated_forward_fold` (definition `seated__forward__fold`): 1 set, 1 rep, 30 s,
`isFormChecked: true` (`assets/data/exercise_catalog.json:290`). Definition:
`SeatedForwardFold(maxHolds: reps ?? 1, holdSeconds: seconds ?? 30)`
(`exercise_definition.dart:1062-1065`), target type seconds. The description says "3 lần giữ × 15
giây" / "3 × 15s" (`:1044`, `:1050`). The onboarding assessment definition
`seated_forward_fold_assessment` builds the same class (`:241-266`).

**Archetype.** Hold-based via `RepCountedHoldExercise`. Side view, landscape only
(`seated_forward_fold.dart:36-41`). Entry and exit debounce both **1 frame** (`:69-73`), but entry
is itself gated on 1 s of stability (below).

**Side** (`:407-417`). Facing `left` tracks the left side, `right` the right side (camera side);
any other facing returns `turnSide`.

**Landmarks** (`:419-430`). Tracked-side ear, shoulder, hip, knee, heel, foot index.

**Start position** (`:132-162`). The six landmarks confident, knee angle (hip-knee-heel) >= 115
(`metrics/seated_forward_metric_base.dart:11`) and hip angle (shoulder-hip-knee) 60 to 170
(`base:10`). The hip angle of the last passing frame is kept as the setup angle (`:160`).

**Stop.** `repCount >= maxHolds`. No timeout.

**checkSafety** (`:113-129`). Facing not left/right returns `turnSide` and cancels re-arm. Any of
the six landmarks missing or unconfident returns `bodyInFrame`, drops an active hold (`wall_guard`)
and cancels re-arm.

**Hold counting** (`:171-241`, `:358-364`). Target depth = max(setup hip angle - 6, 95)
(`base:24-25`). Hip velocity = frame-to-frame change of the hip angle in deg/s (`:185-192`).
- entry: hip angle < target depth and |velocity| < 18 deg/s (`base:15`) continuously for >= 1000 ms
  (`:203-212`)
- exit to `dropping`: hip angle > the smallest hip angle of this attempt + 12 (`base:21`,
  `:213-215`); the minimum is only cleared on `setup` and `reArming` (`:316-320`, `:350-356`)

A hold completes at `holdSeconds` (30 s). Rest 5 s, re-arm 3 s. Deepest hip angle is logged per
hold as `max_depth_angle` (`:313-315`, `:324-326`).

**Anti-cheat.** The fold must reach the target depth and be still for 1 s. Bent knees are not part
of the gate; they are faulted.

**Faults.** Metrics run in `holding` and `dropping` (`:258-263`; mapped to `isometricHold` and
`ascending`). Records are kept once per phase and type; a record with `affectsForm: true` marks the
hold bad form. Faulting frames in `holding` add to `knee_bent_seconds` and `spine_round_seconds`
(`:275-278`). None stops the clock.

| Type (log type, seconds key) | Vietnamese message / voice (live text) | Metric and threshold | Debounce | affectsForm |
|---|---|---|---|---|
| `KneeBent` (`knee`, `knee_bent_seconds`) | "Lỗi co gối" / "Ép thẳng đầu gối xuống" ("Thẳng gối ra!") | knee angle (hip-knee-heel) < 125, `holding` only (`metrics/knee_extension_metric.dart:25-34`, base `:12`) | 5 (`:10`) | true |
| `SpineRound` (`spine`, `spine_round_seconds`) | "Lỗi gù lưng" / "Ưỡn ngực, vươn dài lưng ra" ("Thẳng lưng lên!") | ear-shoulder-hip angle < 95, `holding` or `dropping` (`metrics/spinal_alignment_metric.dart:25-31`, base `:13`) | 6 (`:10`) | true |
| `AnklePlantar` (`ankle`, none) | "Lỗi duỗi mũi chân" / "Bẻ gập mũi chân hướng lên trần" ("Bẻ gập mũi chân!") | knee-heel-toe angle > 145, `holding` or `dropping` (`metrics/ankle_dorsiflexion_metric.dart:25-32`, base `:20`) | 6 (`:10`) | false |
| `TempoShort` (`tempo`, none) | "Chưa đủ thời gian kéo giãn" / "Cố gắng giữ lâu hơn để cơ kịp giãn ra" | on leaving `holding`, wall-clock time held so far < `holdSeconds` (`metrics/hold_tempo_metric.dart:26-34`, `:60-72`; `seated_forward_fold.dart:32`) | none | false |
| `wall_guard` (break id) | none | release by 12 deg, or landmarks lost | 1 | clock paused |

**Tests.** `seated_forward_fold_logging_regression_test.dart` (1 test): a full engine hold logs a
snake-case fault and preserves report keys. `seated_forward_report_builder_test.dart` (4 tests):
score from `good_seconds` / `total_seconds`; coach tip from the highest fault key; pain-linked fault
candidates; registry resolution. `hold_time_logging_oracle_test.dart`: `good_seconds` excludes
active form-fault frames. Nothing tests the depth gate, the release rule or the spine threshold.

**Unverified, stale, or suspicious.**
- **After easing back 12 deg from the deepest point, the clock cannot restart, by reading.** The
  release reference is the minimum hip angle of the whole attempt, not of the current segment. In
  `dropping`, a still fold below the target depth re-enters `holding` after 1 s; on the next frame
  the hip is still more than 12 deg above that minimum, so it drops again before the timer can add
  a frame gap (`hold/timer_metric.dart:23-33`, `:46-55`). The user sees "Nhả cơ" flicker roughly
  once a second and earns no time until they fold within 12 deg of their deepest angle or the set
  re-arms. Not tested.
  FIXED 2026-11-17: confirmed by test; the release reference is the deepest hip angle of the
  current holding segment, reset on entering `holding` (`_minHipAngleThisSegment`).
  `max_depth_angle` still uses the whole attempt.
- **`SpineRound` measures the head, not the back.** Ear-shoulder-hip is the neck angle relative to
  the trunk; the code comment cites a reference capture of 151 deg (`base:8-9`). Dropping the head
  toward the knees, which is common in this stretch, lowers it; a rounded lumbar spine with the head
  in line does not. The report text talks about "lưng dưới bo tròn" and maps it to lower-back pain
  (`seated_forward_report_builder.dart:11-12`, `:24-29`).
  FIXED 2026-11-17: logged message, live text, voice text, report tip, praise and card now speak
  of the head dropping; the `lower_back` and `back` pain mappings are removed. The bundled
  `assets/audio/seated_forward_fold/spine.mp3` was not changed.
- The start position accepts knees down to 115 deg, but the hold faults below 125 deg, so a user
  who starts with knees bent 115-125 deg is faulted on every hold.
  FIXED 2026-11-17: the start gate uses `Ak_Fault_Knee_Angle` (125); `Ak_Start_Knee_Angle` removed.
- `TempoShort` is logged on every early release (once per hold) and shown live while dropping;
  `affectsForm: false`.
- Velocity is a frame-to-frame difference in deg/s with no smoothing beyond the pose smoother;
  landmark jitter of about 0.6 deg per frame at 30 fps exceeds 18 deg/s and restarts the 1 s
  stability timer. Not measured.
- `onSetComplete` pushes only `total_seconds`, `good_seconds`, `knee_bent_seconds`,
  `spine_round_seconds` (`:336-348`): no `max_rep`, no `good_rep_count`, unlike the other hold
  exercises in this batch.
  FIXED 2026-11-17: `max_rep` and `good_rep_count` are pushed.
- `At_Num_Holds` is unreferenced; `At_Min_Hold_Time = 15` is only the metric's default and the
  exercise always passes `holdSeconds` (`base:16-18`, `:32`).
- `scaleFactor` is overwritten with the raw shoulder-hip distance every sampled frame (`:196`).

**Cross-cutting checks.** Cannot fire / always perfect: none found. Fault wipe: only the base
pause/re-hold. Single-frame: the exit (`releasedEarly`) is a single frame; entry needs 1 s of
stability. Left/right: camera side chosen from `cameraFacing`; angles are unsigned, no
head-direction constant.

---

## Downward Dog

Source: `lib/exercise/downward_dog/` (6 files).

**Catalog.** `downward_dog`: 1 set, 1 rep, seconds null, **`isFormChecked: false`**
(`assets/data/exercise_catalog.json:92`, `:94`). Definition (id `downward_dog`, name "Chó Cúi Mặt"):
`DownwardDog(maxHolds: reps)` through `_withReps` (`exercise_definition.dart:1307-1308`), target
type reps (default); description "Bản xem trước của bài tập Downward Dog." (`:1294`). The hold length
is the constant `HOLD_DURATION_SEC = 20.0` (`downward_dog.dart:62`); the file header says 30 s
(`:9`).

**Flag versus code.** `SpineRound` records have `affectsForm: true` and mark the hold bad form
(`metrics/spine_round_metric.dart:126-134`, `downward_dog.dart:493-494`), although the catalog says
not form-checked. The other two metrics are coaching only.

**Archetype.** Hold-based, its own `entry -> hold -> exit` machine (not `RepCountedHoldExercise`).
Side view. No `supportedOrientations` override, so **portrait only** (base default). Camera side via
`getSideLandmark` (`:554-605`).

**Start position** (`:267-342`), camera-side shoulder, hip, knee, ankle, wrist, ear present (no
confidence check here):
- hip Y above shoulder Y and knee Y (hips highest) (`:292`)
- wrist and ankle below the hip (`:295`)
- wrist-shoulder-hip angle >= 100 (`:89`, `:298-299`); the comments say "> 150°" (`:265`, `:297`)
- hip Y moved < 6 px since the previous frame (`:65`, `:304-311`)
- 5 consecutive such frames (`:71`, `:313-323`), on top of the base 3 s hold-still

On success it stores shoulder-hip distance, spine, apex and ear-shoulder baselines (`:324-332`).

**Stop** (`:132`). `repCount >= maxHolds`. No timeout.

**checkSafety** (`:135-164`). Not side view returns `turnSide`. Any of 12 landmarks (both
shoulders, hips, knees, ankles, wrists and ears) missing or unconfident returns `bodyInFrame`.

**Hold counting** (`:182-187`, `:348-432`). Activation calls `activateHold`, which enters `hold`
and starts a wall-clock timer. The hold completes when 20 s of wall clock have passed (`:197-198`,
`:647-650`); `repCount` increments and the state goes to `exit` (`:489-491`). While holding, the
shape is "wrist-shoulder-hip >= 100 and shoulder-hip-ankle <= 145" (`:379-381`); 6 consecutive
frames outside it (`:92`) abort the hold, and so does a single no-pose frame (`:640-645`). An abort
returns to `entry`, clears the start confirmation, and resets every metric without counting
(`:652-669`).

**Anti-cheat.** The inverted-V start check and the 6-frame shape check.

**Faults.** Metrics run only in `hold` (`:360-363`). Faulting frames add to three seconds keys, and
for the first time in this file a caller passes `goodBlockingKeys`: only `spine_round_seconds`
removes time from `good_seconds` (`:404-412`).

| Type (seconds key) | Logged message / voice (live text) | Metric and threshold | Debounce | affectsForm |
|---|---|---|---|---|
| `SpineRound` (`spine_round_seconds`) | "Spine rounding — lumbar flexion detected" (English) / "Gập gối để giữ lưng thẳng" ("Cong gối nhiều hơn nhé! Giữ lưng dài, đừng gù lưng. ...") | wrist-shoulder-hip angle < 132 (`metrics/spine_round_metric.dart:35`, `:98`) | 10 (`:39`) | true |
| (warning, no record) | live "Gập gối một chút để kéo dài lưng nhé!" | wrist-shoulder-hip < 148 (`:32`, `:99`) | 20 (`:42`) | n/a |
| `ShoulderShrug` (`shoulder_shrug_seconds`) | "Shoulders shrugging toward ears" (English) / "Thả vai ra xa tai" ("Đẩy vai ra xa tai nhé, thả lỏng cổ.") | 7-frame median ear-shoulder distance / start torso, divided by its start baseline, < 0.48 (`metrics/shoulder_shrug_metric.dart:35`, `:103-126`) | 10 (`:44`) | false |
| `LegStraightness` (`leg_straightness_seconds`) | "Legs bent — spine long (acceptable, coaching only)" (English) / none ("Gập gối là được — giữ lưng thẳng!") | live: knee angle < 135 while the spine has stayed >= 148 all hold; record: at hold end, minimum knee < 135 and spine never < 148 (`metrics/leg_straightness_metric.dart:32`, `:84-99`, `:104-118`) | none | false |

Hip height (shoulder-hip-ankle) and the arm-torso line only write live text ("Đẩy hông lên cao và
ra sau hơn nhé!", "Hông cao, tuyệt!", "Vươn ngực về phía đùi, kéo dài tay."; `:438-468`); they
never log a fault. `DownwardDogFaultVoicePriority.hipHeight` is unused.

**Tests.** `new_exercise_hold_contract_test.dart` (1 Downward Dog test): counts only after a full
valid hold and writes logs. Report builder key contract and registry tests. Nothing tests the
abort path or any metric.

**Unverified, stale, or suspicious.**
- **An aborted hold can never restart, by reading.** `hold` is only entered from `activateHold`,
  which only `onExerciseActivated` calls (`:186`, `:548-552`). After an abort the state is `entry`
  and `processFrame` returns early (`:360-363`). A pause/resume re-hold calls
  `onExerciseReactivatedAfterPause` instead (`exercise_base.dart:864-866`), which no exercise
  overrides, and `resetHold()` has no caller. So one frame without a skeleton, or six frames out of
  shape, leaves the set unable to count for the rest of the session while the screen shows "Vào lại
  hình chữ V rồi giữ tiếp nhé." For the same reason a second hold (`maxHolds > 1`) never starts. The
  catalog's 1 rep hides the second problem, not the first.
- **The aborted hold's faults are discarded** (`metric.reset()`, `:664-666`).
- **`SpineRound` measures the arm-to-trunk angle at the shoulder** (wrist-shoulder-hip), not lumbar
  flexion; the English message and the report ("lưng có xu hướng bo tròn", mapped to back and lower
  back pain, `downward_dog_report_builder.dart:10-12`, `:19-21`) describe the lumbar spine. Shoulders
  that do not open fully read as a rounded back.
- Comments disagree with code: spine table good >= 160, error < 145 (`metrics/spine_round_metric.dart:17-24`)
  vs 148 / 132, and the constant named `WARNING_ANGLE` is the error threshold; shrug 0.6 / 0.8
  (`metrics/shoulder_shrug_metric.dart:11-12`, `:22-27`) vs 0.48 / 0.68, with "One Euro Filter on the
  ear Y" (`:14-16`) not done in the metric; leg >= 150 (`metrics/leg_straightness_metric.dart:17-23`)
  vs 135; `HoldContext.earShoulderDist` is documented as a normalised vertical distance
  (`metrics/downward_dog_metric_base.dart:49-51`) but is the raw Euclidean distance
  (`downward_dog.dart:246`). All three metric headers say "ESTIMATE — pending PT review".
- `leg_straightness_seconds` counts bent-knee time that the metric's own header calls acceptable;
  the report still praises "Chân vươn tốt" from it and maps knee pain to it
  (`downward_dog_report_builder.dart:14`, `:44`).
- Portrait only, yet the pose is a wide inverted V seen from the side; and `checkSafety` requires the
  far-side wrist, ear, knee and ankle to be confident. By reading, `bodyInFrame` will be frequent.
  Not measured.
- The rep log's `hold_time` is the constant 20 (`:510`), and `total_seconds` = `maxHolds x 20`
  (`:169`).
- `scaleFactor` (base) is not written; the start-position shoulder-hip distance is used instead.

**Cross-cutting checks.** Cannot fire / always perfect: none of the three metrics is structurally
dead, but the whole exercise stops counting after any abort (above). Fault wipe: `_abortHold`
resets every metric without counting (`:664-666`). Single-frame: one no-pose frame aborts the hold
(`:640-645`). Left/right: camera side via `getSideLandmark`; no head-direction constant; "hips
highest" relies on image Y being vertical (portrait).

---

## Low Lunge

Source: `lib/exercise/low_lunge/` (5 files).

**Catalog.** `low_lunge`: 3 sets, 2 reps, seconds null, **`isFormChecked: false`**
(`assets/data/exercise_catalog.json:158`, `:160`). Definition (id `low_lunge`, name "Kỵ Sĩ"):
`LowLunge(maxRep: reps)` through `_withReps` (`exercise_definition.dart:1353-1354`), target type
reps; description "Bản xem trước của bài tập Low Lunge." (`:1340`). `LowLungeConfig.MAX_REP = 2` is
unreferenced (`low_lunge.dart:14`). Hold length is the constant `HOLD_DURATION = 20.0` (`:15`).

**Flag versus code.** `KneeTravel` records have `affectsForm: true` and mark the rep bad form
(`metrics/knee_travel_metric.dart:69-77`, `low_lunge.dart:438`), although the catalog says not
form-checked.

**Archetype.** Hold-based, one rep = one 20 s hold; its own `entry -> holding -> exit` machine.
Side view. No `supportedOrientations` override, so **portrait only**. The exit phase is labelled
"Đổi bên" but nothing checks that the user changed sides.

**Front and back legs** (`:527-565`). With facing `right`, the left leg is front when the left
ankle has the smaller X; with any other facing, when it has the larger X. So facing `left` puts the
front toward **larger X**, the same as Push-Up and the opposite of Lunge and Walking Lunge (finding
6). Lunge direction = sign of front ankle X minus back ankle X.

**Start position** (`:90-118`). All eight hips, knees, ankles, shoulders present (no confidence
check), and: ankle X gap > 0.42 torso (`:21`), back knee "grounded" = |back knee Y - back ankle Y|
<= 0.95 torso (`:22`, `:98-100`), front knee angle < 175 (`:23`). Passing frames collect 20 frames
of calibration (torso length, ear-shoulder-hip angle, front ankle X; `:120-153`).

**Stop** (`:161`). `repCount >= maxRep`. No timeout.

**checkSafety** (`:185-211`). Not side view returns `turnSide`. Any of the eight landmarks missing
returns `bodyInFrame`; front shoulder, hip, knee, ankle or back knee, ankle unconfident returns
`lighting`.

**Hold counting** (`:346-413`). Shape = front knee < 175 and back knee grounded (`:352-353`); hip
velocity = frame-to-frame front-hip Y change in torso lengths per second (`:479-490`).
- activation enters `holding` at once (`:179-183`)
- `entry` to `holding`: shape and |hip velocity| <= 0.06 for 4 frames (`:18`, `:25`, `:354-363`)
- `holding` to `exit`, **rep counted**: 20 s of wall clock since `holding` began (`:366-369`)
- `holding` to `exit`, **not counted**: shape lost or |hip velocity| >= 0.18 for 8 frames (`:26`,
  `:53`, `:357-359`, `:370-375`); shows "Lần này chưa tính nhé" and the reason "Rời tư thế quá sớm -
  giữ Low Lunge đủ thời gian trước khi đổi bên."
- `exit` to `entry`: after 4 s (`:16`, `:377-384`)
- a no-pose frame in `holding` returns to `entry` and resets the metrics (`:501-515`)

**Anti-cheat.** The shape gate and the hip-stillness break. By reading, the shape gate is loose:
any bend under 175 deg passes, and a 0.95 torso knee-to-ankle height admits a lifted back knee whose
shin is short in the image. The test below covers one lifted-knee case.

**Faults.** Metrics run only in `holding` (`:270-279`). The local `FaultRecord` has no voice field
(`metrics/low_lunge_metric_base.dart:52-64`). Records are kept once per type. Set-log keys
`knee_travel_fails_count` and `cervical_fails_count` = counted holds with that fault (`:164-169`).

| Type (count key) | Logged message (live text) | Metric and threshold | Debounce | affectsForm |
|---|---|---|---|---|
| `KneeTravel` (`knee_travel_fails_count`) | "Front knee travelled too far past ankle" (English) ("⚠️ Cẩn thận đầu gối!"; warning "Lùi hông ra sau để gối không vượt mũi chân") | (front knee X - front ankle X) x direction / torso > 1.05; warning > 0.7; knee and ankle likelihood >= 0.45 (`metrics/knee_travel_metric.dart:12-15`, `:36-61`) | `StickyDebouncer` 20 (record), 8 (live) (`:20-23`) | true |
| `CervicalDanger` (`cervical_fails_count`) | "Neck cranked back" (English) ("Nhìn về trước thôi nhé") | ear-shoulder-hip angle < 125, ear likelihood >= 0.5 (`metrics/cervical_safety_metric.dart:13-15`, `:36-48`) | `StickyDebouncer` 8, starts false (`:20-21`) | false |

Live-only text (`low_lunge.dart:297-321`): "Hạ gối sau xuống sàn nhé" (back knee not grounded),
"Hạ hông thấp hơn nếu thoải mái" (front knee > 145), "Độ sâu tốt ✓" (70-135), "Nâng nhẹ ngực lên"
(chest-lift score < 25).

**Tests.** `new_exercise_hold_contract_test.dart` (2 Low Lunge tests): start rejects a lifted back
knee; no count when the hold breaks before the target duration. Report builder key contract and
registry tests. Nothing tests either metric.

**Unverified, stale, or suspicious.**
- **`KneeTravel` fires on the first frame of the first hold of every set, by reading.**
  `StickyDebouncer` starts in `currentState = true` unless told otherwise
  (`lib/utils/debouncer.dart:43`) and returns its current state until `requiredFrames` contrary
  frames arrive (`:45-58`). The three knee debouncers use that default
  (`metrics/knee_travel_metric.dart:20-23`), so `_stickyErrorDebouncer.update(false)` returns true
  for the first 20 holding frames and the fault is logged at once (`:56-58`); the `return` also hides
  the warning text. `reset()` only zeroes the frame counter, not the state (`debouncer.dart:61-63`),
  so after 20 clean frames the state stays false for the rest of the instance. Result: the first
  counted hold of each set is always bad form with `KneeTravel`, and `knee_travel_fails_count` is
  never below 1 for a set with a counted hold. Not tested.
- **A real `KneeTravel` probably cannot fire, by reading.** The knee's horizontal lead over the ankle
  cannot exceed the shin length, which for an adult is shorter than the shoulder-hip distance, so
  1.05 torso is out of reach (0.7 for the live warning is reachable only with a steeply angled shin).
  Not measured.
- **The chest-lift live cue is wrong for one facing, by reading.** `calculateVerticalAngle` returns 0
  for "straight up" in any facing (`pose_math_helpers.dart:244-265`), but the target is 0 for facing
  right and 180 otherwise (`low_lunge.dart:521-525`). Facing left, an upright trunk scores 0 and
  "Nâng nhẹ ngực lên" shows throughout. Live text only; no record.
- `CervicalDanger` uses an unsigned angle, so a head dropped forward also reads below 125 and is
  logged as "Neck cranked back".
- Calibration (`_baselineCervicalAngle`, `_frontAnkleBaselineX`) is passed to the metrics and never
  read; it is collected only during the base activation, then cleared on the first return to `entry`
  (`:404-407`, `:458-472`) and never refilled.
- Holds after the first need only 4 still frames, not the base 3 s hold-still.
- A rejected hold resets its metrics without counting (`:431-433`), and there is no set-log key for
  rejected holds.
- `onExerciseActivated` does not call `super.onExerciseActivated()` (`:179-183`), as V-Up and Wall
  Push-Up.
- The rep log's `hold_time` is the constant 20 (`:448`).
- `scaleFactor` (base) is not written; torso length is the local front shoulder-hip distance.

**Cross-cutting checks.** Cannot fire / always perfect: real `KneeTravel` detection (probable);
conversely `KneeTravel` always fires on each set's first hold. Fault wipe: an early exit and a
no-pose frame both reset metrics without counting (`:431-433`, `:508-510`). Single-frame: a
no-pose frame ends the hold (`:503-513`); `KneeTravel` is logged from the first holding frame.
Left/right: front leg from ankle X and `cameraFacing`, with Push-Up's convention (facing left =
front toward larger X); chest-lift target 0/180 per facing.

---

## Raised Arms

Source: `lib/exercise/raised_arms/` (6 files).

**Catalog.** `raised_arms`: 1 set, 1 rep, seconds null, **`isFormChecked: false`**
(`assets/data/exercise_catalog.json:257`, `:259`). Definition (id `raised_arms`, name "Vươn Tay"):
`RaisedArms(maxRep: reps)` through `_withReps` (`exercise_definition.dart:1399-1400`), target type
reps; description "Bản xem trước của bài tập Raised Arms." (`:1386`). `RaisedArmsConfig.MAX_REP = 1`
is unreferenced (`raised_arms.dart:15`). Hold length is the constant `HOLD_DURATION = 12.0` (`:16`).

**Flag versus code.** One metric (`LumbarOverextension`) is declared `affectsForm: true`
(`metrics/lumbar_backbend_metric.dart:64-71`), although by reading it cannot be logged (below). An
excessive backbend does reject the hold through the state machine.

**Archetype.** Hold-based, one rep = one 12 s hold; the same `entry -> holding -> exit` skeleton as
Low Lunge. Side view; camera side via `getSideLandmark` (`:511-549`). No `supportedOrientations`
override, so portrait only.

**Start position** (`:88-109`). Camera-side shoulder, hip and elbow present (wrist and ear optional;
no confidence check), shoulder above hip, wrist above shoulder, and trunk (hip-to-shoulder) within
35 deg of vertical (`:22`, `:99-100`). Passing frames collect 20 frames of calibration (torso
length, trunk clock angle, ear-shoulder-hip angle; `:111-140`).

**Stop** (`:157`). `repCount >= maxRep`. No timeout.

**checkSafety** (`:183-201`). Not side view returns `turnSide`. Shoulder, hip or elbow missing
returns `bodyInFrame`; any of the three unconfident returns `lighting`. Wrist and ear are not
checked.

**Hold counting** (`:298-370`). Arm angle = deviation of shoulder-to-wrist from straight up, 0 if
the wrist is missing (`:484-491`). Back lean = deviation of hip-to-shoulder from vertical, sign
flipped for facing right (`:479-482`). Hip velocity in torso lengths per second (`:437-448`).
- activation enters `holding` at once (`:169-174`)
- `entry` to `holding`: arm angle <= 50 and |hip velocity| <= 0.025 for 10 frames (`:19`, `:23`,
  `:304-307`)
- `holding` to `exit`, **rep counted**: 12 s of wall clock (`:322-325`)
- `holding` to `exit`, **not counted**: arm angle > 50 or |hip velocity| >= 0.09 for 8 frames (`:24`,
  `:47`, `:308-310`), or back lean > 25 for 20 frames (`StickyDebouncer`, starts false; `:25`,
  `:48-49`, `:311-313`). Reasons: "Rời tư thế quá sớm - giữ Vươn tay đủ thời gian trước khi thả
  tay." or "Ngả lưng quá sâu - đứng thẳng lại rồi giữ từ đầu."
- `exit` to `entry`: after 4 s (`:17`, `:334-341`)
- a no-pose frame in `holding` returns to `entry` and resets the metrics (`:459-473`)

**Anti-cheat.** Arms up, hips still, and the backbend cap. A missing wrist counts as "arms up"
(arm angle 0, `:485`).

**Faults.** Metrics run only in `holding`, after the state machine (`:223-256`). The local
`FaultRecord` has no voice field. Records are kept once per type. Set-log keys
`lumbar_backbend_fails_count`, `cervical_fails_count`, `arm_position_fails_count` = counted holds
with that fault (`:160-167`).

| Type (count key) | Logged message (live text) | Metric and threshold | Debounce | affectsForm |
|---|---|---|---|---|
| `LumbarOverextension` (`lumbar_backbend_fails_count`) | "Trunk leaned too far backward" (English) ("⚠️ Cẩn thận thắt lưng!" at 8 frames; warning "Đừng ngả quá sâu, giữ nhẹ nhàng thôi" > 18) | back lean > 28 (`metrics/lumbar_backbend_metric.dart:12-14`, `:41-60`) | sticky 20 (record) (`:23-24`) | true |
| `CervicalDanger` (`cervical_fails_count`) | "Neck cranked back" (English) ("Nhìn lên nhẹ thôi, đừng ngửa cổ ra sau") | ear-shoulder-hip angle (unnormalised `calculateAngle`, `raised_arms.dart:502-509`), One Euro filtered and 7-frame median, < 125; ear likelihood >= 0.5 (`metrics/cervical_safety_metric.dart:10-13`, `:44-56`) | sticky 20, starts false (`:25-26`) | false |
| `ArmsLow` (`arm_position_fails_count`) | "Arms hanging forward" (English) ("Vươn tay cao hơn nhé") | arm angle > 65 with a confident wrist (`metrics/arm_position_metric.dart:13`, `:45-58`) | 10 (`:21`) | false |
| `ElbowBent` (`arm_position_fails_count`) | "Elbows bent" (English) ("Duỗi thẳng khuỷu tay nhé") | arm angle <= 45 and elbow angle (unnormalised `calculateAngle`, `raised_arms.dart:493-500`) < 125 (`metrics/arm_position_metric.dart:12`, `:16`, `:63-73`) | 10 (`:22`) | false |

**Tests.** `new_exercise_hold_contract_test.dart` (1 Raised Arms test): no count when the arms drop
before the hold target. Report builder key contract and registry tests. Nothing tests any metric.

**Unverified, stale, or suspicious.**
- **`LumbarOverextension` cannot be logged, by reading.** The state machine's backbend exit (> 25
  deg, 20 frames) runs before the metrics on every frame, and every frame that advances the metric's
  counter (> 28) also advances the exit counter (> 25). The exit therefore fires no later than the
  frame on which the metric would log, and once the state is `exit` the metrics do not run.
  `lumbar_backbend_fails_count` is structurally 0 and the "Lưng dưới ổn định c/t lượt giữ" praise
  (`raised_arms_report_builder.dart:35`, `:42`) is always earned. The backbend is handled as a
  rejected hold instead.
- **`ArmsLow` cannot be logged, by reading.** The hold breaks when the arm angle is > 50 for 8
  frames; `ArmsLow` needs > 65 for 10. Every `ArmsLow` frame is also a break frame, so the hold ends
  first.
- **`CervicalDanger` and `ElbowBent` only work in one direction, by reading.** Both use
  `calculateAngle`, which returns |atan2 difference| in 0-360 without folding
  (`lib/utils/pose_math_helpers.dart:212-229`). For a straight line the value is 180; a deviation
  toward one image side reads 180 - x and toward the other 180 + x, which never drops below 125. So
  for a given `cameraFacing` only one direction of neck tilt (and only one direction of elbow bend)
  can fire, and in that facing a head pushed forward can be logged as "Neck cranked back". The
  calibration angle uses the same function (`:123-127`).
- **Back-lean sign uses Plank's convention.** Facing left, a lean toward larger X is "backward"
  (`:479-482`), i.e. the body faces smaller X. Low Lunge, written in the same style, assumes the
  opposite (facing left = front toward larger X). At most one of the two is right for a given
  device; if this one is wrong, a forward lean is treated as a backbend (and vice versa), so a
  backbend is neither rejected nor coached.
- Calibration baselines (`_trunkBaseline`, `_cervicalBaseline`) are passed to the metrics and never
  read; they are cleared on the first return to `entry` and never refilled.
- When the wrist is present but unconfident the arm metric shows "Tay vươn tốt ✓" and checks nothing
  (`metrics/arm_position_metric.dart:45-48`).
- A rejected hold and a no-pose frame reset the metrics without counting (`:388-390`, `:466-468`);
  no set-log key counts rejected holds.
- `onExerciseActivated` does not call `super.onExerciseActivated()` (`:169-174`).
- The rep log's `hold_time` is the constant 12 (`:405`).

**Cross-cutting checks.** Cannot fire / always perfect: `LumbarOverextension` (and its "Lưng dưới"
praise), `ArmsLow`; `CervicalDanger` and `ElbowBent` in one direction per facing. Fault wipe:
rejected holds and no-pose frames reset metrics without counting. Single-frame: a no-pose frame
ends the hold (`:461-470`). Left/right: camera side via `getSideLandmark`; back-lean sign per
facing with "facing left = front toward smaller X", opposite to Low Lunge.

---

## Prayer Pose

Source: `lib/exercise/prayer_pose/` (4 files).

**Catalog.** `prayer_pose`: 1 set, 1 rep, seconds null, **`isFormChecked: false`**
(`assets/data/exercise_catalog.json:235`, `:237`). Definition (id `prayer_pose`, name "Cầu Nguyện"):
`PrayerPose(maxRep: reps)` through `_withReps` (`exercise_definition.dart:1376-1377`), target type
reps; description "Bản xem trước của bài tập Prayer Pose." (`:1363`). `PrayerPoseConfig.MAX_REP = 1`
is unreferenced (`prayer_pose.dart:13`). Hold length is the constant `HOLD_DURATION = 8.0` (`:14`).

**Flag versus code.** Consistent: the only metric is coaching (`affectsForm: false`), so a counted
hold is never marked bad form. Holds can still be rejected by the state machine.

**Archetype.** Hold-based, one rep = one 8 s hold; the same `entry -> holding -> exit` skeleton as
Low Lunge. Side view; camera side via `getSideLandmark` (`:515-547`). No `supportedOrientations`
override, so portrait only.

**Start position** (`:89-118`). Camera-side shoulder and hip present (ankle and ear optional; no
confidence check), and: shoulder above hip and hip above ankle; trunk within 50 deg of vertical
(`:20`); if the ear is present, |shoulder Y - ear Y| >= 0.22 torso (`:21`, `:509-513`); hip
velocity <= 0.06 torso/s (`:22`). **Nothing checks the hands or arms**: the defining part of the
pose (palms together at the chest) is never measured. Passing frames collect 20 frames of
calibration (`:120-160`).

**Stop** (`:168`). `repCount >= maxRep`. No timeout.

**checkSafety** (`:192-210`). Not side view returns `turnSide`. Shoulder or hip missing returns
`bodyInFrame`; either unconfident returns `lighting`.

**Hold counting** (`:312-358`).
- activation enters `holding` at once (`:186-190`)
- `entry` to `holding`: |hip velocity| <= 0.06 for 10 frames (`:17`, `:317-319`)
- `holding` to `exit`, **rep counted**: 8 s of wall clock (`:338-341`)
- `holding` to `exit`, **not counted**: |hip velocity| >= 0.18 for 8 frames (`:23`, `:320-322`), or
  trunk drift (|trunk deviation from vertical - calibrated trunk baseline|) >= 28 deg for 8 frames
  (`:25`, `:323-328`); reason "Rời tư thế quá sớm - giữ Cầu nguyện đủ thời gian trước khi thả
  lỏng."
- `exit` to `entry`: after 3 s (`:15`, `:349-356`)
- a no-pose frame in `holding` returns to `entry` and resets the metric (`:480-494`)

The trunk baseline exists only after the 20 calibration frames collected during the base
activation; it is cleared on the first return to `entry` (`:376-379`, `:430-451`), so later holds
have no trunk-drift check (drift is 0 without a baseline, `:323-325`).

**Anti-cheat.** Hip stillness and, for the first hold only, trunk drift. By reading, standing still
upright in any arm position earns the hold.

**Faults.** One metric, run only in `holding` (`:252-257`). Set-log key `posture_stack_fails_count`
= counted holds with the fault (`:171-176`).

| Type (count key) | Logged message (live text) | Metric and threshold | Debounce | affectsForm |
|---|---|---|---|---|
| `PostureStack` (`posture_stack_fails_count`) | "Forward-head posture" (English) ("Đưa đầu nhẹ về sau, mở ngực ra nhé") | (ear X - shoulder X) x forward sign / torso, One Euro filtered and 7-frame median, > 0.75; ear likelihood >= 0.5 (`metrics/posture_stack_metric.dart:17-20`, `:41-64`) | `StickyDebouncer` 10, default start state (`:25-26`) | false |

Live-only: "Thả lỏng vai xuống nhé" when the vertical ear-shoulder distance falls below 0.55 of
its calibrated value for 10 frames (`:24`, `:273-287`), first hold only (needs the baseline).

**Tests.** No dedicated behaviour test. Report builder key contract and registry tests only.

**Unverified, stale, or suspicious.**
- **`PostureStack` is logged on the first frame of the first hold, by reading.** Its
  `StickyDebouncer` is built without `currentState`, so it starts true (`lib/utils/debouncer.dart:43`)
  and returns true until 10 contrary frames arrive; the fault is recorded immediately and the live
  text tells the user to pull the head back. `reset()` does not restore the state, so this happens
  once per exercise instance. The exercise's own shoulder debouncer is explicitly reset to false
  (`prayer_pose.dart:449-450`); the metric's is not. Effect: `posture_stack_fails_count` is at least
  1 for any set with a counted hold. `affectsForm` is false, so the rep is not marked bad.
- **A real `PostureStack` probably cannot fire, by reading.** 0.75 torso of forward ear offset is
  several times a pronounced forward-head posture. Not measured.
- **The pose itself is not checked** (above). The report tip and praise talk about the ear,
  shoulder and hip stack (`prayer_pose_report_builder.dart:15-29`), which is all that is measured.
- **Forward sign uses Push-Up's convention**: facing left, forward = larger X (`:500-502`,
  `metrics/posture_stack_metric.dart:70-72`), the opposite of Raised Arms. If it is wrong for a
  device, a head held back reads as forward.
- `_cervicalBaseline` and `_postureBaseline` are computed (with the unnormalised `calculateAngle`
  for the cervical one, `:131-135`) and never read.
- A rejected hold and a no-pose frame reset the metric without counting (`:403-405`, `:487-489`).
- `onExerciseActivated` does not call `super.onExerciseActivated()` (`:186-190`).
- The rep log's `hold_time` is the constant 8 (`:420`).

**Cross-cutting checks.** Cannot fire / always perfect: real `PostureStack` detection (probable);
it fires spuriously once per instance instead. Fault wipe: rejected holds and no-pose frames reset
the metric without counting. Single-frame: a no-pose frame ends the hold; `PostureStack` is logged
from the first holding frame. Left/right: forward sign per facing with "facing left = forward
toward larger X" (Push-Up, Low Lunge), opposite to Raised Arms.

---

## Ashtanga Namaskara

Source: `lib/exercise/ashtanga_namaskara/` (5 files).

**Catalog.** `ashtanga_namaskara`: 3 sets, 5 reps, seconds null, **`isFormChecked: false`**
(`assets/data/exercise_catalog.json:4`, `:6`). Definition: `AshtangaNamaskara(maxRep: reps)` through
`_withReps` (`exercise_definition.dart:1330-1331`), target type reps, so `mode` is the default
`AshtangaMode.transient` (`ashtanga_namaskara.dart:46-49`); description "Bản xem trước của bài tập
Ashtanga Namaskara." (`:1317`). `AshtangaConfig.MAX_REP = 1` is unreferenced (`:23`).

**Flag versus code.** The `hip` fault is `affectsForm: true` (`metrics/hip_collapse_metric.dart:61-69`),
although the catalog says not form-checked (and by reading it almost never fires, below).

**Archetype.** Rep-based by **recognition**: in the default transient mode one rep = the shape held
still for 500 ms. A `microHold` mode (3 s hold) exists but no definition selects it. Side view;
camera side via `getSideLandmark` (`:594-634`). No `supportedOrientations` override, so portrait
only. Voice: `PolicyVoiceCoach`, slug `ashtanga_namaskara`, fault ids `hip`, `neck` (`:38-41`,
`:87-115`), with `// TODO(voice): fast-movement policy variant` (`:89`).

**Shape** (`:576-592`). With Y downward:
- "hip position ratio" = (shoulder Y - hip Y) / torso, i.e. how far the hip is **above** the shoulder
- `chestLow` = that ratio >= 0.035 (`:32`)
- `kneesGrounded` = |knee Y - ankle Y| / torso <= 1.2 (`:31`)
- shape present = knees grounded, chest low, ratio >= 0.08 (`:30`, `:353-355`)

By reading, `chestLow` is implied by ratio >= 0.08, and a knee-to-ankle height of 1.2 torso is more
than a shin length, so the shape reduces to "hips at least 0.08 torso above the shoulders". Nothing
checks that the chest, knees or chin touch the floor.

**Start position** (`:135-154`). The shape; 12 frames of calibration are collected (`:156-177`).

**Stop** (`:185`). `repCount >= maxRep`. No timeout.

**checkSafety** (`:217-235`). Not side view returns `turnSide`. Camera-side shoulder, hip, knee or
ankle missing returns `bodyInFrame`; any of them unconfident returns `lighting`.

**Rep counting** (`:348-410`), transient mode. Shoulder velocity = frame-to-frame shoulder Y change
in torso lengths per second (`:531-543`).
- activation enters `recognized` at once (`:205-215`)
- `entry` to `recognized`: shape and |shoulder velocity| <= 0.08 for 4 frames (`:27`, `:33`,
  `:356-358`)
- `recognized` to `exit`, **rep counted**: 500 ms since entering `recognized` (`:26`, `:381-387`)
- `recognized` to `exit`, **not counted**: shape lost or |shoulder velocity| >= 0.22 for 6 frames
  (`:34`, `:64`, `:359-362`, `:376-380`); reason "Rời tư thế Ashtanga quá sớm - vào lại 8 điểm chạm
  rồi giữ ổn định."
- `exit` to `entry`: after 2 s (`:25`, `:401-408`)
- a no-pose frame in `recognized` or `holding` returns to `entry` and resets the metrics
  (`:554-570`)
- a pose finalised when `repCount >= maxRep` is not counted (`:457`)

**Anti-cheat.** The shape and stillness gates only. **By reading, holding the pose still counts a
rep about every 2.6 s**: after a counted rep the state goes `exit` (2 s) then `entry`, and if the
user has not moved, 4 still frames re-enter `recognized` and 500 ms later count again. Nothing
requires leaving the shape between reps, so the catalog's 5 reps can be earned in one ~13 s hold.

**Faults.** Metrics run in `recognized` and `holding`, after the state machine (`:277-289`).
Records are kept once per type. Set-log keys `hip_collapse_fails_count`, `cervical_fails_count` =
counted reps with that fault (`:188-194`).

| Type (count key) | Logged message (live text) | Metric and threshold | Debounce | affectsForm |
|---|---|---|---|---|
| `hip` (`hip_collapse_fails_count`) | "Hips collapsed toward shoulders" (English) ("⚠️ Đẩy hông lên cao!" at 6 frames; warning "Đẩy hông lên cao hơn, đừng để bằng vai" for 0.10-0.30) | hip position ratio < 0.10 (`metrics/hip_collapse_metric.dart:14-16`, `:42-58`) | sticky 15, starts false (`:25-26`) | true |
| `neck` (`cervical_fails_count`) | "Neck cranked upward" (English) ("Đặt cằm xuống nhẹ, đừng đẩy đầu lên cao") | ear-shoulder-hip angle (unnormalised `calculateAngle`, `ashtanga_namaskara.dart:246-252`), One Euro filtered and 7-frame median, < 100; ear likelihood >= 0.5 (`metrics/cervical_safety_metric.dart:16-19`, `:41-60`) | sticky 8, starts false (`:24-25`) | false |

Live-only (`:307-319`): "Hạ gối xuống sàn trước", "Hạ ngực xuống sát sàn nhé" / "Ngực hạ thấp tốt ✓".

**Tests.** `new_exercise_hold_contract_test.dart` (1 Ashtanga test): transient mode does not count
a broken recognition window. Report builder key contract and registry tests. Nothing tests the
repeated-count path or either metric.

**Unverified, stale, or suspicious.**
- **Repeated reps from one hold** (see Anti-cheat). Not tested.
- **`hip` almost cannot fire, by reading.** In transient mode a rep's metrics see at most the frames
  inside the 500 ms window (about 15 at 30 fps; the state leaves `recognized` before metrics run on
  the 500 ms frame). The fault needs 15 consecutive frames with the ratio below 0.10, while a ratio
  below 0.08 for 6 frames breaks the shape and rejects the attempt. So it needs >= 30 fps and every
  frame of the window inside the 0.08-0.10 band. At lower frame rates it cannot fire.
- `neck` uses the unnormalised `calculateAngle`. In this pose the ear-to-shoulder and hip-to-shoulder
  vectors are both near horizontal, so the reading crosses the +/-180 branch cut and a neutral neck
  reads near 170 in one facing and near 190 in the other. The thresholds (100 / 118) were not
  derived for both. By reading; not measured.
- The shape gate is very loose (above): a downward dog, a pike or a forward fold with hips above the
  shoulders passes.
- The calibration cervical baseline is computed and never read.
- A rejected attempt and a no-pose frame reset the metrics without counting (`:467-469`,
  `:563-565`).
- `onExerciseActivated` does not call `super.onExerciseActivated()` (`:205-215`).
- The rep log's `hold_time` is the constant 0.5 s in transient mode (`:496-498`).

**Cross-cutting checks.** Cannot fire / always perfect: `hip` (probable; frame-rate dependent).
Fault wipe: rejected attempts and no-pose frames reset metrics without counting. Single-frame: a
no-pose frame ends the attempt (`:556-567`). Left/right: camera side via `getSideLandmark`; no
facing constant, but the unnormalised neck angle is facing-dependent.

---

## Surya Namaskar (sun salutation sequence)

Source: `lib/exercise/surya_namaskar/` (3 files: `surya_namaskar.dart`, `pose_recognizers.dart`,
`safety_overrides.dart`). Also opened for this section: the `CobraConfig` constants it imports
(`lib/exercise/Cobra/cobra.dart:26-39`), `ViettelTTSService` (`lib/services/viettel_tts_service.dart:55`,
`:132-215`) and the `ttsService` field on `ExerciseBase` (`exercise_base.dart:306`).

**Catalog.** `surya_namaskar`: 1 set, 3 reps, seconds null, **`isFormChecked: false`**
(`assets/data/exercise_catalog.json:378`, `:380`). Definition (id `surya_namaskar`, name "Chào Mặt Trời",
subtitle "Chuỗi 12 tư thế yoga"): `SuryaNamaskarExercise(maxRounds: reps)` through `_withReps`
(`exercise_definition.dart:1260-1261`), so "reps" are rounds of 12 poses; lead leg is the default
right (`surya_namaskar.dart:55-59`). Description "Bản xem trước của bài tập Chào Mặt Trời."
(`:1247`).

**Flag versus code.** Consistent in effect: the class records no `FaultRecord` at all. A round is
marked `correctForm` when it had no safety trigger and no missed pose (`:725`).

**Archetype.** A sequence of 12 timed poses; one rep = one full round. Side view, landscape only
(`:222-227`). It does not instantiate or reuse any other exercise class: each pose has its own
small recogniser in `pose_recognizers.dart` that re-implements, with different thresholds, the
ideas of Prayer Pose, Raised Arms, a forward fold, Low Lunge, High Plank, Ashtanga Namaskara,
Cobra and Downward Dog. The only shared code is `CobraConfig` (horizontal clock targets 270 / 90,
`PRONE_TOLERANCE = 35`, `COBRA_MIN_ELEVATION = 18`, `COBRA_OVEREXTENSION_MAX = 78`,
`COBRA_ELBOW_LOCKOUT_MIN = 170`; `Cobra/cobra.dart:26-39`).

**The sequence** (`:66-193`). Every step lasts 5 s of recognised hold (`:14-15`; step 6 sets the
same 5 s explicitly).

| Step | Pose id (recogniser) | Spoken cue (start of step) |
|---|---|---|
| 1, 12 | `pranamasana` | "Đứng thẳng, chắp tay trước ngực. Thở ra một hơi." / "Thở ra, chắp tay trước ngực. Hoàn thành vòng." |
| 2, 11 | `hastaUttanasana` | "Hít vào, vươn tay lên cao, ngả nhẹ." / "Hít vào, đứng dậy, vươn tay lên cao, ngả nhẹ." |
| 3, 10 | `uttanasana` | "Thở ra, gập người về trước. Gập gối nếu cần." / "Thở ra, bước chân trái lên, gập người về trước." |
| 4 | `lowLungeRightBack` (expects left leg in front) | "Hít vào, bước chân phải ra sau, gối phải xuống sàn." |
| 5 | `highPlankBlank` (recognised; `isBlank` is false) | "Bước về tấm ván cao, vai trên cổ tay và thân người thẳng." |
| 6 | `ashtangaNamaskara` | "Thở ra, hạ gối, ngực, cằm. Hông giữ cao." |
| 7 | `cobra` | "Hít vào, trượt ngực lên thành rắn hổ mang. Ngả nhẹ thôi." |
| 8 | `downwardDog` | "Thở ra, đẩy hông lên cao thành chó cúi mặt." |
| 9 | `lowLungeLeftBack` (expects right leg in front) | "Hít vào, bước chân phải lên trước, gối trái xuống sàn." |

(Left-lead mirrors steps 4 and 9; no definition selects it.)

**How the sequence is driven** (`:434-525`, `:599-767`).
- Activation calls `_startRound`, which enters step 1 (`:260-263`, `:599-608`).
- Each step starts in `waiting`. After a 300 ms grace (`:16`, `:491-492`) the recogniser must return
  true on 6 consecutive frames (2 for Cobra) (`:17-18`, `:490-500`, `:527-531`); then the step enters
  `holding` and "Đúng tư thế. Giữ 5 giây." is spoken (`:631-652`).
- In `holding`, each recognised frame adds its frame gap, capped at 250 ms, to the step's hold time;
  unrecognised frames add nothing but do not reset it (`:501-508`, `:654-664`). For Cobra, any trunk
  deviation from horizontal >= 35 deg also keeps counting (`:533-564`).
- At 5 s the step completes: "Hoàn thành X. Tiếp theo Y." plus the next cue is spoken, and the next
  step begins in `waiting` (`:666-691`).
- Before recognition, every frame runs a safety check for the current pose (below). A triggered check
  skips recognition and hold ticking for that frame and speaks its message once per code (`:464-480`,
  `:693-708`).
- After step 12 the round completes: `repCount` += 1 and a rep log is written with recognised /
  missed / blank pose counts, safety triggers, the variance of step durations and the round duration
  (`:710-753`). The next round starts at once at step 1 (`:766`); the set ends after `maxRounds`
  (`:759-764`).
- There is **no timeout and no skip**: a step that is never recognised waits forever; after three
  safety triggers in a round the user hears "Bài sẽ chờ bạn chỉnh lại tư thế, không tự kết thúc."
  (`:705-707`).

**Start position** (`:249-258`, `:294-432`). A strict visibility gate (both shoulders, elbows, wrists,
hips, knees, ankles with presence >= 0.45, visibility >= 0.20, likelihood >= 0.20, plus a mouth corner
or the nose) and a raised-arms check on both arms: wrist above shoulder + 0.15 torso, shoulders above
hips, elbow angle (unnormalised `calculateAngle`) >= 105, arm within 85 deg of vertical (`:20-23`).
So the user activates with arms raised, and the flow then starts at step 1 (palms together).

**Stop** (`:265-266`). `_setComplete`, i.e. `maxRounds` rounds. No timeout.

**checkSafety** (`:268-292`). Not side view returns `turnSide`. Before activation the strict
visibility gate failing returns `bodyInFrame`. After activation only the presence (not confidence) of
both shoulders and hips is checked; nothing returns `lighting`.

**Recognisers** (`pose_recognizers.dart`). Side landmarks are the camera side (`:557-565`).

| Pose | Recognised when | Lines |
|---|---|---|
| Prayer | shoulder above hip, trunk within 35 deg of vertical, and \|shoulder Y - ear Y\| >= 0.25 torso (ear optional); hands not checked | `:72-107` |
| Raised arms | wrist above shoulder, elbow (unnormalised) >= 120, shoulder above hip, back lean <= 22 | `:109-150` |
| Forward fold | forward trunk lean (`convertClockAngleToTrunkLean`) >= 45 or shoulder below hip, and wrist no more than one torso above the hip | `:152-185` |
| Low lunge | ankle X gap > 0.50 torso, front knee (unnormalised `calculateAngle`) < 170, and the front leg is the expected side | `:187-224` |
| High plank | shoulder-hip-ankle >= 150, \|hip Y - shoulder Y\| <= 1.0 torso, \|wrist X - shoulder X\| <= 1.2 torso | `:257-297` |
| Ashtanga | \|knee Y - ankle Y\| <= 1.0 torso, hip above shoulder by >= 0.12 torso (and >= 0.05) | `:226-255` |
| Cobra | trunk raised more than 18 deg past the facing's horizontal target (facing right: clock < 72; facing left: clock > 288) | `:299-357` |
| Downward dog | (hip above shoulder **or** above knee), wrist and ankle below hip, wrist-shoulder-hip >= 110 | `:359-398` |

**Safety overrides** (`safety_overrides.dart`). Each code triggers after 3 consecutive unsafe frames
(`:223-242`). These are not `FaultRecord`s; they only count toward `total_safety_triggers` and the
round's `correctForm`.

| Code | Spoken / shown message | Condition | Lines |
|---|---|---|---|
| `raised_arms_lumbar_backbend` | "Cẩn thận lưng dưới, ngả nhẹ thôi." | back lean > 15 | `:67-94` |
| `low_lunge_knee_travel` | "Cẩn thận đầu gối, đẩy hông ra sau một chút." | front knee ahead of ankle by > 0.8 torso | `:96-115` |
| `high_plank_body_line` | "Giữ vai, hông và gót chân trên một đường thẳng." | shoulder-hip-ankle < 145 | `:137-156` |
| `ashtanga_hip_collapse` | "Đẩy hông lên cao, đừng sụp hông xuống ngang vai." | hip above shoulder by < 0.15 torso | `:117-135` |
| `cobra_elbow_locked` / `cobra_lumbar_overextension` | "Giữ khuỷu tay gập nhẹ, đừng đẩy thành upward dog." / "Cẩn thận lưng dưới, nâng ngực nhẹ hơn." | elbow (unnormalised) > 170, or trunk elevation > 78 | `:158-200` |
| `downward_dog_spine_round` | "Gập gối nếu cần, giữ lưng dài hơn." | wrist-shoulder-hip < 145 | `:202-221` |

Several safety bands overlap the recognition bands, so the effective requirement is the stricter
one: back lean <= 15 (not 22), ashtanga hip ratio >= 0.15 (not 0.12), downward-dog arm-trunk angle
>= 145 (not 110).

**Voice: the only caller of the cloud TTS service.** `createVoiceCoach()` returns null (`:217-218`),
so no `PolicyVoiceCoach` runs. Every cue above is spoken through `ttsService`, the
`ViettelTTSService` singleton held by `ExerciseBase` (`exercise_base.dart:306`); by grep, Surya is
the only exercise that calls it (`surya_namaskar.dart:627-628`, `:647-648`, `:687-690`, `:702-706`,
`:761-762`). `speak` queues text; playback first looks the exact text up in a small local asset map,
otherwise POSTs it to `https://viettelai.vn/tts/speech_synthesis`; without `VIETTEL_TTS_TOKEN` it logs
and skips the phrase (`viettel_tts_service.dart:55`, `:132-215`). By reading, the step cues are long
dynamic sentences not in the asset map, so without the token the whole sequence is silent, and with it
every cue costs a network round trip before it plays.

**Tests.** `new_exercise_hold_contract_test.dart` (1 Surya test): the High Plank step is recognised
rather than auto-passed. Registry test maps `surya_namaskar` to `GenericReportBuilder`; the report
builder key contract lists it. `test/voice/policy_voice_coach_wiring_test.dart` mentions it (not
opened). Nothing tests a full round, the safety overrides or any other recogniser.

**Unverified, stale, or suspicious.**
- **Conflicting facing conventions inside one sequence, by reading.** The user faces the same way
  for the whole round. Raised Arms back lean, forward-fold lean and Cobra treat facing left as "front
  toward smaller X" (`pose_recognizers.dart:567-573`, `pose_math_helpers.dart:331-345`,
  `pose_recognizers.dart:343-357`); the low-lunge front leg treats facing left as "front toward larger
  X" (`pose_recognizers.dart:540-542`, `safety_overrides.dart:325-327`). On a given device one of the
  two is inverted. If it is the lunge, the user who steps back with the leg the voice names
  ("bước chân phải ra sau") is never recognised at step 4 (and step 9), and the flow waits forever;
  if it is the others, Cobra is never recognised at step 7.
- **Unnormalised angles can block steps, by reading.** `calculateAngle` returns 0-360 without
  folding (`pose_math_helpers.dart:212-229`). (a) Low-lunge front knee: with the shin vertical and
  the thigh pointing back, it reads about 100 when the hip lies at larger X than the knee and about
  260 when it lies at smaller X, so for one of the two directions the user can face, "< 170" fails on
  a correct lunge. (b) Cobra elbow: a bent elbow reads 180 - x in one facing and 180 + x in the
  other; in the second, a correctly bent elbow exceeds 170 and fires "đừng đẩy thành upward dog",
  which blocks recognition of step 7. Neither is tested.
- **`missed_poses` is structurally 0 and the "missed" part of `correctForm` is always perfect.** A
  step only advances after it was recognised (`:666-681`), so every non-blank step is in
  `_recognizedPoseNumbers` when the round completes (`:713-721`). No step sets `isBlank`, so the blank
  path (`:447-462`) is dead and `blank_poses` is always 0.
- The poses are recognised loosely: Prayer never checks the hands; High Plank does not require a
  horizontal body (an upright stance has a shoulder-hip-ankle line near 180 and a shoulder-hip height
  difference just under 1.0 torso); Downward Dog's "hips high" is satisfied by any hip above the knee.
- The low-lunge knee-travel override (> 0.8 torso) is near the shin length, so by reading it rarely
  fires (same reasoning as Low Lunge).
- After activation nothing checks landmark confidence; low-confidence landmarks drive recognition.
- `usesSegmentationPersonGate` (`:220`) is not declared in `ExerciseBase` (grep), so it overrides
  nothing and the presence gate still runs.
- **Import path case.** All three files import `'../cobra/cobra.dart'` while the tracked directory is
  `lib/exercise/Cobra/` and `exercise_definition.dart:27` imports `../exercise/Cobra/cobra.dart`. On
  a case-sensitive file system the Surya imports would not resolve. Not built.
- `manualPause` / `manualResume` mix `DateTime.now()` with frame timestamps (`:566-585`).
- `onExerciseActivated` does not call `super.onExerciseActivated()` (`:260-263`).
- `_SuryaFlowVoiceCoach` is unused (`:827-846`).

**Cross-cutting checks.** Cannot fire / always perfect: `missed_poses` (and the missed-pose half of
`correctForm`); `blank_poses`. Fault wipe: none (no fault records). Single-frame: no; recognition
needs 6 frames (Cobra 2) and safety 3. Left/right: camera side; two opposite facing conventions in
the same sequence (above).

---

## What was not read

- All 40 exercise directories are covered. Within them nothing was skipped: every file of every
  directory was read in full in its batch.
- Outside the forty directories, only these were read in full:
  `lib/exercise/hold/` (all 3 files in batch 1; `rep_counted_hold_exercise.dart` again in batches 2
  and 4; `timer_metric.dart` again in batch 4),
  `lib/exercise/side_tracked_exercise_mixin.dart` (batch 1; batch 2 only re-checked lines 25-60 and
  170-180), `lib/utils/debouncer.dart`, `lib/utils/hold_seconds_accumulator.dart` (batch 2, again in
  batch 3). Line ranges only: `lib/exercise/exercise_base.dart` (batch 2: 284-289, 530-599,
  678-736; batch 3: 312, 781-826; batch 4: 306, 817-921), `lib/utils/pose_math_helpers.dart`
  (batch 2: 180-384; batch 3: 244-266, 325-370; batch 4: 180-266, 325-378),
  `lib/utils/frame_buffer.dart` (batch 2: 11-46; batch 3: 1-60), `lib/utils/debouncer.dart`
  (batch 4: 38-64, `StickyDebouncer`), `lib/services/viettel_tts_service.dart` (batch 4: 125-215,
  plus lines 8-11 and 55 by grep), `lib/services/workout_launch_service.dart` (batch 4: 235-264),
  `lib/exercise/Cobra/cobra.dart` (batch 4: the `CobraConfig` constants at 26-39, by grep).
- Not read: `fault_record.dart`, `debug_types.dart`, `frame_snapshot.dart`, `exercise_logger.dart`,
  the `ExerciseReportBuilder` base class and `GenericReportBuilder` (Surya's report),
  `PoseSmoother`, `SquatInterpreter` (used by Squat's report), `report_builder_registry.dart`, and the
  whole voice layer (`VoiceScript`, `VoiceDefaults`, `PolicyVoiceCoach`, `GenericExerciseVoiceAssets`,
  `lib/services/plank_voice_coach.dart`, `lib/services/bow_pose_voice_coach.dart`). The "voice"
  column above is the `voiceMessage` string on the `FaultRecord`; which audio clip actually plays
  for each fault id was not traced. In batch 3 this matters most for Warrior I and Cobra, which do
  not override `createVoiceCoach` (the base default was not read), and for Step-Back Burpee, whose
  fault records carry no `voiceMessage` at all. In batch 4 only Bow Pose, Ashtanga and Surya
  override `createVoiceCoach`; Sphinx, Butterfly, Seated Forward Fold, Downward Dog, Low Lunge,
  Raised Arms and Prayer Pose do not, and Low Lunge, Raised Arms, Prayer Pose and Butterfly use
  local `FaultRecord` classes with no voice field. Only the tail of `ViettelTTSService`'s local asset map was seen, so the claim that Surya's
  cues are not in it is by reading of the cue strings, not of the full map.
- `isFormChecked` (finding 14) was traced by grep only: the four call sites were found and
  `workout_launch_service.dart:235-264` was read; the recommendation engine and plan mapper lines
  were not read in context.
- Catalog and definitions: the whole catalog JSON was read (all 40 entries) in batch 4.
  `lib/models/exercise_definition.dart` line ranges: batch 2: 1-445, 590-660, 1072-1107, 1217-1290;
  batch 3: 40-64, 160-175, 200-238, 360-504, 936-1037, 1141-1217; batch 4: 240-275, 706-719,
  876-937, 1038-1075, 1107-1143, 1242-1405, and the batch 1 `createExercise` lines by grep.
- `detectCameraFacing` / `_isLeftSide` were read, but how the native pipeline mirrors or rotates
  coordinates before they reach Dart (`pose_landmarker_adapter.dart`, `vika_image_orientation.dart`,
  native code) was not. Cross-cutting finding 6 depends on it.
- Tests: for every dedicated and shared test file in all four batches only the test names were
  read, not the bodies. Exceptions: the landmark constants and facing of
  `plank_anti_cheat_test.dart` and `push_up_anti_cheat_test.dart` (batch 2); the fixture header of
  `russian_twist_anti_cheat_test.dart` (lines 1-80) and the facing and ankle positions in
  `warrior_one_stress_test.dart` (batch 3); the facing used by `jump_squat_anti_cheat_test.dart` and
  `cobra_logging_regression_test.dart` (by grep); the Sphinx pose builder and first Sphinx test in
  `hold_voice_scale_migration_test.dart` (lines 35-84, 144-190) and the Downward Dog test in
  `new_exercise_hold_contract_test.dart` (lines 120-150) (batch 4). `curl_up_orientation_test.dart`
  has uncommitted changes in this checkout; its test names were read from the working tree. Tests
  outside `test/exercise/` that mention these exercises (`test/services/`, including
  `bow_pose_voice_assets_test.dart` and `bow_pose_voice_coach_test.dart`, `test/voice/`,
  `test/screens/`, `test/exercise_lookup_catalog_test.dart`) were not opened.
- Batch 4 by grep only, not read: the batch 3 Cobra metrics' use of default-true `StickyDebouncer`s
  (finding 11) and the batch 1-3 call sites of the unnormalised `calculateAngle` (finding 12).
- Nothing was run. Every "by reading" conclusion should be confirmed with a test or a device session
  before acting on it, in particular: batch 1's Superman elevation fault, Dead Bug `stable_limbs`,
  the structurally-zero `*_fails_count` keys and the Sit-Up report-card key mismatch; batch 2's
  head-direction conflict (finding 6), the Plank sag/pike sign per facing, the Squat and Walking
  Lunge clean-rep overrides, Bear Plank's single-frame faults, Side Plank's zero `*_seconds`, the
  Lunge lumbar angle per facing, the Glute Bridge velocity units, and the Walking Lunge double
  smoothing; batch 3's unwired Tricep Dip metrics, the Russian Twist trunk-angle gate in a real
  front view, the Jumping Jack `legs` fault during the closing phase, the Cossack `torso` clock-angle
  comparison, Warrior I and Cobra holds that continue after the pose is lost, the Warrior I
  cervical/back-straight contradiction, the Cobra neck sign facing right, and the Cobra descent
  faults that never fire; batch 4's Downward Dog hold that cannot restart after an abort, Low Lunge
  and Prayer faults logged on the first frame (finding 11), Ashtanga counting repeated reps from one
  hold, Surya's two facing conventions and its unnormalised knee and elbow angles, Raised Arms'
  unreachable `LumbarOverextension` and `ArmsLow`, Seated Forward Fold's hold that cannot resume
  after easing back 12 deg, Butterfly's stillness-only hold gate, and the Surya `cobra` import path
  on a case-sensitive file system.
