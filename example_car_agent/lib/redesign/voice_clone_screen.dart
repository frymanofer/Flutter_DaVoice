// Step 2 · Clone a new voice (React Native: src/redesign/VoiceCloneScreen.tsx): a name, a sample from the microphone (with the text to read,
// a clock and a level meter) or a file, the voice volume, and the result.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../text_field_menu.dart';
import 'chrome.dart';
import 'theme.dart';

class VoiceCloneScreen extends StatelessWidget {
  const VoiceCloneScreen({
    super.key,
    required this.nameController,
    required this.replaces,
    required this.useMicrophone,
    required this.readingText,
    required this.recommendedSeconds,
    required this.maxSeconds,
    required this.recording,
    required this.recordSeconds,
    required this.recordPeak,
    required this.sample,
    required this.volumePercent,
    required this.minVolumePercent,
    required this.maxVolumePercent,
    required this.busy,
    required this.error,
    required this.resultVoice,
    required this.resultWeak,
    required this.folder,
    required this.scrollController,
    required this.recordButtonKey,
    required this.onNameChanged,
    required this.onChangeSource,
    required this.onToggleRecording,
    required this.onPickFile,
    required this.onPlaySample,
    required this.onVolumeDown,
    required this.onVolumeUp,
    required this.onCreate,
    required this.onListen,
    required this.onUse,
    required this.onBack,
  });
  final TextEditingController nameController;
  /// The cloned voice this name would replace, if any.
  final String? replaces;
  final bool useMicrophone;
  /// The text the user reads aloud into the microphone.
  final String readingText;
  final int recommendedSeconds;
  final int maxSeconds;
  final bool recording;
  final double recordSeconds;
  /// Loudest sample of the recording so far, 0 to 1.
  final double recordPeak;
  /// What was recorded or chosen ("Microphone recording (12.0 s)", a file name).
  final String? sample;
  final int volumePercent;
  final int minVolumePercent;
  final int maxVolumePercent;
  final bool busy;
  final String? error;
  /// The created voice; weak when the recording had little clear speech.
  final String? resultVoice;
  final bool resultWeak;
  final String folder;
  final ScrollController scrollController;
  final GlobalKey recordButtonKey;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<bool> onChangeSource;
  final VoidCallback onToggleRecording;
  final VoidCallback onPickFile;
  final VoidCallback onPlaySample;
  final VoidCallback onVolumeDown;
  final VoidCallback onVolumeUp;
  final VoidCallback onCreate;
  final VoidCallback onListen;
  final VoidCallback onUse;
  final VoidCallback onBack;

  Widget _hint(String text, {Color? color, TextAlign align = TextAlign.start}) =>
      Text(text, textAlign: align, style: inter(13, FontWeight.w400, color ?? C.text2, height: 18));

