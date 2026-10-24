import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/engine.dart';
import '../state/app_controller.dart';
import 'badges_card.dart';
import 'common.dart';
import 'home_screen.dart';

/// Weekly outcomes, newest first, plus streak and boss badges. Everything is
/// recalculated from logs, so past weeks update after backdating or delete.
class WeeksScreen extends StatelessWidget {
  const WeeksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final s = Surface.of(context);
    final history = app.history;
    final current = app.engine.calendar.weekOf(app.now);
    final wins = history.where((w) => w.bossDefeated).toList();
    final white = GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w900);

    Widget bigTile(String emoji, String value, String label, Color color) => Expanded(
          child: Raised(
            face: color,
            edge: Vivid.shadeOf(color),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(children: [
              Text(emoji, style: const TextStyle(fontSize: 30)),
              Text(value, style: white.copyWith(fontSize: 30)),
              Text(label.toUpperCase(), style: white.copyWith(fontSize: 11, letterSpacing: 1)),
            ]),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(children: [
          bigTile('🔥', '${app.streak}', 'win streak', Vivid.flame),
          const SizedBox(width: 12),
          bigTile('🏆', '${wins.length}', 'bosses beaten', Vivid.sun),
        ]),
        const SizedBox(height: 14),
        const BadgesCard(),
        const SizedBox(height: 18),
        Text('HISTORY', style: theme.textTheme.labelLarge?.copyWith(color: s.muted, letterSpacing: 1)),
        const SizedBox(height: 10),
        for (final (i, w) in history.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _WeekTile(
              week: w,
              isCurrent: w.weekStart == current,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => WeekSummaryScreen(
                  week: w,
                  previous: i + 1 < history.length ? history[i + 1] : null,
                  isCurrent: w.weekStart == current,
                ),
              )),
            ),
          ),
      ],
    );
  }
}

class _WeekTile extends StatelessWidget {
  const _WeekTile({required this.week, required this.isCurrent, required this.onTap});

  final WeekResult week;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = Surface.of(context);
    final (label, color) = week.bossDefeated
        ? ('Defeated', Vivid.grass)
        : isCurrent
            ? ('In progress', Vivid.sky)
            : ('Survived', Vivid.berry);
    return GestureDetector(
      onTap: onTap,
      child: Raised(
        face: s.card,
        edge: s.line,
        border: s.line,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          EmojiBadge(week.boss.emoji, color: color, size: 50),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(weekLabel(week.weekStart), style: theme.textTheme.titleSmall),
              Text(week.boss.name, style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Pill(label, color: color),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmtInt(week.teamScore), style: theme.textTheme.titleLarge),
            Text('pts', style: theme.textTheme.bodySmall),
          ]),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: s.muted),
        ]),
      ),
    );
  }
}

class WeekSummaryScreen extends StatelessWidget {
  const WeekSummaryScreen({super.key, required this.week, this.previous, required this.isCurrent});

  final WeekResult week;
  final WeekResult? previous;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prev = previous;
    final white = GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w900);

    String delta(int now, int before) {
      final d = now - before;
      return d == 0 ? 'same as last week' : '${d > 0 ? '▲ +' : '▼ '}${fmtInt(d)} vs last week';
    }

    return Scaffold(
      appBar: AppBar(title: Text('Week of ${weekLabel(week.weekStart)}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isCurrent)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Pill('This week is still in progress', color: Vivid.sky),
            ),
          SectionCard(
            color: Vivid.sun,
            child: Column(children: [
              Text(fmtInt(week.teamScore), style: white.copyWith(fontSize: 44)),
              Text('TEAM POINTS', style: white.copyWith(fontSize: 12, letterSpacing: 1)),
              if (prev != null) Text(delta(week.teamScore, prev.teamScore), style: white.copyWith(fontSize: 13)),
              const SizedBox(height: 6),
              Text('${week.tasksLogged} tasks logged', style: white.copyWith(fontSize: 15)),
            ]),
          ),
          const SizedBox(height: 14),
          BossCard(week: week),
          const SizedBox(height: 14),
          Leaderboard(week: week),
          const SizedBox(height: 14),
          QuestList(week: week),
          const SizedBox(height: 14),
          SectionCard(
            title: '📊 Most frequent',
            child: week.topCategories.isEmpty
                ? Text('No tasks logged.', style: theme.textTheme.bodySmall)
                : Column(children: [
                    for (final e in week.topCategories.take(3))
                      SettingRow(emoji: e.key.emoji, title: e.key.label, trailing: Pill('${e.value}×')),
                  ]),
          ),
        ],
      ),
    );
  }
}
