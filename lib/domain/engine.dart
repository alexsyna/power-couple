import 'calendar.dart';
import 'catalog.dart';
import 'content.dart';
import 'models.dart';
import 'questions.dart';

/// Derives everything the app shows from the raw task logs. Nothing here is
/// stored: past weeks are recalculated whenever logs are backdated or undone,
/// so boss outcomes, quests and streaks can change after the fact.
class ScoringEngine {
  ScoringEngine(this.household, {this.bondReveals = const []})
      : calendar = HouseholdCalendar(household.timezone);

  final Household household;
  final HouseholdCalendar calendar;

  /// When each Bond question day was revealed, sorted. Every boss hit deals
  /// extra damage equal to the bond level at the time of the task.
  final List<DateTime> bondReveals;

  int bondLevelAt(DateTime at) => bondLevelFrom(bondReveals, at);

  DateTime get startDate => calendar.localDate(household.createdAt);

  WeekResult week(DateTime weekStart, Iterable<TaskLog> allLogs) {
    final logs = allLogs
        .where((l) => l.isActive && calendar.weekOf(l.doneAt) == weekStart)
        .toList()
      ..sort((a, b) => b.doneAt.compareTo(a.doneAt));

    final boss = bossForWeek(weekStart);
    final health = bossHealth(boss, weekStart, startDate);

    final points = <String, int>{for (final m in household.members) m.userId: 0};
    var taskPoints = 0;
    var damage = 0;
    var bondBonus = 0;
    final categories = <TaskCategory, int>{};
    for (final log in logs) {
      final task = log.task;
      taskPoints += task.points;
      if (task.countsForBoss) {
        final bonus = bondLevelAt(log.doneAt);
        damage += task.points + bonus;
        bondBonus += bonus;
      }
      categories.update(task.category, (n) => n + 1, ifAbsent: () => 1);
      log.pointsByPerson().forEach((who, p) {
        points.update(who, (n) => n + p, ifAbsent: () => p);
      });
    }

    final quests = [
      for (final q in questsForWeek(weekStart,
          hasKids: household.hasKids, hasPets: household.hasPets))
        QuestProgress(q, [
          for (final r in q.requirements)
            logs.where((l) => r.matches(l.task)).length.clamp(0, r.count),
        ]),
    ];
    final questBonus =
        quests.where((q) => q.isComplete).fold(0, (s, q) => s + q.quest.bonus);

    return WeekResult(
      weekStart: weekStart,
      boss: boss,
      bossHealth: health,
      bossDamage: damage,
      bondBonusDamage: bondBonus,
      pointsByPerson: points,
      taskPoints: taskPoints,
      questBonus: questBonus,
      quests: quests,
      categoryCounts: categories,
      logs: logs,
    );
  }

  /// Every week from the household's first week up to the one containing [now],
  /// newest first.
  List<WeekResult> history(Iterable<TaskLog> allLogs, DateTime now) => [
        for (final w in calendar.weeksBetween(household.createdAt, now).reversed)
          week(w, allLogs),
      ];

  /// Consecutive boss defeats up to now. The current week only counts once its
  /// boss is down, so an in-progress week never breaks the streak.
  int streak(List<WeekResult> newestFirst, DateTime now) {
    final current = calendar.weekOf(now);
    var n = 0;
    for (final w in newestFirst) {
      if (w.bossDefeated) {
        n++;
      } else if (w.weekStart == current) {
        continue;
      } else {
        break;
      }
    }
    return n;
  }

