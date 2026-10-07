/// All UI copy, bilingual (DE + EN). Adding a language is a data addition.
class Strings {
  final String lang;

  const Strings(this.lang);

  String tr(String key) {
    final entry = _table[key];
    if (entry == null) return key;
    return entry[lang] ?? entry['en'] ?? key;
  }

  // ── masthead & shell ──────────────────────────────────────────────────
  String get appName => tr('app.name');
  String get tagline => tr('app.tagline');
  String get datelineNo => tr('app.dateline_no');
  String get navHome => tr('nav.home');
  String get navCookbook => tr('nav.cookbook');
  String get navWeek => tr('nav.week');
  String get navMarket => tr('nav.market');
  String get navSettings => tr('nav.settings');

  // ── onboarding ────────────────────────────────────────────────────────
  String get onbWelcome => tr('onb.welcome');
  String get onbWelcomeBody => tr('onb.welcome_body');
  String get onbPickLanguage => tr('onb.pick_language');
  String get onbYourName => tr('onb.your_name');
  String get onbNameHint => tr('onb.name_hint');
  String get onbDietTitle => tr('onb.diet_title');
  String get onbDietBody => tr('onb.diet_body');
  String get onbAllergiesTitle => tr('onb.allergies_title');
  String get onbAllergiesBody => tr('onb.allergies_body');
  String get onbAvoidIngredientHint => tr('onb.avoid_ingredient_hint');
  String get onbBudgetTitle => tr('onb.budget_title');
  String get onbBudgetBody => tr('onb.budget_body');
  String get onbCalorieTarget => tr('onb.calorie_target');
  String get onbMaxTime => tr('onb.max_time');
  String get onbEffort => tr('onb.effort');
  String get onbConfirmTitle => tr('onb.confirm_title');
  String get onbConfirmBody => tr('onb.confirm_body');
  String get onbStartCooking => tr('onb.start_cooking');
  String get onbNext => tr('onb.next');
  String get onbBack => tr('onb.back');
  String get onbSkip => tr('onb.skip');
  String get onbMinutes => tr('onb.minutes');
  String get onbKcal => tr('onb.kcal');

  // ── home ──────────────────────────────────────────────────────────────
  String get homeSearchHint => tr('home.search_hint');
  String get homeLeadStory => tr('home.lead_story');
  String get homeQuickTonight => tr('home.quick_tonight');
  String get homeForYourTable => tr('home.for_your_table');
  String get homeKitchenBinder => tr('home.kitchen_binder');
  String get homeWaysToMake => tr('home.ways_to_make');
  String get homeNoResults => tr('home.no_results');
  String get homeCuisineShelf => tr('home.cuisine_shelf');

  // ── dish detail ───────────────────────────────────────────────────────
  String get dishBackToPaper => tr('dish.back_to_paper');
  String get dishTime => tr('dish.time');
  String get dishServes => tr('dish.serves');
  String get dishPerServing => tr('dish.per_serving');
  String get dishDimDiet => tr('dish.dim_diet');
  String get dishDimEffort => tr('dish.dim_effort');
  String get dishDimCalorie => tr('dish.dim_calorie');
  String get dishUnreachable => tr('dish.unreachable');
  String get dishBlockedByProfile => tr('dish.blocked_by_profile');
  String get dishOutsideTarget => tr('dish.outside_target');
  String get dishShowOutsideTarget => tr('dish.show_outside_target');
  String get dishIngredients => tr('dish.ingredients');
  String get dishMethod => tr('dish.method');
  String get dishMacros => tr('dish.macros');
  String get dishContains => tr('dish.contains');
  String get dishCookThis => tr('dish.cook_this');
  String get dishSaveVersion => tr('dish.save_version');
  String get dishSaved => tr('dish.saved');
  String get dishAddToMarket => tr('dish.add_to_market');
  String get dishAddedToMarket => tr('dish.added_to_market');
  String get dishLearnMore => tr('dish.learn_more');
  String get dishStepTimer => tr('dish.step_timer');
  String get dishVariantOf => tr('dish.variant_of');

  // ── cook mode ─────────────────────────────────────────────────────────
  String get cookStepOf => tr('cook.step_of');
  String get cookStartTimer => tr('cook.start_timer');
  String get cookPause => tr('cook.pause');
  String get cookResume => tr('cook.resume');
  String get cookPrev => tr('cook.prev');
  String get cookNext => tr('cook.next_step');
  String get cookDone => tr('cook.done');
  String get cookDoneTitle => tr('cook.done_title');
  String get cookDoneBody => tr('cook.done_body');
  String get cookTimerDone => tr('cook.timer_done');
  String get cookServings => tr('cook.servings');
  String get cookQuickTapHint => tr('cook.quick_tap_hint');
  String get cookExit => tr('cook.exit');

