import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class Tk {
  static const Color primary = Color(0xFF2B5CE6);
  static const Color primaryLip = Color(0xFF1B44B8);
  static const Color primarySoft = Color(0xFFEEF2FF);
  static const Color primaryLine = Color(0xFFC9D4FA);
  static const Color orange = Color(0xFFFF8A1F);
  static const Color orangeLip = Color(0xFFD96A00);
  static const Color orangeSoft = Color(0xFFFFF1E3);
  static const Color orangeInk = Color(0xFF9A4300);
  static const Color green = Color(0xFF3CC35A);
  static const Color greenLip = Color(0xFF2A9A43);
  static const Color greenSoft = Color(0xFFEDF8F0);
  static const Color greenInk = Color(0xFF1F6B33);
  static const Color red = Color(0xFFE5484D);
  static const Color redInk = Color(0xFFC62B31);
  static const Color ink = Color(0xFF1E1B4B);
  static const Color inkSoft = Color(0xFF6B6890);
  static const Color inkMuted = Color(0xFF8E8BAE);
  static const Color line = Color(0xFFE3E4F0);
  static const Color lineSoft = Color(0xFFF1F2F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF6F7FC);
  static const Color indigo = Color(0xFF231E5C);
  static const Color indigoHi = Color(0xFF2E2880);
  static const Color indigoLine = Color(0xFF5049A8);
  static const Color onIndigoSoft = Color(0xFFD6D3F7);

  static const String font = 'BeVietnamPro';

  static TextStyle text(
    double size, {
    FontWeight weight = FontWeight.w800,
    Color color = ink,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: font,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle eyebrow({Color color = inkSoft}) =>
      text(13, weight: FontWeight.w900, color: color, letterSpacing: 1);

  static const String mascotWave = 'assets/mascot/tac_ke_wave.webp';
  static const String mascotThumbsUp = 'assets/mascot/tac_ke_thumbs_up.webp';
  static const String mascotPhone = 'assets/mascot/tac_ke_phone_setup.webp';
  static const String mascotPoint = 'assets/mascot/tac_ke_point.webp';
  static const String mascotCheer = 'assets/mascot/tac_ke_cheer.webp';
  static const String mascotTrophy = 'assets/mascot/tac_ke_trophy.webp';
  static const String mascotThink = 'assets/mascot/tac_ke_think.webp';
  static const String mascotEncourage = 'assets/mascot/tac_ke_encourage.webp';
  static const String mascotStreak = 'assets/mascot/tac_ke_streak.webp';
  static const String mascotHead = 'assets/mascot/tac_ke_head.webp';
}

class TkPressable extends StatefulWidget {
  const TkPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.lipColor,
    this.lipDepth = 4,
    this.radius = 16,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? lipColor;
  final double lipDepth;
  final double radius;
  final bool haptic;

  @override
  State<TkPressable> createState() => _TkPressableState();
}

class _TkPressableState extends State<TkPressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final depth = widget.lipDepth;
    final shift = _down ? depth : 0.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.lightImpact();
              widget.onTap!();
            },
      child: Padding(
        padding: EdgeInsets.only(bottom: depth),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          transform: Matrix4.translationValues(0, shift, 0),
          decoration: widget.lipColor == null
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.radius),
                  boxShadow: [
                    BoxShadow(
                      color: widget.lipColor!,
                      offset: Offset(0, depth - shift),
                    ),
                  ],
                ),
          child: widget.child,
        ),
      ),
    );
  }
}

enum TkButtonTone { primary, green, orange, outline, white, ghostOnDark }

class TkButton extends StatelessWidget {
  const TkButton({
    super.key,
    required this.label,
    required this.onTap,
    this.tone = TkButtonTone.primary,
    this.busy = false,
    this.icon,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onTap;
  final TkButtonTone tone;
  final bool busy;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final (bg, lip, fg, border) = switch (tone) {
      TkButtonTone.primary => (Tk.primary, Tk.primaryLip, Colors.white, null),
      TkButtonTone.green => (Tk.green, Tk.greenLip, const Color(0xFF10351B), null),
      TkButtonTone.orange => (Tk.orange, Tk.orangeLip, const Color(0xFF2B1300), null),
      TkButtonTone.outline => (Tk.surface, Tk.line, Tk.primary, Tk.line),
      TkButtonTone.white => (Colors.white, const Color(0xFFB8B3EE), Tk.indigo, null),
      TkButtonTone.ghostOnDark => (Tk.indigo, Tk.indigoLine, Colors.white, Tk.indigoLine),
    };
    final disabled = onTap == null && !busy;
    final effectiveBg = disabled ? const Color(0xFFE5E5EF) : bg;
    final effectiveLip = disabled ? const Color(0xFFD0D0DE) : lip;
    final effectiveFg = disabled ? Tk.inkMuted : fg;
    return TkPressable(
      onTap: busy ? null : onTap,
      lipColor: effectiveLip,
      child: Container(
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: BorderRadius.circular(16),
          border: border == null ? null : Border.all(color: border, width: 2),
        ),
        child: busy
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.6, color: effectiveFg),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: effectiveFg, size: 22),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label.toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Tk.text(16.5, weight: FontWeight.w900, color: effectiveFg, letterSpacing: 0.6),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class TkCard extends StatelessWidget {
  const TkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = Tk.surface,
    this.borderColor = Tk.line,
    this.lip = true,
    this.radius = 22,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final bool lip;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: child,
    );
    if (onTap == null && !lip) return body;
    return TkPressable(
      onTap: onTap,
      lipColor: lip ? borderColor : null,
      radius: radius,
      haptic: onTap != null,
      child: body,
    );
  }
}

