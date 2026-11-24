// Conversation modes (lib/conversation): the settings, the interrupt (echo) rule and the controller's scripted flows,
// on the same fixtures as the React Native apps' __tests__/conversation.test.ts (test/fixtures/conversation_*.json,
// kept identical).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_davoice_example/conversation/barge_in.dart';
import 'package:flutter_davoice_example/conversation/conversation_controller.dart';
import 'package:flutter_davoice_example/conversation/conversation_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_wake_word/flutter_wake_word.dart';

Object? _merge(Object? base, Object? patch) {
  if (patch is! Map) return patch ?? base;
  final out = <String, Object?>{...(base is Map ? base.cast<String, Object?>() : const {})};
  patch.forEach((k, v) => out['$k'] = v is Map ? _merge(out['$k'], v) : v);
  return out;
}

class _FakeTimer implements Timer {
  _FakeTimer(this.clock, this.due, this.callback);
  final _FakeClock clock;
  final int due;
  final void Function() callback;
  bool _active = true;
  @override
  void cancel() => _active = false;
  @override
  bool get isActive => _active;
  @override
  int get tick => 0;
}

class _FakeClock {
  int now = 0;
  final timers = <_FakeTimer>[];
  Timer make(Duration d, void Function() fn) {
    final t = _FakeTimer(this, now + d.inMilliseconds, fn);
    timers.add(t);
    return t;
  }

  void advance(int ms) {
    final end = now + ms;
    for (;;) {
      final due = timers.where((t) => t.isActive && t.due <= end).toList()..sort((a, b) => a.due.compareTo(b.due));
      if (due.isEmpty) break;
      final t = due.first;
      t.cancel();
      now = t.due;
      t.callback();
    }
    now = end;
  }
}

const _rnFixtures = '../../ReactNative_DaVoice/example_car_agent/__tests__/fixtures';

