import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

Future<int?> showSessionSatisfactionDialog(BuildContext context) {
  return showDialog<int?>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final c = VikaColors.of(dialogContext);
      return Dialog(
        backgroundColor: c.bgRaised,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bạn hài lòng thế nào với buổi tập hôm nay?',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '1 = Rất không hài lòng · 5 = Rất hài lòng',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 12.5,
                  color: c.inkSoft,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  for (var rating = 1; rating <= 5; rating++) ...[
                    if (rating > 1) const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            side: BorderSide(color: c.border, width: 1.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            backgroundColor: c.bg,
                            foregroundColor: c.ink,
                          ),
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(rating),
                          child: Text(
                            '$rating',
                            style: const TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: Text(
                    'Bỏ qua',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: c.inkSoft,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
