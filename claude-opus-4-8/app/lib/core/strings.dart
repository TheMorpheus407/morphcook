import 'localized.dart';

/// Static UI copy. Data-driven (recipes, flags…) text lives in the corpus;
/// this is the chrome. Adding a language is adding a column here.
class S {
  const S(this.lang);
  final AppLang lang;

  String t(String key) {
    final entry = _strings[key];
    if (entry == null) return key;
    return entry[lang.code] ?? entry['en'] ?? key;
  }

  static const Map<String, Map<String, String>> _strings = {
    'app.name': {'en': 'MorphCook', 'de': 'MorphCook'},
    'app.tagline': {
      'en': 'every body, the whole cookbook',
      'de': 'jeder Körper, das ganze Kochbuch'
    },

    // nav
    'nav.home': {'en': 'kitchen', 'de': 'Küche'},
    'nav.search': {'en': 'search', 'de': 'Suche'},
    'nav.cookbook': {'en': 'cookbook', 'de': 'Kochbuch'},
    'nav.plan': {'en': 'plan', 'de': 'Plan'},
    'nav.settings': {'en': 'you', 'de': 'Du'},

    // common
    'common.save': {'en': 'Save', 'de': 'Speichern'},
    'common.saved': {'en': 'Saved', 'de': 'Gespeichert'},
    'common.cancel': {'en': 'Cancel', 'de': 'Abbrechen'},
    'common.done': {'en': 'Done', 'de': 'Fertig'},
    'common.next': {'en': 'Next', 'de': 'Weiter'},
    'common.back': {'en': 'Back', 'de': 'Zurück'},
    'common.add': {'en': 'Add', 'de': 'Hinzufügen'},
    'common.remove': {'en': 'Remove', 'de': 'Entfernen'},
    'common.clear': {'en': 'Clear', 'de': 'Leeren'},
    'common.close': {'en': 'Close', 'de': 'Schließen'},
    'common.servings': {'en': 'servings', 'de': 'Portionen'},
    'common.minutes': {'en': 'min', 'de': 'Min'},
    'common.kcal': {'en': 'kcal', 'de': 'kcal'},
    'common.search': {'en': 'Search', 'de': 'Suchen'},
    'common.empty': {'en': 'Nothing here yet.', 'de': 'Noch nichts hier.'},
    'common.learn_more': {'en': 'Learn more', 'de': 'Mehr erfahren'},
    'common.loading': {'en': 'one moment…', 'de': 'einen Moment…'},
    'common.retry': {'en': 'Try again', 'de': 'Erneut versuchen'},

    // home
    'home.featured': {'en': 'today, for you', 'de': 'heute, für dich'},
    'home.sections.breakfast': {'en': 'mornings', 'de': 'Morgens'},
    'home.sections.lunch': {'en': 'midday', 'de': 'Mittags'},
    'home.sections.dinner': {'en': 'evenings', 'de': 'Abends'},
    'home.all_dishes': {'en': 'the whole shelf', 'de': 'das ganze Regal'},
    'home.nothing_matches': {
      'en': "Your filters hide everything here. Loosen them in settings, or peek anyway.",
      'de': 'Deine Filter verbergen hier alles. Lockere sie in den Einstellungen.'
    },

    // dish detail
    'dish.ingredients': {'en': 'ingredients', 'de': 'Zutaten'},
    'dish.method': {'en': 'method', 'de': 'Zubereitung'},
    'dish.macros': {'en': 'per serving', 'de': 'pro Portion'},
    'dish.protein': {'en': 'protein', 'de': 'Eiweiß'},
    'dish.carbs': {'en': 'carbs', 'de': 'Kohlenhydrate'},
    'dish.fat': {'en': 'fat', 'de': 'Fett'},
    'dish.cook': {'en': 'Cook this', 'de': 'Loskochen'},
    'dish.add_to_plan': {'en': 'Add to plan', 'de': 'Zum Plan'},
    'dish.add_to_list': {'en': 'Add to list', 'de': 'Zur Liste'},
    'dish.show_outside_calories': {
      'en': 'show versions outside my calorie target',
      'de': 'Versionen außerhalb meines Kalorienziels zeigen'
    },
    'dish.no_combo': {
      'en': 'no version of this yet',
      'de': 'davon gibt es noch keine Version'
    },
    'dish.variant_unavailable': {
      'en': "doesn't fit your profile",
      'de': 'passt nicht zu deinem Profil'
    },

    // search
    'search.hint': {'en': 'a dish, a craving…', 'de': 'ein Gericht, ein Gelüst…'},
    'search.no_results': {
      'en': "We don't have that one yet — we noted it.",
      'de': 'Das haben wir noch nicht — wir haben es notiert.'
    },
    'search.filters': {'en': 'filters', 'de': 'Filter'},

    // cookbook
    'cookbook.title': {'en': 'your cookbook', 'de': 'dein Kochbuch'},
    'cookbook.empty': {
      'en': 'Save a recipe and it lands here — your variant, your way.',
      'de': 'Speichere ein Rezept und es landet hier — deine Variante.'
    },

    // meal plan
    'plan.title': {'en': 'the week', 'de': 'die Woche'},
    'plan.this_week': {'en': 'this week', 'de': 'diese Woche'},
    'plan.assign': {'en': 'Assign a recipe', 'de': 'Rezept zuweisen'},
    'plan.export_list': {'en': 'Send week to shopping list', 'de': 'Woche zur Einkaufsliste'},
    'plan.empty_slot': {'en': 'empty', 'de': 'leer'},
    'meal.breakfast': {'en': 'breakfast', 'de': 'Frühstück'},
    'meal.lunch': {'en': 'lunch', 'de': 'Mittag'},
    'meal.dinner': {'en': 'dinner', 'de': 'Abend'},
    'day.mon': {'en': 'Mon', 'de': 'Mo'},
    'day.tue': {'en': 'Tue', 'de': 'Di'},
    'day.wed': {'en': 'Wed', 'de': 'Mi'},
    'day.thu': {'en': 'Thu', 'de': 'Do'},
    'day.fri': {'en': 'Fri', 'de': 'Fr'},
    'day.sat': {'en': 'Sat', 'de': 'Sa'},
    'day.sun': {'en': 'Sun', 'de': 'So'},

    // shopping
    'shop.title': {'en': 'shopping list', 'de': 'Einkaufsliste'},
    'shop.empty': {
      'en': 'Add recipes and we tidy the ingredients into one list.',
      'de': 'Füge Rezepte hinzu und wir ordnen die Zutaten zu einer Liste.'
    },
    'shop.from_recipes': {'en': 'from', 'de': 'aus'},
    'shop.insights': {'en': 'Shopping insights', 'de': 'Einkaufs-Einblicke'},
    'shop.recipes_in_list': {'en': 'recipes in your list', 'de': 'Rezepte in deiner Liste'},

    // insights
    'insights.title': {'en': 'shopping insights', 'de': 'Einkaufs-Einblicke'},
    'insights.variety': {'en': 'variety score', 'de': 'Vielfalt'},
    'insights.variety_sub': {'en': 'unique ingredients', 'de': 'verschiedene Zutaten'},
    'insights.top': {'en': 'most added', 'de': 'am häufigsten'},
    'insights.seasonal': {'en': 'by month', 'de': 'nach Monat'},
    'insights.empty': {
      'en': 'Add a few recipes to your list and patterns appear here.',
      'de': 'Füge Rezepte hinzu und hier erscheinen Muster.'
    },

    // settings
    'settings.title': {'en': 'you & your kitchen', 'de': 'du & deine Küche'},
    'settings.profile': {'en': 'Profile', 'de': 'Profil'},
    'settings.name': {'en': 'Name', 'de': 'Name'},
    'settings.language': {'en': 'Language', 'de': 'Sprache'},
    'settings.diet': {'en': 'Diet & allergies', 'de': 'Ernährung & Allergien'},
    'settings.avoid_ingredients': {'en': 'Avoided ingredients', 'de': 'Gemiedene Zutaten'},
    'settings.calorie_target': {'en': 'Calorie target', 'de': 'Kalorienziel'},
    'settings.time_budget': {'en': 'Time budget', 'de': 'Zeitbudget'},
    'settings.effort': {'en': 'Effort mood', 'de': 'Aufwands-Laune'},
    'settings.adaptation': {'en': 'Adaptation', 'de': 'Anpassung'},
    'settings.show_tags': {'en': 'Show variant tags', 'de': 'Varianten-Tags zeigen'},
    'settings.calorie_filter': {'en': 'Filter by calorie target', 'de': 'Nach Kalorienziel filtern'},
    'settings.accessibility': {'en': 'Accessibility', 'de': 'Barrierefreiheit'},
    'settings.reduce_motion': {'en': 'Reduce motion', 'de': 'Bewegung reduzieren'},
    'settings.visual_alert': {'en': 'Visual timer alert', 'de': 'Visueller Timer-Alarm'},
    'settings.visual_alert_sub': {
      'en': 'Flash the screen when a cook timer ends.',
      'de': 'Bildschirm blinkt, wenn ein Timer endet.'
    },
    'settings.quick_tap': {'en': 'One-handed quick-advance', 'de': 'Einhand-Schnellwechsel'},
    'settings.quick_tap_sub': {
      'en': 'Tap the step to go to the next one in cook mode.',
      'de': 'Tippe auf den Schritt, um im Kochmodus weiterzugehen.'
    },
    'settings.data': {'en': 'Your data', 'de': 'Deine Daten'},
    'settings.backup': {'en': 'Back up to a file', 'de': 'In Datei sichern'},
    'settings.restore': {'en': 'Restore from a file', 'de': 'Aus Datei wiederherstellen'},
    'settings.help': {'en': 'Help center', 'de': 'Hilfe-Center'},
    'settings.halal_note': {
      'en': 'We surface halal- and kosher-compatible ingredients. We never claim certification — that is a property of sourcing, not of a recipe.',
      'de': 'Wir zeigen halal- und koscher-geeignete Zutaten. Wir behaupten keine Zertifizierung — das betrifft die Herkunft, nicht den Rezepttext.'
    },
    'settings.offline_note': {
      'en': 'Everything stays on this device. No account, no cloud, no telemetry.',
      'de': 'Alles bleibt auf diesem Gerät. Kein Konto, keine Cloud, keine Telemetrie.'
    },

    // backup
    'backup.password': {'en': 'Password (optional)', 'de': 'Passwort (optional)'},
    'backup.password_hint': {
      'en': 'Encrypts the JSON file. Leave empty for none.',
      'de': 'Verschlüsselt die JSON-Datei. Leer lassen für keine.'
    },
    'backup.export': {'en': 'Create backup', 'de': 'Backup erstellen'},
    'backup.paste': {'en': 'Paste backup contents', 'de': 'Backup-Inhalt einfügen'},
    'backup.import': {'en': 'Restore', 'de': 'Wiederherstellen'},
    'backup.merge': {'en': 'Merge with current', 'de': 'Mit aktuellem zusammenführen'},
    'backup.replace': {'en': 'Replace everything', 'de': 'Alles ersetzen'},
    'backup.ok': {'en': 'Restored.', 'de': 'Wiederhergestellt.'},

    // cook mode
    'cook.step': {'en': 'step', 'de': 'Schritt'},
    'cook.of': {'en': 'of', 'de': 'von'},
    'cook.start_timer': {'en': 'Start timer', 'de': 'Timer starten'},
    'cook.pause': {'en': 'Pause', 'de': 'Pause'},
    'cook.resume': {'en': 'Resume', 'de': 'Weiter'},
    'cook.prev': {'en': 'Previous', 'de': 'Zurück'},
    'cook.next': {'en': 'Next', 'de': 'Weiter'},
    'cook.finish': {'en': 'Finish', 'de': 'Beenden'},
    'cook.done_title': {'en': 'plates up.', 'de': 'angerichtet.'},
    'cook.done_sub': {
      'en': 'Nice. We saved this to your history.',
      'de': 'Schön. Wir haben das in deinem Verlauf gespeichert.'
    },
    'cook.resume_prompt': {'en': 'Pick up where you left off?', 'de': 'Dort weitermachen, wo du warst?'},
    'cook.timer_done': {'en': "time's up", 'de': 'Zeit ist um'},

    // onboarding
    'onb.welcome': {'en': 'a cookbook for your body', 'de': 'ein Kochbuch für deinen Körper'},
    'onb.welcome_sub': {
      'en': 'Not a filtered version of someone else’s. The whole book, written for how you eat.',
      'de': 'Keine gefilterte Version von jemand anderem. Das ganze Buch, für deine Ernährung geschrieben.'
    },
    'onb.lang_q': {'en': 'first — your language', 'de': 'zuerst — deine Sprache'},
    'onb.name_q': {'en': "what shall we call you?", 'de': 'wie sollen wir dich nennen?'},
    'onb.name_hint': {'en': 'a name (optional)', 'de': 'ein Name (optional)'},
    'onb.diet_q': {'en': 'how do you eat?', 'de': 'wie isst du?'},
    'onb.diet_sub': {
      'en': 'Pick what fits. Nothing here removes recipes — it picks the right version.',
      'de': 'Wähle, was passt. Nichts entfernt Rezepte — es wählt die richtige Version.'
    },
    'onb.allergy_q': {'en': 'anything to avoid?', 'de': 'etwas zu meiden?'},
    'onb.targets_q': {'en': 'your daily shape', 'de': 'dein täglicher Rahmen'},
    'onb.targets_sub': {
      'en': 'Rough is fine — you can change all of this later.',
      'de': 'Grob reicht — du kannst alles später ändern.'
    },
    'onb.calorie_q': {'en': 'calories per meal', 'de': 'Kalorien pro Mahlzeit'},
    'onb.time_q': {'en': 'time you usually have', 'de': 'Zeit, die du meist hast'},
    'onb.no_limit': {'en': 'no limit', 'de': 'kein Limit'},
    'onb.confirm_q': {'en': 'that’s your kitchen', 'de': 'das ist deine Küche'},
    'onb.confirm_sub': {
      'en': 'We’ll set things up. Change anything anytime in settings.',
      'de': 'Wir richten alles ein. Ändere alles jederzeit in den Einstellungen.'
    },
    'onb.start': {'en': 'open the kitchen', 'de': 'die Küche öffnen'},

    // faq
    'faq.title': {'en': 'help center', 'de': 'Hilfe-Center'},
    'faq.search': {'en': 'search help…', 'de': 'Hilfe durchsuchen…'},
    'faq.all': {'en': 'all', 'de': 'alle'},

    // guide
    'guide.usage': {'en': 'how it’s used', 'de': 'Verwendung'},
    'guide.storage': {'en': 'keeping it', 'de': 'Aufbewahrung'},
    'guide.where': {'en': 'where to find it', 'de': 'wo zu finden'},
  };
}
