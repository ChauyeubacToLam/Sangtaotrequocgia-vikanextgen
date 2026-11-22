import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/exercise_definition.dart';
import '../models/exercise_lookup.dart';
import '../models/kept_exercises.dart';
import '../services/recommendation/fitness_retest_service.dart';
import '../services/recommendation/models/plan.dart';
import '../services/recommendation/progression_service.dart';
import '../services/recommendation/recommendation_service.dart';
import '../services/recommendation/weekly_check_in_service.dart';
import '../services/research/research_preferences.dart';
import '../utils/exercise_logger.dart';
import '../widgets/tk/tk.dart';
import 'exercise/exercise_launch_args.dart';
import 'weekly_check_in_screen.dart';

class PlanRetestLaunchArgs {
  const PlanRetestLaunchArgs({required this.pending});

  final PendingFitnessRetest pending;
}

class PlanRetestScreen extends StatefulWidget {
  const PlanRetestScreen({
    super.key,
    required this.args,
  });

  final PlanRetestLaunchArgs args;

  @override
  State<PlanRetestScreen> createState() => _PlanRetestScreenState();
}

class _PlanRetestScreenState extends State<PlanRetestScreen> {
  final _retest = FitnessRetestService();
  final _recommendations = RecommendationService();
  final _checkIns = WeeklyCheckInService();
  final _progression = RecommendationProgressionService();

  _RetestStep _step = _RetestStep.intro;
  SubmittedFitnessRetest? _submitted;
  Plan? _newPlan;
  String? _error;
  bool _busy = false;

  Future<void> _startRetest() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final squat = await _runAssessment(squatAssessmentDefinition);
    if (!mounted || squat == null) {
      setState(() => _busy = false);
      return;
    }

    final wallPushup = await _runAssessment(wallPushupAssessmentDefinition);
    if (!mounted || wallPushup == null) {
      setState(() => _busy = false);
      return;
    }

    await _maybeOpenWeekSevenCheckIn();

    final submitted = await _retest.submitRetest(
      recommendationId: widget.args.pending.recommendationId,
      result: FitnessRetestResult(
        squatLogger: squat,
        wallPushupLogger: wallPushup,
      ),
    );
    if (!mounted) return;

    if (submitted == null) {
      setState(() {
        _busy = false;
        _error = 'Chưa lưu được kết quả. Bạn thử lại nhé.';
      });
      return;
    }

