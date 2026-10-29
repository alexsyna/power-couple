import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

import '../domain/catalog.dart';
import '../domain/missions.dart';
import '../domain/models.dart';
import 'backend.dart';

/// In-memory backend with two partners and a few weeks of seeded history.
/// Used when no Supabase config is provided, so the app can be tried on a
/// single device: [switchPartner] flips which partner is "signed in".
class DemoBackend implements Backend {
  DemoBackend({DateTime? now}) {
    _seed(now ?? DateTime.now().toUtc());
  }

  static const alex = Member(userId: 'demo-alex', displayName: 'Alex');
  static const sam = Member(userId: 'demo-sam', displayName: 'Sam');

  final _auth = StreamController<void>.broadcast();
  final _changes = StreamController<void>.broadcast();
  late Household _household;
  final List<TaskLog> _logs = [];
  final List<Mission> _missions = [];
  String? _user = alex.userId;
  var _seq = 0;

  @override
  bool get isDemo => true;

  @override
  String? get currentUserId => _user;

  @override
  Stream<void> get authChanges => _auth.stream;

  void switchPartner() {
    _user = _user == alex.userId ? sam.userId : alex.userId;
    _auth.add(null);
  }

  void _seed(DateTime now) {
    _household = Household(
      id: 'demo-household',
      timezone: 'Europe/Athens',
      hasKids: true,
      hasPets: true,
      inviteCode: 'DEMO2026',
      createdAt: now.subtract(const Duration(days: 19)),
      members: const [alex, sam],
    );
    final rnd = Random(7);
    final pool = catalog.where((t) => !t.isOther).toList();
    for (var day = 18; day >= 0; day--) {
      // Busier on earlier days so the demo shows both won and lost weeks.
      final perDay = (day > 4 ? 5 : 3) + rnd.nextInt(4);
      for (var i = 0; i < perDay; i++) {
        final doneAt = now.subtract(Duration(days: day, hours: 1 + rnd.nextInt(10)));
        if (doneAt.isAfter(now)) continue;
        final task = pool[rnd.nextInt(pool.length)];
        final by = rnd.nextInt(5) < 3 ? alex.userId : sam.userId;
        _logs.add(TaskLog(
          id: 'seed-${_seq++}',
          taskId: task.id,
          loggedBy: by,
          sharedWith: rnd.nextInt(8) == 0 ? (by == alex.userId ? sam.userId : alex.userId) : null,
          doneAt: doneAt,
          createdAt: doneAt,
        ));
      }
    }
    final today = DateTime.utc(now.year, now.month, now.day);
    _missions.addAll([
      Mission(id: 'm1', title: 'Fix the wobbly shelf', dueOn: today.add(const Duration(days: 2)), createdAt: now, createdBy: alex.userId, assignee: sam.userId),
      Mission(id: 'm2', title: 'Book the car service', dueOn: today.subtract(const Duration(days: 1)), createdAt: now, createdBy: sam.userId),
      Mission(id: 'm3', title: 'Sort the winter clothes', dueOn: today.add(const Duration(days: 9)), createdAt: now, createdBy: alex.userId),
      Mission(id: 'm4', title: 'Renew home insurance', dueOn: today, createdAt: now, createdBy: sam.userId, completedAt: now.subtract(const Duration(hours: 5)), completedBy: sam.userId, assignee: sam.userId),
    ]);
    _logs.add(TaskLog(
      id: 'seed-${_seq++}',
      taskId: otherTaskId,
      customName: 'Fixed the garden gate',
      loggedBy: sam.userId,
      doneAt: now.subtract(const Duration(days: 2)),
      createdAt: now.subtract(const Duration(days: 2)),
    ));
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    _user = alex.userId;
    _auth.add(null);
  }

