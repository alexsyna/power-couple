/// The predefined household task catalog.
///
/// Point values and repetition limits are initial hypotheses to calibrate in
/// the pilot. Daily caps are per household per local calendar day.
library;

enum TaskCategory {
  shopping('Shopping & errands', '🛒'),
  cooking('Cooking & food prep', '🍳'),
  kitchen('Kitchen cleanup', '🍽️'),
  laundry('Laundry & clothing', '🧺'),
  cleaning('General cleaning', '🧹'),
  bathroom('Bathroom & hygiene', '🛁'),
  tidying('Organisation & tidying', '📦'),
  maintenance('Home maintenance', '🔧'),
  planning('Planning & admin', '🗓️'),
  supplies('Household supplies', '🧻'),
  childcare('Childcare', '🧸'),
  pets('Pets', '🐾'),
  other('Other', '✨');

  const TaskCategory(this.label, this.emoji);
  final String label;
  final String emoji;
}

class TaskDef {
  const TaskDef({
    required this.id,
    required this.name,
    required this.category,
    required this.points,
    required this.dailyCap,
    this.isCustom = false,
    this.isDeleted = false,
  });

  final String id;
  final String name;
  final TaskCategory category;
  final int points;

  /// Max completions per household per local day.
  final int dailyCap;

  /// Added by the household rather than built in.
  final bool isCustom;

  /// A custom task the household removed. Old logs keep their points, but
  /// it can't be logged again.
  final bool isDeleted;

  bool get isOther => id == otherTaskId;

  /// "Other" earns personal and team points but no boss damage or quest progress.
  bool get countsForBoss => !isOther;
  bool get countsForQuests => !isOther;
}

const otherTaskId = 'other';

/// A second log of the same task within this window triggers a duplicate warning.
const duplicateWindow = Duration(minutes: 30);

