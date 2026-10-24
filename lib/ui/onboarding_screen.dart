import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../data/backend.dart';
import '../state/app_controller.dart';
import 'common.dart';

Future<String> deviceTimezone() async {
  try {
    return (await FlutterTimezone.getLocalTimezone()).identifier;
  } catch (_) {
    return 'UTC';
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _code = TextEditingController();
  bool _kids = false;
  bool _pets = false;
  bool _busy = false;
  String? _timezone;

  @override
  void initState() {
    super.initState();
    deviceTimezone().then((tz) {
      if (mounted) setState(() => _timezone = tz);
    });
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on BackendException catch (e) {
      if (mounted) showMessage(context, e.message, color: Vivid.berry);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up your household'),
        actions: [TextButton(onPressed: app.signOut, child: const Text('Sign out'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: '🏡 Start a new household',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('You\'ll get an invite code to share with your partner.',
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('We have kids'),
                  subtitle: const Text('Adds childcare tasks and quests'),
                  value: _kids,
                  onChanged: (v) => setState(() => _kids = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('We have pets'),
                  subtitle: const Text('Adds pet care tasks and quests'),
                  value: _pets,
                  onChanged: (v) => setState(() => _pets = v),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.public),
                  title: const Text('Household timezone'),
                  subtitle: Text(_timezone ?? 'Detecting…'),
                ),
                Text('Weeks run Monday to Sunday in this timezone. You can change it later.',
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                ChunkyButton(
                  label: 'Create household',
                  busy: _busy,
                  onPressed: _timezone == null
                      ? null
                      : () => _run(() => app.createHousehold(_timezone!, _kids, _pets)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: '💌 Join your partner',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Invite code', hintText: 'e.g. 3F9A21BC'),
                ),
                const SizedBox(height: 12),
                ChunkyButton(
                  label: 'Join household',
                  color: Vivid.sky,
                  busy: _busy,
                  onPressed: () => _run(() => app.joinHousehold(_code.text)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
