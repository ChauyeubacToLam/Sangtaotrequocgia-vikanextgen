import 'package:flutter/material.dart';

import 'package:vika/services/catalog/catalog_source.dart';

import '../v5/v5_primitives.dart';
import '../v5/v5_theme.dart';
import 'quick_start_programs.dart';

/// B2 of the quick start: goal, program, age and intensity on one screen.
///
/// Before a goal is picked it shows three large cards. Picking one folds them
/// into a tab strip and reveals that goal's programs and the intensity block.
/// The intensity is preselected from age and goal, so the shortest path is
/// goal, program, continue.
class QuickStartGoalScreen extends StatelessWidget {
  const QuickStartGoalScreen({
    super.key,
    required this.goal,
    required this.program,
    required this.age,
    required this.level,
    required this.onGoal,
    required this.onProgram,
    required this.onAge,
    required this.onLevel,
    required this.onNext,
  });

  final QuickGoal? goal;
  final QuickProgram? program;
  final int age;

  /// The user's own pick. Null means "follow the recommendation".
  final String? level;

  final ValueChanged<QuickGoal> onGoal;
  final ValueChanged<QuickProgram> onProgram;
  final ValueChanged<int> onAge;
  final ValueChanged<String> onLevel;
  final VoidCallback onNext;

  static const _goals = [
    (
      QuickGoal.pain,
      'Đau mỏi, giãn cơ',
      'Tập nhẹ cho lưng và giãn cơ',
      'Đau mỏi',
      Icons.self_improvement_rounded,
    ),
    (
      QuickGoal.muscle,
      'Tăng cơ, giảm mỡ',
      'Chọn nhóm cơ hoặc đốt mỡ toàn thân',
      'Cơ · mỡ',
      Icons.fitness_center_rounded,
    ),
    (
      QuickGoal.famous,
      'Bài tập nổi tiếng',
      'Tập theo người và giáo trình có tiếng',
      'Nổi tiếng',
      Icons.emoji_events_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final picked = goal;
    return V5Page(
      index: 2,
      total: 3,
      scroll: true,
      cta: picked == null
          ? null
          : V5PillCTA(
              label: 'Tiếp tục',
              disabledLabel: 'Chọn một bài để tiếp',
              enabled: program != null,
              onTap: onNext,
            ),
      child: picked == null ? _cards(context) : _picker(context, picked),
    );
  }

  Widget _cards(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const V5ScreenHeader(
          eyebrow: 'Bước 2/3',
          title: 'Hôm nay bạn\nmuốn tập gì?',
        ),
        const SizedBox(height: V5.space24),
        for (var i = 0; i < _goals.length; i++) ...[
          V5FadeIn(
            delay: Duration(milliseconds: 80 * i),
            slideY: 6,
            child: _GoalCard(
              icon: _goals[i].$5,
              title: _goals[i].$2,
              sub: _goals[i].$3,
              onTap: () => onGoal(_goals[i].$1),
            ),
          ),
          const SizedBox(height: V5.space12),
        ],
      ],
    );
  }

  Widget _picker(BuildContext context, QuickGoal picked) {
    final recommended = recommendedLevel(age: age, goal: picked);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // No headline here: the tab strip names the choice, and the space
        // keeps the intensity block on screen without scrolling.
        const V5Eyebrow(label: 'Bước 2/3'),
        const SizedBox(height: V5.space12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: V5.surface,
            border: Border.all(color: V5.border),
            borderRadius: BorderRadius.circular(V5.radiusFull),
          ),
          child: Row(
            children: [
              for (final g in _goals)
                Expanded(
                  child: _GoalTab(
                    label: g.$4,
                    active: g.$1 == picked,
                    onTap: () => onGoal(g.$1),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: V5.space16),
        for (final p in programsFor(picked)) ...[
          _ProgramCard(
            program: p,
            selected: p.id == program?.id,
            onTap: () => onProgram(p),
          ),
          const SizedBox(height: V5.space10),
        ],
        const SizedBox(height: V5.space10),
        _IntensityBlock(
          age: age,
          level: level ?? recommended,
          recommended: recommended,
          onAge: onAge,
          onLevel: onLevel,
        ),
        const SizedBox(height: V5.space24),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(V5.space20),
        decoration: BoxDecoration(
          color: V5.surface,
          border: Border.all(color: V5.border),
          borderRadius: BorderRadius.circular(V5.radiusLg),
          boxShadow: V5.elevation1,
        ),
        child: Row(
          children: [
            V5IconBubble(icon: icon),
            const SizedBox(width: V5.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: V5.title(context, color: V5.ink)),
                  const SizedBox(height: V5.space4),
                  Text(sub, style: V5.bodySm(context, color: V5.inkSoft)),
                ],
              ),
            ),
            const SizedBox(width: V5.space8),
            Icon(Icons.chevron_right_rounded, color: V5.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _GoalTab extends StatelessWidget {
  const _GoalTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? V5.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(V5.radiusFull),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: V5.text(
            context,
            size: 13.5,
            weight: FontWeight.w700,
            color: active ? V5.invInk : V5.inkSoft,
          ),
        ),
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({
    required this.program,
    required this.selected,
    required this.onTap,
  });

  final QuickProgram program;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // main.dart loads the bundled catalog before any screen is built.
    final names = [
      for (final id in program.exerciseIds)
        CatalogSource.instance.lookup(id)?.vietnameseName ?? id,
    ];
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: selected ? V5.ink : V5.surface,
          border: Border.all(color: selected ? V5.ink : V5.border),
          borderRadius: BorderRadius.circular(V5.radiusMd),
          boxShadow: V5.elevation1,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    program.name,
                    style: V5.titleSm(
                      context,
                      color: selected ? V5.invInk : V5.ink,
                    ),
                  ),
                  const SizedBox(height: V5.space4),
                  // Unselected cards stay one line so four programs and the
                  // intensity block fit on one screen; the pick shows it all.
                  Text(
                    '${names.length} bài: ${names.join(' · ')}',
                    maxLines: selected ? null : 1,
                    overflow: selected ? null : TextOverflow.ellipsis,
                    style: V5.bodySm(
                      context,
                      color: selected ? V5.invInkSoft : V5.inkSoft,
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(height: V5.space4),
                    Text(
                      program.note,
                      style: V5.bodyXs(context, color: V5.invInkFaint),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: V5.space12),
            V5CheckCircle(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _IntensityBlock extends StatelessWidget {
  const _IntensityBlock({
    required this.age,
    required this.level,
    required this.recommended,
    required this.onAge,
    required this.onLevel,
  });

  final int age;
  final String level;
  final String recommended;
  final ValueChanged<int> onAge;
  final ValueChanged<String> onLevel;

  static const _labels = {
    'beginner': 'Nhẹ nhàng',
    'intermediate': 'Vừa sức',
    'advanced': 'Thử thách',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      decoration: BoxDecoration(
        color: V5.surfaceSoft,
        border: Border.all(color: V5.border),
        borderRadius: BorderRadius.circular(V5.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$age tuổi', style: V5.titleSm(context, color: V5.ink)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: V5.ink,
                    inactiveTrackColor: V5.inkDim,
                    thumbColor: V5.ink,
                    overlayColor: V5.yellowSoft,
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: age.toDouble(),
                    min: quickMinAge.toDouble(),
                    max: quickMaxAge.toDouble(),
                    divisions: quickMaxAge - quickMinAge,
                    semanticFormatterCallback: (v) => '${v.round()} tuổi',
                    onChanged: (v) => onAge(v.round()),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              for (var i = 0; i < quickLevels.length; i++) ...[
                if (i > 0) const SizedBox(width: V5.space8),
                Expanded(
                  child: _LevelPill(
                    label: _labels[quickLevels[i]]!,
                    sets: setsForLevel(quickLevels[i]),
                    selected: quickLevels[i] == level,
                    recommended: quickLevels[i] == recommended,
                    onTap: () => onLevel(quickLevels[i]),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: V5.space8),
          Text(
            'Mức gợi ý tính theo tuổi và mục tiêu, bạn đổi được. '
            'Vika chỉnh dần theo từng buổi.',
            style: V5.bodyXs(context, color: V5.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _LevelPill extends StatelessWidget {
  const _LevelPill({
    required this.label,
    required this.sets,
    required this.selected,
    required this.recommended,
    required this.onTap,
  });

  final String label;
  final int sets;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? V5.ink : V5.surface,
          border: Border.all(color: selected ? V5.ink : V5.borderHi),
          borderRadius: BorderRadius.circular(V5.radiusSm),
        ),
        child: Column(
          children: [
            // Always present so the three pills keep one height.
            Text(
              recommended ? 'Gợi ý' : '',
              style: V5.eyebrow(
                context,
                color: selected ? V5.yellow : V5.yellowDeep,
              ),
            ),
            const SizedBox(height: V5.space2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: V5.text(
                context,
                size: 13.5,
                weight: FontWeight.w700,
                color: selected ? V5.invInk : V5.ink,
              ),
            ),
            const SizedBox(height: V5.space2),
            Text(
              '$sets hiệp',
              style: V5.bodyXs(
                context,
                color: selected ? V5.invInkSoft : V5.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
