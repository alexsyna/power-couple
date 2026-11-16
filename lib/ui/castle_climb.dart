import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../data/backend.dart';
import '../domain/challenge.dart';
import '../domain/stars.dart';
import '../state/app_controller.dart';
import 'common.dart';
import 'invite_ui.dart';

// ------------------------------------------------------------ helpers

String _ago(Duration d) {
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

String _medal(int place) => switch (place) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '$place.' };

String _status(AppController app, Challenge c) {
  final phase = c.phase(app.today, app.now);
  final teams = '${c.teams.length} rope ${c.teams.length == 1 ? 'team' : 'teams'}';
  switch (phase) {
    case ClimbPhase.upcoming:
      return 'Starts ${DateFormat('EEE d MMM').format(c.startsOn)} · $teams';
    case ClimbPhase.climbing:
      final n = c.dayNumber(app.today);
      return n == c.days ? 'Final ascent today! Stars count double' : 'Day $n of ${c.days} · $teams';
    case ClimbPhase.summitWait:
      return 'The fog lifts ${DateFormat('EEE HH:mm').format(app.engine.calendar.localTime(c.revealAt))}';
    case ClimbPhase.revealed:
      final top = c.standings().where((s) => s.place == 1).map((s) => s.team.name).join(' & ');
      return 'Finished · 🏰 $top';
  }
}

// ------------------------------------------------------------ card

