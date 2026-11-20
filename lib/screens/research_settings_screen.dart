import 'package:flutter/material.dart';

import '../services/research/research_log_exporter.dart';
import '../services/research/research_log_storage.dart';
import '../services/research/research_preferences.dart';
import '../theme/app_colors.dart';

class ResearchSettingsScreen extends StatefulWidget {
  const ResearchSettingsScreen({
    super.key,
    this.storage,
  });

  final ResearchLogStorage? storage;

  @override
  State<ResearchSettingsScreen> createState() => _ResearchSettingsScreenState();
}

class _ResearchSettingsScreenState extends State<ResearchSettingsScreen> {
  final TextEditingController _participantController = TextEditingController();
  ResearchCondition _condition = ResearchCondition.ai;
  int _storedFileCount = 0;
  bool _loading = true;
  bool _sharing = false;

  ResearchLogStorage get _storage =>
      widget.storage ?? ResearchLogStorage.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _participantController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await ResearchPreferences.load();
    final files = await _storage.listStoredLogFiles();
    if (!mounted) return;
    setState(() {
      _participantController.text = config.rawParticipantId;
      _condition = config.condition;
      _storedFileCount = files.length;
      _loading = false;
    });
  }

  Future<void> _saveParticipantId(String value) async {
    await ResearchPreferences.saveParticipantId(value);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _selectCondition(ResearchCondition condition) async {
    setState(() => _condition = condition);
    await ResearchPreferences.saveCondition(condition);
  }

  static Rect _shareOriginRect(BuildContext context) {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize && !box.size.isEmpty) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final screenSize = MediaQuery.maybeSizeOf(context);
    if (screenSize != null && !screenSize.isEmpty) {
      return Rect.fromCenter(
        center: Offset(screenSize.width / 2, screenSize.height / 2),
        width: 1,
        height: 1,
      );
    }
    return const Rect.fromLTWH(0, 0, 1, 1);
  }

  Future<void> _shareAll(BuildContext buttonContext) async {
    if (_sharing || _storedFileCount == 0) return;
    setState(() => _sharing = true);
    try {
      final shared = await ResearchLogExporter.shareAllStoredLogs(
        sharePositionOrigin: _shareOriginRect(buttonContext),
        storage: _storage,
      );
      if (!mounted) return;
      if (!shared) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Chưa có tệp nhật ký nào để chia sẻ hoặc chia sẻ không thành công.',
              ),
            ),
          );
      }
      final files = await _storage.listStoredLogFiles();
      if (mounted) {
        setState(() => _storedFileCount = files.length);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Không thể chia sẻ tệp nhật ký. Vui lòng thử lại.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final activeConfig = ResearchConfig(
      rawParticipantId: _participantController.text,
      condition: _condition,
    );

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        foregroundColor: c.ink,
        elevation: 0,
        title: Text(
          'Cài đặt nghiên cứu',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: c.ink,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  'MÃ NGƯỜI THAM GIA',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: c.inkSoft,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _participantController,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: _saveParticipantId,
                  onSubmitted: _saveParticipantId,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: P07 (để trống = anon)',
                    hintStyle: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 14,
                      color: c.inkFaint,
                    ),
                    filled: true,
                    fillColor: c.bgRaised,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: c.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: c.border),
                    ),
                    suffixIcon: _participantController.text.isNotEmpty
                        ? IconButton(
                            tooltip: 'Xóa mã',
                            icon: Icon(Icons.clear_rounded, color: c.inkSoft),
                            onPressed: () {
                              _participantController.clear();
                              _saveParticipantId('');
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Mã đang ghi vào tệp: ${activeConfig.participantId}',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 12.5,
                    color: c.inkSoft,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'ĐIỀU KIỆN THỬ NGHIỆM',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: c.inkSoft,
                  ),
                ),
                const SizedBox(height: 8),
                _ConditionOptionTile(
                  title: 'Có phản hồi AI (ai)',
                  subtitle:
                      'Hiển thị bộ đếm, khung xương, điểm số và giọng nhắc kỹ thuật như bình thường.',
                  selected: _condition == ResearchCondition.ai,
                  onTap: () => _selectCondition(ResearchCondition.ai),
                ),
                const SizedBox(height: 10),
                _ConditionOptionTile(
                  title: 'Đối chứng — không phản hồi (control)',
                  subtitle:
                      'Tắt giọng sửa lỗi, bộ đếm, khung xương và điểm số; vẫn chấm và lưu nhật ký ngầm.',
                  selected: _condition == ResearchCondition.control,
                  onTap: () => _selectCondition(ResearchCondition.control),
                ),
                const SizedBox(height: 28),
                Text(
                  'TỆP NHẬT KÝ TRÊN MÁY',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: c.inkSoft,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.bgRaised,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Số tệp nhật ký đang lưu: $_storedFileCount',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tối đa 300 tệp mới nhất được giữ trong bộ nhớ riêng của ứng dụng.',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 12.5,
                          color: c.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Builder(
                        builder: (buttonContext) => SizedBox(
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: (_sharing || _storedFileCount == 0)
                                ? null
                                : () => _shareAll(buttonContext),
                            style: FilledButton.styleFrom(
                              backgroundColor: c.yellow,
                              foregroundColor: c.yellowInk,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.ios_share_rounded, size: 18),
                            label: Text(
                              _sharing
                                  ? 'Đang chuẩn bị chia sẻ…'
                                  : 'Chia sẻ tất cả tệp nhật ký',
                              style: const TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ConditionOptionTile extends StatelessWidget {
  const _ConditionOptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.bgRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? c.yellow : c.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? c.yellow : c.inkFaint,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 12.5,
                      height: 1.4,
                      color: c.inkSoft,
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
