import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/demo_backend.dart';
import '../state/app_controller.dart';
import 'bond_screen.dart';
import 'common.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'log_task_screen.dart';
import 'missions.dart';
import 'settings_screen.dart';
import 'shop.dart';
import 'weeks_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  static const _titles = ['Our home', 'Bond', 'Achievements'];

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
          _StatChip(
            emoji: '🔥',
            value: '${app.streak}',
            color: Vivid.flame,
            explain: app.streak == 1
                ? 'Win streak: 1 boss defeated in a row'
                : 'Win streak: ${app.streak} bosses defeated in a row',
          ),
          const SizedBox(width: 8),
          _StatChip(
            emoji: '⚡',
            value: fmtInt(week.teamScore),
            color: Vivid.sunShade,
            explain: 'Team points this week: ${fmtInt(week.teamScore)}',
          ),
          const SizedBox(width: 4),
          const _Menu(),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: Surface.of(context).line),
        ),
      ),
      body: IndexedStack(
        index: _tab,
        children: const [HomeScreen(), BondScreen(), WeeksScreen()],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _tab == 0
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
          destinations: [
            const NavigationDestination(icon: Text('🏠', style: TextStyle(fontSize: 24)), label: 'Home'),
            NavigationDestination(icon: _BondIcon(alert: app.bondNeedsMe), label: 'Bond'),
            const NavigationDestination(icon: Text('🏆', style: TextStyle(fontSize: 24)), label: 'Achievements'),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.emoji, required this.value, required this.color, required this.explain});

  final String emoji;
  final String value;
  final Color color;

  /// Shown when the chip is tapped (or long-pressed / hovered on web).
  final String explain;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: explain,
        triggerMode: TooltipTriggerMode.tap,
        showDuration: const Duration(seconds: 3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 3),
          Text(value, style: GoogleFonts.nunito(fontWeight: FontWeight.w900, fontSize: 17, color: color)),
        ]),
      );
}

/// Top-right ☰ menu for screens that don't need a bottom-bar slot.
class _Menu extends StatelessWidget {
  const _Menu();

  @override
  Widget build(BuildContext context) => PopupMenuButton<Widget>(
        tooltip: 'Menu',
        icon: const Icon(Icons.menu_rounded),
        position: PopupMenuPosition.under,
        onSelected: (page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
        itemBuilder: (context) => [
          _item(context, '📋', 'Activity', const _MenuPage(title: 'Activity', child: HistoryScreen())),
          _item(context, '🛍️', 'Shop', const ShopPage()),
          _item(context, '⚙️', 'Settings', const _MenuPage(title: 'Settings', child: SettingsScreen())),
        ],
      );

  PopupMenuItem<Widget> _item(BuildContext context, String emoji, String label, Widget page) => PopupMenuItem(
        value: page,
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Text(label, style: Theme.of(context).textTheme.titleSmall),
        ]),
      );
}

/// A screen opened from the menu, with a back button.
class _MenuPage extends StatelessWidget {
  const _MenuPage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Signing out or leaving the household from here swaps the app's root;
    // close this page so it doesn't linger on top.
    if (AppScope.of(context).status != AppStatus.ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      });
      return const Scaffold();
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: Surface.of(context).line),
        ),
      ),
      body: child,
    );
  }
}

/// Bond tab icon. When the partner has answered and is waiting, the heart
/// bounces and a pulsing dot appears to draw attention.
class _BondIcon extends StatefulWidget {
  const _BondIcon({required this.alert});

  final bool alert;

  @override
  State<_BondIcon> createState() => _BondIconState();
}

class _BondIconState extends State<_BondIcon> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_BondIcon old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.alert && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.alert) {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: widget.alert ? 'Your partner answered. Your turn!' : null,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            // Two quick beats, then rest: like a heartbeat.
            final beat = t < 0.15
                ? math.sin(t / 0.15 * math.pi)
                : t < 0.35
                    ? math.sin((t - 0.2) / 0.15 * math.pi).clamp(0.0, 1.0)
                    : 0.0;
            return Stack(clipBehavior: Clip.none, children: [
              Transform.scale(
                scale: 1 + 0.25 * beat,
                child: const Text('💞', style: TextStyle(fontSize: 24)),
              ),
              if (widget.alert)
                Positioned(
                  right: -6,
                  top: -4,
                  child: Stack(alignment: Alignment.center, children: [
                    Container(
                      width: 14 + 14 * t,
                      height: 14 + 14 * t,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Vivid.berry.withValues(alpha: 0.45 * (1 - t)),
                      ),
                    ),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Vivid.berry,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ]),
                ),
            ]);
          },
        ),
      );
}
