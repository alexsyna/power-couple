import 'package:flutter/material.dart';

import '../data/backend.dart';
import '../domain/calendar.dart';
import '../domain/missions.dart';
import '../domain/questions.dart';
import '../domain/models.dart';
import '../state/app_controller.dart';
import 'common.dart';
import 'missions.dart';

enum HistoryRange {
  thisWeek('This week'),
  lastWeek('Last week'),
  fourWeeks('4 weeks');

  const HistoryRange(this.label);
  final String label;
}

/// Every log for the household. Either partner can delete any entry; deleted
/// entries are hidden but can be shown, with who deleted them.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  HistoryRange _range = HistoryRange.thisWeek;
  bool _showDeleted = false;

  Future<bool> _delete(TaskLog log) async {
    final app = AppScope.of(context);
    final mine = log.loggedBy == app.me;
    final ok = await confirm(
      context,
      emoji: '🗑️',
      title: 'Delete ${log.displayName}?',
      body: mine
          ? 'Points, quests and the boss for that week will be recalculated for both of you.'
          : 'This was logged by ${app.nameOf(log.loggedBy)}. They will see that you deleted it, '
              'and that week\'s points, quests and boss will be recalculated.',
      action: 'Delete',
      destructive: true,
    );
    if (!ok) return false;
    try {
      await app.undo(log);
      if (mounted) showMessage(context, 'Deleted ${log.displayName}', color: Vivid.berry);
      return true;
    } on BackendException catch (e) {
      if (mounted) showMessage(context, e.message, color: Vivid.berry);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final s = Surface.of(context);
    final cal = app.engine.calendar;
    final thisWeek = cal.weekOf(app.now);
    final (from, to) = switch (_range) {
      HistoryRange.thisWeek => (thisWeek, addDays(thisWeek, 7)),
      HistoryRange.lastWeek => (addDays(thisWeek, -7), thisWeek),
      HistoryRange.fourWeeks => (addDays(thisWeek, -21), addDays(thisWeek, 7)),
    };
    final inRange = app.logs.where((l) {
      final w = cal.weekOf(l.doneAt);
      return !w.isBefore(from) && w.isBefore(to);
    }).toList()
      ..sort((a, b) => b.doneAt.compareTo(a.doneAt));
    final deletedCount = inRange.where((l) => !l.isActive).length;
    final logs = _showDeleted ? inRange : inRange.where((l) => l.isActive).toList();
    final missionsDone = app.missions.where((m) {
      if (!m.isDone) return false;
      final w = cal.weekOf(m.completedAt!);
      return !w.isBefore(from) && w.isBefore(to);
    });

    // Task logs and completed missions, newest first.
    final entries = <(DateTime, Object)>[
      for (final l in logs) (l.doneAt, l),
      for (final m in missionsDone) (m.completedAt!, m),
      for (final b in app.revealedDays)
        if (!cal.weekOf(b.$2).isBefore(from) && cal.weekOf(b.$2).isBefore(to)) (b.$2, b),
    ]..sort((x, y) => y.$1.compareTo(x.$1));

    final today = cal.localDate(app.now);
    final children = <Widget>[];
    DateTime? day;
    for (final (at, entry) in entries) {
      final d = cal.localDate(at);
      if (d != day) {
        day = d;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Text(dayLabel(d, today).toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(color: s.muted, letterSpacing: 1)),
        ));
      }
      if (entry is (DateTime, DateTime, Answer, Answer)) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _BondTile(mine: entry.$3, theirs: entry.$4),
        ));
        continue;
      }
      if (entry is Mission) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _MissionTile(mission: entry),
        ));
        continue;
      }
      final log = entry as TaskLog;
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: log.isActive
            ? Dismissible(
                key: ValueKey(log.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _delete(log),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(color: Vivid.berry, borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
                ),
                child: _LogTile(log: log, onDelete: () => _delete(log)),
              )
            : _LogTile(log: log),
      ));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        Row(children: [
          for (final r in HistoryRange.values) ...[
            Expanded(
              child: ChunkyButton(
                label: r.label,
                compact: true,
                outlined: r != _range,
                color: Vivid.sky,
                onPressed: () => setState(() => _range = r),
              ),
            ),
            if (r != HistoryRange.values.last) const SizedBox(width: 8),
          ],
        ]),
        if (deletedCount > 0)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => _showDeleted = !_showDeleted),
              icon: Icon(_showDeleted ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
              label: Text(_showDeleted ? 'Hide deleted' : 'Show deleted ($deletedCount)'),
            ),
          ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(children: [
              const Text('🧹', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 8),
              Text('Nothing logged yet', style: theme.textTheme.titleMedium),
              Text('Tap "Hit the boss" when you finish a chore.', style: theme.textTheme.bodySmall),
            ]),
          ),
        ...children,
        if (entries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Swipe left or tap 🗑 to delete an entry.',
                textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log, this.onDelete});

  final TaskLog log;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final s = Surface.of(context);
    final members = app.household!.members;
    final cal = app.engine.calendar;
    final deleted = !log.isActive;
    final who = personColor(members, log.loggedBy);
    final details = [
      timeLabel(cal.localTime(log.doneAt)),
      if (log.isShared) 'with ${app.nameOf(log.sharedWith)}',
      if (log.isBackdated) 'logged later',
      if (log.task.isOther) 'no boss damage',
      if (deleted) 'deleted by ${app.nameOf(log.undoneBy)}',
    ];
    return Opacity(
      opacity: deleted ? 0.55 : 1,
      child: Raised(
        face: s.card,
        edge: s.line,
        border: s.line,
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(children: [
          EmojiBadge(log.task.category.emoji, color: who, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                log.displayName,
                style: theme.textTheme.titleSmall?.copyWith(
                  decoration: deleted ? TextDecoration.lineThrough : null,
                ),
              ),
              Text.rich(TextSpan(children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: PersonAvatar(userId: log.loggedBy, size: 18),
                  ),
                ),
                TextSpan(
                  text: app.nameOf(log.loggedBy),
                  style: theme.textTheme.bodySmall?.copyWith(color: who, fontWeight: FontWeight.w900),
                ),
                TextSpan(text: ' · ${details.join(' · ')}', style: theme.textTheme.bodySmall),
              ])),
            ]),
          ),
          Pill('+${log.task.points}', color: deleted ? s.muted : Vivid.grass),
          if (onDelete != null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded),
              color: s.muted,
              onPressed: onDelete,
            )
          else
            const SizedBox(width: 12),
        ]),
      ),
    );
  }
}

