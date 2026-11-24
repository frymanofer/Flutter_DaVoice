// The conversation mode settings (as the React Native apps' src/conversation/ConversationSettingsPanel.tsx): take turns
// or interrupt, wake word or just talk, and each mode's timeouts. The panel edits a draft; Save applies it (the app saves it).
import 'dart:io';

import 'package:flutter/material.dart';

import 'conversation_controller.dart';
import 'conversation_settings.dart';

/// Colours and font of the app the panel sits in (the defaults are a plain dark theme).
class ConversationPanelTheme {
  const ConversationPanelTheme({
    this.text = const Color(0xFFF9FAFB),
    this.text2 = const Color(0xFFAAB2BA),
    this.accent = const Color(0xFF34D399),
    this.selectedBg = const Color(0xFF1C4636),
    this.control = const Color(0xFF26342F),
    this.controlBorder = const Color(0xFF8C9995),
    this.fontFamily,
  });

  final Color text;
  final Color text2;
  final Color accent;
  final Color selectedBg;
  final Color control;
  final Color controlBorder;
  final String? fontFamily;

  TextStyle style(double size, FontWeight weight, Color color) =>
      TextStyle(fontFamily: fontFamily, fontSize: size, fontWeight: weight, color: color);
}

class ConversationSettingsPanel extends StatelessWidget {
  const ConversationSettingsPanel({
    super.key,
    required this.value,
    required this.onChanged,
    this.wakePhrase = 'the wake word',
    this.disabled = false,
    this.theme = const ConversationPanelTheme(),
  });

