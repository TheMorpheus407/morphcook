"""Extended partition — the long tail. Loaded on demand."""

from dsl import dish, variant, ing, step, Patch

DISHES = []

# ---------------------------------------------------------------------------
# Risotto
# ---------------------------------------------------------------------------
DISHES.append(dish(
    id='risotto',
    name=('Risotto', 'Risotto'),
    hero=('Twenty minutes of stirring in exchange for something you cannot buy.',
          'Zwanzig Minuten Rühren im Tausch gegen etwas, das man nicht kaufen kann.'),
    cap=('stand still and stir', 'stehen bleiben und rühren'),
    stripe='#C9B072',
    cuisines=['italian'],
    categories=['comfort', 'weekend'],
    partition='extended', secondary=['cuisine-italian'], tier=2,
    slots=['lunch', 'dinner'], servings=2,
    tags=['risotto', 'rice', 'reis', 'parmesan', 'stirring'],
    base_ing=[
        ing('arborio-rice', 200, 'g'),
        ing('stock-veg', 900, 'ml', 'kept at a simmer', 'köchelnd halten'),
        ing('shallot', 2, 'piece'),
        ing('white-wine', 120, 'ml'),
        ing('butter', 50, 'g', 'cold, cubed', 'kalt, gewürfelt'),
        ing('parmesan', 60, 'g'),
        ing('olive-oil', 2, 'tbsp'),
        ing('mushroom', 250, 'g'),
        ing('thyme', 5, 'g'),
        ing('salt', 1, 'tsp'),
        ing('pepper', 0.5, 'tsp'),
    ],
    base_steps=[
        step('Keep the stock at a bare simmer in a second pan. Cold stock stops the '
             'rice every time you add it.',
             'Die Brühe im zweiten Topf leicht köcheln lassen. Kalte Brühe stoppt den '
             'Reis bei jeder Zugabe.'),
        step('Brown the mushrooms hard in the oil with the thyme, then take them out '
             'and keep them.',
             'Die Pilze mit dem Thymian im Öl kräftig anbraten, herausnehmen und '
             'beiseitestellen.', 480),
        step('Soften the shallots in the same pan without colouring them, then add the '
             'rice and toast it until the grains turn glassy at the edges.',
             'Die Schalotten in derselben Pfanne ohne Farbe weich dünsten, dann den '
             'Reis zugeben und rösten, bis die Körner am Rand glasig werden.', 180),
        step('Wine in, stirred until it has completely gone.',
             'Wein angießen und rühren, bis er vollständig verschwunden ist.', 120),
        step('A ladle of stock at a time, stirring, waiting until the pan is nearly '
             'dry before the next. Eighteen minutes, roughly.',
             'Kelle für Kelle Brühe zugeben, rühren, warten, bis die Pfanne fast '
             'trocken ist. Etwa achtzehn Minuten.', 1080),
        step('Off the heat, beat in the cold butter and parmesan hard. This is the '
             'part that makes it risotto and not rice.',
             'Vom Herd nehmen und kalte Butter und Parmesan kräftig einschlagen. Das '
             'macht es zu Risotto und nicht zu Reis.', 60),
        step('Rest one minute, then loosen with a splash of stock so it spreads when '
             'it hits the plate.',
             'Eine Minute ruhen lassen, dann mit einem Schuss Brühe lockern, damit es '
             'auf dem Teller fließt.', 60),
    ],
    variants=[
        variant('classic', 'vegetarian',
                ('Mushroom Risotto', 'Pilzrisotto'),
                ('Cold butter beaten in off the heat. That is the whole texture.',
                 'Kalte Butter außerhalb der Hitze eingeschlagen. Das ist die ganze Textur.'),
                ('it should spread, not stand', 'es soll fließen, nicht stehen'),
                'medium', 40, 620, (18, 78, 24),
                attrs=['comfort'], tech=['simmer', 'sauté'], is_base=True),
        variant('vegan', 'vegan',
                ('Vegan Risotto', 'Veganes Risotto'),
                ('Miso and olive oil beaten in instead of butter and parmesan. The '
                 'gloss survives.',
                 'Miso und Olivenöl statt Butter und Parmesan eingeschlagen. Der Glanz '
                 'bleibt.'),
                ('miso is the umami you are missing', 'Miso ist das fehlende Umami'),
                'medium', 40, 540, (13, 80, 18),
                attrs=['comfort'], tech=['simmer', 'sauté'],
                patch=Patch(
                    swap={
                        'butter': ing('olive-oil', 3, 'tbsp', 'good, cold', 'gut, kalt'),
                        'parmesan': ing('nutritional-yeast', 3, 'tbsp'),
                    },
                    add=[ing('miso', 1, 'tbsp')],
                    steps={
                        5: step('Off the heat, beat in the cold olive oil, the miso and the '
                                'nutritional yeast hard until it turns glossy and thick.',
                                'Vom Herd nehmen und kaltes Olivenöl, Miso und Hefeflocken '
                                'kräftig einschlagen, bis es glänzend und dick wird.', 60),
                    },
                )),
        variant('alcohol-free', 'alcohol-free',
                ('Risotto without wine', 'Risotto ohne Wein'),
                ('Lemon juice and a splash of stock do the acid the wine was there for.',
                 'Zitronensaft und ein Schuss Brühe liefern die Säure, für die der Wein '
                 'da war.'),
                ('acid, not alcohol', 'Säure, nicht Alkohol'),
                'medium', 40, 610, (18, 78, 23),
                attrs=['comfort'], tech=['simmer', 'sauté'],
                patch=Patch(
                    swap={'white-wine': ing('lemon', 1, 'piece', 'juice, plus 100 ml stock',
                                            'Saft, plus 100 ml Brühe')},
                    steps={
                        3: step('Add the lemon juice with a ladle of stock and stir until the '
                                'pan is nearly dry. The sharpness lands in the same place the '
                                'wine did.',
                                'Zitronensaft mit einer Kelle Brühe zugeben und rühren, bis die '
                                'Pfanne fast trocken ist. Die Schärfe landet dort, wo sonst der '
                                'Wein war.', 120),
                    },
                )),
    ],
))

