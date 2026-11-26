import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/workout_session_report.dart';
import '../../services/session_coach_builder.dart';
import '../../services/session_summary_builder.dart';
import '../../services/session_trophy_picker.dart';
import '../../nutrition/nutrition_store.dart';
import '../../services/workout_reminders.dart';
import '../../widgets/exercise/previous_exercise_rating_dialog.dart';
import '../../widgets/tk/tk.dart';
import '../nutrition/post_workout_card.dart';
import 'widgets/sensor_rotated_box.dart';

final workoutFinished = ValueNotifier<int>(0);

class WorkoutSummaryScreen extends StatefulWidget {
  const WorkoutSummaryScreen({
    super.key,
    required this.reports,
    required this.sessionSummary,
    required this.totalDuration,
    required this.totalCalories,
    required this.onDone,
    required this.trophy,
    required this.coach,
    this.onShare,
    this.onShareToZalo,
    this.onLastExerciseDifficulty,
    this.onSessionRpe,
    this.controlCondition = false,
    this.onExportSessionLogs,
  });

  final List<ExerciseSessionReport> reports;
  final SessionSummary sessionSummary;
  final Duration totalDuration;
  final int totalCalories;
  final VoidCallback onDone;
  final VoidCallback? onShare;
  final VoidCallback? onShareToZalo;
  final ValueChanged<String>? onLastExerciseDifficulty;
  final Trophy trophy;
  final SessionCoach coach;
  final bool controlCondition;
  final Future<bool> Function(BuildContext)? onExportSessionLogs;
  final ValueChanged<String>? onSessionRpe;

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen> {
  bool _activityLogged = false;

  @override
  void dispose() {
    Future.microtask(() => workoutFinished.value++);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    WorkoutReminders.markTrainedToday();
    _logActivity();
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptLastExercise());
  }

  Future<void> _logActivity() async {
    try {
      final now = DateTime.now();
      final minutes = widget.totalDuration.inMinutes;
      final label =
          '${now.hour}:${now.minute.toString().padLeft(2, '0')} · ${widget.reports.length} bài · $minutes phút · ${widget.totalCalories} kcal';
      await NutritionStore.instance.update(now, (l) {
        l.burnedKcal += widget.totalCalories;
        l.activities.add(label);
      });
    } catch (_) {}
    if (mounted) setState(() => _activityLogged = true);
  }

  Future<void> _promptLastExercise() async {
    if (!mounted) return;
    final reports = widget.reports;
    if (reports.isEmpty || reports.last.userDifficulty != null) return;
    final last = reports.last;
    final difficulty = await showPreviousExerciseRatingDialog(
      context,
      exerciseName: last.exerciseName,
      formScore: widget.controlCondition ? null : last.formScore,
      issueQuestion: widget.controlCondition ? null : last.report.issueQuestion,
    );
    if (!mounted) return;
    last.userDifficulty = difficulty;
    widget.onLastExerciseDifficulty?.call(difficulty);
  }

  int get _totalSets =>
      widget.reports.fold<int>(0, (s, r) => s + r.report.sets.length);
  int get _goodReps =>
      widget.reports.fold<int>(0, (s, r) => s + (r.goodReps ?? 0));
  int get _allReps =>
      widget.reports.fold<int>(0, (s, r) => s + (r.totalReps ?? 0));

