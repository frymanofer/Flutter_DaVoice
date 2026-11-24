import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_davoice/flutter_davoice_method_channel.dart';
import 'package:flutter_davoice/flutter_davoice_platform_interface.dart';
import 'package:flutter_davoice_car_agent/flow/app_language.dart';
import 'package:flutter_davoice_car_agent/main.dart';
import 'package:flutter_test/flutter_test.dart';

// The language screen (first): Brazilian Portuguese loads its own TTS model and STT locale.
void main() {
  tearDown(() => setCurrentAppLanguage('en'));

  testWidgets('Brazilian Portuguese loads the pt-BR model and recognizer', (tester) async {
    rootBundle.clear();
    FlutterDavoicePlatform.instance = MethodChannelFlutterDavoice();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final init = Completer<void>();
    Map? initArgs;
    const channels = [
      MethodChannel('flutter_davoice'),
      MethodChannel('flutter_wake_word'),
      MethodChannel('flutter.baseflow.com/permissions/methods'),
      MethodChannel('flutter_davoice/events'),
      MethodChannel('flutter_wake_word/events'),
      MethodChannel('plugins.flutter.io/path_provider'),
    ];
    messenger.setMockMethodCallHandler(channels[0], (call) async {
      if (call.method == 'initAll') {
        initArgs = call.arguments as Map;
        await init.future;
        return null;
      }
      if (call.method == 'changeVoice') return 0;
      if (call.method == 'setLicense') return true;
      return null;
    });
    messenger.setMockMethodCallHandler(channels[1], (call) async {
      if (call.method == 'getRecordingWav') return '';
      return call.method == 'setAudioRoutingConfig' ? null : true;
    });
    messenger.setMockMethodCallHandler(channels[2], (_) async => 1);
    messenger.setMockMethodCallHandler(channels[3], (_) async => null);
    messenger.setMockMethodCallHandler(channels[4], (_) async => null);
    messenger.setMockMethodCallHandler(channels[5], (_) async => '/tmp/davoice-flutter-language-test');
    addTearDown(() {
      for (final channel in channels) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });

    await tester.pumpWidget(const DavoiceExampleApp());
    expect(find.text('CHOOSE YOUR LANGUAGE'), findsOneWidget);
    expect(find.text('EN • English', findRichText: true), findsOneWidget);
    // Brazilian Portuguese is selected by default (as the React Native example_car_agent): its button continues.
    await tester.tap(find.text('Continue with Português do Brasil'));
    await tester.pump();
    for (var i = 0; i < 30 && initArgs == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(currentAppLanguage, 'pt-BR');
    expect(initArgs?['model'], 'assets/models/model_ex2_portuguese_brv3.dm');
    expect(initArgs?['locale'], 'pt-BR');
    init.complete();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a language that is not built in opens the download screen; Back returns to the languages', (tester) async {
    rootBundle.clear();
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const DavoiceExampleApp());
    await tester.pump();
    expect(find.textContaining(' MB'), findsWidgets, reason: 'download sizes on the languages that are not built in');
    expect(find.text('EL • Ελληνικά', findRichText: true), findsOneWidget);
    await tester.tap(find.text('FR • Français', findRichText: true));
    await tester.pump();
    await tester.tap(find.textContaining('Install Français'));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('INSTALLING LANGUAGE PACK'), findsOneWidget);
    // Tests have no network (HTTP 400): the failure is shown with Retry and Cancel, and the language is not chosen.
    expect(find.text('Retry'), findsOneWidget);
    expect(currentAppLanguage, 'en');
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('CHOOSE YOUR LANGUAGE'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
