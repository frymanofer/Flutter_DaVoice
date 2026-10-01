import 'package:flutter/services.dart';
import 'package:flutter_davoice/flutter_davoice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_wake_word/flutter_wake_word.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Rich ex2 and Hanna/Ariana ex models work through real native bridges',
    (tester) async {
      final speech = FlutterDavoice();
      final wakeword = createKeyWordFlutterPCInstance('parity_smoke');
      var wakewordCreated = false;
      var ttsInitialized = false;
      addTearDown(() async {
        try {
          if (ttsInitialized) await speech.stopSpeaking();
        } finally {
          try {
            await speech.destroyAll();
          } finally {
            if (wakewordCreated) await wakeword.destroyInstance();
          }
        }
      });
      final license = (await rootBundle.loadString('licensekey.txt')).trim();
      expect(await speech.setLicense(license), isTrue);
      await wakeword.createInstanceMulti(
        'parity_smoke',
        ['assets/models/hey_coach_model_28_22012026b.dm'],
        [0.999],
        [3],
        [1000],
      );
      wakewordCreated = true;
      expect(await wakeword.setKeywordDetectionLicense(license), isTrue);
      final verification = await createSpeakerVerificationMicController(
        'parity_sv',
      );
      try {
        await verification.create({
          'modelPath': 'assets/models/sv.dm',
          'options': {
            'decisionThreshold': 0.35,
            'tailSeconds': 2.0,
            'frameSize': 1280,
            'maxTailSeconds': 3.0,
            'cmn': true,
            'expectedLayoutBDT': false,
          },
        });
      } finally {
        await verification.destroy();
      }
      for (final voice in [
        (name: 'Rich', model: 'model_ex2_rich.dm', speed: 0.95),
        (
          name: 'Hanna',
          model: 'model_ex_hanna_light_davoice_ph.dm',
          speed: 0.9,
        ),
        (
          name: 'Ariana',
          model: 'model_ex_ariana_fast_davoice_phoneme.dm',
          speed: 0.88,
        ),
      ]) {
        if (ttsInitialized) {
          await speech.stopSpeaking();
          await speech.destroyAll();
          ttsInitialized = false;
        }
        await speech.initTTS('assets/models/${voice.model}');
        ttsInitialized = true;
        if (voice.name == 'Rich') expect(await speech.changeVoice('Rich'), 0);
        await speech.speak(
          'Hello. My name is ${voice.name}.',
          speed: voice.speed,
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