/// On Achievements: my climbs, plus Start and Join.
class CastleCard extends StatelessWidget {
  const CastleCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final s = Surface.of(context);
    // Running first, then upcoming, then finished.
    int rank(Challenge c) => switch (c.phase(app.today, app.now)) {
          ClimbPhase.climbing => 0,
          ClimbPhase.summitWait => 1,
          ClimbPhase.upcoming => 2,
          ClimbPhase.revealed => 3,
        };
    final list = [...app.challenges]..sort((a, b) => rank(a).compareTo(rank(b)));
    return SectionCard(
      title: '🏰 Castle Climb',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (list.isEmpty)
          Text('Race other couples up the mountain. The rope team with the most stars plants its banner on the castle.',
              style: theme.textTheme.bodySmall),
        for (final c in list.take(4))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => openClimb(context, c.id),
              child: Raised(
                face: s.card,
                edge: s.line,
                border: s.line,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  Text(c.teams.map((t) => t.banner).join(), style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${c.days}-day climb · ${c.activities.map((a) => a.emoji).join(' ')}', style: theme.textTheme.titleSmall),
                      Text(_status(app, c), style: theme.textTheme.bodySmall),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: s.muted),
                ]),
              ),
            ),
          ),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: ChunkyButton(
              label: 'Start a climb',
              compact: true,
              icon: const Text('⛰️'),
              onPressed: () => openCreateClimb(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ChunkyButton(
              label: 'Join',
              compact: true,
              outlined: true,
              color: Vivid.sky,
              onPressed: () => openJoinClimb(context),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ------------------------------------------------------------ climb screen

Future<void> openClimb(BuildContext context, String id) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClimbScreen(id: id)));

class ClimbScreen extends StatefulWidget {
  const ClimbScreen({super.key, required this.id});

  final String id;

  @override
  State<ClimbScreen> createState() => _ClimbScreenState();
}

class _ClimbScreenState extends State<ClimbScreen> with SingleTickerProviderStateMixin {
  late final _reveal = AnimationController(vsync: this);
  bool _started = false;

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  String get _seenKey => 'climb_revealed_${widget.id}';

  /// The first time a finished climb is opened, play the reveal.
  void _maybeReveal(AppController app, Challenge c) {
    if (_started || c.phase(app.today, app.now) != ClimbPhase.revealed) return;
    _started = true;
    final seen = app.prefs?.getBool(_seenKey) ?? false;
    _reveal.duration = Duration(milliseconds: 1400 * c.teams.length + 1600);
    if (seen) {
      _reveal.value = 1;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reveal.forward(from: 0);
        app.prefs?.setBool(_seenKey, true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final s = Surface.of(context);
    final c = app.challenges.where((x) => x.id == widget.id).firstOrNull;
    if (c == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('This climb is gone.')));
    final phase = c.phase(app.today, app.now);
    final me = app.household!.id;
    final revealed = phase == ClimbPhase.revealed;
    _maybeReveal(app, c);
    final standings = c.standings();

    return Scaffold(
      appBar: AppBar(title: const Text('Castle Climb')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        AnimatedBuilder(
          animation: _reveal,
          builder: (context, _) => _Mountain(challenge: c, me: me, revealed: revealed, t: _reveal.value),
        ),
        const SizedBox(height: 12),
        _PhaseBanner(challenge: c, phase: phase),
        if (c.stakes != null) ...[
          const SizedBox(height: 10),
          SectionCard(
            child: Row(children: [
              const Text('🎲', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('THE STAKES', style: theme.textTheme.labelSmall?.copyWith(color: s.muted, letterSpacing: 1)),
                  Text(c.stakes!, style: theme.textTheme.titleSmall),
                  if (revealed && standings.length >= 2)
                    AnimatedBuilder(
                      animation: _reveal,
                      builder: (context, _) => _reveal.value < 1
                          ? const SizedBox.shrink()
                          : Text(
                              '🏰 ${standings.first.team.name} · last place: ${standings.last.team.name}',
                              style: theme.textTheme.bodySmall,
                            ),
                    ),
                ]),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 10),
        SectionCard(
          title: revealed ? '🏁 Final standings' : '🧗 Rope teams',
          child: Column(children: [
            if (revealed)
              AnimatedBuilder(
                animation: _reveal,
                builder: (context, _) => Column(children: [
                  for (final (i, st) in standings.indexed)
                    if (_reveal.value >= 1 || _shownBy(standings, st, _reveal.value))
                      _StandingRow(
                        st: st,
                        me: me,
                        max: c.maxStars,
                        // Same stars as the team below, but ahead on ⭐⭐⭐.
                        wonTieBreak: i + 1 < standings.length &&
                            standings[i + 1].stars == st.stars &&
                            standings[i + 1].place != st.place,
                      ),
                  if (_reveal.value < 1) Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('The fog is lifting…', style: theme.textTheme.bodySmall),
                  ),
                ]),
              )
            else
              for (final t in c.teams) _TeamRow(challenge: c, team: t, me: me),
          ]),
        ),
        const SizedBox(height: 10),
        _Rules(challenge: c),
        if (phase == ClimbPhase.upcoming || (phase == ClimbPhase.climbing && c.canJoin(app.today))) ...[
          const SizedBox(height: 14),
          ChunkyButton(
            label: 'Invite couples · ${c.code}',
            icon: const Icon(Icons.copy_rounded),
            color: Vivid.sky,
            onPressed: () => shareClimbInvite(context, c.code),
          ),
        ],
        if (revealed) ...[
          const SizedBox(height: 14),
          ChunkyButton(
            label: 'Storm the castle again',
            icon: const Text('⚔️'),
            color: Vivid.grape,
            onPressed: () => openCreateClimb(context, like: c),
          ),
        ],
      ]),
    );
  }

  /// During the reveal, teams appear from last place to first.
  static bool _shownBy(List<Standing> standings, Standing st, double t) {
    final order = standings.reversed.toList();
    final i = order.indexOf(st);
    return t >= (i + 1) / (order.length + 1);
  }
}

class _PhaseBanner extends StatelessWidget {
  const _PhaseBanner({required this.challenge, required this.phase});

  final Challenge challenge;
  final ClimbPhase phase;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = challenge;
    final cal = app.engine.calendar;
    final (emoji, title, body, color) = switch (phase) {
      ClimbPhase.upcoming => (
          '🎒',
          'Packing the ropes',
          'Day 1 is ${DateFormat('EEEE d MMM').format(c.startsOn)}. Invite couples until then.',
          Vivid.sky
        ),
      ClimbPhase.climbing when c.dayNumber(app.today) == c.days => (
          '🔥',
          'Final ascent!',
          'Last day: every star counts double. The castle is in sight.',
          Vivid.flame
        ),
      ClimbPhase.climbing => (
          '🧗',
          'Day ${c.dayNumber(app.today)} of ${c.days}',
          'Your stars lift you up the mountain. The other teams are hidden in the fog.',
          Vivid.grass
        ),
      ClimbPhase.summitWait => (
          '🌫️',
          'Waiting at the summit',
          'Last night\'s sleep is still syncing. The fog lifts ${DateFormat('EEEE HH:mm').format(cal.localTime(c.revealAt))}.',
          Vivid.grape
        ),
      ClimbPhase.revealed => ('🏰', 'The fog has lifted', 'See who planted their banner on the castle.', Vivid.sunShade),
    };
    return Raised(
      face: color,
      edge: Vivid.shadeOf(color),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 30)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            Text(body, style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
      ]),
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({required this.challenge, required this.team, required this.me});

  final Challenge challenge;
  final ClimbTeam team;
  final String me;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final s = Surface.of(context);
    final mine = team.coupleId == me;
    final last = team.lastClimbAt;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        _BannerBadge(team.banner, highlight: mine),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(mine ? '${team.name} (you)' : team.name, style: theme.textTheme.titleSmall),
            Text(
              mine
                  ? '${challenge.totalFor(me)} of ${challenge.maxStars} ⭐'
                  : last == null
                      ? '🌫️ Hidden in the fog'
                      : '🌫️ Climbed ${_ago(app.now.difference(last))}',
              style: theme.textTheme.bodySmall?.copyWith(color: mine ? null : s.muted),
            ),
          ]),
        ),
        if (mine) Pill('${challenge.totalFor(me)} ⭐', color: Vivid.sunShade, filled: true),
      ]),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.st, required this.me, required this.max, this.wonTieBreak = false});

  final Standing st;
  final String me;
  final int max;
  final bool wonTieBreak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = st.team.coupleId == me;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: 34, child: Text(_medal(st.place), style: const TextStyle(fontSize: 22))),
        _BannerBadge(st.team.banner, highlight: mine),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(mine ? '${st.team.name} (you)' : st.team.name, style: theme.textTheme.titleSmall),
            if (wonTieBreak) Text('Ahead on ⭐⭐⭐ days (${st.threeStarCount})', style: theme.textTheme.bodySmall),
          ]),
        ),
        Pill('${st.stars} ⭐', color: st.place == 1 ? Vivid.sunShade : Vivid.sky, filled: st.place == 1),
      ]),
    );
  }
}

