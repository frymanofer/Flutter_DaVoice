// Conversation controller: who owns the microphone between requests, for the settings in conversation_settings.dart.
// The same phases, events and commands as the React Native apps (src/conversation/controller.ts); both run the
// scripted flows in conversation_flow.json.
//
//   off        not in the conversation screen (start-up / the wake-word screen owns the audio)
//   listening  the speech recognizer is open for the user's request
//   busy       a request is being answered (thinking, then the agent speaking)
//   asleep     the recognizer is closed; the wake word (or a tap) opens it again

import 'dart:async';

import 'barge_in.dart';
import 'conversation_settings.dart';

/// The reply asked something ("Should I open the driver window?"): in the wake-word mode only then does the user get a follow-up
/// turn without the wake word.
bool isQuestion(String reply) => RegExp(r'''[?？]["'”’)\]]*\s*$''').hasMatch(reply.trim());

enum ConversationPhase { off, listening, busy, asleep }

class ConversationCommands {
  const ConversationCommands({
    required this.openMic,
    required this.closeMic,
    required this.armWakeWord,
    required this.disarmWakeWord,
    required this.stopReply,
    this.onPhase,
    this.log,
    this.timer,
  });

  /// Open the speech recognizer (a fresh transcript). preFetchMs: keep that much audio from before it opened.
  final Future<void> Function(int preFetchMs, String why) openMic;

  /// Close the speech recognizer.
  final Future<void> Function(String why) closeMic;

  /// Wake word detection on.
  final Future<void> Function(String why) armWakeWord;

  /// Wake word detection off (the microphone stays with the app).
  final Future<void> Function(String why) disarmWakeWord;

  /// Stop the agent's reply now: its voice, the sentences still queued, the request.
  final Future<void> Function(String why) stopReply;

  final void Function(ConversationPhase phase)? onPhase;
  final void Function(String message)? log;

  /// Tests pass a fake clock; the app uses Timer.
  final Timer Function(Duration duration, void Function() callback)? timer;
}

class ConversationController {
  ConversationController(this._commands, this._settings);

  final ConversationCommands _commands;
  ConversationSettings _settings;
  ConversationPhase _phase = ConversationPhase.off;
  bool _speaking = false;
  bool _duplex = false;
  bool _wakeArmed = false;
  Timer? _timer;
  Future<void> _chain = Future<void>.value();

  ConversationPhase get phase => _phase;

  /// In the conversation screen.
  bool get active => _phase != ConversationPhase.off;

  /// The agent's voice is playing (replySpeaking .. replyFinished).
  bool get agentSpeaking => _speaking;

  /// Interrupt mode: the recognizer is open under the agent's voice.
  bool get duplexOpen => _duplex;

  ConversationSettings get settings => _settings;

  /// Completes when every command issued so far has run.
  Future<void> idle() => _chain;

  /// New settings; an open listening window restarts with the new timeout.
  /// New settings (the Save button). An open listening window restarts with the new timeout. Asleep in the wake-word mode and
  /// switched to "just talk": the microphone opens (otherwise nothing would ever open it).
  void update(ConversationSettings settings) {
    final before = _settings;
    _settings = settings;
    if (_phase == ConversationPhase.asleep && before.wakeWord && !settings.wakeWord) {
      _disarm('just talk');
      _run('openMic', () => _commands.openMic(0, 'just talk'));
      _setPhase(ConversationPhase.listening);
      _startWindow(_Window.idle);
    } else if (_phase == ConversationPhase.listening && !before.wakeWord && settings.wakeWord) {
      _sleep('wake word before each request'); // from now on every request starts with the wake word
    } else if (_phase == ConversationPhase.listening) {
      _startWindow(_settings.wakeWord ? _Window.listen : _Window.idle);
    }
  }

  /// The conversation screen opened; the app has opened the recognizer (and paused the wake word).
  /// Just talk: the app has opened the recognizer (and paused the wake word). Wake word before each request: asleep until the
  /// wake word (the app left the recognizer paused; the wake word that opened the screen is not a request).
  void enter() {
    _clearWindow();
    _speaking = false;
    _duplex = false;
    _wakeArmed = false;
    if (_settings.wakeWord) {
      _sleep('wake word before each request');
      return;
    }
    _setPhase(ConversationPhase.listening);
    _startWindow(_Window.idle);
  }

