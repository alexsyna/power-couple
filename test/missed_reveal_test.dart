import 'package:flutter_test/flutter_test.dart';
import 'package:power_couple/data/demo_backend.dart';
import 'package:power_couple/state/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a day my partner completed after me is a missed reveal until seen', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final app = AppController(DemoBackend(), prefs: prefs);
    await app.refresh();

    // Demo: Sam completed yesterday after Alex; other days Alex answered last.
    final missed = app.missedReveals;
    expect(missed.length, 1);
    final day = missed.single.$1;
    expect(day, app.today.subtract(const Duration(days: 1)));
    expect(app.bondNeedsMe, isTrue);

    app.markRevealSeen(day);
    expect(app.isRevealSeen(day), isTrue);
    // Still listed for this session so the card doesn't vanish after the flip.
    expect(app.missedReveals.length, 1);

    // A fresh session no longer lists it.
    final next = AppController(DemoBackend(), prefs: prefs);
    await next.refresh();
    expect(next.missedReveals, isEmpty);
  });
}
