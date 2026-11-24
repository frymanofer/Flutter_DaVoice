// Basic languages (2026-11-21, lib/car/basic_language.dart): the same cases and expected sentences as the RN example's
// __tests__/basicLanguage.test.ts (kept aligned: both apps must ask the same question for the same call).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_davoice_car_agent/car/basic_language.dart';
import 'package:flutter_davoice_car_agent/car/car_state.dart';
import 'package:flutter_davoice_car_agent/car/car_tools.dart';
import 'package:flutter_davoice_car_agent/car/speech_composer.dart';
import 'package:flutter_davoice_car_agent/flow/app_language.dart';
import 'package:flutter_davoice_llm/flutter_davoice_llm.dart';
import 'package:flutter_test/flutter_test.dart';

ToolReply run(String name, Map<String, Object?> args) => runCarTool(name, args) as ToolReply;
Map res(ToolReply r) => r.result as Map;

const calls = <(String, Map<String, Object?>)>[
  ('set_window', {'window': 'driver', 'position': 'open'}), ('set_window', {'window': 'all', 'position': 'close'}),
  ('set_window', {'window': 'rear_left', 'position': 'half'}), ('set_window', {'window': 'passenger', 'position': 'crack'}),
  ('open_door', {'door': 'rear_right'}), ('close_doors', {'door': 'all'}), ('lock_car', {}), ('unlock_car', {'door': 'driver'}),
  ('set_sunroof', {'action': 'tilt'}), ('set_trunk', {'which': 'trunk', 'action': 'open'}), ('set_temperature', {'temperature': 21.5}),
  ('set_temperature', {'temperature': 22, 'zone': 'passenger'}), ('set_temperature', {'change': -2}), ('set_temperature', {'change': 1}),
  ('set_dual_zone_temperature', {'driver': 20, 'passenger': 23}), ('comfort_feeling', {'feeling': 'cold'}), ('comfort_feeling', {'feeling': 'hot'}),
  ('set_fan_speed', {'level': 3}), ('set_fan_speed', {'change': -1}), ('set_airflow', {'mode': 'feet'}), ('set_defrost', {'target': 'rear', 'on': true}),
  ('set_defrost', {'target': 'windshield', 'on': false}), ('set_seat_climate', {'seat': 'driver', 'feature': 'heater', 'level': 'high'}),
  ('set_seat_climate', {'seat': 'passenger', 'feature': 'ventilation', 'level': 'off'}), ('set_steering_wheel_heater', {'on': true}),
  ('play_media', {'query': 'Anitta', 'kind': 'artist'}), ('tune_radio', {'band': 'fm', 'frequency': 101.5}), ('set_audio_source', {'source': 'bluetooth'}),
  ('set_volume', {'action': 'up'}), ('set_volume', {'action': 'set', 'level': 12}), ('set_volume', {'action': 'mute'}),
  ('navigate_to', {'destination': 'home'}), ('navigate_to', {'destination': 'Madrid'}), ('set_route_avoid', {'avoid': 'tolls'}),
];

