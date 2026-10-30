/// Bond: a daily question for each partner, revealed once both have answered.
library;

enum QuestionPack {
  light('Light', '☀️', 'Easy, fun questions to get talking.', null),
  deep('Deep', '🌊', 'Feelings, support and what matters.', '€1.99'),
  dreams('Dreams', '🌠', 'Your future and big plans together.', '€1.99');

  const QuestionPack(this.label, this.emoji, this.blurb, this.price);
  final String label;
  final String emoji;
  final String blurb;

  /// Display price; null means free.
  final String? price;

  bool get isFree => price == null;

  static QuestionPack? parse(String s) {
    for (final p in values) {
      if (p.name == s) return p;
    }
    return null;
  }
}

class Question {
  const Question(this.id, this.pack, this.text);
  final String id;
  final QuestionPack pack;
  final String text;
}

/// 20 per pack. Pack sizes must stay even so both partners always draw from
/// the same shuffle (see [questionFor]).
const questions = <Question>[
  // Light
  Question('l01', QuestionPack.light, 'What\'s the best meal we\'ve ever shared?'),
  Question('l02', QuestionPack.light, 'Which song always reminds you of us?'),
  Question('l03', QuestionPack.light, 'What\'s your favourite way to spend a lazy Sunday together?'),
  Question('l04', QuestionPack.light, 'What\'s a small habit of mine that makes you smile?'),
  Question('l05', QuestionPack.light, 'If we had a free day tomorrow, what would you plan?'),
  Question('l06', QuestionPack.light, 'What\'s the funniest thing that\'s happened to us?'),
  Question('l07', QuestionPack.light, 'Which movie or show should we watch together next?'),
  Question('l08', QuestionPack.light, 'What\'s your favourite photo of us, and why?'),
  Question('l09', QuestionPack.light, 'What chore do you secretly not mind doing?'),
  Question('l10', QuestionPack.light, 'What\'s a snack you\'d want me to surprise you with?'),
  Question('l11', QuestionPack.light, 'Where was our best date so far?'),
  Question('l12', QuestionPack.light, 'What\'s something new you\'d like us to try this month?'),
  Question('l13', QuestionPack.light, 'What made you laugh the most this week?'),
  Question('l14', QuestionPack.light, 'Which of our friends would survive a zombie apocalypse?'),
  Question('l15', QuestionPack.light, 'What\'s your ideal breakfast in bed?'),
  Question('l16', QuestionPack.light, 'If our home had a theme song, what would it be?'),
  Question('l17', QuestionPack.light, 'What\'s the best gift you\'ve ever received from me?'),
  Question('l18', QuestionPack.light, 'Which season do you love spending with me the most?'),
  Question('l19', QuestionPack.light, 'What\'s a nickname you\'d secretly like me to call you?'),
  Question('l20', QuestionPack.light, 'What\'s one thing you\'re looking forward to this week?'),
  // Deep
  Question('d01', QuestionPack.deep, 'When did you feel most supported by me?'),
  Question('d02', QuestionPack.deep, 'What\'s something you\'ve never told me but want to?'),
  Question('d03', QuestionPack.deep, 'What does a perfect apology look like to you?'),
  Question('d04', QuestionPack.deep, 'What\'s a moment you felt really proud of us?'),
  Question('d05', QuestionPack.deep, 'What makes you feel most loved: words, time, touch, gifts or help?'),
  Question('d06', QuestionPack.deep, 'What\'s been weighing on your mind lately?'),
  Question('d07', QuestionPack.deep, 'What\'s one thing I could do this week to make your life easier?'),
  Question('d08', QuestionPack.deep, 'When do you feel closest to me?'),
  Question('d09', QuestionPack.deep, 'What\'s a fear you have about the future?'),
  Question('d10', QuestionPack.deep, 'How has being together changed you?'),
  Question('d11', QuestionPack.deep, 'What\'s a childhood memory that shaped who you are?'),
  Question('d12', QuestionPack.deep, 'What do you need from me when you\'ve had a hard day?'),
  Question('d13', QuestionPack.deep, 'What\'s something you admire about me that I might not know?'),
  Question('d14', QuestionPack.deep, 'What\'s a disagreement we had that taught you something?'),
  Question('d15', QuestionPack.deep, 'What does "home" mean to you?'),
  Question('d16', QuestionPack.deep, 'When did you first know this was serious?'),
  Question('d17', QuestionPack.deep, 'What\'s a boundary that matters a lot to you?'),
  Question('d18', QuestionPack.deep, 'What\'s something you\'re working on in yourself right now?'),
  Question('d19', QuestionPack.deep, 'How can we share the mental load better?'),
  Question('d20', QuestionPack.deep, 'What\'s a small moment from us that you\'ll never forget?'),
  // Dreams
  Question('r01', QuestionPack.dreams, 'Where do you see us in 10 years?'),
  Question('r02', QuestionPack.dreams, 'Which place in the world should we visit together first?'),
  Question('r03', QuestionPack.dreams, 'What would our dream home look like?'),
  Question('r04', QuestionPack.dreams, 'If money didn\'t matter, how would we spend our days?'),
  Question('r05', QuestionPack.dreams, 'What\'s a skill we should learn together?'),
  Question('r06', QuestionPack.dreams, 'What\'s a tradition you\'d love us to start?'),
  Question('r07', QuestionPack.dreams, 'What adventure is on your bucket list?'),
  Question('r08', QuestionPack.dreams, 'How do you imagine our perfect retirement?'),
  Question('r09', QuestionPack.dreams, 'What\'s a big goal you want my help with?'),
  Question('r10', QuestionPack.dreams, 'If we started a project together, what would it be?'),
  Question('r11', QuestionPack.dreams, 'What would a perfect anniversary look like?'),
  Question('r12', QuestionPack.dreams, 'Which city would you love to live in for a year?'),
  Question('r13', QuestionPack.dreams, 'What do you want people to say about us as a couple?'),
  Question('r14', QuestionPack.dreams, 'What\'s one thing you want us to do before next summer?'),
  Question('r15', QuestionPack.dreams, 'How would you describe our life in five years in one sentence?'),
  Question('r16', QuestionPack.dreams, 'What\'s a dream you\'ve put on hold that we could revive?'),
  Question('r17', QuestionPack.dreams, 'What kind of community do you want around us?'),
  Question('r18', QuestionPack.dreams, 'If we wrote a book about us, what would the title be?'),
  Question('r19', QuestionPack.dreams, 'What\'s a challenge you\'d love us to take on together?'),
  Question('r20', QuestionPack.dreams, 'What would make next year our best year yet?'),
];

