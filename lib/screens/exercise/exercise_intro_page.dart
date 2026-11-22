import 'dart:async';

import 'package:flutter/material.dart';

import '../../widgets/ivory/atoms.dart';
import '../../widgets/tk/tk.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../interpreter/interpreter_base.dart';
import '../../models/exercise_definition.dart';
import '../../models/exercise_lookup.dart';
import '../../widgets/exercise/auto_start_countdown.dart';
import '../../widgets/exercise/previous_exercise_rating_dialog.dart';
import 'exercise_launch_args.dart';
import '../../data/library_mock.dart';
import 'widgets/camera_placement_card.dart';
import 'widgets/exercise_guide_video.dart';
import 'widgets/skeleton_annotation.dart';

class ExerciseIntroBadge {
  const ExerciseIntroBadge({
    required this.title,
    required this.value,
    required this.color,
  });
  final String title;
  final String value;
  final Color color;
}

class ExerciseIntroPage extends StatefulWidget {
  const ExerciseIntroPage({
    super.key,
    required this.title,
    required this.difficulty,
    required this.totalSets,
    required this.repsPerSet,
    required this.muscles,
    required this.tips,
    required this.badges,
    required this.callouts,
    required this.coachNote,
    required this.onStart,
    required this.onBack,
    this.onReviewerDemoHold,
    this.videoAsset,
    this.restSeconds = 45,
    this.subtitle,
    this.posture = SkeletonPosture.standing,
    this.onWatchVideo,
    this.targetLabel = 'REP/HIỆP',
    this.secondsPerUnit = 4,
    this.sessionProgressLabel,
    this.isContinuation = false,
    this.previousExerciseName,
    this.previousExerciseFormScore,
    this.previousExerciseIssueQuestion,
    this.onPreviousDifficulty,
    this.exerciseId,
    this.safetyWarning,
    this.previousExerciseId,
    this.sequenceExerciseIds = const <String>[],
    this.sequenceIndex = 0,
    this.controlCondition = false,
  });

  final String title;
  final String difficulty;
  final int totalSets;
  final int repsPerSet;
  final List<String> muscles;
  final List<String> tips;

  /// Temporal metrics — no anatomy anchor (e.g. descent tempo, hold).
  final List<ExerciseIntroBadge> badges;

  /// Anatomical metrics — anchored to body positions.
  final List<SkeletonCallout> callouts;
  final String? videoAsset;

  /// Retained for backward compat. Not rendered in v3 — the page is
  /// for specs, not selling.
  final String coachNote;

  final VoidCallback onStart;
  final VoidCallback onBack;

  /// When non-null, a deliberate 5-second press-and-hold on the
  /// "Bắt đầu tập" pill fires this instead of starting the workout —
  /// used to surface the reviewer tracking-demo overlay. A quick tap
  /// (sub-5s press) still starts normally. Null = no long-press wiring.
  final VoidCallback? onReviewerDemoHold;

  final int restSeconds;
  final String? subtitle;
  final SkeletonPosture posture;
  final VoidCallback? onWatchVideo;
  final String targetLabel;
  final double secondsPerUnit;
  final String? sessionProgressLabel;
  final bool isContinuation;

  /// When non-null, an "đánh giá bài vừa rồi" block surfaces at the top
  /// of the body. Filled in only for exercises after the first in a
  /// multi-exercise sequence. The sticky CTA stays gated (locked + grey)
  /// until the user picks a difficulty.
  final String? previousExerciseName;
  final int? previousExerciseFormScore;

  /// Optional detected form issue from the previous exercise. When present,
  /// the rating popup adds a short, optional issue-confirm section.
  final DetectedEvidence? previousExerciseIssueQuestion;
  final ValueChanged<String>? onPreviousDifficulty;

  /// Optional explicit exercise id. When omitted (e.g. from
  /// `ExerciseExperienceScreen`), resolved from route arguments or [title].
  final String? exerciseId;
  final String? safetyWarning;
  final String? previousExerciseId;
  final List<String> sequenceExerciseIds;
  final int sequenceIndex;
  final bool controlCondition;

  @override
  State<ExerciseIntroPage> createState() => _ExerciseIntroPageState();
}

