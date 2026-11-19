import 'package:flutter/foundation.dart';

// A simulated car for the DaVoice Car demo (port of the RN example's src/car/CarState.ts): the agent's car tools change this state,
// and the car card shows what the AI understood and which tool it used. Nothing here talks to a real vehicle.

class CarState {
  String? destination;
  List<String> avoid = [];
  // Temperatures per zone (driver / passenger / rear) and the unit ('celsius' | 'fahrenheit').
  Map<String, num> temperature = {'driver': 21, 'passenger': 21, 'rear': 21};
  String unit = 'celsius';
  int fan = 3;
  String airflow = 'face';
  Map<String, bool> defrost = {'windshield': false, 'rear': false};

  /// The car's configuration: which side the steering wheel is on (driver / passenger are resolved from it). Brazil: left.
  String steering = 'left';

  /// By place: front_left / front_right / rear_left / rear_right. Windows: open | close | half | crack; doors: open | closed.
  Map<String, String> windows = {'front_left': 'close', 'front_right': 'close', 'rear_left': 'close', 'rear_right': 'close'};
  Map<String, String> doors = {'front_left': 'closed', 'front_right': 'closed', 'rear_left': 'closed', 'rear_right': 'closed'};

  /// Every door locked (the car); doorLocks has each door.
  bool locked = false;
  Map<String, bool> doorLocks = {'front_left': false, 'front_right': false, 'rear_left': false, 'rear_right': false};
  String sunroof = 'close';
  String sunshade = 'open';
  String trunk = 'close';
  String frunk = 'close';
  String chargePort = 'close';
  String screen = 'landscape';
  Map<String, String> seatHeater = {'driver': 'off', 'passenger': 'off', 'rear_left': 'off', 'rear_right': 'off'};
  Map<String, String> seatVentilation = {'driver': 'off', 'passenger': 'off', 'rear_left': 'off', 'rear_right': 'off'};
  String massageSeat = 'driver';
  bool massageOn = false;
  int massageMode = 1;
  bool wheelHeater = false;
  bool ambientOn = false;
  String ambientColor = 'white';
  bool readingLights = false;
  String? media;
  String? radio;
  String source = 'streaming';
  String audioFocus = 'all';
  int volume = 12;
  bool muted = false;
  String? call;
  String? scenario;

  /// Moving: the app refuses what isn't allowed while driving (the card's Parked / Driving switch).
  bool driving = false;
  int fuelPercent = 62;
}

/// One tool call the AI made: what the card shows.
class CarAction {
  CarAction(this.id, this.tool, this.args, this.summary, {this.ok = true, this.blocked});
  final int id;
  final String tool;
  final Map<String, Object?> args;

  /// What the car did, in words.
  final String summary;
  final bool ok;

  /// Set when the app refused it (vehicle state, value range): nothing was changed.
  final String? blocked;
}

class Car extends ChangeNotifier {
  Car._();
  static final Car instance = Car._();

  CarState state = CarState();
  final List<CarAction> actions = [];
  int _nextId = 1;

  void changed() => notifyListeners();

  void record(String tool, Map<String, Object?> args, String summary, {bool ok = true, String? blocked}) {
    actions.add(CarAction(_nextId++, tool, args, summary, ok: ok, blocked: blocked));
    if (actions.length > 20) actions.removeAt(0);
    notifyListeners();
  }

  void setDriving(bool driving) {
    state.driving = driving;
    notifyListeners();
  }

  /// The steering-wheel side (vehicle configuration); driver / passenger follow it.
  void setSteering(String steering) {
    state.steering = steering;
    notifyListeners();
  }

  void reset() {
    final keep = state;
    state = CarState()
      ..driving = keep.driving
      ..steering = keep.steering;
    actions.clear();
    notifyListeners();
  }
}

Car get car => Car.instance;
