import 'dart:typed_data';

import '../domain/missions.dart';
import '../domain/models.dart';

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
