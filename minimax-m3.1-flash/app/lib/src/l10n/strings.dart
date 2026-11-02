/// The app's own user-facing copy.
///
/// Every string is written twice — English and German — and the app picks
/// one at runtime. Adding a third language means adding a third branch to
/// [_pick] and nothing else: no schema changes, no resource files, no
/// rebuild of the data layer.
class Strings {
  const Strings(this.lang);

  final String lang;

  /// The language the UI is currently rendered in.
  static Strings of(String lang) => Strings(lang);

  static const String english = 'en';
  static const String german = 'de';

  bool get isGerman => lang == german;

  String _p(String en, String de) => isGerman ? de : en;

  // ── App shell ────────────────────────────────────────────────────────────

  String get appName => 'MorphCook';
  String get tagline => _p(
        'every body deserves a complete cookbook',
        'jeder Körper verdient ein vollständiges Kochbuch',
      );

  String get navHome => _p('home', 'start');
  String get navCookbook => _p('cookbook', 'kochbuch');
  String get navSearch => _p('search', 'suche');
  String get navPlan => _p('plan', 'plan');
  String get navList => _p('list', 'liste');

  // ── Onboarding ───────────────────────────────────────────────────────────

  String get onboardWelcomeTitle => _p(
        'welcome to morphcook',
        'willkommen bei morphcook',
      );
  String get onboardWelcomeBody => _p(
        'the same dish exists for every body. no filters, no swaps — just a '
            'complete recipe written for you.',
        'das gleiche gericht gibt es für jeden körper. keine filter, kein '
            'tausch — nur ein vollständiges rezept, geschrieben für dich.',
      );
  String get onboardStepLanguage => _p('choose your language', 'wähle deine sprache');
  String get onboardStepName => _p('what should we call you?', 'wie sollen wir dich nennen?');
  String get onboardStepDiet => _p('how do you eat?', 'wie isst du?');
  String get onboardStepAllergies => _p('anything to leave out?', 'gibt es etwas auszuschließen?');
  String get onboardStepTargets => _p('your everyday targets', 'deine alltagsziele');
  String get onboardStepConfirm => _p('everything in order?', 'alles in ordnung?');
  String get onboardNameHint => _p('your name', 'dein name');
  String get onboardNamePlaceholder => _p('e.g. Sam', 'z. b. Sam');
  String get onboardNext => _p('next', 'weiter');
  String get onboardBack => _p('back', 'zurück');
  String get onboardFinish => _p('start cooking', 'loslegen');
  String get onboardSkip => _p('skip for now', 'später');
  String get onboardNoName => _p('you can stay anonymous', 'du kannst anonym bleiben');
  String get onboardClassAvoidance => _p('whole classes', 'ganze klassen');
  String get onboardSpecificAvoidance => _p('single ingredients', 'einzelne zutaten');
  String get onboardSearchIngredient => _p('search an ingredient…', 'zutat suchen…');
  String get onboardCalorieTarget => _p('calories per meal', 'kalorien pro mahlzeit');
  String get onboardTimeBudget => _p('time budget', 'zeitbudget');
  String get onboardingDietNote => _p(
        'these shape what you see. you can change them any time.',
        'diese einstellungen bestimmen, was du siehst. du kannst sie jederzeit ändern.',
      );

  // ── Home ─────────────────────────────────────────────────────────────────

  String greeting(String name) {
    final hour = DateTime.now().hour;
    if (isGerman) {
      if (name.isEmpty) return hour < 11 ? 'guten morgen' : (hour < 18 ? 'guten tag' : 'guten abend');
      return hour < 11
          ? 'guten morgen, $name'
          : (hour < 18 ? 'hallo, $name' : 'guten abend, $name');
    }
    if (name.isEmpty) return hour < 11 ? 'good morning' : (hour < 18 ? 'hello' : 'good evening');
    return hour < 11
        ? 'good morning, $name'
        : (hour < 18 ? 'hello, $name' : 'good evening, $name');
  }

  String get homeFeatured => _p('tonight’s pick', 'heute abend');
  String get homeQuick => _p('quick & easy', 'schnell & einfach');
  String get homeForYou => _p('picked for you', 'für dich ausgewählt');
  String get homeWeekend => _p('for a slow weekend', 'für ein ruhiges wochenende');
  String get homeCuisines => _p('by the kitchen', 'nach der küche');
  String get homeFromCookbook => _p('from your cookbook', 'aus deinem kochbuch');
  String get homeFreshIdeas => _p('you haven’t cooked in a while', 'das hast du lange nicht gekocht');
  String get homeAllDishes => _p('every dish', 'alle gerichte');
  String get homeSeeAll => _p('see all', 'alle ansehen');

