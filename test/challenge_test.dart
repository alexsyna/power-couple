import 'package:flutter_test/flutter_test.dart';
import 'package:power_couple/domain/calendar.dart';
import 'package:power_couple/domain/challenge.dart';
import 'package:power_couple/domain/stars.dart';

ClimbTeam team(String id) => ClimbTeam(coupleId: id, name: id, banner: '🦊', joinedAt: DateTime.utc(2026, 11, 1));

void main() {
  final start = DateTime.utc(2026, 11, 20);

  Challenge climb({List<ClimbScore> scores = const [], int days = 3}) => Challenge(
        id: 'c',
        code: 'ABC123',
        activities: const [StarActivity.chores, StarActivity.steps],
        days: days,
        startsOn: start,
        revealAt: DateTime.utc(2026, 11, 23, 10),
        teams: [team('a'), team('b'), team('c')],
        scores: scores,
      );

  ClimbScore s(String who, int day, StarActivity a, int stars) =>
      ClimbScore(coupleId: who, day: addDays(start, day), activity: a, stars: stars);

  test('phases follow the calendar and the reveal time', () {
    final c = climb();
    expect(c.endsOn, DateTime.utc(2026, 11, 22));
    expect(c.phase(DateTime.utc(2026, 11, 19), DateTime.utc(2026, 11, 19, 12)), ClimbPhase.upcoming);
    expect(c.phase(start, DateTime.utc(2026, 11, 20, 12)), ClimbPhase.climbing);
    expect(c.phase(DateTime.utc(2026, 11, 23), DateTime.utc(2026, 11, 23, 9)), ClimbPhase.summitWait);
    expect(c.phase(DateTime.utc(2026, 11, 23), DateTime.utc(2026, 11, 23, 10)), ClimbPhase.revealed);
    expect(c.dayNumber(DateTime.utc(2026, 11, 21)), 2);
    expect(c.canJoin(start), isTrue);
    expect(c.canJoin(addDays(start, 1)), isFalse);
  });

  test('the Final ascent counts double, and the maximum includes it', () {
    final c = climb(scores: [
      s('a', 0, StarActivity.chores, 3),
      s('a', 2, StarActivity.chores, 2), // last day: counts 4
    ]);
    expect(c.totalFor('a'), 7);
    expect(c.maxStars, 2 * 3 * 4); // 2 activities, 3 days + the doubled last day
  });

  test('standings: most stars first, ties broken by ⭐⭐⭐, then shared', () {
    final c = climb(scores: [
      s('a', 0, StarActivity.chores, 2), s('a', 0, StarActivity.steps, 2), // 4, no ⭐⭐⭐
      s('b', 0, StarActivity.chores, 3), s('b', 0, StarActivity.steps, 1), // 4, one ⭐⭐⭐
      s('c', 0, StarActivity.chores, 1),
    ]);
    final st = c.standings();
    expect(st.map((x) => x.team.coupleId), ['b', 'a', 'c']);
    expect(st.map((x) => x.place), [1, 2, 3]);

    final tie = climb(scores: [s('a', 0, StarActivity.chores, 2), s('b', 1, StarActivity.steps, 2)]).standings();
    expect(tie[0].place, 1);
    expect(tie[1].place, 1);
    expect(tie[2].place, 3);
  });

  test('a climb starts tomorrow and reveals at noon after the last day', () {
    final cal = HouseholdCalendar('Europe/Athens');
    final (startsOn, revealAt) = climbSchedule(cal, DateTime.utc(2026, 11, 16, 20), 7);
    expect(startsOn, DateTime.utc(2026, 11, 17));
    expect(cal.localTime(revealAt).hour, 12);
    expect(cal.localDate(revealAt), DateTime.utc(2026, 11, 24));
  });
}
