/// Measured activity beyond chores: Apple Health numbers and Snap moments.
/// Stars are derived from these in stars.dart.
library;

/// One person's Apple Health numbers for one household-local day.
class DailyMetrics {
  const DailyMetrics({required this.userId, required this.day, this.steps, this.sleepMinutes, this.bedAt});

  final String userId;

  /// Household-local date (UTC midnight).
  final DateTime day;

  /// Null when there's no data (Health not connected, or nothing recorded).
  final int? steps;

  /// Sleep for the night that ended on the morning of [day].
  final int? sleepMinutes;

  /// When that night's main sleep started (estimated from Apple Health).
  final DateTime? bedAt;

  bool sameValues(DailyMetrics o) => steps == o.steps && sleepMinutes == o.sleepMinutes && bedAt == o.bedAt;
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