  @override
  Future<void> signInWithGoogle() => signIn(email: 'demo@example.com', password: '');

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await signIn(email: email, password: password);
    return false;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _auth.add(null);
  }

  @override
  Future<Household?> loadHousehold() async =>
      _household.members.any((m) => m.userId == _user) ? _household : null;

  @override
  Future<Household> createHousehold({
    required String timezone,
    required bool hasKids,
    required bool hasPets,
  }) async {
    _household = _household.copyWith(
      timezone: timezone,
      hasKids: hasKids,
      hasPets: hasPets,
      members: [..._household.members, if (_user == alex.userId) alex else sam],
    );
    return _household;
  }

  @override
  Future<Household> joinHousehold(String inviteCode) async {
    if (inviteCode.trim().toUpperCase() != _household.inviteCode) {
      throw BackendException('Invite code not found');
    }
    return createHousehold(
        timezone: _household.timezone, hasKids: _household.hasKids, hasPets: _household.hasPets);
  }

  @override
  Future<void> leaveHousehold() async {
    _household = _household.copyWith(
        members: _household.members.where((m) => m.userId != _user).toList());
    _changes.add(null);
  }

  void _updateMe(Member Function(Member) change) {
    _household = _household.copyWith(members: [
      for (final m in _household.members) m.userId == _user ? change(m) : m,
    ]);
    _changes.add(null);
  }

  @override
  Future<void> updateProfile({String? displayName, AvatarKind? avatarKind}) async =>
      _updateMe((m) => m.copyWith(displayName: displayName, avatarKind: avatarKind));

  @override
  Future<void> uploadAvatarPhoto(Uint8List jpeg) async => _updateMe((m) => m.copyWith(
        avatarKind: AvatarKind.photo,
        photoUrl: 'data:image/jpeg;base64,${base64Encode(jpeg)}',
      ));

  @override
  Future<void> updateHousehold(
    String householdId, {
    String? timezone,
    bool? hasKids,
    bool? hasPets,
  }) async {
    _household = _household.copyWith(timezone: timezone, hasKids: hasKids, hasPets: hasPets);
    _changes.add(null);
  }

  @override
  Future<List<TaskLog>> loadLogs(String householdId) async => List.of(_logs);

  @override
  Future<TaskLog> insertLog({
    required String householdId,
    required String taskId,
    required DateTime doneAt,
    String? customName,
    String? sharedWith,
  }) async {
    final log = TaskLog(
      id: 'log-${_seq++}',
      taskId: taskId,
      customName: customName,
      loggedBy: _user,
      sharedWith: sharedWith,
      doneAt: doneAt,
      createdAt: DateTime.now().toUtc(),
    );
    _logs.add(log);
    return log;
  }

  @override
  Future<void> undoLog(String logId) async {
    final i = _logs.indexWhere((l) => l.id == logId);
    if (i < 0 || !_logs[i].isActive) {
      throw BackendException('Cannot delete this log');
    }
    _logs[i] = _logs[i].undone(DateTime.now().toUtc(), _user!);
  }

  @override
  Future<List<Mission>> loadMissions(String householdId) async =>
      _missions.where((m) => !m.isDeleted).toList();

  @override
  Future<Mission> createMission({
    required String householdId,
    required String title,
    required DateTime dueOn,
    String? assignee,
  }) async {
    final m = Mission(
      id: 'mission-${_seq++}',
      title: title,
      dueOn: dueOn,
      createdAt: DateTime.now().toUtc(),
      createdBy: _user,
      assignee: assignee,
    );
    _missions.add(m);
    return m;
  }

  @override
  Future<void> updateMission(Mission mission) async {
    final i = _missions.indexWhere((m) => m.id == mission.id);
    if (i >= 0) _missions[i] = mission;
  }

  @override
  Future<void> deleteMission(String missionId) async {
    final i = _missions.indexWhere((m) => m.id == missionId);
    if (i >= 0) _missions[i] = _missions[i].copyWith(deletedAt: DateTime.now().toUtc(), deletedBy: _user);
  }

  @override
  Stream<void> householdChanges(String householdId) => _changes.stream;
}