  // ── Dish detail ──────────────────────────────────────────────────────────

  String get dishIngredients => _p('ingredients', 'zutaten');
  String get dishMethod => _p('method', 'zubereitung');
  String get dishMacros => _p('per serving', 'pro portion');
  String get dishSave => _p('save to cookbook', 'ins kochbuch');
  String get dishSaved => _p('saved', 'gespeichert');
  String get dishStartCooking => _p('start cooking', 'kochen starten');
  String get dishMinutes => _p('min', 'min');
  String get dishServings => _p('servings', 'portionen');
  String get dishLearnMore => _p('learn more', 'mehr erfahren');
  String get dishShowAllVersions => _p('show versions outside my target', 'zeige versionen außerhalb meines ziels');
  String get dishNotForYou => _p('not written for you — yet', 'noch nicht für dich geschrieben');

  /// The note shown under a disabled combination, e.g.
  /// "no vegan × hard version yet".
  String dishNoVariantYet(String first, String second) => _p(
        'no $first × $second version yet',
        'noch keine $first-$second-Version',
      );
  String get dishUnavailableTitle => _p(
        'no version of this dish fits your profile',
        'keine version dieses gerichts passt zu deinem profil',
      );
  String get dishUnavailableBody => _p(
        'you can still open the other versions — they are just outside your '
            'filters.',
        'du kannst die anderen versionen trotzdem öffnen — sie liegen nur '
            'außerhalb deiner filter.',
      );
  String get dishVariantOf => _p('version of', 'version von');
  String get dishIngredientsCount => _p('ingredients', 'zutaten');

  /// Why a version is outside the user's filters.
  String get dishReasonContains => _p(
        'this version contains something you have chosen to leave out.',
        'diese version enthält etwas, das du ausgeschlossen hast.',
      );
  String get dishReasonIngredient => _p(
        'this version uses an ingredient you have chosen to leave out.',
        'diese version verwendet eine zutat, die du ausgeschlossen hast.',
      );
  String get dishReasonAttribute => _p(
        'this version is missing something you asked for.',
        'diese version fehlt etwas, das du verlangt hast.',
      );
  String get dishReasonTime => _p(
        'this version takes longer than the time you allow yourself.',
        'diese version dauert länger, als du dir zugestehst.',
      );
  String get dishReasonCalories => _p(
        'this version sits outside your calorie target.',
        'diese version liegt außerhalb deines kalorienziels.',
      );

  // ── Ingredient guide ─────────────────────────────────────────────────────

  String get guideDescription => _p('what it is', 'was es ist');
  String get guideUsage => _p('how to use it', 'wie man es verwendet');
  String get guideStorage => _p('keeping it', 'aufbewahren');
  String get guideWhereToFind => _p('where to find it', 'wo man es findet');

  // ── Search ───────────────────────────────────────────────────────────────

  String get searchHint => _p('search dishes, ingredients, moods…', 'gerichte, zutaten, stimmungen suchen…');
  String get searchNoResults => _p('nothing in the cookbook matches that', 'nichts im kochbuch passt dazu');
  String get searchNoResultsBody => _p(
        'we wrote down what you were looking for. maybe it lands next release.',
        'wir haben notiert, wonach du gesucht hast. vielleicht klappt es im nächsten release.',
      );
  String get searchLogRequest => _p('tell us you’re looking for it', 'sag uns, wonach du suchst');
  String get searchFilterAll => _p('all', 'alle');
  String get searchResultsCount => _p('results', 'ergebnisse');

  // ── Cookbook ─────────────────────────────────────────────────────────────

  String get cookbookTitle => _p('your cookbook', 'dein kochbuch');
  String get cookbookEmptyTitle => _p('nothing saved yet', 'noch nichts gespeichert');
  String get cookbookEmptyBody => _p(
        'tap “save” on any recipe and it lands here.',
        'tippe auf „speichern“ bei einem rezept und es landet hier.',
      );
  String get cookbookRemove => _p('remove', 'entfernen');
  String get cookbookCount => _p('recipes', 'rezepte');