  /// Validates a log before it is saved. Hard limits come back as [error];
  /// a likely duplicate comes back as [duplicateOf] for the UI to confirm.
  LogCheck check(TaskDef task, DateTime doneAt, Iterable<TaskLog> allLogs, DateTime now) {
    if (doneAt.isAfter(now.add(const Duration(minutes: 1)))) {
      return const LogCheck.error("That time hasn't happened yet.");
    }
    if (calendar.localDate(doneAt).isBefore(startDate)) {
      return const LogCheck.error('That is before your household started.');
    }
    final day = calendar.localDate(doneAt);
    final sameTask = allLogs.where((l) => l.isActive && l.taskId == task.id).toList();
    final sameDay = sameTask.where((l) => calendar.localDate(l.doneAt) == day).length;
    if (sameDay >= task.dailyCap) {
      return LogCheck.error(
          '${task.name} can be logged ${_times(task.dailyCap)} a day, and that day is full.');
    }
    TaskLog? duplicate;
    for (final l in sameTask) {
      if (l.doneAt.difference(doneAt).abs() <= duplicateWindow) {
        duplicate = l;
        break;
      }
    }
    return LogCheck.ok(duplicateOf: duplicate);
  }

  static String _times(int n) => switch (n) { 1 => 'once', 2 => 'twice', _ => '$n times' };
}

class LogCheck {
  const LogCheck.ok({this.duplicateOf}) : error = null;
  const LogCheck.error(this.error) : duplicateOf = null;

  final String? error;
  final TaskLog? duplicateOf;

  bool get allowed => error == null;
}

class QuestProgress {
  QuestProgress(this.quest, this.progress);

  final QuestDef quest;

  /// Count achieved per requirement, capped at the requirement's target.
  final List<int> progress;

  bool get isComplete {
    for (var i = 0; i < progress.length; i++) {
      if (progress[i] < quest.requirements[i].count) return false;
    }
    return true;
  }

  /// Requirements not yet met, in quest order.
  List<QuestRequirement> get pending => [
        for (var i = 0; i < progress.length; i++)
          if (progress[i] < quest.requirements[i].count) quest.requirements[i],
      ];

  /// Catalog tasks that would move this quest forward.
  List<TaskDef> tasksToProgress(Iterable<TaskDef> available) {
    final open = pending;
    return [for (final t in available) if (open.any((r) => r.matches(t))) t];
  }

  double get fraction {
    final total = quest.requirements.fold(0, (s, r) => s + r.count);
    final done = progress.fold(0, (s, p) => s + p);
    return total == 0 ? 0 : done / total;
  }
}

class WeekResult {
  WeekResult({
    required this.weekStart,
    required this.boss,
    required this.bossHealth,
    required this.bossDamage,
    this.bondBonusDamage = 0,
    required this.pointsByPerson,
    required this.taskPoints,
    required this.questBonus,
    required this.quests,
    required this.categoryCounts,
    required this.logs,
  });

  final DateTime weekStart;
  final BossDef boss;
  final int bossHealth;

  /// Base points of eligible tasks plus the bond bonus per hit ("Other" and
  /// quest bonuses excluded).
  final int bossDamage;

  /// The part of [bossDamage] that came from the bond bonus.
  final int bondBonusDamage;

  /// Personal task points, keyed by user id. Quest bonuses are team-only.
  final Map<String, int> pointsByPerson;

  /// Base points of every task, including "Other".
  final int taskPoints;
  final int questBonus;
  final List<QuestProgress> quests;
  final Map<TaskCategory, int> categoryCounts;

  /// Active logs in this week, newest first.
  final List<TaskLog> logs;

  int get teamScore => taskPoints + questBonus;
  int get tasksLogged => logs.length;
  bool get bossDefeated => bossDamage >= bossHealth;
  int get bossRemaining => (bossHealth - bossDamage).clamp(0, bossHealth);
  double get bossFraction => (bossDamage / bossHealth).clamp(0, 1).toDouble();
  int get questsCompleted => quests.where((q) => q.isComplete).length;

  /// Members ranked by points, highest first.
  List<MapEntry<String, int>> get leaderboard =>
      pointsByPerson.entries.where((e) => e.key != formerMemberId || e.value > 0).toList()
        ..sort((a, b) => b.value.compareTo(a.value));

  List<MapEntry<TaskCategory, int>> get topCategories =>
      categoryCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}
