import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../data/backend.dart';
import '../domain/activity.dart';
import '../domain/stars.dart';
import '../state/app_controller.dart';
import '../state/health_sync.dart';
import 'common.dart';
import 'snap_screen.dart';

const _colors = {
  StarActivity.chores: Vivid.sky,
  StarActivity.steps: Vivid.grass,
  StarActivity.sleep: Vivid.grape,
  StarActivity.bedtime: Vivid.berry,
  StarActivity.snap: Vivid.flame,
};

/// Today's stars (and the last week's), per activity, for the couple and
/// each partner. Challenges will be built on these.
class StarsCard extends StatefulWidget {
  const StarsCard({super.key});

  @override
  State<StarsCard> createState() => _StarsCardState();
}

class _StarsCardState extends State<StarsCard> {
  /// 0 = today, 1 = yesterday, …
  int _dayIndex = 0;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final s = Surface.of(context);
    final days = app.recentStars;
    final day = days[_dayIndex];
    final isToday = _dayIndex == 0;

    return SectionCard(
      title: '⭐ Daily stars',
      trailing: Pill('${day.total} / ${day.max}', color: Vivid.sunShade, filled: true),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Every day, each activity earns your couple up to 3 stars.', style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        // Oldest on the left, today on the right.
        Row(children: [
          for (var i = days.length - 1; i >= 0; i--)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _dayIndex = i),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: i == _dayIndex ? Vivid.sun.withValues(alpha: 0.25) : null,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: i == _dayIndex ? Vivid.sunShade : s.line, width: 2),
                  ),
                  child: Column(children: [
                    Text(i == 0 ? 'Today' : DateFormat('EEE').format(days[i].day),
                        style: theme.textTheme.labelSmall?.copyWith(color: s.muted)),
                    Text('${days[i].total}',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w900, fontSize: 16, color: Vivid.sunShade)),
                  ]),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        for (final a in StarActivity.values) _ActivityRow(stars: day.activities[a]!, day: day.day, isToday: isToday),
      ]),
    );
  }
}

/// ★★☆ for 2 of 3.
class StarMeter extends StatelessWidget {
  const StarMeter(this.stars, {super.key, this.size = 20});

  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < maxStars; i++)
          Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size, color: i < stars ? Vivid.sun : Surface.of(context).line),
      ]);
}

