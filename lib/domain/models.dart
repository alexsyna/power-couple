import 'catalog.dart';
import 'questions.dart';

/// How a person is pictured: their initial, a preset avatar, or a photo.
enum AvatarKind {
  initial,
  boy,
  girl,
  photo;

  static AvatarKind parse(String? s) =>
      AvatarKind.values.firstWhere((k) => k.name == s, orElse: () => AvatarKind.initial);
}

class Member {
  const Member({
    required this.userId,
    required this.displayName,
    this.avatarKind = AvatarKind.initial,
    this.photoUrl,
  });

  final String userId;
  final String displayName;
  final AvatarKind avatarKind;

  /// Displayable photo URL (signed https URL, or a data: URI in demo mode).
  final String? photoUrl;

  Member copyWith({String? displayName, AvatarKind? avatarKind, String? photoUrl}) => Member(
        userId: userId,
        displayName: displayName ?? this.displayName,
        avatarKind: avatarKind ?? this.avatarKind,
        photoUrl: photoUrl ?? this.photoUrl,
      );
}

class Household {
  const Household({
    required this.id,
    required this.timezone,
    required this.hasKids,
    required this.hasPets,
    required this.inviteCode,
    required this.createdAt,
    required this.members,
    this.unlockedPacks = const {QuestionPack.light},
  });

  final String id;
  final String timezone;
  final bool hasKids;
  final bool hasPets;
  final String inviteCode;
  final DateTime createdAt;
  final List<Member> members;

  /// Bond question packs this household can use (shared by both partners).
  final Set<QuestionPack> unlockedPacks;

  bool get isComplete => members.length >= 2;

  Member? partnerOf(String userId) {
    for (final m in members) {
      if (m.userId != userId) return m;
    }
    return null;
  }

  Household copyWith({
    String? timezone,
    bool? hasKids,
    bool? hasPets,
    List<Member>? members,
    Set<QuestionPack>? unlockedPacks,
  }) =>
      Household(
        id: id,
        timezone: timezone ?? this.timezone,
        hasKids: hasKids ?? this.hasKids,
        hasPets: hasPets ?? this.hasPets,
        inviteCode: inviteCode,
        createdAt: createdAt,
        members: members ?? this.members,
        unlockedPacks: unlockedPacks ?? this.unlockedPacks,
      );
}

/// One completed task as reported by a partner. Logs are never deleted;
/// undo sets [undoneAt] so history stays auditable.
class TaskLog {
  const TaskLog({
    required this.id,
    required this.taskId,
    required this.loggedBy,
    required this.doneAt,
    required this.createdAt,
    this.customName,
    this.sharedWith,
    this.undoneAt,
    this.undoneBy,
  });

  final String id;
  final String taskId;
  final String? customName;

  /// Null when the logger's account was deleted.
  final String? loggedBy;

  /// The partner who shared this task, if any. Points are split; the team
  /// still gets the full value.
  final String? sharedWith;

  final DateTime doneAt;
  final DateTime createdAt;
  final DateTime? undoneAt;

  /// Who deleted this log (either partner may).
  final String? undoneBy;

  bool get isActive => undoneAt == null;
  bool get isShared => sharedWith != null;
  bool get isBackdated => createdAt.difference(doneAt) > const Duration(minutes: 15);

  TaskDef get task => taskById(taskId);
  String get displayName => task.isOther ? (customName ?? task.name) : task.name;

  /// Points per person. Shared logs split base points, with the odd point
  /// going to the logger.
  Map<String, int> pointsByPerson() {
    final p = task.points;
    final logger = loggedBy ?? formerMemberId;
    if (sharedWith == null) return {logger: p};
    return {logger: (p + 1) ~/ 2, sharedWith!: p ~/ 2};
  }

  TaskLog undone(DateTime at, String by) => TaskLog(
        id: id,
        taskId: taskId,
        customName: customName,
        loggedBy: loggedBy,
        sharedWith: sharedWith,
        doneAt: doneAt,
        createdAt: createdAt,
        undoneAt: at,
        undoneBy: by,
      );
}

/// Bucket for points from deleted accounts.
const formerMemberId = '__former__';
