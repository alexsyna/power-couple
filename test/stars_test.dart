import 'package:flutter_test/flutter_test.dart';
import 'package:power_couple/domain/activity.dart';
import 'package:power_couple/domain/calendar.dart';
import 'package:power_couple/domain/models.dart';
import 'package:power_couple/domain/stars.dart';

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
    List<TogetherSession> sessions = const [],
    double? homeLat,
    double? homeLng,
  }) =>
      StarsCalculator(
        household: household(),
        calendar: cal,
        logs: logs,
        metrics: metrics,
        snaps: snaps,
        sessions: sessions,
        now: at(day, 23),
        homeLat: homeLat,
        homeLng: homeLng,
      );

  test('tiers', () {
    expect([0, 2999, 3000, 4999, 5000, 7999, 8000, 20000].map(stepStars), [0, 0, 1, 1, 2, 2, 3, 3]);
    expect([299, 300, 360, 419, 420, 600].map(sleepStars), [0, 1, 2, 2, 3, 3]);
    expect(stepStars(null), 0);
    expect(snapStars(null), 0);
    expect(snapStars(const Duration(minutes: 59)), 3);
    expect(snapStars(const Duration(minutes: 61)), 2);
    expect(snapStars(const Duration(hours: 3)), 1);
    expect(togetherStars(bothJoined: false, minutes: 0), 0);
    expect(togetherStars(bothJoined: true, minutes: 10), 1);
    expect(togetherStars(bothJoined: true, minutes: 30), 2);
    expect(togetherStars(bothJoined: true, minutes: 75), 3);
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

  test('out together counts minutes both phones were close and away from home', () {
    final start = at(day, 19);
    // Two phones 20 m apart, one ping a minute for [minutes].
    List<TogetherPing> walk(int minutes, {double lat = 37.98}) => [
          for (var m = 0; m < minutes; m++) ...[
            TogetherPing(userId: a, at: start.add(Duration(minutes: m)), lat: lat, lng: 23.72),
            TogetherPing(userId: b, at: start.add(Duration(minutes: m)), lat: lat + 0.0002, lng: 23.72),
          ],
        ];
    TogetherSession session(List<TogetherPing> pings, {bool joined = true}) => TogetherSession(
          id: 's',
          startedBy: a,
          startedAt: start,
          joinedBy: joined ? b : null,
          joinedAt: joined ? start : null,
          endedAt: start.add(const Duration(hours: 2)),
          pings: pings,
        );

    expect(calc(sessions: [session(walk(0), joined: false)]).together(day).stars, 0);
    expect(calc(sessions: [session(walk(0))]).together(day).stars, 1);
    final half = calc(sessions: [session(walk(35))]).together(day);
    expect(half.stars, 2);
    expect(half.coupleValue, inInclusiveRange(35, 38)); // last ping covers a few minutes
    expect(calc(sessions: [session(walk(70))]).together(day).stars, 3);

    // Apart: 2 km between the phones.
    final apart = [
      for (var m = 0; m < 70; m++) ...[
        TogetherPing(userId: a, at: start.add(Duration(minutes: m)), lat: 37.98, lng: 23.72),
        TogetherPing(userId: b, at: start.add(Duration(minutes: m)), lat: 38.0, lng: 23.72),
      ],
    ];
    expect(calc(sessions: [session(apart)]).together(day).stars, 1);

    // At home: doesn't count.
    expect(calc(sessions: [session(walk(70))], homeLat: 37.98, homeLng: 23.72).together(day).stars, 1);
  });

  test('a day adds up all five activities', () {
    final d = calc().day(day);
    expect(d.activities.length, 5);
    expect(d.max, 15);
    expect(d.total, 0);
  });
}
