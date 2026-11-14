/// Daily stars: every day, each activity gives the couple 0 to 3 stars.
///
///             ⭐                    ⭐⭐                   ⭐⭐⭐
/// Chores     1+ task logged       more than usual        2+ more than usual
/// Steps      both 3k              both 5k                both 8k
/// Sleep      both 5h              both 6h                both 7h
/// Snap       both snapped         both within 2h         both within 1h
/// Together   both joined          30 min together        1h+ together
///
/// "Both" means the partner who did less sets the couple's level.
library;

import 'activity.dart';
import 'calendar.dart';
import 'missions.dart' show dateKey;
import 'models.dart';

enum StarActivity {
  chores('Chores', '🧹'),
  steps('Steps', '👟'),
  sleep('Sleep', '😴'),
  snap('Snap moment', '📸'),
  together('Out together', '💑');

  const StarActivity(this.label, this.emoji);
  final String label;
  final String emoji;
}

const maxStars = 3;

// Thresholds for ⭐, ⭐⭐, ⭐⭐⭐.
const stepTiers = [3000, 5000, 8000];
const sleepTiers = [5 * 60, 6 * 60, 7 * 60];
const snapTiers = [Duration(hours: 2), Duration(hours: 1)]; // for ⭐⭐, ⭐⭐⭐
const togetherTiers = [30, 60]; // minutes for ⭐⭐, ⭐⭐⭐

/// Chores "usual" looks back this far.
const usualWindowDays = 28;

int _tier(int? value, List<int> tiers) {
  if (value == null) return 0;
  var n = 0;
  for (final t in tiers) {
    if (value >= t) n++;
  }
  return n;
}

int stepStars(int? steps) => _tier(steps, stepTiers);
int sleepStars(int? minutes) => _tier(minutes, sleepTiers);

/// [delay] is how long after the prompt the photo was taken.
int snapStars(Duration? delay) {
  if (delay == null) return 0;
  if (delay <= snapTiers[1]) return 3;
  if (delay <= snapTiers[0]) return 2;
  return 1;
}

int choreStars(int tasks, double usual) {
  if (tasks <= 0) return 0;
  if (tasks >= usual + 2) return 3;
  if (tasks > usual) return 2;
  return 1;
}

int togetherStars({required bool bothJoined, required int minutes}) {
  if (minutes >= togetherTiers[1]) return 3;
  if (minutes >= togetherTiers[0]) return 2;
  return bothJoined ? 1 : 0;
}

/// One activity on one day.
class ActivityStars {
  const ActivityStars({
    required this.activity,
    required this.stars,
    this.personal = const {},
    this.values = const {},
    this.usual,
    this.coupleValue,
  });

  final StarActivity activity;

  /// The couple's stars, 0..3.
  final int stars;

  /// Each partner's own level, where that makes sense (not Out together).
  final Map<String, int> personal;

  /// Each partner's raw number: steps, sleep minutes, tasks, or minutes
  /// from prompt to snap. Missing means no data.
  final Map<String, int> values;

  /// Chores only: the household's usual tasks per day.
  final double? usual;

  /// Chores: tasks logged by the household. Together: minutes together.
  final int? coupleValue;
}

class DayStars {
  const DayStars(this.day, this.activities);

  final DateTime day;
  final Map<StarActivity, ActivityStars> activities;

  int get total => activities.values.fold(0, (n, a) => n + a.stars);
  int get max => activities.length * maxStars;
}

/// Works out stars from everything the household has recorded.
class StarsCalculator {
  StarsCalculator({
    required this.household,
    required this.calendar,
    required this.logs,
    required this.metrics,
    required this.snaps,
    required this.sessions,
    required this.now,
    this.homeLat,
    this.homeLng,
  });

  final Household household;
  final HouseholdCalendar calendar;
  final List<TaskLog> logs;
  final List<DailyMetrics> metrics;
  final List<Snap> snaps;
  final List<TogetherSession> sessions;
  final DateTime now;
  final double? homeLat;
  final double? homeLng;

  List<String> get _members => [for (final m in household.members) m.userId];

  /// When the Snap prompt goes off on [day].
  DateTime snapPromptAt(DateTime day) {
    final m = snapPromptMinute(household.id, dateKey(day));
    return calendar.instantAt(day, m ~/ 60, m % 60);
  }

