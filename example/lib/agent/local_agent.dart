import 'dart:async';

import 'package:flutter_davoice_llm/flutter_davoice_llm.dart';
import 'package:path_provider/path_provider.dart';

import 'agent_pack.dart';

// Local AI Chat's assistant: the shared native agent core (the same one the RN
// example uses), driven by the agent pack in assets/agent/. It decides when to
// search the web, says fillers while waiting, routes calorie requests to the
// tracker's tools, builds the prompt and runs the model. The calorie log and
// food list live in its SQLite database. Port of the RN example's
// src/agent/LocalAgent.ts.

class LocalAgent {
  LocalAgent._();

  static Future<DavoiceAgent>? _agent;
  static final _listeners = <void Function(AgentEvent event)>{};
  static Map<String, Object?> _keys = const {};

  /// Web search and food lookup settings from local.config.ts:
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

  /// The app's one agent, created on first use ([loadAgentPack] must have run).
  static Future<DavoiceAgent> get() => _agent ??= () async {
        try {
          final dir = await getApplicationSupportDirectory();
          return await DavoiceAgent.create({
            'pack': {
              'agent': agentPack.agent,
              'skills': [
                {
                  'skill': agentPack.caloriesSkill,
                  'data': {'foods.json': agentPack.caloriesFoods},
                },
              ],
            },
            'databasePath': '${dir.path}/davoice_agent.db',
            ..._keys,
          }, onEvent: (event) {
            // ignore: avoid_print
            if (event.type == 'log') print('[DavoiceAgent] ${event.json['level']}: ${event.json['message']}');
            for (final listener in [..._listeners]) {
              listener(event);
            }
          });
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