  // ── cookbook ──────────────────────────────────────────────────────────
  String get cbSaved => tr('cb.saved');
  String get cbHistory => tr('cb.history');
  String get cbEmptySaved => tr('cb.empty_saved');
  String get cbEmptySavedBody => tr('cb.empty_saved_body');
  String get cbEmptyHistory => tr('cb.empty_history');
  String get cbSavedAt => tr('cb.saved_at');
  String get cbCookedAt => tr('cb.cooked_at');
  String get cbThisWeek => tr('cb.this_week');
  String get cbLastWeek => tr('cb.last_week');

  // ── search ────────────────────────────────────────────────────────────
  String get searchTitle => tr('search.title');
  String get searchHint => tr('search.hint');
  String get searchFilters => tr('search.filters');
  String get searchNoResults => tr('search.no_results');
  String get searchNoResultsBody => tr('search.no_results_body');
  String get searchTagAll => tr('search.tag_all');

  // ── shopping ──────────────────────────────────────────────────────────
  String get shopTitle => tr('shop.title');
  String get shopClearChecked => tr('shop.clear_checked');
  String get shopEmpty => tr('shop.empty');
  String get shopEmptyBody => tr('shop.empty_body');
  String get shopForRecipes => tr('shop.for_recipes');
  String get shopAddItem => tr('shop.add_item');
  String get shopInsights => tr('shop.insights');
  String get shopChecked => tr('shop.checked');

  // ── insights ──────────────────────────────────────────────────────────
  String get insTitle => tr('ins.title');
  String get insVariety => tr('ins.variety');
  String get insVarietyBody => tr('ins.variety_body');
  String get insTop => tr('ins.top');
  String get insSeasonal => tr('ins.seasonal');
  String get insEmpty => tr('ins.empty');
  String get insTimes => tr('ins.times');

  // ── meal plan ─────────────────────────────────────────────────────────
  String get planTitle => tr('plan.title');
  String get planThisWeek => tr('plan.this_week');
  String get planWeekToMarket => tr('plan.week_to_market');
  String get planExported => tr('plan.exported');
  String get planEmptySlot => tr('plan.empty_slot');
  String get planPickRecipe => tr('plan.pick_recipe');
  String get planClearSlot => tr('plan.clear_slot');
  String get planMove => tr('plan.move');
  String get planBreakfast => tr('plan.breakfast');
  String get planLunch => tr('plan.lunch');
  String get planDinner => tr('plan.dinner');

  // ── settings ──────────────────────────────────────────────────────────
  String get setTitle => tr('set.title');
  String get setProfile => tr('set.profile');
  String get setEditProfile => tr('set.edit_profile');
  String get setLanguage => tr('set.language');
  String get setAdaptation => tr('set.adaptation');
  String get setAvoidClasses => tr('set.avoid_classes');
  String get setAvoidSpecific => tr('set.avoid_specific');
  String get setRequired => tr('set.required');
  String get setCalorieTarget => tr('set.calorie_target');
  String get setMaxTime => tr('set.max_time');
  String get setEffort => tr('set.effort');
  String get setInterface => tr('set.interface');
  String get setShowVariantTags => tr('set.show_variant_tags');
  String get setReduceMotion => tr('set.reduce_motion');
  String get setReduceMotionSystem => tr('set.reduce_motion_system');
  String get setVisualAlert => tr('set.visual_alert');
  String get setQuickTap => tr('set.quick_tap');
  String get setHalalNote => tr('set.halal_note');
  String get setBackup => tr('set.backup');
  String get setBackupExport => tr('set.backup_export');
  String get setBackupImport => tr('set.backup_import');
  String get setHelp => tr('set.help');
  String get setInsights => tr('set.insights');
  String get setAbout => tr('set.about');
  String get setSaved => tr('set.saved');

