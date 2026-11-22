import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tk/tk.dart';

class IvoryBottomNav extends StatelessWidget {
  const IvoryBottomNav({
    super.key,
    required this.currentIndex,
    required this.bottomInset,
    required this.onTap,
    this.showNutrition = false,
  });

  final int currentIndex;
  final double bottomInset;
  final ValueChanged<int> onTap;
  final bool showNutrition;

  static const _all = <(String, IconData, IconData)>[
    ('Trang chủ', Icons.home_rounded, Icons.home_outlined),
    ('Kế hoạch', Icons.calendar_month_rounded, Icons.calendar_month_outlined),
    ('Thư viện', Icons.grid_view_rounded, Icons.grid_view_outlined),
    (
      'Dinh dưỡng',
      Icons.restaurant_menu_rounded,
      Icons.restaurant_menu_outlined
    ),
    ('Tiến độ', Icons.bar_chart_rounded, Icons.bar_chart_rounded),
    ('Hồ sơ', Icons.person_rounded, Icons.person_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final items = [
      for (var i = 0; i < _all.length; i++)
        if (showNutrition || i != 3) _all[i],
    ];
    return Container(
      padding: EdgeInsets.fromLTRB(6, 8, 6, 8 + bottomInset),
      decoration: const BoxDecoration(
        color: Tk.surface,
        border: Border(top: BorderSide(color: Color(0xFFECEDF5), width: 2)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _NavItem(
                label: items[i].$1,
                icon: i == currentIndex ? items[i].$2 : items[i].$3,
                active: i == currentIndex,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap(i);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? Tk.primary : Tk.inkSoft;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: active ? Tk.primarySoft : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: active ? Tk.primaryLine : Colors.transparent,
                    width: 2),
              ),
              child: AnimatedScale(
                scale: active ? 1.08 : 1,
                duration: const Duration(milliseconds: 200),
                child: Icon(icon, size: 26, color: color),
              ),
            ),
            const SizedBox(height: 3),
            ExcludeSemantics(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: Tk.text(11,
                      weight: active ? FontWeight.w900 : FontWeight.w800,
                      color: color),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