    setState(() {
      _submitted = submitted;
      _step = _RetestStep.result;
      _busy = false;
    });
  }

  Future<ExerciseLogger?> _runAssessment(ExerciseDefinition definition) async {
    final result = await Navigator.of(context).pushNamed(
      '/exercise',
      arguments: definition,
    );
    if (result is Map && result['logger'] is ExerciseLogger) {
      return result['logger'] as ExerciseLogger;
    }
    return null;
  }

  Future<void> _maybeOpenWeekSevenCheckIn() async {
    final due = await _checkIns.isDue(
      recommendationId: widget.args.pending.recommendationId,
      weekNumber: widget.args.pending.weekNumber,
    );
    if (!mounted || !due) return;
    await Navigator.of(context).pushNamed(
      '/weekly-check-in',
      arguments: WeeklyCheckInLaunchArgs(
        recommendationId: widget.args.pending.recommendationId,
        weekNumber: widget.args.pending.weekNumber,
      ),
    );
  }

  Future<void> _acceptSuggestedLevel() async {
    final submitted = _submitted;
    if (submitted == null) return;
    setState(() => _busy = true);
    final ok = await _retest.confirmSuggestedLevel(
      retestId: submitted.retestId,
      suggestedLevel: submitted.suggestion.suggestedLevel,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _error = 'Chưa cập nhật được level. Bạn thử lại nhé.';
      });
      return;
    }
    await _generateNewPlan();
  }

  Future<void> _declineSuggestedLevel() async {
    final submitted = _submitted;
    if (submitted == null) return;
    setState(() => _busy = true);
    await _retest.declineSuggestedLevel(submitted.retestId);
    if (!mounted) return;
    await _generateNewPlan();
  }

  Future<void> _continueWithSameLevel() async {
    setState(() => _busy = true);
    await _generateNewPlan();
  }

  Future<void> _generateNewPlan() async {
    final result = await _recommendations.generatePlanForCurrentUser(
      trigger: 'reassessment',
    );
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _busy = false;
        _error = 'Chưa tạo được kế hoạch mới. Bạn thử lại nhé.';
      });
      return;
    }

    _newPlan = result.plan;
    await _showUnlocksIfAny(result.plan.recommendationId);
    if (!mounted) return;
    setState(() {
      _step = _RetestStep.finalChoice;
      _busy = false;
    });
  }

  Future<void> _showUnlocksIfAny(String recommendationId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final notices = await _progression.fetchPendingUnlockNotices(
      userId,
      recommendationId: recommendationId,
    );
    if (!mounted || notices.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (_) => _VariantUnlockDialog(notices: notices),
    );
    await _progression.markUnlockNoticesApplied(
      userId: userId,
      recommendationId: recommendationId,
      notices: notices,
    );
  }

  void _startFirstSessionToday() {
    final launchArgs = resolveRetestFirstSessionLaunchArgs(_newPlan);
    if (launchArgs == null) {
      Navigator.of(context).pop(true);
      return;
    }

    Navigator.of(context).pushReplacementNamed(
      '/exercise',
      arguments: launchArgs,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showMascot = !ResearchPreferences.cachedConfig.isControl;
    return Scaffold(
      backgroundColor: Tk.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TkTopBar(
              onBack: _step == _RetestStep.intro && !_busy
                  ? () => Navigator.of(context).maybePop()
                  : null,
              closeIcon: true,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: switch (_step) {
                  _RetestStep.intro => _RetestIntro(
                      key: const ValueKey('intro'),
                      showMascot: showMascot,
                      busy: _busy,
                      error: _error,
                      onStart: _startRetest,
                      onLater: () => Navigator.of(context).maybePop(),
                    ),
                  _RetestStep.result => _RetestResultView(
                      key: const ValueKey('result'),
                      showMascot: showMascot,
                      submitted: _submitted!,
                      busy: _busy,
                      error: _error,
                      onAccept: _acceptSuggestedLevel,
                      onDecline: _declineSuggestedLevel,
                      onContinue: _continueWithSameLevel,
                    ),
                  _RetestStep.finalChoice => _NewPlanReadyView(
                      key: const ValueKey('final'),
                      showMascot: showMascot,
                      onStartToday: _startFirstSessionToday,
                      onTomorrow: () => Navigator.of(context).pop(true),
                    ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pane extends StatelessWidget {
  const _Pane({required this.content, required this.actions});

  final List<Widget> content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: content,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: actions,
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.showMascot,
    required this.asset,
    required this.icon,
    required this.soft,
    required this.strong,
  });

  final bool showMascot;
  final String asset;
  final IconData icon;
  final Color soft;
  final Color strong;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: showMascot ? 220 : 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: showMascot ? 196 : 104,
            height: showMascot ? 196 : 104,
            decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
          ),
          if (showMascot)
            TkMascot(asset: asset, size: 216)
          else
            Icon(icon, size: 52, color: strong),
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({
    required this.eyebrow,
    required this.eyebrowColor,
    required this.title,
    required this.body,
  });

  final String eyebrow;
  final Color eyebrowColor;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        children: [
          Text(eyebrow,
              textAlign: TextAlign.center,
              style: Tk.text(13,
                  weight: FontWeight.w900,
                  color: eyebrowColor,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(title,
              textAlign: TextAlign.center,
              style: Tk.text(28,
                  weight: FontWeight.w900, height: 1.15, letterSpacing: -0.4)),
          const SizedBox(height: 8),
          Text(body,
              textAlign: TextAlign.center,
              style: Tk.text(16,
                  weight: FontWeight.w700, color: Tk.inkSoft, height: 1.45)),
        ],
      ),
    );
  }
}

class _RetestIntro extends StatelessWidget {
  const _RetestIntro({
    super.key,
    required this.showMascot,
    required this.busy,
    required this.error,
    required this.onStart,
    required this.onLater,
  });

  final bool showMascot;
  final bool busy;
  final String? error;
  final VoidCallback onStart;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    const rows = [
      (Icons.schedule_rounded, Tk.primarySoft, Tk.primary,
          'Khoảng 5 phút, vài bài quen thuộc'),
      (Icons.videocam_rounded, Tk.greenSoft, Tk.greenInk,
          'AI đếm rep như buổi tập thường'),
      (Icons.trending_up_rounded, Tk.orangeSoft, Tk.orangeLip,
          'Kết quả quyết định level kế tiếp'),
    ];
    return _Pane(
      content: [
        _Hero(
          showMascot: showMascot,
          asset: Tk.mascotTrophy,
          icon: Icons.emoji_events_rounded,
          soft: Tk.orangeSoft,
          strong: Tk.orangeLip,
        ),
        const _Headline(
          eyebrow: 'HOÀN THÀNH 7 TUẦN',
          eyebrowColor: Tk.orangeInk,
          title: 'Bạn đã đi hết kế hoạch này!',
          body:
              'Kiểm tra nhanh vài phút để Vika tạo lộ trình tiếp theo vừa sức hơn.',
        ),
        const SizedBox(height: 20),
        TkCard(
          lip: false,
          radius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: i == rows.length - 1
                        ? null
                        : const Border(
                            bottom: BorderSide(color: Tk.lineSoft, width: 2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                            color: rows[i].$2,
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(rows[i].$1, size: 18, color: rows[i].$3),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(rows[i].$4,
                            style: Tk.text(15, weight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 14),
          _ErrorText(error!),
        ],
      ],
      actions: [
        TkButton(
          label: 'Bắt đầu kiểm tra',
          tone: TkButtonTone.orange,
          busy: busy,
          onTap: busy ? null : onStart,
        ),
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: busy ? null : onLater,
            child: Text('Để sau',
                style:
                    Tk.text(15, weight: FontWeight.w900, color: Tk.primary)),
          ),
        ),
      ],
    );
  }
}

class _RetestResultView extends StatelessWidget {
  const _RetestResultView({
    super.key,
    required this.showMascot,
    required this.submitted,
    required this.busy,
    required this.error,
    required this.onAccept,
    required this.onDecline,
    required this.onContinue,
  });

  final bool showMascot;
  final SubmittedFitnessRetest submitted;
  final bool busy;
  final String? error;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final changed = submitted.suggestion.shouldPromptUser;
    final message = changed
        ? 'Vika thấy bạn đã sẵn sàng đổi level. Bạn vẫn là người quyết định.'
        : 'Bạn đang đúng level. Kế hoạch mới sẽ theo nhịp hiện tại.';
    return _Pane(
      content: [
        const SizedBox(height: 4),
        Text('KẾT QUẢ', style: Tk.eyebrow()),
        const SizedBox(height: 6),
        Text('Level của bạn',
            style: Tk.text(28, weight: FontWeight.w900, letterSpacing: -0.4)),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _LevelColumn(
              label: 'HIỆN TẠI',
              level: submitted.suggestion.previousLevel,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward_rounded,
                  color: Tk.inkMuted, size: 26),
            ),
            _LevelColumn(
              label: changed ? 'GỢI Ý MỚI' : 'GIỮ NGUYÊN',
              level: submitted.suggestion.suggestedLevel,
              highlighted: true,
            ),
          ],
        ),
        const SizedBox(height: 22),
        if (showMascot)
          TkSpeechRow(asset: Tk.mascotThink, message: message, mascotSize: 108)
        else
          Text(message,
              style: Tk.text(16,
                  weight: FontWeight.w700, color: Tk.ink, height: 1.45)),
        if (error != null) ...[
          const SizedBox(height: 14),
          _ErrorText(error!),
        ],
      ],
      actions: changed
          ? [
              TkButton(
                label: 'Đồng ý đổi level',
                tone: TkButtonTone.green,
                busy: busy,
                onTap: busy ? null : onAccept,
              ),
              const SizedBox(height: 12),
              TkButton(
                label: 'Giữ level cũ',
                tone: TkButtonTone.outline,
                onTap: busy ? null : onDecline,
              ),
            ]
          : [
              TkButton(
                label: 'Tạo kế hoạch mới',
                tone: TkButtonTone.green,
                busy: busy,
                onTap: busy ? null : onContinue,
              ),
            ],
    );
  }
}