  // ── Shopping ─────────────────────────────────────────────────────────────

  String get shoppingTitle => _p('shopping list', 'einkaufsliste');
  String get shoppingEmptyTitle => _p('the list is empty', 'die liste ist leer');
  String get shoppingEmptyBody => _p(
        'add recipes from the cookbook or export a meal plan.',
        'füge rezepte aus dem kochbuch hinzu oder exportiere eine essensplanung.',
      );
  String get shoppingClear => _p('clear', 'leeren');
  String get shoppingAddNote => _p('add your own', 'eigene zeile');
  String get shoppingNoteHint => _p('e.g. bread', 'z. b. brot');
  String get shoppingAdd => _p('add', 'hinzufügen');
  String get shoppingSelectedRecipes => _p('from your recipes', 'aus deinen rezepten');
  String get shoppingNotes => _p('your own notes', 'deine eigenen notizen');
  String get shoppingInsights => _p('insights', 'analysen');
  String get shoppingClearChecked => _p('clear ticked', 'abgehakte entfernen');

  String aisleName(String aisle) {
    switch (aisle) {
      case 'produce':
        return _p('produce', 'obst & gemüse');
      case 'bakery':
        return _p('bakery', 'bäckerei');
      case 'meat-seafood':
        return _p('meat & seafood', 'fleisch & fisch');
      case 'dairy':
        return _p('dairy', 'milchprodukte');
      case 'pantry':
        return _p('pantry', 'vorratsschrank');
      case 'frozen':
        return _p('frozen', 'tiefkühl');
      case 'beverages':
        return _p('drinks', 'getränke');
      default:
        return _p('other', 'sonstiges');
    }
  }

  // ── Insights ─────────────────────────────────────────────────────────────

  String get insightsTitle => _p('shopping insights', 'einkaufsanalysen');
  String get insightsVariety => _p('variety score', 'vielfaltswert');
  String get insightsVarietyBody => _p(
        'distinct ingredients you reach for',
        'verschiedene zutaten, die du verwendest',
      );
  String get insightsTopIngredients => _p('most used ingredients', 'häufigste zutaten');
  String get insightsSeasonal => _p('by the month', 'nach monat');
  String get insightsSeasonalBody => _p(
        'what you cooked, month by month',
        'was du gekocht hast, monat für monat',
      );
  String get insightsEmpty => _p(
        'cook something and the patterns will show up here.',
        'koch mal etwas und die muster erscheinen hier.',
      );
  String monthName(int month) {
    const en = <String>[
      'january',
      'february',
      'march',
      'april',
      'may',
      'june',
      'july',
      'august',
      'september',
      'october',
      'november',
      'december',
    ];
    const de = <String>[
      'januar',
      'februar',
      'märz',
      'april',
      'mai',
      'juni',
      'juli',
      'august',
      'september',
      'oktober',
      'november',
      'dezember',
    ];
    if (month < 1 || month > 12) return '';
    return isGerman ? de[month - 1] : en[month - 1];
  }

  // ── Meal plan ────────────────────────────────────────────────────────────

  String get planTitle => _p('meal plan', 'essensplanung');
  String get planBreakfast => _p('breakfast', 'frühstück');
  String get planLunch => _p('lunch', 'mittagessen');
  String get planDinner => _p('dinner', 'abendessen');
  String get planAssign => _p('assign a recipe', 'rezept zuweisen');
  String get planEmptySlot => _p('empty', 'leer');
  String get planExport => _p('send to shopping list', 'auf die einkaufsliste');
  String get planExportDone => _p('sent to the shopping list', 'auf die einkaufsliste geschickt');
  String get planThisWeek => _p('this week', 'diese woche');
  String get planClearSlot => _p('clear this slot', 'slot leeren');
  String get planMoveHere => _p('move here', 'hierher verschieben');
  String get planPreviousWeek => _p('previous week', 'vorherige woche');
  String get planNextWeek => _p('next week', 'nächste woche');

  // ── Cook mode ────────────────────────────────────────────────────────────

