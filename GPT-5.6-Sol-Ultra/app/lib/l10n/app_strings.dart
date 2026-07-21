import 'package:flutter/widgets.dart';

@immutable
class MorphStrings {
  const MorphStrings(this.languageCode);

  final String languageCode;

  String call(String key) =>
      (_values[key] ?? const {})[languageCode] ??
      (_values[key] ?? const {})['en'] ??
      key;

  String format(String key, Map<String, Object> values) {
    var value = call(key);
    for (final entry in values.entries) {
      value = value.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return value;
  }

  String plural(
    String key,
    num count, {
    Map<String, Object> values = const {},
  }) {
    final suffix = count == 1 ? 'one' : 'other';
    final pluralKey = _values.containsKey('$key.$suffix')
        ? '$key.$suffix'
        : key;
    return format(pluralKey, <String, Object>{'count': count, ...values});
  }

  String unit(String value, num quantity) {
    final suffix = quantity == 1 ? 'one' : 'other';
    final key = 'unit.$value.$suffix';
    return _values.containsKey(key) ? call(key) : option('unit', value);
  }

  /// Resolves a data-backed option without exposing its storage identifier.
  ///
  /// Known values live beside the rest of the copy in [_values]. Unknown
  /// values remain readable, which keeps custom aisles and future corpus
  /// values usable while their translations are being authored.
  String option(String namespace, String value) {
    final key = '$namespace.$value';
    final translations = _values[key];
    return translations?[languageCode] ??
        translations?['en'] ??
        value.replaceAll('-', ' ');
  }

  static MorphStrings of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_StringsScope>();
    return inherited?.strings ?? const MorphStrings('en');
  }

  static const supportedLocales = [Locale('en'), Locale('de')];

