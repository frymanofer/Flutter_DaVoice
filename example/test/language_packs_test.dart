import 'dart:convert';
import 'dart:io';

import 'package:flutter_davoice_example/flow/app_language.dart';
import 'package:flutter_davoice_example/flow/narration.dart';
import 'package:flutter_davoice_example/tts/language_packs.dart';
import 'package:flutter_davoice_example/tts/voice_styles.dart';
import 'package:flutter_davoice_example/voice_clone/voice_clone.dart';
import 'package:flutter_test/flutter_test.dart';

// Which languages' voices are built in vs downloaded (assets/language_packs.json), as the React Native example; every offered
// language gets a TTS model, a voice-cloning encoder, narration, a reading text and style examples (RN ttsLanguage.test.ts,
// narration.test.ts, voiceStyles.test.ts).
void main() {
  final config = jsonDecode(File('assets/language_packs.json').readAsStringSync()) as Map<String, dynamic>;
  final bundled = [for (final id in config['bundled'] as List) id as String];
  final languages = config['languages'] as Map<String, dynamic>;
  final declared = RegExp(r'^\s+- (assets/\S+)', multiLine: true)
      .allMatches(File('pubspec.yaml').readAsStringSync())
      .map((m) => m.group(1)!)
      .toSet();
  String file(String id, String kind) => (languages[id][kind] as Map)['file'] as String;

  tearDown(() => setCurrentAppLanguage('en'));

  test('built-in languages are in the app, downloaded ones are not (APK size)', () {
    expect(bundled, ['en', 'pt-BR']);
    for (final id in languages.keys) {
      for (final kind in ['model', 'embedder']) {
        final asset = 'assets/models/${file(id, kind)}';
        if (bundled.contains(id)) {
          expect(declared, contains(asset), reason: '$id $kind is built in: list it in pubspec.yaml');
          expect(File(asset).lengthSync(), (languages[id][kind] as Map)['bytes'], reason: '$asset size = language_packs.json');
        } else {
          expect(declared, isNot(contains(asset)), reason: '$id is downloaded: do not ship $asset');
        }
      }
    }
    expect((config['baseUrl'] as String).startsWith('https://'), isTrue);
  });

  test('every offered language has its voices (built in or a language pack)', () {
    for (final l in appLanguageInfos.where((l) => !l.hidden)) {
      expect(languages.containsKey(l.id), isTrue, reason: '${l.id} is offered but has no voices in language_packs.json');
    }
  });

  test('a downloaded language uses the downloaded files once they are complete', () async {
    expect(isDownloadableLanguage('fr'), isTrue);
    expect(isDownloadableLanguage('pt-BR'), isFalse);
    expect(languageFile('pt-BR', 'model'), 'assets/models/model_ex2_portuguese_brv3.dm');
    expect(await isLanguagePackReady('fr'), isFalse);
    expect(languageFile('fr', 'model'), isNull);
    setCurrentAppLanguage('fr');
    expect(voiceEmbedder, 'assets/models/embedder_en.dm', reason: 'not downloaded yet: English');

    // Fake a complete download (right sizes) in the test's documents folder.
    final docs = (await Directory.systemTemp.createTemp('lp')).path;
    await loadLanguagePacks(config: LanguagePackConfig.fromJson(config), documents: Directory(docs));
    for (final kind in ['model', 'embedder']) {
      final f = File('$docs/language_packs/fr/${file('fr', kind)}')..createSync(recursive: true);
      final raf = f.openSync(mode: FileMode.write)..truncateSync((languages['fr'][kind] as Map)['bytes'] as int);
      raf.closeSync();
    }
    // a download of the first (unversioned) layout is moved into its version folder: language_packs/<lang>/<version>/<file>
    expect(await isLanguagePackReady('fr'), isTrue);
    expect(languageFile('fr', 'model'), matches(RegExp('^${RegExp.escape(docs)}/language_packs/fr/[0-9a-f]{12}-[0-9a-f]{12}/model_ex2_french\\.dm\$')));
    expect(voiceEmbedder, matches(RegExp('^${RegExp.escape(docs)}/language_packs/fr/[0-9a-f]{12}-[0-9a-f]{12}/embedder_fr\\.dm\$')));
  });

  test('every language has complete narration, a reading text and style examples', () {
    const known = ['military_sergeant_hard', 'whisper', 'soft_whisper', 'strong_whisper', 'extremly_quiet_whisper', 'angry_whisper',
        'happy_laughing', 'strong_happy_laughing', 'motivating', 'shouting_encouraging', 'disappointed'];
    for (final l in appLanguageInfos) {
      final n = narrationFor(l.id);
      expect(n.wakeWordDetected('DaVoice'), contains('DaVoice'));
      expect(n.introduction('Eleni'), hasLength(3));
      expect(n.introduction('Eleni').first, contains('Eleni'));
      expect(n.cloningChoices(true), isNotEmpty);
      expect(n.sayWakeWord('Hey Coach'), contains('Hey Coach'));
      expect(n.cloneCreated('Eleni'), contains('Eleni'));
      setCurrentAppLanguage(l.id);
      expect(voiceCloneReadingText, isNotEmpty);
      final examples = voiceStyleExamples(known, l.id);
      expect(examples.map((e) => e.ability).toSet(), known.toSet(), reason: l.id);
      for (final e in examples) {
        expect(e.text, matches(RegExp(r'^\[[^\]]+\] .+')), reason: '${l.id} ${e.ability}');
        expect(e.text, isNot(contains('_')));
      }
    }
    expect(narrationFor('el').wakeWordDetected('X'), isNot(narrationFor('en').wakeWordDetected('X')));
    expect(originalTtsVoices, {'da': 'Mads', 'sv': 'Erik', 'el': 'Eleni'});
  });
}
