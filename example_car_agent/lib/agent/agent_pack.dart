import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../flow/app_language.dart';

// The agent packs: Local AI Chat's behavior as data (the same files as the RN example's agent/ and agent_automotive/). agent.json
// holds the persona, prompt templates, web-search rules and filler phrases; each skill folder holds a skill's tools, routing
// rules, messages and data. The native agent core interprets them (see local_agent.dart). Port of src/agent/AgentPack.ts.
//   assets/agent/[pt-BR/]             the calories demo (Personal Agent): agent.json + skills/calories/
//   assets/agent_automotive/[pt-BR/]  the car demo (Automotive Agent): agent.json, no calorie skill - the system prompt the
//                                     automotive model is trained with

typedef Json = Map<String, Object?>;

class AgentPack {
  AgentPack({required this.agent, required this.caloriesSkill, required this.caloriesFoods, required this.automotive});

  /// agent.json: persona, prompts, webSearch, onlineToolFillers.
  final Json agent;
  final Json caloriesSkill;

  /// skills/calories/foods.json: {version, foods: [{name, calories}]}.
  final Json caloriesFoods;

  /// agent_automotive/agent.json (the car demo's pack).
  final Json automotive;

  String get systemPrompt => (agent['persona'] as Json)['systemPrompt'] as String;
  Json get prompts => agent['prompts'] as Json;
  Json get webSearch => agent['webSearch'] as Json;
  List<String> get onlineToolFillers => strings(agent['onlineToolFillers']);
}

final Map<String, AgentPack> _packs = {};

/// The pack of the app's language (English for a language without its own pack).
AgentPack get agentPack => _packs[currentAppLanguage] ?? _packs['en']!;

/// Loads the packs from the app's assets, or with [readFile] (tests).
Future<void> loadAgentPacks({Future<String> Function(String path)? readFile}) async {
  final read = readFile ?? rootBundle.loadString;
  Future<Json> json(String path) async => jsonDecode(await read(path)) as Json;
  // Translated packs exist for English and pt-BR (as the RN example's AgentPack.ts); every other language uses the English pack
  // with its own reply instruction (agentWithReplyLanguage).
  for (final lang in const ['en', 'pt-BR']) {
    final dir = lang == 'en' ? '' : '$lang/';
    _packs[lang] = AgentPack(
      agent: await json('assets/agent/${dir}agent.json'),
      caloriesSkill: await json('assets/agent/${dir}skills/calories/skill.json'),
      caloriesFoods: await json('assets/agent/${dir}skills/calories/foods.json'),
      automotive: await json('assets/agent_automotive/${dir}agent.json'),
    );
  }
}

/// [agent] with the language's reply instruction ending the persona, so it is part of the cached system prompt and the same in
/// every turn and prefill.
Json agentWithReplyLanguage(Json agent) => {
      ...agent,
      'persona': {
        ...agent['persona'] as Json,
        'systemPrompt': '${(agent['persona'] as Json)['systemPrompt']} ${llmReplyInstructionFor(currentAppLanguage)}'.trim(),
      },
    };

List<String> strings(Object? list) => [for (final item in list as List) item as String];