class _ExerciseIntroPageState extends State<ExerciseIntroPage> {
  String? _selectedPreviousDifficulty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openingFlow());
  }

  Future<void> _openingFlow() async {
    String? rating;
    if (widget.previousExerciseName != null) {
      rating = await showPreviousExerciseRatingDialog(
        context,
        exerciseName: widget.previousExerciseName!,
        formScore:
            widget.controlCondition ? null : widget.previousExerciseFormScore,
        issueQuestion: widget.controlCondition
            ? null
            : widget.previousExerciseIssueQuestion,
      );
      if (!mounted) return;
      widget.onPreviousDifficulty?.call(rating);
    }
    final asset = widget.videoAsset;
    if (asset != null) {
      final id = _resolvedExerciseId(context);
      final seen = await guideVideoSeen(id);
      if (!mounted) return;
      if (!seen) {
        await showExerciseGuideVideo(context,
            asset: asset, title: widget.title, exerciseId: id, firstTime: true);
        if (!mounted) return;
      }
    }
    if (rating != null) setState(() => _selectedPreviousDifficulty = rating);
  }

  VoidCallback? _watchVideo(String id) {
    if (widget.onWatchVideo != null) return widget.onWatchVideo;
    final asset = widget.videoAsset;
    if (asset == null) return null;
    return () => showExerciseGuideVideo(context,
        asset: asset, title: widget.title, exerciseId: id);
  }

  String get _estimatedMinutes {
    final workSeconds =
        widget.totalSets * widget.repsPerSet * widget.secondsPerUnit;
    final restSecondsTotal = (widget.totalSets - 1) * widget.restSeconds;
    final total = workSeconds + restSecondsTotal;
    final minutes = (total / 60).ceil();
    return '~$minutes phút';
  }

  String _resolvedExerciseId(BuildContext context) {
    final explicit = widget.exerciseId?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is ExerciseLaunchArgs) {
      final catalogId = routeArgs.catalogExerciseId?.trim();
      if (catalogId != null && catalogId.isNotEmpty) return catalogId;
      final infoId = routeArgs.catalogInfo?.id.trim();
      if (infoId != null && infoId.isNotEmpty) return infoId;
      return routeArgs.definition.id;
    }
    if (routeArgs is ExerciseDefinition) {
      return routeArgs.id;
    }

    for (final def in exerciseDefinitions) {
      if (def.displayName == widget.title || def.name == widget.title) {
        return def.id;
      }
    }
    return widget.title;
  }

  String? _resolvedSafetyWarning(BuildContext context, String resolvedId) {
    final explicit = widget.safetyWarning?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is ExerciseLaunchArgs) {
      return routeArgs.definition.safetyWarning;
    }
    if (routeArgs is ExerciseDefinition) {
      return routeArgs.safetyWarning;
    }
    return lookupExerciseDefinition(resolvedId)?.safetyWarning;
  }

  PlacementTransitionNotice? _resolvedTransitionNotice(
    BuildContext context,
    ExercisePlacementSpec spec,
  ) {
    if (widget.sequenceExerciseIds.isNotEmpty && widget.sequenceIndex > 0) {
      return computePlacementTransition(
        current: spec,
        sequenceExerciseIds: widget.sequenceExerciseIds,
        sequenceIndex: widget.sequenceIndex,
        previousExerciseId: widget.previousExerciseId,
      );
    }
    if (widget.previousExerciseId != null) {
      return computePlacementTransition(
        current: spec,
        previousExerciseId: widget.previousExerciseId,
      );
    }

    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is ExerciseLaunchArgs && routeArgs.sequenceIndex > 0) {
      return computePlacementTransition(
        current: spec,
        sequenceExerciseIds: <String>[
          for (final item in routeArgs.sequence)
            item.catalogExerciseId ?? item.definition.id,
        ],
        sequenceIndex: routeArgs.sequenceIndex,
        previousExerciseId: routeArgs.priorReports.isNotEmpty
            ? routeArgs.priorReports.last.exerciseKey
            : null,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final statusBarInset = mq.viewPadding.top;
    final clampedScaler = mq.textScaler.clamp(
      minScaleFactor: 0.92,
      maxScaleFactor: 1.12,
    );

    final resolvedId = _resolvedExerciseId(context);
    final placementSpec = lookupExercisePlacement(resolvedId);
    final safetyWarning = _resolvedSafetyWarning(context, resolvedId);
    final transitionNotice = placementSpec == null
        ? null
        : _resolvedTransitionNotice(context, placementSpec);

    final watch = _watchVideo(resolvedId);
    final placementCard = placementSpec == null
        ? null
        : CameraPlacementCard(
            spec: placementSpec,
            safetyWarning: safetyWarning,
            transitionNotice: transitionNotice,
          );
    Widget header({required bool showVideo, bool compact = false}) =>
        _IntroHeader(
          statusBarInset: compact ? 0 : statusBarInset,
          title: widget.title,
          exerciseId: resolvedId,
          thumbnail: exerciseThumbnailForId(resolvedId),
          sessionProgressLabel: widget.sessionProgressLabel,
          sets: widget.totalSets,
          repsPerSet: widget.repsPerSet,
          restSeconds: widget.restSeconds,
          targetLabel: widget.targetLabel,
          estimatedMinutes: _estimatedMinutes,
          controlCondition: widget.controlCondition,
          onBack: widget.onBack,
          onWatchVideo: watch,
          videoAsset: widget.videoAsset,
          showVideo: showVideo,
          compact: compact,
        );

    return MediaQuery(
      data: mq.copyWith(textScaler: clampedScaler),
      child: Scaffold(
        backgroundColor: Tk.surface,
        body: LayoutBuilder(builder: (context, box) {
          if (box.maxWidth > box.maxHeight) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 0, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (watch != null)
                      Expanded(
                        flex: 11,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _InlineVideoCard(
                            asset: widget.videoAsset,
                            thumbnail: exerciseThumbnailForId(resolvedId),
                            onOpen: watch,
                            expand: true,
                          ),
                        ),
                      ),
                    Expanded(
                      flex: 10,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  header(showVideo: false, compact: true),
                                  if (placementCard != null)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          20, 10, 20, 0),
                                      child: placementCard,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          _buildBottomDock(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return Stack(
            children: [
              MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header(showVideo: true),
                      const SizedBox(height: 16),
                      if (placementCard != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: placementCard,
                        ),
                      SizedBox(
                        height: 120 + MediaQuery.viewPaddingOf(context).bottom,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildBottomDock(context),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildBottomDock(BuildContext context) {
    final isContinuation = widget.previousExerciseName != null;
    if (isContinuation && _selectedPreviousDifficulty == null) {
      return const SizedBox.shrink();
    }
    if (isContinuation) {
      return AutoStartCountdown(
        totalSeconds: 30,
        onStartNow: widget.onStart,
      );
    }
    return _StickyCtaDock(
      onStart: widget.onStart,
      onReviewerDemoHold: widget.onReviewerDemoHold,
    );
  }
}

class _StickyCtaDock extends StatefulWidget {
  const _StickyCtaDock({
    required this.onStart,
    this.onReviewerDemoHold,
  });

  final VoidCallback onStart;
  final VoidCallback? onReviewerDemoHold;

  @override
  State<_StickyCtaDock> createState() => _StickyCtaDockState();
}

class _StickyCtaDockState extends State<_StickyCtaDock> {
  bool _pressed = false;

  /// Armed on press-down when [_StickyCtaDock.onReviewerDemoHold] is wired;
  /// fires the demo at 5s. Cancelled by an early release.
  Timer? _holdTimer;
  bool _demoFired = false;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _startHold() {
    if (widget.onReviewerDemoHold == null) return;
    _demoFired = false;
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(seconds: 5), () {
      _holdTimer = null;
      _demoFired = true;
      if (mounted) setState(() => _pressed = false);
      widget.onReviewerDemoHold?.call();
    });
  }

  void _endHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    if (_demoFired) {
      // The 5s demo already fired — swallow the release, don't start.
      _demoFired = false;
      return;
    }
    // A sub-5s press still starts the workout.
    HapticFeedback.mediumImpact();
    widget.onStart();
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _demoFired = false;
  }

  void _handlePressDown() {
    setState(() => _pressed = true);
    _startHold();
  }

  void _handlePressUp() {
    setState(() => _pressed = false);
    _endHold();
  }

  void _handlePressCancel() {
    setState(() => _pressed = false);
    _cancelHold();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 14 + bottomInset),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Tk.surface.withValues(alpha: 0), Tk.surface],
          stops: const [0.0, 0.35],
        ),
      ),
      child: Semantics(
        button: true,
        label: 'Bắt đầu tập',
        child: GestureDetector(
          onTapDown: (_) => _handlePressDown(),
          onTapUp: (_) => _handlePressUp(),
          onTapCancel: _handlePressCancel,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            height: 56,
            margin: EdgeInsets.only(top: _pressed ? 4 : 0),
            decoration: BoxDecoration(
              color: Tk.green,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _pressed
                  ? const []
                  : const [BoxShadow(color: Tk.greenLip, offset: Offset(0, 4))],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_arrow_rounded,
                    color: Color(0xFF10351B), size: 24),
                const SizedBox(width: 6),
                Text('BẮT ĐẦU TẬP',
                    style: Tk.text(17,
                        weight: FontWeight.w900,
                        color: const Color(0xFF10351B),
                        letterSpacing: 0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroHeader extends StatelessWidget {
  const _IntroHeader({
    required this.statusBarInset,
    required this.title,
    required this.exerciseId,
    required this.thumbnail,
    required this.sessionProgressLabel,
    required this.sets,
    required this.repsPerSet,
    required this.restSeconds,
    required this.targetLabel,
    required this.estimatedMinutes,
    required this.controlCondition,
    required this.onBack,
    required this.onWatchVideo,
    this.videoAsset,
    this.showVideo = true,
    this.compact = false,
  });

  final String? videoAsset;
  final bool showVideo;
  final bool compact;
  final double statusBarInset;
  final String title;
  final String exerciseId;
  final String? thumbnail;
  final String? sessionProgressLabel;
  final int sets;
  final int repsPerSet;
  final int restSeconds;
  final String targetLabel;
  final String estimatedMinutes;
  final bool controlCondition;
  final VoidCallback onBack;
  final VoidCallback? onWatchVideo;

  @override
  Widget build(BuildContext context) {
    Widget tile(String value, String label, {bool accent = false}) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: accent ? Tk.primarySoft : Tk.surface,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: accent ? Tk.primary : Tk.line, width: 2),
            ),
            child: Column(
              children: [
                Text(value,
                    style: Tk.text(26,
                        weight: FontWeight.w900,
                        color: accent ? Tk.primaryLip : Tk.ink)),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Tk.text(11.5,
                      weight: FontWeight.w900,
                      color: accent ? Tk.primaryLip : Tk.inkSoft,
                      letterSpacing: 0.6),
                ),
              ],
            ),
          ),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(12, statusBarInset + 6, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Quay lại',
                onPressed: onBack,
                icon: const Icon(Icons.close_rounded,
                    color: Tk.inkSoft, size: 28),
              ),
              const Spacer(),
              if (sessionProgressLabel != null)
                Text(sessionProgressLabel!,
                    style: Tk.text(14,
                        weight: FontWeight.w900, color: Tk.inkSoft)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showVideo && onWatchVideo != null) ...[
                  const SizedBox(height: 6),
                  _InlineVideoCard(
                    asset: videoAsset,
                    thumbnail: thumbnail,
                    onOpen: onWatchVideo!,
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Tk.text(compact ? 24 : 30,
                              weight: FontWeight.w900,
                              letterSpacing: -0.5,
                              height: 1.1)),
                    ),
                    if (!controlCondition && !compact)
                      const TkMascot(asset: Tk.mascotPoint, size: 84),
                  ],
                ),
                if (!controlCondition) ...[
                  SizedBox(height: compact ? 6 : 10),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: ExerciseValidationLabel(exerciseId: exerciseId)),
                ],
                SizedBox(height: compact ? 10 : 14),
                Row(
                  children: [
                    tile('$sets', 'HIỆP'),
                    const SizedBox(width: 10),
                    tile('$repsPerSet', targetLabel, accent: true),
                    const SizedBox(width: 10),
                    tile('${restSeconds}s', 'NGHỈ'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                    controlCondition
                        ? 'Video hướng dẫn · $estimatedMinutes'
                        : 'AI chấm form · $estimatedMinutes',
                    style: Tk.text(13.5,
                        weight: FontWeight.w800, color: Tk.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineVideoCard extends StatefulWidget {
  const _InlineVideoCard({
    required this.asset,
    required this.thumbnail,
    required this.onOpen,
    this.expand = false,
  });

  final String? asset;
  final String? thumbnail;
  final VoidCallback onOpen;
  final bool expand;

  @override
  State<_InlineVideoCard> createState() => _InlineVideoCardState();
}

class _InlineVideoCardState extends State<_InlineVideoCard> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    final asset = widget.asset;
    if (asset != null) unawaited(_load(asset));
  }

  Future<void> _load(String asset) async {
    final controller = VideoPlayerController.asset(asset,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (!mounted) return;
      if (_visible) await controller.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.of(context);
    if (visible == _visible) return;
    _visible = visible;
    final controller = _controller;
    if (!_ready || controller == null) return;
    visible ? controller.play() : controller.pause();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final playing = _ready && controller != null;
    final card = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: Tk.indigo, borderRadius: BorderRadius.circular(22)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.thumbnail != null)
            Image.asset(widget.thumbnail!,
                fit: BoxFit.cover, cacheWidth: 720, excludeFromSemantics: true),
          AnimatedOpacity(
            opacity: playing ? 1 : 0,
            duration: const Duration(milliseconds: 260),
            child: playing
                ? FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: controller.value.size.width,
                      height: controller.value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
              decoration: BoxDecoration(
                color: const Color(0xCC231E5C),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fullscreen_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 4),
                  Text('Xem video mẫu',
                      style: Tk.text(13,
                          weight: FontWeight.w900, color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: 'Xem video mẫu',
      child: GestureDetector(
        onTap: widget.onOpen,
        child: widget.expand
            ? card
            : AspectRatio(aspectRatio: 16 / 9, child: card),
      ),
    );
  }
}