class _BannerBadge extends StatelessWidget {
  const _BannerBadge(this.banner, {this.highlight = false, this.size = 40});

  final String banner;
  final bool highlight;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: highlight ? Vivid.sunShade : Surface.of(context).line, width: highlight ? 3 : 2),
        ),
        child: Text(banner, style: TextStyle(fontSize: size * 0.5)),
      );
}

class _Rules extends StatelessWidget {
  const _Rules({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = Surface.of(context);
    final c = challenge;
    return SectionCard(
      title: '📜 The route',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          '${c.days} days, ${DateFormat('d MMM').format(c.startsOn)} – ${DateFormat('d MMM').format(c.endsOn)}. '
          'Every day, each activity lifts your rope team up to 3 stars. The last day counts double.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final a in c.activities) Pill('${a.emoji} ${a.label}', color: Vivid.sky),
        ]),
        const SizedBox(height: 8),
        Text('Up to ${c.maxStars} ⭐ · ties go to the team with more ⭐⭐⭐ days',
            style: theme.textTheme.bodySmall?.copyWith(color: s.muted)),
      ]),
    );
  }
}

// ------------------------------------------------------------ the mountain

/// The scene: a mountain with a castle on top. My team climbs in the open;
/// the others are in the fog until the reveal, when they appear from the
/// lowest to the highest and the winner plants its banner on the tower.
class _Mountain extends StatelessWidget {
  const _Mountain({required this.challenge, required this.me, required this.revealed, required this.t});

  final Challenge challenge;
  final String me;
  final bool revealed;

  /// Reveal progress, 0..1.
  final double t;

  static const _path = [
    Offset(0.50, 0.94),
    Offset(0.28, 0.82),
    Offset(0.66, 0.68),
    Offset(0.34, 0.53),
    Offset(0.60, 0.39),
    Offset(0.44, 0.27),
    Offset(0.50, 0.20),
  ];

  /// A point [f] (0..1) of the way along the trail.
  static Offset along(double f, Size size) {
    final pts = [for (final p in _path) Offset(p.dx * size.width, p.dy * size.height)];
    final lens = [for (var i = 1; i < pts.length; i++) (pts[i] - pts[i - 1]).distance];
    var d = f.clamp(0.0, 1.0) * lens.reduce((a, b) => a + b);
    for (var i = 0; i < lens.length; i++) {
      if (d <= lens[i]) return Offset.lerp(pts[i], pts[i + 1], d / lens[i])!;
      d -= lens[i];
    }
    return pts.last;
  }

