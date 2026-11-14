import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../data/backend.dart';
import '../domain/activity.dart';
import '../domain/missions.dart' show dateKey;
import '../state/app_controller.dart';
import 'common.dart';
import 'stars_card.dart';

Future<void> openSnap(BuildContext context, {DateTime? day}) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SnapScreen(day: day)),
    );

/// The day's Snap moment: the prompt, and both partners' photos. My
/// partner's photo stays hidden until I've snapped mine.
class SnapScreen extends StatefulWidget {
  const SnapScreen({super.key, this.day});

  /// Defaults to today.
  final DateTime? day;

  @override
  State<SnapScreen> createState() => _SnapScreenState();
}

class _SnapScreenState extends State<SnapScreen> {
  bool _busy = false;

  /// Camera only: a photo from the gallery could be from any time.
  static bool get cameraAvailable => !kIsWeb;

  Future<void> _snap() async {
    final app = AppScope.of(context);
    setState(() => _busy = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1440,
        maxHeight: 1440,
        imageQuality: 75,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      await app.takeSnap(bytes);
      if (mounted) showMessage(context, '📸 Snapped!', color: Vivid.grass);
    } on BackendException catch (e) {
      if (mounted) showMessage(context, e.message, color: Vivid.berry);
    } catch (_) {
      if (mounted) showMessage(context, 'Couldn\'t open the camera.', color: Vivid.berry);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final s = Surface.of(context);
    final day = widget.day ?? app.today;
    final isToday = day == app.today;
    final calc = app.stars;
    final prompt = calc.snapPromptAt(day);
    final text = snapPromptText(app.household!.id, dateKey(day));
    final mine = calc.snapOf(app.me, day);
    final partner = app.partner;
    final theirs = partner == null ? null : calc.snapOf(partner.userId, day);
    final open = !app.now.isBefore(prompt);
    final result = calc.snap(day);
    final local = app.engine.calendar.localTime(prompt);

    return Scaffold(
      appBar: AppBar(title: Text(isToday ? 'Snap moment' : DateFormat('EEE d MMM').format(day))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        SectionCard(
          child: Column(children: [
            const Text('📸', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 4),
            Text(open ? text : 'Today\'s prompt is still a surprise',
                style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              open ? 'Prompt at ${DateFormat.Hm().format(local)}' : 'It arrives between $snapWindowStartHour:00 and $snapWindowEndHour:00',
              style: theme.textTheme.bodySmall?.copyWith(color: s.muted),
            ),
            const SizedBox(height: 10),
            StarMeter(result.stars, size: 28),
            if (isToday && open && mine == null) ...[
              const SizedBox(height: 4),
              Text(snapTimingText(app.now.difference(prompt)), style: theme.textTheme.titleSmall),
            ],
          ]),
        ),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: _PhotoTile(
              name: 'You',
              snap: mine,
              prompt: prompt,
              empty: isToday && open
                  ? (cameraAvailable
                      ? ChunkyButton(label: 'Snap', icon: const Text('📸'), busy: _busy, compact: true, onPressed: _snap)
                      : Text('Snap from the iPhone app', style: theme.textTheme.bodySmall, textAlign: TextAlign.center))
                  : Text(isToday ? 'Wait for the prompt' : 'Missed', style: theme.textTheme.bodySmall),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PhotoTile(
              name: partner?.displayName ?? 'Partner',
              snap: theirs,
              prompt: prompt,
              // Hidden until I've snapped too, like Bond answers.
              hidden: mine == null && theirs != null,
              empty: Text(isToday ? 'Not yet' : 'Missed', style: theme.textTheme.bodySmall),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Text(
          'Both snap within an hour of the prompt for ⭐⭐⭐, within 2 hours for ⭐⭐, or any time that day for ⭐. '
          'Photos come from the camera only.',
          style: theme.textTheme.bodySmall?.copyWith(color: s.muted),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.name, required this.snap, required this.prompt, required this.empty, this.hidden = false});

  final String name;
  final Snap? snap;
  final DateTime prompt;
  final Widget empty;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final s = Surface.of(context);
    final snap = this.snap;
    Widget body;
    if (snap == null) {
      body = Center(child: Padding(padding: const EdgeInsets.all(12), child: empty));
    } else if (hidden) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🙈', style: TextStyle(fontSize: 36)),
          Text('Snapped! Snap yours to see it', style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
        ]),
      );
    } else {
      body = FutureBuilder<Uint8List?>(
        future: app.snapPhoto(snap),
        builder: (context, f) {
          final bytes = f.data;
          if (bytes != null) return Image.memory(bytes, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
          if (f.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          return const Center(child: Text('📷', style: TextStyle(fontSize: 36)));
        },
      );
    }
    final mins = snap?.takenAt.difference(prompt).inMinutes;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AspectRatio(
        aspectRatio: 3 / 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: s.card,
              border: Border.all(color: s.line, width: 2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: body,
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(name, style: theme.textTheme.titleSmall, textAlign: TextAlign.center),
      if (mins != null)
        Text(mins < 60 ? '$mins min after the prompt' : '${mins ~/ 60}h ${mins % 60}m after',
            style: theme.textTheme.bodySmall?.copyWith(color: s.muted), textAlign: TextAlign.center),
    ]);
  }
}
