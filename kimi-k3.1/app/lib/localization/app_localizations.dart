import 'package:flutter/material.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;
  static const supportedLocales = [Locale('en'), Locale('de')];
  static const delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      AppLocalizations(Localizations.localeOf(context));

  String t(String key, [Map<String, String>? arguments]) {
    final pair = _strings[key];
    var text = pair == null ? key : pair[locale.languageCode == 'de' ? 1 : 0];
    if (arguments != null) {
      for (final entry in arguments.entries) {
        text = text.replaceAll('{${entry.key}}', entry.value);
      }
    }
    return text;
  }

  String unit(String unit) => t('unit_$unit');
  String aisle(String aisle) => t('aisle_$aisle');
  String tag(String tag) => t('tag_$tag');

  static const _strings = <String, List<String>>{
    'app_title': ['MorphCook', 'MorphCook'],
    'tagline': ['a cookbook for every body', 'ein Kochbuch für jeden Körper'],
    'offline_credit': ['OFFLINE · MADE FOR YOU', 'OFFLINE · FÜR DICH GEMACHT'],
    'plate_study': ['PLATE STUDY', 'TELLERSTUDIE'],
    'loading': ['Setting the table…', 'Der Tisch wird gedeckt…'],
    'load_error': [
      'Your cookbook could not be opened.',
      'Dein Kochbuch konnte nicht geöffnet werden.',
    ],
    'retry': ['Try again', 'Erneut versuchen'],
    'next': ['Next', 'Weiter'],
    'back': ['Back', 'Zurück'],
    'continue': ['Continue', 'Weiter'],
    'done': ['Done', 'Fertig'],
    'save': ['Save', 'Speichern'],
    'cancel': ['Cancel', 'Abbrechen'],
    'close': ['Close', 'Schließen'],
    'clear': ['Clear', 'Leeren'],
    'remove': ['Remove', 'Entfernen'],
    'add': ['Add', 'Hinzufügen'],
    'search': ['Search', 'Suchen'],
    'see_all': ['See all', 'Alle ansehen'],
    'show_less': ['Show less', 'Weniger anzeigen'],
    'nav_home': ['Home', 'Start'],
    'nav_cookbook': ['Cookbook', 'Kochbuch'],
    'nav_plan': ['Plan', 'Plan'],
    'nav_shopping': ['Shopping', 'Einkauf'],
    'onboarding_kicker': ['your very own edition', 'deine ganz eigene Ausgabe'],
    'language_title': [
      'Which language feels like home?',
      'Welche Sprache fühlt sich wie Zuhause an?',
    ],
    'language_body': [
      'You can change this whenever you like.',
      'Du kannst das jederzeit ändern.',
    ],
    'name_title': ['What should we call you?', 'Wie dürfen wir dich nennen?'],
    'name_body': [
      'Just a first name for the little notes in your cookbook.',
      'Nur ein Vorname für die kleinen Notizen in deinem Kochbuch.',
    ],
    'name_hint': ['Your name', 'Dein Name'],
    'name_error': [
      'Add a name or choose “Skip”.',
      'Gib einen Namen ein oder wähle „Überspringen“.',
    ],
    'skip': ['Skip', 'Überspringen'],
    'diet_title': ['Make room at the table.', 'Mach Platz am Tisch.'],
    'diet_body': [
      'Choose what you avoid. We keep complete dishes, not a filtered-afterthought.',
      'Wähle aus, was du vermeidest. Du bekommst vollständige Gerichte, keine nachträglich gefilterte Auswahl.',
    ],
    'allergies_note': ['Allergies & ingredients', 'Allergien & Zutaten'],
    'calorie_title': [
      'What kind of cooking fits your day?',
      'Welches Kochen passt zu deinem Tag?',
    ],
    'calorie_body': [
      'These are firm cookbook preferences. You can override calories for one dish later.',
      'Das sind feste Kochbuch-Einstellungen. Kalorien kannst du später pro Gericht ausnehmen.',
    ],
    'calorie_target': ['Calories per meal', 'Kalorien pro Mahlzeit'],
    'time_budget': ['Time budget', 'Zeitbudget'],
    'preferred_effort': ['Effort mood', 'Lust auf Aufwand'],
    'calorie_tolerance': ['Calorie flexibility', 'Kalorien-Spielraum'],
    'confirm_title': ['Your cookbook is ready.', 'Dein Kochbuch ist bereit.'],
    'confirm_body': [
      'Every recipe you see from here fits the choices you just made.',
      'Jedes Rezept, das du ab jetzt siehst, passt zu deinen Auswahlen.',
    ],
    'start_cookbook': ['Open my cookbook', 'Mein Kochbuch öffnen'],
    'step_count': ['{current} / {total}', '{current} / {total}'],
    'profile_summary': ['Your editorial brief', 'Dein redaktioneller Auftrag'],
    'home_kicker': [
      'VOL. 01  ·  THE EVERY BODY EDITION',
      'AUSG. 01  ·  DIE EVERY-BODY-EDITION',
    ],
    'good_morning': ['good morning', 'guten Morgen'],
    'good_afternoon': ['good afternoon', 'guten Tag'],
    'good_evening': ['good evening', 'guten Abend'],
    'home_greeting': ['{greeting}, {name}.', '{greeting}, {name}.'],
    'home_greeting_plain': [
      '{greeting}, cook.',
      '{greeting}, du kleine Küchenfee.',
    ],
    'featured': ['today’s cover story', 'die Titelgeschichte'],
    'cook_this': ['Cook this', 'Jetzt kochen'],
    'fresh_from_kitchen': ['fresh from the kitchen', 'frisch aus der Küche'],
    'quiet_weeknight': [
      'a quieter kind of weeknight',
      'ein ruhigerer Feierabend',
    ],
    'home_empty_title': [
      'This edition needs a little more room.',
      'Diese Ausgabe braucht etwas mehr Spielraum.',
    ],
    'home_empty_body': [
      'No recipes fit all your current settings. Adjust time or calories in Settings, or check your avoidances.',
      'Keine Rezepte passen zu allen Einstellungen. Passe Zeit oder Kalorien an oder prüfe deine Vermeidungen.',
    ],
    'open_settings': ['Adjust my settings', 'Einstellungen anpassen'],
    'why_recipes': ['Why these recipes?', 'Warum diese Rezepte?'],
    'search_title': [
      'Find your next favorite',
      'Finde dein nächstes Lieblingsrezept',
    ],
    'search_hint': ['a dish, ingredient, mood…', 'Gericht, Zutat, Stimmung…'],
    'search_filters': ['Filter the pages', 'Seiten filtern'],
    'search_empty': [
      'Nothing in this edition—yet.',
      'Noch nichts in dieser Ausgabe.',
    ],
    'search_empty_body': [
      'Try fewer filters or another word. Your query was kept privately in this app as a content request.',
      'Versuche weniger Filter oder ein anderes Wort. Deine Anfrage wurde nur lokal als Inhaltswunsch gespeichert.',
    ],
    'search_results': [
      '{count} recipes on this page',
      '{count} Rezepte auf dieser Seite',
    ],
    'loading_more': ['Turning the page…', 'Nächste Seite…'],
    'list_error': [
      'This page got smudged. Please retry.',
      'Diese Seite ist verwischt. Bitte erneut versuchen.',
    ],
    'recipe_saved': [
      'Your version is tucked into the cookbook.',
      'Deine Version liegt jetzt in deinem Kochbuch.',
    ],
    'recipe_unsaved': [
      'Removed from your cookbook.',
      'Aus deinem Kochbuch entfernt.',
    ],
    'save_variant': ['Save my version', 'Meine Version speichern'],
    'saved_variant': ['My version is saved', 'Meine Version ist gespeichert'],
    'cookbook_title': [
      'the little saved things',
      'die kleinen Lieblingsrezepte',
    ],
    'cookbook_empty': [
      'No recipes tucked away yet.',
      'Noch keine Rezepte gespeichert.',
    ],
    'cookbook_empty_body': [
      'Save a specific version from any dish page. It will be right here when you need it.',
      'Speichere eine bestimmte Version auf einer Gerichtsseite. Sie wartet dann hier auf dich.',
    ],
    'history': ['Cooking history', 'Kochverlauf'],
    'history_empty': [
      'Your kitchen stories will gather here.',
      'Deine Küchengeschichten sammeln sich hier.',
    ],
    'cooked_on': ['Cooked {date}', 'Gekocht am {date}'],
    'dish_variants': ['make this one yours', 'mach es zu deinem'],
    'variant_unavailable': [
      'No {a} × {b} version yet.',
      'Noch keine Version {a} × {b}.',
    ],
    'variant_profile_unavailable': [
      'This combination is outside your current profile settings.',
      'Diese Kombination passt nicht zu deinen aktuellen Profileinstellungen.',
    ],
    'show_outside_calories': [
      'Show versions outside my calorie target',
      'Versionen außerhalb meines Kalorienziels zeigen',
    ],
    'calorie_override_note': [
      'Only this dish ignores the calorie limit. Every other preference still applies.',
      'Nur dieses Gericht ignoriert das Kalorienlimit. Alle anderen Wünsche bleiben aktiv.',
    ],
    'ingredients': ['Ingredients', 'Zutaten'],
    'method': ['Method', 'Zubereitung'],
    'macros': ['Macros', 'Makros'],
    'servings': ['{count} servings', '{count} Portionen'],
    'servings_short': ['servings', 'Portionen'],
    'minutes': ['{count} min', '{count} Min.'],
    'kcal': ['{count} kcal', '{count} kcal'],
    'protein': ['protein', 'Protein'],
    'carbs': ['carbs', 'Kohlenhydrate'],
    'fat': ['fat', 'Fett'],
    'per_serving': ['per serving', 'pro Portion'],
    'learn_more': ['Learn more', 'Mehr erfahren'],
    'usage': ['In the kitchen', 'In der Küche'],
    'storage': ['Keep it well', 'Richtig aufbewahren'],
    'where_to_find': ['Where to find it', 'Wo du es findest'],
    'no_guide': [
      'Guide entry coming in a future edition.',
      'Der Ratgeber folgt in einer späteren Ausgabe.',
    ],
    'start_cooking': ['Start cook mode', 'Kochmodus starten'],
    'resume_cooking': ['Resume cook mode', 'Kochmodus fortsetzen'],
    'step': ['step {current} of {total}', 'Schritt {current} von {total}'],
    'previous_step': ['Previous step', 'Vorheriger Schritt'],
    'next_step': ['Next step', 'Nächster Schritt'],
    'finish_recipe': ['I made this', 'Fertig gekocht'],
    'start_timer': ['Start timer', 'Timer starten'],
    'pause_timer': ['Pause timer', 'Timer pausieren'],
    'resume_timer': ['Resume timer', 'Timer fortsetzen'],
    'reset_timer': ['Reset timer', 'Timer zurücksetzen'],
    'timer_done': [
      'Time. Take a breath, then check your food.',
      'Zeit ist um. Kurz durchatmen und nach dem Essen sehen.',
    ],
    'quick_next_hint': [
      'One-handed tap to advance is on.',
      'Einhand-Tippen zum Weitergehen ist aktiv.',
    ],
    'cook_complete_kicker': [
      'a little kitchen victory',
      'ein kleiner Küchensieg',
    ],
    'cook_complete_title': ['You made {recipe}.', 'Du hast {recipe} gemacht.'],
    'cook_complete_body': [
      'Saved to your cooking history. Leave the dishes for a minute and enjoy it.',
      'Im Kochverlauf gespeichert. Lass den Abwasch kurz stehen und genieße es.',
    ],
    'back_to_dish': ['Back to the recipe', 'Zurück zum Rezept'],
    'settings_title': [
      'your editorial preferences',
      'deine persönlichen Einstellungen',
    ],
    'profile': ['Profile & dietary needs', 'Profil & Ernährung'],
    'language': ['Language', 'Sprache'],
    'english': ['English', 'Englisch'],
    'german': ['Deutsch', 'Deutsch'],
    'adaptation_preferences': [
      'Recipe & motion preferences',
      'Rezept- & Bewegungseinstellungen',
    ],
    'show_variant_tags': ['Show variant tags', 'Varianten-Tags anzeigen'],
    'reduce_motion': ['Reduced motion', 'Weniger Bewegung'],
    'motion_system': ['Use device setting', 'Geräteeinstellung verwenden'],
    'motion_on': ['Reduce motion', 'Bewegung reduzieren'],
    'motion_off': ['Allow gentle motion', 'Sanfte Bewegung erlauben'],
    'visual_alerts': ['Visual timer alerts', 'Visuelle Timer-Hinweise'],
    'visual_alerts_body': [
      'Coral/teal flashes when a timer ends; reduced motion uses a static alert.',
      'Koralle/Petrol blinken am Timerende; bei weniger Bewegung erscheint ein statischer Hinweis.',
    ],
    'quick_next': ['One-handed quick next', 'Einhand-Schnellwechsel'],
    'quick_next_body': [
      'Single-tap step text to advance with haptic feedback. Off when reduced motion is active.',
      'Tippe einmal auf den Schritttext, um mit haptischem Feedback weiterzugehen. Bei weniger Bewegung deaktiviert.',
    ],
    'halal_note': [
      'Halal and kosher settings describe ingredient compatibility only. Recipes are not certified; sourcing and supervision are your responsibility.',
      'Halal- und koscher-Einstellungen beschreiben nur Zutatenkompatibilität. Rezepte sind nicht zertifiziert; Herkunft und Aufsicht liegen bei dir.',
    ],
    'avoid_ingredients': [
      'Specific ingredients to avoid',
      'Bestimmte Zutaten vermeiden',
    ],
    'ingredient_typeahead': ['Type an ingredient…', 'Zutat eingeben…'],
    'no_ingredients_avoided': [
      'No specific ingredients added.',
      'Keine einzelnen Zutaten hinzugefügt.',
    ],
    'shopping_insights': ['Shopping insights', 'Einkaufsanalysen'],
    'backup_restore': ['Backup & restore', 'Sichern & Wiederherstellen'],
    'help_center': ['FAQ & help center', 'FAQ & Hilfe'],
    'offline_note': [
      'Offline by design. No account, no tracking, no recipe requests to a server.',
      'Bewusst offline. Kein Konto, kein Tracking, keine Rezeptanfragen an einen Server.',
    ],
    'faq_title': ['notes from the margins', 'Notizen am Rand'],
    'faq_hint': ['What can we help with?', 'Wobei können wir helfen?'],
    'faq_empty': [
      'No note matches that search.',
      'Keine Notiz passt zu dieser Suche.',
    ],
    'faq_all': ['All', 'Alle'],
    'faq_matching': ['Dietary matching', 'Ernährungsfilter'],
    'faq_recipes': ['Recipes & variants', 'Rezepte & Varianten'],
    'faq_cookbook': ['Cookbook', 'Kochbuch'],
    'faq_cooking': ['Cook mode', 'Kochmodus'],
    'faq_planning': ['Meal planning', 'Wochenplanung'],
    'faq_shopping': ['Shopping', 'Einkaufen'],
    'faq_backup': ['Backup', 'Sicherung'],
    'faq_troubleshooting': ['Troubleshooting', 'Fehlerbehebung'],
    'planner_title': [
      'a week, gently pencilled in',
      'eine Woche, sanft vorgemerkt',
    ],
    'week_of': ['Week of {date}', 'Woche ab {date}'],
    'breakfast': ['breakfast', 'Frühstück'],
    'lunch': ['lunch', 'Mittagessen'],
    'dinner': ['dinner', 'Abendessen'],
    'assign_recipe': ['Add a recipe', 'Rezept hinzufügen'],
    'empty_slot': ['a little blank space', 'noch etwas frei'],
    'from_cookbook': ['From cookbook', 'Aus dem Kochbuch'],
    'from_search': ['From search', 'Aus der Suche'],
    'planner_empty': [
      'This week is still a blank page. Tap a slot to begin.',
      'Diese Woche ist noch leer. Tippe auf ein Feld, um zu beginnen.',
    ],
    'export_week': [
      'Add this week to shopping',
      'Woche zum Einkauf hinzufügen',
    ],
    'week_exported': [
      'This week’s ingredients are on your shopping list.',
      'Die Zutaten dieser Woche sind auf deiner Einkaufsliste.',
    ],
    'clear_week': ['Clear this week', 'Diese Woche leeren'],
    'drag_hint': [
      'Hold and drag a recipe to move or swap it.',
      'Halte ein Rezept gedrückt und ziehe es zum Verschieben oder Tauschen.',
    ],
    'shopping_title': ['the market list', 'die Marktliste'],
    'shopping_empty': [
      'Your list is delightfully empty.',
      'Deine Liste ist noch wunderbar leer.',
    ],
    'shopping_empty_body': [
      'Add recipes from here, your cookbook, or a meal-plan week.',
      'Füge Rezepte von hier, aus dem Kochbuch oder aus dem Wochenplan hinzu.',
    ],
    'add_recipes': ['Add recipes', 'Rezepte hinzufügen'],
    'selected_recipes': [
      'On the list: {count} recipes',
      'Auf der Liste: {count} Rezepte',
    ],
    'checked_items': ['Already in the basket', 'Schon im Korb'],
    'clear_list': ['Clear list', 'Liste leeren'],
    'variety_score': ['ingredient variety', 'Zutatenvielfalt'],
    'variety_body': [
      'Unique ingredients added over time',
      'Verschiedene Zutaten im Laufe der Zeit',
    ],
    'top_ingredients': ['Most-added ingredients', 'Am häufigsten hinzugefügt'],
    'seasonal_breakdown': [
      'Your shopping by month',
      'Deine Einkäufe nach Monat',
    ],
    'no_insights': [
      'Add a recipe to your shopping list and your patterns will appear here.',
      'Füge ein Rezept zum Einkauf hinzu, dann erscheinen hier deine Muster.',
    ],
    'times_added': ['added {count}×', '{count}× hinzugefügt'],
    'ingredient_additions': [
      '{count} additions · {unique} unique',
      '{count} Einträge · {unique} verschiedene',
    ],
    'backup_title': ['take your cookbook with you', 'nimm dein Kochbuch mit'],
    'backup_body': [
      'Create human-readable JSON and a smaller GZip file, then save either or both from the system share sheet.',
      'Erzeuge lesbares JSON und eine kleinere GZip-Datei und speichere beide über das System-Teilen-Menü.',
    ],
    'backup_password': [
      'Password for encrypted JSON (optional)',
      'Passwort für verschlüsseltes JSON (optional)',
    ],
    'backup_password_hint': [
      'Leave blank for readable JSON',
      'Leer lassen für lesbares JSON',
    ],
    'gzip_unencrypted': [
      'The GZip copy stays unencrypted for compatibility, even when a password is set.',
      'Die GZip-Kopie bleibt aus Kompatibilitätsgründen unverschlüsselt, auch mit Passwort.',
    ],
    'export_backup': [
      'Create & share both files',
      'Beide Dateien erzeugen & teilen',
    ],
    'import_backup': ['Restore from a file', 'Aus Datei wiederherstellen'],
    'import_password_title': [
      'This backup is encrypted',
      'Diese Sicherung ist verschlüsselt',
    ],
    'import_password_hint': ['Backup password', 'Passwort der Sicherung'],
    'restore_choice_title': [
      'How should we restore it?',
      'Wie wiederherstellen?',
    ],
    'restore_merge': [
      'Merge with this cookbook',
      'Mit diesem Kochbuch vereinen',
    ],
    'restore_merge_body': [
      'Keep existing entries and add imported ones. Imported profile settings are used.',
      'Vorhandene Einträge behalten und importierte hinzufügen. Importierte Profileinstellungen werden verwendet.',
    ],
    'restore_replace': ['Replace local data', 'Lokale Daten ersetzen'],
    'restore_replace_body': [
      'Use exactly the profile and collections from this backup.',
      'Profil und Sammlungen genau aus dieser Sicherung übernehmen.',
    ],
    'restore_success': [
      'Your cookbook has been restored.',
      'Dein Kochbuch wurde wiederhergestellt.',
    ],
    'backup_created': [
      'Both backup files are ready to share.',
      'Beide Sicherungsdateien sind zum Teilen bereit.',
    ],
    'backup_error': [
      'The backup could not be completed.',
      'Die Sicherung konnte nicht abgeschlossen werden.',
    ],
    'invalid_backup': [
      'This file is not a valid MorphCook backup.',
      'Diese Datei ist keine gültige MorphCook-Sicherung.',
    ],
    'category_produce': ['Fruit & vegetables', 'Obst & Gemüse'],
    'aisle_produce': ['Fruit & vegetables', 'Obst & Gemüse'],
    'aisle_bakery': ['Bakery', 'Bäckerei'],
    'aisle_dairy': ['Dairy & alternatives', 'Milch & Alternativen'],
    'aisle_meat': ['Meat & proteins', 'Fleisch & Proteine'],
    'aisle_pantry': ['Pantry', 'Vorrat'],
    'aisle_frozen': ['Frozen', 'Tiefkühl'],
    'aisle_spices': ['Herbs & spices', 'Kräuter & Gewürze'],
    'unit_g': ['g', 'g'],
    'unit_kg': ['kg', 'kg'],
    'unit_ml': ['ml', 'ml'],
    'unit_l': ['l', 'l'],
    'unit_tsp': ['tsp', 'TL'],
    'unit_tbsp': ['tbsp', 'EL'],
    'unit_cup': ['cup', 'Tasse'],
    'unit_piece': ['pc', 'Stk.'],
    'unit_clove': ['cloves', 'Zehen'],
    'unit_slice': ['slices', 'Scheiben'],
    'unit_pinch': ['pinches', 'Prisen'],
    'unit_bunch': ['bunches', 'Bund'],
    'unit_can': ['cans', 'Dosen'],
    'unit_to-taste': ['to taste', 'nach Geschmack'],
    'tag_quick': ['quick', 'schnell'],
    'tag_comfort': ['comfort food', 'Comfort Food'],
    'tag_breakfast': ['breakfast', 'Frühstück'],
    'tag_dinner': ['dinner', 'Abendessen'],
    'tag_vegan': ['vegan', 'vegan'],
    'tag_vegetarian': ['vegetarian', 'vegetarisch'],
    'tag_keto': ['keto', 'keto'],
    'tag_gluten-free': ['gluten-free', 'glutenfrei'],
    'tag_high-protein': ['high protein', 'proteinreich'],
    'tag_comfort-food': ['comfort food', 'Comfort Food'],
    'tag_one-pan': ['one pan', 'eine Pfanne'],
    'tag_meal-prep': ['meal prep', 'Meal Prep'],
    'tag_italian': ['Italian', 'italienisch'],
    'tag_asian': ['Asian', 'asiatisch'],
    'tag_middle-eastern': ['Middle Eastern', 'nahöstlich'],
    'tag_family': ['family favorite', 'Familienliebling'],
    'tag_light': ['Light', 'Leicht'],
    'tag_regular': ['Regular', 'Klassisch'],
    'tag_easy': ['easy', 'einfach'],
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (item) => item.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String get lang => Localizations.localeOf(this).languageCode;
}
