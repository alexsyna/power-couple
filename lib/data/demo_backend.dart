import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

import '../domain/calendar.dart';
import '../domain/activity.dart';
import '../domain/catalog.dart';
import '../domain/missions.dart';
import '../domain/models.dart';
import '../domain/questions.dart';
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
  final List<TaskDef> _customTasks = [];
  final List<DailyMetrics> _metrics = [];
  final List<Snap> _snaps = [];
  final Map<String, Uint8List> _snapPhotos = {};
  final List<TogetherSession> _sessions = [];
  final List<Answer> _answers = [];
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
    final today = HouseholdCalendar(_household.timezone).localDate(now);
    // Six revealed Bond days (bond level 6), and Sam has answered today.
    for (var i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      for (final m in [alex, sam]) {
        if (i == 0 && m == alex) continue;
        final q = questionFor(
          coupleId: _household.id,
          memberIds: [alex.userId, sam.userId],
          userId: m.userId,
          day: day,
          unlocked: _household.unlockedPacks,
        );
        _answers.add(Answer(
          userId: m.userId,
          day: day,
          questionId: q.id,
          text: m == alex ? 'Honestly? Our Sunday pancakes.' : 'The trip to the lake last spring 🥰',
          // Alex answers last except yesterday, when Sam completes the day
          // after Alex: a reveal Alex hasn't seen yet.
          createdAt: now.subtract(Duration(days: i, hours: (m == alex) == (i == 1) ? 3 : 2)),
        ));
      }
    }
    _missions.addAll([
      Mission(id: 'm1', title: 'Fix the wobbly shelf', dueOn: today.add(const Duration(days: 2)), createdAt: now, createdBy: alex.userId, assignee: sam.userId),
      Mission(id: 'm2', title: 'Book the car service', dueOn: today.subtract(const Duration(days: 1)), createdAt: now, createdBy: sam.userId),
      Mission(id: 'm3', title: 'Sort the winter clothes', dueOn: today.add(const Duration(days: 9)), createdAt: now, createdBy: alex.userId),
      Mission(id: 'm4', title: 'Renew home insurance', dueOn: today, createdAt: now, createdBy: sam.userId, completedAt: now.subtract(const Duration(hours: 5)), completedBy: sam.userId, assignee: sam.userId),
    ]);
    _seedStars(now, today);
    _logs.add(TaskLog(
      id: 'seed-${_seq++}',
      taskId: otherTaskId,
      customName: 'Fixed the garden gate',
      loggedBy: sam.userId,
      doneAt: now.subtract(const Duration(days: 2)),
      createdAt: now.subtract(const Duration(days: 2)),
    ));
  }

  /// A week of steps, sleep, snaps and one evening out, so the stars card
  /// has something to show.
  void _seedStars(DateTime now, DateTime today) {
    final cal = HouseholdCalendar(_household.timezone);
    const alexSteps = [9200, 6100, 4300, 8800, 10400, 5200, 7600];
    const samSteps = [8100, 5400, 3200, 9900, 7300, 2900, 3900];
    const alexSleep = [450, 380, 330, 425, 470, 300, 405];
    const samSleep = [430, 410, 290, 440, 395, 365, 0];
    for (var i = 6; i >= 0; i--) {
      final day = addDays(today, -i);
      _metrics
        ..add(DailyMetrics(userId: alex.userId, day: day, steps: alexSteps[i], sleepMinutes: alexSleep[i]))
        ..add(DailyMetrics(userId: sam.userId, day: day, steps: samSteps[i], sleepMinutes: samSleep[i] == 0 ? null : samSleep[i]));
      if (i == 0) continue;
      final m = snapPromptMinute(_household.id, dateKey(day));
      final prompt = cal.instantAt(day, m ~/ 60, m % 60);
      for (final (who, after) in [(alex.userId, 20 + 25 * i), (sam.userId, 35 * i)]) {
        if (i == 4 && who == sam.userId) continue; // Sam missed one
        _snaps.add(Snap(id: 'snap-${_seq++}', userId: who, day: day, takenAt: prompt.add(Duration(minutes: after))));
      }
    }
    // Yesterday evening: 75 minutes out together, a few blocks from home.
    final start = cal.instantAt(addDays(today, -1), 19, 0);
    _household = _household.copyWith(home: (37.9838, 23.7275));
    _sessions.add(TogetherSession(
      id: 'together-${_seq++}',
      startedBy: alex.userId,
      startedAt: start,
      joinedBy: sam.userId,
      joinedAt: start,
      endedAt: start.add(const Duration(minutes: 80)),
      pings: [
        for (var m = 0; m < 75; m++)
          for (final (who, dLat) in [(alex.userId, 0.0), (sam.userId, 0.0002)])
            TogetherPing(userId: who, at: start.add(Duration(minutes: m)), lat: 37.9938 + dLat, lng: 23.7375),
      ],
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
  Future<List<AnswerMeta>> loadAnswerLog(String householdId) async => [
        for (final a in _answers) AnswerMeta(userId: a.userId, day: a.day, createdAt: a.createdAt),
      ];

  @override
  Future<List<Answer>> loadAnswers(String householdId) async => [
        for (final a in _answers)
          if (a.userId == _user || _answers.any((x) => x.userId == _user && x.day == a.day)) a,
      ];

  @override
  Future<void> submitAnswer({
    required String householdId,
    required DateTime day,
    required String questionId,
    required String text,
  }) async {
    if (_answers.any((a) => a.userId == _user && a.day == day)) {
      throw BackendException('You already answered today');
    }
    _answers.add(Answer(
      userId: _user!,
      day: day,
      questionId: questionId,
      text: text,
      createdAt: DateTime.now().toUtc(),
    ));
    _changes.add(null);
  }

  @override
  Future<void> unlockPacks(String householdId, Set<QuestionPack> packs) async {
    _household = _household.copyWith(unlockedPacks: packs);
    _changes.add(null);
  }

  @override
  Future<void> registerDevice(String token) async {}

  @override
  Future<void> unregisterDevice(String token) async {}

  // ------------------------------------------------------- daily stars

  @override
  Future<void> setHome(String householdId, double lat, double lng) async {
    _household = _household.copyWith(home: (lat, lng));
    _changes.add(null);
  }

  @override
  Future<List<DailyMetrics>> loadMetrics(String householdId, DateTime since) async =>
      [for (final m in _metrics) if (!m.day.isBefore(since)) m];

  @override
  Future<void> saveMetrics(String householdId, List<DailyMetrics> mine) async {
    for (final m in mine) {
      _metrics.removeWhere((x) => x.userId == _user && x.day == m.day);
      _metrics.add(DailyMetrics(userId: _user!, day: m.day, steps: m.steps, sleepMinutes: m.sleepMinutes));
    }
  }

  @override
  Future<List<Snap>> loadSnaps(String householdId, DateTime since) async =>
      [for (final s in _snaps) if (!s.day.isBefore(since)) s];

  @override
  Future<Snap> uploadSnap(String householdId, DateTime day, Uint8List jpeg) async {
    if (_snaps.any((s) => s.userId == _user && s.day == day)) {
      throw BackendException('You already snapped today');
    }
    final snap = Snap(
      id: 'snap-${_seq++}',
      userId: _user!,
      day: day,
      takenAt: DateTime.now().toUtc(),
      path: 'demo/${_seq++}',
    );
    _snapPhotos[snap.path!] = jpeg;
    _snaps.add(snap);
    _changes.add(null);
    return snap;
  }

  @override
  Future<Uint8List?> snapPhoto(Snap snap) async => _snapPhotos[snap.path];

  @override
  Future<List<TogetherSession>> loadTogether(String householdId, DateTime since) async =>
      [for (final s in _sessions) if (!s.startedAt.isBefore(since.subtract(const Duration(days: 1)))) s];

  int _sessionIndex(String id) => _sessions.indexWhere((s) => s.id == id);

  TogetherSession _copySession(TogetherSession s, {String? joinedBy, DateTime? joinedAt, DateTime? endedAt}) =>
      TogetherSession(
        id: s.id,
        startedBy: s.startedBy,
        startedAt: s.startedAt,
        joinedBy: joinedBy ?? s.joinedBy,
        joinedAt: joinedAt ?? s.joinedAt,
        endedAt: endedAt ?? s.endedAt,
        pings: s.pings,
      );

  @override
  Future<TogetherSession> startTogether(String householdId) async {
    final s = TogetherSession(id: 'together-${_seq++}', startedBy: _user!, startedAt: DateTime.now().toUtc());
    _sessions.add(s);
    _changes.add(null);
    return s;
  }

  @override
  Future<void> joinTogether(String sessionId) async {
    final i = _sessionIndex(sessionId);
    if (i < 0 || _sessions[i].joinedBy != null) return;
    _sessions[i] = _copySession(_sessions[i], joinedBy: _user, joinedAt: DateTime.now().toUtc());
    _changes.add(null);
  }

  @override
  Future<void> endTogether(String sessionId) async {
    final i = _sessionIndex(sessionId);
    if (i < 0 || _sessions[i].endedAt != null) return;
    _sessions[i] = _copySession(_sessions[i], endedAt: DateTime.now().toUtc());
    _changes.add(null);
  }

  @override
  Future<bool> addPing(String sessionId, double lat, double lng) async {
    final i = _sessionIndex(sessionId);
    if (i < 0 || !_sessions[i].isActive(DateTime.now().toUtc())) return false;
    final s = _sessions[i];
    _sessions[i] = s.withPings([...s.pings, TogetherPing(userId: _user!, at: DateTime.now().toUtc(), lat: lat, lng: lng)]);
    return true;
  }

  @override
  Future<List<TaskDef>> loadCustomTasks(String householdId) async => List.of(_customTasks);

  @override
  Future<TaskDef> createCustomTask({
    required String householdId,
    required String name,
    required TaskCategory category,
    required int points,
  }) async {
    final t = TaskDef(
      id: '$customTaskPrefix${_seq++}',
      name: name,
      category: category,
      points: points,
      dailyCap: customDailyCap,
      isCustom: true,
    );
    _customTasks.add(t);
    _changes.add(null);
    return t;
  }

  @override
  Future<void> deleteCustomTask(String taskId) async {
    final i = _customTasks.indexWhere((t) => t.id == taskId);
    if (i < 0) return;
    final t = _customTasks[i];
    _customTasks[i] = TaskDef(
      id: t.id,
      name: t.name,
      category: t.category,
      points: t.points,
      dailyCap: t.dailyCap,
      isCustom: true,
      isDeleted: true,
    );
    _changes.add(null);
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