  /// Back to the start screen; the app closes the recognizer. rearmWakeWord: the start screen listens for the wake word
  /// (the car agents); false: the wake word goes back to paused, as in the conversation (a mode menu: the full examples).
  void leave({bool rearmWakeWord = true}) {
    _clearWindow();
    _speaking = false;
    _duplex = false;
    _setPhase(ConversationPhase.off);
    if (rearmWakeWord) {
      _arm('leave');
    } else {
      _disarm('leave');
    }
  }

  /// A request was sent (the app closed the recognizer for it).
  void turnStarted() {
    if (_phase == ConversationPhase.off) return; // a request outside the conversation screen: not ours
    _clearWindow();
    _speaking = false;
    _duplex = false;
    _setPhase(ConversationPhase.busy);
  }

  /// The reply's voice starts. Interrupt mode opens the recognizer under it; the wake-word mode can arm the stop word.
  void replySpeaking() {
    if (_phase != ConversationPhase.busy || _speaking) return;
    _speaking = true;
    if (_settings.interrupt) {
      _duplex = true;
      _run('openMic', () => _commands.openMic(0, 'interrupt: listen under the reply'));
    } else if (_settings.wakeWord && _settings.wakeWordMode.stopWord) {
      _arm('stop word during the reply');
    }
  }

  /// The request ended (its reply was spoken, or it ended without one): the next request, or sleep.
  /// [reply]: what the agent said. Wake-word mode: the user answers without the wake word only when the reply was
  /// a question (and the follow-up window is on); then recognition pauses and unpauses for a fresh turn. Otherwise back to the
  /// wake word.
  void replyFinished([String reply = '']) {
    if (_phase != ConversationPhase.busy) return;
    final wasDuplex = _duplex;
    _speaking = false;
    _duplex = false;
    if (_settings.wakeWord) {
      final question = isQuestion(reply);
      if (_settings.wakeWordMode.followUpMs == 0 || !question) {
        _sleep(question ? 'wake word every time' : 'the reply was not a question'); // a stop word armed for the reply stays armed
        return;
      }
      _disarm('a question: the user answers');
      _run('closeMic', () => _commands.closeMic('pause before the answer'));
      _run('openMic', () => _commands.openMic(0, 'answer to the question'));
      _setPhase(ConversationPhase.listening);
      _startWindow(_Window.followUp);
      return;
    }
    _disarm('reply finished');
    // the recognizer open under the reply heard the reply: a fresh session for the user's turn
    if (wasDuplex) _run('closeMic', () => _commands.closeMic('fresh session after the reply'));
    _run('openMic', () => _commands.openMic(0, 'after the reply'));
    _setPhase(ConversationPhase.listening);
    _startWindow(_Window.idle);
  }

  /// The user said something while listening: the window timeout no longer applies.
  void userSpeech() {
    if (_phase == ConversationPhase.listening) _clearWindow();
  }

  /// Speech heard while busy. True: the user interrupted the reply (interrupt mode, while the agent speaks, words the
  /// agent isn't saying): the reply was stopped and the words start the user's next request. False: drop them.
  bool heardWhileBusy(String heard, String agentText) {
    if (_phase != ConversationPhase.busy || !_duplex || !_speaking) return false;
    if (resolveBargeIn(heard, agentText) != BargeInDecision.interrupt) return false;
    _speaking = false;
    _duplex = false;
    _commands.log?.call('[Conversation] the user interrupted: "$heard"');
    _run('stopReply', () => _commands.stopReply('the user interrupted'));
    _setPhase(ConversationPhase.listening);
    _startWindow(_settings.wakeWord ? _Window.listen : _Window.idle);
    return true;
  }

