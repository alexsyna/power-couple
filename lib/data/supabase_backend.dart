import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/missions.dart';
import '../domain/models.dart';
import '../domain/questions.dart';
import 'backend.dart';

class SupabaseBackend implements Backend {
  SupabaseBackend(this._client);

  final SupabaseClient _client;

  @override
  bool get isDemo => false;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Stream<void> get authChanges => _client.auth.onAuthStateChange.map((_) {});

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(() async {
        await _client.auth.signInWithPassword(email: email, password: password);
        await _ensureProfile();
      });

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) =>
      _guard(() async {
        final res = await _client.auth.signUp(
          email: email,
          password: password,
          data: {'display_name': displayName},
        );
        if (res.session == null) return true;
        await _ensureProfile();
        return false;
      });

  /// Where Google sends the user back: this page on web, the app's URL
  /// scheme on phones (registered in Info.plist / AndroidManifest.xml).
  static const _appCallback = 'org.powercouple.powercouple://login-callback';

  @override
  Future<void> signInWithGoogle() => _guard(() async {
        final redirect = kIsWeb ? '${Uri.base.origin}${Uri.base.path}' : _appCallback;
        await _client.auth.signInWithOAuth(OAuthProvider.google, redirectTo: redirect);
      });

  /// Profiles are created on first sign-in: from the name given at sign-up,
  /// or the Google account's name. With email confirmation or Google there
  /// is no session at sign-up time, so loadHousehold() also calls this.
  Future<void> _ensureProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final meta = user.userMetadata ?? const {};
    final name = ((meta['display_name'] ?? meta['full_name'] ?? meta['name']) as String?)?.trim();
    await _client.from('profiles').upsert(
      {'id': user.id, 'display_name': (name == null || name.isEmpty) ? 'Hero' : name},
      onConflict: 'id',
      ignoreDuplicates: true,
    );
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<Household?> loadHousehold() => _guard(() async {
        final uid = currentUserId;
        if (uid == null) return null;
        await _ensureProfile();
        final mine = await _client
            .from('couple_members')
            .select('couple_id')
            .eq('user_id', uid)
            .maybeSingle();
        if (mine == null) return null;
        return _fetchHousehold(mine['couple_id'] as String);
      });

  Future<Household> _fetchHousehold(String id) async {
    final couple = await _client.from('couples').select().eq('id', id).single();
    final memberRows = await _client
        .from('couple_members')
        .select('user_id, joined_at')
        .eq('couple_id', id)
        .order('joined_at');
    final ids = [for (final r in memberRows) r['user_id'] as String];
    final profiles = ids.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _client.from('profiles').select('id, display_name, avatar_kind, avatar_path').inFilter('id', ids);
    final byId = {for (final p in profiles) p['id'] as String: p};
    // Photos are private; hand the UI a signed URL valid for a week.
    final photos = <String, String>{};
    for (final p in profiles) {
      final path = p['avatar_path'] as String?;
      if (p['avatar_kind'] == 'photo' && path != null) {
        try {
          photos[p['id'] as String] =
              await _client.storage.from('avatars').createSignedUrl(path, 60 * 60 * 24 * 7);
        } on StorageException {
          // Missing file: fall back to the initial.
        }
      }
    }
    Member member(String uid) {
      final p = byId[uid];
      final photo = photos[uid];
      final kind = AvatarKind.parse(p?['avatar_kind'] as String?);
      return Member(
        userId: uid,
        displayName: p?['display_name'] as String? ?? 'Partner',
        avatarKind: kind == AvatarKind.photo && photo == null ? AvatarKind.initial : kind,
        photoUrl: photo,
      );
    }
    return Household(
      id: id,
      timezone: couple['timezone'] as String,
      hasKids: couple['has_kids'] as bool,
      hasPets: couple['has_pets'] as bool,
      inviteCode: couple['invite_code'] as String,
      createdAt: DateTime.parse(couple['created_at'] as String),
      members: [
        for (final uid in ids) member(uid),
      ],
      unlockedPacks: {
        QuestionPack.light,
        for (final p in (couple['unlocked_packs'] as List?) ?? const []) ?QuestionPack.parse(p as String),
      },
    );
  }

  @override
  Future<Household> createHousehold({
    required String timezone,
    required bool hasKids,
    required bool hasPets,
  }) =>
      _guard(() async {
        final row = await _client.rpc('create_couple',
            params: {'tz': timezone, 'kids': hasKids, 'pets': hasPets});
        return _fetchHousehold(row['id'] as String);
      });

  @override
  Future<Household> joinHousehold(String inviteCode) => _guard(() async {
        final row = await _client.rpc('join_couple', params: {'code': inviteCode});
        return _fetchHousehold(row['id'] as String);
      });

  @override
  Future<void> leaveHousehold() => _guard(() => _client.rpc('leave_couple'));

  @override
  Future<void> updateProfile({String? displayName, AvatarKind? avatarKind}) => _guard(() async {
        await _client.from('profiles').update({
          'display_name': ?displayName,
          'avatar_kind': ?avatarKind?.name,
        }).eq('id', currentUserId!);
      });

  @override
  Future<void> uploadAvatarPhoto(Uint8List jpeg) => _guard(() async {
        final uid = currentUserId!;
        final old = await _client.from('profiles').select('avatar_path').eq('id', uid).maybeSingle();
        // New file name each time so cached images never show a stale photo.
        final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _client.storage
            .from('avatars')
            .uploadBinary(path, jpeg, fileOptions: const FileOptions(contentType: 'image/jpeg'));
        await _client.from('profiles').update({'avatar_kind': 'photo', 'avatar_path': path}).eq('id', uid);
        final oldPath = old?['avatar_path'] as String?;
        if (oldPath != null && oldPath != path) {
          try {
            await _client.storage.from('avatars').remove([oldPath]);
          } on StorageException {
            // Best effort cleanup.
          }
        }
      });

  @override
  Future<void> updateHousehold(
    String householdId, {
    String? timezone,
    bool? hasKids,
    bool? hasPets,
  }) =>
      _guard(() => _client.from('couples').update({
            'timezone': ?timezone,
            'has_kids': ?hasKids,
            'has_pets': ?hasPets,
          }).eq('id', householdId));

  @override
  Future<List<TaskLog>> loadLogs(String householdId) => _guard(() async {
        final rows = await _client
            .from('task_logs')
            .select()
            .eq('couple_id', householdId)
            .order('done_at', ascending: false);
        return [for (final r in rows) _logFromRow(r)];
      });

  @override
  Future<TaskLog> insertLog({
    required String householdId,
    required String taskId,
    required DateTime doneAt,
    String? customName,
    String? sharedWith,
  }) =>
      _guard(() async {
        final row = await _client
            .from('task_logs')
            .insert({
              'couple_id': householdId,
              'task_id': taskId,
              'custom_name': customName,
              'logged_by': currentUserId,
              'shared_with': sharedWith,
              'done_at': doneAt.toUtc().toIso8601String(),
            })
            .select()
            .single();
        return _logFromRow(row);
      });

  @override
  Future<void> undoLog(String logId) =>
      _guard(() => _client.rpc('undo_log', params: {'log_id': logId}));

  @override
  Future<List<AnswerMeta>> loadAnswerLog(String householdId) => _guard(() async {
        final rows = await _client.rpc('answer_log') as List;
        return [
          for (final r in rows)
            AnswerMeta(
              userId: r['user_id'] as String,
              day: parseDateKey(r['day'] as String),
              createdAt: DateTime.parse(r['created_at'] as String),
            ),
        ];
      });

  @override
  Future<List<Answer>> loadAnswers(String householdId) => _guard(() async {
        final rows = await _client.from('question_answers').select().eq('couple_id', householdId);
        return [
          for (final r in rows)
            Answer(
              userId: r['user_id'] as String,
              day: parseDateKey(r['day'] as String),
              questionId: r['question_id'] as String,
              text: r['answer'] as String,
              createdAt: DateTime.parse(r['created_at'] as String),
            ),
        ];
      });

  @override
  Future<void> submitAnswer({
    required String householdId,
    required DateTime day,
    required String questionId,
    required String text,
  }) =>
      _guard(() => _client.from('question_answers').insert({
            'couple_id': householdId,
            'day': dateKey(day),
            'question_id': questionId,
            'answer': text,
          }));

  @override
  Future<void> unlockPacks(String householdId, Set<QuestionPack> packs) =>
      _guard(() => _client.from('couples').update({
            'unlocked_packs': [for (final p in packs) p.name],
          }).eq('id', householdId));

  @override
  Future<List<Mission>> loadMissions(String householdId) => _guard(() async {
        final rows = await _client
            .from('missions')
            .select()
            .eq('couple_id', householdId)
            .isFilter('deleted_at', null)
            .order('due_on');
        return [for (final r in rows) _missionFromRow(r)];
      });

  @override
  Future<Mission> createMission({
    required String householdId,
    required String title,
    required DateTime dueOn,
    String? assignee,
  }) =>
      _guard(() async {
        final row = await _client
            .from('missions')
            .insert({
              'couple_id': householdId,
              'title': title,
              'due_on': dateKey(dueOn),
              'created_by': currentUserId,
              'assignee': assignee,
            })
            .select()
            .single();
        return _missionFromRow(row);
      });

  @override
  Future<void> updateMission(Mission m) => _guard(() => _client.from('missions').update({
        'title': m.title,
        'due_on': dateKey(m.dueOn),
        'assignee': m.assignee,
        'completed_at': m.completedAt?.toUtc().toIso8601String(),
        'completed_by': m.completedBy,
      }).eq('id', m.id));

  @override
  Future<void> deleteMission(String missionId) => _guard(() => _client.from('missions').update({
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'deleted_by': currentUserId,
      }).eq('id', missionId));

  static Mission _missionFromRow(Map<String, dynamic> r) {
    DateTime? at(String k) => r[k] == null ? null : DateTime.parse(r[k] as String);
    return Mission(
      id: r['id'] as String,
      title: r['title'] as String,
      dueOn: parseDateKey(r['due_on'] as String),
      createdAt: DateTime.parse(r['created_at'] as String),
      createdBy: r['created_by'] as String?,
      assignee: r['assignee'] as String?,
      completedAt: at('completed_at'),
      completedBy: r['completed_by'] as String?,
      deletedAt: at('deleted_at'),
      deletedBy: r['deleted_by'] as String?,
    );
  }

  @override
  Stream<void> householdChanges(String householdId) {
    late final RealtimeChannel channel;
    final controller = StreamController<void>(
      onCancel: () => _client.removeChannel(channel),
    );
    void ping(PostgresChangePayload _) => controller.add(null);
    PostgresChangeFilter filter(String column) => PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: column,
          value: householdId,
        );
    channel = _client
        .channel('household:$householdId')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'task_logs',
            filter: filter('couple_id'),
            callback: ping)
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'couple_members',
            filter: filter('couple_id'),
            callback: ping)
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'missions',
            filter: filter('couple_id'),
            callback: ping)
        .onPostgresChanges(
            // Row-level security limits this to me and my partner.
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'profiles',
            callback: ping)
        .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'couples',
            filter: filter('id'),
            callback: ping)
        // Every (re)join can follow a gap where events were missed (dropped
        // socket, backgrounded app), so ask the app to catch up from the DB.
        .subscribe((status, _) {
          if (status != RealtimeSubscribeStatus.closed && !controller.isClosed) {
            controller.add(null);
          }
        });
    return controller.stream;
  }

  static TaskLog _logFromRow(Map<String, dynamic> r) => TaskLog(
        id: r['id'] as String,
        taskId: r['task_id'] as String,
        customName: r['custom_name'] as String?,
        loggedBy: r['logged_by'] as String?,
        sharedWith: r['shared_with'] as String?,
        doneAt: DateTime.parse(r['done_at'] as String),
        createdAt: DateTime.parse(r['created_at'] as String),
        undoneAt: r['undone_at'] == null ? null : DateTime.parse(r['undone_at'] as String),
        undoneBy: r['undone_by'] as String?,
      );

  /// Turns Supabase errors into short messages the UI can show.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AuthException catch (e) {
      throw BackendException(e.message);
    } on PostgrestException catch (e) {
      throw BackendException(_friendly(e.message));
    } on StorageException catch (e) {
      throw BackendException('Photo upload failed: ${e.message}');
    }
  }

  static String _friendly(String message) {
    if (message.contains('question_answers_user_id_day_key')) return 'You already answered today';
    for (final known in [
      'invite code not found',
      'household is full',
      'already in a household',
      'cannot delete this log',
    ]) {
      if (message.contains(known)) {
        return known[0].toUpperCase() + known.substring(1);
      }
    }
    return message;
  }
}
