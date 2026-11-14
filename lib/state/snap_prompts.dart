import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/activity.dart';
import '../domain/calendar.dart';
import '../domain/missions.dart' show dateKey;

/// Snap moment reminders. Both phones compute the same prompt time from the
/// household id and the date, so each schedules its own local notification
/// and no server is involved.
class SnapPrompts {
  SnapPrompts(this._prefs);

  final SharedPreferences? _prefs;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Bumped when a Snap notification is tapped: the UI opens the camera page.
  final openSnap = ValueNotifier<int>(0);

  static const _key = 'snap_prompts';
  static const _firstId = 7000;
  static const daysAhead = 7;

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  bool get enabled => supported && (_prefs?.getBool(_key) ?? true);

  Future<void> _init() async {
    if (_ready || !supported) return;
    _ready = true;
    await _plugin.initialize(
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(
          // The notifications permission is asked from Settings / Bond.
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        if (r.payload == 'snap') openSnap.value++;
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true && launch?.notificationResponse?.payload == 'snap') {
      openSnap.value++;
    }
  }

  Future<void> setEnabled(bool on) async {
    await _prefs?.setBool(_key, on);
    if (!on) await _cancel();
  }

  Future<void> _cancel() async {
    for (var i = 0; i <= daysAhead; i++) {
      await _plugin.cancel(id: _firstId + i);
    }
  }

  /// Schedules the next week of prompts (iOS keeps them even if the app
  /// isn't opened). Today's is skipped once I've snapped.
  Future<void> schedule({
    required String householdId,
    required HouseholdCalendar calendar,
    required DateTime now,
    required bool snappedToday,
  }) async {
    if (!supported) return;
    try {
      await _init();
      await _cancel();
      if (!enabled) return;
      ensureTimeZones();
      final today = calendar.localDate(now);
      for (var i = 0; i <= daysAhead; i++) {
        final day = addDays(today, i);
        if (i == 0 && snappedToday) continue;
        final key = dateKey(day);
        final m = snapPromptMinute(householdId, key);
        final at = calendar.instantAt(day, m ~/ 60, m % 60);
        if (!at.isAfter(now)) continue;
        await _plugin.zonedSchedule(
          id: _firstId + i,
          title: '📸 Snap moment!',
          body: '${snapPromptText(householdId, key)} Snap within an hour for ⭐⭐⭐',
          scheduledDate: tz.TZDateTime.from(at, tz.UTC),
          notificationDetails: const NotificationDetails(iOS: DarwinNotificationDetails(presentSound: true)),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'snap',
        );
      }
    } catch (e) {
      debugPrint('Snap prompts: $e');
    }
  }
}
