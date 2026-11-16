import 'package:flutter_test/flutter_test.dart';
import 'package:power_couple/domain/activity.dart';
import 'package:power_couple/domain/calendar.dart';
import 'package:power_couple/domain/models.dart';
import 'package:power_couple/domain/stars.dart';
import 'package:power_couple/state/health_sync.dart';

const a = 'alex', b = 'sam';

Household household() => Household(
      id: 'h1',
      timezone: 'Europe/Athens',
      hasKids: false,
      hasPets: false,
      inviteCode: 'X',
      createdAt: DateTime.utc(2026, 9, 1),
      members: const [Member(userId: a, displayName: 'Alex'), Member(userId: b, displayName: 'Sam')],
    );

var _seq = 0;
TaskLog log(String by, DateTime at) =>
    TaskLog(id: 'l${_seq++}', taskId: 'dishes', loggedBy: by, doneAt: at, createdAt: at);

void main() {
  final day = DateTime.utc(2026, 11, 10); // local date in Athens
  final cal = HouseholdCalendar('Europe/Athens');
  DateTime at(DateTime d, int h) => cal.instantAt(d, h, 0);

  StarsCalculator calc({
    List<TaskLog> logs = const [],
    List<DailyMetrics> metrics = const [],
    List<Snap> snaps = const [],
  }) =>
      StarsCalculator(
        household: household(),
        calendar: cal,
        logs: logs,
        metrics: metrics,
        snaps: snaps,
        now: at(day, 23),
      );

  test('tiers', () {
    expect([0, 2999, 3000, 4999, 5000, 7999, 8000, 20000].map(stepStars), [0, 0, 1, 1, 2, 2, 3, 3]);
    expect([299, 300, 360, 419, 420, 600].map(sleepStars), [0, 1, 2, 2, 3, 3]);
    expect(stepStars(null), 0);
    expect(snapStars(null), 0);
    expect(snapStars(const Duration(minutes: 59)), 3);
    expect(snapStars(const Duration(minutes: 61)), 2);
    expect(snapStars(const Duration(hours: 3)), 1);
    expect(bedtimeStars(null), 0);
    expect(bedtimeStars(const Duration(minutes: 60)), 3);
    expect(bedtimeStars(const Duration(minutes: 61)), 2);
    expect(bedtimeStars(const Duration(hours: 2)), 2);
    expect(bedtimeStars(const Duration(hours: 4)), 1);
    // Usual 2.5 tasks a day: 1-2 is ⭐, 3-4 is ⭐⭐, 5+ is ⭐⭐⭐.
    expect([0, 1, 2, 3, 4, 5].map((t) => choreStars(t, 2.5)), [0, 1, 1, 2, 2, 3]);
  });

  test('the partner who did less sets the couple level', () {
    final c = calc(metrics: [
      DailyMetrics(userId: a, day: day, steps: 9000, sleepMinutes: 480),
      DailyMetrics(userId: b, day: day, steps: 4000, sleepMinutes: 370),
    ]);
    final steps = c.steps(day);
    expect(steps.personal, {a: 3, b: 1});
    expect(steps.stars, 1);
    expect(c.sleep(day).stars, 2);
    // No data for one partner: no stars yet.
    expect(calc(metrics: [DailyMetrics(userId: a, day: day, steps: 9000)]).steps(day).stars, 0);
  });

  test('chores compare with the household usual over four weeks', () {
    // Two tasks a day for the previous 28 days.
    final past = [
      for (var i = 1; i <= 28; i++) ...[log(a, at(addDays(day, -i), 9)), log(b, at(addDays(day, -i), 18))],
    ];
    expect(calc(logs: past).usualTasks(day), 2);
    List<TaskLog> today(int n) => [for (var i = 0; i < n; i++) log(i.isEven ? a : b, at(day, 8 + i))];
    expect(calc(logs: past).chores(day).stars, 0);
    expect(calc(logs: [...past, ...today(1)]).chores(day).stars, 1);
    expect(calc(logs: [...past, ...today(2)]).chores(day).stars, 1);
    expect(calc(logs: [...past, ...today(3)]).chores(day).stars, 2);
    expect(calc(logs: [...past, ...today(4)]).chores(day).stars, 3);
    // A quiet household's usual never drops below one task.
    expect(calc().usualTasks(day), 1);
  });

  test('snap stars count from the prompt, and both must snap', () {
    final c0 = calc();
    final prompt = c0.snapPromptAt(day);
    // The prompt falls in the daytime window, the same on every phone.
    final local = cal.localTime(prompt);
    expect(local.hour, inInclusiveRange(snapWindowStartHour, snapWindowEndHour - 1));
    expect(c0.snapPromptAt(day), calc().snapPromptAt(day));

    Snap s(String u, Duration after) => Snap(id: u, userId: u, day: day, takenAt: prompt.add(after));
    expect(calc(snaps: [s(a, const Duration(minutes: 5))]).snap(day).stars, 0);
    expect(calc(snaps: [s(a, const Duration(minutes: 5)), s(b, const Duration(minutes: 40))]).snap(day).stars, 3);
    expect(calc(snaps: [s(a, const Duration(minutes: 5)), s(b, const Duration(minutes: 90))]).snap(day).stars, 2);
    expect(calc(snaps: [s(a, const Duration(hours: 5)), s(b, const Duration(minutes: 1))]).snap(day).stars, 1);
  });

  test('bedtime sync compares when each partner fell asleep', () {
    DailyMetrics m(String u, int hour, int minute) =>
        DailyMetrics(userId: u, day: day, sleepMinutes: 420, bedAt: cal.instantAt(addDays(day, -1), hour, minute));
    // Across midnight: 23:30 and 00:10 are 40 minutes apart.
    final close = calc(metrics: [m(a, 23, 30), DailyMetrics(userId: b, day: day, sleepMinutes: 400, bedAt: cal.instantAt(day, 0, 10))]).bedtime(day);
    expect(close.coupleValue, 40);
    expect(close.stars, 3);
    expect(calc(metrics: [m(a, 22, 0), m(b, 23, 45)]).bedtime(day).stars, 2);
    expect(calc(metrics: [m(a, 21, 0), m(b, 23, 30)]).bedtime(day).stars, 1);
    // One partner without sleep data: no stars yet.
    expect(calc(metrics: [m(a, 22, 0)]).bedtime(day).stars, 0);
  });

  test('bedtime is the start of the main sleep, not an evening nap', () {
    DateTime t(int d, int h, int m) => DateTime.utc(2026, 11, d, h, m);
    final from = t(9, 16, 0), to = t(10, 10, 0);
    final start = mainSleepStart([
      (t(9, 19, 0), t(9, 19, 40)), // nap on the sofa
      (t(9, 23, 10), t(10, 2, 0)),
      (t(10, 2, 20), t(10, 6, 30)), // woke up briefly: same night
    ], from, to);
    expect(start, t(9, 23, 10));
    expect(mainSleepStart(const [], from, to), isNull);
  });

  test('a day adds up all five activities', () {
    final d = calc().day(day);
    expect(d.activities.length, 5);
    expect(d.max, 15);
    expect(d.total, 0);
  });
}
