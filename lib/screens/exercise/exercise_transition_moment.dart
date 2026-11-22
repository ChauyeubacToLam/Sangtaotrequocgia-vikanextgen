import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/post_exercise_data.dart';
import '../../widgets/tk/tk.dart';

class ExerciseTransitionMoment extends StatefulWidget {
  const ExerciseTransitionMoment({
    super.key,
    required this.exerciseName,
    required this.formScore,
    required this.setResults,
    required this.nextExerciseName,
    required this.onComplete,
    this.timeBased = false,
    this.totalDurationMs = 5000,
    this.controlCondition = false,
  });

  final String exerciseName;
  final int formScore;
  final List<SetReportData> setResults;
  final bool timeBased;
  final String nextExerciseName;
  final VoidCallback onComplete;
  final int totalDurationMs;
  final bool controlCondition;

  @override
  State<ExerciseTransitionMoment> createState() =>
      _ExerciseTransitionMomentState();
}

class _ExerciseTransitionMomentState extends State<ExerciseTransitionMoment>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timer = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.totalDurationMs),
  );
  bool _done = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    _timer.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });
    _timer.forward();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onComplete();
  }

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  String _setLabel(SetReportData s) {
    if (widget.timeBased) {
      final good = (s.goodSeconds ?? 0).round();
      final total = (s.totalSeconds ?? 0).round();
      return '${good}s/${total}s';
    }
    return '${s.goodReps ?? 0}/${s.totalReps ?? 0}';
  }

  @override
  Widget build(BuildContext context) {
    final control = widget.controlCondition;
    final goodTotal =
        widget.setResults.fold<int>(0, (a, s) => a + (s.goodReps ?? 0));
    final allTotal =
        widget.setResults.fold<int>(0, (a, s) => a + (s.totalReps ?? 0));
    final headline = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Hoàn thành bài tập',
            style: Tk.text(13,
                weight: FontWeight.w900,
                color: const Color(0xFF8BE3A2),
                letterSpacing: 1.2)),
        const SizedBox(height: 6),
        Text(
          control ? widget.exerciseName : '${widget.exerciseName} xong rồi!',
          textAlign: TextAlign.center,
          style: Tk.text(32,
              weight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.6,
              height: 1.1),
        ),
        const SizedBox(height: 6),
        Text(
          control || widget.timeBased || allTotal == 0
              ? 'Đã ghi nhận kết quả các hiệp tập.'
              : '$goodTotal/$allTotal rep chuẩn form',
          textAlign: TextAlign.center,
          style: Tk.text(16, weight: FontWeight.w700, color: Tk.onIndigoSoft),
        ),
        if (!control && widget.setResults.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final s in widget.setResults)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                      color: Tk.indigoHi,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                            text: 'Hiệp ${s.setIndex + 1} · ',
                            style: Tk.text(14,
                                weight: FontWeight.w900, color: Colors.white)),
                        TextSpan(
                          text: _setLabel(s),
                          style: Tk.text(
                            14,
                            weight: FontWeight.w900,
                            color: (s.goodReps ?? 0) >= (s.totalReps ?? 0) * 0.9
                                ? const Color(0xFF8BE3A2)
                                : const Color(0xFFFFB870),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
    final nextCard = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0xFFB8B3EE), offset: Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.nextExerciseName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Tk.text(18, weight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 10),
              Semantics(
                button: true,
                label: 'Tiếp tục ngay',
                child: GestureDetector(
                  onTap: _finish,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Tk.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Tk.primaryLip, offset: Offset(0, 3))
                      ],
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 30),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _timer,
            builder: (context, _) =>
                TkProgressBar(value: _timer.value, height: 8),
          ),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: Tk.indigo,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final landscape = c.maxWidth > c.maxHeight;
            final mascot = control
                ? const SizedBox.shrink()
                : TkMascot(
                    asset: Tk.mascotCheer,
                    size: landscape ? c.maxHeight * 0.62 : 280);
            if (landscape) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                child: Row(
                  children: [
                    if (!control) mascot,
                    const SizedBox(width: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            headline,
                            const SizedBox(height: 16),
                            nextCard
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                children: [
                  Expanded(
                      child: Center(
                          child: SingleChildScrollView(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                        mascot,
                        const SizedBox(height: 8),
                        headline
                      ])))),
                  nextCard,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
