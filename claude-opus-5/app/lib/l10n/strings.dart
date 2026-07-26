import 'package:flutter/widgets.dart';

/// UI copy, DE + EN. Corpus text is `Map<lang, String>` in the assets; this
/// file is the same idea for chrome. Adding a language means adding one map
/// entry per string — never a schema change, never a code change elsewhere.
class S {
  const S(this.lang);

  static const List<String> supported = ['en', 'de'];

  static const Map<String, String> languageNames = {
    'en': 'English',
    'de': 'Deutsch',
  };

  static S of(BuildContext context) =>
      S(Localizations.localeOf(context).languageCode == 'de' ? 'de' : 'en');

  final String lang;

  bool get isGerman => lang == 'de';

  String _(String en, String de) => isGerman ? de : en;

  // --- product ------------------------------------------------------------
  String get appName => 'MorphCook';
  String get tagline => _(
    'the same dish exists for every body',
    'jedes Gericht gibt es für jeden Körper',
  );

  // --- navigation ---------------------------------------------------------
  String get navHome => _('Kitchen', 'Küche');
  String get navSearch => _('Search', 'Suche');
  String get navCookbook => _('Cookbook', 'Kochbuch');
  String get navPlan => _('Week', 'Woche');
  String get navList => _('List', 'Liste');

  // --- generic ------------------------------------------------------------
  String get done => _('Done', 'Fertig');
  String get cancel => _('Cancel', 'Abbrechen');
  String get save => _('Save', 'Speichern');
  String get saved => _('Saved', 'Gespeichert');
  String get remove => _('Remove', 'Entfernen');
  String get close => _('Close', 'Schließen');
  String get back => _('Back', 'Zurück');
  String get next => _('Next', 'Weiter');
  String get retry => _('Try again', 'Erneut versuchen');
  String get clear => _('Clear', 'Leeren');
  String get add => _('Add', 'Hinzufügen');
  String get edit => _('Edit', 'Bearbeiten');
  String get undo => _('Undo', 'Rückgängig');
  String get all => _('All', 'Alle');
  String get none => _('None', 'Keine');
  String get search => _('Search', 'Suchen');
  String get loading => _('Loading…', 'Lädt…');
  String get somethingWentWrong =>
      _('Something went sideways.', 'Da ist etwas schiefgelaufen.');
  String get thatIsEverything => _('that is everything', 'das ist alles');
  String get helpLinkLabel => _('What does this mean?', 'Was heißt das?');

  String minutes(int m) => _('$m min', '$m Min.');
  String kcal(int k) => '$k kcal';
  String servings(int n) =>
      n == 1 ? _('1 serving', '1 Portion') : _('$n servings', '$n Portionen');
  String itemsCount(int n) =>
      n == 1 ? _('1 item', '1 Eintrag') : _('$n items', '$n Einträge');
  String recipesCount(int n) =>
      n == 1 ? _('1 recipe', '1 Rezept') : _('$n recipes', '$n Rezepte');

