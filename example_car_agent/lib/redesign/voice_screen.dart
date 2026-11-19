// Screen 3 · Voice (React Native: src/redesign/VoiceScreen.tsx): clone a new voice, the expressive voices with three style examples, the
// built-in voices, the user's cloned voices, and Continue.
import 'package:flutter/material.dart';

import '../tts/voice_styles.dart';
import 'chrome.dart';
import 'theme.dart';

class ExpressiveVoice {
  const ExpressiveVoice(this.name, this.styles);
  final String name;
  final int styles;
}

class VoiceScreen extends StatelessWidget {
  const VoiceScreen({
    super.key,
    required this.expressive,
    required this.originalVoice,
    required this.builtIn,
    required this.cloned,
    required this.selected,
    required this.examples,
    required this.playingExample,
    required this.busy,
    required this.onSelect,
    required this.onPlayExample,
    required this.onClone,
    required this.onDeleteCloned,
    required this.onContinue,
  });

  /// Voices with emotions / styles, and how many styles each has.
  final List<ExpressiveVoice> expressive;

  /// The v1 model's own voice (fastest), shown first among the built-in ones.
  final String? originalVoice;
  final List<String> builtIn;
  final List<String> cloned;
  final String selected;
  final List<VoiceStyleExample> examples;
  final String? playingExample;
  final bool busy;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onPlayExample;
  final VoidCallback onClone;
  final ValueChanged<String> onDeleteCloned;
  final VoidCallback onContinue;

  static const _on = BoxDecoration(
    color: Color(0xFF1C4636),
    border: Border.fromBorderSide(BorderSide(color: C.mint, width: 2)),
    boxShadow: [BoxShadow(color: Color(0x8C10B981), blurRadius: 14)],
  );
  static const _off = BoxDecoration(
    color: C.tile,
    border: Border.fromBorderSide(BorderSide(color: C.tileBorder)),
    boxShadow: kLift,
  );

  BoxDecoration _tile(bool on, double radius) =>
      (on ? _on : _off).copyWith(borderRadius: BorderRadius.circular(radius));

  Widget _avatar(String name, bool on, double size) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: on ? C.mint : const Color(0xFF26322E),
    ),
    child: Text(
      name.isEmpty ? '?' : name[0].toUpperCase(),
      style: inter(
        size > 34 ? 15 : 13,
        FontWeight.w700,
        on ? C.onPrimary : C.text,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final all = [?originalVoice, ...builtIn];
    final maxStyles = expressive.fold<int>(
      0,
      (m, v) => v.styles > m ? v.styles : m,
    );
    final clonedSelected = cloned.contains(selected);
    return PanelScreen(
      child: Column(
        children: [
          const Heading(eyebrow: 'Step 2 of 5', title: 'Choose Your Voice'),
          // The list scrolls when it is taller than the screen (small phones, many cloned voices); Continue stays in view.
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
              children: [
                Semantics(
                  button: true,
                  label: 'Clone a new voice',
                  child: GestureDetector(
                    onTap: busy ? null : onClone,
                    child: Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: C.mint, width: 1.5),
                        color: C.tile,
                        boxShadow: kLift,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: kPrimaryGradient,
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: C.onPrimary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Clone a new voice',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: inter(
                                    15,
                                    FontWeight.w700,
                                    Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Record ~20 s or upload a file',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: inter(12, FontWeight.w400, C.text2),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: C.mint,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (expressive.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SectionLabel('Expressive · $maxStyles styles'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var i = 0; i < expressive.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => onSelect(expressive[i].name),
                            child: Container(
                              height: 60,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: _tile(
                                expressive[i].name == selected,
                                14,
                              ),
                              child: Row(
                                children: [
                                  _avatar(
                                    expressive[i].name,
                                    expressive[i].name == selected,
                                    36,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          expressive[i].name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: inter(
                                            15,
                                            FontWeight.w700,
                                            Colors.white,
                                          ),
                                        ),
                                        Text(
                                          '${expressive[i].styles} styles',
                                          style: inter(
                                            12,
                                            FontWeight.w400,
                                            C.text2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (examples.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (var i = 0; i < examples.length && i < 3; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(
                            child: Semantics(
                              button: true,
                              label: 'Play example: ${examples[i].label}',
                              child: GestureDetector(
                                onTap: () => onPlayExample(examples[i].text),
                                child: Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: playingExample == examples[i].text
                                          ? C.mint
                                          : C.controlBorder,
                                    ),
                                    color: playingExample == examples[i].text
                                        ? const Color(0x1F10B981)
                                        : C.carbon,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.play_arrow_rounded,
                                        size: 14,
                                        color: C.mint,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          examples[i].label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: inter(
                                            13,
                                            FontWeight.w500,
                                            C.text,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                const SectionLabel('Built-in'),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, box) {
                    final w = (box.maxWidth - 4 * 6) / 5;
                    return Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final name in all)
                          GestureDetector(
                            onTap: () => onSelect(name),
                            child: Container(
                              width: w,
                              height: 76,
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 2,
                              ),
                              decoration: _tile(name == selected, 12),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _avatar(name, name == selected, 32),
                                        const SizedBox(height: 6),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            name,
                                            maxLines: 1,
                                            style: inter(
                                              12,
                                              FontWeight.w600,
                                              C.text,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (name == originalVoice)
                                    Positioned(
                                      top: -6,
                                      right: 2,
                                      child: Text(
                                        'fastest',
                                        style: inter(
                                          8,
                                          FontWeight.w600,
                                          C.mintLight,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SectionLabel('Your cloned voices'),
                    if (clonedSelected)
                      GestureDetector(
                        onTap: () => onDeleteCloned(selected),
                        child: Text(
                          'Delete "$selected"',
                          style: inter(12, FontWeight.w600, C.warning2),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (cloned.isEmpty)
                  Container(
                    height: 44,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1F2B27)),
                    ),
                    child: Text(
                      'None yet — clone one above',
                      style: inter(13, FontWeight.w400, C.text2),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final name in cloned)
                        GestureDetector(
                          onTap: () => onSelect(name),
                          child: Container(
                            height: 44,
                            constraints: const BoxConstraints(minWidth: 64),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.center,
                            decoration: _tile(name == selected, 12),
                            child: Text(
                              name,
                              maxLines: 1,
                              style: inter(13, FontWeight.w600, C.text),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          Footer(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: busy ? 'Preparing…' : 'Continue with $selected',
                  onPressed: busy ? null : onContinue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
