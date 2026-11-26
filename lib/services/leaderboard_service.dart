import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum LeaderboardBoard { active, form }

const List<String> leaderboardAvatars = [
  'head',
  'wave',
  'cheer',
  'thumbs_up',
  'trophy',
  'streak',
  'point',
  'think',
];

String leaderboardAvatarAsset(String avatar) => leaderboardAvatars
        .contains(avatar)
    ? 'assets/mascot/tac_ke_$avatar.webp'
    : 'assets/mascot/tac_ke_head.webp';

@immutable
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.nickname,
    required this.avatar,
    required this.value,
    required this.sessions,
    required this.reps,
    required this.isMe,
  });

  factory LeaderboardEntry.fromRow(Map<String, dynamic> row) {
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    return LeaderboardEntry(
      rank: n(row['rank']),
      nickname: (row['nickname'] as String?)?.trim() ?? '',
      avatar: (row['avatar'] as String?) ?? 'head',
      value: n(row['value']),
      sessions: n(row['sessions']),
      reps: n(row['reps']),
      isMe: row['is_me'] == true,
    );
  }

  final int rank;
  final String nickname;
  final String avatar;
  final int value;
  final int sessions;
  final int reps;
  final bool isMe;
}

@immutable
class LeaderboardMembership {
  const LeaderboardMembership({required this.nickname, required this.avatar});

  final String nickname;
  final String avatar;
}

String? validateLeaderboardNickname(String raw) {
  final name = raw.trim();
  if (name.length < 2) return 'Biệt danh cần ít nhất 2 ký tự.';
  if (name.length > 24) return 'Biệt danh tối đa 24 ký tự.';
  return null;
}

class LeaderboardService {
  LeaderboardService({SupabaseClient? client}) : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  Future<LeaderboardMembership?> membership() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('leaderboard_members')
        .select('nickname, avatar')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return LeaderboardMembership(
      nickname: row['nickname'] as String,
      avatar: row['avatar'] as String,
    );
  }

  Future<void> join({required String nickname, required String avatar}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Chưa đăng nhập');
    await _client.from('leaderboard_members').upsert({
      'user_id': userId,
      'nickname': nickname.trim(),
      'avatar': leaderboardAvatars.contains(avatar) ? avatar : 'head',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }

  Future<void> leave() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('leaderboard_members').delete().eq('user_id', userId);
  }

  Future<List<LeaderboardEntry>> week(LeaderboardBoard board) async {
    final rows = await _client.rpc('leaderboard_week', params: {
      'p_board': board.name,
      'p_limit': 50,
    }) as List;
    return [
      for (final row in rows)
        LeaderboardEntry.fromRow(Map<String, dynamic>.from(row as Map)),
    ];
  }
}
