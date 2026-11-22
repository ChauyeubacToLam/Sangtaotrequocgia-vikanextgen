// BodyPainReporter — "The Anatomy Stage".
//
// A tappable pain self-report rendered as a cinematic dark instrument that
// speaks the Progress stage-hero language (warm-dark canvas, ambient glow,
// film grain, italic display, reserved yellow). The body is a luminous ivory
// figure; a reported area glows warm FROM WITHIN the silhouette — the body
// itself lights up — rather than wearing a dot on top. Numbered callout nodes
// link the figure to an editorial intensity ledger beneath it.
//
// The "glow from within" is the silhouette PNG recolored to the pain tone
// (BlendMode.srcIn) and then radial-masked at the zone, so the light is the
// body's own shape fading out — not a circle floating over it.
//
// CAPTURE-ONLY. Nothing here reads a report back into the plan or exercises.
//
// Asset PNGs: assets/images/body_male.png and body_female.png.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/pain_regions.dart';
import '../../theme/app_colors.dart';
import 'body_3d.dart';

/// One reported pain area, shaped for display. [intensity] is 1..5 (null on
/// legacy rows); [confirmed] lights an interpreter-confirmed origin
/// differently from a plain self-report; [notes] is the free-text behind an
/// 'other' report.
class PainMark {
  const PainMark({
    required this.intensity,
    this.confirmed = false,
    this.notes,
  });

  final int? intensity;
  final bool confirmed;
  final String? notes;
}

typedef PainReportCallback = void Function(
  String region,
  int intensity,
  String? notes,
);
typedef PainResolveCallback = void Function(String region);

// ─── Intensity language ───────────────────────────────────────────

/// VN anchors for the intensity ladder. Ends + middle are named; 2 and 4 are
/// unlabeled in-between steps.
const Map<int, String> _intensityAnchors = {
  1: 'Hơi đau',
  3: 'Đau vừa',
  5: 'Rất đau',
};

String _intensityWord(int? i) => switch (i) {
      1 => 'Hơi đau',
      2 => 'Đau nhẹ',
      3 => 'Đau vừa',
      4 => 'Khá đau',
      5 => 'Rất đau',
      _ => 'Đang theo dõi',
    };

/// Warm caution scale — soft amber (1) → deep ember-red (5). Inside the
/// Premium Ivory warm family: never the reserved yellow, never a pure red.
Color _intensityColor(int? i) {
  const scale = [
    Color(0xFFF0C07A), // 1 — soft amber
    Color(0xFFEEA24E), // 2
    Color(0xFFE57E39), // 3
    Color(0xFFDB5F2E), // 4
    Color(0xFFC8462A), // 5 — deep ember
  ];
  if (i == null) return scale[2];
  return scale[(i.clamp(1, 5)) - 1];
}

// ═══════════════════════════════════════════════════════════════════
// THE STAGE
// ═══════════════════════════════════════════════════════════════════

class BodyPainReporter extends StatefulWidget {
  const BodyPainReporter({
    super.key,
    required this.reports,
    required this.gender,
    required this.onReport,
    required this.onResolve,
    this.figureHeight = 330,
  });

  /// region id → reported mark. Absent = not reported.
  final Map<String, PainMark> reports;
  final BodyGender gender;
  final PainReportCallback onReport;
  final PainResolveCallback onResolve;
  final double figureHeight;

  @override
  State<BodyPainReporter> createState() => _BodyPainReporterState();
}

