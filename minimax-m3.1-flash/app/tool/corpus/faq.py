"""The Help Center entries and the ingredient reference."""

# id, category, question(en, de), answer(en, de), keywords, related ids
FAQS = [
    (
        "dietary-how-matching-works",
        "dietary",
        (
            "How does MorphCook decide what I can see?",
            "Wie entscheidet MorphCook, was ich sehe?",
        ),
        (
            "Every recipe carries flags for what it contains. Your profile carries "
            "flags for what you avoid. A recipe is visible when the two sets do "
            "not overlap, when it uses no ingredient you have singled out, when "
            "it carries the attributes you require, when it fits your time "
            "budget, and when it sits inside your calorie target.",
            "Jedes Rezept trägt Markierungen für das, was es enthält. Dein Profil "
            "trägt Markierungen für das, was du meidest. Ein Rezept ist sichtbar, "
            "wenn sich die beiden Mengen nicht überschneiden, wenn es keine "
            "einzelne Zutat verwendet, die du ausgeschlossen hast, wenn es die "
            "geforderten Eigenschaften trägt, in dein Zeitbudget passt und in "
            "deinem Kalorienziel liegt.",
        ),
        ["matching", "visibility", "flags", "regeln", "sichtbarkeit"],
        ["dietary-vegan-vs-vegetarian", "visibility-why-missing", "dietary-specific-avoidance"],
    ),
    (
        "dietary-vegan-vs-vegetarian",
        "dietary",
        (
            "What is the difference between vegan and vegetarian here?",
            "Was ist hier der Unterschied zwischen vegan und vegetarisch?",
        ),
        (
            "Vegetarian excludes meat, fish and shellfish. Vegan also excludes "
            "eggs, dairy, honey and animal gelatins. Both are shortcuts: "
            "choosing one expands into the individual ingredients it covers, and "
            "you can still avoid individual ingredients on top.",
            "Vegetarisch schließt Fleisch, Fisch und Schalentiere aus. Vegan "
            "schließt zusätzlich Eier, Milchprodukte, Honig und tierische "
            "Gelatinen aus. Beides sind Kurzwege: Wer eines auswählt, bekommt "
            "die einzelnen Zutaten dahinter aufgeklappt — einzelne Zutaten kannst "
            "du zusätzlich weiter ausschließen.",
        ),
        ["vegan", "vegetarian", "diet", "ernährung", "vegetarisch"],
        ["dietary-how-matching-works", "dietary-halal-kosher"],
    ),
    (
        "dietary-halal-kosher",
        "dietary",
        (
            "Does MorphCook certify anything as halal or kosher?",
            "Zertifiziert MorphCook etwas als halal oder koscher?",
        ),
        (
            "No — and it never will. Certification is a property of sourcing and "
            "supervision, not of a recipe text. MorphCook only tells you that a "
            "recipe uses halal-compatible ingredients.",
            "Nein — und wird es auch nie. Zertifizierung ist eine Eigenschaft der "
            "Beschaffung und der Aufsicht, nicht des Rezepts. MorphCook sagt dir "
            "nur, dass ein Rezept halal-kompatible Zutaten verwendet.",
        ),
        ["halal", "kosher", "certification", "zertifizierung"],
        ["dietary-how-matching-works"],
    ),
    (
        "dietary-specific-avoidance",
        "dietary",
        (
            "Can I avoid a single ingredient?",
            "Kann ich eine einzelne Zutat ausschließen?",
        ),
        (
            "Yes. Type into the ingredient field in settings. If you pick a "
            "parent — say, dairy — everything beneath it is excluded too: milk, "
            "cheese, butter, all of it.",
            "Ja. Tippe im Einstellungsmenü in das Zutatenfeld. Wählst du eine "
            "übergeordnete Zutat — etwa Milchprodukte — fällt alles darunter weg: "
            "Milch, Käse, Butter, alles.",
        ),
        ["ingredient", "allergy", "avoid", "zutat", "allergie", "milchprodukte"],
        ["dietary-how-matching-works", "visibility-why-missing"],
    ),
    (
        "visibility-why-missing",
        "visibility",
        (
            "Why can I not find a dish I know exists?",
            "Warum finde ich ein Gericht nicht, von dem ich weiß, dass es existiert?",
        ),
        (
            "The dish is almost certainly in the app — but every version of it "
            "sits outside your filters. Open it from search or from a cuisine "
            "section: the app will show you the version and explain which filter "
            "it breaks, and you can loosen that single dish with the override "
            "switch.",
            "Das Gericht ist mit ziemlicher Sicherheit in der App — aber jede "
            "Version davon liegt außerhalb deiner Filter. Öffne es aus der Suche "
            "oder aus einer Küchen-Sektion: die App zeigt dir die Version und "
            "erklärt, welchen Filter sie verletzt, und du kannst dieses eine "
            "Gericht mit dem Überschreiben-Schalter freigeben.",
        ),
        ["missing", "hidden", "not showing", "fehlt", "versteckt"],
        ["dietary-how-matching-works", "features-variant-switcher"],
    ),
    (
        "visibility-variant-disabled",
        "visibility",
        (
            "Why is a version greyed out?",
            "Warum ist eine Version ausgegraut?",
        ),
        (
            "Because no recipe has been written for that combination yet. "
            "MorphCook does not hide it — the disabled chip tells you exactly "
            "which pairing is missing. Writing that version is a matter of "
            "adding a recipe file, not of changing any code.",
            "Weil für diese Kombination noch kein Rezept geschrieben wurde. "
            "MorphCook versteckt sie nicht — die ausgegraute Marke nennt dir "
            "genau, welche Kombination fehlt. Diese Version zu schreiben heißt: "
            "eine Rezeptdatei ergänzen, nicht Code ändern.",
        ),
        ["disabled", "greyed out", "unavailable", "ausgegraut", "nicht verfügbar"],
        ["features-variant-switcher", "visibility-why-missing"],
    ),
    (
        "features-variant-switcher",
        "features",
        (
            "How do the version rows work?",
            "Wie funktionieren die Versions-Zeilen?",
        ),
        (
            "Each row is one axis — diet, effort, calorie level. A collapsed row "
            "shows only what you have selected. Tap it to reveal the "
            "alternatives. Switching one axis narrows the others; when a "
            "combination has no recipe, that option is shown disabled with a "
            "note rather than silently removed.",
            "Jede Zeile ist eine Achse — Ernährung, Aufwand, Kalorienniveau. Eine "
            "zugeklappte Zeile zeigt nur deine Auswahl. Tippe sie an, um die "
            "Alternativen zu sehen. Eine Achse einzugrenzen grenzt die anderen "
            "ein; gibt es für eine Kombination kein Rezept, wird sie ausgegraut "
            "mit einem Hinweis gezeigt statt stillschweigend entfernt.",
        ),
        ["switcher", "versions", "rows", "wechseln", "versionen"],
        ["visibility-variant-disabled", "features-saving-variants"],
    ),
    (
        "features-saving-variants",
        "features",
        (
            "Do I save the dish or the version?",
            "Speichere ich das Gericht oder die Version?",
        ),
        (
            "The version. You save your Döner, not Döner in general. Two people "
            "with different diets can each save their own version of the same "
            "dish, and neither sees the other's.",
            "Die Version. Du speicherst deinen Döner, nicht Döner allgemein. Zwei "
            "Menschen mit unterschiedlichen Ernährungsweisen können jede ihre "
            "eigene Version desselben Gerichts speichern — und keine sieht die "
            "der anderen.",
        ),
        ["save", "cookbook", "speichern", "kochbuch"],
        ["features-variant-switcher"],
    ),
    (
        "features-cook-mode",
        "features",
        (
            "What happens in cook mode?",
            "Was passiert im Kochmodus?",
        ),
        (
            "Cook mode is dark, full-bleed and step by step: a timer on the "
            "steps that need one, a scaler for the number of portions, and "
            "your progress is saved if you close the app. When a timer ends the "
            "screen flashes — you can turn that off in settings, and there is a "
            "single-tap shortcut for advancing a step when your hands are busy.",
            "Der Kochmodus ist dunkel, randlos und Schritt für Schritt: ein Timer "
            "bei den Schritten, die einen brauchen, ein Regler für die "
            "Anzahl der Portionen, und dein Fortschritt wird gespeichert, wenn "
            "du die App schließt. Endet ein Timer, blinkt der Bildschirm — das "
            "lässt sich in den Einstellungen abschalten, und es gibt einen "
            "Einzel-Tipp zum Überspringen eines Schritts, wenn die Hände "
            "beschäftigt sind.",
        ),
        ["cook mode", "timer", "step", "kochmodus", "timer", "schritt"],
        ["features-visual-alerts", "features-one-handed"],
    ),
    (
        "features-visual-alerts",
        "features",
        (
            "What is the flashing screen for?",
            "Wofür ist das blinkende Bildschirmfenster?",
        ),
        (
            "It is for people who cannot hear a timer finish — deaf and "
            "hard-of-hearing cooks, or anyone cooking in a loud room. The screen "
            "flashes coral and teal when a timer ends. You can switch it off, "
            "and if you have reduced motion switched on, it shows a calm banner "
            "instead of a flash.",
            "Es ist für Menschen, die ein Timerende nicht hören können — taub und "
            "schwerhörig kochende Menschen, oder alle in einer lauten Küche. Der "
            "Bildschirm blinkt korall und teal, wenn ein Timer endet. Du kannst "
            "es abschalten, und wenn du Bewegung reduziert hast, erscheint "
            "statt des Blinkens ein ruhiges Banner.",
        ),
        ["flash", "alert", "accessibility", "blinken", "barrierefrei", "taub"],
        ["features-cook-mode", "features-reduce-motion"],
    ),
    (
        "features-one-handed",
        "features",
        (
            "Can I skip a step with one tap?",
            "Kann ich einen Schritt mit einem Tipp überspringen?",
        ),
        (
            "Yes — switch on “tap to skip a step” in settings. A single tap on "
            "the step text moves to the next one, with a small vibration so you "
            "know it registered. A short debounce stops a double tap from "
            "skipping two steps.",
            "Ja — aktiviere „tippen, um einen schritt zu überspringen“ in den "
            "Einstellungen. Ein einzelner Tipp auf den Schritttext geht zum "
            "nächsten, mit einer kleinen Vibration als Bestätigung. Eine kurze "
            "Sperre verhindert, dass ein Doppeltipp zwei Schritte überspringt.",
        ),
        ["tap", "quick", "one handed", "tipp", "einhand", "schnell"],
        ["features-cook-mode", "features-reduce-motion"],
    ),
    (
        "features-reduce-motion",
        "features",
        (
            "What does reduce motion change?",
            "Was ändert „Bewegung reduzieren“?",
        ),
        (
            "Animations collapse to instant changes: the ingredient list swaps "
            "without a fade, the timer banner replaces the flash, and the step "
            "transition is immediate. The setting can follow your system "
            "preference or be pinned on.",
            "Animationen werden zu sofortigen Wechseln: die Zutatenliste tauscht "
            "sich ohne Überblendung, das Timer-Banner ersetzt das Blinken, und "
            "der Schrittwechsel ist unmittelbar. Die Einstellung kann deiner "
            "Systemeinstellung folgen oder fest eingestellt sein.",
        ),
        ["motion", "animation", "accessibility", "bewegung", "animation", "barrierefrei"],
        ["features-visual-alerts", "features-one-handed"],
    ),
    (
        "features-shopping-list",
        "features",
        (
            "How does the shopping list combine recipes?",
            "Wie fasst die Einkaufsliste Rezepte zusammen?",
        ),
        (
            "Ingredients with the same name are merged and their quantities "
            "added: two cloves of garlic plus three cloves makes five cloves. "
            "Where two recipes measure the same thing in compatible units — "
            "millilitres and tablespoons — the smaller one is converted and "
            "folded in. Anything that cannot be converted stays on its own line "
            "rather than being guessed at.",
            "Zutaten mit gleichem Namen werden zusammengefasst und ihre Mengen "
            "addiert: zwei Knoblauchzehen plus drei ergeben fünf Zehen. Messen "
            "zwei Rezepte dasselbe in verträglichen Einheiten — Milliliter und "
            "Esslöffel — wird die kleinere umgerechnet und mitgezählt. Was sich "
            "nicht umrechnen lässt, bleibt in einer eigenen Zeile, statt geraten "
            "zu werden.",
        ),
        ["shopping", "list", "aggregate", "einkaufsliste", "liste", "umrechnen"],
        ["features-meal-plan", "features-insights"],
    ),
    (
        "features-meal-plan",
        "features",
        (
            "Can I plan my week?",
            "Kann ich meine Woche planen?",
        ),
        (
            "Yes — the plan is a Monday-to-Sunday grid with breakfast, lunch and "
            "dinner. Tap a slot to assign a recipe, drag one slot onto another to "
            "move it, and send the whole week to the shopping list in one tap. "
            "There is no auto-planning and no nutrition maths; you decide.",
            "Ja — die Planung ist ein Raster von Montag bis Sonntag mit Frühstück, "
            "Mittag- und Abendessen. Tippe ein Feld an, um ein Rezept zuzuweisen, "
            "ziehe ein Feld auf ein anderes, um es zu verschieben, und schicke die "
            "ganze Woche mit einem Tipp auf die Einkaufsliste. Es gibt keine "
            "automatische Planung und keine Nährwertrechnung — du entscheidest.",
        ),
        ["plan", "week", "meal plan", "planung", "woche", "essensplan"],
        ["features-shopping-list"],
    ),
    (
        "features-insights",
        "features",
        (
            "What do the shopping insights show?",
            "Was zeigen die Einkaufsanalysen?",
        ),
        (
            "Three things: a variety score — how many distinct ingredients you "
            "reach for — the ingredients you use most often, and a month-by-month "
            "breakdown of what you cooked, so seasonal habits become visible.",
            "Drei Dinge: einen Vielfaltswert — wie viele verschiedene Zutaten du "
            "verwendest — die am häufigsten genutzten Zutaten und eine Aufschlüsselung "
            "nach Monaten dessen, was du gekocht hast, damit saisonale Gewohnheiten "
            "sichtbar werden.",
        ),
        ["insights", "analytics", "statistics", "analysen", "statistik"],
        ["features-shopping-list"],
    ),
    (
        "features-offline",
        "features",
        (
            "Does MorphCook need an internet connection?",
            "Braucht MorphCook eine Internetverbindung?",
        ),
        (
            "No. The whole cookbook ships inside the app. There is no account, no "
            "cloud and no tracking — your recipes and your preferences never "
            "leave the device unless you export them yourself.",
            "Nein. Das gesamte Kochbuch steckt in der App. Es gibt kein Konto, "
            "keine Cloud und kein Tracking — deine Rezepte und Einstellungen "
            "verlassen das Gerät nur, wenn du sie selbst exportierst.",
        ),
        ["offline", "privacy", "network", "offline", "privatsphäre", "netzwerk"],
        ["backup-export", "backup-import"],
    ),
    (
        "backup-export",
        "backup",
        (
            "How do I back up my data?",
            "Wie sichere ich meine Daten?",
        ),
        (
            "Open settings and choose export. Two files are written side by side: "
            "a readable JSON file and a compressed one that is roughly 70–90% "
            "smaller. Save whichever you prefer — or both. You can add a "
            "password, which encrypts the JSON file with AES-256-GCM.",
            "Öffne die Einstellungen und wähle Export. Es werden zwei Dateien "
            "nebeneinander geschrieben: eine lesbare JSON-Datei und eine "
            "komprimierte, die rund 70–90 % kleiner ist. Nimm, was dir lieber "
            "ist — oder beides. Du kannst ein Passwort setzen, das die "
            "JSON-Datei mit AES-256-GCM verschlüsselt.",
        ),
        ["backup", "export", "save", "sichern", "export", "teilen"],
        ["backup-import", "backup-password"],
    ),
    (
        "backup-import",
        "backup",
        (
            "How do I restore a backup?",
            "Wie stelle ich ein Backup wieder her?",
        ),
        (
            "In settings, choose restore and pick the file. MorphCook works out "
            "the format on its own — plain, compressed or encrypted. You then "
            "choose whether to merge the backup into your data or replace it. "
            "The bundled cookbook is never touched.",
            "In den Einstellungen „Backup einspielen“ wählen und die Datei "
            "auswählen. MorphCook erkennt das Format selbst — unkomprimiert, "
            "komprimiert oder verschlüsselt. Danach entscheidest du, ob du das "
            "Backup in deine Daten einfließt oder ersetzt. Das mitgelieferte "
            "Kochbuch wird nie angetastet.",
        ),
        ["restore", "import", "wiederherstellen", "einspielen"],
        ["backup-export", "backup-password"],
    ),
    (
        "backup-password",
        "backup",
        (
            "What happens if I forget my backup password?",
            "Was passiert, wenn ich mein Backup-Passwort vergesse?",
        ),
        (
            "The password protects the JSON file, and it cannot be recovered — "
            "that is the point of the encryption. The compressed file is never "
            "encrypted, so keep a copy of the .gz file if the profile data "
            "matters to you.",
            "Das Passwort schützt die JSON-Datei und kann nicht wiederhergestellt "
            "werden — genau das ist der Zweck der Verschlüsselung. Die komprimierte "
            "Datei wird nie verschlüsselt; behalte also eine Kopie der .gz-Datei, "
            "wenn dir die Profildaten wichtig sind.",
        ),
        ["password", "encrypt", "forgot", "passwort", "verschlüsselt", "vergessen"],
        ["backup-export", "backup-import"],
    ),
    (
        "troubleshooting-missing-dish",
        "troubleshooting",
        (
            "A dish is missing from search. What now?",
            "Ein Gericht fehlt in der Suche. Und nun?",
        ),
        (
            "Tell the app. If a search returns nothing, MorphCook writes the "
            "query down locally and offers to log it. Those requests travel "
            "inside your backup file, which tells the cookbook team exactly what "
            "people are looking for and cannot find.",
            "Sag es der App. Wenn eine Suche nichts findet, schreibt MorphCook die "
            "Anfrage lokal auf und bietet an, sie zu erfassen. Diese Anfragen "
            "reisen in deiner Backup-Datei mit — und sagen dem Kochbuch-Team "
            "genau, wonach Leute suchen und es nicht finden.",
        ),
        ["missing", "search", "content request", "fehlt", "suche", "wunsch"],
        ["visibility-why-missing", "backup-export"],
    ),
    (
        "troubleshooting-slow-search",
        "troubleshooting",
        (
            "Search feels slow. What can I do?",
            "Die Suche fühlt sich langsam an. Was kann ich tun?",
        ),
        (
            "Results are paginated — twenty at a time, prefetching ahead of your "
            "scroll — so a long list never blocks the interface. If the app has "
            "just been updated, the first search also has to load the extended "
            "part of the cookbook; after that it is instant.",
            "Die Ergebnisse sind seitenweise geladen — zwanzig auf einmal, mit "
            "Vorausladen vor deinem Scrollen — damit eine lange Liste die "
            "Oberfläche nie blockiert. Wurde die App gerade aktualisiert, muss "
            "die erste Suche zusätzlich den erweiterten Teil des Kochbuchs "
            "laden; danach geht es sofort.",
        ),
        ["slow", "performance", "lag", "langsam", "performance"],
        ["features-variant-switcher"],
    ),
]