  final ConversationSettings value;
  final ValueChanged<ConversationSettings> onChanged;
  final String wakePhrase;
  final bool disabled;
  final ConversationPanelTheme theme;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final w = value.wakeWordMode;
    final f = value.freeMode;
    void setWake(WakeWordModeSettings next) => onChanged(value.copyWith(wakeWordMode: next));
    void setFree(FreeModeSettings next) => onChanged(value.copyWith(freeMode: next));
    final label = t.style(14, FontWeight.w700, t.text);
    final caption = t.style(12, FontWeight.w500, t.text2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Turns', style: label),
        const SizedBox(height: 6),
        _Segments(
          theme: t,
          disabled: disabled,
          semantics: 'Turns',
          options: const [('turns', 'Take turns'), ('interrupt', 'Interrupt')],
          selected: value.interrupt ? 'interrupt' : 'turns',
          onSelect: (k) => onChanged(value.copyWith(interrupt: k == 'interrupt')),
        ),
        const SizedBox(height: 6),
        Text(
          value.interrupt
              ? 'Talk over the agent to stop it. Uses echo cancellation (AEC)${Platform.isAndroid ? ', experimental on Android' : ''}.'
              : 'Listening pauses while the agent answers.',
          style: caption,
        ),
        const SizedBox(height: 14),
        Text('Start each request with', style: label),
        const SizedBox(height: 6),
        _Segments(
          theme: t,
          disabled: disabled,
          semantics: 'Start each request with',
          options: const [('wake', 'Wake word'), ('free', 'Just talk')],
          selected: value.wakeWord ? 'wake' : 'free',
          onSelect: (k) => onChanged(value.copyWith(wakeWord: k == 'wake')),
        ),
        const SizedBox(height: 6),
        Text(
          value.wakeWord
              ? 'Say “$wakePhrase” before a request. When the agent asks a question, answer without it.'
              : 'After the first wake word, just talk: no wake word needed.',
          style: caption,
        ),
        if (value.wakeWord) ...[
          _ChoiceRow(theme: t, disabled: disabled, label: 'End of speech', detail: 'Silence that ends your request',
              choices: endOfSpeechChoices, value: w.endOfSpeechMs, onSelect: (v) => setWake(w.copyWith(endOfSpeechMs: v))),
          _ChoiceRow(theme: t, disabled: disabled, label: 'Listen after the wake word', detail: 'Then back to the wake word',
              choices: listenChoices, value: w.listenMs, onSelect: (v) => setWake(w.copyWith(listenMs: v))),
          _ChoiceRow(theme: t, disabled: disabled, label: 'Follow-up without the wake word',
              detail: w.followUpMs > 0 ? 'After a question from the agent, how long it waits for your answer' : 'The wake word before every request, even after a question',
              choices: followUpChoices, value: w.followUpMs, onSelect: (v) => setWake(w.copyWith(followUpMs: v))),
          _ChoiceRow(theme: t, disabled: disabled, label: 'Pre-fetch',
              detail: w.preFetchMs > 0 ? 'Keeps words said right after the wake word' : 'Wait for the recognizer after the wake word',
              choices: preFetchChoices, value: w.preFetchMs, onSelect: (v) => setWake(w.copyWith(preFetchMs: v))),
          if (!value.interrupt) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Wake word stops the agent', style: label),
                      const SizedBox(height: 2),
                      Text('“$wakePhrase” while it talks, then your request', style: caption),
                    ],
                  ),
                ),
                Switch(
                  value: w.stopWord,
                  onChanged: disabled ? null : (v) => setWake(w.copyWith(stopWord: v)),
                  activeTrackColor: t.accent,
                ),
              ],
            ),
          ],
        ] else ...[
          _ChoiceRow(theme: t, disabled: disabled, label: 'End of speech', detail: 'Silence that ends your request',
              choices: endOfSpeechChoices, value: f.endOfSpeechMs, onSelect: (v) => setFree(f.copyWith(endOfSpeechMs: v))),
          _ChoiceRow(theme: t, disabled: disabled, label: 'Stop listening after',
              detail: f.idleMs > 0 ? 'Then say “$wakePhrase” or tap the microphone' : 'Listening stays on',
              choices: idleChoices, value: f.idleMs, onSelect: (v) => setFree(f.copyWith(idleMs: v))),
        ],
      ],
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.theme,
    required this.label,
    required this.detail,
    required this.choices,
    required this.value,
    required this.onSelect,
    required this.disabled,
  });

  final ConversationPanelTheme theme;
  final String label;
  final String detail;
  final List<ConversationChoice> choices;
  final int value;
  final ValueChanged<int> onSelect;
  final bool disabled;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: theme.style(14, FontWeight.w700, theme.text)),
            const SizedBox(height: 6),
            _Segments(
              theme: theme,
              disabled: disabled,
              semantics: label,
              options: [for (final c in choices) ('${c.value}', c.label)],
              selected: '$value',
              onSelect: (k) => onSelect(int.parse(k)),
            ),
            const SizedBox(height: 6),
            Text(detail, style: theme.style(12, FontWeight.w500, theme.text2)),
          ],
        ),
      );
}

class _Segments extends StatelessWidget {
  const _Segments({
    required this.theme,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.disabled,
    required this.semantics,
  });