# ---------------------------------------------------------------------------
# Gyoza
# ---------------------------------------------------------------------------
DISHES.append(dish(
    id='gyoza',
    name=('Gyoza', 'Gyoza'),
    hero=('Fry, steam, fry again. Three heats in one pan, in that order.',
          'Braten, dämpfen, wieder braten. Drei Hitzen in einer Pfanne, in dieser Reihenfolge.'),
    cap=('crisp bottom, soft top', 'knuspriger Boden, weiche Haube'),
    stripe='#96A67D',
    cuisines=['japanese', 'asian'],
    categories=['handmade', 'weekend', 'sharing'],
    partition='extended', secondary=['cuisine-asian'], tier=2,
    slots=['lunch', 'dinner', 'snack'], servings=3,
    tags=['gyoza', 'dumplings', 'teigtaschen', 'potsticker', 'steam'],
    base_ing=[
        ing('flour', 250, 'g', 'for the wrappers', 'für die Teigblätter'),
        ing('pork-loin', 300, 'g', 'minced, 20 % fat', 'gehackt, 20 % Fett'),
        ing('white-cabbage', 200, 'g', 'finely chopped and salted',
            'fein gehackt und gesalzen'),
        ing('spring-onion', 4, 'piece'),
        ing('ginger', 20, 'g'),
        ing('garlic', 2, 'clove'),
        ing('soy-sauce', 2, 'tbsp'),
        ing('sesame-oil', 2, 'tsp'),
        ing('rapeseed-oil', 2, 'tbsp'),
        ing('rice-vinegar', 3, 'tbsp', 'for dipping', 'zum Dippen'),
        ing('chilli-flakes', 1, 'tsp', optional=True),
        ing('salt', 1, 'tsp'),
    ],
    base_steps=[
        step('Mix the flour with 130 ml just-boiled water, knead until smooth, wrap it '
             'and leave it to relax.',
             'Das Mehl mit 130 ml kochendem Wasser mischen, glatt kneten, einwickeln '
             'und entspannen lassen.', 1800),
        step('Salt the chopped cabbage, wait ten minutes, then squeeze it out hard in '
             'a cloth. Wet filling tears wrappers.',
             'Den gehackten Kohl salzen, zehn Minuten warten, dann in einem Tuch fest '
             'ausdrücken. Feuchte Füllung reißt den Teig.', 600),
        step('Mix the pork, squeezed cabbage, spring onion, grated ginger and garlic, '
             'soy sauce and sesame oil in one direction only until it turns sticky.',
             'Schwein, ausgedrückten Kohl, Frühlingszwiebeln, geriebenen Ingwer und '
             'Knoblauch, Sojasauce und Sesamöl nur in eine Richtung rühren, bis die '
             'Masse klebt.', 180),
        step('Roll the dough into a rope, cut coins, roll each into a thin round with '
             'a thicker middle.',
             'Den Teig zu einer Rolle formen, Taler abschneiden und jeden zu einem '
             'dünnen Kreis mit dickerer Mitte ausrollen.'),
        step('A teaspoon of filling per wrapper, edge wetted, pleated on one side '
             'only, pressed flat-bottomed so they stand.',
             'Ein Teelöffel Füllung pro Blatt, Rand befeuchten, nur eine Seite in '
             'Falten legen, Boden flach drücken, damit sie stehen.'),
        step('Fry them flat-side down in oil until the bottoms are deep gold.',
             'Mit der flachen Seite nach unten in Öl braten, bis die Böden '
             'dunkelgolden sind.', 180),
        step('Pour in 80 ml water, lid on immediately, and steam until the water is '
             'gone.',
             '80 ml Wasser angießen, sofort Deckel drauf und dämpfen, bis das Wasser '
             'verdampft ist.', 360),
        step('Lid off, let the bottoms crisp again for a minute, then turn them out '
             'crisp-side up with the vinegar alongside.',
             'Deckel ab, die Böden eine Minute nachknuspern lassen, dann mit der '
             'knusprigen Seite nach oben stürzen, Essig dazu.', 60),
    ],
    variants=[
        variant('classic', 'classic',
                ('Pork Gyoza', 'Schweine-Gyoza'),
                ('Cabbage salted and wrung out, filling stirred one way until it grips.',
                 'Kohl gesalzen und ausgewrungen, Füllung in eine Richtung gerührt, bis '
                 'sie greift.'),
                ('stir one way. it matters.', 'in eine Richtung rühren. das zählt.'),
                'hard', 90, 520, (26, 52, 22),
                attrs=['freezer-friendly', 'make-ahead'], tech=['pan-fry', 'steam'],
                tips=[('Freeze them raw on a tray, then bag them. Cook from frozen with '
                       'two extra minutes of steam.',
                       'Roh auf einem Blech einfrieren, dann in den Beutel. Gefroren mit '
                       'zwei Minuten mehr Dampfzeit garen.')],
                is_base=True),
        variant('vegan', 'vegan',
                ('Vegan Gyoza', 'Vegane Gyoza'),
                ('Mushroom and tofu, browned first so the filling is not watery.',
                 'Pilze und Tofu, vorher angebraten, damit die Füllung nicht wässert.'),
                ('brown the mushrooms first. always.', 'Pilze zuerst anbraten. immer.'),
                'hard', 90, 430, (18, 56, 14),
                attrs=['freezer-friendly', 'make-ahead'], tech=['pan-fry', 'steam'],
                patch=Patch(
                    swap={'pork-loin': ing('tofu', 250, 'g', 'pressed and crumbled',
                                           'gepresst und zerbröselt')},
                    add=[ing('shiitake', 150, 'g', 'chopped fine', 'fein gehackt'),
                         ing('miso', 1, 'tbsp')],
                    steps={
                        2: step('Brown the shiitake and crumbled tofu hard in a dry pan until '
                                'all their water is gone, then mix with the squeezed cabbage, '
                                'spring onion, ginger, garlic, miso, soy sauce and sesame oil.',
                                'Shiitake und zerbröselten Tofu in einer trockenen Pfanne '
                                'kräftig anbraten, bis alles Wasser weg ist, dann mit '
                                'ausgedrücktem Kohl, Frühlingszwiebeln, Ingwer, Knoblauch, '
                                'Miso, Sojasauce und Sesamöl mischen.', 600),
                    },
                )),
        variant('gluten-free', 'gluten-free',
                ('Gluten-free Gyoza', 'Glutenfreie Gyoza'),
                ('Rice paper instead of wheat wrappers. Different technique, same '
                 'crisp bottom.',
                 'Reispapier statt Weizenteig. Andere Technik, gleicher knuspriger Boden.'),
                ('work fast — rice paper waits for nobody',
                 'schnell arbeiten — Reispapier wartet nicht'),
                'hard', 70, 480, (24, 58, 16),
                attrs=['make-ahead'], tech=['pan-fry', 'steam'],
                patch=Patch(
                    swap={
                        'flour': ing('rice-paper', 24, 'piece', '16 cm rounds', '16-cm-Kreise'),
                        'soy-sauce': ing('tamari', 2, 'tbsp'),
                    },
                    steps={
                        0: step('No dough to make. Set out a shallow bowl of warm water and a '
                                'damp cloth to work on.',
                                'Kein Teig nötig. Eine flache Schale warmes Wasser und ein '
                                'feuchtes Tuch als Arbeitsfläche bereitstellen.'),
                        3: step('Dip a rice paper for two seconds only — it keeps softening on '
                                'the cloth. Use two stacked sheets per dumpling for strength.',
                                'Ein Reispapier nur zwei Sekunden eintauchen — es weicht auf dem '
                                'Tuch weiter auf. Für Stabilität zwei Blätter übereinander '
                                'verwenden.'),
                        4: step('A teaspoon of filling, fold into a parcel, press the base flat. '
                                'Keep them apart; rice paper welds to itself.',
                                'Ein Teelöffel Füllung, zu einem Päckchen falten, Boden flach '
                                'drücken. Auseinanderlegen; Reispapier verschweißt mit sich '
                                'selbst.'),
                    },
                )),
    ],
))

