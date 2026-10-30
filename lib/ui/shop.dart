import 'package:flutter/material.dart';

import '../data/backend.dart';
import '../domain/questions.dart';
import '../state/app_controller.dart';
import 'common.dart';

/// Question packs for sale. Checkout is simulated for now: tapping Buy
/// unlocks the pack for the whole household straight away.
class ShopCard extends StatelessWidget {
  const ShopCard({super.key});

  Future<void> _buy(BuildContext context, QuestionPack pack) async {
    final ok = await confirm(
      context,
      emoji: pack.emoji,
      title: 'Unlock ${pack.label} questions?',
      body: '20 new questions for both of you, ${pack.price}.\n\nThis is a demo checkout: no payment is taken.',
      action: 'Buy for ${pack.price}',
    );
    if (!ok || !context.mounted) return;
    try {
      await AppScope.of(context).unlockPack(pack);
      if (context.mounted) showMessage(context, '${pack.emoji} ${pack.label} pack unlocked!', color: Vivid.grass);
    } on BackendException catch (e) {
      if (context.mounted) showMessage(context, e.message, color: Vivid.berry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final unlocked = app.household!.unlockedPacks;
    return SectionCard(
      title: '🛍️ Shop',
      child: Column(children: [
        for (final p in QuestionPack.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              EmojiBadge(p.emoji, color: Vivid.grape, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${p.label} questions', style: theme.textTheme.titleSmall),
                  Text(p.blurb, style: theme.textTheme.bodySmall),
                ]),
              ),
              const SizedBox(width: 8),
              if (p.isFree || unlocked.contains(p))
                Pill(p.isFree ? 'Free' : 'Owned', color: Vivid.grass)
              else
                SizedBox(
                  width: 92,
                  child: ChunkyButton(
                    label: p.price!,
                    compact: true,
                    color: Vivid.sun,
                    onPressed: () => _buy(context, p),
                  ),
                ),
            ]),
          ),
      ]),
    );
  }
}

/// The shop as its own page, opened from the Bond tab.
class ShopPage extends StatelessWidget {
  const ShopPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Shop')),
        body: ListView(padding: const EdgeInsets.all(16), children: const [ShopCard()]),
      );
}
