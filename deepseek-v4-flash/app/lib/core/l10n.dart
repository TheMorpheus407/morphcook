import 'package:flutter/widgets.dart';

/// Resolves a `Map<lang, String>` content map for the current language,
/// falling back to English, then the first non-empty value. Content data
/// (recipes, dishes, faqs, guides) uses this shape so that adding a language
/// is purely a data addition.
String T(Map<String, dynamic> map, String lang) {
  final v = map[lang];
  if (v != null && v.toString().isNotEmpty) return v.toString();
  final en = map['en'];
  if (en != null && en.toString().isNotEmpty) return en.toString();
  for (final e in map.values) {
    if (e != null && e.toString().isNotEmpty) return e.toString();
  }
  return '';
}

/// UI chrome strings, EN + DE. The corpus provides its own bilingual content;
/// this only covers the app's chrome.
class L10n {
  static const String en = 'en';
  static const String de = 'de';

  static String s(BuildContext context, String key) =>
      strings(Localizations.localeOf(context).languageCode, key);

  static String strings(String lang, String key) =>
      (lang == 'de' ? _de : _en)[key] ?? _en[key] ?? key;

  static const tBack = 'back';
  static const tSave = 'save';
  static const tSaved = 'saved';
  static const tCancel = 'cancel';
  static const tDone = 'done';
  static const tNext = 'next';
  static const tConfirm = 'confirm';
  static const tHomeLoading = 'homeLoading';
  static const tHomeTab = 'homeTab';
  static const tCookbookTab = 'cookbookTab';
  static const tPlanTab = 'planTab';
  static const tShopTab = 'shopTab';
  static const tSettings = 'settings';
  static const tFaq = 'faq';
  static const tInsights = 'insights';
  static const tBackup = 'backup';
  static const tCookMode = 'cookMode';
  static const tStartCooking = 'startCooking';
  static const tIngredients = 'ingredients';
  static const tMethod = 'method';
  static const tMacros = 'macros';
  static const tPerServing = 'perServing';
  static const tCalories = 'calories';
  static const tProtein = 'protein';
  static const tCarbs = 'carbs';
  static const tFat = 'fat';
  static const tTime = 'time';
  static const tEffort = 'effort';
  static const tDiet = 'diet';
  static const tCalorieLevel = 'calorieLevel';
  static const tMinutes = 'minutes';
  static const tServes = 'serves';
  static const tNoVersionYet = 'noVersionYet';
  static const tNoVariantYet = 'noVariantYet';
  static const tLearnMore = 'learnMore';
  static const tGuideWhat = 'guideWhat';
  static const tGuideTips = 'guideTips';
  static const tGuideStorage = 'guideStorage';
  static const tGuideFind = 'guideFind';
  static const tNoResults = 'noResults';
  static const tContentRequest = 'contentRequest';
  static const tRequestSaved = 'requestSaved';
  static const tClear = 'clear';
  static const tSearchRecipes = 'searchRecipes';
  static const tFilters = 'filters';
  static const tUnsaved = 'unsaved';
  static const tAddToShopping = 'addToShopping';
  static const tRemoveShopping = 'removeShopping';
  static const tExportWeek = 'exportWeek';
  static const tThisWeek = 'thisWeek';
  static const tPrevWeek = 'prevWeek';
  static const tNextWeek = 'nextWeek';
  static const tBreakfast = 'breakfast';
  static const tLunch = 'lunch';
  static const tDinner = 'dinner';
  static const tAssign = 'assign';
  static const tFromCookbook = 'fromCookbook';
  static const tFromCookbookMine = 'fromCookbookMine';
  static const tClearSlot = 'clearSlot';
  static const tViewRecipe = 'viewRecipe';
  static const tAisles = 'aisles';
  static const tClearChecked = 'clearChecked';
  static const tVariety = 'variety';
  static const tUniqueAdded = 'uniqueAdded';
  static const tSeasonal = 'seasonal';
  static const tInsightsEmpty = 'insightsEmpty';
  static const tProfile = 'profile';
  static const tName = 'name';
  static const tLanguage = 'language';
  static const tAvoidClass = 'avoidClass';
  static const tAvoidIngredients = 'avoidIngredients';
  static const tAvoidIng = 'avoidIng';
  static const tRequiredAttrs = 'requiredAttrs';
  static const tCalorieTarget = 'calorieTarget';
  static const tCalorieTime = 'calorieTime';
  static const tCalorieWindow = 'calorieWindow';
  static const tTimeBudget = 'timeBudget';
  static const tPrefEffort = 'prefEffort';
  static const tEasy = 'easy';
  static const tMedium = 'medium';
  static const tHard = 'hard';
  static const tShowVariantTags = 'showVariantTags';
  static const tAccessibility = 'accessibility';
  static const tReduceMotion = 'reduceMotion';
  static const tSystem = 'system';
  static const tReduced = 'reduced';
  static const tNormalMotion = 'normalMotion';
  static const tVisualAlert = 'visualAlert';
  static const tQuickNext = 'quickNext';
  static const tHalalNote = 'halalNote';
  static const tExportBackup = 'exportBackup';
  static const tImportBackup = 'importBackup';
  static const tBackupPassword = 'backupPassword';
  static const tEncryptToggle = 'encryptToggle';
  static const tMerge = 'merge';
  static const tReplace = 'replace';
  static const tRestoreOk = 'restoreOk';
  static const tEncryptedPrompt = 'encryptedPrompt';
  static const tWrongPassword = 'wrongPassword';
  static const tCorrupted = 'corrupted';
  static const tInvalidFormat = 'invalidFormat';
  static const tExportOk = 'exportOk';
  static const tExportFail = 'exportFail';
  static const tAbout = 'about';
  static const tAboutBody = 'aboutBody';
  static const tOnboardingSteps = 'onboardingSteps';
  static const tChooseLanguage = 'chooseLanguage';
  static const tWhatsYourName = 'whatsYourName';
  static const tDietAllergies = 'dietAllergies';
  static const tYourWindows = 'yourWindows';
  static const tConfirmProfile = 'confirmProfile';
  static const tOnboardingReady = 'onboardingReady';
  static const tFeatured = 'featured';
  static const tRightNow = 'rightNow';
  static const tHeroes = 'heroes';
  static const tQuickEasy = 'quickEasy';
  static const tRediscover = 'rediscover';
  static const tVol = 'vol';
  static const tIssue = 'issue';
  static const tColophon = 'colophon';
  static const tCooked = 'cooked';
  static const tResume = 'resume';
  static const tPause = 'pause';
  static const tStartFresh = 'startFresh';
  static const tTimer = 'timer';
  static const tServingsScale = 'servingsScale';
  static const tStep = 'step';
  static const tYouDidIt = 'youDidIt';
  static const tCompletionLine = 'completionLine';
  static const tTypeIngredient = 'typeIngredient';
  static const tNoIngredientMatch = 'noIngredientMatch';
  static const tShowOutOfRange = 'showOutOfRange';
  static const tHideOutOfRange = 'hideOutOfRange';
  static const tOutOfRange = 'outOfRange';
  static const tSavedOn = 'savedOn';
  static const tCookedOn = 'cookedOn';
  static const tWeek = 'week';
  static const tAny = 'any';
  static const tClassic = 'classic';
  static const tClearHistory = 'clearHistory';
  static const tHistoryEmpty = 'historyEmpty';
  static const tCookbookEmpty = 'cookbookEmpty';
  static const tSearchHint = 'searchHint';
  static const tTags = 'tags';
  static const tStringIt = 'stringIt';
  static const tBacklogFeed = 'backlogFeed';
  static const tHomeTabKey = 'homeTabKey';
  static const tBrowseAll = 'browseAll';
  static const tIndexTitle = 'indexTitle';
  static const tTheEnd = 'theEnd';
  static const tAgo = 'ago';
  static const tBacklogEmpty = 'backlogEmpty';
  static const tCompleted = 'completed';
  static const tQuickTap = 'quickTap';
  static const tTapToAdvance = 'tapToAdvance';
  static const tCookingHistory = 'cookingHistory';
  static const tSavedRecipes = 'savedRecipes';
  static const tDaysAgo = 'daysAgo';
  static const tSharedServingsNote = 'sharedServingsNote';
  static const tShopEmpty = 'shopEmpty';
  static const tShoppingHint = 'shoppingHint';
  static const tAddRecipes = 'addRecipes';
  static const tWeekExported = 'weekExported';
  static const tRecipeSources = 'recipeSources';
  static const tWeekAlbum = 'weekAlbum';
  static const tRecipes = 'recipes';
  static const tSlotsFilled = 'slotsFilled';
  static const tEdit = 'edit';
  static const tNoIngredient = 'noIngredient';
  static const tAttrNote = 'attrNote';
  static const tCalorieToleranceNote = 'calorieToleranceNote';
  static const tData = 'data';
  static const tVarietyLine = 'varietyLine';
  static const tCookMore = 'cookMore';
  static const tBackupNote = 'backupNote';
  static const tChooseName = 'chooseName';
}

