import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'research/research_preferences.dart';

class WorkoutSchedule {
  const WorkoutSchedule({
    required this.days,
    required this.minute,
    required this.remindersOn,
  });

  final List<int> days;
  final int minute;
  final bool remindersOn;

  String get timeLabel => WorkoutReminders.formatMinute(minute);

  String get daysLabel =>
      days.map((d) => WorkoutReminders.dayShort[d]).join(', ');
}

typedef PlannedReminder = ({DateTime at, String title, String body});

class WorkoutReminders {
  const WorkoutReminders._();

  static const dayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static const defaultDays = [0, 2, 4];
  static const defaultMinute = 18 * 60;
  static const morningMinute = 7 * 60;
  static const noonMinute = 12 * 60;
  static const leadMinutes = 120;
  static const horizonDays = 14;

  static const _daysKey = 'user_workout_days';
  static const _minuteKey = 'user_workout_minute';
  static const _onKey = 'workout_reminders_on';
  static const _trainedKey = 'last_trained_day';
  static const _askedKey = 'workout_reminders_permission_asked';

  static const _widget = MethodChannel('com.vikavn.app/schedule_widget');
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static String formatMinute(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<WorkoutSchedule> load() async {
    final prefs = await SharedPreferences.getInstance();
    final days = (prefs.getStringList(_daysKey) ?? const [])
        .map(int.tryParse)
        .whereType<int>()
        .where((d) => d >= 0 && d <= 6)
        .toSet()
        .toList()
      ..sort();
    return WorkoutSchedule(
      days: days.isEmpty ? defaultDays : days,
      minute: prefs.getInt(_minuteKey) ?? defaultMinute,
      remindersOn: prefs.getBool(_onKey) ?? true,
    );
  }

  static Future<void> save(WorkoutSchedule schedule) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_daysKey, [for (final d in schedule.days) '$d']);
    await prefs.setInt(_minuteKey, schedule.minute);
    await prefs.setBool(_onKey, schedule.remindersOn);
    if (schedule.remindersOn) await requestPermission();
    await refresh();
  }

  static bool get _mobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> markTrainedToday() async {
    if (!_mobile) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_trainedKey, dayKey(DateTime.now()));
    } catch (error) {
      debugPrint('[Vika] Mark trained failed: $error');
    }
    await refresh();
  }

  static Future<void> askPermissionOnce() async {
    if (!_mobile) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_askedKey) ?? false)) {
        await prefs.setBool(_askedKey, true);
        await requestPermission();
      }
    } catch (error) {
      debugPrint('[Vika] Reminder permission flag failed: $error');
    }
    await refresh();
  }

  static Future<bool> requestPermission() async {
    if (!_mobile) return false;
    try {
      await _init();
      if (Platform.isAndroid) {
        return await _plugin
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            false;
      }
      if (Platform.isIOS) {
        return await _plugin
                .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin>()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }
    } catch (error) {
      debugPrint('[Vika] Notification permission failed: $error');
    }
    return false;
  }

  static List<PlannedReminder> plan(
    WorkoutSchedule schedule,
    DateTime now, {
    String? trainedDay,
  }) {
    final out = <PlannedReminder>[];
    final before = schedule.minute - leadMinutes;
    final time = formatMinute(schedule.minute);
    final today = DateTime(now.year, now.month, now.day);
    for (var offset = 0; offset < horizonDays; offset++) {
      final day = DateTime(today.year, today.month, today.day + offset);
      if (!schedule.days.contains(day.weekday - 1)) continue;
      if (dayKey(day) == trainedDay) continue;
      final slots = <(int, String, String)>[
        if (morningMinute < before)
          (
            morningMinute,
            'Hôm nay có lịch tập',
            'Buổi tập lúc $time. Nhớ dành ra 15 phút nhé!'
          ),
        if (noonMinute < before)
          (
            noonMinute,
            'Đừng quên buổi tập hôm nay',
            'Hẹn bạn lúc $time, tập tại nhà thôi.'
          ),
        if (before >= 0)
          (
            before,
            'Còn 2 tiếng nữa là tới giờ tập',
            'Buổi tập lúc $time. Chuẩn bị chỗ đặt điện thoại nhé.'
          ),
        (
          schedule.minute,
          'Đến giờ tập rồi!',
          'Mở Vika và bắt đầu buổi tập hôm nay nhé.'
        ),
      ];
      for (final (minute, title, body) in slots) {
        final at = day.add(Duration(minutes: minute));
        if (at.isAfter(now)) out.add((at: at, title: title, body: body));
      }
    }
    return out;
  }

  static Future<void> refresh({bool active = true}) async {
    if (!_mobile) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final schedule = await load();
      final trainedDay = prefs.getString(_trainedKey);
      await _pushWidget(active ? schedule : null, trainedDay);
      await _init();
      await _cancelRange(0, waterIdBase);
      if (!active || !schedule.remindersOn) return;
      final mode = await _canExact()
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
      final reminders = plan(schedule, DateTime.now(), trainedDay: trainedDay);
      for (var i = 0; i < reminders.length; i++) {
        await _plugin.zonedSchedule(
          id: i,
          scheduledDate: tz.TZDateTime.from(reminders[i].at, tz.UTC),
          notificationDetails: _details,
          androidScheduleMode: mode,
          title: reminders[i].title,
          body: reminders[i].body,
        );
      }
    } catch (error) {
      debugPrint('[Vika] Workout reminders refresh failed: $error');
    }
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'workout_reminders',
      'Nhắc lịch tập',
      channelDescription:
          'Nhắc buổi tập đầu ngày, buổi trưa, trước giờ tập 2 tiếng và đúng giờ tập',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_vika',
      color: Color(0xFF2B5CE6),
    ),
    iOS: DarwinNotificationDetails(),
  );

  static const waterIdBase = 600;
  static const waterHours = [9, 11, 13, 15, 17, 19, 21];

  static Future<void> _cancelRange(int from, int to) async {
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (p.id >= from && p.id < to) await _plugin.cancel(id: p.id);
    }
  }

  static Future<void> refreshWater({required bool on}) async {
    if (!_mobile) return;
    try {
      await _init();
      await _cancelRange(waterIdBase, waterIdBase + 100);
      if (!on) return;
      await requestPermission();
      final now = DateTime.now();
      var id = waterIdBase;
      for (var d = 0; d < 3; d++) {
        for (final h in waterHours) {
          final at = DateTime(now.year, now.month, now.day + d, h);
          if (!at.isAfter(now)) continue;
          await _plugin.zonedSchedule(
            id: id++,
            scheduledDate: tz.TZDateTime.from(at, tz.UTC),
            notificationDetails: _waterDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            title: 'Uống một cốc nước nhé',
            body: 'Một cốc khoảng 250 ml. Ghi lại trong tab Dinh dưỡng.',
          );
        }
      }
    } catch (error) {
      debugPrint('[Vika] Water reminders failed: $error');
    }
  }

  static const _waterDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'water_reminders',
      'Nhắc uống nước',
      channelDescription: 'Nhắc uống nước mỗi 2 tiếng từ 9:00 đến 21:00',
      importance: Importance.defaultImportance,
      icon: 'ic_stat_vika',
      color: Color(0xFF2B5CE6),
    ),
    iOS: DarwinNotificationDetails(),
  );

  static Future<bool> _canExact() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.canScheduleExactNotifications() ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> sendTest() async {
    if (!_mobile) return false;
    final allowed = await requestPermission();
    try {
      await _plugin.show(
        id: 999,
        title: 'Vika sẽ nhắc bạn như thế này',
        body: 'Thông báo nhắc lịch tập đang hoạt động.',
        notificationDetails: _details,
      );
      return allowed;
    } catch (error) {
      debugPrint('[Vika] Test notification failed: $error');
      return false;
    }
  }

  static Future<void> _init() async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_vika'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  static Future<void> _pushWidget(
      WorkoutSchedule? schedule, String? trainedDay) async {
    if (!_mobile || !Platform.isAndroid) return;
    try {
      final research = await ResearchPreferences.load();
      await _widget.invokeMethod<void>('update', {
        'active': schedule != null,
        'mascot': !research.isControl,
        'days': schedule?.days ?? const <int>[],
        'minute': schedule?.minute ?? defaultMinute,
        'trainedDay': trainedDay ?? '',
      });
    } on MissingPluginException {
      return;
    }
  }
}