  // --- onboarding ---------------------------------------------------------
  String get obLanguageTitle => _('First, a language', 'Zuerst eine Sprache');
  String get obLanguageBody => _(
    'Every recipe is written in both. You can switch whenever you like, and nothing is lost when you do.',
    'Jedes Rezept ist in beiden Sprachen geschrieben. Du kannst jederzeit wechseln, ohne etwas zu verlieren.',
  );
  String get obNameTitle =>
      _('What should we call you?', 'Wie sollen wir dich nennen?');
  String get obNameBody => _(
    'Only used to say hello. It stays on this device — there is no account and nothing to sign into.',
    'Nur zur Begrüßung. Der Name bleibt auf diesem Gerät — es gibt kein Konto und nichts zum Anmelden.',
  );
  String get obNameHint => _('Your name', 'Dein Name');
  String get obDietTitle => _('How do you eat?', 'Wie isst du?');
  String get obDietBody => _(
    'Pick as many as apply. Nothing disappears from the book — you will simply be shown the version of each dish that fits.',
    'Wähle so viele, wie zutreffen. Nichts verschwindet aus dem Buch — du bekommst einfach die passende Version jedes Gerichts.',
  );
  String get obAllergyTitle =>
      _('Anything to keep out?', 'Etwas, das draußen bleiben soll?');
  String get obAllergyBody => _(
    'Allergens first, then anything you just do not want in your food.',
    'Zuerst Allergene, dann alles, was du einfach nicht im Essen haben willst.',
  );
  String get obTargetsTitle => _('Time and appetite', 'Zeit und Appetit');
  String get obTargetsBody => _(
    'Both are filters, and both can be relaxed on any single dish later.',
    'Beides sind Filter, und beides lässt sich später bei jedem Gericht lockern.',
  );
  String get obConfirmTitle =>
      _('That is the whole setup', 'Das war die ganze Einrichtung');
  String get obConfirmBody => _(
    'Everything here can be changed in Settings, at any time, without losing a thing.',
    'Alles davon lässt sich jederzeit in den Einstellungen ändern, ohne etwas zu verlieren.',
  );
  String get obStart => _('Open the cookbook', 'Kochbuch öffnen');
  String get obSkip => _('Skip for now', 'Erst mal überspringen');
  String obGreeting(String name) => name.isEmpty
      ? _('Hello.', 'Hallo.')
      : _('Hello, $name.', 'Hallo, $name.');

  // --- home ---------------------------------------------------------------
  String get homeToday => _('Today', 'Heute');
  String get homeFeatured => _('The one for tonight', 'Das für heute Abend');
  String get homeFeaturedMorning =>
      _('The one for this morning', 'Das für heute früh');
  String get homeEveryday => _('Everyday', 'Alltag');
  String get homeBrowse => _('Browse by kind', 'Nach Art stöbern');
  String get homeContinueCooking => _('Still on the hob', 'Noch auf dem Herd');
  String get homeResume => _('Pick it back up', 'Weitermachen');
  String get homeSavedShort => _('From your cookbook', 'Aus deinem Kochbuch');
  String get homeNothingVisible => _(
    'Your filters are strict enough that nothing is showing.',
    'Deine Filter sind so streng, dass nichts angezeigt wird.',
  );
  String get homeLoosen => _('Loosen them', 'Lockern');

  String greetingMorning(String name) => name.isEmpty
      ? _('Good morning', 'Guten Morgen')
      : _('Morning, $name', 'Morgen, $name');
  String greetingDay(String name) =>
      name.isEmpty ? _('Hello', 'Hallo') : _('Hello, $name', 'Hallo, $name');
  String greetingEvening(String name) => name.isEmpty
      ? _('Good evening', 'Guten Abend')
      : _('Evening, $name', 'Abend, $name');

  // --- dish ---------------------------------------------------------------
  String get dishIngredients => _('Ingredients', 'Zutaten');
  String get dishMethod => _('Method', 'Zubereitung');
  String get dishMacros => _('Per serving', 'Pro Portion');
  String get dishTips => _('If it goes wrong', 'Falls es schiefgeht');
  String get dishContains => _('Contains', 'Enthält');
  String get dishCook => _('Cook this', 'Jetzt kochen');
  String get dishAddToList => _('To the list', 'Auf die Liste');
  String get dishAddToPlan => _('Into the week', 'In die Woche');
  String get dishSave => _('Save this one', 'Diese hier speichern');
  String get dishUnsave => _('In your cookbook', 'In deinem Kochbuch');
  String get dishLearnMore => _('Learn more', 'Mehr erfahren');
  String get dishOverrideCalories =>
      _('Ignore my calorie target here', 'Kalorienziel hier ignorieren');
  String get dishOverrideCaloriesNote => _(
    'Shows every version of this one dish, whatever the numbers say.',
    'Zeigt jede Version dieses einen Gerichts, egal was die Zahlen sagen.',
  );
  String get dishNoVariantYet => _('not written yet', 'noch nicht geschrieben');
  String get dishHiddenByProfile =>
      _('hidden by your profile', 'durch dein Profil ausgeblendet');
  String dishUnreachable(String a, String b) =>
      _('no $a × $b version yet', 'noch keine Version $a × $b');
  String get dishOtherVariants =>
      _('Other versions of this dish', 'Andere Versionen dieses Gerichts');
  String get dishShowHidden => _('Show it anyway', 'Trotzdem anzeigen');
  String get dishProtein => _('protein', 'Eiweiß');
  String get dishCarbs => _('carbs', 'Kohlenhydrate');
  String get dishFat => _('fat', 'Fett');
  String get dishOptional => _('optional', 'optional');
  String get dishScaleServings => _('Scale', 'Menge');
  String dishStepCount(int n) => _('$n steps', '$n Schritte');
  String get dishNothingVisibleHere => _(
    'Every version of this dish clashes with your profile.',
    'Jede Version dieses Gerichts kollidiert mit deinem Profil.',
  );