final Map<String, String> _en = {
  L10n.tBack: 'back',
  L10n.tSave: 'save',
  L10n.tSaved: 'saved',
  L10n.tCancel: 'cancel',
  L10n.tDone: 'done',
  L10n.tNext: 'next',
  L10n.tConfirm: 'confirm',
  L10n.tHomeLoading: 'loading the paper',
  L10n.tCookbookTab: 'cookbook',
  L10n.tHomeTab: 'feed',
  L10n.tPlanTab: 'meal plan',
  L10n.tShopTab: 'shopping',
  L10n.tSettings: 'settings',
  L10n.tFaq: 'help & faq',
  L10n.tInsights: 'shopping insights',
  L10n.tBackup: 'backup & restore',
  L10n.tCookMode: 'cook mode',
  L10n.tStartCooking: 'start cooking',
  L10n.tIngredients: 'ingredients',
  L10n.tMethod: 'method',
  L10n.tMacros: 'macros',
  L10n.tPerServing: 'per serving',
  L10n.tCalories: 'calories',
  L10n.tProtein: 'protein',
  L10n.tCarbs: 'carbs',
  L10n.tFat: 'fat',
  L10n.tTime: 'time',
  L10n.tEffort: 'effort',
  L10n.tDiet: 'diet',
  L10n.tCalorieLevel: 'calorie level',
  L10n.tMinutes: 'min',
  L10n.tServes: 'serves',
  L10n.tNoVersionYet: 'no {a} × {b} version yet',
  L10n.tNoVariantYet: 'no {x} yet',
  L10n.tLearnMore: 'learn more',
  L10n.tGuideWhat: 'what it is',
  L10n.tGuideTips: 'tricks',
  L10n.tGuideStorage: 'storage',
  L10n.tGuideFind: 'where to find it',
  L10n.tNoResults: 'no results',
  L10n.tContentRequest: 'we noted "{q}" locally — it lands on your next backup export.',
  L10n.tRequestSaved: 'request saved',
  L10n.tClear: 'clear',
  L10n.tSearchRecipes: 'search recipes & dishes',
  L10n.tFilters: 'filters',
  L10n.tUnsaved: 'save for later',
  L10n.tAddToShopping: 'add to shopping list',
  L10n.tRemoveShopping: 'remove from shopping list',
  L10n.tExportWeek: 'export week to shopping list',
  L10n.tThisWeek: 'this week',
  L10n.tPrevWeek: 'last week',
  L10n.tNextWeek: 'next week',
  L10n.tBreakfast: 'breakfast',
  L10n.tLunch: 'lunch',
  L10n.tDinner: 'dinner',
  L10n.tAssign: 'assign a recipe',
  L10n.tFromCookbookMine: 'from my cookbook',
  L10n.tClearSlot: 'clear this slot',
  L10n.tViewRecipe: 'view recipe',
  L10n.tAisles: 'aisles',
  L10n.tClearChecked: 'clear checked',
  L10n.tVariety: 'unique ingredients',
  L10n.tUniqueAdded: 'most added',
  L10n.tSeasonal: 'seasonal rhythm',
  L10n.tInsightsEmpty: 'add recipes to your shopping list and insights grow here.',
  L10n.tProfile: 'profile',
  L10n.tName: 'name',
  L10n.tLanguage: 'language',
  L10n.tAvoidClass: 'avoid — whole families',
  L10n.tAvoidIng: 'avoid — specific ingredients',
  L10n.tRequiredAttrs: 'required',
  L10n.tCalorieTarget: 'calorie target',
  L10n.tTimeBudget: 'time budget',
  L10n.tPrefEffort: 'preferred effort',
  L10n.tEasy: 'easy',
  L10n.tMedium: 'medium',
  L10n.tHard: 'hard',
  L10n.tShowVariantTags: 'show variant tags on cards',
  L10n.tAccessibility: 'accessibility',
  L10n.tReduceMotion: 'reduce motion',
  L10n.tSystem: 'follow system',
  L10n.tReduced: 'reduced',
  L10n.tNormalMotion: 'default',
  L10n.tVisualAlert: 'visual flash when a timer completes',
  L10n.tQuickNext: 'quick-tap to advance steps (one-handed cook mode)',
  L10n.tHalalNote: 'we surface halal-friendly ingredients — never certification. certification lives with sourcing, not with a recipe.',
  L10n.tExportBackup: 'export backup',
  L10n.tImportBackup: 'import backup',
  L10n.tBackupPassword: 'backup password (optional)',
  L10n.tEncryptToggle: 'encrypt the .json with AES-256-GCM (the .gz stays portable)',
  L10n.tMerge: 'merge — add to what I have',
  L10n.tReplace: 'replace — overwrite everything',
  L10n.tRestoreOk: 'backup restored.',
  L10n.tEncryptedPrompt: 'this backup is encrypted — enter the password',
  L10n.tWrongPassword: 'incorrect password. please try again.',
  L10n.tCorrupted: 'backup file is corrupted and cannot be restored.',
  L10n.tInvalidFormat: 'this file is not a valid morphcook backup.',
  L10n.tExportOk: 'backup written — the share sheet is open.',
  L10n.tExportFail: 'could not write the backup.',
  L10n.tAbout: 'about',
  L10n.tAboutBody: 'morphcook v1 — the same dish for every body. offline-only, no account, no telemetry. recipes ship with the app and are human-reviewed.',
  L10n.tChooseLanguage: 'choose your language · wähle deine sprache',
  L10n.tWhatsYourName: 'what should the paper call you?',
  L10n.tDietAllergies: 'how do you eat?',
  L10n.tCalorieTime: 'your windows',
  L10n.tConfirmProfile: 'everything in order?',
  L10n.tOnboardingReady: 'your cookbook is ready.',
  L10n.tFeatured: 'featured today',
  L10n.tRightNow: 'cooking right now',
  L10n.tHeroes: 'this week’s heroes',
  L10n.tFromCookbook: 'from your cookbook',
  L10n.tQuickEasy: 'quick & easy',
  L10n.tRediscover: 'rediscover',
  L10n.tVol: 'vol. 1',
  L10n.tIssue: 'issue',
  L10n.tColophon: 'morphcook — set & printed on your phone. no server, no tracking. only recipes.',
  L10n.tCooked: 'cooked',
  L10n.tResume: 'resume',
  L10n.tPause: 'pause',
  L10n.tStartFresh: 'start fresh',
  L10n.tTimer: 'timer',
  L10n.tServingsScale: 'servings',
  L10n.tStep: 'step',
  L10n.tYouDidIt: 'you did it.',
  L10n.tCompletionLine: 'that’s dinner, the quiet kind.',
  L10n.tTypeIngredient: 'type an ingredient…',
  L10n.tNoIngredientMatch: 'no ingredient matches',
  L10n.tShowOutOfRange: 'show versions outside my calorie window',
  L10n.tHideOutOfRange: 'hide versions outside my calorie window',
  L10n.tOutOfRange: 'this version is outside your current filters',
  L10n.tSavedOn: 'saved {d}d ago',
  L10n.tCookedOn: 'cooked {d}',
  L10n.tWeek: 'week {w}',
  L10n.tAny: 'any',
  L10n.tClassic: 'classic',
  L10n.tClearHistory: 'clear history',
  L10n.tHistoryEmpty: 'nothing cooked yet — the pan is watching.',
  L10n.tCookbookEmpty: 'save a variant from a dish page; it lands here.',
  L10n.tSearchHint: 'döner, pad thai, tofu…',
  L10n.tTags: 'tags',
  L10n.tStringIt: 'note it for the next corpus',
  L10n.tBacklogFeed: 'the daily table',
  L10n.tCompleted: 'done',
  L10n.tQuickTap: 'quick-tap',
  L10n.tTapToAdvance: 'tap the step to advance',
  L10n.tCookingHistory: 'cooking history',
  L10n.tSavedRecipes: 'saved recipes',
  L10n.tHomeTabKey: 'feed',
  L10n.tBrowseAll: 'browse all dishes',
  L10n.tIndexTitle: 'the index',
  L10n.tTheEnd: '— the end —',
  L10n.tAgo: 'ago',
  L10n.tBacklogEmpty: 'no requests yet',
  L10n.tDaysAgo: 'days ago',
  L10n.tSharedServingsNote: '{n} recipes appear more than once — servings share',
  L10n.tShopEmpty: 'the list is empty — add dishes from a recipe',
  L10n.tShoppingHint: 'open a dish page to add its ingredients here.',
  L10n.tAddRecipes: 'add recipes',
  L10n.tWeekExported: 'added {n} recipes to the shopping list',
  L10n.tRecipeSources: 'recipe sources',
  L10n.tWeekAlbum: 'week album',
  L10n.tRecipes: 'recipes',
  L10n.tSlotsFilled: 'slots filled',
  L10n.tEdit: 'edit',
  L10n.tNoIngredient: 'no ingredients marked yet',
  L10n.tAttrNote: 'chosen methods become filters',
  L10n.tCalorieToleranceNote: '±150 kcal window',
  L10n.tData: 'data',
  L10n.tVarietyLine: 'you added {a} distinct ingredients across {b} recipes',
  L10n.tCookMore: 'add dishes to your list to grow your insight',
  L10n.tBackupNote: 'a backup lives on your own device — import it again to restore',
  L10n.tChooseName: 'optional',
};

