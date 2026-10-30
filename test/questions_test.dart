import 'package:flutter_test/flutter_test.dart';
import 'package:power_couple/domain/questions.dart';

void main() {
  const a = 'alex', b = 'sam';
  const couple = 'c-123';
  final start = DateTime.utc(2026, 10, 1);

  Question q(String user, int dayOffset, Set<QuestionPack> unlocked) => questionFor(
        coupleId: couple,
        memberIds: const [a, b],
        userId: user,
        day: start.add(Duration(days: dayOffset)),
        unlocked: unlocked,
      );

  test('there are 60 questions, 20 per pack, with unique ids', () {
    expect(questions.length, 60);
    for (final p in QuestionPack.values) {
      expect(questions.where((x) => x.pack == p).length, 20);
    }
    expect(questions.map((x) => x.id).toSet().length, 60);
  });

  test('partners never get the same question on the same day', () {
    for (final packs in [
      {QuestionPack.light},
      QuestionPack.values.toSet(),
    ]) {
      for (var d = 0; d < 200; d++) {
        expect(q(a, d, packs).id, isNot(q(b, d, packs).id));
      }
    }
  });

  test('only unlocked packs are used', () {
    for (var d = 0; d < 60; d++) {
      expect(q(a, d, {QuestionPack.light}).pack, QuestionPack.light);
      expect(q(b, d, {QuestionPack.light}).pack, QuestionPack.light);
    }
  });

  test('no repeats within a round, and each partner sees every question', () {
    final all = QuestionPack.values.toSet();
    // A round of 60 questions lasts 30 days: all 60 used exactly once.
    final round = <String>{};
    final roundStart = (DateTime.utc(2026, 10, 1).difference(DateTime.utc(2024, 1, 1)).inDays * 2) % 60;
    final offset = roundStart == 0 ? 0 : (60 - roundStart) ~/ 2;
    for (var d = offset; d < offset + 30; d++) {
      round
        ..add(q(a, d, all).id)
        ..add(q(b, d, all).id);
    }
    expect(round.length, 60);
    // Over a pair of rounds, each partner alone sees all 60.
    final pairOffset = ((offset + (DateTime.utc(2026, 10, 1).difference(DateTime.utc(2024, 1, 1)).inDays)) * 2 ~/ 60).isOdd
        ? offset + 30
        : offset;
    final seenByA = {for (var d = pairOffset; d < pairOffset + 60; d++) q(a, d, all).id};
    expect(seenByA.length, 60);
  });

  test('the same day always gives the same question', () {
    expect(q(a, 5, {QuestionPack.light}).id, q(a, 5, {QuestionPack.light}).id);
  });

  test('bond level counts days both answered, at the later answer', () {
    DateTime t(int day, int hour) => DateTime.utc(2026, 10, day, hour);
    final log = [
      AnswerMeta(userId: a, day: DateTime.utc(2026, 10, 1), createdAt: t(1, 8)),
      AnswerMeta(userId: b, day: DateTime.utc(2026, 10, 1), createdAt: t(1, 20)),
      AnswerMeta(userId: a, day: DateTime.utc(2026, 10, 2), createdAt: t(2, 9)), // partner never answered
      AnswerMeta(userId: b, day: DateTime.utc(2026, 10, 3), createdAt: t(3, 7)),
      AnswerMeta(userId: a, day: DateTime.utc(2026, 10, 3), createdAt: t(3, 9)),
    ];
    final reveals = revealTimes(log, const [a, b]);
    expect(reveals, [t(1, 20), t(3, 9)]);
    expect(bondLevelFrom(reveals, t(1, 19)), 0);
    expect(bondLevelFrom(reveals, t(1, 20)), 1);
    expect(bondLevelFrom(reveals, t(2, 12)), 1);
    expect(bondLevelFrom(reveals, t(4, 0)), 2);
    expect(revealTimes(log, const [a]), isEmpty);
  });
}