# ---------------------------------------------------------------------------
# Tacos
# ---------------------------------------------------------------------------
DISHES.append(dish(
    id='tacos',
    name=('Tacos', 'Tacos'),
    hero=('Warm the tortillas on a dry pan until they smell like popcorn. Non-negotiable.',
          'Die Tortillas in der trockenen Pfanne erwärmen, bis sie nach Popcorn riechen. Nicht verhandelbar.'),
    cap=('two tortillas per taco, always', 'immer zwei Tortillas pro Taco'),
    stripe='#B5762E',
    cuisines=['mexican'],
    categories=['handheld', 'weeknight', 'sharing'],
    partition='extended', secondary=[], tier=2,
    slots=['lunch', 'dinner'], servings=3,
    tags=['tacos', 'tortilla', 'lime', 'limette', 'salsa'],
    base_ing=[
        ing('corn-tortilla', 12, 'piece'),
        ing('chicken-thigh', 450, 'g'),
        ing('paprika-powder', 2, 'tsp'),
        ing('cumin', 2, 'tsp'),
        ing('oregano', 1, 'tsp'),
        ing('lime', 2, 'piece'),
        ing('red-onion', 1, 'piece'),
        ing('coriander-leaf', 30, 'g'),
        ing('tomato', 2, 'piece'),
        ing('chilli', 1, 'piece'),
        ing('avocado', 1, 'piece'),
        ing('rapeseed-oil', 2, 'tbsp'),
        ing('salt', 2, 'tsp'),
    ],
    base_steps=[
        step('Toss the chicken with the paprika, cumin, oregano, salt, oil and the '
             'juice of one lime.',
             'Das Hähnchen mit Paprikapulver, Kreuzkümmel, Oregano, Salz, Öl und dem '
             'Saft einer Limette mischen.', 900),
        step('Dice the tomato, chilli and half the onion, mix with chopped coriander, '
             'lime juice and salt. Let it sit and turn into salsa.',
             'Tomate, Chili und eine halbe Zwiebel würfeln, mit gehacktem Koriander, '
             'Limettensaft und Salz mischen. Ziehen lassen, bis es Salsa wird.', 600),
        step('Slice the rest of the onion thin and squeeze the second lime over it. It '
             'will go pink and lose its bite.',
             'Die restliche Zwiebel dünn schneiden und die zweite Limette darüber '
             'auspressen. Sie wird rosa und verliert die Schärfe.', 600),
        step('Sear the chicken hard in a very hot pan, undisturbed, until it is dark '
             'on one side, then finish and rest it before chopping.',
             'Das Hähnchen in einer sehr heißen Pfanne ungestört scharf anbraten, bis '
             'es auf einer Seite dunkel ist, fertig garen und vor dem Schneiden ruhen '
             'lassen.', 600),
        step('Warm the tortillas one at a time on a dry pan, ten seconds a side, and '
             'stack them under a cloth.',
             'Die Tortillas einzeln in einer trockenen Pfanne erwärmen, zehn Sekunden '
             'pro Seite, unter einem Tuch stapeln.', 240),
        step('Two tortillas per taco. Chicken, salsa, pickled onion, avocado, and a '
             'lime wedge you actually use.',
             'Zwei Tortillas pro Taco. Hähnchen, Salsa, eingelegte Zwiebel, Avocado '
             'und eine Limettenspalte, die du auch benutzt.'),
    ],
    variants=[
        variant('classic', 'gluten-free',
                ('Chicken Tacos', 'Hähnchen-Tacos'),
                ('Marinated thigh, quick pickled onion, salsa made an hour early.',
                 'Marinierte Schenkel, schnell eingelegte Zwiebel, Salsa eine Stunde '
                 'vorher gemacht.'),
                ('the pickled onion carries it', 'die eingelegte Zwiebel trägt alles'),
                'easy', 40, 560, (36, 48, 24),
                attrs=['high-protein'], tech=['pan-fry'], is_base=True),
        variant('vegan', 'vegan',
                ('Jackfruit Tacos', 'Jackfruit-Tacos'),
                ('Young jackfruit shreds like slow-cooked meat once you dry it out '
                 'properly first.',
                 'Junge Jackfrucht zerfasert wie geschmortes Fleisch — wenn man sie '
                 'vorher richtig trocken brät.'),
                ('dry-fry it first. do not skip that.',
                 'erst trocken anbraten. nicht überspringen.'),
                'easy', 40, 470, (11, 68, 18),
                attrs=['budget'], tech=['pan-fry'],
                patch=Patch(
                    swap={'chicken-thigh': ing('jackfruit', 500, 'g', 'tinned in brine, drained and shredded',
                                               'aus der Dose in Lake, abgetropft und zerfasert')},
                    add=[ing('black-beans', 240, 'g', 'drained', 'abgetropft')],
                    steps={
                        3: step('Dry-fry the shredded jackfruit in a hot pan until the moisture '
                                'has gone and the edges brown, then add the spices, oil, lime '
                                'and beans and fry two minutes more.',
                                'Die zerfaserte Jackfrucht in einer heißen Pfanne trocken '
                                'anbraten, bis die Feuchtigkeit weg ist und die Ränder bräunen, '
                                'dann Gewürze, Öl, Limette und Bohnen zugeben und zwei Minuten '
                                'weiterbraten.', 720),
                    },
                )),
        variant('pescatarian', 'pescatarian',
                ('Fish Tacos', 'Fisch-Tacos'),
                ('Cod cooked ninety seconds a side, still just flaking apart.',
                 'Kabeljau, 90 Sekunden pro Seite, gerade eben zerfallend.'),
                ('undercook it slightly. it carries on.',
                 'leicht untergaren. er gart nach.'),
                'medium', 35, 520, (34, 46, 20),
                attrs=['high-protein', 'light-meal'], tech=['pan-fry'],
                patch=Patch(
                    swap={'chicken-thigh': ing('cod', 450, 'g', 'thick loin, in 3 cm pieces',
                                               'dickes Rückenstück, in 3-cm-Stücke')},
                    add=[ing('white-cabbage', 150, 'g', 'shredded fine', 'fein gehobelt'),
                         ing('mayonnaise', 2, 'tbsp')],
                    steps={
                        3: step('Sear the cod pieces ninety seconds a side in a very hot pan. '
                                'They should still be just translucent in the middle when they '
                                'come out.',
                                'Die Kabeljaustücke 90 Sekunden pro Seite in sehr heißer Pfanne '
                                'anbraten. In der Mitte dürfen sie noch glasig sein.', 180),
                    },
                    steps_append=[step('Dress the shredded cabbage with the mayo and a squeeze of '
                                       'lime and put it under the fish in every taco.',
                                       'Den gehobelten Kohl mit Mayo und einem Spritzer Limette '
                                       'anmachen und in jedem Taco unter den Fisch legen.')],
                )),
    ],
))

# ---------------------------------------------------------------------------
# Schnitzel
# ---------------------------------------------------------------------------
DISHES.append(dish(
    id='schnitzel',
    name=('Schnitzel', 'Schnitzel'),
    hero=('The crumb should ripple and lift away from the meat. Swim it in fat.',
          'Die Panade soll wellig sein und sich vom Fleisch lösen. Lass sie im Fett schwimmen.'),
    cap=('swim, do not fry', 'schwimmen, nicht braten'),
    stripe='#C08A45',
    cuisines=['german', 'austrian'],
    categories=['comfort', 'weekend'],
    partition='extended', secondary=[], tier=2,
    slots=['lunch', 'dinner'], servings=2,
    tags=['schnitzel', 'breaded', 'paniert', 'lemon', 'zitrone'],
    base_ing=[
        ing('pork-loin', 400, 'g', 'two cutlets, beaten to 4 mm',
            'zwei Schnitzel, auf 4 mm geklopft'),
        ing('flour', 60, 'g'),
        ing('egg', 2, 'piece'),
        ing('breadcrumbs', 120, 'g', 'coarse, dry', 'grob, trocken'),
        ing('butter', 40, 'g'),
        ing('rapeseed-oil', 250, 'ml'),
        ing('lemon', 1, 'piece'),
        ing('parsley', 15, 'g'),
        ing('potato', 500, 'g'),
        ing('salt', 2, 'tsp'),
        ing('pepper', 1, 'tsp'),
    ],
    base_steps=[
        step('Beat the cutlets between two sheets of paper until they are thin enough '
             'to see shadow through. Season both sides.',
             'Die Schnitzel zwischen zwei Lagen Papier so dünn klopfen, dass Schatten '
             'durchscheint. Beidseitig würzen.'),
        step('Boil the potatoes in salted water until a knife slides out on its own.',
             'Die Kartoffeln in Salzwasser kochen, bis das Messer von allein '
             'herausgleitet.', 1200),
        step('Three plates: flour, beaten egg, breadcrumbs. Flour, egg, crumb — and '
             'press the crumb on loosely, never firmly.',
             'Drei Teller: Mehl, verquirltes Ei, Semmelbrösel. Mehl, Ei, Brösel — die '
             'Brösel nur locker andrücken, nie fest.'),
        step('Heat the oil and butter until a crumb sizzles instantly. There must be '
             'enough fat for the schnitzel to float slightly.',
             'Öl und Butter erhitzen, bis ein Brösel sofort zischt. Es muss genug Fett '
             'sein, dass das Schnitzel leicht schwimmt.'),
        step('Fry one at a time, swirling the pan constantly so hot fat washes over '
             'the top. That is what makes the crumb ripple.',
             'Eines nach dem anderen braten und die Pfanne dabei ständig schwenken, '
             'damit heißes Fett über die Oberseite läuft. Das macht die Panade wellig.',
             240),
        step('Drain upright against a rack, salt straight away, lemon and parsley at '
             'the table.',
             'Aufrecht an einem Gitter abtropfen lassen, sofort salzen, Zitrone und '
             'Petersilie kommen auf den Tisch.'),
    ],
    variants=[
        variant('classic', 'classic',
                ('Pork Schnitzel', 'Schweineschnitzel'),
                ('Loose crumb, swirling pan, salt the second it leaves the fat.',
                 'Lockere Panade, schwenkende Pfanne, salzen in der Sekunde, in der es '
                 'das Fett verlässt.'),
                ('swirl the pan. that is the whole trick.',
                 'die Pfanne schwenken. das ist der ganze Trick.'),
                'medium', 45, 780, (46, 62, 38),
                attrs=['comfort'], tech=['pan-fry'], is_base=True),
        variant('poultry', 'halal',
                ('Chicken Schnitzel', 'Hähnchenschnitzel'),
                ('Chicken breast butterflied and beaten thin. No pork anywhere.',
                 'Hähnchenbrust aufgeschnitten und dünn geklopft. Kein Schwein '
                 'in Sicht.'),
                ('butterfly it first, then beat it', 'erst aufschneiden, dann klopfen'),
                'medium', 45, 700, (48, 60, 30),
                attrs=['comfort', 'high-protein'], tech=['pan-fry'],
                patch=Patch(
                    swap={'pork-loin': ing('chicken-breast', 400, 'g', 'butterflied and beaten thin',
                                           'aufgeschnitten und dünn geklopft')},
                )),
        variant('vegan', 'vegan',
                ('Celeriac Schnitzel', 'Sellerieschnitzel'),
                ('Celeriac steamed first, then breaded. Raw celeriac never softens in '
                 'the pan.',
                 'Sellerie erst dämpfen, dann panieren. Roher Sellerie wird in der '
                 'Pfanne nie weich.'),
                ('steam it first or it stays woody',
                 'erst dämpfen, sonst bleibt er holzig'),
                'medium', 50, 560, (12, 66, 28),
                attrs=['comfort'], tech=['steam', 'pan-fry'],
                patch=Patch(
                    swap={
                        'pork-loin': ing('celeriac', 600, 'g', 'in 1 cm slabs', 'in 1-cm-Scheiben'),
                        'egg': ing('soy-milk', 150, 'ml', 'with 2 tbsp cornflour whisked in',
                                   'mit 2 EL Speisestärke verquirlt'),
                        'butter': ing('vegan-butter', 40, 'g'),
                    },
                    steps={
                        0: step('Steam the celeriac slabs until a knife goes through without '
                                'resistance, then dry them completely on a rack.',
                                'Die Selleriescheiben dämpfen, bis ein Messer ohne Widerstand '
                                'durchgeht, dann auf einem Gitter vollständig trocknen lassen.',
                                900),
                        2: step('Three plates: flour, the cornflour-soy mixture, breadcrumbs. '
                                'Coat twice through the wet and crumb for a thicker jacket.',
                                'Drei Teller: Mehl, die Soja-Stärke-Mischung, Semmelbrösel. '
                                'Zweimal durch Nass und Brösel ziehen für eine dickere Panade.'),
                    },
                )),
        variant('gluten-free', 'gluten-free',
                ('Gluten-free Schnitzel', 'Glutenfreies Schnitzel'),
                ('Polenta in the crumb gives a coarser, louder crust than breadcrumbs '
                 'ever did.',
                 'Polenta in der Panade gibt eine gröbere, lautere Kruste als Brösel '
                 'je hatten.'),
                ('louder crunch, honestly', 'ehrlich lauteres Knuspern'),
                'medium', 45, 760, (45, 60, 38),
                attrs=['comfort'], tech=['pan-fry'],
                patch=Patch(
                    swap={
                        'flour': ing('gf-flour', 60, 'g'),
                        'breadcrumbs': ing('polenta', 120, 'g', 'fine, mixed with 2 tbsp gf flour',
                                           'fein, mit 2 EL glutenfreiem Mehl gemischt'),
                    },
                )),
    ],
))

