/// All UI strings, bilingual (EN + DE). The data model is N-language-ready;
/// this table is the only place to touch when a language is added.
class AppL {
  AppL._();

  static const Map<String, Map<String, String>> _s = {
    // ---- shell / navigation ----
    'nav.home': {'en': 'home', 'de': 'start'},
    'nav.search': {'en': 'search', 'de': 'suche'},
    'nav.cookbook': {'en': 'cookbook', 'de': 'kochbuch'},
    'nav.plan': {'en': 'plan', 'de': 'plan'},
    'nav.settings': {'en': 'settings', 'de': 'einstellungen'},

    // ---- common ----
    'common.min': {'en': 'min', 'de': 'min'},
    'common.kcal': {'en': 'kcal', 'de': 'kcal'},
    'common.servings': {'en': 'servings', 'de': 'portionen'},
    'common.cancel': {'en': 'cancel', 'de': 'abbrechen'},
    'common.save': {'en': 'save', 'de': 'speichern'},
    'common.done': {'en': 'done', 'de': 'fertig'},
    'common.next': {'en': 'next', 'de': 'weiter'},
    'common.back': {'en': 'back', 'de': 'zurück'},
    'common.close': {'en': 'close', 'de': 'schließen'},
    'common.delete': {'en': 'delete', 'de': 'löschen'},
    'common.confirm': {'en': 'confirm', 'de': 'bestätigen'},
    'common.retry': {'en': 'try again', 'de': 'nochmal'},
    'common.loading': {'en': 'fetching from the shelf…', 'de': 'vom regal holen…'},
    'common.error': {'en': 'something tore a page', 'de': 'hier ist eine Seite gerissen'},
    'common.search': {'en': 'search', 'de': 'suchen'},
    'common.all': {'en': 'all', 'de': 'alle'},
    'common.clear': {'en': 'clear', 'de': 'leeren'},
    'common.and': {'en': '&', 'de': '&'},
    'common.learnMore': {'en': 'learn more', 'de': 'mehr erfahren'},
    'common.why': {'en': 'why?', 'de': 'warum?'},
    'common.viewFaq': {'en': 'help center', 'de': 'hilfe-center'},
    'common.diet': {'en': 'diet', 'de': 'ernährung'},
    'common.effort': {'en': 'effort', 'de': 'aufwand'},
    'common.calorieLevel': {'en': 'calorie level', 'de': 'kalorien-niveau'},
    'common.ingredients': {'en': 'ingredients', 'de': 'zutaten'},
    'common.method': {'en': 'method', 'de': 'zubereitung'},
    'common.macros': {'en': 'macros', 'de': 'nährwerte'},
    'common.protein': {'en': 'protein', 'de': 'eiweiß'},
    'common.carbs': {'en': 'carbs', 'de': 'kohlenhydrate'},
    'common.fat': {'en': 'fat', 'de': 'fett'},
    'common.add': {'en': 'add', 'de': 'hinzufügen'},
    'common.remove': {'en': 'remove', 'de': 'entfernen'},
    'common.optional': {'en': 'optional', 'de': 'optional'},
    'common.showMore': {'en': 'show more', 'de': 'mehr zeigen'},
    'common.showLess': {'en': 'show less', 'de': 'weniger zeigen'},
    'common.none': {'en': 'none', 'de': 'keine'},
    'common.today': {'en': 'today', 'de': 'heute'},
    'common.you': {'en': 'you', 'de': 'du'},

    // ---- home ----
    'home.tagline': {
      'en': 'the same dish exists for every body',
      'de': 'dasselbe gericht existiert für jeden menschen'
    },
    'home.edition': {'en': 'no. {n} · the offline edition', 'de': 'nr. {n} · die offline-ausgabe'},
    'home.greeting.morning': {'en': 'good morning, {name}', 'de': 'guten morgen, {name}'},
    'home.greeting.day': {'en': 'hello, {name}', 'de': 'hallo, {name}'},
    'home.greeting.evening': {'en': 'good evening, {name}', 'de': 'guten abend, {name}'},
    'home.greeting.anon': {'en': 'hello, you', 'de': 'hallo, du'},
    'home.calmNote': {'en': 'no noise, no ads — just dinner.', 'de': 'kein lärm, keine werbung — nur essen.'},
    'home.featured': {'en': 'tonight’s feature', 'de': 'heute abend im programm'},
    'home.open': {'en': 'open the recipe', 'de': 'rezept öffnen'},
    'home.section.forYou.eyebrow': {'en': 'for you', 'de': 'für dich'},
    'home.section.forYou.title': {'en': 'your shelf & your mood', 'de': 'dein regal & deine laune'},
    'home.section.quick.eyebrow': {'en': 'tonight', 'de': 'heute abend'},
    'home.section.quick.title': {'en': 'quick & kind', 'de': 'schnell & gütig'},
    'home.section.breakfast.eyebrow': {'en': 'before noon', 'de': 'vor mittag'},
    'home.section.breakfast.title': {'en': 'the breakfast club', 'de': 'das frühstücks-kränzchen'},
    'home.section.recent.eyebrow': {'en': 'the ledger', 'de': 'das heft'},
    'home.section.recent.title': {'en': 'recently cooked', 'de': 'kürzlich gekocht'},
    'home.viewAll': {'en': 'view all', 'de': 'alle ansehen'},
    'home.variantsCount': {'en': '{n} versions', 'de': '{n} versionen'},
    'home.nothingYet': {'en': 'nothing here yet — the kitchen waits.', 'de': 'noch nichts hier — die küche wartet.'},
    'home.loadingCorpus': {'en': 'opening the cookbook…', 'de': 'das kochbuch öffnet sich…'},
    // ---- cuisines ----
    'cuisine.italian': {'en': 'italian', 'de': 'italienisch'},
    'cuisine.asian': {'en': 'asian', 'de': 'asiatisch'},
    'cuisine.middle-eastern': {'en': 'middle-eastern', 'de': 'orientalisch'},
    'cuisine.american': {'en': 'american', 'de': 'amerikanisch'},

    // ---- onboarding ----
    'onb.step': {'en': 'step {n} of 5', 'de': 'schritt {n} von 5'},
    'onb.lang.title': {'en': 'willkommen', 'de': 'willkommen'},
    'onb.lang.body': {
      'en': 'morphcook keeps every recipe on your phone — no account, no cloud. first: which kitchen voice?',
      'de': 'morphcook bewahrt jedes rezept auf deinem telefon — kein konto, keine wolke. zuerst: welche küchenstimme?'
    },
    'onb.name.title': {'en': 'and you are?', 'de': 'und wer bist du?'},
    'onb.name.body': {'en': 'a name for the margin notes. optional.', 'de': 'ein name für die randnotizen. optional.'},
    'onb.name.hint': {'en': 'your name', 'de': 'dein name'},
    'onb.diet.title': {'en': 'how do you eat?', 'de': 'wie isst du?'},
    'onb.diet.body': {
      'en': 'nothing gets filtered away — every dish keeps a version written for you. tell us what to avoid.',
      'de': 'nichts wird weggefiltert — jedes gericht behält eine version, die für dich geschrieben ist. sag uns, was du meidest.'
    },
    'onb.diet.compound': {'en': 'way of eating', 'de': 'ernährungsweise'},
    'onb.diet.classFlags': {'en': 'avoid whole classes', 'de': 'ganze klassen meiden'},
    'onb.diet.specific': {'en': 'specific ingredients', 'de': 'einzelne zutaten'},
    'onb.diet.specificHint': {'en': 'type to search the dictionary…', 'de': 'tippen, um das lexikon zu durchsuchen…'},
    'onb.diet.required': {'en': 'positive requirements', 'de': 'positive anforderungen'},
    'onb.calorie.title': {'en': 'a number, gently', 'de': 'eine zahl, sanft'},
    'onb.calorie.body': {
      'en': 'a per-meal calorie target. hard filter — but every dish has a switch to peek beyond it.',
      'de': 'ein kalorienziel pro mahlzeit. harter filter — aber jedes gericht hat einen schalter, um darüber hinauszuschauen.'
    },
    'onb.calorie.none': {'en': 'no target, thanks', 'de': 'kein ziel, danke'},
    'onb.time.title': {'en': 'your clock', 'de': 'deine uhr'},
    'onb.time.body': {'en': 'the longest you want to stand at the stove on a normal day.', 'de': 'wie lange du an einem normalen tag am herd stehen willst.'},
    'onb.time.none': {'en': 'no limit', 'de': 'keine grenze'},
    'onb.effort.title': {'en': 'today’s effort', 'de': 'heutiger aufwand'},
    'onb.effort.body': {'en': 'your default mood. switch it per dish anytime.', 'de': 'deine standard-stimmung. pro gericht jederzeit umschaltbar.'},
    'onb.confirm.title': {'en': 'the first page', 'de': 'die erste seite'},
    'onb.confirm.body': {'en': 'here is your cookbook’s opening note. everything stays editable in settings.', 'de': 'hier ist die erste notiz deines kochbuchs. alles bleibt in den einstellungen änderbar.'},
    'onb.confirm.name': {'en': 'name', 'de': 'name'},
    'onb.confirm.language': {'en': 'language', 'de': 'sprache'},
    'onb.confirm.avoids': {'en': 'avoiding', 'de': 'meidet'},
    'onb.confirm.avoidsNone': {'en': 'nothing', 'de': 'nichts'},
    'onb.confirm.target': {'en': 'calorie target', 'de': 'kalorienziel'},
    'onb.confirm.time': {'en': 'time budget', 'de': 'zeitbudget'},
    'onb.confirm.effort': {'en': 'preferred effort', 'de': 'bevorzugter aufwand'},
    'onb.start': {'en': 'enter the kitchen', 'de': 'die küche betreten'},

    // ---- dish detail ----
    'dish.variants': {'en': 'the versions', 'de': 'die versionen'},
    'dish.save': {'en': 'save this version', 'de': 'diese version merken'},
    'dish.saved': {'en': 'saved to your cookbook', 'de': 'in deinem kochbuch'},
    'dish.unsave': {'en': 'remove from cookbook', 'de': 'aus dem kochbuch nehmen'},
    'dish.cook': {'en': 'cook this', 'de': 'das kochen wir'},
    'dish.shop': {'en': 'add to shopping list', 'de': 'auf die einkaufsliste'},
    'dish.markCooked': {'en': 'mark as cooked', 'de': 'als gekocht notieren'},
    'dish.markedCooked': {'en': 'noted in the ledger', 'de': 'im heft notiert'},
    'dish.calorieOverride': {'en': 'show versions outside my target', 'de': 'versionen außerhalb meines ziels zeigen'},
    'dish.noVariant': {
      'en': 'no version of this dish fits your profile yet — try the switches below or relax a filter.',
      'de': 'noch keine version dieses gerichts passt zu deinem profil — probiere die schalter unten oder lockere einen filter.'
    },
    'dish.disabledNote': {'en': 'no {a} × {b} version yet', 'de': 'noch keine {a} × {b} version'},
    'dish.ingredientsFor': {'en': 'for {n} servings', 'de': 'für {n} portionen'},
    'dish.resumeCook': {'en': 'continue cooking?', 'de': 'weiterkochen?'},
    'dish.resumeCookBody': {'en': 'you paused halfway through. pick up at step {n}?', 'de': 'du hast mitten drin pausiert. weiter bei schritt {n}?'},
    'dish.startOver': {'en': 'start over', 'de': 'von vorn'},
    'dish.contains': {'en': 'contains', 'de': 'enthält'},
    'dish.hiddenWhy': {'en': 'hidden: {reason}', 'de': 'versteckt: {reason}'},
    // ---- search ----
    'search.hint': {'en': 'a dish, a craving, an ingredient…', 'de': 'ein gericht, ein verlangen, eine zutat…'},
    'search.filters': {'en': 'filters', 'de': 'filter'},
    'search.emptyTitle': {'en': 'nothing on this shelf', 'de': 'nichts auf diesem regal'},
    'search.emptyBody': {
      'en': 'either it is not in the corpus yet, or every version is filtered for you. your search was noted as a content request.',
      'de': 'entweder ist es noch nicht im bestand, oder jede version ist für dich gefiltert. deine suche wurde als inhaltswunsch notiert.'
    },
    'search.results': {'en': '{n} found', 'de': '{n} gefunden'},
    'search.filterDiets': {'en': 'diet', 'de': 'ernährung'},
    'search.filterCuisines': {'en': 'cuisine', 'de': 'küche'},
    'search.filterEfforts': {'en': 'effort', 'de': 'aufwand'},
    'search.filterTechniques': {'en': 'technique', 'de': 'technik'},

    // ---- cookbook ----
    'book.title': {'en': 'your cookbook', 'de': 'dein kochbuch'},
    'book.empty': {'en': 'the pages are still blank', 'de': 'die seiten sind noch leer'},
    'book.emptyBody': {
      'en': 'save a specific version of a dish — your döner, your alfredo — and it will live here.',
      'de': 'merke eine konkrete version eines gerichts — deinen döner, dein alfredo — sie lebt dann hier.'
    },
    'book.savedAt': {'en': 'saved {when}', 'de': 'gemerkt {when}'},

    // ---- planner ----
    'plan.title': {'en': 'the week', 'de': 'die woche'},
    'plan.prev': {'en': 'previous week', 'de': 'vorherige woche'},
    'plan.next': {'en': 'next week', 'de': 'nächste woche'},
    'plan.thisWeek': {'en': 'this week', 'de': 'diese woche'},
    'plan.export': {'en': 'week → shopping list', 'de': 'woche → einkaufsliste'},
    'plan.exported': {'en': '{n} items added to your list', 'de': '{n} posten auf die liste gelegt'},
    'plan.exportEmpty': {'en': 'the week is still empty', 'de': 'die woche ist noch leer'},
    'plan.pickTitle': {'en': 'fill the slot', 'de': 'feld belegen'},
    'plan.pickCookbook': {'en': 'from your cookbook', 'de': 'aus dem kochbuch'},
    'plan.pickSearch': {'en': 'from search', 'de': 'aus der suche'},
    'plan.clear': {'en': 'clear slot', 'de': 'feld leeren'},
    'plan.dragHint': {'en': 'tap to fill · long-press to drag', 'de': 'tippen zum belegen · lange drücken zum ziehen'},

    // ---- shopping ----
    'shop.title': {'en': 'the list', 'de': 'die liste'},
    'shop.empty': {'en': 'nothing to buy', 'de': 'nichts zu kaufen'},
    'shop.emptyBody': {
      'en': 'add a recipe from its page, or export a week from the planner.',
      'de': 'füge ein rezept über seine seite hinzu oder exportiere eine woche aus dem planer.'
    },
    'shop.clearDone': {'en': 'sweep the done', 'de': 'erledigtes entfernen'},
    'shop.done': {'en': '{n} of {m} done', 'de': '{n} von {m} erledigt'},
    'shop.remove': {'en': 'remove', 'de': 'entfernen'},
    'shop.added': {'en': 'on the list', 'de': 'auf der liste'},
    // ---- insights ----
    'insights.title': {'en': 'shopping insights', 'de': 'einkaufs-einblicke'},
    'insights.variety': {'en': 'variety score', 'de': 'vielfalts-score'},
    'insights.varietyBody': {'en': 'different ingredients you have ever shopped for', 'de': 'verschiedene zutaten, die du je eingekauft hast'},
    'insights.top': {'en': 'most added', 'de': 'am häufigsten'},
    'insights.seasonal': {'en': 'through the year', 'de': 'durchs jahr'},
    'insights.empty': {'en': 'add something to the list and patterns will bloom here.', 'de': 'lege etwas auf die liste, und hier blühen muster.'},
    'insights.additions': {'en': '{n} additions logged', 'de': '{n} zugänge notiert'},

    // ---- settings ----
    'set.title': {'en': 'settings', 'de': 'einstellungen'},
    'set.profile': {'en': 'your page', 'de': 'deine seite'},
    'set.name': {'en': 'name', 'de': 'name'},
    'set.lang': {'en': 'language', 'de': 'sprache'},
    'set.diet': {'en': 'diet & avoidance', 'de': 'ernährung & meidung'},
    'set.dietBody': {'en': 'compound ways of eating, whole classes, specific ingredients.', 'de': 'ernährungsweisen, ganze klassen, einzelne zutaten.'},
    'set.calorie': {'en': 'calorie target (hard filter)', 'de': 'kalorienziel (harter filter)'},
    'set.calorieBody': {'en': 'per meal, ± 150 tolerance. each dish can override.', 'de': 'pro mahlzeit, ± 150 toleranz. jedes gericht kann das aufheben.'},
    'set.time': {'en': 'time budget', 'de': 'zeitbudget'},
    'set.effort': {'en': 'preferred effort', 'de': 'bevorzugter aufwand'},
    'set.adaptation': {'en': 'adaptation & accessibility', 'de': 'anpassung & barrierefreiheit'},
    'set.showTags': {'en': 'show variant tags on cards', 'de': 'varianten-tags auf karten zeigen'},
    'set.reduceMotion': {'en': 'reduce motion', 'de': 'bewegung reduzieren'},
    'set.reduceMotionSystem': {'en': 'follow system', 'de': 'system folgen'},
    'set.visualAlert': {'en': 'visual flash on timer end', 'de': 'visueller blitz am timer-ende'},
    'set.visualAlertBody': {'en': 'for deaf & hard-of-hearing cooks: coral/teal flash instead of sound.', 'de': 'für gehörlose & schwerhörige köche: koralle/teal-blitz statt ton.'},
    'set.quickNext': {'en': 'one-handed cook mode (tap anywhere = next step)', 'de': 'einhand-kochmodus (tippen = nächster schritt)'},
    'set.halalNote': {
      'en': 'we never claim halal or kosher certification. recipes are built from compatible ingredients; certification is a property of sourcing, not of a recipe text.',
      'de': 'wir behaupten nie eine halal- oder koscher-zertifizierung. rezepte bestehen aus kompatiblen zutaten; zertifizierung ist eine eigenschaft der herkunft, nicht des rezepttexts.'
    },
    'set.data': {'en': 'your data', 'de': 'deine daten'},
    'set.backup': {'en': 'backup & restore', 'de': 'sicherung & wiederherstellung'},
    'set.insights': {'en': 'shopping insights', 'de': 'einkaufs-einblicke'},
    'set.history': {'en': 'cooking history', 'de': 'koch-historie'},
    'set.contentRequests': {'en': 'content gap log', 'de': 'inhalts-wunschliste'},
    'set.contentRequestsBody': {'en': 'your zero-result searches. they inform what gets written next.', 'de': 'deine suchen ohne treffer. sie zeigen, was als nächstes geschrieben wird.'},
    'set.about': {'en': 'about morphcook', 'de': 'über morphcook'},
    'set.aboutBody': {
      'en': 'offline, accountless, quiet. every dish exists for every body — fully-authored variants, not filtered subsets. corpus edition {v}.',
      'de': 'offline, ohne konto, leise. jedes gericht existiert für jeden menschen — vollständig geschriebene varianten, keine gefilterten restmengen. bestands-ausgabe {v}.'
    },
    // ---- history ----
    'hist.title': {'en': 'the ledger', 'de': 'das heft'},
    'hist.empty': {'en': 'no entries yet — cook something.', 'de': 'noch keine einträge — koch etwas.'},
    'hist.thisWeek': {'en': 'this week', 'de': 'diese woche'},
    'hist.weekOf': {'en': 'week of {when}', 'de': 'woche vom {when}'},
    'hist.cooked': {'en': 'cooked {n}×', 'de': '{n}× gekocht'},
    'hist.showMore': {'en': 'further back', 'de': 'weiter zurück'},

    // ---- faq ----
    'faq.title': {'en': 'help center', 'de': 'hilfe-center'},
    'faq.searchHint': {'en': 'search the help pages…', 'de': 'die hilfeseiten durchsuchen…'},
    'faq.empty': {'en': 'no entry matches that.', 'de': 'kein eintrag passt dazu.'},
    'faq.related': {'en': 'related', 'de': 'passend'},

    // ---- backup ----
    'bak.title': {'en': 'backup & restore', 'de': 'sicherung & wiederherstellung'},
    'bak.body': {
      'en': 'two files go to your share sheet: a human-readable json and a much smaller gzip. optionally protect the json with a password (aes-256-gcm).',
      'de': 'zwei dateien gehen ans teilen-menü: eine lesbare json und eine viel kleinere gzip-datei. optional schützt ein passwort die json (aes-256-gcm).'
    },
    'bak.password': {'en': 'password (optional)', 'de': 'passwort (optional)'},
    'bak.passwordHint': {'en': 'leave empty for no encryption', 'de': 'leer lassen für keine verschlüsselung'},
    'bak.export': {'en': 'create backup', 'de': 'sicherung erstellen'},
    'bak.exported': {'en': 'handed to the share sheet', 'de': 'ans teilen-menü übergeben'},
    'bak.ratio': {'en': 'gzip is {p}% of the original', 'de': 'gzip ist {p}% des originals'},
    'bak.import': {'en': 'restore from file', 'de': 'aus datei wiederherstellen'},
    'bak.importPick': {'en': 'choose a backup file', 'de': 'sicherungsdatei wählen'},
    'bak.merge': {'en': 'merge with my data', 'de': 'mit meinen daten zusammenführen'},
    'bak.replace': {'en': 'replace my data', 'de': 'meine daten ersetzen'},
    'bak.imported': {'en': 'restore complete', 'de': 'wiederherstellung abgeschlossen'},
    'bak.needsPassword': {'en': 'this backup is encrypted — enter its password', 'de': 'diese sicherung ist verschlüsselt — gib ihr passwort ein'},
    'bak.passwordAgain': {'en': 'password', 'de': 'passwort'},
    'bak.wrongPassword': {'en': 'incorrect password. please try again.', 'de': 'falsches passwort. bitte erneut versuchen.'},
    'bak.corrupted': {'en': 'backup file is corrupted and cannot be restored.', 'de': 'die sicherungsdatei ist beschädigt und kann nicht wiederhergestellt werden.'},
    'bak.invalid': {'en': 'this file is not a valid morphcook backup.', 'de': 'diese datei ist keine gültige morphcook-sicherung.'},
    'bak.summary': {'en': '{saved} saved · {history} cooked · {requests} wishes', 'de': '{saved} gemerkt · {history} gekocht · {requests} wünsche'},

    // ---- cook mode ----
    'cook.stepOf': {'en': 'step {n} of {m}', 'de': 'schritt {n} von {m}'},
    'cook.prev': {'en': 'back', 'de': 'zurück'},
    'cook.next': {'en': 'next', 'de': 'weiter'},
    'cook.finish': {'en': 'finish', 'de': 'beenden'},
    'cook.servings': {'en': 'servings', 'de': 'portionen'},
    'cook.start': {'en': 'start timer', 'de': 'timer starten'},
    'cook.pause': {'en': 'pause', 'de': 'pause'},
    'cook.resume': {'en': 'resume', 'de': 'fortsetzen'},
    'cook.paused': {'en': 'paused — progress saved', 'de': 'pausiert — fortschritt gespeichert'},
    'cook.done': {'en': 'timer done', 'de': 'timer fertig'},
    'cook.completeTitle': {'en': 'guten appetit', 'de': 'guten appetit'},
    'cook.completeBody': {'en': 'another page for the ledger.', 'de': 'noch eine seite fürs heft.'},
    'cook.backToDish': {'en': 'back to the dish', 'de': 'zurück zum gericht'},
    'cook.backHome': {'en': 'back to the kitchen', 'de': 'zurück in die küche'},
    'cook.quickNext': {'en': 'quick tap: on', 'de': 'schnell-tipp: an'},
    'cook.quickNextOff': {'en': 'quick tap: off', 'de': 'schnell-tipp: aus'},
    'cook.noTimer': {'en': 'no timer for this step', 'de': 'kein timer für diesen schritt'},
  };

  /// Looks up [key] in [lang] (falls back to english, then the key itself)
  /// and substitutes `{param}` placeholders.
  static String t(String lang, String key, [Map<String, String>? params]) {
    final entry = _s[key];
    var text = entry?[lang] ?? entry?['en'] ?? key;
    params?.forEach((k, v) {
      text = text.replaceAll('{$k}', v);
    });
    return text;
  }
}
