import 'package:flutter/material.dart';

import '../../screens/exercise/widgets/sensor_rotated_box.dart';
import '../tk/tk.dart';

Future<int?> showSessionSatisfactionDialog(BuildContext context) {
  return showDialog<int?>(
    context: context,
    barrierDismissible: true,
    barrierColor: const Color(0xB31E1B4B),
    builder: (dialogContext) {
      return SensorRotatedBox(
          child: Dialog(
        backgroundColor: Tk.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('MỘT CÂU HỎI NHỎ', style: Tk.eyebrow()),
              const SizedBox(height: 6),
              Text(
                'Bạn hài lòng thế nào với buổi tập hôm nay?',
                style: Tk.text(22,
                    weight: FontWeight.w900, height: 1.25, letterSpacing: -0.3),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (var rating = 1; rating <= 5; rating++) ...[
                    if (rating > 1) const SizedBox(width: 8),
                    Expanded(
                      child: TkCard(
                        onTap: () => Navigator.of(dialogContext).pop(rating),
                        radius: 16,
                        padding: EdgeInsets.zero,
                        child: SizedBox(
                          height: 54,
                          child: Center(
                            child: Text('$rating',
                                style: Tk.text(22, weight: FontWeight.w900)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: Text('Rất không hài lòng',
                          style: Tk.text(12.5,
                              weight: FontWeight.w800, color: Tk.inkSoft))),
                  Text('Rất hài lòng',
                      style: Tk.text(12.5,
                          weight: FontWeight.w800, color: Tk.inkSoft)),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: Text('Bỏ qua',
                      style: Tk.text(15,
                          weight: FontWeight.w900, color: Tk.primary)),
                ),
              ),
            ],
          ),
        ),
      ));
    },
  );
}