  String get _duration {
    final d = widget.totalDuration;
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final control = widget.controlCondition;
    final coachLine = widget.coach.watch.trim().isNotEmpty
        ? widget.coach.watch
        : widget.coach.quote;
    Widget hero(double mascotSize) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            children: [
              if (!control)
                TkMascot(
                    asset: Tk.mascotTrophy,
                    size: mascotSize,
                    semanticLabel: 'Tắc Kè nâng cúp'),
              Text(
                control ? 'Hoàn thành buổi tập.' : 'Hoàn thành buổi tập!',
                textAlign: TextAlign.center,
                style: Tk.text(28,
                    weight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.4),
              ),
              const SizedBox(height: 4),
              Text(
                control
                    ? 'Phiên tập đã được ghi nhận hoàn tất.'
                    : '${widget.reports.length} bài · ${widget.trophy.label}',
                textAlign: TextAlign.center,
                style: Tk.text(14.5,
                    weight: FontWeight.w800, color: Tk.onIndigoSoft),
              ),
              if (!control && widget.sessionSummary.streakBonus > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: Tk.indigoHi,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    'Thưởng chuỗi ${widget.sessionSummary.streakWeeks} tuần: +${widget.sessionSummary.streakBonus} điểm',
                    style: Tk.text(13.5,
                        weight: FontWeight.w900,
                        color: const Color(0xFFFFB870)),
                  ),
                ),
              ],
            ],
          ),
        );
    Widget panel(BorderRadius radius) => Container(
          decoration: BoxDecoration(
            color: Tk.surface,
            borderRadius: radius,
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  children: [
                    Row(
                      children: control
                          ? [
                              _Stat(
                                  label: 'SỐ HIỆP',
                                  value: '$_totalSets',
                                  color: Tk.primary,
                                  ink: Tk.primaryLip),
                              const SizedBox(width: 10),
                              _Stat(
                                  label: 'SỐ BÀI',
                                  value: '${widget.reports.length}',
                                  color: Tk.green,
                                  ink: Tk.greenInk),
                              const SizedBox(width: 10),
                              _Stat(
                                  label: 'THỜI GIAN',
                                  value: _duration,
                                  color: Tk.orange,
                                  ink: Tk.orangeInk),
                            ]
                          : [
                              _Stat(
                                  label: 'ĐIỂM FORM',
                                  value:
                                      '${widget.sessionSummary.sessionFormScore}',
                                  color: Tk.green,
                                  ink: Tk.greenInk),
                              const SizedBox(width: 10),
                              _Stat(
                                  label: 'ĐÚNG FORM',
                                  value: '$_goodReps',
                                  suffix: '/$_allReps',
                                  color: Tk.primary,
                                  ink: Tk.primaryLip),
                              const SizedBox(width: 10),
                              _Stat(
                                  label: 'THỜI GIAN',
                                  value: _duration,
                                  color: Tk.orange,
                                  ink: Tk.orangeInk),
                            ],
                    ),
                    const SizedBox(height: 18),
                    Text('CÁC BÀI ĐÃ TẬP', style: Tk.eyebrow()),
                    const SizedBox(height: 4),
                    for (final r in widget.reports)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                            border: Border(
                                bottom:
                                    BorderSide(color: Tk.lineSoft, width: 2))),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(r.exerciseName,
                                    style: Tk.text(15.5,
                                        weight: FontWeight.w900))),
                            Text(
                              control
                                  ? '${r.report.sets.length} hiệp'
                                  : (r.totalReps == null || r.totalReps == 0)
                                      ? '${r.report.sets.length} hiệp'
                                      : '${r.goodReps ?? 0}/${r.totalReps} rep',
                              style: Tk.text(14,
                                  weight: FontWeight.w900,
                                  color: control ? Tk.inkSoft : Tk.greenInk),
                            ),
                          ],
                        ),
                      ),
                    if (!control && coachLine.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFF6EC),
                            borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          children: [
                            const TkMascot(
                                asset: Tk.mascotHead, size: 52, bob: false),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(coachLine,
                                  style: Tk.text(14,
                                      weight: FontWeight.w800,
                                      color: const Color(0xFF3D2A14),
                                      height: 1.4)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (widget.onExportSessionLogs != null) ...[
                      const SizedBox(height: 16),
                      _ExportSessionLogsButton(
                          onExportSessionLogs: widget.onExportSessionLogs!),
                    ],
                    if (!control) ...[
                      const SizedBox(height: 16),
                      PostWorkoutMealCard(
                        key: ValueKey(_activityLogged),
                        compact: true,
                        justTrained: true,
                      ),
                    ],
                    const SizedBox(height: 14),
                    Center(
                      child: Text('Hẹn gặp lại buổi sau.',
                          style: Tk.text(14,
                              weight: FontWeight.w800, color: Tk.inkSoft)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 0, 20, 14 + MediaQuery.of(context).padding.bottom),
                child: Column(
                  children: [
                    TkButton(
                        label: 'Xong',
                        tone: TkButtonTone.green,
                        onTap: widget.onDone),
                    if (!control && widget.onShare != null)
                      TextButton(
                        onPressed: widget.onShare,
                        child: Text('Chia sẻ',
                            style: Tk.text(15,
                                weight: FontWeight.w900, color: Tk.primary)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
    return SensorRotatedBox(
      child: Scaffold(
        backgroundColor: Tk.indigo,
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, box) {
              if (box.maxWidth > box.maxHeight) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Center(
                        child: SingleChildScrollView(child: hero(120)),
                      ),
                    ),
                    Expanded(
                      flex: 6,
                      child: panel(const BorderRadius.only(
                          topLeft: Radius.circular(28))),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  hero(180),
                  Expanded(
                    child: panel(
                        const BorderRadius.vertical(top: Radius.circular(28))),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(
      {required this.label,
      required this.value,
      required this.color,
      required this.ink,
      this.suffix});

  final String label;
  final String value;
  final String? suffix;
  final Color color;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TkCard(
        radius: 16,
        borderColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Column(
          children: [
            Text(label,
                maxLines: 1,
                style: Tk.text(11,
                    weight: FontWeight.w900, color: ink, letterSpacing: 0.6)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                        text: value,
                        style: Tk.text(26, weight: FontWeight.w900)),
                    if (suffix != null)
                      TextSpan(
                          text: suffix,
                          style: Tk.text(15,
                              weight: FontWeight.w900, color: Tk.inkSoft)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportSessionLogsButton extends StatefulWidget {
  const _ExportSessionLogsButton({required this.onExportSessionLogs});

  final Future<bool> Function(BuildContext) onExportSessionLogs;

  @override
  State<_ExportSessionLogsButton> createState() =>
      _ExportSessionLogsButtonState();
}

class _ExportSessionLogsButtonState extends State<_ExportSessionLogsButton> {
  bool _sharing = false;

  Future<void> _share(BuildContext buttonContext) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final shared = await widget.onExportSessionLogs(buttonContext);
      if (!mounted) return;
      if (!shared) {
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                  'Chưa có tệp nhật ký nào để chia sẻ hoặc chia sẻ không thành công.'),
            ),
          );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
              content:
                  Text('Không thể chia sẻ tệp nhật ký. Vui lòng thử lại.')),
        );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (buttonContext) => OutlinedButton.icon(
        onPressed: _sharing ? null : () => _share(buttonContext),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: Tk.line, width: 2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.ios_share_rounded, color: Tk.primary),
        label: Text('Chia sẻ tệp nhật ký phiên này',
            style: Tk.text(14.5, weight: FontWeight.w900, color: Tk.primary)),
      ),
    );
  }
}
