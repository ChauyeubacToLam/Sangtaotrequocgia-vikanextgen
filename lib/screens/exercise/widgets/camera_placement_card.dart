import 'package:flutter/material.dart';

import '../../../models/exercise_lookup.dart';
import '../../../pose/vika_image_orientation.dart';
import '../../../services/catalog/catalog_source.dart';
import '../../../theme/app_colors.dart';

/// Required phone orientation derived from `ExerciseBase.supportedOrientations`.
enum PhonePlacementOrientation {
  portrait,
  landscape,
  portraitOrLandscape;

  Set<VikaImageOrientation> get supportedOrientations => switch (this) {
        PhonePlacementOrientation.portrait => const <VikaImageOrientation>{
            VikaImageOrientation.portrait,
          },
        PhonePlacementOrientation.landscape => const <VikaImageOrientation>{
            VikaImageOrientation.landscapeLeft,
            VikaImageOrientation.landscapeRight,
          },
        PhonePlacementOrientation.portraitOrLandscape =>
          const <VikaImageOrientation>{
            VikaImageOrientation.portrait,
            VikaImageOrientation.landscapeLeft,
            VikaImageOrientation.landscapeRight,
          },
      };

  String get vietnameseLabel => switch (this) {
        PhonePlacementOrientation.portrait => 'Đặt điện thoại dọc',
        PhonePlacementOrientation.landscape => 'Đặt điện thoại ngang',
        PhonePlacementOrientation.portraitOrLandscape =>
          'Đặt máy dọc hoặc ngang',
      };

  IconData get icon => switch (this) {
        PhonePlacementOrientation.portrait => Icons.stay_current_portrait_rounded,
        PhonePlacementOrientation.landscape =>
          Icons.stay_current_landscape_rounded,
        PhonePlacementOrientation.portraitOrLandscape =>
          Icons.screen_rotation_rounded,
      };
}

/// Required user angle to the camera derived from `checkSafety` and start gates.
enum UserCameraView {
  sideOn,
  facingCamera;

  String get vietnameseLabel => switch (this) {
        UserCameraView.sideOn => 'Quay nghiêng người với máy',
        UserCameraView.facingCamera => 'Quay mặt đối diện máy',
      };

  IconData get icon => switch (this) {
        UserCameraView.sideOn => Icons.accessibility_new_rounded,
        UserCameraView.facingCamera => Icons.center_focus_strong_rounded,
      };
}

/// Gross body posture drawn in the placement diagram.
enum PlacementPostureGlyph {
  standing,
  floor,
  seated,
}

/// Camera placement facts for one exercise.
class ExercisePlacementSpec {
  const ExercisePlacementSpec({
    required this.orientation,
    required this.view,
    required this.posture,
    this.bodyFraming = 'Thấy trọn từ đầu đến chân',
    this.placementWhere,
  });

  final PhonePlacementOrientation orientation;
  final UserCameraView view;
  final PlacementPostureGlyph posture;
  final String bodyFraming;

  /// Concrete phone height/distance from existing exercise copy, when present.
  final String? placementWhere;
}

