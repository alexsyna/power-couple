import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/backend.dart';
import '../domain/missions.dart';
import '../state/app_controller.dart';
import 'common.dart';

/// What the shared to-do list is called in the app.
const missionsTitle = 'Legendary Missions';
const missionsEmoji = '🛡️';

/// Due-date label and colour, e.g. "2 days late" in red.
(String, Color) dueLabel(Mission m, DateTime today) {
  final d = m.daysLeft(today);
  if (d < 0) return (d == -1 ? '1 day late' : '${-d} days late', Vivid.berry);
  if (d == 0) return ('Today', Vivid.flame);
  if (d == 1) return ('Tomorrow', Vivid.sunShade);
  if (d < 7) return ('In $d days', Vivid.sky);
  return (DateFormat('d MMM').format(m.dueOn), Vivid.sky);
}

Future<void> _guard(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } on BackendException catch (e) {
    if (context.mounted) showMessage(context, e.message, color: Vivid.berry);
  }
}

Future<void> completeWithUndo(BuildContext context, Mission m) async {
  final app = AppScope.of(context);
  await _guard(context, () => app.completeMission(m));
  if (!context.mounted) return;
  final done = app.missions.firstWhere((x) => x.id == m.id, orElse: () => m);
  showMessage(
    context,
    'Mission complete! $missionsEmoji ${m.title}',
    color: Vivid.grape,
    action: SnackBarAction(label: 'Undo', onPressed: () => _guard(context, () => app.reopenMission(done))),
  );
}

/// Home-screen card listing open missions, below the quests.
class MissionsCard extends StatelessWidget {
  const MissionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final open = openMissions(app.missions);
    return SectionCard(
      title: '$missionsEmoji $missionsTitle',
      trailing: SizedBox(
        width: 96,
        child: ChunkyButton(
          label: 'New',
          compact: true,
          color: Vivid.grape,
          icon: const Icon(Icons.add_rounded),
          onPressed: () => openMissionEditor(context),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('One-off jobs for either of you. No points, just glory.', style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        if (open.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(children: [
              const Text('🏰', style: TextStyle(fontSize: 40)),
              Text('No missions yet', style: theme.textTheme.titleSmall),
              Text('Add something like "Fix the shelf" with a due date.', style: theme.textTheme.bodySmall),
            ]),
          ),
        for (final m in open) ...[
          _MissionRow(mission: m),
          if (m != open.last) const SizedBox(height: 10),
        ],
      ]),
    );
  }
}

class _MissionRow extends StatelessWidget {
  const _MissionRow({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final s = Surface.of(context);
    final (due, dueColor) = dueLabel(mission, app.today);
    final assignee = mission.assignee;
    final members = app.household!.members;
    final mine = assignee == app.me;

    return GestureDetector(
      onTap: () => openMissionSheet(context, mission),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: mission.isOverdue(app.today) ? Vivid.berry : s.line, width: 2),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(mission.title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Pill('📅 $due', color: dueColor),
                if (assignee == null)
                  Pill('Up for grabs', color: s.muted)
                else
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    PersonAvatar(userId: assignee, size: 22),
                    const SizedBox(width: 4),
                    Text(mine ? 'You' : app.nameOf(assignee),
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: personColor(members, assignee), fontWeight: FontWeight.w900)),
                  ]),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          if (assignee == null)
            SizedBox(
              width: 80,
              child: ChunkyButton(
                label: 'Pick',
                compact: true,
                color: Vivid.grape,
                onPressed: () => _guard(context, () => app.toggleMissionPickup(mission)),
              ),
            )
          else
            IconButton.filled(
              tooltip: 'Mark done',
              style: IconButton.styleFrom(backgroundColor: Vivid.grass, foregroundColor: Colors.white),
              icon: const Icon(Icons.check_rounded),
              onPressed: () => completeWithUndo(context, mission),
            ),
        ]),
      ),
    );
  }
}

/// Detail sheet: complete, pick up / drop, edit or delete.
Future<void> openMissionSheet(BuildContext context, Mission mission) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final app = AppScope.of(sheetContext);
        final theme = Theme.of(sheetContext);
        final m = app.missions.firstWhere((x) => x.id == mission.id, orElse: () => mission);
        final (due, dueColor) = dueLabel(m, app.today);
        final mine = m.assignee == app.me;
        void close() => Navigator.pop(sheetContext);
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 28 + MediaQuery.viewPaddingOf(sheetContext).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const EmojiBadge(missionsEmoji, color: Vivid.grape, size: 56),
              const SizedBox(width: 14),
              Expanded(child: Text(m.title, style: theme.textTheme.titleLarge)),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 6, children: [
              Pill('📅 Due ${DateFormat('EEE d MMM').format(m.dueOn)} · $due', color: dueColor),
              Pill(m.assignee == null ? 'Up for grabs' : 'Picked by ${mine ? 'you' : app.nameOf(m.assignee)}',
                  color: Vivid.grape),
              if (m.createdBy != null) Pill('Added by ${app.nameOf(m.createdBy)}', color: Vivid.sky),
            ]),
            const SizedBox(height: 20),
            ChunkyButton(
              label: 'Mark as done',
              icon: const Icon(Icons.check_rounded),
              onPressed: () {
                close();
                completeWithUndo(context, m);
              },
            ),
            const SizedBox(height: 10),
            ChunkyButton(
              label: m.assignee == null
                  ? 'Pick it up'
                  : mine
                      ? 'Drop it'
                      : 'Take it over',
              outlined: true,
              color: Vivid.grape,
              icon: Icon(mine ? Icons.back_hand_outlined : Icons.pan_tool_alt_rounded),
              onPressed: () {
                close();
                // Taking over a partner's mission assigns it to me.
                _guard(context, () => mine || m.assignee == null
                    ? app.toggleMissionPickup(m)
                    : app.saveMission(m.copyWith(assignee: () => app.me)));
              },
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: ChunkyButton(
                  label: 'Edit',
                  outlined: true,
                  color: Vivid.sky,
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: () {
                    close();
                    openMissionEditor(context, existing: m);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChunkyButton(
                  label: 'Delete',
                  outlined: true,
                  color: Vivid.berry,
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () async {
                    close();
                    await confirmDeleteMission(context, m);
                  },
                ),
              ),
            ]),
          ]),
        );
      },
    );

