# Bilingual ingredient education and searchable contextual help.
GUIDE={}
for id,item in INGREDIENTS.items():
 GUIDE[id]={'name':item['name'],
 'description':L('A useful kitchen ingredient. Check the package for exact ingredients and allergens.','Eine nützliche Küchenzutat. Verpackung auf genaue Zutaten und Allergene prüfen.'),
 'usage':L('Measure the amount listed in your recipe. Taste and season as you go.','Die Menge im Rezept abmessen. Während der Zubereitung probieren und würzen.'),
 'storage':L('Follow the label. Keep fresh produce chilled and dry goods cool and dry.','Etikett beachten. Frisches Gemüse kühlen, trockene Vorräte kühl und trocken lagern.'),
 'find':L('Look in the '+AISLES[item['aisle']][0].lower()+' aisle.','Im Bereich '+AISLES[item['aisle']][1]+' suchen.')}
def G(id,description,usage,storage,find):
 GUIDE[id].update(dict(zip(('description','usage','storage','find'),[L(*v) for v in (description,usage,storage,find)])))
G('miso',('Fermented rice and soy paste with a deep savoury flavour. Our recipes use gluten-free rice miso.','Fermentierte Reis-Soja-Paste mit herzhaftem Geschmack. Unsere Rezepte nutzen glutenfreies Reis-Miso.'),('Whisk into warm broth after taking it off the boil.','Nach dem Aufkochen in warme Brühe rühren.'),('Refrigerate after opening, following the label.','Nach dem Öffnen gemäß Etikett kühlen.'),('Asian shops or the international aisle; check for wheat and barley.','Asialaden oder internationales Regal; auf Weizen und Gerste achten.'))
G('tahini',('A smooth sesame-seed paste. Contains sesame.','Glatte Sesampaste. Enthält Sesam.'),('Stir the jar first. Whisk with lemon and water for a dressing.','Zuerst im Glas rühren. Mit Zitrone und Wasser als Dressing verrühren.'),('Keep tightly closed according to the label.','Gut verschlossen nach Etikett lagern.'),('Middle Eastern shops or the nut-butter aisle.','Orientalische Läden oder Nussmusregal.'))
G('nutritional-yeast',('Inactive yeast flakes with a savoury, cheese-like flavour; different from baking yeast.','Inaktive Hefeflocken mit käseähnlichem Geschmack; anders als Backhefe.'),('Blend into sauces or sprinkle over warm dishes.','In Saucen mixen oder über warme Gerichte streuen.'),('Store sealed, cool and dry.','Verschlossen, kühl und trocken lagern.'),('Health-food shops or the vegan pantry aisle.','Bioläden oder veganes Vorratsregal.'))
G('tamarind',('A tangy fruit paste that gives Pad Thai its distinctive sourness.','Säuerliche Fruchtpaste für die typische Säure von Pad Thai.'),('Loosen with warm water. Choose unsweetened paste without added shellfish.','Mit warmem Wasser lockern. Ungesüßte Paste ohne Krebstiere wählen.'),('Refrigerate after opening according to the package.','Nach dem Öffnen nach Packungsangabe kühlen.'),('Asian grocery shops or the international-food aisle.','Asialäden oder internationales Lebensmittelregal.'))
G('oyster-mushrooms',('Tender mushrooms with broad caps and a lovely torn texture.','Zarte Pilze mit breiten Hüten und schöner gezupfter Struktur.'),('Tear rather than slice. Brown in a wide pan without crowding.','Zupfen statt schneiden. Mit Platz in großer Pfanne bräunen.'),('Refrigerate in a paper bag and use while fresh.','In Papiertüte kühlen und frisch verwenden.'),('Produce aisles, markets or Asian shops.','Gemüseregal, Markt oder Asialäden.'))
G('tofu',('Soybean curd; firm tofu holds its shape when fried.','Sojaquark; fester Tofu behält beim Braten seine Form.'),('Pat dry before frying for golden edges.','Vor dem Braten trocken tupfen für goldene Ränder.'),('Keep refrigerated; follow the label after opening.','Kühlen; nach Öffnen das Etikett beachten.'),('Chilled vegetarian aisles or Asian shops.','Vegetarisches Kühlregal oder Asialäden.'))
G('oats',('Certified gluten-free oats are used here. Ordinary oats may carry gluten traces.','Hier werden zertifizierte glutenfreie Haferflocken genutzt. Gewöhnliche können Glutenspuren enthalten.'),('Use flakes whole or grind into flour for pancakes.','Flocken ganz nutzen oder für Pancakes zu Mehl mahlen.'),('Keep sealed, cool and dry.','Verschlossen, kühl und trocken lagern.'),('Breakfast aisles; look for explicit gluten-free certification.','Frühstücksregal; auf Glutenfrei-Zertifizierung achten.'))
G('lentils',('Split red lentils soften quickly and gently thicken soups.','Rote Spaltlinsen werden schnell weich und binden Suppen.'),('Rinse first and simmer until completely soft.','Zuerst abspülen, dann vollständig weich köcheln.'),('Keep dry lentils sealed; refrigerate cooked lentils promptly.','Trockene Linsen verschlossen lagern; gegarte zügig kühlen.'),('Dried pulses, international aisles or health-food stores.','Hülsenfrüchte, internationales Regal oder Bioladen.'))
G('chia',('Tiny seeds that absorb liquid and thicken oats.','Kleine Samen, die Flüssigkeit aufnehmen und Oats binden.'),('Stir into plenty of liquid and allow time to hydrate.','In ausreichend Flüssigkeit rühren und quellen lassen.'),('Store sealed, cool and dry.','Verschlossen, kühl und trocken lagern.'),('Breakfast, baking or health-food aisles.','Frühstücks-, Back- oder Bioregal.'))
G('tamari',('Soy-based seasoning; our recipes require a gluten-free labelled product.','Sojawürzsauce; unsere Rezepte verlangen ausdrücklich glutenfreie Produkte.'),('Add a little first, then taste; it is salty.','Zuerst wenig zugeben und probieren; sie ist salzig.'),('Follow the label after opening.','Nach dem Öffnen Etikett beachten.'),('Asian grocery shops or the gluten-free aisle.','Asialaden oder glutenfreies Regal.'))

