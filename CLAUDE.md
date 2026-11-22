# Vika

Rewritten from scratch on 2026-11-16 from a read of the code. Claims cite file paths. The last section
lists what was NOT read or run. The previous CLAUDE.md (working rules + older codebase map) is in git
history: `git log --follow CLAUDE.md`, the version before the 2026-11-16 rewrite.

## What the app is

Vika (`pubspec.yaml`: "AI fitness coaching for Vietnamese home exercisers", 1.0.3+155, bundle id
`com.vikavn.app`). The phone camera watches the user exercise. Pose landmarks are computed on the
device, per-exercise logic counts reps/holds and detects form faults, and the app coaches by voice and
on-screen cues. User-facing strings are Vietnamese; code and docs are English.
Stack: Flutter/Dart, native pose + segmentation plugins (Kotlin, Swift), Supabase (auth, data),
PostHog (EU host, off until consented).

## Commands (FVM-pinned; not executed by me)

```bash
fvm flutter pub get
cd ios && pod install && cd ..                    # iOS only
fvm flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
fvm flutter analyze                               # flutter_lints, constant_identifier_names ignored
fvm flutter test                                  # 108 files under test/
fvm flutter test test/exercise/presence_gate_test.dart
```

Config: `lib/main.dart` `_loadAppConfig()` reads `--dart-define` first, then gitignored
`assets/env/app.env` (template `app.env.example`). Keys: `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
optional `POSTHOG_API_KEY`, `POSTHOG_HOST`. Missing Supabase config shows
`_VikaStartupErrorApp`. Tooling: `tool/generate_exercise_catalog.dart` (catalog JSON from Supabase),
`tools/voice_tts/generate.py`, `supabase/` (2 edge functions; `migrations/20261116_baseline.sql` and
`seed.sql` rebuild the whole backend on a fresh project).

## Pose pipeline (the core)

```
Native camera + MediaPipe PoseLandmarker (Kotlin / Swift)
 -> EventChannel 'com.vikavn.app/pose_landmarker_stream'  lib/pose/pose_landmarker_channel.dart
 -> PoseLandmarkerAdapter.fromChannelData -> Pose          lib/pose/pose_landmarker_adapter.dart
 -> ActiveExercisePage._handleLandmarkEvent                lib/screens/exercise/active_exercise_page.dart:1153
 -> ExerciseBase.processPose                               lib/exercise/exercise_base.dart:481
      PoseSmoother (One Euro, x/y only) -> PresenceGate.onPose -> detectCameraFacing
      -> checkSafety (subclass) -> scale factor -> checkExerciseState (3 s hold-still)
      -> checkingPose (subclass metrics)
 -> [repCount, feedback] -> UI + PolicyVoiceCoach
