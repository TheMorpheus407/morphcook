/// Hand-written localization. Two languages at launch (EN + DE); adding a
/// language is purely additive — append entries to [_en] and [_de] and add
/// a new map. No code generation needed.
class Strings {
  final String lang;
  const Strings(this.lang);

  String _v(String key) {
    final map = lang == 'de' ? _de : _en;
    return map[key] ?? _en[key] ?? key;
  }

  // Branding
  String get appName => _v('app_name');
  String get tagline => _v('tagline');
  String get everyBody => _v('every_body');

  // Onboarding
  String get languageStepTitle => _v('lang_step_title');
  String get languageStepBody => _v('lang_step_body');
  String get languageEnglish => _v('language_english');
  String get languageGerman => _v('language_german');

  String get nameStepTitle => _v('name_step_title');
  String get nameStepBody => _v('name_step_body');
  String get nameHint => _v('name_hint');
  String get next => _v('next');
  String get back => _v('back');
  String get skip => _v('skip');
  String get done => _v('done');
  String get save => _v('save');
  String get cancel => _v('cancel');
  String get delete => _v('delete');

  String get dietStepTitle => _v('diet_step_title');
  String get dietStepBody => _v('diet_step_body');
  String get allergiesLabel => _v('allergies_label');
  String get specificIngredients => _v('specific_ingredients');
  String get addIngredient => _v('add_ingredient');
  String get searchIngredient => _v('search_ingredient');

  String get targetStepTitle => _v('target_step_title');
  String get targetStepBody => _v('target_step_body');
  String get calorieTarget => _v('calorie_target');
  String get calorieTargetHint => _v('calorie_target_hint');
  String get timeBudget => _v('time_budget');
  String get timeBudgetHint => _v('time_budget_hint');
  String get effortMood => _v('effort_mood');

  String get confirmStepTitle => _v('confirm_step_title');
  String get confirmStepBody => _v('confirm_step_body');
  String get youAvoid => _v('you_avoid');
  String get yourTarget => _v('your_target');
  String get yourBudget => _v('your_budget');
  String get noPreference => _v('no_preference');
  String get nothingSelected => _v('nothing_selected');

  // Home
  String get homeMasthead => _v('home_masthead');
  String get homeIssue => _v('home_issue');
  String get featuredToday => _v('featured_today');
  String get readMore => _v('read_more');
  String get forYourMorning => _v('for_your_morning');
  String get forYourEvening => _v('for_your_evening');
  String get forYourWeekend => _v('for_your_weekend');
  String get freshIdeas => _v('fresh_ideas');
  String get quickToday => _v('quick_today');
  String get neverShownNoMatch => _v('never_shown_no_match');

  // Tabs
  String get tabHome => _v('tab_home');
  String get tabSearch => _v('tab_search');
  String get tabCookbook => _v('tab_cookbook');
  String get tabPlan => _v('tab_plan');
  String get tabSettings => _v('tab_settings');

  // Dish detail
  String get ingredients => _v('ingredients');
  String get method => _v('method');
  String get macros => _v('macros');
  String get servings => _v('servings');
  String get minutes => _v('minutes');
  String get diet => _v('diet');
  String get effort => _v('effort');
  String get calorieLevel => _v('calorie_level');
  String get classicLabel => _v('classic_label');
  String get veganLabel => _v('vegan_label');
  String get cookNow => _v('cook_now');
  String get addToList => _v('add_to_list');
  String get saveToCookbook => _v('save_to_cookbook');
  String get savedToCookbook => _v('saved_to_cookbook');
  String get unavailableCombo => _v('unavailable_combo');
  String get learnMore => _v('learn_more');
  String get ignoreCalorieForDish => _v('ignore_calorie_for_dish');

  // Cookbook
  String get cookbookEmpty => _v('cookbook_empty');
  String get cookbookEmptyBody => _v('cookbook_empty_body');
  String get cookbookHeader => _v('cookbook_header');