void main() {
  late List<String> langs;
  setUpAll(() async {
    await loadCarToolDefinitions(readFile: (p) => File(p).readAsString());
    final data = jsonDecode(await File('assets/car/basic_languages.json').readAsString()) as Map;
    langs = [for (final k in (data['languages'] as Map).keys) if (k != 'en') k as String];
  });
  setUp(() {
    car.reset();
    car.setDriving(false);
    car.setSteering('left');
    clearBasicPending();
    setCurrentAppLanguage('de');
  });

  test('the RN example and this app share the same sentences file', () {
    final rn = File('../../ReactNative_DaVoice/example_car_agent/src/car/basic_languages.json');
    if (rn.existsSync()) expect(File('assets/car/basic_languages.json').readAsStringSync(), rn.readAsStringSync());
  });

  test('tuned and Basic languages', () {
    expect(isBasicLanguage('en'), isFalse);
    expect(isBasicLanguage('pt-BR'), isFalse);
    for (final l in ['de', 'es', 'it', 'fr', 'nl', 'el', 'sv', 'da', 'pt-PT', 'he']) {
      expect(isBasicLanguage(l), isTrue);
    }
  });

  test('every language describes every demo call with no placeholder left', () {
    for (final lang in langs) {
      for (final (name, args) in calls) {
        final q = confirmQuestion([{'name': name, 'arguments': args}], lang);
        expect(q, isNot(matches(RegExp(r'[{}]|null'))), reason: '$lang $name');
        expect(q.length, greaterThan(5));
      }
      for (final item in ['range', 'fuel', 'battery', 'energy_consumption', 'tire_pressure', 'warnings']) {
        expect(basicAnswer('get_vehicle_status', {'item': item}, lang, fuelPercent: 62), isNotNull);
      }
    }
  });

  test('a few sentences read naturally (same as RN)', () {
    expect(confirmQuestion([{'name': 'set_window', 'arguments': {'window': 'driver', 'position': 'open'}}], 'de'), 'Soll ich das Fahrerfenster öffnen?');
    expect(confirmQuestion([{'name': 'lock_car', 'arguments': {}}], 'es'), '¿Bloquear el coche?');
    expect(confirmQuestion([{'name': 'set_temperature', 'arguments': {'temperature': 21.5}}], 'fr'), 'Régler la température à 21,5 °C ?');
    expect(confirmQuestion([{'name': 'set_volume', 'arguments': {'action': 'down'}}], 'it'), 'Abbassare il volume?');
    expect(confirmQuestion([{'name': 'set_sunroof', 'arguments': {'action': 'open'}}], 'el'), 'Να ανοίξω την ηλιοροφή;');
    expect(describeCall('navigate_to', {'destination': 'work'}, 'nl'), 'naar het werk navigeren');
  });

  test('Basic: the action is asked, nothing changes; a yes runs exactly that call', () {
    beginCarTurn();
    final asked = run('set_window', {'window': 'driver', 'position': 'open'});
    expect(asked.say, 'Soll ich das Fahrerfenster öffnen?');
    expect(res(asked)['ok'], isFalse);
    expect((res(asked)['offer'] as Map)['calls'], [
      {'name': 'set_window', 'arguments': {'window': 'driver', 'position': 'open'}},
    ]);
    expect(car.state.windows['front_left'], isNot('open'));
    expect(normalizeYesNo('Ja, bitte.', 'de'), 'yes');
    beginCarTurn();
    final ran = run('set_window', {'window': 'driver', 'position': 'open'});
    expect(ran.say, 'Erledigt.');
    expect(car.state.windows['front_left'], 'open');
    beginCarTurn();
    expect(res(run('set_window', {'window': 'driver', 'position': 'close'}))['ok'], isFalse);
  });

  test('Basic: two actions in one request are one offer; "Erledigt." is said once', () {
    beginCarTurn();
    run('set_window', {'window': 'driver', 'position': 'open'});
    final second = run('set_fan_speed', {'level': 3});
    expect([for (final c in (res(second)['offer'] as Map)['calls'] as List) (c as Map)['name']], ['set_window', 'set_fan_speed']);
    beginCarTurn();
    expect(res(run('set_window', {'window': 'driver', 'position': 'open'}))['ok'], isTrue);
    expect(res(run('set_fan_speed', {'level': 3}))['ok'], isTrue);
    expect(composeCarSpeech('Erledigt. Erledigt.', carTurnActions(), 'de'), 'Erledigt.');
  });

  test('Basic yes / no words: folded, repeated, only when something was asked', () {
    setCurrentAppLanguage('es');
    expect(normalizeYesNo('sí', 'es'), isNull);
    beginCarTurn();
    run('lock_car', {});
    expect(normalizeYesNo('Sí, sí.', 'es'), 'yes');
    expect(normalizeYesNo('no, gracias', 'es'), 'no');
    expect(normalizeYesNo('sí, y abre la ventana', 'es'), isNull);
    expect(normalizeYesNo('yes', 'en'), isNull);
  });

  test('Basic yes words in every language', () {
    const yes = {'de': 'Ja', 'es': 'Vale', 'it': 'Sì, grazie', 'fr': "Oui, d'accord", 'nl': 'Ja graag', 'el': 'Ναι', 'sv': 'Ja tack', 'da': 'Ja tak', 'pt-PT': 'Sim, por favor'};
    for (final e in yes.entries) {
      clearBasicPending();
      setCurrentAppLanguage(e.key);
      beginBasicTurn();
      run('lock_car', {});
      expect([e.key, normalizeYesNo(e.value, e.key)], [e.key, 'yes']);
    }
  });

  hintTests();

  test('tuned languages act directly, as before', () {
    setCurrentAppLanguage('en');
    beginCarTurn();
    expect(run('set_window', {'window': 'driver', 'position': 'open'}).say, "I opened the driver's window.");
  });
}

// English hints (2026-11-21, as the RN example): the expected strings come from the measured Python version (252 sentences, 9 languages).
void hintTests() {
  test('hints: identical to the measured version for all 252 test sentences', () {
    final fx = (jsonDecode(File('test/fixtures/basic_hints.json').readAsStringSync()) as List).cast<List>();
    final diffs = [for (final f in fx) if (withCarHints(f[1] as String, f[0] as String) != f[2]) f];
    expect(diffs, isEmpty);
  });
  test('hints: tuned languages and non-car speech stay as they are', () {
    expect(withCarHints('Mach die Musik leiser', 'de'), 'Mach die Musik leiser (volume down, music)');
    expect(withCarHints('open the window', 'en'), 'open the window');
    expect(withCarHints('Meine Schwester kommt morgen', 'de'), 'Meine Schwester kommt morgen');
  });
  test('a Portuguese sentence from the model is replaced in other Basic languages only', () {
    expect(basicReplyFix('O que você quer ouvir?', 'sv'), 'Förlåt, det uppfattade jag inte. Kan du säga det igen?');
    expect(basicReplyFix('¿Qué quieres escuchar?', 'es'), isNull);
    expect(basicReplyFix('O que você quer ouvir?', 'pt-PT'), isNull);
    expect(basicReplyFix('What do you want to hear?', 'en'), isNull);
  });
}