  // ── backup ────────────────────────────────────────────────────────────
  String get backupTitle => tr('backup.title');
  String get backupPassword => tr('backup.password');
  String get backupPasswordHint => tr('backup.password_hint');
  String get backupPasswordOptional => tr('backup.password_optional');
  String get backupExport => tr('backup.export');
  String get backupImport => tr('backup.import');
  String get backupMergeNote => tr('backup.merge_note');
  String get backupMerge => tr('backup.merge');
  String get backupReplace => tr('backup.replace');
  String get backupImported => tr('backup.imported');
  String get backupWrongPassword => tr('backup.wrong_password');
  String get backupCorrupted => tr('backup.corrupted');
  String get backupInvalid => tr('backup.invalid');
  String get backupEnterPassword => tr('backup.enter_password');
  String get backupEncryptedNotice => tr('backup.encrypted_notice');

  // ── faq ───────────────────────────────────────────────────────────────
  String get faqTitle => tr('faq.title');
  String get faqSearchHint => tr('faq.search_hint');
  String get faqAll => tr('faq.all');
  String get faqEmpty => tr('faq.empty');
  String get faqCategories => tr('faq.categories');

  // ── common ────────────────────────────────────────────────────────────
  String get commonSave => tr('common.save');
  String get commonCancel => tr('common.cancel');
  String get commonDelete => tr('common.delete');
  String get commonClose => tr('common.close');
  String get commonRetry => tr('common.retry');
  String get commonLoading => tr('common.loading');
  String get commonError => tr('common.error');
  String get commonMin => tr('common.min');
  String get commonKcal => tr('common.kcal');
  String get commonGreeting => tr('common.greeting');

  String greeting(String name) => tr('common.greeting').replaceAll('{name}', name);

  String monthName(int month) => tr('month.$month');
  String weekdayName(int weekday) => tr('weekday.$weekday');

  // ── effort / diet labels (data-driven fallback) ───────────────────────
  String effortLabel(String effort) => tr('effort.$effort');
  String dietLabel(String diet) => tr('diet.$diet');
  String flagLabel(String flag) => tr('flag.$flag');
  String aisleLabel(String aisle) => tr('aisle.$aisle');
  String faqCategoryLabel(String category) => tr('faqcat.$category');
}