# ---------------------------------------------------------------------------
# Käsespätzle
# ---------------------------------------------------------------------------
DISHES.append(dish(
    id='kaesespaetzle',
    name=('Käsespätzle', 'Käsespätzle'),
    hero=('Layer it while everything is hot, or the cheese never joins in.',
          'Schichte alles heiß, sonst macht der Käse nicht mit.'),
    cap=('onions first, an hour before', 'Zwiebeln zuerst, eine Stunde vorher'),
    stripe='#C4A05A',
    cuisines=['german', 'swabian'],
    categories=['comfort', 'weekend'],
    partition='extended', secondary=[], tier=2,
    slots=['lunch', 'dinner'], servings=3,
    tags=['spätzle', 'cheese', 'käse', 'swabian', 'onions'],
    base_ing=[
        ing('flour', 350, 'g'),
        ing('egg', 4, 'piece'),
        ing('whole-milk', 120, 'ml'),
        ing('emmental', 150, 'g', 'grated', 'gerieben'),
        ing('cheddar', 100, 'g', 'grated, for sharpness', 'gerieben, für die Schärfe'),
        ing('onion', 3, 'piece', 'sliced thin', 'dünn geschnitten'),
        ing('butter', 60, 'g'),
        ing('nutmeg', 0.5, 'tsp'),
        ing('chives', 15, 'g'),
        ing('salt', 2, 'tsp'),
        ing('pepper', 1, 'tsp'),
    ],
    base_steps=[
        step('Start the onions first: butter, low heat, a pinch of salt, and forty '
             'minutes of near-neglect until they are brown and jammy.',
             'Zuerst die Zwiebeln: Butter, niedrige Hitze, eine Prise Salz und vierzig '
             'Minuten fast ohne Zuwendung, bis sie braun und marmeladig sind.', 2400),
        step('Beat the flour, eggs, milk, salt and nutmeg until the batter blisters '
             'and falls off the spoon in ribbons.',
             'Mehl, Eier, Milch, Salz und Muskat schlagen, bis der Teig Blasen wirft '
             'und in Bändern vom Löffel fällt.', 300),
        step('Rest the batter while a wide pan of salted water comes to the boil.',
             'Den Teig ruhen lassen, während ein weiter Topf Salzwasser aufkocht.', 900),
        step('Press the batter through a spätzle board or a wide-holed colander into '
             'the water in batches. They are done thirty seconds after they float.',
             'Den Teig portionsweise über ein Spätzlebrett oder ein grobes Sieb ins '
             'Wasser drücken. Dreißig Sekunden nach dem Aufsteigen sind sie fertig.', 120),
        step('Lift each batch straight into a warm dish and layer immediately with the '
             'cheeses so the heat melts them as you go.',
             'Jede Portion direkt in eine warme Form heben und sofort mit dem Käse '
             'schichten, damit die Hitze ihn schmilzt.'),
        step('Onions over the top, chives, pepper, and to the table before it sets.',
             'Zwiebeln obenauf, Schnittlauch, Pfeffer, und auf den Tisch, bevor es fest '
             'wird.'),
    ],
    variants=[
        variant('classic', 'vegetarian',
                ('Käsespätzle', 'Käsespätzle'),
                ('Forty minutes of onions, hand-pressed spätzle, layered while '
                 'steaming.',
                 'Vierzig Minuten Zwiebeln, handgepresste Spätzle, dampfend geschichtet.'),
                ('do not let it wait', 'lass es nicht warten'),
                'medium', 80, 860, (34, 84, 42),
                attrs=['comfort'], tech=['simmer', 'sauté'], is_base=True),
        variant('vegan', 'vegan',
                ('Vegan Käsespätzle', 'Vegane Käsespätzle'),
                ('Chickpea flour and turmeric replace the eggs; the dough is stiffer '
                 'and behaves better.',
                 'Kichererbsenmehl und Kurkuma ersetzen die Eier; der Teig ist fester '
                 'und lässt sich besser verarbeiten.'),
                ('stiffer dough, easier press', 'festerer Teig, leichteres Pressen'),
                'medium', 80, 660, (20, 90, 22),
                attrs=['comfort'], tech=['simmer', 'sauté'],
                patch=Patch(
                    drop=['egg'],
                    swap={
                        'whole-milk': ing('soy-milk', 260, 'ml'),
                        'butter': ing('vegan-butter', 60, 'g'),
                        'emmental': ing('vegan-cheese', 200, 'g', 'meltable, grated',
                                        'schmelzend, gerieben'),
                        'cheddar': ing('nutritional-yeast', 3, 'tbsp'),
                    },
                    add=[ing('gf-flour', 60, 'g', 'chickpea flour', 'Kichererbsenmehl'),
                         ing('turmeric', 0.5, 'tsp', 'for colour', 'für die Farbe')],
                    steps={
                        1: step('Beat the plain flour, chickpea flour, turmeric, soy drink, salt '
                                'and nutmeg until the batter blisters. It will be stiffer than '
                                'the egg version — that is correct.',
                                'Weizenmehl, Kichererbsenmehl, Kurkuma, Sojadrink, Salz und '
                                'Muskat schlagen, bis der Teig Blasen wirft. Er wird fester als '
                                'die Ei-Variante — das ist richtig.', 300),
                    },
                )),
        variant('gluten-free', 'gluten-free',
                ('Gluten-free Käsespätzle', 'Glutenfreie Käsespätzle'),
                ('Gluten-free batter needs an extra egg and a longer rest, otherwise '
                 'the spätzle dissolve.',
                 'Glutenfreier Teig braucht ein Ei mehr und längere Ruhe, sonst lösen '
                 'sich die Spätzle auf.'),
                ('one extra egg. non-negotiable.', 'ein Ei mehr. nicht verhandelbar.'),
                'medium', 85, 830, (35, 80, 42),
                attrs=['comfort'], tech=['simmer', 'sauté'],
                patch=Patch(
                    swap={'flour': ing('gf-flour', 350, 'g', 'with xanthan', 'mit Xanthan')},
                    qty={'egg': 5},
                    steps={
                        2: step('Rest the batter twice as long as a wheat one and test a single '
                                'spätzle before committing the batch — if it frays, beat in one '
                                'more spoon of flour.',
                                'Den Teig doppelt so lang ruhen lassen wie Weizenteig und ein '
                                'einzelnes Spätzle testen, bevor du den Rest einsetzt — franst '
                                'es aus, noch einen Löffel Mehl unterschlagen.', 1800),
                    },
                )),
    ],
))