  DayStars day(DateTime day) => DayStars(day, {
        StarActivity.chores: chores(day),
        StarActivity.steps: steps(day),
        StarActivity.sleep: sleep(day),
        StarActivity.snap: snap(day),
        StarActivity.together: together(day),
      });

  // ---------------------------------------------------------------- chores

  Iterable<TaskLog> get _active => logs.where((l) => l.isActive);

  int _tasksOn(DateTime day, {String? user}) => _active
      .where((l) => calendar.localDate(l.doneAt) == day)
      .where((l) => user == null || l.loggedBy == user || l.sharedWith == user)
      .length;

  /// Average tasks per day over the previous four weeks (never below 1).
  double usualTasks(DateTime day, {String? user}) {
    final start = calendar.localDate(household.createdAt);
    var from = addDays(day, -usualWindowDays);
    if (from.isBefore(start)) from = start;
    final days = day.difference(from).inDays;
    if (days <= 0) return 1;
    final count = _active.where((l) {
      final d = calendar.localDate(l.doneAt);
      return !d.isBefore(from) && d.isBefore(day) && (user == null || l.loggedBy == user || l.sharedWith == user);
    }).length;
    final avg = count / days;
    return avg < 1 ? 1 : avg;
  }

  ActivityStars chores(DateTime day) {
    final tasks = _tasksOn(day);
    final usual = usualTasks(day);
    return ActivityStars(
      activity: StarActivity.chores,
      stars: choreStars(tasks, usual),
      usual: usual,
      coupleValue: tasks,
      personal: {for (final u in _members) u: choreStars(_tasksOn(day, user: u), usualTasks(day, user: u))},
      values: {for (final u in _members) u: _tasksOn(day, user: u)},
    );
  }

  // ---------------------------------------------------------- health data

  DailyMetrics? _metric(String user, DateTime day) {
    for (final m in metrics) {
      if (m.userId == user && m.day == day) return m;
    }
    return null;
  }

  ActivityStars _both(StarActivity a, DateTime day, int? Function(DailyMetrics) pick, int Function(int?) tier) {
    final values = <String, int>{};
    for (final u in _members) {
      final v = _metric(u, day);
      if (v != null && pick(v) != null) values[u] = pick(v)!;
    }
    final personal = {for (final u in _members) u: tier(values[u])};
    final couple = _members.length < 2 ? 0 : personal.values.reduce((x, y) => x < y ? x : y);
    return ActivityStars(activity: a, stars: couple, personal: personal, values: values);
  }

  ActivityStars steps(DateTime day) => _both(StarActivity.steps, day, (m) => m.steps, stepStars);
  ActivityStars sleep(DateTime day) => _both(StarActivity.sleep, day, (m) => m.sleepMinutes, sleepStars);

  // ------------------------------------------------------------------ snap

  Snap? snapOf(String user, DateTime day) {
    for (final s in snaps) {
      if (s.userId == user && s.day == day) return s;
    }
    return null;
  }

  ActivityStars snap(DateTime day) {
    final prompt = snapPromptAt(day);
    final values = <String, int>{};
    final personal = <String, int>{};
    for (final u in _members) {
      final s = snapOf(u, day);
      final delay = s?.takenAt.difference(prompt);
      if (delay != null) values[u] = delay.inMinutes < 0 ? 0 : delay.inMinutes;
      personal[u] = delay == null ? 0 : snapStars(delay.isNegative ? Duration.zero : delay);
    }
    final couple = _members.length < 2 ? 0 : personal.values.reduce((x, y) => x < y ? x : y);
    return ActivityStars(activity: StarActivity.snap, stars: couple, personal: personal, values: values);
  }

  // -------------------------------------------------------------- together

  List<TogetherSession> sessionsOn(DateTime day) =>
      [for (final s in sessions) if (calendar.localDate(s.startedAt) == day) s];

  ActivityStars together(DateTime day) {
    final list = sessionsOn(day);
    final minutes = list.fold(0, (n, s) => n + s.togetherMinutes(now, homeLat: homeLat, homeLng: homeLng));
    return ActivityStars(
      activity: StarActivity.together,
      stars: togetherStars(bothJoined: list.any((s) => s.bothJoined), minutes: minutes),
      coupleValue: minutes,
    );
  }
}