  // --- search -------------------------------------------------------------
  String get searchHint =>
      _('Dish, ingredient, mood…', 'Gericht, Zutat, Stimmung…');
  String get searchFilters => _('Filters', 'Filter');
  String get searchDiet => _('Diet', 'Ernährung');
  String get searchEffort => _('Effort', 'Aufwand');
  String get searchTags => _('Tags', 'Schlagwörter');
  String get searchClearFilters => _('Clear filters', 'Filter zurücksetzen');
  String searchHiddenCount(int n) => n == 1
      ? _(
          '1 match is hidden by your profile',
          '1 Treffer ist durch dein Profil ausgeblendet',
        )
      : _(
          '$n matches are hidden by your profile',
          '$n Treffer sind durch dein Profil ausgeblendet',
        );
  String get searchEmptyTitle => _('Nothing here', 'Nichts hier');
  String searchEmptyBody(String query) => _(
    'We have not written anything for "$query" yet. The query is noted on this device so the corpus team can see the gap.',
    'Zu „$query“ haben wir noch nichts geschrieben. Die Anfrage wird auf diesem Gerät notiert, damit das Rezept-Team die Lücke sieht.',
  );
  String get searchStartTitle => _('What are you after?', 'Wonach ist dir?');
  String get searchStartBody => _(
    'Search by dish, by an ingredient you have in, or by how much of an evening you have.',
    'Suche nach Gericht, nach einer Zutat, die du da hast, oder danach, wie viel Abend du hast.',
  );

  // --- cookbook -----------------------------------------------------------
  String get cookbookTitle => _('Your cookbook', 'Dein Kochbuch');
  String get cookbookSubtitle => _(
    'Specific versions you saved, not dishes.',
    'Konkrete Versionen, die du gespeichert hast — keine Gerichte.',
  );
  String get cookbookEmptyTitle =>
      _('Nothing saved yet', 'Noch nichts gespeichert');
  String get cookbookEmptyBody => _(
    'When you save a recipe it is that exact version that lands here — your Döner, not the idea of Döner.',
    'Wenn du ein Rezept speicherst, landet genau diese Version hier — dein Döner, nicht die Idee von Döner.',
  );
  String get cookbookEmptyHand => _(
    'save one and it stays saved',
    'einmal gespeichert, bleibt gespeichert',
  );
  String get cookbookSortRecent => _('Recently saved', 'Zuletzt gespeichert');
  String get cookbookSortName => _('By name', 'Nach Name');
  String get cookbookRemoved =>
      _('Removed from your cookbook', 'Aus dem Kochbuch entfernt');

  // --- history ------------------------------------------------------------
  String get historyTitle => _('What you cooked', 'Was du gekocht hast');
  String get historyEmptyTitle => _('No cooking logged', 'Noch nichts gekocht');
  String get historyEmptyBody => _(
    'Finishing a recipe in cook mode writes it down here.',
    'Wenn du ein Rezept im Kochmodus beendest, wird es hier notiert.',
  );
  String get historyThisWeek => _('This week', 'Diese Woche');
  String get historyLastWeek => _('Last week', 'Letzte Woche');
  String historyWeekOf(String date) => _('Week of $date', 'Woche ab $date');
  String get historyIncomplete => _('stopped partway', 'unterwegs abgebrochen');

