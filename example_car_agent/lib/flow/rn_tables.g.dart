// GENERATED from the React Native example (example/src: appflow.ts, narration.ts, tts/voiceClone.ts, tts/voiceStyles.ts,
// aichat/fragments.ts, local_llm/constants.ts) by the RN->Flutter table sync. Do not edit by hand: change the RN source and
// regenerate, so both apps say exactly the same.

/// The text read aloud while recording a voice to clone (about 10 seconds), per language.
const voiceCloneReadingTexts = {
  'en': 'Hello! This is my voice. I am recording a short sample so that my assistant can speak just like me. Today is a good day to try something new.',
  'pt-BR': 'Olá! Esta é a minha voz. Estou gravando uma amostra curta para que meu assistente possa falar como eu. Hoje é um bom dia para experimentar algo novo.',
  'pt-PT': 'Olá! Esta é a minha voz. Estou a gravar uma pequena amostra para que o meu assistente possa falar como eu. Hoje é um bom dia para experimentar algo novo.',
  'de': 'Hallo! Das ist meine Stimme. Ich nehme eine kurze Probe auf, damit mein Assistent wie ich sprechen kann. Heute ist ein guter Tag, um etwas Neues auszuprobieren.',
  'el': 'Γεια σας! Αυτή είναι η φωνή μου. Ηχογραφώ ένα σύντομο δείγμα ώστε ο βοηθός μου να μπορεί να μιλάει όπως εγώ. Σήμερα είναι μια καλή μέρα για να δοκιμάσω κάτι καινούργιο.',
  'es': '¡Hola! Esta es mi voz. Estoy grabando una muestra breve para que mi asistente pueda hablar como yo. Hoy es un buen día para probar algo nuevo.',
  'fr': 'Bonjour ! Voici ma voix. J’enregistre un court échantillon pour que mon assistant puisse parler comme moi. C’est une bonne journée pour essayer quelque chose de nouveau.',
  'it': 'Ciao! Questa è la mia voce. Sto registrando un breve campione affinché il mio assistente possa parlare come me. Oggi è un buon giorno per provare qualcosa di nuovo.',
  'nl': 'Hallo! Dit is mijn stem. Ik neem een kort fragment op zodat mijn assistent net als ik kan spreken. Vandaag is een goede dag om iets nieuws te proberen.',
  'he': 'שלום! זה הקול שלי. אני מקליט דוגמה קצרה כדי שהעוזר שלי יוכל לדבר בדיוק כמוני. היום הוא יום טוב לנסות משהו חדש.',
  'da': 'Hej! Det her er min stemme. Jeg optager en kort prøve, så min assistent kan tale ligesom mig. I dag er en god dag til at prøve noget nyt.',
  'sv': 'Hej! Det här är min röst. Jag spelar in ett kort prov så att min assistent kan prata precis som jag. I dag är en bra dag att prova något nytt.',
};

/// "Didn't catch that" for speech noise, per language (English for the others).
const didNotCatchTexts = {
  'en': 'Sorry, I didn\'t catch that. Could you say it again?',
  'pt-BR': 'Desculpe, não entendi o que você disse. Pode repetir, por favor?',
  'pt-PT': 'Desculpe, não percebi. Pode repetir?',
};

/// What the car demo says for a request this demo can't do, per language (English for the others).
const notInDemoTexts = {
  'en': 'This is not available in this demo, to make it available please contact info@davoice.io',
  'pt-BR': 'Isso não está disponível nesta demonstração. Para disponibilizar, entre em contato com info@davoice.io',
  'pt-PT': 'Isto não está disponível nesta demonstração. Para o disponibilizar, contacte info@davoice.io',
  'he': 'זה לא זמין בהדגמה הזאת. כדי לקבל את זה, צרו איתנו קשר בכתובת info@davoice.io',
  'da': 'Det er ikke tilgængeligt i denne demo. Kontakt info@davoice.io for at få det.',
  'sv': 'Det är inte tillgängligt i den här demon. Kontakta info@davoice.io för att få det.',
  'el': 'Αυτό δεν είναι διαθέσιμο σε αυτή την επίδειξη. Για να το αποκτήσετε, επικοινωνήστε με το info@davoice.io.',
};

