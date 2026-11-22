import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/library_mock.dart';
import '../data/program_mock.dart';
import '../services/recommendation/program_plan_mapper.dart';
import '../services/recommendation/recommendation_service.dart';
import '../services/research/research_preferences.dart';
import '../services/session_persistence.dart';
import '../services/user_profile_service.dart';
import '../services/user_program_service.dart';
import '../services/workout_launch_service.dart';
import '../utils/orientation_lock.dart';
import '../widgets/tk/tk.dart';
import 'exercise/exercise_launch_args.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({
    super.key,
    required this.bottomPadding,
    this.program,
    this.userProfile,
    this.refreshListenable,
    this.onProfileChanged,
  });

  final double bottomPadding;
  final AppUserProfile? userProfile;

  /// Real assigned-program data from MainShell. Not consumed directly — the
  /// screen loads its own PlanSnapshot via RecommendationService and maps it.
  /// Kept so MainShell's existing wiring compiles unchanged.
  final UserProgramData? program;

  /// Bumped by MainShell when the Plan tab becomes visible.
  final Listenable? refreshListenable;

  /// Forwarded on workout completion so MainShell can refresh streak/profile.
  final ValueChanged<AppUserProfile>? onProfileChanged;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final _recommendations = RecommendationService();
  final _launches = WorkoutLaunchService();
  final _sessions = SessionPersistence();

  /// null = still loading. Non-null with empty blocks = no active plan.
  ProgramPlan? _program;
  int _selectedBlockIndex = 0;
  bool _loadingProgram = false;
  bool _programReloadQueued = false;

  @override
  void initState() {
    super.initState();
    unawaited(OrientationLock.portraitOnly());
    widget.refreshListenable?.addListener(_handleRefreshNudge);
    unawaited(_loadProgram());
  }

  @override
  void didUpdateWidget(covariant PlanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshListenable != widget.refreshListenable) {
      oldWidget.refreshListenable?.removeListener(_handleRefreshNudge);
      widget.refreshListenable?.addListener(_handleRefreshNudge);
    }
  }

  @override
  void dispose() {
    widget.refreshListenable?.removeListener(_handleRefreshNudge);
    super.dispose();
  }

  void _handleRefreshNudge() {
    unawaited(_loadProgram());
  }

  /// Loads (or reloads) the real plan + completion state and maps it to a
  /// ProgramPlan. Safe to call again after a workout to refresh status.
  Future<void> _loadProgram() async {
    if (_loadingProgram) {
      _programReloadQueued = true;
      return;
    }
    _loadingProgram = true;
    try {
      final snapshot =
          await _recommendations.fetchLatestActivePlanSnapshotForCurrentUser();

      if (snapshot == null) {
        if (!mounted) return;
        setState(() => _program = const ProgramPlan(blocks: [], retest: null));
        return;
      }

      // Every exercise_id in the plan (slots + retest) needs a name + AI flag.
      final ids = <String>{
        for (final w in snapshot.plan.weeks)
          for (final s in w.sessions)
            for (final slot in s.slots) slot.exerciseId,
        for (final e in snapshot.plan.endOfPlanRetest?.exercises ?? const [])
          e.exerciseId,
      };
      final catalogFuture =
          _recommendations.fetchLaunchCatalogInfoForExerciseIds(ids);
      final ledgerResultsFuture = _sessions.ledgerResultsForPlan(
        recommendationId: snapshot.plan.recommendationId,
      );

      final catalog = await catalogFuture;
      final ledgerResults = await ledgerResultsFuture;

      if (!mounted) return;
      final mapped = ProgramPlanMapper.fromSnapshot(
        snapshot,
        catalogById: catalog,
        ledgerResults: ledgerResults,
      );
      setState(() {
        _program = mapped;
        // Re-point to the current block (advances after a completed session).
        _selectedBlockIndex =
            mapped.blocks.isEmpty ? 0 : mapped.currentBlockIndex;
      });
    } finally {
      _loadingProgram = false;
      if (_programReloadQueued && mounted) {
        _programReloadQueued = false;
        unawaited(_loadProgram());
      }
    }
  }

  ProgramBlock get _selectedBlock => _program!.blocks[_selectedBlockIndex];

  void _selectBlock(int index) {
    if (index == _selectedBlockIndex) return;
    setState(() {
      _selectedBlockIndex = index;
    });
  }

  Future<void> _startNextSession() async {
    final target = await _launches.resolveTodayOrNextInCurrentWeek();
    if (!mounted) return;
    if (target == null || !target.hasLaunchableSlots) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Buổi này chưa có bài camera phù hợp.'),
        ));
      return;
    }

    final base = target.firstLaunchArgs();
    if (base == null) return;

    String? workoutSessionId;
    if (base.recommendationId != null) {
      workoutSessionId = await _sessions.startWorkoutSession(
        recommendationId: base.recommendationId!,
        weekNumber: base.weekNumber!,
        sessionIndex: base.sessionIndex!,
      );
    }

    final first = target.firstLaunchArgs(workoutSessionId: workoutSessionId);
    final completed = await _runWorkoutSequence(first!);
    if (completed) {
      final profile = await UserProfileService().fetchCurrentProfile();
      if (profile != null) widget.onProfileChanged?.call(profile);
    }
    if (!mounted) return;
    // Refresh the ledger so the just-completed session flips to done.
    await _loadProgram();
  }

  Future<bool> _runWorkoutSequence(ExerciseLaunchArgs first) async {
    ExerciseLaunchArgs? next = first;
    var completedFinalSlot = false;
    while (mounted && next != null) {
      final result = await Navigator.of(context).pushNamed(
        '/exercise',
        arguments: next,
      );
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

  void _openSession(PlanSession session, {required bool startable}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SessionSheet(
        title: session.title.isEmpty
            ? 'Buổi ${session.index + 1}'
            : 'Buổi ${session.index + 1} · ${session.title}',
        meta: [
          '${session.exerciseCount} bài',
          if (session.durationLabel.isNotEmpty) session.durationLabel,
        ].join(' · '),
        note: session.coachNote,
        exercises: session.exercises,
        status: session.status,
        onStart: startable
            ? () {
                Navigator.of(context).pop();
                unawaited(_startNextSession());
              }
            : null,
      ),
    );
  }

  void _openRetest(ProgramRetest retest, {required bool startable}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SessionSheet(
        title: retest.title,
        meta: retest.description,
        note: retest.coachNote,
        exercises: retest.exercises,
        status: retest.status,
        onStart: startable
            ? () {
                Navigator.of(context).pop();
                unawaited(_startNextSession());
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final program = _program;
    if (program == null) {
      return const ColoredBox(
        color: Tk.surface,
        child: Center(child: CircularProgressIndicator(color: Tk.primary)),
      );
    }
    if (program.blocks.isEmpty) {
      return ColoredBox(
        color: Tk.surface,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!ResearchPreferences.cachedConfig.isControl)
                  const TkMascot(asset: Tk.mascotThink, size: 160),
                const SizedBox(height: 12),
                Text(
                  'Chưa có lộ trình. Hoàn tất thiết lập để Vika lên kế hoạch cho bạn nhé.',
                  textAlign: TextAlign.center,
                  style: Tk.text(16,
                      weight: FontWeight.w700, color: Tk.inkSoft, height: 1.45),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final block = _selectedBlock;
    final isCurrentBlock = _selectedBlockIndex == program.currentBlockIndex;
    final isLastBlock = _selectedBlockIndex == program.blocks.length - 1;
    final retest = isLastBlock ? program.retest : null;
    final nextBlock = _selectedBlockIndex + 1 < program.blocks.length
        ? program.blocks[_selectedBlockIndex + 1]
        : null;
    final showMascot = !ResearchPreferences.cachedConfig.isControl;

    return ColoredBox(
      color: Tk.surface,
      child: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(bottom: widget.bottomPadding + 20),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lộ trình của bạn',
                      style: Tk.text(28,
                          weight: FontWeight.w900, letterSpacing: -0.4)),
                  const SizedBox(height: 4),
                  Text(
                    '${program.blocksTotal} tuần · Tiến từng buổi, không vội.',
                    style:
                        Tk.text(15, weight: FontWeight.w700, color: Tk.inkSoft),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 62,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                itemCount: program.blocks.length,
                separatorBuilder: (context, i) => const SizedBox(width: 8),
                itemBuilder: (context, i) => _WeekChip(
                  block: program.blocks[i],
                  selected: i == _selectedBlockIndex,
                  onTap: () => _selectBlock(i),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _BlockBanner(block: block),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < block.sessions.length; i++)
              _PathRow(
                offset: _pathOffsets[i % _pathOffsets.length],
                mascot:
                    showMascot && isCurrentBlock && block.sessions[i].isNext,
                child: _SessionNode(
                  session: block.sessions[i],
                  live: isCurrentBlock,
                  onTap: () {
                    final s = block.sessions[i];
                    if (isCurrentBlock && s.isNext) {
                      unawaited(_startNextSession());
                    } else {
                      _openSession(s, startable: false);
                    }
                  },
                  onLongPress: () => _openSession(block.sessions[i],
                      startable: isCurrentBlock && block.sessions[i].isNext),
                ),
              ),
            if (retest != null)
              _PathRow(
                offset:
                    _pathOffsets[block.sessions.length % _pathOffsets.length],
                mascot: false,
                child: _RetestNode(
                  retest: retest,
                  unlocked: program.allBlocksDone,
                  onTap: () => _openRetest(retest,
                      startable: program.allBlocksDone &&
                          retest.status != ProgramStatus.done),
                ),
              ),
            if (nextBlock != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: GestureDetector(
                  onTap: () => _selectBlock(_selectedBlockIndex + 1),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: const Color(0xFFDADCEB), width: 2),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'TUẦN ${nextBlock.blockNumber} · ${nextBlock.phaseName.toUpperCase()}',
                            style: Tk.text(14,
                                weight: FontWeight.w900, color: Tk.inkSoft),
                          ),
                        ),
                        Icon(
                          nextBlock.status == ProgramStatus.upcoming
                              ? Icons.lock_rounded
                              : Icons.chevron_right_rounded,
                          color: Tk.inkSoft,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const _pathOffsets = <double>[0, 58, 0, -58];

class _WeekChip extends StatelessWidget {
  const _WeekChip(
      {required this.block, required this.selected, required this.onTap});

  final ProgramBlock block;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch ((selected, block.status)) {
      (true, _) => (Tk.ink, Colors.white, Tk.ink),
      (false, ProgramStatus.done) => (Tk.greenSoft, Tk.greenInk, Tk.greenSoft),
      (false, ProgramStatus.current) => (
          Tk.primarySoft,
          Tk.primaryLip,
          Tk.primaryLine
        ),
      (false, ProgramStatus.upcoming) => (Tk.surface, Tk.inkSoft, Tk.line),
    };
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (block.status == ProgramStatus.done) ...[
                Icon(Icons.check_rounded, size: 16, color: fg),
                const SizedBox(width: 4),
              ],
              Text('Tuần ${block.blockNumber}',
                  style: Tk.text(14, weight: FontWeight.w900, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockBanner extends StatelessWidget {
  const _BlockBanner({required this.block});

  final ProgramBlock block;

  @override
  Widget build(BuildContext context) {
    final total = block.sessionsTotal;
    final done = block.sessionsDone;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: Tk.primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Tk.primaryLip, offset: Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TUẦN ${block.blockNumber} · ${block.phaseName.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Tk.text(12.5,
                      weight: FontWeight.w900,
                      color: const Color(0xFFDCE4FF),
                      letterSpacing: 1),
                ),
                const SizedBox(height: 2),
                Text('Đã xong $done/$total buổi',
                    style: Tk.text(18,
                        weight: FontWeight.w900, color: Colors.white)),
                if (block.focusLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    block.focusLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Tk.text(13,
                        weight: FontWeight.w700,
                        color: const Color(0xFFDCE4FF)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              value: total == 0 ? 0 : done / total,
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              backgroundColor: const Color(0xFF4E78F0),
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _PathRow extends StatelessWidget {
  const _PathRow(
      {required this.offset, required this.mascot, required this.child});

  final double offset;
  final bool mascot;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mascotLeft = offset >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        height: mascot ? 150 : 104,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (mascot)
              Align(
                alignment:
                    mascotLeft ? Alignment.centerLeft : Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Transform.flip(
                    flipX: !mascotLeft,
                    child: const TkMascot(
                        asset: Tk.mascotPoint,
                        size: 124,
                        semanticLabel: 'Tắc Kè chỉ vào buổi tiếp theo'),
                  ),
                ),
              ),
            Transform.translate(offset: Offset(offset, 0), child: child),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.size,
    required this.color,
    required this.lip,
    required this.child,
    required this.onTap,
    this.onLongPress,
  });

  final Size size;
  final Color color;
  final Color lip;
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: TkPressable(
        onTap: onTap,
        lipColor: lip,
        lipDepth: 6,
        radius: size.height,
        child: Container(
          width: size.width,
          height: size.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.all(
                  Radius.elliptical(size.width / 2, size.height / 2))),
          child: child,
        ),
      ),
    );
  }
}

class _SessionNode extends StatelessWidget {
  const _SessionNode(
      {required this.session,
      required this.live,
      required this.onTap,
      required this.onLongPress});

  final PlanSession session;
  final bool live;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final number = session.index + 1;
    if (live && session.isNext) {
      return Semantics(
        button: true,
        label: 'Bắt đầu buổi $number',
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Tk.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Tk.line, width: 2),
              ),
              child: Text('BẮT ĐẦU',
                  style:
                      Tk.text(13, weight: FontWeight.w900, color: Tk.primary)),
            ),
            const SizedBox(height: 6),
            _Bubble(
              size: const Size(84, 76),
              color: Tk.primary,
              lip: Tk.primaryLip,
              onTap: onTap,
              onLongPress: onLongPress,
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 44),
            ),
            const SizedBox(height: 4),
            Text('Buổi $number · Tiếp theo',
                style:
                    Tk.text(12.5, weight: FontWeight.w900, color: Tk.primary)),
          ],
        ),
      );
    }
    final done = session.status == ProgramStatus.done;
    return Semantics(
      button: true,
      label: done ? 'Buổi $number, đã xong' : 'Buổi $number, chưa mở',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Bubble(
            size: const Size(68, 62),
            color: done ? Tk.green : const Color(0xFFE9EAF2),
            lip: done ? Tk.greenLip : const Color(0xFFD3D5E3),
            onTap: onTap,
            child: done
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 34)
                : const Icon(Icons.lock_rounded, color: Tk.inkMuted, size: 24),
          ),
          const SizedBox(height: 4),
          Text('Buổi $number',
              style: Tk.text(12, weight: FontWeight.w800, color: Tk.inkSoft)),
        ],
      ),
    );
  }
}

