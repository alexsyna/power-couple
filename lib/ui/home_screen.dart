import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/catalog.dart';
import '../domain/engine.dart';
import '../state/app_controller.dart';
import 'common.dart';
import 'log_task_screen.dart';
import 'missions.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final week = app.currentWeek;
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: app.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          Text('THIS WEEK · ${weekLabel(week.weekStart).toUpperCase()}',
              style: theme.textTheme.labelLarge?.copyWith(color: Surface.of(context).muted, letterSpacing: 1)),
          const SizedBox(height: 12),
          if (!app.household!.isComplete) ...[
            const _InviteCard(),
            const SizedBox(height: 14),
          ],
          BossCard(week: week),
          const SizedBox(height: 14),
          Leaderboard(week: week),
          const SizedBox(height: 14),
          QuestList(week: week, canHit: true),
          const SizedBox(height: 14),
          const MissionsCard(),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard();

  @override
  Widget build(BuildContext context) {
    final code = AppScope.of(context).household!.inviteCode;
    return SectionCard(
      color: Vivid.sky,
      child: Row(children: [
        const Text('💌', style: TextStyle(fontSize: 36)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Invite your partner',
                style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
            Text(code,
                style: GoogleFonts.nunito(
                    color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 3)),
          ]),
        ),
        IconButton(
          tooltip: 'Copy code',
          color: Colors.white,
          icon: const Icon(Icons.copy_rounded),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: code));
            showMessage(context, 'Invite code copied', color: Vivid.sky);
          },
        ),
      ]),
    );
  }
}

class BossCard extends StatelessWidget {
  const BossCard({super.key, required this.week});

  final WeekResult week;

  @override
  Widget build(BuildContext context) {
    final boss = week.boss;
    final defeated = week.bossDefeated;
    final color = defeated ? Vivid.grass : Vivid.grape;
    final white = GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w900);
    return SectionCard(
      color: color,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Vivid.shadeOf(color), width: 4),
            ),
            child: Text(defeated ? '🏆' : boss.emoji, style: const TextStyle(fontSize: 42)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Pill(defeated ? 'DEFEATED!' : 'WEEKLY BOSS', color: Vivid.shadeOf(color), filled: true),
              const SizedBox(height: 4),
              Text(boss.name, style: white.copyWith(fontSize: 22, height: 1.1)),
              Text(boss.taunt,
                  style: white.copyWith(
                      fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9))),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        ProgressBar(
          value: week.bossFraction,
          height: 22,
          color: defeated ? Vivid.sun : Vivid.berry,
          track: Vivid.shadeOf(color),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Text('${fmtInt(week.bossDamage)} / ${fmtInt(week.bossHealth)} dmg', style: white.copyWith(fontSize: 14)),
          const Spacer(),
          Text(defeated ? 'Victory! 🎉' : '❤️ ${fmtInt(week.bossRemaining)} HP',
              style: white.copyWith(fontSize: 14)),
        ]),
        if (week.teamScore != week.bossDamage) ...[
          const SizedBox(height: 6),
          Text('Only catalog tasks hit the boss. Quest bonuses and "Other" tasks add to team points.',
              style: white.copyWith(
                  fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85))),
        ],
      ]),
    );
  }
}

class Leaderboard extends StatelessWidget {
  const Leaderboard({super.key, required this.week});

  final WeekResult week;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final s = Surface.of(context);
    final members = app.household!.members;
    final total = week.taskPoints;
    final ranked = week.leaderboard;
    return SectionCard(
      title: '💥 Damage Dealers',
      child: Column(children: [
        for (final (i, e) in ranked.indexed) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: e.key == app.me ? Vivid.sky.withValues(alpha: 0.1) : null,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: e.key == app.me ? Vivid.sky : s.line, width: 2),
            ),
            child: Column(children: [
              Row(children: [
                SizedBox(
                  width: 30,
                  child: Text(total == 0 ? '${i + 1}' : medal(i),
                      textAlign: TextAlign.center,
                      style: total == 0 ? theme.textTheme.titleMedium : const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 8),
                PersonAvatar(userId: e.key, size: 36),
                const SizedBox(width: 10),
                Expanded(child: Text(app.nameOf(e.key), style: theme.textTheme.titleMedium)),
                Text('${fmtInt(e.value)} pts', style: theme.textTheme.titleMedium),
                const SizedBox(width: 8),
                Pill(total == 0 ? '–' : '${(e.value * 100 / total).round()}%',
                    color: personColor(members, e.key)),
              ]),
              const SizedBox(height: 8),
              ProgressBar(value: total == 0 ? 0 : e.value / total, height: 10, color: personColor(members, e.key)),
            ]),
          ),
          if (i < ranked.length - 1) const SizedBox(height: 10),
        ],
        if (ranked.length < 2) ...[
          const SizedBox(height: 8),
          Text('Your partner will appear here once they join.', style: theme.textTheme.bodySmall),
        ],
      ]),
    );
  }
}

class QuestList extends StatelessWidget {
  const QuestList({super.key, required this.week, this.canHit = false});

  final WeekResult week;

  /// Shows a Hit button on unfinished quests (only for the current week).
  final bool canHit;

  static const _colors = [Vivid.sun, Vivid.sky, Vivid.grape, Vivid.flame];

  /// Opens the shared log flow narrowed to the tasks this quest still needs;
  /// with a single option, straight to its confirm sheet.
  static void _hit(BuildContext context, QuestProgress q, List<TaskDef> tasks) {
    if (tasks.length == 1) {
      openLogTaskFor(context, tasks.single);
    } else {
      openLogTask(context, only: tasks, title: '${q.quest.emoji} ${q.quest.name}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = canHit ? AppScope.of(context).visibleTasks : const <TaskDef>[];
    return SectionCard(
      title: '🗺️ Quests',
      trailing: Pill('${week.questsCompleted}/${week.quests.length}', color: Vivid.grass),
      child: Column(children: [
        for (final (qi, q) in week.quests.indexed)
          _questRow(context, qi, q, q.tasksToProgress(available), last: qi == week.quests.length - 1),
      ]),
    );
  }

  Widget _questRow(BuildContext context, int qi, QuestProgress q, List<TaskDef> hitTasks, {required bool last}) {
    final theme = Theme.of(context);
    final color = q.isComplete ? Vivid.grass : _colors[qi % _colors.length];
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        EmojiBadge(q.isComplete ? '✅' : q.quest.emoji, color: color, size: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(q.quest.name, style: theme.textTheme.titleSmall)),
              Pill('+${q.quest.bonus}', color: Vivid.sun, filled: q.isComplete),
            ]),
            for (final (i, r) in q.quest.requirements.indexed)
              Text('${r.label}  ${q.progress[i]}/${r.count}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: ProgressBar(value: q.fraction, height: 14, color: color)),
              if (!q.isComplete && hitTasks.isNotEmpty) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 84,
                  child: ChunkyButton(
                    label: 'Hit',
                    icon: const Text('💥'),
                    compact: true,
                    onPressed: () => _hit(context, q, hitTasks),
                  ),
                ),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }
}
