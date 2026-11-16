import 'package:flutter_test/flutter_test.dart';
import 'package:power_couple/data/demo_backend.dart';
import 'package:power_couple/domain/challenge.dart';
import 'package:power_couple/domain/stars.dart';
import 'package:power_couple/state/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('my stars are posted; other teams stay hidden until the reveal', () async {
    final app = AppController(DemoBackend());
    await app.refresh();
    await app.syncClimbs();
    final me = app.household!.id;

    final running = app.challenges.firstWhere((c) => c.id == 'climb-run');
    expect(running.phase(app.today, app.now), ClimbPhase.climbing);
    // My rows exist for each day so far and each activity; nobody else's.
    expect(running.scores.where((s) => s.coupleId == me).length, 4 * running.activities.length);
    expect(running.scores.every((s) => s.coupleId == me), isTrue);
    // And they match the daily stars card.
    final todayStars = app.stars.day(app.today);
    for (final a in running.activities) {
      final row = running.scores.firstWhere((s) => s.day == app.today && s.activity == a);
      expect(row.stars, todayStars.activities[a]!.stars);
    }

    final done = app.challenges.firstWhere((c) => c.id == 'climb-done');
    expect(done.phase(app.today, app.now), ClimbPhase.revealed);
    expect(done.scores.map((s) => s.coupleId).toSet().length, 3);
    expect(done.standings().first.place, 1);
  });

  test('joining a climb by code adds my rope team', () async {
    final app = AppController(DemoBackend());
    await app.refresh();
    final preview = await app.previewClimb(' friend ');
    expect(preview, isNotNull);
    expect(preview!.alreadyIn, isFalse);
    expect(preview.activities, contains(StarActivity.bedtime));
    await app.joinClimb('FRIEND', '🐼');
    final c = app.challenges.firstWhere((x) => x.code == 'FRIEND');
    expect(c.teams.length, 3);
    expect(c.teamOf(app.household!.id)!.name, 'Alex & Sam');
    expect((await app.previewClimb('FRIEND'))!.alreadyIn, isTrue);
  });

  test('a new climb starts tomorrow with my team on it', () async {
    final app = AppController(DemoBackend());
    await app.refresh();
    final c = await app.createClimb(
      activities: const [StarActivity.chores, StarActivity.snap],
      days: 3,
      stakes: 'Last place cooks dinner 🍲',
      banner: '🦄',
    );
    expect(c.startsOn, app.today.add(const Duration(days: 1)));
    expect(c.teams.single.banner, '🦄');
    expect(app.challenges.any((x) => x.id == c.id), isTrue);
  });
}
