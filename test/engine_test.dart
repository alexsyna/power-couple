import 'package:flutter_test/flutter_test.dart';
import 'package:power_couple/domain/calendar.dart';
import 'package:power_couple/domain/catalog.dart';
import 'package:power_couple/domain/content.dart';
import 'package:power_couple/domain/engine.dart';
import 'package:power_couple/domain/models.dart';

const a = 'alex';
const b = 'sam';

// Monday 2026-10-19 00:00 in Athens is Sunday 21:00 UTC.
final monday = DateTime.utc(2026, 10, 19);

Household household({DateTime? createdAt, bool kids = false, bool pets = false}) => Household(
      id: 'h1',
      timezone: 'Europe/Athens',
      hasKids: kids,
      hasPets: pets,
      inviteCode: 'ABCD1234',
      createdAt: createdAt ?? DateTime.utc(2026, 9, 1),
      members: const [
        Member(userId: a, displayName: 'Alex'),
        Member(userId: b, displayName: 'Sam'),
      ],
    );

var _seq = 0;
TaskLog log(String task, String by, DateTime doneAt,
        {String? sharedWith, String? name, DateTime? undoneAt}) =>
    TaskLog(
      id: 'l${_seq++}',
      taskId: task,
      loggedBy: by,
      sharedWith: sharedWith,
      customName: name,
      doneAt: doneAt,
      createdAt: doneAt,
      undoneAt: undoneAt,
    );

