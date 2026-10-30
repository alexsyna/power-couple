import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../data/backend.dart';
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
        for (final (day, mine, theirs) in app.missedReveals) ...[
          _MissedRevealCard(day: day, mine: mine, theirs: theirs),
          const SizedBox(height: 14),
        ],
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

class _TodayCardState extends State<_TodayCard> {
  final _text = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
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
          RevealCards(day: today, mine: mine, theirs: theirs),
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

/// Both answer cards for a revealed day. The first time a day is shown on
/// this device the two cards flip over one after the other; after that they
/// show face up.
class RevealCards extends StatefulWidget {
  const RevealCards({super.key, required this.day, required this.mine, required this.theirs});

  final DateTime day;
  final Answer mine;
  final Answer theirs;

  @override
  State<RevealCards> createState() => _RevealCardsState();
}

class _RevealCardsState extends State<RevealCards> with SingleTickerProviderStateMixin {
  late final _flip = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final app = AppScope.of(context);
    if (app.isRevealSeen(widget.day) || MediaQuery.disableAnimationsOf(context)) {
      _flip.value = 1;
      app.markRevealSeen(widget.day);
      return;
    }
    app.markRevealSeen(widget.day);
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _flip.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final partner = app.partner;
    final partnerName = partner?.displayName ?? 'Partner';
    return AnimatedBuilder(
      animation: _flip,
      builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Flip(
          t: _flip.value,
          back: const _LockedCard(name: 'You', answered: true, iAnswered: true),
          front: _QuestionCard(
            who: 'You',
            userId: app.me,
            question: widget.mine.question.text,
            pack: widget.mine.question.pack,
            answer: widget.mine.text,
          ),
        ),
        const SizedBox(height: 12),
        _Flip(
          // Second card turns a beat later.
          t: ((_flip.value - 0.25) / 0.75).clamp(0.0, 1.0),
          back: _LockedCard(name: partnerName, answered: true, iAnswered: true),
          front: _QuestionCard(
            who: partnerName,
            userId: widget.theirs.userId,
            question: widget.theirs.question.text,
            pack: widget.theirs.question.pack,
            answer: widget.theirs.text,
          ),
        ),
      ]),
    );
  }
}

/// A past day my partner completed after I'd answered, which I haven't seen.
class _MissedRevealCard extends StatelessWidget {
  const _MissedRevealCard({required this.day, required this.mine, required this.theirs});

  final DateTime day;
  final Answer mine;
  final Answer theirs;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final yesterday = app.today.subtract(const Duration(days: 1));
    final when = day == yesterday ? 'Yesterday' : DateFormat('EEEE d MMM').format(day);
    return SectionCard(
      title: '💌 $when\'s answers',
      trailing: const Pill('Missed reveal', color: Vivid.berry),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${app.partner?.displayName ?? 'Your partner'} answered after you. Here\'s what you both said:',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        RevealCards(day: day, mine: mine, theirs: theirs),
      ]),
    );
  }
}
