import 'catalog.dart';

/// Curated weekly bosses and quests. Rotation is deterministic from the week
/// start date so both partners always see the same content.

class BossDef {
  const BossDef({
    required this.id,
    required this.name,
    required this.emoji,
    required this.taunt,
    required this.health,
  });

  final String id;
  final String name;
  final String emoji;
  final String taunt;
  final int health;
}

const bosses = <BossDef>[
  BossDef(id: 'chaos_titan', name: 'The Chaos Titan', emoji: '🗿', taunt: 'Feeds on unfinished chores.', health: 1000),
  BossDef(id: 'dust_wyrm', name: 'The Dust Wyrm', emoji: '🐉', taunt: 'Hides under every sofa.', health: 950),
  BossDef(id: 'laundry_hydra', name: 'The Laundry Hydra', emoji: '🐍', taunt: 'Fold one sock, two more appear.', health: 1000),
  BossDef(id: 'grease_golem', name: 'The Grease Golem', emoji: '🫠', taunt: 'Built from last week\'s pans.', health: 1050),
  BossDef(id: 'clutter_kraken', name: 'The Clutter Kraken', emoji: '🐙', taunt: 'Eight arms, zero storage.', health: 1000),
  BossDef(id: 'grime_lich', name: 'The Grime Lich', emoji: '💀', taunt: 'Undying, unless someone scrubs.', health: 1100),
];

/// Weeks are counted from this Monday for rotation.
final _epoch = DateTime.utc(2024, 1, 1);

int weekIndex(DateTime weekStart) => weekStart.difference(_epoch).inDays ~/ 7;

BossDef bossForWeek(DateTime weekStart) => bosses[weekIndex(weekStart) % bosses.length];

/// Boss health for a week. The household's first week is scaled down to the
/// days remaining after it was created, so a mid-week start is winnable.
int bossHealth(BossDef boss, DateTime weekStart, DateTime householdStartDate) {
  final daysIntoWeek = householdStartDate.difference(weekStart).inDays;
  if (daysIntoWeek <= 0 || daysIntoWeek >= 7) return boss.health;
  final remaining = 7 - daysIntoWeek;
  final scaled = boss.health * remaining / 7;
  final rounded = ((scaled / 50).ceil() * 50).toInt();
  return rounded < 200 ? 200 : rounded;
}

class QuestRequirement {
  const QuestRequirement({
    required this.label,
    required this.count,
    this.taskIds = const {},
    this.categories = const {},
  });

  final String label;
  final int count;
  final Set<String> taskIds;
  final Set<TaskCategory> categories;

  bool matches(TaskDef task) =>
      task.countsForQuests &&
      (taskIds.contains(task.id) || categories.contains(task.category));
}

class QuestDef {
  const QuestDef({
    required this.id,
    required this.name,
    required this.emoji,
    required this.bonus,
    required this.requirements,
    this.needsKids = false,
    this.needsPets = false,
  });

  final String id;
  final String name;
  final String emoji;
  final int bonus;
  final List<QuestRequirement> requirements;
  final bool needsKids;
  final bool needsPets;
}

const questPool = <QuestDef>[
  QuestDef(id: 'fridge_stocked', name: 'The Fridge Is Stocked', emoji: '🥬', bonus: 25, requirements: [
    QuestRequirement(label: 'Buy groceries', count: 1, taskIds: {'groceries'}),
  ]),
  QuestDef(id: 'kitchen_reset', name: 'Kitchen Reset', emoji: '🍽️', bonus: 50, requirements: [
    QuestRequirement(label: 'Kitchen cleanup tasks', count: 3, categories: {TaskCategory.kitchen}),
  ]),
  QuestDef(id: 'laundry_zero', name: 'Laundry Zero', emoji: '🧺', bonus: 50, requirements: [
    QuestRequirement(label: 'Laundry loads', count: 2, taskIds: {'laundry_load'}),
    QuestRequirement(label: 'Fold and put away', count: 2, taskIds: {'fold_laundry'}),
  ]),
  QuestDef(id: 'dust_buster', name: 'Dust Buster', emoji: '🧹', bonus: 40, requirements: [
    QuestRequirement(label: 'Vacuum the home', count: 1, taskIds: {'vacuum'}),
    QuestRequirement(label: 'Dust the home', count: 1, taskIds: {'dust'}),
  ]),
  QuestDef(id: 'admin_hero', name: 'Household Admin Hero', emoji: '🗓️', bonus: 40, requirements: [
    QuestRequirement(label: 'Planning or admin tasks', count: 2, categories: {TaskCategory.planning}),
  ]),
  QuestDef(id: 'chefs_table', name: "Chef's Table", emoji: '👩‍🍳', bonus: 50, requirements: [
    QuestRequirement(label: 'Cook a meal', count: 4, taskIds: {'cook_meal'}),
  ]),
  QuestDef(id: 'sparkle_squad', name: 'Sparkle Squad', emoji: '✨', bonus: 45, requirements: [
    QuestRequirement(label: 'Clean the bathroom', count: 1, taskIds: {'clean_bathroom'}),
    QuestRequirement(label: 'Mop the floors', count: 1, taskIds: {'mop'}),
  ]),
  QuestDef(id: 'fresh_start', name: 'Fresh Start', emoji: '🛏️', bonus: 30, requirements: [
    QuestRequirement(label: 'Change bed sheets', count: 1, taskIds: {'bed_sheets'}),
    QuestRequirement(label: 'Tidy or declutter', count: 2, categories: {TaskCategory.tidying}),
  ]),
  QuestDef(id: 'little_heroes', name: 'Little Heroes', emoji: '🧸', bonus: 50, needsKids: true, requirements: [
    QuestRequirement(label: 'Childcare tasks', count: 5, categories: {TaskCategory.childcare}),
  ]),
  QuestDef(id: 'pack_leader', name: 'Pack Leader', emoji: '🐾', bonus: 40, needsPets: true, requirements: [
    QuestRequirement(label: 'Pet care tasks', count: 5, categories: {TaskCategory.pets}),
  ]),
];

const questsPerWeek = 4;

/// The quests active in a week. Kid and pet quests only appear for households
/// that have them; the rest rotate through the pool.
List<QuestDef> questsForWeek(DateTime weekStart, {required bool hasKids, required bool hasPets}) {
  final eligible = questPool
      .where((q) => (!q.needsKids || hasKids) && (!q.needsPets || hasPets))
      .toList();
  final start = (weekIndex(weekStart) * questsPerWeek) % eligible.length;
  return [
    for (var i = 0; i < questsPerWeek && i < eligible.length; i++)
      eligible[(start + i) % eligible.length],
  ];
}