void main() {
  final engine = ScoringEngine(household());
  final tue = DateTime.utc(2026, 10, 20, 9);

  test('logger gets full points, team gets the same', () {
    final w = engine.week(monday, [log('cook_meal', a, tue), log('dishes', b, tue)]);
    expect(w.pointsByPerson, {a: 40, b: 20});
    expect(w.taskPoints, 60);
    expect(w.bossDamage, 60);
  });

  test('shared task splits points, odd point to logger, team gets full', () {
    final w = engine.week(monday, [log('dishwasher', a, tue, sharedWith: b)]);
    expect(w.pointsByPerson, {a: 8, b: 7});
    expect(w.taskPoints, 15);
  });

  test('Other is 10 pts, counts for people and team but not the boss or quests', () {
    final w = engine.week(monday, [log(otherTaskId, a, tue, name: 'Fix the gate')]);
    expect(w.pointsByPerson[a], 10);
    expect(w.taskPoints, 10);
    expect(w.bossDamage, 0);
    expect(w.quests.every((q) => q.fraction == 0), isTrue);
  });

  test('undone logs are excluded and the boss is recalculated', () {
    final logs = [
      for (var i = 0; i < 20; i++) log('deep_clean', a, tue.add(Duration(hours: i))),
    ];
    expect(engine.week(monday, logs).bossDefeated, isTrue);
    logs[0] = logs[0].undone(tue, b);
    final w = engine.week(monday, logs);
    expect(w.bossDamage, 1140);
    // Week of 2026-10-19 → boss rotation; check against its own health.
    expect(w.bossDefeated, w.bossDamage >= w.bossHealth);
  });

  test('week boundary uses household timezone (Athens)', () {
    // Sunday 22:30 UTC is Monday 01:30 in Athens → new week.
    final lateSunUtc = DateTime.utc(2026, 10, 25, 22, 30);
    expect(engine.calendar.weekOf(lateSunUtc), DateTime.utc(2026, 10, 26));
    // Sunday 20:30 UTC is still Sunday 23:30 in Athens.
    expect(engine.calendar.weekOf(DateTime.utc(2026, 10, 25, 20, 30)), monday);
  });

  test('backdated log lands in its own past week and can flip that boss', () {
    final prev = DateTime.utc(2026, 10, 12);
    final health = engine.week(prev, const []).bossHealth;
    final logs = [
      for (var i = 0; i < health ~/ 60; i++)
        log('deep_clean', a, DateTime.utc(2026, 10, 13, 8).add(Duration(hours: i))),
    ];
    expect(engine.week(prev, logs).bossDefeated, isFalse);
    logs.add(TaskLog(
      id: 'late',
      taskId: 'deep_clean',
      loggedBy: b,
      doneAt: DateTime.utc(2026, 10, 15, 10),
      createdAt: DateTime.utc(2026, 10, 21, 10),
    ));
    expect(engine.week(prev, logs).bossDefeated, isTrue);
    expect(engine.week(monday, logs).taskPoints, 0);
    expect(logs.last.isBackdated, isTrue);
  });

  test('quest bonus is team-only and quests complete from matching logs', () {
    final quests = questsForWeek(monday, hasKids: false, hasPets: false);
    final q = quests.first;
    final logs = [
      for (final r in q.requirements)
        for (var i = 0; i < r.count; i++)
          log(
            r.taskIds.isNotEmpty
                ? r.taskIds.first
                : catalog.firstWhere((t) => r.categories.contains(t.category)).id,
            a,
            tue.add(Duration(hours: i)),
          ),
    ];
    final w = engine.week(monday, logs);
    expect(w.quests.first.isComplete, isTrue);
    expect(w.questBonus, greaterThanOrEqualTo(q.bonus));
    expect(w.teamScore, w.taskPoints + w.questBonus);
    expect(w.pointsByPerson.values.fold(0, (s, p) => s + p), w.taskPoints);
  });

  test('a quest offers only the tasks for its unmet requirements', () {
    final laundryZero = questPool.firstWhere((q) => q.id == 'laundry_zero');
    final visible = visibleCatalog(hasKids: false, hasPets: false);
    // Loads done (2/2), folding still open (0/2).
    final half = QuestProgress(laundryZero, [2, 0]);
    expect(half.pending.map((r) => r.label), ['Fold and put away']);
    expect(half.tasksToProgress(visible).map((t) => t.id), ['fold_laundry']);
    // Nothing done: both tasks qualify, and "Other" never does.
    final none = QuestProgress(laundryZero, [0, 0]);
    expect(none.tasksToProgress(catalog).map((t) => t.id), ['laundry_load', 'fold_laundry']);
    // Complete: nothing left to offer.
    expect(QuestProgress(laundryZero, [2, 2]).tasksToProgress(visible), isEmpty);
  });

  test('kid and pet quests only appear for households that have them', () {
    for (var i = 0; i < 12; i++) {
      final week = addDays(monday, 7 * i);
      final plain = questsForWeek(week, hasKids: false, hasPets: false);
      expect(plain.any((q) => q.needsKids || q.needsPets), isFalse);
    }
    final all = {
      for (var i = 0; i < 12; i++)
        ...questsForWeek(addDays(monday, 7 * i), hasKids: true, hasPets: true).map((q) => q.id),
    };
    expect(all, containsAll(['little_heroes', 'pack_leader']));
  });

  test('first week boss health is prorated for a mid-week start', () {
    final thu = DateTime.utc(2026, 10, 22);
    final boss = bossForWeek(monday);
    final h = bossHealth(boss, monday, thu);
    expect(h, lessThan(boss.health));
    expect(h % 50, 0);
    final next = bossForWeek(addDays(monday, 7));
    expect(bossHealth(next, addDays(monday, 7), thu), next.health);
  });

  test('daily cap blocks, duplicate within window warns', () {
    final logs = [log('vacuum', a, tue)];
    final capped = engine.check(taskById('vacuum'), tue.add(const Duration(hours: 3)), logs, tue.add(const Duration(hours: 4)));
    expect(capped.allowed, isFalse);

    final dishes = [log('dishes', b, tue)];
    final dup = engine.check(taskById('dishes'), tue.add(const Duration(minutes: 10)), dishes, tue.add(const Duration(minutes: 10)));
    expect(dup.allowed, isTrue);
    expect(dup.duplicateOf?.loggedBy, b);

    final later = engine.check(taskById('dishes'), tue.add(const Duration(hours: 5)), dishes, tue.add(const Duration(hours: 5)));
    expect(later.duplicateOf, isNull);
  });

  test('cannot log in the future or before the household started', () {
    final now = tue;
    expect(engine.check(taskById('dishes'), now.add(const Duration(hours: 1)), const [], now).allowed, isFalse);
    expect(engine.check(taskById('dishes'), DateTime.utc(2026, 8, 1), const [], now).allowed, isFalse);
    expect(engine.check(taskById('dishes'), DateTime.utc(2026, 9, 15), const [], now).allowed, isTrue);
  });

  test('streak counts consecutive defeats and ignores an unfinished current week', () {
    final e = ScoringEngine(household(createdAt: DateTime.utc(2026, 9, 28, 12)));
    List<TaskLog> beat(DateTime weekStart) => [
          for (var i = 0; i < 20; i++)
            log('deep_clean', a, weekStart.add(Duration(days: 1, minutes: 31 * i))),
        ];
    final now = DateTime.utc(2026, 10, 21, 12);
    // Weeks: 28 Sep (lost), 5 Oct (won), 12 Oct (won), 19 Oct (current, not yet).
    final logs = [...beat(DateTime.utc(2026, 10, 5)), ...beat(DateTime.utc(2026, 10, 12))];
    final history = e.history(logs, now);
    expect(history.length, 4);
    expect(e.streak(history, now), 2);
  });
}
