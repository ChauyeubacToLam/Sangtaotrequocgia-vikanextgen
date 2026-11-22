import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/post_exercise_data.dart';
import '../../services/session_persistence.dart';
import '../../utils/exercise_logger.dart';
import '../../widgets/tk/tk.dart';

class RestScreen extends StatefulWidget {
  const RestScreen({
    super.key,
    required this.setReport,
    required this.setIndex,
    required this.totalSets,
    required this.currentReps,
    required this.baseRestSeconds,
    required this.isLastSet,
    required this.onNext,
    this.exerciseName,
    this.onDifficultyAnswer,
    this.setLogger,
    this.previousSession,
    this.controlCondition = false,
    this.aiVisibleRatio,
    this.onReportFault,
    this.onExportLogs,
  });

  final SetReportData setReport;
  final int setIndex;
  final int totalSets;
  final int currentReps;
  final int baseRestSeconds;
  final bool isLastSet;
  final String? exerciseName;
  final VoidCallback onNext;
  final void Function(String difficulty)? onDifficultyAnswer;
  final ExerciseLogger? setLogger;
  final List<PreviousSessionSummary>? previousSession;
  final bool controlCondition;

  final double? aiVisibleRatio;

  final void Function(String faultType, bool reported)? onReportFault;

  final Future<bool> Function(BuildContext buttonContext)? onExportLogs;

