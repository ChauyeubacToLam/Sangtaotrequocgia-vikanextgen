import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:vika/services/catalog/catalog_source.dart';
import 'package:vika/widgets/tk/tk.dart';

import 'quick_start_programs.dart';

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
    this.busy = false,
  });

  final QuickGoal? goal;
  final QuickProgram? program;
  final int age;
  final String? level;
  final ValueChanged<QuickGoal> onGoal;
  final ValueChanged<QuickProgram> onProgram;
  final ValueChanged<int> onAge;
  final ValueChanged<String> onLevel;
  final VoidCallback onNext;
  final bool busy;

  static const _goals = [
    (
      QuickGoal.pain,
      'Đau mỏi, giãn cơ',
      'Tập nhẹ cho lưng và giãn cơ',
      'Đau mỏi',
      Icons.self_improvement_rounded,
      Tk.green,
      Tk.greenSoft
    ),
    (
      QuickGoal.muscle,
      'Tăng cơ, giảm mỡ',
      'Chọn nhóm cơ hoặc đốt mỡ toàn thân',
      'Cơ · mỡ',
      Icons.fitness_center_rounded,
      Tk.primary,
      Tk.primarySoft
    ),
    (
      QuickGoal.famous,
      'Bài tập nổi tiếng',
      'Tập theo người và giáo trình có tiếng',
      'Nổi tiếng',
      Icons.emoji_events_rounded,
      Tk.orange,
      Tk.orangeSoft
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final picked = goal;
    return SafeArea(
      child: Column(
        children: [
          const TkTopBar(progress: 1, trailing: '2/2'),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
              child: picked == null ? _cards() : _picker(picked),
            ),
          ),
          if (picked != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: TkButton(
                label: program == null ? 'Chọn một bài để tiếp' : 'Bắt đầu tập',
                tone:
                    program == null ? TkButtonTone.primary : TkButtonTone.green,
                busy: busy,
                onTap: program == null ? null : onNext,
              ),
            ),
        ],
      ),
    );
  }

  Widget _cards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Hôm nay bạn muốn tập gì?',
                  style: Tk.text(28,
                      weight: FontWeight.w900,
                      letterSpacing: -0.4,
                      height: 1.15),
                ),
              ),
              const TkMascot(asset: Tk.mascotThink, size: 108),
            ],
          ),
          const SizedBox(height: 14),
          for (final g in _goals) ...[
            TkCard(
              onTap: () => onGoal(g.$1),
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: g.$7, borderRadius: BorderRadius.circular(14)),
                    child: Icon(g.$5, color: g.$6, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.$2, style: Tk.text(18, weight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(g.$3,
                            style: Tk.text(14,
                                weight: FontWeight.w700, color: Tk.inkSoft)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Tk.inkMuted, size: 28),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _picker(QuickGoal picked) {
    final recommended = recommendedLevel(age: age, goal: picked);
    final index = _goals.indexWhere((g) => g.$1 == picked);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TkSegmented(
            labels: [for (final g in _goals) g.$4],
            selected: index,
            onChanged: busy ? null : (i) => onGoal(_goals[i].$1),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Text('CHỌN MỘT BÀI', style: Tk.eyebrow()),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Vuốt ngang · chạm để lật',
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Tk.text(12.5,
                      weight: FontWeight.w700, color: Tk.inkMuted),
                ),
              ),
            ],
          ),
        ),
        _ProgramDeck(
          goal: picked,
          selectedId: program?.id,
          onPick: (p) {
            if (!busy) onProgram(p);
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _IntensityBlock(
            age: age,
            level: level ?? recommended,
            recommended: recommended,
            onAge: onAge,
            onLevel: onLevel,
          ),
        ),
      ],
    );
  }
}

class _ProgramDeck extends StatelessWidget {
  const _ProgramDeck(
      {required this.goal, required this.selectedId, required this.onPick});

  final QuickGoal goal;
  final String? selectedId;
  final ValueChanged<QuickProgram> onPick;

  @override
  Widget build(BuildContext context) {
    final programs = programsFor(goal);
    return SizedBox(
      height: 340,
      child: ListView.separated(
        key: PageStorageKey('deck-${goal.name}'),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
        itemCount: programs.length,
        separatorBuilder: (context, i) => const SizedBox(width: 14),
        itemBuilder: (context, i) => _FlipCard(
          program: programs[i],
          selected: programs[i].id == selectedId,
          dimmed: selectedId != null && programs[i].id != selectedId,
          onTap: () => onPick(programs[i]),
        ),
      ),
    );
  }
}

class _FlipCard extends StatelessWidget {
  const _FlipCard(
      {required this.program,
      required this.selected,
      required this.dimmed,
      required this.onTap});

  final QuickProgram program;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  static const _tones = {
    QuickGoal.pain: (
      Color(0xFF7FD892),
      Color(0xFF2A9A43),
      Icons.self_improvement_rounded
    ),
    QuickGoal.muscle: (
      Color(0xFF7D9BFF),
      Color(0xFF1B44B8),
      Icons.fitness_center_rounded
    ),
    QuickGoal.famous: (
      Color(0xFFFFB866),
      Color(0xFFD96A00),
      Icons.emoji_events_rounded
    ),
  };

