/// Castle Climb: 2 to 6 couples ("rope teams") race up a mountain to a
/// castle over 3, 7, 14 or 30 days. Each day, each chosen activity gives a
/// team 0-3 stars (see stars.dart); the last day counts double ("Final
/// ascent"). Other teams stay hidden in the fog until the reveal.
library;

import 'calendar.dart';
import 'stars.dart';

const climbDurations = [3, 7, 14, 30];
const minTeams = 2;
const maxTeams = 6;

/// Banners a rope team can carry.
const climbBanners = ['🦊', '🐻', '🦁', '🐼', '🐸', '🐙', '🦄', '🐝', '🐧', '🐯', '🦉', '🐲'];

const stakePresets = [
  'Last place buys the first round 🍻',
  'Winners pick the restaurant 🍝',
  'Last place cooks dinner 🍲',
];

enum ClimbPhase {
  /// Joining is open; day 1 hasn't started.
  upcoming,

  /// Somewhere between day 1 and the last day.
  climbing,

  /// The last day is over; waiting for late sleep and steps before the fog lifts.
  summitWait,

  /// Everyone's stars are visible.
  revealed,
}

class ClimbTeam {
  const ClimbTeam({
    required this.coupleId,
    required this.name,
    required this.banner,
    required this.joinedAt,
    this.lastClimbAt,
  });

  final String coupleId;

  /// "Alex & Sam"
  final String name;
  final String banner;
  final DateTime joinedAt;

  /// When they last earned a star; the only thing others see before the reveal.
  final DateTime? lastClimbAt;
}

/// One team's stars for one activity on one day.
class ClimbScore {
  const ClimbScore({required this.coupleId, required this.day, required this.activity, required this.stars});

  final String coupleId;
  final DateTime day;
  final StarActivity activity;
  final int stars;

  String get key => '$coupleId|${day.toIso8601String()}|${activity.name}';
}

class Standing {
  const Standing(this.team, this.stars, this.threeStarCount, this.place);

  final ClimbTeam team;

  /// With the Final ascent doubled.
  final int stars;
  final int threeStarCount;

  /// 1 = winner. Teams that tie on stars and ⭐⭐⭐ count share a place.
  final int place;
}

class Challenge {
  const Challenge({
    required this.id,
    required this.code,
    required this.activities,
    required this.days,
    required this.startsOn,
    required this.revealAt,
    required this.teams,
    this.stakes,
    this.createdBy,
    this.scores = const [],
  });

  final String id;

  /// Shared with friends to join.
  final String code;
  final List<StarActivity> activities;
  final int days;

  /// Day 1, in each team's own calendar.
  final DateTime startsOn;

  /// When the fog lifts for everyone.
  final DateTime revealAt;
  final String? stakes;
  final String? createdBy;
  final List<ClimbTeam> teams;

  /// Scores visible to me: my team's, plus everyone's after the reveal.
  final List<ClimbScore> scores;

  DateTime get endsOn => addDays(startsOn, days - 1);

  bool isFinalAscent(DateTime day) => day == endsOn;

  /// The most stars a team can reach (the last day counts twice).
  int get maxStars => activities.length * 3 * (days + 1);

  bool get isFull => teams.length >= maxTeams;

  ClimbPhase phase(DateTime today, DateTime now) {
    if (!now.isBefore(revealAt)) return ClimbPhase.revealed;
    if (today.isBefore(startsOn)) return ClimbPhase.upcoming;
    if (!today.isAfter(endsOn)) return ClimbPhase.climbing;
    return ClimbPhase.summitWait;
  }

  /// Joining stays open through day 1.
  bool canJoin(DateTime today) => !today.isAfter(startsOn) && !isFull;

  /// 1-based day of the climb, clamped to the challenge.
  int dayNumber(DateTime today) {
    final n = today.difference(startsOn).inDays + 1;
    return n < 1 ? 0 : (n > days ? days : n);
  }

  int totalFor(String coupleId) {
    var sum = 0;
    for (final s in scores) {
      if (s.coupleId == coupleId) sum += s.stars * (isFinalAscent(s.day) ? 2 : 1);
    }
    return sum;
  }

  int _threeStars(String coupleId) => scores.where((s) => s.coupleId == coupleId && s.stars == 3).length;

  /// Highest first. Ties go to more ⭐⭐⭐; still level, they share the place.
  List<Standing> standings() {
    final rows = [for (final t in teams) (t, totalFor(t.coupleId), _threeStars(t.coupleId))]
      ..sort((a, b) => b.$2 != a.$2 ? b.$2.compareTo(a.$2) : b.$3.compareTo(a.$3));
    final out = <Standing>[];
    for (var i = 0; i < rows.length; i++) {
      final (team, stars, three) = rows[i];
      final tiedWithPrevious = i > 0 && rows[i - 1].$2 == stars && rows[i - 1].$3 == three;
      out.add(Standing(team, stars, three, tiedWithPrevious ? out[i - 1].place : i + 1));
    }
    return out;
  }

  ClimbTeam? teamOf(String coupleId) {
    for (final t in teams) {
      if (t.coupleId == coupleId) return t;
    }
    return null;
  }

  /// My team's rows for every climb day so far, from my daily stars.
  List<ClimbScore> scoresFrom(StarsCalculator stars, String coupleId, DateTime today) {
    final out = <ClimbScore>[];
    final last = today.isBefore(endsOn) ? today : endsOn;
    for (var d = startsOn; !d.isAfter(last); d = addDays(d, 1)) {
      final day = stars.day(d);
      for (final a in activities) {
        out.add(ClimbScore(coupleId: coupleId, day: d, activity: a, stars: day.activities[a]!.stars));
      }
    }
    return out;
  }
}

/// Day 1 is tomorrow, so everyone gets a full first day; the fog lifts at
/// noon the day after the last day, once last night's sleep has synced.
(DateTime startsOn, DateTime revealAt) climbSchedule(HouseholdCalendar cal, DateTime now, int days) {
  final startsOn = addDays(cal.localDate(now), 1);
  final revealAt = cal.instantAt(addDays(startsOn, days), 12, 0);
  return (startsOn, revealAt);
}

/// What an invite code leads to, shown before joining.
class ClimbPreview {
  const ClimbPreview({
    required this.id,
    required this.activities,
    required this.days,
    required this.startsOn,
    required this.teams,
    required this.alreadyIn,
    this.stakes,
  });

  final String id;
  final List<StarActivity> activities;
  final int days;
  final DateTime startsOn;
  final int teams;
  final bool alreadyIn;
  final String? stakes;
}

List<StarActivity> parseActivities(Iterable<Object?> names) => [
      for (final a in StarActivity.values)
        if (names.contains(a.name)) a,
    ];
