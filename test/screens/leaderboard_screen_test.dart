import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vika/screens/leaderboard_screen.dart';
import 'package:vika/services/leaderboard_service.dart';

class _FakeService extends LeaderboardService {
  LeaderboardMembership? member;
  final joined = <String>[];
  final boards = <LeaderboardBoard>[];

  @override
  Future<LeaderboardMembership?> membership() async => member;

  @override
  Future<void> join({required String nickname, required String avatar}) async {
    joined.add('$nickname|$avatar');
    member = LeaderboardMembership(nickname: nickname.trim(), avatar: avatar);
  }

  @override
  Future<void> leave() async => member = null;

  @override
  Future<List<LeaderboardEntry>> week(LeaderboardBoard board) async {
    boards.add(board);
    if (board == LeaderboardBoard.form) return const [];
    return [
      LeaderboardEntry.fromRow(const {
        'rank': 1,
        'nickname': 'Tắc kè nhanh',
        'avatar': 'cheer',
        'value': 95,
        'sessions': 8,
        'reps': 420,
        'is_me': false,
      }),
      LeaderboardEntry.fromRow(const {
        'rank': 2,
        'nickname': 'Kiệt',
        'avatar': 'head',
        'value': 40,
        'sessions': 3,
        'reps': 150,
        'is_me': true,
      }),
    ];
  }
}

void main() {
  test('row parsing, nickname rules and avatar fallback', () {
    final e = LeaderboardEntry.fromRow(const {
      'rank': 3,
      'nickname': '  An  ',
      'value': 12.0,
      'is_me': null,
    });
    expect(e.rank, 3);
    expect(e.nickname, 'An');
    expect(e.avatar, 'head');
    expect(e.value, 12);
    expect(e.sessions, 0);
    expect(e.isMe, isFalse);
    expect(validateLeaderboardNickname(' a '), isNotNull);
    expect(validateLeaderboardNickname('x' * 25), isNotNull);
    expect(validateLeaderboardNickname('Tắc kè'), isNull);
    expect(leaderboardAvatarAsset('trophy'), 'assets/mascot/tac_ke_trophy.webp');
    expect(leaderboardAvatarAsset('../x'), 'assets/mascot/tac_ke_head.webp');
  });

  testWidgets('join, see my rank, switch board', (tester) async {
    final service = _FakeService();
    await tester.pumpWidget(
        MaterialApp(home: LeaderboardScreen(service: service)));
    await tester.pumpAndSettle();

    expect(find.text('THAM GIA BẢNG XẾP HẠNG'), findsOneWidget);
    await tester.ensureVisible(find.text('THAM GIA BẢNG XẾP HẠNG'));
    await tester.tap(find.text('THAM GIA BẢNG XẾP HẠNG'));
    await tester.pumpAndSettle();
    expect(find.text('Biệt danh cần ít nhất 2 ký tự.'), findsOneWidget);
    expect(service.joined, isEmpty);

    await tester.enterText(find.byType(TextField), 'Kiệt');
    await tester.ensureVisible(find.text('THAM GIA BẢNG XẾP HẠNG'));
    await tester.tap(find.text('THAM GIA BẢNG XẾP HẠNG'));
    await tester.pumpAndSettle();
    expect(service.joined, ['Kiệt|head']);
    expect(find.text('Hạng 2 · 40 phút'), findsOneWidget);
    expect(find.text('Kiệt (bạn)'), findsOneWidget);
    expect(find.text('Tắc kè nhanh'), findsOneWidget);

    await tester.tap(find.text('Chuẩn nhất'));
    await tester.pumpAndSettle();
    expect(service.boards.last, LeaderboardBoard.form);
    expect(find.text('Chưa đủ 3 lượt và 60 rep ở bài đã kiểm chứng'),
        findsOneWidget);
  });
}