final Map<String, String> _de = {
  L10n.tBack: 'zurück',
  L10n.tSave: 'speichern',
  L10n.tSaved: 'gespeichert',
  L10n.tCancel: 'abbrechen',
  L10n.tDone: 'fertig',
  L10n.tNext: 'weiter',
  L10n.tConfirm: 'bestätigen',
  L10n.tHomeLoading: 'die zeit wird gesetzt',
  L10n.tCookbookTab: 'kochbuch',
  L10n.tPlanTab: 'essensplan',
  L10n.tShopTab: 'einkaufen',
  L10n.tSettings: 'einstellungen',
  L10n.tFaq: 'hilfe & faq',
  L10n.tInsights: 'einkaufs-einblicke',
  L10n.tBackup: 'backup & wiederherstellung',
  L10n.tCookMode: 'kochmodus',
  L10n.tStartCooking: 'loskochen',
  L10n.tIngredients: 'zutaten',
  L10n.tMethod: 'zubereitung',
  L10n.tMacros: 'makros',
  L10n.tPerServing: 'pro portion',
  L10n.tCalories: 'kalorien',
  L10n.tProtein: 'eiweiß',
  L10n.tCarbs: 'kohlenhydrate',
  L10n.tFat: 'fett',
  L10n.tTime: 'zeit',
  L10n.tEffort: 'aufwand',
  L10n.tDiet: 'ernährung',
  L10n.tCalorieLevel: 'kalorienlevel',
  L10n.tMinutes: 'min',
  L10n.tServes: 'portionen',
  L10n.tNoVersionYet: 'noch keine variante {a} × {b}',
  L10n.tNoVariantYet: 'noch kein {x}',
  L10n.tLearnMore: 'mehr erfahren',
  L10n.tGuideWhat: 'was es ist',
  L10n.tGuideTips: 'tricks',
  L10n.tGuideStorage: 'lagerung',
  L10n.tGuideFind: 'wo du es findest',
  L10n.tNoResults: 'keine treffer',
  L10n.tContentRequest: 'die suche „{q}“ wurde notiert.',
  L10n.tRequestSaved: 'wunsch notiert',
  L10n.tClear: 'leeren',
  L10n.tSearchRecipes: 'rezepte & gerichte suchen',
  L10n.tFilters: 'filter',
  L10n.tUnsaved: 'für später speichern',
  L10n.tAddToShopping: 'zur einkaufsliste addieren',
  L10n.tRemoveShopping: 'von einkaufsliste nehmen',
  L10n.tExportWeek: 'woche in einkaufsliste exportieren',
  L10n.tThisWeek: 'diese woche',
  L10n.tPrevWeek: 'letzte woche',
  L10n.tNextWeek: 'nächste woche',
  L10n.tBreakfast: 'frühstück',
  L10n.tLunch: 'mittag',
  L10n.tDinner: 'abendessen',
  L10n.tAssign: 'rezept zuweisen',
  L10n.tFromCookbookMine: 'aus meinem kochbuch',
  L10n.tClearSlot: 'platz leeren',
  L10n.tViewRecipe: 'rezept ansehen',
  L10n.tAisles: 'gänge',
  L10n.tClearChecked: 'abgehaktes löschen',
  L10n.tVariety: 'einzigartige zutaten',
  L10n.tUniqueAdded: 'am häufigsten hinzugefügt',
  L10n.tSeasonal: 'saisonaler rhytmus',
  L10n.tInsightsEmpty: 'füge rezepte zur einkaufsliste hinzu — hier wächst es.',
  L10n.tProfile: 'profil',
  L10n.tName: 'name',
  L10n.tLanguage: 'sprache',
  L10n.tAvoidClass: 'meiden — ganze familien',
  L10n.tAvoidIngredients: 'meiden — einzelne zutaten',
  L10n.tRequiredAttrs: 'pflicht',
  L10n.tCalorieTarget: 'kalorienziel',
  L10n.tTimeBudget: 'zeitbudget',
  L10n.tPrefEffort: 'bevorzugter aufwand',
  L10n.tEasy: 'einfach',
  L10n.tMedium: 'mittel',
  L10n.tHard: 'anspruchsvoll',
  L10n.tShowVariantTags: 'varianten-tags auf karten zeigen',
  L10n.tAccessibility: 'barrierefreiheit',
  L10n.tReduceMotion: 'bewegung reduzieren',
  L10n.tSystem: 'system folgen',
  L10n.tReduced: 'reduziert',
  L10n.tNormalMotion: 'normal',
  L10n.tVisualAlert: 'visueller blitz am ablauf eines timers',
  L10n.tQuickNext: 'schnell-tippen zum nächsten schritt (einhand-kochmodus)',
  L10n.tHalalNote: 'wir zeigen halal-kompatible zutaten — nie zertifikate. zertifizierung gehört zur beschaffung, nicht zum rezept.',
  L10n.tExportBackup: 'backup exportieren',
  L10n.tImportBackup: 'backup importieren',
  L10n.tBackupPassword: 'backup-passwort (optional)',
  L10n.tEncryptToggle: 'die json mit AES-256-GCM verschlüsseln (die gz bleibt portabel)',
  L10n.tMerge: 'zusammenführen — hinzufügen',
  L10n.tReplace: 'ersetzen — alles überschreiben',
  L10n.tRestoreOk: 'backup wiederhergestellt.',
  L10n.tEncryptedPrompt: 'dieses backup ist verschlüsselt — passwort eingeben',
  L10n.tWrongPassword: 'passwort falsch. bitte erneut versuchen.',
  L10n.tCorrupted: 'die backup-datei ist beschädigt und kann nicht wiederhergestellt werden.',
  L10n.tInvalidFormat: 'das ist kein gültiges morphcook-backup.',
  L10n.tExportOk: 'backup geschrieben — die freigabe ist offen.',
  L10n.tExportFail: 'backup konnte nicht geschrieben werden.',
  L10n.tAbout: 'über',
  L10n.tAboutBody: 'morphcook v1 — dasselbe gericht für jede essence. offline, kein konto, kein tracking. die rezepte reisen in der app und sind von menschen geprüft.',
  L10n.tOnboardingSteps: 'sprache → name → ernährung → fenster → fertig',
  L10n.tChooseLanguage: 'sprache wählen · choose a language',
  L10n.tWhatsYourName: 'wie soll dich die zeit nennen?',
  L10n.tDietAllergies: 'wie isst du?',
  L10n.tCalorieWindow: 'deine fenster',
  L10n.tConfirmProfile: 'passt alles?',
  L10n.tOnboardingReady: 'dein kochbuch ist bereit.',
  L10n.tFeatured: 'heute hervorgehoben',
  L10n.tRightNow: 'wird gerade gekocht',
  L10n.tHeroes: 'helden der woche',
  L10n.tFromCookbook: 'aus deinem kochbuch',
  L10n.tQuickEasy: 'schnell & einfach',
  L10n.tRediscover: 'wiederentdecken',
  L10n.tVol: 'jrg. 1',
  L10n.tIssue: 'ausgabe',
  L10n.tColophon: 'morphcook — gesetzt auf deinem telefon. kein server, kein tracking. nur rezepte.',
  L10n.tCooked: 'gekocht',
  L10n.tResume: 'fortfahren',
  L10n.tPause: 'pause',
  L10n.tStartFresh: 'neu beginnen',
  L10n.tTimer: 'timer',
  L10n.tServingsScale: 'portionen',
  L10n.tStep: 'schritt',
  L10n.tYouDidIt: 'geschafft.',
  L10n.tCompletionLine: 'das ist aufgetischt, die leise art.',
  L10n.tTypeIngredient: 'eine zutat tippen…',
  L10n.tNoIngredientMatch: 'keine zutat gefunden',
  L10n.tShowOutOfRange: 'versionen außerhalb des kalorienfensters zeigen',
  L10n.tHideOutOfRange: 'versionen außerhalb des fensters verstecken',
  L10n.tOutOfRange: 'diese version liegt außerhalb deiner filter',
  L10n.tSavedOn: 'vor {d} tagen gespeichert',
  L10n.tCookedOn: 'gekocht am {d}',
  L10n.tWeek: 'woche {w}',
  L10n.tAny: 'egal',
  L10n.tClassic: 'klassiker',
  L10n.tClearHistory: 'verlauf löschen',
  L10n.tHistoryEmpty: 'noch nichts gekocht — die pfanne schaut zu.',
  L10n.tCookbookEmpty: 'speichere eine variante auf der gerichtseite — sie landet hier.',
  L10n.tSearchHint: 'döner, pad thai, tofu…',
  L10n.tTags: 'tags',
  L10n.tStringIt: 'fürs nächste corpus notieren',
  L10n.tBacklogFeed: 'die tageszeitung',
  L10n.tCompleted: 'erledigt',
  L10n.tQuickTap: 'schnell-tippen',
  L10n.tTapToAdvance: 'tippe auf den schritt zum weiterschalten',
  L10n.tCookingHistory: 'koch-verlauf',
  L10n.tSavedRecipes: 'gespeicherte rezepte',
  L10n.tHomeTabKey: 'tageszeitung',
  L10n.tBrowseAll: 'alle gerichte durchstöbern',
  L10n.tIndexTitle: 'das register',
  L10n.tTheEnd: '— ende —',
  L10n.tAgo: 'her',
  L10n.tBacklogEmpty: 'noch keine wünsche',
  L10n.tDaysAgo: 'tage her',
  L10n.tSharedServingsNote: '{n} rezepte erscheinen mehrfach — portionen werden geteilt',
  L10n.tShopEmpty: 'die liste ist leer — füge gerichte aus einem rezept hinzu',
  L10n.tShoppingHint: 'öffne eine gerichtsseite, um die zutaten hinzuzufügen.',
  L10n.tAddRecipes: 'rezepte hinzufügen',
  L10n.tWeekExported: '{n} rezepte zur einkaufsliste hinzugefügt',
  L10n.tRecipeSources: 'rezept-quellen',
  L10n.tWeekAlbum: 'wochen-album',
  L10n.tRecipes: 'rezepte',
  L10n.tSlotsFilled: 'belegte plätze',
  L10n.tEdit: 'bearbeiten',
  L10n.tNoIngredient: 'noch keine zutaten markiert',
  L10n.tAttrNote: 'gewählte methoden werden filter',
  L10n.tCalorieToleranceNote: '±150 kcal fenster',
  L10n.tData: 'daten',
  L10n.tVarietyLine: 'du hast {a} einzelne zutaten aus {b} rezepten notiert',
  L10n.tCookMore: 'füge gerichte zur liste hinzu, damit die einblicke wachsen',
  L10n.tBackupNote: 'ein backup wohnt auf deinem gerät — importiere es erneut zum wiederherstellen',
  L10n.tChooseName: 'optional',
};