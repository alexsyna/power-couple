import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:power_couple/domain/content.dart';
import 'package:power_couple/ui/boss_hit.dart';
import 'package:power_couple/ui/common.dart';

void main() {
  testWidgets('boss hit holds on the celebration, then closes itself', (tester) async {
    final hit = BossHit(
      boss: bosses.first,
      health: 1000,
      damageBefore: 600,
      damageAfter: 640,
      projectile: '🍳',
    );
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(onPressed: () => showBossHit(context, hit), child: const Text('go')),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();

    // Mid-way through the hold the result and cheer are on screen.
    await tester.pump(const Duration(milliseconds: 3500));
    expect(find.text('DIRECT HIT!'), findsOneWidget);
    expect(find.text('❤️ 360 HP left'), findsOneWidget);
    expect(find.textContaining('Great hit!'), findsOneWidget);

    // Closes on its own after ~5s.
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
    expect(find.text('DIRECT HIT!'), findsNothing);
  });
}