const catalog = <TaskDef>[
  // Shopping & errands
  TaskDef(id: 'groceries', name: 'Buy groceries', category: TaskCategory.shopping, points: 50, dailyCap: 2),
  TaskDef(id: 'errand', name: 'Run a household errand', category: TaskCategory.shopping, points: 20, dailyCap: 3),
  // Cooking
  TaskDef(id: 'cook_meal', name: 'Cook a meal', category: TaskCategory.cooking, points: 40, dailyCap: 3),
  TaskDef(id: 'meal_prep', name: 'Batch meal prep', category: TaskCategory.cooking, points: 50, dailyCap: 1),
  // Kitchen cleanup
  TaskDef(id: 'dishes', name: 'Wash the dishes', category: TaskCategory.kitchen, points: 20, dailyCap: 3),
  TaskDef(id: 'dishwasher', name: 'Load or unload dishwasher', category: TaskCategory.kitchen, points: 15, dailyCap: 4),
  TaskDef(id: 'clean_kitchen', name: 'Clean the kitchen', category: TaskCategory.kitchen, points: 35, dailyCap: 1),
  // Laundry
  TaskDef(id: 'laundry_load', name: 'Do a laundry load', category: TaskCategory.laundry, points: 25, dailyCap: 3),
  TaskDef(id: 'hang_laundry', name: 'Hang out the laundry', category: TaskCategory.laundry, points: 15, dailyCap: 3),
  TaskDef(id: 'fold_laundry', name: 'Fold and put away laundry', category: TaskCategory.laundry, points: 25, dailyCap: 3),
  TaskDef(id: 'bed_sheets', name: 'Change bed sheets', category: TaskCategory.laundry, points: 25, dailyCap: 1),
  // General cleaning
  TaskDef(id: 'vacuum', name: 'Vacuum the home', category: TaskCategory.cleaning, points: 35, dailyCap: 1),
  TaskDef(id: 'dust', name: 'Dust the home', category: TaskCategory.cleaning, points: 25, dailyCap: 1),
  TaskDef(id: 'mop', name: 'Mop the floors', category: TaskCategory.cleaning, points: 30, dailyCap: 1),
  TaskDef(id: 'deep_clean', name: 'Deep-clean a room', category: TaskCategory.cleaning, points: 60, dailyCap: 2),
  // Bathroom
  TaskDef(id: 'clean_bathroom', name: 'Clean the bathroom', category: TaskCategory.bathroom, points: 50, dailyCap: 1),
  // Tidying
  TaskDef(id: 'rubbish', name: 'Take out the rubbish', category: TaskCategory.tidying, points: 10, dailyCap: 2),
  TaskDef(id: 'tidy_room', name: 'Tidy a room', category: TaskCategory.tidying, points: 15, dailyCap: 3),
  TaskDef(id: 'declutter', name: 'Declutter a space', category: TaskCategory.tidying, points: 35, dailyCap: 1),
  // Maintenance
  TaskDef(id: 'repair', name: 'Handle a household repair', category: TaskCategory.maintenance, points: 40, dailyCap: 2),
  TaskDef(id: 'plants', name: 'Water the plants', category: TaskCategory.maintenance, points: 10, dailyCap: 1),
  // Planning & admin
  TaskDef(id: 'plan_meals', name: "Plan the week's meals", category: TaskCategory.planning, points: 30, dailyCap: 1),
  TaskDef(id: 'pay_bills', name: 'Pay or sort household bills', category: TaskCategory.planning, points: 30, dailyCap: 1),
  TaskDef(id: 'appointments', name: 'Book household appointments', category: TaskCategory.planning, points: 20, dailyCap: 2),
  // Supplies
  TaskDef(id: 'restock', name: 'Restock household essentials', category: TaskCategory.supplies, points: 20, dailyCap: 1),
  // Childcare
  TaskDef(id: 'school_run', name: 'School or nursery run', category: TaskCategory.childcare, points: 25, dailyCap: 2),
  TaskDef(id: 'bedtime', name: 'Bath and bedtime routine', category: TaskCategory.childcare, points: 30, dailyCap: 1),
  TaskDef(id: 'kids_meals', name: "Prepare kids' meals", category: TaskCategory.childcare, points: 25, dailyCap: 3),
  TaskDef(id: 'homework', name: 'Help with homework', category: TaskCategory.childcare, points: 20, dailyCap: 1),
  TaskDef(id: 'kids_medical', name: "Kids' medical appointment", category: TaskCategory.childcare, points: 40, dailyCap: 1),
  TaskDef(id: 'kids_admin', name: "Organise kids' activities & admin", category: TaskCategory.childcare, points: 25, dailyCap: 1),
  TaskDef(id: 'night_wakeup', name: 'Night wake-up', category: TaskCategory.childcare, points: 20, dailyCap: 3),
  // Pets
  TaskDef(id: 'walk_dog', name: 'Walk the dog', category: TaskCategory.pets, points: 20, dailyCap: 3),
  TaskDef(id: 'feed_pets', name: 'Feed the pets', category: TaskCategory.pets, points: 10, dailyCap: 2),
  TaskDef(id: 'litter', name: 'Clean litter, cage or tank', category: TaskCategory.pets, points: 15, dailyCap: 1),
  TaskDef(id: 'vet', name: 'Vet appointment', category: TaskCategory.pets, points: 40, dailyCap: 1),
  TaskDef(id: 'groom_pet', name: 'Groom a pet', category: TaskCategory.pets, points: 25, dailyCap: 1),
  // Other: user-named, fixed 10 pts, no boss damage.
  TaskDef(id: otherTaskId, name: 'Other task', category: TaskCategory.other, points: 10, dailyCap: 5),
];

final Map<String, TaskDef> _byId = {for (final t in catalog) t.id: t};

// Custom tasks: points range and repetition limit.
const customMinPoints = 10;
const customMaxPoints = 50;
const customPointsStep = 5;
const customDailyCap = 3;
const customNameMaxLength = 40;

/// Custom task ids are this prefix plus the database id.
const customTaskPrefix = 'custom_';

/// The household's own tasks, including deleted ones so old logs still
/// resolve. Kept here so any log can look up its task by id.
final Map<String, TaskDef> _customById = {};

void setCustomTasks(Iterable<TaskDef> tasks) {
  _customById
    ..clear()
    ..addAll({for (final t in tasks) t.id: t});
}

/// Categories a custom task can go in ("Other" is for one-off names).
List<TaskCategory> get customCategories =>
    [for (final c in TaskCategory.values) if (c != TaskCategory.other) c];

TaskDef taskById(String id) {
  final known = _byId[id] ?? _customById[id];
  if (known != null) return known;
  // A partner's new task that hasn't loaded here yet.
  if (id.startsWith(customTaskPrefix)) {
    return TaskDef(
      id: id,
      name: 'Custom task',
      category: TaskCategory.other,
      points: customMinPoints,
      dailyCap: customDailyCap,
      isCustom: true,
    );
  }
  throw ArgumentError('Unknown task id: $id');
}

/// Catalog plus the household's custom tasks, filtered to its settings.
List<TaskDef> visibleCatalog({
  required bool hasKids,
  required bool hasPets,
  Iterable<TaskDef> custom = const [],
}) =>
    [...catalog, ...custom.where((t) => !t.isDeleted)]
        .where((t) =>
            (hasKids || t.category != TaskCategory.childcare) &&
            (hasPets || t.category != TaskCategory.pets))
        .toList();
