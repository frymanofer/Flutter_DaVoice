// Screen 8 · Car agent, one live car (React Native: src/redesign/CarAgentScreen.tsx): header with Parked / Driving, a status banner, the car
// seen from above with temperatures / fan / fuel / volume / doors beside it, the last message card (what was heard, what ran, the reply,
// outcome + model score), suggestion chips + text input in development builds, and the settings sheet (model, Local confidence).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../car/car_state.dart';
import '../local_llm/confidence.dart';
import 'car_drawing.dart';
import 'chrome.dart';
import 'theme.dart';

const _suggestionsPt = [
  'Abre o vidro do motorista',
  'Tô com frio',
  'Abre o teto',
  'Me leva pra casa',
  'Liga pra Ana',
  'Abre o porta-malas',
  'Coloca o ar em 19',
  'Luz ambiente azul',
  'Abre a porta traseira esquerda',
  'Tranca o carro',
  'Toca Anitta',
  'Quanto tem de combustível?',
  'Desembaça o vidro',
  'Volume 20',
];
const _suggestionsEn = [
  'Open the driver window',
  "I'm cold",
  'Open the sunroof',
  'Take me home',
  'Call Ana',
  'Open the trunk',
  'Set the AC to 19',
  'Ambient light blue',
  'Open the rear left door',
  'Lock the car',
  'Play Anitta',
  'How much fuel do I have?',
  'Defrost the windshield',
  'Volume 20',
];

String _callText(CarAction a) =>
    '${a.tool}(${a.args.entries.map((e) => '${e.key}: ${e.value is String ? e.value : e.value.toString()}').join(', ')})';

(String, String)? _banner(CarState s) {
  if (s.call != null) return ('Calling ${s.call}', 'Phone');
  if (s.destination != null) {
    return (
      '→ ${s.destination}',
      s.avoid.isNotEmpty ? 'avoid ${s.avoid.join(', ')}' : 'Navigation',
    );
  }
  if (s.radio != null) return ('♪ ${s.radio}', 'Radio');
  if (s.media != null) return ('♪ ${s.media}', s.source);
  if (s.scenario != null) {
    return ('${s.scenario!.replaceAll('_', ' ')} mode', '');
  }
  return null;
}

class CarAgentScreen extends StatefulWidget {
  const CarAgentScreen({
    super.key,
    required this.language,
    required this.voice,
    required this.wakePhrase,
    required this.heard,
    required this.reply,
    required this.working,
    required this.ignored,
    required this.modelName,
    required this.localConfidence,
    required this.lastTurn,
    required this.onBack,
    required this.onResetChat,
    required this.onChangeModel,
    required this.onChangeConfidence,
    this.onSendText,
  });
  final String language;
  final String voice;
  final String wakePhrase;
  final String heard;
  final String reply;
  final bool working;
  final bool ignored;
  final String modelName;
  final ConfidenceSettings localConfidence;
  final TurnInfo lastTurn;
  final VoidCallback onBack;
  final VoidCallback onResetChat;
  final VoidCallback onChangeModel;
  final ValueChanged<ConfidenceSettings> onChangeConfidence;

  /// Dev aid: sends text through the same path as a final speech transcript.
  final ValueChanged<String>? onSendText;
  @override
  State<CarAgentScreen> createState() => _CarAgentScreenState();
}

class _CarAgentScreenState extends State<CarAgentScreen> {
  final _text = TextEditingController();
  bool _settingsOpen = false;

  @override
  void initState() {
    super.initState();
    Car.instance.addListener(_carChanged);
  }

  @override
  void dispose() {
    Car.instance.removeListener(_carChanged);
    _text.dispose();
    super.dispose();
  }

  void _carChanged() {
    if (mounted) setState(() {});
  }

  void _send(String value) {
    final t = value.trim();
    if (t.isEmpty || widget.onSendText == null) return;
    FocusScope.of(context).unfocus();
    _text.clear();
    widget.onSendText!(t);
  }

