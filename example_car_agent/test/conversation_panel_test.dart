// The conversation settings panel and bar (lib/conversation/conversation_settings_panel.dart): each control changes its own
// setting, each mode shows its own timeouts, the gear opens the panel and the microphone line follows the phase (as the
// React Native apps' __tests__/conversationPanel.test.tsx).
import 'package:flutter/material.dart';
import 'package:flutter_davoice_car_agent/conversation/conversation_controller.dart';
import 'package:flutter_davoice_car_agent/conversation/conversation_settings.dart';
import 'package:flutter_davoice_car_agent/conversation/conversation_settings_panel.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('just talk: the free mode timeouts; wake word: its own, with pre-fetch and the stop word', (tester) async {
    await tester.pumpWidget(_host(ConversationSettingsPanel(value: defaultConversationSettings, onChanged: (_) {})));
    expect(find.text('Stop listening after'), findsOneWidget);
    expect(find.text('Pre-fetch'), findsNothing);
    await tester.pumpWidget(_host(ConversationSettingsPanel(value: defaultConversationSettings.copyWith(wakeWord: true), onChanged: (_) {})));
    expect(find.text('Pre-fetch'), findsOneWidget);
    expect(find.text('Follow-up without the wake word'), findsOneWidget);
    expect(find.text('Wake word stops the agent'), findsOneWidget);
    expect(find.text('Stop listening after'), findsNothing);
    await tester.pumpWidget(
        _host(ConversationSettingsPanel(value: defaultConversationSettings.copyWith(wakeWord: true, interrupt: true), onChanged: (_) {})));
    expect(find.text('Wake word stops the agent'), findsNothing);
  });

  testWidgets('every tap changes only its own setting', (tester) async {
    ConversationSettings? got;
    const base = defaultConversationSettings;
    await tester.pumpWidget(_host(ConversationSettingsPanel(value: base, onChanged: (v) => got = v)));
    Future<void> tap(String key) async {
      await tester.ensureVisible(find.byKey(ValueKey('conversation:$key')));
      await tester.tap(find.byKey(ValueKey('conversation:$key')));
    }

    await tap('Turns:Interrupt');
    expect(got, base.copyWith(interrupt: true));
    await tap('Start each request with:Wake word');
    expect(got, base.copyWith(wakeWord: true));
    await tap('Stop listening after:1 min');
    expect(got, base.copyWith(freeMode: base.freeMode.copyWith(idleMs: 60000)));
    await tap('End of speech:1.5 s');
    expect(got, base.copyWith(freeMode: base.freeMode.copyWith(endOfSpeechMs: 1500)));

    final wake = base.copyWith(wakeWord: true);
    await tester.pumpWidget(_host(ConversationSettingsPanel(value: wake, onChanged: (v) => got = v)));
    await tap('Pre-fetch:Off');
    expect(got, wake.copyWith(wakeWordMode: wake.wakeWordMode.copyWith(preFetchMs: 0)));
    await tap('Follow-up without the wake word:15 s');
    expect(got, wake.copyWith(wakeWordMode: wake.wakeWordMode.copyWith(followUpMs: 15000)));
    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    expect(got, wake.copyWith(wakeWordMode: wake.wakeWordMode.copyWith(stopWord: true)));
  });

  testWidgets('the bar: the gear opens the panel; asleep, a tap wakes the conversation', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(ConversationBar(
      settings: defaultConversationSettings,
      onChanged: (_) {},
      phase: ConversationPhase.asleep,
      wakePhrase: 'Hey Coach',
      onTapToTalk: () => taps++,
    )));
    expect(find.text('Say “Hey Coach” or tap to talk'), findsOneWidget);
    expect(find.text('CONVERSATION'), findsNothing);
    await tester.tap(find.text('Say “Hey Coach” or tap to talk'));
    expect(taps, 1);
    await tester.tap(find.byKey(const ValueKey('conversation:settings')));
    await tester.pump();
    expect(find.text('CONVERSATION'), findsOneWidget);
    expect(find.text('Take turns'), findsOneWidget);
  });
}
