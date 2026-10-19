import 'dart:async';
import 'dart:io';

import 'package:flutter_davoice_example/local_llm/chat_template.dart';
import 'package:flutter_davoice_example/local_llm/local_llm_service.dart';
import 'package:flutter_davoice_example/local_llm/model_config.dart';
import 'package:flutter_davoice_example/local_llm/model_store.dart';
import 'package:flutter_davoice_example/local_llm/prompt.dart';
import 'package:flutter_davoice_llm/flutter_davoice_llm.dart';
import 'package:flutter_davoice_llm/flutter_davoice_llm_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLlm extends FlutterDavoiceLlmPlatform {
  final events = StreamController<LocalLlmTokenEvent>.broadcast(sync: true);
  int loads = 0;
  final prefills = <String>[];
  final prompts = <String>[];
  int cancels = 0;
  List<String> script = const [];
  Completer<void>? loadGate;

  @override
  Stream<LocalLlmTokenEvent> get tokenEvents => events.stream;
  @override
  Future<bool> setLicense(String licenseKey) async => licenseKey == 'ok';
  @override
  Future<void> loadModel(String modelPath, LocalLlmLoadOptions options) async {
    loads++;
    await loadGate?.future;
  }

  @override
  Future<void> generateStream(String prompt, int requestId) async {
    prompts.add(prompt);
    for (final token in script) {
      events.add(LocalLlmTokenEvent(requestId: requestId, token: token, done: false));
    }
    events.add(LocalLlmTokenEvent(requestId: requestId, token: '', done: true));
  }

  @override
  Future<void> prefill(String prompt) async => prefills.add(prompt);
  @override
  Future<void> cancel() async => cancels++;
  @override
  Future<void> unloadModel() async {}
  @override
  Future<bool> isModelLoaded() async => loads > 0;
}

