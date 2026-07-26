"""Help centre entries. Bilingual, searchable, categorised, deep-linkable.

`anchor` is the stable key that UI copy links to — see AppFaqLink in the app.
"""

CATEGORIES = [
    ('matching', 'How matching works', 'Wie das Matching funktioniert'),
    ('profile', 'Your profile', 'Dein Profil'),
    ('features', 'Features', 'Funktionen'),
    ('data', 'Data & backup', 'Daten & Backup'),
    ('trouble', 'Troubleshooting', 'Fehlerbehebung'),
]

# id, category, anchor, question(en/de), answer(en/de), keywords, related
ENTRIES = [
    (
        'why-fewer-recipes', 'matching', 'visibility',
        ('Why do I see fewer recipes than my friend?',
         'Warum sehe ich weniger Rezepte als meine Freundin?'),
        ('Your profile hides recipes that clash with it — anything containing a flag '
         'you avoid, an ingredient you named specifically, a cooking time above your '
         'budget, or calories far from your target. Nothing is deleted; loosen a '
         'setting and it comes straight back. The dish itself never disappears: if '
         'one variant is hidden, MorphCook shows you a different variant of the same '
         'dish instead.',
         'Dein Profil blendet Rezepte aus, die dazu im Widerspruch stehen — alles mit '
         'einem Flag, das du meidest, mit einer Zutat, die du ausgeschlossen hast, mit '
         'einer Kochzeit über deinem Budget oder mit Kalorien weit weg von deinem Ziel. '
         'Nichts wird gelöscht; lockere eine Einstellung und es ist sofort wieder da. '
         'Das Gericht selbst verschwindet nie: Ist eine Variante ausgeblendet, zeigt '
         'MorphCook dir eine andere Variante desselben Gerichts.'),
        ['hidden', 'missing', 'filter', 'ausgeblendet', 'fehlt', 'weniger'],
        ['dish-vs-recipe', 'calorie-filter'],
    ),
    (
        'dish-vs-recipe', 'matching', 'dish-vs-recipe',
        ('What is the difference between a dish and a recipe?',
         'Was ist der Unterschied zwischen Gericht und Rezept?'),
        ('A dish is a concept — "Döner". A recipe is one fully-written version of it — '
         '"Vegan Döner", "Halal-friendly Döner". Every recipe is complete on its own; '
         'none of them is a modified copy of another. That is why a vegan variant can '
         'have entirely different steps rather than a list of swaps.',
         'Ein Gericht ist ein Konzept — „Döner“. Ein Rezept ist eine vollständig '
         'ausgeschriebene Version davon — „Veganer Döner“, „Halal-freundlicher Döner“. '
         'Jedes Rezept steht für sich; keines ist eine abgewandelte Kopie eines anderen. '
         'Deshalb kann eine vegane Variante völlig andere Schritte haben statt einer '
         'Liste von Ersatzzutaten.'),
        ['variant', 'dish', 'recipe', 'variante', 'gericht', 'rezept'],
        ['why-fewer-recipes', 'unreachable-combos'],
    ),
    (
        'unreachable-combos', 'matching', 'unreachable',
        ('Why is a variant greyed out?',
         'Warum ist eine Variante ausgegraut?'),
        ('Because that exact combination has not been written yet. If you pick '
         'diet = vegan and there is no vegan × involved version of the dish, the '
         'effort chip stays visible but disabled, with a note. We show it rather than '
         'hide it so you can see what exists and what does not — and so a future '
         'update can simply fill the gap.',
         'Weil genau diese Kombination noch nicht geschrieben wurde. Wählst du '
         'Ernährung = vegan und es gibt keine vegane × aufwendige Version, bleibt der '
         'Aufwand-Chip sichtbar, aber deaktiviert, mit Hinweis. Wir zeigen ihn, statt '
         'ihn zu verstecken, damit du siehst, was existiert und was nicht — und damit '
         'ein späteres Update die Lücke einfach füllen kann.'),
        ['disabled', 'grey', 'greyed', 'ausgegraut', 'deaktiviert', 'kombination'],
        ['dish-vs-recipe', 'request-recipe'],
    ),
    (
        'calorie-filter', 'profile', 'calorie-target',
        ('My calorie target hides too much. What do I do?',
         'Mein Kalorienziel blendet zu viel aus. Was tun?'),
        ('The target is a hard filter with a tolerance band around it, so recipes far '
         'above or below drop out. Two fixes: widen the tolerance in Settings, or use '
         'the per-dish override switch on any dish page to see every version of that '
         'one dish regardless of calories. The override is remembered per dish, not '
         'globally.',
         'Das Ziel ist ein harter Filter mit einem Toleranzband; Rezepte weit darüber '
         'oder darunter fallen heraus. Zwei Wege: die Toleranz in den Einstellungen '
         'erweitern, oder auf einer Gerichtseite den Schalter „Kalorienziel ignorieren“ '
         'nutzen, um alle Versionen dieses einen Gerichts zu sehen. Der Schalter gilt '
         'pro Gericht, nicht global.'),
        ['calories', 'kalorien', 'target', 'ziel', 'tolerance', 'toleranz'],
        ['why-fewer-recipes', 'time-budget'],
    ),
    (
        'time-budget', 'profile', 'time-budget',
        ('What does the time budget actually filter?',
         'Was filtert das Zeitbudget genau?'),
        ('Total time from the first step to the last, including resting and marinating. '
         'A lasagne that simmers for two hours counts as two-plus hours even though '
         'you are not standing over it. If that feels wrong for you, raise the budget '
         'and use the effort dimension instead — effort describes attention, time '
         'describes the clock.',
         'Die Gesamtzeit vom ersten bis zum letzten Schritt, inklusive Ruhen und '
         'Marinieren. Eine Lasagne, die zwei Stunden schmort, zählt als über zwei '
         'Stunden, auch wenn du nicht danebenstehst. Falls das für dich nicht passt: '
         'Budget erhöhen und stattdessen die Dimension „Aufwand“ nutzen — Aufwand '
         'beschreibt Aufmerksamkeit, Zeit beschreibt die Uhr.'),
        ['time', 'zeit', 'minutes', 'minuten', 'budget', 'effort', 'aufwand'],
        ['calorie-filter', 'effort-levels'],
    ),
    (
        'effort-levels', 'profile', 'effort',
        ('What do easy, medium and involved mean?',
         'Was bedeuten einfach, mittel und aufwendig?'),
        ('Easy: one pan, few decisions, safe when you are tired. Medium: real cooking, '
         'still a weeknight. Involved: you chose this on purpose and you have the '
         'afternoon. Effort is about attention, not skill — nothing here is gatekept '
         'behind technique.',
         'Einfach: eine Pfanne, wenige Entscheidungen, sicher, wenn du müde bist. '
         'Mittel: richtig kochen, trotzdem werktags machbar. Aufwendig: bewusst '
         'gewählt, mit einem freien Nachmittag. Aufwand meint Aufmerksamkeit, nicht '
         'Können — hier ist nichts hinter Technik verschlossen.'),
        ['effort', 'aufwand', 'easy', 'einfach', 'hard', 'schwer'],
        ['time-budget'],
    ),
    (
        'class-vs-specific', 'profile', 'avoidance',
        ('Class avoidance versus specific avoidance — which do I use?',
         'Klassen- oder Einzelvermeidung — was nehme ich?'),
        ('Class avoidance is a checkbox for a whole group: all dairy, all tree nuts, '
         'all shellfish. Specific avoidance is a typeahead for one thing: apples, '
         'coriander, bell peppers. Use classes for allergies and diets, specifics for '
         'dislikes. Both apply at once, and choosing a parent ingredient automatically '
         'covers everything under it — avoid "cheese" and parmesan, feta and mozzarella '
         'all go with it.',
         'Die Klassenvermeidung ist ein Häkchen für eine ganze Gruppe: alle '
         'Milchprodukte, alle Schalenfrüchte, alle Krebstiere. Die Einzelvermeidung ist '
         'eine Suche nach einer Sache: Äpfel, Koriander, Paprika. Klassen für Allergien '
         'und Ernährungsformen, Einzelnes für Abneigungen. Beides gilt gleichzeitig, '
         'und wer eine übergeordnete Zutat wählt, schließt automatisch alles darunter '
         'aus — „Käse“ nimmt Parmesan, Feta und Mozzarella gleich mit.'),
        ['allergy', 'allergie', 'avoid', 'vermeiden', 'ingredient', 'zutat'],
        ['why-fewer-recipes', 'halal-kosher'],
    ),
    (
        'halal-kosher', 'profile', 'halal-kosher',
        ('Are the halal and kosher recipes certified?',
         'Sind die Halal- und Koscher-Rezepte zertifiziert?'),
        ('No, and we will never say they are. MorphCook filters ingredients: a '
         'halal-compatible recipe contains no pork, no alcohol and no non-halal '
         'gelatin. Certification depends on sourcing, slaughter and supervision — '
         'facts about a supply chain, not about a recipe text. Only your supplier can '
         'tell you that.',
         'Nein, und wir werden das nie behaupten. MorphCook filtert Zutaten: ein '
         'halal-kompatibles Rezept enthält kein Schweinefleisch, keinen Alkohol und '
         'keine Nicht-Halal-Gelatine. Zertifizierung hängt an Herkunft, Schlachtung und '
         'Aufsicht — Tatsachen über eine Lieferkette, nicht über einen Rezepttext. Das '
         'kann dir nur dein Händler sagen.'),
        ['halal', 'kosher', 'koscher', 'certified', 'zertifiziert', 'religion'],
        ['class-vs-specific'],
    ),
    (
        'save-variant', 'features', 'cookbook',
        ('Why does my cookbook save a variant and not the dish?',
         'Warum speichert mein Kochbuch eine Variante und nicht das Gericht?'),
        ('Because you save your Döner, not the idea of Döner. If your profile changes '
         'later, the saved recipe stays exactly as you saved it. You can save several '
         'variants of the same dish side by side — useful when you cook for other '
         'people too.',
         'Weil du deinen Döner speicherst, nicht die Idee von Döner. Ändert sich dein '
         'Profil später, bleibt das gespeicherte Rezept genau so, wie du es gespeichert '
         'hast. Du kannst mehrere Varianten desselben Gerichts nebeneinander speichern '
         '— praktisch, wenn du auch für andere kochst.'),
        ['saved', 'cookbook', 'kochbuch', 'gespeichert', 'bookmark'],
        ['dish-vs-recipe'],
    ),
    (
        'shopping-aggregation', 'features', 'shopping-list',
        ('How does the shopping list add things up?',
         'Wie rechnet die Einkaufsliste zusammen?'),
        ('It merges the same ingredient across recipes when the units are compatible: '
         '2 cloves of garlic plus 3 cloves becomes 5 cloves; 15 ml plus 1 tbsp becomes '
         '30 ml. Grams and millilitres are never mixed, because that conversion depends '
         'on the ingredient. Anything it cannot merge is listed separately rather than '
         'guessed at, and everything is grouped by supermarket aisle.',
         'Sie fasst dieselbe Zutat über Rezepte hinweg zusammen, wenn die Einheiten '
         'kompatibel sind: 2 Zehen Knoblauch plus 3 Zehen ergeben 5 Zehen; 15 ml plus '
         '1 EL ergeben 30 ml. Gramm und Milliliter werden nie vermischt, weil diese '
         'Umrechnung von der Zutat abhängt. Was sich nicht zusammenfassen lässt, steht '
         'einzeln da statt geraten zu werden, und alles ist nach Supermarktgang '
         'gruppiert.'),
        ['shopping', 'einkauf', 'list', 'liste', 'units', 'einheiten', 'aggregation'],
        ['shopping-insights', 'meal-plan-export'],
    ),
    (
        'shopping-insights', 'features', 'insights',
        ('What is the variety score in Shopping Insights?',
         'Was ist der Vielfalts-Score in den Einkaufs-Insights?'),
        ('It counts how many distinct ingredients have passed through your shopping '
         'list. A high score means you are cooking across a wide range; a low one '
         'means you are repeating a small set. It is descriptive, not a grade — a low '
         'score during a hard month is a perfectly reasonable way to eat.',
         'Er zählt, wie viele verschiedene Zutaten durch deine Einkaufsliste gelaufen '
         'sind. Ein hoher Wert heißt, dass du breit kochst; ein niedriger, dass du eine '
         'kleine Auswahl wiederholst. Das ist eine Beschreibung, keine Note — ein '
         'niedriger Wert in einem harten Monat ist eine völlig vernünftige Art zu essen.'),
        ['insights', 'variety', 'vielfalt', 'analytics', 'statistik', 'score'],
        ['shopping-aggregation'],
    ),
    (
        'meal-plan-export', 'features', 'meal-plan',
        ('How do I get my week into the shopping list?',
         'Wie bekomme ich meine Woche in die Einkaufsliste?'),
        ('Open the meal plan and use "Send week to shopping list". Every recipe in the '
         'visible week is added and aggregated in one pass. Slots you left empty are '
         'skipped, and adding the same week twice will not double your quantities — '
         'the list de-duplicates by recipe.',
         'Öffne den Wochenplan und tippe auf „Woche zur Einkaufsliste“. Alle Rezepte '
         'der sichtbaren Woche werden in einem Durchgang hinzugefügt und '
         'zusammengefasst. Leere Slots werden übersprungen, und dieselbe Woche zweimal '
         'hinzuzufügen verdoppelt nichts — die Liste entdoppelt nach Rezept.'),
        ['meal plan', 'wochenplan', 'export', 'week', 'woche'],
        ['shopping-aggregation'],
    ),
    (
        'cook-mode-timers', 'features', 'cook-mode',
        ('Do the timers in cook mode keep running?',
         'Laufen die Timer im Kochmodus weiter?'),
        ('Yes, while the app is open. Your position in the recipe is saved as you go, '
         'so if you close the app mid-cook you can pick up at the same step with the '
         'same servings scale. There is no background notification — that would need '
         'permissions MorphCook does not ask for.',
         'Ja, solange die App offen ist. Deine Position im Rezept wird laufend '
         'gespeichert; schließt du die App mitten im Kochen, machst du beim selben '
         'Schritt mit derselben Portionsanzahl weiter. Es gibt keine '
         'Hintergrundbenachrichtigung — dafür bräuchte MorphCook Berechtigungen, die '
         'es nicht anfragt.'),
        ['timer', 'cook mode', 'kochmodus', 'pause', 'resume', 'fortsetzen'],
        ['visual-alerts', 'quick-tap'],
    ),
    (
        'visual-alerts', 'features', 'visual-alert',
        ('Can I get a visual signal instead of a sound?',
         'Kann ich ein visuelles Signal statt eines Tons bekommen?'),
        ('Yes. Turn on visual alerts in Settings and a finished timer flashes the '
         'whole screen in coral and teal instead of relying on audio. If you also have '
         'reduced motion enabled, the flash becomes a single steady colour hold rather '
         'than a pulse.',
         'Ja. Aktiviere visuelle Signale in den Einstellungen — ein abgelaufener Timer '
         'lässt dann den ganzen Bildschirm in Korall und Petrol blitzen, statt sich auf '
         'Ton zu verlassen. Ist zusätzlich „Bewegung reduzieren“ aktiv, wird daraus ein '
         'einzelnes ruhiges Halten der Farbe statt eines Pulsierens.'),
        ['deaf', 'gehörlos', 'accessibility', 'barrierefrei', 'flash', 'blitz', 'alert'],
        ['cook-mode-timers', 'reduce-motion'],
    ),
    (
        'quick-tap', 'features', 'quick-tap',
        ('What is quick-tap advance?',
         'Was ist Weitertippen mit einem Tipp?'),
        ('An opt-in gesture for cooking with one hand: a single tap anywhere on the '
         'step content moves to the next step, with a short haptic tick. It debounces '
         'for 300 ms so a slip does not skip two steps, and it respects reduced motion. '
         'It is off by default because accidental advances during cooking are worse '
         'than an extra button press.',
         'Eine optionale Geste zum einhändigen Kochen: ein einzelner Tipp irgendwo auf '
         'den Schritt springt zum nächsten, mit kurzem haptischem Feedback. 300 ms '
         'Entprellung verhindern, dass ein Verrutschen zwei Schritte überspringt, und '
         'die Geste respektiert „Bewegung reduzieren“. Standardmäßig aus, weil '
         'versehentliches Weiterspringen beim Kochen schlimmer ist als ein Tastendruck '
         'mehr.'),
        ['gesture', 'geste', 'one hand', 'einhändig', 'tap', 'tippen'],
        ['cook-mode-timers', 'visual-alerts'],
    ),
    (
        'reduce-motion', 'features', 'reduce-motion',
        ('What does reduce motion change?',
         'Was ändert „Bewegung reduzieren“?'),
        ('It shortens or removes the morph animation when you switch variants, the '
         'flash pulse on timer completion, and page transitions. Left unset, MorphCook '
         'follows your operating system setting; set it explicitly to override that '
         'either way.',
         'Es verkürzt oder entfernt die Morph-Animation beim Variantenwechsel, das '
         'Pulsieren beim Timer-Ende und die Seitenübergänge. Ohne eigene Auswahl folgt '
         'MorphCook der Systemeinstellung; setze es explizit, um sie in beide '
         'Richtungen zu überstimmen.'),
        ['motion', 'bewegung', 'animation', 'accessibility', 'barrierefrei'],
        ['visual-alerts'],
    ),
    (
        'ingredient-guide', 'features', 'ingredient-guide',
        ('What is the "Learn more" button next to an ingredient?',
         'Was ist der Knopf „Mehr erfahren“ neben einer Zutat?'),
        ('A short kitchen reference for ingredients that are easy to get wrong: what '
         'it is, what to do with it, how to store it, and where in a shop to find it. '
         'It exists for the unfamiliar ones — you will not find an entry for salt.',
         'Eine kurze Küchenreferenz für Zutaten, bei denen man leicht danebenliegt: was '
         'es ist, was man damit macht, wie man es lagert und wo im Laden man es findet. '
         'Sie gibt es für die ungewohnten — zu Salz wirst du keinen Eintrag finden.'),
        ['ingredient', 'zutat', 'guide', 'learn', 'lernen', 'storage', 'lagerung'],
        ['shopping-aggregation'],
    ),
    (
        'offline', 'data', 'offline',
        ('Does MorphCook work without internet?',
         'Funktioniert MorphCook ohne Internet?'),
        ('Always. The whole recipe corpus ships inside the app and nothing is fetched '
         'at runtime. There is no account, no sync and no telemetry — the app makes no '
         'network requests at all. New recipes arrive with app updates from the store.',
         'Immer. Der gesamte Rezeptbestand steckt in der App, zur Laufzeit wird nichts '
         'nachgeladen. Es gibt kein Konto, keine Synchronisierung und keine Telemetrie — '
         'die App stellt überhaupt keine Netzwerkanfragen. Neue Rezepte kommen mit '
         'App-Updates aus dem Store.'),
        ['offline', 'internet', 'network', 'netzwerk', 'privacy', 'datenschutz'],
        ['backup-formats', 'request-recipe'],
    ),
    (
        'backup-formats', 'data', 'backup',
        ('Why does export create two files?',
         'Warum erzeugt der Export zwei Dateien?'),
        ('One readable and one small. `morphcook-backup.json` is plain text you can '
         'open and inspect; `morphcook-backup.json.gz` is the same data compressed, '
         'usually 70–90 % smaller, which is the one to send to yourself. Import accepts '
         'either and detects the format automatically.',
         'Eine lesbare und eine kleine. `morphcook-backup.json` ist Klartext, den du '
         'öffnen und prüfen kannst; `morphcook-backup.json.gz` sind dieselben Daten '
         'komprimiert, meist 70–90 % kleiner — die zum Verschicken. Der Import nimmt '
         'beide an und erkennt das Format automatisch.'),
        ['backup', 'export', 'import', 'gzip', 'sicherung', 'datei'],
        ['backup-password', 'offline'],
    ),
    (
        'backup-password', 'data', 'backup-password',
        ('What happens if I set a backup password?',
         'Was passiert, wenn ich ein Backup-Passwort setze?'),
        ('The JSON file is encrypted with AES-256-GCM, using a key derived from your '
         'password with PBKDF2 (10 000 iterations, SHA-256) and a fresh salt each time. '
         'The `.gz` file stays unencrypted so it remains readable by anything. There is '
         'no recovery: the password exists only in your head, and a lost password means '
         'a lost backup.',
         'Die JSON-Datei wird mit AES-256-GCM verschlüsselt; der Schlüssel wird per '
         'PBKDF2 (10 000 Iterationen, SHA-256) mit jedes Mal frischem Salt aus deinem '
         'Passwort abgeleitet. Die `.gz`-Datei bleibt unverschlüsselt und damit '
         'universell lesbar. Es gibt keine Wiederherstellung: Das Passwort existiert nur '
         'in deinem Kopf, und ein verlorenes Passwort heißt ein verlorenes Backup.'),
        ['password', 'passwort', 'encryption', 'verschlüsselung', 'aes', 'security'],
        ['backup-formats', 'import-failed'],
    ),
    (
        'import-failed', 'trouble', 'import-error',
        ('My import failed. What do the messages mean?',
         'Mein Import ist fehlgeschlagen. Was bedeuten die Meldungen?'),
        ('"Incorrect password" means the file decrypted to nonsense — the data is fine, '
         'the key is wrong. "Backup file is corrupted" means the authentication tag did '
         'not match, so the bytes changed in transit. "Not a valid MorphCook backup" '
         'means the file is not one of ours at all. In every case the bundled recipes '
         'and your current data are untouched — a failed import never overwrites '
         'anything.',
         '„Falsches Passwort“ heißt, die Datei wurde zu Unsinn entschlüsselt — die Daten '
         'sind in Ordnung, der Schlüssel nicht. „Backup-Datei beschädigt“ heißt, das '
         'Authentifizierungs-Tag passte nicht, die Bytes haben sich unterwegs geändert. '
         '„Keine gültige MorphCook-Sicherung“ heißt, die Datei ist gar keine von uns. In '
         'allen Fällen bleiben die mitgelieferten Rezepte und deine aktuellen Daten '
         'unangetastet — ein fehlgeschlagener Import überschreibt nie etwas.'),
        ['import', 'error', 'fehler', 'failed', 'password', 'corrupt', 'beschädigt'],
        ['backup-password', 'merge-replace'],
    ),
    (
        'merge-replace', 'data', 'merge-replace',
        ('Merge or replace on import?',
         'Beim Import zusammenführen oder ersetzen?'),
        ('Merge keeps what you already have and adds anything new from the file — safe '
         'when you are pulling in a second device. Replace wipes your saved recipes, '
         'plan and history first, so the result matches the file exactly — right when '
         'you are restoring after a reinstall. Neither ever touches the bundled recipe '
         'corpus.',
         'Zusammenführen behält, was du hast, und ergänzt Neues aus der Datei — sicher, '
         'wenn du ein zweites Gerät dazunimmst. Ersetzen löscht zuerst gespeicherte '
         'Rezepte, Plan und Verlauf, sodass das Ergebnis exakt der Datei entspricht — '
         'richtig nach einer Neuinstallation. Beides rührt den mitgelieferten '
         'Rezeptbestand nie an.'),
        ['merge', 'replace', 'ersetzen', 'zusammenführen', 'restore', 'wiederherstellen'],
        ['import-failed', 'backup-formats'],
    ),
    (
        'request-recipe', 'trouble', 'content-request',
        ('The dish I want does not exist. Can I request it?',
         'Das Gericht, das ich suche, gibt es nicht. Kann ich es vorschlagen?'),
        ('Indirectly, and privately. When a search returns nothing, MorphCook records '
         'the query on your device only. Those queries ride along in your backup file '
         'under `content_requests`, so if you ever choose to send us a backup they tell '
         'the corpus team what is missing. Nothing is uploaded on its own; you can '
         'clear the list in Settings at any time.',
         'Indirekt und privat. Wenn eine Suche nichts findet, merkt sich MorphCook die '
         'Anfrage ausschließlich auf deinem Gerät. Diese Anfragen reisen in deiner '
         'Sicherungsdatei unter `content_requests` mit; schickst du uns irgendwann eine '
         'Sicherung, sagen sie dem Rezept-Team, was fehlt. Von allein wird nichts '
         'hochgeladen; du kannst die Liste jederzeit in den Einstellungen löschen.'),
        ['request', 'wunsch', 'missing', 'fehlt', 'search', 'suche', 'content'],
        ['offline', 'unreachable-combos'],
    ),
    (
        'no-results', 'trouble', 'no-results',
        ('My search finds nothing at all.',
         'Meine Suche findet gar nichts.'),
        ('Two likely causes. Either the words genuinely are not in the corpus, or your '
         'profile filtered every match away — the results screen tells you which by '
         'showing how many matches were hidden. Tap "show anyway" there to see them '
         'without changing your profile.',
         'Zwei wahrscheinliche Gründe. Entweder kommen die Wörter im Bestand wirklich '
         'nicht vor, oder dein Profil hat alle Treffer weggefiltert — die '
         'Ergebnisseite sagt dir welches, indem sie anzeigt, wie viele Treffer '
         'ausgeblendet wurden. Tippe dort auf „trotzdem anzeigen“, um sie zu sehen, '
         'ohne dein Profil zu ändern.'),
        ['search', 'suche', 'empty', 'leer', 'results', 'ergebnisse'],
        ['why-fewer-recipes', 'request-recipe'],
    ),
    (
        'language-switch', 'profile', 'language',
        ('Can I switch language without losing anything?',
         'Kann ich die Sprache wechseln, ohne etwas zu verlieren?'),
        ('Yes. Every recipe carries both German and English text side by side, so the '
         'switch is instant and nothing is re-downloaded or lost. Your saved recipes, '
         'plan and shopping list are language-independent — they reference recipes, not '
         'translations.',
         'Ja. Jedes Rezept trägt deutschen und englischen Text nebeneinander, der '
         'Wechsel ist also sofort und nichts wird nachgeladen oder verworfen. '
         'Gespeicherte Rezepte, Plan und Einkaufsliste sind sprachunabhängig — sie '
         'verweisen auf Rezepte, nicht auf Übersetzungen.'),
        ['language', 'sprache', 'german', 'deutsch', 'english', 'englisch'],
        ['offline'],
    ),
]
