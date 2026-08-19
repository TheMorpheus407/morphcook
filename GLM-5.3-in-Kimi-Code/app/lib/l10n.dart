/// MorphCook UI strings — bilingual (EN + DE), N-language-ready.
/// All keys must exist in every supported language; the design goal is that
/// adding a language is a data addition, never a schema change.
library;

import 'package:flutter/foundation.dart';

enum Lang { en, de }

extension LangX on Lang {
  String get code => name;
  static Lang fromCode(String? code) =>
      code == 'de' ? Lang.de : Lang.en;
}

/// Pick a localized string out of a `Map<lang, String>` from the corpus.
String pickText(Map<String, dynamic>? map, Lang lang) {
  if (map == null) return '';
  return (map[lang.name] ?? map['en'] ?? '').toString();
}

class L {
  L._();

  static final Map<String, Map<Lang, String>> _data = _build();

  static String t(Lang lang, String key) {
    final entry = _data[key];
    if (entry == null) return key;
    return entry[lang] ?? entry[Lang.en] ?? key;
  }

  /// Interpolate `{x}` placeholders.
  static String f(Lang lang, String key, Map<String, Object> params) {
    var s = t(lang, key);
    params.forEach((k, v) => s = s.replaceAll('{$k}', v.toString()));
    return s;
  }

  /// Test hook: raw key → language map (for completeness checks).
  @visibleForTesting
  static Map<String, Map<Lang, String>> get debugData => _data;

