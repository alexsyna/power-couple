import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/badges.dart';
import '../state/app_controller.dart';
import 'common.dart';

/// Every badge: unlocked ones in colour, locked ones greyed with progress.
/// Tapping one explains exactly how to unlock it.
class BadgesCard extends StatelessWidget {
  const BadgesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = AppScope.of(context).badgeProgress;
    final unlocked = progress.where((p) => p.unlocked).length;
    return SectionCard(
      title: '🎖️ Badges',
      trailing: Pill('$unlocked / ${progress.length}', color: Vivid.sun, filled: unlocked > 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Tap a badge to see how to unlock it.', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, c) {
          const gap = 10.0;
          final w = (c.maxWidth - gap * 2) / 3;
          return Wrap(spacing: gap, runSpacing: 14, children: [
            for (final p in progress) SizedBox(width: w, child: _BadgeTile(progress: p)),
          ]);
        }),
      ]),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.progress});

  final BadgeProgress progress;

  @override
  Widget build(BuildContext context) {
    final s = Surface.of(context);
    final b = progress.badge;
    final on = progress.unlocked;
    return GestureDetector(
      onTap: () => _showBadge(context, progress),
      child: Column(children: [
        _Medal(emoji: b.emoji, unlocked: on, size: 64),
        const SizedBox(height: 6),
        Text(
          b.name,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            height: 1.1,
            color: on ? s.ink : s.muted,
          ),
        ),
        const SizedBox(height: 4),
        if (on)
          const Pill('Unlocked', color: Vivid.grass)
        else ...[
          ProgressBar(value: progress.fraction, height: 8, color: Vivid.sun),
          const SizedBox(height: 2),
          Text('${fmtInt(progress.value)}/${fmtInt(b.target)}',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 11, color: s.muted)),
        ],
      ]),
    );
  }
}

/// Round medal: gold when unlocked, grey with a padlock when locked.
class _Medal extends StatelessWidget {
  const _Medal({required this.emoji, required this.unlocked, required this.size});

  final String emoji;
  final bool unlocked;
  final double size;

  static const _grey = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 0.45, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final s = Surface.of(context);
    final face = Text(emoji, style: TextStyle(fontSize: size * 0.48));
    return Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
      Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: unlocked ? Vivid.sun : s.line.withValues(alpha: 0.6),
          shape: BoxShape.circle,
          border: Border.all(color: unlocked ? Vivid.sunShade : s.line, width: 4),
        ),
        child: unlocked ? face : ColorFiltered(colorFilter: _grey, child: face),
      ),
      if (!unlocked)
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: size * 0.36,
            height: size * 0.36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: s.card, shape: BoxShape.circle, border: Border.all(color: s.line, width: 2)),
            child: Text('🔒', style: TextStyle(fontSize: size * 0.17)),
          ),
        ),
    ]);
  }
}

void _showBadge(BuildContext context, BadgeProgress p) {
  final b = p.badge;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      return Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 32 + MediaQuery.viewPaddingOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _Medal(emoji: b.emoji, unlocked: p.unlocked, size: 104),
          const SizedBox(height: 14),
          Text(b.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Pill(p.unlocked ? 'Unlocked! 🎉' : 'Locked', color: p.unlocked ? Vivid.grass : Vivid.flame, filled: true),
          const SizedBox(height: 14),
          Text(b.condition, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          ProgressBar(value: p.fraction, height: 18, color: p.unlocked ? Vivid.grass : Vivid.sun),
          const SizedBox(height: 6),
          Text(
            p.unlocked ? 'Completed' : '${fmtInt(p.value)} of ${fmtInt(b.target)} · ${fmtInt(b.target - p.value)} to go',
            style: theme.textTheme.bodySmall,
          ),
        ]),
      );
    },
  );
}
