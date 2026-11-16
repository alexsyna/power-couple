import 'package:flutter_test/flutter_test.dart';
import 'package:power_couple/data/demo_backend.dart';
import 'package:power_couple/state/app_controller.dart';
import 'package:power_couple/state/invites.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> waitFor(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(done(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('invites are found in our links, paths and pasted messages only', () {
    expect(Invite.parse('https://powercouple.mindblo.app/c/CLIMB7'), const Invite(InviteKind.climb, 'CLIMB7'));
    expect(Invite.parse('https://powercouple.mindblo.app/h/3f9a21bc'), const Invite(InviteKind.household, '3F9A21BC'));
    expect(Invite.parse('/c/friend'), const Invite(InviteKind.climb, 'FRIEND'));
    expect(
      Invite.parse('We challenge you to a Castle Climb 🏰 on Power Couple! Tap to join: https://powercouple.mindblo.app/c/AB12CD'),
      const Invite(InviteKind.climb, 'AB12CD'),
    );
    expect(Invite.parse('org.powercouple.powercouple://invite/c/CLIMB7'), const Invite(InviteKind.climb, 'CLIMB7'));
    // Someone else's site, the login callback, or nothing.
    expect(Invite.parse('https://example.com/c/CLIMB7'), isNull);
    expect(Invite.parse('org.powercouple.powercouple://login-callback?code=abc'), isNull);
    expect(Invite.parse('https://powercouple.mindblo.app/'), isNull);
    expect(Invite.parse(null), isNull);
    expect(const Invite(InviteKind.climb, 'CLIMB7').url.toString(), 'https://powercouple.mindblo.app/c/CLIMB7');
  });

  test('a waiting climb invite joins the climb and opens it', () async {
    SharedPreferences.setMockInitialValues({'pending_invite': 'climb:FRIEND'});
    final prefs = await SharedPreferences.getInstance();
    final app = AppController(DemoBackend(), prefs: prefs);
    // The app uses the invite by itself once it has loaded.
    await waitFor(() => app.inviteOutcome.value != null);
    await app.refresh();
    final c = app.challenges.firstWhere((x) => x.code == 'FRIEND');
    expect(c.teamOf(app.household!.id), isNotNull);
    expect(app.inviteOutcome.value?.climbId, c.id);
    // The demo household already has both partners: no need to ask.
    expect(app.inviteOutcome.value?.askPartner, isFalse);
    expect(app.invites.pending, isNull);
    expect(prefs.getString('pending_invite'), isNull);
  });

  test('a household link while already in a household is dropped with a note', () async {
    SharedPreferences.setMockInitialValues({'pending_invite': 'household:ZZZZ9999'});
    final prefs = await SharedPreferences.getInstance();
    final app = AppController(DemoBackend(), prefs: prefs);
    await waitFor(() => app.inviteOutcome.value != null);
    expect(app.invites.pending, isNull);
    expect(app.inviteOutcome.value?.error, isTrue);
  });
}
