import 'dart:math';

// Port of the RN example's src/local_llm/rag/web/needsWebSearch.ts — keep the
// two in sync.
//
// Decides, without the model, whether a question depends on facts newer than
// the model's training (office holders, news, prices, "latest", recent years).
// A 1.5B model can't reliably judge that itself, and a regex costs nothing.

final _timeWords = RegExp(r'\b(current|currently|latest|recent|recently|newest|nowadays|today|tonight|tomorrow|yesterday|right now|at the moment|as of now|this (week|month|year)|these days)\b', caseSensitive: false);

/// Roles whose holder changes. Only with a "who" style question, so "tell me a
/// story about a king" doesn't search.
final _officeWords = RegExp(r'\b(president|vice president|prime minister|chancellor|king|queen|pope|ceo|chief executive|leader|mayor|governor|minister|secretary of state|head of state|chairman|coach of|owner of|richest)\b', caseSensitive: false);
final _whoQuestion = RegExp(r'\b(who|whom|whose|name of|is the)\b', caseSensitive: false);

/// "Is Joe Biden the president?", "Is he still the CEO?": yes/no questions
/// about an office holder need today's answer too.
final _yesNoQuestion = RegExp(r'^\s*(is|was|are|were|does|did|has|have)\b|\bstill\b', caseSensitive: false);

/// "Who runs the US?", "who is in charge of Apple".
final _whoRuns = RegExp(r"\bwho('s| is)? (runs|leads|governs|rules|heads|is running|is leading|is in charge|in charge)\b",
    caseSensitive: false);

final _newsy = RegExp(r'\b(news|headlines|weather|forecast|temperature outside|stock|share price|exchange rate|bitcoin|price of|how much does .* cost|score|standings|who won|winner of|champion|election|elected|release date|just released|happening)\b', caseSensitive: false);

/// A recent or future year (2023 and later).
final _recentYear = RegExp(r'\b20(2[3-9]|[3-9]\d)\b');

bool needsWebSearch(String text) {
  final t = text.trim();
  if (t.isEmpty) return false;
  return _timeWords.hasMatch(t) ||
      _newsy.hasMatch(t) ||
      _recentYear.hasMatch(t) ||
      _whoRuns.hasMatch(t) ||
      (_officeWords.hasMatch(t) && (_whoQuestion.hasMatch(t) || _yesNoQuestion.hasMatch(t)));
}

// Wikipedia page for "who holds this office" questions. Wikipedia's keyword
// search matches the question's own words, so "Is Joe Biden the president?"
// finds an article about Biden's 2024 campaign and "Who runs the US?" a
// highway; the office's own page names the current holder in its intro.

final _officeTitles = <(RegExp, String)>[
  (RegExp(r'\bvice president\b', caseSensitive: false), 'Vice President'),
  (RegExp(r'\bprime minister\b', caseSensitive: false), 'Prime Minister'),
  (RegExp(r'\bpresident\b', caseSensitive: false), 'President'),
  (RegExp(r'\bchancellor\b', caseSensitive: false), 'Chancellor'),
  (RegExp(r'\bmayor\b', caseSensitive: false), 'Mayor'),
  (RegExp(r'\bgovernor\b', caseSensitive: false), 'Governor'),
  (RegExp(r'\bking\b', caseSensitive: false), 'King'),
  (RegExp(r'\bqueen\b', caseSensitive: false), 'Queen'),
];

final _places = <(RegExp, String)>[
  (RegExp(r"\b(u\.?s\.?a?|united states( of america)?|america|american|america's)(?=\W|$)", caseSensitive: false),
      'the United States'),
  (RegExp(r'\b(u\.?k\.?|united kingdom|great britain|britain|british|england)(?=\W|$)', caseSensitive: false),
      'the United Kingdom'),
  (RegExp(r'\b(france|french)\b', caseSensitive: false), 'France'),
  (RegExp(r'\b(germany|german)\b', caseSensitive: false), 'Germany'),
  (RegExp(r'\b(canada|canadian)\b', caseSensitive: false), 'Canada'),
];

final _ofPlace = RegExp(
  r"\bof\s+(?:the\s+)?([a-z][a-z .'-]*?)\s*(?:[?.!,]|$|\b(?:right now|now|today|currently|these days|at the moment)\b)",
  caseSensitive: false,
);

/// The Wikipedia page that names the current holder of the office a question
/// asks about, e.g. "Is Joe Biden the president?" → "President of the United
/// States", "who runs the UK" → "Prime Minister of the United Kingdom", "the
/// mayor of London" → "Mayor of London". null when there's no such office.
String? officeHolderPage(String question) {
  final text = question.trim();
  if (RegExp(r'\bpope\b', caseSensitive: false).hasMatch(text)) return 'Pope';
  String? firstMatch(List<(RegExp, String)> table) {
    for (final (pattern, value) in table) {
      if (pattern.hasMatch(text)) return value;
    }
    return null;
  }

  final office = firstMatch(_officeTitles);
  final place = firstMatch(_places);
  if (office == null) {
    if (!_whoRuns.hasMatch(text)) return null;
    if (place == 'the United States') return 'President of the United States';
    if (place == 'the United Kingdom') return 'Prime Minister of the United Kingdom';
    return null;
  }
  if (place != null) return '$office of $place';
  // "mayor of London", "governor of California": the words after "of".
  final after = _ofPlace.firstMatch(text)?.group(1)?.trim();
  if (after != null && after.isNotEmpty) {
    return '$office of ${after.replaceAllMapped(RegExp(r'\b[a-z]'), (m) => m[0]!.toUpperCase())}';
  }
  // A president with no country: the user most likely means the US one.
  if (office == 'President' || office == 'Vice President') return '$office of the United States';
  return null;
}

