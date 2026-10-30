import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/backend.dart';
import '../data/demo_backend.dart';
import '../state/app_controller.dart';
import 'common.dart';
import 'intro_screen.dart';
import 'onboarding_screen.dart';
import 'profile_card.dart';
import 'shop.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } on BackendException catch (e) {
      if (context.mounted) showMessage(context, e.message, color: Vivid.berry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final h = app.household!;
    final backend = app.backend;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        const ProfileCard(),
        const SizedBox(height: 14),
        SectionCard(
          title: '🏡 Household',
          child: Column(children: [
            Row(children: [
              for (final m in h.members) ...[
                PersonAvatar(userId: m.userId, size: 44),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(h.members.map((m) => m.displayName).join(' & '),
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ]),
            const SizedBox(height: 10),
            SettingRow(
              emoji: '🔑',
              title: 'Invite code',
              subtitle: h.inviteCode,
              color: Vivid.sun,
              trailing: IconButton(
                icon: const Icon(Icons.copy_rounded),
                tooltip: 'Copy',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: h.inviteCode));
                  showMessage(context, 'Invite code copied', color: Vivid.sky);
                },
              ),
            ),
            SettingRow(
              emoji: '🌍',
              title: 'Timezone',
              subtitle: '${h.timezone} · weeks start Monday',
              trailing: TextButton(
                child: const Text('Use device'),
                onPressed: () => _run(context, () async {
                  final tz = await deviceTimezone();
                  if (tz == h.timezone) return;
                  if (!context.mounted) return;
                  final ok = await confirm(context,
                      emoji: '🌍',
                      title: 'Change timezone to $tz?',
                      body: 'Week boundaries move for both of you, and past weeks are recalculated.',
                      action: 'Change');
                  if (ok) await app.updateSettings(timezone: tz);
                }),
              ),
            ),
            SettingRow(
              emoji: '🧸',
              title: 'We have kids',
              color: Vivid.berry,
              trailing: Switch(
                value: h.hasKids,
                onChanged: (v) => _run(context, () => app.updateSettings(hasKids: v)),
              ),
            ),
            SettingRow(
              emoji: '🐾',
              title: 'We have pets',
              color: Vivid.flame,
              trailing: Switch(
                value: h.hasPets,
                onChanged: (v) => _run(context, () => app.updateSettings(hasPets: v)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        const ShopCard(),
        const SizedBox(height: 14),
        if (backend is DemoBackend) ...[
          SectionCard(
            title: '🧪 Demo mode',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Data lives on this device only. Switch partner to see the other side.'),
              const SizedBox(height: 12),
              ChunkyButton(
                label: 'Switch from ${app.myName()}',
                color: Vivid.grape,
                icon: const Icon(Icons.swap_horiz_rounded),
                onPressed: backend.switchPartner,
              ),
            ]),
          ),
          const SizedBox(height: 14),
        ],
        SectionCard(
          title: '👤 Account',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ChunkyButton(
              label: 'Replay intro',
              outlined: true,
              color: Vivid.grape,
              icon: const Icon(Icons.play_arrow_rounded),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                fullscreenDialog: true,
                builder: (introContext) => IntroScreen(replay: true, onDone: (_) => Navigator.pop(introContext)),
              )),
            ),
            const SizedBox(height: 12),
            ChunkyButton(label: 'Sign out', outlined: true, color: Vivid.sky, onPressed: app.signOut),
            const SizedBox(height: 12),
            ChunkyButton(
              label: 'Leave household',
              outlined: true,
              color: Vivid.berry,
              onPressed: () async {
                final ok = await confirm(context,
                    emoji: '👋',
                    title: 'Leave household?',
                    body: 'Your past tasks stay in the household history. '
                        'You can join or start another household afterwards.',
                    action: 'Leave',
                    destructive: true);
                if (ok && context.mounted) await _run(context, app.leaveHousehold);
              },
            ),
          ]),
        ),
      ],
    );
  }
}