  String get cookStep => _p('step', 'schritt');
  String get cookOf => _p('of', 'von');
  String get cookPrevious => _p('previous', 'zurück');
  String get cookNext => _p('next', 'weiter');
  String get cookStartTimer => _p('start timer', 'timer starten');
  String get cookPause => _p('pause', 'pause');
  String get cookResume => _p('resume', 'fortsetzen');
  String get cookDone => _p('done', 'fertig');
  String get cookFinishedTitle => _p('that’s dinner', 'das war’s');
  String get cookFinishedBody => _p(
        'plate up. you earned it.',
        'anrichten. du hast es dir verdient.',
      );
  String get cookServings => _p('portions', 'portionen');
  String get cookTimerFinished => _p('timer done', 'timer fertig');
  String get cookKeepScreenOn => _p('keep the screen awake', 'bildschirm anlassen');

  // ── Settings ─────────────────────────────────────────────────────────────

  String get settingsTitle => _p('settings', 'einstellungen');
  String get settingsProfile => _p('your profile', 'dein profil');
  String get settingsLanguage => _p('language', 'sprache');
  String get settingsDiet => _p('diet & allergies', 'ernährung & allergien');
  String get settingsAvoidFlags => _p('whole classes', 'ganze klassen');
  String get settingsAvoidIngredients => _p('single ingredients', 'einzelne zutaten');
  String get settingsRequired => _p('must include', 'muss enthalten sein');
  String get settingsTargets => _p('targets', 'ziele');
  String get settingsCalorieTarget => _p('calories per meal', 'kalorien pro mahlzeit');
  String get settingsCalorieTolerance => _p('tolerance around the target', 'toleranz um das ziel');
  String get settingsTimeBudget => _p('time budget', 'zeitbudget');
  String get settingsEffort => _p('effort mood', 'aufwands-stimmung');
  String get settingsAppearance => _p('reading & motion', 'lesen & bewegung');
  String get settingsShowVariantTags => _p('show version tags', 'versionen-tags zeigen');
  String get settingsReduceMotion => _p('reduce motion', 'bewegung reduzieren');
  String get settingsReduceMotionSystem => _p('follow the system setting', 'systemeinstellung folgen');
  String get settingsVisualAlerts => _p('flash the screen when a timer ends', 'bildschirm blinken, wenn ein timer endet');
  String get settingsQuickTap => _p('tap to skip a step', 'tippen, um einen schritt zu überspringen');
  String get settingsQuickTapBody => _p(
        'a single tap on the step moves to the next one. handy when your hands '
            'are covered in flour.',
        'ein einzelner tipp auf den schritt geht zum nächsten. praktisch, wenn '
            'die hände voller mehl sind.',
      );
  String get settingsData => _p('your data', 'deine daten');
  String get settingsExport => _p('export a backup', 'backup exportieren');
  String get settingsImport => _p('restore a backup', 'backup einspielen');
  String get settingsInsights => _p('shopping insights', 'einkaufsanalysen');
  String get settingsHelp => _p('help centre', 'hilfe-center');
  String get settingsAbout => _p('about morphcook', 'über morphcook');
  String get settingsHalalNote => _p(
        'morphcook never claims “halal-certified” or “kosher-certified”. '
            'certification is a property of sourcing and supervision, not of a '
            'recipe text. here we only surface halal-compatible ingredients.',
        'morphcook behauptet niemals „halal-zertifiziert“ oder '
            '„koscher-zertifiziert“. zertifizierung ist eine eigenschaft der '
            'beschaffung und der aufsicht, nicht des rezepts. hier zeigen wir '
            'nur halal-kompatible zutaten.',
      );
  String get settingsOfflineNote => _p(
        'morphcook works entirely offline. no account, no cloud, no tracking.',
        'morphcook funktioniert komplett offline. kein konto, keine cloud, kein tracking.',
      );
  String get settingsResetProfile => _p('reset profile', 'profil zurücksetzen');
  String get settingsResetConfirm => _p(
        'this clears your dietary preferences. your cookbook stays.',
        'das löscht deine essensvorlieben. dein kochbuch bleibt.',
      );

  // ── Backup ───────────────────────────────────────────────────────────────

