import 'package:flutter_test/flutter_test.dart';
import 'package:power_couple/domain/badges.dart';
import 'package:power_couple/domain/engine.dart';
import 'package:power_couple/domain/missions.dart';
import 'package:power_couple/domain/models.dart';

const a = 'alex';
const b = 'sam';

final household = Household(
  id: 'h1',
  timezone: 'Europe/Athens',
  hasKids: false,
  hasPets: false,
  inviteCode: 'ABCD1234',
  createdAt: DateTime.utc(2026, 9, 28, 12),
  members: const [Member(userId: a, displayName: 'Alex'), Member(userId: b, displayName: 'Sam')],
);

var _seq = 0;
TaskLog log(String task, String by, DateTime at, {String? sharedWith}) =>
    TaskLog(id: 'l${_seq++}', taskId: task, loggedBy: by, sharedWith: sharedWith, doneAt: at, createdAt: at);

/// Enough deep cleans to beat any boss, on the Tuesday of [weekStart].
List<TaskLog> beat(DateTime weekStart, String by) => [
      for (var i = 0; i < 20; i++) log('deep_clean', by, weekStart.add(Duration(days: 1, minutes: 31 * i))),
    ];

Mission mission(String id, {DateTime? completedAt, DateTime? deletedAt}) => Mission(
      id: id,
      title: 'Fix the shelf',
      dueOn: DateTime.utc(2026, 10, 25),
      createdAt: DateTime.utc(2026, 10, 20),
      completedAt: completedAt,
      deletedAt: deletedAt,
    );

void main() {
  final engine = ScoringEngine(household);
  final now = DateTime.utc(2026, 10, 21, 12);

  BadgeStats stats(List<TaskLog> logs, [List<Mission> missions = const []]) => BadgeStats.from(
        newestFirst: engine.history(logs, now),
        logs: logs,
        missions: missions,
        members: household.members,
      );

  Map<String, BadgeProgress> byId(BadgeStats s) => {for (final p in evaluateBadges(s)) p.badge.id: p};

  test('nothing unlocked for a fresh household, with zero progress', () {
    final p = byId(stats(const []));
    expect(p.values.where((x) => x.unlocked), isEmpty);
    expect(p['century']!.value, 0);
  });

  test('best streak survives a later loss; current week counts once beaten', () {
    // Weeks: 28 Sep won, 5 Oct won, 12 Oct lost, 19 Oct (current) won.
    final logs = [
      ...beat(DateTime.utc(2026, 9, 28), a),
      ...beat(DateTime.utc(2026, 10, 5), b),
      ...beat(DateTime.utc(2026, 10, 19), a),
    ];
    final s = stats(logs);
    expect(s.bestStreak, 2);
    expect(s.bossesDefeated, 3);
    final p = byId(s);
    expect(p['first_victory']!.unlocked, isTrue);
    expect(p['on_fire']!.unlocked, isTrue);
    expect(p['unstoppable']!.unlocked, isFalse);
    expect(p['unstoppable']!.value, 2);
    expect(p['unstoppable']!.fraction, 0.5);
  });

  test('dynamic duo counts weeks where both partners logged', () {
    final logs = [
      log('dishes', a, DateTime.utc(2026, 9, 29, 9)),
      log('dishes', b, DateTime.utc(2026, 9, 30, 9)),
      log('dishes', a, DateTime.utc(2026, 10, 6, 9)),
    ];
    expect(stats(logs).duoWeeks, 1);
  });

  test('shared tasks, total tasks and progress are capped at the target', () {
    final logs = [
      for (var i = 0; i < 12; i++) log('dishes', a, DateTime.utc(2026, 10, 1 + i % 9, 8 + i), sharedWith: b),
    ];
    final p = byId(stats(logs));
    expect(p['better_together']!.unlocked, isTrue);
    expect(p['better_together']!.value, 10);
    expect(p['century']!.value, 12);
  });

  test('only completed, non-deleted missions count', () {
    final ms = [
      mission('1', completedAt: now),
      mission('2', completedAt: now, deletedAt: now),
      mission('3'),
    ];
    expect(stats(const [], ms).missionsDone, 1);
    expect(openMissions(ms).map((m) => m.id), ['3']);
  });

  test('missions know when they are overdue', () {
    final m = mission('1');
    expect(m.isOverdue(DateTime.utc(2026, 10, 25)), isFalse);
    expect(m.isOverdue(DateTime.utc(2026, 10, 26)), isTrue);
    expect(m.daysLeft(DateTime.utc(2026, 10, 23)), 2);
    expect(parseDateKey(dateKey(m.dueOn)), m.dueOn);
  });
}
