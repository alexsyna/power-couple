import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/backend.dart';
import '../domain/activity.dart';
import '../domain/badges.dart';
import '../domain/calendar.dart';
import '../domain/challenge.dart';
import '../domain/catalog.dart';
import '../domain/engine.dart';
import '../domain/missions.dart';
import '../domain/questions.dart';
import '../domain/models.dart';
import '../domain/stars.dart';
import 'health_sync.dart';
import 'invites.dart';
import 'push.dart';
import 'snap_prompts.dart';

enum AppStatus { loading, signedOut, needsHousehold, ready }

/// App-wide state: who is signed in, their household, and its task logs.
/// Every score shown in the UI is derived from [logs] by [engine].
class AppController extends ChangeNotifier {
  AppController(this.backend, {this.prefs}) {
    _authSub = backend.authChanges.listen((_) => refresh());
    // Live updates pause while the app is backgrounded (always on iOS), so
    // catch up with the partner's changes whenever it comes back.
    _lifecycle = AppLifecycleListener(onResume: refresh);
    invites.addListener(() => handleInvite().ignore());
    invites.start().ignore();
    refresh();
  }

  final Backend backend;

  /// Device storage for which Bond reveals have been shown here.
  final SharedPreferences? prefs;

  /// Bond push notifications on this phone.
  late final push = PushNotifications(backend, prefs);

  /// Invite links waiting to be used (climbs and households).
  late final invites = InviteLinks(prefs);

  /// What happened with an invite, for the UI to show.
  final inviteOutcome = ValueNotifier<InviteOutcome?>(null);

  /// Daily stars: Apple Health and Snap moment reminders.
  late final health = HealthSync(prefs);
  late final snapPrompts = SnapPrompts(prefs);

  AppStatus status = AppStatus.loading;
  Household? household;
  List<TaskLog> logs = const [];
  List<Mission> missions = const [];

  /// The household's own tasks, deleted ones included.
  List<TaskDef> customTasks = const [];

  /// Recent days' measurements for both partners.
  List<DailyMetrics> metrics = const [];
  List<Snap> snaps = const [];

  /// Castle Climbs my household is in.
  List<Challenge> challenges = const [];

  /// How many days back stars are shown.
  static const starDays = 7;

