import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_davoice_example/local_llm/chat_template.dart';
import 'package:flutter_davoice_example/local_llm/local_llm_service.dart';
import 'package:flutter_davoice_example/local_llm/model_config.dart';
import 'package:flutter_davoice_example/local_llm/model_store.dart';
import 'package:flutter_davoice_example/flow/transcript.dart';
import 'package:flutter_davoice_llm/flutter_davoice_llm.dart';
import 'package:flutter_davoice_llm/flutter_davoice_llm_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The engine and the agent's native side.
class FakeLlm extends FlutterDavoiceLlmPlatform with MockPlatformInterfaceMixin {
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

  // The agent: records calls; a turn streams `script` as text events.
  final agentEvents$ = StreamController<String>.broadcast();
  final agentCalls = <String>[];
  @override
  Stream<String> get agentEvents => agentEvents$.stream;
  @override
  Future<void> agentCreate(String configJson) async {}
  @override
  Future<String> agentCall(int callId, String method, String argsJson) async {
    agentCalls.add('$method $argsJson');
    if (method == 'turn') {
      for (final token in script) {
        agentEvents$.add(jsonEncode({'type': 'text', 'text': token}));
      }
    }
    scheduleMicrotask(() => agentEvents$.add(jsonEncode({'type': 'end', 'callId': callId})));
    return method == 'turn' ? jsonEncode({'text': script.join(), 'toolMessages': [], 'cancelled': false}) : 'null';
  }

  @override
  Future<void> agentClose() async {}
}

void main() {
  final chatml = presetById('chatml').template;

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
      final agent = DavoiceAgent.create({'pack': {}}, platform: platform);
      service = LocalLlmService(
        licenseKey: () => 'ok',
        llm: FlutterDavoiceLlm(platform: platform),
        store: store,
        agent: () => agent,
      );
    });

    tearDown(() => dir.delete(recursive: true));

    test('concurrent warm-ups load the model once, then set the template and prefill', () async {
      platform.loadGate = Completer<void>();
      final a = service.warmUp();
      final b = service.warmUp();
      platform.loadGate!.complete();
      await Future.wait([a, b]);
      await pumpEventQueue();
      expect(platform.loads, 1);
      expect(service.isModelReady(localLlmDefaultModelId), isTrue);
      expect(platform.agentCalls.first, startsWith('configure {"chatTemplate":{"systemPrefix":"<|im_start|>system'));
      expect(platform.agentCalls.where((c) => c.startsWith('configure')).length, 1);
      expect(platform.agentCalls, contains('prefill {"history":[],"text":""}'));
    });

    test('prefill is skipped until the model is ready', () async {
      await service.prefillForTurn(const [], 'hello');
      await pumpEventQueue();
      expect(platform.agentCalls, isEmpty);
    });

    test('a turn streams the agent\'s text and passes the history and date', () async {
      platform.script = ['Paris', '.'];
      final deltas = <String>[];
      final history = [
        {'role': 'user', 'text': 'Hi'},
        {'role': 'model', 'text': 'Hello!'},
      ];
      final turn = await service.generateReplyStream(history, 'Capital of France?', deltas.add);
      expect(deltas.join(), 'Paris.');
      expect(turn.text, 'Paris.');
      final call = platform.agentCalls.firstWhere((c) => c.startsWith('turn '));
      final args = jsonDecode(call.substring(5)) as Map;
      expect(args['text'], 'Capital of France?');
      expect(args['history'], history);
      expect(args['date'], currentDateText());
    });

    test('a rejected license fails the load and leaves it retryable', () async {
      final rejected = LocalLlmService(
        licenseKey: () => 'bad',
        llm: FlutterDavoiceLlm(platform: platform),
        store: service.store,
        agent: () => DavoiceAgent.create({'pack': {}}, platform: platform),
      );
      await expectLater(
        rejected.warmUp(),
        throwsA(isA<LocalLlmException>().having((e) => e.code, 'code', LocalLlmErrorCode.licenseRequired)),
      );
      expect(rejected.isModelReady(localLlmDefaultModelId), isFalse);
    });
  });
}
