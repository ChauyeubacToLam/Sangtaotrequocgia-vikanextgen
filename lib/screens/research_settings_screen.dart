import 'package:flutter/material.dart';

import '../services/research/research_log_exporter.dart';
import '../services/research/research_log_storage.dart';
import '../services/research/research_preferences.dart';
import '../widgets/tk/tk.dart';

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
    final activeConfig = ResearchConfig(
      rawParticipantId: _participantController.text,
      condition: _condition,
    );
    final fieldStyle = Tk.text(16, weight: FontWeight.w700);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: 2),
        );

    return Scaffold(
      backgroundColor: Tk.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TkTopBar(onBack: () => Navigator.of(context).maybePop()),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Tk.primary))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(24, 6, 24, 32),
                      children: [
                        Text('Cài đặt nghiên cứu', style: Tk.text(28, weight: FontWeight.w900, letterSpacing: -0.4)),
                        const SizedBox(height: 4),
                        Text(
                          'Chỉ dùng khi tham gia thử nghiệm.',
                          style: Tk.text(15, weight: FontWeight.w700, color: Tk.inkSoft),
                        ),
                        const SizedBox(height: 22),
                        Text('MÃ NGƯỜI THAM GIA', style: Tk.eyebrow()),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _participantController,
                          textCapitalization: TextCapitalization.characters,
                          onChanged: _saveParticipantId,
                          onSubmitted: _saveParticipantId,
                          cursorColor: Tk.primary,
                          style: fieldStyle,
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: Tk.surfaceSoft,
                            hintText: 'Ví dụ: P07 (để trống = anon)',
                            hintStyle: fieldStyle.copyWith(color: Tk.inkMuted),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            enabledBorder: border(const Color(0xFFE1E3F0)),
                            focusedBorder: border(Tk.primary),
                            suffixIcon: _participantController.text.isNotEmpty
                                ? IconButton(
                                    tooltip: 'Xóa mã',
                                    icon: const Icon(Icons.clear_rounded, color: Tk.inkSoft),
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
                          style: Tk.text(13, weight: FontWeight.w700, color: Tk.inkSoft),
                        ),
                        const SizedBox(height: 24),
                        Text('ĐIỀU KIỆN THỬ NGHIỆM', style: Tk.eyebrow()),
                        const SizedBox(height: 8),
                        _ConditionOptionTile(
                          title: 'Có phản hồi AI (ai)',
                          subtitle: 'Hiển thị bộ đếm, khung xương, điểm số và giọng nhắc kỹ thuật như bình thường.',
                          selected: _condition == ResearchCondition.ai,
                          onTap: () => _selectCondition(ResearchCondition.ai),
                        ),
                        const SizedBox(height: 10),
                        _ConditionOptionTile(
                          title: 'Đối chứng — không phản hồi (control)',
                          subtitle: 'Tắt giọng sửa lỗi, bộ đếm, khung xương và điểm số; vẫn chấm và lưu nhật ký ngầm.',
                          selected: _condition == ResearchCondition.control,
                          onTap: () => _selectCondition(ResearchCondition.control),
                        ),
                        const SizedBox(height: 24),
                        Text('TỆP NHẬT KÝ TRÊN MÁY', style: Tk.eyebrow()),
                        const SizedBox(height: 8),
                        TkCard(
                          lip: false,
                          radius: 18,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Số tệp nhật ký đang lưu: $_storedFileCount', style: Tk.text(16, weight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              Text(
                                'Tối đa 300 tệp mới nhất được giữ trong bộ nhớ riêng của ứng dụng.',
                                style: Tk.text(13, weight: FontWeight.w600, color: Tk.inkSoft, height: 1.4),
                              ),
                              const SizedBox(height: 14),
                              Builder(
                                builder: (buttonContext) => TkButton(
                                  label: _sharing ? 'Đang chuẩn bị chia sẻ…' : 'Chia sẻ tất cả tệp nhật ký',
                                  icon: Icons.ios_share_rounded,
                                  busy: _sharing,
                                  onTap: _storedFileCount == 0 ? null : () => _shareAll(buttonContext),
                                ),
                              ),
                            ],
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
    return Semantics(
      button: true,
      selected: selected,
      child: TkCard(
        onTap: onTap,
        radius: 18,
        padding: const EdgeInsets.all(14),
        color: selected ? Tk.primarySoft : Tk.surface,
        borderColor: selected ? Tk.primary : Tk.line,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              color: selected ? Tk.primary : Tk.inkMuted,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Tk.text(15, weight: FontWeight.w900, color: selected ? Tk.primaryLip : Tk.ink)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Tk.text(13, weight: FontWeight.w600, color: Tk.inkSoft, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