class _RetestNode extends StatelessWidget {
  const _RetestNode(
      {required this.retest, required this.unlocked, required this.onTap});

  final ProgramRetest retest;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = retest.status == ProgramStatus.done;
    return Semantics(
      button: true,
      label: retest.title,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Bubble(
            size: const Size(74, 68),
            color: done
                ? Tk.green
                : (unlocked ? Tk.orange : const Color(0xFFE9EAF2)),
            lip: done
                ? Tk.greenLip
                : (unlocked ? Tk.orangeLip : const Color(0xFFD3D5E3)),
            onTap: onTap,
            child: Icon(Icons.emoji_events_rounded,
                color: unlocked || done ? Colors.white : Tk.inkMuted, size: 34),
          ),
          const SizedBox(height: 4),
          Text('Kiểm tra lại',
              style: Tk.text(12, weight: FontWeight.w800, color: Tk.inkSoft)),
        ],
      ),
    );
  }
}

class _SessionSheet extends StatelessWidget {
  const _SessionSheet({
    required this.title,
    required this.meta,
    required this.note,
    required this.exercises,
    required this.status,
    required this.onStart,
  });

  final String title;
  final String meta;
  final String note;
  final List<SessionExercise> exercises;
  final ProgramStatus status;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: const BoxDecoration(
          color: Tk.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                      color: Tk.line, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        switch (status) {
                          ProgramStatus.done => 'ĐÃ XONG',
                          ProgramStatus.current => 'TIẾP THEO',
                          ProgramStatus.upcoming => 'SẮP TỚI',
                        },
                        style: Tk.eyebrow(
                            color: status == ProgramStatus.done
                                ? Tk.greenLip
                                : Tk.inkSoft),
                      ),
                      const SizedBox(height: 4),
                      Text(title,
                          style: Tk.text(23,
                              weight: FontWeight.w900, height: 1.2)),
                      const SizedBox(height: 4),
                      Text(meta,
                          style: Tk.text(14.5,
                              weight: FontWeight.w700,
                              color: Tk.inkSoft,
                              height: 1.4)),
                      const SizedBox(height: 14),
                      for (final e in exercises)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                    color: Tk.surfaceSoft,
                                    borderRadius: BorderRadius.circular(14)),
                                alignment: Alignment.center,
                                child: switch (
                                    exerciseThumbnailForId(e.exerciseId)) {
                                  final asset? => Image.asset(asset,
                                      width: 44,
                                      height: 44,
                                      cacheWidth: 720,
                                      fit: BoxFit.contain,
                                      excludeFromSemantics: true),
                                  null => const Icon(
                                      Icons.fitness_center_rounded,
                                      color: Tk.inkSoft),
                                },
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.name,
                                        style: Tk.text(15.5,
                                            weight: FontWeight.w900)),
                                    Text(e.volumeLabel,
                                        style: Tk.text(13,
                                            weight: FontWeight.w700,
                                            color: Tk.inkSoft)),
                                  ],
                                ),
                              ),
                              if (e.formScore != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: Tk.greenSoft,
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Text('Form ${e.formScore}',
                                      style: Tk.text(12,
                                          weight: FontWeight.w900,
                                          color: Tk.greenInk)),
                                ),
                            ],
                          ),
                        ),
                      if (note.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          decoration: BoxDecoration(
                              color: Tk.primarySoft,
                              borderRadius: BorderRadius.circular(14)),
                          child: Text(note,
                              style: Tk.text(14,
                                  weight: FontWeight.w700,
                                  color: Tk.primaryLip,
                                  height: 1.4)),
                        ),
                    ],
                  ),
                ),
              ),
              if (onStart != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: TkButton(
                      label: 'Bắt đầu',
                      icon: Icons.play_arrow_rounded,
                      tone: TkButtonTone.green,
                      onTap: onStart),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
