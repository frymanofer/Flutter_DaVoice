// The same cases and expected sentences as the RN example's __tests__/speechComposer.test.ts (kept aligned).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_davoice_car_agent/car/speech_composer.dart';
import 'package:flutter_test/flutter_test.dart';

String run(
  List<(String, String, bool, Map<String, Object?>)> says,
  String text, [
  String lang = 'en',
  bool acked = false,
]) {
  beginCarTurn();
  resetSpeechVariant();
  for (final (tool, say, merge, args) in says) {
    noteCarSay(tool, say, merge, args: args);
  }
  return composeCarSpeech(text, carTurnActions(), lang, acked: acked);
}

void main() {
  test('closes the doors and locks the car', () {
    expect(
      run([
        ('close_doors', 'I closed all the doors.', true, {}),
        ('lock_car', 'I locked the car.', true, {}),
      ], 'I closed all the doors. I locked the car.'),
      'All set. I closed all the doors and locked the car. Everything is secure.',
    );
  });
  test('the offer: unlock then open', () {
    expect(
      run([
        ('unlock_car', 'I unlocked the car.', true, {}),
        ('open_door', 'I opened all the doors.', true, {}),
      ], 'I unlocked the car. I opened all the doors.'),
      'All set. I unlocked the car and opened all the doors. Come on in!',
    );
  });
  test('pt-BR, three actions', () {
    expect(
      run(
        [
          ('set_window', 'Fechei todas as janelas.', true, {}),
          ('close_doors', 'Fechei todas as portas.', true, {}),
          ('lock_car', 'Tranquei o carro.', true, {}),
        ],
        'Fechei todas as janelas. Fechei todas as portas. Tranquei o carro.',
        'pt-BR',
      ),
      'Pronto, já fiz isso para você. Fechei todas as janelas, fechei todas as portas e tranquei o carro. Agora o carro está todo seguro.',
    );
  });
  test('one action: a warm opener and, every other time, a closing line that fits', () {
    expect(run([('lock_car', 'I locked the car.', true, {})], 'I locked the car.'), "Sure, you got it. I locked the car. You're good to go.");
    expect(run([('unlock_car', 'Destranquei o carro.', true, {})], 'Destranquei o carro.', 'pt-BR'), 'Claro, já fiz isso para você. Destranquei todas as portas do carro. Pode entrar, o carro já está aberto.');
    // pt-BR: a short sentence said on its own is said longer (tested wording); a merged sentence keeps the short form (as the RN example)
    expect(run([('lock_car', 'Tranquei o carro.', true, {})], 'Tranquei o carro.', 'pt-BR'),
        'Claro, já fiz isso para você. Tranquei todas as portas do carro. Pode ficar tranquilo, está tudo seguro.');
    expect(run([('play_media', 'Tocando Anitta.', true, {'query': 'Anitta'})], 'Tocando Anitta.', 'pt-BR'),
        'Claro, já fiz isso para você. Agora tocando Anitta para você. Aproveite a música durante a viagem.');
    expect(
      run([('navigate_to', 'Navigating to home: about 24 minutes, 18 km.', true, {})], 'Navigating to home: about 24 minutes, 18 km.', 'en', true),
      "Navigating home: about 24 minutes, 18 km. Let's go!",
    );
    expect(
      run([('set_window', 'I closed all the windows.', true, {'window': 'all', 'position': 'close'})], 'I closed all the windows.'),
      'Sure, you got it. I closed all the windows.',
    );
  });
  test('varies: the next request gets another opener and no closing line', () {
    beginCarTurn();
    resetSpeechVariant();
    noteCarSay('set_window', "I opened the driver's window.", true, args: {'window': 'driver', 'position': 'open'});
    expect(composeCarSpeech("I opened the driver's window.", carTurnActions(), 'en'), "Sure, you got it. I opened the driver's window. Enjoy the fresh air.");
    beginCarTurn();
    noteCarSay('set_window', "I opened the driver's window.", true, args: {'window': 'driver', 'position': 'open'});
    expect(composeCarSpeech("I opened the driver's window.", carTurnActions(), 'en'), "You got it! I opened the driver's window.");
  });
  test('a refusal, an undo, a status, "already", Basic languages or model text stay as they were; nothing is invented', () {
    expect(
      run([
        ('lock_car', 'I locked the car.', true, {}),
        ('open_door', 'The car is locked. Should I unlock it?', false, {}),
      ], 'I locked the car. The car is locked. Should I unlock it?'),
      'I locked the car. The car is locked. Should I unlock it?',
    );
    expect(
      run([
        ('get_vehicle_status', 'The battery is at 76%.', true, {}),
        ('lock_car', 'I locked the car.', true, {}),
      ], 'The battery is at 76%. I locked the car.'),
      'The battery is at 76%. I locked the car.',
    );
    expect(run([('lock_car', 'I locked the car.', true, {})], 'I closed all the doors. I locked the car.'), 'I closed all the doors. I locked the car.');
    expect(run([('get_vehicle_status', 'The tank is at 62%, about 310 km.', true, {})], 'The tank is at 62%, about 310 km.'), 'The tank is at 62%, about 310 km.');
    expect(run([('lock_car', 'Erledigt.', true, {})], 'Erledigt.', 'de'), 'Erledigt.');
    beginCarTurn();
    resetSpeechVariant();
    noteCarSay('lock_car', 'The car is already locked.', true, kind: 'already');
    expect(composeCarSpeech('The car is already locked.', carTurnActions(), 'en'), 'The car is already locked.');
  });
  test('acknowledgement while a request takes a moment: rotates, tuned languages only', () {
    resetSpeechVariant();
    expect([carAck('en'), carAck('en'), carAck('pt-BR')], ['Got it.', 'On it.', 'Pode deixar, só um instante, por favor.']);
    expect(carAck('de'), isNull);
  });

  // The spoken wording (2026-11-21 reply review): the same cases as the RN example (test/fixtures/spoken_say.json, kept identical).
  test('how a tool sentence is said: every case of the shared fixture', () {
    final rn = File('../../ReactNative_DaVoice/example_car_agent/__tests__/fixtures/spoken_say.json');
    if (rn.existsSync()) expect(File('test/fixtures/spoken_say.json').readAsStringSync(), rn.readAsStringSync());
    final cases = (jsonDecode(File('test/fixtures/spoken_say.json').readAsStringSync()) as List).cast<List>();
    final diffs = [
      for (final c in cases)
        if (spokenSay(CarTurnAction(c[1] as String, c[2] as String, true, args: (c[3] as Map).cast<String, Object?>()), c[0] as String) != c[4])
          '${c[0]} ${c[2]} -> ${spokenSay(CarTurnAction(c[1] as String, c[2] as String, true, args: (c[3] as Map).cast<String, Object?>()), c[0] as String)}',
    ];
    expect(diffs, isEmpty);
  });
  test('in a full reply: smoother words, the same facts (same as RN)', () {
    expect(run([('set_temperature', 'I raised the whole cabin to 23°C.', true, {'change': 2})], 'I raised the whole cabin to 23°C.'),
        "Sure, you got it. I turned the temperature up to 23°C. It'll warm up soon.");
    expect(
      run([('navigate_to', 'Indo para aeroporto: cerca de 24 minutos, 18 km.', true, {'destination': 'aeroporto'})],
          'Indo para aeroporto: cerca de 24 minutos, 18 km.', 'pt-BR'),
      'Claro, já fiz isso para você. Indo para o aeroporto: cerca de 24 minutos, 18 km. Vamos lá, tenha uma ótima viagem!',
    );
    expect(run([('set_temperature', "I didn't change it: the temperature must be between 16 and 30.", false, {})],
        "I didn't change it: the temperature must be between 16 and 30."), 'Sorry, the temperature only goes from 16 to 30.');
  });
  test('an action that ran next to one that was already so: one reply with the opener (same as RN)', () {
    beginCarTurn();
    resetSpeechVariant();
    noteCarSay('lock_car', 'I locked the car.', true, kind: 'did');
    noteCarSay('set_window', 'All the windows are already closed.', true, args: {'window': 'all', 'position': 'close'}, kind: 'already');
    expect(composeCarSpeech('I locked the car. All the windows are already closed.', carTurnActions(), 'en'),
        'All set. I locked the car. All the windows are already closed. Everything is secure.');
    beginCarTurn();
    noteCarSay('close_doors', 'All the doors are already closed.', true, kind: 'already');
    noteCarSay('lock_car', 'The car is already locked.', true, kind: 'already');
    expect(composeCarSpeech('All the doors are already closed. The car is already locked.', carTurnActions(), 'en'),
        'All the doors are already closed. The car is already locked.');
  });
  test('a found place offers to navigate there; the offer is remembered for the next request', () {
    beginCarTurn();
    resetSpeechVariant();
    noteCarSay('find_along_route', 'I found a gas station 2.1 km ahead.', true, kind: 'answer', offer: ['navigate_to']);
    expect(composeCarSpeech('I found a gas station 2.1 km ahead.', carTurnActions(), 'en'),
        'I found a gas station 2.1 km ahead. Want me to take you there?');
    expect(pendingOfferCalls(), ['navigate_to']);
    beginCarTurn();
    expect(pendingOfferCalls(), isNull);
  });
  test('while driving, unlocking gets no "Come on in!" (same as RN)', () {
    beginCarTurn();
    resetSpeechVariant();
    noteCarSay('unlock_car', 'I unlocked the car.', true, kind: 'did');
    expect(composeCarSpeech('I unlocked the car.', carTurnActions(), 'en', driving: true), 'Sure, you got it. I unlocked the car.');
  });
  test('both seats: two seat heaters are one sentence (same as RN)', () {
    beginCarTurn();
    resetSpeechVariant();
    noteCarSay('set_seat_climate', "I set the heater in the driver's seat to high.", true,
        args: {'seat': 'driver', 'feature': 'heater', 'level': 'high'}, kind: 'did');
    noteCarSay('set_seat_climate', 'I set the heater in the passenger seat to high.', true,
        args: {'seat': 'passenger', 'feature': 'heater', 'level': 'high'}, kind: 'did');
    expect(composeCarSpeech("I set the heater in the driver's seat to high. I set the heater in the passenger seat to high.", carTurnActions(), 'en'),
        "All set. I set the driver's seat heater to high and set the passenger seat heater to high. Nice and cozy.");
  });
  test('an undo is said as putting it back, its sentence smoothed like any other (2026-11-21)', () {
    expect(run([('set_temperature', 'Undone. I set the whole cabin to 21°C.', false, {'temperature': 21})], 'Undone. I set the whole cabin to 21°C.'),
        'Okay, I put it back. I set the temperature to 21°C.');
    expect(run([('set_window', 'Desfeito. Fechei todos os vidros.', false, {})], 'Desfeito. Fechei todos os vidros.', 'pt-BR'),
        'Pronto, voltei tudo como estava antes. Fechei todas as janelas do carro.');
  });
}
