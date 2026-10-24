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
  });

  final String id;
  final String name;
  final TaskCategory category;
  final int points;

  /// Max completions per household per local day.
  final int dailyCap;

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

TaskDef taskById(String id) =>
    _byId[id] ?? (throw ArgumentError('Unknown task id: $id'));

/// Catalog filtered to the household's settings.
List<TaskDef> visibleCatalog({required bool hasKids, required bool hasPets}) =>
    catalog
        .where((t) =>
            (hasKids || t.category != TaskCategory.childcare) &&
            (hasPets || t.category != TaskCategory.pets))
        .toList();
