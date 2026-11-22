import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../nutrition/food_db.dart';
import '../../widgets/tk/tk.dart';

Future<void> showNutritionSources(BuildContext context, FoodDb db) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Tk.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Text('Nguồn khoa học', style: Tk.text(24, weight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            'Mọi con số về nhu cầu, khẩu phần và thành phần món ăn trong Vika đều lấy từ các nguồn dưới đây. '
            'Đây là thông tin tham khảo, không thay cho tư vấn của bác sĩ hay chuyên gia dinh dưỡng.',
            style: Tk.text(14,
                weight: FontWeight.w600, color: Tk.inkSoft, height: 1.45),
          ),
          const SizedBox(height: 16),
          for (final s in db.sources.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TkCard(
                lip: false,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                onTap: s.url.isEmpty
                    ? null
                    : () => launchUrl(Uri.parse(s.url),
                        mode: LaunchMode.externalApplication),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(s.cite,
                          style: Tk.text(13.5,
                              weight: FontWeight.w700, height: 1.4)),
                    ),
                    if (s.url.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(left: 8, top: 2),
                        child: Icon(Icons.open_in_new_rounded,
                            size: 18, color: Tk.primary),
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
