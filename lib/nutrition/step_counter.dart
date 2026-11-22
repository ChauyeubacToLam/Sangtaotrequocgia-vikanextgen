import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nutrition_store.dart';

class StepCounter {
  StepCounter._();

  static final instance = StepCounter._();

  bool get _mobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<bool> requestPermission() async {
    if (!_mobile) return false;
    try {
      final status = Platform.isAndroid
          ? await Permission.activityRecognition.request()
          : await Permission.sensors.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  Stream<int> todaySteps() async* {
    if (!_mobile) return;
    final granted = Platform.isAndroid
        ? await Permission.activityRecognition.isGranted
        : true;
    if (!granted) return;
    final prefs = await SharedPreferences.getInstance();
    await for (final event in Pedometer.stepCountStream) {
      final today = NutritionStore.dayKey(DateTime.now());
      final baseKey = 'nutri_steps_base_$today';
      var base = prefs.getInt(baseKey);
      if (base == null || event.steps < base) {
        final last = prefs.getInt('nutri_steps_last');
        base = last != null && last <= event.steps ? last : event.steps;
        await prefs.setInt(baseKey, base);
      }
      await prefs.setInt('nutri_steps_last', event.steps);
      final steps = event.steps - base;
      await NutritionStore.instance.saveSteps(DateTime.now(), steps);
      yield steps;
    }
  }
}
