// Conversation mode settings (the settings sheet): how the user and the agent take turns.
//
// - interrupt: false = take turns (the microphone is closed while the agent answers), true = the user can talk
//   over the agent. Interrupting keeps the microphone open under the agent's voice, so it needs echo cancellation
//   (AEC): it turns AEC on for speech recognition, the wake word and text to speech.
// - wakeWord: true = each request starts with the wake word (a short window after a reply lets a follow-up through
//   without it), false = just talk: the microphone stays open between requests.
// - Each of the two modes has its own timeouts. The wake-word mode can also keep the audio from just before the
//   speech recognizer opened (preFetchMs), so "Hey DaVoice, open the window" said in one breath keeps its first words.
//
// The same JSON shape and rules as the React Native apps (src/conversation/settings.ts).

import 'package:flutter_wake_word/flutter_wake_word.dart';

class WakeWordModeSettings {
  const WakeWordModeSettings({
    required this.endOfSpeechMs,
    required this.listenMs,
    required this.followUpMs,
    required this.preFetchMs,
    required this.stopWord,
  });

  /// Silence that ends the user's request (ms).
  final int endOfSpeechMs;

  /// After the wake word (or a tap), how long to wait for the first words before going back to the wake word (ms).
  final int listenMs;

  /// After a reply, how long to keep listening for a follow-up without the wake word (ms). 0 = the wake word every time.
  final int followUpMs;

  /// Audio kept from just before the recognizer opened after the wake word (ms). 0 = off.
  final int preFetchMs;

  /// The wake word said while the agent is talking stops it and opens a new request.
  final bool stopWord;

  WakeWordModeSettings copyWith({int? endOfSpeechMs, int? listenMs, int? followUpMs, int? preFetchMs, bool? stopWord}) =>
      WakeWordModeSettings(
        endOfSpeechMs: endOfSpeechMs ?? this.endOfSpeechMs,
        listenMs: listenMs ?? this.listenMs,
        followUpMs: followUpMs ?? this.followUpMs,
        preFetchMs: preFetchMs ?? this.preFetchMs,
        stopWord: stopWord ?? this.stopWord,
      );

  Map<String, Object> toJson() => {
        'endOfSpeechMs': endOfSpeechMs,
        'listenMs': listenMs,
        'followUpMs': followUpMs,
        'preFetchMs': preFetchMs,
        'stopWord': stopWord,
      };

  @override
  bool operator ==(Object other) =>
      other is WakeWordModeSettings &&
      other.endOfSpeechMs == endOfSpeechMs &&
      other.listenMs == listenMs &&
      other.followUpMs == followUpMs &&
      other.preFetchMs == preFetchMs &&
      other.stopWord == stopWord;

  @override
  int get hashCode => Object.hash(endOfSpeechMs, listenMs, followUpMs, preFetchMs, stopWord);
}

class FreeModeSettings {
  const FreeModeSettings({required this.endOfSpeechMs, required this.idleMs});

  /// Silence that ends the user's request (ms).
  final int endOfSpeechMs;

  /// With nothing said for this long, the microphone closes until the wake word or a tap (ms). 0 = never.
  final int idleMs;

  FreeModeSettings copyWith({int? endOfSpeechMs, int? idleMs}) =>
      FreeModeSettings(endOfSpeechMs: endOfSpeechMs ?? this.endOfSpeechMs, idleMs: idleMs ?? this.idleMs);

  Map<String, Object> toJson() => {'endOfSpeechMs': endOfSpeechMs, 'idleMs': idleMs};

  @override
  bool operator ==(Object other) => other is FreeModeSettings && other.endOfSpeechMs == endOfSpeechMs && other.idleMs == idleMs;

  @override
  int get hashCode => Object.hash(endOfSpeechMs, idleMs);
}

class ConversationSettings {
  const ConversationSettings({
    required this.interrupt,
    required this.wakeWord,
    required this.wakeWordMode,
    required this.freeMode,
  });

  final bool interrupt;
  final bool wakeWord;
  final WakeWordModeSettings wakeWordMode;
  final FreeModeSettings freeMode;

  ConversationSettings copyWith({bool? interrupt, bool? wakeWord, WakeWordModeSettings? wakeWordMode, FreeModeSettings? freeMode}) =>
      ConversationSettings(
        interrupt: interrupt ?? this.interrupt,
        wakeWord: wakeWord ?? this.wakeWord,
        wakeWordMode: wakeWordMode ?? this.wakeWordMode,
        freeMode: freeMode ?? this.freeMode,
      );

  Map<String, Object> toJson() => {
        'interrupt': interrupt,
        'wakeWord': wakeWord,
        'wakeWordMode': wakeWordMode.toJson(),
        'freeMode': freeMode.toJson(),
      };

  /// The silence that ends a request in the selected mode.
  int get endOfSpeechMs => wakeWord ? wakeWordMode.endOfSpeechMs : freeMode.endOfSpeechMs;

  /// One line for the settings row ("Wake word · take turns").
  String get description => '${wakeWord ? 'Wake word' : 'Just talk'} · ${interrupt ? 'interrupt anytime' : 'take turns'}';

