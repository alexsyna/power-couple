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
/// out and the HP bar drains, then holds on a short celebration so the win
/// registers. Closes itself after ~5s, or on tap. Skipped when the
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
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4800))
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

  /// The action plays over the first part of the run; the rest is a hold on
  /// the result so the user can enjoy it.
  static const _actionShare = 0.58;

  /// Position within the action, 0→1 (stays at 1 during the hold).
  double get _t => (_c.value / _actionShare).clamp(0.0, 1.0);

  /// Position within the hold, 0→1.
  double get _hold => ((_c.value - _actionShare) / (1 - _actionShare)).clamp(0.0, 1.0);

  /// 0→1 over [a, b] of the action, eased.
  double _phase(double a, double b, [Curve curve = Curves.easeOut]) =>
      curve.transform(((_t - a) / (b - a)).clamp(0.0, 1.0));

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
            final impact = _t >= 0.3;
            final shake = impact && _t < 0.55 ? math.sin(_t * 70) * 8 * (1 - _phase(0.3, 0.55)) : 0.0;
            final burst = _phase(0.3, 0.55);
            final drain = _phase(0.35, 0.75, Curves.easeInOut);
            final damageNow = hit.damageBefore + (hit.damage * drain).round();
            final hpLeft = (hit.health - damageNow).clamp(0, hit.health);
            final float = _phase(0.32, 0.85);
            final defeatedNow = hit.defeated && drain >= 1;
            final confetti = _phase(0.3, 1.0, Curves.easeOutCubic);
            final cheer = _phase(0.8, 1.0, Curves.easeOutBack);

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
                        // Confetti bursting out of the boss.
                        if (impact)
                          for (var i = 0; i < 10; i++)
                            Transform.translate(
                              offset: Offset.fromDirection(
                                i * 2 * math.pi / 10 - math.pi / 2,
                                40 + 95 * confetti,
                              ).translate(0, 30 * confetti * confetti),
                              child: Opacity(
                                opacity: (1 - _hold).clamp(0.0, 1.0),
                                child: Transform.rotate(
                                  angle: confetti * 6 + i,
                                  child: Text(const ['🎉', '✨', '⭐'][i % 3], style: const TextStyle(fontSize: 22)),
                                ),
                              ),
                            ),
                        // Damage number floating up.
                        if (impact)
                          Positioned(
                            right: 30,
                            top: 30 - 40 * float,
                            child: Opacity(
                              // Stays up through the hold so the damage registers.
                              opacity: _phase(0.32, 0.4),
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
                    const SizedBox(height: 14),
                    Opacity(
                      opacity: cheer.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.6 + 0.4 * cheer,
                        child: Text(
                          defeatedNow ? 'Boss down! Legendary teamwork 🏆' : 'Great hit! −${hit.damage} HP 💪',
                          textAlign: TextAlign.center,
                          style: white.copyWith(fontSize: 20, color: Vivid.sun),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Opacity(
                      opacity: _phase(0.95, 1.0),
                      child: Text('Tap to continue',
                          style: white.copyWith(fontSize: 12, color: Colors.white.withValues(alpha: 0.75))),
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
