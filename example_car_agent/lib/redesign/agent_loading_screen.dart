// Screen 7 · Agent loading (React Native: src/redesign/AgentLoadingScreen.tsx): download the model, load it into memory, warm up.
import 'package:flutter/material.dart';

import 'chrome.dart';
import 'theme.dart';

class LoadingStage {
  const LoadingStage({
    required this.key,
    required this.label,
    required this.detail,
    this.progress,
  });
  final String key;
  final String label;
  final String detail;
  final int? progress;
}

class AgentLoadingScreen extends StatelessWidget {
  const AgentLoadingScreen({
    super.key,
    required this.modelName,
    required this.stages,
    required this.activeIndex,
    required this.seconds,
    required this.error,
    required this.onBack,
    required this.onRetry,
  });
  final String modelName;
  final List<LoadingStage> stages;

  /// Index of the running stage; -1 when it failed.
  final int activeIndex;
  final int seconds;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => PanelScreen(
    large: true,
    traces: false,
    child: Column(
      children: [
        // the stages scroll on a short screen (or with a long error); the buttons stay in view
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Heading(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
                  eyebrow: 'Step 5 of 5',
                  title: 'Starting the car agent',
                  subtitle: modelName.isEmpty ? null : modelName,
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF3A4A44)),
                    color: const Color(0xFF18231F),
                  ),
                  child: Column(
                    children: [for (var i = 0; i < stages.length; i++) _row(i)],
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Text(
                      error!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: inter(13, FontWeight.w500, C.warning2, height: 18),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Footer(
          children: [
            Expanded(
              child: SecondaryButton(label: 'Back', onPressed: onBack),
            ),
            Expanded(
              flex: 2,
              child: error != null
                  ? PrimaryButton(label: 'Retry', onPressed: onRetry)
                  : const PrimaryButton(
                      label: 'Loading…',
                      onPressed: null,
                    ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _row(int i) {
    final stage = stages[i];
    final done = activeIndex > i;
    final active = activeIndex == i;
    final detail = done
        ? 'done'
        : active
        ? [stage.detail, '$seconds s'].where((s) => s.isNotEmpty).join(' · ')
        : stage.detail;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: i < stages.length - 1
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1A2421))),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? C.emerald : null,
              border: done
                  ? null
                  : Border.all(color: active ? C.mint : C.olive, width: 2),
              boxShadow: active
                  ? const [BoxShadow(color: Color(0x9934D399), blurRadius: 10)]
                  : null,
            ),
            child: done
                ? const Icon(Icons.check_rounded, size: 18, color: C.onPrimary)
                : Text(
                    '${i + 1}',
                    style: inter(
                      13,
                      FontWeight.w700,
                      active ? C.mint : C.text2,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stage.label,
                    style: !done && !active
                        ? inter(16, FontWeight.w400, C.text2)
                        : inter(16, FontWeight.w700, Colors.white),
                  ),
                  if (active || done || stage.detail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style:
                          inter(
                            13,
                            FontWeight.w400,
                            active ? C.tag : C.text2,
                          ).copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                  ],
                  if (active && stage.progress != null) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: stage.progress!.clamp(0, 100) / 100,
                        minHeight: 6,
                        backgroundColor: const Color(0xFF1A2421),
                        color: C.mint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
