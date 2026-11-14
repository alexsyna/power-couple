import 'package:flutter_test/flutter_test.dart';
import 'package:power_couple/data/backend.dart';
import 'package:power_couple/data/demo_backend.dart';
import 'package:power_couple/domain/catalog.dart';
import 'package:power_couple/state/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('"Hang out the laundry" is in the laundry category', () {
    final t = taskById('hang_laundry');
    expect(t.category, TaskCategory.laundry);
    expect(t.countsForBoss, isTrue);
  });

  test('custom tasks can be added, logged, and deleted without losing points', () async {
    final app = AppController(DemoBackend());
    await app.refresh();
    final before = app.currentWeek.teamScore;

    final t = await app.addCustomTask('  Iron   the shirts ', TaskCategory.laundry, 35);
    expect(t.name, 'Iron the shirts');
    expect(t.isCustom, isTrue);
    expect(app.visibleTasks, contains(t));

    // Same name again, any case: refused.
    expect(() => app.addCustomTask('iron the shirts', TaskCategory.cleaning, 10), throwsA(isA<BackendException>()));

    final log = await app.logTask(t, doneAt: app.now);
    expect(log.task.points, 35);
    expect(app.currentWeek.teamScore, before + 35);

    await app.deleteCustomTask(t);
    expect(app.visibleTasks.map((x) => x.id), isNot(contains(t.id)));
    // The log keeps its task and its points.
    expect(taskById(t.id).isDeleted, isTrue);
    expect(app.currentWeek.teamScore, before + 35);
  });

  test('custom categories exclude Other', () {
    expect(customCategories, isNot(contains(TaskCategory.other)));
    expect(customCategories, contains(TaskCategory.laundry));
  });
}
