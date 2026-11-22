import '../services/catalog/catalog_source.dart';
import 'exercise_lookup.dart';

/// Single source of truth for the 24 exercises kept visible for the 2026-11
/// submission, stored in canonical catalog-id space (`catalogId` in
/// `assets/data/exercise_catalog.json` and `id` in Supabase `exercise_catalog`).
///
/// To expose a 25th exercise: add its `catalogId` here (and to
/// [validatedExerciseIds] once its form checking is empirically validated).
const Set<String> keptExerciseIds = {
  'squat',
  'push_up',
  'glute_bridge',
  'plank',
  'lunge',
  'jump_squat',
  'jumping_jack',
  'wall_pushup',
  'situp',
  'leg_raises',
  'vup',
  'mcgill_curlup',
  'dead_bug',
  'bird_dog',
  'mountain_climber',
  'superman',
  'tricep_dip',
  'side_plank_dip',
  'seated_forward_fold',
  'butterfly',
  'sphinx',
  'step_up',
  'neck_side_stretch',
  'pushup_rotation',
};

/// Subset of [keptExerciseIds] whose real-time form checking is validated.
/// Every other kept exercise is surfaced as [ExerciseValidationStatus.countsOnly].
const Set<String> validatedExerciseIds = {
  'squat',
  'push_up',
  'glute_bridge',
  'plank',
};

/// Form-checking validation status for a kept exercise.
enum ExerciseValidationStatus {
  validated('Đã kiểm chứng'),
  countsOnly('Chỉ đếm, chưa kiểm chứng');

  const ExerciseValidationStatus(this.vietnameseLabel);

  /// Quiet user-facing Vietnamese status label.
  final String vietnameseLabel;
}

final Map<String, String> _keptCatalogIdByDefinitionId = {
  for (final catalogId in keptExerciseIds)
    if (lookupExerciseDefinition(catalogId) case final def?) def.id: catalogId,
};

final RegExp _assessmentSuffixPattern = RegExp(
  r'(?:_|\s+)assessment$',
  caseSensitive: false,
);

String? _resolveKeptCatalogId(String rawId) {
  final trimmed = rawId.trim();
  if (trimmed.isEmpty) return null;

  final base = trimmed.replaceFirst(_assessmentSuffixPattern, '').trim();
  if (base.isEmpty) return null;

  final lowerBase = base.toLowerCase();
  if (keptExerciseIds.contains(lowerBase)) return lowerBase;

  final definition = lookupExerciseDefinition(base);
  if (definition != null) {
    return _keptCatalogIdByDefinitionId[definition.id];
  }

  final catalogHit = CatalogSource.instance.lookup(base);
  if (catalogHit != null) {
    return keptExerciseIds.contains(catalogHit.id) ? catalogHit.id : null;
  }

  // Fallback for Vietnamese/English catalog display names when CatalogSource is
  // loaded (e.g. ExerciseIntroPage resolving from a rendered title).
  final normalizedBase = base.toLowerCase();
  for (final catalogId in keptExerciseIds) {
    final info = CatalogSource.instance.lookup(catalogId);
    if (info == null) continue;
    if (info.vietnameseName?.toLowerCase() == normalizedBase ||
        info.englishName?.toLowerCase() == normalizedBase) {
      return catalogId;
    }
  }

  return null;
}

/// Returns true iff [id] (catalog id, definition id, class key, alias, or
/// assessment variant) resolves to one of the 24 [keptExerciseIds].
bool isKeptExercise(String id) => _resolveKeptCatalogId(id) != null;

/// Returns the [ExerciseValidationStatus] for [id] (in any id form), or `null`
/// if [id] is hidden or unknown.
ExerciseValidationStatus? exerciseValidationStatus(String id) {
  final catalogId = _resolveKeptCatalogId(id);
  if (catalogId == null) return null;
  return validatedExerciseIds.contains(catalogId)
      ? ExerciseValidationStatus.validated
      : ExerciseValidationStatus.countsOnly;
}
