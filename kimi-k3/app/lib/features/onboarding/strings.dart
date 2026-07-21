/// Onboarding copy, bilingual (en/de). German is informal (du-form).
/// Voice: warm, lowercase, poetic-but-plain cookbook.
const Map<String, Map<String, String>> strings = {
  'onboarding.welcome': {
    'en': 'a little cookbook, made for you',
    'de': 'ein kleines kochbuch, nur für dich',
  },
  'onboarding.step': {'en': 'step', 'de': 'schritt'},
  'onboarding.common.next': {'en': 'next', 'de': 'weiter'},
  'onboarding.common.back': {'en': 'back', 'de': 'zurück'},
  'onboarding.common.skip': {
    'en': 'skip for now',
    'de': 'erstmal überspringen',
  },
  'onboarding.common.edit': {'en': 'edit', 'de': 'ändern'},

  // step 0 — language
  'onboarding.lang.title': {
    'en': 'which language should we cook in?',
    'de': 'in welcher sprache kochen wir?',
  },
  'onboarding.lang.note': {
    'en': 'you can change this anytime',
    'de': 'du kannst das jederzeit ändern',
  },

  // step 1 — name
  'onboarding.name.title': {
    'en': 'what should we call you?',
    'de': 'wie sollen wir dich nennen?',
  },
  'onboarding.name.hint': {
    'en': 'your name, or a nickname…',
    'de': 'dein name, oder ein spitzname…',
  },
  'onboarding.name.note': {
    'en': 'optional — but recipes read nicer with a name in the margin',
    'de': 'optional — aber rezepte lesen sich schöner mit einem namen am rand',
  },

  // step 2 — diet & allergies
  'onboarding.diet.title': {
    'en': 'anything you’d rather skip?',
    'de': 'gibt es etwas, das du lieber weglässt?',
  },
  'onboarding.diet.compound': {
    'en': 'ways of eating',
    'de': 'ernährungsweisen',
  },
  'onboarding.diet.classes': {
    'en': 'ingredient groups',
    'de': 'zutatengruppen',
  },
  'onboarding.diet.specific': {
    'en': 'specific ingredients',
    'de': 'einzelne zutaten',
  },
  'onboarding.diet.search_hint': {
    'en': 'type to search — e.g. coriander',
    'de': 'tippe zum suchen — z. b. koriander',
  },
  'onboarding.diet.chosen': {
    'en': 'your skip-list',
    'de': 'deine streichliste',
  },
  'onboarding.diet.empty': {
    'en': 'nothing yet — you eat everything, how lovely',
    'de': 'noch nichts — du isst alles, wie schön',
  },
  'onboarding.diet.note': {
    'en': 'no wrong answers here',
    'de': 'hier gibt es keine falschen antworten',
  },
  'onboarding.require.title': {'en': 'must-haves', 'de': 'muss-kriterien'},
  'onboarding.require.halal': {
    'en': 'require halal-compatible recipes',
    'de': 'nur halal-kompatible rezepte zeigen',
  },
  'onboarding.require.kosher': {
    'en': 'require kosher-compatible recipes',
    'de': 'nur koscher-kompatible rezepte zeigen',
  },

  // step 3 — targets
  'onboarding.targets.title': {
    'en': 'your everyday rhythm',
    'de': 'dein alltagsrhythmus',
  },
  'onboarding.targets.calories': {
    'en': 'calories per meal',
    'de': 'kalorien pro mahlzeit',
  },
  'onboarding.targets.time': {
    'en': 'time in the kitchen',
    'de': 'zeit in der küche',
  },
  'onboarding.targets.effort': {
    'en': 'how much effort feels right?',
    'de': 'wie viel aufwand fühlt sich richtig an?',
  },
  'onboarding.targets.note': {
    'en': 'rough guesses are perfectly fine',
    'de': 'grobe schätzungen sind völlig okay',
  },
  'onboarding.effort.easy': {'en': 'easy', 'de': 'einfach'},
  'onboarding.effort.medium': {'en': 'medium', 'de': 'mittel'},
  'onboarding.effort.hard': {'en': 'hard', 'de': 'aufwendig'},

  // step 4 — confirm
  'onboarding.confirm.title': {
    'en': 'does this sound like you?',
    'de': 'klingt das nach dir?',
  },
  'onboarding.confirm.note': {
    'en': 'all of this can be changed later, promise',
    'de': 'das lässt sich später alles ändern, versprochen',
  },
  'onboarding.confirm.begin': {'en': 'begin', 'de': 'los geht’s'},
  'onboarding.summary.language': {'en': 'language', 'de': 'sprache'},
  'onboarding.summary.name': {'en': 'name', 'de': 'name'},
  'onboarding.summary.avoids': {'en': 'skip-list', 'de': 'streichliste'},
  'onboarding.summary.requires': {'en': 'must-haves', 'de': 'muss-kriterien'},
  'onboarding.summary.calories': {'en': 'per meal', 'de': 'pro mahlzeit'},
  'onboarding.summary.time': {'en': 'time budget', 'de': 'zeitbudget'},
  'onboarding.summary.effort': {'en': 'effort', 'de': 'aufwand'},
  'onboarding.summary.no_name': {'en': 'no name (yet)', 'de': 'noch kein name'},
  'onboarding.summary.none': {'en': 'none', 'de': 'nichts'},
};
