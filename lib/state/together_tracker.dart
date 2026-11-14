import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../data/backend.dart';

/// Reports this phone's position once a minute while an Out together
/// session runs, including with the screen locked (iOS shows the blue
/// location pill meanwhile). Positions are only sent during sessions.
class TogetherTracker {
  TogetherTracker(this._backend);

  final Backend _backend;
  StreamSubscription<Position>? _sub;
  Timer? _timer;
  Position? _last;

  /// The session this phone is reporting for, if any.
  String? sessionId;

  /// Called when tracking stops because the session ended elsewhere.
  VoidCallback? onStopped;

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static const interval = Duration(minutes: 1);

  /// Asks for location access if needed. Returns a message when it can't
  /// be used, or null when it's fine.
  static Future<String?> ensurePermission() async {
    if (!supported) return 'Out together works in the iPhone app.';
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Location Services are off. Turn them on in iPhone Settings → Privacy.';
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
      return 'Location is blocked. Allow it in iPhone Settings → Power Couple → Location.';
    }
    return null;
  }

  /// Where this phone is now, for setting the home location.
  static Future<Position> here() => Geolocator.getCurrentPosition(
        locationSettings: AppleSettings(accuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 20)),
      );

  Future<void> start(String id) async {
    if (!supported || sessionId == id) return;
    await stop();
    sessionId = id;
    _sub = Geolocator.getPositionStream(
      locationSettings: AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      ),
    ).listen((p) {
      final first = _last == null;
      _last = p;
      if (first) _send();
    }, onError: (Object e) => debugPrint('Together location: $e'));
    // A ping every minute, even standing still at the table.
    _timer = Timer.periodic(interval, (_) => _send());
  }

  Future<void> _send() async {
    final id = sessionId, p = _last;
    if (id == null || p == null) return;
    try {
      final running = await _backend.addPing(id, p.latitude, p.longitude);
      if (!running && sessionId == id) {
        await stop();
        onStopped?.call();
      }
    } on BackendException catch (e) {
      debugPrint('Together ping: $e'); // offline: try again next minute
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _sub?.cancel();
    _sub = null;
    _last = null;
    sessionId = null;
  }
}
