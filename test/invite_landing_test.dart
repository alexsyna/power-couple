import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:power_couple/data/demo_backend.dart';
import 'package:power_couple/state/app_controller.dart';
import 'package:power_couple/state/invites.dart';
import 'package:power_couple/ui/common.dart';
import 'package:power_couple/ui/invite_ui.dart';

void main() {
  testWidgets('the landing page says who invited you and how to get in', (tester) async {
    final app = AppController(DemoBackend());
    var continued = false;
    await tester.pumpWidget(AppScope(
      controller: app,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: InviteLandingScreen(
          invite: const Invite(InviteKind.climb, 'FRIEND'),
          onContinueHere: () => continued = true,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Maria & Nikos, Eleni & Kostas challenged you to a Castle Climb!'), findsOneWidget);
    expect(find.textContaining('Last place cooks dinner'), findsOneWidget);
    expect(find.textContaining('Allow Paste'), findsOneWidget);
    // No public download link yet: the page says so.
    expect(find.textContaining('private beta'), findsOneWidget);
    await tester.ensureVisible(find.text('CONTINUE IN THE BROWSER'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUE IN THE BROWSER'));
    await tester.pumpAndSettle();
    expect(continued, isTrue);
  });

  testWidgets('an unknown code says the link doesn\'t work', (tester) async {
    final app = AppController(DemoBackend());
    await tester.pumpWidget(AppScope(
      controller: app,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: InviteLandingScreen(invite: const Invite(InviteKind.climb, 'NOPE00'), onContinueHere: () {}),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('This invite link doesn\'t work'), findsOneWidget);
  });
}