class _BodyPainReporterState extends State<BodyPainReporter> {
  Future<void> _openPicker({
    required String region,
    required String label,
    required bool isOther,
    String? notesHint,
  }) async {
    HapticFeedback.selectionClick();
    final existing = widget.reports[region];
    final result = await showModalBottomSheet<_PickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xFF130E09).withValues(alpha: 0.62),
      builder: (_) => _IntensitySheet(
        regionLabel: label,
        isOther: isOther,
        initialIntensity: existing?.intensity,
        initialNotes: notesHint ?? existing?.notes,
        editing: existing != null,
      ),
    );
    if (!mounted || result == null) return;
    if (result.remove) {
      widget.onResolve(region);
    } else {
      widget.onReport(region, result.intensity!, isOther ? result.notes : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final reports = widget.reports;

    // Active body reports, top-to-bottom, with stable callout ordinals.
    final activeBody = [
      for (final r in painRegions)
        if (reports.containsKey(r.id)) r,
    ];
    final ordinals = <String, int>{
      for (var i = 0; i < activeBody.length; i++) activeBody[i].id: i + 1,
    };
    final other = reports[kOtherPainRegion];
    final isEmpty = reports.isEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: const Alignment(-0.6, -1),
            end: const Alignment(0.6, 1),
            colors: [c.bgInverse, c.bgInverseHi],
          ),
          boxShadow: [
            BoxShadow(
              color: c.ink.withValues(alpha: 0.28),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Overhead spotlight bathing the figure.
            const Positioned(
              top: -150,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: _AmbientGlow(
                    size: Size(360, 360),
                    color: Color(0xFFFFCF7A),
                    opacity: 0.12,
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(child: _GrainTexture(opacity: 0.045)),
            ),
            const Positioned.fill(
              child: IgnorePointer(child: _Vignette()),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PanelEyebrow(count: reports.length),
                  const SizedBox(height: 6),
                  Center(
                    child: Body3DPicker(
                      gender: widget.gender,
                      height: widget.figureHeight,
                      colorFor: (part) {
                        final region = part.region;
                        final mark = region != null
                            ? reports[region]
                            : (other?.notes?.trim() == part.label
                                ? other
                                : null);
                        return mark == null
                            ? null
                            : _intensityColor(mark.intensity);
                      },
                      onTapPart: (part) {
                        final region = part.region;
                        if (region != null) {
                          _openPicker(
                            region: region,
                            label: part.displayLabel,
                            isOther: false,
                          );
                        } else {
                          _openPicker(
                            region: kOtherPainRegion,
                            label: part.label,
                            isOther: true,
                            notesHint: part.label,
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (isEmpty)
                    const _EmptyPrompt()
                  else ...[
                    _HairlineRule(color: c.invInk.withValues(alpha: 0.10)),
                    const SizedBox(height: 14),
                    for (final r in activeBody)
                      _LedgerRow(
                        ordinal: ordinals[r.id]!,
                        label: r.vnLabel,
                        mark: reports[r.id]!,
                        onTap: () => _openPicker(
                          region: r.id,
                          label: r.vnLabel,
                          isOther: false,
                        ),
                      ),
                    if (other != null)
                      _LedgerRow(
                        ordinal: null,
                        label: 'Khác',
                        mark: other,
                        onTap: () => _openPicker(
                          region: kOtherPainRegion,
                          label: 'Khác',
                          isOther: true,
                        ),
                      ),
                  ],
                  const SizedBox(height: 14),
                  _OtherTile(
                    reported: other != null,
                    onTap: () => _openPicker(
                      region: kOtherPainRegion,
                      label: 'Khác',
                      isOther: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// In-panel instrument label: a sparkle + hint, with a live count chip.
class _PanelEyebrow extends StatelessWidget {
  const _PanelEyebrow({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      children: [
        const _Sparkle(size: 10),
        const SizedBox(width: 8),
        Text(
          'KÉO ĐỂ XOAY · CHẠM VÀO VÙNG ĐAU',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            color: c.invInkSoft.withValues(alpha: 0.65),
          ),
        ),
        const Spacer(),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: c.yellow.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border:
                  Border.all(color: c.yellow.withValues(alpha: 0.32), width: 1),
            ),
            child: Text(
              '$count VÙNG',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: c.yellow,
              ),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// LEDGER — editorial list of active reports under the figure
// ═══════════════════════════════════════════════════════════════════

class _EmptyPrompt extends StatelessWidget {
  const _EmptyPrompt();

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Text(
        'Bạn chưa ghi nhận vùng đau nào. Chạm vào cơ thể nếu có chỗ khó chịu.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          height: 1.55,
          letterSpacing: 0.1,
          color: c.invInkSoft,
        ),
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.ordinal,
    required this.label,
    required this.mark,
    required this.onTap,
  });

  final int? ordinal; // null for 'other' (no body node)
  final String label;
  final PainMark mark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final accent = _intensityColor(mark.intensity);
    final note = mark.notes?.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: c.invInk.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
            child: Row(
              children: [
                // Callout ordinal (matches the body node) or a glow dot.
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ordinal != null
                        ? accent.withValues(alpha: 0.18)
                        : Colors.transparent,
                    border: Border.all(
                      color: accent.withValues(alpha: 0.65),
                      width: 1.4,
                    ),
                  ),
                  child: ordinal != null
                      ? Text(
                          '$ordinal',
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: accent,
                            height: 1,
                          ),
                        )
                      : Icon(Icons.edit_note_rounded, size: 13, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: c.invInk,
                              ),
                            ),
                          ),
                          if (mark.confirmed) ...[
                            const SizedBox(width: 8),
                            _ConfirmedChip(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          _IntensityMeter(level: mark.intensity),
                          const SizedBox(width: 10),
                          Text(
                            _intensityWord(mark.intensity),
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                      if (note != null && note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                            color: c.invInkFaint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: c.invInk.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A slim 5-segment intensity readout; fills up to [level] in the warm scale.
class _IntensityMeter extends StatelessWidget {
  const _IntensityMeter({required this.level});
  final int? level;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final lvl = level ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++) ...[
          Container(
            width: 16,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: i <= lvl
                  ? _intensityColor(i)
                  : c.invInk.withValues(alpha: 0.14),
            ),
          ),
          if (i < 5) const SizedBox(width: 3),
        ],
      ],
    );
  }
}

class _ConfirmedChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.invInk.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'VIKA GHI NHẬN',
        style: TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: c.invInkFaint,
        ),
      ),
    );
  }
}

class _OtherTile extends StatelessWidget {
  const _OtherTile({required this.reported, required this.onTap});
  final bool reported;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // When 'other' is already active it shows in the ledger; the footer then
    // only offers a quiet "edit" path, so we hide the add-affordance.
    if (reported) return const SizedBox.shrink();
    final c = VikaColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: c.invInk.withValues(alpha: 0.14),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded,
                  size: 17, color: c.invInkSoft.withValues(alpha: 0.8)),
              const SizedBox(width: 8),
              Text(
                'Ghi vùng khác',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                  color: c.invInkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HairlineRule extends StatelessWidget {
  const _HairlineRule({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(height: 1, color: color);
}

// ═══════════════════════════════════════════════════════════════════
// INTENSITY PICKER — dark sheet, tactile "levels" ladder
// ═══════════════════════════════════════════════════════════════════

class _PickerResult {
  const _PickerResult({this.intensity, this.notes, this.remove = false});
  final int? intensity;
  final String? notes;
  final bool remove;
}

class _IntensitySheet extends StatefulWidget {
  const _IntensitySheet({
    required this.regionLabel,
    required this.isOther,
    required this.initialIntensity,
    required this.initialNotes,
    required this.editing,
  });

  final String regionLabel;
  final bool isOther;
  final int? initialIntensity;
  final String? initialNotes;
  final bool editing;

  @override
  State<_IntensitySheet> createState() => _IntensitySheetState();
}

class _IntensitySheetState extends State<_IntensitySheet> {
  late int? _intensity = widget.initialIntensity;
  late final TextEditingController _notes =
      TextEditingController(text: widget.initialNotes ?? '');

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _select(int v) {
    HapticFeedback.selectionClick();
    setState(() => _intensity = v);
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final canConfirm = _intensity != null;
    final accent = _intensityColor(_intensity);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(-0.6, -1),
              end: const Alignment(0.6, 1),
              colors: [c.bgInverse, c.bgInverseHi],
            ),
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                child: IgnorePointer(child: _GrainTexture(opacity: 0.05)),
              ),
              Positioned(
                top: -120,
                right: -60,
                child: IgnorePointer(
                  child: _AmbientGlow(
                    size: const Size(280, 280),
                    color: accent,
                    opacity: 0.16,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: c.invInk.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'CHẠM ĐỂ GHI',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                        color: c.invInkFaint,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.regionLabel,
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -1.0,
                        height: 1.0,
                        color: c.invInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Live readout: the chosen word, colored by intensity.
                    SizedBox(
                      height: 20,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          _intensity == null
                              ? 'Đau cỡ nào?'
                              : _intensityWord(_intensity),
                          key: ValueKey(_intensity),
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _intensity == null ? c.invInkSoft : accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // The levels ladder — five rising bars.
                    SizedBox(
                      height: 84,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 1; i <= 5; i++)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(right: i < 5 ? 10 : 0),
                                child: _LevelBar(
                                  level: i,
                                  height: 34.0 + (i - 1) * 12.0,
                                  active:
                                      _intensity != null && i <= _intensity!,
                                  isSelected: _intensity == i,
                                  onTap: () => _select(i),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _Anchor(_intensityAnchors[1]!, TextAlign.left),
                        ),
                        Expanded(
                          child:
                              _Anchor(_intensityAnchors[3]!, TextAlign.center),
                        ),
                        Expanded(
                          child:
                              _Anchor(_intensityAnchors[5]!, TextAlign.right),
                        ),
                      ],
                    ),

                    if (widget.isOther) ...[
                      const SizedBox(height: 22),
                      TextField(
                        controller: _notes,
                        maxLength: 80,
                        cursorColor: c.yellow,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.invInk,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Vùng nào? (ví dụ: khuỷu tay)',
                          hintStyle: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: c.invInkFaint,
                          ),
                          counterText: '',
                          filled: true,
                          fillColor: c.invInk.withValues(alpha: 0.06),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: c.invInk.withValues(alpha: 0.14)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: c.yellow.withValues(alpha: 0.6)),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    _ConfirmButton(
                      label: widget.editing ? 'Cập nhật' : 'Ghi nhận',
                      enabled: canConfirm,
                      onTap: canConfirm
                          ? () => Navigator.of(context).pop(
                                _PickerResult(
                                  intensity: _intensity,
                                  notes: _notes.text.trim().isEmpty
                                      ? null
                                      : _notes.text.trim(),
                                ),
                              )
                          : null,
                    ),
                    if (widget.editing) ...[
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () => Navigator.of(context)
                            .pop(const _PickerResult(remove: true)),
                        child: Text(
                          'Bỏ vùng này',
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: c.invInkFaint,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({
    required this.level,
    required this.height,
    required this.active,
    required this.isSelected,
    required this.onTap,
  });

  final int level;
  final double height;
  final bool active;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final accent = _intensityColor(level);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: active ? accent : c.invInk.withValues(alpha: 0.07),
              border: Border.all(
                color: active
                    ? accent
                    : c.invInk.withValues(alpha: isSelected ? 0.4 : 0.16),
                width: 1.2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: accent.withValues(alpha: 0.5), blurRadius: 14)
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '$level',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: active ? c.bgInverse : c.invInkFaint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Anchor extends StatelessWidget {
  const _Anchor(this.text, this.align);
  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Text(
      text,
      textAlign: align,
      style: TextStyle(
        fontFamily: 'BeVietnamPro',
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: c.invInkSoft,
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: c.yellow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: c.yellow.withValues(alpha: 0.4),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: c.yellowInk,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ATMOSPHERE — inlined per the design-system rule
// ═══════════════════════════════════════════════════════════════════

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({
    required this.size,
    required this.color,
    required this.opacity,
  });
  final Size size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _Vignette extends StatelessWidget {
  const _Vignette();
  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          radius: 0.9,
          colors: [Colors.transparent, Color(0x44000000)],
          stops: [0.62, 1.0],
        ),
      ),
    );
  }
}

class _GrainTexture extends StatelessWidget {
  const _GrainTexture({required this.opacity});
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _GrainPainter(opacity: opacity),
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter({required this.opacity});
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(421); // deterministic — never time-based
    final count = (size.width * size.height * 0.0009).round();
    final paint = Paint()..isAntiAlias = false;
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final a = rng.nextDouble() * opacity;
      final tone = rng.nextDouble();
      paint.color =
          (tone > 0.5 ? Colors.white : Colors.black).withValues(alpha: a);
      canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter old) => old.opacity != opacity;
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SparklePainter(color: c.yellow)),
    );
  }
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.58, h * 0.42)
      ..lineTo(w, h * 0.5)
      ..lineTo(w * 0.58, h * 0.58)
      ..lineTo(w * 0.5, h)
      ..lineTo(w * 0.42, h * 0.58)
      ..lineTo(0, h * 0.5)
      ..lineTo(w * 0.42, h * 0.42)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.color != color;
}