const Map<String, Map<String, String>> _table = {
  'app.name': {'en': 'morphcook', 'de': 'morphcook'},
  'app.tagline': {
    'en': 'the same dish exists for every body',
    'de': 'für jeden körper existiert dasselbe gericht',
  },
  'app.dateline_no': {'en': 'no. 001 — vol. i', 'de': 'nr. 001 — band i'},
  'nav.home': {'en': 'home', 'de': 'start'},
  'nav.cookbook': {'en': 'cookbook', 'de': 'kochbuch'},
  'nav.week': {'en': 'week', 'de': 'woche'},
  'nav.market': {'en': 'market', 'de': 'markt'},
  'nav.settings': {'en': 'settings', 'de': 'einstellungen'},

  'onb.welcome': {'en': 'welcome to the paper', 'de': 'willkommen im heft'},
  'onb.welcome_body': {
    'en':
        'morphcook is your cookbook — every dish exists in a version written for the way you eat. no filters that punish you, no watered-down swaps.',
    'de':
        'morphcook ist dein kochbuch — jedes gericht existiert in einer version, geschrieben für deine art zu essen. keine filter, die bestrafen, keine halbherzigen ersatzlösungen.',
  },
  'onb.pick_language': {'en': 'first — your language', 'de': 'zuerst — deine sprache'},
  'onb.your_name': {'en': 'what should we call you?', 'de': 'wie sollen wir dich nennen?'},
  'onb.name_hint': {'en': 'your name…', 'de': 'dein name…'},
  'onb.diet_title': {'en': 'how do you eat?', 'de': 'wie isst du?'},
  'onb.diet_body': {
    'en': 'pick everything that applies — your cookbook is built around it.',
    'de': 'wähle alles Zutreffende — dein kochbuch wird darum gebaut.',
  },
  'onb.allergies_title': {'en': 'anything to leave out?', 'de': 'etwas weglassen?'},
  'onb.allergies_body': {
    'en':
        'whole classes (all dairy, all nuts) or single ingredients (apples, cilantro). both combine — anything you avoid never reaches your feed.',
    'de':
        'ganze klassen (alle milchprodukte, alle nüsse) oder einzelne zutaten (äpfel, koriander). beides kombiniert — was du meidest, landet nie in deinem feed.',
  },
  'onb.avoid_ingredient_hint': {
    'en': 'type an ingredient to avoid…',
    'de': 'zutat eingeben, die du meiden willst…',
  },
  'onb.budget_title': {'en': 'your day, your budget', 'de': 'dein tag, dein budget'},
  'onb.budget_body': {
    'en': 'a per-meal calorie target and a time budget. both are hard filters — you can relax them per dish, any time.',
    'de': 'ein kalorienziel pro mahlzeit und ein zeitbudget. beides sind harte filter — pro gericht kannst du sie jederzeit lockern.',
  },
  'onb.calorie_target': {'en': 'calorie target / meal', 'de': 'kalorienziel / mahlzeit'},
  'onb.max_time': {'en': 'max time per recipe', 'de': 'max. zeit pro rezept'},
  'onb.effort': {'en': 'effort mood today', 'de': 'aufwands-stimmung heute'},
  'onb.confirm_title': {'en': 'that’s your cookbook', 'de': 'das ist dein kochbuch'},
  'onb.confirm_body': {
    'en': 'everything can be changed later in settings. let’s cook.',
    'de': 'alles lässt sich später in den einstellungen ändern. lass uns kochen.',
  },
  'onb.start_cooking': {'en': 'start cooking', 'de': 'kochen beginnen'},
  'onb.next': {'en': 'next', 'de': 'weiter'},
  'onb.back': {'en': 'back', 'de': 'zurück'},
  'onb.skip': {'en': 'skip', 'de': 'überspringen'},
  'onb.minutes': {'en': 'min', 'de': 'min'},
  'onb.kcal': {'en': 'kcal', 'de': 'kcal'},

  'home.search_hint': {'en': 'dish, ingredient, craving…', 'de': 'gericht, zutat, gelüste…'},
  'home.lead_story': {'en': "tonight's lead story", 'de': 'heute die titelgeschichte'},
  'home.quick_tonight': {'en': 'quick tonight — under 30', 'de': 'schnell heute — unter 30'},
  'home.for_your_table': {'en': 'for your table', 'de': 'für deinen tisch'},
  'home.kitchen_binder': {'en': 'from the kitchen binder', 'de': 'aus dem küchenheft'},
  'home.ways_to_make': {'en': '{n} ways to make it', 'de': '{n} arten, es zu machen'},
  'home.no_results': {'en': 'nothing found', 'de': 'nichts gefunden'},
  'home.cuisine_shelf': {'en': 'the {cuisine} shelf', 'de': 'das regal {cuisine}'},

  'dish.back_to_paper': {'en': '← back to the paper', 'de': '← zurück zum heft'},
  'dish.time': {'en': 'time', 'de': 'zeit'},
  'dish.serves': {'en': 'serves', 'de': 'portionen'},
  'dish.per_serving': {'en': '/ serving', 'de': '/ portion'},
  'dish.dim_diet': {'en': 'diet', 'de': 'diät'},
  'dish.dim_effort': {'en': 'effort', 'de': 'aufwand'},
  'dish.dim_calorie': {'en': 'calorie level', 'de': 'kaloriestufe'},
  'dish.unreachable': {
    'en': 'no {diet} × {effort} version yet',
    'de': 'noch keine kombination {diet} × {effort}',
  },
  'dish.blocked_by_profile': {
    'en': 'clashes with your dietary rules',
    'de': ' kollidiert mit deinen essensregeln',
  },
  'dish.outside_target': {'en': 'outside your calorie target', 'de': 'außerhalb deines kalorienziels'},
  'dish.show_outside_target': {
    'en': 'show versions outside my target',
    'de': 'versionen außerhalb meines ziels zeigen',
  },
  'dish.ingredients': {'en': 'ingredients', 'de': 'zutaten'},
  'dish.method': {'en': 'method', 'de': 'zubereitung'},
  'dish.macros': {'en': 'macros — per serving', 'de': 'makros — pro portion'},
  'dish.contains': {'en': 'contains', 'de': 'enthält'},
  'dish.cook_this': {'en': 'cook this', 'de': 'jetzt kochen'},
  'dish.save_version': {'en': 'save this version', 'de': 'diese version speichern'},
  'dish.saved': {'en': 'saved to your cookbook', 'de': 'im kochbuch gespeichert'},
  'dish.add_to_market': {'en': 'add → market list', 'de': '→ marktliste'},
  'dish.added_to_market': {'en': 'added to your market list', 'de': 'zur marktliste hinzugefügt'},
  'dish.learn_more': {'en': 'learn more', 'de': 'mehr erfahren'},
  'dish.step_timer': {'en': 'timer', 'de': 'timer'},
  'dish.variant_of': {'en': 'a version of {dish}', 'de': 'eine version von {dish}'},

  'cook.step_of': {'en': 'step {i} of {n}', 'de': 'schritt {i} von {n}'},
  'cook.start_timer': {'en': 'start timer', 'de': 'timer starten'},
  'cook.pause': {'en': 'pause', 'de': 'pause'},
  'cook.resume': {'en': 'resume', 'de': 'fortsetzen'},
  'cook.prev': {'en': 'previous', 'de': 'zurück'},
  'cook.next_step': {'en': 'next step', 'de': 'nächster schritt'},
  'cook.done': {'en': 'done — enjoy', 'de': 'fertig — guten appetit'},
  'cook.done_title': {'en': 'dish complete', 'de': 'gericht fertig'},
  'cook.done_body': {
    'en': 'you cooked {dish}. it’s in your history now.',
    'de': 'du hast {dish} gekocht. es ist jetzt in deinem verlauf.',
  },
  'cook.timer_done': {'en': 'timer is done', 'de': 'timer ist abgelaufen'},
  'cook.servings': {'en': 'servings', 'de': 'portionen'},
  'cook.quick_tap_hint': {
    'en': 'tap anywhere to jump to the next step',
    'de': 'tippe irgendwo für den nächsten schritt',
  },
  'cook.exit': {'en': 'exit cook mode', 'de': 'kochmodus verlassen'},

  'cb.saved': {'en': 'saved', 'de': 'gespeichert'},
  'cb.history': {'en': 'history', 'de': 'verlauf'},
  'cb.empty_saved': {'en': 'nothing saved yet', 'de': 'noch nichts gespeichert'},
  'cb.empty_saved_body': {
    'en': 'tap “save this version” on any dish — you save your döner, not just “döner”.',
    'de': 'tippe „diese version speichern“ bei einem gericht — du speicherst deinen döner, nicht nur „döner“.',
  },
  'cb.empty_history': {'en': 'nothing cooked yet', 'de': 'noch nichts gekocht'},
  'cb.saved_at': {'en': 'saved {date}', 'de': 'gespeichert {date}'},
  'cb.cooked_at': {'en': 'cooked {date}', 'de': 'gekocht {date}'},
  'cb.this_week': {'en': 'this week', 'de': 'diese woche'},
  'cb.last_week': {'en': 'last week', 'de': 'letzte woche'},

  'search.title': {'en': 'search the paper', 'de': 'das heft durchsuchen'},
  'search.hint': {'en': 'dish, ingredient, craving…', 'de': 'gericht, zutat, gelüste…'},
  'search.filters': {'en': 'filters', 'de': 'filter'},
  'search.no_results': {'en': 'no recipes found', 'de': 'keine rezepte gefunden'},
  'search.no_results_body': {
    'en': 'your filters may be narrow — try relaxing your calorie target or time budget in settings.',
    'de': 'deine filter sind vielleicht zu eng — lockere kalorienziel oder zeitbudget in den einstellungen.',
  },
  'search.tag_all': {'en': 'all', 'de': 'alle'},

  'shop.title': {'en': 'market list', 'de': 'marktliste'},
  'shop.clear_checked': {'en': 'clear checked', 'de': 'abgehakte löschen'},
  'shop.empty': {'en': 'your list is empty', 'de': 'deine liste ist leer'},
  'shop.empty_body': {
    'en': 'add ingredients from any dish, or send a whole week from your meal plan.',
    'de': 'füge zutaten von einem gericht hinzu, oder schicke eine ganze woche aus deinem plan.',
  },
  'shop.for_recipes': {'en': 'for {n} recipes', 'de': 'für {n} rezepte'},
  'shop.add_item': {'en': 'add item', 'de': 'eintrag hinzufügen'},
  'shop.insights': {'en': 'shopping insights', 'de': 'einkaufs-einblicke'},
  'shop.checked': {'en': 'in the basket', 'de': 'im korb'},

  'ins.title': {'en': 'shopping insights', 'de': 'einkaufs-einblicke'},
  'ins.variety': {'en': 'variety score', 'de': 'vielfalts-score'},
  'ins.variety_body': {
    'en': '{n} unique ingredients on your lists — the wider your basket, the wider your table.',
    'de': '{n} einzigartige zutaten in deinen listen — je breiter der korb, desto breiter der tisch.',
  },
  'ins.top': {'en': 'top added ingredients', 'de': 'meistgekaufte zutaten'},
  'ins.seasonal': {'en': 'through the year', 'de': 'durch das jahr'},
  'ins.empty': {'en': 'no shopping data yet — add a few recipes first.', 'de': 'noch keine einkaufsdaten — füge zuerst ein paar rezepte hinzu.'},
  'ins.times': {'en': '×{n}', 'de': '×{n}'},

  'plan.title': {'en': 'the week', 'de': 'die woche'},
  'plan.this_week': {'en': 'this week', 'de': 'diese woche'},
  'plan.week_to_market': {'en': 'week → market list', 'de': 'woche → marktliste'},
  'plan.exported': {'en': 'week sent to your market list', 'de': 'woche an die marktliste geschickt'},
  'plan.empty_slot': {'en': 'empty', 'de': 'leer'},
  'plan.pick_recipe': {'en': 'pick a recipe', 'de': 'rezept wählen'},
  'plan.clear_slot': {'en': 'clear slot', 'de': 'platz löschen'},
  'plan.move': {'en': 'move', 'de': 'verschieben'},
  'plan.breakfast': {'en': 'breakfast', 'de': 'frühstück'},
  'plan.lunch': {'en': 'lunch', 'de': 'mittag'},
  'plan.dinner': {'en': 'dinner', 'de': 'abendessen'},

  'set.title': {'en': 'settings', 'de': 'einstellungen'},
  'set.profile': {'en': 'your profile', 'de': 'dein profil'},
  'set.edit_profile': {'en': 'edit profile', 'de': 'profil bearbeiten'},
  'set.language': {'en': 'language', 'de': 'sprache'},
  'set.adaptation': {'en': 'adaptation preferences', 'de': 'anpassungs-einstellungen'},
  'set.avoid_classes': {'en': 'avoid — whole classes', 'de': 'meiden — ganze klassen'},
  'set.avoid_specific': {'en': 'avoid — specific ingredients', 'de': 'meiden — einzelne zutaten'},
  'set.required': {'en': 'must have', 'de': 'muss enthalten'},
  'set.calorie_target': {'en': 'calorie target / meal', 'de': 'kalorienziel / mahlzeit'},
  'set.max_time': {'en': 'max time / recipe', 'de': 'max. zeit / rezept'},
  'set.effort': {'en': 'preferred effort', 'de': 'bevorzugter aufwand'},
  'set.interface': {'en': 'interface & accessibility', 'de': 'oberfläche & barrierefreiheit'},
  'set.show_variant_tags': {'en': 'show variant tags on cards', 'de': 'varianten-tags auf karten zeigen'},
  'set.reduce_motion': {'en': 'reduce motion', 'de': 'bewegungen reduzieren'},
  'set.reduce_motion_system': {'en': 'follow system setting', 'de': 'systemeinstellung folgen'},
  'set.visual_alert': {'en': 'visual timer alert (flash)', 'de': 'visueller timer-alarm (blitzen)'},
  'set.quick_tap': {'en': 'one-handed cook mode (tap to advance)', 'de': 'ein-hand-kochmodus (tippen = weiter)'},
  'set.halal_note': {
    'en':
        'note: “halal” and “kosher” here mean halal-compatible / kosher-compatible ingredients. certification is a property of sourcing (slaughter, supervision), not of a recipe text — we never claim certification.',
    'de':
        'hinweis: „halal“ und „koscher“ bedeuten hier halal-kompatible / koscher-kompatible zutaten. zertifizierung ist eine eigenschaft der herkunft (schlachtung, aufsicht), nicht eines rezepttextes — wir behaupten nie eine zertifizierung.',
  },
  'set.backup': {'en': 'backup & restore', 'de': 'sichern & wiederherstellen'},
  'set.backup_export': {'en': 'export backup', 'de': 'backup exportieren'},
  'set.backup_import': {'en': 'import backup', 'de': 'backup importieren'},
  'set.help': {'en': 'help & faq', 'de': 'hilfe & faq'},
  'set.insights': {'en': 'shopping insights', 'de': 'einkaufs-einblicke'},
  'set.about': {'en': 'about morphcook', 'de': 'über morphcook'},
  'set.saved': {'en': 'saved', 'de': 'gespeichert'},

  'backup.title': {'en': 'backup & restore', 'de': 'sichern & wiederherstellen'},
  'backup.password': {'en': 'password (optional)', 'de': 'passwort (optional)'},
  'backup.password_hint': {'en': 'protects sensitive data with aes-256-gcm', 'de': 'schützt sensible daten mit aes-256-gcm'},
  'backup.password_optional': {
    'en': 'without a password the json file stays human-readable; the .gz file is always unencrypted.',
    'de': 'ohne passwort bleibt die json-datei menschenlesbar; die .gz-datei ist immer unverschlüsselt.',
  },
  'backup.export': {'en': 'export backup', 'de': 'backup exportieren'},
  'backup.import': {'en': 'import backup', 'de': 'backup importieren'},
  'backup.merge_note': {
    'en': 'merge keeps your current data and adds what is missing; replace clears local data first.',
    'de': 'zusammenführen behält deine daten und ergänzt fehlendes; ersetzen löscht zuerst die lokalen daten.',
  },
  'backup.merge': {'en': 'merge with my data', 'de': 'mit meinen daten zusammenführen'},
  'backup.replace': {'en': 'replace my data', 'de': 'meine daten ersetzen'},
  'backup.imported': {'en': 'backup restored', 'de': 'backup wiederhergestellt'},
  'backup.wrong_password': {'en': 'incorrect password. please try again.', 'de': 'falsches passwort. bitte versuche es erneut.'},
  'backup.corrupted': {'en': 'backup file is corrupted and cannot be restored.', 'de': 'die backup-datei ist beschädigt und kann nicht wiederhergestellt werden.'},
  'backup.invalid': {'en': 'this file is not a valid morphcook backup.', 'de': 'diese datei ist kein gültiges morphcook-backup.'},
  'backup.enter_password': {'en': 'this backup is encrypted — enter the password', 'de': 'dieses backup ist verschlüsselt — passwort eingeben'},
  'backup.encrypted_notice': {'en': 'encrypted backup detected', 'de': 'verschlüsseltes backup erkannt'},

  'faq.title': {'en': 'help & faq', 'de': 'hilfe & faq'},
  'faq.search_hint': {'en': 'search the help center…', 'de': 'hilfe durchsuchen…'},
  'faq.all': {'en': 'all topics', 'de': 'alle themen'},
  'faq.empty': {'en': 'nothing found — try another word', 'de': 'nichts gefunden — versuche ein anderes wort'},
  'faq.categories': {'en': 'topics', 'de': 'themen'},

  'common.save': {'en': 'save', 'de': 'speichern'},
  'common.cancel': {'en': 'cancel', 'de': 'abbrechen'},
  'common.delete': {'en': 'delete', 'de': 'löschen'},
  'common.close': {'en': 'close', 'de': 'schließen'},
  'common.retry': {'en': 'retry', 'de': 'erneut versuchen'},
  'common.loading': {'en': 'loading…', 'de': 'lädt…'},
  'common.error': {'en': 'something went wrong', 'de': 'etwas ist schiefgelaufen'},
  'common.min': {'en': 'min', 'de': 'min'},
  'common.kcal': {'en': 'kcal', 'de': 'kcal'},
  'common.greeting': {'en': 'hey {name}', 'de': 'hey {name}'},

  'effort.easy': {'en': 'easy', 'de': 'einfach'},
  'effort.medium': {'en': 'medium', 'de': 'mittel'},
  'effort.hard': {'en': 'hard', 'de': 'aufwändig'},

  'diet.classic': {'en': 'classic', 'de': 'klassisch'},
  'diet.vegan': {'en': 'vegan', 'de': 'vegan'},
  'diet.vegetarian': {'en': 'vegetarian', 'de': 'vegetarisch'},
  'diet.pescatarian': {'en': 'pescatarian', 'de': 'pescetarisch'},
  'diet.keto': {'en': 'keto', 'de': 'keto'},
  'diet.halal': {'en': 'halal-friendly', 'de': 'halal-freundlich'},
  'diet.kosher': {'en': 'kosher-friendly', 'de': 'koscher-freundlich'},
  'diet.gluten-free': {'en': 'gluten-free', 'de': 'glutenfrei'},
  'diet.sugar-free': {'en': 'sugar-free', 'de': 'zuckerfrei'},
  'diet.low-fodmap': {'en': 'low-fodmap', 'de': 'fodmap-arm'},
  'diet.lactose-free': {'en': 'lactose-free', 'de': 'laktosefrei'},

  'flag.pork': {'en': 'pork', 'de': 'schwein'},
  'flag.beef': {'en': 'beef', 'de': 'rind'},
  'flag.lamb': {'en': 'lamb', 'de': 'lamm'},
  'flag.poultry': {'en': 'poultry', 'de': 'geflügel'},
  'flag.fish': {'en': 'fish', 'de': 'fisch'},
  'flag.shellfish': {'en': 'shellfish', 'de': 'schalentiere'},
  'flag.molluscs': {'en': 'molluscs', 'de': 'weichtiere'},
  'flag.egg': {'en': 'egg', 'de': 'ei'},
  'flag.dairy': {'en': 'dairy', 'de': 'milch'},
  'flag.gluten': {'en': 'gluten', 'de': 'gluten'},
  'flag.soy': {'en': 'soy', 'de': 'soja'},
  'flag.peanuts': {'en': 'peanuts', 'de': 'erdnüsse'},
  'flag.tree-nuts': {'en': 'tree nuts', 'de': 'baumnüsse'},
  'flag.sesame': {'en': 'sesame', 'de': 'sesam'},
  'flag.mustard': {'en': 'mustard', 'de': 'senf'},
  'flag.celery': {'en': 'celery', 'de': 'sellerie'},
  'flag.lupin': {'en': 'lupin', 'de': 'lupine'},
  'flag.sulphites': {'en': 'sulphites', 'de': 'sulfite'},
  'flag.alcohol': {'en': 'alcohol', 'de': 'alkohol'},
  'flag.caffeine': {'en': 'caffeine', 'de': 'koffein'},
  'flag.added-sugar': {'en': 'added sugar', 'de': 'zusatzzucker'},
  'flag.high-fodmap': {'en': 'high-fodmap', 'de': 'fodmap-reich'},
  'flag.honey': {'en': 'honey', 'de': 'honig'},
  'flag.vegan': {'en': 'vegan', 'de': 'vegan'},
  'flag.vegetarian': {'en': 'vegetarian', 'de': 'vegetarisch'},
  'flag.pescatarian': {'en': 'pescatarian', 'de': 'pescetarisch'},
  'flag.halal': {'en': 'halal-compatible', 'de': 'halal-kompatibel'},
  'flag.kosher': {'en': 'kosher-compatible', 'de': 'koscher-kompatibel'},
  'flag.low-fodmap': {'en': 'low-fodmap', 'de': 'fodmap-arm'},
  'flag.sugar-free': {'en': 'sugar-free', 'de': 'zuckerfrei'},
  'flag.lactose-free': {'en': 'lactose-free', 'de': 'laktosefrei'},

  'aisle.produce': {'en': 'produce', 'de': 'obst & gemüse'},
  'aisle.meat': {'en': 'meat & fish', 'de': 'fleisch & fisch'},
  'aisle.dairy': {'en': 'dairy & eggs', 'de': 'molkerei & eier'},
  'aisle.pantry': {'en': 'pantry', 'de': 'vorrat'},
  'aisle.spices': {'en': 'spices & oils', 'de': 'gewürze & öle'},
  'aisle.bakery': {'en': 'bakery', 'de': 'bäckerei'},
  'aisle.frozen': {'en': 'frozen', 'de': 'tiefkühl'},

  'faqcat.dietary': {'en': 'dietary matching', 'de': 'diät-abgleich'},
  'faqcat.visibility': {'en': 'recipe visibility', 'de': 'sichtbarkeit von rezepten'},
  'faqcat.features': {'en': 'features', 'de': 'funktionen'},
  'faqcat.troubleshooting': {'en': 'troubleshooting', 'de': 'problembehebung'},
  'faqcat.privacy': {'en': 'privacy & backup', 'de': 'datenschutz & backup'},

  'month.1': {'en': 'january', 'de': 'januar'},
  'month.2': {'en': 'february', 'de': 'februar'},
  'month.3': {'en': 'march', 'de': 'märz'},
  'month.4': {'en': 'april', 'de': 'april'},
  'month.5': {'en': 'may', 'de': 'mai'},
  'month.6': {'en': 'june', 'de': 'juni'},
  'month.7': {'en': 'july', 'de': 'juli'},
  'month.8': {'en': 'august', 'de': 'august'},
  'month.9': {'en': 'september', 'de': 'september'},
  'month.10': {'en': 'october', 'de': 'oktober'},
  'month.11': {'en': 'november', 'de': 'november'},
  'month.12': {'en': 'december', 'de': 'dezember'},

  'weekday.1': {'en': 'monday', 'de': 'montag'},
  'weekday.2': {'en': 'tuesday', 'de': 'dienstag'},
  'weekday.3': {'en': 'wednesday', 'de': 'mittwoch'},
  'weekday.4': {'en': 'thursday', 'de': 'donnerstag'},
  'weekday.5': {'en': 'friday', 'de': 'freitag'},
  'weekday.6': {'en': 'saturday', 'de': 'samstag'},
  'weekday.7': {'en': 'sunday', 'de': 'sonntag'},
};