  Widget _stepper(String label, String a11y, VoidCallback? onTap) => Semantics(
        button: true,
        label: a11y,
        child: GestureDetector(
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? 0.45 : 1,
            child: Container(
              width: 52,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: C.controlBorder), color: C.carbon),
              child: Text(label, style: inter(22, FontWeight.w700, C.text)),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final seconds = recordSeconds.floor();
    final clock = '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    final clipping = recordPeak > 0.97;
    final recordHint = recording
        ? clipping
            ? 'Too loud: move the phone a little further away.'
            : recordSeconds < recommendedSeconds
                ? 'Keep reading: about $recommendedSeconds seconds is best.'
                : 'Good. Stop when you finish the sentence.'
        : 'Recording stops by itself after $maxSeconds seconds.';
    final volumeHint = volumePercent == 100
        ? 'Same loudness as the recording.'
        : '${(volumePercent - 100).abs()}% ${volumePercent > 100 ? 'louder' : 'quieter'} than the recording.';
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    return PanelScreen(
      child: Column(children: [
        Heading(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
          eyebrow: 'Step 2 of 5',
          title: 'Clone a New Voice',
          subtitle: 'One person speaking for about $recommendedSeconds seconds.',
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionLabel('Voice name'),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                contextMenuBuilder: textFieldContextMenu,
                enabled: !busy,
                onChanged: onNameChanged,
                textCapitalization: TextCapitalization.words,
                autocorrect: false,
                inputFormatters: [LengthLimitingTextInputFormatter(30)],
                textInputAction: TextInputAction.done,
                style: inter(16, FontWeight.w500, C.text),
                cursorColor: C.mint,
                decoration: InputDecoration(
                  hintText: 'For example: Dana',
                  hintStyle: inter(16, FontWeight.w400, C.text2),
                  filled: true,
                  fillColor: C.tile,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.tileBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.mint, width: 2)),
                  disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2C3432))),
                ),
              ),
              const SizedBox(height: 6),
              _hint(replaces != null
                  ? 'Replaces your cloned voice "$replaces".'
                  : 'Shown under this name in the voice list. Letters, digits, spaces and dashes.'),
              const SizedBox(height: 18),
              const SectionLabel('Voice sample'),
              const SizedBox(height: 8),
              Row(children: [
                for (final mic in const [true, false]) ...[
                  if (!mic) const SizedBox(width: 10),
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: useMicrophone == mic,
                      child: GestureDetector(
                        onTap: recording || busy ? null : () => onChangeSource(mic),
                        child: Container(
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: useMicrophone == mic ? C.mint : C.controlBorder, width: useMicrophone == mic ? 2 : 1),
                            color: useMicrophone == mic ? const Color(0xFF1C4636) : C.carbon,
                          ),
                          child: Text(mic ? 'Microphone' : 'Upload a file',
                              maxLines: 1, style: inter(14, useMicrophone == mic ? FontWeight.w700 : FontWeight.w600, useMicrophone == mic ? C.text : C.tag)),
                        ),
                      ),
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 12),
              if (useMicrophone) ...[
                _hint('In a quiet room, read this aloud in your natural voice, at a steady distance from the phone:'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: C.mint, width: 1.5),
                    color: C.messageCard,
                    boxShadow: kLift,
                  ),
                  child: Text(readingText, style: inter(17, FontWeight.w600, Colors.white, height: 25)),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  SizedBox(
                    width: 56,
                    child: Text(clock,
                        style: inter(20, FontWeight.w700, recording ? C.mint : C.text).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Container(
                        height: 10,
                        color: const Color(0xFF1A2421),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: recordPeak.clamp(0.0, 1.0),
                          heightFactor: 1,
                          child: ColoredBox(color: clipping ? const Color(0xFFF87171) : C.mint),
                        ),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                _hint(recordHint, color: clipping && recording ? C.warning2 : null),
                const SizedBox(height: 10),
                Semantics(
                  key: recordButtonKey,
                  button: true,
                  child: GestureDetector(
                    onTap: busy ? null : onToggleRecording,
                    child: Opacity(
                      opacity: busy ? 0.5 : 1,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: recording ? C.warning2 : C.controlBorder, width: 1.5),
                          color: C.carbon,
                          boxShadow: kLift,
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(recording ? Icons.stop_rounded : Icons.circle, size: 18, color: recording ? C.warning2 : const Color(0xFFF87171)),
                          const SizedBox(width: 10),
                          Text(recording ? 'Stop recording' : sample != null ? 'Record again' : 'Start recording', style: inter(16, FontWeight.w700, Colors.white)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                _hint('A recording of one person speaking, without music: wav, mp3, m4a, aac, flac or ogg.'),
                const SizedBox(height: 10),
                SecondaryButton(label: sample != null ? 'Choose another file' : 'Choose an audio file', onPressed: busy ? null : onPickFile),
              ],
              if (sample != null && !recording) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('SAMPLE', style: inter(10, FontWeight.w700, C.text2, letterSpacing: 1)),
                      const SizedBox(height: 2),
                      Text(sample!, maxLines: 2, overflow: TextOverflow.ellipsis, style: inter(14, FontWeight.w500, C.text)),
                    ]),
                  ),
                  GestureDetector(
                    onTap: busy ? null : onPlaySample,
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: C.controlBorder), color: C.carbon),
                      child: Row(children: [
                        const Icon(Icons.play_arrow_rounded, size: 16, color: C.mint),
                        const SizedBox(width: 6),
                        Text('Play', style: inter(13, FontWeight.w600, C.text)),
                      ]),
                    ),
                  ),
                ]),
              ],
              const SizedBox(height: 18),
              const SectionLabel('Voice volume'),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _stepper('−', 'Quieter', !busy && volumePercent > minVolumePercent ? onVolumeDown : null),
                SizedBox(
                  width: 84,
                  child: Text('$volumePercent%',
                      textAlign: TextAlign.center,
                      style: inter(20, FontWeight.w800, C.text).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                ),
                _stepper('+', 'Louder', !busy && volumePercent < maxVolumePercent ? onVolumeUp : null),
              ]),
              const SizedBox(height: 6),
              _hint(volumeHint, align: TextAlign.center),
              if (resultVoice != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: C.mint, width: 1.5),
                    color: const Color(0x1F10B981),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('Voice "$resultVoice" is ready', style: inter(16, FontWeight.w700, Colors.white)),
                    if (resultWeak) ...[
                      const SizedBox(height: 6),
                      Text(
                        'The recording has little clear speech, so the voice may not sound its best. For a better voice, record again for about $recommendedSeconds seconds in a quiet room.',
                        style: inter(13, FontWeight.w500, C.warning2, height: 18),
                      ),
                    ],
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: onListen,
                      child: Row(children: [
                        const Icon(Icons.play_arrow_rounded, size: 18, color: C.mint),
                        const SizedBox(width: 6),
                        Text('Listen to it', style: inter(14, FontWeight.w700, C.mint)),
                      ]),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 14),
              Text('Cloned voices folder: $folder', textAlign: TextAlign.center, style: inter(11, FontWeight.w400, const Color(0x73FFFFFF), height: 16)),
            ]),
          ),
        ),
        if (error != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: const Color(0x26F59E0B), border: Border.all(color: C.warning)),
            child: Text(error!, style: inter(13, FontWeight.w500, C.warning2, height: 18)),
          ),
        if (!keyboardOpen)
          Footer(children: [
            BackSquare(onPressed: busy ? null : onBack),
            Expanded(
              child: resultVoice != null
                  ? PrimaryButton(label: 'Use this voice', onPressed: onUse)
                  : PrimaryButton(label: busy ? 'Creating voice…' : 'Create voice', onPressed: busy || recording ? null : onCreate),
            ),
          ]),
      ]),
    );
  }
}
