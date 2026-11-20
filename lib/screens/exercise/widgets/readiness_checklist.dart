import 'package:flutter/material.dart';

import '../../../exercise/exercise_base.dart';
import '../../../theme/vf_theme.dart';

/// One of the four live pre-activation camera readiness checks.
enum ReadinessCheckLine {
  bodyInFrame('Giữ toàn thân trong khung'),
  viewAndOrientation('Đúng chiều máy và góc nhìn'),
  lighting('Đủ ánh sáng'),
  startPosition('Vào tư thế đầu, giữ yên');

  const ReadinessCheckLine(this.vietnameseLabel);

  final String vietnameseLabel;
}

/// Evaluation state of a single readiness line for the current frame.
enum ReadinessCheckStatus {
  /// Upstream gate blocked before this check could be verified.
  pending,

  /// The current `GuidanceSignal` directly names this condition as unmet.
  blocker,

  /// Verified as satisfied on this frame.
  met;

  bool get isMet => this == ReadinessCheckStatus.met;
}

/// Immutable O(1) snapshot of all four readiness lines derived solely from
/// the exercise's published `GuidanceSignal`.
class ReadinessChecklistSnapshot {
  const ReadinessChecklistSnapshot({
    required this.bodyInFrame,
    required this.viewAndOrientation,
    required this.lighting,
    required this.startPosition,
  });

  final ReadinessCheckStatus bodyInFrame;
  final ReadinessCheckStatus viewAndOrientation;
  final ReadinessCheckStatus lighting;
  final ReadinessCheckStatus startPosition;

  ReadinessCheckStatus statusFor(ReadinessCheckLine line) => switch (line) {
        ReadinessCheckLine.bodyInFrame => bodyInFrame,
        ReadinessCheckLine.viewAndOrientation => viewAndOrientation,
        ReadinessCheckLine.lighting => lighting,
        ReadinessCheckLine.startPosition => startPosition,
      };

  static const _allPending = ReadinessChecklistSnapshot(
    bodyInFrame: ReadinessCheckStatus.pending,
    viewAndOrientation: ReadinessCheckStatus.pending,
    lighting: ReadinessCheckStatus.pending,
    startPosition: ReadinessCheckStatus.pending,
  );

  static const _viewBlocked = ReadinessChecklistSnapshot(
    bodyInFrame: ReadinessCheckStatus.pending,
    viewAndOrientation: ReadinessCheckStatus.blocker,
    lighting: ReadinessCheckStatus.pending,
    startPosition: ReadinessCheckStatus.pending,
  );

  static const _bodyBlockedBeforeView = ReadinessChecklistSnapshot(
    bodyInFrame: ReadinessCheckStatus.blocker,
    viewAndOrientation: ReadinessCheckStatus.pending,
    lighting: ReadinessCheckStatus.pending,
    startPosition: ReadinessCheckStatus.pending,
  );

  static const _bodyBlockedAfterView = ReadinessChecklistSnapshot(
    bodyInFrame: ReadinessCheckStatus.blocker,
    viewAndOrientation: ReadinessCheckStatus.met,
    lighting: ReadinessCheckStatus.pending,
    startPosition: ReadinessCheckStatus.pending,
  );

  static const _lightingBlocked = ReadinessChecklistSnapshot(
    bodyInFrame: ReadinessCheckStatus.met,
    viewAndOrientation: ReadinessCheckStatus.met,
    lighting: ReadinessCheckStatus.blocker,
    startPosition: ReadinessCheckStatus.pending,
  );

  static const _startPoseBlocked = ReadinessChecklistSnapshot(
    bodyInFrame: ReadinessCheckStatus.met,
    viewAndOrientation: ReadinessCheckStatus.met,
    lighting: ReadinessCheckStatus.met,
    startPosition: ReadinessCheckStatus.blocker,
  );

  static const _holdingStartPose = ReadinessChecklistSnapshot(
    bodyInFrame: ReadinessCheckStatus.met,
    viewAndOrientation: ReadinessCheckStatus.met,
    lighting: ReadinessCheckStatus.met,
    startPosition: ReadinessCheckStatus.met,
  );