  @override
  State<RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends State<RestScreen> with TickerProviderStateMixin {
  Timer? _timer;
  String? _selectedDifficulty;
  final Set<String> _reportedFaults = <String>{};
  bool _didAdvance = false;
  bool _exporting = false;
  late int _restDuration;
  late int _remaining;
  late final AnimationController _dotController;
  late final List<CurvedAnimation> _dotAnimations;

  List<_FaultObservation> get _faultObservations =>
      _groupFaultObservations(widget.setLogger);

  bool get _lockedDifficulty => _selectedDifficulty != null;

  void _toggleReport(String faultType) {
    final reported = !_reportedFaults.contains(faultType);
    HapticFeedback.selectionClick();
    setState(() {
      reported
          ? _reportedFaults.add(faultType)
          : _reportedFaults.remove(faultType);
    });
    widget.onReportFault?.call(faultType, reported);
  }

  double get _progress {
    if (_restDuration == 0) return 1;
    return (1 - (_remaining / _restDuration)).clamp(0.0, 1.0).toDouble();
  }

  String get _exerciseLabel {
    final passed = widget.exerciseName;
    if (passed != null && passed.trim().isNotEmpty) {
      return passed.trim();
    }
    final loggerLabel = widget.setLogger?.setLogs['exercise_name'];
    if (loggerLabel is String && loggerLabel.trim().isNotEmpty) {
      return loggerLabel.trim();
    }
    final altLabel = widget.setLogger?.setLogs['exerciseName'];
    if (altLabel is String && altLabel.trim().isNotEmpty) {
      return altLabel.trim();
    }
    return 'Squat';
  }

  @override
  void initState() {
    super.initState();
    _restDuration = widget.isLastSet ? 10 : widget.baseRestSeconds;
    _remaining = _restDuration;
    _dotController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds:
            math.max(680, 320 + (widget.setReport.repResults.length * 40)),
      ),
    )..forward();
    _dotAnimations = List.generate(
      widget.setReport.repResults.length,
      (i) {
        final start = (i * 0.04).clamp(0.0, 0.82).toDouble();
        final end = (start + 0.24).clamp(start + 0.01, 1.0).toDouble();
        return CurvedAnimation(
          parent: _dotController,
          curve: Interval(start, end, curve: Curves.easeOutBack),
        );
      },
    );
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final anim in _dotAnimations) {
      anim.dispose();
    }
    _dotController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remaining <= 0) {
        _advance();
        return;
      }
      setState(() => _remaining -= 1);
    });
  }

  Future<void> _exportLogs(BuildContext buttonContext) async {
    final export = widget.onExportLogs;
    if (export == null || _exporting || _didAdvance) return;
    HapticFeedback.selectionClick();
    _timer?.cancel();
    setState(() => _exporting = true);
    var shared = false;
    try {
      shared = await export(buttonContext);
    } catch (_) {
      shared = false;
    }
    if (!mounted) return;
    setState(() => _exporting = false);
    if (!shared) {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Chưa xuất được tệp nhật ký. Vui lòng thử lại.'),
          ),
        );
    }
    if (!_didAdvance) _startTimer();
  }

  void _advance() {
    if (_didAdvance) return;
    _didAdvance = true;
    _timer?.cancel();
    HapticFeedback.lightImpact();
    widget.onNext();
  }

  void _selectDifficulty(String difficulty) {
    if (_lockedDifficulty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDifficulty = difficulty;
      if (difficulty == 'heavy') {
        _restDuration += 15;
        _remaining += 15;
      }
    });
    widget.onDifficultyAnswer?.call(difficulty);
  }

  String? get _adjustmentText {
    if (_selectedDifficulty == null || widget.isLastSet) return null;
    return switch (_selectedDifficulty!) {
      'light' => 'Set sau tăng 2 reps',
      'medium' => 'Set sau giữ ${widget.currentReps} reps',
      'heavy' => '+15 giây nghỉ · Set sau giảm 1 rep',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final goodReps = widget.setReport.goodReps ??
        widget.setReport.repResults.where((isGood) => isGood).length;
    final totalReps = widget.setReport.totalReps ?? widget.currentReps;
    final faults = _faultObservations;
    final control = widget.controlCondition;
    final tip = (widget.setReport.coachTip ?? '').trim();
    final praise = (widget.setReport.praiseSentence ?? '').trim();
    final bubble = tip.isNotEmpty
        ? tip
        : praise.isNotEmpty
            ? praise
            : 'Hít thở sâu, uống ngụm nước rồi mình tập tiếp nhé!';
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 20, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Bỏ qua nghỉ',
            onPressed: _advance,
            icon: const Icon(Icons.close_rounded, color: Tk.inkSoft, size: 28),
          ),
          Expanded(
            child: Text(
              '${_exerciseLabel.toUpperCase()} · HIỆP ${widget.setIndex + 1}/${widget.totalSets} XONG',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Tk.eyebrow(color: Tk.greenLip),
            ),
          ),
        ],
      ),
    );
    final summary = Row(
      children: [
        _TimerRing(progress: _progress, remaining: _remaining),
        const SizedBox(width: 18),
        Expanded(
          child: control
              ? Text(
                  'Đã hoàn thành hiệp ${widget.setIndex + 1}',
                  style: Tk.text(22, weight: FontWeight.w900, height: 1.2),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                              text: '$goodReps',
                              style: Tk.text(34, weight: FontWeight.w900)),
                          TextSpan(
                              text: '/$totalReps',
                              style: Tk.text(20,
                                  weight: FontWeight.w900, color: Tk.inkSoft)),
                        ],
                      ),
                    ),
                    Text('REP CHUẨN FORM',
                        style: Tk.eyebrow(color: Tk.greenInk)),
                    if (praise.isNotEmpty && bubble != praise) ...[
                      const SizedBox(height: 4),
                      Text(praise,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Tk.text(13.5,
                              weight: FontWeight.w800, color: Tk.greenInk)),
                    ],
                    if (widget.setReport.repResults.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (var i = 0;
                              i < widget.setReport.repResults.length;
                              i++)
                            ScaleTransition(
                              scale: _dotAnimations[i],
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: widget.setReport.repResults[i]
                                      ? Tk.green
                                      : Tk.orange,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
    List<Widget> coach({required double mascotSize}) => [
          if (control)
            Text(
              'Nghỉ ngơi một chút trước khi sang hiệp tiếp theo.',
              style: Tk.text(15, weight: FontWeight.w700, color: Tk.inkSoft),
            )
          else
            TkSpeechRow(
              asset: faults.isEmpty ? Tk.mascotThumbsUp : Tk.mascotEncourage,
              mascotSize: mascotSize,
              message: bubble,
            ),
          if (!control && faults.isNotEmpty) ...[
            const SizedBox(height: 12),
            _FaultsCard(
              faults: faults,
              reported: _reportedFaults,
              aiVisibleRatio: widget.aiVisibleRatio,
              onReport: widget.onReportFault == null ? null : _toggleReport,
            ),
          ] else if (!control && widget.aiVisibleRatio != null) ...[
            const SizedBox(height: 10),
            _VisibilityLine(ratio: widget.aiVisibleRatio!),
          ],
          if (widget.onExportLogs != null) ...[
            const SizedBox(height: 12),
            Builder(
              builder: (buttonContext) => TkButton(
                label: 'Xuất tệp nhật ký',
                tone: TkButtonTone.outline,
                height: 46,
                busy: _exporting,
                onTap: () => _exportLogs(buttonContext),
              ),
            ),
          ],
        ];
    final difficulty = <Widget>[
      Text('HIỆP NÀY THẤY THẾ NÀO?', style: Tk.eyebrow()),
      const SizedBox(height: 8),
      Row(
        children: [
          for (final (value, label) in const [
            ('light', 'Nhẹ'),
            ('medium', 'Vừa'),
            ('heavy', 'Nặng')
          ]) ...[
            if (value != 'light') const SizedBox(width: 8),
            Expanded(
              child: TkCard(
                onTap:
                    _lockedDifficulty ? null : () => _selectDifficulty(value),
                lip: false,
                radius: 14,
                padding: const EdgeInsets.symmetric(vertical: 11),
                color:
                    _selectedDifficulty == value ? Tk.primarySoft : Tk.surface,
                borderColor:
                    _selectedDifficulty == value ? Tk.primary : Tk.line,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Tk.text(
                    15.5,
                    weight: FontWeight.w900,
                    color: _selectedDifficulty == value
                        ? Tk.primaryLip
                        : (_lockedDifficulty ? Tk.inkMuted : Tk.ink),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      if (_adjustmentText != null) ...[
        const SizedBox(height: 8),
        Text(_adjustmentText!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Tk.text(13.5, weight: FontWeight.w800, color: Tk.inkSoft)),
      ],
    ];
    final next = TkButton(
      label: widget.isLastSet ? 'Xem tổng kết' : 'Bắt đầu hiệp tiếp',
      onTap: _advance,
    );
    return Scaffold(
      backgroundColor: Tk.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            if (box.maxWidth > box.maxHeight) {
              return Column(
                children: [
                  header,
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                summary,
                                const Spacer(),
                                ...difficulty,
                                const SizedBox(height: 12),
                                next,
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 6,
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: coach(mascotSize: 76),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                header,
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        summary,
                        const SizedBox(height: 10),
                        ...coach(mascotSize: 100),
                        const SizedBox(height: 16),
                        ...difficulty,
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: next,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TimerRing extends StatelessWidget {
  const _TimerRing({required this.progress, required this.remaining});

  final double progress;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      height: 128,
      child: CustomPaint(
        painter: _RingPainter(1 - progress),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$remaining',
                  style: Tk.text(40, weight: FontWeight.w900, height: 1)),
              Text('GIÂY NGHỈ',
                  style: Tk.text(10.5,
                      weight: FontWeight.w900,
                      color: Tk.inkSoft,
                      letterSpacing: 1)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final rect = Offset.zero & size;
    final ring = rect.deflate(stroke / 2);
    final track = Paint()
      ..color = const Color(0xFFEEF0F7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(ring, 0, math.pi * 2, false, track);
    final arc = Paint()
      ..color = Tk.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        ring, -math.pi / 2, math.pi * 2 * value.clamp(0, 1), false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.value != value;
}

class _VisibilityLine extends StatelessWidget {
  const _VisibilityLine({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final percent = (ratio * 100).round().clamp(0, 100);
    final low = percent < 80;
    return Row(
      children: [
        Icon(Icons.visibility_rounded,
            size: 17, color: low ? Tk.orangeLip : Tk.inkSoft),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            low
                ? 'AI nhìn rõ $percent% thời gian · kiểm tra lại vị trí máy'
                : 'AI nhìn rõ $percent% thời gian tập',
            style: Tk.text(13,
                weight: FontWeight.w800,
                color: low ? Tk.orangeInk : const Color(0xFF4F4C75)),
          ),
        ),
      ],
    );
  }
}

class _FaultsCard extends StatelessWidget {
  const _FaultsCard({
    required this.faults,
    required this.reported,
    required this.aiVisibleRatio,
    required this.onReport,
  });

  final List<_FaultObservation> faults;
  final Set<String> reported;
  final double? aiVisibleRatio;
  final void Function(String type)? onReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Tk.line, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFFFFF6EC),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CẦN CHÚ Ý (${faults.length})',
                    style: Tk.eyebrow(color: Tk.orangeInk)),
                if (aiVisibleRatio != null) ...[
                  const SizedBox(height: 4),
                  _VisibilityLine(ratio: aiVisibleRatio!),
                ],
              ],
            ),
          ),
          for (final fault in faults)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              decoration: const BoxDecoration(
                  border:
                      Border(top: BorderSide(color: Tk.lineSoft, width: 2))),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fault.title,
                            style: Tk.text(15, weight: FontWeight.w900)),
                        if (fault.reps.isNotEmpty)
                          Text('Rep ${fault.reps.join(', ')}',
                              style: Tk.text(12.5,
                                  weight: FontWeight.w700, color: Tk.inkSoft)),
                        if (fault.tip.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(fault.tip,
                              style: Tk.text(13,
                                  weight: FontWeight.w700,
                                  color: const Color(0xFF4F4C75),
                                  height: 1.35)),
                        ],
                      ],
                    ),
                  ),
                  if (onReport != null) ...[
                    const SizedBox(width: 8),
                    _ReportButton(
                      reported: reported.contains(fault.type),
                      onTap: () => onReport!(fault.type),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportButton extends StatelessWidget {
  const _ReportButton({required this.reported, required this.onTap});

  final bool reported;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: reported,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: reported ? Tk.primarySoft : Tk.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: reported ? Tk.primary : const Color(0xFFE1E3F0),
                width: 2),
          ),
          child: Text(
            reported ? 'Đã báo sai' : 'Báo sai',
            style: Tk.text(13,
                weight: FontWeight.w900,
                color: reported ? Tk.primaryLip : const Color(0xFF4F4C75)),
          ),
        ),
      ),
    );
  }
}

class _FaultObservation {
  const _FaultObservation({
    required this.type,
    required this.title,
    required this.tip,
    required this.reps,
  });
  final String type;
  final String title;
  final String tip;
  final List<int> reps;
}

List<_FaultObservation> _groupFaultObservations(ExerciseLogger? logger) {
  if (logger == null) return const [];
  final groups = <String, List<int>>{};
  for (final rep in logger.repLogs) {
    final faultTypes = (rep.data['fault_types'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toSet();
    for (final type in faultTypes) {
      groups.putIfAbsent(type, () => <int>[]).add(rep.repNumber);
    }
  }
  final mapped = groups.entries.map((entry) {
    final copy = [...entry.value]..sort();
    final meta = _faultMeta(entry.key);
    return _FaultObservation(
      type: entry.key,
      title: meta.title,
      tip: meta.tip,
      reps: copy,
    );
  }).toList()
    ..sort((a, b) => b.reps.length.compareTo(a.reps.length));
  return mapped;
}

({String title, String tip}) _faultMeta(String type) {
  return switch (type) {
    'Back' => (
        title: 'đổ thân trên',
        tip: 'Ép ngực ra và đẩy hông ra sau nhẹ để thân trên thẳng hơn nhé.',
      ),
    'Feet' => (
        title: 'Gót chân nhấc',
        tip: 'Ép gót xuống sàn và cảm nhận bàn chân bám chắc hơn nhé.',
      ),
    'Depth' => (
        title: 'Chưa xuống đủ sâu',
        tip: 'Thử hạ hông thêm một chút nếu vẫn kiểm soát được nhé.',
      ),
    'Tempo' => (
        title: 'Nhịp chưa đều',
        tip: 'Xuống chậm hơn, giữ ở đáy thêm một nhịp nhé.',
      ),
    'HipShoulderSync' => (
        title: 'Hông và vai lên không đều',
        tip: 'Lúc lên, kéo hông và ngực đồng thời nhé, form sẽ chắc hơn.',
      ),
    _ => (
        title: type.replaceAll('_', ' ').toLowerCase(),
        tip: 'Giữ nhịp đều, chú ý kiểm soát chuyển động nhé.',
      ),
  };
}
