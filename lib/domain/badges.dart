import 'content.dart';
import 'engine.dart';
import 'missions.dart';
import 'models.dart';

/// Lifetime facts the badges are judged on, derived from history.
class BadgeStats {
  BadgeStats({
    required this.bossesDefeated,
    required this.distinctBosses,
    required this.bestStreak,
    required this.questsCompleted,
    required this.mostQuestsInAWeek,
    required this.sharedTasks,
    required this.totalTasks,
    required this.duoWeeks,
    required this.bestWeekScore,
    required this.missionsDone,
  });

  final int bossesDefeated;
  final int distinctBosses;
  final int bestStreak;
  final int questsCompleted;
  final int mostQuestsInAWeek;
  final int sharedTasks;
  final int totalTasks;

  /// Weeks in which both partners logged at least one task.
  final int duoWeeks;
  final int bestWeekScore;
  final int missionsDone;

  /// [newestFirst] is the engine's history; the current week counts like any
  /// other (a streak includes it only once its boss is down).
  factory BadgeStats.from({
    required List<WeekResult> newestFirst,
    required Iterable<TaskLog> logs,
    required Iterable<Mission> missions,
    required List<Member> members,
  }) {
    var best = 0;
    var run = 0;
    for (final w in newestFirst.reversed) {
      run = w.bossDefeated ? run + 1 : 0;
      if (run > best) best = run;
    }
    final memberIds = members.map((m) => m.userId).toSet();
    final active = logs.where((l) => l.isActive).toList();
    return BadgeStats(
      bossesDefeated: newestFirst.where((w) => w.bossDefeated).length,
      distinctBosses: newestFirst.where((w) => w.bossDefeated).map((w) => w.boss.id).toSet().length,
      bestStreak: best,
      questsCompleted: newestFirst.fold(0, (s, w) => s + w.questsCompleted),
      mostQuestsInAWeek: newestFirst.fold(0, (s, w) => w.questsCompleted > s ? w.questsCompleted : s),
      sharedTasks: active.where((l) => l.isShared).length,
      totalTasks: active.length,
      duoWeeks: memberIds.length < 2
          ? 0
          : newestFirst.where((w) => memberIds.every((id) => w.logs.any((l) => l.loggedBy == id))).length,
      bestWeekScore: newestFirst.fold(0, (s, w) => w.teamScore > s ? w.teamScore : s),
      missionsDone: missions.where((m) => m.isDone).length,
    );
  }
}

class BadgeDef {
  const BadgeDef({
    required this.id,
    required this.emoji,
    required this.name,
    required this.condition,
    required this.target,
    required this.measure,
  });

  final String id;
  final String emoji;
  final String name;

  /// How to unlock it, shown to the couple.
  final String condition;
  final int target;
  final int Function(BadgeStats) measure;
}

class BadgeProgress {
  BadgeProgress(this.badge, int value) : value = value > badge.target ? badge.target : value;

  final BadgeDef badge;
  final int value;

  bool get unlocked => value >= badge.target;
  double get fraction => value / badge.target;
}

final badges = <BadgeDef>[
  BadgeDef(id: 'first_victory', emoji: '🗡️', name: 'First Victory', condition: 'Defeat your first weekly boss.', target: 1, measure: (s) => s.bossesDefeated),
  BadgeDef(id: 'on_fire', emoji: '🔥', name: 'On Fire', condition: 'Defeat the boss 2 weeks in a row.', target: 2, measure: (s) => s.bestStreak),
  BadgeDef(id: 'unstoppable', emoji: '⚡', name: 'Unstoppable', condition: 'Defeat the boss 4 weeks in a row.', target: 4, measure: (s) => s.bestStreak),
  BadgeDef(id: 'legends', emoji: '👑', name: 'Living Legends', condition: 'Defeat the boss 8 weeks in a row.', target: 8, measure: (s) => s.bestStreak),
  BadgeDef(id: 'monster_hunter', emoji: '🐉', name: 'Monster Hunter', condition: 'Defeat all ${bosses.length} different bosses.', target: bosses.length, measure: (s) => s.distinctBosses),
  BadgeDef(id: 'quest_starter', emoji: '🗺️', name: 'Quest Starter', condition: 'Complete your first quest.', target: 1, measure: (s) => s.questsCompleted),
  BadgeDef(id: 'clean_sweep', emoji: '🧹', name: 'Clean Sweep', condition: 'Complete all $questsPerWeek quests in a single week.', target: questsPerWeek, measure: (s) => s.mostQuestsInAWeek),
  BadgeDef(id: 'better_together', emoji: '🤝', name: 'Better Together', condition: 'Log 10 tasks done together.', target: 10, measure: (s) => s.sharedTasks),
  BadgeDef(id: 'dynamic_duo', emoji: '👯', name: 'Dynamic Duo', condition: 'Both of you log tasks in 4 different weeks.', target: 4, measure: (s) => s.duoWeeks),
  BadgeDef(id: 'century', emoji: '💯', name: 'Century', condition: 'Log 100 tasks in total.', target: 100, measure: (s) => s.totalTasks),
  BadgeDef(id: 'power_week', emoji: '🚀', name: 'Power Week', condition: 'Score 1,500 team points in one week.', target: 1500, measure: (s) => s.bestWeekScore),
  BadgeDef(id: 'mission_accomplished', emoji: '🛡️', name: 'Mission Accomplished', condition: 'Complete 5 missions.', target: 5, measure: (s) => s.missionsDone),
];

List<BadgeProgress> evaluateBadges(BadgeStats stats) => [for (final b in badges) BadgeProgress(b, b.measure(stats))];
