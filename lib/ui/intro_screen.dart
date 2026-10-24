import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'common.dart';
import 'logo.dart';

/// First-launch walkthrough shown before sign-in. Each slide has a small
/// looping scene drawn with emoji and transforms, so no image assets needed.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.onDone, this.replay = false});

  /// Called with true for "Get started" (new account), false for "sign in".
  final ValueChanged<bool> onDone;

  /// Rewatching from Settings while signed in: no account buttons.
  final bool replay;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _Slide {
  const _Slide(this.title, this.body, this.color, this.scene);
  final String title;
  final String body;
  final Color color;
  final Widget scene;
}

const _slides = [
  _Slide(
    'Turn housework into epic quests',
    'Every chore you finish is a move in your shared adventure.',
    Vivid.flame,
    _CookingScene(),
  ),
  _Slide(
    'Power-up for battle',
    'Stock the fridge, mop the beast, conquer the laundry pile. Every action protects your kingdom!',
    Vivid.grass,
    _ShoppingScene(),
  ),
  _Slide(
    'Beat the weekly boss together',
    'Every task hits this week\'s monster. Defeat it by Sunday to keep your win streak alive.',
    Vivid.grape,
    _BossScene(),
  ),
  _Slide(
    'Missions, badges and glory',
    'Assign missions to each other, complete quests and unlock achievements as a team.',
    Vivid.sun,
    _RewardsScene(),
  ),
];

class _IntroScreenState extends State<IntroScreen> {
  final _pages = PageController();
  int _page = 0;

  bool get _last => _page == _slides.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_last) {
      widget.onDone(true);
    } else {
      _pages.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = Surface.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
            child: Row(children: [
              const PowerCoupleLogo(size: 36),
              const SizedBox(width: 10),
              Text('Power Couple', style: theme.textTheme.titleMedium),
              const Spacer(),
              // Keeps its space on the last slide so the header doesn't jump.
              Visibility.maintain(
                visible: !_last,
                child: TextButton(onPressed: () => widget.onDone(true), child: const Text('Skip')),
              ),
            ]),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final slide = _slides[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(children: [
                    Expanded(child: Center(child: _SceneFrame(color: slide.color, child: slide.scene))),
                    Text(slide.title, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 10),
                    Text(
                      slide.body,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(color: s.muted, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 24),
                  ]),
                );
              },
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < _slides.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _page ? 28 : 10,
                height: 10,
                decoration: BoxDecoration(
                  color: i == _page ? _slides[_page].color : s.line,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: SizedBox(
              width: double.infinity,
              child: ChunkyButton(label: _last ? (widget.replay ? "Let's go!" : 'Get started') : 'Continue', onPressed: _next),
            ),
          ),
          Visibility.maintain(
            visible: !widget.replay,
            child: TextButton(
              onPressed: () => widget.onDone(false),
              child: const Text('I already have an account'),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

/// Round tinted stage behind each scene.
class _SceneFrame extends StatelessWidget {
  const _SceneFrame({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final size = math.min(320.0, math.min(c.maxWidth, c.maxHeight));
        return SizedBox.square(
          dimension: size,
          child: Stack(children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(size * 0.1),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.18), shape: BoxShape.circle),
                ),
              ),
            ),
            Positioned.fill(child: child),
          ]),
        );
      });
}

// ---------------------------------------------------------------- scene kit

/// Rebuilds [builder] with t running 0→1 on repeat.
class _Loop extends StatefulWidget {
  const _Loop({required this.period, required this.builder});

  final Duration period;
  final Widget Function(double t, double size) builder;

  @override
  State<_Loop> createState() => _LoopState();
}

class _LoopState extends State<_Loop> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => AnimatedBuilder(
          animation: _c,
          builder: (_, _) => widget.builder(_c.value, box.maxWidth),
        ),
      );
}