# ---------------------------------------------------------------------------
# Bibimbap
# ---------------------------------------------------------------------------
DISHES.append(dish(
    id='bibimbap',
    name=('Bibimbap', 'Bibimbap'),
    hero=('Every vegetable dressed separately, then all of it ruined together on '
          'purpose.',
          'Jedes Gemüse einzeln angemacht — und dann absichtlich alles zusammen ruiniert.'),
    cap=('mix it violently at the table', 'am Tisch heftig vermischen'),
    stripe='#A3462F',
    cuisines=['korean', 'asian'],
    categories=['bowl', 'weeknight', 'meal-prep'],
    partition='extended', secondary=['cuisine-asian'], tier=2,
    slots=['lunch', 'dinner'], servings=2,
    tags=['bibimbap', 'rice', 'korean', 'gochujang', 'bowl'],
    base_ing=[
        ing('jasmine-rice', 200, 'g'),
        ing('beef-mince', 200, 'g'),
        ing('spinach', 200, 'g'),
        ing('carrot', 2, 'piece', 'julienned', 'in feine Streifen'),
        ing('beansprouts', 150, 'g'),
        ing('shiitake', 120, 'g'),
        ing('egg', 2, 'piece'),
        ing('gochujang', 3, 'tbsp'),
        ing('soy-sauce', 3, 'tbsp'),
        ing('sesame-oil', 3, 'tsp'),
        ing('sesame-seeds', 2, 'tsp'),
        ing('garlic', 3, 'clove'),
        ing('rice-vinegar', 1, 'tbsp'),
        ing('sugar', 1, 'tsp'),
        ing('salt', 1, 'tsp'),
    ],
    base_steps=[
        step('Cook the rice and leave it covered. It should be dry and separate, not '
             'sticky.',
             'Den Reis kochen und abgedeckt stehen lassen. Er soll trocken und körnig '
             'sein, nicht klebrig.', 900),
        step('Blanch the spinach for thirty seconds, squeeze it dry, and dress it with '
             'a teaspoon of sesame oil, a grated garlic clove and salt.',
             'Den Spinat 30 Sekunden blanchieren, ausdrücken und mit einem Teelöffel '
             'Sesamöl, einer geriebenen Knoblauchzehe und Salz anmachen.', 30),
        step('Blanch the beansprouts for one minute and dress them the same way. Every '
             'vegetable gets its own seasoning; that is the whole idea.',
             'Die Sprossen eine Minute blanchieren und genauso anmachen. Jedes Gemüse '
             'bekommt seine eigene Würze; das ist die ganze Idee.', 60),
        step('Fry the carrots quickly with salt, then the mushrooms with soy sauce '
             'until they are dark. Keep everything in separate piles.',
             'Die Karotten kurz mit Salz braten, dann die Pilze mit Sojasauce, bis sie '
             'dunkel sind. Alles getrennt halten.', 480),
        step('Brown the mince with the remaining garlic, a tablespoon of soy sauce and '
             'the sugar until sticky.',
             'Das Hack mit dem restlichen Knoblauch, einem Esslöffel Sojasauce und dem '
             'Zucker klebrig braun braten.', 420),
        step('Stir the gochujang with the vinegar, remaining sesame oil and a splash '
             'of water into a pourable sauce.',
             'Gochujang mit Essig, restlichem Sesamöl und einem Schuss Wasser zu einer '
             'gießbaren Sauce verrühren.'),
        step('Fry the eggs so the whites are crisp at the edges and the yolks are '
             'liquid. Rice down, everything arranged in wedges on top, egg in the '
             'centre, sauce, sesame.',
             'Die Eier so braten, dass das Eiweiß am Rand knusprig und das Eigelb '
             'flüssig ist. Reis zuerst, alles in Segmenten darauf anrichten, Ei in die '
             'Mitte, Sauce, Sesam.', 180),
    ],
    variants=[
        variant('classic', 'classic',
                ('Beef Bibimbap', 'Rind-Bibimbap'),
                ('Each vegetable seasoned alone, crisp-edged fried egg, gochujang '
                 'poured over.',
                 'Jedes Gemüse einzeln gewürzt, Spiegelei mit knusprigem Rand, '
                 'Gochujang darüber.'),
                ('separate piles until the last second',
                 'getrennte Häufchen bis zur letzten Sekunde'),
                'medium', 50, 690, (38, 72, 26),
                attrs=['high-protein', 'meal-prep'], tech=['stir-fry', 'blanch'],
                is_base=True),
        variant('vegan', 'vegan',
                ('Vegan Bibimbap', 'Veganes Bibimbap'),
                ('Tofu crumbled and fried until it has edges; the yolk becomes an '
                 'avocado half.',
                 'Tofu zerbröselt und gebraten, bis er Kanten hat; das Eigelb wird zur '
                 'halben Avocado.'),
                ('check the gochujang for anchovy', 'prüf das Gochujang auf Sardelle'),
                'medium', 50, 560, (22, 76, 20),
                attrs=['meal-prep'], tech=['stir-fry', 'blanch'],
                patch=Patch(
                    drop=['egg'],
                    swap={'beef-mince': ing('tofu', 250, 'g', 'pressed and crumbled',
                                            'gepresst und zerbröselt')},
                    add=[ing('avocado', 1, 'piece')],
                    steps={
                        4: step('Fry the crumbled tofu hard and undisturbed until it browns in '
                                'patches, then add the remaining garlic, soy sauce and sugar and '
                                'let it go sticky.',
                                'Den zerbröselten Tofu ungestört kräftig braten, bis er '
                                'stellenweise bräunt, dann restlichen Knoblauch, Sojasauce und '
                                'Zucker zugeben und klebrig werden lassen.', 600),
                        6: step('Rice down, everything in wedges on top, half an avocado in the '
                                'centre where the yolk would be, sauce, sesame.',
                                'Reis zuerst, alles in Segmenten darauf, eine halbe Avocado in '
                                'die Mitte, wo sonst das Eigelb wäre, Sauce, Sesam.'),
                    },
                )),
        variant('gluten-free', 'gluten-free',
                ('Gluten-free Bibimbap', 'Glutenfreies Bibimbap'),
                ('Tamari and a gluten-free gochujang. Most standard gochujang carries '
                 'barley.',
                 'Tamari und ein glutenfreies Gochujang. Die meisten Standard-Gochujang '
                 'enthalten Gerste.'),
                ('read the gochujang label twice', 'lies das Gochujang-Etikett zweimal'),
                'medium', 50, 640, (37, 70, 25),
                attrs=['high-protein', 'meal-prep'], tech=['stir-fry', 'blanch'],
                patch=Patch(
                    swap={
                        'soy-sauce': ing('tamari', 3, 'tbsp'),
                        'gochujang': ing('gochujang', 3, 'tbsp', 'gluten-free, rice-based',
                                         'glutenfrei, auf Reisbasis'),
                    },
                )),
    ],
))

