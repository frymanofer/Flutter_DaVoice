# DaVoice Car — Flutter

The on-device **Automotive Agent** demo in Flutter: the same app as the React Native `example_car_agent`, with the same screens,
flow and car. A simulated car is controlled by voice. Speech recognition, the wake word, speaker verification, voice cloning,
text-to-speech and the agent model all run on the phone. Nothing controls a real vehicle.

The main project README lives at [`../README.md`](../README.md); the general Flutter example (all modes, the calories demo) is in
[`../example`](../example).

## Run it

```bash
git lfs pull          # the voice models are stored with Git LFS
flutter pub get
flutter run           # or: flutter build apk --release
```

Optional: your own keys (Gemini for general questions, web search) go in `config/local.config.ts`. Copy
`config/local.config.example.ts`, fill it in, and never commit it (it is git-ignored).

## The flow

1. **Language, "under the hood":** pick a language in the module rack. Brazilian Portuguese is the default; English and
   pt-BR are built in.
2. **Install:** a speedometer shows the download of a language that is not built in.
3. **Voice:** a built-in voice, an expressive voice (with style examples), or clone your own.
4. **Isolate your voice:** record a short voice signature (five sentences, read aloud) so the agent answers only you, then
   test it. Or skip and answer any voice.
5. **Wake word:** say "Hey Coach".
6. **Starting the car agent:** the first start downloads, loads and warms up the on-device model.
7. **The car agent:** the car seen from above (doors, windows, sunroof, trunk, seats, lights and climate change as you speak),
   what was heard, what ran, the reply, the outcome and the model's score. The settings sheet has the model and **Local
   confidence** (on / off, threshold 0–1 in 0.05 steps, below it: Clarify, Remote or Decline). In debug builds, suggestion chips
   and a text field send commands without speaking.

## Settings in code

- `lib/general_questions_config.dart`: how general questions ("who is the president…") are answered: `'gemini'` (the cloud
  assistant), `'message'` (say a remote assistant is needed) or `'local'` (look it up on Wikipedia and let the phone's model try;
  needs an agent core from 2026-11-19 or later).
- `assets/agent_automotive/`: the car agent's pack (fixed replies, prompts, routing), the same files as the React Native app.
- `assets/stt_bias_conf/`: car words that help speech recognition.

## Where things are

| Folder | What |
|---|---|
| `lib/redesign/` | the screens ("VW Emerald" design): theme, header and panel, language, install, voice, speaker isolation, wake word, agent loading, car agent, the car drawing |
| `lib/car/` | the simulated car, its tools, undo, and the speech composer (several actions said as one sentence) |
| `lib/local_llm/` | the on-device model: download, load, warm-up, Local confidence |
| `lib/agent/` | the agent pack and the remote assistant |
| `assets/fonts/` | Inter (SIL Open Font License) |