/// Single source of camera-placement facts for the 21 kept exercises, keyed by
/// canonical `catalogId` (`keptExerciseIds`).
///
/// Orientation and view come from each exercise class's `supportedOrientations`,
/// `checkSafety`, and `isInStartPosition`. `placementWhere` carries concrete
/// height/distance phrases from `exercise_definition.dart` without inventing
/// numbers where the copy gives none.
const Map<String, ExercisePlacementSpec> kExercisePlacementByCatalogId =
    <String, ExercisePlacementSpec>{
  'squat': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.portrait,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.standing,
    placementWhere: 'Máy ngang hông · cách 2–3 m',
  ),
  'push_up': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
    placementWhere: 'Đặt máy thấp ngang thân',
  ),
  'glute_bridge': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
    placementWhere: 'Thấp ngang thân · cao 30–50 cm',
  ),
  'plank': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
    placementWhere: 'Đặt máy thấp ngang thân',
  ),
  'lunge': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.portrait,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.standing,
    placementWhere: 'Máy ngang hông · cách 2–3 m',
  ),
  'jump_squat': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.portrait,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.standing,
  ),
  'jumping_jack': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.portrait,
    view: UserCameraView.facingCamera,
    posture: PlacementPostureGlyph.standing,
    placementWhere: 'Lùi xa, chừa khoảng trống trên đầu',
  ),
  'wall_pushup': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.portrait,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.standing,
  ),
  'situp': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
    placementWhere: 'Thấp ngang thân · cao 30–50 cm',
  ),
  'leg_raises': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
    placementWhere: 'Thấp ngang thân · cao 30–50 cm',
  ),
  'vup': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
    placementWhere: 'Thấp ngang thân · cao 30–50 cm',
  ),
  'mcgill_curlup': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
    placementWhere: 'Đặt máy thấp ngang thân',
  ),
  'dead_bug': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
    placementWhere: 'Thấp ngang thân · cao 30–50 cm',
  ),
  'bird_dog': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
    placementWhere: 'Thấp ngang thân · cao 30–50 cm',
  ),
  'mountain_climber': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
    placementWhere: 'Thấp ngang thân · cao 30–50 cm',
  ),
  'superman': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
    placementWhere: 'Thấp ngang thân · cao 30–50 cm',
  ),
  'tricep_dip': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.seated,
  ),
  'side_plank_dip': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.portraitOrLandscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
  ),
  'seated_forward_fold': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.seated,
    placementWhere: 'Đặt máy ngang hông',
  ),
  'butterfly': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.portraitOrLandscape,
    view: UserCameraView.facingCamera,
    posture: PlacementPostureGlyph.seated,
  ),
  'sphinx': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
    placementWhere: 'Đặt máy thấp ngang thân',
  ),
};

final RegExp _assessmentSuffix = RegExp(
  r'(?:_|\s+)assessment$',
  caseSensitive: false,
);

final Map<String, String> _catalogIdByDefinitionId = <String, String>{
  for (final catalogId in kExercisePlacementByCatalogId.keys)
    if (lookupExerciseDefinition(catalogId) case final def?) def.id: catalogId,
};

/// Resolves canonical `catalogId` for any kept exercise id, definition id,
/// catalog display name, or assessment variant; returns `null` when unknown or
/// hidden.
String? resolvePlacementCatalogId(String? rawId) {
  if (rawId == null) return null;
  final trimmed = rawId.trim();
  if (trimmed.isEmpty) return null;
  final base = trimmed.replaceFirst(_assessmentSuffix, '').trim();
  if (base.isEmpty) return null;

  final lower = base.toLowerCase();
  if (kExercisePlacementByCatalogId.containsKey(lower)) return lower;

  final def = lookupExerciseDefinition(base);
  if (def != null) {
    return _catalogIdByDefinitionId[def.id];
  }

  final catalogHit = CatalogSource.instance.lookup(base);
  if (catalogHit != null) {
    return kExercisePlacementByCatalogId.containsKey(catalogHit.id)
        ? catalogHit.id
        : null;
  }

  for (final catalogId in kExercisePlacementByCatalogId.keys) {
    final info = CatalogSource.instance.lookup(catalogId);
    if (info == null) continue;
    if (info.vietnameseName?.toLowerCase() == lower ||
        info.englishName?.toLowerCase() == lower) {
      return catalogId;
    }
  }
  return null;
}

/// Looks up the [ExercisePlacementSpec] for [rawId].
ExercisePlacementSpec? lookupExercisePlacement(String? rawId) {
  final catalogId = resolvePlacementCatalogId(rawId);
  if (catalogId == null) return null;
  return kExercisePlacementByCatalogId[catalogId];
}

/// Transition notice comparing the current exercise's setup with the previous
/// exercise in a multi-exercise sequence.
class PlacementTransitionNotice {
  const PlacementTransitionNotice({
    required this.message,
    required this.requiresAction,
    required this.phoneRotated,
  });

  final String message;
  final bool requiresAction;
  final bool phoneRotated;
}