  /// The wake word was heard. False when the conversation isn't open (the app's own start-up path handles it).
  bool wakeWord() {
    if (_phase == ConversationPhase.off) return false;
    if (_phase == ConversationPhase.busy) {
      // a stop word while the agent talks; while it is thinking the wake word is ignored
      if (_speaking && _wakeArmed) _stopAndListen('stop word');
      return true;
    }
    if (_phase == ConversationPhase.asleep) {
      _disarm('wake word');
      final preFetch = _settings.wakeWord ? _settings.wakeWordMode.preFetchMs : 0;
      _run('openMic', () => _commands.openMic(preFetch, 'wake word'));
      _setPhase(ConversationPhase.listening);
      _startWindow(_settings.wakeWord ? _Window.listen : _Window.idle);
    }
    return true;
  }

  /// The microphone button: wakes the conversation, or stops the agent and listens.
  void tapToTalk() {
    if (_phase == ConversationPhase.asleep) {
      _disarm('tap');
      _run('openMic', () => _commands.openMic(0, 'tap'));
      _setPhase(ConversationPhase.listening);
      _startWindow(_settings.wakeWord ? _Window.listen : _Window.idle);
    } else if (_phase == ConversationPhase.busy && _speaking) {
      _stopAndListen('tap');
    }
  }

  void _stopAndListen(String why) {
    final wasDuplex = _duplex;
    _speaking = false;
    _duplex = false;
    _run('stopReply', () => _commands.stopReply(why));
    _disarm(why);
    if (wasDuplex) _run('closeMic', () => _commands.closeMic('fresh session'));
    // no pre-fetch: the audio before this moment is the agent's voice and the wake word itself
    _run('openMic', () => _commands.openMic(0, 'after the $why'));
    _setPhase(ConversationPhase.listening);
    _startWindow(_settings.wakeWord ? _Window.listen : _Window.idle);
  }

  void _sleep(String why) {
    _clearWindow();
    _speaking = false;
    _duplex = false;
    _run('closeMic', () => _commands.closeMic(why));
    _arm(why);
    _setPhase(ConversationPhase.asleep);
  }

  void _startWindow(_Window kind) {
    _clearWindow();
    final ms = switch (kind) {
      _Window.listen => _settings.wakeWordMode.listenMs,
      _Window.followUp => _settings.wakeWordMode.followUpMs,
      _Window.idle => _settings.freeMode.idleMs,
    };
    if (ms <= 0) return;
    final make = _commands.timer ?? Timer.new;
    _timer = make(Duration(milliseconds: ms), () {
      _timer = null;
      if (_phase == ConversationPhase.listening) _sleep(kind == _Window.idle ? 'nothing said' : 'no request');
    });
  }

  void _clearWindow() {
    _timer?.cancel();
    _timer = null;
  }

  void _arm(String why) {
    if (_wakeArmed) return;
    _wakeArmed = true;
    _run('armWakeWord', () => _commands.armWakeWord(why));
  }

  void _disarm(String why) {
    if (!_wakeArmed) return;
    _wakeArmed = false;
    _run('disarmWakeWord', () => _commands.disarmWakeWord(why));
  }

  void _setPhase(ConversationPhase phase) {
    if (phase == _phase) return;
    _phase = phase;
    _commands.log?.call('[Conversation] ${phase.name}');
    _commands.onPhase?.call(phase);
  }

  void _run(String name, Future<void> Function() command) {
    _chain = _chain.then((_) => command()).catchError((Object error) {
      _commands.log?.call('[Conversation] $name failed (ignored): $error');
    });
  }
}

enum _Window { listen, followUp, idle }

/// The microphone line: what the conversation is doing now and how to go on.
String conversationHint(ConversationPhase phase, String wakePhrase, bool wakeWord) => switch (phase) {
      ConversationPhase.asleep => wakeWord ? 'Say “$wakePhrase” before each request' : 'Say “$wakePhrase” or tap to talk',
      ConversationPhase.listening => wakeWord ? 'Listening… say your request' : 'Listening… just talk',
      ConversationPhase.busy => 'Answering… tap to stop',
      ConversationPhase.off => '“$wakePhrase” + your command',
    };

/// A tap on the microphone line does something (wakes the conversation, or stops the agent).
bool conversationTapEnabled(ConversationPhase phase) => phase == ConversationPhase.asleep || phase == ConversationPhase.busy;

