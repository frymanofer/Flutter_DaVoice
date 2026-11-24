// What to play = the driver's own words when the model copied them wrong (2026-11-22 phone: "Play Pretty Woman" -> play_media
// {query: "Perma Woman"}; "Can you play pretty woman on the radio please?" -> "woman"). Port of the RN car app's
// src/car/mediaQuery.ts; shared fixture test/fixtures/media_query.json (identical to the RN one).

// the words before the title (the first one: a title may hold one, "Play Let Me Play")
final _playVerb = RegExp(r'(?<!\p{L})(?:play|put on|listen to|toca|toque|tocar|coloca|coloque|bota|poe|põe|quero ouvir|ouvir)(?!\p{L})',
    caseSensitive: false, unicode: true);
// words after the title that are not part of it
final _trailing = RegExp(
    r'(?:\s+(?:on the radio|on spotify|in the car|for me|please|now|right now|no radio|no rádio|no spotify|pra mim|para mim|por favor|agora))+\s*$',
    caseSensitive: false);
// words a copy may leave out or add without changing what is played
const _small = {'a', 'o', 'as', 'os', 'the', 'some', 'um', 'uma', 'me', 'de', 'do', 'da', 'song', 'musica', 'cancao'};

const _accents = {'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'é': 'e', 'ê': 'e', 'è': 'e', 'ë': 'e', 'í': 'i', 'ì': 'i', 'î': 'i',
  'ï': 'i', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ò': 'o', 'ö': 'o', 'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c', 'ñ': 'n'};

String _norm(String w) =>
    w.toLowerCase().split('').map((c) => _accents[c] ?? c).join().replaceAll(RegExp(r'[^a-z0-9]'), '');
List<String> _words(String s) => s.split(RegExp(r'\s+')).map(_norm).where((w) => w.isNotEmpty).toList();

/// The title the driver said after the play verb (their own spelling), or null.
String? spokenTitle(String userText) {
  final m = _playVerb.firstMatch(userText);
  if (m == null) return null;
  final span = userText
      .substring(m.end)
      .replaceFirst(RegExp(r'[?.!]+\s*$'), '')
      .replaceFirst(_trailing, '')
      .replaceAll(RegExp(r'^[\s,]+|[\s,]+$'), '');
  return _words(span).isEmpty ? null : span;
}

String _titleCase(String s) => s == s.toLowerCase()
    ? s.replaceAllMapped(RegExp(r'(^|\s)(\p{L})', unicode: true), (m) => '${m[1]}${m[2]!.toUpperCase()}')
    : s;

/// The query to play: the model's, or the driver's words when the model's is a damaged copy of them.
String groundMediaQuery(String query, String userText) {
  final span = spokenTitle(userText);
  if (span == null) return query;
  final q = _words(query).where((w) => !_small.contains(w)).toList();
  final s = _words(span).where((w) => !_small.contains(w)).toList();
  if (q.isEmpty || s.isEmpty || q.join(' ') == s.join(' ')) return query;
  final exact = q.where(s.contains).length;
  if (exact == 0) return query; // not a copy of what was said
  // (a) words left out: every query word was said, some said words are missing ("woman" for "pretty woman")
  final leftOut = exact == q.length && s.length > q.length;
  // (b) words misspelt: as many words, at least half exact, the others start with the same letter ("Perma Woman")
  var misspelt = q.length == s.length && exact * 2 >= q.length;
  for (var i = 0; misspelt && i < q.length; i++) {
    if (!s.contains(q[i]) && q[i][0] != s[i][0]) misspelt = false;
  }
  return leftOut || misspelt ? _titleCase(span) : query;
}