  // --- meal plan ----------------------------------------------------------
  String get planTitle => _('Your week', 'Deine Woche');
  String get planThisWeek => _('This week', 'Diese Woche');
  String get planEmptySlot => _('empty', 'leer');
  String get planAssign => _('Put something here', 'Etwas hierher legen');
  String get planFromCookbook => _('From your cookbook', 'Aus deinem Kochbuch');
  String get planFromSearch => _('Search everything', 'Alles durchsuchen');
  String get planExport =>
      _('Send week to shopping list', 'Woche zur Einkaufsliste');
  String get planClearSlot => _('Clear this slot', 'Slot leeren');
  String get planBreakfast => _('breakfast', 'Frühstück');
  String get planLunch => _('lunch', 'Mittag');
  String get planDinner => _('dinner', 'Abend');
  String get planMonday => _('Mon', 'Mo');
  String get planTuesday => _('Tue', 'Di');
  String get planWednesday => _('Wed', 'Mi');
  String get planThursday => _('Thu', 'Do');
  String get planFriday => _('Fri', 'Fr');
  String get planSaturday => _('Sat', 'Sa');
  String get planSunday => _('Sun', 'So');
  String get planDragHint => _(
    'Hold a card to move it to another slot.',
    'Halte eine Karte, um sie in einen anderen Slot zu ziehen.',
  );
  String planExported(int n) => _(
    '$n recipes went to your shopping list.',
    '$n Rezepte sind auf deiner Einkaufsliste gelandet.',
  );
  String get planNothingToExport =>
      _('This week is still empty.', 'Diese Woche ist noch leer.');

  String dayLabel(String day) => switch (day) {
    'mon' => planMonday,
    'tue' => planTuesday,
    'wed' => planWednesday,
    'thu' => planThursday,
    'fri' => planFriday,
    'sat' => planSaturday,
    _ => planSunday,
  };

  String mealLabel(String meal) => switch (meal) {
    'breakfast' => planBreakfast,
    'lunch' => planLunch,
    _ => planDinner,
  };

  // --- shopping -----------------------------------------------------------
  String get listTitle => _('Shopping list', 'Einkaufsliste');
  String get listEmptyTitle => _('Empty list', 'Leere Liste');
  String get listEmptyBody => _(
    'Add a recipe from a dish page, or send a whole week over from your plan.',
    'Füge ein Rezept von einer Gerichtseite hinzu oder schicke eine ganze Woche aus deinem Plan herüber.',
  );
  String get listClearChecked => _('Clear ticked', 'Abgehaktes entfernen');
  String get listClearAll => _('Clear the list', 'Liste leeren');
  String get listAddManual => _('Add something', 'Etwas hinzufügen');
  String get listSplitUnits => _(
    'kept separate — units do not convert',
    'getrennt gehalten — Einheiten rechnen sich nicht um',
  );
  String listFromRecipes(int n) => n == 1
      ? _('from 1 recipe', 'aus 1 Rezept')
      : _('from $n recipes', 'aus $n Rezepten');
  String get listInsights => _('Shopping insights', 'Einkaufs-Insights');

  // --- insights -----------------------------------------------------------
  String get insightsTitle => _('Shopping insights', 'Einkaufs-Insights');
  String get insightsVariety => _('variety score', 'Vielfalts-Score');
  String get insightsVarietyNote => _(
    'Distinct ingredients that have passed through your list. A description, not a grade.',
    'Verschiedene Zutaten, die durch deine Liste gelaufen sind. Eine Beschreibung, keine Note.',
  );
  String get insightsTotal => _('items added', 'Einträge');
  String get insightsRepeat => _('repeats each', 'Wiederholungen je');
  String get insightsTop => _('Most added', 'Am häufigsten');
  String get insightsSeasonal => _('By month', 'Nach Monat');
  String get insightsAisles => _('Where you shop', 'Wo du einkaufst');
  String get insightsEmptyTitle =>
      _('Nothing to read yet', 'Noch nichts zu lesen');
  String get insightsEmptyBody => _(
    'Add a few things to your shopping list and this page starts to say something.',
    'Leg ein paar Dinge auf die Einkaufsliste, dann hat diese Seite etwas zu sagen.',
  );
  String insightsSince(String date) => _('since $date', 'seit $date');

