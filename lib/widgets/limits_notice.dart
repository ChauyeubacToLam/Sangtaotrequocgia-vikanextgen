import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/exercise/widgets/sensor_rotated_box.dart';
import 'tk/tk.dart';

const String kPrivacyPolicyUrl = 'https://vikavn.app/privacy.html';
const String kLimitsNoticeTitle = 'Vika làm được gì và chưa làm được gì';
const String kFormScoreDisclaimer =
    'Điểm form do AI ước lượng kỹ thuật động tác, không phải đánh giá sức khỏe.';

const List<(IconData, String)> kLimitsNoticePoints = [
  (
    Icons.insights_rounded,
    'Vika đếm rep và nhắc kỹ thuật động tác qua camera. Điểm form là ước '
        'lượng kỹ thuật, không phải đánh giá sức khỏe hay chẩn đoán.',
  ),
  (
    Icons.medical_services_outlined,
    'Vika không thay thế bác sĩ, chuyên gia vật lý trị liệu hay huấn luyện '
        'viên.',
  ),
  (
    Icons.wb_twilight_rounded,
    'AI có thể đếm sai khi thiếu sáng, đặt máy sai góc hoặc có nhiều người '
        'trong khung hình.',
  ),
  (
    Icons.videocam_off_outlined,
    'Camera xử lý ngay trên máy. Vika không quay, không lưu và không gửi '
        'video đi. Chỉ kết quả dạng số được lưu: số rep, điểm và lỗi.',
  ),
  (
    Icons.health_and_safety_outlined,
    'Dừng ngay nếu đau nhói, chóng mặt hoặc khó thở.',
  ),
];

Future<bool> showLimitsNotice(
  BuildContext context, {
  bool requireAck = false,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: !requireAck,
    barrierLabel: 'Đóng',
    barrierColor: const Color(0xCC0F0A06),
    pageBuilder: (dialogContext, _, __) {
      final card = LimitsNoticeCard(
        requireAck: requireAck,
        onDone: () => Navigator.of(dialogContext).pop(true),
      );
      return requireAck ? SensorRotatedBox(child: card) : card;
    },
  );
  return result ?? false;
}

class LimitsNoticeCard extends StatelessWidget {
  const LimitsNoticeCard({
    super.key,
    required this.requireAck,
    required this.onDone,
  });

  final bool requireAck;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final privacyLink = TextButton.icon(
      onPressed: () => launchUrl(
        Uri.parse(kPrivacyPolicyUrl),
        mode: LaunchMode.externalApplication,
      ),
      icon: const Icon(Icons.open_in_new_rounded, size: 18),
      label: Text(
        'Đọc chính sách quyền riêng tư',
        style: Tk.text(14.5, weight: FontWeight.w900, color: Tk.primary),
      ),
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Material(
            color: Tk.surface,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 600;
                final doneButton = TkButton(
                  label: requireAck ? 'Tôi đã hiểu' : 'Đóng',
                  onTap: onDone,
                  height: wide ? 46 : 52,
                );
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        padding: wide
                            ? const EdgeInsets.fromLTRB(22, 14, 22, 0)
                            : const EdgeInsets.fromLTRB(22, 20, 22, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('GIỚI HẠN & QUYỀN RIÊNG TƯ',
                                style: Tk.eyebrow()),
                            SizedBox(height: wide ? 2 : 6),
                            Text(
                              kLimitsNoticeTitle,
                              style: Tk.text(wide ? 19 : 22,
                                  weight: FontWeight.w900, height: 1.2),
                            ),
                            SizedBox(height: wide ? 8 : 14),
                            for (final (icon, text) in kLimitsNoticePoints)
                              Padding(
                                padding: EdgeInsets.only(bottom: wide ? 5 : 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(icon,
                                        size: wide ? 19 : 22,
                                        color: Tk.primary),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        text,
                                        style: Tk.text(wide ? 13.5 : 14.5,
                                            weight: FontWeight.w700,
                                            height: wide ? 1.3 : 1.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: wide
                          ? const EdgeInsets.fromLTRB(12, 2, 22, 10)
                          : const EdgeInsets.fromLTRB(12, 4, 22, 14),
                      child: wide
                          ? Row(
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: privacyLink,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(width: 240, child: doneButton),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: privacyLink,
                                ),
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.only(left: 10),
                                  child: doneButton,
                                ),
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
