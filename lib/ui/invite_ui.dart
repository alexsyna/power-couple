import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/links.dart';
import '../domain/challenge.dart';
import '../state/app_controller.dart';
import '../state/invites.dart';
import 'common.dart';
import 'logo.dart';

// ------------------------------------------------------------ sharing

Future<void> _share(BuildContext context, String text, String subject) async {
  final box = context.findRenderObject() as RenderBox?;
  try {
    final r = await SharePlus.instance.share(ShareParams(
      text: text,
      subject: subject,
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
    if (r.status == ShareResultStatus.unavailable) throw StateError('no share sheet');
  } catch (_) {
    // No share sheet (e.g. a desktop browser): copy instead.
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) showMessage(context, '📋 Link copied. Paste it in a chat!', color: Vivid.grass);
  }
}

Future<void> shareClimbInvite(BuildContext context, String code) => _share(
      context,
      'We challenge you to a Castle Climb 🏰 on Power Couple! Tap to join: ${Invite(InviteKind.climb, code).url}',
      'Castle Climb challenge',
    );

Future<void> sharePartnerInvite(BuildContext context) {
  final code = AppScope.of(context).household!.inviteCode;
  return _share(
    context,
    'Join me on Power Couple 💞 Chores, daily questions and Castle Climbs, together. '
        'Tap to join our household: ${Invite(InviteKind.household, code).url}',
    'Join me on Power Couple',
  );
}

/// After joining a climb solo: the rope team needs the partner.
Future<void> showPartnerInviteSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('🧗💞', style: TextStyle(fontSize: 48), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('You\'re on the mountain!', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              'A rope team is two people. Send your partner the link: once they join your household, '
              'you\'re climbing together, with nothing else to do.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Builder(
              builder: (context) => ChunkyButton(
                label: 'Invite my partner',
                icon: const Text('💌'),
                onPressed: () async {
                  await sharePartnerInvite(context);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
          ]),
        );
      },
    );

// ------------------------------------------------------------ banner

/// Shown on sign-up and household setup while an invite is waiting.
class InviteBanner extends StatelessWidget {
  const InviteBanner({super.key, required this.invite, required this.atSetup});

  final Invite invite;

  /// On the household setup screen (otherwise sign-up).
  final bool atSetup;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return FutureBuilder<InviteInfo?>(
      future: app.backend.inviteInfo(invite.code),
      builder: (context, f) {
        final info = f.data;
        final climb = invite.kind == InviteKind.climb;
        final who = climb
            ? (info?.teams?.join(', ') ?? 'Your friends')
            : (info?.inviter ?? 'Your partner');
        final text = climb
            ? atSetup
                ? 'Set up your household (or join your partner\'s) and you\'ll join $who\'s Castle Climb right after.'
                : 'Sign up to join $who\'s Castle Climb 🏰'
            : 'Sign up and you\'ll join $who\'s household automatically 💞';
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Raised(
            face: climb ? Vivid.grape : Vivid.berry,
            edge: Vivid.shadeOf(climb ? Vivid.grape : Vivid.berry),
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Text(climb ? '🏰' : '💌', style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text,
                    style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------ web landing

/// What someone sees when they open an invite link in a browser without the
/// app: who invited them, and how to get in.
class InviteLandingScreen extends StatelessWidget {
  const InviteLandingScreen({super.key, required this.invite, required this.onContinueHere});

  final Invite invite;
  final VoidCallback onContinueHere;

  bool get _onIPhone => defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _getApp(BuildContext context) async {
    // The app picks this up from the clipboard on its first launch.
    await Clipboard.setData(ClipboardData(text: invite.url.toString()));
    await launchUrl(Uri.parse(appDownloadUrl), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final s = Surface.of(context);
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<InviteInfo?>(
          future: app.backend.inviteInfo(invite.code),
          builder: (context, f) {
            final info = f.data;
            final loading = f.connectionState != ConnectionState.done;
            final climb = invite.kind == InviteKind.climb;
            final String title;
            if (loading) {
              title = climb ? 'You\'re invited to a Castle Climb 🏰' : 'You\'re invited 💞';
            } else if (info == null) {
              title = 'This invite link doesn\'t work';
            } else if (climb) {
              title = '${info.teams!.join(', ')} challenged you to a Castle Climb!';
            } else {
              title = '${info.inviter ?? 'Your partner'} invited you to Power Couple';
            }
            final closed = info != null && !info.open;
            return ListView(padding: const EdgeInsets.fromLTRB(24, 24, 24, 32), children: [
              const Center(child: PowerCoupleLogo(size: 96)),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              if (climb && info != null) ...[
                Text(
                  'Race up the mountain for ${info.days == 30 ? 'a month' : '${info.days} days'}: '
                  '${info.activities!.map((a) => '${a.emoji} ${a.label}').join(', ')}. '
                  'Most stars plants their banner on the castle.',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                if (info.stakes != null) ...[
                  const SizedBox(height: 8),
                  Text('🎲 ${info.stakes}', style: theme.textTheme.titleSmall, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 4),
                Text('Day 1: ${DateFormat('EEEE d MMM').format(info.startsOn!)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: s.muted), textAlign: TextAlign.center),
              ],
              if (!climb && info != null)
                Text('Beat the weekly chores boss together, answer a daily question, and climb castles with friends.',
                    style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
              if (closed)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(climb ? 'This climb has already started or is full.' : 'This household is already full.',
                      style: theme.textTheme.titleSmall?.copyWith(color: Vivid.berry), textAlign: TextAlign.center),
                ),
              const SizedBox(height: 24),
              if (info != null && !closed) ...[
                SectionCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('1. Get the Power Couple app', style: theme.textTheme.titleSmall),
                    Text('2. Open it and sign up. Tap "Allow Paste" if asked: that\'s this invite.',
                        style: theme.textTheme.titleSmall),
                    Text(
                      climb
                          ? '3. You\'re in the climb. Then invite your partner to climb with you.'
                          : '3. You\'re in your partner\'s household.',
                      style: theme.textTheme.titleSmall,
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                if (appDownloadUrl.isNotEmpty)
                  ChunkyButton(label: 'Get the iPhone app', icon: const Text('📲'), onPressed: () => _getApp(context))
                else
                  Text('The iPhone app is in private beta. Ask your friend for a TestFlight invite, or play in the browser.',
                      style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
                if (_onIPhone) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => launchUrl(
                      Uri.parse('${InviteLinks.appScheme}://invite/${invite.kind.path}/${invite.code}'),
                    ),
                    child: const Text('I already have the app: open it'),
                  ),
                ],
              ],
              const SizedBox(height: 8),
              ChunkyButton(
                label: 'Continue in the browser',
                outlined: true,
                color: Vivid.sky,
                onPressed: onContinueHere,
              ),
            ]);
          },
        ),
      ),
    );
  }
}