  // --- cook mode ----------------------------------------------------------
  String get cookTitle => _('Cook mode', 'Kochmodus');
  String cookStepOf(int a, int b) => _('Step $a of $b', 'Schritt $a von $b');
  String get cookStart => _('Start', 'Start');
  String get cookPause => _('Pause', 'Pause');
  String get cookResume => _('Resume', 'Weiter');
  String get cookReset => _('Reset', 'Zurücksetzen');
  String get cookPrev => _('Previous', 'Zurück');
  String get cookNext => _('Next', 'Weiter');
  String get cookFinish => _('Finish', 'Fertig');
  String get cookExit => _('Leave cook mode', 'Kochmodus verlassen');
  String get cookExitConfirm => _(
    'Your place is saved. You can pick this back up later.',
    'Deine Position ist gespeichert. Du kannst später weitermachen.',
  );
  String get cookDoneTitle => _('That is dinner', 'Das ist das Essen');
  String get cookDoneBody => _(
    'Written down in your history. Nothing else to do.',
    'In deinem Verlauf notiert. Sonst nichts zu tun.',
  );
  String get cookDoneHand => _('go and eat it', 'geh und iss');
  String get cookTimerDone => _('Timer finished', 'Timer abgelaufen');
  String get cookQuickTapHint =>
      _('Tap the step to move on', 'Tippe auf den Schritt zum Weitergehen');
  String get cookResumeTitle =>
      _('Carry on where you stopped?', 'Da weitermachen, wo du warst?');
  String cookResumeBody(String title, int step) => _(
    'You were on step $step of $title.',
    'Du warst bei Schritt $step von $title.',
  );
  String get cookStartOver => _('Start over', 'Von vorn');
  String get cookIngredientsForStep => _('On hand', 'Bereitlegen');