class TkProgressBar extends StatelessWidget {
  const TkProgressBar({
    super.key,
    required this.value,
    this.color = Tk.primary,
    this.height = 16,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: const Color(0xFFE9EAF4),
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0, 1)),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => FractionallySizedBox(
            widthFactor: v,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height),
              ),
              alignment: Alignment.topCenter,
              padding: EdgeInsets.fromLTRB(6, height * 0.2, 6, 0),
              child: Container(
                height: height * 0.25,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TkSegmented extends StatelessWidget {
  const TkSegmented({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Tk.lineSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onChanged == null
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        onChanged!(i);
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? Tk.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: i == selected
                        ? const [BoxShadow(color: Color(0xFFDADCEB), offset: Offset(0, 2))]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: Tk.text(
                      15,
                      weight: i == selected ? FontWeight.w900 : FontWeight.w800,
                      color: i == selected ? Tk.ink : Tk.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TkField extends StatelessWidget {
  const TkField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.obscure = false,
    this.suffix,
    this.autofillHints,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final style = Tk.text(17, weight: FontWeight.w700);
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: 2),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Tk.text(13, weight: FontWeight.w900, color: Tk.inkSoft, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          autocorrect: false,
          enableSuggestions: !obscure,
          autofillHints: autofillHints,
          onSubmitted: onSubmitted,
          cursorColor: Tk.primary,
          style: style,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Tk.surfaceSoft,
            hintText: hint,
            hintStyle: style.copyWith(color: const Color(0xFF9A97B8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: border(const Color(0xFFE1E3F0)),
            focusedBorder: border(Tk.primary),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

class TkMascot extends StatefulWidget {
  const TkMascot({
    super.key,
    required this.asset,
    this.size = 120,
    this.bob = true,
    this.semanticLabel,
  });

  final String asset;
  final double size;
  final bool bob;
  final String? semanticLabel;

  @override
  State<TkMascot> createState() => _TkMascotState();
}

class _TkMascotState extends State<TkMascot> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    if (widget.bob) {
      _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      widget.asset,
      width: widget.size,
      height: widget.size,
      cacheWidth: (widget.size * MediaQuery.devicePixelRatioOf(context))
          .round()
          .clamp(64, 768),
      fit: BoxFit.contain,
      semanticLabel: widget.semanticLabel,
      excludeFromSemantics: widget.semanticLabel == null,
    );
    final c = _c;
    if (c == null) return image;
    return AnimatedBuilder(
      animation: c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(c.value);
        return Transform.translate(
          offset: Offset(0, -6 * t),
          child: Transform.scale(scaleY: 1 - 0.015 * (1 - t), alignment: Alignment.bottomCenter, child: child),
        );
      },
      child: image,
    );
  }
}

class TkSpeechRow extends StatelessWidget {
  const TkSpeechRow({
    super.key,
    required this.asset,
    required this.message,
    this.mascotSize = 124,
  });

  final String asset;
  final String message;
  final double mascotSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TkMascot(asset: asset, size: mascotSize),
        const SizedBox(width: 4),
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
                decoration: BoxDecoration(
                  color: Tk.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Tk.line, width: 2),
                ),
                child: Text(message, style: Tk.text(16.5, height: 1.35)),
              ),
              Positioned(
                left: -8,
                top: 24,
                child: Transform.rotate(
                  angle: 0.785398,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: Tk.surface,
                      border: Border(
                        left: BorderSide(color: Tk.line, width: 2),
                        bottom: BorderSide(color: Tk.line, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TkTopBar extends StatelessWidget {
  const TkTopBar({super.key, this.onBack, this.progress, this.trailing, this.closeIcon = false});

  final VoidCallback? onBack;
  final double? progress;
  final String? trailing;
  final bool closeIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: onBack == null
                ? null
                : IconButton(
                    onPressed: onBack,
                    tooltip: closeIcon ? 'Đóng' : 'Quay lại',
                    icon: Icon(
                      closeIcon ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded,
                      color: Tk.inkSoft,
                      size: closeIcon ? 28 : 22,
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          if (progress != null) Expanded(child: TkProgressBar(value: progress!)) else const Spacer(),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            Text(trailing!, style: Tk.text(15, weight: FontWeight.w900, color: Tk.inkSoft)),
          ],
        ],
      ),
    );
  }
}