  // Search
  String get searchHint => _v('search_hint');
  String get searchEmpty => _v('search_empty');
  String get searchNoResults => _v('search_no_results');
  String get filters => _v('filters');
  String get loggedAsRequest => _v('logged_as_request');

  // Meal plan
  String get planThisWeek => _v('plan_this_week');
  String get planNextWeek => _v('plan_next_week');
  String get planPrevWeek => _v('plan_prev_week');
  String get breakfast => _v('breakfast');
  String get lunch => _v('lunch');
  String get dinner => _v('dinner');
  String get tapToAssign => _v('tap_to_assign');
  String get clearSlot => _v('clear_slot');
  String get exportToShopping => _v('export_to_shopping');
  String get monday => _v('mon');
  String get tuesday => _v('tue');
  String get wednesday => _v('wed');
  String get thursday => _v('thu');
  String get friday => _v('fri');
  String get saturday => _v('sat');
  String get sunday => _v('sun');

  // Shopping
  String get shoppingList => _v('shopping_list');
  String get shoppingEmpty => _v('shopping_empty');
  String get shoppingInsights => _v('shopping_insights');
  String get clearChecked => _v('clear_checked');
  String get clearAll => _v('clear_all');
  String get varietyScore => _v('variety_score');
  String get topIngredients => _v('top_ingredients');
  String get seasonalBreakdown => _v('seasonal_breakdown');
  String get uniqueIngredients => _v('unique_ingredients');

  // Cook mode
  String get cookModeTitle => _v('cook_mode_title');
  String get stepOf => _v('step_of');
  String get pause => _v('pause');
  String get resume => _v('resume');
  String get prev => _v('prev');
  String get nextStep => _v('next_step');
  String get finishCooking => _v('finish_cooking');
  String get cookingDone => _v('cooking_done');
  String get cookingDoneBody => _v('cooking_done_body');
  String get logToHistory => _v('log_to_history');
  String get timerStarted => _v('timer_started');

  // Settings
  String get settingsTitle => _v('settings_title');
  String get profile => _v('profile');
  String get language => _v('language');
  String get languageGerman2 => _v('language_german');
  String get accessibility => _v('accessibility');
  String get reduceMotion => _v('reduce_motion');
  String get visualAlerts => _v('visual_alerts');
  String get quickTapAdvance => _v('quick_tap_advance');
  String get backupRestore => _v('backup_restore');
  String get exportBackup => _v('export_backup');
  String get importBackup => _v('import_backup');
  String get backupPassword => _v('backup_password');
  String get faqHelp => _v('faq_help');
  String get insights => _v('insights');
  String get followsSystem => _v('follows_system');
  String get on => _v('on');
  String get off => _v('off');

  // FAQ
  String get faqTitle => _v('faq_title');
  String get faqSearchHint => _v('faq_search_hint');
  String get faqRelated => _v('faq_related');
  String get faqAllCategories => _v('faq_all_categories');

  // Backup
  String get backupExportTitle => _v('backup_export_title');
  String get backupExportBody => _v('backup_export_body');
  String get backupCreateFiles => _v('backup_create_files');
  String get backupShared => _v('backup_shared');
  String get backupImportTitle => _v('backup_import_title');
  String get backupImportBody => _v('backup_import_body');
  String get backupImportPick => _v('backup_import_pick');
  String get backupImported => _v('backup_imported');
  String get backupOptionalPassword => _v('backup_optional_password');
  String get backupPasswordPrompt => _v('backup_password_prompt');
  String get backupWrongPassword => _v('backup_wrong_password');
  String get backupCorrupted => _v('backup_corrupted');
  String get backupNotValid => _v('backup_not_valid');
  String get backupMergeOrReplace => _v('backup_merge_or_replace');
  String get backupMerge => _v('backup_merge');
  String get backupReplace => _v('backup_replace');
  String get backupHumanReadable => _v('backup_human_readable');
  String get backupCompressed => _v('backup_compressed');

