import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/backend.dart';
import '../domain/missions.dart' show dateKey;
import '../domain/questions.dart';
import '../state/app_controller.dart';
import 'common.dart';
import 'shop.dart';

/// Daily questions: each partner answers their own; both are revealed with
/// a card flip once both have answered. Every revealed day raises the bond
/// level, which adds damage to each boss hit.
class BondScreen extends StatelessWidget {
  const BondScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final partner = app.partner;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        const _BondLevelCard(),
        const SizedBox(height: 14),
        if (partner == null)
          const SectionCard(
            title: '💌 Waiting for your partner',
            child: Text('Daily questions start once your partner joins with your invite code.'),
          )
        else
          const _TodayCard(),
        const SizedBox(height: 14),
        const _PacksTeaser(),
      ],
    );
  }
}

class _BondLevelCard extends StatelessWidget {
  const _BondLevelCard();

  @override
  Widget build(BuildContext context) {
    final level = AppScope.of(context).bondLevel;
    final white = GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w900);
    return SectionCard(
      color: Vivid.berry,
      child: Row(children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Vivid.berryShade, width: 4),
          ),
          child: const Text('💞', style: TextStyle(fontSize: 38)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('BOND LEVEL', style: white.copyWith(fontSize: 12, letterSpacing: 1)),
            Text('$level', style: white.copyWith(fontSize: 34, height: 1.1)),
            Text(
              level == 0
                  ? 'Answer together to power up your boss hits.'
                  : '+$level damage on every boss hit 💥',
              style: white.copyWith(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _TodayCard extends StatefulWidget {
  const _TodayCard();

  @override
  State<_TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends State<_TodayCard> with SingleTickerProviderStateMixin {
  final _text = TextEditingController();
  late final _flip = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  bool _busy = false;

  /// Whether today's reveal has been shown on this device.
  bool? _seen;
  String? _seenDay;

  @override
  void dispose() {
    _text.dispose();
    _flip.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(context).submitAnswer(text);
      _text.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } on BackendException catch (e) {
      if (mounted) showMessage(context, e.message, color: Vivid.berry);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Plays the flip once per day per device, the first time both answers
  /// are available while this card is on screen.
  Future<void> _maybeReveal(String day) async {
    if (_seenDay == day) return;
    _seenDay = day;
    final prefs = await SharedPreferences.getInstance();
    final key = 'bond_revealed_$day';
    final seen = prefs.getBool(key) ?? false;
    if (!mounted) return;
    setState(() => _seen = seen);
    if (seen) {
      _flip.value = 1;
      return;
    }
    await prefs.setBool(key, true);
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _flip.value = 1;
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) await _flip.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final partner = app.partner!;
    final today = app.today;
    final mine = app.answerOn(app.me, today);
    final theirs = app.answerOn(partner.userId, today);
    final revealed = mine != null && theirs != null;
    final myQuestion = mine?.question ?? app.questionToday(app.me);

    if (revealed) _maybeReveal(dateKey(today));

    return SectionCard(
      title: '💬 Today\'s questions',
      trailing: revealed ? const Pill('Revealed!', color: Vivid.grass) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!revealed) ...[
          _QuestionCard(
            who: 'Your question',
            userId: app.me,
            question: myQuestion.text,
            pack: myQuestion.pack,
            answer: mine?.text,
            input: mine == null
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const SizedBox(height: 10),
                    TextField(
                      controller: _text,
                      minLines: 2,
                      maxLines: 5,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(hintText: 'Your answer… ${partner.displayName} will see it once they answer too.'),
                    ),
                    ChunkyButton(
                      label: 'Lock in my answer',
                      color: Vivid.berry,
                      icon: const Icon(Icons.lock_rounded),
                      busy: _busy,
                      onPressed: _submit,
                    ),
                  ])
                : null,
          ),
          const SizedBox(height: 12),
          _LockedCard(
            name: partner.displayName,
            answered: theirs != null || app.partnerAnsweredToday,
            iAnswered: mine != null,
          ),
        ] else ...[
          AnimatedBuilder(
            animation: _flip,
            builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _Flip(
                t: _seen == null ? 0 : _flip.value,
                back: _LockedCard(name: 'You', answered: true, iAnswered: true),
                front: _QuestionCard(
                  who: 'You',
                  userId: app.me,
                  question: mine.question.text,
                  pack: mine.question.pack,
                  answer: mine.text,
                ),
              ),
              const SizedBox(height: 12),
              _Flip(
                // Second card turns a beat later.
                t: _seen == null ? 0 : ((_flip.value - 0.25) / 0.75).clamp(0.0, 1.0),
                back: _LockedCard(name: partner.displayName, answered: true, iAnswered: true),
                front: _QuestionCard(
                  who: partner.displayName,
                  userId: partner.userId,
                  question: theirs.question.text,
                  pack: theirs.question.pack,
                  answer: theirs.text,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Text(
            'Bond level up! 💞 Come back tomorrow for new questions.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(color: Vivid.berry),
          ),
        ],
      ]),
    );
  }
}

/// Turns [back] into [front] around the vertical axis as [t] goes 0→1.
class _Flip extends StatelessWidget {
  const _Flip({required this.t, required this.back, required this.front});

  final double t;
  final Widget back;
  final Widget front;

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeInOutBack.transform(t).clamp(0.0, 1.0);
    final angle = eased * math.pi;
    final showFront = angle > math.pi / 2;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0015)
        ..rotateY(showFront ? angle - math.pi : angle),
      child: showFront ? front : back,
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.who,
    required this.userId,
    required this.question,
    required this.pack,
    this.answer,
    this.input,
  });

