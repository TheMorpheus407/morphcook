// UI copy. Every key has en + de. Lowercase display is applied by widgets,
// so keep natural casing here.
class S {
  const S(this.lang);
  final String lang;

  static const supported = ['en', 'de'];

  String t(String key, [Map<String, String>? args]) {
    final entry = _table[key];
    var text = entry == null ? key : (entry[lang] ?? entry['en'] ?? key);
    if (args != null) {
      args.forEach((k, v) => text = text.replaceAll('{$k}', v));
    }
    return text;
  }

  String call(String key, [Map<String, String>? args]) => t(key, args);

  String weekday(int weekday, {bool short = false}) {
    final names = lang == 'de' ? _weekdaysDe : _weekdaysEn;
    final n = names[(weekday - 1).clamp(0, 6)];
    return short ? n.substring(0, lang == 'de' ? 2 : 3) : n;
  }

  String month(int month) => (lang == 'de' ? _monthsDe : _monthsEn)[(month - 1).clamp(0, 11)];

  /// "tuesday, 2 september 2026" / "dienstag, 2. september 2026"
  String longDate(DateTime d) => lang == 'de'
      ? '${weekday(d.weekday)}, ${d.day}. ${month(d.month)} ${d.year}'
      : '${weekday(d.weekday)}, ${d.day} ${month(d.month)} ${d.year}';

  String shortDate(DateTime d) => lang == 'de' ? '${d.day}. ${month(d.month).substring(0, 3)}' : '${d.day} ${month(d.month).substring(0, 3)}';

  String minutes(int m) => lang == 'de' ? '$m min' : '$m min';

  String kcal(int k) => '~$k kcal';

  String servings(int n) => lang == 'de' ? (n == 1 ? '1 portion' : '$n portionen') : (n == 1 ? '1 serving' : '$n servings');

  static const _weekdaysEn = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  static const _weekdaysDe = ['montag', 'dienstag', 'mittwoch', 'donnerstag', 'freitag', 'samstag', 'sonntag'];
  static const _monthsEn = ['january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september', 'october', 'november', 'december'];
  static const _monthsDe = ['januar', 'februar', 'märz', 'april', 'mai', 'juni', 'juli', 'august', 'september', 'oktober', 'november', 'dezember'];
}

