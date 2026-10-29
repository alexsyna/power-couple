import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/content.dart';
import 'common.dart';

/// What a just-logged task did to this week's boss.
class BossHit {
  const BossHit({
    required this.boss,
    required this.health,
    required this.damageBefore,
    required this.damageAfter,
    required this.projectile,
  });

  final BossDef boss;
  final int health;
  final int damageBefore;
  final int damageAfter;

  /// Emoji that flies at the boss (the task's category).
  final String projectile;

  int get damage => damageAfter - damageBefore;
  bool get defeated => damageAfter >= health;
}

/// Plays the hit: the task flies at the boss, it shakes, the damage pops
/// out and the HP bar drains. Closes itself, or on tap. Skipped when the
/// user has asked the system to reduce motion.
Future<void> showBossHit(BuildContext context, BossHit hit) async {
  if (MediaQuery.disableAnimationsOf(context)) return;
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, _, _) => _BossHitView(hit),
    transitionBuilder: (_, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(animation), child: child),
    ),
  );
}

class _BossHitView extends StatefulWidget {
  const _BossHitView(this.hit);

  final BossHit hit;

  @override
  State<_BossHitView> createState() => _BossHitViewState();
}

class _BossHitViewState extends State<_BossHitView> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _close();
    })
    ..forward();
  bool _closed = false;

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 0→1 over [a, b] of the timeline, eased.
  double _phase(double a, double b, [Curve curve = Curves.easeOut]) =>
      curve.transform(((_c.value - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final hit = widget.hit;
    const color = Vivid.grape;
    final white = GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w900);
    return GestureDetector(
      onTap: _close,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final fly = _phase(0.0, 0.3, Curves.easeIn);
            final impact = _c.value >= 0.3;
            final shake = impact && _c.value < 0.55 ? math.sin(_c.value * 120) * 8 * (1 - _phase(0.3, 0.55)) : 0.0;
            final burst = _phase(0.3, 0.55);
            final drain = _phase(0.35, 0.75, Curves.easeInOut);
            final damageNow = hit.damageBefore + (hit.damage * drain).round();
            final hpLeft = (hit.health - damageNow).clamp(0, hit.health);
            final float = _phase(0.32, 0.85);
            final defeatedNow = hit.defeated && drain >= 1;

            return SizedBox(
              width: 320,
              child: Raised(
                face: defeatedNow ? Vivid.grass : color,
                edge: Vivid.shadeOf(defeatedNow ? Vivid.grass : color),
                padding: const EdgeInsets.all(20),
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Pill(defeatedNow ? 'DEFEATED!' : 'DIRECT HIT!', color: Vivid.shadeOf(color), filled: true),
                    const SizedBox(height: 6),
                    Text(hit.boss.name, textAlign: TextAlign.center, style: white.copyWith(fontSize: 22)),
                    SizedBox(
                      height: 190,
                      child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                        // The boss, shaking on impact.
                        Transform.translate(
                          offset: Offset(shake, 0),
                          child: Container(
                            width: 110,
                            height: 110,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Color.lerp(Colors.white, Vivid.berry, impact ? 0.35 * (1 - burst) : 0),
                              shape: BoxShape.circle,
                              border: Border.all(color: Vivid.shadeOf(color), width: 5),
                            ),
                            child: Text(defeatedNow ? '🏆' : hit.boss.emoji, style: const TextStyle(fontSize: 60)),
                          ),
                        ),
                        // The chore, thrown from below.
                        if (!impact)
                          Transform.translate(
                            offset: Offset(0, 110 * (1 - fly)),
                            child: Transform.rotate(
                              angle: fly * 4 * math.pi,
                              child: Text(hit.projectile, style: TextStyle(fontSize: 34 + 10 * fly)),
                            ),
                          ),
                        // Impact burst.
                        if (impact && burst < 1)
                          Opacity(
                            opacity: 1 - burst,
                            child: Transform.scale(
                              scale: 0.5 + 1.2 * burst,
                              child: const Text('💥', style: TextStyle(fontSize: 90)),
                            ),
                          ),
                        // Damage number floating up.
                        if (impact)
                          Positioned(
                            right: 30,
                            top: 30 - 40 * float,
                            child: Opacity(
                              opacity: (1 - _phase(0.75, 1.0)).clamp(0.0, 1.0),
                              child: Text(
                                '-${hit.damage}',
                                style: GoogleFonts.nunito(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  shadows: const [Shadow(color: Vivid.berryShade, offset: Offset(0, 3))],
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ),
                    ProgressBar(
                      value: 1 - hpLeft / hit.health,
                      height: 20,
                      color: defeatedNow ? Vivid.sun : Vivid.berry,
                      track: Vivid.shadeOf(defeatedNow ? Vivid.grass : color),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      defeatedNow ? 'Victory! 🎉' : '❤️ ${fmtInt(hpLeft)} HP left',
                      style: white.copyWith(fontSize: 16),
                    ),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
