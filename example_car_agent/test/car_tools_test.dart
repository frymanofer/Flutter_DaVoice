// The car's confirmed replies - the same cases and expected sentences as the RN example's __tests__/carTools.test.ts (kept
// aligned: both apps must say the same thing for the same call).
import 'dart:io';

import 'package:flutter_davoice_car_agent/car/car_state.dart';
import 'package:flutter_davoice_car_agent/car/car_tools.dart';
import 'package:flutter_davoice_car_agent/flow/app_language.dart';
import 'package:flutter_davoice_llm/flutter_davoice_llm.dart';
import 'package:flutter_test/flutter_test.dart';

String say(String name, Map<String, Object?> args) => (runCarTool(name, args) as ToolReply).say;
Map result(String name, Map<String, Object?> args) => (runCarTool(name, args) as ToolReply).result as Map;

void main() {
  setUpAll(() => loadCarToolDefinitions(readFile: (p) => File(p).readAsString()));
  setUp(() {
    car.reset();
    car.setDriving(false);
    car.setSteering('left');
    setCurrentAppLanguage('en');
  });

  test('the h3 VW demo profile has the dual-zone tool; the v1 fallback does not', () {
    expect(carTools(wording: 'h3').map((t) => t.name), contains('set_dual_zone_temperature'));
    expect(carTools(wording: 'v1').map((t) => t.name), isNot(contains('set_dual_zone_temperature')));
    expect(carTools(wording: 'h3').firstWhere((t) => t.name == 'unlock_car').execution, isNotNull);
  });

  group('windows by place', () {
    test('success / already, en', () {
      expect(say('set_window', {'window': 'front_left', 'position': 'open'}), 'I opened the front left window.');
      expect(car.state.windows['front_left'], 'open');
      expect(say('set_window', {'window': 'front_left', 'position': 'open'}), 'The front left window is already open.');
      expect(say('set_window', {'window': 'rear', 'position': 'half'}), 'I opened the rear windows halfway.');
      expect(say('set_window', {'window': 'all', 'position': 'close'}), 'I closed all the windows.');
      expect(say('set_window', {'window': 'all', 'position': 'close'}), 'All the windows are already closed.');
    });
    test('success / already, pt-BR (agreement)', () {
      setCurrentAppLanguage('pt-BR');
      expect(say('set_window', {'window': 'rear_right', 'position': 'open'}), 'Abri o vidro traseiro direito.');
      expect(say('set_window', {'window': 'rear_right', 'position': 'open'}), 'O vidro traseiro direito já está aberto.');
      expect(say('set_window', {'window': 'left', 'position': 'close'}), 'Os vidros do lado esquerdo já estão fechados.');
      expect(say('set_window', {'window': 'left', 'position': 'crack'}), 'Deixei os vidros do lado esquerdo com uma fresta.');
      expect(say('set_window', {'window': 'left', 'position': 'close'}), 'Fechei os vidros do lado esquerdo.');
      expect(say('set_window', {'window': 'front', 'position': 'close'}), 'Os vidros da frente já estão fechados.');
    });
    test('driver / passenger follow the steering wheel', () {
      say('set_window', {'window': 'driver', 'position': 'open'});
      expect(car.state.windows['front_left'], 'open');
      car.setSteering('right');
      say('set_window', {'window': 'driver', 'position': 'crack'});
      expect(car.state.windows['front_right'], 'crack');
      say('set_window', {'window': 'passenger', 'position': 'half'});
      expect(car.state.windows['front_left'], 'half');
    });
    test('blocked while driving (all open) and an unknown window', () {
      car.setDriving(true);
      final r = runCarTool('set_window', {'window': 'all', 'position': 'open'}) as ToolReply;
      expect(r.say, "I can't do that while the car is moving.");
      expect((r.result as Map)['ok'], false);
      expect(car.state.windows['front_left'], 'close');
      expect(result('set_window', {'window': 'sunroof', 'position': 'open'})['ok'], false);
    });
  });

  group('doors and locks are separate operations', () {
    test('open / close one door, already, en + pt', () {
      expect(say('open_door', {'door': 'rear_left'}), 'I opened the rear left door.');
      expect(say('open_door', {'door': 'rear_left'}), 'The rear left door is already open.');
      setCurrentAppLanguage('pt-BR');
      expect(say('close_doors', {'door': 'rear_left'}), 'Fechei a porta traseira esquerda.');
      expect(say('close_doors', {}), 'Todas as portas já estão fechadas.');
      expect(car.state.windows['rear_left'], 'close');
    });
    test('a locked door: the app asks, nothing opens, nothing is unlocked', () {
      say('lock_car', {});
      final r = runCarTool('open_door', {'door': 'all'}) as ToolReply;
      expect(r.say, 'The car is locked. Should I unlock it?');
      expect((r.result as Map)['ok'], false);
      expect(car.state.locked, true);
      expect(car.state.doors.values.every((d) => d == 'closed'), true);
    });
    test('one door locked, en + pt', () {
      expect(say('lock_car', {'door': 'front_right'}), 'I locked the front right door.');
      expect(car.state.doorLocks['front_right'], true);
      expect(car.state.locked, false);
      expect(say('open_door', {'door': 'passenger'}), 'The front right door is locked. Should I unlock it?');
      setCurrentAppLanguage('pt-BR');
      expect(say('lock_car', {'door': 'front_right'}), 'A porta dianteira direita já está trancada.');
      expect(say('unlock_car', {'door': 'passenger'}), 'Destranquei a porta do passageiro.');
      expect(say('unlock_car', {}), 'O carro já está destrancado.');
    });
    test('no locking with a door open', () {
      say('open_door', {'door': 'front_left'});
      expect(say('lock_car', {}), "I can't lock it while the front left door is open. Close it first?");
      expect(car.state.locked, false);
    });
  });

  group('temperature', () {
    test('one zone: success / already / out of range', () {
      expect(say('set_temperature', {'temperature': 22, 'zone': 'driver'}), "I set the driver's side to 22°C.");
      expect(say('set_temperature', {'temperature': 22, 'zone': 'driver'}), "The driver's side is already at 22°C.");
      final r = runCarTool('set_temperature', {'temperature': 40}) as ToolReply;
      expect((r.result as Map)['ok'], false);
      expect(r.say, "I didn't change it: the temperature must be between 16 and 30.");
    });
    test('dual zone: both, already, partial, none (en + pt)', () {
      expect(say('set_dual_zone_temperature', {'driver': 20, 'passenger': 23}), "I set the driver's side to 20°C and the passenger side to 23°C.");
      expect(car.state.temperature['driver'], 20);
      expect(car.state.temperature['passenger'], 23);
      expect(say('set_dual_zone_temperature', {'driver': 20, 'passenger': 23}), "The driver's side is already at 20°C and the passenger side at 23°C.");
      setCurrentAppLanguage('pt-BR');
      expect(say('set_dual_zone_temperature', {'driver': 21, 'passenger': 35}), 'Coloquei o lado do motorista em 21°C, mas não o do passageiro: precisa ficar entre 16 e 30.');
      expect(car.state.temperature['passenger'], 23);
      final r = runCarTool('set_dual_zone_temperature', {'driver': 5, 'passenger': 50}) as ToolReply;
      expect((r.result as Map)['ok'], false);
      expect(r.say, 'Não mudei a temperatura: os dois valores precisam ficar entre 16 e 30.');
    });
  });

  group('other operations name what they did, or that nothing changed', () {
    test('seat, defrost, volume, fan', () {
      expect(say('set_seat_climate', {'feature': 'heater', 'level': 'off'}), "The heater in the driver's seat is already off.");
      expect(say('set_seat_climate', {'feature': 'heater', 'level': 'medium'}), "I set the heater in the driver's seat to medium.");
      expect(say('set_defrost', {'target': 'rear', 'on': false}), 'The rear defogger is already off.');
      expect(say('set_volume', {'action': 'unmute'}), 'The sound is already on, volume 12.');
      expect(say('set_volume', {'action': 'mute'}), 'I muted the sound.');
    });
    test('volume: a step of the size the user said, a target, the default step', () {
      // "change" = the step the agent core writes from the user's words (execution.stepArgument)
      expect(say('set_volume', {'action': 'up', 'change': 5}), 'I turned the volume up to 17.');
      expect(say('set_volume', {'action': 'down', 'change': -2}), 'I turned the volume down to 15.');
      expect(say('set_volume', {'action': 'down', 'change': 4}), 'I turned the volume down to 11.');
      expect(say('set_volume', {'action': 'set', 'change': 3}), 'I turned the volume up to 14.');
      expect(say('set_volume', {'action': 'up', 'change': 50}), 'I turned the volume up to 30.');
      expect(say('set_volume', {'action': 'set', 'level': 12}), 'I set the volume to 12.');
      // "up" with a level below the volume / "down" with one above it cannot be a target: the step
      expect(say('set_volume', {'action': 'up', 'level': 2}), 'I turned the volume up to 14.');
      expect(say('set_volume', {'action': 'down', 'level': 20}), 'I turned the volume down to 0.');
      expect(say('set_volume', {'action': 'set', 'level': 12}), 'I set the volume to 12.');
      // a target stays a target ("turn the volume down to 5", "up to 20"), the plain step stays 3
      expect(say('set_volume', {'action': 'down', 'level': 5}), 'I turned the volume down to 5.');
      expect(say('set_volume', {'action': 'up', 'level': 20}), 'I turned the volume up to 20.');
      expect(say('set_volume', {'action': 'up'}), 'I turned the volume up to 23.');
      expect(say('set_volume', {'action': 'down'}), 'I turned the volume down to 20.');
      expect(say('set_volume', {'action': 'set', 'level': 12}), 'I set the volume to 12.');
    });
    test('fan and the rest in Portuguese', () {
      setCurrentAppLanguage('pt-BR');
      expect(say('set_fan_speed', {'level': 3}), 'A ventilação já está no nível 3.');
      expect(say('set_fan_speed', {'level': 5}), 'Coloquei a ventilação no nível 5.');
    });
    test('lookups answer with the value', () {
      expect(say('get_vehicle_status', {'item': 'range'}), 'You have about 312 km of range left.');
      expect(say('get_trip_eta', {}), "There's no active route. Where do you want to go?");
    });
    test('the ETA says the route it has: the found place nearby, then a usual destination (2026-11-21)', () {
      say('find_along_route', {'place_type': 'gas_station'});
      say('navigate_to', {'destination': 'the nearest gas station'});
      expect(say('get_trip_eta', {}), "You'll get to the nearest gas station in about 3 minutes, 2.1 km to go.");
      say('navigate_to', {'destination': 'airport'});
      expect(say('get_trip_eta', {}), "You'll get to airport in about 24 minutes, 18 km to go.");
      setCurrentAppLanguage('pt-BR');
      say('find_along_route', {'place_type': 'coffee'});
      say('navigate_to', {'destination': 'o café mais próximo'});
      expect(say('get_trip_eta', {}), 'Você chega em o café mais próximo em cerca de 3 minutos; faltam 2,1 km.');
    });
  });

  test('a fan level outside 1-7 goes to the nearest end and says so (2026-11-10 round 2)', () {
    setCurrentAppLanguage('pt-BR');
    expect(say('set_fan_speed', {'level': 9}), 'A ventilação vai até o nível 7, então coloquei no nível 7.');
    expect(say('set_fan_speed', {'change': 2}), 'A ventilação vai até o nível 7, e já está nele.');
    setCurrentAppLanguage('en');
    expect(say('set_fan_speed', {'level': 0}), 'The lowest fan level is 1, so I set it to level 1.');
    expect(say('set_fan_speed', {'level': 4}), 'I set the fan to level 4.');
  });

  test('airflow sentences use the article in pt-BR ("para os pés"; as the RN example)', () {
    setCurrentAppLanguage('pt-BR');
    expect(say('set_airflow', {'mode': 'feet'}), 'O ar agora vai para os pés.');
    expect(say('set_airflow', {'mode': 'feet'}), 'O ar já vai para os pés.');
    expect(say('set_airflow', {'mode': 'face_and_feet'}), 'O ar agora vai para o rosto e os pés.');
    expect(say('set_airflow', {'mode': 'windshield'}), 'O ar agora vai para o para-brisa.');
  });
}