  /// Bond: who answered when (all), and the answers I'm allowed to read.
  List<AnswerMeta> answerLog = const [];
  List<Answer> answers = const [];
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
        handleInvite().ignore();
        return;
      }
      // Custom tasks first: logs look their task up by id.
      customTasks = await backend.loadCustomTasks(h.id);
      setCustomTasks(customTasks);
      final (l, m) = (await backend.loadLogs(h.id), await backend.loadMissions(h.id));
      missions = m;
      answerLog = await backend.loadAnswerLog(h.id);
      answers = await backend.loadAnswers(h.id);
      challenges = await backend.loadChallenges(h.id);
      final cal = HouseholdCalendar(h.timezone);
      final today = cal.localDate(now);
      // Enough history for the star card and every climb still being scored.
      var since = addDays(today, -starDays);
      for (final c in challenges) {
        if (c.phase(today, now) != ClimbPhase.revealed && c.startsOn.isBefore(since)) since = c.startsOn;
      }
      metrics = await backend.loadMetrics(h.id, since);
      snaps = await backend.loadSnaps(h.id, since);
      _set(AppStatus.ready, h, l);
      push.attach(me).ignore();
      _afterLoad();
      handleInvite().ignore();
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
    _engine = h == null
        ? null
        : ScoringEngine(h, bondReveals: revealTimes(answerLog, [for (final m in h.members) m.userId]));
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

  // ------------------------------------------------------------ bond

  List<String> get _memberIds => [for (final m in household!.members) m.userId];

  /// Days both partners answered; +1 boss damage per hit for each.
  int get bondLevel => engine.bondReveals.length;

  /// The question [userId] gets today.
  Question questionToday(String userId) => questionFor(
        coupleId: household!.id,
        memberIds: _memberIds,
        userId: userId,
        day: today,
        unlocked: household!.unlockedPacks,
      );

  bool _answered(String? userId, DateTime day) =>
      answerLog.any((a) => a.userId == userId && a.day == day);

  bool get iAnsweredToday => _answered(me, today);
  bool get partnerAnsweredToday => partner != null && _answered(partner!.userId, today);

  /// Partner answered and is waiting for me: drives the nav badge.
  /// Something on the Bond tab needs me: my partner is waiting for my
  /// answer, or a reveal happened that I haven't seen yet.
  bool get bondNeedsMe => (partnerAnsweredToday && !iAnsweredToday) || missedReveals.isNotEmpty;

  // Reveals shown on this device during this session (fallback when there's
  // no device storage, e.g. in tests).
  final Set<DateTime> _shownThisSession = {};

  static String _seenKey(DateTime day) => 'bond_revealed_${dateKey(day)}';

  bool isRevealSeen(DateTime day) => prefs?.getBool(_seenKey(day)) ?? _shownThisSession.contains(day);

  void markRevealSeen(DateTime day) {
    if (_shownThisSession.add(day)) {
      prefs?.setBool(_seenKey(day), true);
      // Next frame, so the badge updates without rebuilding mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }
  }

  /// How far back the Bond history goes.
  static const bondHistoryDays = 7;

  /// Revealed past days within the history window, newest first.
  List<(DateTime day, Answer mine, Answer theirs)> get recentReveals {
    final cutoff = today.subtract(const Duration(days: bondHistoryDays + 1));
    final out = [
      for (final (day, _, mine, theirs) in revealedDays)
        if (day != today && day.isAfter(cutoff)) (day, mine, theirs),
    ];
    return out..sort((a, b) => b.$1.compareTo(a.$1));
  }

  /// Recent days my partner completed after I'd answered, which this device
  /// hasn't shown yet: I never saw their flip. Newest first.
  List<(DateTime day, Answer mine, Answer theirs)> get missedReveals => [
        for (final r in recentReveals)
          if (r.$3.createdAt.isAfter(r.$2.createdAt) && !isRevealSeen(r.$1)) r,
      ];

  Answer? answerOn(String? userId, DateTime day) {
    for (final a in answers) {
      if (a.userId == userId && a.day == day) return a;
    }
    return null;
  }

  /// Revealed days (both answers visible to me), newest first.
  List<(DateTime day, DateTime revealedAt, Answer mine, Answer theirs)> get revealedDays {
    final p = partner?.userId;
    final out = <(DateTime, DateTime, Answer, Answer)>[];
    for (final mine in answers.where((a) => a.userId == me)) {
      final theirs = answerOn(p, mine.day);
      if (theirs == null) continue;
      final at = mine.createdAt.isAfter(theirs.createdAt) ? mine.createdAt : theirs.createdAt;
      out.add((mine.day, at, mine, theirs));
    }
    return out..sort((x, y) => y.$2.compareTo(x.$2));
  }

  Future<void> submitAnswer(String text) async {
    final q = answerOn(me, today)?.question ?? questionToday(me);
    await backend.submitAnswer(householdId: household!.id, day: today, questionId: q.id, text: text);
    await refresh();
  }

  /// Fake checkout: unlocks immediately.
  Future<void> unlockPack(QuestionPack pack) async {
    await backend.unlockPacks(household!.id, {...household!.unlockedPacks, pack});
    await refresh();
  }

  // ------------------------------------------------------------ stars

  StarsCalculator get stars => StarsCalculator(
        household: household!,
        calendar: engine.calendar,
        logs: logs,
        metrics: metrics,
        snaps: snaps,
        now: now,
      );

  /// Newest first: today, yesterday, …
  List<DayStars> get recentStars {
    final c = stars;
    return [for (var i = 0; i < starDays; i++) c.day(addDays(today, -i))];
  }

  DateTime? _lastHealthSync;

  /// Background work after each load: Health and Snap reminders.
  void _afterLoad() {
    () async {
      try {
        await syncHealth();
      } on BackendException catch (e) {
        debugPrint('Health sync: ${e.message}');
      }
      try {
        await syncClimbs();
      } on BackendException catch (e) {
        debugPrint('Climb sync: ${e.message}');
      }
    }();
    snapPrompts
        .schedule(
          householdId: household!.id,
          calendar: engine.calendar,
          now: now,
          snappedToday: stars.snapOf(me, today) != null,
        )
        .ignore();
  }

  /// Reads my Apple Health numbers and saves the ones that changed. At most
  /// every 10 minutes unless [force]d: every save makes my partner's phone
  /// reload too.
  Future<void> syncHealth({bool force = false}) async {
    if (!health.connected || household == null) return;
    final last = _lastHealthSync;
    if (!force && last != null && DateTime.now().difference(last) < const Duration(minutes: 10)) return;
    _lastHealthSync = DateTime.now();
    final h = household!;
    final mine = await health.read(me, engine.calendar, today);
    final changed = [
      for (final m in mine)
        if (!metrics.any((x) => x.userId == me && x.day == m.day && x.sameValues(m)) &&
            (m.steps != null || m.sleepMinutes != null))
          m,
    ];
    if (changed.isEmpty) return;
    await backend.saveMetrics(h.id, changed);
    metrics = [
      for (final x in metrics) if (!(x.userId == me && changed.any((m) => m.day == x.day))) x,
      ...changed,
    ];
    notifyListeners();
  }

  Future<bool> connectHealth() async {
    final ok = await health.connect();
    await syncHealth(force: true);
    notifyListeners();
    return ok;
  }

  Future<void> disconnectHealth() async {
    await health.disconnect();
    notifyListeners();
  }

  // Snap moments

  DateTime get snapPromptToday => stars.snapPromptAt(today);
  String get snapPromptTextToday => snapPromptText(household!.id, dateKey(today));
  bool get snapOpen => !now.isBefore(snapPromptToday);

  final Map<String, Future<Uint8List?>> _snapPhotos = {};
  Future<Uint8List?> snapPhoto(Snap s) => _snapPhotos.putIfAbsent(s.id, () => backend.snapPhoto(s));

  Future<void> takeSnap(Uint8List jpeg) async {
    await backend.uploadSnap(household!.id, today, jpeg);
    await refresh();
  }

  Future<void> setSnapPrompts(bool on) async {
    await snapPrompts.setEnabled(on);
    _afterLoad();
    notifyListeners();
  }

  // ------------------------------------------------------- castle climb

  String get teamName => [for (final m in household!.members) m.displayName].join(' & ');

  /// Posts my team's stars to every climb still before its reveal. Only
  /// changed rows are sent.
  Future<void> syncClimbs() async {
    final h = household;
    if (h == null) return;
    final calc = stars;
    var changed = false;
    for (final c in challenges) {
      final phase = c.phase(today, now);
      if (phase != ClimbPhase.climbing && phase != ClimbPhase.summitWait) continue;
      final saved = {for (final s in c.scores) if (s.coupleId == h.id) s.key: s.stars};
      final rows = [
        for (final r in c.scoresFrom(calc, h.id, today))
          if (saved[r.key] != r.stars) r,
      ];
      if (rows.isEmpty) continue;
      try {
        await backend.saveClimbScores(c.id, h.id, rows);
        changed = true;
      } on BackendException catch (e) {
        debugPrint('Climb scores: ${e.message}');
      }
    }
    if (changed && household?.id == h.id) {
      challenges = await backend.loadChallenges(h.id);
      notifyListeners();
    }
  }

  Future<Challenge> createClimb({
    required List<StarActivity> activities,
    required int days,
    required String? stakes,
    required String banner,
  }) async {
    final (startsOn, revealAt) = climbSchedule(engine.calendar, now, days);
    final c = await backend.createChallenge(
      householdId: household!.id,
      activities: activities,
      days: days,
      startsOn: startsOn,
      revealAt: revealAt,
      stakes: stakes,
      teamName: teamName,
      banner: banner,
    );
    await refresh();
    return c;
  }

  Future<ClimbPreview?> previewClimb(String code) => backend.previewChallenge(code);

  bool _handlingInvite = false;

  /// Uses a waiting invite as soon as it can:
  /// - a partner's household link joins that household right away;
  /// - a climb link waits until I have a household, then joins the climb
  ///   (my partner is in it too: the team is the household).
  Future<void> handleInvite() async {
    final invite = invites.pending;
    if (invite == null || _handlingInvite) return;
    if (status != AppStatus.needsHousehold && status != AppStatus.ready) return;
    _handlingInvite = true;
    try {
      if (invite.kind == InviteKind.household) {
        if (status == AppStatus.needsHousehold) {
          await backend.joinHousehold(invite.code);
          invites.clear();
          await refresh();
          inviteOutcome.value = InviteOutcome(message: '💞 You\'re in! Welcome to $teamName\'s household.');
        } else {
          invites.clear();
          if (household!.inviteCode != invite.code) {
            inviteOutcome.value = const InviteOutcome(
              message: 'You\'re already in a household. Leave it in Settings to join another.',
              error: true,
            );
          }
        }
        return;
      }
      if (status != AppStatus.ready) return; // after household setup
      final preview = await backend.previewChallenge(invite.code);
      if (preview == null) {
        invites.clear();
        inviteOutcome.value = const InviteOutcome(message: 'That climb link doesn\'t work anymore.', error: true);
        return;
      }
      if (!preview.alreadyIn) {
        await backend.joinChallenge(
          code: invite.code,
          teamName: teamName,
          banner: climbBanners[math.Random().nextInt(climbBanners.length)],
        );
      }
      invites.clear();
      await refresh();
      inviteOutcome.value = InviteOutcome(
        climbId: preview.id,
        askPartner: !preview.alreadyIn && !(household?.isComplete ?? true),
      );
    } on BackendException catch (e) {
      invites.clear();
      inviteOutcome.value = InviteOutcome(message: e.message, error: true);
    } finally {
      _handlingInvite = false;
    }
  }

  Future<void> joinClimb(String code, String banner) async {
    await backend.joinChallenge(code: code, teamName: teamName, banner: banner);
    await refresh();
  }

  List<TaskDef> get visibleTasks =>
      visibleCatalog(hasKids: household!.hasKids, hasPets: household!.hasPets, custom: customTasks);

  /// Adds a household task. Names must be new, ignoring case.
  Future<TaskDef> addCustomTask(String name, TaskCategory category, int points) async {
    final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (visibleTasks.any((t) => t.name.toLowerCase() == clean.toLowerCase())) {
      throw BackendException('"$clean" is already on the list.');
    }
    final t = await backend.createCustomTask(
        householdId: household!.id, name: clean, category: category, points: points);
    customTasks = [...customTasks, t];
    setCustomTasks(customTasks);
    notifyListeners();
    return t;
  }

  Future<void> deleteCustomTask(TaskDef task) async {
    await backend.deleteCustomTask(task.id);
    await refresh();
  }

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

  Future<void> signInWithGoogle() => backend.signInWithGoogle();

  Future<bool> signUp(String email, String password, String name) =>
      backend.signUp(email: email, password: password, displayName: name);

  Future<void> signOut() async {
    await push.detach();
    await backend.signOut();
  }

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

/// The result of using an invite link.
class InviteOutcome {
  const InviteOutcome({this.climbId, this.askPartner = false, this.message, this.error = false});

  /// A climb I just joined (or was already in): open it.
  final String? climbId;

  /// My partner isn't in the household yet: ask me to invite them.
  final bool askPartner;
  final String? message;
  final bool error;
}
