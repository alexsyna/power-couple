import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

bool _tzReady = false;

void ensureTimeZones() {
  if (_tzReady) return;
  tzdata.initializeTimeZones();
  _tzReady = true;
}

/// Calendar maths in the household's timezone. Weeks run Monday to Sunday.
///
/// Local dates are represented as UTC-midnight [DateTime]s so they compare
/// and hash cleanly regardless of the device timezone.
class HouseholdCalendar {
  HouseholdCalendar(String timezone) : _location = _resolve(timezone);

  final tz.Location _location;

  static tz.Location _resolve(String name) {
    ensureTimeZones();
    try {
      return tz.getLocation(name);
    } on tz.LocationNotFoundException {
      return tz.UTC;
    }
  }

  String get timezoneName => _location.name;

  /// The household-local calendar date of an instant.
  DateTime localDate(DateTime instant) {
    final l = tz.TZDateTime.from(instant, _location);
    return DateTime.utc(l.year, l.month, l.day);
  }

  /// An instant as household-local wall-clock time, for display.
  DateTime localTime(DateTime instant) => tz.TZDateTime.from(instant, _location);

  /// Monday of the week containing [instant].
  DateTime weekOf(DateTime instant) => mondayOf(localDate(instant));

  static DateTime mondayOf(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day - (date.weekday - DateTime.monday));

  /// The instant the given local date starts, as UTC.
  DateTime startOfDay(DateTime date) =>
      tz.TZDateTime(_location, date.year, date.month, date.day).toUtc();

  /// Combines a local date and time-of-day into an instant.
  DateTime instantAt(DateTime date, int hour, int minute) =>
      tz.TZDateTime(_location, date.year, date.month, date.day, hour, minute).toUtc();

  /// Week starts from the week containing [from] up to and including [to]'s.
  List<DateTime> weeksBetween(DateTime from, DateTime to) {
    final weeks = <DateTime>[];
    var w = weekOf(from);
    final last = weekOf(to);
    while (!w.isAfter(last)) {
      weeks.add(w);
      w = DateTime.utc(w.year, w.month, w.day + 7);
    }
    return weeks;
  }
}

DateTime addDays(DateTime date, int days) =>
    DateTime.utc(date.year, date.month, date.day + days);