  // Misc
  String get noteHalalDisclaimer => _v('note_halal_disclaimer');
  String get profileEditor => _v('profile_editor');
  String get changeName => _v('change_name');
  String get changeAvoidances => _v('change_avoidances');
  String get aisleProduce => _v('aisle_produce');
  String get aisleMeatFish => _v('aisle_meat_fish');
  String get aisleDairy => _v('aisle_dairy');
  String get aislePantry => _v('aisle_pantry');
  String get aislePlantMilks => _v('aisle_plant_milks');
  String get aisleOther => _v('aisle_other');
  String get insightsEmpty => _v('insights_empty');
}

const _en = <String, String>{
  'app_name': 'MorphCook',
  'tagline': "every body's cookbook",
  'every_body': 'every body',

  'lang_step_title': 'first things first',
  'lang_step_body': 'pick a language. you can switch later.',
  'language_english': 'english',
  'language_german': 'deutsch',

  'name_step_title': 'what shall we call you?',
  'name_step_body': 'a kitchen feels better with a name on the door.',
  'name_hint': 'your first name',
  'next': 'next',
  'back': 'back',
  'skip': 'skip',
  'done': 'done',
  'save': 'save',
  'cancel': 'cancel',
  'delete': 'delete',

  'diet_step_title': 'what do you avoid?',
  'diet_step_body': 'pick categories. add specific ingredients below if you like.',
  'allergies_label': 'classes & diets',
  'specific_ingredients': 'specific ingredients',
  'add_ingredient': 'add ingredient',
  'search_ingredient': 'search ingredients…',

  'target_step_title': 'your daily rhythm',
  'target_step_body': 'rough numbers. nothing fixed. you can change all of this whenever.',
  'calorie_target': 'per-meal calorie target',
  'calorie_target_hint': '~600 is gentle, ~800 hearty.',
  'time_budget': 'time budget',
  'time_budget_hint': 'how long do you cook on a normal day?',
  'effort_mood': 'effort mood',

  'confirm_step_title': 'looks good?',
  'confirm_step_body': 'this is your cookbook now. let\'s open it.',
  'you_avoid': 'you avoid',
  'your_target': 'per-meal target',
  'your_budget': 'time budget',
  'no_preference': 'no preference',
  'nothing_selected': 'nothing selected',

  'home_masthead': 'the morphcook daily',
  'home_issue': 'issue',
  'featured_today': 'featured today',
  'read_more': 'read more',
  'for_your_morning': 'for your morning',
  'for_your_evening': 'for your evening',
  'for_your_weekend': 'a slower weekend',
  'fresh_ideas': 'fresh ideas',
  'quick_today': 'quick today',
  'never_shown_no_match': 'no recipes match your filters here. loosen one in settings.',

  'tab_home': 'home',
  'tab_search': 'search',
  'tab_cookbook': 'cookbook',
  'tab_plan': 'plan',
  'tab_settings': 'settings',

  'ingredients': 'ingredients',
  'method': 'method',
  'macros': 'macros',
  'servings': 'servings',
  'minutes': 'min',
  'diet': 'diet',
  'effort': 'effort',
  'calorie_level': 'calorie level',
  'classic_label': 'classic',
  'vegan_label': 'vegan',
  'cook_now': 'cook now',
  'add_to_list': 'add to list',
  'save_to_cookbook': 'save',
  'saved_to_cookbook': 'saved',
  'unavailable_combo': 'no recipe for this combo yet.',
  'learn_more': 'learn more',
  'ignore_calorie_for_dish': 'show all calories for this dish',

  'cookbook_empty': 'your cookbook is empty',
  'cookbook_empty_body': 'tap save on a recipe to keep it here.',
  'cookbook_header': 'your cookbook',

  'search_hint': 'search dishes, ingredients…',
  'search_empty': 'start typing to find a dish.',
  'search_no_results': 'no recipe matches that. we noted it for the corpus team.',
  'filters': 'filters',
  'logged_as_request': 'noted.',

  'plan_this_week': 'this week',
  'plan_next_week': 'next week →',
  'plan_prev_week': '← previous week',
  'breakfast': 'breakfast',
  'lunch': 'lunch',
  'dinner': 'dinner',
  'tap_to_assign': 'tap to add',
  'clear_slot': 'clear',
  'export_to_shopping': 'export → shopping list',
  'mon': 'mon',
  'tue': 'tue',
  'wed': 'wed',
  'thu': 'thu',
  'fri': 'fri',
  'sat': 'sat',
  'sun': 'sun',

  'shopping_list': 'shopping list',
  'shopping_empty': 'nothing on your list yet.',
  'shopping_insights': 'shopping insights',
  'clear_checked': 'clear checked',
  'clear_all': 'clear all',
  'variety_score': 'variety',
  'top_ingredients': 'top ingredients',
  'seasonal_breakdown': 'seasonal',
  'unique_ingredients': 'unique ingredients',

  'cook_mode_title': 'cook mode',
  'step_of': 'step {a} of {b}',
  'pause': 'pause',
  'resume': 'resume',
  'prev': '← back',
  'next_step': 'next →',
  'finish_cooking': 'finish',
  'cooking_done': 'plated.',
  'cooking_done_body': 'add it to history?',
  'log_to_history': 'log to history',
  'timer_started': 'timer started',

  'settings_title': 'settings',
  'profile': 'profile',
  'language': 'language',
  'accessibility': 'accessibility',
  'reduce_motion': 'reduce motion',
  'visual_alerts': 'visual alerts (timer flash)',
  'quick_tap_advance': 'quick-tap step advance',
  'backup_restore': 'backup & restore',
  'export_backup': 'export backup',
  'import_backup': 'import backup',
  'backup_password': 'backup password',
  'faq_help': 'help center',
  'insights': 'shopping insights',
  'follows_system': 'follows system',
  'on': 'on',
  'off': 'off',

  'faq_title': 'help center',
  'faq_search_hint': 'search help…',
  'faq_related': 'related',
  'faq_all_categories': 'all',

  'backup_export_title': 'export backup',
  'backup_export_body': 'we save two files: one readable, one compressed. you choose where they go.',
  'backup_create_files': 'create files & share',
  'backup_shared': 'backup ready.',
  'backup_import_title': 'import backup',
  'backup_import_body': 'pick a morphcook backup file. we detect format and encryption.',
  'backup_import_pick': 'pick file',
  'backup_imported': 'imported.',
  'backup_optional_password': 'optional password (encrypts JSON only)',
  'backup_password_prompt': 'enter backup password',
  'backup_wrong_password': 'incorrect password. please try again.',
  'backup_corrupted': 'backup file is corrupted and cannot be restored.',
  'backup_not_valid': 'this file is not a valid morphcook backup.',
  'backup_merge_or_replace': 'merge with existing data or replace?',
  'backup_merge': 'merge',
  'backup_replace': 'replace',
  'backup_human_readable': 'human-readable JSON',
  'backup_compressed': 'GZip compressed (~80% smaller)',

  'note_halal_disclaimer': 'we surface halal-compatible ingredients only. certification depends on sourcing.',
  'profile_editor': 'edit profile',
  'change_name': 'name',
  'change_avoidances': 'avoidances',
  'aisle_produce': 'produce',
  'aisle_meat_fish': 'meat & fish',
  'aisle_dairy': 'dairy & eggs',
  'aisle_pantry': 'pantry',
  'aisle_plant_milks': 'plant milks',
  'aisle_other': 'other',
  'insights_empty': 'cook a few recipes to see your patterns.',
};

