/// Measured activity beyond chores: Apple Health numbers, Snap moments and
/// Out together sessions. Stars are derived from these in stars.dart.
library;

import 'dart:math' as math;

/// One person's Apple Health numbers for one household-local day.
class DailyMetrics {
  const DailyMetrics({required this.userId, required this.day, this.steps, this.sleepMinutes});

  final String userId;

  /// Household-local date (UTC midnight).
  final DateTime day;

  /// Null when there's no data (Health not connected, or nothing recorded).
  final int? steps;

  /// Sleep for the night that ended on the morning of [day].
  final int? sleepMinutes;

  bool sameValues(DailyMetrics o) => steps == o.steps && sleepMinutes == o.sleepMinutes;
}

/// A photo taken in answer to the day's Snap moment prompt.
class Snap {
  const Snap({
    required this.id,
    required this.userId,
    required this.day,
    required this.takenAt,
    this.path,
  });

  final String id;
  final String userId;
  final DateTime day;

  /// Server time of the upload, so a phone clock can't fake speed.
  final DateTime takenAt;

  /// Storage path of the photo; null for demo data without a picture.
  final String? path;
}

/// A position reported by one phone during an Out together session.
class TogetherPing {
  const TogetherPing({required this.userId, required this.at, required this.lat, required this.lng});

  final String userId;
  final DateTime at;
  final double lat;
  final double lng;
}

/// "We're out together": one partner starts it, the other joins, and both
/// phones report where they are until it ends.
class TogetherSession {
  const TogetherSession({
    required this.id,
    required this.startedBy,
    required this.startedAt,
    this.joinedBy,
    this.joinedAt,
    this.endedAt,
    this.pings = const [],
  });

  final String id;
  final String startedBy;
  final DateTime startedAt;
  final String? joinedBy;
  final DateTime? joinedAt;
  final DateTime? endedAt;
  final List<TogetherPing> pings;

  /// Sessions stop on their own after this long.
  static const maxLength = Duration(hours: 6);

  bool get bothJoined => joinedBy != null;

  bool isActive(DateTime now) => endedAt == null && now.isBefore(startedAt.add(maxLength));

  DateTime endOr(DateTime now) {
    final cap = startedAt.add(maxLength);
    final end = endedAt ?? (now.isBefore(cap) ? now : cap);
    return end;
  }

  TogetherSession withPings(List<TogetherPing> p) => TogetherSession(
        id: id,
        startedBy: startedBy,
        startedAt: startedAt,
        joinedBy: joinedBy,
        joinedAt: joinedAt,
        endedAt: endedAt,
        pings: p,
      );

  /// Minutes both phones were within [togetherMeters] of each other and,
  /// when the household set a home, away from it.
  int togetherMinutes(DateTime now, {double? homeLat, double? homeLng}) {
    if (joinedBy == null || pings.isEmpty) return 0;
    final users = {for (final p in pings) p.userId};
    if (users.length < 2) return 0;
    final (a, b) = (users.first, users.elementAt(1));
    final byUser = {
      for (final u in [a, b]) u: (pings.where((p) => p.userId == u).toList()..sort((x, y) => x.at.compareTo(y.at))),
    };
    TogetherPing? near(String user, DateTime t) {
      TogetherPing? best;
      var bestGap = pingTolerance;
      for (final p in byUser[user]!) {
        final gap = p.at.difference(t).abs();
        if (gap <= bestGap) {
          best = p;
          bestGap = gap;
        }
      }
      return best;
    }

    bool atHome(TogetherPing p) =>
        homeLat != null && homeLng != null && distanceMeters(p.lat, p.lng, homeLat, homeLng) < homeRadiusMeters;

    var minutes = 0;
    final end = endOr(now);
    for (var t = joinedAt ?? startedAt; t.isBefore(end); t = t.add(const Duration(minutes: 1))) {
      final pa = near(a, t), pb = near(b, t);
      if (pa == null || pb == null) continue;
      if (distanceMeters(pa.lat, pa.lng, pb.lat, pb.lng) > togetherMeters) continue;
      if (atHome(pa) || atHome(pb)) continue;
      minutes++;
    }
    return minutes;
  }

  /// Phones closer than this count as together (GPS is rough indoors).
  static const togetherMeters = 100.0;

  /// Time near home doesn't count: sessions are for going out.
  static const homeRadiusMeters = 150.0;

  /// A ping stands for the minutes around it, so a phone that sends one a
  /// minute (or skips one) still counts.
  static const pingTolerance = Duration(minutes: 3);
}

/// Great-circle distance in metres.
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}

// ------------------------------------------------------------ snap prompts

/// Prompts land between these local hours.
const snapWindowStartHour = 10;
const snapWindowEndHour = 20;

const snapPrompts = [
  'Show us your view right now 👀',
  'What are your hands up to? ✋',
  'Something that made you smile today 😊',
  'Your outfit of the day 👕',
  'The last thing you ate or drank 🍽️',
  'Something blue 💙',
  'Your favourite spot right now 📍',
  'A selfie with your current mood 🤪',
  'Something that reminds you of your partner 💞',
  'Look up! What do you see? ☁️',
  'Your shoes right now 👟',
  'Something that needs fixing at home 🔧',
  'The best thing within arm\'s reach 🤲',
  'Show us your coffee or tea ☕',
];

int _hash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0x7fffffff;
  }
  return h;
}

/// Minutes after midnight (local) of a household's Snap prompt on a day.
/// Both phones compute the same time, so no server is needed to send it.
int snapPromptMinute(String householdId, String dayKey) {
  const window = (snapWindowEndHour - snapWindowStartHour) * 60;
  return snapWindowStartHour * 60 + _hash('snap#$householdId#$dayKey') % window;
}

String snapPromptText(String householdId, String dayKey) =>
    snapPrompts[_hash('prompt#$householdId#$dayKey') % snapPrompts.length];