/// An emoji centred on (x, y).
Widget _emoji(String e, double x, double y, double size,
    {double rotation = 0, double scale = 1, double opacity = 1}) {
  return Positioned(
    left: x - size,
    top: y - size,
    width: size * 2,
    height: size * 2,
    child: Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.rotate(
        angle: rotation,
        child: Transform.scale(
          scale: scale,
          child: Center(child: Text(e, style: TextStyle(fontSize: size, height: 1))),
        ),
      ),
    ),
  );
}

/// 0→1 over [a, b], clamped, eased.
double _phase(double t, double a, double b) => Curves.easeInOut.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

double _wave(double t, [double cycles = 1]) => math.sin(t * 2 * math.pi * cycles);

// ---------------------------------------------------------------- scenes

/// A chef bobbing while a pancake flips out of the pan and steam rises.
class _CookingScene extends StatelessWidget {
  const _CookingScene();

  @override
  Widget build(BuildContext context) => _Loop(
        period: const Duration(milliseconds: 2400),
        builder: (t, s) {
          final flip = _phase(t, 0.1, 0.7);
          final jump = 4 * flip * (1 - flip); // parabola 0→1→0
          final panX = s * 0.66, panY = s * 0.66;
          return Stack(children: [
            _emoji('🧑‍🍳', s * 0.36, s * 0.48 + _wave(t, 2) * 5, s * 0.3),
            for (var i = 0; i < 3; i++)
              () {
                final p = (t + i / 3) % 1;
                return _emoji('💨', panX - s * 0.04 + _wave(p) * 8, panY - s * 0.12 - p * s * 0.28, s * 0.07,
                    opacity: 1 - p, rotation: -math.pi / 2);
              }(),
            _emoji('🥞', panX, panY - s * 0.06 - jump * s * 0.3, s * 0.11, rotation: flip * 2 * math.pi),
            _emoji('🍳', panX, panY, s * 0.18, rotation: -0.15 * jump),
            _emoji('✨', s * 0.2, s * 0.22, s * 0.07, opacity: 0.5 + 0.5 * _wave(t)),
            _emoji('✨', s * 0.82, s * 0.3, s * 0.06, opacity: 0.5 - 0.5 * _wave(t)),
          ]);
        },
      );
}

/// Groceries dropping one by one into a bouncing cart, then points pop up.
class _ShoppingScene extends StatelessWidget {
  const _ShoppingScene();

  static const _items = ['🥦', '🥖', '🥛', '🍎'];

  @override
  Widget build(BuildContext context) => _Loop(
        period: const Duration(milliseconds: 3200),
        builder: (t, s) {
          final cartX = s * 0.5, cartY = s * 0.68;
          var bounce = 0.0;
          final children = <Widget>[];
          for (var i = 0; i < _items.length; i++) {
            final start = 0.05 + i * 0.16;
            final p = ((t - start) / 0.16).clamp(0.0, 1.0);
            if (t >= start && p < 1) {
              final y = s * 0.08 + Curves.easeIn.transform(p) * (cartY - s * 0.14 - s * 0.08);
              children.add(_emoji(_items[i], cartX + (i - 1.5) * s * 0.06, y, s * 0.1, rotation: p * math.pi));
            }
            // Little squash right after each item lands.
            final since = t - (start + 0.16);
            if (since >= 0 && since < 0.06) bounce = math.sin(since / 0.06 * math.pi) * 6;
          }
          final pop = _phase(t, 0.72, 0.85);
          final fade = 1 - _phase(t, 0.9, 1.0);
          return Stack(children: [
            ...children,
            _emoji('🛒', cartX, cartY + bounce, s * 0.26),
            if (t > 0.72)
              Positioned(
                left: 0,
                right: 0,
                top: s * 0.2 - pop * s * 0.06,
                child: Opacity(
                  opacity: fade,
                  child: Transform.scale(
                    scale: 0.6 + 0.4 * pop,
                    child: Center(child: Pill('+50 pts', color: Vivid.grass, filled: true)),
                  ),
                ),
              ),
          ]);
        },
      );
}

