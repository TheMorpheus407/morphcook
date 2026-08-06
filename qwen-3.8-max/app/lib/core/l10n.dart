import 'package:flutter/widgets.dart';

enum AppLang { en, de }

AppLang langFromString(String? value, {AppLang fallback = AppLang.en}) {
  switch (value) {
    case 'de':
      return AppLang.de;
    case 'en':
      return AppLang.en;
    default:
      return fallback;
  }
}

extension AppLangX on AppLang {
  String get code => name;
}

/// Resolve a `Map<lang, String>` localized field, falling back to English,
/// then to any available language.
String tx(Map<String, dynamic>? localized, AppLang lang) {
  if (localized == null || localized.isEmpty) return '';
  final direct = localized[lang.code];
  if (direct is String && direct.isNotEmpty) return direct;
  final en = localized['en'];
  if (en is String && en.isNotEmpty) return en;
  return localized.values.firstWhere((v) => v is String, orElse: () => '').toString();
}

/// UI strings. The app is bilingual; everything user-visible lives here.
class Strings {
  final AppLang lang;
  const Strings(this.lang);

  static final Map<String, Map<String, String>> _table = {
    'appName': {'en': 'MorphCook', 'de': 'MorphCook'},
    'tagline': {
      'en': 'the same dish exists for every body',
      'de': 'dasselbe gericht gibt es für jeden körper'
    },
    'today': {'en': 'today', 'de': 'heute'},
    'featured': {'en': 'featured dish', 'de': 'gericht des tages'},
    'forYou': {'en': 'for you', 'de': 'für dich'},
    'weeknight': {'en': 'weeknight table', 'de': 'feierabend-küche'},
    'comfort': {'en': 'comfort', 'de': 'komfort'},
    'breakfast': {'en': 'breakfast', 'de': 'frühstück'},
    'lunch': {'en': 'lunch', 'de': 'mittag'},
    'dinner': {'en': 'dinner', 'de': 'abend'},
    'discover': {'en': 'discover', 'de': 'entdecken'},
    'home': {'en': 'home', 'de': 'start'},
    'search': {'en': 'search', 'de': 'suche'},
    'cookbook': {'en': 'cookbook', 'de': 'kochbuch'},
    'plan': {'en': 'plan', 'de': 'plan'},
    'shopping': {'en': 'shopping', 'de': 'einkauf'},
    'settings': {'en': 'settings', 'de': 'einstellungen'},
    'saved': {'en': 'saved', 'de': 'gespeichert'},
    'save': {'en': 'save', 'de': 'speichern'},
    'unsave': {'en': 'remove', 'de': 'entfernen'},
    'cook': {'en': 'cook', 'de': 'kochen'},
    'ingredients': {'en': 'ingredients', 'de': 'zutaten'},
    'method': {'en': 'method', 'de': 'zubereitung'},
    'macros': {'en': 'macros', 'de': 'nährwerte'},
    'serves': {'en': 'serves', 'de': 'für'},
    'minutes': {'en': 'min', 'de': 'min'},
    'kcal': {'en': 'kcal', 'de': 'kcal'},
    'diet': {'en': 'diet', 'de': 'ernährung'},
    'effort': {'en': 'effort', 'de': 'aufwand'},
    'calorieLevel': {'en': 'calorie level', 'de': 'kalorienstufe'},
    'noVariantYet': {
      'en': 'no version for this combination yet',
      'de': 'für diese kombination gibt es noch keine version'
    },
    'learnMore': {'en': 'learn more', 'de': 'mehr erfahren'},
    'optional': {'en': 'optional', 'de': 'optional'},
    'language': {'en': 'language', 'de': 'sprache'},
    'profile': {'en': 'profile', 'de': 'profil'},
    'name': {'en': 'name', 'de': 'name'},
    'dietAndAllergies': {'en': 'diet & allergies', 'de': 'ernährung & allergien'},
    'avoidedIngredients': {'en': 'avoided ingredients', 'de': 'gemiedene zutaten'},
    'requiredAttributes': {'en': 'required attributes', 'de': 'benötigte attribute'},
    'calorieTarget': {'en': 'calorie target', 'de': 'kalorienziel'},
    'timeBudget': {'en': 'time budget', 'de': 'zeitbudget'},
    'preferredEffort': {'en': 'preferred effort', 'de': 'bevorzugter aufwand'},
    'showVariantTags': {'en': 'show variant tags', 'de': 'varianten-tags anzeigen'},
    'reduceMotion': {'en': 'reduce motion', 'de': 'bewegung reduzieren'},
    'systemDefault': {'en': 'system default', 'de': 'systemstandard'},
    'visualAlerts': {'en': 'timer flash alerts', 'de': 'blitz-signale bei timern'},
    'quickTap': {'en': 'quick-tap next step', 'de': 'schnelltippen: nächster schritt'},
    'backup': {'en': 'backup', 'de': 'sicherung'},
    'exportBackup': {'en': 'export backup', 'de': 'sicherung exportieren'},
    'importBackup': {'en': 'import backup', 'de': 'sicherung importieren'},
    'backupPassword': {'en': 'backup password', 'de': 'sicherungs-passwort'},
    'helpCenter': {'en': 'help center', 'de': 'hilfe-center'},
    'faq': {'en': 'FAQ', 'de': 'FAQ'},
    'insights': {'en': 'shopping insights', 'de': 'einkaufs-insights'},
    'continue_': {'en': 'continue', 'de': 'weiter'},
    'back': {'en': 'back', 'de': 'zurück'},
    'done': {'en': 'done', 'de': 'fertig'},
    'welcome': {'en': 'welcome', 'de': 'willkommen'},
    'onboardingIntro': {
      'en': 'a cookbook that keeps every dish — written for the way you eat.',
      'de': 'ein kochbuch, das jedes gericht behält — geschrieben für deine art zu essen.'
    },
    'chooseLanguage': {'en': 'choose your language', 'de': 'wähle deine sprache'},
    'whatShouldWeCallYou': {
      'en': 'what should we call you?',
      'de': 'wie dürfen wir dich nennen?'
    },
    'howDoYouEat': {'en': 'how do you eat?', 'de': 'wie isst du?'},
    'allergyNote': {
      'en': 'pick anything you avoid. We hide dishes that contain it — nothing is ever deleted.',
      'de': 'Wähle alles aus, was du meidest. Wir blenden Gerichte aus, die es enthalten — gelöscht wird nichts.'
    },
    'specificAvoidNote': {
      'en': 'avoid one specific ingredient — apples, cilantro, anything.',
      'de': 'Meide eine einzelne Zutat — Äpfel, Koriander, irgendetwas.'
    },
    'yourDay': {'en': 'your day', 'de': 'dein tag'},
    'calorieNote': {
      'en': 'per-meal target. Dishes far outside it stay hidden unless you override.',
      'de': 'Ziel pro Mahlzeit. Gerichte weit darüber bleiben ausgeblendet, außer du überschreibst es.'
    },
    'timeNote': {
      'en': 'how long may cooking take?',
      'de': 'wie lange darf kochen dauern?'
    },
    'confirmNote': {
      'en': 'you can change all of this any time in settings.',
      'de': 'du kannst all das jederzeit in den einstellungen ändern.'
    },
    'confirm': {'en': 'confirm', 'de': 'bestätigen'},
    'noLimit': {'en': 'no limit', 'de': 'kein limit'},
    'off': {'en': 'off', 'de': 'aus'},
    'showAll': {'en': 'show all', 'de': 'alle zeigen'},
    'hiddenByProfile': {
      'en': 'hidden by your profile',
      'de': 'durch dein profil ausgeblendet'
    },
    'whyHidden': {'en': 'why is this hidden?', 'de': 'warum ist das ausgeblendet?'},
    'calorieOverride': {
      'en': 'show versions outside my calorie target',
      'de': 'versionen außerhalb meines kalorienziels zeigen'
    },
    'searchPlaceholder': {
      'en': 'search dishes, tags, ingredients…',
      'de': 'suche gerichte, tags, zutaten…'
    },
    'noResults': {'en': 'nothing found', 'de': 'nichts gefunden'},
    'noResultsNote': {
      'en': 'we noted what you were looking for — it helps us write new variants.',
      'de': 'wir haben notiert, was du gesucht hast — das hilft uns, neue varianten zu schreiben.'
    },
    'empty': {'en': 'nothing here yet', 'de': 'noch nichts hier'},
    'emptyCookbook': {
      'en': 'save a variant you love and it lands here — your version of the dish.',
      'de': 'speichere eine variante, die du liebst, und sie landet hier — deine version des gerichts.'
    },
    'servings': {'en': 'servings', 'de': 'portionen'},
    'step': {'en': 'step', 'de': 'schritt'},
    'of': {'en': 'of', 'de': 'von'},
    'pause': {'en': 'pause', 'de': 'pause'},
    'resume': {'en': 'resume', 'de': 'weiter'},
    'start': {'en': 'start', 'de': 'start'},
    'next': {'en': 'next', 'de': 'weiter'},
    'prev': {'en': 'back', 'de': 'zurück'},
    'timerDone': {'en': 'timer done', 'de': 'timer abgelaufen'},
    'cookedIt': {'en': 'cooked it!', 'de': 'gekocht!'},
    'wellDone': {'en': 'well done.', 'de': 'gut gemacht.'},
    'again': {'en': 'cook again', 'de': 'nochmal kochen'},
    'exit': {'en': 'exit', 'de': 'beenden'},
    'addToShopping': {'en': 'add to shopping list', 'de': 'zur einkaufsliste'},
    'added': {'en': 'added', 'de': 'hinzugefügt'},
    'clear': {'en': 'clear', 'de': 'leeren'},
    'checked': {'en': 'checked off', 'de': 'abgehakt'},
    'aisle': {'en': 'aisle', 'de': 'regal'},
    'week': {'en': 'week', 'de': 'woche'},
    'tapToAssign': {'en': 'tap to assign', 'de': 'tippen zum zuweisen'},
    'assignRecipe': {'en': 'assign a recipe', 'de': 'rezept zuweisen'},
    'removeFromPlan': {'en': 'remove', 'de': 'entfernen'},
    'exportWeek': {
      'en': 'add this week to the shopping list',
      'de': 'diese woche zur einkaufsliste hinzufügen'
    },
    'mon': {'en': 'mon', 'de': 'mo'},
    'tue': {'en': 'tue', 'de': 'di'},
    'wed': {'en': 'wed', 'de': 'mi'},
    'thu': {'en': 'thu', 'de': 'do'},
    'fri': {'en': 'fri', 'de': 'fr'},
    'sat': {'en': 'sat', 'de': 'sa'},
    'sun': {'en': 'sun', 'de': 'so'},
    'varietyScore': {'en': 'variety score', 'de': 'vielfalts-wert'},
    'uniqueIngredients': {'en': 'unique ingredients', 'de': 'einzigartige zutaten'},
    'topIngredients': {'en': 'most added', 'de': 'am häufigsten'},
    'byMonth': {'en': 'by month', 'de': 'nach monat'},
    'times': {'en': '×', 'de': '×'},
    'merge': {'en': 'merge', 'de': 'zusammenführen'},
    'replace': {'en': 'replace', 'de': 'ersetzen'},
    'mergeOrReplace': {
      'en': 'merge with your current data, or replace it?',
      'de': 'mit deinen aktuellen daten zusammenführen oder ersetzen?'
    },
    'importDone': {'en': 'backup restored', 'de': 'sicherung wiederhergestellt'},
    'exportDone': {'en': 'backup exported', 'de': 'sicherung exportiert'},
    'enterPassword': {'en': 'enter backup password', 'de': 'sicherungs-passwort eingeben'},
    'wrongPassword': {'en': 'Incorrect password. Please try again.', 'de': 'Falsches Passwort. Bitte versuche es erneut.'},
    'corrupted': {
      'en': 'Backup file is corrupted and cannot be restored.',
      'de': 'Die Sicherungsdatei ist beschädigt und kann nicht wiederhergestellt werden.'
    },
    'invalidBackup': {
      'en': 'This file is not a valid MorphCook backup.',
      'de': 'Diese Datei ist keine gültige MorphCook-Sicherung.'
    },
    'halalKosherNote': {
      'en': 'We never claim certification. Halal/kosher here means compatible ingredients — certification is a property of sourcing.',
      'de': 'Wir behaupten nie eine Zertifizierung. Halal/koscher heißt hier: kompatible Zutaten — Zertifizierung ist eine Eigenschaft der Beschaffung.'
    },
    'resetOnboarding': {'en': 'restart onboarding', 'de': 'onboarding neu starten'},
    'aboutCorpus': {
      'en': 'all recipes ship with the app. no network, no accounts, no tracking.',
      'de': 'alle rezepte liegen in der app. kein netzwerk, keine konten, kein tracking.'
    },
    'history': {'en': 'cooked history', 'de': 'koch-verlauf'},
    'contentRequests': {'en': 'searched & missing', 'de': 'gesucht & fehlt'},
    'quickTapHint': {
      'en': 'tap the step to continue',
      'de': 'tippe auf den schritt, um fortzufahren'
    },
    'loading': {'en': 'loading…', 'de': 'lädt…'},
    'cuisineItalian': {'en': 'the italian table', 'de': 'der italienische tisch'},
    'cuisineAsian': {'en': 'the asian table', 'de': 'der asiatische tisch'},
    'cuisineMiddleEastern': {'en': 'the middle-eastern table', 'de': 'der nahöstliche tisch'},
    'seeAll': {'en': 'see all', 'de': 'alle'},
    'yourVariant': {'en': 'your variant', 'de': 'deine variante'},
    'savedOn': {'en': 'saved', 'de': 'gespeichert'},
    'cookAgainFromHistory': {'en': 'cook again', 'de': 'nochmal kochen'},
    'guideWhere': {'en': 'where to find it', 'de': 'wo zu finden'},
    'guideStorage': {'en': 'storage', 'de': 'lagerung'},
    'guideTip': {'en': 'kitchen tip', 'de': 'küchentipp'},
    'guideAbout': {'en': 'what it is', 'de': 'was es ist'},
    'noGuide': {'en': 'no guide entry yet', 'de': 'noch kein guide-eintrag'},
    'perServing': {'en': 'per serving', 'de': 'pro portion'},
    'protein': {'en': 'protein', 'de': 'protein'},
    'carbs': {'en': 'carbs', 'de': 'kohlenhydrate'},
    'fat': {'en': 'fat', 'de': 'fett'},
    'searchFaq': {'en': 'search the help center…', 'de': 'hilfe-center durchsuchen…'},
    'allCategories': {'en': 'all', 'de': 'alle'},
    'catMatching': {'en': 'matching', 'de': 'matching'},
    'catVariants': {'en': 'variants', 'de': 'varianten'},
    'catShopping': {'en': 'shopping', 'de': 'einkauf'},
    'catFeatures': {'en': 'features', 'de': 'funktionen'},
    'catBackup': {'en': 'backup', 'de': 'sicherung'},
    'adaptation': {'en': 'adaptation', 'de': 'anpassung'},
    'accessibility': {'en': 'accessibility', 'de': 'barrierefreiheit'},
    'cookMode': {'en': 'cook mode', 'de': 'kochmodus'},
    'data': {'en': 'data', 'de': 'daten'},
    'edition': {'en': 'edition', 'de': 'ausgabe'},
    'morning': {'en': 'morning', 'de': 'morgen'},
    'evening': {'en': 'evening', 'de': 'abend'},
    'weekend': {'en': 'weekend', 'de': 'wochenende'},
  };

  String get(String key) {
    final entry = _table[key];
    if (entry == null) return key;
    return entry[lang.code] ?? entry['en'] ?? key;
  }
}

/// Tiny helper so widgets can write `S.of(context).get('cook')`.
class S {
  static Strings of(BuildContext context) {
    final model = _stringsOf(context);
    return model;
  }

  static Strings _stringsOf(BuildContext context) {
    // Avoid a hard dependency on provider in this file: the app installs an
    // InheritedStrings at the root.
    final inherited =
        context.dependOnInheritedWidgetOfExactType<InheritedStrings>();
    return inherited?.strings ?? const Strings(AppLang.en);
  }
}

class InheritedStrings extends InheritedWidget {
  final Strings strings;
  const InheritedStrings({super.key, required this.strings, required super.child});

  @override
  bool updateShouldNotify(InheritedStrings oldWidget) =>
      oldWidget.strings.lang != strings.lang;
}
