import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:vika/models/exercise_definition.dart';
import 'package:vika/pose/vika_image_orientation.dart';
import 'package:vika/screens/exercise/exercise_launch_args.dart';
import 'package:vika/services/analytics_service.dart';
import 'package:vika/services/auth_service.dart';
import 'package:vika/services/onboarding_persistence.dart';
import 'package:vika/services/recommendation/models/plan.dart';
import 'package:vika/services/recommendation/recommendation_service.dart';
import 'package:vika/services/session_persistence.dart';
import 'package:vika/services/workout_launch_service.dart';
import 'package:vika/utils/orientation_lock.dart';

import '../onboarding_data.dart';
import '../v5/v5_primitives.dart';
import '../v5/v5_theme.dart';
import 'quick_start_goal_screen.dart';
import 'quick_start_programs.dart';

/// Three-step path from app open to the first rep. Replaces the 17-screen
/// V5OnboardingNavigator at the app entry gate; that one stays in the repo
/// as a fallback and is not edited.
///
///   B1 account   email + password (create / sign in)
///   B2 goal      one screen: goal, program, age, intensity
///   B3 train     persist, generate plan, camera placement, launch session 1
///
/// A signed-in user who reaches this widget (signed up but never finished)
/// starts at B2.
class QuickStartNavigator extends StatefulWidget {
  const QuickStartNavigator({super.key, this.onTakeOverAuth});

  /// Called once when this navigator mounts. The entry gate then ignores the
  /// auth stream (sign-in, metadata updates) so it cannot swap this flow out
  /// mid-way; this navigator owns every exit via `pushReplacementNamed('/')`.
  final VoidCallback? onTakeOverAuth;

  @override
  State<QuickStartNavigator> createState() => _QuickStartNavigatorState();
}

enum _Step { account, goal, setup }

// Defaults for the fields the old 17-screen flow collected. The plan engine
// reads fitness_level, fork, goals, training_duration and schedule_sessions
// from `profiles`; every one is set in [_fillDefaults].
const _defaultScheduleSessions = [
  'T2_afternoon',
  'T4_afternoon',
  'T6_afternoon',
];

const _trainingDurationForLevel = {
  'beginner': '<3m',
  'intermediate': '3-11m',
  'advanced': '1y+',
};

/// The first session uses the chosen level's set count; reps and seconds
/// stay at the catalog base.
ExerciseSequenceItem _withSets(ExerciseSequenceItem item, int sets) {
  final volume = item.prescription;
  if (volume == null) return item;
  return ExerciseSequenceItem(
    definition: item.definition,
    catalogExerciseId: item.catalogExerciseId,
    catalogInfo: item.catalogInfo,
    prescription: VolumePrescription(
      sets: sets,
      restSeconds: volume.restSeconds,
      reps: volume.reps,
      seconds: volume.seconds,
    ),
  );
}

class _QuickStartNavigatorState extends State<QuickStartNavigator> {
  final OnboardingData _data = OnboardingData();
  late _Step _step;
  QuickGoal? _goal;
  QuickProgram? _program;
  int _age = quickDefaultAge;

  /// The user's own pick; null follows the age and goal recommendation.
  String? _level;

  String get _effectiveLevel =>
      _level ??
      recommendedLevel(age: _age, goal: _goal ?? QuickGoal.muscle);

  // B3 state.
  bool _preparing = false;
  bool _launching = false;
  bool _persisted = false;
  bool _signalsWritten = false;
  bool _landscape = false;
  List<ExerciseSequenceItem> _sequence = const [];

  @override
  void initState() {
    super.initState();
    unawaited(OrientationLock.portraitOnly());
    widget.onTakeOverAuth?.call();
    _step = Supabase.instance.client.auth.currentSession == null
        ? _Step.account
        : _Step.goal;
  }

  void _go(_Step step) => setState(() => _step = step);

  // ─── B1 ────────────────────────────────────────────────────────────