  @override
  bool operator ==(Object other) =>
      other is ConversationSettings &&
      other.interrupt == interrupt &&
      other.wakeWord == wakeWord &&
      other.wakeWordMode == wakeWordMode &&
      other.freeMode == freeMode;

  @override
  int get hashCode => Object.hash(interrupt, wakeWord, wakeWordMode, freeMode);
}

/// Today's behaviour: take turns; after the first wake word the microphone stays open (no wake word).
const defaultConversationSettings = ConversationSettings(
  interrupt: false,
  wakeWord: false,
  wakeWordMode: WakeWordModeSettings(endOfSpeechMs: 2000, listenMs: 8000, followUpMs: 8000, preFetchMs: 2000, stopWord: false),
  freeMode: FreeModeSettings(endOfSpeechMs: 2000, idleMs: 0),
);

typedef ConversationChoice = ({int value, String label});

const endOfSpeechChoices = <ConversationChoice>[
  (value: 1000, label: '1 s'),
  (value: 1500, label: '1.5 s'),
  (value: 2000, label: '2 s'),
  (value: 2500, label: '2.5 s'),
  (value: 3000, label: '3 s'),
];
const listenChoices = <ConversationChoice>[
  (value: 4000, label: '4 s'),
  (value: 6000, label: '6 s'),
  (value: 8000, label: '8 s'),
  (value: 10000, label: '10 s'),
  (value: 15000, label: '15 s'),
];
const followUpChoices = <ConversationChoice>[
  (value: 0, label: 'Off'),
  (value: 5000, label: '5 s'),
  (value: 8000, label: '8 s'),
  (value: 15000, label: '15 s'),
  (value: 30000, label: '30 s'),
];
const preFetchChoices = <ConversationChoice>[
  (value: 0, label: 'Off'),
  (value: 500, label: '0.5 s'),
  (value: 1000, label: '1 s'),
  (value: 2000, label: '2 s'),
  (value: 3000, label: '3 s'),
];
const idleChoices = <ConversationChoice>[
  (value: 0, label: 'Never'),
  (value: 15000, label: '15 s'),
  (value: 30000, label: '30 s'),
  (value: 60000, label: '1 min'),
  (value: 120000, label: '2 min'),
];

int _num(Object? v, int fallback, int min, int max) {
  final n = v is num && v.isFinite ? v.round() : fallback;
  return n < min ? min : (n > max ? max : n);
}

bool _bool(Object? v, bool fallback) => v is bool ? v : fallback;

Map<String, Object?> _obj(Object? v) => v is Map ? v.map((k, value) => MapEntry('$k', value)) : const {};

/// Any stored or edited value -> complete, in-range settings (unknown keys dropped, missing ones defaulted).
ConversationSettings normalizeConversationSettings(Object? raw) {
  const d = defaultConversationSettings;
  final r = _obj(raw);
  final w = _obj(r['wakeWordMode']);
  final f = _obj(r['freeMode']);
  return ConversationSettings(
    interrupt: _bool(r['interrupt'], d.interrupt),
    wakeWord: _bool(r['wakeWord'], d.wakeWord),
    wakeWordMode: WakeWordModeSettings(
      endOfSpeechMs: _num(w['endOfSpeechMs'], d.wakeWordMode.endOfSpeechMs, 500, 6000),
      listenMs: _num(w['listenMs'], d.wakeWordMode.listenMs, 2000, 60000),
      followUpMs: _num(w['followUpMs'], d.wakeWordMode.followUpMs, 0, 120000),
      preFetchMs: _num(w['preFetchMs'], d.wakeWordMode.preFetchMs, 0, 3000),
      stopWord: _bool(w['stopWord'], d.wakeWordMode.stopWord),
    ),
    freeMode: FreeModeSettings(
      endOfSpeechMs: _num(f['endOfSpeechMs'], d.freeMode.endOfSpeechMs, 500, 6000),
      idleMs: _num(f['idleMs'], d.freeMode.idleMs, 0, 600000),
    ),
  );
}

/// The audio routing for these settings: the app's routing with echo cancellation on for every listener when the user
/// can interrupt, and unchanged otherwise (as the React Native apps' routingConfigForConversation).
AudioRoutingConfig routingConfigForConversation(AudioRoutingConfig base, ConversationSettings s) {
  if (!s.interrupt) return base;
  return AudioRoutingConfig(
    defaultRoute: base.defaultRoute,
    carAudio: base.carAudio,
    builtInReceiver: base.builtInReceiver,
    builtInSpeaker: base.builtInSpeaker,
    bluetoothA2DP: base.bluetoothA2DP,
    bluetoothHFP: base.bluetoothHFP,
    headphones: base.headphones,
    whenPlayingAudio: base.whenPlayingAudio,
    sttDuckingConfig: base.sttDuckingConfig,
    aec: const AECConfig(mode: AECMode.always),
    wakewordAEC: const WakewordAECConfig(regular: true, duringTTS: true),
    wakeWordDuringTTS: base.wakeWordDuringTTS,
  );
}
