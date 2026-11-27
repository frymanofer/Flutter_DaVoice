import 'package:flutter/material.dart';
import 'package:flutter_davoice_car_agent/redesign/voice_clone_screen.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _screen({required bool mic, required bool recording, String? sample, String? result, String? error}) => MaterialApp(
      home: VoiceCloneScreen(
        nameController: TextEditingController(text: 'Dana'),
        replaces: 'dana',
        useMicrophone: mic,
        readingText: 'The quick brown fox jumps over the lazy dog, and the car drives home in the evening light.',
        recommendedSeconds: 10,
        maxSeconds: 30,
        recording: recording,
        recordSeconds: 12.4,
        recordPeak: 0.99,
        sample: sample,
        volumePercent: 120,
        minVolumePercent: 50,
        maxVolumePercent: 200,
        busy: false,
        error: error,
        resultVoice: result,
        resultWeak: true,
        folder: '/storage/emulated/0/Android/data/io.davoice.flutter.caragent/files/cloned_voices',
        scrollController: ScrollController(),
        recordButtonKey: GlobalKey(),
        onNameChanged: (_) {},
        onChangeSource: (_) {},
        onToggleRecording: () {},
        onPickFile: () {},
        onPlaySample: () {},
        onVolumeDown: () {},
        onVolumeUp: () {},
        onCreate: () {},
        onListen: () {},
        onUse: () {},
        onBack: () {},
      ),
    );

void main() {
  for (final size in const [Size(320, 640), Size(390, 844)]) {
    testWidgets('clone screen lays out at ${size.width.toInt()} wide', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_screen(mic: true, recording: true));
      expect(tester.takeException(), isNull);
      expect(find.text('Stop recording'), findsOneWidget);
      expect(find.text('Too loud: move the phone a little further away.'), findsOneWidget);
      expect(find.text('Create voice'), findsOneWidget);

      await tester.pumpWidget(_screen(
          mic: true, recording: false, sample: 'Microphone recording (12.4 s)', result: 'Dana', error: 'Something went wrong while saving.'));
      expect(tester.takeException(), isNull);
      expect(find.text('Use this voice'), findsOneWidget);
      expect(find.text('Record again'), findsOneWidget);
      expect(find.text('Something went wrong while saving.'), findsOneWidget);

      await tester.pumpWidget(_screen(mic: false, recording: false, sample: 'a_very_long_file_name_for_a_voice_recording_sample.m4a'));
      expect(tester.takeException(), isNull);
      expect(find.text('Choose another file'), findsOneWidget);
      expect(find.text('+20%'), findsOneWidget);
    });
  }
}