FAQS=[]
def F(id,category,en,de,answer_en,answer_de):
 FAQS.append({'id':id,'category':category,'question':L(en,de),'answer':L(answer_en,answer_de)})
F('matching','diet','How does my cookbook match my diet?','Wie passt mein Kochbuch zu meiner Ernährung?',
 'Every dish has complete separate recipes. Your diet, allergies, avoided ingredients, time budget and calorie range decide what appears. Avoiding an ingredient family excludes all its children.',
 'Jedes Gericht hat vollständige eigenständige Rezepte. Ernährung, Allergien, Zutatenvermeidung, Zeitbudget und Kalorienbereich bestimmen die Auswahl. Vermiedene Zutatenfamilien schließen alle Untergruppen aus.')
F('visibility','diet','Why can’t I see a recipe?','Warum sehe ich ein Rezept nicht?',
 'It may contain an avoided ingredient, take too long or fall outside your calorie range. Review My kitchen in Settings. Other calorie levels on a dish relaxes only calories. Saved recipes remain saved and show a compatibility note after profile changes.',
 'Es kann eine vermiedene Zutat enthalten, zu lange dauern oder außerhalb des Kalorienbereichs liegen. Prüfe Meine Küche in Einstellungen. Andere Kalorienbereiche lockert nur Kalorien. Gespeicherte Rezepte bleiben mit Kompatibilitätshinweis erhalten.')