  static const Map<String, Map<String, String>> _values = {
    'app.tagline': {
      'en': 'a complete cookbook for the way you eat',
      'de': 'ein ganzes kochbuch für deine art zu essen',
    },
    'app.loading': {
      'en': 'opening the pantry…',
      'de': 'die speisekammer öffnet sich…',
    },
    'common.continue': {'en': 'continue', 'de': 'weiter'},
    'common.back': {'en': 'back', 'de': 'zurück'},
    'common.done': {'en': 'done', 'de': 'fertig'},
    'common.cancel': {'en': 'cancel', 'de': 'abbrechen'},
    'common.save': {'en': 'save', 'de': 'speichern'},
    'common.saved': {'en': 'saved', 'de': 'gespeichert'},
    'common.remove': {'en': 'remove', 'de': 'entfernen'},
    'common.edit': {'en': 'edit', 'de': 'bearbeiten'},
    'common.add': {'en': 'add', 'de': 'hinzufügen'},
    'common.retry': {'en': 'try again', 'de': 'noch einmal'},
    'common.search': {'en': 'search', 'de': 'suchen'},
    'common.clear': {'en': 'clear', 'de': 'leeren'},
    'common.close': {'en': 'close', 'de': 'schließen'},
    'common.minutes': {'en': 'min', 'de': 'min'},
    'common.servings': {'en': 'servings', 'de': 'portionen'},
    'common.servingCount.one': {
      'en': '{count} serving',
      'de': '{count} portion',
    },
    'common.servingCount.other': {
      'en': '{count} servings',
      'de': '{count} portionen',
    },
    'common.today': {'en': 'today', 'de': 'heute'},
    'common.week': {'en': 'week', 'de': 'woche'},
    'common.you': {'en': 'you', 'de': 'dich'},
    'common.all': {'en': 'all', 'de': 'alle'},
    'common.help': {'en': 'help', 'de': 'hilfe'},
    'common.unavailable': {'en': 'unavailable', 'de': 'nicht verfügbar'},
    'common.optional': {'en': 'optional', 'de': 'optional'},
    'common.previousWeek': {'en': 'previous week', 'de': 'vorherige woche'},
    'common.nextWeek': {'en': 'next week', 'de': 'nächste woche'},
    'common.saveToCookbook': {
      'en': 'save to cookbook',
      'de': 'im kochbuch speichern',
    },
    'common.removeFromCookbook': {
      'en': 'remove from cookbook',
      'de': 'aus dem kochbuch entfernen',
    },
    'common.fewerServings': {'en': 'fewer servings', 'de': 'weniger portionen'},
    'common.moreServings': {'en': 'more servings', 'de': 'mehr portionen'},
    'common.recipeMinutes': {'en': '{minutes} min', 'de': '{minutes} min'},
    'common.recipeMeta': {
      'en': '{minutes} min · {calories} kcal',
      'de': '{minutes} min · {calories} kcal',
    },
    'common.errorTitle': {
      'en': 'a little kitchen mishap',
      'de': 'ein kleines küchenmalheur',
    },
    'common.errorBody': {
      'en': 'Something went wrong while opening these recipes.',
      'de': 'Beim Öffnen dieser Rezepte ist etwas schiefgegangen.',
    },
    'common.onboardingProgress': {
      'en': 'onboarding progress',
      'de': 'fortschritt der einrichtung',
    },
    'common.noResults': {
      'en': 'Nothing matched this time.',
      'de': 'Diesmal gab es keinen Treffer.',
    },
    'onboarding.language.title': {
      'en': 'first, your language',
      'de': 'zuerst deine sprache',
    },
    'onboarding.language.body': {
      'en': 'Every recipe and every note can meet you in English or Deutsch.',
      'de':
          'Jedes Rezept und jede Notiz kann dich auf Deutsch oder Englisch begleiten.',
    },
    'onboarding.name.title': {
      'en': 'what shall we call you?',
      'de': 'wie dürfen wir dich nennen?',
    },
    'onboarding.name.hint': {'en': 'your name', 'de': 'dein name'},
    'onboarding.name.note': {
      'en': 'Only stored on this phone.',
      'de': 'Wird nur auf diesem Gerät gespeichert.',
    },
    'onboarding.diet.title': {
      'en': 'your table, your rules',
      'de': 'dein tisch, deine regeln',
    },
    'onboarding.diet.body': {
      'en':
          'Choose what belongs in your cookbook. No dish disappears—we show a complete version made for you.',
      'de':
          'Wähle, was in dein Kochbuch gehört. Kein Gericht verschwindet—du bekommst eine vollständige Version für dich.',
    },
    'onboarding.avoidClasses': {
      'en': 'avoid ingredient classes',
      'de': 'zutatenklassen vermeiden',
    },
    'onboarding.specific': {
      'en': 'anything else to avoid?',
      'de': 'noch etwas vermeiden?',
    },
    'onboarding.specificHint': {
      'en': 'try cilantro, apples, bell pepper…',
      'de': 'z. b. koriander, äpfel, paprika…',
    },
    'onboarding.goals.title': {
      'en': 'how do you cook lately?',
      'de': 'wie kochst du gerade?',
    },
    'onboarding.calories': {
      'en': 'calories per meal',
      'de': 'kalorien pro mahlzeit',
    },
    'onboarding.time': {'en': 'time budget', 'de': 'zeitbudget'},
    'onboarding.effort': {'en': 'usual effort', 'de': 'typischer aufwand'},
    'onboarding.confirm.title': {
      'en': 'this cookbook is yours',
      'de': 'dieses kochbuch gehört dir',
    },
    'onboarding.confirm.body': {
      'en':
          'Your feed will open with recipes that fit. You can change every choice at any time.',
      'de':
          'Dein Feed startet mit passenden Rezepten. Du kannst jede Wahl jederzeit ändern.',
    },
    'onboarding.noMatch': {
      'en':
          'No bundled recipe fits every current choice. Go back and give the time or calorie range a little more room.',
      'de':
          'Kein enthaltenes Rezept passt zu allen aktuellen Angaben. Geh zurück und gib Zeit oder Kalorienbereich etwas mehr Spielraum.',
    },
    'onboarding.start': {
      'en': 'open my cookbook',
      'de': 'mein kochbuch öffnen',
    },
    'onboarding.tape': {
      'en': 'a cookbook that fits',
      'de': 'ein kochbuch, das passt',
    },
    'onboarding.language.english': {'en': 'English', 'de': 'English'},
    'onboarding.language.german': {'en': 'Deutsch', 'de': 'Deutsch'},
    'onboarding.language.englishShort': {'en': 'EN', 'de': 'EN'},
    'onboarding.language.germanShort': {'en': 'DE', 'de': 'DE'},
    'language.en': {'en': 'English', 'de': 'English'},
    'language.de': {'en': 'Deutsch', 'de': 'Deutsch'},
    'onboarding.language.englishNote': {
      'en': 'recipes & notes',
      'de': 'rezepte & notizen',
    },
    'onboarding.language.germanNote': {
      'en': 'rezepte & notizen',
      'de': 'rezepte & notizen',
    },
    'onboarding.groupedIngredients': {
      'en': 'grouped ingredients: {count}',
      'de': 'gruppierte zutaten: {count}',
    },
    'onboarding.tolerance': {'en': 'tolerance', 'de': 'toleranz'},
    'diet.vegan': {'en': 'vegan', 'de': 'vegan'},
    'diet.vegetarian': {'en': 'vegetarian', 'de': 'vegetarisch'},
    'diet.pescatarian': {'en': 'pescatarian', 'de': 'pescetarisch'},
    'diet.halal': {'en': 'halal-compatible', 'de': 'halal-kompatibel'},
    'diet.kosher': {'en': 'kosher-compatible', 'de': 'koscher-kompatibel'},
    'diet.none': {'en': 'no set diet', 'de': 'keine feste ernährung'},
    'diet.classic': {'en': 'classic', 'de': 'klassisch'},
    'diet.gluten-free': {'en': 'gluten-free', 'de': 'glutenfrei'},
    'diet.keto': {'en': 'keto', 'de': 'keto'},
    'avoid.dairy': {'en': 'all dairy', 'de': 'alle milchprodukte'},
    'avoid.gluten': {'en': 'gluten', 'de': 'gluten'},
    'avoid.nuts': {'en': 'all nuts', 'de': 'alle nüsse'},
    'avoid.shellfish': {'en': 'all shellfish', 'de': 'alle schalentiere'},
    'avoid.molluscs': {'en': 'all shellfish', 'de': 'alle schalentiere'},
    'avoid.egg': {'en': 'egg', 'de': 'ei'},
    'avoid.soy': {'en': 'soy', 'de': 'soja'},
    'avoid.sesame': {'en': 'sesame', 'de': 'sesam'},
    'effort.easy': {'en': 'easy', 'de': 'einfach'},
    'effort.medium': {'en': 'medium', 'de': 'mittel'},
    'effort.hard': {'en': 'slow project', 'de': 'kochprojekt'},
    'nav.home': {'en': 'home', 'de': 'start'},
    'nav.search': {'en': 'search', 'de': 'suche'},
    'nav.cookbook': {'en': 'cookbook', 'de': 'kochbuch'},
    'nav.plan': {'en': 'plan', 'de': 'plan'},
    'nav.more': {'en': 'more', 'de': 'mehr'},
    'home.greeting': {'en': 'made for {name}', 'de': 'gemacht für {name}'},
    'home.featured': {
      'en': 'today’s front page',
      'de': 'heute auf der titelseite',
    },
    'home.weeknight': {'en': 'quiet weeknights', 'de': 'ruhige feierabende'},
    'home.rediscover': {'en': 'worth rediscovering', 'de': 'wiederzuentdecken'},
    'home.browseAll': {'en': 'browse all', 'de': 'alle ansehen'},
    'home.weeknightKicker': {
      'en': 'under 35 minutes',
      'de': 'unter 35 minuten',
    },
    'home.rediscoverKicker': {
      'en': 'a recipe for later',
      'de': 'ein rezept für später',
    },
    'home.outsideTarget': {
      'en': 'beyond today’s calorie range',
      'de': 'außerhalb des heutigen kalorienbereichs',
    },
    'home.outsideTargetKicker': {
      'en': 'safe versions you can open explicitly',
      'de': 'passende versionen zum bewussten öffnen',
    },
    'home.noMatchesTitle': {
      'en': 'your settings need a little more room',
      'de': 'deine einstellungen brauchen etwas mehr spielraum',
    },
    'home.noMatchesBody': {
      'en':
          'No bundled recipe fits every current limit. Adjust your time, calorie range, or dietary choices to reopen the cookbook.',
      'de':
          'Kein enthaltenes Rezept passt zu allen aktuellen Grenzen. Passe Zeit, Kalorienbereich oder Ernährung an, um das Kochbuch wieder zu öffnen.',
    },
    'home.adjustProfile': {'en': 'adjust my profile', 'de': 'profil anpassen'},
    'home.todayPick': {'en': 'today’s pick', 'de': 'heutige empfehlung'},
    'home.mastheadLine': {
      'en': '& every recipe belongs to you',
      'de': '& jedes rezept gehört dir',
    },
    'search.title': {'en': 'find a dish', 'de': 'gericht finden'},
    'search.hint': {
      'en': 'dish, ingredient, cuisine…',
      'de': 'gericht, zutat, küche…',
    },
    'search.filters': {'en': 'filters', 'de': 'filter'},
    'search.results': {'en': '{count} recipes', 'de': '{count} rezepte'},
    'search.results.one': {'en': '{count} recipe', 'de': '{count} rezept'},
    'search.results.other': {'en': '{count} recipes', 'de': '{count} rezepte'},
    'search.noResultsTitle': {
      'en': 'not in the pantry—yet',
      'de': 'noch nicht in der speisekammer',
    },
    'search.noResultsBody': {
      'en':
          'We saved this search locally so it can travel with your next backup.',
      'de':
          'Diese Suche wurde lokal gespeichert und reist mit deinem nächsten Backup mit.',
    },
    'filter.tag.quick': {'en': 'quick', 'de': 'schnell'},
    'filter.tag.comfort-food': {'en': 'comfort food', 'de': 'wohlfühlküche'},
    'filter.tag.plant-based': {'en': 'plant-based', 'de': 'pflanzlich'},
    'filter.cuisine.italian-inspired': {
      'en': 'Italian-inspired',
      'de': 'italienisch inspiriert',
    },
    'filter.cuisine.southeast-asian': {
      'en': 'Southeast Asian',
      'de': 'südostasiatisch',
    },
    'filter.cuisine.middle-eastern-inspired': {
      'en': 'Middle Eastern-inspired',
      'de': 'nahöstlich inspiriert',
    },
    'cookbook.title': {'en': 'your cookbook', 'de': 'dein kochbuch'},
    'cookbook.emptyTitle': {
      'en': 'your pages are waiting',
      'de': 'deine seiten warten',
    },
    'cookbook.emptyBody': {
      'en':
          'Save the exact version you love. Your vegan Döner and your easy Alfredo stay just as chosen.',
      'de':
          'Speichere genau deine Version. Dein veganer Döner und deine einfache Alfredo bleiben genau so.',
    },
    'cookbook.savedCount': {
      'en': 'saved: {count}',
      'de': 'gespeichert: {count}',
    },
    'dish.ingredients': {'en': 'ingredients', 'de': 'zutaten'},
    'dish.method': {'en': 'method', 'de': 'zubereitung'},
    'dish.nutrition': {'en': 'nutrition', 'de': 'nährwerte'},
    'dish.diet': {'en': 'diet', 'de': 'ernährung'},
    'dish.effort': {'en': 'effort', 'de': 'aufwand'},
    'dish.calories': {'en': 'calorie level', 'de': 'kalorien'},
    'dish.noCombo': {
      'en': 'This combination is not written yet.',
      'de': 'Diese Kombination ist noch nicht geschrieben.',
    },
    'dish.outsideChoice': {
      'en': 'This version is outside your calorie target.',
      'de': 'Diese Version liegt außerhalb deines Kalorienziels.',
    },
    'dish.outsideTarget': {
      'en': 'show versions outside my calorie target',
      'de': 'versionen außerhalb meines kalorienziels zeigen',
    },
    'dish.noSafeVariant': {
      'en':
          'No version of this dish fits your current dietary and time settings.',
      'de':
          'Keine Version dieses Gerichts passt zu deinen Ernährungs- und Zeiteinstellungen.',
    },
    'dish.outsidePromptTitle': {
      'en': 'outside your calorie target',
      'de': 'außerhalb deines kalorienziels',
    },
    'dish.outsidePromptBody': {
      'en':
          'This dish has no version inside your calorie range. Show its other safe versions anyway?',
      'de':
          'Für dieses Gericht gibt es keine Version in deinem Kalorienbereich. Trotzdem die anderen passenden Versionen anzeigen?',
    },
    'dish.outsidePromptConfirm': {
      'en': 'show versions',
      'de': 'versionen anzeigen',
    },
    'dish.learnMore': {'en': 'learn more', 'de': 'mehr erfahren'},
    'dish.startCooking': {'en': 'start cooking', 'de': 'kochen starten'},
    'dish.addShopping': {
      'en': 'add to shopping list',
      'de': 'zur einkaufsliste',
    },
    'dish.optional': {'en': 'optional', 'de': 'optional'},
    'dish.timerMinutes': {
      'en': '{minutes} min timer',
      'de': '{minutes}-min-timer',
    },
    'nutrition.energy': {'en': 'energy', 'de': 'energie'},
    'nutrition.protein': {'en': 'protein', 'de': 'eiweiß'},
    'nutrition.carbs': {'en': 'carbs', 'de': 'kohlenhydrate'},
    'nutrition.fat': {'en': 'fat', 'de': 'fett'},
    'plan.title': {'en': 'the week ahead', 'de': 'die kommende woche'},
    'plan.breakfast': {'en': 'breakfast', 'de': 'frühstück'},
    'plan.lunch': {'en': 'lunch', 'de': 'mittag'},
    'plan.dinner': {'en': 'dinner', 'de': 'abendessen'},
    'plan.emptySlot': {'en': 'add a recipe', 'de': 'rezept hinzufügen'},
    'plan.toShopping': {
      'en': 'week to shopping list',
      'de': 'woche zur einkaufsliste',
    },
    'shopping.title': {'en': 'shopping list', 'de': 'einkaufsliste'},
    'shopping.emptyTitle': {
      'en': 'the basket is light',
      'de': 'der korb ist leicht',
    },
    'shopping.emptyBody': {
      'en':
          'Add a recipe or your own pantry note. Matching units will gather themselves together.',
      'de':
          'Füge ein Rezept oder eine eigene Notiz hinzu. Passende Einheiten werden automatisch zusammengefasst.',
    },
    'shopping.addItem': {'en': 'add an item', 'de': 'eintrag hinzufügen'},
    'shopping.clearChecked': {'en': 'clear checked', 'de': 'erledigte löschen'},
    'shopping.item': {'en': 'item', 'de': 'eintrag'},
    'shopping.amount': {'en': 'amount', 'de': 'menge'},
    'shopping.unit': {'en': 'unit', 'de': 'einheit'},
    'shopping.aisle': {'en': 'aisle', 'de': 'abteilung'},
    'shopping.itemCount': {'en': 'items: {count}', 'de': 'einträge: {count}'},
    'shopping.itemCount.one': {'en': 'item: {count}', 'de': 'eintrag: {count}'},
    'shopping.itemCount.other': {
      'en': 'items: {count}',
      'de': 'einträge: {count}',
    },
    'shopping.recipeCount': {
      'en': 'recipes: {count}',
      'de': 'rezepte: {count}',
    },
    'shopping.recipeCount.one': {
      'en': 'recipe: {count}',
      'de': 'rezept: {count}',
    },
    'shopping.recipeCount.other': {
      'en': 'recipes: {count}',
      'de': 'rezepte: {count}',
    },
    'unit.piece': {'en': 'piece', 'de': 'stück'},
    'unit.g': {'en': 'g', 'de': 'g'},
    'unit.kg': {'en': 'kg', 'de': 'kg'},
    'unit.ml': {'en': 'ml', 'de': 'ml'},
    'unit.l': {'en': 'l', 'de': 'l'},
    'unit.tbsp': {'en': 'tbsp', 'de': 'EL'},
    'unit.tsp': {'en': 'tsp', 'de': 'TL'},
    'unit.clove': {'en': 'clove', 'de': 'zehe'},
    'unit.bunch': {'en': 'bunch', 'de': 'bund'},
    'unit.sheet': {'en': 'sheet', 'de': 'blatt'},
    'unit.sprig': {'en': 'sprig', 'de': 'zweig'},
    'unit.piece.one': {'en': 'piece', 'de': 'stück'},
    'unit.piece.other': {'en': 'pieces', 'de': 'stück'},
    'unit.clove.one': {'en': 'clove', 'de': 'zehe'},
    'unit.clove.other': {'en': 'cloves', 'de': 'zehen'},
    'unit.bunch.one': {'en': 'bunch', 'de': 'bund'},
    'unit.bunch.other': {'en': 'bunches', 'de': 'bünde'},
    'unit.sheet.one': {'en': 'sheet', 'de': 'blatt'},
    'unit.sheet.other': {'en': 'sheets', 'de': 'blätter'},
    'unit.sprig.one': {'en': 'sprig', 'de': 'zweig'},
    'unit.sprig.other': {'en': 'sprigs', 'de': 'zweige'},
    'aisle.produce': {'en': 'fruit & vegetables', 'de': 'obst & gemüse'},
    'aisle.bakery': {'en': 'bakery', 'de': 'backwaren'},
    'aisle.dairy': {'en': 'dairy', 'de': 'milchprodukte'},
    'aisle.meat & fish': {'en': 'meat & fish', 'de': 'fleisch & fisch'},
    'aisle.pantry': {'en': 'pantry', 'de': 'vorrat'},
    'aisle.spices': {'en': 'spices', 'de': 'gewürze'},
    'aisle.frozen': {'en': 'frozen', 'de': 'tiefkühlkost'},
    'aisle.drinks': {'en': 'drinks', 'de': 'getränke'},
    'aisle.other': {'en': 'other', 'de': 'sonstiges'},
    'aisle.beverages': {'en': 'beverages', 'de': 'getränke'},
    'aisle.canned-goods': {'en': 'canned goods', 'de': 'konserven'},
    'aisle.condiments': {'en': 'condiments', 'de': 'würzmittel'},
    'aisle.dairy-eggs': {'en': 'dairy & eggs', 'de': 'milchprodukte & eier'},
    'aisle.dry-goods': {'en': 'dry goods', 'de': 'trockenvorrat'},
    'aisle.international': {
      'en': 'international',
      'de': 'internationale küche',
    },
    'aisle.meat-seafood': {'en': 'meat & seafood', 'de': 'fleisch & fisch'},
    'aisle.refrigerated': {'en': 'refrigerated', 'de': 'kühlregal'},
    'settings.title': {
      'en': 'more from your kitchen',
      'de': 'mehr aus deiner küche',
    },
    'settings.profile': {'en': 'profile & matching', 'de': 'profil & auswahl'},
    'settings.aboutYou': {'en': 'about you', 'de': 'über dich'},
    'settings.profileSummary': {
      'en': '{calories} kcal · {minutes} min · {effort}',
      'de': '{calories} kcal · {minutes} min · {effort}',
    },
    'settings.appearance': {
      'en': 'comfort & motion',
      'de': 'komfort & bewegung',
    },
    'settings.language': {'en': 'language', 'de': 'sprache'},
    'settings.variantTags': {
      'en': 'show variant tags',
      'de': 'varianten-tags zeigen',
    },
    'settings.reduceMotion': {
      'en': 'reduce motion',
      'de': 'bewegung reduzieren',
    },
    'settings.visualAlerts': {
      'en': 'visual timer alerts',
      'de': 'visuelle timer-hinweise',
    },
    'settings.quickTap': {'en': 'one-tap next step', 'de': 'mit tippen weiter'},
    'settings.quickTapBody': {
      'en':
          'In cook mode, tap the step once to advance. Includes a short safety debounce.',
      'de':
          'Im Kochmodus bringt ein Tippen dich zum nächsten Schritt. Mit kurzer Sicherheitspause.',
    },
    'settings.compatibleNote': {
      'en':
          'Halal- and kosher-compatible refer to ingredients only, never certification or sourcing.',
      'de':
          'Halal- und koscher-kompatibel bezieht sich nur auf Zutaten, nie auf Zertifizierung oder Herkunft.',
    },
    'settings.backup': {
      'en': 'backup & restore',
      'de': 'sichern & wiederherstellen',
    },
    'settings.export': {
      'en': 'export both backup files',
      'de': 'beide sicherungsdateien exportieren',
    },
    'settings.import': {
      'en': 'restore from a file',
      'de': 'aus datei wiederherstellen',
    },
    'settings.password': {
      'en': 'optional password',
      'de': 'optionales passwort',
    },
    'settings.followPhone': {
      'en': 'Following the phone setting',
      'de': 'Folgt der telefoneinstellung',
    },
    'settings.backupKicker': {
      'en': 'human-readable · portable · yours',
      'de': 'lesbar · übertragbar · deins',
    },
    'settings.exportFormat': {
      'en': 'JSON + GZip · optional AES-256-GCM',
      'de': 'JSON + GZip · wahlweise AES-256-GCM',
    },
    'settings.importFormat': {
      'en': 'JSON · GZip · encrypted JSON',
      'de': 'JSON · GZip · verschlüsseltes JSON',
    },
    'settings.libraryHelp': {
      'en': 'library & help',
      'de': 'bibliothek & hilfe',
    },
    'settings.insightsBody': {
      'en': 'See variety and seasonal patterns',
      'de': 'Vielfalt und saisonale Muster ansehen',
    },
    'settings.compatibleLearnMore': {
      'en': 'Open the help center for details.',
      'de': 'Details findest du im Hilfe-Center.',
    },
    'settings.versionFooter': {
      'en': 'MorphCook · v1.0.0\nmade to stay offline',
      'de': 'MorphCook · v1.0.0\nfürs Offlinebleiben gemacht',
    },
    'settings.exportExplanation': {
      'en':
          'Both files will be shared. A password encrypts the readable JSON; the smaller GZip remains compatible and unencrypted.',
      'de':
          'Beide Dateien werden geteilt. Ein Passwort verschlüsselt die lesbare JSON-Datei; die kleinere GZip-Datei bleibt kompatibel und unverschlüsselt.',
    },
    'settings.showPassword': {'en': 'show password', 'de': 'passwort anzeigen'},
    'settings.hidePassword': {
      'en': 'hide password',
      'de': 'passwort ausblenden',
    },
    'settings.insights': {
      'en': 'shopping insights',
      'de': 'einkaufs-einblicke',
    },
    'settings.faq': {'en': 'help center', 'de': 'hilfe-center'},
    'settings.history': {'en': 'cooking history', 'de': 'kochverlauf'},
    'settings.offline': {
      'en': 'Offline by design · no account · no telemetry',
      'de': 'Absichtlich offline · kein Konto · kein Tracking',
    },
    'faq.title': {'en': 'help center', 'de': 'hilfe-center'},
    'faq.hint': {'en': 'search a question…', 'de': 'frage durchsuchen…'},
    'faq.category.dietary-matching': {
      'en': 'dietary matching',
      'de': 'ernährungsabgleich',
    },
    'faq.category.dietary': {'en': 'dietary choices', 'de': 'ernährung'},
    'faq.category.matching': {'en': 'recipe matching', 'de': 'rezeptabgleich'},
    'faq.category.recipe-visibility': {
      'en': 'recipe visibility',
      'de': 'rezeptanzeige',
    },
    'faq.category.features': {'en': 'features', 'de': 'funktionen'},
    'faq.category.troubleshooting': {
      'en': 'troubleshooting',
      'de': 'problemlösung',
    },
    'faq.category.privacy-data': {
      'en': 'privacy & data',
      'de': 'datenschutz & daten',
    },
    'faq.category.privacy': {'en': 'privacy', 'de': 'datenschutz'},
    'faq.backupQuery': {'en': 'backup', 'de': 'sicherung'},
    'insights.title': {'en': 'shopping insights', 'de': 'einkaufs-einblicke'},
    'insights.variety': {'en': 'variety score', 'de': 'vielfaltswert'},
    'insights.unique': {
      'en': '{count} unique ingredients',
      'de': '{count} verschiedene zutaten',
    },
    'insights.unique.one': {
      'en': '{count} unique ingredient',
      'de': '{count} verschiedene zutat',
    },
    'insights.unique.other': {
      'en': '{count} unique ingredients',
      'de': '{count} verschiedene zutaten',
    },
    'insights.top': {'en': 'most gathered', 'de': 'am häufigsten gesammelt'},
    'insights.seasonal': {
      'en': 'the year by basket',
      'de': 'das jahr im einkaufskorb',
    },
    'insights.topKicker': {
      'en': 'your repeat pantry companions',
      'de': 'deine treuen vorratsbegleiter',
    },
    'insights.seasonalKicker': {
      'en': 'additions by month',
      'de': 'hinzugefügt pro monat',
    },
    'insights.monthAdditions': {
      'en': '{month}, additions: {count}',
      'de': '{month}, hinzugefügt: {count}',
    },
    'history.title': {'en': 'cooking history', 'de': 'kochverlauf'},
    'cook.step': {
      'en': 'step {current} of {total}',
      'de': 'schritt {current} von {total}',
    },
    'cook.pause': {'en': 'pause', 'de': 'pause'},
    'cook.resume': {'en': 'resume', 'de': 'weiter'},
    'cook.previous': {'en': 'previous', 'de': 'zurück'},
    'cook.next': {'en': 'next', 'de': 'weiter'},
    'cook.finish': {'en': 'finish', 'de': 'abschließen'},
    'cook.completeTitle': {'en': 'you made it', 'de': 'du hast es gekocht'},
    'cook.completeBody': {
      'en': 'Another recipe now has a memory attached to it.',
      'de': 'An diesem Rezept hängt jetzt eine neue Erinnerung.',
    },
    'cook.timer': {'en': 'step timer', 'de': 'schritt-timer'},
    'cook.tapNextHint': {
      'en': 'Tap once to move to the next step',
      'de': 'Einmal tippen, um zum nächsten Schritt zu gelangen',
    },
    'cook.resetTimer': {'en': 'reset timer', 'de': 'timer zurücksetzen'},
    'cook.timerComplete': {'en': 'timer complete', 'de': 'timer abgelaufen'},
    'cook.tapDismiss': {'en': 'tap to dismiss', 'de': 'zum schließen tippen'},
    'backup.restoreChoiceBody': {
      'en':
          'Merge keeps local items and adds the backup. Replace uses the backup as your new local library.',
      'de':
          'Zusammenführen behält lokale Einträge und ergänzt die Sicherung. Ersetzen macht die Sicherung zu deiner neuen lokalen Bibliothek.',
    },
    'backup.shareTitle': {
      'en': 'MorphCook backup',
      'de': 'MorphCook-Sicherung',
    },
    'backup.shareText': {
      'en': 'Your offline MorphCook backup files.',
      'de': 'Deine lokalen MorphCook-Sicherungsdateien.',
    },
    'backup.replace': {'en': 'replace', 'de': 'ersetzen'},
    'backup.merge': {'en': 'merge', 'de': 'zusammenführen'},
    'backup.restoreSuccess': {
      'en':
          'Restored — saved recipes: {saved}, meals: {meals}, shopping items: {shopping}.',
      'de':
          'Wiederhergestellt — gespeicherte Rezepte: {saved}, Mahlzeiten: {meals}, Einkaufseinträge: {shopping}.',
    },
    'backup.encryptedTitle': {
      'en': 'encrypted backup',
      'de': 'verschlüsselte sicherung',
    },
    'backup.decryptFailedTitle': {
      'en': 'could not decrypt',
      'de': 'entschlüsselung fehlgeschlagen',
    },
    'backup.passwordRequired': {
      'en': 'This backup is encrypted. Please enter its password.',
      'de': 'Diese Sicherung ist verschlüsselt. Bitte gib ihr Passwort ein.',
    },
    'backup.incorrectPassword': {
      'en': 'Incorrect password. Please try again.',
      'de': 'Falsches Passwort. Bitte versuche es erneut.',
    },
    'backup.corrupted': {
      'en': 'Backup file is corrupted and cannot be restored.',
      'de':
          'Die Sicherungsdatei ist beschädigt und kann nicht wiederhergestellt werden.',
    },
    'backup.invalid': {
      'en': 'This file is not a valid MorphCook backup.',
      'de': 'Diese Datei ist keine gültige MorphCook-Sicherung.',
    },
    'backup.unreadable': {
      'en': 'The selected backup file could not be read.',
      'de': 'Die ausgewählte Sicherungsdatei konnte nicht gelesen werden.',
    },
    'backup.unsupported': {
      'en': 'This backup version is not supported.',
      'de': 'Diese Sicherungsversion wird nicht unterstützt.',
    },
    'backup.unexpected': {
      'en': 'The backup could not be completed.',
      'de': 'Die Sicherung konnte nicht abgeschlossen werden.',
    },
    'ingredientGuide.storage': {'en': 'keep it', 'de': 'aufbewahren'},
    'ingredientGuide.usage': {'en': 'use it', 'de': 'verwenden'},
    'ingredientGuide.find': {'en': 'find it', 'de': 'finden'},
  };
}

class MorphStringsScope extends StatelessWidget {
  const MorphStringsScope({
    required this.languageCode,
    required this.child,
    super.key,
  });

  final String languageCode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _StringsScope(strings: MorphStrings(languageCode), child: child);
  }
}

class _StringsScope extends InheritedWidget {
  const _StringsScope({required this.strings, required super.child});

  final MorphStrings strings;

  @override
  bool updateShouldNotify(_StringsScope oldWidget) =>
      oldWidget.strings.languageCode != strings.languageCode;
}

extension MorphStringsContext on BuildContext {
  MorphStrings get strings => MorphStrings.of(this);
}