# id, name(en, de), description(en, de), usage(en, de), storage(en, de), where(en, de)
GUIDE = [
    (
        "produce.garlic",
        ("Garlic", "Knoblauch"),
        (
            "A bulb of cloves that turns sweet when cooked and sharp when raw.",
            "Eine Knolle aus Zehen, die gekocht süß und roh scharf wird.",
        ),
        (
            "Slice thin for flavour without heat, or crush it for raw sauces. "
            "Cook it slowly in oil first to mellow it.",
            "Dünn schneiden für Aroma ohne Schärfe, zerdrücken für rohe Saucen. "
            "Langsam in Öf garen, um es abzumildern.",
        ),
        (
            "Keep in a cool, dry, ventilated place — never the fridge, which "
            "makes it sprout.",
            "Kühl, trocken und luftig lagern — nie in den Kühlschrank, sonst "
            "treibt er aus.",
        ),
        (
            "Any supermarket aisle, in the bulb section.",
            "In jeder Gemüseabteilung, bei den Zwiebeln.",
        ),
    ),
    (
        "pantry.tahini",
        ("Tahini", "Tahini"),
        (
            "A paste of ground sesame, thick, nutty and a little bitter.",
            "Eine Paste aus gemahlenem Sesam — dick, nussig und leicht bitter.",
        ),
        (
            "Whisk with lemon juice and cold water; it seizes before it loosens. "
            "Keep stirring and it turns pale and pourable.",
            "Mit Zitronensaft und kaltem Wasser anrühren; es wird erst dick, dann "
            "flüssig. Weiter rühren, bis es hell und gießfähig ist.",
        ),
        (
            "Store in the jar it came in. It separates, so stir before using.",
            "Im Originalglas aufbewahren. Es trennt sich — vor Gebrauch umrühren.",
        ),
        (
            "The international aisle, next to the nut butters.",
            "In der internationalen Abteilung, bei den Nussbuttern.",
        ),
    ),
    (
        "pantry.miso",
        ("Miso", "Miso"),
        (
            "A fermented soybean paste — salty, sweet and deeply savoury.",
            "Ein fermentierter Sojabohnen-Paste — salzig, süß und sehr aromatisch.",
        ),
        (
            "Never boil miso. Whisk it with a ladle of hot broth and stir it "
            "back in at the end, or it turns grainy and bitter.",
            "Miso nie kochen. Mit einer Schöpfkelle heißer Brühe anrühren und erst "
            "am Ende zurückgeben, sonst wird es körnig und bitter.",
        ),
        (
            "Keep refrigerated in a sealed container. It darkens over time but "
            "keeps for months.",
            "Kühl und verschlossen aufbewahren. Es dunkelt mit der Zeit nach, "
            "hält sich aber monatelang.",
        ),
        (
            "The international aisle, near the soy sauce.",
            "In der internationalen Abteilung, neben der Sojasauce.",
        ),
    ),
    (
        "produce.ginger",
        ("Ginger", "Ingwer"),
        (
            "A knobbly root that is sharp when raw and warmly sweet when cooked.",
            "Eine knollige Wurzel, roh scharf und gekocht warm-süß.",
        ),
        (
            "Grate the skin off with a microplane or use a spoon to scrape it. "
            "Grate the pale inner part for curries and stir-fries.",
            "Die Schale mit der Microplane abschaben oder mit einem Löffel. Den "
            "hellen inneren Teil für Currys und Pfannengerichte fein reiben.",
        ),
        (
            "Wrap loosely in paper and keep in the fridge, or freeze it in "
            "portions.",
            "Locker in Papier wickeln und in den Kühlschrank legen, oder in "
            "Portionen einfrieren.",
        ),
        (
            "The produce aisle, often next to the garlic.",
            "In der Gemüseabteilung, meist neben dem Knoblauch.",
        ),
    ),
    (
        "dairy.cheese.parmesan",
        ("Parmesan", "Parmesan"),
        (
            "A hard, aged cheese that shaves into flakes and melts into sauce.",
            "Ein harter, gereifter Käse, der sich in Flocken hobeln und in Saucen "
            "auflösen lässt.",
        ),
        (
            "Grate it finely for sauces — a coarse grate makes them grainy. "
            "Always take it off the heat before adding it, or it seizes.",
            "Fein reiben für Saucen — eine grobe Reibe macht sie körnig. Immer "
            "erst von der Platte nehmen, sonst gerinnt er.",
        ),
        (
            "Wrap in paper, not cling film, and refrigerate. It can be frozen "
            "grated in a sealed bag.",
            "In Papier, nicht in Folie wickeln und kühlen. Gerieben lässt es sich "
            "in einem verschlossenen Beutel einfrieren.",
        ),
        (
            "The cheese counter, next to the aged Italian cheeses.",
            "Die Käsetheke, bei den gereiften italienischen Käsen.",
        ),
    ),
    (
        "dairy.cream.heavy",
        ("Double cream", "Schlagsahne"),
        (
            "Thick cream with around 48% fat — the backbone of many sauces.",
            "Dicke Sahne mit rund 48 % Fett — das Rückgrat vieler Saucen.",
        ),
        (
            "Bring it to the boil to split it into butter and buttermilk if you "
            "need the solids.",
            "Zum Sieden bringen, wenn du die Feststoffe brauchst — dann trennt sie "
            "sich in Butter und Buttermilch.",
        ),
        (
            "Keep refrigerated in the carton and use within a week of opening.",
            "Gekühlt im Karton aufbewahren und innerhalb einer Woche verbrauchen.",
        ),
        (
            "The dairy aisle, next to the milk.",
            "In der Milchproduktabteilung, neben der Milch.",
        ),
    ),
    (
        "pantry.pasta",
        ("Pasta", "Nudeln"),
        (
            "Durum wheat pasta, sold dried — spaghetti, penne, rigatoni and more.",
            "Hartweizennudeln, getrocknet — Spaghetti, Penne, Rigatoni und mehr.",
        ),
        (
            "Salt the water heavily — it should taste like a mild broth. Save a "
            "cup of the water before draining; the starch is what turns oil "
            "and cheese into a sauce.",
            "Salze das Wasser kräftig — es sollte wie eine leichte Brühe "
            "schmecken. Hebe vor dem Abgießen eine Tasse Wasser auf; die Stärke "
            "daraus macht aus Öl und Käse eine Sauce.",
        ),
        (
            "Keep sealed and dry in the pantry, away from any heat.",
            "Verschlossen und trocken im Vorratsschrank lagern, fern von Wärme.",
        ),
        (
            "The pasta aisle, next to the rice.",
            "In der Nudelabteilung, neben dem Reis.",
        ),
    ),
    (
        "produce.mushroom",
        ("Mushrooms", "Pilze"),
        (
            "Fungi with almost no flavour of their own — they borrow whatever "
            "they are cooked with.",
            "Pilze, die fast keinen eigenen Geschmack haben — sie übernehmen den "
            "ihrer Umgebung.",
        ),
        (
            "Brown them in a hot pan without crowding it. Salt them at the end, "
            "or they release water and stew in their own juices.",
            "Bräune sie in einer heißen Pfanne, ohne sie zu überfüllen. Erst am "
            "Ende salzen, sonst geben sie Wasser ab und garen in ihrem Saft.",
        ),
        (
            "Keep in a paper bag in the fridge and use within three days.",
            "In einer Papiertüte in den Kühlschrank, drei Tage haltbar.",
        ),
        (
            "The produce aisle, usually near the greens.",
            "In der Gemüseabteilung, meist bei den Blattsalaten.",
        ),
    ),
    (
        "pantry.chickpeas",
        ("Chickpeas", "Kichererbsen"),
        (
            "A nutty pulse that holds its shape and takes on whatever spice you "
            "give it.",
            "Eine nussige Hülsenfrucht, die ihre Form behält und jedes Gewürz "
            "annimmt.",
        ),
        (
            "For falafel, blitz soaked chickpeas rather than tinned ones — the "
            "texture is completely different.",
            "Für Falafel eingeweichte statt Dosenkichererbsen zerkleinern — die "
            "Textur ist völlig anders.",
        ),
        (
            "Tinned: keep in the tin, covered, for up to five days once opened. "
            "Dried: keep airtight in a cool place.",
            "In der Dose: mit Flüssigkeit bedeckt bis zu fünf Tage. Getrocknet: "
            "luftdicht und kühl lagern.",
        ),
        (
            "The tinned goods aisle, or the pulses shelf.",
            "In der Konservenabteilung oder beim Trockenregal.",
        ),
    ),
    (
        "produce.cumin",
        ("Cumin", "Kreuzkümmel"),
        (
            "A warm, earthy seed that smells of cumin the moment it is toasted.",
            "Ein warmes, erdiges Saat, das beim Rösten sofort nach Kreuzkümmel riecht.",
        ),
        (
            "Toast the seeds whole in a dry pan for a minute, then grind them. "
            "Ground cumin goes stale within weeks, whole seeds keep for months.",
            "Die Samen eine Minute in einer trockenen Pfanne rösten, dann mörsern. "
            "Gemahlener Kreuzkümmel wird nach Wochen alt, ganze Samen halten "
            "Monate.",
        ),
        (
            "Whole seeds in an airtight jar. Ground cumin in a sealed container, "
            "used within a month.",
            "Ganze Samen im luftdichten Glas. Gemahlener Kreuzkümmel im "
            "verschlossenen Behälter, innerhalb eines Monats verbrauchen.",
        ),
        (
            "The spice aisle.",
            "In der Gewürzabteilung.",
        ),
    ),
    (
        "produce.lemon",
        ("Lemon", "Zitrone"),
        (
            "Sour, bright and the most useful thing in the kitchen.",
            "Sauer, hell und das nützlichste Ding in der Küche.",
        ),
        (
            "Zest the skin before you juice it — the skin holds the oils, the "
            "juice holds the acid. Roll the lemon on the board first and you get "
            "twice the juice.",
            "Die Schale abreiben, bevor du sie presst — die Schale trägt die Öle, "
            "der Saft die Säure. Rolle die Zitrone vorher auf dem Brett, dann "
            "bekommst du doppelt so viel Saft.",
        ),
        (
            "Kept at room temperature for a week, in the fridge for a month. "
            "Freeze the juice in an ice cube tray.",
            "Eine Woche bei Zimmertemperatur, einen Monat im Kühlschrank. Den Saft "
            "in einer Eiswürfelform einfrieren.",
        ),
        (
            "The produce aisle, next to the limes.",
            "In der Gemüseabteilung, bei den Limetten.",
        ),
    ),
    (
        "pantry.nut.cashew",
        ("Cashews", "Cashewkerne"),
        (
            "A creamy, buttery nut — the base of most dairy-free cream sauces.",
            "Eine cremige, buttrige Nuss — die Basis der meisten pflanzlichen "
            "Cremesaucen.",
        ),
        (
            "Soak them for two hours or overnight, then blend with fresh water "
            "for a smooth cream. Soaked cashews taste much less bitter.",
            "Zwei Stunden oder über Nacht einweichen, dann mit frischem Wasser "
            "zu einer glatten Creme mixen. Eingeweichte Cashews schmecken "
            "wesentlich weniger bitter.",
        ),
        (
            "Keep in an airtight jar in the fridge for up to two months.",
            "Luftdicht im Glas im Kühlschrank, bis zu zwei Monate.",
        ),
        (
            "The baking and nuts aisle.",
            "In der Backwaren- und Nussabteilung.",
        ),
    ),
    (
        "pantry.oil.olive",
        ("Olive oil", "Olivenöl"),
        (
            "A peppery, grassy oil — good raw, better for frying than most people "
            "think.",
            "Ein pfeffriges, grünes Öl — roh gut, zum Frittieren besser, als "
            "die meisten denken.",
        ),
        (
            "Use a green, peppery oil raw and a milder one for heat. Do not fry "
            "at smoking point — olive oil is meant to be used at lower "
            "temperatures.",
            "Nimm ein grünes, pfeffriges Öl roh und ein milderes für starke Hitze. "
            "Nicht am Rauchpunkt frittieren — Olivenöl will bei niedrigeren "
            "Temperaturen eingesetzt werden.",
        ),
        (
            "Store in a dark cupboard away from heat and light. It does not "
            "really go off, it just gets dull.",
            "Dunkel und fern von Hitze und Licht lagern. Es verdirbt nicht "
            "wirklich, es wird nur geschmacklos.",
        ),
        (
            "The oil aisle, next to the sunflower oil.",
            "In der Ölabteilung, neben dem Sonnenblumenöl.",
        ),
    ),
    (
        "produce.pomegranate",
        ("Pomegranate", "Granatapfel"),
        (
            "A jewel of a fruit — sharp ruby seeds inside a tough, inedible skin.",
            "Eine Schatztruhe: scharfe rubinrote Kerne in einer zähen, ungenießbaren "
            "Schale.",
        ),
        (
            "Cut the fruit open and prize the seeds out with a spoon. Tap the "
            "shell with the back of a spoon to release them.",
            "Schneide die Frucht auf und löse die Kerne mit einem Löffel heraus. "
            "Klopfe gegen die Schale, damit sie herausfallen.",
        ),
        (
            "Whole, in the fridge, for a month. Once seeded, use within three days.",
            "Ganz im Kühlschrank einen Monat. Gekerbt innerhalb von drei Tagen "
            "verbrauchen.",
        ),
        (
            "The produce aisle, near the citrus.",
            "In der Gemüseabteilung, bei den Zitrusfrüchten.",
        ),
    ),
    (
        "produce.cabbage.red",
        ("Red cabbage", "Rotkohl"),
        (
            "A dense, purple cabbage that stays crunchy and turns sweet when "
            "slow-cooked.",
            "Ein dichter, violetter Kohl, der knackig bleibt und beim Langsamkochen "
            "süß wird.",
        ),
        (
            "Shred it as finely as you can for slaw. Salt it and leave it ten "
            "minutes to soften before dressing.",
            "Hauchdünn hobeln für Krautsalat. Salzen und zehn Minuten stehen "
            "lassen, damit er weich wird, bevor du anmachst.",
        ),
        (
            "Keeps for weeks in the fridge. Cut side down, in a bag.",
            "Hält im Kühlschrank wochenlang. Schnittseite nach unten, in einen "
            "Beutel.",
        ),
        (
            "The produce aisle, with the cabbages and lettuces.",
            "In der Gemüseabteilung, bei Kohl und Salat.",
        ),
    ),
    (
        "pantry.tamari",
        ("Tamari", "Tamari"),
        (
            "A wheat-free soy sauce, richer and less salty than the regular one.",
            "Eine weizenfreie Sojasauce, kräftiger und weniger salzig als die "
            "gewöhnliche.",
        ),
        (
            "Use it wherever you want soy flavour without the gluten — the "
            "flavour is rounder and less salty, so use a little less.",
            "Nutze sie überall, wo du Sojageschmack ohne Gluten willst — der "
            "Geschmack ist runder und weniger salzig, also etwas weniger davon.",
        ),
        (
            "A sealed bottle keeps for a year in the pantry.",
            "Ein verschlossenes Glas hält sich ein Jahr im Vorratsschrank.",
        ),
        (
            "The international aisle, next to the soy sauce.",
            "In der internationalen Abteilung, neben der Sojasauce.",
        ),
    ),
    (
        "produce.kale",
        ("Kale", "Grünkohl"),
        (
            "A hardy green with a mild, sweet flavour that softens when cooked.",
            "Ein robustes Grün mit mildem, süßem Geschmack, der beim Garen weich wird.",
        ),
        (
            "Strip the leaves from the stem, tear them, and massage them with a "
            "little oil and salt for a minute to tenderise.",
            "Die Blätter vom Strunk zupfen, zerreißen und eine Minute mit etwas "
            "Öl und Salz massieren, damit sie zarter werden.",
        ),
        (
            "Keep in a bag in the fridge for a week, or blanch and freeze it.",
            "In einer Tüte im Kühlschrank eine Woche, oder blanchieren und "
            "einfrieren.",
        ),
        (
            "The produce aisle, next to the spinach.",
            "In der Gemüseabteilung, beim Spinat.",
        ),
    ),
    (
        "pantry.paprika",
        ("Paprika", "Paprikapulver"),
        (
            "A sweet, warm spice, from mild scarlet to smoky and deep red.",
            "Ein süßes, warmes Gewürz — von mildem Scharlach bis rauchig-dunkelrot.",
        ),
        (
            "Sweet paprika is for colour and warmth; smoked paprika is for depth. "
            "Fry it briefly in fat to bloom it before it goes in.",
            "Süße Paprika ist für Farbe und Wärme, geräucherte für Tiefe. Kurz in "
            "Fett anrösten, damit sich das Aroma öffnet.",
        ),
        (
            "Keep sealed and dark. It fades on the shelf rather than spoiling.",
            "Verschlossen und dunkel lagern. Es verblasst am Regal, verdirbt aber "
            "nicht.",
        ),
        (
            "The spice aisle.",
            "In der Gewürzabteilung.",
        ),
    ),
    (
        "pantry.stock",
        ("Stock", "Brühe"),
        (
            "A savoury liquid made from bones or vegetables — the base of soups "
            "and sauces.",
            "Ein aromatisches Liquid aus Knochen oder Gemüse — die Basis von Suppen "
            "und Saucen.",
        ),
        (
            "Reduce it by half if you need more body. Never let it boil hard "
            "after the first twenty minutes — a bare simmer keeps it clear.",
            "Auf die Hälfte einkochen, wenn du mehr Kraft brauchst. Nie hart kochen "
            "lassen — ein leichtes Köcheln hält sie klar.",
        ),
        (
            "Refrigerate for three days or freeze in portions for a month.",
            "Drei Tage im Kühlschrank oder portionsweise einen Monat einfrieren.",
        ),
        (
            "The soup and stock aisle, in cartons and cubes.",
            "In der Suppen- und Brühenabteilung, als Karton oder Würfel.",
        ),
    ),
    (
        "produce.avocado",
        ("Avocado", "Avocado"),
        (
            "A buttery fruit with a creamy flesh and a single large stone.",
            "Eine buttrige Frucht mit cremigem Fleisch und einem großen Kern.",
        ),
        (
            "Ripen on the counter until it yields to gentle pressure, then keep it "
            "in the fridge. Brush cut surfaces with lemon to slow the browning.",
            "An der Luft reifen lassen, bis es leicht nachgibt, dann in den "
            "Kühlschrank legen. Geschnittene Flächen mit Zitrone bestreichen, damit "
            "es nicht braun wird.",
        ),
        (
            "Whole: three days on the counter, a week in the fridge. Cut: two "
            "days, covered.",
            "Ganz: drei Tage an der Luft, eine Woche im Kühlschrank. Geschnitten: "
            "zwei Tage, abgedeckt.",
        ),
        (
            "The produce aisle, near the avocados and mangoes.",
            "In der Gemüseabteilung, bei Avocado und Mango.",
        ),
    ),
]
