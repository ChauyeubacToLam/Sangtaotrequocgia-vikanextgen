import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/library_mock.dart';
import '../data/vika_albums.dart';
import '../models/exercise_definition.dart';
import '../models/exercise_lookup.dart';
import '../models/kept_exercises.dart';
import '../screens/exercise/exercise_launch_args.dart';
import '../services/catalog/catalog_source.dart';
import '../services/user_profile_service.dart';
import '../services/workout_launch_service.dart';
import '../utils/vn_text.dart';
import '../widgets/tk/tk.dart';
import 'onboarding/quick_start/quick_start_programs.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.bottomPadding,
    required this.onSelectExercise,
    this.userProfile,
  });

  final double bottomPadding;
  final void Function(ExerciseDefinition) onSelectExercise;
  final AppUserProfile? userProfile;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _Tone {
  const _Tone(this.tint, this.ink);
  final Color tint;
  final Color ink;
}

const _groupTones = {
  'CHÂN · MÔNG': _Tone(Tk.orangeSoft, Tk.orangeInk),
  'CỐT LÕI': _Tone(Tk.primarySoft, Tk.primaryLip),
  'NGỰC · VAI': _Tone(Tk.greenSoft, Tk.greenInk),
  'CARDIO': _Tone(Color(0xFFFFEEF0), Tk.redInk),
  'YOGA': _Tone(Color(0xFFF3EEFF), Color(0xFF5B3FC4)),
};

_Tone _toneFor(String group) =>
    _groupTones[group] ?? const _Tone(Tk.surfaceSoft, Tk.ink);

class _SetData {
  const _SetData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.exerciseIds,
    required this.color,
    this.icon,
    this.mono,
    this.portrait,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<String> exerciseIds;
  final Color color;
  final IconData? icon;
  final String? mono;
  final String? portrait;
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _search = TextEditingController();
  final _launches = WorkoutLaunchService();
  String _query = '';
  String? _group;

