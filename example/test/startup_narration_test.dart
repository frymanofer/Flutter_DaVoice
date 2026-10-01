import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_davoice_example/flow/startup_narration.dart';

void main() {
  test(
    'skip during loading never stops native initialization or speaks later',
    () async {
      final narration = StartupNarration();
      var stops = 0;
      final spoken = <String>[];
      await narration.skip(() async {
        stops++;
      });
      await narration.speak(
        ['intro'],
        speakLine: (line) async {
          spoken.add(line);
        },
        isActive: () => true,
      );
      expect(stops, 0);
      expect(spoken, isEmpty);
    },
  );

  test(
    'skip waits for native stop even when Dart speak resolves first',
    () async {
      final narration = StartupNarration();
      final speech = Completer<void>();
      final nativeStop = Completer<void>();
      final spoken = <String>[];
      var advanced = false;
      final run = narration
          .speak(
            ['first', 'second'],
            speakLine: (line) {
              spoken.add(line);
              return speech.future;
            },
            isActive: () => true,
          )
          .then((_) {
            advanced = true;
          });
      final skip = narration.skip(() {
        speech.complete();
        return nativeStop.future;
      });
      await Future<void>.delayed(Duration.zero);
      expect(advanced, false);
      nativeStop.complete();
      await skip;
      await run;
      expect(advanced, true);
      expect(spoken, ['first']);
    },
  );

  test(
    'disposal prevents another narration line and genuine failures propagate',
    () async {
      final narration = StartupNarration();
      var active = true;
      final spoken = <String>[];
      await narration.speak(
        ['first', 'second'],
        speakLine: (line) async {
          spoken.add(line);
          active = false;
        },
        isActive: () => active,
      );
      expect(spoken, ['first']);
      await expectLater(
        StartupNarration().speak(
          ['intro'],
          speakLine: (_) async {
            throw StateError('synthesis failed');
          },
          isActive: () => true,
        ),
        throwsStateError,
      );
    },
  );
}
