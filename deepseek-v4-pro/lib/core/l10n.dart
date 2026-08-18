import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Language state. Data model is N-language-ready: every user-visible
/// corpus text is Map of lang to String; UI chrome lives in [_table].
class LocaleController extends ChangeNotifier {
  LocaleController(this._prefs) : lang = _prefs.getString('lang') ?? 'en';

  final SharedPreferences _prefs;
  String lang;

  static const supported = ['en', 'de'];

  void setLang(String value) {
    if (!supported.contains(value) || value == lang) return;
    lang = value;
    _prefs.setString('lang', value);
    notifyListeners();
  }

  /// Data-map accessor: m[lang] with fallback to en.
  String pick(Map<String, String> m) => m[lang] ?? m['en'] ?? '';

  /// UI-chrome string lookup.
  String t(String key) =>
      _table[key]?[lang] ?? _table[key]?['en'] ?? key;
}

const _table = <String, Map<String, String>>{
  'appName': {'en': 'MorphCook', 'de': 'MorphCook'},
  'mastheadSubtitle': {
    'en': 'the same dish exists for every body',
    'de': 'dasselbe Gericht existiert für jeden Körper',
  },
  'ok': {'en': 'ok', 'de': 'ok'},
  'cancel': {'en': 'cancel', 'de': 'abbrechen'},
  'save': {'en': 'save', 'de': 'speichern'},
  'delete': {'en': 'delete', 'de': 'löschen'},
  'back': {'en': 'back', 'de': 'zurück'},
  'next': {'en': 'next', 'de': 'weiter'},
  'done': {'en': 'done', 'de': 'fertig'},
  'skip': {'en': 'skip', 'de': 'überspringen'},
  'close': {'en': 'close', 'de': 'schließen'},
  'confirm': {'en': 'confirm', 'de': 'bestätigen'},
  'edit': {'en': 'edit', 'de': 'bearbeiten'},
  'add': {'en': 'add', 'de': 'hinzufügen'},
  'remove': {'en': 'remove', 'de': 'entfernen'},
  'yes': {'en': 'yes', 'de': 'ja'},
  'no': {'en': 'no', 'de': 'nein'},
  'continue': {'en': 'continue', 'de': 'weiter'},
  'of': {'en': 'of', 'de': 'von'},
  'servings': {'en': 'servings', 'de': 'Portionen'},
  'minutes': {'en': 'min', 'de': 'Min.'},
  'kcal': {'en': 'kcal', 'de': 'kcal'},
  'loading': {'en': 'loading…', 'de': 'lädt…'},
  'empty': {'en': 'nothing here yet', 'de': 'hier ist noch nichts'},
  'search': {'en': 'search', 'de': 'suchen'},

  // Tabs
  'tabHome': {'en': 'home', 'de': 'start'},
  'tabSearch': {'en': 'search', 'de': 'suche'},
  'tabCookbook': {'en': 'cookbook', 'de': 'kochbuch'},
  'tabPlanner': {'en': 'planner', 'de': 'planer'},
  'tabShopping': {'en': 'shopping', 'de': 'einkauf'},
  'tabSettings': {'en': 'settings', 'de': 'einstellungen'},

  // Onboarding
  'obWelcome': {
    'en': 'your cookbook, written for you',
    'de': 'dein Kochbuch, für dich geschrieben',
  },
  'obWelcomeSub': {
    'en':
        'most apps filter recipes away from you. we wrote a full cookbook for every way of eating — yours included.',
    'de':
        'die meisten Apps filtern Rezepte von dir weg. wir haben ein vollständiges Kochbuch für jede Ernährungsweise geschrieben — auch deine.',
  },
  'obStep1': {'en': 'first, the language', 'de': 'zuerst die Sprache'},
  'obLanguageHint': {
    'en': 'pick your language — everything switches instantly.',
    'de': 'wähle deine Sprache — alles wechselt sofort.',
  },
  'obStep2': {'en': 'what should we call you?', 'de': 'wie sollen wir dich nennen?'},
  'obNameHint': {
    'en': 'it stays on this phone. no accounts, ever.',
    'de': 'sie bleibt auf diesem Gerät. keine Konten, niemals.',
  },
  'obNameField': {'en': 'your name', 'de': 'dein Name'},
  'obStep3': {
    'en': 'how do you eat?',
    'de': 'wie isst du?',
  },
  'obDietHint': {
    'en': 'these expand into avoids automatically. pick as many as you like.',
    'de':
        'diese werden automatisch zu Vermeidungen erweitert. wähle so viele, wie du möchtest.',
  },
  'obAvoidTitle': {'en': 'anything else to avoid?', 'de': 'noch etwas zu vermeiden?'},
  'obAvoidHint': {
    'en':
        'allergies & dislikes — search any ingredient. avoiding “nuts” excludes every nut.',
    'de':
        'allergien & abneigungen — suche jede zutat. wer „nüsse“ vermeidet, schließt alle nüsse aus.',
  },
  'obSpecificPlaceholder': {
    'en': 'e.g. apples, cilantro, bell pepper',
    'de': 'z. B. Äpfel, Koriander, Paprika',
  },
  'obStep4': {
    'en': 'calories & time',
    'de': 'kalorien & zeit',
  },
  'obCalorieHint': {
    'en': 'per-meal target — a hard filter with a little tolerance.',
    'de': 'ziel pro mahlzeit — ein harter filter mit etwas toleranz.',
  },
  'obTimeHint': {
    'en': 'the longest you want to cook, ever.',
    'de': 'die längste zeit, die du je kochen willst.',
  },
  'obEffortHint': {
    'en': 'how ambitious do you feel on a normal day?',
    'de': 'wie ambitioniert fühlst du dich an einem normalen tag?',
  },
  'obStep5': {'en': 'that is everything', 'de': 'das ist alles'},
  'obConfirmSub': {
    'en': 'from here on, the machinery is invisible. you just see your cookbook.',
    'de': 'ab jetzt ist die maschinerie unsichtbar. du siehst nur dein kochbuch.',
  },
  'obStart': {'en': 'open my cookbook', 'de': 'mein kochbuch öffnen'},
  'obBack': {'en': 'back', 'de': 'zurück'},

  // Diets (compound avoid-flags)
  'diet.vegan': {'en': 'vegan', 'de': 'vegan'},
  'diet.vegetarian': {'en': 'vegetarian', 'de': 'vegetarisch'},
  'diet.pescatarian': {'en': 'pescatarian', 'de': 'pescetarisch'},
  'diet.halal': {'en': 'halal', 'de': 'halal'},
  'diet.kosher': {'en': 'kosher', 'de': 'koscher'},
  'diet.low-fodmap': {'en': 'low-fodmap', 'de': 'low-fodmap'},
  'diet.sugar-free': {'en': 'sugar-free', 'de': 'zuckerfrei'},
  'diet.lactose-free': {'en': 'lactose-free', 'de': 'laktosefrei'},
  'diet.none': {'en': 'no restrictions', 'de': 'keine einschränkungen'},

  // Home
  'homeFeatured': {'en': 'featured dish', 'de': 'gericht des tages'},
  'homeForYou': {'en': 'for you right now', 'de': 'gerade jetzt für dich'},
  'homeQuick': {'en': 'quick & easy', 'de': 'schnell & einfach'},
  'homeWeekend': {'en': 'for the weekend', 'de': 'fürs wochenende'},
  'homeDiscover': {'en': 'wander the cuisines', 'de': 'durch die küchen streifen'},
  'homeSeeAll': {'en': 'see all', 'de': 'alle ansehen'},
  'homeGreeting': {'en': 'good appetite', 'de': 'guten appetit'},
  'homeVariants': {'en': 'variants', 'de': 'varianten'},

  // Dish detail
  'dishDiet': {'en': 'diet', 'de': 'ernährung'},
  'dishEffort': {'en': 'effort', 'de': 'aufwand'},
  'dishCalorieLevel': {'en': 'calorie level', 'de': 'kalorienstufe'},
  'dishIngredients': {'en': 'ingredients', 'de': 'zutaten'},
  'dishMethod': {'en': 'method', 'de': 'zubereitung'},
  'dishMacros': {'en': 'macros', 'de': 'makros'},
  'dishNoCombo': {
    'en': 'no {a} × {b} version yet',
    'de': 'noch keine {a} × {b}-Version',
  },
  'dishOverride': {'en': 'show outside my calorie target', 'de': 'außerhalb meines kalorienziels zeigen'},
  'dishOverrideSub': {
    'en': 'sometimes a birthday demands tiramisu.',
    'de': 'manchmal verlangt ein geburtstag tiramisu.',
  },
  'dishYourVersion': {'en': 'your version', 'de': 'deine version'},
  'dishSave': {'en': 'save to cookbook', 'de': 'ins kochbuch speichern'},
  'dishSaved': {'en': 'saved — your {name}', 'de': 'gespeichert — dein {name}'},
  'dishCook': {'en': 'cook this', 'de': 'jetzt kochen'},
  'dishLearnMore': {'en': 'learn more', 'de': 'mehr erfahren'},
  'dishAddShopping': {'en': 'add to shopping list', 'de': 'zur einkaufsliste'},
  'dishAddedShopping': {'en': 'added to shopping list', 'de': 'zur einkaufsliste hinzugefügt'},
  'dishSwapFlash': {'en': 'changed ingredients highlighted', 'de': 'geänderte zutaten hervorgehoben'},
  'protein': {'en': 'protein', 'de': 'eiweiß'},
  'carbs': {'en': 'carbs', 'de': 'kohlenhydrate'},
  'fat': {'en': 'fat', 'de': 'fett'},
  'ingredientGuide': {'en': 'kitchen reference', 'de': 'küchen-lexikon'},
  'guideUse': {'en': 'how to use it', 'de': 'so benutzt du es'},
  'guideStore': {'en': 'storage', 'de': 'aufbewahrung'},
  'guideFind': {'en': 'where to find it', 'de': 'wo du es findest'},

  // Effort / buckets / meal types
  'effort.easy': {'en': 'easy', 'de': 'einfach'},
  'effort.medium': {'en': 'medium', 'de': 'mittel'},
  'effort.hard': {'en': 'pro', 'de': 'profi'},
  'time.le15': {'en': '≤ 15 min', 'de': '≤ 15 min'},
  'time.le30': {'en': '≤ 30 min', 'de': '≤ 30 min'},
  'time.le60': {'en': '≤ 60 min', 'de': '≤ 60 min'},
  'time.gt60': {'en': '> 60 min', 'de': '> 60 min'},
  'cal.le400': {'en': '≤ 400 kcal', 'de': '≤ 400 kcal'},
  'cal.le600': {'en': '≤ 600 kcal', 'de': '≤ 600 kcal'},
  'cal.le800': {'en': '≤ 800 kcal', 'de': '≤ 800 kcal'},
  'cal.gt800': {'en': '> 800 kcal', 'de': '> 800 kcal'},
  'meal.breakfast': {'en': 'breakfast', 'de': 'frühstück'},
  'meal.lunch': {'en': 'lunch', 'de': 'mittag'},
  'meal.dinner': {'en': 'dinner', 'de': 'abendessen'},
  'meal.snack': {'en': 'snack', 'de': 'snack'},
  'meal.any': {'en': 'anytime', 'de': 'jederzeit'},
  'tag.street-food': {'en': 'street food', 'de': 'street food'},
  'tag.plant-based': {'en': 'plant-based', 'de': 'pflanzlich'},
  'tag.gluten-free': {'en': 'gluten-free', 'de': 'glutenfrei'},
  'tag.keto': {'en': 'keto', 'de': 'keto'},
  'tag.low-carb': {'en': 'low-carb', 'de': 'low-carb'},
  'tag.comfort': {'en': 'comfort', 'de': 'komfort'},
  'tag.weekend': {'en': 'weekend', 'de': 'wochenende'},
  'tag.weekend-project': {'en': 'weekend project', 'de': 'wochenendprojekt'},
  'tag.quick': {'en': 'quick', 'de': 'schnell'},
  'tag.breakfast': {'en': 'breakfast', 'de': 'frühstück'},
  'tag.family': {'en': 'family', 'de': 'familie'},
  'tag.sunday': {'en': 'sunday', 'de': 'sonntag'},
  'tag.soup': {'en': 'soup', 'de': 'suppe'},
  'tag.dessert': {'en': 'dessert', 'de': 'dessert'},
  'tag.no-bake': {'en': 'no-bake', 'de': 'ohne backen'},
  'tag.one-pan': {'en': 'one pan', 'de': 'eine pfanne'},
  'tag.spread': {'en': 'spread', 'de': 'aufstrich'},
  'tag.wok': {'en': 'wok', 'de': 'wok'},
  'tag.roman': {'en': 'roman', 'de': 'römisch'},
  'tag.neapolitan': {'en': 'neapolitan', 'de': 'neapolitanisch'},
  'tag.japanese': {'en': 'japanese', 'de': 'japanisch'},
  'tag.takeout-at-home': {'en': 'takeout at home', 'de': 'takeout daheim'},
  'tag.halal': {'en': 'halal-compatible', 'de': 'halal-kompatibel'},
  'tag.low-fodmap': {'en': 'low-fodmap', 'de': 'low-fodmap'},
  'tag.lactose-free': {'en': 'lactose-free', 'de': 'laktosefrei'},
  'tag.grilled-party': {'en': 'grill party', 'de': 'grillparty'},

  // Cookbook
  'cbEmpty': {
    'en': 'your cookbook is empty — save the variant of a dish you love.',
    'de': 'dein kochbuch ist leer — speichere die variante eines gerichts, das du liebst.',
  },
  'cbSavedOn': {'en': 'saved', 'de': 'gespeichert'},
  'cbRemove': {'en': 'remove from cookbook', 'de': 'aus dem kochbuch entfernen'},
  'cbUnsaved': {'en': 'removed from cookbook', 'de': 'aus dem kochbuch entfernt'},
  'cbRecent': {'en': 'recently cooked', 'de': 'zuletzt gekocht'},

  // Search
  'searchHint': {
    'en': 'search dishes, tags, ingredients…',
    'de': 'gerichte, tags, zutaten suchen…',
  },
  'searchFilters': {'en': 'filters', 'de': 'filter'},
  'searchClear': {'en': 'clear', 'de': 'löschen'},
  'searchNoResults': {
    'en': 'nothing found — your profile filters apply to search too.',
    'de': 'nichts gefunden — deine profilfilter gelten auch für die suche.',
  },
  'searchZeroNote': {
    'en':
        'zero-result queries are stored locally and shipped in your backup as content requests.',
    'de':
        'ergebnislose suchanfragen werden lokal gespeichert und im backup als inhaltswünsche exportiert.',
  },
  'filterCuisine': {'en': 'cuisine', 'de': 'küche'},
  'filterMeal': {'en': 'meal', 'de': 'mahlzeit'},
  'filterEffort': {'en': 'effort', 'de': 'aufwand'},
  'filterTag': {'en': 'tag', 'de': 'tag'},
  'cuisine.italian': {'en': 'italian', 'de': 'italienisch'},
  'cuisine.asian': {'en': 'asian', 'de': 'asiatisch'},
  'cuisine.middle-eastern': {'en': 'middle-eastern', 'de': 'orientalisch'},
  'cuisine.american': {'en': 'american', 'de': 'amerikanisch'},
  'cuisine.breakfast': {'en': 'breakfast', 'de': 'frühstück'},

  // Settings
  'stProfile': {'en': 'profile', 'de': 'profil'},
  'stProfileSub': {
    'en': 'name, avoids, budget — everything from onboarding',
    'de': 'name, vermeidungen, budget — alles aus dem onboarding',
  },
  'stLanguage': {'en': 'language', 'de': 'sprache'},
  'stAdaptions': {'en': 'adaptations', 'de': 'anpassungen'},
  'stVisualAlert': {
    'en': 'visual flash on timer end',
    'de': 'visueller blitz bei timer-ende',
  },
  'stVisualAlertSub': {
    'en': 'coral/teal full-screen flash — built for deaf & hard-of-hearing cooks',
    'de': 'koral/türkis-blitz über den bildschirm — für gehörlose & schwerhörige köch:innen',
  },
  'stQuickTap': {
    'en': 'one-handed quick-tap',
    'de': 'einhand-quick-tap',
  },
  'stQuickTapSub': {
    'en': 'single tap on a step advances to the next (300 ms debounce)',
    'de': 'ein tipp auf einen schritt springt zum nächsten (300 ms entprellung)',
  },
  'stReduceMotion': {
    'en': 'reduce motion',
    'de': 'bewegung reduzieren',
  },
  'stVariantTags': {
    'en': 'show variant tags on cards',
    'de': 'varianten-tags auf karten zeigen',
  },
  'stVariantTagsSub': {
    'en': 'small mono labels like “vegan · easy”',
    'de': 'kleine mono-etiketten wie „vegan · einfach“',
  },
  'stHalalKosherNote': {
    'en':
        'we never claim halal- or kosher-certification. certification is a property of sourcing — slaughter, supervision — not of a recipe text. we surface “halal-compatible ingredients” only, and the same honesty applies to kosher. check labels and your trusted certifier.',
    'de':
        'wir behaupten niemals halal- oder koscher-zertifizierung. zertifizierung ist eine eigenschaft der beschaffung — schlachtung, überwachung — nicht eines rezepttextes. wir zeigen nur „halal-kompatible zutaten“, und dieselbe ehrlichkeit gilt für koscher. prüfe etiketten und deine vertrauenswürdige zertifizierungsstelle.',
  },
  'stBackup': {'en': 'backup & restore', 'de': 'sicherung & wiederherstellung'},
  'stBackupSub': {
    'en': 'file-based export/import — json + gzip, optional password encryption',
    'de': 'dateibasierter export/import — json + gzip, optionale passwort-verschlüsselung',
  },
  'stInsights': {'en': 'shopping insights', 'de': 'einkaufs-insights'},
  'stInsightsSub': {
    'en': 'variety score, top ingredients, seasonal patterns',
    'de': 'vielfalts-score, top-zutaten, saisonale muster',
  },
  'stFaq': {'en': 'help center', 'de': 'hilfe-center'},
  'stAbout': {'en': 'about morphcook', 'de': 'über morphcook'},
  'stAboutText': {
    'en':
        'morphcook v1 — offline-only, no accounts, no telemetry. every recipe ships in the app, authored for your way of eating. fonts: playfair display, jetbrains mono, caveat (ofl).',
    'de':
        'morphcook v1 — nur offline, keine konten, keine telemetrie. jedes rezept kommt in der app, verfasst für deine ernährungsweise. schriften: playfair display, jetbrains mono, caveat (ofl).',
  },

  // FAQ
  'faqTitle': {'en': 'help center', 'de': 'hilfe-center'},
  'faqSearch': {'en': 'search the faq…', 'de': 'die faq durchsuchen…'},
  'faqAll': {'en': 'all', 'de': 'alle'},
  'faqDietary': {'en': 'dietary matching', 'de': 'ernährungs-matching'},
  'faqFeatures': {'en': 'features', 'de': 'funktionen'},
  'faqGeneral': {'en': 'general', 'de': 'allgemein'},
  'faqTroubleshooting': {'en': 'troubleshooting', 'de': 'problemlösung'},
  'faqAccessibility': {'en': 'accessibility', 'de': 'barrierefreiheit'},

  // Shopping
  'shTitle': {'en': 'shopping list', 'de': 'einkaufsliste'},
  'shEmpty': {
    'en': 'nothing on the list — add recipes from a dish page or the planner.',
    'de': 'nichts auf der liste — füge rezepte von einer gerichtsseite oder dem planer hinzu.',
  },
  'shAddFrom': {'en': 'add from recipes', 'de': 'aus rezepten hinzufügen'},
  'shSelect': {'en': 'select recipes', 'de': 'rezepte auswählen'},
  'shAddSelected': {'en': 'add {n} to list', 'de': '{n} zur liste hinzufügen'},
  'shClearChecked': {'en': 'clear checked', 'de': 'abgehakt löschen'},
  'shClearAll': {'en': 'clear all', 'de': 'alles löschen'},
  'shItems': {'en': 'items', 'de': 'posten'},
  'shSmart': {
    'en': 'amounts are merged across recipes & units convert automatically',
    'de': 'mengen werden rezeptübergreifend zusammengeführt & einheiten automatisch umgerechnet',
  },
  'aisle.produce': {'en': 'produce', 'de': 'obst & gemüse'},
  'aisle.dairy': {'en': 'dairy & chilled', 'de': 'milchprodukte & kühlung'},
  'aisle.meat': {'en': 'meat', 'de': 'fleisch'},
  'aisle.fish': {'en': 'fish & seafood', 'de': 'fisch & meeresfrüchte'},
  'aisle.bakery': {'en': 'bakery', 'de': 'bäckerei'},
  'aisle.pantry': {'en': 'pantry', 'de': 'vorratskammer'},
  'aisle.spices': {'en': 'spices', 'de': 'gewürze'},
  'aisle.baking': {'en': 'baking', 'de': 'backwaren'},
  'aisle.other': {'en': 'other', 'de': 'sonstiges'},

  // Insights
  'insTitle': {'en': 'shopping insights', 'de': 'einkaufs-insights'},
  'insVariety': {'en': 'variety score', 'de': 'vielfalts-score'},
  'insVarietySub': {
    'en': 'unique ingredients shopped for, all time',
    'de': 'verschiedene eingekaufte zutaten, gesamt',
  },
  'insTop': {'en': 'top added ingredients', 'de': 'häufigste zutaten'},
  'insTopSub': {'en': 'by times added to your list', 'de': 'nach häufigkeit des hinzufügens'},
  'insTimes': {'en': '× {n} added', 'de': '× {n} hinzugefügt'},
  'insSeasonal': {'en': 'seasonal breakdown', 'de': 'saisonale verteilung'},
  'insSeasonalSub': {'en': 'items added per month', 'de': 'posten pro monat'},
  'insEmpty': {
    'en': 'add things to your shopping list and patterns will appear here.',
    'de': 'füge dinge zu deiner einkaufsliste hinzu, dann erscheinen hier muster.',
  },
  'month.1': {'en': 'jan', 'de': 'jan'},
  'month.2': {'en': 'feb', 'de': 'feb'},
  'month.3': {'en': 'mar', 'de': 'mär'},
  'month.4': {'en': 'apr', 'de': 'apr'},
  'month.5': {'en': 'may', 'de': 'mai'},
  'month.6': {'en': 'jun', 'de': 'jun'},
  'month.7': {'en': 'jul', 'de': 'jul'},
  'month.8': {'en': 'aug', 'de': 'aug'},
  'month.9': {'en': 'sep', 'de': 'sep'},
  'month.10': {'en': 'oct', 'de': 'okt'},
  'month.11': {'en': 'nov', 'de': 'nov'},
  'month.12': {'en': 'dec', 'de': 'dez'},

  // Planner
  'plTitle': {'en': 'meal planner', 'de': 'essensplaner'},
  'plWeek': {'en': 'week', 'de': 'woche'},
  'plExport': {'en': 'export week to shopping list', 'de': 'woche zur einkaufsliste'},
  'plExported': {'en': 'week added to shopping list', 'de': 'woche zur einkaufsliste hinzugefügt'},
  'plAssign': {'en': 'assign a recipe', 'de': 'rezept zuweisen'},
  'plEmptySlot': {'en': 'tap to assign', 'de': 'tippen zum zuweisen'},
  'plClearSlot': {'en': 'clear slot', 'de': 'feld leeren'},
  'plHint': {
    'en': 'tap a slot to assign from your cookbook or search. drag to move.',
    'de': 'tippe ein feld, um aus kochbuch oder suche zuzuweisen. ziehen zum verschieben.',
  },
  'plFromCookbook': {'en': 'from cookbook', 'de': 'aus dem kochbuch'},
  'plFromSearch': {'en': 'search all recipes', 'de': 'alle rezepte suchen'},
  'weekday.mon': {'en': 'mon', 'de': 'mo'},
  'weekday.tue': {'en': 'tue', 'de': 'di'},
  'weekday.wed': {'en': 'wed', 'de': 'mi'},
  'weekday.thu': {'en': 'thu', 'de': 'do'},
  'weekday.fri': {'en': 'fri', 'de': 'fr'},
  'weekday.sat': {'en': 'sat', 'de': 'sa'},
  'weekday.sun': {'en': 'sun', 'de': 'so'},

  // Cook mode
  'cmDone': {'en': 'plated & proud', 'de': 'angerichtet & stolz'},
  'cmDoneSub': {
    'en': 'the dish exists now. it was you.',
    'de': 'das gericht existiert jetzt. du warst es.',
  },
  'cmCookAgain': {'en': 'back to start', 'de': 'zurück zum anfang'},
  'cmTimer': {'en': 'timer', 'de': 'timer'},
  'cmStartTimer': {'en': 'start timer', 'de': 'timer starten'},
  'cmPause': {'en': 'pause', 'de': 'pausieren'},
  'cmResume': {'en': 'resume', 'de': 'fortsetzen'},
  'cmReset': {'en': 'reset', 'de': 'zurücksetzen'},
  'cmPrev': {'en': 'prev', 'de': 'zurück'},
  'cmSteps': {'en': 'steps', 'de': 'schritte'},
  'cmQuickTapOn': {'en': 'tap a step to advance · on', 'de': 'schritt antippen zum weiterblättern · an'},
  'cmQuickTapOff': {'en': 'tap a step to advance · off', 'de': 'schritt antippen zum weiterblättern · aus'},
  'cmPausedNote': {'en': 'paused — progress is kept', 'de': 'pausiert — fortschritt bleibt erhalten'},

  // Backup
  'buTitle': {'en': 'backup & restore', 'de': 'sicherung & wiederherstellung'},
  'buExport': {'en': 'export backup', 'de': 'backup exportieren'},
  'buExportSub': {
    'en':
        'writes morphcook-backup.json and morphcook-backup.json.gz to the share sheet. pick whichever you like.',
    'de':
        'schreibt morphcook-backup.json und morphcook-backup.json.gz ins teilen-menü. nimm, was dir gefällt.',
  },
  'buPassword': {'en': 'password (optional)', 'de': 'passwort (optional)'},
  'buPasswordSub': {
    'en':
        'encrypts the json with aes-256-gcm. the gzip file stays unencrypted for compatibility.',
    'de':
        'verschlüsselt die json mit aes-256-gcm. die gzip-datei bleibt aus kompatibilität unverschlüsselt.',
  },
  'buImport': {'en': 'import backup', 'de': 'backup importieren'},
  'buImportSub': {
    'en': 'auto-detects json, gzip and encrypted formats.',
    'de': 'erkennt json-, gzip- und verschlüsselte formate automatisch.',
  },
  'buMerge': {'en': 'merge with current data', 'de': 'mit aktuellen daten zusammenführen'},
  'buReplace': {'en': 'replace current data', 'de': 'aktuelle daten ersetzen'},
  'buPasswordPrompt': {
    'en': 'this backup is encrypted. enter the password.',
    'de': 'dieses backup ist verschlüsselt. gib das passwort ein.',
  },
  'buWrongPassword': {
    'en': 'Incorrect password. Please try again.',
    'de': 'Falsches Passwort. Bitte versuche es erneut.',
  },
  'buCorrupted': {
    'en': 'Backup file is corrupted and cannot be restored.',
    'de': 'Die Sicherungsdatei ist beschädigt und kann nicht wiederhergestellt werden.',
  },
  'buInvalid': {
    'en': 'This file is not a valid MorphCook backup.',
    'de': 'Diese Datei ist kein gültiges MorphCook-Backup.',
  },
  'buDone': {'en': 'backup exported', 'de': 'backup exportiert'},
  'buImported': {'en': 'backup imported', 'de': 'backup importiert'},
  'buEncryptedJson': {'en': 'encrypted', 'de': 'verschlüsselt'},
};