  @override
  void initState() {
    super.initState();
    unawaited(CatalogSource.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    }));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_SetData> get _famous => [
        for (final p in programsFor(QuickGoal.famous))
          _SetData(
            id: p.id,
            title: p.name,
            subtitle: p.note,
            exerciseIds: p.exerciseIds,
            color: Tk.orange,
            mono: quickProgramMonograms[p.id],
            portrait: quickProgramPortraits[p.id],
            icon: Icons.emoji_events_rounded,
          ),
      ];

  List<_SetData> get _albums => [
        for (final a in vikaAlbums)
          _SetData(
            id: a.id,
            title: a.vietnameseTitle,
            subtitle: a.vietnameseSubtitle,
            exerciseIds: a.exerciseIds,
            color: Tk.primary,
            icon: a.icon,
            portrait: a.cover,
          ),
      ];

  void _startExercise(String id) {
    final def = lookupExerciseDefinition(id);
    if (def == null || !isKeptExercise(id)) return;
    widget.onSelectExercise(def);
  }

  Future<void> _startSet(List<String> ids) async {
    final kept = ids.where(isKeptExercise).toList(growable: false);
    final sequence = await _launches.buildSequenceFromCatalogIds(kept);
    if (!mounted) return;
    if (sequence.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Bộ tập này chưa có bài camera phù hợp.')));
      return;
    }
    final first = sequence.first;
    ExerciseLaunchArgs? next = ExerciseLaunchArgs(
      definition: first.definition,
      catalogExerciseId: first.catalogExerciseId,
      catalogInfo: first.catalogInfo,
      prescription: first.prescription,
      recommendationId: first.recommendationId,
      weekNumber: first.weekNumber,
      sessionIndex: first.sessionIndex,
      slotName: first.slotName,
      sequence: sequence,
      sequenceIndex: 0,
    );
    while (mounted && next != null) {
      final result =
          await Navigator.of(context).pushNamed('/exercise', arguments: next);
      if (!mounted) return;
      next = result is Map && result['next'] is ExerciseLaunchArgs
          ? result['next'] as ExerciseLaunchArgs
          : null;
    }
  }

  void _zoom(Widget Function(BuildContext) builder) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierLabel: 'Đóng',
        barrierColor: const Color(0xB31E1B4B),
        transitionDuration: const Duration(milliseconds: 340),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, animation, secondary) => builder(context),
        transitionsBuilder: (context, animation, secondary, child) {
          final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeIn);
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: ScaleTransition(
                scale: Tween(begin: 0.86, end: 1.0).animate(curved),
                child: child),
          );
        },
      ),
    );
  }

  void _openExercise(AllExerciseRowMock row) {
    final id = row.definitionName!;
    _zoom((context) => _ExerciseZoom(
          row: row,
          onStart: () {
            Navigator.of(context).pop();
            _startExercise(id);
          },
        ));
  }

  void _openSet(_SetData set) {
    _zoom((context) => _SetZoom(
          set: set,
          onStart: () {
            Navigator.of(context).pop();
            unawaited(_startSet(set.exerciseIds));
          },
        ));
  }

  @override
  Widget build(BuildContext context) {
    final groups = orderedCatalogGroups(libraryMockAllExercises);
    final q = foldVietnamese(_query.trim());
    bool hit(String text) => q.isEmpty || foldVietnamese(text).contains(q);
    final rows = [
      for (final r in libraryMockAllExercises)
        if ((_group == null || r.group == _group) && hit(r.name)) r,
    ];
    final browsing = q.isEmpty && _group == null;
    final allFamous = _famous;
    final featured =
        allFamous.where((s) => s.id == 'famous_acsm_7min').firstOrNull;
    final famous = [
      for (final s in allFamous)
        if (s != featured && _group == null && hit(s.title)) s
    ];
    final albums = [
      for (final s in _albums)
        if (_group == null && hit(s.title)) s
    ];

    return ColoredBox(
      color: Tk.surface,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Thư viện',
                        style: Tk.text(28,
                            weight: FontWeight.w900, letterSpacing: -0.4)),
                    const SizedBox(height: 4),
                    Text('Mỗi tuần Vika thêm bài mới.',
                        style: Tk.text(15,
                            weight: FontWeight.w700, color: Tk.inkSoft)),
                    const SizedBox(height: 14),
                    _SearchField(
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v),
                      onClear: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 58,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
                  children: [
                    _Chip(
                        label: 'Tất cả',
                        selected: _group == null,
                        onTap: () => setState(() => _group = null)),
                    for (final g in groups)
                      _Chip(
                        label: libraryGroupEditorial[g]?.title ?? g,
                        selected: _group == g,
                        onTap: () =>
                            setState(() => _group = _group == g ? null : g),
                      ),
                  ],
                ),
              ),
            ),
            if (browsing && featured != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _FeaturedCard(
                      set: featured, onTap: () => _openSet(featured)),
                ),
              ),
            if (famous.isNotEmpty) ...[
              const _SectionLabel('TẬP THEO NGƯỜI NỔI TIẾNG'),
              _SetRail(sets: famous, onTap: _openSet),
            ],
            if (albums.isNotEmpty) ...[
              const _SectionLabel('BỘ TẬP'),
              _SetRail(sets: albums, onTap: _openSet),
            ],
            _SectionLabel('BÀI TẬP · AI CHẤM FORM',
                trailing: '${rows.length} bài'),
            if (rows.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Text('Chưa có bài nào khớp "$_query".',
                      style: Tk.text(15,
                          weight: FontWeight.w700, color: Tk.inkSoft)),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 230,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _ExerciseTile(
                        row: rows[i], onTap: () => _openExercise(rows[i])),
                    childCount: rows.length,
                  ),
                ),
              ),
            SliverToBoxAdapter(
                child: SizedBox(height: widget.bottomPadding + 20)),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField(
      {required this.controller,
      required this.onChanged,
      required this.onClear});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final style = Tk.text(16, weight: FontWeight.w700);
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: 2),
        );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      cursorColor: Tk.primary,
      style: style,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Tk.surfaceSoft,
        hintText: 'Tìm bài tập, bộ tập…',
        hintStyle: style.copyWith(color: Tk.inkMuted),
        prefixIcon: const Icon(Icons.search_rounded, color: Tk.inkSoft),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Xóa',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, color: Tk.inkSoft)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: border(const Color(0xFFE1E3F0)),
        focusedBorder: border(Tk.primary),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
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
              color: selected ? Tk.ink : Tk.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? Tk.ink : Tk.line, width: 2),
            ),
            child: Text(
              label,
              style: Tk.text(14,
                  weight: selected ? FontWeight.w900 : FontWeight.w800,
                  color: selected ? Colors.white : Tk.ink),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 10),
        child: Row(
          children: [
            Expanded(child: Text(text, style: Tk.eyebrow())),
            if (trailing != null)
              Text(trailing!,
                  style:
                      Tk.text(13, weight: FontWeight.w800, color: Tk.inkMuted)),
          ],
        ),
      ),
    );
  }
}

