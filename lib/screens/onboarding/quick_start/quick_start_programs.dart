/// Curated first sessions for the quick-start goal screen.
///
/// `exerciseIds` are catalog ids (`catalogId` in
/// assets/data/exercise_catalog.json), played in this order as one ad-hoc
/// session. Portrait exercises come first, then landscape ones, so the phone
/// is re-propped at most once per session.
///
/// Only the 21 exercises kept visible for the 2026-11 submission may appear
/// here; test/onboarding/quick_start_test.dart enforces it. Rep and hold
/// targets come from the catalog and the chosen level, never from the numbers
/// attributed to the people or papers named below.
library;

enum QuickGoal { pain, muscle, famous }

class QuickProgram {
  const QuickProgram({
    required this.id,
    required this.goal,
    required this.name,
    required this.note,
    required this.exerciseIds,
  });

  final String id;
  final QuickGoal goal;
  final String name;

  /// One line shown under the exercise list: what the session is based on.
  final String note;
  final List<String> exerciseIds;
}

const quickPrograms = <QuickProgram>[
  // ─── Đau mỏi, giãn cơ ───────────────────────────────────────────────
  QuickProgram(
    id: 'pain_lower_back',
    goal: QuickGoal.pain,
    name: 'Đau mỏi lưng dưới',
    note: 'Bài ổn định cột sống của GS Stuart McGill. Đau dữ dội, tê chân '
        'hoặc sau mổ: hãy đi khám trước.',
    exerciseIds: [
      'mcgill_curlup',
      'bird_dog',
      'side_plank_dip',
      'glute_bridge'
    ],
  ),
  QuickProgram(
    id: 'stretch_lower_body',
    goal: QuickGoal.pain,
    name: 'Giãn cơ thân dưới',
    note: 'Giữ yên 30 giây mỗi tư thế, theo khuyến nghị của ACSM.',
    exerciseIds: ['seated_forward_fold', 'butterfly', 'sphinx'],
  ),

  // ─── Tăng cơ, giảm mỡ ───────────────────────────────────────────────
  QuickProgram(
    id: 'fat_full_body',
    goal: QuickGoal.muscle,
    name: 'Giảm mỡ toàn thân',
    note: 'Xoay vòng nhiều nhóm cơ. Không có bài nào giảm mỡ riêng một vùng.',
    exerciseIds: [
      'jumping_jack',
      'squat',
      'push_up',
      'mountain_climber',
      'plank',
    ],
  ),
  QuickProgram(
    id: 'muscle_legs',
    goal: QuickGoal.muscle,
    name: 'Mông và đùi',
    note: 'Nhóm cơ lớn nhất của cơ thể.',
    exerciseIds: ['squat', 'lunge', 'jump_squat', 'glute_bridge'],
  ),
  QuickProgram(
    id: 'muscle_chest',
    goal: QuickGoal.muscle,
    name: 'Ngực và tay sau',
    note: 'Các động tác đẩy, từ dễ đến khó.',
    exerciseIds: ['wall_pushup', 'push_up', 'tricep_dip'],
  ),
  QuickProgram(
    id: 'muscle_core',
    goal: QuickGoal.muscle,
    name: 'Bụng',
    note: 'Cơ bụng và các cơ giữ vững thân người.',
    exerciseIds: ['situp', 'leg_raises', 'dead_bug', 'plank'],
  ),

  // ─── Bài tập nổi tiếng ──────────────────────────────────────────────
  QuickProgram(
    id: 'famous_ronaldo',
    goal: QuickGoal.famous,
    name: 'Cristiano Ronaldo',
    note: 'Bụng, chân và sức bật theo phong cách của Ronaldo. Không phải lịch '
        'tập chính thức của anh ấy.',
    exerciseIds: ['situp', 'leg_raises', 'jump_squat', 'lunge'],
  ),
  QuickProgram(
    id: 'famous_tyson',
    goal: QuickGoal.famous,
    name: 'Mike Tyson',
    note: 'Bốn động tác trong bài tập không tạ của Mike Tyson.',
    exerciseIds: ['squat', 'push_up', 'tricep_dip', 'situp'],
  ),
  QuickProgram(
    id: 'famous_walker',
    goal: QuickGoal.famous,
    name: 'Herschel Walker',
    note: 'Lấy cảm hứng từ lịch tập không tạ của huyền thoại bóng bầu dục Mỹ.',
    exerciseIds: ['squat', 'push_up', 'situp'],
  ),
  QuickProgram(
    id: 'famous_bruce_lee',
    goal: QuickGoal.famous,
    name: 'Lý Tiểu Long',
    note: 'Lấy cảm hứng từ bài tập bụng trong ghi chép của ông.',
    exerciseIds: ['situp', 'leg_raises', 'vup'],
  ),
  QuickProgram(
    id: 'famous_acsm_7min',
    goal: QuickGoal.famous,
    name: 'Bài 7 phút ACSM',
    note: 'Bài xoay vòng đăng trên tạp chí của Hội Y học Thể thao Mỹ (2013). '
        'Bản rút gọn 8/12 động tác.',
    exerciseIds: [
      'jumping_jack',
      'squat',
      'lunge',
      'push_up',
      'situp',
      'tricep_dip',
      'plank',
      'side_plank_dip',
    ],
  ),
];

const quickProgramMonograms = {
  'famous_ronaldo': 'CR7',
  'famous_tyson': 'MT',
  'famous_walker': 'HW',
  'famous_bruce_lee': 'LTL',
  'famous_acsm_7min': '7′',
};

const quickProgramPortraits = {
  'famous_ronaldo': 'assets/famous/ronaldo.webp',
  'famous_tyson': 'assets/famous/tyson.webp',
  'famous_walker': 'assets/famous/walker.webp',
  'famous_bruce_lee': 'assets/famous/bruce_lee.webp',
};

List<QuickProgram> programsFor(QuickGoal goal) => [
      for (final p in quickPrograms)
        if (p.goal == goal) p
    ];

/// Level keys match `profiles.fitness_level`.
const quickLevels = ['beginner', 'intermediate', 'advanced'];

const quickMinAge = 16;
const quickMaxAge = 80;
const quickDefaultAge = 28;

/// Level preselected on the goal screen. A starting point the user can
/// override, not a medical rule: the pain branch and the youngest and oldest
/// users start light, and the hardest level is never suggested.
String recommendedLevel({required int age, required QuickGoal goal}) {
  if (goal == QuickGoal.pain || age < 18 || age >= 50) return 'beginner';
  return 'intermediate';
}

/// Sets per exercise in the first session.
int setsForLevel(String level) => switch (level) {
      'advanced' => 3,
      'intermediate' => 2,
      _ => 1,
    };