/// A completed mission in the feed: no points, just the win.
class _MissionTile extends StatelessWidget {
  const _MissionTile({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final s = Surface.of(context);
    final members = app.household!.members;
    final who = mission.completedBy;
    return Raised(
      face: Vivid.grape.withValues(alpha: 0.08),
      edge: Vivid.grape.withValues(alpha: 0.35),
      border: Vivid.grape.withValues(alpha: 0.35),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(children: [
        const EmojiBadge(missionsEmoji, color: Vivid.grape, size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(mission.title, style: theme.textTheme.titleSmall),
            Text.rich(TextSpan(children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: PersonAvatar(userId: who, size: 18),
                ),
              ),
              TextSpan(
                text: app.nameOf(who),
                style: theme.textTheme.bodySmall?.copyWith(color: personColor(members, who), fontWeight: FontWeight.w900),
              ),
              TextSpan(
                text: ' · ${timeLabel(app.engine.calendar.localTime(mission.completedAt!))} · mission complete',
                style: theme.textTheme.bodySmall,
              ),
            ])),
          ]),
        ),
        const Pill('Done', color: Vivid.grape),
        IconButton(
          tooltip: 'Reopen mission',
          icon: const Icon(Icons.undo_rounded),
          color: s.muted,
          onPressed: () async {
            try {
              await app.reopenMission(mission);
              if (context.mounted) showMessage(context, 'Mission reopened', color: Vivid.grape);
            } on BackendException catch (e) {
              if (context.mounted) showMessage(context, e.message, color: Vivid.berry);
            }
          },
        ),
      ]),
    );
  }
}

/// A revealed Bond day: both questions and answers.
class _BondTile extends StatelessWidget {
  const _BondTile({required this.mine, required this.theirs});

  final Answer mine;
  final Answer theirs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget qa(Answer a) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PersonAvatar(userId: a.userId, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.question.text, style: theme.textTheme.bodySmall),
                Text(a.text, style: theme.textTheme.titleSmall),
              ]),
            ),
          ]),
        );
    return Raised(
      face: Vivid.berry.withValues(alpha: 0.08),
      edge: Vivid.berry.withValues(alpha: 0.35),
      border: Vivid.berry.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const EmojiBadge('💞', color: Vivid.berry, size: 36),
          const SizedBox(width: 10),
          Expanded(child: Text('Bond questions revealed', style: theme.textTheme.titleSmall)),
          const Pill('+1 bond', color: Vivid.berry),
        ]),
        qa(mine),
        qa(theirs),
      ]),
    );
  }
}