F('variants','recipes','How do recipe choices work?','Wie funktionieren die Rezeptauswahlen?',
 'Tap a row for diet, effort or appetite. Each choice opens a complete recipe. Unavailable combinations stay visible with a note. Saving keeps your exact selected recipe.',
 'Tippe auf eine Zeile für Ernährung, Aufwand oder Appetit. Jede Auswahl öffnet ein vollständiges Rezept. Fehlende Kombinationen bleiben mit Hinweis sichtbar. Speichern behält das genaue ausgewählte Rezept.')
F('halal','diet','Are these halal- or kosher-certified?','Sind die Rezepte halal- oder koscher-zertifiziert?',
 'We describe halal-compatible or kosher-compatible ingredients. Certification depends on sourcing, slaughter and supervision. Choose appropriately sourced products and follow your requirements; recipe text cannot certify a meal.',
 'Wir beschreiben halal- oder koscher-kompatible Zutaten. Zertifizierung hängt von Herkunft, Schlachtung und Aufsicht ab. Wähle entsprechend bezogene Produkte und beachte deine Anforderungen; Rezepttext kann kein Gericht zertifizieren.')
F('shopping','shopping','How are shopping quantities combined?','Wie werden Einkaufsmengen kombiniert?',
 'Matching ingredients combine: 2 garlic cloves plus 3 become 5. Compatible liquids convert teaspoons and tablespoons to 5 ml and 15 ml. Grams and millilitres stay separate. Serving counts apply first; items group by aisle.',
 'Gleiche Zutaten werden addiert: 2 und 3 Knoblauchzehen ergeben 5. Flüssigkeiten rechnen TL und EL zu 5 ml und 15 ml um. Gramm und Milliliter bleiben getrennt. Portionen gelten zuerst; alles wird nach Bereichen gruppiert.')
F('planning','planning','How do I plan the week?','Wie plane ich die Woche?',
 'Tap a slot, choose a saved recipe or search. Hold and drag a filled slot to move it; two filled slots swap. The shopping button adds the week at your chosen servings. Adding it again adds those quantities again.',
 'Platz antippen und gespeichertes Rezept wählen oder suchen. Halten und ziehen verschiebt gefüllte Plätze; zwei gefüllte Plätze tauschen. Der Einkaufsbutton fügt die Woche mit gewählten Portionen hinzu. Erneutes Hinzufügen addiert erneut.')
F('backup','backup','Where do my backups go?','Wohin gehen Backups?',
 'Export opens the OS share sheet with JSON and GZip files. You choose where to save. A password encrypts JSON using AES-256-GCM. GZip always stays unencrypted; choose the encrypted file for private data. Nothing is uploaded.',
 'Export öffnet das Teilen-Menü mit JSON und GZip. Du wählst den Speicherort. Ein Passwort verschlüsselt JSON mit AES-256-GCM. GZip bleibt unverschlüsselt; für private Daten die verschlüsselte Datei wählen. Nichts wird hochgeladen.')
F('restore','backup','Can I merge a backup?','Kann ich ein Backup zusammenführen?',
 'Merge keeps your profile, unions saved recipes and deduplicates history. Current meal slots win conflicts. Identical shopping lines use the larger quantity. Replace restores everything from the backup. Validation happens before changes.',
 'Zusammenführen behält dein Profil, vereint gespeicherte Rezepte und dedupliziert Verlauf. Aktuelle Essensplätze haben Vorrang. Gleiche Einkaufszeilen nutzen die größere Menge. Ersetzen übernimmt das Backup. Vor Änderungen wird geprüft.')
F('timer','cooking','What if I leave cook mode?','Was passiert beim Verlassen des Kochmodus?',
 'Pause & save pauses the timer and keeps your place. Continue cooking appears on Home. A running timer uses a deadline so background time is retained; completed timer alerts appear when you return.',
 'Pause & speichern hält den Timer an und behält den Fortschritt. Weiterkochen erscheint auf der Startseite. Laufende Timer nutzen einen Endzeitpunkt und behalten Hintergrundzeit; Hinweise erscheinen bei Rückkehr.')