/// Two heroes fire bolts at the boss; it shakes and its HP drains.
class _BossScene extends StatelessWidget {
  const _BossScene();

  @override
  Widget build(BuildContext context) => _Loop(
        period: const Duration(milliseconds: 2600),
        builder: (t, s) {
          final bossX = s * 0.5, bossY = s * 0.34;
          final fly = _phase(t, 0.15, 0.45);
          final hit = t > 0.45 && t < 0.7;
          final shake = hit ? math.sin(t * 90) * 7 : 0.0;
          final burst = _phase(t, 0.45, 0.6);
          final hp = 0.85 - 0.35 * _phase(t, 0.45, 0.65);
          final heroes = [(s * 0.2, s * 0.78, '🦸‍♀️'), (s * 0.8, s * 0.78, '🦸‍♂️')];
          return Stack(children: [
            _emoji('🐉', bossX + shake, bossY, s * 0.26),
            // HP bar under the boss.
            Positioned(
              left: s * 0.24,
              width: s * 0.52,
              top: bossY + s * 0.15,
              child: ProgressBar(value: hp, height: 12, color: Vivid.berry, track: Colors.white),
            ),
            for (final (hx, hy, e) in heroes) _emoji(e, hx, hy + _wave(t, 2) * 3, s * 0.15),
            if (t > 0.12 && t < 0.47)
              for (final (hx, hy, _) in heroes)
                _emoji('⚡', hx + (bossX - hx) * fly, hy - s * 0.1 + (bossY - hy + s * 0.1) * fly, s * 0.09,
                    rotation: hx < bossX ? 0.4 : -0.4),
            if (t > 0.45 && t < 0.75)
              _emoji('💥', bossX, bossY, s * 0.18, scale: 0.4 + burst, opacity: 1 - _phase(t, 0.6, 0.75)),
            if (t > 0.48)
              Positioned(
                left: bossX + s * 0.12,
                top: bossY - s * 0.12 - _phase(t, 0.48, 0.9) * s * 0.12,
                child: Opacity(
                  opacity: 1 - _phase(t, 0.75, 0.95),
                  child: Text('-40',
                      style: GoogleFonts.nunito(fontSize: s * 0.08, fontWeight: FontWeight.w900, color: Vivid.berry)),
                ),
              ),
          ]);
        },
      );
}

/// A trophy with badges orbiting it and confetti drifting down.
class _RewardsScene extends StatelessWidget {
  const _RewardsScene();

  static const _badges = ['🔥', '⚡', '👑', '🛡️', '🗺️'];
  static const _confetti = [Vivid.berry, Vivid.sky, Vivid.grass, Vivid.grape, Vivid.flame, Vivid.sun];

  @override
  Widget build(BuildContext context) => _Loop(
        period: const Duration(milliseconds: 6000),
        builder: (t, s) {
          final c = s / 2;
          return Stack(children: [
            for (var i = 0; i < 10; i++)
              () {
                final p = (t * 2 + i / 10) % 1;
                final x = s * (0.12 + 0.76 * ((i * 37) % 10) / 10) + _wave(p, 2) * 10;
                return Positioned(
                  left: x,
                  top: -10 + p * (s + 20),
                  child: Transform.rotate(
                    angle: p * 6 + i,
                    child: Container(
                      width: 9,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _confetti[i % _confetti.length],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                );
              }(),
            for (var i = 0; i < _badges.length; i++)
              () {
                final a = 2 * math.pi * (t + i / _badges.length);
                return _emoji(_badges[i], c + math.cos(a) * s * 0.33, c + math.sin(a) * s * 0.33, s * 0.09);
              }(),
            _emoji('🏆', c, c, s * 0.26, scale: 1 + 0.06 * _wave(t, 4)),
          ]);
        },
      );
}
