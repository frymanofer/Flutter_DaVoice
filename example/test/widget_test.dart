import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_davoice_example/main.dart';
import 'package:flutter_davoice/flutter_davoice_platform_interface.dart';
import 'package:flutter_davoice/flutter_davoice_method_channel.dart';

void main() {
  for (final selectedVoice in ['Rich', 'Hanna', 'Ariana']) {
    testWidgets(
      'Rich startup and $selectedVoice selection load the correct model',
      (tester) async {
        rootBundle.clear();
        FlutterDavoicePlatform.instance = MethodChannelFlutterDavoice();
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final init = Completer<void>();
        final calls = <String>[];
        final voices = <String>[];
        final models = <String>[];
        final wakewordPauseStopMicValues = <bool>[];
        const speech = MethodChannel('flutter_davoice');
        const wakeword = MethodChannel('flutter_wake_word');
        const permissions = MethodChannel(
          'flutter.baseflow.com/permissions/methods',
        );
        const speechEvents = MethodChannel('flutter_davoice/events');
        const wakewordEvents = MethodChannel('flutter_wake_word/events');
        const paths = MethodChannel('plugins.flutter.io/path_provider');
        messenger.setMockMethodCallHandler(
          paths,
          (_) async => '/tmp/davoice-flutter-parity-no-enrollment',
        );
        messenger.setMockMethodCallHandler(permissions, (_) async => 1);
        messenger.setMockMethodCallHandler(speechEvents, (_) async => null);
        messenger.setMockMethodCallHandler(wakewordEvents, (_) async => null);
        messenger.setMockMethodCallHandler(wakeword, (call) async {
          calls.add('wakeword.${call.method}');
          if (call.method == 'pauseDetection') {
            wakewordPauseStopMicValues.add(
              (call.arguments as Map)['stopMic'] as bool,
            );
          }
          if (call.method == 'getRecordingWav') return '';
          return call.method == 'setAudioRoutingConfig' ? null : true;
        });
        messenger.setMockMethodCallHandler(speech, (call) async {
          calls.add('speech.${call.method}');
          if (call.method == 'initAll') {
            models.add((call.arguments as Map)['model'] as String);
            await init.future;
            return null;
          }
          if (call.method == 'changeVoice') {
            voices.add((call.arguments as Map)['name'] as String);
            return 0;
          }
          if (call.method == 'setLicense') return true;
          return null;
        });
        addTearDown(() {
          for (final channel in [
            speech,
            wakeword,
            permissions,
            speechEvents,
            wakewordEvents,
            paths,
          ]) {
            messenger.setMockMethodCallHandler(channel, null);
          }
        });
        await tester.pumpWidget(const DavoiceExampleApp());
        for (var i = 0; i < 30 && !calls.contains('speech.initAll'); i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(calls, contains('speech.initAll'));
        expect(find.text('Choose Voice'), findsNothing);
        await tester.tap(find.text('Skip Narration'));
        await tester.pump();
        expect(calls, isNot(contains('speech.stopSpeaking')));
        init.complete();
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('Choose Voice'), findsOneWidget);
        expect(find.text('Lite'), findsNothing);
        expect(find.text('Hanna'), findsOneWidget);
        expect(find.text('Rich'), findsOneWidget);
        expect(find.text('Ariana'), findsOneWidget);
        expect(calls, isNot(contains('speech.speak')));
        expect(calls, isNot(contains('wakeword.unPauseDetection')));
        expect(
          calls.indexOf('speech.setAudioRoutingConfig'),
          lessThan(calls.indexOf('speech.initAll')),
        );
        expect(
          calls.indexOf('speech.initAll'),
          lessThan(calls.indexOf('speech.changeVoice')),
        );
        expect(voices, ['Rich']);
        expect(models, ['assets/models/model_ex2_rich.dm']);
        await tester.ensureVisible(find.text(selectedVoice));
        await tester.tap(find.text(selectedVoice));
        await tester.pump();
        await tester.ensureVisible(find.text('Continue'));
        await tester.tap(find.text('Continue'));
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(voices, ['Rich']);
        final selectedModel = switch (selectedVoice) {
          'Hanna' => 'assets/models/model_ex_hanna_light_davoice_ph.dm',
          'Ariana' => 'assets/models/model_ex_ariana_fast_davoice_phoneme.dm',
          _ => 'assets/models/model_ex2_rich.dm',
        };
        expect(
          models,
          selectedVoice == 'Rich'
              ? [selectedModel]
              : ['assets/models/model_ex2_rich.dm', selectedModel],
        );
        expect(find.text('Skip'), findsOneWidget);
        await tester.ensureVisible(find.text('Skip'));
        await tester.tap(find.text('Skip'));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          calls.where((call) => call == 'speech.initAll'),
          hasLength(selectedVoice == 'Rich' ? 1 : 2),
        );
        expect(
          calls.where((call) => call == 'wakeword.createInstanceMulti'),
          hasLength(1),
        );
        expect(calls, contains('wakeword.unPauseDetection'));
        expect(wakewordPauseStopMicValues, isNotEmpty);
        expect(wakewordPauseStopMicValues, everyElement(isFalse));
        expect(
          find.text('Say the wake word "Hey Coach" to continue.'),
          findsOneWidget,
        );
        Future<void> emit(String channel, Map<String, dynamic> event) async {
          messenger.handlePlatformMessage(
            channel,
            const StandardMethodCodec().encodeSuccessEnvelope(event),
            (_) {},
          );
          await tester.pump();
        }

        await emit('flutter_davoice/events', {
          'event': 'onSpeechResults',
          'value': ['must be ignored'],
        });
        await tester.pump(const Duration(seconds: 3));
        expect(calls, isNot(contains('speech.speak')));
        await emit('flutter_wake_word/events', {
          'event': 'onKeywordDetectionEvent',
          'instanceId': 'multi_model_instance',
          'phrase': 'Hey Coach',
        });
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('Type to TTS'), findsOneWidget);
        for (final mode in [
          'Type to TTS',
          'STT Only',
          'Combined STT + TTS',
          'Full AI Chat',
        ]) {
          await tester.ensureVisible(find.text(mode));
          await tester.tap(find.text(mode));
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(find.text('Choose Mode'), findsOneWidget);
          if (mode == 'STT Only') {
            await emit('flutter_davoice/events', {
              'event': 'onSpeechResults',
              'value': ['transcript only'],
            });
            await tester.pump(const Duration(seconds: 3));
            expect(calls, isNot(contains('speech.speak')));
          }
          if (mode == 'Combined STT + TTS') {
            await emit('flutter_davoice/events', {
              'event': 'onSpeechResults',
              'value': ['echo this'],
            });
            await tester.pump(const Duration(seconds: 2));
            await tester.pump(const Duration(milliseconds: 150));
            expect(calls, contains('speech.speak'));
          }
          await tester.tap(find.text('Choose Mode'));
          for (var i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          final resumes = calls
              .where((call) => call == 'speech.unPauseSpeechRecognition')
              .length;
          await emit('flutter_davoice/events', {'event': 'onFinishedSpeaking'});
          await emit('flutter_davoice/events', {
            'event': 'onSpeechResults',
            'value': ['late result'],
          });
          await tester.pump(const Duration(seconds: 3));
          expect(
            calls.where((call) => call == 'speech.unPauseSpeechRecognition'),
            hasLength(resumes),
          );
          expect(find.text('Type to TTS'), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}