class _SetArt extends StatelessWidget {
  const _SetArt({required this.set, required this.size});

  final _SetData set;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (set.portrait case final asset?) {
      return Image.asset(asset,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.5),
          excludeFromSemantics: true,
          errorBuilder: (context, error, stackTrace) => Icon(
                set.icon ?? Icons.playlist_play_rounded,
                size: size,
                color: Colors.white.withValues(alpha: 0.95),
              ));
    }
    final mono = set.mono;
    final fg = Colors.white.withValues(alpha: 0.95);
    return mono != null
        ? Text(mono,
            style: Tk.text(size * 0.62,
                weight: FontWeight.w900,
                color: fg,
                letterSpacing: -1.5,
                height: 1))
        : Icon(set.icon ?? Icons.playlist_play_rounded, size: size, color: fg);
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.set, required this.onTap});

  final _SetData set;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: set.title,
      child: TkPressable(
        onTap: onTap,
        lipColor: Tk.orangeLip,
        radius: 20,
        child: Container(
          height: 116,
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
              color: Tk.orange, borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('BỘ TẬP NỔI BẬT',
                        style: Tk.text(12,
                            weight: FontWeight.w900,
                            color: const Color(0xFF4A1F00),
                            letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(set.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Tk.text(21,
                            weight: FontWeight.w900,
                            color: const Color(0xFF2B1300),
                            height: 1.15)),
                    const SizedBox(height: 4),
                    Text(
                      '${set.exerciseIds.length} động tác · AI chạy từng bài',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Tk.text(13,
                          weight: FontWeight.w800,
                          color: const Color(0xFF4A1F00)),
                    ),
                  ],
                ),
              ),
              Hero(
                  tag: 'lib-set-${set.id}', child: _SetArt(set: set, size: 72)),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetRail extends StatelessWidget {
  const _SetRail({required this.sets, required this.onTap});

  final List<_SetData> sets;
  final ValueChanged<_SetData> onTap;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 206,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: sets.length,
          separatorBuilder: (context, i) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final set = sets[i];
            return SizedBox(
              width: 164,
              child: Semantics(
                button: true,
                label: set.title,
                child: TkCard(
                  onTap: () => onTap(set),
                  padding: EdgeInsets.zero,
                  radius: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 96,
                        alignment: Alignment.center,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: set.color,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(18)),
                        ),
                        child: Hero(
                            tag: 'lib-set-${set.id}',
                            child: _SetArt(set: set, size: 50)),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(set.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Tk.text(15,
                                    weight: FontWeight.w900, height: 1.2)),
                            const SizedBox(height: 4),
                            Text('${set.exerciseIds.length} bài',
                                style: Tk.text(12.5,
                                    weight: FontWeight.w700,
                                    color: Tk.inkSoft)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.row, required this.iconSize});

  final AllExerciseRowMock row;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final tone = _toneFor(row.group);
    final asset = row.thumbnailAsset;
    return Container(
      color: tone.tint,
      alignment: Alignment.center,
      child: asset == null
          ? Icon(
              lookupExerciseDefinition(row.definitionName ?? '')?.icon ??
                  Icons.fitness_center_rounded,
              size: iconSize,
              color: tone.ink)
          : Image.asset(asset,
              fit: BoxFit.contain,
              cacheWidth: 720,
              excludeFromSemantics: true,
              frameBuilder: (context, child, frame, sync) => sync
                  ? child
                  : AnimatedOpacity(
                      opacity: frame == null ? 0 : 1,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      child: child)),
    );
  }
}

