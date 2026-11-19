// Undo (core 2026-11-14, configure "undo") - the same cases as the RN example's __tests__/carUndo.test.ts (kept aligned): every
// state-changing call returns the calls that put the car back exactly as it was; navigation is undo false; lookups and "already"
// carry none; running the returned calls restores the previous state; an undo never unlocks while driving.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_davoice_car_agent/car/car_state.dart';
import 'package:flutter_davoice_car_agent/car/car_tools.dart';
import 'package:flutter_davoice_car_agent/car/car_undo.dart';
import 'package:flutter_davoice_car_agent/flow/app_language.dart';
import 'package:flutter_davoice_llm/flutter_davoice_llm.dart';
import 'package:flutter_test/flutter_test.dart';

Map res(Object? r) => (r is ToolReply ? r.result : r) as Map;
Map run(String name, Map<String, Object?> args) => res(runCarTool(name, args));
List<Object?> undo(Object? u) => [
      for (final c in ((u as Map)['calls'] as List).cast<Map>())
        runCarTool(c['name'] as String, (c['arguments'] as Map).cast<String, Object?>(), undoing: true)
    ];
String snap() => jsonEncode(carSnapshot(car.state));

void main() {
  setUpAll(() => loadCarToolDefinitions(readFile: (p) => File(p).readAsString()));
  setUp(() {
    car.reset();
    car.setDriving(false);
    car.setSteering('left');
    setCurrentAppLanguage('en');
    carUndoResults = true;
  });

  test('volume: back to the recorded level, not "down by 3"', () {
    run('set_volume', {'action': 'set', 'level': 20});
    final r = run('set_volume', {'action': 'up'});
    expect(car.state.volume, 23);
    expect(jsonEncode(r['undo']['calls']), jsonEncode([{'name': 'set_volume', 'arguments': {'action': 'set', 'level': 20}}]));
    final said = undo(r['undo']);
    expect(car.state.volume, 20);
    expect((said.first as ToolReply).say, startsWith('Undone. '));
  });

  test('mute is undone by unmute', () {
    final r = run('set_volume', {'action': 'mute'});
    undo(r['undo']);
    expect(car.state.muted, false);
  });

  test('windows: each window back to its own position', () {
    run('set_window', {'window': 'front_left', 'position': 'half'});
    final before = Map.of(car.state.windows);
    final r = run('set_window', {'window': 'all', 'position': 'open'});
    undo(r['undo']);
    expect(car.state.windows, before);
  });

  test('dual-zone temperature and comfort_feeling are restored', () {
    run('set_dual_zone_temperature', {'driver': 19, 'passenger': 24});
    final before = snap();
    final r = run('comfort_feeling', {'feeling': 'hot'});
    undo(r['undo']);
    expect(snap(), before);
  });

  test('locks: undo of a lock unlocks only when parked (vehicle policy)', () {
    final r = run('lock_car', {'door': 'all'});
    car.setDriving(true);
    final said = undo(r['undo']);
    expect(car.state.locked, true);
    expect(res(said.first)['ok'], false);
    car.setDriving(false);
    undo(r['undo']);
    expect(car.state.locked, false);
  });

  test('seat climate, fan, airflow, defrost, sunroof', () {
    for (final c in [
      ['set_seat_climate', {'seat': 'passenger', 'feature': 'heater', 'level': 'high'}],
      ['set_fan_speed', {'level': 6}],
      ['set_airflow', {'mode': 'feet'}],
      ['set_defrost', {'target': 'rear', 'on': true}],
      ['set_sunroof', {'action': 'tilt'}],
    ]) {
      final before = snap();
      final r = run(c[0] as String, (c[1] as Map).cast<String, Object?>());
      expect(r['undo'], isNotNull, reason: c[0] as String);
      undo(r['undo']);
      expect(snap(), before, reason: c[0] as String);
    }
  });

  test('no way back: navigation is undo false; lookups and "already" carry none', () {
    expect(run('navigate_to', {'destination': 'Ibirapuera'})['undo'], false);
    expect(run('get_trip_eta', {}).containsKey('undo'), false);
    expect(run('set_window', {'window': 'all', 'position': 'close'}).containsKey('undo'), false);
  });

  test('off unless the service enables it', () {
    carUndoResults = false;
    expect(run('set_volume', {'action': 'up'}).containsKey('undo'), false);
  });

  test('pt-BR undo sentence', () {
    setCurrentAppLanguage('pt-BR');
    final r = run('set_fan_speed', {'level': 5});
    expect((undo(r['undo']).first as ToolReply).say, startsWith('Desfeito. Coloquei a ventilação no nível 3.'));
  });

  test('a refused state-changing call is still the last action: ok false + undo false (core g29zk); nothing changed', () {
    final before = snap();
    final r = run('set_temperature', {'temperature': 99});
    expect(r['ok'], false);
    expect(r['undo'], false);
    expect(snap(), before);
    carUndoResults = false;
    expect(run('set_temperature', {'temperature': 99}).containsKey('undo'), false);
  });
}