const _de = <String, String>{
  'app_name': 'MorphCook',
  'tagline': 'das kochbuch für jeden körper',
  'every_body': 'jeder körper',

  'lang_step_title': 'das erste',
  'lang_step_body': 'wähle eine sprache. du kannst sie später ändern.',
  'language_english': 'englisch',
  'language_german': 'deutsch',

  'name_step_title': 'wie sollen wir dich nennen?',
  'name_step_body': 'eine küche fühlt sich mit einem namen besser an.',
  'name_hint': 'dein vorname',
  'next': 'weiter',
  'back': 'zurück',
  'skip': 'überspringen',
  'done': 'fertig',
  'save': 'speichern',
  'cancel': 'abbrechen',
  'delete': 'löschen',

  'diet_step_title': 'was meidest du?',
  'diet_step_body': 'wähle kategorien. spezifische zutaten unten.',
  'allergies_label': 'klassen & ernährung',
  'specific_ingredients': 'spezifische zutaten',
  'add_ingredient': 'zutat hinzufügen',
  'search_ingredient': 'zutaten suchen…',

  'target_step_title': 'dein alltagsrhythmus',
  'target_step_body': 'grobe zahlen. nichts ist fest. alles jederzeit änderbar.',
  'calorie_target': 'kalorienziel pro mahlzeit',
  'calorie_target_hint': '~600 ist leicht, ~800 kräftig.',
  'time_budget': 'zeitbudget',
  'time_budget_hint': 'wie lange kochst du an einem normalen tag?',
  'effort_mood': 'aufwand-stimmung',

  'confirm_step_title': 'sieht gut aus?',
  'confirm_step_body': 'das ist jetzt dein kochbuch. lass uns reinschauen.',
  'you_avoid': 'du meidest',
  'your_target': 'kalorienziel',
  'your_budget': 'zeitbudget',
  'no_preference': 'keine vorliebe',
  'nothing_selected': 'nichts ausgewählt',

  'home_masthead': 'die morphcook-tageszeitung',
  'home_issue': 'ausgabe',
  'featured_today': 'heute hervorgehoben',
  'read_more': 'weiterlesen',
  'for_your_morning': 'für deinen morgen',
  'for_your_evening': 'für deinen abend',
  'for_your_weekend': 'ein langsameres wochenende',
  'fresh_ideas': 'frische ideen',
  'quick_today': 'heute schnell',
  'never_shown_no_match': 'keine rezepte passen zu deinen filtern. lockere einen in den einstellungen.',

  'tab_home': 'start',
  'tab_search': 'suche',
  'tab_cookbook': 'kochbuch',
  'tab_plan': 'plan',
  'tab_settings': 'einstellungen',

  'ingredients': 'zutaten',
  'method': 'zubereitung',
  'macros': 'nährwerte',
  'servings': 'portionen',
  'minutes': 'min',
  'diet': 'ernährung',
  'effort': 'aufwand',
  'calorie_level': 'kalorienniveau',
  'classic_label': 'klassisch',
  'vegan_label': 'vegan',
  'cook_now': 'jetzt kochen',
  'add_to_list': 'zur liste',
  'save_to_cookbook': 'merken',
  'saved_to_cookbook': 'gemerkt',
  'unavailable_combo': 'für diese kombination noch kein rezept.',
  'learn_more': 'mehr erfahren',
  'ignore_calorie_for_dish': 'alle kalorienstufen zeigen',

  'cookbook_empty': 'dein kochbuch ist leer',
  'cookbook_empty_body': 'tippe „merken" bei einem rezept.',
  'cookbook_header': 'dein kochbuch',

  'search_hint': 'gerichte, zutaten…',
  'search_empty': 'tippe los, um ein gericht zu finden.',
  'search_no_results': 'kein rezept passt. wir notieren das für das korpusteam.',
  'filters': 'filter',
  'logged_as_request': 'notiert.',

  'plan_this_week': 'diese woche',
  'plan_next_week': 'nächste woche →',
  'plan_prev_week': '← vorige woche',
  'breakfast': 'frühstück',
  'lunch': 'mittag',
  'dinner': 'abend',
  'tap_to_assign': 'antippen',
  'clear_slot': 'leeren',
  'export_to_shopping': 'export → einkaufsliste',
  'mon': 'mo',
  'tue': 'di',
  'wed': 'mi',
  'thu': 'do',
  'fri': 'fr',
  'sat': 'sa',
  'sun': 'so',

  'shopping_list': 'einkaufsliste',
  'shopping_empty': 'noch nichts auf deiner liste.',
  'shopping_insights': 'einkaufs-einblicke',
  'clear_checked': 'erledigte entfernen',
  'clear_all': 'alles entfernen',
  'variety_score': 'vielfalt',
  'top_ingredients': 'top-zutaten',
  'seasonal_breakdown': 'saisonal',
  'unique_ingredients': 'einzigartige zutaten',

  'cook_mode_title': 'kochmodus',
  'step_of': 'schritt {a} von {b}',
  'pause': 'pause',
  'resume': 'weiter',
  'prev': '← zurück',
  'next_step': 'weiter →',
  'finish_cooking': 'fertig',
  'cooking_done': 'angerichtet.',
  'cooking_done_body': 'in den verlauf aufnehmen?',
  'log_to_history': 'in verlauf',
  'timer_started': 'timer läuft',

  'settings_title': 'einstellungen',
  'profile': 'profil',
  'language': 'sprache',
  'accessibility': 'barrierefreiheit',
  'reduce_motion': 'bewegungen reduzieren',
  'visual_alerts': 'visuelle hinweise (timer-blitz)',
  'quick_tap_advance': 'schnell-tipp weiter',
  'backup_restore': 'backup & wiederherstellung',
  'export_backup': 'backup exportieren',
  'import_backup': 'backup importieren',
  'backup_password': 'backup-passwort',
  'faq_help': 'hilfecenter',
  'insights': 'einkaufs-einblicke',
  'follows_system': 'folgt system',
  'on': 'an',
  'off': 'aus',

  'faq_title': 'hilfecenter',
  'faq_search_hint': 'hilfe durchsuchen…',
  'faq_related': 'verwandt',
  'faq_all_categories': 'alle',

  'backup_export_title': 'backup exportieren',
  'backup_export_body': 'wir speichern zwei dateien: eine lesbar, eine komprimiert. du wählst, wo sie hingehen.',
  'backup_create_files': 'dateien erzeugen & teilen',
  'backup_shared': 'backup bereit.',
  'backup_import_title': 'backup importieren',
  'backup_import_body': 'wähle eine morphcook-backup-datei. format & verschlüsselung erkennen wir.',
  'backup_import_pick': 'datei wählen',
  'backup_imported': 'importiert.',
  'backup_optional_password': 'optionales passwort (verschlüsselt nur JSON)',
  'backup_password_prompt': 'backup-passwort eingeben',
  'backup_wrong_password': 'falsches passwort. bitte erneut versuchen.',
  'backup_corrupted': 'backup-datei ist beschädigt und kann nicht wiederhergestellt werden.',
  'backup_not_valid': 'diese datei ist kein gültiges morphcook-backup.',
  'backup_merge_or_replace': 'mit bestehenden daten zusammenführen oder ersetzen?',
  'backup_merge': 'zusammenführen',
  'backup_replace': 'ersetzen',
  'backup_human_readable': 'lesbares JSON',
  'backup_compressed': 'GZip komprimiert (~80% kleiner)',

  'note_halal_disclaimer': 'wir zeigen nur halal-kompatible zutaten. die zertifizierung hängt von der herkunft ab.',
  'profile_editor': 'profil bearbeiten',
  'change_name': 'name',
  'change_avoidances': 'vermeidungen',
  'aisle_produce': 'obst & gemüse',
  'aisle_meat_fish': 'fleisch & fisch',
  'aisle_dairy': 'milchprodukte & eier',
  'aisle_pantry': 'trockenwaren',
  'aisle_plant_milks': 'pflanzendrinks',
  'aisle_other': 'sonstiges',
  'insights_empty': 'koche ein paar rezepte, um muster zu sehen.',
};
