import 'package:flutter_davoice_car_agent/car/speech_composer.dart';
import 'package:flutter_test/flutter_test.dart';

String run(
  List<(String, String, bool)> says,
  String text, [
  String lang = 'en',
]) {
  beginCarTurn();
  resetSpeechVariant();
  for (final (tool, say, merge) in says) {
    noteCarSay(tool, say, merge);
  }
  return composeCarSpeech(text, carTurnActions(), lang);
}

void main() {
  test('closes the doors and locks the car', () {
    expect(
      run([
        ('close_doors', 'I closed all the doors.', true),
        ('lock_car', 'I locked the car.', true),
      ], 'I closed all the doors. I locked the car.'),
      'All set. I closed all the doors and locked the car. Everything is secure.',
    );
  });
  test('pt-BR, three actions', () {
    expect(
      run(
        [
          ('set_window', 'Fechei todas as janelas.', true),
          ('close_doors', 'Fechei todas as portas.', true),
          ('lock_car', 'Tranquei o carro.', true),
        ],
        'Fechei todas as janelas. Fechei todas as portas. Tranquei o carro.',
        'pt-BR',
      ),
      'Pronto! Fechei todas as janelas, fechei todas as portas e tranquei o carro. Está tudo seguro.',
    );
  });
  test(
    'one action, a refusal, an undo or a status stay as they were; nothing is invented',
    () {
      expect(
        run([('lock_car', 'I locked the car.', true)], 'I locked the car.'),
        'I locked the car.',
      );
      expect(
        run([
          ('lock_car', 'I locked the car.', true),
          ('open_door', 'The car is locked. Should I unlock it?', false),
        ], 'I locked the car. The car is locked. Should I unlock it?'),
        'I locked the car. The car is locked. Should I unlock it?',
      );
      expect(
        run([
          ('get_vehicle_status', 'The battery is at 76%.', true),
          ('lock_car', 'I locked the car.', true),
        ], 'The battery is at 76%. I locked the car.'),
        'The battery is at 76%. I locked the car.',
      );
      expect(
        run([
          ('lock_car', 'I locked the car.', true),
        ], 'I closed all the doors. I locked the car.'),
        'I closed all the doors. I locked the car.',
      );
    },
  );
}
