# Flutter DaVoice Example

The main project README lives at:

[`../README.md`](../README.md)

This `example/` directory contains the runnable Flutter app.

## Android compatibility

This example uses Flutter 3.47 or newer, AGP 9.0.1, Gradle 9.1.0, and
AGP built-in Kotlin. The two Flutter packages also support AGP 8 projects on
older Flutter releases; their minimum Flutter/Dart constraints are unchanged
from the releases before the AGP 9 migration.

The example has `minSdk = 23` and keeps its current `compileSdk`. The
supported API 23 device ABI is `arm64-v8a`.

On API 23–32, STT uses the system recognizer's normal microphone input. Custom
PCM injection/AEC and the inline STT SpeakerID gate are disabled because the
required Android audio-source extras were introduced in API 33. API 33 and
newer retain the existing custom-audio and inline-gate behavior.

Wakeword, standalone SpeakerID, TTS, and TTS2 use API-23-built ARM64 native
libraries. The complete app does not support `armeabi-v7a`, `x86`, or
`x86_64`, because the native TTS dependencies are only available for ARM64.
See [ANDROID_COMPATIBILITY.md](ANDROID_COMPATIBILITY.md) for the package and
runtime contract.

## Local AI Chat: the AI changes the app (tool calling and MCP)

Local AI Chat shows a **Calories today** card that the on-device AI updates by voice, using
flutter_davoice_llm's tool calling. Try:

- "I had two eggs for breakfast", "And a banana", "Log a can of coke"
- "Remove the banana" (deletes that line), "Remove 100 calories", "Set it to 1500", "Undo that"
- "How much have I eaten today?" / "What did I eat today?"
- "How many calories are in an apple?" (a question: answered without touching the tracker)

Every change shows on the card with an **Undo** button. The model extracts the food and
quantity and the app looks up the calories, so "two eggs" is always 156. Foods missing from
the built-in table are looked up on Wikipedia (per 100 g; "I had 200 grams of lentils" uses
the weight). For dishes and brands with real serving sizes, add a free
[USDA FoodData Central](https://fdc.nal.usda.gov/api-key-signup) key; USDA is then tried
first. If no source knows the food, the AI asks how many calories it had. Other sources
plug in through `FoodCalorieSource` (online_foods.dart). The demo's code is
in `lib/calories/` (`calorie_tools.dart` defines the tools, `calorie_store.dart` holds the data, `calories_card.dart` is the card): copy it as a template for your own app's tools.

Optional settings, in the git-ignored `local.config.ts` asset:

```ts
export const MCP_SERVER_URL = 'https://example.com/mcp';  // optional: tools from a remote MCP server
export const MCP_SERVER_TOKEN = '';   // its bearer token, if it needs one
export const USDA_API_KEY = '';       // optional: USDA food lookup
```

## Local AI Chat web search

Local AI Chat runs on the device, so its model only knows facts up to its training. For
time-sensitive questions ("Who is the president of the US?", "latest", "today", news,
prices), the app says a short phrase such as "Well, that is a good question, let me
search.", searches the web, and the on-device model answers from the results. Other
questions never leave the device.

The search engine is replaceable. Choose it in the git-ignored `local.config.ts` asset
(the same file that holds `GEMINI_API_KEY`); every line is optional:

```ts
export const WEB_SEARCH_ENGINE = 'wikipedia'; // default: free, no key. Or 'tavily' / 'brave'.
export const TAVILY_API_KEY = '';             // https://tavily.com (free plan available)
export const BRAVE_API_KEY = '';              // https://brave.com/search/api
```

Wikipedia handles "who currently holds this office" questions well but has no news,
prices or weather; Tavily and Brave are full web search. If the chosen engine fails or
finds nothing, Wikipedia is tried.

To use any other search API, implement `WebSearchEngine` from
`lib/local_llm/web_search.dart`:

```dart
class MySearchEngine implements WebSearchEngine {
  @override
  String get name => 'MySearch';

  @override
  Future<List<WebRagPassage>> search(String query, {required int maxResults}) async {
    // Call your API; return short plain-text passages, most relevant first.
    return [WebRagPassage(text: '...', url: 'https://...')];
  }
}

WebSearch.configure(customEngine: MySearchEngine()); // also: fallbackToWikipedia, maxResults, timeout
```

Which questions trigger a search is decided in `lib/local_llm/needs_web_search.dart`.