  // --- settings -----------------------------------------------------------
  String get settingsTitle => _('Settings', 'Einstellungen');
  String get settingsProfile => _('Profile', 'Profil');
  String get settingsName => _('Name', 'Name');
  String get settingsLanguage => _('Language', 'Sprache');
  String get settingsDiet => _('Diet & avoidance', 'Ernährung & Vermeidung');
  String get settingsClassAvoidance => _('Whole groups', 'Ganze Gruppen');
  String get settingsClassAvoidanceNote => _(
    'A checkbox for everything in a category — all dairy, all tree nuts.',
    'Ein Häkchen für alles einer Kategorie — alle Milchprodukte, alle Schalenfrüchte.',
  );
  String get settingsSpecificAvoidance =>
      _('Specific things', 'Einzelne Zutaten');
  String get settingsSpecificAvoidanceNote => _(
    'Search for one ingredient. Choosing a parent covers everything under it.',
    'Suche nach einer Zutat. Wählst du eine übergeordnete, gilt es für alles darunter.',
  );
  String get settingsSpecificHint =>
      _('apples, coriander, bell peppers…', 'Äpfel, Koriander, Paprika…');
  String get settingsRequired => _('Must have', 'Muss erfüllen');
  String get settingsRequiredNote => _(
    'Only show recipes that carry these.',
    'Nur Rezepte zeigen, die das erfüllen.',
  );
  String get settingsAdaptation => _('Adaptation', 'Anpassung');
  String get settingsTimeBudget => _('Time budget', 'Zeitbudget');
  String get settingsTimeBudgetNote => _(
    'Total clock time, including resting and marinating.',
    'Gesamte Uhrzeit, inklusive Ruhen und Marinieren.',
  );
  String get settingsCalorieTarget => _('Calorie target', 'Kalorienziel');
  String get settingsCalorieTargetOff => _('No target', 'Kein Ziel');
  String get settingsCalorieTolerance => _('Tolerance', 'Toleranz');
  String get settingsEffort => _('Usual effort', 'Üblicher Aufwand');
  String get settingsShowTags =>
      _('Show variant tags', 'Varianten-Tags anzeigen');
  String get settingsShowTagsNote => _(
    'Small labels like "vegan" on recipe cards.',
    'Kleine Labels wie „vegan“ auf Rezeptkarten.',
  );
  String get settingsAccessibility => _('Accessibility', 'Barrierefreiheit');
  String get settingsReduceMotion => _('Reduce motion', 'Bewegung reduzieren');
  String get settingsReduceMotionSystem => _('Follow system', 'System folgen');
  String get settingsReduceMotionOn => _('Always reduce', 'Immer reduzieren');
  String get settingsReduceMotionOff => _('Always animate', 'Immer animieren');
  String get settingsVisualAlert =>
      _('Flash on timer end', 'Blitz bei Timer-Ende');
  String get settingsVisualAlertNote => _(
    'A coral and teal flash instead of relying on sound.',
    'Ein Blitz in Korall und Petrol statt sich auf Ton zu verlassen.',
  );
  String get settingsQuickTap => _('Quick-tap to advance', 'Weitertippen');
  String get settingsQuickTapNote => _(
    'One tap on the step moves on, with a haptic tick. Debounced so a slip does not skip two.',
    'Ein Tipp auf den Schritt geht weiter, mit haptischem Feedback. Entprellt, damit ein Verrutschen nicht zwei überspringt.',
  );
  String get settingsData => _('Data', 'Daten');
  String get settingsExport => _('Export a backup', 'Sicherung exportieren');
  String get settingsExportNote => _(
    'Writes a readable JSON file and a compressed copy, then hands both to the share sheet.',
    'Schreibt eine lesbare JSON-Datei und eine komprimierte Kopie und übergibt beide dem Teilen-Menü.',
  );
  String get settingsImport =>
      _('Restore from a file', 'Aus Datei wiederherstellen');
  String get settingsBackupPassword => _('Backup password', 'Backup-Passwort');
  String get settingsBackupPasswordNote => _(
    'Optional. Encrypts the JSON file with AES-256-GCM. There is no recovery — a lost password is a lost backup.',
    'Optional. Verschlüsselt die JSON-Datei mit AES-256-GCM. Es gibt keine Wiederherstellung — ein verlorenes Passwort ist eine verlorene Sicherung.',
  );
  String get settingsContentRequests => _('Recorded gaps', 'Notierte Lücken');
  String contentRequestCount(int n) => n == 1
      ? _('1 search found nothing', '1 Suche fand nichts')
      : _('$n searches found nothing', '$n Suchen fanden nichts');
  String get settingsContentRequestsNote => _(
    'Searches that returned nothing, kept on this device. They travel only inside a backup you choose to share.',
    'Suchen ohne Treffer, auf diesem Gerät gespeichert. Sie reisen nur in einer Sicherung mit, die du selbst teilst.',
  );
  String get settingsClearRequests => _('Forget them', 'Vergessen');
  String get settingsAbout => _('About', 'Über');
  String get settingsHelp => _('Help centre', 'Hilfe');
  String get settingsCorpus => _('Recipe corpus', 'Rezeptbestand');
  String corpusSummary(int dishes, int recipes, String version) => _(
    '$dishes dishes, $recipes recipes, corpus $version',
    '$dishes Gerichte, $recipes Rezepte, Bestand $version',
  );
  String get settingsOffline => _(
    'MorphCook makes no network requests. Nothing you do here leaves the device unless you export a file yourself.',
    'MorphCook stellt keine Netzwerkanfragen. Nichts verlässt dieses Gerät, außer du exportierst selbst eine Datei.',
  );
  String get settingsReset => _('Reset everything', 'Alles zurücksetzen');
  String get settingsResetConfirm => _(
    'Deletes your profile, saved recipes, plan, list and history from this device. The recipes themselves stay.',
    'Löscht Profil, gespeicherte Rezepte, Plan, Liste und Verlauf von diesem Gerät. Die Rezepte selbst bleiben.',
  );

  // --- halal / kosher note ------------------------------------------------
  String get certificationHeadline =>
      _('About halal and kosher', 'Zu Halal und Koscher');

