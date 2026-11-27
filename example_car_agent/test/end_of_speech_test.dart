// Words that cannot end a request wait longer before they are sent (lib/flow/end_of_speech.dart; the RN app's endOfSpeech.test.ts).
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_davoice_car_agent/flow/end_of_speech.dart';

void main() {
  test('unfinished: the fragments that were sent too early', () {
    for (final t in ['Look at', 'Please', "Yeah, it's", 'Set the', 'Can you', 'Open', 'Set the heat of the', 'Turn on', 'Open all the doors and']) {
      expect([t, looksUnfinished(t, 'en')], [t, true]);
    }
    for (final t in ['Fecha a', 'Você pode', 'Abre', 'Coloca o volume em', 'Por favor']) {
      expect([t, looksUnfinished(t, 'pt-BR')], [t, true]);
    }
  });

  test('finished requests and answers keep the normal silence', () {
    for (final t in ['Open the sunroof', 'Yes', 'Yes please', 'Stop', 'No', 'Close it please', 'Set the fan to five', 'Thank you', 'Lock the car', "What's that"]) {
      expect([t, looksUnfinished(t, 'en')], [t, false]);
    }
    for (final t in ['Fecha a janela, por favor', 'Sim', 'Pode', 'Liga o ar', 'Tranca o carro']) {
      expect([t, looksUnfinished(t, 'pt-BR')], [t, false]);
    }
    expect(looksUnfinished('Mach das', 'de'), false);
  });

  test('silenceFor adds the extra wait only when unfinished', () {
    expect(silenceFor('Set the', 1500, 'en'), 1500 + unfinishedExtraMs);
    expect(silenceFor('Open the window', 1500, 'en'), 1500);
  });
}
