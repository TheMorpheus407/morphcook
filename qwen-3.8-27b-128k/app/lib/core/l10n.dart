/// Bilingual string catalog for every UI string the app needs.
/// `L10n.t(key)` resolves against the active [LanguageNotifier] or a fallback.
library;

import 'package:flutter/foundation.dart';

class LanguageNotifier extends ChangeNotifier {
  LanguageNotifier([String initial = 'en'])
      : _lang = (initial == 'de' || initial == 'en') ? initial : 'en';

  String _lang;

  static const List<String> codes = ['en', 'de'];

  String get lang => _lang;

  bool get isDe => _lang == 'de';

  void set(String code) {
    if (!codes.contains(code) || code == _lang) return;
    _lang = code;
    notifyListeners();
  }
}

class L10n {
  L10n._();

  static const Map<String, Map<String, String>> _s = {
    "app.name": {"en": "MorphCook", "de": "MorphCook"},

    // nav
    "nav.home": {"en": "home", "de": "start"},
    "nav.cookbook": {"en": "cookbook", "de": "kochbuch"},
    "nav.search": {"en": "search", "de": "suche"},
    "nav.plan": {"en": "plan", "de": "plan"},
    "nav.list": {"en": "list", "de": "liste"},
    "nav.settings": {"en": "settings", "de": "einstellungen"},

    // onboarding
    "ob.welcome": {"en": "the same dish, for every body.", "de": "dasselbe gericht, für jeden körper."},
    "ob.sub": {"en": "nothing gets filtered away — variants keep their seat.", "de": "nichts wird weggefiltert — jedes variante behält seinen platz."},
    "ob.language": {"en": "language", "de": "sprache"},
    "ob.name": {"en": "what should we call you?", "de": "wie dürfen wir dich nennen?"},
    "ob.name-ph": {"en": "a name, a nickname…", "de": "ein name, ein spitzname …"},
    "ob.diet": {"en": "what do you avoid?", "de": "was meidest du?"},
    "ob.diet.sub": {"en": "class-level shortcuts — they expand into the ingredient flags beneath.", "de": "klassenebene kürzel — sie entfalten sich in die zutaten-flags darunter."},
    "ob.avoid": {"en": "any individual ingredients to skip?", "de": "einzelne zutaten, die du überspringst?"},
    "ob.avoid.sub": {"en": "type to search the ingredient dictionary — avoiding a parent covers its children", "de": "zutatendictionary durchsuchen — um elterliche zutaten zu meiden, decken sie ihre kinder ab"},
    "ob.avoid-ph": {"en": "apples, cilantro, bell peppers…", "de": "äpfel, koriander, paprika …"},
    "ob.calories": {"en": "calorie target, per serving", "de": "kalorienziel, pro portion"},
    "ob.time": {"en": "time budget", "de": "zeitbudget"},
    "ob.effort": {"en": "effort mood", "de": "anstrengungs-mood"},
    "ob.confirm-title": {"en": "your kitchen, as it is now", "de": "deine küche, so wie sie ist"},
    "ob.confirm-empty": {"en": "— open, no restrictions", "de": "— offen, keine einschränkungen"},
    "ob.next": {"en": "next", "de": "weiter"},
    "ob.back": {"en": "back", "de": "zurück"},
    "ob.begin": {"en": "begin", "de": "anfangen"},

    // home
    "home.masthead": {"en": "the cookbook", "de": "das kochbuch"},
    "home.dateline": {"en": "today", "de": "heute"},
    "home.featured": {"en": "featured", "de": "hervorgehoben"},
    "home.grid": {"en": "the shelf — every dish that fits you", "de": "das regal — jedes gericht, das dich passt"},
    "home.grid-en": {"en": "the shelf", "de": "das regal"},
    "home.none": {"en": "nothing fits this profile — loosen a filter or two in settings.", "de": "nichts passt zu diesem profil — lockere in den einstellungen ein, zwei filter."},

    // dish detail
    "dim.diet": {"en": "diet", "de": "ernährung"},
    "dim.effort": {"en": "effort", "de": "anstrengung"},
    "dim.calories": {"en": "calorie level", "de": "kalorienpegel"},
    "dim.meal": {"en": "meal", "de": "mahlzeit"},
    "dim.technique": {"en": "technique", "de": "technik"},
    "dish.no-variant": {"en": "no {a} × {b} version yet — we've noted it for the corpus team.", "de": "noch keine {a} × {b}-version — wir haben es für das korpus-team notiert."},
    "dish.ingredients": {"en": "the list", "de": "die liste"},
    "dish.method": {"en": "the method", "de": "die methode"},
    "dish.macros": {"en": "the numbers", "de": "die zahlen"},
    "dish.calories": {"en": "per serving", "de": "pro portion"},
    "dish.time": {"en": "time", "de": "zeit"},
    "dish.effort": {"en": "effort", "de": "anstrengung"},
    "dish.serves": {"en": "serves", "de": "für"},
    "dish.saved": {"en": "in your cookbook", "de": "in deinem kochbuch"},
    "dish.save": {"en": "save this variant", "de": "diese variante speichern"},
    "dish.cook": {"en": "start cooking", "de": "kochen starten"},
    "dish.learn": {"en": "learn", "de": "lernen"},
    "dish.kcal": {"en": "kcal", "de": "kcal"},
    "dish.calories-over": {"en": "outside your calorie target", "de": "außerhalb deiner kalorienziel"},
    "dish.overrides": {"en": "show all regardless of target", "de": "zeige alle trotz ziel"},
    "dish.showing-other": {"en": "showing a variant outside your target — switch back any time", "de": "zeige eine variante außerhalb deiner ziel — wechsle jederzeit zurück"},
    "dish.tags": {"en": "flags", "de": "flaggen"},
    "variant.disabled-note": {"en": "grayed out = outside your current kitchen", "de": "grau = außerhalb deiner aktuellen küche"},
    "variant.switcher": {"en": "sibling variants", "de": "geschwister-varianten"},

    // cookbook
    "cb.title": {"en": "your cookbook", "de": "dein kochbuch"},
    "cb.sub": {"en": "the exact variants you saved — one sibling, not the whole family", "de": "die genauen varianten, die du gespeichert hast — ein bruder, nicht die ganze familie"},
    "cb.empty": {"en": "nothing saved yet", "de": "noch nichts gespeichert"},
    "cb.empty.sub": {"en": "save the exact variant you cook, from a dish page — you save *your* döner.", "de": "speichere die genaue variante, die du kochst, von einer gerichtseite — du speicherst *dein* döner."},
    "cb.saved-on": {"en": "saved", "de": "gespeichert am"},
    "cb.remove": {"en": "unsave", "de": " entfernen"},

    // search
    "search.title": {"en": "search the shelf", "de": "das regal durchsuchen"},
    "search.hint": {"en": "a dish, an ingredient, a word in a step…", "de": "ein gericht, eine zutat, ein wort in einem schritt …"},
    "search.tags": {"en": "filter", "de": "filter"},
    "search.none": {"en": "no dish in the corpus matches — we've noted it for the corpus team.", "de": "kein gericht im korpus passt — wir haben es für das korpus-team notiert."},
    "search.requested": {"en": "search not found · logged", "de": "suche nicht gefunden · protokolliert"},
    "search.results": {"en": "results", "de": "ergebnisse"},

    // meal plan
    "plan.title": {"en": "the week", "de": "die woche"},
    "plan.sub": {"en": "mon–sun × three sittings", "de": "Mo–So × drei sitzungen"},
    "plan.breakfast": {"en": "breakfast", "de": "frühstück"},
    "plan.lunch": {"en": "lunch", "de": "mittag"},
    "plan.dinner": {"en": "dinner", "de": "abend"},
    "plan.empty-slot": {"en": "empty", "de": "leer"},
    "plan.tap": {"en": "tap to assign", "de": "antippen, um zuzuweisen"},
    "plan.assign": {"en": "what goes here?", "de": "was kommt rein?"},
    "plan.cookbook": {"en": "from your book", "de": "aus deinem buch"},
    "plan.remove": {"en": "clear slot", "de": "feld leeren"},
    "plan.export": {"en": "add the week to the list", "de": "woche zur liste hinzufügen"},
    "plan.exported": {"en": "the week is in your shopping list", "de": "die woche ist in deiner einkaufsliste"},
    "plan.prev-week": {"en": "< prev week", "de": "< vorherige woche"},
    "plan.next-week": {"en": "next week >", "de": "nächste woche >"},

    // shopping
    "shop.title": {"en": "the list", "de": "die liste"},
    "shop.sub": {"en": "aggregated across your chosen recipes", "de": "über deine gewählten rezepte aggregiert"},
    "shop.empty": {"en": "list is empty", "de": "liste ist leer"},
    "shop.empty.sub": {"en": "add a recipe, a saved dish, or export a week. 2 cloves + 3 cloves garlic becomes 5.", "de": "füge ein rezept, ein gespeichertes gericht oder eine woche hinzu. 2 zehen knoblauch + 3 zehen knoblauch = 5 zehen."},
    "shop.total": {"en": "ingredients", "de": "zutaten"},
    "shop.clear": {"en": "clear list", "de": "liste leeren"},
    "shop.added-from": {"en": "from", "de": "aus"},
    "shop.aisle": {"en": "aisle", "de": "abteilung"},
    "shop.add-current": {"en": "add this recipe", "de": "dieses rezept hinzufügen"},
    "shop.insights": {"en": "shopping insights", "de": "einkaufs-insights"},

    // insights
    "ins.sub": {"en": "a read-only mirror of what you buy", "de": "ein schreibgeschützter spiegel dessen, was du kaufst"},
    "ins.variety": {"en": "variety score", "de": "vielfaltspunkte"},
    "ins.variety.sub": {"en": "unique ingredients across the recipes on your list", "de": "einzelne zutaten über die rezepte in deiner liste"},
    "ins.top": {"en": "most added", "de": "am meisten hinzugefügt"},
    "ins.none": {"en": "no shopping history yet — add a few recipes to your list.", "de": "noch keine einkaufshistorie — füge ein paar rezepte zu deiner liste hinzu."},
    "ins.month": {"en": "by month", "de": "nach monat"},
    "ins.seasonal": {"en": "seasonal split", "de": "saisonale aufteilung"},

    // cook mode
    "cook.title": {"en": "cooking", "de": "kochen"},
    "cook.step": {"en": "step", "de": "schritt"},
    "cook.of": {"en": "of", "de": "von"},
    "cook.servings": {"en": "servings", "de": "portionen"},
    "cook.next": {"en": "next", "de": "weiter"},
    "cook.prev": {"en": "back", "de": "zurück"},
    "cook.pause": {"en": "pause", "de": "pause"},
    "cook.resume": {"en": "resume", "de": "weiter"},
    "cook.time-left": {"en": "on this step", "de": "auf diesem schritt"},
    "cook.finish": {"en": "finish & log", "de": "beenden & loggen"},
    "cook.logged": {"en": "added to your history", "de": "zu deiner historie hinzugefügt"},
    "cook.quicktap": {"en": "tap to advance", "de": "tippen, um weiter"},
    "cook.done-title": {"en": "cooked.", "de": "gekocht."},
    "cook.done-sub": {"en": "logged to your history — next time another sibling variant gets the nudge.", "de": "in deine historie geloggt — nächstes mal bekommt eine andere geschwister-variante den anstoß."},
    "cook.total-time": {"en": "steps", "de": "schritte"},
    "cook.timer": {"en": "timer", "de": "timer"},
    "cook.timer-done": {"en": "time's up", "de": "zeit ist um"},

    // history
    "hist.title": {"en": "what you've cooked", "de": "was du gekocht hast"},
    "hist.sub": {"en": "the recent past of your kitchen", "de": "die jüngere vergangenheit deiner küche"},
    "hist.empty": {"en": "nothing cooked yet — start a recipe and finish it", "de": "noch nichts gekocht — starte ein rezept und beende es"},
    "hist.week-this": {"en": "this week", "de": "diese woche"},
    "hist.week-ago": {"en": "week {n} ago", "de": "woche {n} zurück"},
    "hist.times": {"en": "×{n}", "de": "×{n}"},
    "hist.last": {"en": "last time", "de": "letztes mal"},
    "plan.fill": {"en": "{n} of 21 slots filled", "de": "{n} von 21 feldern befüllt"},

    // settings
    "set.title": {"en": "settings", "de": "einstellungen"},
    "set.profile": {"en": "your kitchen", "de": "deine küche"},
    "set.name": {"en": "name", "de": "name"},
    "set.language": {"en": "language", "de": "sprache"},
    "set.diet": {"en": "avoid · class", "de": "meiden · klasse"},
    "set.avoid-list": {"en": "avoid · ingredients", "de": "meiden · zutaten"},
    "set.required": {"en": "want (positive)", "de": "möchten (positiv)"},
    "set.calories": {"en": "calorie target / serving", "de": "kalorienziel / portion"},
    "set.tolerance": {"en": "tolerance ±", "de": "toleranz ±"},
    "set.time": {"en": "time budget", "de": "zeitbudget"},
    "set.effort": {"en": "preferred effort", "de": "bevorzugte anstrengung"},
    "set.appearance": {"en": "appearance & motion", "de": "optik & bewegung"},
    "set.show-tags": {"en": "show variant tags", "de": "varianten-tags anzeigen"},
    "set.reduce-motion": {"en": "reduce motion", "de": "bewegung reduzieren"},
    "set.visual-alerts": {"en": "visual flash when a timer ends", "de": "visuelles blinken, wenn ein timer endet"},
    "set.quick-tap": {"en": "quick-tap to advance steps", "de": "schnell-tippen, um schritte zu wechseln"},
    "set.backup": {"en": "backup & restore", "de": "backup & wiederherstellung"},
    "set.help": {"en": "help center", "de": "hilfszentrum"},
    "set.guide": {"en": "kitchen reference", "de": "küchenreferenz"},
    "set.about": {"en": "about", "de": "über"},
    "set.onboard": {"en": "re-run onboarding", "de": "onboarding neu starten"},
    "set.halal-note": {"en": "we never claim halal or kosher certification. 'compatible' means ingredient choices only — sourcing is yours to verify.", "de": "wir behaupten niemals halal oder koscher-zertifizierung. 'kompatibel' bedeutet nur zutatenauswahl — beschaffung liegt bei dir."},

    // backup
    "bk.title": {"en": "backup & restore", "de": "backup & wiederherstellung"},
    "bk.sub": {"en": "two files, no cloud, you keep them", "de": "zwei dateien, keine cloud, du behältst sie"},
    "bk.password": {"en": "backup password (optional)", "de": "backup-passwort (optional)"},
    "bk.password.sub": {"en": "if set, the .json is AES-256-GCM encrypted; the .gz stays plain", "de": "falls gesetzt, wird das .json mit aes-256-gcm verschlüsselt; das .gz bleibt unverschlüsselt"},
    "bk.export": {"en": "export backup", "de": "backup exportieren"},
    "bk.import": {"en": "import backup", "de": "backup importieren"},
    "bk.merge": {"en": "merge with existing", "de": "mit bestehendem zusammenführen"},
    "bk.replace": {"en": "replace everything", "de": "alles ersetzen"},
    "bk.choose": {"en": "choose how to import", "de": "wähle, wie importiert werden soll"},
    "bk.exported": {"en": "two files handed to your share sheet", "de": "zwei dateien wurden deinem share- panel übergeben"},
    "bk.no-file": {"en": "no backup file selected", "de": "keine backup-datei ausgewählt"},
    "bk.need-password": {"en": "this backup is encrypted — enter the password", "de": "dieses backup ist verschlüsselt — gib das passwort ein"},
    "bk.err.badpass": {"en": "Incorrect password. Please try again.", "de": "Falsches Passwort. Bitte versuche es erneut."},
    "bk.err.corrupt": {"en": "Backup file is corrupted and cannot be restored.", "de": "Die Backup-Datei ist beschädigt und kann nicht wiederhergestellt werden."},
    "bk.err.invalid": {"en": "This file is not a valid MorphCook backup.", "de": "Diese Datei ist kein gültiges MorphCook-Backup."},
    "bk.imported": {"en": "backup restored", "de": "Backup wiederhergestellt"},
    "bk.imported-sub": {"en": "{n} saved · {m} history · {p} meal slots", "de": "{n} gespeichert · {m} historien · {p} mahlzeitslots"},

    // faq
    "faq.title": {"en": "help center", "de": "hilfszentrum"},
    "faq.sub": {"en": "search the answers", "de": "die antworten durchsuchen"},
    "faq.all": {"en": "all", "de": "alle"},
    "faq.none": {"en": "no entry matches", "de": "keine eintrag passt"},

    // ingredient guide
    "ig.title": {"en": "kitchen reference", "de": "küchenreferenz"},
    "ig.sub": {"en": "what it is, how to treat it, where to find it", "de": "was es ist, wie man es behandelt, wo man es findet"},
    "ig.search": {"en": "find an ingredient", "de": "eine zutat finden"},
    "ig.none": {"en": "nothing here yet", "de": "noch nichts hier"},

    // misc
    "common.close": {"en": "close", "de": "schließen"},
    "common.cancel": {"en": "cancel", "de": "abbrechen"},
    "common.ok": {"en": "ok", "de": "ok"},
    "common.add": {"en": "add", "de": "hinzufügen"},
    "common.remove": {"en": "remove", "de": "entfernen"},
    "common.save": {"en": "save", "de": "speichern"},
    "common.search": {"en": "search", "de": "suche"},
    "effort.easy": {"en": "easy", "de": "einfach"},
    "effort.medium": {"en": "medium", "de": "mittel"},
    "effort.hard": {"en": "hard", "de": "anspruchsvoll"},
    "meal.breakfast": {"en": "breakfast", "de": "frühstück"},
    "meal.lunch": {"en": "lunch", "de": "mittag"},
    "meal.dinner": {"en": "dinner", "de": "abend"},
    "about.v1": {"en": "v1 · the offline cookbook", "de": "v1 · das offline-kochbuch"},
    "about.built": {"en": "offline, no accounts, no cloud — the corpus ships in the store release", "de": "offline, keine accounts, keine cloud — das korpus kommt in der store-veröffentlichung"},
    "about.corpus": {"en": "corpus {n} recipes across {d} dish families · de + en", "de": "korpus {n} rezepte über {d} gerichte · de + en"},
  };

  static void bind(LanguageNotifier n) => n.addListener(() {});

  /// Resolve key for the [lang] code.
  static String t(String key, String lang) {
    final m = _s[key];
    if (m == null) return key;
    return m[lang] ?? m['en'] ?? key;
  }

  /// Resolve key with `{a}`-style interpolation.
  static String tf(String key, String lang, Map<String, String> args) {
    var out = t(key, lang);
    out = out.replaceAllMapped(
      RegExp(RegExp.escape('{') + r'\s*\w+\s*' + RegExp.escape('}')),
      (m0) {
        final k = m0[0]!.replaceFirst('{', '').replaceFirst('}', '').trim();
        return args[k] ?? m0[0]!;
      },
    );
    return out;
  }
}