/// Computes the plain Vietnamese setup-change callout between consecutive
/// exercises in a workout sequence.
PlacementTransitionNotice? computePlacementTransition({
  required ExercisePlacementSpec current,
  List<String> sequenceExerciseIds = const <String>[],
  int sequenceIndex = 0,
  String? previousExerciseId,
}) {
  ExercisePlacementSpec? previous;
  var phoneWasLandscape = false;

  if (sequenceIndex > 0 && sequenceIndex <= sequenceExerciseIds.length) {
    for (var i = 0; i < sequenceIndex; i++) {
      final spec = lookupExercisePlacement(sequenceExerciseIds[i]);
      if (spec == null) continue;
      previous = spec;
      if (spec.orientation == PhonePlacementOrientation.landscape) {
        phoneWasLandscape = true;
      } else if (spec.orientation == PhonePlacementOrientation.portrait) {
        phoneWasLandscape = false;
      }
    }
  } else if (previousExerciseId != null) {
    previous = lookupExercisePlacement(previousExerciseId);
    if (previous != null) {
      phoneWasLandscape =
          previous.orientation == PhonePlacementOrientation.landscape;
    }
  }

  if (previous == null) return null;

  final turnToLandscape = !phoneWasLandscape &&
      current.orientation == PhonePlacementOrientation.landscape;
  final turnToPortrait = phoneWasLandscape &&
      current.orientation == PhonePlacementOrientation.portrait;
  final phoneRotated = turnToLandscape || turnToPortrait;

  final phoneText = turnToLandscape
      ? 'Xoay ngang điện thoại'
      : turnToPortrait
          ? 'Xoay dọc điện thoại'
          : 'Giữ nguyên vị trí máy';

  final userTurned = previous.view != current.view;
  final userText = userTurned
      ? (current.view == UserCameraView.sideOn
          ? 'Quay nghiêng người'
          : 'Quay mặt về camera')
      : null;

  final message = userText != null ? '$phoneText · $userText' : phoneText;
  return PlacementTransitionNotice(
    message: message,
    requiresAction: phoneRotated || userTurned,
    phoneRotated: phoneRotated,
  );
}

/// Compact camera & body placement card rendered on `ExerciseIntroPage` before
/// each exercise starts.
class CameraPlacementCard extends StatelessWidget {
  const CameraPlacementCard({
    super.key,
    required this.spec,
    this.safetyWarning,
    this.transitionNotice,
  });

  final ExercisePlacementSpec spec;
  final String? safetyWarning;
  final PlacementTransitionNotice? transitionNotice;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final warning = safetyWarning?.trim();
    final hasWarning = warning != null && warning.isNotEmpty;
    final transition = transitionNotice;

    return Container(
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (transition != null) _TransitionStrip(notice: transition),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _PlacementDiagramTile(spec: spec),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PlacementFactRow(
                        icon: spec.orientation.icon,
                        text: spec.orientation.vietnameseLabel,
                        emphasized: true,
                      ),
                      const SizedBox(height: 6),
                      _PlacementFactRow(
                        icon: spec.view.icon,
                        text: spec.view.vietnameseLabel,
                        emphasized: true,
                      ),
                      const SizedBox(height: 6),
                      _PlacementFactRow(
                        icon: Icons.crop_free_rounded,
                        text: spec.bodyFraming,
                      ),
                      if (spec.placementWhere != null) ...[
                        const SizedBox(height: 6),
                        _PlacementFactRow(
                          icon: Icons.straighten_rounded,
                          text: spec.placementWhere!,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (hasWarning) _SafetyWarningStrip(warning: warning),
        ],
      ),
    );
  }
}

class _TransitionStrip extends StatelessWidget {
  const _TransitionStrip({required this.notice});

  final PlacementTransitionNotice notice;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final bg = notice.requiresAction ? c.yellowGhost : c.powder;
    final iconColor = notice.requiresAction ? c.yellowInk : c.inkSoft;
    final icon = notice.phoneRotated
        ? Icons.screen_rotation_alt_rounded
        : notice.requiresAction
            ? Icons.sync_alt_rounded
            : Icons.check_circle_outline_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(
            color: notice.requiresAction
                ? c.yellow.withValues(alpha: 0.45)
                : c.border,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              notice.message,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.25,
                color: c.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlacementFactRow extends StatelessWidget {
  const _PlacementFactRow({
    required this.icon,
    required this.text,
    this.emphasized = false,
  });

  final IconData icon;
  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1.5),
          child: Icon(
            icon,
            size: 15,
            color: emphasized ? c.ink : c.inkSoft,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 12.5,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
              height: 1.3,
              color: emphasized ? c.ink : c.inkSoft,
            ),
          ),
        ),
      ],
    );
  }
}

class _SafetyWarningStrip extends StatelessWidget {
  const _SafetyWarningStrip({required this.warning});

