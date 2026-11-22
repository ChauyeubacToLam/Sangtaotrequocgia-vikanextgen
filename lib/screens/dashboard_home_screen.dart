import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/exercise_definition.dart';
import '../screens/exercise/exercise_launch_args.dart';
import '../screens/nutrition/post_workout_card.dart';
import '../services/research/research_preferences.dart';
import '../services/session_persistence.dart';
import '../services/user_program_service.dart';
import '../services/user_profile_service.dart';
import '../services/workout_launch_service.dart';
import '../utils/orientation_lock.dart';
import '../widgets/tk/tk.dart';

class DashboardHomeScreen extends StatefulWidget {
  const DashboardHomeScreen({
    super.key,
    required this.bottomPadding,
    required this.onOpenBrowser,
    this.program,
    this.userProfile,
    this.onProfileChanged,
  });

  final double bottomPadding;
  final VoidCallback onOpenBrowser;
  final UserProgramData? program;
  final AppUserProfile? userProfile;
  final ValueChanged<AppUserProfile>? onProfileChanged;

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  final _launches = WorkoutLaunchService();
  late Future<WorkoutLaunchHomeState> _launchStateFuture;
  late Future<int> _streakFuture;
  late Future<({int? percent, int? delta, List<int> week})> _formSummaryFuture;

  @override
  void initState() {
    super.initState();
    unawaited(OrientationLock.portraitOnly());
    _launchStateFuture = _launches.resolveHomeState();
    _streakFuture = SessionPersistence().currentStreak();
    _formSummaryFuture = SessionPersistence().homeFormSummary();
  }

  void _reloadLaunchTarget() {
    setState(() {
      _launchStateFuture = _launches.resolveHomeState();
      _streakFuture = SessionPersistence().currentStreak();
      _formSummaryFuture = SessionPersistence().homeFormSummary();
    });
  }

