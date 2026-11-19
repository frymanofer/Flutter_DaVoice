// What the user reads aloud while the voice signature is recorded: one sentence per sample, shown one after the other.
// Same table as the React Native example_car_agent (src/speaker_verification/enrollmentSentences.ts): the wake phrase + a request, a short
// question, a command with a number, another question, one long relaxed sentence; each language's wording includes the sounds that tell
// its speakers apart. `{wake}` is replaced with the wake phrase.

const svOnboardingSampleCount = 5;

const _sentences = <String, List<String>>{
  'en': [
    "{wake}, Please send a message to my friend.",
    "How's the weather going to be today?",
    "Please set a timer for three minutes.",
    "Can you play some music for me?",
    "Every morning, I enjoy a fresh cup of coffee while watching the beautiful sunrise.",
  ],
  'pt-BR': [
    "{wake}, por favor, envie uma mensagem para o meu melhor amigo.",
    "Como vai estar o tempo hoje, será que vai chover?",
    "Por favor, programe um alarme para daqui a três minutos.",
    "Você pode tocar uma música para mim?",
    "Toda manhã, gosto de tomar um café fresquinho enquanto vejo o lindo nascer do sol.",
  ],
  'pt-PT': [
    "{wake}, por favor, envia uma mensagem ao meu melhor amigo.",
    "Como vai estar o tempo hoje, será que vai chover?",
    "Por favor, põe um temporizador de três minutos.",
    "Podes pôr um pouco de música para mim?",
    "Todas as manhãs, gosto de beber um café acabado de fazer enquanto vejo o lindo nascer do sol.",
  ],
  'de': [
    "{wake}, bitte schick meinem Freund eine Nachricht.",
    "Wie wird das Wetter heute Nachmittag?",
    "Bitte stell einen Timer auf drei Minuten.",
    "Kannst du für mich etwas Musik spielen?",
    "Jeden Morgen genieße ich eine frische Tasse Kaffee und schaue mir den wunderschönen Sonnenaufgang an.",
  ],
  'es': [
    "{wake}, por favor, envía un mensaje a mi mejor amigo.",
    "¿Va a llover hoy o hará buen tiempo?",
    "Por favor, pon un temporizador de tres minutos.",
    "¿Puedes poner un poco de música para mí?",
    "Cada mañana disfruto de una taza de café recién hecho mientras veo el hermoso amanecer.",
  ],
  'fr': [
    "{wake}, s'il te plaît, envoie un message à mon ami.",
    "Quel temps va-t-il faire aujourd'hui ?",
    "Mets un minuteur de trois minutes, s'il te plaît.",
    "Peux-tu me jouer un peu de musique ?",
    "Chaque matin, je savoure une bonne tasse de café en regardant le magnifique lever du soleil.",
  ],
  'it': [
    "{wake}, per favore, manda un messaggio al mio migliore amico.",
    "Che tempo farà oggi pomeriggio?",
    "Per favore, imposta un timer di tre minuti.",
    "Puoi mettere un po' di musica per me?",
    "Ogni mattina mi piace bere una tazza di caffè appena fatto mentre guardo la bellissima alba.",
  ],
  'nl': [
    "{wake}, stuur alsjeblieft een bericht naar mijn vriend.",
    "Wat voor weer wordt het vandaag?",
    "Zet alsjeblieft een timer op drie minuten.",
    "Kun je wat muziek voor me afspelen?",
    "Elke ochtend geniet ik van een vers kopje koffie terwijl ik buiten naar de prachtige zonsopgang kijk.",
  ],
  'da': [
    "{wake}, send venligst en besked til min ven.",
    "Hvordan bliver vejret i dag?",
    "Sæt venligst en timer på tre minutter.",
    "Kan du spille noget musik for mig?",
    "Hver morgen nyder jeg en frisk kop kaffe og ser den smukke solopgang over søen.",
  ],
  'sv': [
    "{wake}, skicka ett meddelande till min vän, tack.",
    "Hur blir vädret i dag?",
    "Ställ en timer på tre minuter, tack.",
    "Kan du spela lite musik åt mig?",
    "Varje morgon njuter jag av en nybryggd kopp kaffe medan jag ser den vackra soluppgången över sjön.",
  ],
  'el': [
    "{wake}, στείλε σε παρακαλώ ένα μήνυμα στον φίλο μου.",
    "Τι καιρό θα κάνει σήμερα;",
    "Βάλε σε παρακαλώ ένα χρονόμετρο για τρία λεπτά.",
    "Μπορείς να μου παίξεις λίγη μουσική;",
    "Κάθε πρωί απολαμβάνω ένα φλιτζάνι φρέσκο καφέ, βλέποντας την όμορφη ανατολή του ήλιου δίπλα στη θάλασσα.",
  ],
  'he': [
    "{wake}, בבקשה שלח הודעה לחבר שלי.",
    "מה יהיה מזג האוויר היום?",
    "בבקשה כוון טיימר לשלוש דקות.",
    "אתה יכול לנגן לי קצת מוזיקה?",
    "כל בוקר אני נהנה מכוס קפה טרי בזמן שאני צופה בזריחה היפה.",
  ],
};

/// The sentences to read for the voice signature, in order: one per sample. English when the language is unknown.
List<String> enrollmentSentences(String? language, String wakePhrase) {
  final sentences = _sentences[language] ?? _sentences['en']!;
  return [for (final s in sentences.take(svOnboardingSampleCount)) s.replaceAll('{wake}', wakePhrase)];
}