/// What the agent says for a handed-over request when no remote model is set up, per language (English for the others).
const noRemoteTexts = {
  'en': 'I need to send this to a remote Model. To make this work, please setup a remote model in the App.',
  'pt-BR': 'Preciso enviar isso para um modelo remoto. Para isso funcionar, configure um modelo remoto no aplicativo.',
  'pt-PT': 'Preciso de enviar isto para um modelo remoto. Para isto funcionar, configure um modelo remoto na aplicação.',
  'he': 'אני צריך לשלוח את זה למודל מרוחק. כדי שזה יעבוד, הגדירו מודל מרוחק באפליקציה.',
  'da': 'Jeg skal sende det her til en ekstern model. Konfigurer en ekstern model i appen, så det virker.',
  'sv': 'Jag behöver skicka det här till en fjärrmodell. Ställ in en fjärrmodell i appen så att det fungerar.',
  'el': 'Πρέπει να το στείλω σε ένα απομακρυσμένο μοντέλο. Για να λειτουργήσει, ρυθμίστε ένα απομακρυσμένο μοντέλο στην εφαρμογή.',
};

/// The voice-style tag hint shown on the style screen, per language.
const styleTagHints = {
  'en': 'Put a tag in square brackets before the words it applies to, e.g. [happy] Hello! or [whispering] Listen. [regular] goes back to the normal voice.',
  'pt-BR': 'Coloque uma etiqueta entre colchetes antes das palavras, por exemplo [feliz] Olá! ou [sussurrando] Escute. [normal] volta à voz normal.',
  'pt-PT': 'Coloca uma etiqueta entre parênteses retos antes das palavras, por exemplo [feliz] Olá! ou [a sussurrar] Ouve. [normal] volta à voz normal.',
  'de': 'Setze ein Tag in eckigen Klammern vor die Wörter, zum Beispiel [fröhlich] Hallo! Mit [normal] kehrst du zur normalen Stimme zurück.',
  'es': 'Pon una etiqueta entre corchetes antes de las palabras, por ejemplo [feliz] ¡Hola! [normal] vuelve a la voz normal.',
  'fr': 'Placez une balise entre crochets avant les mots, par exemple [joyeux] Bonjour ! [normal] revient à la voix normale.',
  'it': 'Inserisci un tag tra parentesi quadre prima delle parole, ad esempio [felice] Ciao! [normale] torna alla voce normale.',
  'nl': 'Zet een tag tussen vierkante haakjes voor de woorden, bijvoorbeeld [vrolijk] Hallo! [normaal] keert terug naar de normale stem.',
  'he': 'שימו תגית בסוגריים מרובעים לפני המילים, למשל [happy] שלום! [regular] מחזיר לקול הרגיל.',
  'da': 'Sæt et mærke i firkantede parenteser foran ordene, f.eks. [happy] Hej! [regular] går tilbage til den normale stemme.',
  'sv': 'Sätt en tagg inom hakparenteser före orden, t.ex. [happy] Hej! [regular] återgår till den vanliga rösten.',
  'el': 'Βάλτε μια ετικέτα σε αγκύλες πριν από τις λέξεις, π.χ. [happy] Γεια σας! Το [regular] επαναφέρει την κανονική φωνή.',
};