  static int _minutesFor(WorkoutLaunchTarget target) =>
      (target.sequence.length * 5).clamp(12, 35);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Tk.surface,
      child: FutureBuilder<WorkoutLaunchHomeState>(
        future: _launchStateFuture,
        builder: (context, snapshot) {
          final state = snapshot.data;
          final loading = snapshot.connectionState == ConnectionState.waiting;
          final target = state?.target;
          final training = target != null && target.hasLaunchableSlots;
          final String message;
          if (loading) {
            message = 'Đợi mình xem hôm nay tập gì nhé…';
          } else if (training) {
            message = 'Sẵn sàng chưa? Buổi ${target.session.sessionIndex + 1} có '
                '${target.sequence.length} bài, chừng ${_minutesFor(target)} phút thôi!';
          } else {
            message = 'Hôm nay nghỉ nhé! Mai mình tập tiếp.';
          }
          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(bottom: widget.bottomPadding + 16),
            children: [
              _HomeTopBar(
                profile: widget.userProfile,
                streakFuture: _streakFuture,
                formFuture: _formSummaryFuture,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 2, 20, 0),
                child: ResearchPreferences.cachedConfig.isControl
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(18, 8, 0, 4),
                        child: Text(message, style: Tk.text(18, weight: FontWeight.w900, height: 1.3)),
                      )
                    : TkSpeechRow(
                        asset: training || loading ? Tk.mascotWave : Tk.mascotThink,
                        message: message,
                      ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: loading
                      ? const _CardSkeleton(key: ValueKey('loading'))
                      : training
                          ? _TodayCard(
                              key: const ValueKey('today'),
                              target: target,
                              minutes: _minutesFor(target),
                              onStart: () => _startWorkoutTarget(target),
                            )
                          : _RestCard(
                              key: const ValueKey('rest'),
                              onStretch: widget.onOpenBrowser,
                            ),
                ),
              ),
              if (!loading && (state?.sessionsThisWeek ?? 0) > 0) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _WeekCard(
                    done: state!.completedSessionsThisWeek,
                    total: state.sessionsThisWeek,
                  ),
                ),
              ],
              if (!loading && !ResearchPreferences.cachedConfig.isControl) ...[
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: PostWorkoutMealCard(compact: true),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _startWorkoutTarget(WorkoutLaunchTarget target) async {
    HapticFeedback.mediumImpact();
    final base = target.firstLaunchArgs();
    if (base == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Buổi này chưa có bài camera phù hợp.')),
        );
      return;
    }
    String? workoutSessionId;
    if (base.recommendationId != null) {
      workoutSessionId = await SessionPersistence().startWorkoutSession(
        recommendationId: base.recommendationId!,
        weekNumber: base.weekNumber!,
        sessionIndex: base.sessionIndex!,
      );
    }
    final first = target.firstLaunchArgs(workoutSessionId: workoutSessionId);
    final completedWorkout = await _runWorkoutSequence(first!);
    if (completedWorkout) {
      final profile = await UserProfileService().fetchCurrentProfile();
      if (profile != null) widget.onProfileChanged?.call(profile);
    }
    if (!mounted) return;
    _reloadLaunchTarget();
  }

  Future<bool> _runWorkoutSequence(ExerciseLaunchArgs first) async {
    ExerciseLaunchArgs? next = first;
    var completedFinalSlot = false;
    while (mounted && next != null) {
      final result = await Navigator.of(context).pushNamed('/exercise', arguments: next);
      if (!mounted) return false;
      if (result is Map && result['next'] is ExerciseLaunchArgs) {
        next = result['next'] as ExerciseLaunchArgs;
      } else {
        completedFinalSlot = result is Map && result['completed'] == true;
        next = null;
      }
    }
    return completedFinalSlot;
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({
    required this.profile,
    required this.streakFuture,
    required this.formFuture,
  });

  final AppUserProfile? profile;
  final Future<int> streakFuture;
  final Future<({int? percent, int? delta, List<int> week})> formFuture;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile?.avatarUrl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Tk.primary,
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Tk.primaryLip, offset: Offset(0, 3))],
              image: avatarUrl == null
                  ? null
                  : DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover),
            ),
            alignment: Alignment.center,
            child: avatarUrl == null
                ? Text(profile?.initial ?? 'V', style: Tk.text(18, weight: FontWeight.w900, color: Colors.white))
                : null,
          ),
          const Spacer(),
          FutureBuilder<int>(
            future: streakFuture,
            builder: (context, snap) => _Chip(
              background: Tk.orangeSoft,
              color: Tk.orangeInk,
              icon: Icons.local_fire_department_rounded,
              iconColor: Tk.orange,
              label: '${snap.data ?? profile?.streakWeeks ?? 0} tuần',
            ),
          ),
          const SizedBox(width: 8),
          FutureBuilder<({int? percent, int? delta, List<int> week})>(
            future: formFuture,
            builder: (context, snap) {
              final p = snap.data?.percent;
              return _Chip(
                background: Tk.primarySoft,
                color: Tk.primaryLip,
                icon: Icons.track_changes_rounded,
                iconColor: Tk.primary,
                label: p == null ? 'Form —' : 'Form $p%',
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.background,
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  final Color background;
  final Color color;
  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 6),
          Text(label, style: Tk.text(15, weight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    super.key,
    required this.target,
    required this.minutes,
    required this.onStart,
  });

  final WorkoutLaunchTarget target;
  final int minutes;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final items = target.sequence;
    final shown = items.take(4).toList();
    final more = items.length - shown.length;
    return TkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'HÔM NAY · BUỔI ${target.session.sessionIndex + 1}',
                  style: Tk.eyebrow(color: Tk.primary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: Tk.greenSoft, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_rounded, size: 16, color: Tk.greenInk),
                    const SizedBox(width: 5),
                    Text('AI chấm form', style: Tk.text(12, weight: FontWeight.w900, color: Tk.greenInk)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Buổi tập hôm nay', style: Tk.text(26, weight: FontWeight.w900, letterSpacing: -0.4)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 18, color: Tk.inkSoft),
              const SizedBox(width: 5),
              Text('$minutes phút', style: Tk.text(15, color: Tk.inkSoft)),
              const SizedBox(width: 14),
              const Icon(Icons.format_list_bulleted_rounded, size: 18, color: Tk.inkSoft),
              const SizedBox(width: 5),
              Text('${items.length} bài', style: Tk.text(15, color: Tk.inkSoft)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in shown)
                _Pill(
                  label: item.prescription == null
                      ? item.definition.displayName
                      : '${item.definition.displayName} · ${workoutVolumeLabel(item.prescription!)}',
                ),
              if (more > 0) _Pill(label: '+$more bài', muted: true),
            ],
          ),
          const SizedBox(height: 16),
          TkButton(label: 'Bắt đầu tập', icon: Icons.play_arrow_rounded, onTap: onStart),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(color: Tk.lineSoft, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: Tk.text(14, color: muted ? Tk.inkSoft : Tk.ink)),
    );
  }
}

