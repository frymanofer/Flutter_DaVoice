// The two Local AI Chat demos (port of the RN example's src/local_llm/demo.ts): each loads its own agent pack (system prompt +
// skills), tool registry, card and model.
//   calories  DaVoice Personal Agent: the calorie tracker skill + memory, no car tools (assets/agent/)
//   car       DaVoice Automotive Agent: the simulated VW car's tools, no calorie skill (assets/agent_automotive/, the pack the
//             automotive model is trained with)
// The choice is persisted with the model registry (model_store.dart); this holds the current value for synchronous readers.
const localDemos = ['calories', 'car'];

String _current = 'car';

String get currentLocalDemo => _current;

void setCurrentLocalDemo(String demo) {
  _current = localDemos.contains(demo) ? demo : 'car';
}