  @override
  Widget build(BuildContext context) {
    final names = [
      for (final id in program.exerciseIds)
        CatalogSource.instance.lookup(id)?.vietnameseName ?? id,
    ];
    return Semantics(
      button: true,
      selected: selected,
      label: '${program.name}, ${names.length} bài',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          offset: Offset(0, selected ? -0.02 : 0),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            scale: dimmed ? 0.94 : 1,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: dimmed ? 0.6 : 1,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: selected ? 1 : 0),
                duration: const Duration(milliseconds: 560),
                curve: Curves.easeOutBack,
                builder: (context, t, _) {
                  final angle = t * math.pi;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(angle),
                    child: angle > math.pi / 2
                        ? Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.rotationY(math.pi),
                            child: _back(names),
                          )
                        : _front(names),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _shell(
          {required Color color,
          required Color border,
          required Widget child}) =>
      Container(
        width: 228,
        height: 318,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border, width: 2),
          boxShadow: [BoxShadow(color: border, offset: const Offset(0, 4))],
        ),
        child: child,
      );

  Widget _front(List<String> names) {
    final (tone1, tone2, icon) = _tones[program.goal]!;
    final mono = quickProgramMonograms[program.id];
    final portrait = quickProgramPortraits[program.id];
    return _shell(
      color: Tk.surface,
      border: Tk.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 206,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [tone1, tone2]),
              image: portrait == null
                  ? null
                  : DecorationImage(
                      image: AssetImage(portrait),
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.4)),
            ),
            child: Stack(
              children: [
                if (portrait == null)
                  Center(
                  child: mono == null
                      ? Icon(icon,
                          size: 92, color: Colors.white.withValues(alpha: 0.92))
                      : Text(mono,
                          style: Tk.text(64,
                              weight: FontWeight.w900,
                              color: Colors.white.withValues(alpha: 0.92),
                              letterSpacing: -2)),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(99)),
                    child: Text('${names.length} bài',
                        style: Tk.text(12.5,
                            weight: FontWeight.w900, color: tone2)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(program.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Tk.text(18, weight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  names.join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Tk.text(13,
                      weight: FontWeight.w700, color: Tk.inkSoft, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _back(List<String> names) {
    return _shell(
      color: Tk.indigo,
      border: Tk.indigoLine,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: Tk.green, borderRadius: BorderRadius.circular(99)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_rounded,
                      size: 15, color: Color(0xFF10351B)),
                  const SizedBox(width: 4),
                  Text('ĐÃ CHỌN',
                      style: Tk.text(12,
                          weight: FontWeight.w900,
                          color: const Color(0xFF10351B),
                          letterSpacing: 0.6)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(program.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Tk.text(19,
                    weight: FontWeight.w900, color: Colors.white, height: 1.2)),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final n in names)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                                color: Tk.indigoHi,
                                borderRadius: BorderRadius.circular(10)),
                            child: Text(n,
                                style: Tk.text(12.5,
                                    weight: FontWeight.w800,
                                    color: Colors.white)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      program.note,
                      style: Tk.text(12.5,
                          weight: FontWeight.w600,
                          color: Tk.onIndigoSoft,
                          height: 1.4),
                    ),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
          color: Tk.surfaceSoft, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('CƯỜNG ĐỘ', style: Tk.eyebrow()),
          Row(
            children: [
              Text('$age tuổi', style: Tk.text(17, weight: FontWeight.w900)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Tk.primary,
                    inactiveTrackColor: const Color(0xFFDCE2F7),
                    thumbColor: Tk.primary,
                    overlayColor: Tk.primary.withValues(alpha: 0.12),
                    trackHeight: 6,
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
                if (i > 0) const SizedBox(width: 8),
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
          const SizedBox(height: 10),
          Text(
            'Mức gợi ý tính theo tuổi và mục tiêu, bạn đổi được. Vika chỉnh dần theo từng buổi.',
            style: Tk.text(13,
                weight: FontWeight.w700, color: Tk.inkSoft, height: 1.4),
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
    return TkCard(
      onTap: onTap,
      radius: 14,
      lip: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      color: selected ? Tk.primarySoft : Tk.surface,
      borderColor: selected ? Tk.primary : Tk.line,
      child: Column(
        children: [
          Text(
            recommended ? 'GỢI Ý' : ' ',
            style: Tk.text(10.5,
                weight: FontWeight.w900,
                color: Tk.orangeLip,
                letterSpacing: 0.6),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Tk.text(14.5,
                weight: FontWeight.w900,
                color: selected ? Tk.primaryLip : Tk.ink),
          ),
          Text('$sets hiệp',
              style: Tk.text(12.5, weight: FontWeight.w700, color: Tk.inkSoft)),
        ],
      ),
    );
  }
}