  /// Maps the published [GuidanceSignal] (and whether a skeleton was present on
  /// this frame) to the four checklist statuses without heap allocation.
  static ReadinessChecklistSnapshot fromSignal(
    GuidanceSignal? signal, {
    bool hasPose = true,
  }) {
    if (signal == null) return _allPending;
    return switch (signal.kind) {
      GuidanceClass.phoneLandscape ||
      GuidanceClass.phonePortrait ||
      GuidanceClass.turnSide ||
      GuidanceClass.faceCamera =>
        _viewBlocked,
      GuidanceClass.searching || GuidanceClass.paused => _bodyBlockedBeforeView,
      GuidanceClass.bodyInFrame =>
        hasPose ? _bodyBlockedAfterView : _bodyBlockedBeforeView,
      GuidanceClass.lighting => _lightingBlocked,
      GuidanceClass.setupPosition || GuidanceClass.resume => _startPoseBlocked,
      GuidanceClass.holdStill => _holdingStartPose,
    };
  }
}

/// Live camera readiness checklist shown on `ActiveExercisePage` while the
/// exercise is not yet activated (including post-pause re-hold).
class ReadinessChecklist extends StatelessWidget {
  const ReadinessChecklist({
    super.key,
    required this.signal,
    this.hasPose = true,
    this.compact = false,
  });

  final GuidanceSignal? signal;
  final bool hasPose;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final snapshot = ReadinessChecklistSnapshot.fromSignal(
      signal,
      hasPose: hasPose,
    );
    final mq = MediaQuery.of(context);
    final clampedScaler = mq.textScaler.clamp(
      minScaleFactor: 0.92,
      maxScaleFactor: compact ? 1.06 : 1.15,
    );

    return MediaQuery(
      data: mq.copyWith(textScaler: clampedScaler),
      child: RepaintBoundary(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? 192 : 336),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 13,
              vertical: compact ? 6 : 10,
            ),
            decoration: BoxDecoration(
              color: VikaIvory.heroBg.withValues(alpha: 0.84),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: VikaIvory.glassBorderHi),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < ReadinessCheckLine.values.length; i++) ...[
                  if (i > 0) SizedBox(height: compact ? 3 : 5),
                  ReadinessCheckRow(
                    key: ValueKey<ReadinessCheckLine>(
                      ReadinessCheckLine.values[i],
                    ),
                    line: ReadinessCheckLine.values[i],
                    status: snapshot.statusFor(ReadinessCheckLine.values[i]),
                    compact: compact,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Single line inside [ReadinessChecklist]. Exposed for widget-test inspection.
class ReadinessCheckRow extends StatelessWidget {
  const ReadinessCheckRow({
    super.key,
    required this.line,
    required this.status,
    this.compact = false,
  });

  final ReadinessCheckLine line;
  final ReadinessCheckStatus status;
  final bool compact;

  bool get isMet => status.isMet;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color iconColor, Color textColor, FontWeight weight) =
        switch (status) {
      ReadinessCheckStatus.met => (
          Icons.check_circle_rounded,
          VikaIvory.live,
          VikaIvory.invInk,
          FontWeight.w700,
        ),
      ReadinessCheckStatus.blocker => (
          Icons.error_outline_rounded,
          VikaIvory.yellow,
          VikaIvory.yellow,
          FontWeight.w700,
        ),
      ReadinessCheckStatus.pending => (
          Icons.radio_button_unchecked_rounded,
          VikaIvory.invInkDim,
          VikaIvory.invInkSoft,
          FontWeight.w500,
        ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: compact ? 14 : 16, color: iconColor),
        ),
        SizedBox(width: compact ? 7 : 8),
        Expanded(
          child: Text(
            line.vietnameseLabel,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: VikaIvory.fontFamily,
              fontSize: compact ? 10.5 : 12.5,
              fontWeight: weight,
              height: 1.2,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}
