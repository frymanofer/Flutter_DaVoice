// When a pause ends the driver's request (2026-11-25 iPhone log: "Look at", "Please", "Yeah, it's" were sent after the
// end-of-speech silence while the driver was still talking). Words that cannot end a request ("Set the", "Open", "Can you",
// "Please") get a longer pause before they are sent. The same rule as the React Native car agent (src/stt/endOfSpeech.ts).

/// Extra wait when the words so far cannot end a request (ms).
const int unfinishedExtraMs = 2000;

const Map<String, String> _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'é': 'e', 'ê': 'e', 'è': 'e', 'í': 'i', 'î': 'i', 'ó': 'o', 'ô': 'o', 'õ': 'o',
  'ö': 'o', 'ú': 'u', 'ü': 'u', 'ç': 'c', 'ñ': 'n',
};

String _fold(String s) {
  final lower = s.toLowerCase().split('').map((c) => _accents[c] ?? c).join();
  return lower.replaceAll(RegExp(r"[’']"), ' ').replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

class _Words {
  const _Words(this.last, this.lastTwo, this.alone);
  final Set<String> last;
  final Set<String> lastTwo;
  final Set<String> alone;
}

const _en = _Words(
  {'the', 'a', 'an', 'to', 'at', 'of', 'on', 'in', 'into', 'onto', 'for', 'with', 'from', 'by', 'about', 'and', 'or', 'but',
    'my', 'your', 'our', 'their', 'his', 'her', 'its', 'is', 'are', 'was', 'can', 'could', 'would', 'will', 'should', 'please', 'than'},
  {'can you', 'could you', 'would you', 'will you', 'it s', 'that s', 'there s', 'i want', 'i d like', 'i would like',
    'set the', 'turn the', 'turn on', 'turn off', 'turn up', 'turn down'},
  {'open', 'close', 'shut', 'set', 'turn', 'put', 'make', 'play', 'lock', 'unlock', 'raise', 'lower', 'increase', 'decrease',
    'navigate', 'take', 'find', 'switch', 'tune', 'change', 'hey', 'so', 'um', 'uh', 'and'},
);

const _pt = _Words(
  {'o', 'a', 'os', 'as', 'de', 'do', 'da', 'dos', 'das', 'no', 'na', 'nos', 'nas', 'em', 'para', 'pra', 'pro', 'por', 'com',
    'e', 'ou', 'mas', 'um', 'uma', 'meu', 'minha', 'seu', 'sua', 'que', 'ao', 'pelo', 'pela'},
  {'voce pode', 'vc pode', 'por favor', 'eu quero', 'eu queria', 'liga o', 'liga a'},
  {'abre', 'fecha', 'coloca', 'poe', 'bota', 'aumenta', 'diminui', 'abaixa', 'baixa', 'sobe', 'toca', 'muda', 'troca',
    'tranca', 'destranca', 'navega', 'leva', 'ei', 'entao', 'e'},
);

/// The words so far cannot end a request ("Set the", "Can you", "Please"). Languages other than English / Portuguese: never.
bool looksUnfinished(String text, String language) {
  final words = _fold(text).split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return false;
  final set = language == 'en' ? _en : language.startsWith('pt') ? _pt : null;
  if (set == null) return false;
  final last = words.last;
  if (words.length == 1 && (set.alone.contains(last) || (identical(set, _en) && last == 'please'))) return true;
  if (words.length >= 2 && set.lastTwo.contains('${words[words.length - 2]} $last')) {
    // "por favor" ends many requests ("Fecha a janela, por favor"): unfinished only when it is all that was said
    return !(identical(set, _pt) && last == 'favor' && words.length > 2);
  }
  if (last == 'please') return false;   // "yes please" / "close it please"
  return set.last.contains(last);
}

/// The silence that ends this request: the end-of-speech setting, longer when the words so far cannot end a request.
int silenceFor(String text, int baseMs, String language) => looksUnfinished(text, language) ? baseMs + unfinishedExtraMs : baseMs;
