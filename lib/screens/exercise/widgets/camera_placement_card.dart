import 'package:flutter/material.dart';

import '../../../models/exercise_lookup.dart';
import '../../../pose/vika_image_orientation.dart';
import '../../../services/catalog/catalog_source.dart';
import '../../../widgets/tk/tk.dart';

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
        PhonePlacementOrientation.portrait =>
          Icons.stay_current_portrait_rounded,
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

const String kOnePlacementWhere = 'Máy ngang · cao 60–70 cm · cách ~3 m';
const String kGeneralSafetyReminder =
    'Dọn chỗ trống khoảng 2 × 2 m, sàn không trơn. Dừng ngay nếu đau nhói, '
    'chóng mặt hoặc khó thở. Đang điều trị bệnh tim hay chấn thương thì hỏi '
    'bác sĩ trước khi tập.';
const String kJumpPlacementWhere =
    'Máy ngang · cao 60–70 cm · lùi ~3,5 m, chừa chỗ trên đầu';

const Map<String, ExercisePlacementSpec> kExercisePlacementByCatalogId =
    <String, ExercisePlacementSpec>{
  'squat': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.standing,
    placementWhere: kOnePlacementWhere,
  ),
  'push_up': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
    placementWhere: kOnePlacementWhere,
  ),
  'glute_bridge': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
    placementWhere: kOnePlacementWhere,
  ),
  'plank': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
    placementWhere: kOnePlacementWhere,
  ),
  'lunge': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.standing,
    placementWhere: kOnePlacementWhere,
  ),
  'jump_squat': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.standing,
    placementWhere: kJumpPlacementWhere,
  ),
  'jumping_jack': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.facingCamera,
    posture: PlacementPostureGlyph.standing,
    placementWhere: kJumpPlacementWhere,
  ),
  'wall_pushup': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.standing,
    placementWhere: kOnePlacementWhere,
  ),
  'situp': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
    placementWhere: kOnePlacementWhere,
  ),
  'leg_raises': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
    placementWhere: kOnePlacementWhere,
  ),
  'vup': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
    placementWhere: kOnePlacementWhere,
  ),
  'mcgill_curlup': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
    placementWhere: kOnePlacementWhere,
  ),
  'dead_bug': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
    placementWhere: kOnePlacementWhere,
  ),
  'bird_dog': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
    placementWhere: kOnePlacementWhere,
  ),
  'mountain_climber': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
    placementWhere: kOnePlacementWhere,
  ),
  'superman': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
    placementWhere: kOnePlacementWhere,
  ),
  'tricep_dip': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.seated,
    placementWhere: kOnePlacementWhere,
  ),
  'side_plank_dip': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
    placementWhere: kOnePlacementWhere,
  ),
  'seated_forward_fold': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.seated,
    placementWhere: kOnePlacementWhere,
  ),
  'butterfly': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.facingCamera,
    posture: PlacementPostureGlyph.seated,
    placementWhere: kOnePlacementWhere,
  ),
  'sphinx': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
    placementWhere: kOnePlacementWhere,
  ),
  'step_up': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.standing,
    placementWhere: kOnePlacementWhere,
  ),
  'neck_side_stretch': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.facingCamera,
    posture: PlacementPostureGlyph.standing,
    placementWhere: kOnePlacementWhere,
  ),
  'pushup_rotation': ExercisePlacementSpec(
    orientation: PhonePlacementOrientation.landscape,
    view: UserCameraView.sideOn,
    posture: PlacementPostureGlyph.floor,
    placementWhere: kOnePlacementWhere,
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
    final warning = safetyWarning?.trim();
    final transition = transitionNotice;
    return TkCard(
      lip: false,
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (transition != null && transition.requiresAction) ...[
            _Note(
              icon: transition.phoneRotated
                  ? Icons.screen_rotation_alt_rounded
                  : Icons.sync_alt_rounded,
              text: transition.message,
              color: Tk.orangeSoft,
              ink: Tk.orangeInk,
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Tk.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(spec.orientation.icon, color: Tk.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.placementWhere ?? spec.orientation.vietnameseLabel,
                      style: Tk.text(15, weight: FontWeight.w900, height: 1.3),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spec.view.vietnameseLabel,
                      style: Tk.text(13.5,
                          weight: FontWeight.w700, color: Tk.inkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (warning != null && warning.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Note(
              icon: Icons.warning_amber_rounded,
              text: warning,
              color: const Color(0xFFFDECEC),
              ink: Tk.redInk,
            ),
          ],
          const SizedBox(height: 12),
          _Note(
            icon: Icons.health_and_safety_rounded,
            text: kGeneralSafetyReminder,
            color: Tk.orangeSoft,
            ink: Tk.orangeInk,
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({
    required this.icon,
    required this.text,
    required this.color,
    required this.ink,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: ink),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Tk.text(13,
                  weight: FontWeight.w800, color: Tk.ink, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