# ---------------------------------------------------------------------------
# Hummus Mezze
# ---------------------------------------------------------------------------
DISHES.append(dish(
    id='hummus-mezze',
    name=('Hummus Mezze', 'Hummus-Mezze'),
    hero=('Overcook the chickpeas. Everything people dislike about hummus is '
          'undercooked chickpeas.',
          'Koch die Kichererbsen zu weich. Alles, was Leute an Hummus stört, sind zu '
          'harte Kichererbsen.'),
    cap=('too soft is exactly right', 'zu weich ist genau richtig'),
    stripe='#B8A05E',
    cuisines=['levantine', 'middle-eastern'],
    categories=['sharing', 'no-cook', 'lunch'],
    partition='extended', secondary=['cuisine-middle-eastern'], tier=2,
    slots=['lunch', 'snack'], servings=4,
    tags=['hummus', 'tahini', 'mezze', 'chickpeas', 'kichererbsen'],
    base_ing=[
        ing('chickpeas', 480, 'g', 'two tins, drained', 'zwei Dosen, abgetropft'),
        ing('bicarb', 0.5, 'tsp'),
        ing('tahini', 120, 'g', 'good, runny', 'gut, fließend'),
        ing('lemon', 2, 'piece'),
        ing('garlic', 2, 'clove'),
        ing('cumin', 1, 'tsp'),
        ing('olive-oil', 5, 'tbsp'),
        ing('paprika-powder', 1, 'tsp'),
        ing('parsley', 20, 'g'),
        ing('flatbread', 3, 'piece'),
        ing('cucumber', 1, 'piece'),
        ing('cherry-tomato', 200, 'g'),
        ing('olives', 100, 'g'),
        ing('salt', 2, 'tsp'),
    ],
    base_steps=[
        step('Simmer the drained chickpeas with the bicarbonate and fresh water until '
             'the skins slip and they crush between two fingers with no effort.',
             'Die abgetropften Kichererbsen mit Natron und frischem Wasser köcheln, bis '
             'sich die Häute lösen und sie mühelos zwischen zwei Fingern zerdrücken '
             'lassen.', 1200),
        step('While they are hot, blend them with the garlic, cumin, lemon juice and '
             'salt until completely smooth. Hot chickpeas blend smoother than cold.',
             'Noch heiß mit Knoblauch, Kreuzkümmel, Zitronensaft und Salz vollkommen '
             'glatt mixen. Heiße Kichererbsen werden glatter als kalte.', 180),
        step('Add the tahini and three tablespoons of iced water and blend again until '
             'it goes pale and lifts. It will look too loose; it firms up.',
             'Tahin und drei Esslöffel Eiswasser zugeben und erneut mixen, bis es hell '
             'wird und aufgeht. Es sieht zu flüssig aus; es wird fester.', 120),
        step('Spread it in a shallow bowl with the back of a spoon, making a well, and '
             'pour the olive oil in.',
             'In einer flachen Schale mit dem Löffelrücken ausstreichen, eine Mulde '
             'formen und das Olivenöl hineingießen.'),
        step('Paprika, parsley, and warm flatbread. Cucumber, tomatoes and olives '
             'alongside.',
             'Paprikapulver, Petersilie und warmes Fladenbrot. Gurke, Tomaten und '
             'Oliven daneben.'),
    ],
    variants=[
        variant('classic', 'vegan',
                ('Hummus Mezze', 'Hummus-Mezze'),
                ('Chickpeas cooked to collapse, blended hot, loosened with iced water.',
                 'Kichererbsen weich gekocht, heiß gemixt, mit Eiswasser gelockert.'),
                ('iced water. yes, iced.', 'Eiswasser. ja, Eis.'),
                'easy', 35, 420, (14, 40, 24),
                attrs=['sharing', 'budget', 'make-ahead'], tech=['simmer'],
                is_base=True),
        variant('sesame-free', 'nut-free',
                ('Sesame-free Hummus', 'Hummus ohne Sesam'),
                ('Sunflower seed butter instead of tahini. Slightly sweeter, otherwise '
                 'unchanged.',
                 'Sonnenblumenmus statt Tahin. Etwas süßer, sonst unverändert.'),
                ('more lemon to balance the sweetness',
                 'mehr Zitrone, um die Süße auszugleichen'),
                'easy', 35, 400, (13, 40, 22),
                attrs=['sharing', 'budget'], tech=['simmer'],
                patch=Patch(
                    swap={'tahini': ing('sunflower-seeds', 120, 'g', 'blitzed to a smooth butter',
                                        'zu glattem Mus gemahlen')},
                    qty={'lemon': 3},
                    steps={
                        2: step('Blitz the sunflower seeds to a smooth butter first, then add '
                                'them with three tablespoons of iced water and blend. Add the '
                                'extra lemon — sunflower butter is sweeter than tahini.',
                                'Die Sonnenblumenkerne zuerst zu glattem Mus mahlen, dann mit '
                                'drei Esslöffeln Eiswasser zugeben und mixen. Die zusätzliche '
                                'Zitrone dazu — Sonnenblumenmus ist süßer als Tahin.', 240),
                    },
                )),
        variant('high-protein', 'vegetarian',
                ('Hummus with warm spiced lentils', 'Hummus mit warmen Gewürzlinsen'),
                ('A pile of hot lentils in the well turns a dip into dinner.',
                 'Ein Haufen heißer Linsen in der Mulde macht aus einem Dip ein '
                 'Abendessen.'),
                ('the well exists for a reason', 'die Mulde hat einen Grund'),
                'easy', 45, 520, (24, 52, 24),
                attrs=['high-protein', 'sharing', 'meal-prep'], tech=['simmer'],
                patch=Patch(
                    add=[
                        ing('puy-lentils', 150, 'g'),
                        ing('baharat', 2, 'tsp'),
                        ing('greek-yoghurt', 100, 'g'),
                        ing('pistachios', 30, 'g', 'chopped', 'gehackt'),
                    ],
                    steps_insert=[(3, step('Simmer the lentils until just tender, drain, and toss '
                                           'them hot with the baharat, a tablespoon of olive oil '
                                           'and salt.',
                                           'Die Linsen bissfest kochen, abgießen und heiß mit '
                                           'Baharat, einem Esslöffel Olivenöl und Salz mischen.',
                                           1500))],
                    steps={
                        4: step('Pile the warm lentils into the well, spoon the yoghurt around '
                                'them, then paprika, pistachios, parsley and warm bread.',
                                'Die warmen Linsen in die Mulde häufen, den Joghurt darum '
                                'löffeln, dann Paprikapulver, Pistazien, Petersilie und warmes '
                                'Brot.'),
                    },
                )),
    ],
))

