// How the car agent answers GENERAL questions ("who is the president of the US", "tell me a joke", "quem é o presidente do Brasil").
// Same setting as the React Native example_car_agent's general_questions.config.ts. The car model never acts on these questions (the
// command scope sends them away before any car decision): this setting changes only what the driver hears. Change it and restart.
//
//   'gemini'   (a) The cloud assistant (Gemini; GEMINI_API_KEY in config/local.config.ts). The question leaves the phone; text-only answers,
//                  never a car action. Without a key it behaves like 'message'.
//   'message'  (b) No remote assistant: the driver hears generalQuestionsMessage.
//   'local'    (c) No remote assistant: the question is looked up on Wikipedia, then the car model on the phone answers from the page,
//                  after generalQuestionsLocalIntro (no second model, no tools). Needs flutter_davoice_llm with the agent core of
//                  2026-11-19 or later; an older one behaves like 'message'.

const generalQuestionsMode = 'message'; // 'gemini' | 'message' | 'local'

/// (b) What the driver hears when there is no remote assistant.
const generalQuestionsMessage = {
  'en':
      "General questions go to a remote assistant, which isn't set up in this demo. I can help you with the car.",
  'pt-BR':
      'Perguntas gerais vão para um assistente remoto, que não está configurado nesta demonstração. Posso te ajudar com o carro.',
};

/// (c) Said before the car model's own attempt, when it has no answer, and before Wikipedia's own sentences.
const generalQuestionsLocalIntro = {
  'en': "There's no online assistant set up here, but let me try.",
  'pt-BR': 'Não tem um assistente online configurado aqui, mas deixa eu tentar.',
};
const generalQuestionsLocalNoAnswer = {
  'en': "I'm not sure about that one.",
  'pt-BR': 'Não tenho certeza sobre isso.',
};
const generalQuestionsSourceLead = {
  'en': 'Here is what Wikipedia says:',
  'pt-BR': 'Segundo a Wikipédia:',
};
