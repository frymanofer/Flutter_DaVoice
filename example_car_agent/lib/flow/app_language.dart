// GENERATED from the React Native example (example/src: appflow.ts, narration.ts, tts/voiceClone.ts, tts/voiceStyles.ts,
// aichat/fragments.ts, local_llm/constants.ts) by the RN->Flutter table sync. Do not edit by hand: change the RN source and
// regenerate, so both apps say exactly the same.

/// One language of the language screen (RN APP_LANGUAGES): STT locale, the AI chats' reply instruction, and whether it is offered.
class AppLanguageInfo {
  const AppLanguageInfo(this.id, this.label, this.sttLocale, this.llmReplyInstruction, {this.hidden = false});

  final String id;
  final String label;
  final String sttLocale;
  final String llmReplyInstruction;

  /// Supported but not offered on the language screen.
  final bool hidden;
}

const appLanguageInfos = <AppLanguageInfo>[
  // Order = quality (2026-11-19): English; Spanish, Italian, German, Dutch (some word errors); Brazilian Portuguese (kept here for
  // VW Brazil); Greek, Swedish, Danish (a bit robotic); French, European Portuguese (more mistakes). Hebrew is hidden.
  AppLanguageInfo('en', 'English', 'en-US', 'The user speaks English. Always reply in English.'),
  AppLanguageInfo('es', 'Español (Spanish)', 'es-ES', 'The user speaks Spanish. Always reply in Spanish.'),
  AppLanguageInfo('it', 'Italiano (Italian)', 'it-IT', 'The user speaks Italian. Always reply in Italian.'),
  AppLanguageInfo('de', 'Deutsch (German)', 'de-DE', 'The user speaks German. Always reply in German.'),
  AppLanguageInfo('nl', 'Nederlands (Dutch)', 'nl-NL', 'The user speaks Dutch. Always reply in Dutch.'),
  AppLanguageInfo('pt-BR', 'Português do Brasil (Brazilian Portuguese)', 'pt-BR', 'Important: always reply in Brazilian Portuguese (pt-BR). Sempre responda em português do Brasil.'),
  AppLanguageInfo('el', 'Ελληνικά (Greek)', 'el-GR', 'The user speaks Greek. Always reply in Greek. Απάντα πάντα στα ελληνικά.'),
  AppLanguageInfo('sv', 'Svenska (Swedish)', 'sv-SE', 'The user speaks Swedish. Always reply in Swedish. Svara alltid på svenska.'),
  AppLanguageInfo('da', 'Dansk (Danish)', 'da-DK', 'The user speaks Danish. Always reply in Danish. Svar altid på dansk.'),
  AppLanguageInfo('fr', 'Français (French)', 'fr-FR', 'The user speaks French. Always reply in French.'),
  AppLanguageInfo('pt-PT', 'Português de Portugal (European Portuguese)', 'pt-PT', 'Important: always reply in European Portuguese (pt-PT), never Brazilian Portuguese. Responde sempre em português de Portugal.'),
  AppLanguageInfo('he', 'עברית (Hebrew)', 'he-IL', 'The user speaks Hebrew. Always reply in Hebrew. ענה תמיד בעברית.', hidden: true),
];

/// Every language id the app knows.
final appLanguages = [for (final l in appLanguageInfos) l.id];

/// A TTS v1 model's own voice (named after the language): no voice conversion, so much faster. Shown first, the language's default voice.
const originalTtsVoices = {
  'da': 'Mads',
  'sv': 'Erik',
  'el': 'Eleni',
};

String _current = 'en';

/// The app's language (an id of [appLanguageInfos]).
String get currentAppLanguage => _current;

void setCurrentAppLanguage(String language) {
  _current = appLanguages.contains(language) ? language : 'en';
}

/// Portuguese (Brazil or Portugal): Portuguese voice names and speeds, as RN's isPortuguese().
bool get isPortuguese => _current == 'pt-BR' || _current == 'pt-PT';

AppLanguageInfo appLanguageInfo(String language) =>
    appLanguageInfos.firstWhere((l) => l.id == language, orElse: () => appLanguageInfos.first);

/// The system-prompt line that sets the AI chats' reply language.
String llmReplyInstructionFor(String language) => appLanguageInfo(language).llmReplyInstruction;