final Map<String, Question> _byId = {for (final q in questions) q.id: q};

Question questionById(String id) =>
    _byId[id] ?? (throw ArgumentError('Unknown question id: $id'));

final _epoch = DateTime.utc(2024, 1, 1);

/// Stable 31-bit hash of a string (FNV-1a), identical on web and native.
int _hash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0x7fffffff;
  }
  return h == 0 ? 1 : h;
}

/// Deterministic shuffle (Park-Miller), identical on web and native, so both
/// partners' phones always compute the same questions.
List<Question> _shuffled(List<Question> pool, int seed) {
  final out = List.of(pool);
  var state = seed % 2147483647;
  if (state <= 0) state += 2147483646;
  for (var i = out.length - 1; i > 0; i--) {
    state = (state * 48271) % 2147483647;
    final j = state % (i + 1);
    final t = out[i];
    out[i] = out[j];
    out[j] = t;
  }
  return out;
}

/// The question [userId] gets on [day] (a household-local date).
///
/// Each day the couple takes the next two cards of a shuffled deck of their
/// unlocked questions: one partner the even card, the other the odd one, so
/// they never get the same question and nothing repeats within a round. The
/// next round reuses the same shuffle with the partners swapped, so over two
/// rounds each partner sees every question; then it reshuffles.
Question questionFor({
  required String coupleId,
  required List<String> memberIds,
  required String userId,
  required DateTime day,
  required Set<QuestionPack> unlocked,
}) {
  final pool = [for (final q in questions) if (unlocked.contains(q.pack) || q.pack.isFree) q];
  final n = pool.length;
  final dayIndex = DateTime.utc(day.year, day.month, day.day).difference(_epoch).inDays;
  final k = 2 * dayIndex;
  final round = k ~/ n;
  final deck = _shuffled(pool, _hash('$coupleId#${round ~/ 2}'));
  final first = memberIds.isEmpty || memberIds.first == userId;
  final takesFirst = first == round.isEven;
  return deck[(k % n) + (takesFirst ? 0 : 1)];
}

/// Who answered on which day, without the content.
class AnswerMeta {
  const AnswerMeta({required this.userId, required this.day, required this.createdAt});
  final String userId;
  final DateTime day;
  final DateTime createdAt;
}

/// A visible answer (mine, or my partner's once revealed).
class Answer {
  const Answer({
    required this.userId,
    required this.day,
    required this.questionId,
    required this.text,
    required this.createdAt,
  });
  final String userId;
  final DateTime day;
  final String questionId;
  final String text;
  final DateTime createdAt;

  Question get question => questionById(questionId);
}

/// When each day's answers were revealed (the later of the two answers),
/// sorted. The bond level at any moment is how many reveals came before it.
List<DateTime> revealTimes(Iterable<AnswerMeta> log, List<String> memberIds) {
  if (memberIds.length < 2) return const [];
  final byDay = <DateTime, Map<String, DateTime>>{};
  for (final a in log) {
    if (!memberIds.contains(a.userId)) continue;
    byDay.putIfAbsent(a.day, () => {})[a.userId] = a.createdAt;
  }
  final out = [
    for (final answers in byDay.values)
      if (answers.length >= 2) answers.values.reduce((x, y) => x.isAfter(y) ? x : y),
  ]..sort();
  return out;
}

/// Bond level at [at]: number of reveals up to and including that moment.
int bondLevelFrom(List<DateTime> sortedReveals, DateTime at) {
  var lo = 0, hi = sortedReveals.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (sortedReveals[mid].isAfter(at)) {
      hi = mid;
    } else {
      lo = mid + 1;
    }
  }
  return lo;
}