  @override
  Widget build(BuildContext context) {
    final c = challenge;
    final standings = c.standings();
    final n = standings.length;
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: LayoutBuilder(builder: (context, box) {
          final size = Size(box.maxWidth, box.maxHeight);
          final markers = <Widget>[];
          void place(ClimbTeam team, double f, {bool label = true, int lane = 0}) {
            final p = along(f, size) + Offset(lane * 16.0, 0);
            markers.add(Positioned(
              left: p.dx - 22,
              top: p.dy - 44,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _BannerBadge(team.banner, highlight: team.coupleId == me, size: 36),
                if (label)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                    child: Text(team.coupleId == me ? 'You' : team.name.split(' & ').first,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
              ]),
            ));
          }

          double fog;
          if (!revealed) {
            fog = 1;
            final mine = c.teamOf(me);
            if (mine != null) place(mine, c.maxStars == 0 ? 0 : c.totalFor(me) / c.maxStars);
          } else {
            // Teams appear lowest first; the winner then walks to the castle.
            final order = standings.reversed.toList();
            final slot = 1 / (n + 1);
            fog = (1 - t * 1.6).clamp(0.0, 1.0);
            for (var i = 0; i < n; i++) {
              final st = order[i];
              final appear = ((t - i * slot) / slot).clamp(0.0, 1.0);
              if (appear <= 0) continue;
              var f = c.maxStars == 0 ? 0.0 : st.stars / c.maxStars * Curves.easeOut.transform(appear);
              if (st.place == 1) {
                final summit = ((t - n * slot) / slot).clamp(0.0, 1.0);
                f = f + (1 - f) * Curves.easeInOut.transform(summit);
              }
              // Once planted, the winner's banner flies from the tower instead.
              if (st.place == 1 && t >= 1) continue;
              place(st.team, f, lane: st.place == 1 ? 0 : (i.isEven ? -1 : 1));
            }
          }

          final winnerOnTop = revealed && t >= 1 && standings.isNotEmpty;
          return Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _MountainPainter(fog: fog))),
            Positioned(
              left: size.width * 0.5 - 30,
              top: size.height * 0.04,
              child: Column(children: [
                if (winnerOnTop)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('🚩', style: TextStyle(fontSize: 18)),
                    for (final s in standings)
                      if (s.place == 1) _BannerBadge(s.team.banner, highlight: true, size: 26),
                  ])
                else
                  const SizedBox(height: 27),
                const Text('🏰', style: TextStyle(fontSize: 50)),
              ]),
            ),
            ...markers,
            if (!revealed)
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    c.teams.length < 2
                        ? '🧗 Waiting for rivals'
                        : '🌫️ ${c.teams.length - 1} hidden in the fog',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black87),
                  ),
                ),
              ),
          ]);
        }),
      ),
    );
  }
}

class _MountainPainter extends CustomPainter {
  _MountainPainter({required this.fog});

  /// 1 = thick fog over the slopes, 0 = clear.
  final double fog;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), const [Color(0xFF7CC8FF), Color(0xFFDDF2FF)]),
    );
    // Far ridge, then the main mountain.
    final far = Path()
      ..moveTo(0, h * 0.72)
      ..lineTo(w * 0.18, h * 0.42)
      ..lineTo(w * 0.32, h * 0.58)
      ..lineTo(w * 0.78, h * 0.36)
      ..lineTo(w, h * 0.55)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(far, Paint()..color = const Color(0xFFA9C4DE));
    final main = Path()
      ..moveTo(-w * 0.05, h)
      ..lineTo(w * 0.22, h * 0.5)
      ..lineTo(w * 0.5, h * 0.17)
      ..lineTo(w * 0.8, h * 0.52)
      ..lineTo(w * 1.05, h)
      ..close();
    canvas.drawPath(
      main,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, h * 0.17), Offset(0, h), const [Color(0xFF8A7F95), Color(0xFF4F7A4A)]),
    );
    // Snow cap.
    final snow = Path()
      ..moveTo(w * 0.5, h * 0.17)
      ..lineTo(w * 0.41, h * 0.28)
      ..lineTo(w * 0.46, h * 0.27)
      ..lineTo(w * 0.5, h * 0.31)
      ..lineTo(w * 0.55, h * 0.27)
      ..lineTo(w * 0.6, h * 0.29)
      ..close();
    canvas.drawPath(snow, Paint()..color = Colors.white);
    // The trail.
    final trail = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      final a = _Mountain.along(i / 60, size), b = _Mountain.along((i + 0.5) / 60, size);
      canvas.drawLine(a, b, trail);
    }
    // Fog over the slopes (the castle peeks out on top).
    if (fog > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, h * 0.3, w, h * 0.7),
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, h * 0.3), Offset(0, h), [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.9 * fog),
          ]),
      );
      final puff = Paint()
        ..color = Colors.white.withValues(alpha: 0.5 * fog)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05);
      for (final (x, y, r) in [(0.15, 0.62, 0.16), (0.45, 0.7, 0.2), (0.8, 0.6, 0.17), (0.3, 0.85, 0.22), (0.7, 0.88, 0.22)]) {
        canvas.drawCircle(Offset(w * x, h * y), w * r, puff);
      }
    }
  }

  @override
  bool shouldRepaint(_MountainPainter old) => old.fog != fog;
}

