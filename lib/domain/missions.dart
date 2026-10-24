/// A shared to-do with a due date. Missions earn no points and never affect
/// the boss, quests or streaks; completed ones show in the activity feed.
class Mission {
  const Mission({
    required this.id,
    required this.title,
    required this.dueOn,
    required this.createdAt,
    this.createdBy,
    this.assignee,
    this.completedAt,
    this.completedBy,
    this.deletedAt,
    this.deletedBy,
  });

  final String id;
  final String title;

  /// Household-local calendar date, as a UTC-midnight DateTime.
  final DateTime dueOn;
  final DateTime createdAt;
  final String? createdBy;

  /// The partner who picked it up, if any.
  final String? assignee;
  final DateTime? completedAt;
  final String? completedBy;
  final DateTime? deletedAt;
  final String? deletedBy;

  bool get isDeleted => deletedAt != null;
  bool get isDone => completedAt != null && !isDeleted;
  bool get isOpen => completedAt == null && !isDeleted;

  bool isOverdue(DateTime today) => isOpen && dueOn.isBefore(today);

  /// Days until due (negative when overdue).
  int daysLeft(DateTime today) => dueOn.difference(today).inDays;

  Mission copyWith({
    String? title,
    DateTime? dueOn,
    String? Function()? assignee,
    DateTime? Function()? completedAt,
    String? Function()? completedBy,
    DateTime? deletedAt,
    String? deletedBy,
  }) =>
      Mission(
        id: id,
        title: title ?? this.title,
        dueOn: dueOn ?? this.dueOn,
        createdAt: createdAt,
        createdBy: createdBy,
        assignee: assignee != null ? assignee() : this.assignee,
        completedAt: completedAt != null ? completedAt() : this.completedAt,
        completedBy: completedBy != null ? completedBy() : this.completedBy,
        deletedAt: deletedAt ?? this.deletedAt,
        deletedBy: deletedBy ?? this.deletedBy,
      );
}

/// Open missions, most urgent first.
List<Mission> openMissions(Iterable<Mission> all) =>
    all.where((m) => m.isOpen).toList()..sort((a, b) => a.dueOn.compareTo(b.dueOn));

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDateKey(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime.utc(p[0], p[1], p[2]);
}