const Map<String, Map<String, String>> _table = {
  // app / nav
  'app.name': {'en': 'morphcook', 'de': 'morphcook'},
  'app.tagline': {'en': 'the same dish exists for every body', 'de': 'jedes gericht gibt es für jeden körper'},
  'nav.home': {'en': 'home', 'de': 'start'},
  'nav.search': {'en': 'search', 'de': 'suche'},
  'nav.cookbook': {'en': 'cookbook', 'de': 'kochbuch'},
  'nav.plan': {'en': 'plan', 'de': 'plan'},
  'nav.list': {'en': 'list', 'de': 'liste'},
  'common.ok': {'en': 'ok', 'de': 'ok'},
  'common.cancel': {'en': 'cancel', 'de': 'abbrechen'},
  'common.save': {'en': 'save', 'de': 'speichern'},
  'common.done': {'en': 'done', 'de': 'fertig'},
  'common.back': {'en': 'back', 'de': 'zurück'},
  'common.next': {'en': 'next', 'de': 'weiter'},
  'common.remove': {'en': 'remove', 'de': 'entfernen'},
  'common.clear': {'en': 'clear', 'de': 'leeren'},
  'common.close': {'en': 'close', 'de': 'schließen'},
  'common.retry': {'en': 'try again', 'de': 'nochmal'},
  'common.learnMore': {'en': 'learn more', 'de': 'mehr erfahren'},
  'common.help': {'en': 'help', 'de': 'hilfe'},
  'common.loading': {'en': 'loading…', 'de': 'lädt…'},
  'common.showAll': {'en': 'show all', 'de': 'alle zeigen'},
  'common.settings': {'en': 'settings', 'de': 'einstellungen'},
  'common.and': {'en': '&', 'de': '&'},
  'common.undo': {'en': 'undo', 'de': 'rückgängig'},
  'common.yes': {'en': 'yes', 'de': 'ja'},
  'common.no': {'en': 'no', 'de': 'nein'},

  // onboarding
  'onb.language.title': {'en': 'which language?', 'de': 'welche sprache?'},
  'onb.language.note': {'en': 'recipes, ingredients and help follow along. you can switch any time.', 'de': 'rezepte, zutaten und hilfe ziehen mit. du kannst jederzeit wechseln.'},
  'onb.name.title': {'en': 'what should we call you?', 'de': 'wie sollen wir dich nennen?'},
  'onb.name.note': {'en': 'only for the masthead. it never leaves this phone.', 'de': 'nur für die titelzeile. es verlässt dieses handy nie.'},
  'onb.name.hint': {'en': 'your name', 'de': 'dein name'},
  'onb.diet.title': {'en': 'how do you eat?', 'de': 'wie isst du?'},
  'onb.diet.note': {'en': 'tick what you avoid. nothing disappears — every dish exists in a version for you.', 'de': 'hak an, was du meidest. nichts verschwindet — jedes gericht gibt es in einer version für dich.'},
  'onb.diet.styles': {'en': 'ways of eating', 'de': 'ernährungsweisen'},
  'onb.diet.allergens': {'en': 'allergies & things to avoid', 'de': 'allergien & dinge, die du meidest'},
  'onb.diet.specific': {'en': 'specific ingredients', 'de': 'einzelne zutaten'},
  'onb.diet.specificHint': {'en': 'type an ingredient, e.g. cilantro', 'de': 'zutat eingeben, z. b. koriander'},
  'onb.diet.requirements': {'en': 'requirements', 'de': 'anforderungen'},
  'onb.targets.title': {'en': 'how much, how long?', 'de': 'wie viel, wie lange?'},
  'onb.targets.note': {'en': 'a calorie target per meal and a time budget. both optional, both changeable.', 'de': 'ein kalorienziel pro mahlzeit und ein zeitbudget. beides optional, beides änderbar.'},
  'onb.targets.calories': {'en': 'calorie target per meal', 'de': 'kalorienziel pro mahlzeit'},
  'onb.targets.caloriesOff': {'en': 'no target', 'de': 'kein ziel'},
  'onb.targets.time': {'en': 'time budget', 'de': 'zeitbudget'},
  'onb.targets.timeOff': {'en': 'no limit', 'de': 'kein limit'},
  'onb.targets.effort': {'en': 'effort mood', 'de': 'aufwand heute'},
  'onb.confirm.title': {'en': 'your cookbook, then.', 'de': 'dann mal dein kochbuch.'},
  'onb.confirm.note': {'en': 'everything can be changed in settings.', 'de': 'alles lässt sich in den einstellungen ändern.'},
  'onb.confirm.avoiding': {'en': 'avoiding', 'de': 'du meidest'},
  'onb.confirm.nothing': {'en': 'nothing in particular', 'de': 'nichts bestimmtes'},
  'onb.confirm.start': {'en': 'open the cookbook', 'de': 'kochbuch öffnen'},
  'onb.step': {'en': 'step {n} of {total}', 'de': 'schritt {n} von {total}'},

  // home
  'home.masthead.vol': {'en': 'vol. i · no. {n}', 'de': 'bd. i · nr. {n}'},
  'home.masthead.for': {'en': 'for {name}', 'de': 'für {name}'},
  'home.masthead.kitchen': {'en': 'your kitchen edition', 'de': 'deine küchenausgabe'},
  'home.featured': {'en': 'today', 'de': 'heute'},
  'home.featured.morning': {'en': 'this morning', 'de': 'heute morgen'},
  'home.featured.evening': {'en': 'tonight', 'de': 'heute abend'},
  'home.section.now': {'en': 'for right now', 'de': 'für jetzt'},
  'home.section.now.morning': {'en': 'breakfast & slow starts', 'de': 'frühstück & langsame starts'},
  'home.section.now.evening': {'en': 'dinner & dusk', 'de': 'abendessen & dämmerung'},
  'home.section.now.day': {'en': 'lunch & the middle of things', 'de': 'mittag & mittendrin'},
  'home.section.quick': {'en': 'quick & calm', 'de': 'schnell & ruhig'},
  'home.section.quick.kicker': {'en': 'under thirty minutes', 'de': 'unter dreißig minuten'},
  'home.section.saved': {'en': 'from your cookbook', 'de': 'aus deinem kochbuch'},
  'home.section.again': {'en': 'cook again', 'de': 'nochmal kochen'},
  'home.section.again.kicker': {'en': 'it has been a while', 'de': 'ist schon eine weile her'},
  'home.section.cuisine.italian': {'en': 'from italy', 'de': 'aus italien'},
  'home.section.cuisine.asian': {'en': 'from asia', 'de': 'aus asien'},
  'home.section.cuisine.middle-eastern': {'en': 'from the levant & anatolia', 'de': 'aus levante & anatolien'},
  'home.section.all': {'en': 'the whole book', 'de': 'das ganze buch'},
  'home.section.all.kicker': {'en': '{n} dishes for you', 'de': '{n} gerichte für dich'},
  'home.empty.title': {'en': 'a quiet page', 'de': 'eine stille seite'},
  'home.empty.note': {'en': 'nothing fits your profile right now. loosen a filter in settings, or ask why.', 'de': 'gerade passt nichts zu deinem profil. lockere einen filter in den einstellungen, oder frag nach dem warum.'},
  'home.hidden.note': {'en': '{n} dishes have no version for you yet', 'de': '{n} gerichte haben noch keine version für dich'},
  'home.why': {'en': 'why don\'t i see some dishes?', 'de': 'warum sehe ich manche gerichte nicht?'},
  'home.colophon': {'en': 'set in playfair, jetbrains mono & caveat · printed on this phone · no cloud, no accounts', 'de': 'gesetzt in playfair, jetbrains mono & caveat · gedruckt auf diesem handy · keine cloud, keine konten'},

  // dish
  'dish.versions': {'en': 'versions', 'de': 'versionen'},
  'dish.yourVersion': {'en': 'your version', 'de': 'deine version'},
  'dish.ingredients': {'en': 'ingredients', 'de': 'zutaten'},
  'dish.method': {'en': 'method', 'de': 'zubereitung'},
  'dish.macros': {'en': 'macros', 'de': 'nährwerte'},
  'dish.perServing': {'en': 'per serving', 'de': 'pro portion'},
  'dish.protein': {'en': 'protein', 'de': 'eiweiß'},
  'dish.carbs': {'en': 'carbs', 'de': 'kohlenhydrate'},
  'dish.fat': {'en': 'fat', 'de': 'fett'},
  'dish.contains': {'en': 'contains', 'de': 'enthält'},
  'dish.containsNothing': {'en': 'none of the usual suspects', 'de': 'keine der üblichen verdächtigen'},
  'dish.cook': {'en': 'start cooking', 'de': 'kochen starten'},
  'dish.resume': {'en': 'resume cooking', 'de': 'weiterkochen'},
  'dish.save': {'en': 'save to cookbook', 'de': 'ins kochbuch'},
  'dish.saved': {'en': 'in your cookbook', 'de': 'in deinem kochbuch'},
  'dish.addToList': {'en': 'add to list', 'de': 'auf die liste'},
  'dish.addedToList': {'en': 'added to your shopping list', 'de': 'auf deine einkaufsliste gesetzt'},
  'dish.plan': {'en': 'plan it', 'de': 'einplanen'},
  'dish.calorieOverride': {'en': 'show versions outside my calorie target', 'de': 'versionen außerhalb meines kalorienziels zeigen'},
  'dish.unreachable': {'en': 'no {combo} version yet', 'de': 'noch keine version für {combo}'},
  'dish.unreachable.try': {'en': 'try {combo}', 'de': 'probier {combo}'},
  'dish.conflict': {'en': 'this version contains {what}, which you avoid', 'de': 'diese version enthält {what}, was du meidest'},
  'dish.conflict.ingredient': {'en': 'this version uses {what}, which you avoid', 'de': 'diese version verwendet {what}, was du meidest'},
  'dish.missingAttribute': {'en': 'this version does not meet: {what}', 'de': 'diese version erfüllt nicht: {what}'},
  'dish.outsideCalories': {'en': 'outside your calorie target', 'de': 'außerhalb deines kalorienziels'},
  'dish.noVisible': {'en': 'none of these versions fits your profile; showing the closest one', 'de': 'keine dieser versionen passt zu deinem profil; wir zeigen die nächstbeste'},
  'dish.tooLong': {'en': 'over your time budget', 'de': 'über deinem zeitbudget'},
  'dish.time': {'en': 'time', 'de': 'zeit'},
  'dish.servings': {'en': 'servings', 'de': 'portionen'},
  'dish.notFound': {'en': 'this page fell out of the book', 'de': 'diese seite ist aus dem buch gefallen'},
  'dish.technique': {'en': 'technique', 'de': 'technik'},
  'dish.step': {'en': 'step {n}', 'de': 'schritt {n}'},
  'dish.timerHint': {'en': '{m} min timer', 'de': '{m} min timer'},
  'dish.changed': {'en': 'changed', 'de': 'neu'},

  // guide
  'guide.title': {'en': 'kitchen reference', 'de': 'küchenwissen'},
  'guide.description': {'en': 'what it is', 'de': 'was es ist'},
  'guide.usage': {'en': 'how to use it', 'de': 'so verwendest du es'},
  'guide.storage': {'en': 'storage', 'de': 'lagerung'},
  'guide.where': {'en': 'where to find it', 'de': 'wo du es findest'},
  'guide.none': {'en': 'no reference entry for this one yet', 'de': 'dazu gibt es noch keinen eintrag'},
  'guide.avoid': {'en': 'avoid this ingredient', 'de': 'diese zutat meiden'},
  'guide.avoiding': {'en': 'you avoid this ingredient', 'de': 'du meidest diese zutat'},

  // search
  'search.title': {'en': 'search', 'de': 'suche'},
  'search.hint': {'en': 'a dish, an ingredient, a mood…', 'de': 'ein gericht, eine zutat, eine laune…'},
  'search.tags': {'en': 'tags', 'de': 'tags'},
  'search.results': {'en': '{n} results', 'de': '{n} treffer'},
  'search.empty.title': {'en': 'nothing under that name', 'de': 'nichts unter diesem namen'},
  'search.empty.note': {'en': 'we wrote it down. dishes people look for and can\'t find tell us what to write next.', 'de': 'wir haben es notiert. gerichte, die gesucht und nicht gefunden werden, sagen uns, was als nächstes geschrieben wird.'},
  'search.empty.filtered': {'en': 'there are versions of this, but none fits your profile.', 'de': 'es gibt versionen davon, aber keine passt zu deinem profil.'},
  'search.idle.title': {'en': 'what are you in the mood for?', 'de': 'worauf hast du lust?'},
  'search.idle.note': {'en': 'try “döner”, “quick”, “soup” or an ingredient you have', 'de': 'probier „döner“, „schnell“, „suppe“ oder eine zutat, die du da hast'},
  'search.cap': {'en': 'showing the first {n} · narrow it down', 'de': 'die ersten {n} · grenz es ein'},
  'search.showOutside': {'en': 'include versions outside my calorie target', 'de': 'auch versionen außerhalb meines kalorienziels'},

  // cookbook
  'cookbook.title': {'en': 'your cookbook', 'de': 'dein kochbuch'},
  'cookbook.kicker': {'en': 'saved versions', 'de': 'gespeicherte versionen'},
  'cookbook.empty.title': {'en': 'no pages yet', 'de': 'noch keine seiten'},
  'cookbook.empty.note': {'en': 'save a version of a dish — your döner, your alfredo — and it lands here.', 'de': 'speicher eine version eines gerichts — dein döner, dein alfredo — und sie landet hier.'},
  'cookbook.history': {'en': 'cooking history', 'de': 'kochverlauf'},
  'cookbook.savedOn': {'en': 'saved {date}', 'de': 'gespeichert {date}'},
  'cookbook.loadNext': {'en': 'load the next {n}', 'de': 'die nächsten {n} laden'},

  // history
  'history.title': {'en': 'cooking history', 'de': 'kochverlauf'},
  'history.kicker': {'en': 'what you actually cooked', 'de': 'was du wirklich gekocht hast'},
  'history.empty.title': {'en': 'nothing cooked yet', 'de': 'noch nichts gekocht'},
  'history.empty.note': {'en': 'finish a recipe in cook mode and it gets a line here.', 'de': 'beende ein rezept im kochmodus und es bekommt hier eine zeile.'},
  'history.week': {'en': 'week {n}', 'de': 'woche {n}'},
  'history.thisWeek': {'en': 'this week', 'de': 'diese woche'},
  'history.lastWeek': {'en': 'last week', 'de': 'letzte woche'},
  'history.cooked': {'en': 'cooked {n}×', 'de': '{n}× gekocht'},
  'history.olderNote': {'en': 'older weeks', 'de': 'ältere wochen'},

  // plan
  'plan.title': {'en': 'the week', 'de': 'die woche'},
  'plan.kicker': {'en': 'meal plan', 'de': 'wochenplan'},
  'plan.thisWeek': {'en': 'this week', 'de': 'diese woche'},
  'plan.export': {'en': 'send week to list', 'de': 'woche auf die liste'},
  'plan.exported': {'en': '{n} recipes added to your list', 'de': '{n} rezepte auf deine liste gesetzt'},
  'plan.exportNothing': {'en': 'nothing planned this week', 'de': 'diese woche ist nichts geplant'},
  'plan.emptySlot': {'en': 'tap to plan', 'de': 'tippen zum planen'},
  'plan.pick.title': {'en': 'pick a recipe', 'de': 'rezept wählen'},
  'plan.pick.cookbook': {'en': 'cookbook', 'de': 'kochbuch'},
  'plan.pick.search': {'en': 'search', 'de': 'suche'},
  'plan.pick.empty': {'en': 'your cookbook is empty — search instead', 'de': 'dein kochbuch ist leer — such stattdessen'},
  'plan.clearSlot': {'en': 'clear slot', 'de': 'feld leeren'},
  'plan.dragHint': {'en': 'hold & drag to move · drop on another to swap', 'de': 'halten & ziehen zum verschieben · auf ein anderes fallen lassen zum tauschen'},
  'plan.meal.breakfast': {'en': 'breakfast', 'de': 'frühstück'},
  'plan.meal.lunch': {'en': 'lunch', 'de': 'mittag'},
  'plan.meal.dinner': {'en': 'dinner', 'de': 'abend'},
  'plan.weekOf': {'en': 'week of {date}', 'de': 'woche vom {date}'},
  'plan.limit': {'en': 'four weeks at a time keeps things calm', 'de': 'vier wochen auf einmal halten es ruhig'},

  // shopping
  'list.title': {'en': 'shopping list', 'de': 'einkaufsliste'},
  'list.kicker': {'en': 'merged & sorted by aisle', 'de': 'zusammengefasst & nach regal sortiert'},
  'list.empty.title': {'en': 'an empty basket', 'de': 'ein leerer korb'},
  'list.empty.note': {'en': 'add a recipe from its page, or send a planned week here.', 'de': 'füg ein rezept von seiner seite hinzu, oder schick eine geplante woche hierher.'},
  'list.recipes': {'en': 'recipes on the list', 'de': 'rezepte auf der liste'},
  'list.addManual': {'en': 'add your own item', 'de': 'eigenen eintrag hinzufügen'},
  'list.manualHint': {'en': 'e.g. dish soap, flowers', 'de': 'z. b. spülmittel, blumen'},
  'list.manual': {'en': 'your own', 'de': 'eigene'},
  'list.clearChecked': {'en': 'remove ticked', 'de': 'abgehakte entfernen'},
  'list.clearAll': {'en': 'clear list', 'de': 'liste leeren'},
  'list.clearAll.confirm': {'en': 'clear the whole list?', 'de': 'die ganze liste leeren?'},
  'list.from': {'en': 'from {n} recipes', 'de': 'aus {n} rezepten'},
  'list.insights': {'en': 'shopping insights', 'de': 'einkaufs-einblicke'},
  'list.toTaste': {'en': 'to taste', 'de': 'nach geschmack'},
  'list.servings': {'en': 'servings', 'de': 'portionen'},

  // insights
  'insights.title': {'en': 'shopping insights', 'de': 'einkaufs-einblicke'},
  'insights.kicker': {'en': 'computed on this phone only', 'de': 'nur auf diesem handy berechnet'},
  'insights.variety': {'en': 'variety score', 'de': 'vielfalt'},
  'insights.variety.note': {'en': 'different ingredients you have shopped for', 'de': 'verschiedene zutaten, die du eingekauft hast'},
  'insights.top': {'en': 'most added', 'de': 'am häufigsten'},
  'insights.seasonal': {'en': 'month by month', 'de': 'monat für monat'},
  'insights.adds': {'en': '{n} additions', 'de': '{n} einträge'},
  'insights.unique': {'en': '{n} different', 'de': '{n} verschiedene'},
  'insights.empty.title': {'en': 'nothing to see yet', 'de': 'noch nichts zu sehen'},
  'insights.empty.note': {'en': 'add recipes to your shopping list for a while and patterns will show up here.', 'de': 'setz eine weile rezepte auf deine einkaufsliste, dann zeigen sich hier muster.'},
  'insights.since': {'en': 'since {date}', 'de': 'seit {date}'},
  'insights.times': {'en': '{n}×', 'de': '{n}×'},

  // settings
  'settings.title': {'en': 'settings', 'de': 'einstellungen'},
  'settings.profile': {'en': 'your profile', 'de': 'dein profil'},
  'settings.profile.note': {'en': 'what you avoid, what you need, how much time you have', 'de': 'was du meidest, was du brauchst, wie viel zeit du hast'},
  'settings.language': {'en': 'language', 'de': 'sprache'},
  'settings.adaptation': {'en': 'adaptation', 'de': 'anpassung'},
  'settings.showTags': {'en': 'show version tags on cards', 'de': 'versions-tags auf karten zeigen'},
  'settings.showTags.note': {'en': 'diet · effort · kcal under each dish', 'de': 'ernährung · aufwand · kcal unter jedem gericht'},
  'settings.accessibility': {'en': 'accessibility', 'de': 'barrierefreiheit'},
  'settings.reduceMotion': {'en': 'reduce motion', 'de': 'bewegung reduzieren'},
  'settings.reduceMotion.system': {'en': 'follow system', 'de': 'wie das system'},
  'settings.reduceMotion.on': {'en': 'on', 'de': 'an'},
  'settings.reduceMotion.off': {'en': 'off', 'de': 'aus'},
  'settings.visualAlert': {'en': 'visual timer alert', 'de': 'visueller timer-alarm'},
  'settings.visualAlert.note': {'en': 'flash coral & teal when a timer ends (steady banner with reduced motion)', 'de': 'koralle & petrol blinken, wenn ein timer endet (ruhiges banner bei reduzierter bewegung)'},
  'settings.quickTap': {'en': 'quick next tap in cook mode', 'de': 'schnell-tipp im kochmodus'},
  'settings.quickTap.note': {'en': 'one tap on the step text moves on, with a little buzz', 'de': 'ein tipp auf den schritt-text geht weiter, mit kurzem vibrieren'},
  'settings.data': {'en': 'your data', 'de': 'deine daten'},
  'settings.backup': {'en': 'backup & restore', 'de': 'sichern & wiederherstellen'},
  'settings.backup.note': {'en': 'two files to the share sheet, optional password', 'de': 'zwei dateien ins teilen-menü, optional mit passwort'},
  'settings.insights': {'en': 'shopping insights', 'de': 'einkaufs-einblicke'},
  'settings.history': {'en': 'cooking history', 'de': 'kochverlauf'},
  'settings.help': {'en': 'help & faq', 'de': 'hilfe & faq'},
  'settings.about': {'en': 'about', 'de': 'über die app'},
  'settings.about.note': {'en': 'offline, no accounts, no telemetry, no ai at runtime. corpus {version}.', 'de': 'offline, keine konten, keine telemetrie, keine ki zur laufzeit. korpus {version}.'},
  'settings.about.privacy': {'en': 'nothing you do here leaves this phone.', 'de': 'nichts, was du hier tust, verlässt dieses handy.'},
  'settings.resetOnboarding': {'en': 'run the welcome again', 'de': 'begrüßung nochmal zeigen'},

  // profile editor
  'profile.title': {'en': 'your profile', 'de': 'dein profil'},
  'profile.name': {'en': 'name', 'de': 'name'},
  'profile.styles': {'en': 'ways of eating', 'de': 'ernährungsweisen'},
  'profile.styles.note': {'en': 'shortcuts that expand to everything they imply', 'de': 'abkürzungen, die alles einschließen, was sie bedeuten'},
  'profile.classes': {'en': 'classes to avoid', 'de': 'klassen, die du meidest'},
  'profile.classes.note': {'en': 'all dairy, all nuts, all shellfish…', 'de': 'alle milchprodukte, alle nüsse, alle krustentiere…'},
  'profile.specific': {'en': 'specific ingredients', 'de': 'einzelne zutaten'},
  'profile.specific.note': {'en': 'apples, cilantro, bell peppers… picking a group covers everything under it.', 'de': 'äpfel, koriander, paprika… eine gruppe deckt alles darunter ab.'},
  'profile.specific.hint': {'en': 'type to search the ingredient dictionary', 'de': 'tippen, um im zutatenverzeichnis zu suchen'},
  'profile.required': {'en': 'requirements', 'de': 'anforderungen'},
  'profile.required.note': {'en': 'only show versions that meet these', 'de': 'nur versionen zeigen, die das erfüllen'},
  'profile.halalKosher.note': {'en': 'we describe ingredients only — “halal-compatible” means no pork, no alcohol, no non-halal gelatin; “kosher-compatible” means no pork, no shellfish, no meat with dairy, no non-kosher gelatin. certification is a matter of sourcing and supervision, never of a recipe text.', 'de': 'wir beschreiben nur zutaten — „halal-kompatibel“ heißt kein schwein, kein alkohol, keine nicht-halal gelatine; „koscher-kompatibel“ heißt kein schwein, keine krustentiere, kein fleisch mit milch, keine nicht-koschere gelatine. eine zertifizierung ist eine frage von herkunft und aufsicht, nie eines rezepttextes.'},
  'profile.calories': {'en': 'calorie target', 'de': 'kalorienziel'},
  'profile.calories.note': {'en': 'per meal, ± {tol} kcal. a hard filter, with a per-dish switch to peek outside.', 'de': 'pro mahlzeit, ± {tol} kcal. ein harter filter, mit einem schalter pro gericht zum drüberschauen.'},
  'profile.tolerance': {'en': 'tolerance', 'de': 'toleranz'},
  'profile.time': {'en': 'time budget', 'de': 'zeitbudget'},
  'profile.time.note': {'en': 'versions that take longer stay out of sight', 'de': 'versionen, die länger dauern, bleiben außer sicht'},
  'profile.effort': {'en': 'effort mood', 'de': 'aufwand heute'},
  'profile.effort.note': {'en': 'which version wins when several fit', 'de': 'welche version gewinnt, wenn mehrere passen'},
  'profile.saved': {'en': 'profile saved', 'de': 'profil gespeichert'},
  'profile.avoidNone': {'en': 'nothing avoided yet', 'de': 'noch nichts gemieden'},

  // backup
  'backup.title': {'en': 'backup & restore', 'de': 'sichern & wiederherstellen'},
  'backup.kicker': {'en': 'files, not clouds', 'de': 'dateien statt cloud'},
  'backup.export': {'en': 'export', 'de': 'exportieren'},
  'backup.export.note': {'en': 'writes morphcook-backup.json (readable) and morphcook-backup.json.gz (compressed) to the share sheet. save whichever you prefer.', 'de': 'schreibt morphcook-backup.json (lesbar) und morphcook-backup.json.gz (komprimiert) ins teilen-menü. behalte, was dir lieber ist.'},
  'backup.password': {'en': 'password (optional)', 'de': 'passwort (optional)'},
  'backup.password.note': {'en': 'encrypts the .json file (aes-256-gcm). the .gz stays readable. a lost password cannot be recovered.', 'de': 'verschlüsselt die .json-datei (aes-256-gcm). die .gz bleibt lesbar. ein verlorenes passwort ist nicht wiederherstellbar.'},
  'backup.exportNow': {'en': 'export two files', 'de': 'zwei dateien exportieren'},
  'backup.exported': {'en': 'backup handed to the share sheet', 'de': 'sicherung ans teilen-menü übergeben'},
  'backup.exportFailed': {'en': 'export failed: {error}', 'de': 'export fehlgeschlagen: {error}'},
  'backup.import': {'en': 'restore', 'de': 'wiederherstellen'},
  'backup.import.note': {'en': 'pick a morphcook backup. the format is detected automatically.', 'de': 'wähl eine morphcook-sicherung. das format wird automatisch erkannt.'},
  'backup.importNow': {'en': 'choose a file', 'de': 'datei wählen'},
  'backup.needsPassword': {'en': 'this backup is password protected.', 'de': 'diese sicherung ist passwortgeschützt.'},
  'backup.enterPassword': {'en': 'password', 'de': 'passwort'},
  'backup.decrypt': {'en': 'unlock', 'de': 'entsperren'},
  'backup.error.wrongPassword': {'en': 'Incorrect password. Please try again.', 'de': 'Falsches Passwort. Bitte versuch es nochmal.'},
  'backup.error.corrupted': {'en': 'Backup file is corrupted and cannot be restored.', 'de': 'Die Sicherungsdatei ist beschädigt und kann nicht wiederhergestellt werden.'},
  'backup.error.invalid': {'en': 'This file is not a valid MorphCook backup.', 'de': 'Diese Datei ist keine gültige MorphCook-Sicherung.'},
  'backup.error.newer': {'en': 'This backup comes from a newer version of MorphCook.', 'de': 'Diese Sicherung stammt aus einer neueren MorphCook-Version.'},
  'backup.mode.title': {'en': 'merge or replace?', 'de': 'zusammenführen oder ersetzen?'},
  'backup.mode.note': {'en': 'the backup is from {date}: {saved} saved, {history} cooks, {plan} planned meals.', 'de': 'die sicherung ist vom {date}: {saved} gespeichert, {history} gekocht, {plan} geplante mahlzeiten.'},
  'backup.mode.merge': {'en': 'merge', 'de': 'zusammenführen'},
  'backup.mode.merge.note': {'en': 'keep what is here and add the backup', 'de': 'behalten, was da ist, und die sicherung dazu'},
  'backup.mode.replace': {'en': 'replace', 'de': 'ersetzen'},
  'backup.mode.replace.note': {'en': 'throw away what is here', 'de': 'wegwerfen, was da ist'},
  'backup.restored': {'en': 'restored. welcome back.', 'de': 'wiederhergestellt. willkommen zurück.'},
  'backup.includes': {'en': 'includes profile, saved versions, meal plan, history, shopping list and the dishes you searched for and didn\'t find. never the recipe corpus.', 'de': 'enthält profil, gespeicherte versionen, wochenplan, verlauf, einkaufsliste und die gerichte, die du gesucht und nicht gefunden hast. nie den rezeptkorpus.'},
  'backup.contentRequests': {'en': '{n} dishes searched for and not found', 'de': '{n} gesuchte gerichte ohne treffer'},

  // faq
  'faq.title': {'en': 'help & faq', 'de': 'hilfe & faq'},
  'faq.kicker': {'en': 'the small print, kindly', 'de': 'das kleingedruckte, freundlich'},
  'faq.hint': {'en': 'search the help', 'de': 'hilfe durchsuchen'},
  'faq.all': {'en': 'all', 'de': 'alle'},
  'faq.empty': {'en': 'nothing matches — try another word', 'de': 'nichts passt — probier ein anderes wort'},
  'faq.related': {'en': 'related', 'de': 'siehe auch'},

  // cook mode
  'cook.step': {'en': 'step {n} of {total}', 'de': 'schritt {n} von {total}'},
  'cook.prev': {'en': 'previous', 'de': 'zurück'},
  'cook.next': {'en': 'next', 'de': 'weiter'},
  'cook.finish': {'en': 'finish', 'de': 'fertig'},
  'cook.timer.start': {'en': 'start timer', 'de': 'timer starten'},
  'cook.timer.pause': {'en': 'pause', 'de': 'pause'},
  'cook.timer.resume': {'en': 'resume', 'de': 'weiter'},
  'cook.timer.reset': {'en': 'reset', 'de': 'zurücksetzen'},
  'cook.timer.done': {'en': 'time', 'de': 'zeit'},
  'cook.timer.custom': {'en': 'set a timer', 'de': 'timer stellen'},
  'cook.pause': {'en': 'pause cooking', 'de': 'kochen pausieren'},
  'cook.paused': {'en': 'paused — your place is kept', 'de': 'pausiert — dein platz bleibt'},
  'cook.leave': {'en': 'leave', 'de': 'verlassen'},
  'cook.leave.note': {'en': 'your place is kept. come back any time.', 'de': 'dein platz bleibt. komm jederzeit zurück.'},
  'cook.servings': {'en': 'servings', 'de': 'portionen'},
  'cook.ingredients': {'en': 'ingredients for this step', 'de': 'zutaten für diesen schritt'},
  'cook.allIngredients': {'en': 'all ingredients', 'de': 'alle zutaten'},
  'cook.done.title': {'en': 'that\'s dinner.', 'de': 'das war\'s.'},
  'cook.done.note': {'en': 'added to your cooking history. sit down, eat, ignore the dishes.', 'de': 'in deinem kochverlauf notiert. hinsetzen, essen, den abwasch ignorieren.'},
  'cook.done.again': {'en': 'cook it again some time', 'de': 'irgendwann nochmal kochen'},
  'cook.done.save': {'en': 'save this version', 'de': 'diese version speichern'},
  'cook.done.close': {'en': 'back to the book', 'de': 'zurück zum buch'},
  'cook.resume.title': {'en': 'pick up where you left off?', 'de': 'da weitermachen, wo du warst?'},
  'cook.resume.note': {'en': 'you were at step {n} of {total}.', 'de': 'du warst bei schritt {n} von {total}.'},
  'cook.resume.yes': {'en': 'resume', 'de': 'weitermachen'},
  'cook.resume.restart': {'en': 'start over', 'de': 'von vorn'},
  'cook.quickTapHint': {'en': 'tap the text to move on', 'de': 'tipp auf den text, um weiterzugehen'},
  'cook.timerEnded': {'en': 'timer ended', 'de': 'timer abgelaufen'},

  // misc flags / effort
  'effort.easy': {'en': 'easy', 'de': 'einfach'},
  'effort.medium': {'en': 'medium', 'de': 'mittel'},
  'effort.hard': {'en': 'hard', 'de': 'aufwendig'},
  'meal.breakfast': {'en': 'breakfast', 'de': 'frühstück'},
  'meal.lunch': {'en': 'lunch', 'de': 'mittag'},
  'meal.dinner': {'en': 'dinner', 'de': 'abend'},
  'meal.snack': {'en': 'snack', 'de': 'snack'},
  'meal.dessert': {'en': 'dessert', 'de': 'nachtisch'},
  'lang.en': {'en': 'english', 'de': 'englisch'},
  'lang.de': {'en': 'german', 'de': 'deutsch'},
  'error.load': {'en': 'the cookbook could not be opened: {error}', 'de': 'das kochbuch ließ sich nicht öffnen: {error}'},
  'flaggroup.allergen': {'en': 'allergens', 'de': 'allergene'},
  'flaggroup.animal': {'en': 'animal-derived', 'de': 'tierisches'},
  'flaggroup.meat': {'en': 'meat', 'de': 'fleisch'},
  'flaggroup.seafood': {'en': 'fish & seafood', 'de': 'fisch & meeresfrüchte'},
  'flaggroup.lifestyle': {'en': 'lifestyle', 'de': 'lebensstil'},
  'plan.openDish': {'en': 'open the dish page', 'de': 'gerichtseite öffnen'},
  'history.cap': {'en': 'showing the last {n} cooks', 'de': 'die letzten {n} kochabende'},
};