  final String warning;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
      decoration: BoxDecoration(
        color: c.attention.withValues(alpha: 0.10),
        border: Border(
          top: BorderSide(color: c.attention.withValues(alpha: 0.30)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: c.attention,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              warning,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: c.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlacementDiagramTile extends StatelessWidget {
  const _PlacementDiagramTile({required this.spec});

  final ExercisePlacementSpec spec;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      width: 88,
      height: 84,
      decoration: BoxDecoration(
        color: c.bgInverse,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: c.borderDark),
      ),
      child: CustomPaint(
        painter: _PlacementDiagramPainter(
          spec: spec,
          phoneColor: c.yellow,
          personColor: c.invInk,
          guideColor: c.invInkFaint,
        ),
      ),
    );
  }
}

class _PlacementDiagramPainter extends CustomPainter {
  const _PlacementDiagramPainter({
    required this.spec,
    required this.phoneColor,
    required this.personColor,
    required this.guideColor,
  });

  final ExercisePlacementSpec spec;
  final Color phoneColor;
  final Color personColor;
  final Color guideColor;

  @override
  void paint(Canvas canvas, Size size) {
    final phonePaint = Paint()
      ..color = phoneColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final phoneFill = Paint()
      ..color = phoneColor.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    final guidePaint = Paint()
      ..color = guideColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final personStroke = Paint()
      ..color = personColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final personHead = Paint()
      ..color = personColor
      ..style = PaintingStyle.fill;

    // 1. Floor baseline
    final floorY = size.height - 13;
    canvas.drawLine(
      Offset(8, floorY),
      Offset(size.width - 8, floorY),
      guidePaint,
    );

    // 2. Phone glyph on the left (raised to hip height for standing exercises,
    // resting low near the floor for floor/seated exercises).
    final standingPhone = spec.posture == PlacementPostureGlyph.standing &&
        spec.orientation == PhonePlacementOrientation.portrait;
    final Rect phoneRect = switch (spec.orientation) {
      PhonePlacementOrientation.portrait => standingPhone
          ? Rect.fromLTWH(10, floorY - 38, 13, 24)
          : Rect.fromLTWH(10, floorY - 26, 13, 24),
      PhonePlacementOrientation.landscape =>
          Rect.fromLTWH(8, floorY - 15, 22, 13),
      PhonePlacementOrientation.portraitOrLandscape =>
          Rect.fromLTWH(10, floorY - 25, 13, 23),
    };
    if (standingPhone) {
      canvas.drawLine(
        Offset(phoneRect.center.dx, phoneRect.bottom + 1),
        Offset(phoneRect.center.dx, floorY),
        guidePaint,
      );
      canvas.drawLine(
        Offset(phoneRect.left + 1, floorY),
        Offset(phoneRect.right - 1, floorY),
        guidePaint,
      );
    }
    final phoneRRect =
        RRect.fromRectAndRadius(phoneRect, const Radius.circular(3));
    canvas.drawRRect(phoneRRect, phoneFill);
    canvas.drawRRect(phoneRRect, phonePaint);

    if (spec.orientation == PhonePlacementOrientation.portraitOrLandscape) {
      final altRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(8, floorY - 14, 21, 12),
        const Radius.circular(2.5),
      );
      canvas.drawRRect(
        altRect,
        Paint()
          ..color = phoneColor.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    // 3. Camera field-of-view rays toward the framing box
    final lensOrigin = Offset(phoneRect.right + 2, phoneRect.center.dy);
    const frameLeft = 39.0;
    final frameRight = size.width - 9;
    const frameTop = 12.0;
    final frameBottom = floorY - 2;

    final rayPaint = Paint()
      ..color = phoneColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(lensOrigin, Offset(frameLeft, frameTop + 4), rayPaint);
    canvas.drawLine(lensOrigin, Offset(frameLeft, frameBottom - 2), rayPaint);

    // 4. Corner brackets showing whole-body framing (head to feet)
    const corner = 5.0;
    // Top-left
    canvas.drawLine(Offset(frameLeft, frameTop + corner),
        Offset(frameLeft, frameTop), guidePaint);
    canvas.drawLine(Offset(frameLeft, frameTop),
        Offset(frameLeft + corner, frameTop), guidePaint);
    // Top-right
    canvas.drawLine(Offset(frameRight - corner, frameTop),
        Offset(frameRight, frameTop), guidePaint);
    canvas.drawLine(Offset(frameRight, frameTop),
        Offset(frameRight, frameTop + corner), guidePaint);
    // Bottom-left
    canvas.drawLine(Offset(frameLeft, frameBottom - corner),
        Offset(frameLeft, frameBottom), guidePaint);
    canvas.drawLine(Offset(frameLeft, frameBottom),
        Offset(frameLeft + corner, frameBottom), guidePaint);
    // Bottom-right
    canvas.drawLine(Offset(frameRight - corner, frameBottom),
        Offset(frameRight, frameBottom), guidePaint);
    canvas.drawLine(Offset(frameRight, frameBottom),
        Offset(frameRight, frameBottom - corner), guidePaint);

    // 5. Person silhouette inside the frame
    final cx = (frameLeft + frameRight) / 2;
    switch ((spec.posture, spec.view)) {
      case (PlacementPostureGlyph.standing, UserCameraView.facingCamera):
        // Front-facing standing figure (both arms and legs open)
        canvas.drawCircle(Offset(cx, 21), 3.6, personHead);
        canvas.drawLine(Offset(cx, 25), Offset(cx, 44), personStroke);
        canvas.drawLine(Offset(cx - 10, 32), Offset(cx + 10, 32), personStroke);
        canvas.drawLine(Offset(cx, 44), Offset(cx - 7, 65), personStroke);
        canvas.drawLine(Offset(cx, 44), Offset(cx + 7, 65), personStroke);
      case (PlacementPostureGlyph.standing, UserCameraView.sideOn):
        // Side-profile standing figure (facing toward left/camera with nose/arm)
        canvas.drawCircle(Offset(cx, 21), 3.6, personHead);
        canvas.drawLine(Offset(cx, 25), Offset(cx + 1, 45), personStroke);
        canvas.drawLine(Offset(cx, 29), Offset(cx - 8, 37), personStroke);
        canvas.drawLine(Offset(cx + 1, 45), Offset(cx - 3, 55), personStroke);
        canvas.drawLine(Offset(cx - 3, 55), Offset(cx - 1, 65), personStroke);
        canvas.drawLine(Offset(cx - 1, 65), Offset(cx - 5, 65), personStroke);
      case (PlacementPostureGlyph.floor, _):
        // Side-profile floor plank/supine figure spanning head-to-feet
        canvas.drawCircle(Offset(frameLeft + 8, floorY - 16), 3.3, personHead);
        canvas.drawLine(
          Offset(frameLeft + 12, floorY - 15),
          Offset(frameRight - 6, floorY - 8),
          personStroke,
        );
        canvas.drawLine(
          Offset(frameLeft + 14, floorY - 14),
          Offset(frameLeft + 14, floorY - 3),
          personStroke,
        );
        canvas.drawLine(
          Offset(frameRight - 6, floorY - 8),
          Offset(frameRight - 6, floorY - 3),
          personStroke,
        );
      case (PlacementPostureGlyph.seated, UserCameraView.facingCamera):
        // Seated front-facing butterfly figure
        canvas.drawCircle(Offset(cx, 31), 3.5, personHead);
        canvas.drawLine(Offset(cx, 35), Offset(cx, 54), personStroke);
        canvas.drawLine(Offset(cx - 8, 43), Offset(cx, 54), personStroke);
        canvas.drawLine(Offset(cx + 8, 43), Offset(cx, 54), personStroke);
        canvas.drawLine(Offset(cx, 54), Offset(cx - 11, 61), personStroke);
        canvas.drawLine(Offset(cx, 54), Offset(cx + 11, 61), personStroke);
        canvas.drawLine(Offset(cx - 11, 61), Offset(cx, 65), personStroke);
        canvas.drawLine(Offset(cx + 11, 61), Offset(cx, 65), personStroke);
      case (PlacementPostureGlyph.seated, UserCameraView.sideOn):
        // Seated side-profile figure with legs extended horizontally
        canvas.drawCircle(Offset(frameLeft + 10, 36), 3.4, personHead);
        canvas.drawLine(
          Offset(frameLeft + 10, 40),
          Offset(frameLeft + 12, floorY - 4),
          personStroke,
        );
        canvas.drawLine(
          Offset(frameLeft + 12, floorY - 4),
          Offset(frameRight - 6, floorY - 4),
          personStroke,
        );
        canvas.drawLine(
          Offset(frameLeft + 11, 46),
          Offset(frameLeft + 22, 52),
          personStroke,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _PlacementDiagramPainter oldDelegate) {
    return oldDelegate.spec != spec ||
        oldDelegate.phoneColor != phoneColor ||
        oldDelegate.personColor != personColor ||
        oldDelegate.guideColor != guideColor;
  }
}
