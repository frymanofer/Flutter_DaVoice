// Emotion / style tags for voices that have style variants ("abilities"),
// like the RN example's src/tts/voiceStyles.ts. getVoiceAbilities(voice)
// lists a voice's abilities (e.g. "whisper", "military_sergeant_hard"); empty
// when it has none. To use one, put free text in square brackets before the
// words it applies to, until the next tag:
//   "[drill sergeant] Give me 50 push-ups! [regular] Thanks."
// Tags in Portuguese work too ("[sussurrando] ..."), and are never spoken.

import 'package:flutter_davoice/flutter_davoice.dart';

import '../flow/rn_tables.g.dart';

class VoiceStyleExample {
  const VoiceStyleExample(this.ability, this.label, this.text);

  final String ability;
  final String label;
  final String text;
}

// One example per known ability, per language, and the generic example of an ability without one: lib/flow/rn_tables.g.dart
// (generated from the RN example's src/tts/voiceStyles.ts, every language).
(String, String) _example(String ability, String language) {
  final known = styleExamplesByAbility[ability.toLowerCase()]?[language];
  if (known != null) return known;
  final words = ability.replaceAll('_', ' ').trim();
  final label = words.isEmpty ? words : words[0].toUpperCase() + words.substring(1);
  return (label, genericStyleText(language, words));
}

// Shown first, in this order; the other abilities follow in the voice's order.
const _firstAbilities = ['military_sergeant_hard', 'whisper'];
// Shown last.
const _lastAbilities = ['disappointed'];

int _abilityRank(String ability) {
  final name = ability.toLowerCase();
  if (_firstAbilities.contains(name)) return _firstAbilities.indexOf(name) - _firstAbilities.length;
  return _lastAbilities.contains(name) ? 1 + _lastAbilities.indexOf(name) : 0;
}

/// One example per ability of the voice, in [language].
List<VoiceStyleExample> voiceStyleExamples(List<String> abilities, String language) {
  final hidden = hiddenStyleAbilities[language] ?? const [];
  final shown = abilities.where((ability) => !hidden.contains(ability.toLowerCase())).toList();
  // A stable sort: same-rank abilities keep the voice's order.
  final ordered = [for (var i = 0; i < shown.length; i++) (i, shown[i])]
    ..sort((a, b) {
      final byRank = _abilityRank(a.$2).compareTo(_abilityRank(b.$2));
      return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
    });
  return [
    for (final (_, ability) in ordered)
      () {
        final (label, text) = _example(ability, language);
        return VoiceStyleExample(ability, label, text);
      }(),
  ];
}

/// The abilities of each voice (voices without any are left out).
Future<Map<String, List<String>>> loadVoiceAbilities(FlutterDavoice speech, List<String> voices) async {
  final result = <String, List<String>>{};
  for (final voice in voices) {
    try {
      final abilities = await speech.getVoiceAbilities(voice);
      if (abilities.isNotEmpty) result[voice] = abilities;
    } catch (_) {
      // A voice that can't be queried is listed without styles.
    }
  }
  return result;
}

/// The tag hint per language (RN STYLE_TAG_HINT).
const styleTagHint = styleTagHints;