  final String who;
  final String userId;
  final String question;
  final QuestionPack pack;
  final String? answer;
  final Widget? input;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final s = Surface.of(context);
    final color = personColor(app.household!.members, userId);
    return Raised(
      face: s.card,
      edge: color.withValues(alpha: 0.5),
      border: color.withValues(alpha: 0.5),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          PersonAvatar(userId: userId, size: 28),
          const SizedBox(width: 8),
          Expanded(child: Text(who, style: theme.textTheme.labelLarge?.copyWith(color: color))),
          Pill('${pack.emoji} ${pack.label}', color: color),
        ]),
        const SizedBox(height: 10),
        Text(question, style: theme.textTheme.titleMedium),
        if (answer != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(answer!, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
          ),
        ],
        ?input,
      ]),
    );
  }
}

/// The face-down card: shows whether the other side has answered.
class _LockedCard extends StatelessWidget {
  const _LockedCard({required this.name, required this.answered, required this.iAnswered});

  final String name;
  final bool answered;
  final bool iAnswered;

  @override
  Widget build(BuildContext context) {
    final white = GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w900);
    final (title, sub) = !answered
        ? ('$name hasn\'t answered yet', iAnswered ? 'Your answer is locked in. We\'ll reveal both when $name answers.' : 'Their question is a surprise too.')
        : iAnswered
            ? ('Revealing…', '')
            : ('$name answered! 🎉', 'Answer yours to reveal both cards.');
    return Raised(
      face: Vivid.grape,
      edge: Vivid.grapeShade,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: Column(children: [
        Text(answered ? '💌' : '🔒', style: const TextStyle(fontSize: 40)),
        const SizedBox(height: 6),
        Text(title, textAlign: TextAlign.center, style: white.copyWith(fontSize: 17)),
        if (sub.isNotEmpty)
          Text(sub,
              textAlign: TextAlign.center,
              style: white.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9))),
      ]),
    );
  }
}

class _PacksTeaser extends StatelessWidget {
  const _PacksTeaser();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final unlocked = app.household!.unlockedPacks;
    final locked = [for (final p in QuestionPack.values) if (!p.isFree && !unlocked.contains(p)) p];
    return SectionCard(
      title: '🃏 Question packs',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in QuestionPack.values)
            Pill(
              '${p.emoji} ${p.label} ${p.isFree || unlocked.contains(p) ? '✓' : '🔒'}',
              color: p.isFree || unlocked.contains(p) ? Vivid.grass : Surface.of(context).muted,
            ),
        ]),
        if (locked.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Unlock deeper questions in the shop.', style: theme.textTheme.bodySmall),
          const SizedBox(height: 10),
          ChunkyButton(
            label: 'Visit the shop',
            color: Vivid.sun,
            icon: const Text('🛍️'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShopPage())),
          ),
        ],
      ]),
    );
  }
}
