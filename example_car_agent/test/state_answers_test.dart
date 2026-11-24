// A question about the car is answered from the car (lib/car/state_answers.dart, 2026-11-21 reply review: the model RAN the action for
// "Is the car locked?" and the like), and the follow-ups to those answers (lib/car/follow_up.dart). The same cases as the RN example's
// __tests__/stateAnswers.test.ts (test/fixtures/state_answers.json and car_dialogs.json, kept identical).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_davoice_car_agent/car/basic_language.dart';
import 'package:flutter_davoice_car_agent/car/car_state.dart';
import 'package:flutter_davoice_car_agent/car/follow_up.dart';
import 'package:flutter_davoice_car_agent/car/state_answers.dart';
import 'package:flutter_test/flutter_test.dart';

/// The demo's starting car with the case's changes (only what differs from the start is in the fixture, in the RN state's shape).
CarState carWith(Map changes) {
  final s = CarState();
  Map<String, T> m<T>(Object? v) => (v as Map).map((k, x) => MapEntry(k as String, x as T));
  changes.forEach((k, v) {
    switch (k) {
      case 'windows':
        s.windows = m<String>(v);
      case 'doors':
        s.doors = m<String>(v);
      case 'doorLocks':
        s.doorLocks = m<bool>(v);
      case 'locked':
        s.locked = v as bool;
      case 'sunroof':
        s.sunroof = v as String;
      case 'seatHeater':
        s.seatHeater = m<String>(v);
      case 'seatVentilation':
        s.seatVentilation = m<String>(v);
      case 'temperature':
        final t = v as Map;
        for (final z in ['driver', 'passenger', 'rear']) {
          if (t[z] != null) s.temperature[z] = t[z] as num;
        }
        if (t['unit'] != null) s.unit = t['unit'] as String;
      case 'volume':
        s.volume = v as int;
      case 'muted':
        s.muted = v as bool;
      case 'fan':
        s.fan = v as int;
      case 'media':
        s.media = v as String?;
      case 'radio':
        s.radio = v as String?;
      case 'destination':
        s.destination = v as String?;
      default:
        throw StateError('fixture state "$k" is not mapped');
    }
  });
  return s;
}

void main() {
  for (final f in ['state_answers.json', 'car_dialogs.json']) {
    test('the RN example and this app share the same cases ($f)', () {
      final rn = File('../../ReactNative_DaVoice/example_car_agent/__tests__/fixtures/$f');
      if (rn.existsSync()) expect(File('test/fixtures/$f').readAsStringSync(), rn.readAsStringSync());
    });
  }

  test('every question of the shared fixture', () {
    final cases = (jsonDecode(File('test/fixtures/state_answers.json').readAsStringSync()) as List).cast<Map>();
    final diffs = <String>[];
    for (final c in cases) {
      final got = answerCarQuestion(c['user'] as String, c['lang'] as String, carWith(c['state'] as Map));
      final want = c['expect'] as Map?;
      final ok = want == null ? got == null : got != null && got.reply == want['reply'] && got.offer == want['offer'];
      if (!ok) diffs.add('${c['lang']} "${c['user']}": got ${got?.reply} / ${got?.offer}, want ${want?['reply']} / ${want?['offer']}');
    }
    expect(diffs, isEmpty);
  });

  test('every conversation of the shared fixture', () {
    final dialogs = (jsonDecode(File('test/fixtures/car_dialogs.json').readAsStringSync()) as List).cast<Map>();
    final diffs = <String>[];
    for (final d in dialogs) {
      resetFollowUp();
      clearBasicPending();
      final lang = d['lang'] as String;
      final state = carWith(d['state'] as Map);
      for (final s in (d['steps'] as List).cast<Map>()) {
        final flags = d['car'] as Map?;
        final got = carTurnInput(s['user'] as String, lang, null,
            state: state, musicOn: flags?['musicOn'] == true, lastActed: flags?['lastActed'] as bool?);
        final want = s['expect'] as Map;
        final ok = want.containsKey('reply') ? got.reply == want['reply'] && got.text == null : got.text == want['text'] && got.reply == null;
        if (!ok) diffs.add('$lang "${s['user']}": got ${got.text ?? got.reply}, want ${want['text'] ?? want['reply']}');
        noteCarSpoken(got.reply ?? (s['heard'] as String? ?? ''));
      }
    }
    expect(diffs, isEmpty);
  });

  test('nothing pending: a yes is passed on as it is (the agent core decides)', () {
    resetFollowUp();
    expect(carTurnInput('Yes', 'en', null, state: CarState()).text, 'Yes');
  });
}