  /// After a successful sign-in/up: a returning user who already finished
  /// goes to MainShell; everyone else continues to B2.
  Future<void> _afterAuth() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    var complete = false;
    if (uid != null) {
      try {
        final row = await client
            .from('profiles')
            .select('onboarding_complete')
            .eq('id', uid)
            .maybeSingle();
        complete = row?['onboarding_complete'] == true;
      } catch (_) {
        // Offline or no row: treat as not finished; B2 is short.
      }
    }
    if (complete) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        '/',
        arguments: const {'onboardingComplete': true},
      );
      return;
    }
    if (mounted) _go(_Step.goal);
  }

  // ─── B2 ────────────────────────────────────────────────────────────

  void _pickGoal(QuickGoal goal) {
    if (goal == _goal) return;
    setState(() {
      _goal = goal;
      _program = null;
    });
  }

  void _startSetup() {
    _go(_Step.setup);
    unawaited(_prepare());
  }

  // ─── B3 ────────────────────────────────────────────────────────────

  void _fillDefaults() {
    final level = _effectiveLevel;
    _data
      // Yoga is hidden for this release, so every goal plans from 'home'.
      ..fork = 'home'
      ..goal = switch (_goal ?? QuickGoal.muscle) {
        QuickGoal.pain => 'flexible',
        QuickGoal.muscle => 'body',
        QuickGoal.famous => 'health',
      }
      ..level = level
      ..trainingDuration = _trainingDurationForLevel[level]
      ..scheduleSessions = List.of(_defaultScheduleSessions)
      ..age = _age
      ..email = Supabase.instance.client.auth.currentUser?.email
      // ponytail: no pain region is collected, so the plan engine gets no
      // pain signal. Ask for the region once the catalog's pain fields have
      // been reviewed.
      ..noPain = true
      ..painAreas.clear()
      ..painIntensities.clear();
  }

  Future<void> _prepare() async {
    final program = _program;
    if (_preparing || program == null) return;
    setState(() => _preparing = true);
    _fillDefaults();

    // markComplete (the default) here, not after the workout: a user who
    // closes the app mid-session lands on MainShell next time.
    // writeSignals once, so going back and forth does not double-count pain.
    _persisted = await OnboardingPersistence().persist(
      _data,
      writeSignals: !_signalsWritten,
    );
    if (_persisted) _signalsWritten = true;
    await _saveChoices();

    // An empty sequence shows the retry screen, so a failed call must not
    // leave the spinner up.
    var sequence = const <ExerciseSequenceItem>[];
    try {
      if (_persisted) {
        // The plan the Home tab shows after this first session.
        await RecommendationService()
            .ensurePlanForCurrentUser(trigger: 'onboarding');
      }
      final sets = setsForLevel(_effectiveLevel);
      sequence = [
        for (final item in await WorkoutLaunchService()
            .buildSequenceFromCatalogIds(program.exerciseIds))
          _withSets(item, sets),
      ];
    } catch (e) {
      debugPrint('[QuickStart] could not build the first session: $e');
    }
    final landscape = sequence.isEmpty
        ? false
        : await _needsLandscape(sequence.first.definition);

    if (!mounted) return;
    setState(() {
      _sequence = sequence;
      _landscape = landscape;
      _preparing = false;
    });
  }

  /// The chosen program (the engine has no input for it) plus the local
  /// mirrors the old flow wrote. The program also goes to the auth user's
  /// metadata, so it survives a reinstall without a schema change.
  Future<void> _saveChoices() async {
    final prefs = await SharedPreferences.getInstance();
    if (_persisted) await prefs.setBool('onboarding_complete', true);
    await prefs.setString('user_goal', _data.goal ?? '');
    await prefs.setString('user_level', _data.level ?? 'beginner');
    await prefs.setString('user_fork', _data.fork ?? 'home');
    await prefs.setStringList(
      'user_schedule_sessions',
      _data.scheduleSessions,
    );
    await prefs.setBool('no_pain', _data.noPain);
    await prefs.setInt('user_age', _age);
    await prefs.setString('quick_start_program_id', _program?.id ?? '');
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {
          'quick_start_goal': _goal?.name,
          'quick_start_program_id': _program?.id,
        }),
      );
    } catch (e) {
      debugPrint('[QuickStart] user metadata write failed: $e');
    }
  }

  /// Same launch as the Home hero (`dashboard_home_screen.dart`). A quick
  /// start program is an ad-hoc sequence, so it runs standalone with no
  /// workout_sessions row. Any exit, summary or back-out, lands on MainShell.
  Future<void> _launch() async {
    if (_launching || _sequence.isEmpty) return;
    setState(() => _launching = true);
    HapticFeedback.lightImpact();
    unawaited(AnalyticsService.instance.capture('onboarding_completed'));

    final first = _sequence.first;
    String? workoutSessionId;
    if (first.recommendationId != null) {
      workoutSessionId = await SessionPersistence().startWorkoutSession(
        recommendationId: first.recommendationId!,
        weekNumber: first.weekNumber!,
        sessionIndex: first.sessionIndex!,
      );
    }

    ExerciseLaunchArgs? next = ExerciseLaunchArgs(
      definition: first.definition,
      catalogExerciseId: first.catalogExerciseId,
      catalogInfo: first.catalogInfo,
      prescription: first.prescription,
      recommendationId: first.recommendationId,
      weekNumber: first.weekNumber,
      sessionIndex: first.sessionIndex,
      slotName: first.slotName,
      sequence: _sequence,
      workoutSessionId: workoutSessionId,
    );
    while (next != null) {
      if (!mounted) return;
      final result =
          await Navigator.of(context).pushNamed('/exercise', arguments: next);
      next = result is Map && result['next'] is ExerciseLaunchArgs
          ? result['next'] as ExerciseLaunchArgs
          : null;
    }
    if (!mounted) return;
    // Not persisted: let the gate re-resolve; it resumes this flow at B2.
    Navigator.of(context).pushReplacementNamed(
      '/',
      arguments: _persisted
          ? const {'onboardingComplete': true}
          : const {'entryState': 'loading'},
    );
  }

  // ─── build ─────────────────────────────────────────────────────────

  Widget _buildStep() {
    switch (_step) {
      case _Step.account:
        return _AccountStep(onAuthenticated: _afterAuth);
      case _Step.goal:
        return QuickStartGoalScreen(
          goal: _goal,
          program: _program,
          age: _age,
          level: _level,
          onGoal: _pickGoal,
          onProgram: (program) => setState(() => _program = program),
          onAge: (age) => setState(() => _age = age),
          onLevel: (level) => setState(() => _level = level),
          onNext: _startSetup,
        );
      case _Step.setup:
        return _SetupStep(
          preparing: _preparing,
          launching: _launching,
          sequence: _sequence,
          landscape: _landscape,
          planSaved: _persisted,
          onStart: _launch,
          onRetry: _prepare,
          onBack: _preparing || _launching ? null : () => _go(_Step.goal),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: V5.clampedTextScaler(context)),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: V5.bg,
          // B1 owns its keyboard resize via V5KeyboardForm; the outer
          // Scaffold must not resize too (same rule as the v5 navigator).
          resizeToAvoidBottomInset: false,
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: KeyedSubtree(
              key: ValueKey('$_step-$_goal'),
              child: _buildStep(),
            ),
          ),
        ),
      ),
    );
  }
}