class _RestCard extends StatelessWidget {
  const _RestCard({super.key, required this.onStretch});

  final VoidCallback onStretch;

  @override
  Widget build(BuildContext context) {
    return TkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('HÔM NAY · NGÀY NGHỈ', style: Tk.eyebrow(color: Tk.greenLip)),
          const SizedBox(height: 10),
          Text('Nghỉ ngơi cũng là tập', style: Tk.text(26, weight: FontWeight.w900, letterSpacing: -0.4)),
          const SizedBox(height: 8),
          Text(
            'Cơ thể cần hồi lại để buổi tới khỏe hơn. Muốn vận động nhẹ thì giãn cơ vài phút nhé.',
            style: Tk.text(15, weight: FontWeight.w700, color: Tk.inkSoft, height: 1.45),
          ),
          const SizedBox(height: 16),
          TkButton(label: 'Xem bài giãn cơ', tone: TkButtonTone.outline, height: 54, onTap: onStretch),
        ],
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: Tk.lineSoft, borderRadius: BorderRadius.circular(8)),
        );
    return TkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(140, 14),
          const SizedBox(height: 14),
          bar(220, 26),
          const SizedBox(height: 12),
          bar(160, 16),
          const SizedBox(height: 16),
          bar(double.infinity, 56),
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final nodes = <Widget>[];
    for (var i = 0; i < total; i++) {
      if (i > 0) {
        nodes.add(
          Expanded(
            child: Container(
              height: 6,
              margin: const EdgeInsets.only(top: 18),
              decoration: BoxDecoration(
                color: i <= done ? Tk.green : const Color(0xFFE1E3F0),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      }
      final isDone = i < done;
      final isToday = i == done;
      nodes.add(
        SizedBox(
          width: 60,
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDone ? Tk.green : Tk.surface,
                  shape: BoxShape.circle,
                  border: isDone ? null : Border.all(color: isToday ? Tk.primary : const Color(0xFFD3D5E3), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: isDone ? Tk.greenLip : (isToday ? Tk.primaryLine : const Color(0xFFE9EAF2)),
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: isDone
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 26)
                    : Text(
                        '${i + 1}',
                        style: Tk.text(16, weight: FontWeight.w900, color: isToday ? Tk.primary : Tk.inkMuted),
                      ),
              ),
              const SizedBox(height: 6),
              Text(
                isToday ? 'Hôm nay' : 'Buổi ${i + 1}',
                style: Tk.text(12, weight: isToday ? FontWeight.w900 : FontWeight.w800, color: isToday ? Tk.primary : Tk.inkSoft),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(color: Tk.surfaceSoft, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('TUẦN NÀY', style: Tk.eyebrow()),
              const Spacer(),
              Text('$done/$total buổi', style: Tk.text(15, weight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: nodes),
        ],
      ),
    );
  }
}
