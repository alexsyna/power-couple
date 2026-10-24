import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../data/backend.dart';
import '../domain/catalog.dart';
import '../domain/models.dart';
import '../state/app_controller.dart';
import 'common.dart';

/// Opens the catalog. After a task is logged, shows the result (and an undo)
/// on the screen the user came from.
Future<void> openLogTask(BuildContext context) async {
  final message = await Navigator.of(context).push<_LogOutcome>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => const LogTaskScreen()),
  );
  if (message == null || !context.mounted) return;
  final app = AppScope.of(context);
  showMessage(
    context,
    message.text,
    color: Vivid.grass,
    action: SnackBarAction(
      label: 'Undo',
      onPressed: () async {
        try {
          await app.undo(message.log);
        } on BackendException catch (e) {
          if (context.mounted) showMessage(context, e.message, color: Vivid.berry);
        }
      },
    ),
  );
  if (message.bossDefeated != null && context.mounted) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Text('🏆', style: TextStyle(fontSize: 72)),
        title: Text('${message.bossDefeated} defeated!', textAlign: TextAlign.center),
        content: const Text('Amazing teamwork! This victory is saved in your weekly history.',
            textAlign: TextAlign.center),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ChunkyButton(label: 'Woohoo!', onPressed: () => Navigator.pop(context)),
          ),
        ],
      ),
    );
  }
}

class _LogOutcome {
  _LogOutcome(this.log, this.text, this.bossDefeated);
  final TaskLog log;
  final String text;
  final String? bossDefeated;
}

const _categoryColors = <TaskCategory, Color>{
  TaskCategory.shopping: Vivid.grass,
  TaskCategory.cooking: Vivid.flame,
  TaskCategory.kitchen: Vivid.sky,
  TaskCategory.laundry: Vivid.grape,
  TaskCategory.cleaning: Vivid.sky,
  TaskCategory.bathroom: Vivid.sky,
  TaskCategory.tidying: Vivid.sun,
  TaskCategory.maintenance: Vivid.flame,
  TaskCategory.planning: Vivid.grape,
  TaskCategory.supplies: Vivid.grass,
  TaskCategory.childcare: Vivid.berry,
  TaskCategory.pets: Vivid.sun,
  TaskCategory.other: Vivid.grape,
};

Color categoryColor(TaskCategory c) => _categoryColors[c] ?? Vivid.sky;

class LogTaskScreen extends StatefulWidget {
  const LogTaskScreen({super.key});

  @override
  State<LogTaskScreen> createState() => _LogTaskScreenState();
}