/// The exercise class owns its supported orientations; build one, read it,
/// and release its detector straight away (the experience screen builds its
/// own instance when the session starts).
Future<bool> _needsLandscape(ExerciseDefinition definition) async {
  try {
    final exercise = definition.createExercise(reps: 1, seconds: 1);
    final landscape = !exercise.supportedOrientations
        .contains(VikaImageOrientation.portrait);
    await exercise.disposeDetectors();
    return landscape;
  } catch (_) {
    return false;
  }
}

// ═══════════════════════════════════════════════════════════════════
// B1 — account
// ═══════════════════════════════════════════════════════════════════

class _AccountStep extends StatefulWidget {
  const _AccountStep({required this.onAuthenticated});

  final Future<void> Function() onAuthenticated;

  @override
  State<_AccountStep> createState() => _AccountStepState();
}

class _AccountStepState extends State<_AccountStep> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = true;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validate() {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Email chưa đúng định dạng.';
    }
    if (_password.text.length < 6) return 'Mật khẩu cần ít nhất 6 ký tự.';
    return null;
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final invalid = _validate();
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = AuthService();
      if (_signUp) {
        await auth.signUpWithPassword(
          email: _email.text,
          password: _password.text,
        );
      } else {
        await auth.signInWithPassword(
          email: _email.text,
          password: _password.text,
        );
      }
      await widget.onAuthenticated();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return V5KeyboardForm(
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PrimaryButton(
            label: _signUp ? 'Tạo tài khoản' : 'Đăng nhập',
            busy: _busy,
            onTap: _submit,
          ),
          const SizedBox(height: V5.space10),
          Text(
            'Bạn cần từ 16 tuổi trở lên. Hình ảnh camera chỉ được xử lý '
            'trên điện thoại, không gửi đi đâu.',
            textAlign: TextAlign.center,
            style: V5.bodyXs(context, color: V5.inkSoft),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: V5.space24),
          V5ScreenHeader(
            eyebrow: 'Bước 1/3',
            title: _signUp
                ? 'Tạo tài khoản\nđể bắt đầu tập'
                : 'Chào mừng\nbạn quay lại',
            subtitle: 'Ba bước là vào buổi tập đầu tiên.',
          ),
          const SizedBox(height: V5.space24),
          _ModeToggle(
            signUp: _signUp,
            onChanged: _busy
                ? null
                : (v) => setState(() {
                      _signUp = v;
                      _error = null;
                    }),
          ),
          const SizedBox(height: V5.space16),
          AutofillGroup(
            child: Column(
              children: [
                _Field(
                  label: 'EMAIL',
                  controller: _email,
                  hint: 'ban@email.com',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                ),
                const SizedBox(height: V5.space12),
                _Field(
                  label: 'MẬT KHẨU',
                  controller: _password,
                  hint: 'Ít nhất 6 ký tự',
                  obscure: _obscure,
                  autofillHints: [
                    _signUp
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  onSubmitted: (_) => _submit(),
                  suffix: GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: V5.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: V5.space12),
            Text(_error!, style: V5.bodySm(context, color: V5.danger)),
          ],
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.signUp, required this.onChanged});

  final bool signUp;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool value) {
      final active = signUp == value;
      return Expanded(
        child: GestureDetector(
          onTap: onChanged == null ? null : () => onChanged!(value),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? V5.ink : Colors.transparent,
              borderRadius: BorderRadius.circular(V5.radiusFull),
            ),
            child: Text(
              label,
              style: V5.text(
                context,
                size: 13.5,
                weight: FontWeight.w700,
                color: active ? V5.invInk : V5.inkSoft,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: V5.surface,
        border: Border.all(color: V5.border),
        borderRadius: BorderRadius.circular(V5.radiusFull),
      ),
      child: Row(
        children: [tab('Tạo tài khoản', true), tab('Đăng nhập', false)],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.obscure = false,
    this.suffix,
    this.autofillHints,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final style = V5.text(
      context,
      size: 15,
      weight: FontWeight.w600,
      color: V5.ink,
      letterSpacing: -0.1,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: V5.surface,
        border: Border.all(color: V5.border),
        borderRadius: BorderRadius.circular(V5.radiusMd),
        boxShadow: V5.elevation1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: V5.eyebrow(context, color: V5.inkFaint)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  obscureText: obscure,
                  autocorrect: false,
                  enableSuggestions: !obscure,
                  autofillHints: autofillHints,
                  onSubmitted: onSubmitted,
                  cursorColor: V5.yellow,
                  style: style,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: hint,
                    hintStyle: style.copyWith(color: V5.inkFaint),
                  ),
                ),
              ),
              if (suffix != null) suffix!,
            ],
          ),
        ],
      ),
    );
  }
}