void main() {
  test('the React Native apps and this app share the same fixtures', () {
    for (final name in ['conversation_flow.json', 'conversation_barge_in.json', 'conversation_wake_phrase.json']) {
      final rn = File('$_rnFixtures/$name');
      if (rn.existsSync()) expect(File('test/fixtures/$name').readAsStringSync(), rn.readAsStringSync(), reason: name);
    }
  });

  group('conversation settings', () {
    test('defaults keep the behaviour from before the settings', () {
      expect(defaultConversationSettings.toJson(), {
        'interrupt': false,
        'wakeWord': false,
        'wakeWordMode': {'endOfSpeechMs': 2000, 'listenMs': 8000, 'followUpMs': 8000, 'preFetchMs': 2000, 'stopWord': false},
        'freeMode': {'endOfSpeechMs': 2000, 'idleMs': 0},
      });
      expect(defaultConversationSettings.description, 'Just talk · take turns');
    });

    test('normalize fills, clamps and drops what it does not know (as the RN test)', () {
      expect(normalizeConversationSettings(null), defaultConversationSettings);
      expect(normalizeConversationSettings('nonsense'), defaultConversationSettings);
      final s = normalizeConversationSettings({
        'interrupt': true,
        'wakeWord': 'yes',
        'extra': 1,
        'wakeWordMode': {'endOfSpeechMs': 50, 'followUpMs': -5, 'preFetchMs': 99999, 'listenMs': 7000.4, 'stopWord': false},
        'freeMode': {'idleMs': 'x'},
      });
      expect(s.toJson(), {
        'interrupt': true,
        'wakeWord': false,
        'wakeWordMode': {'endOfSpeechMs': 500, 'listenMs': 7000, 'followUpMs': 0, 'preFetchMs': 3000, 'stopWord': false},
        'freeMode': {'endOfSpeechMs': 2000, 'idleMs': 0},
      });
      expect(normalizeConversationSettings(jsonDecode(jsonEncode(s.toJson()))), s);
    });

    test('the defaults are among the choices; the end of speech follows the mode', () {
      expect(endOfSpeechChoices.map((c) => c.value), contains(2000));
      expect(listenChoices.map((c) => c.value), contains(8000));
      expect(followUpChoices.map((c) => c.value), contains(8000));
      expect(preFetchChoices.map((c) => c.value), contains(2000));
      expect(idleChoices.map((c) => c.value), contains(0));
      final s = normalizeConversationSettings({'wakeWordMode': {'endOfSpeechMs': 1500}, 'freeMode': {'endOfSpeechMs': 3000}});
      expect(s.endOfSpeechMs, 3000);
      expect(s.copyWith(wakeWord: true).endOfSpeechMs, 1500);
    });

    test('interrupting turns echo cancellation on; taking turns leaves the routing as it is', () {
      const base = AudioRoutingConfig(
        defaultRoute: RouteConfigEntry(category: WakewordAudioCategory.playAndRecord, mode: WakewordAudioMode.defaultMode, options: [], preferredInput: WakewordPreferredInput.none),
        wakewordAEC: WakewordAECConfig(),
      );
      expect(identical(routingConfigForConversation(base, defaultConversationSettings), base), isTrue);
      final on = routingConfigForConversation(base, defaultConversationSettings.copyWith(interrupt: true)).toJson();
      expect(on['AEC'], {'mode': 'always'});
      expect(on['WakewordAEC'], {'regular': true, 'duringTTS': true});
      expect(on['default'], base.toJson()['default']);
    });
  });

  test('interrupt rule (conversation_barge_in.json)', () {
    final cases = (jsonDecode(File('test/fixtures/conversation_barge_in.json').readAsStringSync()) as List).cast<Map>();
    for (final c in cases) {
      expect(resolveBargeIn(c['heard'] as String, c['agent'] as String).name, c['decision'], reason: '"${c['heard']}" over "${c['agent']}"');
    }
  });

  test('wake phrase (conversation_wake_phrase.json)', () {
    final cases = (jsonDecode(File('test/fixtures/conversation_wake_phrase.json').readAsStringSync()) as List).cast<Map>();
    for (final c in cases) {
      expect(dropWakePhrase(c['text'] as String, c['phrase'] as String), c['out'], reason: '"${c['text']}"');
    }
  });

  test('microphone line', () {
    expect(conversationHint(ConversationPhase.asleep, 'Hey Coach', true), 'Say “Hey Coach” before each request');
    expect(conversationHint(ConversationPhase.asleep, 'Hey Coach', false), 'Say “Hey Coach” or tap to talk');
    expect(conversationHint(ConversationPhase.listening, 'Hey Coach', true), 'Listening… say your request');
    expect(conversationHint(ConversationPhase.listening, 'Hey Coach', false), 'Listening… just talk');
    expect(conversationHint(ConversationPhase.busy, 'Hey Coach', false), 'Answering… tap to stop');
    expect(conversationHint(ConversationPhase.off, 'Hey Coach', false), '“Hey Coach” + your command');
    expect(ConversationPhase.values.where(conversationTapEnabled), [ConversationPhase.busy, ConversationPhase.asleep]);
  });

  group('conversation controller (conversation_flow.json)', () {
    final flows = (jsonDecode(File('test/fixtures/conversation_flow.json').readAsStringSync()) as List).cast<Map>();
    for (final flow in flows) {
      test(flow['name'] as String, () async {
        final clock = _FakeClock();
        final log = <String>[];
        var settings = normalizeConversationSettings(_merge(defaultConversationSettings.toJson(), flow['settings']));
        final c = ConversationController(
          ConversationCommands(
            openMic: (ms, _) async => log.add('openMic:$ms'),
            closeMic: (_) async => log.add('closeMic'),
            armWakeWord: (_) async => log.add('armWakeWord'),
            disarmWakeWord: (_) async => log.add('disarmWakeWord'),
            stopReply: (_) async => log.add('stopReply'),
            timer: clock.make,
          ),
          settings,
        );
        final steps = (flow['steps'] as List).cast<Map>();
        for (var i = 0; i < steps.length; i++) {
          final step = steps[i];
          final at = 'step $i (${step['do']})';
          final before = log.length;
          bool? returned;
          switch (step['do']) {
            case 'enter':
              c.enter();
            case 'leave':
              c.leave(rearmWakeWord: step['rearm'] as bool? ?? true);
            case 'turnStarted':
              c.turnStarted();
            case 'replySpeaking':
              c.replySpeaking();
            case 'replyFinished':
              c.replyFinished(step['reply'] as String? ?? '');
            case 'userSpeech':
              c.userSpeech();
            case 'tapToTalk':
              c.tapToTalk();
            case 'wakeWord':
              returned = c.wakeWord();
            case 'heard':
              returned = c.heardWhileBusy(step['text'] as String? ?? '', step['agent'] as String? ?? '');
            case 'wait':
              clock.advance(step['ms'] as int? ?? 0);
            case 'update':
              settings = normalizeConversationSettings(_merge(settings.toJson(), step['settings']));
              c.update(settings);
            default:
              fail('unknown step ${step['do']}');
          }
          await c.idle();
          if (step.containsKey('returns')) expect(returned, step['returns'], reason: at);
          if (step.containsKey('log')) expect(log.sublist(before), (step['log'] as List).cast<String>(), reason: at);
          if (step.containsKey('phase')) expect(c.phase.name, step['phase'], reason: at);
        }
      });
    }
  });

  test('runs the commands in order even when one is slow, and a failing command does not stop the next', () async {
    final log = <String>[];
    Future<void> Function(String) slow(String name, int ms) => (_) async {
          await Future<void>.delayed(Duration(milliseconds: ms));
          log.add(name);
        };
    final c = ConversationController(
      ConversationCommands(
        openMic: (ms, why) => slow('openMic', 30)(why),
        closeMic: (_) async => throw StateError('boom'),
        armWakeWord: slow('armWakeWord', 1),
        disarmWakeWord: slow('disarmWakeWord', 1),
        stopReply: slow('stopReply', 1),
      ),
      normalizeConversationSettings({'wakeWord': true, 'wakeWordMode': {'followUpMs': 0, 'stopWord': true}}),
    );
    c.enter();
    c.turnStarted();
    c.replySpeaking();
    c.replyFinished();
    c.wakeWord();
    c.userSpeech();
    c.turnStarted();
    c.replySpeaking();
    await c.idle();
    expect(log, ['armWakeWord', 'disarmWakeWord', 'openMic', 'armWakeWord']);
  });

  test('a reply that asks a question (the wake-word mode answers it without the wake word)', () {
    expect(isQuestion('Should I open the passenger window too?'), isTrue);
    expect(isQuestion('Quer que eu abra o vidro do carona? '), isTrue);
    expect(isQuestion('Did you say “the trunk?”'), isTrue);
    expect(isQuestion('I opened the driver window.'), isFalse);
    expect(isQuestion('Why? Because it was cold.'), isFalse);
    expect(isQuestion(''), isFalse);
  });
}