```
No skeleton in a frame goes through `processNoPoseFrame()`, which still ticks the presence gate.

**Native.** MediaPipe PoseLandmarker, `pose_landmarker_lite.task`, live stream, 1 pose.
Android (`PoseLandmarkerHelper.kt`, `PoseLandmarkerPlugin.kt`): CameraX, `tasks-vision:0.20230731`,
CPU, min detection/presence/tracking 0.5/0.5/0.5. iOS (`PoseLandmarkerService.swift`):
`MediaPipeTasksVision ~> 0.10.21`, GPU with CPU fallback, 0.5/0.5/0.7. Preview is a native `Texture`.
Channel methods: initialize, startDetection, stopDetection, switchCamera, setOrientation,
setDetectionInterval, dispose. Selfie segmentation (ML Kit, stream mode) is a separate channel
`com.vikavn.app/segmentation` (`SelfieSegmentationHelper.kt`, `SegmentationService.swift`); native
sends only `personRatio` and `softPersonRatio`. `google_mlkit_pose_detection` is still a dependency but
on devices only supplies Dart types (`Pose`, `PoseLandmark`, `InputImage`); its detector runs only as
an emulator fallback (`_startMlKitFallback` in `active_exercise_page.dart`).

**Confidence.** Native sends x,y,z, `visibility`, `presence`; presence and visibility ride on an
`Expando` (`lib/pose/vika_pose_landmark.dart`). `ExerciseBase.MIN_PRESENCE = 0.7`,
`MIN_VISIBILITY = 0.3`, `isLandmarkConfident()` (`exercise_base.dart:249-303`). `checkSafety` returns a
`GuidanceSignal` (searching, paused, bodyInFrame, lighting, turnSide, faceCamera, setupPosition,
holdStill, resume, phoneLandscape, phonePortrait). Non-null means that frame stops: no rep counting, no fault evaluation, a Vietnamese
prompt is shown instead. Plank (`plank.dart:157-205`): not side-on -> turnSide; missing joints ->
bodyInFrame; low-confidence shoulder/hip/ear -> lighting. Guidance copy lives in `ExerciseBase`, not
in `PresenceGate`.

**PresenceGate** (`lib/exercise/presence_gate.dart`): "is a real person in frame", auto-pause/resume,
driven by `PersonDetector` (segmentation), not by landmarks. Confirm 400 ms; auto-pause after 400 ms
lost; auto-resume after 320 ms present; manual pause only cleared by `manualResume`. After any resume
the exercise drops back to `notActivated` and the user must re-hold the start pose 3 s. Extra
segmentation samples are triggered by: no landmarks, pose returned, avg presence < 0.35, frame-edge
risk (>= 2 joints outside or >= 5 within the 4% margin, >= 8 visible), and `PresenceAnomalyDetector`
(window 60/10 frames, delta 0.15). `PersonDetector` (`lib/utils/person_detector.dart`): pixel
confidence 0.82, soft 0.35 (weight 0.45), enter 0.03, exit 0.02, EMA 0.30; cadence 2 s searching, 8 s
active, 1 s auto-paused; pose inference throttles to ~1 fps while paused. Tests:
`presence_gate_test.dart`, `resume_rehold_regression_test.dart`.

**ExerciseBase contract.** State `notActivated -> activated -> completed`. Subclasses implement
`requestStop`, `checkSafety`, `checkingPose`, `isInStartPosition`, `onSetComplete`, `exerciseName`,
`currentPhaseKey`, `currentPhaseLabel`; optional `supportedOrientations` (default portrait),
`liveHoldSeconds`, `liveFaults`, `usesRepCountedHolds`, `createVoiceCoach()`. Camera facing from
shoulder width / torso height: > 0.57 front, < 0.35 side (left/right by z-vote, 5-frame sticky
debouncer), else angled (`exercise_base.dart:37-49`). `scaleFactor` = shoulder-hip pixel distance
(hard-write before activation, EMA 0.1 after, never written from unconfident landmarks).
`frameTimestamp` is read once per frame; do not call `DateTime.now()` mid-frame.
`ResultIssues.feedback` clears every frame. `SideTrackedExerciseMixin` picks the camera-side limb.

## Exercises

Each is `lib/exercise/<name>/` with main class, `metrics/`, `*_report_builder.dart`. Directory names are
inconsistent (`1.Bird Dog`, `glute bridge`, `push up`); keep existing names. 43 exercise dirs plus the shared `hold/`.
- Metrics debounce (`lib/utils/debouncer.dart`), write feedback, record `FaultRecord`s. Real example:
  `plank/metrics/trunk_alignment_metric.dart` (sag > 8/12 deg, pike > 4/8 deg, 5-frame debounce, form
  affected only if fault time > 45% of the hold).
- Archetypes: rep-based, and hold-based via `RepCountedHoldExercise`
  (`lib/exercise/hold/rep_counted_hold_exercise.dart`; High Plank, Bear Plank, Butterfly, Seated
  Forward Fold, Side Plank Dip, Sphinx, Neck Side Stretch). Plank is a separate hold implementation
  (15 s hold, 5 s rest).
- New exercise touchpoints: `exerciseDefinitions` in `lib/models/exercise_definition.dart` (+ aliases in
  `exercise_lookup.dart`); `assets/data/exercise_catalog.json` (43 entries, mirrors Supabase
  `exercise_catalog`; same rows in `supabase/seed.sql`); `report_builder_registry.dart` (builder +
  MET) and `calorie_estimator_registry.dart` (only squat has a custom estimator, the rest use the
  MET fallback); `kExercisePlacementByCatalogId` in `camera_placement_card.dart`; `keptExerciseIds`
  in `lib/models/kept_exercises.dart`; a row in `lib/data/library_mock.dart`;
  `assets/audio/<slug>/` listed in `pubspec.yaml` plus voice keys
  (`lib/services/generic_exercise_voice_assets.dart`). Only list an audio folder in `pubspec.yaml`
  once it has files: a listed folder that does not exist fails the build.
- 30/43 catalog entries are `isFormChecked: true`. Not form-checked: ashtanga_namaskara, butterfly,
  downward_dog, low_lunge, neck_side_stretch, prayer_pose, pushup_rotation, raised_arms,
  reverse_crunch, russian_twist, standing_knee_to_elbow, step_up, surya_namaskar. The recommendation
  engine only picks form-checked rows, so these never enter generated plans.
- 24 kept exercises (`keptExerciseIds`): the 21 of 2026-11-20 plus step_up, neck_side_stretch and
  pushup_rotation (added 2026-11-22, counts only, thresholds not measured on a device; see
  `docs/field-test-log.md` 5.16). 4 are validated (`validatedExerciseIds`).
- Landscape is on (`kLandscapeRotationEnabled`): OS locked to portrait, UI rotated from the sensor
  (`lib/pose/vika_image_orientation.dart`). All 24 kept exercises are landscape-only
  with one shared placement (`kOnePlacementWhere` in `camera_placement_card.dart`: phone landscape,
  60–70 cm high, ~3 m away). In landscape the preview uses `BoxFit.contain` so the screen shows the
  whole frame the AI sees.
- Android capture (`PoseLandmarkerPlugin.kt`): preview 1440x1080 and analysis 960x720 (both 4:3, full
  sensor width), CameraX rotates frames natively, AE fps locked to the best range <= 30, landmark
  pixel size reported with a 1280 long side. MediaPipe tries GPU and falls back to CPU. Logcat tags
  `PoseLandmarkerPlugin`/`PoseLandmarkerHelper` print `perf` lines every 3 s.
- The skeleton is drawn by `SmoothedPoseOverlay` (`lib/pose/pose_display_smoother.dart`): display-rate
  interpolation with a 40 ms velocity lead between detections. Drawing only; rep logic still uses the
  raw detections.

## Workout flow and data

`pushNamed('/exercise', ExerciseLaunchArgs)` -> `ExerciseExperienceScreen` loops phases
`intro -> active -> rest -> transition` (`exercise_experience_screen.dart:889`) -> `WorkoutSummaryScreen`.
Results accumulate as `ExerciseSessionReport`
(`lib/models/workout_session_report.dart`). Data path: `ExerciseLogger`/`RepLog`
(`lib/utils/exercise_logger.dart`) -> report builder -> `PostExerciseData` -> `SessionPersistence`
(`lib/services/session_persistence.dart`) -> Supabase. `lib/interpreter/` maps set logs to body-region
issues; only `SquatInterpreter` exists.

Voice (`lib/voice/`): `PolicyVoiceCoach` implements `ExerciseVoiceCoach`; `VoicePolicy`/`CueTuning`
decide cues; `AssetVoiceSink` plays bundled mp3s. Plank and Bow Pose override the coach.
Surya Namaskar (hidden) speaks free text through `AssetPhrasePlayer` (bundled mp3 only). The Viettel
TTS API client was removed on 2026-11-20.

App shell: `MainShell` = `IndexedStack` of Home, Plan, Library, Progress, Profile + `IvoryBottomNav`.
Entry flow (since 2026-11-16): `QuickStartNavigator` in `lib/screens/onboarding/quick_start/` (account,
goal + intensity, camera setup, first session). The old v5 onboarding screens were deleted on
2026-11-20; `v5_theme.dart` and `v5_primitives.dart` stay because the auth screens use them. Auth (`auth_service.dart`):
email + password, magic link, Google, Facebook, Apple; reviewer demo via 5 s hold on the Apple tile + `demo-session` edge function;
`delete-account` edge function. Supabase tables used by client code: workout_sessions,
exercise_sessions, profiles, user_pain_areas, user_exercise_capacity, recommendations_log,
fitness_retests, user_detected_issues, exercise_catalog, weekly_checkins, level_assessments,
fork_decisions, all created by `20261116_baseline.sql`. Recommendation engine
(`lib/services/recommendation/`): `kRecommendationAlgorithmVersion = 'v4.4.0'`; plan default per code
comment is 2 phases x 3 weeks + 1 deload. No state-management package. `lib/data/*_mock.dart` feeds
some tabs; `// TODO(wiring):` marks unfinished wiring.

## Design system

Two registers, do not mix: main app uses `VikaColors.of(context)` (`lib/theme/app_colors.dart`,
`lib/theme/tokens/`) and `VikaIvoryMain`; onboarding uses `V5.*` (`onboarding/v5/v5_theme.dart`).
`VFTheme` in `lib/theme/vf_theme.dart` is legacy, do not extend; `VikaIvory` in the same file styles
the active-exercise screen. One font: Be Vietnam Pro (`assets/fonts/be_vietnam_pro/`).

## Directory map

`lib/` 466 files, ~134k lines, every file reachable from `main.dart` (71 unreachable files were deleted
on 2026-11-20; 6 exercise files added 2026-11-22). `exercise/` 48.8k, `screens/` 35.8k, `widgets/` 20.7k, `services/` 12.1k, `data/` 3.4k,
`voice/` 3k, `models/` 2.5k, `utils/` 1.4k, `debug/` 1.4k, `theme/` 1.3k, `pose/` 0.5k,
`interpreter/` 0.3k. `test/` 108 files (`exercise/` 66, `services/` 23, plus pose, voice, screens,
widgets). Native: `android/app/src/main/kotlin/com/vikavn/app/`, `ios/Runner/`. Docs: `docs/README.md`
is the map (`state.md`, `canonical-numbers.md`, `decisions.md`, `reference/`, `agent-memory/`);
those docs were not re-verified, trust code over docs.

## Gaps found while reading

1. Plank metrics are unvalidated in code: "adjust after empirical testing", "verify with debug data
   that positive = sag" (`trunk_alignment_metric.dart`), "verify sign mapping" (`plank_metric_base.dart`).
   No accuracy measurement exists in the repo.
2. iOS tracking confidence 0.7 vs Android 0.5; MediaPipe versions differ.
3. `.fvm/version` = 3.38.9, `.fvm/fvm_config.json` and `docs/new-machine-setup.md` = 3.38.8.
4. `pubspec.yaml` comment says the `fonts:` block must be uncommented; it already is.
5. `ExerciseScreen` (`lib/main.dart:879`) has no call site.
6. `AGENTS.md` is a git symlink; on this Windows checkout it is a 9-byte text file reading `CLAUDE.md`.
7. `docs/README.md` still cites CLAUDE.md "Part 1 / Part 2" and rules this rewrite removed.

## Not verified

- Not read line by line: nearly all exercise implementations (only `exercise_base`, `presence_gate`,
  `plank` partly, `trunk_alignment_metric`, `rep_counted_hold_exercise` header), all of `widgets/`, most
  of `screens/`, `PolicyVoiceCoach`/`VoicePolicy` internals, `session_persistence` beyond its method
  list, recommendation internals, `lib/debug/`, mock data, Kotlin camera/orientation code, Swift
  services beyond config lines, and `docs/` (listed, `state.md` partly read).
- Not executed: analyze, tests, builds, device runs. No pass state or test count is claimed.
- Table list comes from grep of client code, not a live database.
