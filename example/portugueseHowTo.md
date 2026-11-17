# Guia: o app de exemplo DaVoice (Flutter)

> Para desenvolvedores que vão rodar, testar ou copiar partes deste exemplo Flutter (`Flutter_DaVoice/example/`). Última
> atualização: 17/11/2026, `flutter_davoice_llm` 0.0.14 (o núcleo do agente com a Confiança local), `flutter_davoice` 0.0.19,
> `flutter_wake_word` 0.0.55. Os caminhos são relativos a `example/`. A versão em inglês está em `englishHowTo.md`.
>
> O app é a versão Flutter do exemplo React Native da DaVoice: as mesmas telas, os mesmos pacotes do agente, ferramentas do
> carro, modelos no aparelho, estados pré-aquecidos e arquivos de idioma.

> **Situação: modelos de teste, ainda em treinamento.** O modelo da demo do carro, que roda no aparelho ("DaVoice Automotive
> Agent 0.6B", checkpoint `g3c_it3639`, o padrão desde 17/11/2026), é **um modelo de teste, não um produto final**. Num conjunto
> lacrado de 128 frases novas, nunca vistas por ele (rodado uma única vez, português do Brasil e inglês):
> - **86%** dos comandos do carro (92 de 107) terminaram exatamente na ação certa;
> - **2 de 128** turnos executaram uma ação errada, **nenhuma ação oposta** ("abrir" no lugar de "fechar") e **nenhuma ação não
>   suportada**; fala de fundo e fragmentos nunca viraram ação;
> - 6 comandos completos receberam "pode repetir" em vez da ação.
>
> Toda ação do carro é **simulada** (o cartão do carro) e conferida antes de rodar (2.2). A configuração **Confiança local** (2.3)
> pode mandar comandos incertos para um agente remoto. Este exemplo não controla um veículo de verdade.

O app mostra um assistente de voz que roda no aparelho: palavra de ativação, verificação de locutor, reconhecimento de fala (STT),
síntese de fala (TTS) com clonagem de voz, e duas demos de IA no aparelho com ferramentas:
- **Demo do carro:** um carro Volkswagen simulado (vidros, portas, travas, clima, bancos, navegação, rádio, ...);
- **Demo de calorias:** um contador de calorias com memória pessoal.

Pacotes (`pubspec.yaml`):

| Pacote | Para quê |
|---|---|
| `flutter_wake_word` | palavra de ativação + verificação de locutor |
| `flutter_davoice` | STT + TTS, clonagem de voz, filtro de locutor no STT |
| `flutter_davoice_llm` (0.0.14) | o modelo no aparelho, `DavoiceAgent` (um turno completo do assistente), ferramentas, verificações das chamadas, Confiança local |
| `path_provider`, `crypto`, `permission_handler` | arquivos e downloads (conferidos por sha256), permissão do microfone |

---

## 1. Usando o app

### 1.1 Rodar

```bash
cd Flutter_DaVoice/example
flutter pub get
cd ios && pod install && cd ..      # só iOS
flutter run                         # um celular conectado; ou: flutter build apk / flutter build ios
```

- Requisitos: Flutter 3.47 ou mais novo (Dart 3.12). Android `minSdk` 23 (`android/app/build.gradle.kts`).
- O app instala como `com.davoice.flutter_davoice_example`.
- **Licença:** `licensekey.txt` (dentro do app) traz uma chave temporária da DaVoice; o campo de licença no app a substitui. No
  seu app, use a sua chave (info@davoice.io).
- **Chaves opcionais** (Gemini para o modo Full AI Chat, busca na web, consulta de alimentos USDA, um servidor MCP remoto):
  `config/local.config.ts` (ignorado pelo git). Sem ele o app usa o modelo `config/local.config.example.ts`; a demo do carro não
  precisa de nenhuma.
- Logs: `flutter logs`, ou no Android `adb logcat | grep -E "flutter|DavoiceChat"` (`DavoiceChat` = o log do próprio agente: cada
  saída do modelo, verificação e resposta). O mesmo log é gravado em `davoice_chat.log` na pasta de documentos do app.

### 1.2 Fluxo de abertura

1. **Idioma.** Inglês, Português do Brasil, Português de Portugal, alemão, grego, espanhol, francês, italiano, holandês,
   dinamarquês ou sueco. **Inglês e português do Brasil vêm dentro do app**; qualquer outro idioma é baixado na primeira vez que é
   escolhido (o botão mostra "⬇ N MB"; uma tela de download mostra o progresso, com Retry e Back). O idioma define o locale do
   STT, as vozes, o idioma das respostas do agente e o pacote do agente (`assets/agent*/` ou `assets/agent*/pt-BR/`).
2. **Permissão do microfone.** Aceite.
3. **Apresentação falada** (narração, `lib/flow/narration.dart` e `lib/flow/startup_narration.dart`). **Skip Narration** pula.
4. **Voz.** Escolha uma voz pronta, uma voz que você clonou antes, ou clone uma nova (`lib/voice_clone/voice_clone.dart`).
5. **Verificação de locutor** (1.3): crie uma assinatura de voz, use a salva, ou pule.
6. **Palavra de ativação.** Diga **"Hey Coach"** (`assets/models/hey_coach_model_28_22012026b.dm`, a mesma em todos os idiomas).
   Este app não tem botão que substitua a palavra falada.
7. **Choose Mode:**

| Modo | O que faz |
|---|---|
| **Local AI · Car demo** | STT → Agente Automotivo no aparelho → TTS, com o carro simulado |
| **Local AI · Calories demo** | STT → Personal Agent no aparelho → TTS, com o contador de calorias e a memória |
| Full AI Chat | STT → Gemini (nuvem) → TTS; precisa de `GEMINI_API_KEY` |
| Combined STT + TTS | você fala e ouve o texto de volta |
| STT Only | só mostra a transcrição |
| Type to TTS | você digita e o app fala |

8. **A tela de carregamento de uma demo local:** download (o modelo e, na demo do carro, o estado pré-aquecido dele, numa barra
   só), carregamento, aquecimento, com os segundos de cada etapa e Retry / Back em caso de erro. No "Ready" abre a tela de
   conversa.

### 1.3 Verificação de locutor

O app grava uma **assinatura de voz** do dono (5 frases naturais, num lugar silencioso) e a cadastra na palavra de ativação **e**
no STT, então a palavra de ativação só dispara para a voz cadastrada e todo resultado do STT diz quem falou. Com assinatura, as
ferramentas de porta (`open_door`, `unlock_car`, escopo `"door_locks"`) só rodam para o dono verificado
(`lib/speaker_verification/current_speaker.dart`); com a verificação pulada elas rodam (é uma demonstração).

### 1.4 O que dizer (demo do carro)

- **Vidros:** "abre os vidros", "fecha o vidro do carona", "abaixa os vidros de trás" / "open the windows".
- **Clima:** "coloca o ar em vinte e dois", "vinte graus pro carona", "coloca 20 pro motorista e 23 pro passageiro",
  "ventilador no três", "liga o desembaçador" / "set the temperature to 22".
- **Bancos:** "liga o aquecimento do banco do motorista" / "turn on my seat heating".
- **Portas e travas:** "tranca o carro", "abre a porta traseira esquerda" / "lock the car".
- **Mídia e navegação:** "sintoniza noventa e oito ponto cinco", "me leva pra Campinas", "quanto tempo falta?".
- **Dois comandos de uma vez:** "fecha os vidros e tranca o carro". **Desfazer:** "desfaz" / "undo".
- **Continuações:** depois de "abre o vidro do motorista": "agora o do carona", "fecha ele".
- **Incompleto:** "abre um vidro" → "Qual vidro?".
- **Fora do carro** ("me fala do Brasil"): vai para o assistente remoto. Este exemplo não tem um configurado
  (`localLlmLayer2 = 'none'` em `lib/local_llm/model_config.dart`), então o app avisa.

---

## 2. A demo do carro

### 2.1 Modelos e a tela de conversa

- **Modelos** (`lib/local_llm/model_config.dart`): o padrão da demo do carro é o **DaVoice Automotive Agent 0.6B**
  (`localLlmDavoiceAutomotiveG3c`, checkpoint `g3c_it3639`, 382 MB, conferido por sha256), com um estado pré-aquecido em inglês
  ou português do Brasil (cerca de 430 MB), para o primeiro início pular os cerca de 30 segundos de aquecimento. Reservas, usadas
  só quando escolhidas à mão: `r8d_it150` e `r4b_it100`. A demo de calorias usa o Personal Agent `ft7f2_it900`. **Change** abre
  o seletor de modelos; só um modelo fica carregado por vez.
- **Tela de conversa:** o cartão do carro (estado e últimas ações), **You said**, **Reply**, **Model · Change**, **Local
  confidence · Change** (demo do carro), **Reset Chat**, **Back** (para a escolha de modo).

### 2.2 Como um turno funciona

1. **Escopo.** Só comandos de carro diretos chegam ao modelo; perguntas gerais vão para o assistente remoto, fala truncada é
   perguntada de novo, funções do carro sem ferramenta são recusadas, fala de fundo é ignorada (`scope` na entrada do modelo).
2. **O modelo** escreve uma chamada de ferramenta com as ferramentas do carro no prompt
   (`assets/car/carToolDefinitions.h3d.json`, a redação com que ele foi treinado).
3. **Confiança local** (se ligada, 2.3): uma chamada da qual o modelo não tem certeza suficiente nunca roda.
4. **Verificações:** toda chamada é comparada com as palavras do próprio usuário antes de rodar (objeto errado, inversões de
   liga/desliga e abre/fecha, zonas, números não ditos, valores fora da faixa); uma chamada com a ferramenta errada ganha mais uma
   tentativa sem aquela ferramenta, senão o usuário é perguntado. Configuração: `callGuards: 'correct'`, `guardRetry: true`,
   `maxOperations: 2`, `undo: true` na entrada do modelo.
5. **O carro** (`lib/car/car_tools.dart`) executa a ação no carro simulado e diz o que fez; "desfaz" / "undo" volta o estado
   anterior (`lib/car/car_undo.dart`).

### 2.3 Confiança local

**Local confidence · Change** alterna Off (padrão) → 0,80 → 0,90 → 0,95. O valor fica em `local_confidence.json` ao lado do
registro de modelos (`LocalLlmModelStore.localConfidence`) e é enviado ao agente antes do próximo turno
(`configure({'confidence': {'min': valor}})` em `lib/local_llm/local_llm_service.dart`; a demo de calorias sempre envia 0).

Uma chamada de ferramenta cuja probabilidade (o produto das probabilidades dos tokens que o modelo escolheu) fica abaixo do valor
**nunca roda**. O pedido vai para o assistente remoto (motivo `low-confidence`); sem um configurado,
`lib/agent/remote_assistant.dart` responde **"Para esse comando eu preciso de um agente remoto."** / **"For this command I need a
remote agent."**

Medido com o `g3c_it3639` em comandos que ele nunca viu no treinamento:

| Valor | Ações erradas evitadas | Comandos válidos enviados ao agente remoto |
|---|---|---|
| Off (padrão) | 0% | 0% |
| 0,80 | cerca de 40% | cerca de 13% |
| 0,90 | cerca de dois terços | cerca de 20% |
| 0,95 | cerca de 70% | cerca de 27% |

Sozinha ela não chega a zero (algumas chamadas erradas saem com confiança alta). Ela não muda o prompt, então os estados
pré-aquecidos continuam valendo.

### 2.4 O que é baixado

| O quê | Onde | Quando |
|---|---|---|
| Palavra de ativação, verificação de locutor (`sv.dm`), arquivos de voz de inglês e português do Brasil | dentro do app (`assets/models/`) | sempre |
| Modelo de voz + codificador de clonagem de qualquer outro idioma (136–170 MB cada) | R2 `language-packs/<arquivo>` → documentos do app | quando o idioma é escolhido |
| Modelos no aparelho (GGUF, 382 MB cada) | R2 `agent-llm/<arquivo>` → documentos do app `local_llm/models/` | quando a demo abre pela primeira vez |
| Estado pré-aquecido do modelo do carro, inglês ou pt-BR (cerca de 430 MB) | R2 `agent-llm/prewarm/<arquivo>` → ao lado do modelo | junto com o modelo |

R2 = o Cloudflare R2 da DaVoice (`https://pub-27f94b1602c647ab95a601086cf52820.r2.dev`); todo arquivo é conferido por sha256.
Idiomas: `assets/language_packs.json` (`bundled` = os idiomas dentro do app; `lib/tts/language_packs.dart` baixa os outros).
Modelos e estados: `lib/local_llm/model_config.dart` (`url`, `sizeBytes`, `sha256`, `prebuiltStates`).

---

## 3. Onde está o código

| Parte | Arquivos |
|---|---|
| Telas e fluxo (idioma, narração, voz, verificação de locutor, palavra de ativação, modos) | `lib/main.dart`, `lib/flow/` |
| Modelo no aparelho: lista, download, seletor, carregamento, aquecimento, turnos | `lib/local_llm/` |
| O agente, os pacotes dele e a resposta remota | `lib/agent/local_agent.dart`, `lib/agent/agent_pack.dart`, `lib/agent/remote_assistant.dart`, `assets/agent/`, `assets/agent_automotive/` |
| O carro simulado (ferramentas, estado, cartão, desfazer, posições) | `lib/car/`, `assets/car/` |
| Demo de calorias | `lib/calories/` |
| Vozes, estilos, clonagem, pacotes de idioma | `lib/tts/`, `lib/voice_clone/` |
| Estado da verificação de locutor | `lib/speaker_verification/current_speaker.dart` |

Testes: `flutter test` (testes de unidade e de widget em `test/`: ferramentas do carro, desfazer, pacotes de idioma, a lista de
modelos, narração, a transcrição) e `integration_test/` num aparelho.

## Checklist rápido de teste

1. Rode o app (1.1); escolha **Português do Brasil**. Teste também um idioma que não vem no app (por exemplo, francês): a tela de
   download mostra o progresso, e o app só continua quando o download termina.
2. Escolha uma voz; crie a assinatura de voz (5 frases); diga **"Hey Coach"**; escolha **Local AI · Car demo**.
3. Na primeira vez o modelo e o estado pré-aquecido dele são baixados (cerca de 810 MB); depois o "Ready" vem em cerca de um
   segundo.
4. "abre os vidros" → todos os vidros abrem; "fecha eles" → fecham; "desfaz" → voltam. Confira o cartão do carro e se a frase
   falada bate com o que aconteceu.
5. "abre um vidro" → o agente pergunta qual.
6. **Local confidence** → 0,90; os comandos incertos não rodam e o app diz que precisa de um agente remoto; os claros continuam
   rodando.
7. Uma voz diferente **não** deve acordar o assistente nem destrancar o carro.
