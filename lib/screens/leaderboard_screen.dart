import 'package:flutter/material.dart';

import '../services/leaderboard_service.dart';
import '../services/research/research_preferences.dart';
import '../widgets/tk/tk.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, this.service});

  final LeaderboardService? service;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final LeaderboardService _service =
      widget.service ?? LeaderboardService();
  final _nickname = TextEditingController();
  LeaderboardBoard _board = LeaderboardBoard.active;
  LeaderboardMembership? _member;
  List<LeaderboardEntry>? _entries;
  bool _loading = true;
  bool _busy = false;
  bool _editing = false;
  String _avatar = leaderboardAvatars.first;
  String? _error;

  bool get _research => ResearchPreferences.cachedConfig.hasParticipantId;

  @override
  void initState() {
    super.initState();
    if (!_research) _load();
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final member = await _service.membership();
      final entries = member == null ? null : await _service.week(_board);
      if (!mounted) return;
      setState(() {
        _member = member;
        _entries = entries;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Chưa tải được bảng xếp hạng. Kiểm tra mạng rồi thử lại.';
      });
    }
  }

  Future<void> _switchBoard(LeaderboardBoard board) async {
    if (board == _board) return;
    setState(() {
      _board = board;
      _entries = null;
    });
    await _load();
  }

  Future<void> _join() async {
    final problem = validateLeaderboardNickname(_nickname.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.join(nickname: _nickname.text, avatar: _avatar);
      _editing = false;
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa lưu được. Thử lại sau nhé.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rời bảng xếp hạng?',
            style: Tk.text(18, weight: FontWeight.w900)),
        content: Text(
            'Biệt danh của bạn sẽ biến mất khỏi bảng. Dữ liệu tập vẫn giữ nguyên.',
            style: Tk.text(15, weight: FontWeight.w700, color: Tk.inkSoft)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Ở lại',
                  style: Tk.text(15, weight: FontWeight.w800))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Rời',
                  style: Tk.text(15,
                      weight: FontWeight.w800, color: Tk.redInk))),
        ],
      ),
    );
    if (ok != true) return;
    await _service.leave();
    await _load();
  }

  void _startEdit() {
    final member = _member;
    if (member == null) return;
    setState(() {
      _editing = true;
      _nickname.text = member.nickname;
      _avatar = member.avatar;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tk.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TkTopBar(onBack: () => Navigator.of(context).maybePop()),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Bảng xếp hạng tuần',
                        style: Tk.text(26,
                            weight: FontWeight.w900, letterSpacing: -0.4)),
                  ),
                  if (_member != null && !_editing)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz_rounded,
                          color: Tk.inkSoft),
                      onSelected: (v) => v == 'edit' ? _startEdit() : _leave(),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                            value: 'edit',
                            child: Text('Đổi biệt danh',
                                style: Tk.text(15, weight: FontWeight.w700))),
                        PopupMenuItem(
                            value: 'leave',
                            child: Text('Rời bảng xếp hạng',
                                style: Tk.text(15,
                                    weight: FontWeight.w700,
                                    color: Tk.redInk))),
                      ],
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Text('Làm mới mỗi thứ Hai',
                  style:
                      Tk.text(14, weight: FontWeight.w700, color: Tk.inkSoft)),
            ),
            const SizedBox(height: 14),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_research) {
      return const _Notice(
          message:
              'Bảng xếp hạng tạm tắt khi máy đang tham gia nghiên cứu, để không ảnh hưởng cách bạn tập.');
    }
    if (_loading && _member == null && _entries == null) {
      return const Center(
          child: CircularProgressIndicator(color: Tk.primary));
    }
    if (_member == null || _editing) return _joinForm();
    return RefreshIndicator(
      color: Tk.primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          TkSegmented(
            labels: const ['Chăm nhất', 'Chuẩn nhất'],
            selected: LeaderboardBoard.values.indexOf(_board),
            onChanged: (i) => _switchBoard(LeaderboardBoard.values[i]),
          ),
          const SizedBox(height: 10),
          Text(
            _board == LeaderboardBoard.active
                ? 'Tổng số phút tập trong tuần.'
                : 'Điểm form trung bình ở squat, chống đẩy, cầu mông và plank. Cần ít nhất 3 lượt và 60 rep trong tuần.',
            style: Tk.text(13.5, weight: FontWeight.w700, color: Tk.inkSoft),
          ),
          const SizedBox(height: 14),
          if (_error != null) _Notice(message: _error!),
          ..._rows(),
        ],
      ),
    );
  }

  List<Widget> _rows() {
    final entries = _entries;
    if (entries == null) {
      return [
        const Padding(
          padding: EdgeInsets.only(top: 40),
          child:
              Center(child: CircularProgressIndicator(color: Tk.primary)),
        ),
      ];
    }
    final me = entries.where((e) => e.isMe).firstOrNull;
    return [
      _MyRank(entry: me, board: _board),
      const SizedBox(height: 14),
      if (entries.isEmpty)
        const _Notice(
            message:
                'Tuần này chưa ai có điểm. Tập một buổi để mở màn bảng xếp hạng.'),
      for (final e in entries.where((e) => e.rank <= 50))
        _Row(entry: e, board: _board),
    ];
  }

  Widget _joinForm() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        TkCard(
          radius: 20,
          lip: false,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const TkMascot(asset: Tk.mascotTrophy, size: 72, bob: false),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                        _editing
                            ? 'Đổi biệt danh và hình đại diện'
                            : 'Đua cùng mọi người mỗi tuần',
                        style: Tk.text(18, weight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                  'Bảng chỉ hiện biệt danh, hình tắc kè và số tổng trong tuần. Không hiện tên thật, email hay hình ảnh tập.',
                  style: Tk.text(14.5,
                      weight: FontWeight.w700, color: Tk.inkSoft, height: 1.4)),
              const SizedBox(height: 16),
              TkField(
                label: 'BIỆT DANH',
                controller: _nickname,
                hint: 'Ví dụ: Tắc kè chăm chỉ',
                onSubmitted: (_) => _join(),
              ),
              const SizedBox(height: 16),
              Text('HÌNH ĐẠI DIỆN',
                  style: Tk.text(13,
                      weight: FontWeight.w900,
                      color: Tk.inkSoft,
                      letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final a in leaderboardAvatars)
                    Semantics(
                      button: true,
                      selected: a == _avatar,
                      label: 'Hình đại diện $a',
                      child: GestureDetector(
                        onTap: () => setState(() => _avatar = a),
                        child: _Avatar(avatar: a, size: 52, selected: a == _avatar),
                      ),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: Tk.text(14, weight: FontWeight.w800, color: Tk.redInk)),
              ],
              const SizedBox(height: 18),
              TkButton(
                label: _editing ? 'Lưu' : 'Tham gia bảng xếp hạng',
                busy: _busy,
                onTap: _busy ? null : _join,
              ),
              if (_editing) ...[
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() {
                      _editing = false;
                      _error = null;
                    }),
                    child: Text('Huỷ',
                        style: Tk.text(15,
                            weight: FontWeight.w800, color: Tk.inkSoft)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String _valueLabel(LeaderboardBoard board, int value) =>
    board == LeaderboardBoard.active ? '$value phút' : '$value điểm';

class _MyRank extends StatelessWidget {
  const _MyRank({required this.entry, required this.board});

  final LeaderboardEntry? entry;
  final LeaderboardBoard board;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
          color: Tk.primarySoft, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: Tk.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HẠNG CỦA BẠN', style: Tk.eyebrow(color: Tk.primary)),
                const SizedBox(height: 2),
                Text(
                  e == null
                      ? (board == LeaderboardBoard.active
                          ? 'Chưa có hạng, tập một buổi để lên bảng'
                          : 'Chưa đủ 3 lượt và 60 rep ở bài đã kiểm chứng')
                      : 'Hạng ${e.rank} · ${_valueLabel(board, e.value)}',
                  style: Tk.text(16, weight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.board});

  final LeaderboardEntry entry;
  final LeaderboardBoard board;

  @override
  Widget build(BuildContext context) {
    final top = entry.rank <= 3;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
      decoration: BoxDecoration(
        color: entry.isMe ? Tk.orangeSoft : Tk.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: entry.isMe ? Tk.orange : Tk.lineSoft),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text('${entry.rank}',
                textAlign: TextAlign.center,
                style: Tk.text(top ? 20 : 16,
                    weight: FontWeight.w900,
                    color: top ? Tk.orangeInk : Tk.inkSoft)),
          ),
          const SizedBox(width: 6),
          _Avatar(avatar: entry.avatar, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.isMe ? '${entry.nickname} (bạn)' : entry.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Tk.text(15.5, weight: FontWeight.w800)),
                Text('${entry.sessions} lượt · ${entry.reps} rep',
                    style: Tk.text(12.5,
                        weight: FontWeight.w700, color: Tk.inkMuted)),
              ],
            ),
          ),
          Text(_valueLabel(board, entry.value),
              style: Tk.text(16, weight: FontWeight.w900, color: Tk.ink)),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.avatar, required this.size, this.selected = false});

  final String avatar;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Tk.surface,
        border: Border.all(
            color: selected ? Tk.primary : Tk.line, width: selected ? 3 : 1.5),
      ),
      child: ClipOval(
        child: Image.asset(
          leaderboardAvatarAsset(avatar),
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.person_rounded, color: Tk.inkMuted),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(message,
          textAlign: TextAlign.center,
          style: Tk.text(15, weight: FontWeight.w700, color: Tk.inkSoft, height: 1.4)),
    );
  }
}