String _stars(int n) => '⭐' * n;
final _num = NumberFormat.decimalPattern();
String _hm(int minutes) => '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m';

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.stars, required this.day, required this.isToday});

  final ActivityStars stars;
  final DateTime day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final s = Surface.of(context);
    final a = stars.activity;
    final (detail, hint) = _texts(app);
    final action = _action(context, app);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        EmojiBadge(a.emoji, color: _colors[a]!, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(a.label, style: theme.textTheme.titleSmall)),
              StarMeter(stars.stars),
            ]),
            if (detail != null) Text(detail, style: theme.textTheme.bodySmall),
            if (hint != null)
              Text(hint, style: theme.textTheme.bodySmall?.copyWith(color: s.muted, fontStyle: FontStyle.italic)),
            if (action != null) Padding(padding: const EdgeInsets.only(top: 6), child: action),
          ]),
        ),
      ]),
    );
  }

  /// "You ⭐⭐⭐ 9,200 · Sam ⭐ 4,000"
  String _people(AppController app, String Function(int value) fmt, {String missing = 'no data'}) {
    final parts = <String>[];
    for (final m in app.household!.members) {
      final v = stars.values[m.userId];
      final p = stars.personal[m.userId] ?? 0;
      final who = app.nameOf(m.userId);
      parts.add(v == null ? '$who $missing' : '$who ${p > 0 ? '${_stars(p)} ' : ''}${fmt(v)}');
    }
    return parts.join(' · ');
  }

  (String?, String?) _texts(AppController app) {
    final n = stars.stars;
    final needsPartner = app.partner == null;
    switch (stars.activity) {
      case StarActivity.chores:
        final tasks = stars.coupleValue ?? 0;
        final usual = stars.usual ?? 1;
        final usualText = usual == usual.roundToDouble() ? usual.toStringAsFixed(0) : usual.toStringAsFixed(1);
        String? hint;
        if (isToday) {
          final for2 = usual.floor() + 1, for3 = (usual + 2).ceil();
          hint = switch (n) {
            0 => 'Log a task for ⭐',
            1 => '${for2 - tasks} more for ⭐⭐',
            2 => '${for3 - tasks} more for ⭐⭐⭐',
            _ => null,
          };
        }
        return ('$tasks ${tasks == 1 ? 'task' : 'tasks'} · usual day: $usualText', hint);

      case StarActivity.steps:
        if (needsPartner) return ('Both partners need step data', null);
        String? hint;
        if (isToday && n < maxStars) {
          final target = stepTiers[n];
          final behind = [
            for (final m in app.household!.members)
              if ((stars.values[m.userId] ?? 0) < target)
                '${app.nameOf(m.userId)} ${_num.format(target - (stars.values[m.userId] ?? 0))} to go',
          ];
          hint = 'Both ${_num.format(target)} for ${_stars(n + 1)} · ${behind.join(', ')}';
        }
        return (_people(app, (v) => _num.format(v)), hint);

      case StarActivity.sleep:
        if (needsPartner) return ('Both partners need sleep data', null);
        return (
          _people(app, _hm),
          isToday ? (n < maxStars ? 'Last night · 7h each for ⭐⭐⭐' : 'Last night') : null,
        );

      case StarActivity.bedtime:
        if (needsPartner) return ('Both partners need sleep data', null);
        // Values are minutes after 6 pm the evening before.
        final evening = DateTime.utc(2000, 1, 1, 18);
        String clock(int v) => DateFormat.Hm().format(evening.add(Duration(minutes: v)));
        final gap = stars.coupleValue;
        final detail = stars.values.isEmpty
            ? 'When you each fell asleep, from Apple Health'
            : [
                for (final m in app.household!.members)
                  '${app.nameOf(m.userId)} ${stars.values[m.userId] == null ? 'no data' : clock(stars.values[m.userId]!)}',
              ].join(' · ');
        String? hint;
        if (gap != null) {
          final apart = gap < 60 ? '$gap min apart' : '${_hm(gap)} apart';
          hint = isToday && n < maxStars ? '$apart · within 1h for ⭐⭐⭐' : apart;
        }
        return (detail, hint);

      case StarActivity.snap:
        final open = !isToday || app.snapOpen;
        final detail = !open
            ? 'A surprise prompt arrives between $snapWindowStartHour:00 and $snapWindowEndHour:00'
            : _people(app, (v) => v < 60 ? '$v min' : _hm(v), missing: 'not yet');
        String? hint;
        if (isToday && open && n < maxStars) {
          final left = app.snapPromptToday.add(const Duration(hours: 1)).difference(app.now);
          hint = left.isNegative ? 'Both snap today for ⭐' : 'Both snap within ${left.inMinutes + 1} min for ⭐⭐⭐';
        }
        return (detail, hint);

    }
  }

  Widget? _action(BuildContext context, AppController app) {
    if (!isToday) {
      if (stars.activity == StarActivity.snap && stars.values.isNotEmpty) {
        return _SmallButton('See snaps', onPressed: () => openSnap(context, day: day));
      }
      return null;
    }
    switch (stars.activity) {
      case StarActivity.chores:
        return null;
      case StarActivity.sleep:
      case StarActivity.bedtime:
        return null; // one Apple Health button, on Steps, is enough
      case StarActivity.steps:
        if (!HealthSync.supported) return const _Note('Apple Health works in the iPhone app');
        if (app.health.connected) return null;
        return _SmallButton('Connect Apple Health', onPressed: () => _run(context, app.connectHealth));
      case StarActivity.snap:
        if (!app.snapOpen) return null;
        final mine = app.stars.snapOf(app.me, day);
        return _SmallButton(mine == null ? '📸 Snap now' : 'See snaps', onPressed: () => openSnap(context, day: day));
    }
  }

  static Future<void> _run(BuildContext context, Future<Object?> Function() body) async {
    try {
      await body();
    } on BackendException catch (e) {
      if (context.mounted) showMessage(context, e.message, color: Vivid.berry);
    }
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton(this.label, {required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: ChunkyButton(label: label, compact: true, color: Vivid.sky, onPressed: onPressed),
      );
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Surface.of(context).muted));
}

/// Shown by the snap screen and the stars card: what a snap is worth.
String snapTimingText(Duration since) => since <= snapTiers[1]
    ? 'Within the hour: ⭐⭐⭐'
    : since <= snapTiers[0]
        ? 'Within 2 hours: ⭐⭐'
        : 'Still counts: ⭐';

