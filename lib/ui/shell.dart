import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/demo_backend.dart';
import '../state/app_controller.dart';
import 'common.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'log_task_screen.dart';
import 'missions.dart';
import 'settings_screen.dart';
import 'weeks_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  static const _titles = ['Our home', 'Activity', 'Achievements', 'Settings'];

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final backend = app.backend;
    final week = app.currentWeek;
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(_titles[_tab]),
        actions: [
          if (backend is DemoBackend)
            IconButton(
              tooltip: 'Switch partner (demo)',
              icon: const Icon(Icons.swap_horiz),
              onPressed: backend.switchPartner,
            ),
          _StatChip(emoji: '🔥', value: '${app.streak}', color: Vivid.flame),
          const SizedBox(width: 8),
          _StatChip(emoji: '⚡', value: fmtInt(week.teamScore), color: Vivid.sunShade),
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: Surface.of(context).line),
        ),
      ),
      body: IndexedStack(
        index: _tab,
        children: const [HomeScreen(), HistoryScreen(), WeeksScreen(), SettingsScreen()],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _tab <= 1
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(
                  child: ChunkyButton(
                    label: 'Hit the boss',
                    icon: const Text('💥'),
                    fontSize: 13,
                    onPressed: () => openLogTask(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChunkyButton(
                    label: 'Assign mission',
                    icon: const Text('🛡️'),
                    fontSize: 13,
                    color: Vivid.grape,
                    onPressed: () => openMissionEditor(context, forPartner: true),
                  ),
                ),
              ]),
            )
          : null,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Surface.of(context).line, width: 2))),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(icon: Text('🏠', style: TextStyle(fontSize: 24)), label: 'Home'),
            NavigationDestination(icon: Text('📋', style: TextStyle(fontSize: 24)), label: 'Activity'),
            NavigationDestination(icon: Text('🏆', style: TextStyle(fontSize: 24)), label: 'Achievements'),
            NavigationDestination(icon: Text('⚙️', style: TextStyle(fontSize: 24)), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.emoji, required this.value, required this.color});

  final String emoji;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 3),
        Text(value, style: GoogleFonts.nunito(fontWeight: FontWeight.w900, fontSize: 17, color: color)),
      ]);
}