// ------------------------------------------------------------ create

Future<void> openCreateClimb(BuildContext context, {Challenge? like}) async {
  final created = await showModalBottomSheet<Challenge>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CreateClimbSheet(like: like),
  );
  if (created == null || !context.mounted) return;
  await openClimb(context, created.id);
}

class _CreateClimbSheet extends StatefulWidget {
  const _CreateClimbSheet({this.like});

  /// Rematch: start from this climb's settings.
  final Challenge? like;

  @override
  State<_CreateClimbSheet> createState() => _CreateClimbSheetState();
}

class _CreateClimbSheetState extends State<_CreateClimbSheet> {
  late final Set<StarActivity> _activities = {...?widget.like?.activities};
  late int _days = widget.like?.days ?? 7;
  late String? _stakes = widget.like?.stakes ?? stakePresets.first;
  late final _custom = TextEditingController(
      text: widget.like?.stakes != null && !stakePresets.contains(widget.like!.stakes) ? widget.like!.stakes : '');
  String _banner = climbBanners[math.Random().nextInt(climbBanners.length)];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (_activities.isEmpty) _activities.addAll(StarActivity.values);
    if (_custom.text.isNotEmpty) _stakes = null;
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_activities.isEmpty) return;
    setState(() => _busy = true);
    try {
      final custom = _custom.text.trim();
      final c = await AppScope.of(context).createClimb(
        activities: [for (final a in StarActivity.values) if (_activities.contains(a)) a],
        days: _days,
        stakes: custom.isNotEmpty ? custom : _stakes,
        banner: _banner,
      );
      if (mounted) Navigator.pop(context, c);
    } on BackendException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMessage(context, e.message, color: Vivid.berry);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(t, style: theme.textTheme.labelLarge?.copyWith(letterSpacing: 1)),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.like == null ? '⛰️ New Castle Climb' : '⚔️ Storm the castle again',
              style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('Up to 6 couples. Most stars plants their banner on the castle.',
              style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
          label('WHAT COUNTS'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final a in StarActivity.values)
              FilterChip(
                label: Text('${a.emoji} ${a.label}'),
                selected: _activities.contains(a),
                onSelected: (on) => setState(() => on ? _activities.add(a) : _activities.remove(a)),
              ),
          ]),
          label('HOW LONG'),
          Wrap(spacing: 8, children: [
            for (final d in climbDurations)
              ChoiceChip(
                label: Text(d == 30 ? '1 month' : '$d days'),
                selected: _days == d,
                onSelected: (_) => setState(() => _days = d),
              ),
          ]),
          label('THE STAKES'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in stakePresets)
              ChoiceChip(
                label: Text(p),
                selected: _stakes == p && _custom.text.trim().isEmpty,
                onSelected: (_) => setState(() {
                  _stakes = p;
                  _custom.clear();
                }),
              ),
            ChoiceChip(
              label: const Text('Just for glory'),
              selected: _stakes == null && _custom.text.trim().isEmpty,
              onSelected: (_) => setState(() {
                _stakes = null;
                _custom.clear();
              }),
            ),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _custom,
            maxLength: 80,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Or write your own', hintText: 'e.g. Losers do the dishes all week'),
          ),
          label('YOUR BANNER'),
          _BannerPicker(value: _banner, onChanged: (b) => setState(() => _banner = b)),
          const SizedBox(height: 18),
          Text('Day 1 is tomorrow. You\'ll get a code to invite couples.',
              style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          ChunkyButton(
            label: 'Start the climb',
            busy: _busy,
            icon: const Text('🧗'),
            onPressed: _activities.isEmpty ? null : _create,
          ),
        ]),
      ),
    );
  }
}