F('accessibility','cooking','Can I cook one-handed or without sound?','Kann ich einhändig oder ohne Ton kochen?',
 'Enable Tap the step to continue in Settings. Taps have a 300 ms debounce. Visual timer alerts are on by default. Reduced motion uses a steady alert and disables gesture haptics.',
 'Schritt antippen zum Weitergehen in Einstellungen aktivieren. Zwischen Tipps liegen mindestens 300 ms. Visuelle Timerhinweise sind an. Reduzierte Bewegung nutzt ruhige Hinweise und deaktiviert Gesten-Haptik.')
F('offline','help','Does this need internet?','Braucht die App Internet?',
 'Recipes, search, planning, shopping, fonts and help work offline. New collections arrive with app-store updates. There are no accounts, cloud services, telemetry or live AI.',
 'Rezepte, Suche, Planung, Einkauf, Schriften und Hilfe funktionieren offline. Neue Sammlungen kommen mit App-Store-Updates. Es gibt keine Konten, Cloud, Telemetrie oder Live-KI.')
F('calories','diet','How does the calorie range work?','Wie funktioniert der Kalorienbereich?',
 'Your target and tolerance form a hard per-meal range. Nutrition is estimated per serving from ingredients; brands and preparation vary. Other calorie levels on a dish shows recipes outside the range without changing your profile.',
 'Ziel und Toleranz bilden einen festen Bereich pro Mahlzeit. Nährwerte sind Schätzungen pro Portion anhand der Zutaten; Marken und Zubereitung variieren. Andere Kalorienbereiche zeigt Rezepte außerhalb, ohne dein Profil zu ändern.')
F('time','recipes','Does recipe time include chilling?','Enthält die Zeitangabe Kühlzeiten?',
 'Times estimate active preparation and cooking. Extra resting or overnight chilling is clearly stated in the method. Plan ahead for overnight oats.',
 'Zeitangaben schätzen aktive Zubereitung und Garen. Zusätzliche Ruhe- oder Kühlzeit steht klar in der Methode. Overnight Oats rechtzeitig vorbereiten.')
F('insights','shopping','What do Shopping Insights count?','Was zählt die Einkaufsübersicht?',
 'Variety counts unique ingredients ever added. Frequency counts recipe and manual additions. Monthly groups show when you added ingredients, not their natural harvest season. History stays on your device and in backups.',
 'Vielfalt zählt jemals hinzugefügte verschiedene Zutaten. Häufigkeit zählt Rezept- und manuelle Hinzufügungen. Monatsgruppen zeigen Einkaufszeiten, nicht Erntesaison. Verlauf bleibt auf Gerät und in Backups.')
F('missing','help','What if my dish is missing?','Was, wenn mein Wunschgericht fehlt?',
 'Searches without results become local recipe wishes. Review or delete them in Settings, or export in a backup to share with the recipe team. Nothing is sent automatically. Try a shorter search or fewer tags first.',
 'Suchen ohne Ergebnis werden lokale Rezeptwünsche. In Einstellungen ansehen oder löschen, oder im Backup mit dem Rezeptteam teilen. Nichts wird automatisch gesendet. Zuerst kürzer suchen oder weniger Tags nutzen.')
F('allergens','diet','Can I avoid a whole ingredient family?','Kann ich eine Zutatenfamilie vermeiden?',
 'Yes. Search for dairy, nuts or vegetables in your profile. Avoiding a parent excludes all descendants. Package labels and cross-contact depend on your purchased ingredients.',
 'Ja. Im Profil nach Milchprodukten, Nüssen oder Gemüse suchen. Übergeordnete Einträge schließen Untergruppen aus. Verpackungsangaben und Kreuzkontakt hängen von gekauften Zutaten ab.')
