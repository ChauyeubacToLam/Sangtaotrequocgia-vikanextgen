import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:vika/screens/exercise/exercise_launch_args.dart';
import 'package:vika/services/analytics_service.dart';
import 'package:vika/services/auth_service.dart';
import 'package:vika/services/onboarding_persistence.dart';
import 'package:vika/services/recommendation/models/plan.dart';
import 'package:vika/services/recommendation/recommendation_service.dart';
import 'package:vika/services/session_persistence.dart';
import 'package:vika/services/workout_launch_service.dart';
import 'package:vika/utils/orientation_lock.dart';
import 'package:vika/widgets/tk/tk.dart';

import '../onboarding_data.dart';
import '../v5/v5_primitives.dart';
import '../v5/v5_theme.dart';
import 'quick_start_goal_screen.dart';
import 'quick_start_programs.dart';

/// Two-step path from app open to the first rep. Replaces the 17-screen
/// V5OnboardingNavigator at the app entry gate; that one stays in the repo
/// as a fallback and is not edited.
///
///   B1 account   email + password (create / sign in)
///   B2 goal      one screen: goal, program, age, intensity
///              then persist, generate plan and launch session 1
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

enum _Step { welcome, account, goal }

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
      _level ?? recommendedLevel(age: _age, goal: _goal ?? QuickGoal.muscle);

  bool _preparing = false;
  bool _launching = false;
  bool _persisted = false;
  bool _signalsWritten = false;
  List<ExerciseSequenceItem> _sequence = const [];

  @override
  void initState() {
    super.initState();
    unawaited(OrientationLock.portraitOnly());
    widget.onTakeOverAuth?.call();
    _step = Supabase.instance.client.auth.currentSession == null
        ? _Step.welcome
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

  Future<void> _start() async {
    if (_preparing || _launching) return;
    await _prepare();
    if (!mounted) return;
    if (_sequence.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Chưa tạo được buổi tập. Kiểm tra mạng rồi bấm lại nhé.'),
        ),
      );
      return;
    }
    await _launch();
  }

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
    if (!mounted) return;
    setState(() {
      _sequence = sequence;
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
      case _Step.welcome:
        return _WelcomeStep(onStart: () => _go(_Step.account));
      case _Step.account:
        return _AccountStep(
          onAuthenticated: _afterAuth,
          initialSignUp: true,
          onBack: () => _go(_Step.welcome),
        );
      case _Step.goal:
        return QuickStartGoalScreen(
          goal: _goal,
          program: _program,
          age: _age,
          level: _level,
          onGoal: _pickGoal,
          onProgram: (program) => setState(
              () => _program = program.id == _program?.id ? null : program),
          onAge: (age) => setState(() => _age = age),
          onLevel: (level) => setState(() => _level = level),
          busy: _preparing || _launching,
          onNext: _start,
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

// ═══════════════════════════════════════════════════════════════════
// B1 — account
// ═══════════════════════════════════════════════════════════════════

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    Widget dot(double size, Color color, {double radius = 99}) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(radius)),
        );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: Container(
        color: Tk.indigo,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: 360,
                    height: 360,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 290,
                          height: 290,
                          decoration: const BoxDecoration(
                              color: Tk.indigoHi, shape: BoxShape.circle),
                        ),
                        Positioned(
                            left: 40, top: 46, child: dot(22, Tk.orange)),
                        Positioned(
                            right: 48, top: 18, child: dot(14, Tk.green)),
                        Positioned(
                            right: 26,
                            bottom: 64,
                            child: Transform.rotate(
                                angle: 0.3,
                                child: dot(18, const Color(0xFF6E8BFF),
                                    radius: 5))),
                        Positioned(
                            left: 30,
                            bottom: 50,
                            child: dot(10, const Color(0xFFFFD23F))),
                        const TkMascot(
                            asset: Tk.mascotWave,
                            size: 330,
                            semanticLabel: 'Tắc Kè Vika vẫy tay chào'),
                      ],
                    ),
                  ),
                ),
              ),
              Text(
                'CHÀO MỪNG BẠN ĐẾN VỚI',
                style: Tk.text(14,
                    weight: FontWeight.w800,
                    color: Tk.onIndigoSoft,
                    letterSpacing: 2),
              ),
              const SizedBox(height: 6),
              Text('VIKA',
                  style: Tk.text(64,
                      weight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 4,
                      height: 1)),
              const SizedBox(height: 10),
              Text(
                'HLV AI ngay tại nhà',
                textAlign: TextAlign.center,
                style: Tk.text(20,
                    weight: FontWeight.w700,
                    color: Tk.onIndigoSoft,
                    height: 1.3),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    TkButton(
                        label: 'Bắt đầu ngay',
                        tone: TkButtonTone.white,
                        onTap: onStart),
                    const SizedBox(height: 10),
                    Text(
                      'Dành cho người từ 16 tuổi trở lên',
                      style: Tk.text(12,
                          weight: FontWeight.w700,
                          color: const Color(0xFFA9A4E0)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountStep extends StatefulWidget {
  const _AccountStep({
    required this.onAuthenticated,
    required this.initialSignUp,
    required this.onBack,
  });

  final Future<void> Function() onAuthenticated;
  final bool initialSignUp;
  final VoidCallback onBack;

  @override
  State<_AccountStep> createState() => _AccountStepState();
}

class _AccountStepState extends State<_AccountStep> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  late bool _signUp = widget.initialSignUp;
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
      background: Tk.surface,
      scrollPadding: const EdgeInsets.only(bottom: 24),
      footer: TkButton(
        label: _signUp ? 'Tiếp tục' : 'Đăng nhập',
        busy: _busy,
        onTap: _submit,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TkTopBar(
            onBack: _busy ? null : widget.onBack,
            progress: 1 / 2,
            trailing: '1/2',
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 20, 0),
            child: TkSpeechRow(
              asset: Tk.mascotPoint,
              mascotSize: 128,
              message: _signUp
                  ? 'Chào bạn! Tạo tài khoản để mình nhớ tiến bộ của bạn nhé.'
                  : 'Mừng bạn quay lại! Đăng nhập để tập tiếp nhé.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                Text(
                  _signUp ? 'Tạo tài khoản' : 'Đăng nhập',
                  style:
                      Tk.text(28, weight: FontWeight.w900, letterSpacing: -0.4),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hai bước là vào buổi tập đầu tiên.',
                  style:
                      Tk.text(16, weight: FontWeight.w700, color: Tk.inkSoft),
                ),
                const SizedBox(height: 18),
                TkSegmented(
                  labels: const ['Tạo tài khoản', 'Đăng nhập'],
                  selected: _signUp ? 0 : 1,
                  onChanged: _busy
                      ? null
                      : (i) => setState(() {
                            _signUp = i == 0;
                            _error = null;
                          }),
                ),
                const SizedBox(height: 18),
                AutofillGroup(
                  child: Column(
                    children: [
                      TkField(
                        label: 'EMAIL',
                        controller: _email,
                        hint: 'ban@email.com',
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                      ),
                      const SizedBox(height: 14),
                      TkField(
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
                        suffix: IconButton(
                          tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Tk.inkSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: Tk.text(14,
                          weight: FontWeight.w800, color: Tk.redInk)),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                      color: Tk.greenSoft,
                      borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lock_outline_rounded,
                          color: Tk.greenLip, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Bạn cần từ 16 tuổi trở lên. Hình ảnh camera chỉ được xử lý trên điện thoại, không gửi đi đâu.',
                          style: Tk.text(13,
                              weight: FontWeight.w700,
                              color: const Color(0xFF24442D),
                              height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
