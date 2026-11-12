import 'dart:async';
import 'dart:io';

import 'package:flutter_davoice_llm/flutter_davoice_llm.dart';
import 'package:path_provider/path_provider.dart';

import '../flow/app_language.dart';
import '../local_llm/demo.dart';
import '../speaker_verification/current_speaker.dart';
import 'agent_pack.dart';
import 'remote_assistant.dart';

// Local AI Chat's assistant: the shared native agent core (the same one the RN
// example uses), driven by the agent pack in assets/agent/. It decides when to
// search the web, says fillers while waiting, routes calorie requests to the
// tracker's tools, builds the prompt and runs the model. The calorie log and
// food list live in its SQLite database. Port of the RN example's
// src/agent/LocalAgent.ts.

// The router's sentence-embedding model (all-MiniLM-L6-v2, 25 MB): the agent
// decides what a turn needs (web search, a calorie tool, neither) by comparing
// the user's words with example sentences. Downloaded once; until then the
// router compares words directly.
const _embeddingModelUrl =
    'https://huggingface.co/second-state/All-MiniLM-L6-v2-Embedding-GGUF/resolve/main/all-MiniLM-L6-v2-Q8_0.gguf';

Future<void> _setUpRouterEmbeddings(DavoiceAgent agent, Directory dir) async {
  try {
    final models = Directory('${dir.path}/models');
    final file = File('${models.path}/all-MiniLM-L6-v2-Q8_0.gguf');
    if (!await file.exists()) {
      await models.create(recursive: true);
      final tmp = File('${file.path}.download');
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
      try {
        final response = await (await client.getUrl(Uri.parse(_embeddingModelUrl))).close();
        if (response.statusCode != 200) throw HttpException('HTTP ${response.statusCode}');
        await response.pipe(tmp.openWrite());
      } finally {
        client.close();
      }
      await tmp.rename(file.path);
    }
    await agent.configure({
      'router': {'embeddingModel': file.path},
    });
    // ignore: avoid_print
    print('[DavoiceAgent] router embedding model set');
  } catch (error) {
    // ignore: avoid_print
    print('[DavoiceAgent] router embedding model not available (word overlap is used): $error');
  }
}

class LocalAgent {
  LocalAgent._();

  static Future<DavoiceAgent>? _agent;
  static final _listeners = <void Function(AgentEvent event)>{};
  static Map<String, Object?> _keys = const {};

  /// Web search and food lookup settings from config/local.config.ts:
  /// WEB_SEARCH_ENGINE ('wikipedia' default | 'tavily' | 'brave'), the API
  /// keys, and USDA_API_KEY (USDA FoodData Central before Wikipedia).
  static Future<void> setKeys({
    String? webSearchEngine,
    String? tavilyApiKey,
    String? braveApiKey,
    String? usdaApiKey,
  }) async {
    final usda = usdaApiKey?.trim() ?? '';
    _keys = {
      'webSearch': {
        'engine': webSearchEngine ?? 'wikipedia',
        'tavilyApiKey': ?tavilyApiKey,
        'braveApiKey': ?braveApiKey,
      },
      'skillSettings': {
        'calories': {
          'sources': [
            if (usda.isNotEmpty) {'type': 'usda', 'apiKey': usda},
            {'type': 'wikipedia'},
          ],
        },
      },
    };
    final agent = _agent;
    if (agent != null) await (await agent).configure(_keys);
  }

  /// Tool scopes the app authorizes besides door_locks (none).
  static const _authorizedToolScopes = <String>{};

  /// Doors (unlock_car, open_door): only the enrolled owner's voice, when speaker verification is on. Others: refused.
  static bool _isToolAuthorized(Map<String, Object?> request) {
    if (request['scope'] == 'door_locks') {
      final owner = ownerMayAct();
      // ignore: avoid_print
      print('[DavoiceAgent] authorize ${request['name']} (scope "door_locks"): ${owner.allowed ? 'yes' : 'no'} - ${owner.reason}');
      return owner.allowed;
    }
    final ok = _authorizedToolScopes.contains(request['scope']);
    // ignore: avoid_print
    print('[DavoiceAgent] authorize ${request['name']} (scope "${request['scope']}"): ${ok ? 'yes' : 'no'}');
    return ok;
  }

  /// Closes the agent so the next use creates it with the current demo's pack (a demo switch). The loaded model stays: a new
  /// agent attaches the engine's model when it is created.
  static Future<void> reset() async {
    final pending = _agent;
    _agent = null;
    if (pending == null) return;
    try {
      await (await pending).close();
    } catch (error) {
      // ignore: avoid_print
      print('[LocalAgent] close on demo switch failed: $error');
    }
  }

  /// The app's one agent, created on first use ([loadAgentPacks] must have run): the current demo's pack and language.
  static Future<DavoiceAgent> get() => _agent ??= () async {
        try {
          final dir = await getApplicationSupportDirectory();
          // The car demo (local_llm/demo.dart): the automotive pack, no calorie skill, its own database.
          final car = currentLocalDemo == 'car';
          final lang = currentAppLanguage;
          final db = '${lang == 'en' ? 'davoice_agent' : 'davoice_agent_${lang.replaceAll('-', '_').toLowerCase()}'}${car ? '_car' : ''}';
          final agent = await DavoiceAgent.create({
            'pack': {
              'agent': agentWithReplyLanguage(car ? agentPack.automotive : agentPack.agent),
              'skills': [
                if (!car)
                  {
                    'skill': agentPack.caloriesSkill,
                    'data': {'foods.json': agentPack.caloriesFoods},
                  },
              ],
            },
            'databasePath': '${dir.path}/$db.db',
            // The whole chat (user, model outputs, tools, replies), readable
            // off the phone even when the console drops lines.
            'chatLogPath': '${dir.path}/davoice_chat.log',
            ..._keys,
          }, onEvent: (event) {
            // ignore: avoid_print
            if (event.type == 'log') print('[DavoiceAgent] ${event.json['level']}: ${event.json['message']}');
            for (final listener in [..._listeners]) {
              listener(event);
            }
          }, onRequest: (request) async {
            // The remote assistant (Gemini) for models that hand over to it
            // (see LocalLlmModelConfig.remoteAssistant).
            if (request['type'] == 'remote') return RemoteAssistant.answer(request);
            if (request['type'] == 'authorizeTool') return {'authorized': _isToolAuthorized(request)};
            throw StateError('The app does not answer "${request['type']}" requests.');
          });
          unawaited(_setUpRouterEmbeddings(agent, dir)); // in the background: turns work meanwhile
          return agent;
        } catch (_) {
          _agent = null; // retry on next use
          rethrow;
        }
      }();

  /// Every agent event (e.g. the calorie log's `skill` changes); returns a
  /// function that unsubscribes.
  static void Function() listen(void Function(AgentEvent event) listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }
}