  static Map<String, Map<Lang, String>> _build() => {
        // ---- common ----
        'appName': {
          Lang.en: 'morphcook',
          Lang.de: 'morphcook',
        },
        'tagline': {
          Lang.en: 'the same dish exists for every body',
          Lang.de: 'dasselbe gericht existiert für jeden menschen',
        },
        'tabHome': {Lang.en: 'home', Lang.de: 'start'},
        'tabCookbook': {Lang.en: 'cookbook', Lang.de: 'kochbuch'},
        'tabPlan': {Lang.en: 'week', Lang.de: 'woche'},
        'tabShopping': {Lang.en: 'market', Lang.de: 'markt'},
        'tabSettings': {Lang.en: 'settings', Lang.de: 'einstellungen'},
        'cancel': {Lang.en: 'cancel', Lang.de: 'abbrechen'},
        'done': {Lang.en: 'done', Lang.de: 'fertig'},
        'next': {Lang.en: 'next', Lang.de: 'weiter'},
        'back': {Lang.en: 'back', Lang.de: 'zurück'},
        'skip': {Lang.en: 'skip', Lang.de: 'überspringen'},
        'save': {Lang.en: 'save', Lang.de: 'speichern'},
        'saved': {Lang.en: 'saved', Lang.de: 'gespeichert'},
        'remove': {Lang.en: 'remove', Lang.de: 'entfernen'},
        'add': {Lang.en: 'add', Lang.de: 'hinzufügen'},
        'all': {Lang.en: 'all', Lang.de: 'alle'},
        'close': {Lang.en: 'close', Lang.de: 'schließen'},
        'retry': {Lang.en: 'try again', Lang.de: 'nochmal'},
        'delete': {Lang.en: 'delete', Lang.de: 'löschen'},
        'yes': {Lang.en: 'yes', Lang.de: 'ja'},
        'no': {Lang.en: 'no', Lang.de: 'nein'},
        'minutes': {Lang.en: 'min', Lang.de: 'min'},
        'kcal': {Lang.en: 'kcal', Lang.de: 'kcal'},
        'servings': {Lang.en: 'servings', Lang.de: 'portionen'},
        'perServing': {Lang.en: 'per serving', Lang.de: 'pro portion'},
        'more': {Lang.en: 'more', Lang.de: 'mehr'},
        'empty': {Lang.en: 'nothing here yet', Lang.de: 'hier ist noch nichts'},

        // ---- onboarding ----
        'obWelcomeTitle': {
          Lang.en: 'every body gets\nthe whole cookbook',
          Lang.de: 'jeder mensch bekommt\ndas ganze kochbuch',
        },
        'obWelcomeBody': {
          Lang.en:
              'no filters that shrink the world. if you’re vegan, the döner stays — fully written, not watered down. tell morphcook how you eat and it quietly reshapes itself around you.',
          Lang.de:
              'keine filter, die die welt verkleinern. wenn du vegan lebst, bleibt der döner — komplett geschrieben, keine abschwächung. sag morphcook, wie du isst, und die app ordnet sich still um dich herum an.',
        },
        'obLangTitle': {Lang.en: 'first — a language', Lang.de: 'zuerst — eine sprache'},
        'obNameTitle': {Lang.en: 'what should we call you?', Lang.de: 'wie sollen wir dich nennen?'},
        'obNameHint': {Lang.en: 'your name', Lang.de: 'dein name'},
        'obDietTitle': {Lang.en: 'how do you eat?', Lang.de: 'wie isst du?'},
        'obDietBody': {
          Lang.en: 'pick the diets that must hold. these become hard rules — morphcook will only ever show you recipes that respect them.',
          Lang.de: 'wähle die ernährungsweisen, die gelten müssen. daraus werden feste regeln — morphcook zeigt dir nur rezepte, die sie respektieren.',
        },
        'obAvoidClassTitle': {Lang.en: 'classes to avoid', Lang.de: 'klassen zum meiden'},
        'obAvoidClassBody': {
          Lang.en: 'whole families of ingredients: all dairy, all nuts, all shellfish…',
          Lang.de: 'ganze zutatenfamilien: alle milchprodukte, alle nüsse, alle schalentiere …',
        },
        'obAvoidSpecTitle': {Lang.en: 'single ingredients', Lang.de: 'einzelne zutaten'},
        'obAvoidSpecBody': {
          Lang.en: 'apples, cilantro, bell peppers… type and pick any level of the ingredient tree.',
          Lang.de: 'äpfel, koriandergrün, paprika … tippe und wähle jede ebene des zutatenbaums.',
        },
        'obPrefsTitle': {Lang.en: 'your kitchen rhythm', Lang.de: 'dein küchenrhythmus'},
        'obPrefsBody': {
          Lang.en: 'calorie target per meal (hard filter, overridable per dish), time budget, and how much effort you usually feel like.',
          Lang.de: 'kalorienziel pro mahlzeit (hartfilter, pro gericht abschaltbar), zeitbudget und wie viel aufwand du dir meist zumutest.',
        },
        'obConfirmTitle': {Lang.en: 'that’s you, then', Lang.de: 'das bist du also'},
        'obConfirmBody': {
          Lang.en: 'everything you picked can change later in settings. the machinery stays invisible — you’ll just see your cookbook.',
          Lang.de: 'alles, was du gewählt hast, lässt sich später in den einstellungen ändern. die maschinerie bleibt unsichtbar — du siehst einfach dein kochbuch.',
        },
        'obStart': {Lang.en: 'open the cookbook', Lang.de: 'das kochbuch öffnen'},
        'obAnyCalorie': {Lang.en: 'no calorie target', Lang.de: 'kein kalorienziel'},

        // ---- home ----
        'hmFeatured': {Lang.en: 'tonight’s lead story', Lang.de: 'die heutige hauptgeschichte'},
        'hmQuick': {Lang.en: 'quick tonight — under 30', Lang.de: 'schnell heute — unter 30'},
        'hmForYou': {Lang.en: 'for your table', Lang.de: 'für deinen tisch'},
        'hmBinder': {Lang.en: 'from the kitchen binder', Lang.de: 'aus der küchenmappe'},
        'hmOutsideNote': {
          Lang.en:
              'nothing fits your rules perfectly right now — showing the closest versions, each marked with a note on its dish page',
          Lang.de:
              'im moment passt nichts perfekt zu deinen regeln — die nächsten versionen werden gezeigt, jede mit hinweis auf ihrer gerichtseite vermerkt',
        },
        'hmFlagged': {
          Lang.en: 'outside your rules',
          Lang.de: 'außerhalb deiner regeln',
        },
        'hmVariants': {
          Lang.en: '{n} ways to make it',
          Lang.de: '{n} weisen, es zu machen',
        },
        'hmGreeting': {
          Lang.en: 'good {part}, {name}',
          Lang.de: 'guten {part}, {name}',
        },
        'hmMorning': {Lang.en: 'morning', Lang.de: 'morgen'},
        'hmDay': {Lang.en: 'day', Lang.de: 'tag'},
        'hmEvening': {Lang.en: 'evening', Lang.de: 'abend'},

        // ---- dish detail ----
        'dhDiet': {Lang.en: 'diet', Lang.de: 'ernährung'},
        'dhEffort': {Lang.en: 'effort', Lang.de: 'aufwand'},
        'dhCalories': {Lang.en: 'calorie level', Lang.de: 'kalorien-niveau'},
        'dhIngredients': {Lang.en: 'ingredients', Lang.de: 'zutaten'},
        'dhMethod': {Lang.en: 'method', Lang.de: 'zubereitung'},
        'dhMacros': {Lang.en: 'macros', Lang.de: 'nährwerte'},
        'dhTips': {Lang.en: 'margin notes', Lang.de: 'randnotizen'},
        'dhCook': {Lang.en: 'cook this', Lang.de: 'das kochen'},
        'dhSave': {Lang.en: 'save this version', Lang.de: 'diese version speichern'},
        'dhSaved': {Lang.en: 'in your cookbook', Lang.de: 'in deinem kochbuch'},
        'dhLearnMore': {Lang.en: 'learn more', Lang.de: 'mehr erfahren'},
        'dhNoVersionYet': {
          Lang.en: 'no {a} × {b} version yet',
          Lang.de: 'noch keine {a} × {b} version',
        },
        'dhBlockedByProfile': {
          Lang.en: 'clashes with your dietary rules',
          Lang.de: 'widerspricht deinen ernährungsregeln',
        },
        'dhShowOutside': {
          Lang.en: 'show versions outside my calorie target',
          Lang.de: 'versionen außerhalb meines kalorienziels zeigen',
        },
        'dhOutsideNote': {
          Lang.en: 'showing versions outside your calorie target',
          Lang.de: 'versionen außerhalb deines kalorienziels werden gezeigt',
        },
        'dhTime': {Lang.en: 'time', Lang.de: 'zeit'},
        'dhServes': {Lang.en: 'serves', Lang.de: 'portionen'},
        'dhContains': {Lang.en: 'contains', Lang.de: 'enthält'},
        'dhProtein': {Lang.en: 'protein', Lang.de: 'eiweiß'},
        'dhCarbs': {Lang.en: 'carbs', Lang.de: 'kohlenhydrate'},
        'dhFat': {Lang.en: 'fat', Lang.de: 'fett'},
        'dhAddedToList': {
          Lang.en: 'added to your market list',
          Lang.de: 'auf deine marktliste gekommen',
        },
        'dhGuideTitle': {Lang.en: 'kitchen reference', Lang.de: 'küchenlexikon'},

        // ---- cook mode ----
        'ckTitle': {Lang.en: 'cook mode', Lang.de: 'kochmodus'},
        'ckStepOf': {
          Lang.en: 'step {a} of {b}',
          Lang.de: 'schritt {a} von {b}',
        },
        'ckTimerStart': {Lang.en: 'start timer', Lang.de: 'timer starten'},
        'ckPause': {Lang.en: 'pause', Lang.de: 'pause'},
        'ckResume': {Lang.en: 'resume', Lang.de: 'fortsetzen'},
        'ckRestart': {Lang.en: 'restart', Lang.de: 'neu starten'},
        'ckDone': {Lang.en: 'finish cooking', Lang.de: 'fertig gekocht'},
        'ckNext': {Lang.en: 'next step', Lang.de: 'nächster schritt'},
        'ckPrev': {Lang.en: 'previous step', Lang.de: 'vorheriger schritt'},
        'ckServings': {Lang.en: 'scale servings', Lang.de: 'portionen skalieren'},
        'ckQuickTapHint': {
          Lang.en: 'quick-tap is on: tap the text to advance',
          Lang.de: 'quick-tap ist an: tippe auf den text zum weiterblättern',
        },
        'ckCompleted': {Lang.en: 'you cooked it.', Lang.de: 'du hast es gekocht.'},
        'ckCompletedBody': {
          Lang.en: 'logged to your history. the pan can cool down now.',
          Lang.de: 'in deiner historie vermerkt. die pfanne darf jetzt abkühlen.',
        },
        'ckBackToRecipe': {Lang.en: 'back to the recipe', Lang.de: 'zurück zum rezept'},
        'ckTimerDone': {Lang.en: 'time is up', Lang.de: 'die zeit ist um'},
        'ckPaused': {Lang.en: 'paused — progress saved', Lang.de: 'pausiert — fortschritt gesichert'},

        // ---- cookbook ----
        'cbTitle': {Lang.en: 'your cookbook', Lang.de: 'dein kochbuch'},
        'cbEmpty': {Lang.en: 'no saved versions yet', Lang.de: 'noch keine gespeicherten versionen'},
        'cbEmptyBody': {
          Lang.en: 'you save a specific version — YOUR döner, not just “döner”. open a dish and tap save.',
          Lang.de: 'du speicherst eine konkrete version — DEINEN döner, nicht nur „döner“. öffne ein gericht und tippe auf speichern.',
        },
        'cbHistory': {Lang.en: 'history', Lang.de: 'historie'},

        // ---- search ----
        'scTitle': {Lang.en: 'search', Lang.de: 'suche'},
        'scHint': {Lang.en: 'dish, ingredient, craving…', Lang.de: 'gericht, zutat, lust …'},
        'scNoResults': {Lang.en: 'nothing found', Lang.de: 'nichts gefunden'},
        'scNoResultsBody': {
          Lang.en: 'either it’s not in the corpus yet, or your profile filters hide it. the search was noted — zero-result queries tell us what to write next.',
          Lang.de: 'entweder ist es noch nicht im bestand, oder deine profilfilter verbergen es. die suche wurde notiert — nulltreffer-suchen sagen uns, was wir als nächstes schreiben.',
        },
        'scFilters': {Lang.en: 'filters', Lang.de: 'filter'},
        'scCuisine': {Lang.en: 'cuisine', Lang.de: 'küche'},
        'scDiet': {Lang.en: 'diet', Lang.de: 'ernährung'},
        'scEffort': {Lang.en: 'effort', Lang.de: 'aufwand'},
        'scAny': {Lang.en: 'any', Lang.de: 'egal'},
        'scResults': {Lang.en: '{n} results', Lang.de: '{n} treffer'},

        // ---- settings ----
        'stTitle': {Lang.en: 'settings', Lang.de: 'einstellungen'},
        'stProfile': {Lang.en: 'profile', Lang.de: 'profil'},
        'stName': {Lang.en: 'name', Lang.de: 'name'},
        'stLanguage': {Lang.en: 'language', Lang.de: 'sprache'},
        'stDiets': {Lang.en: 'diets & requirements', Lang.de: 'ernährung & anforderungen'},
        'stDietsBody': {
          Lang.en: 'hard rules — every recipe you see respects these.',
          Lang.de: 'feste regeln — jedes rezept, das du siehst, respektiert diese.',
        },
        'stAvoidClasses': {Lang.en: 'avoid ingredient classes', Lang.de: 'zutatenklassen meiden'},
        'stAvoidSpecific': {Lang.en: 'avoid specific ingredients', Lang.de: 'einzelne zutaten meiden'},
        'stAvoidSpecificHint': {
          Lang.en: 'pick any level — avoiding “nuts” covers everything beneath it.',
          Lang.de: 'wähle jede ebene — „nüsse“ meiden deckt alles darunter ab.',
        },
        'stCalorie': {Lang.en: 'calorie target (per meal)', Lang.de: 'kalorienziel (pro mahlzeit)'},
        'stCalorieOff': {Lang.en: 'off', Lang.de: 'aus'},
        'stTimeBudget': {Lang.en: 'time budget', Lang.de: 'zeitbudget'},
        'stEffort': {Lang.en: 'preferred effort', Lang.de: 'bevorzugter aufwand'},
        'stAdaptation': {Lang.en: 'adaptation preferences', Lang.de: 'anpassungs-präferenzen'},
        'stShowVariantTags': {
          Lang.en: 'show variant tags in lists',
          Lang.de: 'varianten-tags in listen zeigen',
        },
        'stAccessibility': {Lang.en: 'accessibility', Lang.de: 'barrierefreiheit'},
        'stReduceMotion': {
          Lang.en: 'reduce motion (shorter animations)',
          Lang.de: 'weniger animationen (kürzere animationen)',
        },
        'stVisualAlerts': {
          Lang.en: 'visual flash when a cook timer ends',
          Lang.de: 'visueller blitz, wenn ein koch-timer endet',
        },
        'stQuickTap': {
          Lang.en: 'quick-tap in cook mode (one-handed)',
          Lang.de: 'quick-tap im kochmodus (einhand)',
        },
        'stQuickTapHint': {
          Lang.en: 'a single tap on the step text advances to the next step.',
          Lang.de: 'ein einfacher tipp auf den schritttext blättert weiter.',
        },
        'stData': {Lang.en: 'your data', Lang.de: 'deine daten'},
        'stBackup': {Lang.en: 'backup & restore', Lang.de: 'backup & wiederherstellung'},
        'stBackupBody': {
          Lang.en: 'writes a readable json and a compressed .gz to the share sheet. nothing ever leaves your device unless you share it.',
          Lang.de: 'schreibt ein lesbares json und ein komprimiertes .gz ins teilen-menü. nichts verlässt dein gerät, außer du teilst es.',
        },
        'stExport': {Lang.en: 'export backup', Lang.de: 'backup exportieren'},
        'stExportLocked': {Lang.en: 'export with password', Lang.de: 'mit passwort exportieren'},
        'stPassword': {Lang.en: 'password', Lang.de: 'passwort'},
        'stPasswordHint': {
          Lang.en: 'optional — encrypts the json file (AES-256). if lost, the backup is lost.',
          Lang.de: 'optional — verschlüsselt die json-datei (AES-256). verloren heißt backup verloren.',
        },
        'stImport': {Lang.en: 'import backup', Lang.de: 'backup importieren'},
        'stImportDone': {
          Lang.en: 'imported {n} saved recipes',
          Lang.de: '{n} gespeicherte rezepte importiert',
        },
        'stMergeOrReplace': {
          Lang.en: 'merge with your data, or replace everything?',
          Lang.de: 'mit deinen daten zusammenführen oder alles ersetzen?',
        },
        'stMerge': {Lang.en: 'merge', Lang.de: 'zusammenführen'},
        'stReplace': {Lang.en: 'replace', Lang.de: 'ersetzen'},
        'stWrongPassword': {
          Lang.en: 'incorrect password. please try again.',
          Lang.de: 'falsches passwort. bitte nochmal.',
        },
        'stCorrupted': {
          Lang.en: 'backup file is corrupted and cannot be restored.',
          Lang.de: 'die backup-datei ist beschädigt und kann nicht wiederhergestellt werden.',
        },
        'stInvalidFormat': {
          Lang.en: 'this file is not a valid morphcook backup.',
          Lang.de: 'diese datei ist kein gültiges morphcook-backup.',
        },
        'stInsights': {Lang.en: 'shopping insights', Lang.de: 'einkaufs-insights'},
        'stFaq': {Lang.en: 'help center', Lang.de: 'hilfecenter'},
        'stAbout': {Lang.en: 'about morphcook', Lang.de: 'über morphcook'},
        'stAboutBody': {
          Lang.en:
              'offline cookbook, fully-authored variants for every way of eating. no account, no cloud, no telemetry. every recipe human-reviewed. striped placeholders are the design, not a placeholder for the design.',
          Lang.de:
              'offline-kochbuch mit vollständig ausgearbeiteten varianten für jede ernährung. kein konto, keine cloud, keine telemetrie. jedes rezept von menschen geprüft. die gestreiften platzhalter sind das design, kein platzhalter für das design.',
        },
        'stHalalNote': {
          Lang.en:
              'note on halal & kosher: we surface halal-compatible and kosher-style ingredients only — never “certified”. certification is a property of sourcing and supervision, not of a recipe text. buy from suppliers you trust.',
          Lang.de:
              'hinweis zu halal & koscher: wir zeigen nur halal-kompatible bzw. koscher-stil-zutaten — niemals „zertifiziert“. zertifizierung ist eine eigenschaft von beschaffung und aufsicht, nicht eines rezepttextes. kauf bei anbietern, denen du vertraust.',
        },
        'stContentRequests': {Lang.en: 'your zero-result searches', Lang.de: 'deine nulltreffer-suchen'},
        'stContentRequestsBody': {
          Lang.en: 'kept locally, exported with your backup — they tell us what to write next.',
          Lang.de: 'lokal gespeichert, mit dem backup exportiert — sie sagen uns, was wir als nächstes schreiben.',
        },
        'stOnboardingAgain': {Lang.en: 'run onboarding again', Lang.de: 'onboarding erneut starten'},
        'stExporting': {Lang.en: 'preparing backup…', Lang.de: 'backup wird vorbereitet …'},
        'stImporting': {Lang.en: 'reading backup…', Lang.de: 'backup wird gelesen …'},

        // ---- faq ----
        'fqTitle': {Lang.en: 'help center', Lang.de: 'hilfecenter'},
        'fqHint': {Lang.en: 'search the help…', Lang.de: 'hilfe durchsuchen …'},
        'fqAll': {Lang.en: 'all', Lang.de: 'alle'},
        'fqCatGeneral': {Lang.en: 'general', Lang.de: 'allgemein'},
        'fqCatRecipes': {Lang.en: 'recipes', Lang.de: 'rezepte'},
        'fqCatMatching': {Lang.en: 'dietary matching', Lang.de: 'ernährungs-abstimmung'},
        'fqCatFeatures': {Lang.en: 'features', Lang.de: 'funktionen'},
        'fqCatTroubleshooting': {Lang.en: 'troubleshooting', Lang.de: 'probleme'},
        'fqRelated': {Lang.en: 'related', Lang.de: 'passt dazu'},

        // ---- shopping ----
        'shTitle': {Lang.en: 'market list', Lang.de: 'marktliste'},
        'shEmpty': {Lang.en: 'your list is empty', Lang.de: 'deine liste ist leer'},
        'shEmptyBody': {
          Lang.en: 'add a recipe from its page, or a whole week from the meal plan. quantities merge intelligently.',
          Lang.de: 'füge ein rezept von seiner seite hinzu oder eine ganze woche aus dem wochenplan. mengen verschmelzen klug.',
        },
        'shAddWeek': {Lang.en: 'add this week', Lang.de: 'diese woche hinzufügen'},
        'shClearChecked': {Lang.en: 'clear checked', Lang.de: 'abgehaktes entfernen'},
        'shCleared': {Lang.en: 'removed {n} items', Lang.de: '{n} einträge entfernt'},
        'shAdded': {Lang.en: 'added {n} items', Lang.de: '{n} einträge hinzugefügt'},
        'shSources': {Lang.en: 'for {n} recipes', Lang.de: 'für {n} rezepte'},
        'shConverted': {Lang.en: 'converted', Lang.de: 'umgerechnet'},
        'aisle_produce': {Lang.en: 'produce', Lang.de: 'obst & gemüse'},
        'aisle_meat': {Lang.en: 'meat', Lang.de: 'fleisch'},
        'aisle_fish': {Lang.en: 'fish & seafood', Lang.de: 'fisch & meeresfrüchte'},
        'aisle_dairy': {Lang.en: 'dairy & eggs', Lang.de: 'milch & eier'},
        'aisle_bakery': {Lang.en: 'bread & bakery', Lang.de: 'brot & backwaren'},
        'aisle_pantry': {Lang.en: 'pantry', Lang.de: 'vorrat'},
        'aisle_frozen': {Lang.en: 'frozen', Lang.de: 'tiefkühl'},
        'aisle_spices': {Lang.en: 'spices', Lang.de: 'gewürze'},
        'aisle_drinks': {Lang.en: 'drinks', Lang.de: 'getränke'},
        'aisle_other': {Lang.en: 'other', Lang.de: 'sonstiges'},

        // ---- insights ----
        'inTitle': {Lang.en: 'shopping insights', Lang.de: 'einkaufs-insights'},
        'inVariety': {Lang.en: 'variety score', Lang.de: 'abwechslungswert'},
        'inVarietyBody': {
          Lang.en: 'unique ingredients across everything you’ve added to your lists.',
          Lang.de: 'verschiedene zutaten über alles, was du je auf deine listen gesetzt hast.',
        },
        'inTop': {Lang.en: 'most added', Lang.de: 'am häufigsten'},
        'inTimes': {Lang.en: '×{n}', Lang.de: '×{n}'},
        'inMonths': {Lang.en: 'by month', Lang.de: 'nach monat'},
        'inEmpty': {Lang.en: 'no insights yet', Lang.de: 'noch keine insights'},
        'inEmptyBody': {
          Lang.en: 'add recipes to your market list and this page starts drawing.',
          Lang.de: 'füge rezepte zur marktliste hinzu und diese seite beginnt zu zeichnen.',
        },

        // ---- meal plan ----
        'mpTitle': {Lang.en: 'the week', Lang.de: 'die woche'},
        'mpBreakfast': {Lang.en: 'breakfast', Lang.de: 'frühstück'},
        'mpLunch': {Lang.en: 'lunch', Lang.de: 'mittag'},
        'mpDinner': {Lang.en: 'dinner', Lang.de: 'abend'},
        'mpEmpty': {Lang.en: 'empty', Lang.de: 'frei'},
        'mpPickTitle': {Lang.en: 'plan a meal', Lang.de: 'eine mahlzeit planen'},
        'mpPickCookbook': {Lang.en: 'from cookbook', Lang.de: 'aus dem kochbuch'},
        'mpPickSearch': {Lang.en: 'search all', Lang.de: 'alles durchsuchen'},
        'mpWeek': {Lang.en: 'week {n}', Lang.de: 'woche {n}'},
        'mpThisWeek': {Lang.en: 'this week', Lang.de: 'diese woche'},
        'mpToShopping': {Lang.en: 'week → market list', Lang.de: 'woche → marktliste'},
        'mpAddedAll': {
          Lang.en: 'the whole week is on your list',
          Lang.de: 'die ganze woche ist auf deiner liste',
        },
        'mpClearSlot': {Lang.en: 'clear this slot', Lang.de: 'dieses feld leeren'},
        'mpSlotOf': {
          Lang.en: '{day} · {meal}',
          Lang.de: '{day} · {meal}',
        },
        'mpWeekEmpty': {
          Lang.en: 'nothing planned — the week is yours',
          Lang.de: 'nichts geplant — die woche gehört dir',
        },

        // days (short)
        'day_mon': {Lang.en: 'mon', Lang.de: 'mo'},
        'day_tue': {Lang.en: 'tue', Lang.de: 'di'},
        'day_wed': {Lang.en: 'wed', Lang.de: 'mi'},
        'day_thu': {Lang.en: 'thu', Lang.de: 'do'},
        'day_fri': {Lang.en: 'fri', Lang.de: 'fr'},
        'day_sat': {Lang.en: 'sat', Lang.de: 'sa'},
        'day_sun': {Lang.en: 'sun', Lang.de: 'so'},

        // ---- history ----
        'hsTitle': {Lang.en: 'cooked & done', Lang.de: 'gekocht & fertig'},
        'hsEmpty': {Lang.en: 'nothing cooked yet', Lang.de: 'noch nichts gekocht'},
        'hsEmptyBody': {
          Lang.en: 'finish a cook mode session and it lands here, grouped by week.',
          Lang.de: 'beende eine kochmodus-session und es landet hier, nach wochen gruppiert.',
        },
        'hsWeek': {Lang.en: 'week of {date}', Lang.de: 'woche vom {date}'},
        'hsTimes': {Lang.en: '{n}×', Lang.de: '{n}×'},
        'hsNever': {Lang.en: 'first time', Lang.de: 'erstmals'},

        // ---- units ----
        'u_g': {Lang.en: 'g', Lang.de: 'g'},
        'u_kg': {Lang.en: 'kg', Lang.de: 'kg'},
        'u_ml': {Lang.en: 'ml', Lang.de: 'ml'},
        'u_l': {Lang.en: 'l', Lang.de: 'l'},
        'u_tbsp': {Lang.en: 'tbsp', Lang.de: 'EL'},
        'u_tsp': {Lang.en: 'tsp', Lang.de: 'TL'},
        'u_piece': {Lang.en: 'piece', Lang.de: 'Stück'},
        'u_pieces': {Lang.en: 'pieces', Lang.de: 'Stück'},
        'u_clove': {Lang.en: 'clove', Lang.de: 'Zehe'},
        'u_cloves': {Lang.en: 'cloves', Lang.de: 'Zehen'},
        'u_stick': {Lang.en: 'stick', Lang.de: 'Stange'},
        'u_sticks': {Lang.en: 'sticks', Lang.de: 'Stangen'},
        'u_bunch': {Lang.en: 'bunch', Lang.de: 'Bund'},
        'u_pinch': {Lang.en: 'pinch', Lang.de: 'Prise'},
        'u_dash': {Lang.en: 'dash', Lang.de: 'Schuss'},

        // misc errors
        'errGeneric': {
          Lang.en: 'something went wrong',
          Lang.de: 'etwas ist schiefgegangen',
        },
      };
}
