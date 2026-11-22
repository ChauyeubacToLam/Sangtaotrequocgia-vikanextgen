import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/workout_reminders.dart';

void main() {
  const evening = WorkoutSchedule(days: [0, 2, 4], minute: 18 * 60, remindersOn: true);

  test('workout day gets morning, noon, two-hours-before and on-time reminders', () {
    final monday = DateTime(2026, 11, 23, 6);
    final today = WorkoutReminders.plan(evening, monday)
        .where((r) => r.at.day == 23)
        .map((r) => r.at.hour)
        .toList();
    expect(today, [7, 12, 16, 18]);
  });

  test('a session soon after midnight still gets the on-time reminder', () {
    const late = WorkoutSchedule(days: [6], minute: 67, remindersOn: true);
    final plan = WorkoutReminders.plan(late, DateTime(2026, 11, 22, 0, 30));
    expect(plan.first.at, DateTime(2026, 11, 22, 1, 7));
  });

  test('rest days get nothing and past slots are skipped', () {
    final tuesdayNoon = DateTime(2026, 11, 24, 12, 30);
    final first = WorkoutReminders.plan(evening, tuesdayNoon).first.at;
    expect(first, DateTime(2026, 11, 25, 7));
    final mondayAfternoon = DateTime(2026, 11, 23, 13);
    expect(WorkoutReminders.plan(evening, mondayAfternoon).first.at, DateTime(2026, 11, 23, 16));
  });

  test('early session drops slots that are not before the two-hour reminder', () {
    const early = WorkoutSchedule(days: [0], minute: 13 * 60, remindersOn: true);
    final hours = WorkoutReminders.plan(early, DateTime(2026, 11, 23, 0))
        .where((r) => r.at.day == 23)
        .map((r) => r.at.hour)
        .toList();
    expect(hours, [7, 11, 13]);
  });

  test('a day already trained is skipped', () {
    final monday = DateTime(2026, 11, 23, 6);
    final plan = WorkoutReminders.plan(evening, monday, trainedDay: '2026-11-23');
    expect(plan.any((r) => r.at.day == 23), isFalse);
  });
}
