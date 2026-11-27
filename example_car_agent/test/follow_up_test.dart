// What the driver says right after the agent's question or offer (lib/car/follow_up.dart, 2026-11-21 reply review): the same cases as
// the RN example's __tests__/followUp.test.ts (test/fixtures/follow_up.json, kept identical).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_davoice_car_agent/car/basic_language.dart';
import 'package:flutter_davoice_car_agent/car/car_tools.dart';
import 'package:flutter_davoice_car_agent/car/follow_up.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async => loadCarToolDefinitions(readFile: (p) => File(p).readAsString()));

  test('the RN example and this app share the same cases', () {
    final rn = File('../../ReactNative_DaVoice/example_car_agent/__tests__/fixtures/follow_up.json');
    if (rn.existsSync()) expect(File('test/fixtures/follow_up.json').readAsStringSync(), rn.readAsStringSync());
  });

  test('every case of the shared fixture', () {
    final cases = (jsonDecode(File('test/fixtures/follow_up.json').readAsStringSync()) as List).cast<Map>();
    final diffs = <String>[];
    for (final c in cases) {
      resetFollowUp();
      clearBasicPending();
      final lang = c['lang'] as String;
      final before = c['before'] as Map?;
      if (before != null) noteCarReply(before['sent'] as String, before['reply'] as String, lang);
      final got = carTurnInput(c['user'] as String, lang, (c['offer'] as List?)?.cast<String>(), musicOn: (c['car'] as Map?)?['musicOn'] == true);
      final want = c['expect'] as Map;
      final ok = want.containsKey('reply') ? got.reply == want['reply'] && got.text == null : got.text == want['text'] && got.reply == null;
      if (!ok) diffs.add('$lang "${c['user']}": got ${got.text ?? got.reply}, want ${want['text'] ?? want['reply']}');
    }
    expect(diffs, isEmpty);
  });

  test('a question is answered once: the request after the answer is a new one', () {
    resetFollowUp();
    noteCarReply('Open the window', 'Which window should I open?', 'en');
    expect(carTurnInput("The driver's one", 'en', null).text, "Open the window, the driver's one");
    expect(carTurnInput('The rear ones', 'en', null).text, 'The rear ones');
  });

  test('dismissals rotate between two short replies', () {
    resetFollowUp();
    expect([carTurnInput('Never mind', 'en', null).reply, carTurnInput('Cancel', 'en', null).reply], ['Okay.', 'No problem.']);
  });

  test('something the car cannot do is offered the way it can ("Lock the sunroof" -> close it); a yes sends that request', () {
    resetFollowUp();
    expect(carTurnInput('Can you lock the sunroof?', 'en', null).reply, "I can't lock the sunroof, but I can close it. Want me to close it?");
    expect(carTurnInput('Yes', 'en', null).text, 'Close the sunroof');
    resetFollowUp();
    carTurnInput('Lock the sunroof', 'en', null);
    expect(carTurnInput('Close it', 'en', null).text, 'Close the sunroof');
    resetFollowUp();
    carTurnInput('Unlock the windows', 'en', null);
    expect(carTurnInput('No', 'en', null).reply, 'Okay.');
    resetFollowUp();
    carTurnInput('Tranca o teto solar', 'pt-BR', null);
    expect(carTurnInput('Sim', 'pt-BR', null).text, 'Fecha o teto solar');
    resetFollowUp();
    carTurnInput('Destranca os vidros', 'pt-BR', null);
    expect(carTurnInput('Pode abrir', 'pt-BR', null).text, 'Abre todos os vidros');
  });
}