/// How speech recognition also writes each wake-phrase word, as word sequences (on the phone: "Hey couch", "A coach", "Hey the
/// voice", "Hey da voice", "Hello voice").
const _soundsLike = <String, List<List<String>>>{
  'hey': [['hey'], ['hi'], ['hay'], ['hei'], ['a'], ['okay'], ['ok']],
  'hello': [['hello'], ['hallo'], ['hullo'], ['hola'], ['allo'], ['hey'], ['hi']],
  'coach': [['coach'], ['couch'], ['koch'], ['coachs'], ['coaches']],
  'davoice': [
    ['davoice'], ['da', 'voice'], ['the', 'voice'], ['de', 'voice'], ['devoice'], ['divoice'], ['dvoice'], ['d', 'voice'],
    ['davoices'], ['the', 'voices'], ['voice'], ['voices'], ['davos'], ['davis'],
  ],
};

/// A first word that counts alone ("Hey, open the window"); "a" or "ok" only count in front of the next word of the phrase.
const _alone = <String, List<String>>{
  'hey': ['hey', 'hi', 'hay', 'hei'],
  'hello': ['hello', 'hallo', 'hullo'],
};

final _nonWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
final _word = RegExp(r"[\p{L}\p{N}']+", unicode: true);
final _leadingSeparators = RegExp(r'''^[\s,.!?;:'"“”‘’-]+''');
String _norm(String w) => w.toLowerCase().replaceAll(_nonWord, '');
List<List<String>> _forms(String phraseWord) => _soundsLike[phraseWord] ?? [[phraseWord]];
bool _aloneWord(String word, String phraseWord) => (_alone[phraseWord] ?? [phraseWord]).contains(_norm(word));

/// The transcript without the wake phrase that leads it, so the model never gets it: "Hey DaVoice, open the window" -> "open the
/// window". Also part of the phrase ("DaVoice, lock the car", "The voice, lock the car", "Hey, open the window"), the way
/// recognition mishears it ("Hey the voice", "Hey couch"), and the phrase said twice. Only wake words ("Hey DaVoice.", "The voice",
/// "Hey") -> '' (the request is still to come). Words are compared whole: "Coaching tips", "Heyday", "a car" stay as they are.
/// As the React Native apps' dropWakePhrase (src/conversation/wakePhrase.ts), the same fixture (conversation_wake_phrase.json).
String dropWakePhrase(String text, String wakePhrase) {
  final phrase = wakePhrase.split(RegExp(r'\s+')).map(_norm).where((w) => w.isNotEmpty).toList();
  final words = _word.allMatches(text).toList();
  if (words.isEmpty) return '';
  if (phrase.isEmpty) return text.trim();
  final normalized = words.map((m) => _norm(m.group(0)!)).toList();
  var at = 0; // words consumed
  for (var round = 0; round < 3 && at < words.length; round++) {
    final taken = _leadingPhrase(normalized.sublist(at), phrase);
    if (taken == 0) break;
    at += taken;
  }
  if (at == 0) return text.trim();
  if (at >= words.length) return '';
  return text.substring(words[at - 1].end).replaceFirst(_leadingSeparators, '').trim();
}

/// How many words phrase[from..] takes at the start of words (each phrase word in one of its forms), or -1. Longest first.
int _matchFrom(List<String> words, List<String> phrase, int from, [int at = 0]) {
  if (from == phrase.length) return at;
  var best = -1;
  for (final form in _forms(phrase[from])) {
    var fits = at + form.length <= words.length;
    for (var i = 0; fits && i < form.length; i++) {
      if (words[at + i] != form[i]) fits = false;
    }
    if (fits) {
      final taken = _matchFrom(words, phrase, from + 1, at + form.length);
      if (taken > best) best = taken;
    }
  }
  return best;
}

/// How many leading words are the wake phrase: all of it, its end ("davoice", "the voice"), or its first word alone ("hey").
int _leadingPhrase(List<String> words, List<String> phrase) {
  for (var start = 0; start < phrase.length; start++) {
    final taken = _matchFrom(words, phrase, start);
    if (taken > 0) return taken;
  }
  if (phrase.length > 1 && _aloneWord(words[0], phrase[0])) return 1;
  return 0;
}
