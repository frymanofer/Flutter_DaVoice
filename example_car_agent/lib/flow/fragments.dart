import 'rn_tables.g.dart';

// Speech-recognition noise ("The.", "But.", "Boy.", "Alma Alma." between real commands): answered with "didn't catch that" instead
// of going to the model. Port of the RN example's src/aichat/fragments.ts (same word lists and rules).

const _fillers = {
  'the', 'a', 'an', 'and', 'but', 'or', 'so', 'then', 'um', 'uh', 'uhm', 'hmm', 'mm', 'oh', 'ah', 'eh', 'boy', 'well', 'like', 'just',
  'o', 'os', 'as', 'e', 'é', 'mas', 'ou', 'então', 'entao', 'tipo', 'né', 'ne', 'hã', 'ha', 'hum', 'ahn', 'ué', 'ue', 'peraí', 'perai', 'bom',
};

List<String> _words(String text) =>
    text.toLowerCase().replaceAll(RegExp(r"[^\p{L}\p{N}\s']", unicode: true), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

/// True for a transcript that is only noise: filler words, or one word said twice ("Alma Alma.").
bool isNoiseFragment(String text) {
  final words = _words(text);
  if (words.isEmpty) return true;
  if (words.length > 2 || words.any((w) => RegExp(r'\d').hasMatch(w))) return false;
  if (words.every(_fillers.contains)) return true;
  return words.length == 2 && words[0] == words[1];
}

/// A very short request (two words or fewer, no number): too little to be a real "can't do that".
bool isTooShortForDecline(String text) {
  final words = _words(text);
  return words.length <= 2 && !words.any((w) => RegExp(r'\d').hasMatch(w));
}

/// A bare "Done." (en / pt): in the car demo every real action is confirmed by the app's own sentence from the tool result, so the
/// model saying only "Done." means nothing was done.
bool isBareDone(String sentence) =>
    RegExp(r'^\s*(done|all set|okay,? done|ok,? done|pronto|prontinho|feito|ok,? feito|tudo certo)\s*[.!]?\s*$', caseSensitive: false).hasMatch(sentence);

/// "Didn't catch that" per language (RN DID_NOT_CATCH; English for a language without its own).
const didNotCatch = didNotCatchTexts;