/// Non-positioned pill button for the form footer. [V5PillCTA] is a
/// `Positioned` and only works inside a V5Screen stack.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: V5.ink,
          borderRadius: BorderRadius.circular(V5.radiusFull),
          boxShadow: V5.elevation1,
        ),
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: V5.yellow,
                ),
              )
            : Text(
                label,
                style: V5.text(
                  context,
                  size: 15,
                  weight: FontWeight.w700,
                  color: V5.invInk,
                ),
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// B3 — camera setup, then launch
// ═══════════════════════════════════════════════════════════════════

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.preparing,
    required this.launching,
    required this.sequence,
    required this.landscape,
    required this.planSaved,
    required this.onStart,
    required this.onRetry,
    required this.onBack,
  });

  final bool preparing;
  final bool launching;
  final List<ExerciseSequenceItem> sequence;
  final bool landscape;
  final bool planSaved;
  final VoidCallback onStart;
  final VoidCallback onRetry;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    if (preparing) {
      return V5Page(
        index: 3,
        total: 3,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: V5.yellow),
              const SizedBox(height: V5.space16),
              Text(
                'Đang chuẩn bị buổi tập đầu tiên…',
                style: V5.body(context, color: V5.inkSoft),
              ),
            ],
          ),
        ),
      );
    }
    if (sequence.isEmpty) {
      return V5Page(
        index: 3,
        total: 3,
        onBack: onBack,
        cta: V5PillCTA(label: 'Thử lại', onTap: onRetry),
        child: const V5ScreenHeader(
          eyebrow: 'Bước 3/3',
          title: 'Chưa tạo được\nbuổi tập',
          subtitle: 'Vui lòng kiểm tra kết nối mạng rồi thử lại.',
        ),
      );
    }

    final definition = sequence.first.definition;
    final tips = <(IconData, String)>[
      if (landscape)
        (
          Icons.screen_rotation_rounded,
          'Xoay ngang điện thoại. Bài này cần đặt máy nằm ngang.',
        ),
      for (final tip in definition.setupTips)
        (Icons.check_circle_outline_rounded, tip),
      (Icons.videocam_outlined, definition.cameraHint),
      (Icons.crop_free_rounded, definition.framingHint),
    ];

    return V5Page(
      index: 3,
      total: 3,
      onBack: onBack,
      scroll: true,
      cta: V5PillCTA(
        label: launching ? 'Đang mở camera…' : 'Bắt đầu tập',
        yellow: true,
        enabled: !launching,
        onTap: onStart,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V5ScreenHeader(
            eyebrow: 'Bước 3/3',
            title: 'Đặt máy cho bài\n${definition.displayName}',
            subtitle: 'Buổi đầu có ${sequence.length} bài: '
                '${sequence.map((s) => s.definition.displayName).join(', ')}.',
            size: V5HeaderSize.medium,
          ),
          const SizedBox(height: V5.space20),
          for (final (icon, text) in tips)
            if (text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: V5.space12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 20, color: V5.yellowDeep),
                    const SizedBox(width: V5.space12),
                    Expanded(
                      child: Text(
                        text,
                        style: V5.body(context, color: V5.ink),
                      ),
                    ),
                  ],
                ),
              ),
          if (!planSaved) ...[
            const SizedBox(height: V5.space8),
            Text(
              'Chưa lưu được hồ sơ (có thể do mất mạng). Bạn vẫn tập '
              'được buổi này; lần mở sau Vika sẽ hỏi lại mục tiêu.',
              style: V5.bodySm(context, color: V5.inkSoft),
            ),
          ],
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}