# ---------------------------------------------------------------------------
# Tiramisu
# ---------------------------------------------------------------------------
DISHES.append(dish(
    id='tiramisu',
    name=('Tiramisù', 'Tiramisù'),
    hero=('Dip, do not soak. One second per side and no more.',
          'Tunken, nicht einweichen. Eine Sekunde pro Seite, nicht mehr.'),
    cap=('overnight in the fridge, minimum', 'mindestens eine Nacht im Kühlschrank'),
    stripe='#8E6A4E',
    cuisines=['italian'],
    categories=['dessert', 'make-ahead'],
    partition='extended', secondary=['cuisine-italian'], tier=2,
    slots=['dessert'], servings=6,
    tags=['tiramisu', 'dessert', 'nachtisch', 'coffee', 'mascarpone'],
    base_ing=[
        ing('egg', 4, 'piece', 'separated, very fresh', 'getrennt, sehr frisch'),
        ing('sugar', 100, 'g'),
        ing('mascarpone', 500, 'g', 'room temperature', 'zimmerwarm'),
        ing('ladyfingers', 300, 'g'),
        ing('espresso', 350, 'ml', 'cooled completely', 'vollständig abgekühlt'),
        ing('cocoa-powder', 3, 'tbsp'),
        ing('salt', 0.25, 'tsp'),
    ],
    base_steps=[
        step('Whisk the yolks with three quarters of the sugar until pale and thick '
             'enough to hold a ribbon.',
             'Die Eigelbe mit drei Vierteln des Zuckers hell und so dick schlagen, dass '
             'sie ein Band halten.', 300),
        step('Beat the mascarpone in gently, a third at a time. Overworked mascarpone '
             'splits and never comes back.',
             'Den Mascarpone in drei Teilen vorsichtig unterschlagen. Überarbeiteter '
             'Mascarpone gerinnt und kommt nicht zurück.'),
        step('Whip the whites with the salt and the remaining sugar to soft peaks, '
             'then fold them through in two additions.',
             'Das Eiweiß mit Salz und dem restlichen Zucker zu weichen Spitzen '
             'schlagen und in zwei Portionen unterheben.', 240),
        step('Dip each ladyfinger in the cold coffee for one second a side. They keep '
             'drinking after they leave the cup.',
             'Jeden Löffelbiskuit eine Sekunde pro Seite in den kalten Kaffee tauchen. '
             'Sie trinken weiter, auch nachdem sie die Tasse verlassen haben.'),
        step('Layer: biscuits, cream, biscuits, cream. Flatten the top and cover.',
             'Schichten: Biskuits, Creme, Biskuits, Creme. Oberfläche glatt streichen '
             'und abdecken.'),
        step('Refrigerate overnight. Cocoa through a sieve only just before it goes to '
             'the table.',
             'Über Nacht kalt stellen. Kakao erst kurz vor dem Servieren durch ein Sieb '
             'darüber.', 28800),
    ],
    variants=[
        variant('classic', 'vegetarian',
                ('Tiramisù', 'Tiramisù'),
                ('Raw egg, real mascarpone, one second per dip.',
                 'Rohes Ei, echter Mascarpone, eine Sekunde pro Tunken.'),
                ('cocoa at the last possible moment', 'Kakao im letzten Moment'),
                'medium', 40, 480, (10, 44, 28),
                attrs=['make-ahead', 'comfort'], tech=['raw'],
                tips=[('Raw egg: use the freshest you can and keep it cold. Pasteurised '
                       'egg works and changes nothing.',
                       'Rohes Ei: möglichst frisch und durchgehend kalt. Pasteurisiertes '
                       'Ei funktioniert genauso.')],
                is_base=True),
        variant('vegan', 'vegan',
                ('Vegan Tiramisù', 'Veganes Tiramisù'),
                ('Aquafaba whips like egg white, and cashew cream holds like '
                 'mascarpone.',
                 'Aquafaba schlägt wie Eiweiß, und Cashewcreme hält wie Mascarpone.'),
                ('aquafaba needs twice the whipping time',
                 'Aquafaba braucht doppelt so lange'),
                'medium', 50, 420, (8, 48, 22),
                extra_contains=['tree-nuts', 'cashews', 'coconut'],
                attrs=['make-ahead'], tech=['raw'],
                patch=Patch(
                    drop=['egg'],
                    swap={
                        'mascarpone': ing('cashews', 250, 'g', 'soaked 4 h, blended with 150 ml coconut cream',
                                          '4 Std. eingeweicht, mit 150 ml Kokoscreme gemixt'),
                        'ladyfingers': ing('ladyfingers-vegan', 300, 'g', 'egg-free', 'ohne Ei'),
                    },
                    add=[
                        ing('aquafaba', 150, 'ml', 'the liquid from a chickpea tin',
                            'die Flüssigkeit aus einer Kichererbsendose'),
                        ing('coconut-milk', 150, 'ml', 'the thick cream from the top',
                            'die dicke Creme von oben'),
                        ing('vanilla', 1, 'tsp'),
                    ],
                    steps={
                        0: step('Blend the soaked cashews with the thick coconut cream, half the '
                                'sugar and the vanilla until completely smooth — three minutes '
                                'longer than you think.',
                                'Die eingeweichten Cashews mit der dicken Kokoscreme, der Hälfte '
                                'des Zuckers und der Vanille vollkommen glatt mixen — drei '
                                'Minuten länger als du denkst.', 300),
                        1: step('Chill the cashew cream while you whip the aquafaba; cold cream '
                                'folds without deflating anything.',
                                'Die Cashewcreme kalt stellen, während das Aquafaba geschlagen '
                                'wird; kalte Creme lässt sich unterheben, ohne zusammenzufallen.'),
                        2: step('Whip the aquafaba with the remaining sugar and salt until it '
                                'holds a peak — eight to ten minutes, far longer than egg white '
                                '— then fold it through in two additions.',
                                'Das Aquafaba mit restlichem Zucker und Salz schlagen, bis es '
                                'Spitzen hält — acht bis zehn Minuten, viel länger als Eiweiß — '
                                'dann in zwei Portionen unterheben.', 540),
                    },
                )),
        variant('caffeine-free', 'caffeine-free',
                ('Caffeine-free Tiramisù', 'Koffeinfreies Tiramisù'),
                ('Decaf and carob. Sweeter and rounder, and it will not keep you up.',
                 'Entkoffeiniert und Johannisbrot. Süßer und runder, und es hält dich '
                 'nicht wach.'),
                ('dessert you can eat at ten p.m.', 'Nachtisch, den du um 22 Uhr essen kannst'),
                'medium', 40, 470, (10, 45, 27),
                attrs=['make-ahead', 'comfort'], tech=['raw'],
                patch=Patch(
                    swap={
                        'espresso': ing('decaf-espresso', 350, 'ml', 'cooled', 'abgekühlt'),
                        'cocoa-powder': ing('carob-powder', 3, 'tbsp'),
                    },
                )),
        variant('gluten-free', 'gluten-free',
                ('Gluten-free Tiramisù', 'Glutenfreies Tiramisù'),
                ('Gluten-free ladyfingers drink faster. Half a second per side, not one.',
                 'Glutenfreie Löffelbiskuits trinken schneller. Eine halbe Sekunde pro '
                 'Seite, nicht eine.'),
                ('half a second. count fast.', 'eine halbe Sekunde. zähl schnell.'),
                'medium', 40, 460, (10, 43, 27),
                attrs=['make-ahead'], tech=['raw'],
                patch=Patch(
                    swap={'ladyfingers': ing('gf-ladyfingers', 300, 'g')},
                    steps={
                        3: step('Dip each gluten-free biscuit for half a second a side only. '
                                'They collapse in the time a wheat one takes to wet.',
                                'Jeden glutenfreien Biskuit nur eine halbe Sekunde pro Seite '
                                'tunken. Sie zerfallen in der Zeit, die ein Weizenbiskuit zum '
                                'Nasswerden braucht.'),
                    },
                )),
    ],
))

# ---------------------------------------------------------------------------
# Banana Bread
# ---------------------------------------------------------------------------
DISHES.append(dish(
    id='banana-bread',
    name=('Banana Bread', 'Bananenbrot'),
    hero=('The blacker the bananas, the better the loaf. There is no upper limit.',
          'Je schwärzer die Bananen, desto besser das Brot. Es gibt keine Obergrenze.'),
    cap=('wait for the black ones', 'warte auf die schwarzen'),
    stripe='#A98450',
    cuisines=['american'],
    categories=['baking', 'breakfast', 'make-ahead'],
    partition='extended', secondary=[], tier=2,
    slots=['breakfast', 'snack', 'dessert'], servings=8,
    tags=['banana', 'banane', 'baking', 'backen', 'loaf'],
    base_ing=[
        ing('banana', 4, 'piece', 'black, mashed', 'schwarz, zerdrückt'),
        ing('flour', 250, 'g'),
        ing('brown-sugar', 130, 'g'),
        ing('butter', 110, 'g', 'melted and cooled', 'geschmolzen und abgekühlt'),
        ing('egg', 2, 'piece'),
        ing('bicarb', 1, 'tsp'),
        ing('baking-powder', 0.5, 'tsp'),
        ing('cinnamon', 1, 'tsp'),
        ing('salt', 0.5, 'tsp'),
        ing('walnuts', 80, 'g', 'toasted, broken', 'geröstet, gebrochen'),
        ing('vanilla', 1, 'tsp'),
    ],
    base_steps=[
        step('Heat the oven to 170 °C and line a loaf tin, leaving the paper standing '
             'proud so you can lift the loaf out.',
             'Ofen auf 170 °C vorheizen und eine Kastenform auslegen, das Papier über '
             'den Rand stehen lassen, damit sich das Brot herausheben lässt.'),
        step('Mash the bananas properly — no lumps bigger than a pea — then beat in '
             'the sugar, melted butter, eggs and vanilla.',
             'Die Bananen gründlich zerdrücken — keine Stücke größer als eine Erbse — '
             'dann Zucker, geschmolzene Butter, Eier und Vanille unterschlagen.'),
        step('Fold in the flour, bicarbonate, baking powder, cinnamon and salt with as '
             'few strokes as you can manage, then the walnuts.',
             'Mehl, Natron, Backpulver, Zimt und Salz mit so wenigen Zügen wie möglich '
             'unterheben, dann die Walnüsse.'),
        step('Bake until a skewer comes out with a crumb or two but no wet batter. '
             'Cover with foil if the top darkens early.',
             'Backen, bis ein Spieß mit ein paar Krümeln, aber ohne feuchten Teig '
             'herauskommt. Mit Folie abdecken, falls die Oberfläche zu früh dunkelt.',
             3300),
        step('Cool in the tin for ten minutes, then lift it out. Slicing it hot tears '
             'the crumb.',
             'Zehn Minuten in der Form abkühlen, dann herausheben. Heiß geschnitten '
             'reißt die Krume.', 600),
    ],
    variants=[
        variant('classic', 'vegetarian',
                ('Banana Bread', 'Bananenbrot'),
                ('Melted butter, black bananas, walnuts folded in last.',
                 'Geschmolzene Butter, schwarze Bananen, Walnüsse zuletzt untergehoben.'),
                ('the freezer is where bananas go to improve',
                 'im Gefrierfach werden Bananen besser'),
                'easy', 70, 320, (6, 42, 15),
                attrs=['make-ahead', 'freezer-friendly', 'kid-friendly'], tech=['bake'],
                is_base=True),
        variant('vegan', 'vegan',
                ('Vegan Banana Bread', 'Veganes Bananenbrot'),
                ('More banana replaces the eggs entirely. It comes out denser and '
                 'moister.',
                 'Mehr Banane ersetzt die Eier vollständig. Es wird dichter und '
                 'saftiger.'),
                ('denser, and better for it', 'dichter, und dadurch besser'),
                'easy', 75, 300, (4, 45, 12),
                attrs=['make-ahead', 'freezer-friendly'], tech=['bake'],
                patch=Patch(
                    drop=['egg'],
                    swap={'butter': ing('rapeseed-oil', 100, 'ml')},
                    qty={'banana': 5},
                    steps={
                        1: step('Mash all five bananas to a purée, then beat in the sugar, oil '
                                'and vanilla. No eggs here — the extra banana binds it.',
                                'Alle fünf Bananen zu Püree zerdrücken, dann Zucker, Öl und '
                                'Vanille unterschlagen. Keine Eier — die zusätzliche Banane '
                                'bindet.'),
                        3: step('Bake until a skewer comes out clean; vegan batter takes about '
                                'ten minutes longer than the egg version.',
                                'Backen, bis ein Spieß sauber herauskommt; veganer Teig braucht '
                                'etwa zehn Minuten länger als die Ei-Variante.', 3900),
                    },
                )),
        variant('gluten-free', 'gluten-free',
                ('Gluten-free Banana Bread', 'Glutenfreies Bananenbrot'),
                ('Almond flour in the blend gives it structure gluten-free flour alone '
                 'cannot.',
                 'Mandelmehl in der Mischung gibt Struktur, die glutenfreies Mehl allein '
                 'nicht liefert.'),
                ('let it cool fully. it firms as it goes.',
                 'vollständig auskühlen lassen. es festigt sich.'),
                'easy', 75, 310, (7, 36, 17),
                attrs=['make-ahead'], tech=['bake'],
                patch=Patch(
                    swap={'flour': ing('gf-flour', 180, 'g')},
                    add=[ing('almond-flour', 80, 'g')],
                    steps={
                        4: step('Cool it completely in the tin. Gluten-free crumb sets as it '
                                'cools and will crumble if you cut it warm.',
                                'Vollständig in der Form auskühlen lassen. Glutenfreie Krume '
                                'festigt sich beim Abkühlen und zerbröselt, wenn man sie warm '
                                'schneidet.', 3600),
                    },
                )),
        variant('sugar-free', 'sugar-free',
                ('Banana Bread, no added sugar', 'Bananenbrot ohne Zuckerzusatz'),
                ('Dates blitzed into the batter. Sweet enough that nobody asks.',
                 'Datteln in den Teig gemixt. Süß genug, dass niemand fragt.'),
                ('soak the dates in hot water first', 'die Datteln zuerst in heißem Wasser einweichen'),
                'easy', 75, 260, (7, 38, 10),
                attrs=['make-ahead', 'kid-friendly'], tech=['bake'],
                patch=Patch(
                    swap={'brown-sugar': ing('dates', 150, 'g', 'pitted, soaked in hot water 10 min',
                                             'entsteint, 10 Min. in heißem Wasser eingeweicht')},
                    steps={
                        1: step('Blitz the soaked dates with a splash of their water into a '
                                'paste, then mash in the bananas and beat in the butter, eggs '
                                'and vanilla.',
                                'Die eingeweichten Datteln mit einem Schuss ihres Wassers zu '
                                'Paste mixen, dann die Bananen unterdrücken und Butter, Eier '
                                'und Vanille unterschlagen.'),
                    },
                )),
    ],
))