/// One example per known style ability, per language: (label, text).
const Map<String, Map<String, (String, String)>> styleExamplesByAbility = {
  'whisper': {
    'en': ('Whisper', '[whispering confidentially] Quiet, this is a secret! Do not tell anyone!'),
    'pt-BR': ('Sussurro', '[sussurrando em segredo] Silêncio, isso é um segredo! Não conte para ninguém!'),
    'pt-PT': ('Sussurro', '[a sussurrar em segredo] Silêncio, isto é um segredo! Não contes a ninguém!'),
    'de': ('Flüstern', '[vertraulich flüsternd] Leise, das ist ein Geheimnis! Sag es niemandem!'),
    'es': ('Susurro', '[susurrando confidencialmente] Silencio, ¡esto es un secreto! ¡No se lo digas a nadie!'),
    'fr': ('Murmure', '[murmurant confidentiellement] Chut, c’est un secret ! Ne le dis à personne !'),
    'it': ('Sussurro', '[sussurrando in confidenza] Piano, è un segreto! Non dirlo a nessuno!'),
    'nl': ('Fluisteren', '[vertrouwelijk fluisterend] Stil, dit is een geheim! Vertel het aan niemand!'),
  },
  'soft_whisper': {
    'en': ('Soft whisper', '[soft gentle whisper] Close your eyes and rest. Everything is going to be fine.'),
    'pt-BR': ('Sussurro suave', '[sussurro suave e terno] Feche os olhos e descanse. Vai ficar tudo bem.'),
    'pt-PT': ('Sussurro suave', '[sussurro suave e terno] Fecha os olhos e descansa. Vai correr tudo bem.'),
    'de': ('Sanftes Flüstern', '[sanft und beruhigend flüsternd] Schließe die Augen und ruhe dich aus. Alles wird gut.'),
    'es': ('Susurro suave', '[susurro suave y tierno] Cierra los ojos y descansa. Todo va a estar bien.'),
    'fr': ('Murmure doux', '[murmure doux et tendre] Ferme les yeux et repose-toi. Tout va bien se passer.'),
    'it': ('Sussurro dolce', '[sussurro dolce e tenero] Chiudi gli occhi e riposati. Andrà tutto bene.'),
    'nl': ('Zacht gefluister', '[zacht en teder gefluister] Sluit je ogen en rust uit. Alles komt goed.'),
  },
  'strong_whisper': {
    'en': ('Strong whisper', '[strong urgent whisper] Get down, now! They are right behind the door!'),
    'pt-BR': ('Sussurro forte', '[sussurro forte e urgente] Abaixe agora! Eles estão atrás da porta!'),
    'pt-PT': ('Sussurro forte', '[sussurro forte e urgente] Baixa-te já! Eles estão atrás da porta!'),
    'de': ('Kräftiges Flüstern', '[dringend und kräftig flüsternd] Runter, sofort! Sie sind direkt hinter der Tür!'),
    'es': ('Susurro intenso', '[susurro fuerte y urgente] ¡Agáchate, ahora! ¡Están justo detrás de la puerta!'),
    'fr': ('Murmure intense', '[murmure fort et urgent] Baisse-toi, tout de suite ! Ils sont juste derrière la porte !'),
    'it': ('Sussurro intenso', '[sussurro forte e urgente] Abbassati, subito! Sono proprio dietro la porta!'),
    'nl': ('Krachtig gefluister', '[krachtig en dringend gefluister] Duik weg, nu! Ze staan vlak achter de deur!'),
  },
  'extremly_quiet_whisper': {
    'en': ('Very quiet whisper', '[barely audible whisper] Shh... the baby is finally asleep.'),
    'pt-BR': ('Sussurro bem baixo', '[sussurro quase inaudível] Psiu... o bebê finalmente dormiu.'),
    'pt-PT': ('Sussurro muito baixo', '[sussurro quase inaudível] Chiu... o bebé finalmente adormeceu.'),
    'de': ('Sehr leises Flüstern', '[kaum hörbares Flüstern] Psst ... das Baby schläft endlich.'),
    'es': ('Susurro muy bajo', '[susurro casi inaudible] Shh... el bebé por fin se ha dormido.'),
    'fr': ('Murmure très discret', '[murmure à peine audible] Chut... le bébé dort enfin.'),
    'it': ('Sussurro molto piano', '[sussurro appena udibile] Shh... il bambino finalmente dorme.'),
    'nl': ('Heel zacht gefluister', '[bijna onhoorbaar gefluister] Ssst... de baby slaapt eindelijk.'),
  },
  'angry_whisper': {
    'en': ('Angry whisper', '[angry whisper] I told you not to touch that. Put it back right now.'),
    'pt-BR': ('Sussurro bravo', '[sussurrando com raiva] Eu falei para não mexer nisso. Coloque de volta agora.'),
    'pt-PT': ('Sussurro zangado', '[a sussurrar com raiva] Eu disse-te para não mexeres nisso. Põe isso no sítio já.'),
    'de': ('Wütendes Flüstern', '[wütend flüsternd] Ich habe dir gesagt, dass du das nicht anfassen sollst. Leg es sofort zurück.'),
    'es': ('Susurro enfadado', '[susurrando con enfado] Te dije que no tocaras eso. Vuélvelo a poner ahora mismo.'),
    'fr': ('Murmure furieux', '[murmurant avec colère] Je t’ai dit de ne pas toucher à ça. Remets-le tout de suite.'),
    'it': ('Sussurro arrabbiato', '[sussurrando con rabbia] Ti ho detto di non toccarlo. Rimettilo subito a posto.'),
    'nl': ('Boos gefluister', '[boos fluisterend] Ik zei dat je dat niet mocht aanraken. Leg het onmiddellijk terug.'),
  },
  'happy_laughing': {
    'en': ('Happy', '[happy and enjoying life] What a funny joke! I could not stop laughing.'),
    'pt-BR': ('Feliz', '[feliz e sorrindo] Que piada engraçada! Eu não consegui parar de rir.'),
    'pt-PT': ('Feliz', '[feliz e a sorrir] Que piada tão engraçada! Não consegui parar de rir.'),
    'de': ('Fröhlich', '[fröhlich und lebensfroh] Was für ein lustiger Witz! Ich musste einfach lachen.'),
    'es': ('Feliz', '[alegre y disfrutando de la vida] ¡Qué chiste tan gracioso! No podía parar de reírme.'),
    'fr': ('Joyeux', '[joyeux et plein de vie] Quelle blague amusante ! Je n’arrivais plus à m’arrêter de rire.'),
    'it': ('Felice', '[felice e pieno di gioia] Che battuta divertente! Non riuscivo a smettere di ridere.'),
    'nl': ('Vrolijk', '[vrolijk en levenslustig] Wat een grappige grap! Ik kon niet ophouden met lachen.'),
  },
  'strong_happy_laughing': {
    'en': ('Laughing hard', '[laughing hysterically] Oh no, you did not just say that! That is hilarious!'),
    'pt-BR': ('Gargalhada', '[gargalhando histericamente] Não acredito que você disse isso! Que hilário!'),
    'pt-PT': ('Gargalhada', '[às gargalhadas histéricas] Não acredito que disseste isso! Que hilariante!'),
    'de': ('Hysterisches Lachen', '[hysterisch lachend] Oh nein, das hast du jetzt nicht wirklich gesagt! Das ist ja unglaublich lustig!'),
    'es': ('Risa descontrolada', '[riendo histéricamente] ¡No puede ser, no acabas de decir eso! ¡Es divertidísimo!'),
    'fr': ('Rire aux éclats', '[riant aux éclats] Oh non, tu n’as pas vraiment dit ça ! C’est hilarant !'),
    'it': ('Risata sfrenata', '[ridendo istericamente] Oh no, non puoi averlo detto davvero! È esilarante!'),
    'nl': ('Hysterisch lachen', '[hysterisch lachend] O nee, dat heb je toch niet echt gezegd! Dat is hilarisch!'),
  },
  'motivating': {
    'en': ('Motivating', '[motivating coach] You are stronger than you think. One more step, you can do it!'),
    'pt-BR': ('Motivador', '[treinador motivador] Você é mais forte do que imagina. Só mais um passo, você consegue!'),
    'pt-PT': ('Motivador', '[treinador motivador] És mais forte do que imaginas. Só mais um passo, tu consegues!'),
    'de': ('Motivierend', '[motivierender Coach] Du bist stärker, als du denkst. Noch ein Schritt, du schaffst das!'),
    'es': ('Motivador', '[entrenador motivador] Eres más fuerte de lo que crees. ¡Un paso más, tú puedes!'),
    'fr': ('Motivant', '[coach motivant] Tu es plus fort que tu ne le penses. Encore un pas, tu peux y arriver !'),
    'it': ('Motivante', '[allenatore motivante] Sei più forte di quanto pensi. Ancora un passo, ce la puoi fare!'),
    'nl': ('Motiverend', '[motiverende coach] Je bent sterker dan je denkt. Nog één stap, je kunt het!'),
  },
  'shouting_encouraging': {
    'en': ('Shouting encouragement', '[shouting encouragement] Come on! Faster! You are almost there!'),
    'pt-BR': ('Gritando incentivo', '[gritando e encorajando] Vamos lá! Mais rápido! Você está quase lá!'),
    'pt-PT': ('Grito de incentivo', '[a gritar e a encorajar] Vamos lá! Mais depressa! Estás quase lá!'),
    'de': ('Lauter Ansporn', '[laut anfeuernd] Los! Schneller! Du bist fast da!'),
    'es': ('Grito de ánimo', '[gritando para animar] ¡Vamos! ¡Más rápido! ¡Ya casi llegas!'),
    'fr': ('Encouragement crié', '[criant des encouragements] Allez ! Plus vite ! Tu y es presque !'),
    'it': ('Incoraggiamento urlato', '[incoraggiando a gran voce] Forza! Più veloce! Ci sei quasi!'),
    'nl': ('Luid aanmoedigen', '[luid aanmoedigend] Kom op! Sneller! Je bent er bijna!'),
  },
  'disappointed': {
    'en': ('Disappointed', '[disappointed and sad] I really thought you would come today. Oh well.'),
    'pt-BR': ('Decepcionado', '[decepcionado e triste] Eu realmente achei que você viria hoje. Que pena.'),
    'pt-PT': ('Desiludido', '[desiludido e triste] Pensei mesmo que vinhas hoje. Que pena.'),
    'de': ('Enttäuscht', '[enttäuscht und traurig] Ich dachte wirklich, dass du heute kommst. Na ja.'),
    'es': ('Decepcionado', '[decepcionado y triste] De verdad pensé que vendrías hoy. En fin.'),
    'fr': ('Déçu', '[déçu et triste] Je pensais vraiment que tu viendrais aujourd’hui. Tant pis.'),
    'it': ('Deluso', '[deluso e triste] Pensavo davvero che saresti venuto oggi. Pazienza.'),
    'nl': ('Teleurgesteld', '[teleurgesteld en verdrietig] Ik dacht echt dat je vandaag zou komen. Jammer dan.'),
  },
  'military_sergeant_hard': {
    'en': ('Drill sergeant', '[drill sergeant] Get down and give me 50 push-ups!'),
    'pt-BR': ('Sargento', '[sargento militar durão] Ao chão e faça cinquenta flexões!'),
    'pt-PT': ('Sargento', '[sargento militar duro] Para o chão e faz cinquenta flexões!'),
    'de': ('Drill-Sergeant', '[harter Drill-Sergeant] Auf den Boden und 50 Liegestütze, sofort!'),
    'es': ('Sargento instructor', '[sargento instructor] ¡Al suelo y haz 50 flexiones!'),
    'fr': ('Sergent instructeur', '[sergent instructeur] À terre, et fais 50 pompes !'),
    'it': ('Sergente istruttore', '[sergente istruttore] A terra, e fai 50 flessioni!'),
    'nl': ('Drillinstructeur', '[drillinstructeur] Naar de grond en doe vijftig keer opdrukken!'),
  },
  'military_sergeant_soft': {
    'en': ('Friendly sergeant', '[friendly army sergeant] Good work, soldier. Take five and drink some water.'),
    'pt-BR': ('Sargento gentil', '[sargento do exército gentil] Bom trabalho, soldado. Descanse um pouco e beba água.'),
    'pt-PT': ('Sargento gentil', '[sargento do exército gentil] Bom trabalho, soldado. Descansa um pouco e bebe água.'),
    'de': ('Freundlicher Feldwebel', '[freundlicher Feldwebel] Gute Arbeit, Soldat. Ruh dich fünf Minuten aus und trink etwas Wasser.'),
    'es': ('Sargento amable', '[sargento amable] Buen trabajo, soldado. Descansa cinco minutos y bebe agua.'),
    'fr': ('Sergent bienveillant', '[sergent bienveillant] Beau travail, soldat. Repose-toi cinq minutes et bois un peu d’eau.'),
    'it': ('Sergente gentile', '[sergente gentile] Ottimo lavoro, soldato. Riposati cinque minuti e bevi un po’ d’acqua.'),
    'nl': ('Vriendelijke sergeant', '[vriendelijke sergeant] Goed gedaan, soldaat. Neem vijf minuten rust en drink wat water.'),
  },
};