class _NewPlanReadyView extends StatelessWidget {
  const _NewPlanReadyView({
    super.key,
    required this.showMascot,
    required this.onStartToday,
    required this.onTomorrow,
  });

  final bool showMascot;
  final VoidCallback onStartToday;
  final VoidCallback onTomorrow;

  @override
  Widget build(BuildContext context) {
    return _Pane(
      content: [
        const SizedBox(height: 12),
        _Hero(
          showMascot: showMascot,
          asset: Tk.mascotCheer,
          icon: Icons.check_rounded,
          soft: Tk.greenSoft,
          strong: Tk.greenInk,
        ),
        const _Headline(
          eyebrow: 'LỘ TRÌNH MỚI',
          eyebrowColor: Tk.greenInk,
          title: 'Kế hoạch mới đã sẵn sàng!',
          body:
              'Bạn có thể tập buổi đầu hôm nay, hoặc để cơ thể nghỉ và bắt đầu vào ngày mai.',
        ),
      ],
      actions: [
        TkButton(
          label: 'Có, tập luôn',
          tone: TkButtonTone.green,
          icon: Icons.play_arrow_rounded,
          onTap: onStartToday,
        ),
        const SizedBox(height: 12),
        TkButton(
          label: 'Để mai',
          tone: TkButtonTone.outline,
          onTap: onTomorrow,
        ),
      ],
    );
  }
}

