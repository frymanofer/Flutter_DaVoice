import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_davoice_example/flow/transcript.dart';

void main() {
  test(
    'partial overlap preserves punctuation without duplicating question marks',
    () {
      expect(
        mergeTranscript('How are you?', 'are you? Fine.'),
        'How are you? Fine.',
      );
      expect(
        mergeTranscript('Hello there, friend', 'there, friend!'),
        'Hello there, friend!',
      );
      expect(mergeTranscript('Hello there', 'Hello'), 'Hello there');
    },
  );
  test('newlines keep existing sentence punctuation', () {
    expect(
      normalizeTextForSpeech('Hello!\nHow are you?'),
      'Hello! How are you?',
    );
    expect(
      normalizeTextForSpeech('Hello\nHow are you?'),
      'Hello. How are you?',
    );
  });
}