Future<bool> confirmDeleteMission(BuildContext context, Mission m) async {
  final app = AppScope.of(context);
  final ok = await confirm(
    context,
    emoji: '🗑️',
    title: 'Delete "${m.title}"?',
    body: 'It disappears for both of you.',
    action: 'Delete',
    destructive: true,
  );
  if (!ok || !context.mounted) return false;
  await _guard(context, () => app.deleteMission(m));
  if (context.mounted) showMessage(context, 'Mission deleted', color: Vivid.berry);
  return true;
}

/// Create or edit a mission.
/// [forPartner] pre-selects the partner as the one doing it.
Future<void> openMissionEditor(BuildContext context, {Mission? existing, bool forPartner = false}) =>
    // Full screen with a close button, like the "Hit the boss" screen.
    Navigator.of(context).push<void>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _MissionEditor(existing: existing, forPartner: forPartner),
    ));

class _MissionEditor extends StatefulWidget {
  const _MissionEditor({this.existing, this.forPartner = false});

  final Mission? existing;
  final bool forPartner;

  @override
  State<_MissionEditor> createState() => _MissionEditorState();
}

class _MissionEditorState extends State<_MissionEditor> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  DateTime? _due;

  /// Who should do it; null means anyone.
  String? _assignee;
  bool _assigneeSet = false;
  String? _error;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    _due ??= widget.existing?.dueOn ?? addDaysUtc(app.today, 1);
    if (!_assigneeSet) {
      _assigneeSet = true;
      _assignee = widget.existing != null
          ? widget.existing!.assignee
          : widget.forPartner
              ? app.partner?.userId
              : null;
    }
  }

  static DateTime addDaysUtc(DateTime d, int n) => DateTime.utc(d.year, d.month, d.day + n);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = AppScope.of(context).today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _due!.isBefore(today) ? today : _due!,
      firstDate: _due!.isBefore(today) ? _due! : today,
      lastDate: addDaysUtc(today, 365 * 2),
      helpText: 'Due date',
    );
    if (picked != null) setState(() => _due = DateTime.utc(picked.year, picked.month, picked.day));
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give your mission a name.');
      return;
    }
    final app = AppScope.of(context);
    setState(() => _busy = true);
    try {
      final existing = widget.existing;
      if (existing == null) {
        await app.createMission(title, _due!, assignee: _assignee);
      } else {
        await app.saveMission(existing.copyWith(title: title, dueOn: _due, assignee: () => _assignee));
      }
      if (mounted) Navigator.pop(context);
    } on BackendException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit mission' : 'New mission'),
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
        Row(children: [
          const EmojiBadge(missionsEmoji, color: Vivid.grape, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Text('A one-off job for either of you. No points, just glory.',
                style: theme.textTheme.bodyMedium),
          ),
        ]),
        const SizedBox(height: 20),
        TextField(
          controller: _title,
          autofocus: !editing,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'What needs doing?', hintText: 'e.g. Fix the wobbly shelf'),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 4),
        ChunkyButton(
          label: 'Due ${DateFormat('EEE d MMM').format(_due!)}',
          outlined: true,
          color: Vivid.sky,
          icon: const Icon(Icons.event_rounded),
          onPressed: _pickDate,
        ),
        const SizedBox(height: 14),
        Text('WHO WILL DO IT?', style: theme.textTheme.labelLarge?.copyWith(letterSpacing: 1)),
        const SizedBox(height: 8),
        _AssigneePicker(value: _assignee, onChanged: (v) => setState(() => _assignee = v)),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: theme.textTheme.titleSmall?.copyWith(color: Vivid.berry)),
        ],
        const SizedBox(height: 16),
        ChunkyButton(
          label: editing ? 'Save' : 'Add mission',
          color: Vivid.grape,
          busy: _busy,
          icon: const Icon(Icons.check_rounded),
          onPressed: _save,
        ),
      ]),
    );
  }
}

/// Partner / Me / Anyone choice for a mission.
class _AssigneePicker extends StatelessWidget {
  const _AssigneePicker({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final partner = app.partner;
    final options = <(String?, String)>[
      if (partner != null) (partner.userId, partner.displayName),
      (app.me, 'Me'),
      (null, 'Anyone'),
    ];
    return Row(children: [
      for (final (i, (id, label)) in options.indexed) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: ChunkyButton(
            label: label,
            compact: true,
            color: Vivid.grape,
            outlined: value != id,
            onPressed: () => onChanged(id),
          ),
        ),
      ],
    ]);
  }
}