  String get backupTitle => _p('backup', 'backup');
  String get backupExportBody => _p(
        'two files are written side by side: a readable json file and a '
            'compressed one. save whichever you prefer.',
        'es werden zwei dateien nebeneinander geschrieben: eine lesbare '
            'json-datei und eine komprimierte. nimm, was dir lieber ist.',
      );
  String get backupPassword => _p('password (optional)', 'passwort (optional)');
  String get backupPasswordHint => _p(
        'encrypts the json file with aes-256-gcm',
        'verschlüsselt die json-datei mit aes-256-gcm',
      );
  String get backupExportAction => _p('export', 'exportieren');
  String get backupExported => _p('backup ready to share', 'backup bereit zum teilen');
  String get backupImportAction => _p('choose a file', 'datei wählen');
  String get backupMerge => _p('merge with my data', 'mit meinen daten zusammenführen');
  String get backupReplace => _p('replace my data', 'meine daten ersetzen');
  String get backupImported => _p('backup restored', 'backup wiederhergestellt');
  String get backupWrongPassword => _p(
        'incorrect password. please try again.',
        'falsches passwort. bitte erneut versuchen.',
      );
  String get backupCorrupted => _p(
        'backup file is corrupted and cannot be restored.',
        'die backup-datei ist beschädigt und kann nicht wiederhergestellt werden.',
      );
  String get backupInvalid => _p(
        'this file is not a valid morphcook backup.',
        'diese datei ist kein gültiges morphcook-backup.',
      );

  // ── FAQ ──────────────────────────────────────────────────────────────────

  String get faqTitle => _p('help centre', 'hilfe-center');
  String get faqHint => _p('search the help centre…', 'hilfe-center durchsuchen…');
  String get faqEmpty => _p('nothing matches that', 'nichts passt dazu');
  String get faqAll => _p('all', 'alle');
  String get faqDietary => _p('dietary', 'ernährung');
  String get faqVisibility => _p('visibility', 'sichtbarkeit');
  String get faqFeatures => _p('features', 'funktionen');
  String get faqTroubleshooting => _p('troubleshooting', 'problemlösung');
  String get faqBackup => _p('backup', 'backup');
  String get faqRelated => _p('related', 'verwandt');
  String get faqOpenSettings => _p('open settings', 'einstellungen öffnen');
  String get faqOpenSearch => _p('open search', 'suche öffnen');

  // ── Dimensions ───────────────────────────────────────────────────────────

  String get dimensionDiet => _p('diet', 'ernährung');
  String get dimensionEffort => _p('effort', 'aufwand');
  String get dimensionCalorie => _p('calorie level', 'kalorienniveau');

  /// The label of a diet value.
  String dietLabel(String diet) {
    switch (diet) {
      case 'classic':
        return _p('classic', 'klassisch');
      case 'vegan':
        return 'vegan';
      case 'vegetarian':
        return _p('vegetarian', 'vegetarisch');
      case 'pescatarian':
        return _p('pescatarian', 'pescatarisch');
      case 'halal':
        return 'halal';
      case 'kosher':
        return 'kosher';
      case 'keto':
        return 'keto';
      case 'gluten-free':
        return _p('gluten-free', 'glutenfrei');
      case 'dairy-free':
        return _p('dairy-free', 'ohne milchprodukte');
      default:
        return diet.replaceAll('-', ' ');
    }
  }

  /// The label of an effort value.
  String effortLabel(String effort) {
    switch (effort) {
      case 'easy':
        return _p('easy', 'einfach');
      case 'medium':
        return _p('medium', 'mittel');
      case 'hard':
        return _p('hard', 'aufwendig');
      default:
        return effort;
    }
  }

  /// The label of a calorie bucket.
  String calorieBucketLabel(String bucket) {
    switch (bucket) {
      case '≤400':
        return '≤400';
      case '≤600':
        return '≤600';
      case '≤800':
        return '≤800';
      case '>800':
        return '>800';
      default:
        return bucket;
    }
  }

  // ── Generic ──────────────────────────────────────────────────────────────
  String get genericCancel => _p('cancel', 'abbrechen');
  String get genericSave => _p('save', 'speichern');
  String get genericDelete => _p('delete', 'löschen');
  String get genericClose => _p('close', 'schließen');
  String get genericRetry => _p('try again', 'erneut versuchen');
  String get genericError => _p('something went wrong', 'etwas ist schiefgelaufen');
  String get genericLoading => _p('loading…', 'lädt…');
  String get genericNone => _p('none', 'keine');
  String get genericYes => _p('yes', 'ja');
  String get genericNo => _p('no', 'nein');
  String get genericOn => _p('on', 'an');
  String get genericOff => _p('off', 'aus');
  String get genericVersion => _p('version', 'version');
  String get genericCookedOn => _p('cooked', 'gekocht');
  String get genericTimes => _p('times', 'mal');
}