  final ConversationPanelTheme theme;
  final List<(String, String)> options;
  final String selected;
  final ValueChanged<String> onSelect;
  final bool disabled;
  final String semantics;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (final (i, o) in options.indexed) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Semantics(
                button: true,
                selected: o.$1 == selected,
                label: '$semantics: ${o.$2}',
                excludeSemantics: true,
                child: GestureDetector(
                  key: ValueKey('conversation:$semantics:${o.$2}'),
                  onTap: disabled ? null : () => onSelect(o.$1),
                  child: Opacity(
                    opacity: disabled ? 0.5 : 1,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 40),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: o.$1 == selected ? theme.selectedBg : theme.control,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: o.$1 == selected ? theme.accent : theme.controlBorder,
                          width: o.$1 == selected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        o.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.style(13, o.$1 == selected ? FontWeight.w700 : FontWeight.w500, o.$1 == selected ? theme.text : theme.text2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      );
}

/// The chat screens' microphone line and settings icon (the full example): the gear opens the conversation settings
/// below it. As the React Native apps' src/conversation/ConversationBar.tsx.
/// Cancel and Save under the settings: the panel edits a draft, and nothing changes in the app until Save.
class ConversationSaveRow extends StatelessWidget {
  const ConversationSaveRow({super.key, required this.dirty, required this.onCancel, required this.onSave, required this.theme});
  final bool dirty;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final ConversationPanelTheme theme;

  Widget _button(String label, VoidCallback? onTap, {required bool primary}) => Expanded(
        child: Semantics(
          button: true,
          enabled: onTap != null,
          label: label,
          child: GestureDetector(
            key: ValueKey('conversation:${label.toLowerCase()}'),
            onTap: onTap,
            child: Opacity(
              opacity: onTap == null ? 0.4 : 1,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary ? theme.accent : null,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primary ? theme.accent : theme.controlBorder),
                ),
                child: Text(label, style: theme.style(15, FontWeight.w700, primary ? Colors.black : theme.text)),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _button('Cancel', onCancel, primary: false),
          const SizedBox(width: 10),
          _button('Save', dirty ? onSave : null, primary: true),
        ],
      );
}

class ConversationBar extends StatefulWidget {
  const ConversationBar({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.phase,
    required this.wakePhrase,
    required this.onTapToTalk,
    this.theme = const ConversationPanelTheme(
      text: Colors.white,
      text2: Color(0xA6FFFFFF),
      accent: Color(0xFF34C759),
      selectedBg: Color(0x4034C759),
      control: Color(0x14FFFFFF),
      controlBorder: Color(0x38FFFFFF),
    ),
  });

  final ConversationSettings settings;
  final ValueChanged<ConversationSettings> onChanged;
  final ConversationPhase phase;
  final String wakePhrase;
  final VoidCallback onTapToTalk;
  final ConversationPanelTheme theme;

  @override
  State<ConversationBar> createState() => _ConversationBarState();
}

class _ConversationBarState extends State<ConversationBar> {
  bool _open = false;
  late ConversationSettings _draft = widget.settings;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final asleep = widget.phase == ConversationPhase.asleep;
    final tap = conversationTapEnabled(widget.phase);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: tap,
                  label: asleep ? 'Tap to talk' : widget.phase == ConversationPhase.busy ? 'Stop the agent and talk' : 'Microphone',
                  child: GestureDetector(
                    onTap: tap ? widget.onTapToTalk : null,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: asleep ? t.text2 : t.accent, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(asleep ? Icons.mic_off_rounded : Icons.mic_none_rounded, size: 18, color: asleep ? t.text2 : t.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              conversationHint(widget.phase, widget.wakePhrase, widget.settings.wakeWord),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.style(15, FontWeight.w600, asleep ? t.text2 : t.text),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: 'Conversation settings',
                child: GestureDetector(
                  key: const ValueKey('conversation:settings'),
                  onTap: () => setState(() {
                    _draft = widget.settings;
                    _open = !_open;
                  }),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0x1FFFFFFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _open ? t.accent : const Color(0x38FFFFFF)),
                    ),
                    child: Icon(Icons.settings_rounded, color: t.text, size: 22),
                  ),
                ),
              ),
            ],
          ),
          if (_open) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0x0FFFFFFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x29FFFFFF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('CONVERSATION', style: t.style(11, FontWeight.w700, t.accent).copyWith(letterSpacing: 2)),
                  const SizedBox(height: 8),
                  ConversationSettingsPanel(value: _draft, onChanged: (v) => setState(() => _draft = v), wakePhrase: widget.wakePhrase, theme: t),
                  const SizedBox(height: 12),
                  ConversationSaveRow(
                    dirty: _draft != widget.settings,
                    theme: t,
                    onCancel: () => setState(() => _open = false),
                    onSave: () {
                      widget.onChanged(_draft);
                      setState(() => _open = false);
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
