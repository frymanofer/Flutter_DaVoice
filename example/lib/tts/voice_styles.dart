// Emotion / style tags for voices that have style variants ("abilities"),
// like the RN example's src/tts/voiceStyles.ts. getVoiceAbilities(voice)
// lists a voice's abilities (e.g. "whisper", "military_sergeant_hard"); empty
// when it has none. To use one, put free text in square brackets before the
// words it applies to, until the next tag:
//   "[drill sergeant] Give me 50 push-ups! [regular] Thanks."
// Tags in Portuguese work too ("[sussurrando] ..."), and are never spoken.

import 'package:flutter_davoice/flutter_davoice.dart';

class VoiceStyleExample {
  const VoiceStyleExample(this.ability, this.label, this.text);

  final String ability;
  final String label;
  final String text;
}

// One example per known ability, per language ('en', 'pt-BR'). Every tag below
// is checked to select its own ability when the voice has all of them.
const Map<String, Map<String, (String, String)>> _styleExamples = {
  'whisper': {
    'en': ('Whisper', '[whispering confidentially] Quiet, this is a secret! Do not tell anyone!'),
    'pt-BR': ('Sussurro', '[sussurrando em segredo] Silêncio, isso é um segredo! Não conte para ninguém!'),
  },
  'soft_whisper': {
    'en': ('Soft whisper', '[soft gentle whisper] Close your eyes and rest. Everything is going to be fine.'),
    'pt-BR': ('Sussurro suave', '[sussurro suave e terno] Feche os olhos e descanse. Vai ficar tudo bem.'),
  },
  'strong_whisper': {
    'en': ('Strong whisper', '[strong urgent whisper] Get down, now! They are right behind the door!'),
    'pt-BR': ('Sussurro forte', '[sussurro forte e urgente] Abaixe agora! Eles estão atrás da porta!'),
  },
  'extremly_quiet_whisper': {
    'en': ('Very quiet whisper', '[barely audible whisper] Shh... the baby is finally asleep.'),
    'pt-BR': ('Sussurro bem baixo', '[sussurro quase inaudível] Psiu... o bebê finalmente dormiu.'),
  },
  'angry_whisper': {
    'en': ('Angry whisper', '[angry whisper] I told you not to touch that. Put it back right now.'),
    'pt-BR': ('Sussurro bravo', '[sussurrando com raiva] Eu falei para não mexer nisso. Coloque de volta agora.'),
  },
  'happy_laughing': {
    'en': ('Happy', '[happy mode enjoying life] What a funny joke! I could not stop laughing.'),
    'pt-BR': ('Feliz', '[feliz e sorrindo] Que piada engraçada! Eu não consegui parar de rir.'),
  },
  'strong_happy_laughing': {
    'en': ('Laughing hard', '[laughing hysterically] Oh no, you did not just say that! That is hilarious!'),
    'pt-BR': ('Gargalhada', '[gargalhando histericamente] Não acredito que você disse isso! Que hilário!'),
  },
  'motivating': {
    'en': ('Motivating', '[motivating coach] You are stronger than you think. One more step, you can do it!'),
    'pt-BR': ('Motivador', '[treinador motivador] Você é mais forte do que imagina. Só mais um passo, você consegue!'),
  },
  'shouting_encouraging': {
    'en': ('Shouting encouragement', '[shouting encouragement] Come on! Faster! You are almost there!'),
    'pt-BR': ('Gritando incentivo', '[gritando e encorajando] Vamos lá! Mais rápido! Você está quase lá!'),
  },
  'disappointed': {
    'en': ('Disappointed', '[disappointed and sad] I really thought you would come today. Oh well.'),
    'pt-BR': ('Decepcionado', '[decepcionado e triste] Eu realmente achei que você viria hoje. Que pena.'),
  },
  'military_sergeant_hard': {
    'en': ('Drill sergeant', '[drill sergeant] Get down and give me 50 push-ups!'),
    'pt-BR': ('Sargento', '[sargento militar durão] Para o chão e me pague 50 flexões!'),
  },
  'military_sergeant_soft': {
    'en': ('Friendly sergeant', '[friendly army sergeant] Good work, soldier. Take five and drink some water.'),
    'pt-BR': ('Sargento gentil', '[sargento do exército gentil] Bom trabalho, soldado. Descanse um pouco e beba água.'),
  },
};

// An ability without a written example: its own name works as the tag.
(String, String) _genericExample(String ability, String language) {
  final words = ability.replaceAll('_', ' ').trim();
  final label = words.isEmpty ? words : words[0].toUpperCase() + words.substring(1);
  return language == 'pt-BR'
      ? (label, '[$words] Olá! Esta é a minha voz com este estilo.')
      : (label, '[$words] Hello! This is my voice in this style.');
}

// Shown first, in this order; the other abilities follow in the voice's order.
const _firstAbilities = ['military_sergeant_hard', 'whisper'];
// Shown last.
const _lastAbilities = ['disappointed'];
// Abilities without examples in a language.
const _hiddenAbilities = <String, List<String>>{
  'pt-BR': ['angry_whisper'],
};

int _abilityRank(String ability) {
  final name = ability.toLowerCase();
  if (_firstAbilities.contains(name)) return _firstAbilities.indexOf(name) - _firstAbilities.length;
  return _lastAbilities.contains(name) ? 1 + _lastAbilities.indexOf(name) : 0;
}

/// One example per ability of the voice, in [language].
List<VoiceStyleExample> voiceStyleExamples(List<String> abilities, String language) {
  final hidden = _hiddenAbilities[language] ?? const [];
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
        final (label, text) =
            _styleExamples[ability.toLowerCase()]?[language] ?? _genericExample(ability, language);
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

const Map<String, String> styleTagHint = {
  'en': 'Put a tag in square brackets before the words it applies to, e.g. [happy] Hello! or [whispering] Listen. [regular] goes back to the normal voice.',
  'pt-BR': 'Coloque uma etiqueta entre colchetes antes das palavras, por exemplo [feliz] Olá! ou [sussurrando] Escute. [normal] volta à voz normal.',
};
