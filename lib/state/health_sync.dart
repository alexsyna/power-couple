import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/activity.dart';
import '../domain/calendar.dart';

/// Reads steps and sleep from Apple Health on this iPhone.
///
/// iOS never tells an app whether the user allowed reading, so "connected"
/// only means we asked. Health with nothing shared just returns no data.
class HealthSync {
  HealthSync(this._prefs);

  final SharedPreferences? _prefs;
  final _health = Health();
  bool _configured = false;

  static const _key = 'health_connected';

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  bool get connected => supported && (_prefs?.getBool(_key) ?? false);

  static const _sleepTypes = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_LIGHT, // "Core" sleep on Apple Watch
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
  ];
  static const _types = [HealthDataType.STEPS, ..._sleepTypes, HealthDataType.SLEEP_IN_BED];

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Shows Apple's permission sheet. Returns false if it couldn't be shown.
  Future<bool> connect() async {
    if (!supported) return false;
    await _configure();
    final ok = await _health.requestAuthorization(_types);
    await _prefs?.setBool(_key, true);
    return ok;
  }

  Future<void> disconnect() async => _prefs?.setBool(_key, false);

  /// My numbers for each of the last [days] household-local days (today
  /// included). Steps typed in by hand don't count.
  Future<List<DailyMetrics>> read(String userId, HouseholdCalendar cal, DateTime today, {int days = 8}) async {
    if (!connected) return const [];
    await _configure();
    final out = <DailyMetrics>[];
    for (var i = days - 1; i >= 0; i--) {
      final day = addDays(today, -i);
      final start = cal.startOfDay(day);
      final end = cal.startOfDay(addDays(day, 1));
      int? steps;
      try {
        steps = await _health.getTotalStepsInInterval(start, end, includeManualEntry: false);
      } catch (e) {
        debugPrint('Health steps: $e');
      }
      final sleep = await _sleepFor(cal, day);
      out.add(DailyMetrics(userId: userId, day: day, steps: steps, sleepMinutes: sleep));
    }
    return out;
  }

  /// Sleep for the night that ended on the morning of [day]: 6 pm the day
  /// before until noon. Overlapping records (watch + phone) count once.
  Future<int?> _sleepFor(HouseholdCalendar cal, DateTime day) async {
    final from = cal.instantAt(addDays(day, -1), 18, 0);
    final to = cal.instantAt(day, 12, 0);
    try {
      final points = await _health.getHealthDataFromTypes(
        types: [..._sleepTypes, HealthDataType.SLEEP_IN_BED],
        startTime: from,
        endTime: to,
        recordingMethodsToFilter: const [RecordingMethod.manual],
      );
      final asleep = [for (final p in points) if (_sleepTypes.contains(p.type)) (p.dateFrom, p.dateTo)];
      // Without a watch, iPhone only knows time in bed (from the sleep schedule).
      final intervals = asleep.isNotEmpty
          ? asleep
          : [for (final p in points) if (p.type == HealthDataType.SLEEP_IN_BED) (p.dateFrom, p.dateTo)];
      if (intervals.isEmpty) return null;
      return mergedMinutes(intervals, from, to);
    } catch (e) {
      debugPrint('Health sleep: $e');
      return null;
    }
  }
}

/// Total minutes covered by [intervals] within [from]..[to], counting
/// overlaps once.
int mergedMinutes(List<(DateTime, DateTime)> intervals, DateTime from, DateTime to) {
  final sorted = [
    for (final (a, b) in intervals)
      (a.isBefore(from) ? from : a, b.isAfter(to) ? to : b),
  ]..sort((x, y) => x.$1.compareTo(y.$1));
  var total = Duration.zero;
  DateTime? curStart, curEnd;
  for (final (a, b) in sorted) {
    if (!b.isAfter(a)) continue;
    if (curEnd == null || a.isAfter(curEnd)) {
      if (curStart != null) total += curEnd!.difference(curStart);
      curStart = a;
      curEnd = b;
    } else if (b.isAfter(curEnd)) {
      curEnd = b;
    }
  }
  if (curStart != null) total += curEnd!.difference(curStart);
  return total.inMinutes;
}