# ---------------------------------------------------------------------------
# French Toast
# ---------------------------------------------------------------------------
DISHES.append(dish(
    id='french-toast',
    name=('French Toast', 'Arme Ritter'),
    hero=('Stale bread only. Fresh bread turns to porridge in the custard.',
          'Nur altbackenes Brot. Frisches wird in der Eiermilch zu Brei.'),
    cap=('yesterday’s bread, today’s breakfast',
         'das Brot von gestern, das Frühstück von heute'),
    stripe='#CFA05F',
    cuisines=['french', 'american'],
    categories=['breakfast', 'weekend', 'quick'],
    partition='extended', secondary=[], tier=2,
    slots=['breakfast', 'dessert'], servings=2,
    tags=['french toast', 'arme ritter', 'breakfast', 'frühstück', 'brioche'],
    base_ing=[
        ing('brioche', 4, 'piece', 'thick slices, a day old', 'dicke Scheiben, einen Tag alt'),
        ing('egg', 3, 'piece'),
        ing('whole-milk', 150, 'ml'),
        ing('cinnamon', 1, 'tsp'),
        ing('vanilla', 1, 'tsp'),
        ing('salt', 0.25, 'tsp'),
        ing('butter', 30, 'g'),
        ing('maple-syrup', 3, 'tbsp'),
        ing('berries', 150, 'g'),
        ing('sugar', 1, 'tbsp'),
    ],
    base_steps=[
        step('Whisk the eggs, milk, cinnamon, vanilla, sugar and salt until there are '
             'no strings of white left.',
             'Eier, Milch, Zimt, Vanille, Zucker und Salz verquirlen, bis keine '
             'Eiweißfäden mehr da sind.'),
        step('Soak each slice for twenty seconds a side. Longer and the middle never '
             'sets; shorter and it stays dry bread.',
             'Jede Scheibe 20 Sekunden pro Seite einweichen. Länger, und die Mitte '
             'stockt nie; kürzer, und es bleibt trockenes Brot.', 40),
        step('Medium-low heat, butter foaming but not browning, and fry until deep '
             'gold and slightly puffed.',
             'Mittlere bis niedrige Hitze, Butter schäumend aber nicht bräunend, und '
             'braten, bis es dunkelgolden und leicht aufgegangen ist.', 300),
        step('Warm the berries in the pan for a minute with what is left of the '
             'butter, then syrup over everything.',
             'Die Beeren mit der restlichen Butter eine Minute in der Pfanne erwärmen, '
             'dann Sirup über alles.', 60),
    ],
    variants=[
        variant('classic', 'vegetarian',
                ('French Toast', 'Arme Ritter'),
                ('Day-old brioche, twenty seconds a side, butter that foams and stops.',
                 'Brioche von gestern, 20 Sekunden pro Seite, Butter, die schäumt und '
                 'aufhört.'),
                ('medium-low. always medium-low.', 'mittlere Hitze. immer mittlere Hitze.'),
                'easy', 20, 520, (16, 58, 24),
                attrs=['comfort', 'kid-friendly'], tech=['pan-fry'], is_base=True),
        variant('vegan', 'vegan',
                ('Vegan French Toast', 'Vegane Arme Ritter'),
                ('Chickpea flour and oat drink make a custard that sets exactly like '
                 'egg does.',
                 'Kichererbsenmehl und Haferdrink ergeben eine Masse, die genau wie Ei '
                 'stockt.'),
                ('chickpea flour is the egg here', 'Kichererbsenmehl ist hier das Ei'),
                'easy', 20, 440, (11, 62, 15),
                attrs=['comfort'], tech=['pan-fry'],
                patch=Patch(
                    drop=['egg'],
                    swap={
                        'whole-milk': ing('oat-milk', 250, 'ml'),
                        'butter': ing('vegan-butter', 30, 'g'),
                        'brioche': ing('sourdough', 4, 'piece', 'thick slices, a day old',
                                       'dicke Scheiben, einen Tag alt'),
                    },
                    add=[ing('gf-flour', 4, 'tbsp', 'chickpea flour', 'Kichererbsenmehl')],
                    steps={
                        0: step('Whisk the chickpea flour into a little of the oat drink until '
                                'lump-free, then add the rest with the cinnamon, vanilla, sugar '
                                'and salt.',
                                'Das Kichererbsenmehl zuerst mit etwas Haferdrink klumpenfrei '
                                'verrühren, dann den Rest mit Zimt, Vanille, Zucker und Salz '
                                'zugeben.'),
                        2: step('Medium-low heat and a little longer in the pan than the egg '
                                'version — chickpea custard needs the extra minute to set '
                                'through.',
                                'Mittlere bis niedrige Hitze und etwas länger als bei der '
                                'Ei-Variante — die Kichererbsenmasse braucht die Extraminute '
                                'zum Durchstocken.', 420),
                    },
                )),
        variant('gluten-free', 'gluten-free',
                ('Gluten-free French Toast', 'Glutenfreie Arme Ritter'),
                ('Gluten-free bread soaks in half the time and falls apart in the '
                 'other half.',
                 'Glutenfreies Brot zieht in der halben Zeit durch und zerfällt in der '
                 'anderen Hälfte.'),
                ('ten seconds a side. no more.', 'zehn Sekunden pro Seite. nicht mehr.'),
                'easy', 20, 500, (15, 56, 24),
                attrs=['comfort'], tech=['pan-fry'],
                patch=Patch(
                    swap={'brioche': ing('gf-bread', 4, 'piece', 'thick slices, toasted dry first',
                                         'dicke Scheiben, vorher trocken getoastet')},
                    steps={
                        1: step('Toast the gluten-free slices dry first to firm them, then soak '
                                'for ten seconds a side only.',
                                'Die glutenfreien Scheiben zuerst trocken toasten, damit sie '
                                'fester werden, dann nur zehn Sekunden pro Seite einweichen.', 20),
                    },
                )),
    ],
))
