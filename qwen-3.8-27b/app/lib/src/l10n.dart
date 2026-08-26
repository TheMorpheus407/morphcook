/// Bilingual (DE/EN, N-language-ready) UI strings.
class L10n {
  const L10n._();

  static const Map<String, Map<String, String>> _t = {
    // app
    'app.name': {'en': 'MorphCook', 'de': 'MorphCook'},
    'app.tagline': {
      'en': 'the same dish, for every body',
      'de': 'das gleiche Gericht, für jeden Körper'
    },

    // nav
    'nav.home': {'en': 'home', 'de': 'start'},
    'nav.search': {'en': 'search', 'de': 'suche'},
    'nav.plan': {'en': 'plan', 'de': 'plan'},
    'nav.settings': {'en': 'settings', 'de': 'einstellungen'},

    // onboarding
    'onb.welcome.hand': {'en': 'hello — welcome in', 'de': 'hallo — willkommen in'},
    'onb.welcome.title': {'en': 'your cookbook,', 'de': 'deinem Kochbuch,'},
    'onb.welcome.sub': {
      'en': 'not a feed, not a filter. every dish you have ever loved — written fully for the way you eat. nothing removed, nothing swapped. just authored, for you.',
      'de': 'kein Feed, kein Filter. Jedes Gericht, das du je geliebt hast — vollständig für dich geschrieben. Nichts entfernt, nichts ersetzt. Nur verfasst, für dich.'
    },
    'onb.pick_lang': {'en': 'which language shall we write in?', 'de': 'in welcher Sprache sollen wir schreiben?'},
    'onb.name.q': {'en': 'what shall we call you?', 'de': 'wie dürfen wir dich nennen?'},
    'onb.name.hand': {'en': 'we write recipes for you — by name.', 'de': 'wir schreiben Rezepte für dich — namentlich.'},
    'onb.diet.q': {'en': 'what should recipes never contain?', 'de': 'was dürfen Rezepte bitte niemals enthalten?'},
    'onb.diet.hand': {
      'en': 'these act as quiet rules. recipes that break them simply don&rsquo;t appear — no guilt, no "adapted for you".',
      'de': 'diese wirken als stille Regeln. Rezepte, die sie brechen, erscheinen einfach nicht — keine Schuld, kein „angepasst für dich“.'
    },
    'onb.ing.q': {'en': 'any individual ingredients to avoid?', 'de': 'bestimmte Zutaten meiden?'},
    'onb.ing.hand': {'en': 'optional. e.g. “apples”, “cilantro”.', 'de': 'optional. z. B. „Äpfel“, „Koriander“.'},
    'onb.ing.placeholder': {'en': 'type an ingredient…', 'de': 'Zutat eingeben …'},
    'onb.effort.q': {'en': 'how much effort sounds right?', 'de': 'wie viel Aufwand klingt richtig?'},
    'onb.time.q': {'en': 'how much time do you have?', 'de': 'wie viel Zeit hast du?'},
    'onb.cal.q': {'en': 'a calorie target for a main dish?', 'de': 'ein Kalorienziel fürs Hauptgericht?'},
    'onb.cal.hand': {'en': 'a soft compass, not a rule — you can always relax it per dish.', 'de': 'ein sanfter Kompass, keine Regel — pro Gericht lässt es sich immer lockern.'},
    'onb.review.q': {'en': 'your book, in one glance', 'de': 'dein Buch auf einen Blick'},
    'onb.review.hand': {'en': 'you can change all of this later, in settings.', 'de': 'all das kannst du später in den Einstellungen ändern.'},
    'onb.begin': {'en': 'begin cooking', 'de': 'loskochen'},
    'onb.back': {'en': 'back', 'de': 'zurück'},

    // common
    'c.save': {'en': 'save to cookbook', 'de': 'ins Kochbuch'},
    'c.saved': {'en': 'in your cookbook', 'de': 'im Kochbuch'},
    'c.cook': {'en': 'cook it now', 'de': 'jetzt kochen'},
    'c.resume': {'en': 'resume', 'de': 'fortsetzen'},
    'c.close': {'en': 'close', 'de': 'schließen'},
    'c.cancel': {'en': 'cancel', 'de': 'abbrechen'},
    'c.confirm': {'en': 'confirm', 'de': 'bestätigen'},
    'c.ok': {'en': 'ok', 'de': 'ok'},
    'c.delete': {'en': 'delete', 'de': 'löschen'},
    'c.add': {'en': 'add', 'de': 'hinzufügen'},
    'c.remove': {'en': 'remove', 'de': 'entfernen'},
    'c.search': {'en': 'search…', 'de': 'suchen …'},
    'c.learnMore': {'en': 'learn more', 'de': 'mehr erfahren'},
    'c.cookedIt': {'en': 'cooked it', 'de': 'gekocht'},
    'c.notYet': {'en': 'not yet — no version for that combination exists.', 'de': 'noch nicht — für diese Kombination existiert noch keine Version.'},
    'c.kcal': {'en': 'kcal', 'de': 'kcal'},
    'c.min': {'en': 'min', 'de': 'min'},
    'c.serves': {'en': 'serves', 'de': 'für'},
    'c.prep': {'en': 'prep', 'de': 'vorbereitung'},
    'c.effort.easy': {'en': 'easy', 'de': 'leicht'},
    'c.effort.medium': {'en': 'medium', 'de': 'mittlere Mühe'},
    'c.effort.hard': {'en': 'hard', 'de': 'ambitioniert'},
    'c.ing.title': {'en': 'ingredients', 'de': 'zutaten'},
    'c.method.title': {'en': 'method', 'de': 'zubereitung'},
    'c.macros.title': {'en': 'macros', 'de': 'nährwerte'},
    'c.dish': {'en': 'dish', 'de': 'gericht'},
    'c.tags': {'en': 'notes', 'de': 'merkmalen'},
    'c.aisle': {'en': 'aisle', 'de': 'abteilung'},,

    // home
    'home.masthead': {'en': 'the cookbook of', 'de': 'das Kochbuch von'},
    'home.featured': {'en': 'today’s dish', 'de': 'heutiges Gericht'},
    'home.featured.hand': {'en': 'fresh off the stove — picked for you', 'de': 'frisch vom Herd — für dich ausgewählt'},
    'home.yourStyle': {'en': 'written for your way of eating', 'de': 'geschrieben für deine Art zu essen'},
    'home.section.breakfast': {'en': 'for breakfast', 'de': 'zum Frühstück'},
    'home.section.lunch': {'en': 'for lunch', 'de': 'zum Mittagessen'},
    'home.section.dinner': {'en': 'for dinner', 'de': 'zum Abendessen'},
    'home.section.more': {'en': 'further dishes', 'de': 'weitere Gerichte'},
    'home.continue': {'en': 'continue cooking', 'de': 'weiterkochen'},
    'home.continue.hand': {'en': 'left off at step {n} of {m}', 'de': 'abgebrochen bei Schritt {n} von {m}'},
    'home.noMatch': {'en': 'nothing matches right now', 'de': 'momentan passt nichts'},
    'home.noMatch.hand': {'en': 'try relaxing a rule in settings — your cookbook is bigger than it looks.', 'de': 'lockere eine Regel in den Einstellungen — dein Kochbuch ist größer als es aussieht.'},
    'home.loading': {'en': 'opening the pantry…', 'de': 'die Vorratskammer wird geöffnet …'},
    'home.diet.vegan': {'en': 'vegan', 'de': 'vegan'},
    'home.diet.vegetarian': {'en': 'vegetarian', 'de': 'vegetarisch'},
    'home.diet.keto': {'en': 'keto', 'de': 'keto'},
    'home.diet.halal': {'en': 'halal-compatible', 'de': 'halal-konform*'},
    'home.diet.classic': {'en': 'classic', 'de': 'klassisch'},
    'home.diet.italian': {'en': 'italian', 'de': 'italienisch'},

    // dish detail
    'dish.by': {'en': 'a version of', 'de': 'eine Version von'},
    'dish.dim.diet': {'en': 'diet', 'de': 'Ernährung'},
    'dish.dim.effort': {'en': 'effort', 'de': 'Aufwand'},
    'dish.dim.cal': {'en': 'calorie level', 'de': 'Kalorienstufe'},
    'dish.noVariant': {'en': 'no version for this combination yet', 'de': 'für diese Kombination gibt es noch keine Version'},
    'dish.calOverride.on': {'en': 'showing all calorie levels', 'de': 'alle Kalorienstufen angezeigt'},
    'dish.calOverride.off': {'en': 'within your target (~{n} kcal)', 'de': 'deinem Ziel (~{n} kcal) nahe'},
    'dish.switchNote': {'en': 'switching is instant — nothing is replaced, a different recipe is simply chosen.', 'de': 'das Umschalten ist sofort da — es wird nichts ersetzt, lediglich ein anderes Rezept gewählt.'},

    // search
    'search.title': {'en': 'search the book', 'de': 'suche im Buch'},
    'search.placeholder': {'en': 'a dish, an ingredient, a mood…', 'de': 'ein Gericht, eine Zutat, eine Stimmung …'},
    'search.results': {'en': '{n} dishes in your book', 'de': '{n} Gerichte in deinem Buch'},
    'search.tags': {'en': 'filter by note', 'de': 'nach Merkmalen filtern'},
    'search.none': {'en': 'nothing in your book matches', 'de': 'in deinem Buch passt nichts dazu'},
    'search.none.hand': {'en': 'we noted this — the cookbook grows over time.', 'de': 'wir haben es notiert — das Kochbuch wächst mit der Zeit.'},
    'search.tag.vegan': {'en': 'vegan', 'de': 'vegan'},
    'search.tag.fast': {'en': 'under 30 min', 'de': 'unter 30 min'},

    // cooking
    'cook.title': {'en': 'now cooking', 'de': 'jetzt wird gekocht'},
    'cook.step': {'en': 'step', 'de': 'Schritt'},
    'cook.of': {'en': 'of', 'de': 'von'},
    'cook.start': {'en': 'start recipe', 'de': 'Rezept starten'},
    'cook.next': {'en': 'next', 'de': 'weiter'},
    'cook.prev': {'en': 'back', 'de': 'zurück'},
    'cook.pause': {'en': 'pause', 'de': 'Pause'},
    'cook.finished': {'en': 'you cooked this', 'de': 'du hast gekocht'},
    'cook.finished.hand': {'en': 'the kitchen remembers. see it again any time in your cookbook.', 'de': 'die Küche merkt es sich. In deinem Kochbuch findest du es jederzeit wieder.'},
    'cook.servings': {'en': 'servings', 'de': 'Portionen'},
    'cook.muted': {'en': 'done — tap to continue', 'de': 'fertig — antippen zum Fortfahren'},
    'cook.timer': {'en': 'timer', 'de': 'Timer'},
    'cook.tapNote': {'en': 'tip: tap the page to go forward', 'de': 'Tipp: auf die Seite tippen = weiter'},

    // cookbook
    'book.title': {'en': 'your cookbook', 'de': 'dein Kochbuch'},
    'book.hand': {'en': 'each entry is a fully-authored recipe — saved by choice, not by default.', 'de': 'Jeder Eintrag ist ein vollständig verfasstes Rezept — bewusst gespeichert.'},
    'book.empty': {'en': 'still empty', 'de': 'noch leer'},
    'book.empty.hand': {'en': 'when a recipe feels like yours, save it. it will be waiting here.', 'de': 'Wenn dir ein Rezept gehört, speichere es. Es wartet hier.'},

    // history
    'hist.title': {'en': 'cooking history', 'de': 'Kochhistorie'},
    'hist.hand': {'en': 'what the kitchen has seen', 'de': 'was die Küche gesehen hat'},
    'hist.week': {'en': 'this week', 'de': 'diese Woche'},
    'hist.prevWeek': {'en': 'last week', 'de': 'letzte Woche'},
    'hist.earlier': {'en': 'before that', 'de': 'davor'},
    'hist.empty': {'en': 'nothing cooked yet', 'de': 'noch nichts gekocht'},
    'hist.empty.hand': {'en': 'the first dish is always the bravest.', 'de': 'Das erste Gericht ist immer das Mutigste.'},

    // meal plan
    'plan.title': {'en': 'week planner', 'de': 'Wochenplan'},
    'plan.hand': {'en': 'tap a slot, pick from your book. drag to move.', 'de': 'Slot antippen, aus dem Buch wählen. Zum Verschieben ziehen.'},
    'plan.slot.breakfast': {'en': 'breakfast', 'de': 'Frühstück'},
    'plan.slot.lunch': {'en': 'lunch', 'de': 'Mittag'},
    'plan.slot.dinner': {'en': 'dinner', 'de': 'Abend'},
    'plan.pick.title': {'en': 'choose a dish for', 'de': 'Gericht wählen für'},
    'plan.pick.from': {'en': 'from your cookbook', 'de': 'aus deinem Kochbuch'},
    'plan.pick.search': {'en': 'or search the whole book', 'de': 'oder im ganzen Buch suchen'},
    'plan.clear': {'en': 'clear', 'de': 'leeren'},
    'plan.sharing': {'en': 'shopping list for this week', 'de': 'Einkaufsliste für diese Woche'},
    'plan.empty': {'en': 'nothing planned yet', 'de': 'noch nichts geplant'},

    // shopping
    'shop.title': {'en': 'shopping list', 'de': 'Einkaufsliste'},
    'shop.hand': {'en': 'quantities merged — where the units allow it.', 'de': 'Mengen zusammengeführt — wo die Einheiten es erlauben.'},
    'shop.total': {'en': '{n} items', 'de': '{n} Artikel'},
    'shop.from': {'en': 'from {n} recipes', 'de': 'aus {n} Rezepten'},
    'shop.copy': {'en': 'copy as text', 'de': 'als Text kopieren'},
    'shop.copied': {'en': 'copied!', 'de': 'kopiert!'},
    'shop.insights': {'en': 'shopping insights', 'de': 'Einkaufs-Insights'},
    'shop.insights.variety': {'en': 'variety score', 'de': 'Vielfalt'},
    'shop.insights.variety.hand': {'en': 'unique ingredients across your saved book', 'de': 'eindeutige Zutaten in deinem gespeicherten Buch'},
    'shop.insights.top': {'en': 'most bought', 'de': 'am häufigsten'},
    'shop.insights.seasonal': {'en': 'by season', 'de': 'nach Saison'},
    'shop.insights.empty': {'en': 'save recipes and your patterns will appear here.', 'de': 'Speichere Rezepte — dann erscheinen hier deine Muster.'},
    'shop.empty': {'en': 'select recipes to build a list', 'de': 'Rezepte auswählen, um eine Liste zu bauen'},
    'shop.empty.hand': {'en': 'or build one from your week plan.', 'de': 'oder erstelle eine aus deinem Wochenplan.'},

    // settings
    'set.title': {'en': 'settings', 'de': 'Einstellungen'},
    'set.profile': {'en': 'profile', 'de': 'Profil'},
    'set.name': {'en': 'name', 'de': 'Name'},
    'set.lang': {'en': 'language', 'de': 'Sprache'},
    'set.avoid': {'en': 'never contain', 'de': 'niemals enthalten'},
    'set.avoid.hand': {'en': 'class-level rules; recipes breaking these never appear.', 'de': 'Klassenregeln; Rezepte, die diese brechen, erscheinen nie.'},
    'set.avoidIng': {'en': 'avoid specific ingredients', 'de': 'bestimmte Zutaten meiden'},
    'set.required': {'en': 'must be compatible with', 'de': 'konform mit'},
    'set.required.hand': {'en': 'we never claim certification — only “compatible ingredients”.', 'de': 'Wir behaupten nie Siegel — nur „konforme Zutaten“.'},
    'set.time': {'en': 'time budget', 'de': 'Zeitbudget'},
    'set.time.hand': {'en': 'dishes beyond this never appear.', 'de': 'Gerichte darüber erscheinen nie.'},
    'set.cal': {'en': 'calorie target (per serving)', 'de': 'Kalorienziel (pro Portion)'},
    'set.cal.hand': {'en': '± {tol} kcal tolerance — relax it per dish any time.', 'de': '± {tol} kcal Toleranz — pro Gericht jederzeit lockern.'},
    'set.effort': {'en': 'effort mood', 'de': 'Aufwandsstimmung'},
    'set.tags': {'en': 'show variant tags', 'de': 'Varianten-Tags anzeigen'},
    'set.acc': {'en': 'accessibility', 'de': 'Barrierefreiheit'},
    'set.reduceMotion': {'en': 'reduce motion', 'de': 'Bewegung reduzieren'},
    'set.reduceMotion.hand': {'en': 'off — follows device setting', 'de': 'aus — folgt der Geräteeinstellung'},
    'set.visualAlert': {'en': 'visual flash alerts in cook mode', 'de': 'visuelle Blitz-Warnungen im Kochmodus'},
    'set.quickTap': {'en': 'one-hand quick tap (tap page → next step)', 'de': 'Einhand-Schnell-Tipp (Seite antippen → weiter)'},
    'set.data': {'en': 'your data', 'de': 'deine Daten'},
    'set.backup': {'en': 'backup & restore', 'de': 'Sichern & Wiederherstellen'},
    'set.backup.hand': {'en': 'two files: a readable one and a compressed one. nothing leaves your device except what you send to the share sheet.', 'de': 'Zwei Dateien: eine lesbare und eine komprimierte. Verlässt nichts dein Gerät, außer was du ins Freigabefenster sendest.'},
    'set.password': {'en': 'backup password (optional)', 'de': 'Sicherungspasswort (optional)'},
    'set.password.hand': {'en': 'if set, the readable file is encrypted (AES-256). the compressed file stays readable for tools.', 'de': 'Falls gesetzt, wird die lesbare Datei verschlüsselt (AES-256). Die komprimierte bleibt lesbar.'},
    'set.export': {'en': 'export backup…', 'de': 'Sicherung exportieren …'},
    'set.import': {'en': 'import backup…', 'de': 'Sicherung importieren …'},
    'set.merge': {'en': 'merge with current data', 'de': 'mit aktuellen Daten zusammenführen'},
    'set.replace': {'en': 'replace current data', 'de': 'aktuelle Daten ersetzen'},
    'set.contentRequests': {'en': 'content gap notes', 'de': 'Inhalts-Lückenmerkmale'},
    'set.contentRequests.hand': {'en': 'searches that found nothing. helps the book grow where it&rsquo;s missing.', 'de': 'Suche ohne Ergebnis. Hilft dem Buch, an der lückenhaften Stelle zu wachsen.'},
    'set.reset': {'en': 'danger zone', 'de': 'Gefahrenzone'},
    'set.reset.data': {'en': 'erase all local data', 'de': 'alle lokalen Daten löschen'},
    'set.about': {'en': 'about', 'de': 'Über'},
    'set.about.hand': {'en': 'MorphCook v1 — offline, no account, no telemetry. your book is yours; it leaves this device only in files you choose to send.', 'de': 'MorphCook v1 — offline, kein Konto, keine Telemetrie. Dein Buch gehört dir; es verlässt dieses Gerät nur in Dateien, die du selbst weiterreichst.'},

    // faq
    'faq.title': {'en': 'help center', 'de': 'Hilfe-Zentrum'},
    'faq.search': {'en': 'search the help…', 'de': 'Hilfe durchsuchen …'},
    'faq.all': {'en': 'all topics', 'de': 'alle Themen'},
    'faq.none': {'en': 'nothing matched', 'de': 'nichts gefunden'},
    'faq.cat.matching': {'en': 'matching & visibility', 'de': 'Matchen & Sichtbarkeit'},
    'faq.cat.cook': {'en': 'cooking', 'de': 'Kochen'},
    'faq.cat.data': {'en': 'data & privacy', 'de': 'Daten & Privatsphäre'},
    'faq.cat.features': {'en': 'features', 'de': 'Funktionen'},

    // ingredients
    'ing.whereToFind': {'en': 'where to find', 'de': 'wo zu finden'},
    'ing.storage': {'en': 'storage', 'de': 'Aufbewahrung'},
    'ing.usage': {'en': 'kitchen note', 'de': 'Küchennotiz'},
    'ing.description': {'en': 'what it is', 'de': 'was es ist'},
    'ing.shelf': {'en': 'shelf life', 'de': 'Haltbarkeit'},

    // errors
    'err.corpus': {'en': 'the recipe book failed to open. check your installation.', 'de': 'Das Kochbuch konnte nicht geöffnet werden. Prüfe die Installation.'},
    'err.backup.invalid': {'en': 'This file is not a valid MorphCook backup.', 'de': 'Diese Datei ist keine gültige MorphCook-Sicherung.'},
    'err.backup.wrongpw': {'en': 'Incorrect password. Please try again.', 'de': 'Falsches Passwort. Bitte versuche es erneut.'},
    'err.backup.corrupt': {'en': 'Backup file is corrupted and cannot be restored.', 'de': 'Die Sicherung ist beschädigt und kann nicht wiederhergestellt werden.'},
    'err.unknown': {'en': 'something unexpected happened.', 'de': 'es ist etwas Unerwartetes passiert.'},

    // units
    'u.g': {'en': 'g', 'de': 'g'},
    'u.ml': {'en': 'ml', 'de': 'ml'},
    'u.oz': {'en': 'oz', 'de': 'oz'},
    'u.tsp': {'en': 'tsp', 'de': 'TL'},
    'u.tbsp': {'en': 'tbsp', 'de': 'EL'},
    'u.cup': {'en': 'cup', 'de': 'Tasse'},
    'u.pc': {'en': 'pc', 'de': 'Stk'},
    'u.clove': {'en': 'cloves', 'de': 'Zehen'},
    'u.stick': {'en': 'sticks', 'de': 'Stangen'},
    'u.whole': {'en': '', 'de': ''},
    'u.handful': {'en': 'small handful', 'de': 'kleine Handvoll'},
    'u.pinch': {'en': 'pinch', 'de': 'Prise'},
  };