void main() {
  final chatml = presetById('chatml').template;
  final gemma = presetById('gemma').template;
  const history = [
    ChatTurn(fromUser: true, text: 'Hi'),
    ChatTurn(fromUser: false, text: 'Hello!'),
  ];

  group('assemblePrompt', () {
    test('ChatML: system turn, history, then the assistant prefix', () {
      expect(
        assemblePrompt(template: chatml, history: history, userText: 'How are you?', systemPrompt: 'SYS'),
        '<|im_start|>system\nSYS<|im_end|>\n'
        '<|im_start|>user\nHi<|im_end|>\n'
        '<|im_start|>assistant\nHello!<|im_end|>\n'
        '<|im_start|>user\nHow are you?<|im_end|>\n'
        '<|im_start|>assistant\n',
      );
    });

    test('Gemma: no system role, so the system prompt joins the first user turn', () {
      expect(
        assemblePrompt(template: gemma, history: const [], userText: 'Hi', systemPrompt: 'SYS'),
        '<start_of_turn>user\nSYS\n\nHi<end_of_turn>\n<start_of_turn>model\n',
      );
    });

    test('the prefill prefix is an exact prefix of the final prompt', () {
      for (final template in [chatml, gemma]) {
        final prefix = assemblePromptPrefix(template: template, history: history, partialUserText: 'How are');
        final full = assemblePrompt(template: template, history: history, userText: 'How are you?');
        expect(full.startsWith(prefix), isTrue);
        final empty = assemblePromptPrefix(template: template, history: const [], partialUserText: '');
        expect(assemblePrompt(template: template, history: const [], userText: 'x').startsWith(empty), isTrue);
      }
    });
  });

  group('StopSequenceFilter', () {
    test('cuts at a stop sequence split across tokens', () {
      final filter = StopSequenceFilter(['<|im_end|>']);
      final out = StringBuffer();
      for (final token in ['Paris', ' is nice.', '<|im', '_end|>', 'garbage']) {
        out.write(filter.push(token));
      }
      out.write(filter.flush());
      expect(out.toString(), 'Paris is nice.');
      expect(filter.isStopped, isTrue);
    });

    test('releases held text that turned out not to be a stop sequence', () {
      final filter = StopSequenceFilter(['<|im_end|>']);
      expect(filter.push('a <|i'), 'a ');
      expect(filter.flush(), '<|i');
    });
  });

  test('splitCompletedSentences keeps the unfinished tail', () {
    final split = splitCompletedSentences('Hello there. How are "you?" I am');
    expect(split.completed, ['Hello there.', 'How are "you?"']);
    expect(split.remainder, 'I am');
  });

  group('LocalLlmModelStore', () {
    late Directory dir;
    late LocalLlmModelStore store;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('local_llm_test');
      store = LocalLlmModelStore(baseDirectory: () async => dir);
    });

    tearDown(() => dir.delete(recursive: true));

    test('defaults to Qwen2.5 1.5B and persists selection and custom models', () async {
      expect((await store.selectedModel()).id, localLlmDefaultModelId);
      final custom = await store.addCustomModel(
        displayName: 'My Llama',
        url: 'https://example.com/m.gguf',
        contextSize: 2048,
        chatTemplate: presetById('llama3').template,
      );
      expect(custom.id, 'custom-my-llama');
      await store.selectModel(custom.id);

      final reopened = LocalLlmModelStore(baseDirectory: () async => dir);
      final selected = await reopened.selectedModel();
      expect(selected.id, 'custom-my-llama');
      expect(findMatchingPreset(selected.chatTemplate)?.id, 'llama3');

      await reopened.removeCustomModel(custom.id);
      expect((await reopened.selectedModel()).id, localLlmDefaultModelId);
    });

    test('rejects invalid custom models', () async {
      Future<void> add(String url, int context) => store.addCustomModel(
            displayName: 'X',
            url: url,
            contextSize: context,
            chatTemplate: chatml,
          );
      await expectLater(add('http://a/m.gguf', 2048), throwsFormatException);
      await expectLater(add('https://a/m.bin', 2048), throwsFormatException);
      await expectLater(add('https://a/m.gguf', 100), throwsFormatException);
    });
  });

  group('LocalLlmService', () {
    late Directory dir;
    late FakeLlm platform;
    late LocalLlmService service;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('local_llm_service');
      final store = LocalLlmModelStore(baseDirectory: () async => dir);
      // Pretend the default model is downloaded.
      final file = File(await store.modelPath(await store.selectedModel()));
      await file.parent.create(recursive: true);
      await file.writeAsString('gguf');
      platform = FakeLlm();
      service = LocalLlmService(
        licenseKey: () => 'ok',
        llm: FlutterDavoiceLlm(platform: platform),
        store: store,
      );
    });

    tearDown(() => dir.delete(recursive: true));

    test('concurrent warm-ups load the model once, then prefill the system prompt', () async {
      platform.loadGate = Completer<void>();
      final a = service.warmUp();
      final b = service.warmUp();
      platform.loadGate!.complete();
      await Future.wait([a, b]);
      expect(platform.loads, 1);
      expect(service.isModelReady(localLlmDefaultModelId), isTrue);
      expect(
        platform.prefills.first,
        "<|im_start|>system\n$voiceAssistantPersona\n\nToday's date is ${currentDateText()}.<|im_end|>\n<|im_start|>user\n",
      );
    });

    test('prefill is skipped until the model is ready', () async {
      await service.prefillForTurn(const [], 'hello');
      expect(platform.prefills, isEmpty);
    });

    test('generateReplyStream strips the turn-end marker and cancels at it', () async {
      platform.script = ['Paris', '.', '<|im_end|>', 'leak'];
      final deltas = <String>[];
      await service.generateReplyStream(const [], 'Capital of France?', deltas.add);
      expect(deltas.join(), 'Paris.');
      expect(platform.cancels, 1);
      expect(platform.prompts.single, endsWith('<|im_start|>user\nCapital of France?<|im_end|>\n<|im_start|>assistant\n'));
    });

    test('a rejected license fails the load and leaves it retryable', () async {
      final rejected = LocalLlmService(
        licenseKey: () => 'bad',
        llm: FlutterDavoiceLlm(platform: platform),
        store: service.store,
      );
      await expectLater(
        rejected.warmUp(),
        throwsA(isA<LocalLlmException>().having((e) => e.code, 'code', LocalLlmErrorCode.licenseRequired)),
      );
      expect(rejected.isModelReady(localLlmDefaultModelId), isFalse);
    });
  });
}
