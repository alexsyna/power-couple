import 'dart:typed_data';

import '../domain/activity.dart';
import '../domain/catalog.dart';
import '../domain/missions.dart';
import '../domain/models.dart';
import '../domain/questions.dart';

/// Everything the app needs from storage and auth. The Supabase implementation
/// is the real one; [DemoBackend] runs fully on-device for previews.
abstract class Backend {
  bool get isDemo;

  /// Signed-in user id, or null.
  String? get currentUserId;

  /// Emits whenever sign-in state changes.
  Stream<void> get authChanges;

  Future<void> signIn({required String email, required String password});

  /// Returns true when the account still needs email confirmation.
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  /// Starts Google sign-in (creates the account on first use). Completes
  /// once the browser has opened; the session arrives via [authChanges].
  Future<void> signInWithGoogle();

  Future<void> signOut();

  /// The signed-in user's household, or null if they have not joined one.
  Future<Household?> loadHousehold();

  Future<Household> createHousehold({
    required String timezone,
    required bool hasKids,
    required bool hasPets,
  });

  Future<Household> joinHousehold(String inviteCode);

  Future<void> leaveHousehold();

  /// Updates the signed-in user's name and/or avatar choice.
  Future<void> updateProfile({String? displayName, AvatarKind? avatarKind});

  /// Stores a new profile photo (JPEG) and switches the avatar to it.
  Future<void> uploadAvatarPhoto(Uint8List jpeg);

  Future<void> updateHousehold(
    String householdId, {
    String? timezone,
    bool? hasKids,
    bool? hasPets,
  });

  Future<List<TaskLog>> loadLogs(String householdId);

  Future<TaskLog> insertLog({
    required String householdId,
    required String taskId,
    required DateTime doneAt,
    String? customName,
    String? sharedWith,
  });

  Future<void> undoLog(String logId);

  /// Who answered Bond questions on which day, for the whole household.
  Future<List<AnswerMeta>> loadAnswerLog(String householdId);

  /// Answers I can read: mine, and my partner's on days I answered too.
  Future<List<Answer>> loadAnswers(String householdId);

  Future<void> submitAnswer({
    required String householdId,
    required DateTime day,
    required String questionId,
    required String text,
  });

  /// Fake purchase for now: unlocks the packs for the whole household.
  Future<void> unlockPacks(String householdId, Set<QuestionPack> packs);

  /// Push notifications: this phone's token for the signed-in user.
  Future<void> registerDevice(String token);
  Future<void> unregisterDevice(String token);

  Future<List<Mission>> loadMissions(String householdId);

  Future<Mission> createMission({
    required String householdId,
    required String title,
    required DateTime dueOn,
    String? assignee,
  });

  /// Saves title, due date, assignee and completion state.
  Future<void> updateMission(Mission mission);

  Future<void> deleteMission(String missionId);

  /// The household's own tasks, deleted ones included (old logs need them).
  Future<List<TaskDef>> loadCustomTasks(String householdId);

  Future<TaskDef> createCustomTask({
    required String householdId,
    required String name,
    required TaskCategory category,
    required int points,
  });

  /// Hides the task from the list; logs already made keep their points.
  Future<void> deleteCustomTask(String taskId);

  // ------------------------------------------------------- daily stars

  /// Saves where the couple lives (time near home isn't "out together").
  Future<void> setHome(String householdId, double lat, double lng);

  /// Both partners' Apple Health numbers from [since] (a local date).
  Future<List<DailyMetrics>> loadMetrics(String householdId, DateTime since);

  /// Saves my Apple Health numbers.
  Future<void> saveMetrics(String householdId, List<DailyMetrics> mine);

  Future<List<Snap>> loadSnaps(String householdId, DateTime since);

  /// Uploads my photo for [day]'s Snap moment. One per person per day.
  Future<Snap> uploadSnap(String householdId, DateTime day, Uint8List jpeg);

  /// The photo's bytes, or null if it has none (demo data).
  Future<Uint8List?> snapPhoto(Snap snap);

  /// Sessions started from [since], each with its pings.
  Future<List<TogetherSession>> loadTogether(String householdId, DateTime since);

  Future<TogetherSession> startTogether(String householdId);
  Future<void> joinTogether(String sessionId);
  Future<void> endTogether(String sessionId);

  /// Records where my phone is during a session. Returns false once the
  /// session has ended (so the phone can stop tracking).
  Future<bool> addPing(String sessionId, double lat, double lng);

  /// Emits when the household's members, settings or logs change elsewhere
  /// (e.g. on the partner's phone).
  Stream<void> householdChanges(String householdId);
}

class BackendException implements Exception {
  BackendException(this.message);
  final String message;
  @override
  String toString() => message;
}