class _VariantUnlockDialog extends StatelessWidget {
  const _VariantUnlockDialog({required this.notices});

  final List<VariantUnlockNotice> notices;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Tk.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('MỞ KHÓA BÀI MỚI', style: Tk.eyebrow()),
            const SizedBox(height: 6),
            Text(
              'Bạn đã sẵn sàng cho bài khó hơn.',
              style: Tk.text(22,
                  weight: FontWeight.w900, height: 1.25, letterSpacing: -0.3),
            ),
            const SizedBox(height: 14),
            for (final notice in notices)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(Icons.lock_open_rounded,
                        size: 20, color: Tk.greenInk),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${notice.unlockedExerciseName} thay cho ${notice.exerciseName}',
                        style: Tk.text(15,
                            weight: FontWeight.w800, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            TkButton(
              label: 'Xem kế hoạch mới',
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelColumn extends StatelessWidget {
  const _LevelColumn({
    required this.label,
    required this.level,
    this.highlighted = false,
  });

  final String label;
  final String level;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TkCard(
        lip: highlighted,
        radius: 18,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        color: highlighted ? Tk.primarySoft : Tk.surface,
        borderColor: highlighted ? Tk.primary : Tk.line,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: Tk.text(12,
                    weight: FontWeight.w900,
                    color: highlighted ? Tk.primary : Tk.inkSoft,
                    letterSpacing: 1)),
            const SizedBox(height: 6),
            Text(
              _levelLabel(level),
              style: Tk.text(22,
                  weight: FontWeight.w900,
                  color: highlighted ? Tk.primaryLip : Tk.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: Tk.text(14, weight: FontWeight.w800, color: Tk.redInk),
    );
  }
}

enum _RetestStep { intro, result, finalChoice }

@visibleForTesting
ExerciseLaunchArgs? resolveRetestFirstSessionLaunchArgs(Plan? plan) {
  final firstWeek =
      plan == null || plan.weeks.isEmpty ? null : plan.weeks.first;
  final firstSession = firstWeek == null || firstWeek.sessions.isEmpty
      ? null
      : firstWeek.sessions.first;
  final firstSlot = firstSession?.slots
      .where((slot) => isKeptExercise(slot.exerciseId))
      .firstOrNull;
  if (plan == null || firstWeek == null || firstSlot == null) {
    return null;
  }

  final definition = lookupExerciseDefinition(firstSlot.exerciseId);
  if (definition == null) {
    return null;
  }

  return ExerciseLaunchArgs(
    definition: definition,
    catalogExerciseId: firstSlot.exerciseId,
    prescription: firstSlot.volume,
    recommendationId: plan.recommendationId,
    weekNumber: firstWeek.weekNumber,
    slotName: firstSlot.slotName,
  );
}

String _levelLabel(String level) {
  return switch (level) {
    'advanced' => 'Nâng cao',
    'intermediate' => 'Trung cấp',
    _ => 'Cơ bản',
  };
}
