// On-device check of Local AI Chat's engine path, without the voice UI:
// downloads (if needed) and loads the selected model through the same
// LocalLlmService the app uses, then streams replies.
//
//   flutter test integration_test/local_llm_smoke_test.dart -d <device>
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_davoice_example/agent/agent_pack.dart';
import 'package:flutter_davoice_example/local_llm/local_llm_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Local AI Chat's prompts, rules and tools (assets/agent/).
  setUpAll(loadAgentPack);

  testWidgets(
    'local LLM downloads, loads, streams, reuses the cache and cancels',
    (tester) async {
      final license = (await rootBundle.loadString('licensekey.txt')).trim();
      final service = LocalLlmService(licenseKey: () => license);

      var lastPercent = -10;
      final load = Stopwatch()..start();
      final model = await service.warmUp(onDownloadProgress: (fraction) {
        final percent = (fraction * 100).floor();
        if (percent >= lastPercent + 10) {
          lastPercent = percent;
          debugPrint('[LocalLlmSmoke] download $percent%');
        }
      });
      debugPrint('[LocalLlmSmoke] ${model.displayName} ready after ${load.elapsedMilliseconds} ms');
      expect(service.isModelReady(model.id), isTrue);

      Future<String> ask(List<Map<String, Object?>> history, String question) async {
        final reply = StringBuffer();
        final timer = Stopwatch()..start();
        int? firstTokenMs;
        await service.generateReplyStream(history, question, (delta) {
          firstTokenMs ??= timer.elapsedMilliseconds;
          reply.write(delta);
        });
        debugPrint('[LocalLlmSmoke] "$question" -> first token ${firstTokenMs}ms, '
            'total ${timer.elapsedMilliseconds}ms: ${reply.toString().trim()}');
        return reply.toString().trim();
      }

      final first = await ask(const [], 'What is the capital of France? Answer in one short sentence.');
      expect(first.toLowerCase(), contains('paris'));

      // Second turn: the first turn is already in the cache.
      final history = [
        {'role': 'user', 'text': 'What is the capital of France? Answer in one short sentence.'},
        {'role': 'model', 'text': first},
      ];
      await service.prefillForTurn(history, 'And of');
      final second = await ask(history, 'And of Japan?');
      expect(second.toLowerCase(), contains('tokyo'));

      // Cancel shortly after a long reply starts: it must end early and cleanly.
      final pieces = <String>[];
      final long = service.generateReplyStream(
        const [],
        'Write a long story about a dragon, at least 400 words.',
        (delta) {
          pieces.add(delta);
          if (pieces.length == 5) service.cancel();
        },
      );
      await long.timeout(const Duration(seconds: 60));
      debugPrint('[LocalLlmSmoke] cancelled after ${pieces.length} pieces');
      expect(pieces.length, lessThan(60));

      // Still usable after the cancel.
      expect((await ask(const [], 'What is 2 plus 2? Answer with the number.')), contains('4'));
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