class _BannerPicker extends StatelessWidget {
  const _BannerPicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final b in climbBanners)
          GestureDetector(
            onTap: () => onChanged(b),
            child: _BannerBadge(b, highlight: b == value, size: 44),
          ),
      ]);
}

// ------------------------------------------------------------ join

Future<void> openJoinClimb(BuildContext context) async {
  final id = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _JoinClimbSheet(),
  );
  if (id == null || !context.mounted) return;
  await openClimb(context, id);
}

class _JoinClimbSheet extends StatefulWidget {
  const _JoinClimbSheet();

  @override
  State<_JoinClimbSheet> createState() => _JoinClimbSheetState();
}

class _JoinClimbSheetState extends State<_JoinClimbSheet> {
  final _code = TextEditingController();
  ClimbPreview? _preview;
  String? _error;
  bool _busy = false;
  String _banner = climbBanners[math.Random().nextInt(climbBanners.length)];

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  /// Accepts the bare code or the whole pasted invite message.
  String get _cleanCode {
    final words = RegExp(r'[A-Za-z0-9]{6}').allMatches(_code.text).map((m) => m.group(0)!).toList();
    return (words.isEmpty ? _code.text : words.last).trim().toUpperCase();
  }

  Future<void> _lookUp() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await AppScope.of(context).previewClimb(_cleanCode);
      setState(() {
        _preview = p;
        _error = p == null ? 'No climb with that code.' : null;
      });
    } on BackendException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final p = _preview!;
    if (p.alreadyIn) {
      Navigator.pop(context, p.id);
      return;
    }
    setState(() => _busy = true);
    try {
      await AppScope.of(context).joinClimb(_cleanCode, _banner);
      if (mounted) Navigator.pop(context, p.id);
    } on BackendException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = _preview;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('🧗 Join a Castle Climb', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          TextField(
            controller: _code,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Invite code', hintText: 'e.g. CLIMB7'),
            onChanged: (_) => setState(() => _preview = null),
            onSubmitted: (_) => _lookUp(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: theme.textTheme.titleSmall?.copyWith(color: Vivid.berry)),
          ],
          const SizedBox(height: 12),
          if (p == null)
            ChunkyButton(label: 'Find the climb', busy: _busy, color: Vivid.sky, onPressed: _lookUp)
          else ...[
            SectionCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p.days == 30 ? '1-month' : '${p.days}-day'} climb · ${p.teams} ${p.teams == 1 ? 'team' : 'teams'} so far',
                    style: theme.textTheme.titleSmall),
                Text('Day 1: ${DateFormat('EEEE d MMM').format(p.startsOn)}', style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final a in p.activities) Pill('${a.emoji} ${a.label}', color: Vivid.sky),
                ]),
                if (p.stakes != null) ...[
                  const SizedBox(height: 8),
                  Text('🎲 ${p.stakes}', style: theme.textTheme.bodyMedium),
                ],
                if (p.activities.any((a) => a == StarActivity.steps || a == StarActivity.sleep || a == StarActivity.bedtime)) ...[
                  const SizedBox(height: 8),
                  Text('Steps, sleep and bedtime come from Apple Health, so connect it to earn those stars.',
                      style: theme.textTheme.bodySmall),
                ],
              ]),
            ),
            if (!p.alreadyIn) ...[
              const SizedBox(height: 12),
              Text('YOUR BANNER', style: theme.textTheme.labelLarge?.copyWith(letterSpacing: 1)),
              const SizedBox(height: 8),
              _BannerPicker(value: _banner, onChanged: (b) => setState(() => _banner = b)),
            ],
            const SizedBox(height: 14),
            ChunkyButton(
              label: p.alreadyIn ? 'Open the climb' : 'Join the climb',
              busy: _busy,
              icon: const Text('🧗'),
              onPressed: _join,
            ),
          ],
        ]),
      ),
    );
  }
}
