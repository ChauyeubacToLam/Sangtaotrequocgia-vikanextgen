import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/screens/exercise/rest_screen.dart';
import 'package:vika/services/rep_replay.dart';
import 'package:vika/utils/exercise_logger.dart';
import 'package:vika/widgets/rep_replay_view.dart';

RepLog _rep(int n, {List<String> faults = const [], bool judged = true}) =>
    RepLog(
      repNumber: n,
      correctForm: faults.isEmpty,
      data: <String, dynamic>{
        'fault_types': faults,
        'fault_affects_form': {for (final f in faults) f: true},
        if (!judged) 'form_judged': false,
      },
    );

void main() {
  late List<(String, int)> saved;
  late RepReplayCollector collector;
  late ExerciseLogger logger;
  var now = 0;

  void addRep(RepLog rep, {int afterMs = 2000, Set<String> muted = const {}}) {
    now += afterMs;
    logger.addRepLog(rep);
    collector.onFrame(
      nowMs: now,
      activated: true,
      logger: logger,
      mutedFaultTypes: muted,
      describe: (type) => 'lỗi $type',
    );
  }

  setUp(() {
    saved = [];
    now = 1000;
    logger = ExerciseLogger();
    collector = RepReplayCollector(
      saveClip: (id, ms) async {
        saved.add((id, ms));
        return 20;
      },
      startCapture: () async {},
      stopCapture: () async {},
    )..begin();
    collector.onFrame(nowMs: now, activated: true, logger: logger);
  });

  test('an all-correct set keeps the latest good rep and offers no replay', () {
    addRep(_rep(1));
    addRep(_rep(2), afterMs: 1500);
    expect(collector.hasReplay, isFalse);
    expect(collector.goodRep?.repNumber, 2);
    expect(saved, [('good', 2000), ('good', 1500)]);
  });

  test('one clip per new fault type, at most three, muted and unjudged skipped',
      () {
    addRep(_rep(1));
    addRep(_rep(2, faults: ['depth']));
    addRep(_rep(3, faults: ['depth']));
    addRep(_rep(4, faults: ['trunk']), muted: {'trunk'});
    addRep(_rep(5, faults: ['heel'], judged: false));
    addRep(_rep(6, faults: ['depth', 'tempo']));
    addRep(_rep(7, faults: ['sync']));
    addRep(_rep(8, faults: ['knee']));
    expect(collector.faultReps.map((e) => e.repNumber), [2, 6, 7]);
    expect(collector.faultReps[1].label, 'Rep 6 · lỗi depth · lỗi tempo');
    expect(saved.map((s) => s.$1),
        ['good', 'fault_0', 'fault_1', 'fault_2']);
    expect(collector.hasReplay, isTrue);
  });

  test('fault titles drop the per-rep numbers', () {
    expect(faultTitle('Chưa ngồi lên hết: thân mới lên 45°'), 'Chưa ngồi lên hết');
    expect(faultTitle('Chân chưa đủ rộng (1.1×)'), 'Chân chưa đủ rộng');
    expect(faultTitle('Nhấc chân khỏi sàn'), 'Nhấc chân khỏi sàn');
    expect(
      faultTitlesFromSetFeedback([
        {false: {'REP_COMPLETE': {'rom': 'Chưa ngồi lên hết: thân mới lên 45°'}}},
        {false: {'HOLDING': {'Back': 'Hông hơi chùng'}}},
      ]),
      {'rom': 'Chưa ngồi lên hết', 'Back': 'Hông hơi chùng'},
    );
  });

  test('the same fault code with a different message gets its own clip', () {
    final messages = <String>['Hông hơi chùng', 'Hông hơi chùng', 'Hông hơi cao'];
    for (var i = 0; i < messages.length; i++) {
      now += 2000;
      logger.addRepLog(_rep(i + 1, faults: ['Back']));
      collector.onFrame(
        nowMs: now,
        activated: true,
        logger: logger,
        describe: (_) => messages[i],
      );
    }
    expect(collector.faultReps.map((e) => e.repNumber), [1, 3]);
  });

  test('clip length is the time since the previous rep, clamped', () {
    addRep(_rep(1, faults: ['depth']), afterMs: 200);
    addRep(_rep(2, faults: ['trunk']), afterMs: 15000);
    expect(saved, [('fault_0', 800), ('fault_1', 3500)]);
  });

  test('nothing is recorded after end()', () {
    collector.end();
    addRep(_rep(1, faults: ['depth']));
    expect(saved, isEmpty);
  });

  test('a cached loader asks native for each clip once', () async {
    final asked = <String>[];
    final load = cachedClipLoader((id) async {
      asked.add(id);
      return null;
    });
    await load('good');
    await load('good');
    await load('fault_0');
    expect(asked, ['good', 'fault_0']);
  });

  Widget rest({required bool control, List<RepReplayEntry>? faults}) =>
      MaterialApp(
        home: RestScreen(
          setReport: const SetReportData(
            setIndex: 0,
            score: 60,
            totalReps: 2,
            goodReps: 1,
            repResults: <bool>[true, false],
          ),
          setIndex: 0,
          totalSets: 2,
          currentReps: 2,
          baseRestSeconds: 30,
          isLastSet: false,
          onNext: () {},
          controlCondition: control,
          replayGoodRep: const RepReplayEntry(
              clipId: 'good', repNumber: 1, faultTypes: [], label: 'Rep 1 · đúng'),
          replayFaultReps: faults ??
              const [
                RepReplayEntry(
                    clipId: 'fault_0',
                    repNumber: 2,
                    faultTypes: ['depth'],
                    label: 'Rep 2 · Xuống thấp hơn'),
              ],
          loadReplayClip: (_) async => null,
        ),
      );

  testWidgets('rest screen shows the good and faulty rep side by side',
      (tester) async {
    await tester.pumpWidget(rest(control: false));
    await tester.pump();
    expect(find.text('XEM LẠI REP'), findsOneWidget);
    expect(find.text('Rep 1 · đúng'), findsOneWidget);
    expect(find.text('Rep 2 · Xuống thấp hơn'), findsOneWidget);
    expect(find.text('Không có hình'), findsNWidgets(2));
  });

  testWidgets('the faults card names a fault in Vietnamese, not by its code',
      (tester) async {
    final setLogger = ExerciseLogger()
      ..addRepLog(_rep(1, faults: ['rom']))
      ..addRepLog(_rep(2, faults: ['rom']));
    await tester.pumpWidget(MaterialApp(
      home: RestScreen(
        setReport: const SetReportData(
          setIndex: 0,
          score: 0,
          totalReps: 2,
          goodReps: 0,
          repResults: <bool>[false, false],
        ),
        setIndex: 0,
        totalSets: 2,
        currentReps: 2,
        baseRestSeconds: 30,
        isLastSet: false,
        onNext: () {},
        setLogger: setLogger,
        faultTitles: const {'rom': 'Chưa ngồi lên hết'},
      ),
    ));
    await tester.pump();
    expect(find.text('Chưa ngồi lên hết'), findsOneWidget);
    expect(find.text('rom'), findsNothing);
  });

  testWidgets('no replay in the control condition or for a clean set',
      (tester) async {
    await tester.pumpWidget(rest(control: true));
    await tester.pump();
    expect(find.text('XEM LẠI REP'), findsNothing);
    await tester.pumpWidget(rest(control: false, faults: const []));
    await tester.pump();
    expect(find.text('XEM LẠI REP'), findsNothing);
  });
}