  Widget _stat(
    String label,
    String value, {
    required bool left,
    bool big = false,
    String? unit,
    String? sub,
    Color? color,
  }) => Column(
    crossAxisAlignment: left
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.end,
    children: [
      Text(
        label.toUpperCase(),
        style: inter(10, FontWeight.w700, C.text2, letterSpacing: 1.2),
      ),
      const SizedBox(height: 1),
      Text.rich(
        TextSpan(
          children: [
            TextSpan(text: value),
            if (unit != null)
              TextSpan(text: unit, style: inter(12, FontWeight.w400, C.text2)),
          ],
        ),
        maxLines: 1,
        style: big
            ? inter(
                28,
                FontWeight.w700,
                color ?? C.text,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()])
            : inter(18, FontWeight.w700, color ?? C.text),
      ),
      if (sub != null && sub.isNotEmpty)
        Text(sub, maxLines: 1, style: inter(11, FontWeight.w400, C.text2)),
    ],
  );

  Widget _iconButton(String label, IconData icon, VoidCallback onTap) =>
      Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A3632)),
              color: C.carbon,
            ),
            child: Icon(icon, size: 19, color: C.text),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = widget;
    final s = Car.instance.state;
    final actions = Car.instance.actions;
    final latest = actions.isEmpty ? null : actions.last;
    final pt = p.language == 'pt-BR';
    final sb = MediaQuery.of(context).padding.top;
    final pop = _banner(s);
    final openDoors = s.doors.values.where((d) => d == 'open').length;
    final anyLock = s.doorLocks.values.any((v) => v);
    final doorsLabel = openDoors > 0
        ? '$openDoors open'
        : s.locked
        ? 'Locked'
        : anyLock
        ? 'Part locked'
        : 'Unlocked';
    final blocked = latest != null && !latest.ok;
    final title = p.working
        ? 'Working…'
        : p.ignored
        ? 'Not for me — ignored'
        : latest != null
        ? '${blocked ? 'Blocked: ' : ''}${latest.summary.isEmpty ? '' : latest.summary[0].toUpperCase() + latest.summary.substring(1)}'
        : 'Ready for a command';
    final pool = pt ? _suggestionsPt : _suggestionsEn;
    final k = (actions.length * 3) % pool.length;
    final chips = [for (var i = 0; i < 3; i++) pool[(k + i) % pool.length]];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Material(
        color: C.bg,
        child: Stack(
          children: [
            Column(
              children: [
                // header
                Container(
                  height: 56 + sb,
                  padding: EdgeInsets.only(top: sb, left: 10, right: 10),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: C.mint)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x2E10B981),
                        offset: Offset(0, 4),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      const Positioned.fill(child: CarbonFill()),
                      Row(
                        children: [
                          Semantics(
                            button: true,
                            label: 'Back',
                            child: GestureDetector(
                              onTap: p.onBack,
                              child: const SizedBox(
                                width: 44,
                                height: 44,
                                child: Icon(
                                  Icons.chevron_left_rounded,
                                  color: C.text,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x8034D399),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Image.asset(kEmblem, width: 32, height: 32),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Car Agent',
                                  style: inter(15, FontWeight.w700, C.text),
                                ),
                                Text(
                                  'On-device',
                                  style: inter(11, FontWeight.w400, C.text2),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF2A3632),
                              ),
                              color: C.carbon,
                            ),
                            child: Row(
                              children: [
                                for (final driving in const [false, true])
                                  Semantics(
                                    inMutuallyExclusiveGroup: true,
                                    checked: s.driving == driving,
                                    button: true,
                                    child: GestureDetector(
                                      onTap: () =>
                                          Car.instance.setDriving(driving),
                                      child: Container(
                                        height: 38,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 11,
                                        ),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            9,
                                          ),
                                          color: s.driving == driving
                                              ? C.emerald
                                              : null,
                                        ),
                                        child: Text(
                                          driving ? 'Driving' : 'Parked',
                                          style: inter(
                                            13,
                                            FontWeight.w600,
                                            s.driving == driving
                                                ? C.onPrimary
                                                : C.tag,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // status banner, reset, settings
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: SizedBox(
                    height: 44,
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            liveRegion: true,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: pop != null
                                      ? C.mint
                                      : const Color(0xFF34423D),
                                ),
                                color: pop != null
                                    ? const Color(0x1F10B981)
                                    : const Color(0xFF141C19),
                                boxShadow: pop != null
                                    ? const [
                                        BoxShadow(
                                          color: Color(0x4D10B981),
                                          blurRadius: 12,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: pop != null ? C.mint : C.titanium,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      pop?.$1 ??
                                          '${s.driving ? 'Driving' : 'Parked'} · all on-device',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: inter(13, FontWeight.w600, C.text),
                                    ),
                                  ),
                                  if (pop != null && pop.$2.isNotEmpty)
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 120,
                                      ),
                                      child: Text(
                                        pop.$2,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: inter(
                                          12,
                                          FontWeight.w400,
                                          C.text2,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _iconButton(
                          'Reset car and chat',
                          Icons.refresh_rounded,
                          () {
                            Car.instance.reset();
                            p.onResetChat();
                          },
                        ),
                        const SizedBox(width: 8),
                        _iconButton(
                          'Settings: model and local confidence',
                          Icons.tune_rounded,
                          () => setState(() => _settingsOpen = true),
                        ),
                      ],
                    ),
                  ),
                ),
                // the car and the stats beside it
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        colors: [Color(0xFF0C1512), Color(0x00060908)],
                        stops: [0, 0.7],
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final sideW = box.maxWidth * 0.2 < 76
                            ? 76.0
                            : box.maxWidth * 0.2;
                        final carW = (box.maxHeight * kCarAspect).clamp(
                          0.0,
                          (box.maxWidth - 2 * sideW).clamp(
                            0.0,
                            double.infinity,
                          ),
                        );
                        return Stack(
                          children: [
                            Positioned(
                              left: 10,
                              top: 24,
                              width: sideW,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _stat(
                                    'Driver',
                                    '${s.temperature['driver']}°',
                                    left: true,
                                    big: true,
                                  ),
                                  const SizedBox(height: 18),
                                  _stat(
                                    'Fan',
                                    '${s.fan}',
                                    unit: ' / 7',
                                    left: true,
                                  ),
                                  const SizedBox(height: 18),
                                  _stat(
                                    'Fuel',
                                    '${s.fuelPercent}%',
                                    left: true,
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              right: 10,
                              top: 24,
                              width: sideW,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _stat(
                                    'Passenger',
                                    '${s.temperature['passenger']}°',
                                    left: false,
                                    big: true,
                                  ),
                                  const SizedBox(height: 18),
                                  _stat(
                                    'Volume',
                                    s.muted ? 'Muted' : '${s.volume}',
                                    sub: s.radio != null ? 'Radio' : s.source,
                                    left: false,
                                  ),
                                  const SizedBox(height: 18),
                                  _stat(
                                    'Doors',
                                    doorsLabel,
                                    color: openDoors > 0 || s.locked
                                        ? C.mint
                                        : null,
                                    left: false,
                                  ),
                                ],
                              ),
                            ),
                            if (carW > 0)
                              Center(
                                child: CarDrawing(
                                  state: s,
                                  latest: latest,
                                  width: carW,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                // the last message
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  constraints: const BoxConstraints(minHeight: 96),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 9,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: blocked
                          ? const Color(0xCCF59E0B)
                          : latest != null || p.heard.isNotEmpty
                          ? C.mint
                          : const Color(0xFF1F2B27),
                      width: 1.5,
                    ),
                    color: C.messageCard,
                    boxShadow: kLift,
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'You: '),
                              TextSpan(
                                text: p.heard.isNotEmpty ? '“${p.heard}”' : '—',
                                style: inter(13, FontWeight.w500, C.text),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: inter(13, FontWeight.w400, C.tag),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: inter(
                            17,
                            FontWeight.w800,
                            blocked && !p.working ? C.warning2 : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          latest != null
                              ? _callText(latest)
                              : 'Say “${p.wakePhrase}”, then speak',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: C.tag,
                          ),
                        ),
                        if (p.reply.isNotEmpty && !p.ignored) ...[
                          const SizedBox(height: 3),
                          Text(
                            '${p.voice}: ${p.reply}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: inter(
                              14,
                              FontWeight.w500,
                              const Color(0xFFA7F3D0),
                              height: 19,
                            ),
                          ),
                        ],
                        if (!p.working && p.lastTurn.outcome != null) ...[
                          const SizedBox(height: 3),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: outcomeLabels[p.lastTurn.outcome] ?? '',
                                  style: inter(
                                    12,
                                    FontWeight.w700,
                                    p.lastTurn.outcome == 'executed'
                                        ? C.mint
                                        : C.warning2,
                                  ),
                                ),
                                if (p.lastTurn.low)
                                  const TextSpan(
                                    text: ' · held back by Local confidence',
                                  ),
                                if (p.lastTurn.score.isNotEmpty)
                                  TextSpan(text: ' · ${p.lastTurn.score}'),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: inter(12, FontWeight.w500, C.text2),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // dev: chips + typed input; release: the voice hint
                if (p.onSendText != null && kDebugMode)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      8,
                      12,
                      16 + MediaQuery.of(context).padding.bottom,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            for (var i = 0; i < chips.length; i++) ...[
                              if (i > 0) const SizedBox(width: 6),
                              Expanded(
                                child: GestureDetector(
                                  onTap: p.working
                                      ? null
                                      : () => _send(chips[i]),
                                  child: Container(
                                    height: 40,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: C.tileBorder),
                                      color: C.carbon,
                                    ),
                                    child: Text(
                                      chips[i],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: inter(
                                        12,
                                        FontWeight.w600,
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 56,
                          padding: const EdgeInsets.only(left: 14, right: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: C.mint, width: 1.5),
                            color: const Color(0xFF1A2622),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x6610B981),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.mic_none_rounded,
                                color: C.mint,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _text,
                                  enabled: !p.working,
                                  onSubmitted: _send,
                                  textInputAction: TextInputAction.send,
                                  style: inter(15, FontWeight.w400, C.text),
                                  cursorColor: C.mint,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    hintText: 'What the driver says…',
                                    hintStyle: inter(
                                      15,
                                      FontWeight.w400,
                                      C.text2,
                                    ),
                                  ),
                                ),
                              ),
                              Semantics(
                                button: true,
                                label: 'Send',
                                child: GestureDetector(
                                  onTap: () => _send(_text.text),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: kPrimaryGradient,
                                    ),
                                    child: const Icon(
                                      Icons.arrow_forward_rounded,
                                      color: C.onPrimary,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    margin: EdgeInsets.fromLTRB(
                      12,
                      8,
                      12,
                      16 + MediaQuery.of(context).padding.bottom,
                    ),
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: C.mint, width: 1.5),
                      color: const Color(0xFF1A2622),
                      boxShadow: const [
                        BoxShadow(color: Color(0x6610B981), blurRadius: 16),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.mic_none_rounded,
                          color: C.mint,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Say “${p.wakePhrase}”, then speak',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: inter(15, FontWeight.w500, C.tag),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (_settingsOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _settingsOpen = false),
                  child: ColoredBox(
                    color: const Color(0x73000000),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(12, sb + 112, 12, 12),
                        child: GestureDetector(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: C.titanium),
                              color: C.panel,
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x99000000),
                                  offset: Offset(0, 12),
                                  blurRadius: 30,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'SETTINGS',
                                  style: inter(
                                    11,
                                    FontWeight.w700,
                                    C.mint,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Model',
                                            style: inter(
                                              14,
                                              FontWeight.w600,
                                              C.text,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            p.modelName.isEmpty
                                                ? '…'
                                                : p.modelName,
                                            maxLines: 2,
                                            style: inter(
                                              12,
                                              FontWeight.w400,
                                              C.text2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: p.working
                                          ? null
                                          : () {
                                              setState(
                                                () => _settingsOpen = false,
                                              );
                                              p.onChangeModel();
                                            },
                                      child: Opacity(
                                        opacity: p.working ? 0.5 : 1,
                                        child: Container(
                                          height: 44,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                          ),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: const Color(0x8034D399),
                                            ),
                                          ),
                                          child: Text(
                                            'Change',
                                            style: inter(
                                              14,
                                              FontWeight.w600,
                                              C.mint,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ConfidenceControls(
                                  value: p.localConfidence,
                                  onChanged: p.onChangeConfidence,
                                  disabled: p.working,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