/// An ability without a written example: its own name as the tag, per language.
const _genericStyle = {
  'en': '[WORDS] Hello! This is my voice in this style.',
  'pt-BR': '[WORDS] Olá! Esta é a minha voz com este estilo.',
  'pt-PT': '[WORDS] Olá! Esta é a minha voz com este estilo.',
  'de': '[WORDS] Hallo! So klingt meine Stimme in diesem Stil.',
  'el': '[WORDS] Γεια σας! Έτσι ακούγεται η φωνή μου σε αυτό το ύφος.',
  'es': '[WORDS] ¡Hola! Así suena mi voz con este estilo.',
  'fr': '[WORDS] Bonjour ! Voici ma voix avec ce style.',
  'it': '[WORDS] Ciao! Questa è la mia voce con questo stile.',
  'nl': '[WORDS] Hallo! Zo klinkt mijn stem in deze stijl.',
  'he': '[WORDS] שלום! ככה נשמע הקול שלי בסגנון הזה.',
  'da': '[WORDS] Hej! Sådan lyder min stemme i denne stil.',
  'sv': '[WORDS] Hej! Så här låter min röst i den här stilen.',
};

String genericStyleText(String language, String words) => (_genericStyle[language] ?? _genericStyle['en']!).replaceFirst('WORDS', words);

/// Abilities without examples in a language.
const Map<String, List<String>> hiddenStyleAbilities = {
  'en': [],
  'pt-BR': [],
  'pt-PT': [],
  'de': [],
  'es': [],
  'fr': [],
  'it': [],
  'nl': [],
  'he': [],
  'da': [],
  'sv': [],
  'el': [],
};
