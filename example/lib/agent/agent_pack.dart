import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

// The agent pack: Local AI Chat's behavior as data, in assets/agent/ (the same
// files as the RN example's agent/). agent.json holds the persona, prompt
// templates, web-search rules and filler phrases; each skill folder holds a
// skill's tools, routing rules, messages and data (skills/calories/foods.json).
// The native agent core interprets them (see local_agent.dart); change
// behavior by editing the files. Port of the RN example's src/agent/AgentPack.ts.

typedef Json = Map<String, Object?>;

/// The loaded pack. [loadAgentPack] must run first (main(), or the tests'
/// flutter_test_config.dart).
late AgentPack agentPack;

/// Loads the pack from the app's assets, or with [readFile] (tests).
Future<AgentPack> loadAgentPack({Future<String> Function(String path)? readFile}) async {
  final read = readFile ?? rootBundle.loadString;
  Future<Json> json(String path) async => jsonDecode(await read('assets/agent/$path')) as Json;
  return agentPack = AgentPack(
    agent: await json('agent.json'),
    caloriesSkill: await json('skills/calories/skill.json'),
    caloriesFoods: await json('skills/calories/foods.json'),
  );
}

class AgentPack {
  AgentPack({required this.agent, required this.caloriesSkill, required this.caloriesFoods});

  /// agent/agent.json: persona, prompts, webSearch, onlineToolFillers.
  final Json agent;

  /// agent/skills/calories/skill.json.
  final Json caloriesSkill;

  /// agent/skills/calories/foods.json: {version, foods: [{name, calories}]}.
  final Json caloriesFoods;

  String get systemPrompt => (agent['persona'] as Json)['systemPrompt'] as String;
  Json get prompts => agent['prompts'] as Json;
  Json get webSearch => agent['webSearch'] as Json;
  List<String> get onlineToolFillers => strings(agent['onlineToolFillers']);
}

List<String> strings(Object? list) => [for (final item in list as List) item as String];