class _LogTaskScreenState extends State<LogTaskScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pick(TaskDef task) async {
    final outcome = await showModalBottomSheet<_LogOutcome>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ConfirmLogSheet(task: task, initialName: _query.trim()),
    );
    if (outcome != null && mounted) Navigator.pop(context, outcome);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final s = Surface.of(context);
    final tasks = app.visibleTasks;
    final q = _query.trim().toLowerCase();
    final matches = q.isEmpty
        ? tasks
        : tasks.where((t) => t.name.toLowerCase().contains(q) || t.category.label.toLowerCase().contains(q)).toList();
    final recent = app.recentTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('What did you do?'),
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            style: theme.textTheme.titleSmall,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Search tasks',
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () => setState(() {
                        _search.clear();
                        _query = '';
                      }),
                    ),
            ),
          ),
          if (q.isEmpty && recent.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('⚡ QUICK LOG', style: theme.textTheme.labelLarge?.copyWith(color: s.muted, letterSpacing: 1)),
            const SizedBox(height: 10),
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recent.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _RecentTile(task: recent[i], onTap: () => _pick(recent[i])),
              ),
            ),
          ],
          for (final cat in TaskCategory.values)
            if (matches.any((t) => t.category == cat)) ...[
              Padding(
                padding: const EdgeInsets.only(top: 22, bottom: 10),
                child: Row(children: [
                  EmojiBadge(cat.emoji, color: categoryColor(cat), size: 32),
                  const SizedBox(width: 10),
                  Text(cat.label.toUpperCase(),
                      style: theme.textTheme.labelLarge?.copyWith(color: s.muted, letterSpacing: 1)),
                ]),
              ),
              for (final t in matches.where((t) => t.category == cat))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => _pick(t),
                    child: Raised(
                      face: s.card,
                      edge: s.line,
                      border: s.line,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(t.name, style: theme.textTheme.titleSmall),
                            if (t.isOther) Text('Name it yourself · no boss damage', style: theme.textTheme.bodySmall),
                          ]),
                        ),
                        Pill('+${t.points}', color: Vivid.grass),
                      ]),
                    ),
                  ),
                ),
            ],
          if (matches.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Text('🔍', style: TextStyle(fontSize: 48)),
                Text('No matching task', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                ChunkyButton(
                  label: 'Log "${_query.trim()}" as Other',
                  color: Vivid.grape,
                  onPressed: () => _pick(taskById(otherTaskId)),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.task, required this.onTap});

  final TaskDef task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(task.category);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 112,
        child: Raised(
          face: color,
          edge: Vivid.shadeOf(color),
          padding: const EdgeInsets.all(10),
          child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(task.category.emoji, style: const TextStyle(fontSize: 28)),
            Text(task.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, height: 1.1)),
            Text('+${task.points}',
                style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

class _ConfirmLogSheet extends StatefulWidget {
  const _ConfirmLogSheet({required this.task, this.initialName = ''});

  final TaskDef task;

  /// Prefills Other's name from the catalog search.
  final String initialName;

  @override
  State<_ConfirmLogSheet> createState() => _ConfirmLogSheetState();
}

class _ConfirmLogSheetState extends State<_ConfirmLogSheet> {
  final _name = TextEditingController();
  bool _shared = false;

  /// Null means "now".
  DateTime? _doneAt;
  String? _error;
  bool _busy = false;

  TaskDef get task => widget.task;

  @override
  void initState() {
    super.initState();
    if (task.isOther) _name.text = widget.initialName;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickEarlier() async {
    final app = AppScope.of(context);
    final cal = app.engine.calendar;
    final today = cal.localDate(app.now);
    final date = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: app.engine.startDate,
      lastDate: today,
      helpText: 'When did you do it?',
    );
    if (date == null || !mounted) return;
    final local = cal.localTime(app.now);
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: local.hour, minute: local.minute),
    );
    if (time == null) return;
    setState(() {
      _doneAt = cal.instantAt(DateTime.utc(date.year, date.month, date.day), time.hour, time.minute);
      _error = null;
    });
  }

  Future<void> _submit() async {
    final app = AppScope.of(context);
    final customName = task.isOther ? _name.text.trim() : null;
    if (task.isOther && (customName == null || customName.isEmpty)) {
      setState(() => _error = 'Give your task a name.');
      return;
    }
    final doneAt = _doneAt ?? app.now;
    final check = app.check(task, doneAt);
    if (!check.allowed) {
      setState(() => _error = check.error);
      return;
    }
    final dup = check.duplicateOf;
    if (dup != null) {
      final who = app.nameOf(dup.loggedBy);
      final ok = await confirm(
        context,
        emoji: '👀',
        title: 'Already logged?',
        body: '${who == 'You' ? 'You' : who} logged ${task.name} '
            '${_ago(app.now.difference(dup.doneAt))}. Is this a separate time?',
        action: 'Log anyway',
      );
      if (!ok || !mounted) return;
    }

    final cal = app.engine.calendar;
    final weekStart = cal.weekOf(doneAt);
    final before = app.engine.week(weekStart, app.logs);
    setState(() => _busy = true);
    try {
      final log = await app.logTask(task, doneAt: doneAt, customName: customName, shared: _shared);
      final after = app.engine.week(weekStart, app.logs);
      final isCurrent = weekStart == cal.weekOf(app.now);
      final mine = log.pointsByPerson()[app.me] ?? 0;
      final parts = <String>[
        '+$mine pts${_shared ? ' (shared)' : ''} 🎉',
        if (isCurrent && task.countsForBoss) '${task.points} dmg to ${after.boss.name}',
        if (!isCurrent) 'added to week of ${weekLabel(weekStart)}',
        for (final (i, q) in after.quests.indexed)
          if (q.isComplete && !before.quests[i].isComplete) 'Quest complete: ${q.quest.name} +${q.quest.bonus}',
      ];
      final newlyDefeated = after.bossDefeated && !before.bossDefeated;
      if (mounted) {
        Navigator.pop(
          context,
          _LogOutcome(log, parts.join(' · '), newlyDefeated ? after.boss.name : null),
        );
      }
    } on BackendException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  static String _ago(Duration d) {
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    return '${d.inHours} h ago';
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final s = Surface.of(context);
    final partner = app.partner;
    final cal = app.engine.calendar;
    final doneAt = _doneAt;
    final pastWeek = doneAt != null && cal.weekOf(doneAt) != cal.weekOf(app.now);
    final myPoints = _shared ? (task.points + 1) ~/ 2 : task.points;
    final color = categoryColor(task.category);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            EmojiBadge(task.category.emoji, color: color, size: 60),
            const SizedBox(width: 14),
            Expanded(child: Text(task.name, style: theme.textTheme.titleLarge)),
            Pill('+${task.points}', color: Vivid.grass, filled: true),
          ]),
          if (task.isOther) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'What did you do?'),
            ),
            Text('Other tasks earn 10 pts for you and the team, but don\'t damage the boss or count for quests.',
                style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 18),
          if (partner != null)
            GestureDetector(
              onTap: () => setState(() => _shared = !_shared),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _shared ? Vivid.grape.withValues(alpha: 0.12) : null,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _shared ? Vivid.grape : s.line, width: 2),
                ),
                child: Row(children: [
                  const Text('🤝', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Did it together with ${partner.displayName}', style: theme.textTheme.titleSmall),
                      Text(
                        _shared
                            ? 'You get $myPoints, ${partner.displayName} gets ${task.points ~/ 2}. Team gets ${task.points}.'
                            : 'Split the points between you',
                        style: theme.textTheme.bodySmall,
                      ),
                    ]),
                  ),
                  Switch(value: _shared, onChanged: (v) => setState(() => _shared = v)),
                ]),
              ),
            ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: ChunkyButton(
                label: 'Now',
                compact: true,
                icon: const Icon(Icons.bolt_rounded),
                color: Vivid.sky,
                outlined: doneAt != null,
                onPressed: () => setState(() => _doneAt = null),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ChunkyButton(
                label: doneAt == null ? 'Earlier…' : DateFormat('EEE d MMM HH:mm').format(cal.localTime(doneAt)),
                compact: true,
                icon: const Icon(Icons.history_rounded),
                color: Vivid.sky,
                outlined: doneAt == null,
                onPressed: _pickEarlier,
              ),
            ),
          ]),
          if (pastWeek) ...[
            const SizedBox(height: 8),
            Text('This counts toward the week of ${weekLabel(cal.weekOf(doneAt))}. '
                'That week\'s boss, quests and streak will be recalculated.',
                style: theme.textTheme.bodySmall),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: theme.textTheme.titleSmall?.copyWith(color: Vivid.berry)),
          ],
          const SizedBox(height: 20),
          ChunkyButton(
            label: _busy ? 'Saving…' : 'Log it · +$myPoints pts',
            busy: _busy,
            icon: const Icon(Icons.check_rounded),
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