  // --- backup flow --------------------------------------------------------
  String get backupExporting =>
      _('Writing the files…', 'Dateien werden geschrieben…');
  String backupExported(String json, String gz, int percent) => _(
    '$json and $gz — the compressed copy is $percent% smaller.',
    '$json und $gz — die komprimierte Kopie ist $percent % kleiner.',
  );
  String get backupEncrypted => _(
    'The JSON file is encrypted. The .gz copy is not, so it stays readable anywhere.',
    'Die JSON-Datei ist verschlüsselt. Die .gz-Kopie nicht, sie bleibt überall lesbar.',
  );
  String get backupPasswordPrompt =>
      _('This backup is encrypted', 'Diese Sicherung ist verschlüsselt');
  String get backupPasswordField => _('Password', 'Passwort');
  String get backupImportMode =>
      _('How should it land?', 'Wie soll sie landen?');
  String get backupMerge => _('Merge', 'Zusammenführen');
  String get backupMergeNote => _(
    'Keep what is here and add what is new.',
    'Behalten, was da ist, und Neues ergänzen.',
  );
  String get backupReplace => _('Replace', 'Ersetzen');
  String get backupReplaceNote => _(
    'Wipe saved recipes, plan and history first, then match the file exactly.',
    'Erst gespeicherte Rezepte, Plan und Verlauf löschen, dann exakt der Datei entsprechen.',
  );
  String backupImported(int saved, int history, int slots) => _(
    'Restored: $saved saved, $history cooked, $slots planned slots.',
    'Wiederhergestellt: $saved gespeichert, $history gekocht, $slots Plan-Slots.',
  );
  String get backupPickFile =>
      _('Choose a backup file', 'Sicherungsdatei wählen');
  String get backupPasteInstead => _(
    'Paste the contents of a backup file',
    'Inhalt einer Sicherungsdatei einfügen',
  );
  String get backupPasteHint => _('Paste JSON here', 'JSON hier einfügen');

  // --- faq ----------------------------------------------------------------
  String get faqTitle => _('Help centre', 'Hilfe');
  String get faqSearchHint => _('Search the help centre', 'Hilfe durchsuchen');
  String get faqRelated => _('Related', 'Passt dazu');
  String get faqNoResults => _('Nothing matches that.', 'Dazu passt nichts.');
  String get faqAllCategories => _('Everything', 'Alles');

  // --- ingredient guide ---------------------------------------------------
  String get guideWhatItIs => _('What it is', 'Was es ist');
  String get guideHowToUse => _('How to use it', 'Wie man es benutzt');
  String get guideStorage => _('Keeping it', 'Aufbewahren');
  String get guideWhereToFind => _('Where to find it', 'Wo man es findet');

  // --- categories ---------------------------------------------------------
  String category(String id) => switch (id) {
    'street-food' => _('street food', 'Streetfood'),
    'handheld' => _('handheld', 'aus der Hand'),
    'weeknight' => _('weeknight', 'unter der Woche'),
    'pasta' => _('pasta', 'Pasta'),
    'comfort' => _('comfort', 'Seelenfutter'),
    'noodles' => _('noodles', 'Nudeln'),
    'brunch' => _('brunch', 'Brunch'),
    'one-pan' => _('one pan', 'eine Pfanne'),
    'breakfast' => _('breakfast', 'Frühstück'),
    'weekend' => _('weekend', 'Wochenende'),
    'baking' => _('baking', 'Backen'),
    'grill' => _('grill', 'Grill'),
    'budget' => _('budget', 'günstig'),
    'quick' => _('quick', 'schnell'),
    'salad' => _('salad', 'Salat'),
    'lunch' => _('lunch', 'Mittag'),
    'soup' => _('soup', 'Suppe'),
    'one-pot' => _('one pot', 'ein Topf'),
    'batch' => _('batch cooking', 'Vorkochen'),
    'bowl' => _('bowl', 'Bowl'),
    'meal-prep' => _('meal prep', 'Meal Prep'),
    'handmade' => _('handmade', 'handgemacht'),
    'sharing' => _('sharing', 'zum Teilen'),
    'no-cook' => _('no cooking', 'ohne Kochen'),
    'dessert' => _('dessert', 'Nachtisch'),
    'make-ahead' => _('make ahead', 'vorbereiten'),
    _ => id.replaceAll('-', ' '),
  };
}