class _ValidationTag extends StatelessWidget {
  const _ValidationTag({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final status = exerciseValidationStatus(id);
    if (status == null) return const SizedBox.shrink();
    final ok = status == ExerciseValidationStatus.validated;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ok ? Icons.verified_rounded : Icons.timelapse_rounded,
            size: 14, color: ok ? Tk.greenLip : Tk.inkMuted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            status.vietnameseLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Tk.text(11.5,
                weight: FontWeight.w800, color: ok ? Tk.greenInk : Tk.inkMuted),
          ),
        ),
      ],
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.row, required this.onTap});

  final AllExerciseRowMock row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: row.name,
      child: TkCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        radius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 128,
              child: Hero(
                tag: 'lib-ex-${row.definitionName}',
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                  child: _Thumb(row: row, iconSize: 48),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Tk.text(15.5, weight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(row.displayCat,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Tk.text(12.5,
                          weight: FontWeight.w700, color: Tk.inkSoft)),
                  const SizedBox(height: 5),
                  _ValidationTag(id: row.definitionName ?? ''),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomFrame extends StatelessWidget {
  const _ZoomFrame({required this.hero, required this.body, required this.cta});

  final Widget hero;
  final Widget body;
  final Widget cta;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Material(
              color: Tk.surface,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    children: [
                      hero,
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: 'Đóng',
                            onPressed: () => Navigator.of(context).pop(),
                            icon:
                                const Icon(Icons.close_rounded, color: Tk.ink),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                      child: body,
                    ),
                  ),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                      child: cta),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExerciseZoom extends StatelessWidget {
  const _ExerciseZoom({required this.row, required this.onStart});

  final AllExerciseRowMock row;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final def = lookupExerciseDefinition(row.definitionName ?? '');
    final editorial = libraryGroupEditorial[row.group];
    final tone = _toneFor(row.group);
    final tags = [
      if (def != null && def.difficulty.isNotEmpty) def.difficulty,
      ...?def?.targetMuscles,
    ];
    final screen = MediaQuery.sizeOf(context);
    return _ZoomFrame(
      hero: SizedBox(
        height: (screen.height * 0.36).clamp(180.0, 320.0),
        child: Hero(
            tag: 'lib-ex-${row.definitionName}',
            child: _Thumb(row: row, iconSize: 110)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.name,
              style: Tk.text(26,
                  weight: FontWeight.w900, letterSpacing: -0.3, height: 1.15)),
          const SizedBox(height: 4),
          Text(row.displayCat,
              style: Tk.text(15, weight: FontWeight.w700, color: Tk.inkSoft)),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in tags)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: tone.tint,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(t,
                        style: Tk.text(13,
                            weight: FontWeight.w800, color: tone.ink)),
                  ),
              ],
            ),
          ],
          if (editorial != null && editorial.subtitle.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(editorial.subtitle,
                style: Tk.text(14.5, weight: FontWeight.w600, height: 1.4)),
          ],
          const SizedBox(height: 10),
          _ValidationTag(id: row.definitionName ?? ''),
        ],
      ),
      cta: TkButton(
          label: 'Tập ngay',
          icon: Icons.play_arrow_rounded,
          tone: TkButtonTone.green,
          onTap: def == null ? null : onStart),
    );
  }
}

class _SetZoom extends StatelessWidget {
  const _SetZoom({required this.set, required this.onStart});

  final _SetData set;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final kept = set.exerciseIds.where(isKeptExercise).toList();
    return _ZoomFrame(
      hero: Container(
        height: 170,
        alignment: Alignment.center,
        color: set.color,
        child:
            Hero(tag: 'lib-set-${set.id}', child: _SetArt(set: set, size: 92)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(set.title,
              style: Tk.text(25,
                  weight: FontWeight.w900, letterSpacing: -0.3, height: 1.15)),
          const SizedBox(height: 6),
          Text(set.subtitle,
              style: Tk.text(14.5,
                  weight: FontWeight.w600, color: Tk.inkSoft, height: 1.4)),
          const SizedBox(height: 14),
          Text('${kept.length} BÀI', style: Tk.eyebrow()),
          const SizedBox(height: 8),
          for (var i = 0; i < kept.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: Tk.lineSoft,
                        borderRadius: BorderRadius.circular(9)),
                    child: Text('${i + 1}',
                        style: Tk.text(13,
                            weight: FontWeight.w900, color: Tk.inkSoft)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      CatalogSource.instance.lookup(kept[i])?.vietnameseName ??
                          kept[i],
                      style: Tk.text(15.5, weight: FontWeight.w800),
                    ),
                  ),
                  if (exerciseThumbnailForId(kept[i]) case final asset?)
                    Image.asset(asset,
                        width: 40,
                        height: 40,
                        cacheWidth: 720,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true),
                ],
              ),
            ),
        ],
      ),
      cta: TkButton(
          label: 'Tập ngay',
          icon: Icons.play_arrow_rounded,
          tone: TkButtonTone.green,
          onTap: kept.isEmpty ? null : onStart),
    );
  }
}
