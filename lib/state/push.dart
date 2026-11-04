import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/backend.dart';

// Firebase client config for the iOS app (public identifiers, not secrets).
// Pass with --dart-define-from-file=config/firebase.json. Without them push
// notifications are simply unavailable.
const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
const _appId = String.fromEnvironment('FIREBASE_APP_ID');
const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

bool _firebaseReady = false;

/// Starts Firebase if this build has push configured. Call once before runApp.
Future<void> initPush() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS || _apiKey.isEmpty) return;
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: _apiKey,
        appId: _appId,
        messagingSenderId: _senderId,
        projectId: _projectId,
        iosBundleId: 'org.powercouple.powerCouple',
      ),
    );
    // Show notifications even while the app is open.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    _firebaseReady = true;
  } catch (e) {
    debugPrint('Push unavailable: $e');
  }
}

/// Bond push notifications on this phone: turning them on or off, keeping
/// the phone's token registered to the signed-in account, and opening the
/// Bond tab when a notification is tapped.
class PushNotifications extends ChangeNotifier {
  PushNotifications(this._backend, this._prefs);

  final Backend _backend;
  final SharedPreferences? _prefs;

  static const _enabledKey = 'push_enabled';
  static const _askedKey = 'push_asked';

  /// Whether this build and platform can receive push notifications.
  bool get supported => _firebaseReady && !_backend.isDemo;

  /// Whether notifications are on for this phone (as chosen in the app).
  bool get enabled => supported && (_prefs?.getBool(_enabledKey) ?? false);

  /// Whether we've already offered notifications after a first answer.
  bool get asked => _prefs?.getBool(_askedKey) ?? false;
  void markAsked() => _prefs?.setBool(_askedKey, true);

  /// Bumped when a notification is tapped; the shell switches to Bond.
  final ValueNotifier<int> openBond = ValueNotifier(0);

  StreamSubscription<String>? _refreshSub;
  bool _listening = false;
  String? _registeredFor;

  /// Called when someone is signed in with a household: re-registers this
  /// phone if notifications are on, and starts listening for taps.
  Future<void> attach(String userId) async {
    if (!supported) return;
    if (!_listening) {
      _listening = true;
      FirebaseMessaging.onMessageOpenedApp.listen(_onTap);
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _onTap(initial);
    }
    if (enabled && _registeredFor != userId) {
      try {
        await _register();
        _registeredFor = userId;
      } catch (e) {
        debugPrint('Push register failed: $e');
      }
    }
  }

  void _onTap(RemoteMessage m) {
    if (m.data['tab'] == 'bond') openBond.value++;
  }

  /// Asks iOS for permission and registers this phone. Returns false when
  /// the user has notifications blocked for the app in iPhone Settings.
  Future<bool> enable() async {
    if (!supported) return false;
    final settings = await FirebaseMessaging.instance.requestPermission();
    final ok = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!ok) return false;
    await _register();
    await _prefs?.setBool(_enabledKey, true);
    _registeredFor = _backend.currentUserId;
    notifyListeners();
    return true;
  }

  Future<void> disable() async {
    await _prefs?.setBool(_enabledKey, false);
    notifyListeners();
    await _forget();
  }

  /// Before signing out: this phone shouldn't keep getting the old account's
  /// notifications. The on/off choice stays for the next account.
  Future<void> detach() async {
    if (enabled) await _forget();
    _registeredFor = null;
  }

  Future<void> _register() async {
    final messaging = FirebaseMessaging.instance;
    // On iOS the FCM token needs the APNs token, which can take a moment.
    for (var i = 0; i < 10 && await messaging.getAPNSToken() == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    // The classic FCM token, which the server's v1 send API targets. Newer
    // releases prefer installation IDs; switch when the server does.
    // ignore: deprecated_member_use
    final token = await messaging.getToken();
    if (token == null) throw StateError('No push token');
    await _backend.registerDevice(token);
    // ignore: deprecated_member_use
    _refreshSub ??= messaging.onTokenRefresh.listen((t) {
      if (enabled) _backend.registerDevice(t).ignore();
    });
  }

  Future<void> _forget() async {
    try {
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _backend.unregisterDevice(token);
    } catch (e) {
      debugPrint('Push unregister failed: $e');
    }
  }
}
