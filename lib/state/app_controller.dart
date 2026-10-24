import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../data/backend.dart';
import '../domain/badges.dart';
import '../domain/catalog.dart';
import '../domain/engine.dart';
import '../domain/missions.dart';
import '../domain/models.dart';

enum AppStatus { loading, signedOut, needsHousehold, ready }

/// App-wide state: who is signed in, their household, and its task logs.
/// Every score shown in the UI is derived from [logs] by [engine].
class AppController extends ChangeNotifier {
  AppController(this.backend) {
    _authSub = backend.authChanges.listen((_) => refresh());
    // Live updates pause while the app is backgrounded (always on iOS), so
    // catch up with the partner's changes whenever it comes back.
    _lifecycle = AppLifecycleListener(onResume: refresh);
    refresh();
  }

  final Backend backend;

  AppStatus status = AppStatus.loading;
  Household? household;
  List<TaskLog> logs = const [];
  List<Mission> missions = const [];
  ScoringEngine? _engine;
  String? loadError;

  StreamSubscription<void>? _authSub;
  StreamSubscription<void>? _changesSub;
  String? _watching;
  late final AppLifecycleListener _lifecycle;

  DateTime get now => DateTime.now().toUtc();
  ScoringEngine get engine => _engine!;
  String get me => backend.currentUserId!;
  Member? get partner => household?.partnerOf(me);

  String nameOf(String? userId) {
    if (userId == me) return 'You';
    for (final m in household?.members ?? const <Member>[]) {
      if (m.userId == userId) return m.displayName;
    }
    return 'Former partner';
  }

  Member? memberById(String? userId) {
    for (final m in household?.members ?? const <Member>[]) {
      if (m.userId == userId) return m;
    }
    return null;
  }

  String myName() =>
      household?.members.firstWhere((m) => m.userId == me).displayName ?? 'You';

  Future<void> refresh() async {
    try {
      if (backend.currentUserId == null) {
        _set(AppStatus.signedOut, null, const []);
        return;
      }
      final h = await backend.loadHousehold();
      if (h == null) {
        _set(AppStatus.needsHousehold, null, const []);
        return;
      }
      final (l, m) = (await backend.loadLogs(h.id), await backend.loadMissions(h.id));
      missions = m;
      _set(AppStatus.ready, h, l);
      _watch(h.id);
      loadError = null;
    } on BackendException catch (e) {
      loadError = e.message;
      notifyListeners();
    }
  }

  void _set(AppStatus s, Household? h, List<TaskLog> l) {
    status = s;
    household = h;
    logs = l;
    _engine = h == null ? null : ScoringEngine(h);
    if (h == null) {
      _changesSub?.cancel();
      _changesSub = null;
      _watching = null;
    }
    notifyListeners();
  }

  void _watch(String householdId) {
    if (_watching == householdId) return;
    _changesSub?.cancel();
    _watching = householdId;
    _changesSub = backend.householdChanges(householdId).listen((_) => refresh());
  }

  // ------------------------------------------------------------ derived

  WeekResult get currentWeek => engine.week(engine.calendar.weekOf(now), logs);

  /// All weeks newest first, recalculated from logs.
  List<WeekResult> get history => engine.history(logs, now);

  int get streak => engine.streak(history, now);

  List<BadgeProgress> get badgeProgress => evaluateBadges(BadgeStats.from(
        newestFirst: history,
        logs: logs,
        missions: missions,
        members: household!.members,
      ));

  DateTime get today => engine.calendar.localDate(now);

  List<TaskDef> get visibleTasks =>
      visibleCatalog(hasKids: household!.hasKids, hasPets: household!.hasPets);

  /// My most recently logged distinct catalog tasks, for one-tap logging.
  List<TaskDef> get recentTasks {
    final seen = <String>{};
    final visible = {for (final t in visibleTasks) t.id};
    final mine = logs.where((l) => l.loggedBy == me && l.isActive).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [
      for (final l in mine)
        if (!l.task.isOther && visible.contains(l.taskId) && seen.add(l.taskId)) l.task,
    ].take(6).toList();
  }

  // ------------------------------------------------------------ actions

  LogCheck check(TaskDef task, DateTime doneAt) => engine.check(task, doneAt, logs, now);

  Future<TaskLog> logTask(
    TaskDef task, {
    required DateTime doneAt,
    String? customName,
    bool shared = false,
  }) async {
    final log = await backend.insertLog(
      householdId: household!.id,
      taskId: task.id,
      doneAt: doneAt,
      customName: customName,
      sharedWith: shared ? partner?.userId : null,
    );
    logs = [...logs, log];
    notifyListeners();
    return log;
  }

  /// Removes a log for both partners. Either partner can delete any entry;
  /// it stays in history as "deleted by …" and the week is recalculated.
  Future<void> undo(TaskLog log) async {
    await backend.undoLog(log.id);
    logs = [for (final l in logs) l.id == log.id ? l.undone(now, me) : l];
    notifyListeners();
  }

  Future<Mission> createMission(String title, DateTime dueOn, {String? assignee}) async {
    final m = await backend.createMission(
        householdId: household!.id, title: title, dueOn: dueOn, assignee: assignee);
    missions = [...missions, m];
    notifyListeners();
    return m;
  }

  Future<void> saveMission(Mission m) async {
    await backend.updateMission(m);
    missions = [for (final x in missions) x.id == m.id ? m : x];
    notifyListeners();
  }

  Future<void> deleteMission(Mission m) async {
    await backend.deleteMission(m.id);
    missions = [for (final x in missions) if (x.id != m.id) x];
    notifyListeners();
  }

  /// Picks up a mission for me, or drops it if it's already mine.
  Future<void> toggleMissionPickup(Mission m) =>
      saveMission(m.copyWith(assignee: () => m.assignee == me ? null : me));

  Future<void> completeMission(Mission m) => saveMission(m.copyWith(
        assignee: () => m.assignee ?? me,
        completedAt: () => now,
        completedBy: () => me,
      ));

  Future<void> reopenMission(Mission m) =>
      saveMission(m.copyWith(completedAt: () => null, completedBy: () => null));

  Future<void> signIn(String email, String password) =>
      backend.signIn(email: email, password: password);

  Future<bool> signUp(String email, String password, String name) =>
      backend.signUp(email: email, password: password, displayName: name);

  Future<void> signOut() => backend.signOut();

  Future<void> createHousehold(String timezone, bool hasKids, bool hasPets) async {
    await backend.createHousehold(timezone: timezone, hasKids: hasKids, hasPets: hasPets);
    await refresh();
  }

  Future<void> joinHousehold(String code) async {
    await backend.joinHousehold(code);
    await refresh();
  }

  Future<void> leaveHousehold() async {
    await backend.leaveHousehold();
    await refresh();
  }

  Future<void> updateProfile({String? displayName, AvatarKind? avatarKind}) async {
    await backend.updateProfile(displayName: displayName, avatarKind: avatarKind);
    await refresh();
  }

  Future<void> uploadAvatarPhoto(Uint8List jpeg) async {
    await backend.uploadAvatarPhoto(jpeg);
    await refresh();
  }

  Future<void> updateSettings({String? timezone, bool? hasKids, bool? hasPets}) async {
    await backend.updateHousehold(household!.id,
        timezone: timezone, hasKids: hasKids, hasPets: hasPets);
    await refresh();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _changesSub?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child})
      : super(notifier: controller);

  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