  static String? raw(String key) => _t[key];

  static String t(String lang, String key, {Map<String, String>? args}) {
    final table = _t[key];
    final s = table?[lang] ?? table?['en'] ?? key;
    final out = args != null
        ? s.replaceAll(RegExp(r'\{(\w+)\}'), (m) => args[m.group(1)!] ?? m.group(0)!)
        : s;
    return out
        .replaceAll('&rsquo;', '’')
        .replaceAll('&ldquo;', '“')
        .replaceAll('&rdquo;', '”');
  }

  static const days = {
    'mon': {'en': 'mon', 'de': 'mo'},
    'tue': {'en': 'tue', 'de': 'di'},
    'wed': {'en': 'wed', 'de': 'mi'},
    'thu': {'en': 'thu', 'de': 'do'},
    'fri': {'en': 'fri', 'de': 'fr'},
    'sat': {'en': 'sat', 'de': 'sa'},
    'sun': {'en': 'sun', 'de': 'so'},
  };

  static String day(String lang, String key) => days[key]?[lang] ?? key;

  static const months = {
    1: 'jan',
    2: 'feb',
    3: 'mar',
    4: 'apr',
    5: 'may',
    6: 'jun',
    7: 'jul',
    8: 'aug',
    9: 'sep',
    10: 'oct',
    11: 'nov',
    12: 'dec',
  };
}