/// The neutral question the model answers instead of a yes/no or "who runs"
/// question about an office holder, e.g. "Is Joe Biden the president?" →
/// "Who is the president of the United States today?". A 1.5B model repeats a
/// name from the question even when the search results say otherwise; "The
/// president is Donald Trump" answers the original question correctly too.
/// null for other questions ("How old is the president?" keeps its words).
String? officeHolderQuestion(String question) {
  final page = officeHolderPage(question);
  if (page == null) return null;
  final asksWho = RegExp(r"^\s*(who|who's)\b", caseSensitive: false).hasMatch(question);
  if (!_yesNoQuestion.hasMatch(question) && !_whoRuns.hasMatch(question) && !asksWho) return null;
  // "Prime Minister of the United Kingdom" → "the prime minister of the United Kingdom".
  final office = 'the ${page.replaceFirstMapped(RegExp(r'^.*?(?= of |$)'), (m) => m[0]!.toLowerCase())}';
  return 'Who is $office today?';
}

// Spoken while the search runs, to cover the network delay, and when it
// failed. Each is one plain sentence (spoken as one piece); no "Mmm"/"Hmm",
// which the TTS voices don't pronounce well.

const _generalFillers = [
  'Well, that is a good question, let me search.',
  'That is a good question, please let me do some digging.',
  'Good question, let me look that up for you.',
  'Let me check the latest information on that.',
  'Give me a second, I will look that up.',
  'Great question, let me find out.',
];

/// Phrases for a kind of question, checked in order; the first match wins.
final _topicFillers = <({RegExp pattern, List<String> fillers})>[
  (
    pattern: RegExp(r'\b(weather|forecast|temperature|rain|snow|sunny)\b', caseSensitive: false),
    fillers: [
      'Let me check the latest forecast.',
      'Good question, let me look at the weather for you.',
      'Let me see what the weather looks like.',
    ],
  ),
  (
    pattern: RegExp(r'\b(price|cost|stock|shares?|exchange rate|bitcoin|crypto|dollar|euro|market)\b', caseSensitive: false),
    fillers: [
      'Prices change all the time, let me check the latest numbers.',
      'Let me look up the current figures for you.',
      'Good question, let me check the latest market data.',
    ],
  ),
  (
    pattern: RegExp(r'\b(score|scores|won|winner|win|match|game|champion|championship|league|cup|standings|tournament)\b', caseSensitive: false),
    fillers: [
      'Let me check the latest results.',
      'Good question, let me look up how that turned out.',
      'Let me see what the latest scores say.',
    ],
  ),
  (
    pattern: RegExp(r'\b(news|headlines|happening|happened|announced|released|election|elected)\b', caseSensitive: false),
    fillers: [
      'Let me check the latest news on that.',
      'Good question, let me see what is new.',
      'Let me look up the most recent reports.',
    ],
  ),
  (
    pattern: RegExp(r'\b(who|whom|whose|president|prime minister|ceo|pope|king|queen|leader|minister|mayor|governor|chancellor)\b', caseSensitive: false),
    fillers: [
      'That can change over time, so let me check who it is right now.',
      'Good question, let me make sure I have the latest on that.',
      'Let me check who holds that role today.',
    ],
  ),
];

String _lastFiller = '';

String _pickFrom(List<String> fillers, Random random) {
  // Never the same phrase twice in a row.
  final choices = fillers.length > 1 ? fillers.where((f) => f != _lastFiller).toList() : fillers;
  return _lastFiller = choices[random.nextInt(choices.length)];
}

/// A phrase to say while searching for [question]: usually one that fits the
/// kind of question (weather, prices, results, news, people), sometimes a
/// general one, so repeated questions don't sound scripted.
String pickSearchFiller(String question, [Random? random]) {
  final rng = random ?? Random();
  final topic = _topicFillers.where((t) => t.pattern.hasMatch(question)).firstOrNull;
  final pool = topic != null && rng.nextDouble() < 0.7 ? topic.fillers : _generalFillers;
  return _pickFrom(pool, rng);
}

const _searchFailedFillers = [
  'Sorry, I can\'t reach the internet right now.',
  'I could not connect to the internet just now.',
  'It looks like I\'m offline at the moment.',
];

/// Said when the search failed (offline, timeout); the model then answers from
/// its training data. Said by the app, not the model, so it's never left out.
const _onlineToolFillers = [
  'Let me check that online.',
  "One moment, I'm getting that from the server.",
  'Give me a second to look that up.',
  'Let me fetch that for you.',
];

/// Said while a tool that goes online (a remote MCP server) runs.
String pickOnlineToolFiller([Random? random]) => _pickFrom(_onlineToolFillers, random ?? Random());

String pickSearchFailedFiller([Random? random]) =>
    _searchFailedFillers[(random ?? Random()).nextInt(_searchFailedFillers.length)];
