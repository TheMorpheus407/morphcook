import '../models/localized_text.dart';

abstract final class Copy {
  static const Map<String, LocalizedText> _values = {
    'home': {'en': 'home', 'de': 'start'},
    'search': {'en': 'search', 'de': 'suche'},
    'cookbook': {'en': 'cookbook', 'de': 'kochbuch'},
    'plan': {'en': 'plan', 'de': 'plan'},
    'shopping': {'en': 'list', 'de': 'liste'},
    'settings': {'en': 'settings', 'de': 'einstellungen'},
    'continue': {'en': 'continue', 'de': 'weiter'},
    'back': {'en': 'back', 'de': 'zurück'},
    'done': {'en': 'done', 'de': 'fertig'},
    'cancel': {'en': 'cancel', 'de': 'abbrechen'},
    'save': {'en': 'save', 'de': 'speichern'},
    'saved': {'en': 'saved', 'de': 'gespeichert'},
    'add': {'en': 'add', 'de': 'hinzufügen'},
    'remove': {'en': 'remove', 'de': 'entfernen'},
    'close': {'en': 'close', 'de': 'schließen'},
    'language': {'en': 'language', 'de': 'sprache'},
    'hello': {'en': 'hello', 'de': 'hallo'},
    'onboarding_language_title': {
      'en': 'first, your language.',
      'de': 'zuerst, deine sprache.',
    },
    'onboarding_language_note': {
      'en': 'Everything in your cookbook changes with you.',
      'de': 'Alles in deinem Kochbuch wechselt mit dir.',
    },
    'onboarding_name_title': {
      'en': 'whose cookbook is this?',
      'de': 'wem gehört dieses kochbuch?',
    },
    'name': {'en': 'your name', 'de': 'dein name'},
    'name_hint': {'en': 'Mara, perhaps?', 'de': 'Vielleicht Mara?'},
    'onboarding_diet_title': {
      'en': 'make every dish yours.',
      'de': 'mach jedes gericht zu deinem.',
    },
    'onboarding_diet_note': {
      'en':
          'Choose what to avoid and what your food should honour. We show complete recipes—not compromises.',
      'de':
          'Wähle, was du meidest und was dein Essen beachten soll. Wir zeigen vollständige Rezepte – keine Kompromisse.',
    },
    'diet_style': {'en': 'diet & values', 'de': 'ernährung & werte'},
    'allergies': {'en': 'allergies & classes', 'de': 'allergien & gruppen'},
    'specific_avoidance': {
      'en': 'specific ingredients',
      'de': 'einzelne zutaten',
    },
    'ingredient_search_hint': {
      'en': 'type apples, cilantro…',
      'de': 'apfel, koriander …',
    },
    'onboarding_limits_title': {
      'en': 'what fits today?',
      'de': 'was passt heute?',
    },
    'calorie_target': {'en': 'calorie target', 'de': 'kalorienziel'},
    'time_budget': {'en': 'time budget', 'de': 'zeitbudget'},
    'effort': {'en': 'effort', 'de': 'aufwand'},
    'easy': {'en': 'easy', 'de': 'einfach'},
    'medium': {'en': 'medium', 'de': 'mittel'},
    'hard': {'en': 'pro', 'de': 'profi'},
    'confirm_title': {
      'en': 'your table is set.',
      'de': 'dein tisch ist gedeckt.',
    },
    'confirm_note': {
      'en':
          'No disappearing dishes. Just the version written for the way you eat.',
      'de':
          'Keine verschwindenden Gerichte. Einfach die Version, die für deine Art zu essen geschrieben wurde.',
    },
    'open_cookbook': {'en': 'open my cookbook', 'de': 'mein kochbuch öffnen'},
    'today': {'en': 'today’s edition', 'de': 'heutige ausgabe'},
    'today_short': {'en': 'today', 'de': 'heute'},
    'featured': {'en': 'on the cover', 'de': 'auf dem titel'},
    'weeknight': {'en': 'quiet weeknights', 'de': 'ruhige feierabende'},
    'weekend': {'en': 'for a slow weekend', 'de': 'fürs langsame wochenende'},
    'for_you': {'en': 'written for you', 'de': 'für dich geschrieben'},
    'minutes': {'en': 'min', 'de': 'min'},
    'calories': {'en': 'kcal', 'de': 'kcal'},
    'no_recipes': {
      'en': 'No recipe fits these limits yet.',
      'de': 'Noch kein Rezept passt zu diesen Grenzen.',
    },
    'adjust_profile': {'en': 'adjust profile', 'de': 'profil anpassen'},
    'search_hint': {
      'en': 'dish, ingredient, small craving…',
      'de': 'gericht, zutat, kleiner appetit …',
    },
    'all': {'en': 'all', 'de': 'alle'},
    'results': {'en': 'results', 'de': 'ergebnisse'},
    'no_results': {
      'en':
          'Nothing in this edition—your search was kept in your backup as a content request.',
      'de':
          'Nichts in dieser Ausgabe – deine Suche wurde lokal als Rezeptwunsch vorgemerkt.',
    },
    'saved_empty': {
      'en':
          'Your shelves are waiting. Save a specific recipe variant and it will live here.',
      'de':
          'Deine Regale warten. Speichere eine bestimmte Rezeptversion, dann lebt sie hier.',
    },
    'diet': {'en': 'diet', 'de': 'ernährung'},
    'calorie': {'en': 'calorie level', 'de': 'kalorien'},
    'ingredients': {'en': 'ingredients', 'de': 'zutaten'},
    'method': {'en': 'method', 'de': 'zubereitung'},
    'nutrition': {'en': 'nutrition', 'de': 'nährwerte'},
    'servings': {'en': 'servings', 'de': 'portionen'},
    'no_combo': {
      'en': 'not available with the current choices yet',
      'de': 'mit der aktuellen auswahl noch nicht verfügbar',
    },
    'outside_calorie': {
      'en': 'show versions outside my calorie target',
      'de': 'versionen außerhalb meines kalorienziels zeigen',
    },
    'learn_more': {'en': 'learn more', 'de': 'mehr erfahren'},
    'usage': {'en': 'how to use', 'de': 'verwendung'},
    'storage': {'en': 'storage', 'de': 'aufbewahrung'},
    'where_to_find': {'en': 'where to find it', 'de': 'wo du es findest'},
    'add_to_list': {'en': 'add to list', 'de': 'zur liste'},
    'start_cooking': {'en': 'start cooking', 'de': 'kochen starten'},
    'added_to_list': {
      'en': 'added to your list',
      'de': 'zur liste hinzugefügt',
    },
    'weekly_plan': {'en': 'the weekly table', 'de': 'der wochenplan'},
    'breakfast': {'en': 'breakfast', 'de': 'frühstück'},
    'lunch': {'en': 'lunch', 'de': 'mittag'},
    'dinner': {'en': 'dinner', 'de': 'abendessen'},
    'choose_recipe': {'en': 'choose a recipe', 'de': 'rezept auswählen'},
    'export_week': {
      'en': 'week → shopping list',
      'de': 'woche → einkaufsliste',
    },
    'week_added': {
      'en': 'planned meals added',
      'de': 'geplante mahlzeiten hinzugefügt',
    },
    'shopping_title': {'en': 'market list', 'de': 'marktliste'},
    'shopping_empty': {
      'en': 'A clean sheet. Add ingredients from a recipe or your weekly plan.',
      'de':
          'Ein leeres Blatt. Füge Zutaten aus einem Rezept oder deinem Wochenplan hinzu.',
    },
    'clear_checked': {'en': 'clear checked', 'de': 'erledigtes löschen'},
    'aisle_produce': {'en': 'produce', 'de': 'obst & gemüse'},
    'aisle_pantry': {'en': 'pantry', 'de': 'vorrat'},
    'aisle_chilled': {'en': 'chilled', 'de': 'kühlregal'},
    'aisle_bakery': {'en': 'bakery', 'de': 'bäckerei'},
    'aisle_spices': {'en': 'spices', 'de': 'gewürze'},
    'aisle_other': {'en': 'other', 'de': 'sonstiges'},
    'profile': {'en': 'profile & matching', 'de': 'profil & auswahl'},
    'preferences': {'en': 'adaptation preferences', 'de': 'darstellung'},
    'show_tags': {'en': 'show variant tags', 'de': 'varianten-tags zeigen'},
    'reduce_motion': {'en': 'reduce motion', 'de': 'bewegung reduzieren'},
    'follow_system': {'en': 'follow system', 'de': 'systemeinstellung'},
    'visual_alert': {'en': 'visual timer alert', 'de': 'visueller timeralarm'},
    'quick_tap': {
      'en': 'tap step to advance',
      'de': 'tippen für nächsten schritt',
    },
    'help': {'en': 'help center', 'de': 'hilfe'},
    'insights': {'en': 'shopping insights', 'de': 'einkaufs-einblicke'},
    'history': {'en': 'cooking history', 'de': 'kochverlauf'},
    'backup': {'en': 'backup & restore', 'de': 'sichern & wiederherstellen'},
    'export': {'en': 'export backup', 'de': 'sicherung exportieren'},
    'import': {'en': 'restore backup', 'de': 'sicherung wiederherstellen'},
    'password_optional': {
      'en': 'password (optional)',
      'de': 'passwort (optional)',
    },
    'merge': {
      'en': 'merge with this device',
      'de': 'mit diesem gerät zusammenführen',
    },
    'replace': {'en': 'replace this device', 'de': 'dieses gerät ersetzen'},
    'backup_ready': {
      'en': 'backup ready to share',
      'de': 'sicherung ist bereit',
    },
    'restore_done': {
      'en': 'backup restored',
      'de': 'sicherung wiederhergestellt',
    },
    'halal_note': {
      'en':
          '“Halal” and “kosher” mean compatible ingredients here, never certification. Certification depends on sourcing and supervision.',
      'de':
          '„Halal“ und „koscher“ bedeuten hier kompatible Zutaten, niemals Zertifizierung. Diese hängt von Herkunft und Aufsicht ab.',
    },
    'faq_search': {'en': 'search help…', 'de': 'hilfe durchsuchen …'},
    'variety': {'en': 'variety score', 'de': 'vielfaltswert'},
    'unique_ingredients': {
      'en': 'unique ingredients',
      'de': 'einzigartige zutaten',
    },
    'top_added': {'en': 'most often added', 'de': 'am häufigsten hinzugefügt'},
    'seasonal': {'en': 'your year by month', 'de': 'dein jahr nach monaten'},
    'no_insights': {
      'en':
          'Add a few recipes to your list and your patterns will appear here.',
      'de':
          'Füge einige Rezepte zur Liste hinzu, dann erscheinen hier deine Muster.',
    },
    'step': {'en': 'step', 'de': 'schritt'},
    'pause': {'en': 'pause', 'de': 'pause'},
    'resume': {'en': 'resume', 'de': 'weiter'},
    'reset': {'en': 'reset', 'de': 'neu'},
    'previous': {'en': 'previous', 'de': 'zurück'},
    'next': {'en': 'next', 'de': 'weiter'},
    'finish': {'en': 'finish', 'de': 'abschließen'},
    'timer_done': {'en': 'timer finished', 'de': 'timer abgelaufen'},
    'cooked': {'en': 'you made this.', 'de': 'du hast es gekocht.'},
    'cooked_note': {
      'en': 'Another page with a little flour on it.',
      'de': 'Eine weitere Seite mit ein wenig Mehl darauf.',
    },
    'return_home': {'en': 'back to the table', 'de': 'zurück zum tisch'},
    'protein': {'en': 'protein', 'de': 'protein'},
    'carbs': {'en': 'carbs', 'de': 'kohlenhydrate'},
    'fat': {'en': 'fat', 'de': 'fett'},
  };

  static String text(String key, String language) =>
      _values[key]?.value(language) ?? key;
}
