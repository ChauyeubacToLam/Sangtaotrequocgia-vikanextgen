import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/recommendation/weekly_check_in_service.dart';
import '../services/research/research_preferences.dart';
import '../widgets/tk/tk.dart';

class WeeklyCheckInLaunchArgs {
  const WeeklyCheckInLaunchArgs({
    required this.recommendationId,
    required this.weekNumber,
  });

  final String recommendationId;
  final int weekNumber;
}

class WeeklyCheckInScreen extends StatefulWidget {
  const WeeklyCheckInScreen({
    super.key,
    required this.args,
  });

  final WeeklyCheckInLaunchArgs args;

  @override
  State<WeeklyCheckInScreen> createState() => _WeeklyCheckInScreenState();
}

class _WeeklyCheckInScreenState extends State<WeeklyCheckInScreen> {
  final _service = WeeklyCheckInService();
  final _answers = <String, dynamic>{};
  int _index = 0;
  bool _isSubmitting = false;
  bool _isDone = false;

  String get _prefsKey =>
      'weekly_checkin_${widget.args.recommendationId}_${widget.args.weekNumber}';

  @override
  void initState() {
    super.initState();
    unawaited(_restorePartial());
  }

  Future<void> _restorePartial() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || !mounted) return;
    final restored = (jsonDecode(raw) as Map).cast<String, dynamic>();
    setState(() {
      _answers
        ..clear()
        ..addAll(restored);
      _index = (_answers.length).clamp(0, _questions.length - 1).toInt();
    });
  }

  Future<void> _savePartial() async {
    final prefs = await SharedPreferences.getInstance();
    if (_answers.isEmpty) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, jsonEncode(_answers));
    }
  }

  Future<void> _clearPartial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  void _answer(dynamic value) {
    final question = _questions[_index];
    setState(() => _answers[question.key] = value);
    unawaited(_savePartial());
  }

  void _next() {
    if (_index < _questions.length - 1) {
      setState(() => _index += 1);
    } else {
      unawaited(_submit());
    }
  }

  void _back() {
    if (_index == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _index -= 1);
  }

  Future<void> _submit() async {
    if (!_hasAllAnswers || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    final ok = await _service.submit(
      recommendationId: widget.args.recommendationId,
      weekNumber: widget.args.weekNumber,
      answers: WeeklyCheckInAnswers(
        energy: _answers['energy'] as int,
        soreness: _answers['soreness'] as int,
        sleep: _answers['sleep'] as int,
        motivation: _answers['motivation'] as int,
        painChange: _answers['pain_change'] as String,
        progressFeel: _answers['progress_feel'] as String,
      ),
    );
    if (!mounted) return;
    if (ok) {
      await _clearPartial();
      setState(() {
        _isDone = true;
        _isSubmitting = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop(true);
    } else {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa lưu được. Bạn thử lại nhé.')),
      );
    }
  }

  bool get _hasAllAnswers {
    return _questions.every((question) => _answers.containsKey(question.key));
  }

  @override
  Widget build(BuildContext context) {
    final question = _questions[_index];
    final showMascot = !ResearchPreferences.cachedConfig.isControl;
    final answered = _answers.containsKey(question.key);
    final last = _index == _questions.length - 1;

    return PopScope(
      onPopInvokedWithResult: (_, __) => unawaited(_savePartial()),
      child: Scaffold(
        backgroundColor: Tk.surface,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _isDone
                ? _ThankYouView(
                    key: const ValueKey('done'), showMascot: showMascot)
                : Column(
                    key: const ValueKey('form'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TkTopBar(
                        onBack: _back,
                        closeIcon: _index == 0,
                        progress: (_index + 1) / _questions.length,
                        trailing: '${_index + 1}/${_questions.length}',
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (showMascot)
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(6, 6, 20, 0),
                                  child: TkSpeechRow(
                                    asset: Tk.mascotThink,
                                    message: question.subtitle,
                                    mascotSize: 112,
                                  ),
                                ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(24, 18, 24, 0),
                                child: Text(
                                  question.title,
                                  style: Tk.text(26,
                                      weight: FontWeight.w900,
                                      height: 1.2,
                                      letterSpacing: -0.4),
                                ),
                              ),
                              if (!showMascot)
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(24, 6, 24, 0),
                                  child: Text(
                                    question.subtitle,
                                    style: Tk.text(15,
                                        weight: FontWeight.w700,
                                        color: Tk.inkSoft,
                                        height: 1.4),
                                  ),
                                ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(24, 20, 24, 0),
                                child: question.kind == _QuestionKind.scale
                                    ? _ScalePicker(
                                        selected:
                                            _answers[question.key] as int?,
                                        onChanged: _answer,
                                      )
                                    : _ChoicePicker(
                                        choices: question.choices,
                                        selected:
                                            _answers[question.key] as String?,
                                        onChanged: _answer,
                                      ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(24, 16, 24, 0),
                                child: Text(
                                  'Vika chỉ ghi nhận để hiểu nhịp hồi phục của bạn.',
                                  style: Tk.text(13,
                                      weight: FontWeight.w700,
                                      color: Tk.inkSoft),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                        child: TkButton(
                          label: last ? 'Hoàn tất' : 'Tiếp tục',
                          tone: TkButtonTone.green,
                          busy: _isSubmitting,
                          onTap: answered && !_isSubmitting ? _next : null,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ScalePicker extends StatelessWidget {
  const _ScalePicker({
    required this.selected,
    required this.onChanged,
  });

  final int? selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var value = 1; value <= 5; value++) ...[
          if (value > 1) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              button: true,
              selected: selected == value,
              child: TkCard(
                onTap: () => onChanged(value),
                radius: 16,
                padding: EdgeInsets.zero,
                color: selected == value ? Tk.primarySoft : Tk.surface,
                borderColor: selected == value ? Tk.primary : Tk.line,
                child: SizedBox(
                  height: 60,
                  child: Center(
                    child: Text(
                      '$value',
                      style: Tk.text(22,
                          weight: FontWeight.w900,
                          color: selected == value ? Tk.primaryLip : Tk.ink),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChoicePicker extends StatelessWidget {
  const _ChoicePicker({
    required this.choices,
    required this.selected,
    required this.onChanged,
  });

  final List<_Choice> choices;
  final String? selected;
  final ValueChanged<String> onChanged;

  static (Color, Color) _colors(_Tone tone) => switch (tone) {
        _Tone.green => (Tk.greenSoft, Tk.greenInk),
        _Tone.blue => (Tk.primarySoft, Tk.primary),
        _Tone.orange => (Tk.orangeSoft, Tk.orangeLip),
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final choice in choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Builder(builder: (context) {
              final active = selected == choice.value;
              final (soft, strong) = _colors(choice.tone);
              return Semantics(
                button: true,
                selected: active,
                child: TkCard(
                  onTap: () => onChanged(choice.value),
                  radius: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: active ? Tk.primarySoft : Tk.surface,
                  borderColor: active ? Tk.primary : Tk.line,
                  child: SizedBox(
                    height: 60,
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: active ? Tk.primary : soft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(choice.icon,
                              size: 18,
                              color: active ? Colors.white : strong),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            choice.label,
                            style: Tk.text(17,
                                weight: FontWeight.w900,
                                color: active ? Tk.primaryLip : Tk.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }
}

class _ThankYouView extends StatelessWidget {
  const _ThankYouView({super.key, required this.showMascot});

  final bool showMascot;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showMascot)
              const TkMascot(asset: Tk.mascotCheer, size: 190)
            else
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                    color: Tk.green, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 34),
              ),
            const SizedBox(height: 18),
            Text(
              'Cảm ơn bạn',
              textAlign: TextAlign.center,
              style: Tk.text(28, weight: FontWeight.w900, letterSpacing: -0.4),
            ),
            const SizedBox(height: 8),
            Text(
              'Vika đã lưu lại cảm nhận tuần này.',
              textAlign: TextAlign.center,
              style:
                  Tk.text(15, weight: FontWeight.w700, color: Tk.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

enum _QuestionKind { scale, choice }

class _Question {
  const _Question({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.kind,
    this.choices = const [],
  });

  final String key;
  final String title;
  final String subtitle;
  final _QuestionKind kind;
  final List<_Choice> choices;
}

class _Choice {
  const _Choice(this.value, this.label, this.icon, this.tone);

  final String value;
  final String label;
  final IconData icon;
  final _Tone tone;
}

enum _Tone { green, blue, orange }

const _questions = [
  _Question(
    key: 'energy',
    title: 'Năng lượng tuần này thế nào?',
    subtitle: 'Chọn nhanh theo cảm giác chung của bạn.',
    kind: _QuestionKind.scale,
  ),
  _Question(
    key: 'soreness',
    title: 'Đau cơ sau tập?',
    subtitle: '1 là rất nhẹ, 5 là khá nhiều.',
    kind: _QuestionKind.scale,
  ),
  _Question(
    key: 'sleep',
    title: 'Giấc ngủ tuần này?',
    subtitle: 'Vika chỉ ghi nhận để hiểu nhịp hồi phục của bạn.',
    kind: _QuestionKind.scale,
  ),
  _Question(
    key: 'motivation',
    title: 'Động lực tập?',
    subtitle: 'Không cần trả lời hoàn hảo. Cứ chọn đúng hôm nay.',
    kind: _QuestionKind.scale,
  ),
  _Question(
    key: 'pain_change',
    title: 'Đau nhức có thay đổi?',
    subtitle: 'So với tuần trước, cơ thể bạn đang nói gì?',
    kind: _QuestionKind.choice,
    choices: [
      _Choice('better', 'Tốt hơn', Icons.arrow_upward_rounded, _Tone.green),
      _Choice('same', 'Như cũ', Icons.remove_rounded, _Tone.blue),
      _Choice('worse', 'Tệ hơn', Icons.arrow_downward_rounded, _Tone.orange),
    ],
  ),
  _Question(
    key: 'progress_feel',
    title: 'Cảm thấy có tiến bộ?',
    subtitle: 'Cảm giác chủ quan cũng là dữ liệu quan trọng.',
    kind: _QuestionKind.choice,
    choices: [
      _Choice('yes', 'Có', Icons.check_rounded, _Tone.green),
      _Choice('unsure', 'Không chắc', Icons.help_outline_rounded, _Tone.blue),
      _Choice('no', 'Không', Icons.close_rounded, _Tone.orange),
    ],
  ),
];
