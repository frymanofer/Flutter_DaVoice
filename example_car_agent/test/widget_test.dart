import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_davoice_car_agent/main.dart';
import 'package:flutter_davoice/flutter_davoice_platform_interface.dart';
import 'package:flutter_davoice/flutter_davoice_method_channel.dart';

void main() {
  const sharedModel = 'assets/models/model_ex2_rich_kate.dm';
  for (final selectedVoice in ['Rich', 'Kate', 'Gloria', 'Hanna', 'Ariana']) {
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
          // The loaded model's own voices (the English model's).
          if (call.method == 'getAllVoices') return ['Ariana', 'Rich', 'Hanna', 'Kate', 'Jenny', 'Matthew', 'Gloria'];
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
        // First of all: the language (the "under the hood" screen: pick English in the module rack, then the button).
        expect(find.text('CHOOSE YOUR LANGUAGE'), findsOneWidget);
        await tester.tap(find.text('EN • English', findRichText: true));
        await tester.pump();
        await tester.tap(find.text('Continue with English'));
        await tester.pump();
        for (var i = 0; i < 30 && !calls.contains('speech.initAll'); i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(calls, contains('speech.initAll'));
        expect(find.text('Choose Your Voice'), findsNothing);
        expect(find.text('Skip narration'), findsNothing);
        init.complete();
        // Real async too: loading the cloned voices creates their folder.
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('Choose Your Voice'), findsOneWidget);
        expect(find.text('Lite'), findsNothing);
        expect(find.text('Clone a new voice'), findsOneWidget);
        expect(find.text('YOUR CLONED VOICES'), findsOneWidget);
        expect(find.text('BUILT-IN'), findsOneWidget);
        for (final voice in ['Ariana', 'Rich', 'Hanna', 'Kate', 'Jenny', 'Matthew', 'Gloria']) {
          expect(find.text(voice), findsOneWidget);
        }
        expect(calls, isNot(contains('speech.speak')));
        expect(calls, contains('wakeword.unPauseDetection'));
        expect(
          calls.indexOf('speech.pauseSpeechRecognition'),
          lessThan(calls.indexOf('wakeword.unPauseDetection')),
        );
        expect(
          calls.indexOf('speech.setAudioRoutingConfig'),
          lessThan(calls.indexOf('speech.initAll')),
        );
        expect(
          calls.indexOf('speech.initAll'),
          lessThan(calls.indexOf('speech.changeVoice')),
        );
        expect(voices, ['Rich']);
        expect(models, [sharedModel]);
        await tester.ensureVisible(find.text(selectedVoice));
        await tester.tap(find.text(selectedVoice));
        await tester.pump();
        await tester.ensureVisible(find.text('Continue with $selectedVoice'));
        await tester.tap(find.text('Continue with $selectedVoice'));
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        // Every built-in voice is a voice in the shared model: it is
        // switched without reloading the model.
        expect(voices, selectedVoice != 'Rich' ? ['Rich', selectedVoice] : ['Rich']);
        expect(models, [sharedModel]);
        // Speaker isolation: answer any voice.
        expect(find.text('Skip · answer any voice'), findsOneWidget);
        await tester.tap(find.text('Skip · answer any voice'));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          calls.where((call) => call == 'speech.initAll'),
          hasLength(1),
        );
        expect(
          calls.where((call) => call == 'wakeword.createInstanceMulti'),
          hasLength(1),
        );
        expect(calls, contains('wakeword.unPauseDetection'));
        expect(wakewordPauseStopMicValues, isNotEmpty);
        expect(wakewordPauseStopMicValues, everyElement(isFalse));
        // The wake word screen, listening.
        expect(find.text('Listening for the wake word'), findsOneWidget);
        expect(find.text('“Hey Coach”'), findsOneWidget);
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
        // Car agent (as the React Native example_car_agent): the first wake word opens the on-device car agent, no mode menu. Without
        // a model in the test it stays on the agent's loading screen.
        expect(find.text('Type to TTS'), findsNothing);
        expect(find.text('Starting the car agent'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}
