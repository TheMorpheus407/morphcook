"""Core partition — the dishes people actually open. Loaded at launch."""

from dsl import dish, variant, ing, step, Patch

DISHES = []

# ---------------------------------------------------------------------------
# 1. Döner
# ---------------------------------------------------------------------------
DISHES.append(dish(
    id='doener',
    name=('Döner', 'Döner'),
    hero=('The one everybody says you have to give up. You do not.',
          'Das eine Gericht, das du angeblich aufgeben musst. Musst du nicht.'),
    cap=('vertical spit, horizontal appetite',
         'senkrechter Spieß, waagerechter Hunger'),
    stripe='#C2703F',
    cuisines=['turkish', 'middle-eastern'],
    categories=['street-food', 'handheld', 'weeknight'],
    partition='core', secondary=['cuisine-middle-eastern'], tier=1,
    slots=['lunch', 'dinner'], servings=2,
    tags=['doner', 'kebab', 'flatbread', 'street food', 'imbiss'],
    base_ing=[
        ing('chicken-thigh', 400, 'g', 'boneless, skin off', 'ohne Knochen und Haut'),
        ing('yoghurt', 100, 'g', 'for the marinade', 'für die Marinade'),
        ing('paprika-powder', 2, 'tsp'),
        ing('cumin', 1, 'tsp'),
        ing('garlic', 2, 'clove'),
        ing('olive-oil', 2, 'tbsp'),
        ing('flatbread', 2, 'piece'),
        ing('white-cabbage', 150, 'g', 'finely shredded', 'fein gehobelt'),
        ing('red-onion', 1, 'piece'),
        ing('tomato', 2, 'piece'),
        ing('cucumber', 0.5, 'piece'),
        ing('parsley', 15, 'g'),
        ing('greek-yoghurt', 150, 'g', 'for the sauce', 'für die Sauce'),
        ing('lemon', 1, 'piece'),
        ing('salt', 1, 'tsp'),
        ing('pepper', 0.5, 'tsp'),
        ing('chilli-flakes', 1, 'tsp', 'to taste', 'nach Geschmack', optional=True),
    ],
    base_steps=[
        step('Stir the yoghurt, paprika, cumin, one grated garlic clove, the oil, '
             'salt and pepper together. Turn the chicken through it until every '
             'piece is coated and leave it somewhere cool.',
             'Joghurt, Paprikapulver, Kreuzkümmel, eine geriebene Knoblauchzehe, '
             'Öl, Salz und Pfeffer verrühren. Das Hähnchen darin wenden, bis alles '
             'bedeckt ist, und kühl stellen.', 1800),
        step('Heat the oven to 220 °C. Press the chicken into a tight stack in a '
             'small tin — that pressure is what gives you the shaved edge later.',
             'Ofen auf 220 °C vorheizen. Das Hähnchen fest in eine kleine Form '
             'schichten — dieser Druck sorgt später für die abgeschnittene Kante.'),
        step('Roast until the top is dark at the edges and the middle is just firm.',
             'Rösten, bis die Oberfläche an den Rändern dunkel ist und die Mitte '
             'gerade fest wird.', 1500),
        step('Meanwhile shred the cabbage as thinly as you can, slice the onion into '
             'half-moons, dice the tomato and cucumber, chop the parsley.',
             'Währenddessen den Kohl so fein wie möglich hobeln, die Zwiebel in '
             'Halbmonde schneiden, Tomate und Gurke würfeln, Petersilie hacken.'),
        step('Stir the remaining garlic and half the lemon juice into the Greek '
             'yoghurt. Taste. It should be sharper than feels sensible.',
             'Restlichen Knoblauch und den Saft einer halben Zitrone unter den '
             'griechischen Joghurt rühren. Abschmecken. Es darf schärfer sein, '
             'als vernünftig wirkt.'),
        step('Warm the flatbread directly on the hot oven rack until it puffs.',
             'Das Fladenbrot direkt auf dem heißen Rost erwärmen, bis es sich wölbt.',
             120),
        step('Slice the chicken thinly across the stack. Open the bread, sauce it, '
             'load it, sauce it again, fold, eat standing up.',
             'Das Hähnchen quer zum Stapel dünn abschneiden. Brot öffnen, Sauce '
             'hinein, füllen, nochmal Sauce, falten, im Stehen essen.'),
    ],
    variants=[
        variant('classic', 'classic',
                ('Classic Döner', 'Klassischer Döner'),
                ('Thigh meat, yoghurt marinade, cabbage cut thin enough to be rude.',
                 'Schenkelfleisch, Joghurtmarinade, Kohl so fein geschnitten, dass es fast unhöflich ist.'),
                ('the 2 a.m. version, made at 7 p.m.', 'die Zwei-Uhr-nachts-Variante, um 19 Uhr gekocht'),
                'medium', 55, 780, (48, 62, 34),
                attrs=['high-protein', 'comfort'], tech=['roast', 'pan-fry'],
                tips=[('Freeze the roasted stack for twenty minutes before slicing and '
                       'you get proper thin shavings.',
                       'Den gerösteten Stapel vor dem Schneiden 20 Minuten einfrieren — '
                       'dann gelingen wirklich dünne Späne.')],
                is_base=True),
        variant('vegan', 'vegan',
                ('Vegan Döner', 'Veganer Döner'),
                ('Seitan pressed and roasted the same way, because the technique was '
                 'never the animal.',
                 'Seitan, genauso gepresst und geröstet — die Technik war nie das Tier.'),
                ('nobody at the table can tell. really.', 'niemand am Tisch merkt es. wirklich.'),
                'medium', 50, 610, (39, 68, 19),
                extra_contains=['gluten', 'soy'],
                attrs=['high-protein'], tech=['roast', 'pan-fry'],
                patch=Patch(
                    swap={
                        'chicken-thigh': ing('seitan', 350, 'g', 'torn into strips', 'in Streifen gerissen'),
                        'yoghurt': ing('soy-milk', 80, 'ml', 'for the marinade', 'für die Marinade'),
                        'greek-yoghurt': ing('coconut-yoghurt', 150, 'g', 'thick, unsweetened', 'dick, ungesüßt'),
                    },
                    add=[ing('soy-sauce', 1, 'tbsp'), ing('tahini', 2, 'tbsp', 'loosens the sauce', 'lockert die Sauce')],
                    steps={
                        0: step('Whisk the soy drink, soy sauce, paprika, cumin, one grated '
                                'garlic clove, the oil, salt and pepper. Turn the torn seitan '
                                'through it and let it drink.',
                                'Sojadrink, Sojasauce, Paprikapulver, Kreuzkümmel, eine '
                                'geriebene Knoblauchzehe, Öl, Salz und Pfeffer verquirlen. '
                                'Den gerissenen Seitan darin wenden und ziehen lassen.', 1200),
                        1: step('Heat the oven to 220 °C. Press the seitan into a tight stack '
                                'in a small tin. Same pressure, same shaved edge.',
                                'Ofen auf 220 °C vorheizen. Den Seitan fest in eine kleine Form '
                                'pressen. Gleicher Druck, gleiche Kante.'),
                        2: step('Roast until the top edges go dark and crisp.',
                                'Rösten, bis die Ränder dunkel und knusprig sind.', 1200),
                        4: step('Loosen the coconut yoghurt with the tahini, the remaining '
                                'garlic and half the lemon juice.',
                                'Kokosjoghurt mit Tahin, restlichem Knoblauch und dem Saft '
                                'einer halben Zitrone glatt rühren.'),
                    },
                )),
        variant('halal', 'halal',
                ('Halal-friendly Döner', 'Halal-freundlicher Döner'),
                ('Lamb and beef, no pork anywhere near it, no alcohol in the marinade.',
                 'Lamm und Rind, kein Schwein in der Nähe, kein Alkohol in der Marinade.'),
                ('the way the corner shop back home did it',
                 'so wie beim Imbiss zu Hause'),
                'medium', 60, 760, (46, 60, 36),
                attrs=['high-protein', 'comfort'], tech=['roast'],
                patch=Patch(
                    swap={'chicken-thigh': ing('lamb-mince', 400, 'g', 'coarse, 20 % fat', 'grob, 20 % Fett')},
                    add=[ing('baharat', 2, 'tsp'), ing('onion', 0.5, 'piece', 'grated into the mince', 'in das Hack gerieben')],
                    steps={
                        0: step('Knead the lamb with the yoghurt, baharat, paprika, cumin, '
                                'grated onion, one grated garlic clove, salt and pepper until '
                                'it turns sticky — that stickiness is what holds the stack.',
                                'Das Lamm mit Joghurt, Baharat, Paprikapulver, Kreuzkümmel, '
                                'geriebener Zwiebel, einer geriebenen Knoblauchzehe, Salz und '
                                'Pfeffer kneten, bis es klebrig wird — diese Klebrigkeit hält '
                                'den Stapel zusammen.', 600),
                        1: step('Heat the oven to 200 °C. Pack the mince into a loaf tin, '
                                'pressing out every air pocket.',
                                'Ofen auf 200 °C vorheizen. Das Hack fest in eine Kastenform '
                                'drücken, jede Luftblase heraus.'),
                        2: step('Roast until firm and browned, then rest ten minutes before '
                                'shaving thin slices off the block.',
                                'Rösten, bis fest und gebräunt, dann zehn Minuten ruhen lassen '
                                'und dünne Späne vom Block schneiden.', 2100),
                    },
                )),
        variant('gluten-free', 'gluten-free',
                ('Döner Bowl, gluten-free', 'Döner-Bowl, glutenfrei'),
                ('The bread steps out; rice and the sharp salad carry it instead.',
                 'Das Brot tritt ab; Reis und der scharfe Salat übernehmen.'),
                ('a bowl is just bread with better manners',
                 'eine Bowl ist nur Brot mit besseren Manieren'),
                'easy', 40, 690, (46, 66, 24),
                attrs=['high-protein', 'meal-prep'], tech=['roast'],
                patch=Patch(
                    swap={'flatbread': ing('jasmine-rice', 160, 'g', 'dry weight', 'Trockengewicht')},
                    steps={
                        5: step('Cook the rice while the chicken roasts and fork it through '
                                'with a little of the lemon juice.',
                                'Den Reis kochen, während das Hähnchen röstet, und mit etwas '
                                'Zitronensaft auflockern.', 720),
                        6: step('Rice down first, salad around the edge, sliced chicken on '
                                'top, sauce over everything.',
                                'Zuerst der Reis, Salat am Rand, geschnittenes Hähnchen '
                                'darauf, Sauce über alles.'),
                    },
                )),
        variant('keto', 'keto',
                ('Döner Bowl, low carb', 'Döner-Bowl, Low Carb'),
                ('Same marinade, more salad, the bread traded for a fatter sauce.',
                 'Gleiche Marinade, mehr Salat, das Brot gegen eine fettere Sauce getauscht.'),
                ('turns out the sauce was the point', 'die Sauce war offenbar der Punkt'),
                'easy', 45, 540, (44, 14, 34),
                attrs=['high-protein', 'light-meal'], tech=['roast'],
                patch=Patch(
                    drop=['flatbread'],
                    swap={'white-cabbage': ing('white-cabbage', 250, 'g', 'finely shredded', 'fein gehobelt')},
                    add=[ing('avocado', 1, 'piece'), ing('olive-oil', 1, 'tbsp', 'over the salad', 'über den Salat')],
                    steps={
                        5: step('Skip the bread. Dress the shredded cabbage with the extra '
                                'olive oil and the rest of the lemon; let it sit and soften '
                                'while the chicken rests.',
                                'Kein Brot. Den gehobelten Kohl mit dem zusätzlichen Olivenöl '
                                'und dem restlichen Zitronensaft anmachen; ziehen lassen, '
                                'während das Hähnchen ruht.', 600),
                        6: step('Cabbage in the bowl, chicken and sliced avocado over it, '
                                'sauce spooned on last.',
                                'Kohl in die Schüssel, Hähnchen und Avocadoscheiben darauf, '
                                'zum Schluss die Sauce.'),
                    },
                )),
    ],
))

# ---------------------------------------------------------------------------
# 2. Alfredo
# ---------------------------------------------------------------------------
DISHES.append(dish(
    id='alfredo',
    name=('Spaghetti Alfredo', 'Spaghetti Alfredo'),
    hero=('Butter, cheese, starchy water. Three things pretending to be a sauce.',
          'Butter, Käse, Nudelwasser. Drei Dinge, die so tun, als wären sie eine Sauce.'),
    cap=('emulsion, not cream', 'Emulsion, nicht Sahne'),
    stripe='#D9A441',
    cuisines=['italian'],
    categories=['pasta', 'weeknight', 'comfort'],
    partition='core', secondary=['cuisine-italian'], tier=1,
    slots=['lunch', 'dinner'], servings=2,
    tags=['pasta', 'alfredo', 'parmesan', 'nudeln', 'creamy'],
    base_ing=[
        ing('spaghetti', 200, 'g'),
        ing('butter', 60, 'g', 'cold, cubed', 'kalt, gewürfelt'),
        ing('parmesan', 80, 'g', 'grated on the fine side', 'fein gerieben'),
        ing('pepper', 1, 'tsp', 'coarse', 'grob'),
        ing('salt', 2, 'tsp', 'for the water', 'für das Wasser'),
        ing('nutmeg', 0.25, 'tsp', 'a scrape', 'eine Prise', optional=True),
    ],
    base_steps=[
        step('Bring a wide pan of water to the boil and salt it less than usual — '
             'the cheese brings its own salt.',
             'Eine weite Pfanne Wasser aufkochen und weniger salzen als sonst — '
             'der Käse bringt eigenes Salz mit.'),
        step('Cook the spaghetti two minutes short of the packet time, then lift it '
             'straight into a warm bowl. Keep a mug of the water.',
             'Die Spaghetti zwei Minuten kürzer kochen als angegeben, dann direkt in '
             'eine warme Schüssel heben. Eine Tasse Kochwasser aufheben.', 480),
        step('Add the cold butter to the hot pasta and toss until it disappears.',
             'Die kalte Butter zur heißen Pasta geben und schwenken, bis sie '
             'verschwindet.'),
        step('Add the cheese in three goes, splashing in pasta water between each, '
             'tossing hard. It will look broken, then suddenly it will not.',
             'Den Käse in drei Portionen zugeben, dazwischen jeweils Nudelwasser, '
             'kräftig schwenken. Es sieht erst geronnen aus — und dann plötzlich '
             'nicht mehr.'),
        step('Black pepper, the scrape of nutmeg, and onto plates before it thinks '
             'about cooling.',
             'Schwarzer Pfeffer, die Prise Muskat, und auf die Teller, bevor es ans '
             'Abkühlen denkt.'),
    ],
    variants=[
        variant('classic', 'classic',
                ('Alfredo, the real one', 'Alfredo, der echte'),
                ('No cream. If it needs cream, the emulsion failed.',
                 'Keine Sahne. Wenn Sahne nötig ist, ist die Emulsion gescheitert.'),
                ('toss it like you mean it', 'schwenk es, als würdest du es ernst meinen'),
                'medium', 20, 820, (28, 76, 44),
                attrs=['comfort', 'kid-friendly'], tech=['simmer'],
                tips=[('If it splits, take it off the heat and add a splash of cold '
                       'water while tossing. It comes back.',
                       'Falls es gerinnt: vom Herd nehmen, einen Schuss kaltes Wasser '
                       'zugeben und schwenken. Es kommt zurück.')],
                is_base=True),
        variant('gluten-free', 'gluten-free',
                ('Gluten-free Alfredo', 'Glutenfreier Alfredo'),
                ('Gluten-free pasta gives up more starch, which is a gift here.',
                 'Glutenfreie Pasta gibt mehr Stärke ab — hier ein Geschenk.'),
                ('the starch does half the work', 'die Stärke macht die halbe Arbeit'),
                'medium', 20, 800, (24, 78, 42),
                attrs=['comfort'], tech=['simmer'],
                patch=Patch(
                    swap={'spaghetti': ing('gf-pasta', 200, 'g', 'corn and rice blend holds best',
                                           'Mais-Reis-Mischung hält am besten')},
                    steps={
                        1: step('Cook the gluten-free pasta one minute short. Its water is '
                                'cloudier than wheat water — that is exactly what you want, '
                                'so keep two mugs.',
                                'Die glutenfreie Pasta eine Minute kürzer kochen. Ihr Wasser '
                                'ist trüber als Weizenwasser — genau richtig, also zwei Tassen '
                                'aufheben.', 540),
                    },
                )),
        variant('vegan', 'vegan',
                ('Vegan Alfredo', 'Veganer Alfredo'),
                ('Soaked cashews and nutritional yeast, blitzed until they forget '
                 'they were ever nuts.',
                 'Eingeweichte Cashews und Hefeflocken, so lange gemixt, bis sie '
                 'vergessen, dass sie mal Nüsse waren.'),
                ('the blender is doing the emulsifying now',
                 'jetzt emulgiert der Mixer'),
                'medium', 30, 690, (22, 82, 28),
                extra_contains=['tree-nuts', 'cashews'],
                attrs=['comfort'], tech=['simmer'],
                patch=Patch(
                    swap={
                        'butter': ing('cashews', 90, 'g', 'soaked in hot water 15 min',
                                      '15 Min. in heißem Wasser eingeweicht'),
                        'parmesan': ing('nutritional-yeast', 4, 'tbsp'),
                    },
                    add=[
                        ing('garlic', 1, 'clove'),
                        ing('lemon', 0.5, 'piece', 'juice only', 'nur der Saft'),
                        ing('olive-oil', 2, 'tbsp'),
                    ],
                    steps={
                        2: step('Drain the cashews and blend them with the garlic, nutritional '
                                'yeast, lemon juice, olive oil and 150 ml of the pasta water '
                                'until completely smooth — no grain left at all.',
                                'Die Cashews abgießen und mit Knoblauch, Hefeflocken, '
                                'Zitronensaft, Olivenöl und 150 ml Nudelwasser vollkommen '
                                'glatt mixen — kein Korn darf bleiben.', 120),
                        3: step('Pour the cashew cream over the hot pasta and toss in the pan '
                                'for a minute so it tightens around every strand.',
                                'Die Cashewcreme über die heiße Pasta geben und eine Minute '
                                'in der Pfanne schwenken, damit sie sich um jeden Strang legt.',
                                60),
                    },
                )),
        variant('light', 'light',
                ('Lighter Alfredo', 'Leichterer Alfredo'),
                ('Half the fat, a squeeze of lemon, a fistful of peas. Still counts.',
                 'Halb so viel Fett, ein Spritzer Zitrone, eine Handvoll Erbsen. Zählt trotzdem.'),
                ('a Tuesday alfredo', 'ein Dienstags-Alfredo'),
                'easy', 20, 520, (26, 72, 16),
                attrs=['light-meal', 'kid-friendly'], tech=['simmer'],
                patch=Patch(
                    qty={'butter': 20, 'parmesan': 45},
                    add=[
                        ing('edamame', 120, 'g', 'frozen, straight in', 'gefroren, direkt hinein'),
                        ing('lemon', 0.5, 'piece', 'zest and juice', 'Abrieb und Saft'),
                    ],
                    steps={
                        1: step('Cook the spaghetti two minutes short, throwing the frozen '
                                'edamame in for the last ninety seconds. Lift both out '
                                'together and keep a mug of water.',
                                'Die Spaghetti zwei Minuten kürzer kochen, die gefrorenen '
                                'Edamame die letzten 90 Sekunden dazugeben. Beides zusammen '
                                'herausheben, eine Tasse Wasser aufheben.', 480),
                        4: step('Pepper, lemon zest, a squeeze of the juice. The acid does '
                                'what the missing butter used to.',
                                'Pfeffer, Zitronenabrieb, ein Spritzer Saft. Die Säure macht, '
                                'was sonst die fehlende Butter gemacht hat.'),
                    },
                )),
    ],
))

# ---------------------------------------------------------------------------
# 3. Pad Thai
# ---------------------------------------------------------------------------
DISHES.append(dish(
    id='pad-thai',
    name=('Pad Thai', 'Pad Thai'),
    hero=('Sour, salty, sweet, hot — in that order, argued about forever.',
          'Sauer, salzig, süß, scharf — in dieser Reihenfolge, ewig umstritten.'),
    cap=('wok on, phone off', 'Wok an, Handy aus'),
    stripe='#B85C38',
    cuisines=['thai', 'asian'],
    categories=['noodles', 'weeknight', 'street-food'],
    partition='core', secondary=['cuisine-asian'], tier=1,
    slots=['lunch', 'dinner'], servings=2,
    tags=['noodles', 'wok', 'thai', 'tamarind', 'reisnudeln'],
    base_ing=[
        ing('rice-noodles', 180, 'g', 'flat, 5 mm', 'flach, 5 mm'),
        ing('tamarind', 3, 'tbsp'),
        ing('fish-sauce', 2, 'tbsp'),
        ing('brown-sugar', 2, 'tbsp'),
        ing('egg', 2, 'piece'),
        ing('tofu', 150, 'g', 'pressed, cubed', 'gepresst, gewürfelt'),
        ing('beansprouts', 120, 'g'),
        ing('spring-onion', 3, 'piece'),
        ing('peanuts', 40, 'g', 'crushed', 'grob gehackt'),
        ing('garlic', 2, 'clove'),
        ing('lime', 1, 'piece'),
        ing('rapeseed-oil', 3, 'tbsp'),
        ing('chilli-flakes', 1, 'tsp', optional=True),
    ],
    base_steps=[
        step('Soak the noodles in warm water until bendy but still firm. Drain them '
             'and leave them dry — wet noodles steam instead of frying.',
             'Die Nudeln in warmem Wasser einweichen, bis sie biegsam, aber noch fest '
             'sind. Abgießen und trocken lassen — nasse Nudeln dämpfen statt zu braten.',
             900),
        step('Stir the tamarind, fish sauce and sugar together until the sugar is '
             'gone. Taste it on a spoon: sour first, then salt, then sweet.',
             'Tamarinde, Fischsauce und Zucker verrühren, bis der Zucker weg ist. Vom '
             'Löffel probieren: erst sauer, dann salzig, dann süß.'),
        step('Get the wok properly hot. Fry the tofu in one layer, undisturbed, until '
             'it releases itself from the metal. Push it up the side.',
             'Den Wok richtig heiß werden lassen. Den Tofu in einer Lage braten, ohne '
             'zu rühren, bis er sich vom Metall löst. An den Rand schieben.', 300),
        step('Garlic in, five seconds. Noodles in, sauce over, toss hard for a minute '
             'until every strand is the colour of weak tea.',
             'Knoblauch hinein, fünf Sekunden. Nudeln dazu, Sauce darüber, eine Minute '
             'kräftig schwenken, bis jeder Strang die Farbe von dünnem Tee hat.', 90),
        step('Clear a hole, crack the eggs into it, let them set for ten seconds, '
             'then fold everything through each other.',
             'Eine Lücke schieben, die Eier hineingeben, zehn Sekunden stocken lassen, '
             'dann alles ineinander falten.'),
        step('Beansprouts and spring onion in, off the heat almost immediately. '
             'Peanuts, lime, chilli at the table.',
             'Sprossen und Frühlingszwiebeln dazu, fast sofort vom Herd. Erdnüsse, '
             'Limette, Chili kommen auf den Tisch.'),
    ],
    variants=[
        variant('classic', 'classic',
                ('Pad Thai', 'Pad Thai'),
                ('Tamarind, fish sauce, palm sugar, egg. The four-note chord.',
                 'Tamarinde, Fischsauce, Palmzucker, Ei. Der Vierklang.'),
                ('do not walk away from the wok', 'geh nicht vom Wok weg'),
                'medium', 35, 640, (26, 84, 22),
                attrs=['high-protein'], tech=['stir-fry'],
                tips=[('Cook one portion at a time if your pan is small. Two portions '
                       'in a home wok is how you get noodle soup.',
                       'Bei kleiner Pfanne einzeln portionsweise braten. Zwei Portionen '
                       'im Haushaltswok werden zu Nudelsuppe.')],
                is_base=True),
        variant('vegan', 'vegan',
                ('Vegan Pad Thai', 'Veganes Pad Thai'),
                ('Miso and lime stand in for the fish sauce; the egg becomes more tofu.',
                 'Miso und Limette ersetzen die Fischsauce; das Ei wird zu mehr Tofu.'),
                ('the sour note carries it', 'die saure Note trägt es'),
                'medium', 35, 580, (24, 82, 18),
                attrs=['high-protein'], tech=['stir-fry'],
                patch=Patch(
                    drop=['egg'],
                    swap={
                        'fish-sauce': ing('miso', 2, 'tbsp', 'loosened with 1 tbsp water',
                                          'mit 1 EL Wasser verrührt'),
                        'tofu': ing('tofu', 250, 'g', 'pressed hard, cubed', 'gut gepresst, gewürfelt'),
                    },
                    add=[ing('soy-sauce', 1, 'tbsp')],
                    steps={
                        1: step('Whisk the miso, soy sauce, tamarind and sugar smooth. Taste: '
                                'you are chasing sour-salty, so add lime juice until it stings '
                                'slightly.',
                                'Miso, Sojasauce, Tamarinde und Zucker glatt rühren. Probieren: '
                                'Ziel ist sauer-salzig, also Limettensaft zugeben, bis es leicht '
                                'sticht.'),
                        4: step('No egg here — instead let the noodles sit still for twenty '
                                'seconds so a few catch and caramelise on the pan.',
                                'Kein Ei — stattdessen die Nudeln 20 Sekunden ruhig liegen '
                                'lassen, damit ein paar am Pfannenboden karamellisieren.', 20),
                    },
                )),
        variant('nut-free', 'nut-free',
                ('Nut-free Pad Thai', 'Pad Thai ohne Nüsse'),
                ('Toasted pumpkin seeds do the crunch. Nothing else changes.',
                 'Geröstete Kürbiskerne übernehmen den Crunch. Sonst ändert sich nichts.'),
                ('crunch is a texture, not an ingredient',
                 'Crunch ist eine Textur, keine Zutat'),
                'medium', 35, 600, (25, 84, 18),
                attrs=['kid-friendly'], tech=['stir-fry'],
                patch=Patch(
                    swap={'peanuts': ing('pumpkin-seeds', 40, 'g', 'toasted dry', 'trocken geröstet')},
                    steps_insert=[(0, step('Toast the pumpkin seeds in the dry wok until they '
                                           'start popping, then tip them out and keep them for '
                                           'the end.',
                                           'Die Kürbiskerne im trockenen Wok rösten, bis sie zu '
                                           'springen beginnen, herausnehmen und für den Schluss '
                                           'aufheben.', 180))],
                )),
        variant('pescatarian', 'pescatarian',
                ('Prawn Pad Thai', 'Pad Thai mit Garnelen'),
                ('Prawns go in last and cook in ninety seconds. Longer is a mistake.',
                 'Garnelen kommen zuletzt und brauchen 90 Sekunden. Länger ist ein Fehler.'),
                ('ninety seconds. count them.', 'neunzig Sekunden. zähl mit.'),
                'medium', 35, 660, (36, 80, 20),
                attrs=['high-protein'], tech=['stir-fry'],
                patch=Patch(
                    qty={'tofu': 80},
                    add=[ing('prawns', 200, 'g', 'raw, peeled', 'roh, geschält')],
                    steps={
                        2: step('Get the wok properly hot. Sear the prawns for forty-five '
                                'seconds a side, lift them out while still slightly '
                                'translucent, then fry the tofu in the same oil.',
                                'Den Wok richtig heiß werden lassen. Die Garnelen 45 Sekunden '
                                'pro Seite anbraten, noch leicht glasig herausnehmen, dann den '
                                'Tofu im selben Öl braten.', 90),
                    },
                    steps_append=[step('Return the prawns for the last ten seconds only, just '
                                       'to warm through.',
                                       'Die Garnelen erst in den letzten zehn Sekunden zurück '
                                       'in den Wok geben, nur zum Erwärmen.', 10)],
                )),
    ],
))

# ---------------------------------------------------------------------------
# 4. Shakshuka
# ---------------------------------------------------------------------------
DISHES.append(dish(
    id='shakshuka',
    name=('Shakshuka', 'Schakschuka'),
    hero=('A pan you put on the table with a spoon in it.',
          'Eine Pfanne, die du mit dem Löffel darin auf den Tisch stellst.'),
    cap=('one pan, no plates', 'eine Pfanne, keine Teller'),
    stripe='#C0392B',
    cuisines=['middle-eastern', 'north-african'],
    categories=['brunch', 'one-pan', 'weeknight'],
    partition='core', secondary=['cuisine-middle-eastern'], tier=1,
    slots=['breakfast', 'lunch', 'dinner'], servings=2,
    tags=['eggs', 'tomato', 'brunch', 'eier', 'pfanne'],
    base_ing=[
        ing('olive-oil', 3, 'tbsp'),
        ing('onion', 1, 'piece', 'sliced thin', 'in dünne Streifen'),
        ing('bell-pepper', 1, 'piece', 'red, sliced', 'rot, in Streifen'),
        ing('garlic', 3, 'clove'),
        ing('cumin', 2, 'tsp'),
        ing('paprika-powder', 1, 'tsp'),
        ing('tinned-tomatoes', 400, 'g'),
        ing('egg', 4, 'piece'),
        ing('feta', 60, 'g'),
        ing('parsley', 15, 'g'),
        ing('salt', 1, 'tsp'),
        ing('pepper', 0.5, 'tsp'),
        ing('sourdough', 2, 'piece', 'thick slices, to mop', 'dicke Scheiben, zum Tunken'),
    ],
    base_steps=[
        step('Warm the oil in a wide pan and cook the onion and pepper slowly until '
             'they slump and sweeten. Do not rush this part; it is the whole dish.',
             'Das Öl in einer weiten Pfanne erwärmen und Zwiebel und Paprika langsam '
             'weich und süß werden lassen. Nicht hetzen; das ist das ganze Gericht.',
             720),
        step('Garlic, cumin and paprika in, thirty seconds, until the kitchen smells '
             'like somewhere warmer.',
             'Knoblauch, Kreuzkümmel und Paprika dazu, 30 Sekunden, bis die Küche nach '
             'einem wärmeren Ort riecht.', 30),
        step('Tomatoes in, crushed with the spoon. Season and let it reduce until a '
             'spoon dragged through leaves a trail that stays open.',
             'Tomaten dazu, mit dem Löffel zerdrücken. Würzen und einkochen, bis eine '
             'Spur, die der Löffel zieht, offen bleibt.', 900),
        step('Make four wells. Crack an egg into each, cover the pan, and leave it '
             'alone until the whites are set and the yolks still move.',
             'Vier Mulden formen. In jede ein Ei geben, Pfanne abdecken und in Ruhe '
             'lassen, bis das Eiweiß gestockt ist und das Eigelb noch wackelt.', 420),
        step('Crumble the feta over, scatter parsley, take the whole pan to the table '
             'with the bread.',
             'Feta darüber bröseln, Petersilie darauf, die ganze Pfanne mit dem Brot '
             'auf den Tisch stellen.'),
    ],
    variants=[
        variant('classic', 'classic',
                ('Shakshuka', 'Schakschuka'),
                ('Peppers cooked past patience, eggs barely set, feta on top.',
                 'Paprika über die Geduld hinaus geschmort, Eier kaum gestockt, Feta darauf.'),
                ('the yolk should still be nervous', 'das Eigelb soll noch nervös sein'),
                'easy', 40, 380, (20, 26, 22),
                attrs=['one-pot', 'comfort'], tech=['simmer'],
                tips=[('A lid is not optional. Without it the tops of the eggs stay raw '
                       'while the bottoms go rubbery.',
                       'Ein Deckel ist Pflicht. Ohne ihn bleibt das Ei oben roh und wird '
                       'unten gummiartig.')],
                is_base=True),
        variant('vegan', 'vegan',
                ('Vegan Shakshuka', 'Vegane Schakschuka'),
                ('Chickpeas take the eggs’ place; the sauce never noticed.',
                 'Kichererbsen übernehmen die Rolle der Eier; die Sauce merkt nichts.'),
                ('same pan, same spoon, same table', 'gleiche Pfanne, gleicher Löffel, gleicher Tisch'),
                'easy', 35, 340, (14, 42, 12),
                attrs=['one-pot', 'budget'], tech=['simmer'],
                patch=Patch(
                    drop=['egg'],
                    swap={'feta': ing('vegan-cheese', 60, 'g', 'the crumbly kind', 'die krümelige Sorte')},
                    add=[
                        ing('chickpeas', 240, 'g', 'drained', 'abgetropft'),
                        ing('tahini', 2, 'tbsp', 'drizzled at the end', 'zum Schluss darüber'),
                    ],
                    steps={
                        3: step('Stir the chickpeas through and press them half under the '
                                'surface. Simmer uncovered so they take on the sauce.',
                                'Die Kichererbsen unterrühren und halb unter die Oberfläche '
                                'drücken. Offen köcheln lassen, damit sie die Sauce aufnehmen.',
                                480),
                        4: step('Crumble the vegan cheese over, zigzag the tahini across, '
                                'parsley, table.',
                                'Veganen Käse darüber bröseln, Tahin im Zickzack darüber, '
                                'Petersilie, Tisch.'),
                    },
                )),
        variant('low-fodmap', 'low-fodmap',
                ('Gentle Shakshuka', 'Sanfte Schakschuka'),
                ('Garlic oil instead of garlic, leek greens instead of onion. The '
                 'flavour stays, the ache does not.',
                 'Knoblauchöl statt Knoblauch, Lauchgrün statt Zwiebel. Der Geschmack '
                 'bleibt, das Ziehen nicht.'),
                ('your gut gets a say too', 'dein Darm redet auch mit'),
                'easy', 40, 360, (19, 24, 21),
                attrs=['one-pot', 'light-meal'], tech=['simmer'],
                patch=Patch(
                    drop=['onion', 'garlic'],
                    swap={'sourdough': ing('gf-bread', 2, 'piece', 'toasted hard', 'kräftig getoastet')},
                    add=[ing('leek-greens', 1, 'piece', 'green tops only', 'nur das Grün'),
                         ing('olive-oil', 1, 'tbsp', 'garlic-infused', 'mit Knoblauch aromatisiert')],
                    steps={
                        0: step('Warm both oils in a wide pan and cook the green leek tops and '
                                'the pepper slowly until soft. The garlic-infused oil carries '
                                'the flavour without the fructans.',
                                'Beide Öle in einer weiten Pfanne erwärmen und das Lauchgrün '
                                'mit der Paprika langsam weich schmoren. Das Knoblauchöl bringt '
                                'den Geschmack ohne die Fruktane.', 600),
                        1: step('Cumin and paprika in, thirty seconds.',
                                'Kreuzkümmel und Paprika dazu, 30 Sekunden.', 30),
                    },
                )),
        variant('keto', 'keto',
                ('Shakshuka, low carb', 'Schakschuka, Low Carb'),
                ('More egg, more cheese, spinach folded through, no bread on the side.',
                 'Mehr Ei, mehr Käse, Spinat untergehoben, kein Brot dazu.'),
                ('the pan is the plate', 'die Pfanne ist der Teller'),
                'medium', 40, 520, (30, 16, 38),
                attrs=['high-protein', 'one-pot'], tech=['simmer'],
                patch=Patch(
                    drop=['sourdough'],
                    qty={'egg': 6, 'feta': 100},
                    add=[ing('spinach', 150, 'g'), ing('olive-oil', 1, 'tbsp')],
                    steps={
                        2: step('Tomatoes in, crushed. Season and reduce hard — you want it '
                                'thicker than usual with no bread to soak it up. Fold the '
                                'spinach through at the end and let it collapse.',
                                'Tomaten dazu, zerdrücken. Würzen und kräftig einkochen — ohne '
                                'Brot darf es dicker sein als sonst. Zum Schluss den Spinat '
                                'unterheben und zusammenfallen lassen.', 900),
                    },
                )),
    ],
))

# ---------------------------------------------------------------------------
# 5. Burger
# ---------------------------------------------------------------------------
DISHES.append(dish(
    id='burger',
    name=('Burger', 'Burger'),
    hero=('Coarse mince, a screaming pan, and the discipline not to press it.',
          'Grobes Hack, eine kreischend heiße Pfanne und die Disziplin, nicht zu drücken.'),
    cap=('do not press the patty', 'nicht auf das Patty drücken'),
    stripe='#8C4A2F',
    cuisines=['american'],
    categories=['handheld', 'weekend', 'grill'],
    partition='core', secondary=[], tier=1,
    slots=['lunch', 'dinner'], servings=2,
    tags=['burger', 'patty', 'brioche', 'grill', 'hack'],
    base_ing=[
        ing('beef-mince', 400, 'g', '20 % fat, coarse', '20 % Fett, grob'),
        ing('burger-bun', 2, 'piece', 'brioche if you can', 'wenn möglich Brioche'),
        ing('cheddar', 60, 'g', 'two thin slices', 'zwei dünne Scheiben'),
        ing('onion', 1, 'piece', 'half raw, half for the pan', 'halb roh, halb für die Pfanne'),
        ing('gherkins', 40, 'g'),
        ing('tomato', 1, 'piece'),
        ing('romaine', 2, 'piece', 'inner leaves', 'innere Blätter'),
        ing('mayonnaise', 3, 'tbsp'),
        ing('ketchup', 1, 'tbsp'),
        ing('mustard-condiment', 1, 'tsp'),
        ing('butter', 15, 'g', 'for the buns', 'für die Buns'),
        ing('salt', 1, 'tsp'),
        ing('pepper', 0.5, 'tsp'),
    ],
    base_steps=[
        step('Divide the mince into two loose balls. Do not knead it, do not season '
             'it yet — salt inside the meat makes it bouncy.',
             'Das Hack in zwei lockere Kugeln teilen. Nicht kneten, noch nicht würzen '
             '— Salz im Fleisch macht es gummiartig.'),
        step('Stir the mayo, ketchup and mustard together with a spoonful of chopped '
             'gherkin. That is the sauce; there is no secret.',
             'Mayo, Ketchup und Senf mit einem Löffel gehackter Gewürzgurke verrühren. '
             'Das ist die Sauce; es gibt kein Geheimnis.'),
        step('Butter the cut sides of the buns and toast them face down in a dry pan '
             'until properly brown.',
             'Die Schnittflächen der Buns buttern und in einer trockenen Pfanne mit '
             'der Fläche nach unten kräftig bräunen.', 120),
        step('Get a heavy pan very hot. Salt the outside of the balls, put them in, '
             'and press once — hard, flat, for ten seconds. Then never again.',
             'Eine schwere Pfanne sehr heiß werden lassen. Die Kugeln außen salzen, '
             'hineinlegen und einmal drücken — fest, flach, zehn Sekunden. Danach nie '
             'wieder.', 10),
        step('Two minutes, flip, cheese on, lid on for thirty seconds so the cheese '
             'gives up.',
             'Zwei Minuten, wenden, Käse darauf, Deckel für 30 Sekunden drauf, damit '
             'der Käse aufgibt.', 150),
        step('Sauce on both halves, lettuce as a raincoat under the patty, tomato and '
             'raw onion on top, lid, press gently, eat immediately.',
             'Sauce auf beide Hälften, Salat als Regenjacke unter das Patty, Tomate '
             'und rohe Zwiebel darauf, Deckel drauf, sanft drücken, sofort essen.'),
    ],
    variants=[
        variant('classic', 'classic',
                ('Smash Burger', 'Smash Burger'),
                ('Pressed once, flipped once, cheese melted under a lid.',
                 'Einmal gedrückt, einmal gewendet, Käse unter dem Deckel geschmolzen.'),
                ('the crust is the point', 'die Kruste ist der Punkt'),
                'medium', 25, 890, (46, 52, 54),
                attrs=['high-protein', 'comfort'], tech=['pan-fry'],
                tips=[('Your extractor fan will not be enough. Open a window before you '
                       'start, not after.',
                       'Die Dunstabzugshaube reicht nicht. Fenster vorher öffnen, nicht '
                       'hinterher.')],
                is_base=True),
        variant('vegan', 'vegan',
                ('Vegan Burger', 'Veganer Burger'),
                ('Pea protein mince behaves almost identically — it just needs a '
                 'hotter pan and less time.',
                 'Erbsenprotein-Hack verhält sich fast identisch — es braucht nur eine '
                 'heißere Pfanne und weniger Zeit.'),
                ('same press, same crust', 'gleicher Druck, gleiche Kruste'),
                'medium', 25, 700, (34, 58, 34),
                attrs=['high-protein'], tech=['pan-fry'],
                patch=Patch(
                    swap={
                        'beef-mince': ing('pea-protein-mince', 400, 'g'),
                        'cheddar': ing('vegan-cheese', 60, 'g', 'meltable slices', 'schmelzende Scheiben'),
                        'mayonnaise': ing('vegan-mayo', 3, 'tbsp'),
                        'butter': ing('vegan-butter', 15, 'g', 'for the buns', 'für die Buns'),
                        'burger-bun': ing('burger-bun', 2, 'piece', 'check for egg wash', 'auf Eistreiche achten'),
                    },
                    steps={
                        4: step('Ninety seconds, flip, cheese on, lid on for a minute. Plant '
                                'mince dries out faster than beef, so err short.',
                                '90 Sekunden, wenden, Käse darauf, Deckel für eine Minute. '
                                'Pflanzliches Hack trocknet schneller aus als Rind — lieber '
                                'kürzer.', 150),
                    },
                )),
        variant('gluten-free', 'gluten-free',
                ('Gluten-free Burger', 'Glutenfreier Burger'),
                ('Gluten-free buns need more butter and more heat, otherwise they '
                 'crumble on the second bite.',
                 'Glutenfreie Buns brauchen mehr Butter und mehr Hitze, sonst zerfallen '
                 'sie beim zweiten Biss.'),
                ('toast it harder than feels right', 'toaste es kräftiger als es sich richtig anfühlt'),
                'medium', 25, 830, (44, 46, 52),
                attrs=['high-protein'], tech=['pan-fry'],
                patch=Patch(
                    swap={'burger-bun': ing('gf-bread', 2, 'piece', 'burger-shaped, halved', 'burgerförmig, halbiert')},
                    qty={'butter': 25},
                    steps={
                        2: step('Butter the cut sides generously and toast them face down '
                                'until they are dark and genuinely crisp — gluten-free crumb '
                                'needs that crust to hold a burger.',
                                'Die Schnittflächen großzügig buttern und mit der Fläche nach '
                                'unten dunkel und wirklich knusprig rösten — glutenfreie Krume '
                                'braucht diese Kruste, um einen Burger zu tragen.', 180),
                    },
                )),
        variant('halal', 'halal',
                ('Halal-friendly Burger', 'Halal-freundlicher Burger'),
                ('Beef only, no bacon, no beer in the sauce, buns checked for lard.',
                 'Nur Rind, kein Speck, kein Bier in der Sauce, Buns auf Schmalz geprüft.'),
                ('read the bun label. always the bun.', 'lies das Etikett der Buns. immer die Buns.'),
                'medium', 25, 870, (46, 52, 52),
                attrs=['high-protein'], tech=['pan-fry'],
                patch=Patch(
                    swap={'mayonnaise': ing('mayonnaise', 3, 'tbsp', 'check it uses no wine vinegar',
                                            'ohne Weinessig wählen')},
                    add=[ing('sumac', 1, 'tsp', 'over the raw onion', 'über die rohe Zwiebel')],
                    steps_append=[step('Toss the raw onion slices with the sumac before they go '
                                       'on. It gives the sourness that the pickle brine used to.',
                                       'Die rohen Zwiebelringe vor dem Auflegen mit Sumach '
                                       'mischen. Das bringt die Säure, die sonst die '
                                       'Gurkenlake liefert.')],
                )),
    ],
))

# ---------------------------------------------------------------------------
# 6. Pancakes
# ---------------------------------------------------------------------------
DISHES.append(dish(
    id='pancakes',
    name=('Pancakes', 'Pancakes'),
    hero=('Lumpy batter, rested. Smooth batter makes flat, sad discs.',
          'Klumpiger Teig, geruht. Glatter Teig ergibt flache, traurige Scheiben.'),
    cap=('leave the lumps alone', 'lass die Klumpen in Ruhe'),
    stripe='#D2A15C',
    cuisines=['american'],
    categories=['breakfast', 'weekend', 'baking'],
    partition='core', secondary=[], tier=1,
    slots=['breakfast', 'dessert'], servings=2,
    tags=['pancakes', 'breakfast', 'frühstück', 'maple', 'fluffy'],
    base_ing=[
        ing('flour', 200, 'g'),
        ing('baking-powder', 2, 'tsp'),
        ing('sugar', 2, 'tbsp'),
        ing('salt', 0.5, 'tsp'),
        ing('whole-milk', 250, 'ml'),
        ing('egg', 1, 'piece'),
        ing('butter', 40, 'g', 'melted, plus more for the pan', 'geschmolzen, plus mehr für die Pfanne'),
        ing('maple-syrup', 4, 'tbsp', 'to serve', 'zum Servieren'),
        ing('blueberries', 100, 'g', optional=True),
    ],
    base_steps=[
        step('Whisk the flour, baking powder, sugar and salt in one bowl.',
             'Mehl, Backpulver, Zucker und Salz in einer Schüssel verquirlen.'),
        step('Beat the milk, egg and melted butter in another.',
             'Milch, Ei und geschmolzene Butter in einer zweiten verquirlen.'),
        step('Pour wet into dry and stir about ten times. Stop while it still looks '
             'wrong — lumps are structure.',
             'Flüssiges ins Trockene gießen und etwa zehnmal rühren. Aufhören, solange '
             'es noch falsch aussieht — Klumpen sind Struktur.'),
        step('Rest the batter. This is not optional; it is where the fluff comes from.',
             'Den Teig ruhen lassen. Nicht optional; daher kommt die Fluffigkeit.', 900),
        step('Medium-low heat, a scrape of butter, a small ladle per pancake. Flip '
             'when the bubbles at the edge stay open.',
             'Mittlere bis niedrige Hitze, ein Hauch Butter, eine kleine Kelle pro '
             'Pancake. Wenden, wenn die Blasen am Rand offen bleiben.', 180),
        step('Stack them, syrup, berries, do not photograph the last one.',
             'Stapeln, Sirup, Beeren, den letzten nicht fotografieren.'),
    ],
    variants=[
        variant('classic', 'classic',
                ('Buttermilk-style Pancakes', 'Pancakes nach Buttermilch-Art'),
                ('Rested batter, medium-low pan, patience measured in bubbles.',
                 'Geruhter Teig, mittlere Hitze, Geduld gemessen in Blasen.'),
                ('the first one is always a sacrifice', 'der erste ist immer ein Opfer'),
                'easy', 30, 480, (13, 68, 18),
                attrs=['kid-friendly', 'comfort'], tech=['pan-fry'],
                is_base=True),
        variant('vegan', 'vegan',
                ('Vegan Pancakes', 'Vegane Pancakes'),
                ('Flax egg and oat drink. A splash of vinegar wakes the baking powder up.',
                 'Leinsamen-Ei und Haferdrink. Ein Schuss Essig weckt das Backpulver.'),
                ('vinegar is the trick, honestly', 'der Essig ist der Trick, ehrlich'),
                'easy', 30, 430, (9, 70, 12),
                attrs=['kid-friendly'], tech=['pan-fry'],
                patch=Patch(
                    swap={
                        'egg': ing('flaxseed', 1, 'tbsp', 'in 3 tbsp water, 5 min', 'in 3 EL Wasser, 5 Min.'),
                        'whole-milk': ing('oat-milk', 260, 'ml'),
                        'butter': ing('vegan-butter', 40, 'g', 'melted', 'geschmolzen'),
                    },
                    add=[ing('vinegar', 1, 'tsp')],
                    steps={
                        1: step('Stir the flaxseed into three tablespoons of water and leave it '
                                'to gel. Then beat it with the oat drink, melted vegan butter '
                                'and the vinegar.',
                                'Die Leinsamen in drei Esslöffel Wasser rühren und gelieren '
                                'lassen. Dann mit Haferdrink, geschmolzener veganer Butter und '
                                'dem Essig verquirlen.', 300),
                    },
                )),
        variant('gluten-free', 'gluten-free',
                ('Gluten-free Pancakes', 'Glutenfreie Pancakes'),
                ('Gluten-free flour needs a longer rest and a wetter batter. Give it both.',
                 'Glutenfreies Mehl braucht längere Ruhe und einen feuchteren Teig. Gib ihm beides.'),
                ('twenty minutes, not ten', 'zwanzig Minuten, nicht zehn'),
                'easy', 35, 460, (11, 70, 15),
                attrs=['kid-friendly'], tech=['pan-fry'],
                patch=Patch(
                    swap={'flour': ing('gf-flour', 200, 'g', 'with xanthan', 'mit Xanthan')},
                    qty={'whole-milk': 290},
                    steps={
                        3: step('Rest the batter twice as long as you would wheat. Gluten-free '
                                'flour drinks slowly, and an under-rested batter fries gritty.',
                                'Den Teig doppelt so lang ruhen lassen wie Weizenteig. '
                                'Glutenfreies Mehl trinkt langsam; zu kurz geruht wird es '
                                'sandig.', 1200),
                    },
                )),
        variant('sugar-free', 'sugar-free',
                ('Protein Pancakes, no added sugar', 'Protein-Pancakes ohne Zuckerzusatz'),
                ('Mashed banana for sweetness, oats for body, no syrup needed.',
                 'Zerdrückte Banane für die Süße, Haferflocken für Substanz, kein Sirup nötig.'),
                ('the banana was always enough', 'die Banane hat immer gereicht'),
                'easy', 25, 390, (22, 48, 12),
                attrs=['high-protein', 'light-meal'], tech=['pan-fry'],
                patch=Patch(
                    drop=['sugar', 'maple-syrup'],
                    swap={'flour': ing('oats', 120, 'g', 'blitzed to flour', 'zu Mehl gemahlen')},
                    add=[ing('banana', 2, 'piece', 'very ripe, mashed', 'sehr reif, zerdrückt'),
                         ing('cinnamon', 1, 'tsp')],
                    qty={'egg': 2, 'whole-milk': 180},
                    steps={
                        0: step('Blitz the oats to a rough flour and whisk them with the baking '
                                'powder, cinnamon and salt.',
                                'Die Haferflocken grob zu Mehl mahlen und mit Backpulver, Zimt '
                                'und Salz verrühren.'),
                        1: step('Mash the bananas until almost liquid, then beat in the eggs, '
                                'milk and melted butter.',
                                'Die Bananen fast flüssig zerdrücken, dann Eier, Milch und '
                                'geschmolzene Butter unterrühren.'),
                        5: step('Stack them and eat as they are — ripe banana already did the '
                                'sweetening.',
                                'Stapeln und so essen — die reife Banane hat schon gesüßt.'),
                    },
                )),
    ],
))

# ---------------------------------------------------------------------------
# 7. Porridge
# ---------------------------------------------------------------------------
DISHES.append(dish(
    id='porridge',
    name=('Porridge', 'Porridge'),
    hero=('The most forgiving thing you can cook before you are properly awake.',
          'Das nachsichtigste Gericht, das du kochen kannst, bevor du wach bist.'),
    cap=('stir with a wooden spoon, always', 'immer mit dem Holzlöffel rühren'),
    stripe='#B99A6B',
    cuisines=['british', 'nordic'],
    categories=['breakfast', 'budget', 'quick'],
    partition='core', secondary=[], tier=1,
    slots=['breakfast'], servings=2,
    tags=['oats', 'breakfast', 'haferbrei', 'frühstück', 'warm'],
    base_ing=[
        ing('oats', 100, 'g', 'rolled, not instant', 'kernig, nicht Instant'),
        ing('whole-milk', 400, 'ml'),
        ing('salt', 0.25, 'tsp'),
        ing('cinnamon', 0.5, 'tsp'),
        ing('banana', 1, 'piece'),
        ing('walnuts', 25, 'g', 'toasted, broken', 'geröstet, gebrochen'),
        ing('maple-syrup', 1, 'tbsp'),
    ],
    base_steps=[
        step('Tip the oats, milk and salt into a small pan over medium heat.',
             'Haferflocken, Milch und Salz in einen kleinen Topf bei mittlerer Hitze geben.'),
        step('Stir slowly and constantly. The stirring is what makes it creamy — '
             'nothing else does.',
             'Langsam und stetig rühren. Das Rühren macht es cremig — sonst nichts.', 480),
        step('When it holds a soft ridge behind the spoon, take it off and let it sit '
             'for a minute; it thickens more off the heat than on it.',
             'Wenn der Löffel eine weiche Spur hinterlässt, vom Herd nehmen und eine '
             'Minute stehen lassen; es dickt außerhalb der Hitze stärker nach.', 60),
        step('Cinnamon in, sliced banana on, walnuts and syrup over.',
             'Zimt hinein, Bananenscheiben darauf, Walnüsse und Sirup darüber.'),
    ],
    variants=[
        variant('classic', 'classic',
                ('Creamy Porridge', 'Cremiger Porridge'),
                ('Oats, milk, salt, and eight minutes of slow stirring.',
                 'Haferflocken, Milch, Salz und acht Minuten langsames Rühren.'),
                ('salt in porridge is not optional', 'Salz im Porridge ist nicht optional'),
                'easy', 12, 380, (14, 52, 13),
                attrs=['budget', 'comfort', 'kid-friendly'], tech=['simmer'],
                is_base=True),
        variant('vegan', 'vegan',
                ('Vegan Porridge', 'Veganer Porridge'),
                ('Oat drink on oats. Circular, and better than it sounds.',
                 'Haferdrink auf Hafer. Zirkulär, und besser als es klingt.'),
                ('a spoon of tahini makes it rich', 'ein Löffel Tahin macht ihn reich'),
                'easy', 12, 360, (10, 56, 11),
                attrs=['budget', 'comfort'], tech=['simmer'],
                patch=Patch(
                    swap={
                        'whole-milk': ing('oat-milk', 400, 'ml'),
                        'maple-syrup': ing('maple-syrup', 1, 'tbsp'),
                    },
                    add=[ing('tahini', 1, 'tbsp', 'stirred in at the end', 'zum Schluss unterrühren')],
                    steps={
                        2: step('Off the heat, stir in the tahini. It replaces the fat the '
                                'dairy was carrying and makes the whole bowl taste older and '
                                'more serious.',
                                'Vom Herd nehmen und das Tahin unterrühren. Es ersetzt das Fett '
                                'der Milch und lässt die ganze Schüssel älter und ernster '
                                'schmecken.'),
                    },
                )),
        variant('gluten-free', 'gluten-free',
                ('Gluten-free Porridge', 'Glutenfreier Porridge'),
                ('Certified gluten-free oats. Ordinary oats are cross-contaminated '
                 'more often than not.',
                 'Zertifiziert glutenfreie Haferflocken. Normaler Hafer ist häufiger '
                 'kontaminiert als nicht.'),
                ('check the packet, not the grain', 'prüf die Packung, nicht das Korn'),
                'easy', 12, 370, (13, 52, 13),
                attrs=['budget'], tech=['simmer'],
                patch=Patch(
                    swap={'oats': ing('gf-oats', 100, 'g', 'certified', 'zertifiziert')},
                )),
        variant('high-protein', 'classic',
                ('Protein Porridge', 'Protein-Porridge'),
                ('Greek yoghurt folded in off the heat, so it stays thick instead of '
                 'splitting.',
                 'Griechischer Joghurt außerhalb der Hitze untergehoben, damit er dick '
                 'bleibt statt zu gerinnen.'),
                ('never boil yoghurt. ever.', 'Joghurt niemals kochen. nie.'),
                'easy', 14, 470, (28, 50, 16),
                attrs=['high-protein', 'meal-prep'], tech=['simmer'],
                patch=Patch(
                    qty={'whole-milk': 300},
                    add=[ing('greek-yoghurt', 150, 'g', 'folded in off the heat',
                             'außerhalb der Hitze unterheben'),
                         ing('pumpkin-seeds', 20, 'g')],
                    steps={
                        2: step('Take the pan off the heat, wait thirty seconds, then fold the '
                                'yoghurt through. Heat it further and it will curdle.',
                                'Den Topf vom Herd nehmen, 30 Sekunden warten, dann den Joghurt '
                                'unterheben. Weiter erhitzt gerinnt er.', 30),
                    },
                )),
    ],
))

# ---------------------------------------------------------------------------
# 8. Caesar Salad
# ---------------------------------------------------------------------------
DISHES.append(dish(
    id='caesar-salad',
    name=('Caesar Salad', 'Caesar Salad'),
    hero=('A salad that is really a dressing with lettuce as a delivery system.',
          'Ein Salat, der eigentlich ein Dressing ist — mit Salat als Transportmittel.'),
    cap=('anchovy is not optional', 'Sardelle ist nicht optional'),
    stripe='#7E8C4A',
    cuisines=['american', 'italian'],
    categories=['salad', 'quick', 'lunch'],
    partition='core', secondary=[], tier=1,
    slots=['lunch', 'dinner'], servings=2,
    tags=['salad', 'caesar', 'croutons', 'salat', 'parmesan'],
    base_ing=[
        ing('romaine', 2, 'piece', 'cold, torn by hand', 'kalt, mit der Hand gerissen'),
        ing('sourdough', 2, 'piece', 'torn into rough cubes', 'in grobe Würfel gerissen'),
        ing('olive-oil', 4, 'tbsp'),
        ing('garlic', 1, 'clove'),
        ing('anchovy', 4, 'piece', 'in oil', 'in Öl'),
        ing('egg-yolk', 1, 'piece'),
        ing('mustard-condiment', 1, 'tsp'),
        ing('lemon', 1, 'piece'),
        ing('parmesan', 50, 'g'),
        ing('pepper', 1, 'tsp'),
        ing('worcestershire', 1, 'tsp'),
    ],
    base_steps=[
        step('Toss the torn bread with half the oil and a pinch of salt and bake at '
             '200 °C until dark gold and hollow-sounding.',
             'Das gerissene Brot mit der Hälfte des Öls und einer Prise Salz mischen '
             'und bei 200 °C backen, bis es dunkelgolden ist und hohl klingt.', 720),
        step('Mash the anchovies and garlic to a paste with the flat of a knife.',
             'Sardellen und Knoblauch mit der Messerklinge zu einer Paste zerdrücken.'),
        step('Whisk in the yolk, mustard and Worcestershire, then trickle in the rest '
             'of the oil while whisking until it thickens like a thin mayonnaise.',
             'Eigelb, Senf und Worcestersauce unterrühren, dann das restliche Öl '
             'langsam einrühren, bis es wie dünne Mayonnaise andickt.', 180),
        step('Lemon juice and most of the parmesan in. Taste: it should be almost too '
             'salty on its own.',
             'Zitronensaft und den meisten Parmesan dazu. Abschmecken: allein sollte '
             'es fast zu salzig sein.'),
        step('Toss the cold lettuce through the dressing with your hands. Croutons '
             'last, remaining parmesan and a lot of pepper on top.',
             'Den kalten Salat mit den Händen im Dressing wenden. Croûtons zuletzt, '
             'restlicher Parmesan und viel Pfeffer darüber.'),
    ],
    variants=[
        variant('classic', 'classic',
                ('Caesar Salad', 'Caesar Salad'),
                ('Raw yolk, anchovy, real parmesan, croutons torn not cut.',
                 'Rohes Eigelb, Sardelle, echter Parmesan, gerissene statt geschnittene Croûtons.'),
                ('cold leaves, room-temp dressing', 'kalte Blätter, Dressing bei Zimmertemperatur'),
                'easy', 25, 560, (18, 28, 42),
                attrs=['light-meal'], tech=['bake', 'raw'],
                tips=[('Use pasteurised yolk if you are pregnant or feeding anyone '
                       'immunocompromised.',
                       'Pasteurisiertes Eigelb verwenden, wenn du schwanger bist oder '
                       'immungeschwächte Menschen mitisst.')],
                is_base=True),
        variant('vegan', 'vegan',
                ('Vegan Caesar', 'Veganer Caesar'),
                ('Capers and miso replace the anchovy; cashews replace the yolk. The '
                 'salt-and-funk axis survives.',
                 'Kapern und Miso ersetzen die Sardelle; Cashews das Eigelb. Die Achse '
                 'aus Salz und Funk überlebt.'),
                ('funk is the flavour you are missing', 'Funk ist der Geschmack, der dir fehlt'),
                'medium', 30, 430, (12, 32, 28),
                extra_contains=['tree-nuts', 'cashews', 'soy'],
                attrs=['light-meal'], tech=['bake', 'raw'],
                patch=Patch(
                    drop=['egg-yolk', 'anchovy', 'worcestershire'],
                    swap={'parmesan': ing('nutritional-yeast', 3, 'tbsp')},
                    add=[
                        ing('cashews', 70, 'g', 'soaked 15 min in hot water', '15 Min. in heißem Wasser eingeweicht'),
                        ing('olives', 30, 'g', 'black, for the salt', 'schwarz, für das Salz'),
                        ing('miso', 1, 'tbsp'),
                    ],
                    steps={
                        1: step('Chop the olives and garlic very fine and mash them with the '
                                'miso — that trio is doing the anchovy’s job.',
                                'Oliven und Knoblauch sehr fein hacken und mit dem Miso '
                                'zerdrücken — dieses Trio übernimmt die Rolle der Sardelle.'),
                        2: step('Blend the soaked cashews with the mustard, 4 tbsp water and '
                                'the oil until glossy and thick, then stir the olive-miso '
                                'paste through.',
                                'Die eingeweichten Cashews mit Senf, 4 EL Wasser und dem Öl '
                                'glänzend und dick mixen, dann die Oliven-Miso-Paste '
                                'unterrühren.', 120),
                    },
                )),
        variant('gluten-free', 'gluten-free',
                ('Gluten-free Caesar', 'Glutenfreier Caesar'),
                ('Chickpeas roasted hard take the croutons’ job and do it better.',
                 'Kräftig geröstete Kichererbsen übernehmen die Rolle der Croûtons — besser sogar.'),
                ('crunchier than bread ever was', 'knuspriger als Brot es je war'),
                'easy', 35, 520, (20, 30, 34),
                attrs=['light-meal', 'high-protein'], tech=['bake', 'raw'],
                patch=Patch(
                    swap={'sourdough': ing('chickpeas', 240, 'g', 'drained and dried well',
                                           'abgetropft und gut getrocknet')},
                    steps={
                        0: step('Toss the dried chickpeas with half the oil, salt and pepper '
                                'and roast at 200 °C, shaking twice, until they rattle in the '
                                'tin and split slightly.',
                                'Die getrockneten Kichererbsen mit der Hälfte des Öls, Salz und '
                                'Pfeffer mischen und bei 200 °C rösten, zweimal schütteln, bis '
                                'sie im Blech klappern und leicht aufplatzen.', 1800),
                    },
                )),
        variant('light', 'light',
                ('Light Caesar', 'Leichter Caesar'),
                ('Yoghurt base instead of an oil emulsion. Sharper, thinner, still '
                 'unmistakably Caesar.',
                 'Joghurtbasis statt Ölemulsion. Schärfer, dünner, unverkennbar Caesar.'),
                ('lunch you can work after', 'Mittagessen, nach dem du noch arbeiten kannst'),
                'easy', 20, 320, (20, 24, 16),
                attrs=['light-meal', 'high-protein'], tech=['bake', 'raw'],
                patch=Patch(
                    drop=['egg-yolk'],
                    qty={'olive-oil': 1, 'parmesan': 30},
                    add=[ing('greek-yoghurt', 150, 'g')],
                    steps={
                        2: step('Whisk the yoghurt with the mustard, Worcestershire and the '
                                'anchovy paste. No emulsion to break, so it will not split.',
                                'Den Joghurt mit Senf, Worcestersauce und der Sardellenpaste '
                                'verrühren. Keine Emulsion, die brechen könnte.'),
                    },
                )),
    ],
))

# ---------------------------------------------------------------------------
# 9. Pizza Margherita
# ---------------------------------------------------------------------------
DISHES.append(dish(
    id='pizza-margherita',
    name=('Pizza Margherita', 'Pizza Margherita'),
    hero=('Three toppings. Everything else is oven temperature and time.',
          'Drei Beläge. Alles andere ist Ofentemperatur und Zeit.'),
    cap=('hotter. no, hotter.', 'heißer. nein, heißer.'),
    stripe='#A8322D',
    cuisines=['italian'],
    categories=['baking', 'weekend', 'comfort'],
    partition='core', secondary=['cuisine-italian'], tier=1,
    slots=['lunch', 'dinner'], servings=2,
    tags=['pizza', 'dough', 'teig', 'mozzarella', 'basil'],
    base_ing=[
        ing('bread-flour', 320, 'g'),
        ing('yeast-dry', 3, 'g'),
        ing('salt', 8, 'g'),
        ing('olive-oil', 2, 'tbsp'),
        ing('tinned-tomatoes', 250, 'g', 'best you can find, crushed by hand',
            'die besten, die du findest, mit der Hand zerdrückt'),
        ing('mozzarella', 200, 'g', 'drained an hour, torn', 'eine Stunde abgetropft, gerissen'),
        ing('basil', 10, 'g'),
        ing('parmesan', 20, 'g', optional=True),
    ],
    base_steps=[
        step('Mix the flour, yeast, salt and 210 ml cold water into a shaggy mess. '
             'Leave it twenty minutes before you touch it again.',
             'Mehl, Hefe, Salz und 210 ml kaltes Wasser zu einer zottigen Masse mischen. '
             'Zwanzig Minuten liegen lassen, bevor du sie wieder anfasst.', 1200),
        step('Fold the dough over itself four times in the bowl, rest ten minutes, '
             'repeat three more rounds. No kneading required.',
             'Den Teig in der Schüssel viermal über sich falten, zehn Minuten ruhen, '
             'drei weitere Runden. Kein Kneten nötig.', 1800),
        step('Cover and leave to rise until doubled, then divide into two balls and '
             'let them relax, seam down.',
             'Abgedeckt gehen lassen, bis sich das Volumen verdoppelt hat, in zwei '
             'Kugeln teilen und mit dem Schluss nach unten entspannen lassen.', 5400),
        step('Put a heavy tray or stone on the top shelf and heat the oven as high as '
             'it will go for a full thirty minutes. Domestic ovens need the whole time.',
             'Ein schweres Blech oder einen Stein auf die oberste Schiene legen und den '
             'Ofen 30 volle Minuten auf höchster Stufe aufheizen. Haushaltsöfen '
             'brauchen die ganze Zeit.', 1800),
        step('Stretch a ball from the middle out, leaving the last two centimetres '
             'thick. Never use a rolling pin.',
             'Eine Kugel von der Mitte nach außen ziehen, die letzten zwei Zentimeter '
             'dick lassen. Nie ein Nudelholz benutzen.'),
        step('Thin layer of crushed tomato, torn mozzarella in gaps not a blanket, a '
             'thread of oil.',
             'Dünne Schicht zerdrückte Tomaten, Mozzarellastücke in Lücken statt als '
             'Decke, ein Faden Öl.'),
        step('Bake until the crust is blistered and the cheese has just gone liquid. '
             'Basil goes on after the oven, never before.',
             'Backen, bis der Rand Blasen wirft und der Käse gerade flüssig ist. '
             'Basilikum kommt nach dem Ofen, nie vorher.', 480),
    ],
    variants=[
        variant('classic', 'classic',
                ('Margherita', 'Margherita'),
                ('Cold ferment optional, blistering crust not.',
                 'Kalte Gare optional, Blasen am Rand nicht.'),
                ('basil after the oven. always after.', 'Basilikum nach dem Ofen. immer danach.'),
                'hard', 150, 740, (30, 92, 24),
                attrs=['comfort', 'make-ahead'], tech=['bake'],
                tips=[('If you have twenty-four hours, rise the dough in the fridge '
                       'instead. Flavour doubles, effort does not.',
                       'Wenn du 24 Stunden hast: den Teig im Kühlschrank gehen lassen. '
                       'Der Geschmack verdoppelt sich, der Aufwand nicht.')],
                is_base=True),
        variant('vegan', 'vegan',
                ('Vegan Margherita', 'Vegane Margherita'),
                ('Cashew cream in spoonfuls behaves more like mozzarella than vegan '
                 'mozzarella does.',
                 'Cashewcreme in Tupfen verhält sich mehr wie Mozzarella als veganer '
                 'Mozzarella.'),
                ('spoon it, do not spread it', 'tupfen, nicht streichen'),
                'hard', 150, 660, (20, 94, 18),
                extra_contains=['tree-nuts', 'cashews'],
                attrs=['comfort'], tech=['bake'],
                patch=Patch(
                    drop=['parmesan'],
                    swap={'mozzarella': ing('cashews', 100, 'g', 'soaked, blended with lemon and salt',
                                            'eingeweicht, mit Zitrone und Salz gemixt')},
                    add=[ing('lemon', 0.5, 'piece'), ing('nutritional-yeast', 2, 'tbsp')],
                    steps={
                        5: step('Blend the soaked cashews with the lemon juice, nutritional '
                                'yeast, a pinch of salt and enough water to make a thick cream. '
                                'Thin tomato layer, then spoon the cream in coins across it.',
                                'Die eingeweichten Cashews mit Zitronensaft, Hefeflocken, einer '
                                'Prise Salz und so viel Wasser mixen, dass eine dicke Creme '
                                'entsteht. Dünne Tomatenschicht, dann die Creme in Talern '
                                'daraufsetzen.'),
                    },
                )),
        variant('gluten-free', 'gluten-free',
                ('Gluten-free Pizza', 'Glutenfreie Pizza'),
                ('Gluten-free dough is a batter you spread, not a dough you stretch. '
                 'Par-bake the base first.',
                 'Glutenfreier Teig ist ein Teig zum Streichen, nicht zum Ziehen. '
                 'Den Boden vorbacken.'),
                ('spread it, do not fight it', 'streich ihn, kämpf nicht mit ihm'),
                'medium', 70, 700, (22, 88, 26),
                attrs=['comfort'], tech=['bake'],
                patch=Patch(
                    swap={'bread-flour': ing('gf-flour', 300, 'g', 'with psyllium or xanthan',
                                             'mit Flohsamen oder Xanthan')},
                    steps={
                        0: step('Beat the gluten-free flour, yeast, salt, oil and 260 ml warm '
                                'water into a thick batter. It should drop from the spoon, not '
                                'hold a shape.',
                                'Glutenfreies Mehl, Hefe, Salz, Öl und 260 ml warmes Wasser zu '
                                'einem dicken Teig schlagen. Er soll vom Löffel fallen, nicht '
                                'die Form halten.'),
                        1: step('Rest it thirty minutes so the flour hydrates fully.',
                                '30 Minuten quellen lassen, damit das Mehl vollständig '
                                'hydratisiert.', 1800),
                        2: step('Spread it onto oiled baking paper in a rough circle, about '
                                '6 mm thick.',
                                'Auf geöltes Backpapier in einem groben Kreis streichen, etwa '
                                '6 mm dick.'),
                        4: step('Par-bake the naked base for eight minutes until it lifts off '
                                'the paper in one piece.',
                                'Den nackten Boden acht Minuten vorbacken, bis er sich in einem '
                                'Stück vom Papier löst.', 480),
                    },
                )),
        variant('quick', 'classic',
                ('Pan Pizza, tonight', 'Pfannenpizza, heute Abend'),
                ('No proving schedule, no stone. A cast-iron pan on the hob and then '
                 'under the grill.',
                 'Kein Gehzeitplan, kein Stein. Eine gusseiserne Pfanne auf dem Herd, '
                 'dann unter den Grill.'),
                ('pizza on a weeknight, actually', 'Pizza unter der Woche, wirklich'),
                'easy', 40, 690, (26, 88, 22),
                attrs=['comfort', 'kid-friendly'], tech=['bake', 'pan-fry'],
                patch=Patch(
                    qty={'yeast-dry': 7},
                    steps={
                        0: step('Mix the flour, yeast, salt, oil and 210 ml warm water into a '
                                'soft dough and knead it for two minutes. More yeast, warm '
                                'water — it will be ready in half an hour.',
                                'Mehl, Hefe, Salz, Öl und 210 ml warmes Wasser zu einem weichen '
                                'Teig verkneten, zwei Minuten. Mehr Hefe, warmes Wasser — in '
                                'einer halben Stunde fertig.', 120),
                        1: step('Rise somewhere warm until puffy.',
                                'An einem warmen Ort gehen lassen, bis er aufgeht.', 1800),
                        2: step('Oil a cast-iron pan generously and press the dough out to the '
                                'edges with your fingertips.',
                                'Eine gusseiserne Pfanne großzügig ölen und den Teig mit den '
                                'Fingerspitzen bis zum Rand drücken.'),
                        3: step('Heat the grill to maximum with a shelf near the top.',
                                'Den Grill auf Maximum vorheizen, Schiene weit oben.'),
                        4: step('Top the dough in the cold pan, then set the pan over a high '
                                'hob flame for four minutes to set and brown the base.',
                                'Den Teig in der kalten Pfanne belegen, dann die Pfanne vier '
                                'Minuten bei hoher Hitze auf den Herd stellen, damit der Boden '
                                'bräunt.', 240),
                        6: step('Slide the whole pan under the grill until the top blisters. '
                                'Basil after.',
                                'Die ganze Pfanne unter den Grill schieben, bis die Oberfläche '
                                'Blasen wirft. Basilikum danach.', 300),
                    },
                )),
    ],
))

# ---------------------------------------------------------------------------
# 10. Ramen
# ---------------------------------------------------------------------------
DISHES.append(dish(
    id='ramen',
    name=('Ramen', 'Ramen'),
    hero=('Broth, tare, fat, noodle, topping. Five parts, assembled at the last second.',
          'Brühe, Tare, Fett, Nudel, Topping. Fünf Teile, in letzter Sekunde zusammengesetzt.'),
    cap=('assemble fast, eat faster', 'schnell zusammenbauen, schneller essen'),
    stripe='#8A6A3B',
    cuisines=['japanese', 'asian'],
    categories=['noodles', 'soup', 'weekend'],
    partition='core', secondary=['cuisine-asian'], tier=1,
    slots=['lunch', 'dinner'], servings=2,
    tags=['ramen', 'noodles', 'broth', 'brühe', 'miso'],
    base_ing=[
        ing('stock-chicken', 900, 'ml'),
        ing('chicken-thigh', 250, 'g'),
        ing('soy-sauce', 4, 'tbsp'),
        ing('miso', 2, 'tbsp'),
        ing('ginger', 20, 'g'),
        ing('garlic', 3, 'clove'),
        ing('sesame-oil', 2, 'tsp'),
        ing('egg-noodles', 200, 'g', 'fresh if you can find them', 'frisch, wenn möglich'),
        ing('egg', 2, 'piece', 'for the jammy egg', 'für das wachsweiche Ei'),
        ing('spring-onion', 3, 'piece'),
        ing('shiitake', 100, 'g'),
        ing('pak-choi', 150, 'g'),
        ing('sesame-seeds', 1, 'tbsp'),
        ing('chilli-flakes', 1, 'tsp', optional=True),
    ],
    base_steps=[
        step('Simmer the stock with smashed ginger, garlic and the chicken thighs '
             'until the chicken shreds easily.',
             'Die Brühe mit zerdrücktem Ingwer, Knoblauch und den Hähnchenschenkeln '
             'köcheln, bis das Fleisch leicht zerfällt.', 2400),
        step('Lower the eggs into boiling water for exactly six and a half minutes, '
             'then straight into iced water. Peel them under a running tap.',
             'Die Eier genau sechseinhalb Minuten in kochendes Wasser geben, dann '
             'sofort in Eiswasser. Unter fließendem Wasser pellen.', 390),
        step('Lift out the chicken and shred it. Whisk the soy sauce and miso into a '
             'ladleful of hot broth until smooth, then stir it back in. This is the '
             'tare; do not boil it after.',
             'Das Hähnchen herausnehmen und zerpflücken. Sojasauce und Miso in einer '
             'Kelle heißer Brühe glatt rühren und zurückgeben. Das ist die Tare; '
             'danach nicht mehr kochen.'),
        step('Fry the shiitake in the sesame oil until deeply browned, then wilt the '
             'pak choi beside them for thirty seconds.',
             'Die Shiitake im Sesamöl kräftig braun braten, dann den Pak Choi daneben '
             '30 Sekunden zusammenfallen lassen.', 360),
        step('Cook the noodles separately in plain water — starch in the broth makes '
             'it cloudy and dull. Drain them hard.',
             'Die Nudeln separat in klarem Wasser kochen — Stärke in der Brühe macht '
             'sie trüb und stumpf. Gut abtropfen.', 180),
        step('Noodles into hot bowls, broth over, then chicken, mushrooms, greens, '
             'halved egg, spring onion, sesame. Eat before the noodles soften.',
             'Nudeln in heiße Schalen, Brühe darüber, dann Hähnchen, Pilze, Grünzeug, '
             'halbiertes Ei, Frühlingszwiebeln, Sesam. Essen, bevor die Nudeln weich '
             'werden.'),
    ],
    variants=[
        variant('classic', 'classic',
                ('Chicken Ramen', 'Hähnchen-Ramen'),
                ('A forty-minute broth, a six-and-a-half-minute egg, and no shortcuts '
                 'on the tare.',
                 'Eine Vierzig-Minuten-Brühe, ein Sechseinhalb-Minuten-Ei und keine '
                 'Abkürzung bei der Tare.'),
                ('warm the bowls. it matters.', 'die Schalen vorwärmen. das zählt.'),
                'hard', 70, 780, (48, 78, 28),
                attrs=['high-protein', 'comfort'], tech=['simmer', 'poach'],
                is_base=True),
        variant('vegan', 'vegan',
                ('Vegan Miso Ramen', 'Veganes Miso-Ramen'),
                ('Dried shiitake and kombu do what bones do, in a third of the time.',
                 'Getrocknete Shiitake und Kombu leisten, was Knochen leisten — in '
                 'einem Drittel der Zeit.'),
                ('the mushroom stock is the whole trick', 'die Pilzbrühe ist der ganze Trick'),
                'medium', 45, 560, (24, 82, 16),
                attrs=['comfort'], tech=['simmer'],
                patch=Patch(
                    drop=['egg', 'chicken-thigh'],
                    swap={
                        'stock-chicken': ing('stock-clean', 900, 'ml'),
                        'egg-noodles': ing('rice-noodles', 200, 'g', 'or egg-free wheat ramen',
                                           'oder eifreie Weizen-Ramen'),
                    },
                    add=[
                        ing('shiitake', 30, 'g', 'dried, for the stock', 'getrocknet, für die Brühe'),
                        ing('tofu', 200, 'g', 'firm, cubed and fried', 'fest, gewürfelt und gebraten'),
                        ing('sweetcorn', 80, 'g'),
                    ],
                    steps={
                        0: step('Steep the dried shiitake in the hot stock with the smashed '
                                'ginger and garlic. Do not boil it hard; a bare shiver keeps '
                                'the broth clear.',
                                'Die getrockneten Shiitake mit zerdrücktem Ingwer und Knoblauch '
                                'in der heißen Brühe ziehen lassen. Nicht sprudelnd kochen; '
                                'leichtes Zittern hält die Brühe klar.', 1500),
                        1: step('Fry the tofu cubes on all sides until they have a skin, then '
                                'set them aside.',
                                'Die Tofuwürfel rundherum braten, bis sie eine Haut haben, dann '
                                'beiseitestellen.', 480),
                        2: step('Whisk the soy sauce and miso into a ladleful of the hot broth '
                                'and stir it back. Keep it below a boil from here.',
                                'Sojasauce und Miso in einer Kelle heißer Brühe glatt rühren '
                                'und zurückgeben. Ab jetzt nicht mehr kochen lassen.'),
                        5: step('Noodles into hot bowls, broth over, then tofu, mushrooms, pak '
                                'choi, sweetcorn, spring onion, sesame.',
                                'Nudeln in heiße Schalen, Brühe darüber, dann Tofu, Pilze, Pak '
                                'Choi, Mais, Frühlingszwiebeln, Sesam.'),
                    },
                )),
        variant('gluten-free', 'gluten-free',
                ('Gluten-free Ramen', 'Glutenfreies Ramen'),
                ('Tamari instead of soy, rice noodles instead of wheat. Rinse the '
                 'noodles or the broth goes gluey.',
                 'Tamari statt Sojasauce, Reisnudeln statt Weizen. Nudeln abspülen, '
                 'sonst wird die Brühe klebrig.'),
                ('rinse the noodles. seriously.', 'die Nudeln abspülen. wirklich.'),
                'medium', 60, 600, (42, 66, 20),
                attrs=['high-protein'], tech=['simmer', 'poach'],
                patch=Patch(
                    swap={
                        'soy-sauce': ing('tamari', 4, 'tbsp'),
                        'egg-noodles': ing('rice-noodles', 200, 'g'),
                        'miso': ing('miso', 2, 'tbsp', 'check it is rice-koji, not barley',
                                    'auf Reis-Koji achten, nicht Gerste'),
                    },
                    steps={
                        4: step('Cook the rice noodles in plain water, then rinse them under '
                                'cold water until the water runs clear. Rice starch will '
                                'thicken your broth into paste otherwise.',
                                'Die Reisnudeln in klarem Wasser kochen, dann kalt abspülen, bis '
                                'das Wasser klar läuft. Sonst bindet die Reisstärke die Brühe '
                                'zu Paste.', 240),
                    },
                )),
        variant('quick', 'classic',
                ('Twenty-minute Ramen', 'Ramen in zwanzig Minuten'),
                ('Shop-bought stock, a good tare, and everything else the same. Honest '
                 'about what it is.',
                 'Fertigbrühe, eine gute Tare, sonst alles gleich. Ehrlich in dem, was '
                 'es ist.'),
                ('a Tuesday bowl', 'eine Dienstagsschale'),
                'easy', 20, 620, (38, 74, 20),
                attrs=['comfort'], tech=['simmer'],
                patch=Patch(
                    swap={'chicken-thigh': ing('chicken-breast', 200, 'g', 'sliced thin',
                                               'dünn geschnitten')},
                    steps={
                        0: step('Bring the stock to a bare simmer with the smashed ginger and '
                                'garlic, then poach the thinly sliced chicken in it for four '
                                'minutes and lift it out.',
                                'Die Brühe mit zerdrücktem Ingwer und Knoblauch leicht köcheln '
                                'lassen, das dünn geschnittene Hähnchen vier Minuten darin '
                                'pochieren und herausnehmen.', 240),
                    },
                )),
    ],
))

# ---------------------------------------------------------------------------
# 11. Chili
# ---------------------------------------------------------------------------
DISHES.append(dish(
    id='chili',
    name=('Chili', 'Chili'),
    hero=('Better the next day, which is the only honest thing a recipe can promise.',
          'Am nächsten Tag besser — das Ehrlichste, was ein Rezept versprechen kann.'),
    cap=('cook it today, eat it tomorrow', 'heute kochen, morgen essen'),
    stripe='#993D2E',
    cuisines=['american', 'tex-mex'],
    categories=['one-pot', 'batch', 'comfort'],
    partition='core', secondary=[], tier=1,
    slots=['lunch', 'dinner'], servings=4,
    tags=['chili', 'beans', 'bohnen', 'eintopf', 'batch cooking'],
    base_ing=[
        ing('beef-mince', 500, 'g'),
        ing('onion', 2, 'piece'),
        ing('garlic', 4, 'clove'),
        ing('bell-pepper', 2, 'piece'),
        ing('tinned-tomatoes', 800, 'g'),
        ing('kidney-beans', 400, 'g', 'drained', 'abgetropft'),
        ing('tomato-paste', 3, 'tbsp'),
        ing('cumin', 2, 'tsp'),
        ing('paprika-powder', 2, 'tsp'),
        ing('oregano', 1, 'tsp'),
        ing('chilli-flakes', 1, 'tsp'),
        ing('cocoa-powder', 1, 'tsp', 'trust it', 'vertrau darauf'),
        ing('stock-beef', 250, 'ml'),
        ing('rapeseed-oil', 2, 'tbsp'),
        ing('salt', 2, 'tsp'),
        ing('coriander-leaf', 20, 'g'),
        ing('creme-fraiche', 100, 'g', 'to serve', 'zum Servieren'),
    ],
    base_steps=[
        step('Brown the mince hard in a dry, wide pan in two batches. Crowding it '
             'steams it, and steamed mince tastes like nothing.',
             'Das Hack in zwei Portionen in einer trockenen, weiten Pfanne kräftig '
             'anbraten. Zu voll bedeutet dämpfen, und gedämpftes Hack schmeckt nach '
             'nichts.', 600),
        step('Oil in, then the onion and pepper, cooked until they take colour at the '
             'edges. Garlic last, one minute.',
             'Öl hinein, dann Zwiebel und Paprika, bis sie an den Rändern Farbe nehmen. '
             'Knoblauch zuletzt, eine Minute.', 480),
        step('Spices and tomato paste straight onto the hot pan base and fried for a '
             'minute until they darken and stick.',
             'Gewürze und Tomatenmark direkt auf den heißen Pfannenboden, eine Minute '
             'braten, bis sie dunkler werden und ansetzen.', 60),
        step('Everything back in with the tomatoes, stock, beans and cocoa. Scrape the '
             'stuck bits up; that is the flavour.',
             'Alles zurück in den Topf mit Tomaten, Brühe, Bohnen und Kakao. Den '
             'Bodensatz loskratzen; das ist der Geschmack.'),
        step('Simmer with the lid off, stirring now and then, until it darkens and a '
             'spoon leaves a channel.',
             'Ohne Deckel köcheln lassen, ab und zu rühren, bis es dunkler wird und der '
             'Löffel eine Rinne hinterlässt.', 3600),
        step('Salt at the end, coriander over, crème fraîche in a cold spoonful on top.',
             'Zum Schluss salzen, Koriander darüber, ein kalter Löffel Crème fraîche '
             'obenauf.'),
    ],
    variants=[
        variant('classic', 'classic',
                ('Beef Chili', 'Rinder-Chili'),
                ('Cocoa in the pot, an hour with the lid off, salt only at the end.',
                 'Kakao im Topf, eine Stunde ohne Deckel, Salz erst zum Schluss.'),
                ('the cocoa is not a gimmick', 'der Kakao ist keine Spielerei'),
                'medium', 90, 640, (38, 46, 30),
                attrs=['one-pot', 'meal-prep', 'freezer-friendly', 'budget'],
                tech=['simmer', 'sauté'],
                tips=[('Chill it overnight and skim the fat if you want it lighter — the '
                       'flavour stays behind.',
                       'Über Nacht kalt stellen und das Fett abschöpfen, wenn es leichter '
                       'sein soll — der Geschmack bleibt.')],
                is_base=True),
        variant('vegan', 'vegan',
                ('Vegan Chili', 'Veganes Chili'),
                ('Three beans and walnuts for the fatty, chewy bit meat was doing.',
                 'Drei Bohnensorten und Walnüsse für das Fettige und Bissfeste, das '
                 'sonst das Fleisch macht.'),
                ('walnuts. that is the whole secret.', 'Walnüsse. das ist das ganze Geheimnis.'),
                'medium', 75, 480, (20, 58, 20),
                extra_contains=['tree-nuts', 'walnuts'],
                attrs=['one-pot', 'meal-prep', 'freezer-friendly', 'budget'],
                tech=['simmer', 'sauté'],
                patch=Patch(
                    drop=['beef-mince'],
                    swap={
                        'stock-beef': ing('stock-veg', 250, 'ml'),
                        'creme-fraiche': ing('coconut-yoghurt', 100, 'g', 'to serve', 'zum Servieren'),
                    },
                    add=[
                        ing('black-beans', 400, 'g', 'drained', 'abgetropft'),
                        ing('walnuts', 80, 'g', 'chopped fine', 'fein gehackt'),
                        ing('soy-sauce', 2, 'tbsp'),
                    ],
                    steps={
                        0: step('Toast the chopped walnuts in the dry pan until they smell '
                                'nutty and the oil comes out of them. They are standing in for '
                                'the fat and the chew.',
                                'Die gehackten Walnüsse in der trockenen Pfanne rösten, bis sie '
                                'nussig duften und Öl austritt. Sie ersetzen Fett und Biss.', 300),
                        3: step('Everything back in with both tins of beans, the tomatoes, '
                                'stock, soy sauce and cocoa. Scrape the base clean.',
                                'Alles zurück in den Topf mit beiden Bohnensorten, Tomaten, '
                                'Brühe, Sojasauce und Kakao. Den Boden sauber kratzen.'),
                    },
                )),
        variant('low-fodmap', 'low-fodmap',
                ('Gentle Chili', 'Sanftes Chili'),
                ('No onion, no garlic, no beans — and still recognisably chili.',
                 'Keine Zwiebel, kein Knoblauch, keine Bohnen — und trotzdem erkennbar Chili.'),
                ('quinoa gives it the body beans used to',
                 'Quinoa gibt ihm den Körper, den sonst die Bohnen geben'),
                'medium', 75, 520, (34, 34, 26),
                attrs=['one-pot', 'meal-prep'], tech=['simmer', 'sauté'],
                patch=Patch(
                    drop=['onion', 'garlic', 'kidney-beans'],
                    swap={'stock-beef': ing('stock-clean', 250, 'ml')},
                    add=[
                        ing('leek-greens', 2, 'piece', 'green tops only', 'nur das Grün'),
                        ing('quinoa', 150, 'g', 'cooked', 'gekocht'),
                        ing('olive-oil', 1, 'tbsp', 'garlic-infused', 'mit Knoblauch aromatisiert'),
                    ],
                    steps={
                        1: step('Oil in — including the garlic-infused oil — then the green '
                                'leek tops and pepper until they colour at the edges. The '
                                'infused oil carries garlic flavour without the fructans.',
                                'Öl hinein — auch das Knoblauchöl — dann Lauchgrün und Paprika, '
                                'bis sie an den Rändern Farbe nehmen. Das aromatisierte Öl '
                                'bringt Knoblauchgeschmack ohne Fruktane.', 480),
                        3: step('Everything back in with the tomatoes, stock, cooked quinoa '
                                'and cocoa.',
                                'Alles zurück mit Tomaten, Brühe, gekochtem Quinoa und Kakao.'),
                    },
                )),
    ],
))

# ---------------------------------------------------------------------------
# 12. Lasagne
# ---------------------------------------------------------------------------
DISHES.append(dish(
    id='lasagne',
    name=('Lasagne', 'Lasagne'),
    hero=('An afternoon in a dish. Nobody has ever regretted making one.',
          'Ein Nachmittag in einer Form. Niemand hat es je bereut.'),
    cap=('rest it. twenty minutes. no.', 'ruhen lassen. zwanzig Minuten. doch.'),
    stripe='#A9542F',
    cuisines=['italian'],
    categories=['baking', 'weekend', 'comfort'],
    partition='core', secondary=['cuisine-italian'], tier=1,
    slots=['lunch', 'dinner'], servings=6,
    tags=['lasagne', 'ragu', 'bechamel', 'auflauf', 'baked pasta'],
    base_ing=[
        ing('beef-mince', 500, 'g'),
        ing('bacon', 100, 'g', 'diced', 'gewürfelt'),
        ing('onion', 1, 'piece'),
        ing('carrot', 2, 'piece'),
        ing('celery-stick', 2, 'piece'),
        ing('garlic', 3, 'clove'),
        ing('tinned-tomatoes', 800, 'g'),
        ing('tomato-paste', 2, 'tbsp'),
        ing('red-wine', 150, 'ml'),
        ing('whole-milk', 700, 'ml'),
        ing('butter', 60, 'g'),
        ing('flour', 60, 'g'),
        ing('nutmeg', 0.5, 'tsp'),
        ing('parmesan', 100, 'g'),
        ing('lasagne-sheets', 250, 'g'),
        ing('olive-oil', 2, 'tbsp'),
        ing('salt', 2, 'tsp'),
        ing('pepper', 1, 'tsp'),
    ],
    base_steps=[
        step('Chop the onion, carrot and celery to the same small dice and cook them '
             'in the oil with the bacon, slowly, until sweet and collapsing.',
             'Zwiebel, Karotte und Sellerie gleich klein würfeln und mit dem Speck im '
             'Öl langsam süß und zerfallend schmoren.', 900),
        step('Push them aside, brown the mince hard in the space you made, then mix '
             'everything together.',
             'Zur Seite schieben, das Hack in der freien Fläche kräftig anbraten, dann '
             'alles vermischen.', 480),
        step('Tomato paste in for a minute, wine in, boiled down until the pan smells '
             'of wine and not alcohol.',
             'Tomatenmark eine Minute mitbraten, Wein angießen, einkochen, bis es nach '
             'Wein und nicht nach Alkohol riecht.', 300),
        step('Tomatoes in. Lid half on, lowest possible heat, and leave it. Two hours '
             'is right; ninety minutes is acceptable.',
             'Tomaten dazu. Deckel halb auf, niedrigste Hitze, in Ruhe lassen. Zwei '
             'Stunden sind richtig; 90 Minuten gehen auch.', 7200),
        step('For the béchamel: melt the butter, stir in the flour, cook two minutes, '
             'then add the milk a splash at a time, whisking. Nutmeg, salt, half the '
             'parmesan.',
             'Für die Béchamel: Butter schmelzen, Mehl einrühren, zwei Minuten kochen, '
             'dann die Milch schluckweise unter Rühren zugeben. Muskat, Salz, die '
             'Hälfte des Parmesans.', 600),
        step('Layer: ragù, sheets, béchamel, repeat, finishing with béchamel and the '
             'rest of the parmesan. Sauce touches the dish at every edge or the pasta '
             'stays hard.',
             'Schichten: Ragù, Platten, Béchamel, wiederholen, mit Béchamel und '
             'restlichem Parmesan abschließen. Sauce muss überall die Form berühren, '
             'sonst bleibt die Pasta hart.'),
        step('Bake at 180 °C until the top is blistered and bronzed.',
             'Bei 180 °C backen, bis die Oberfläche Blasen wirft und bronzefarben ist.',
             2700),
        step('Rest it out of the oven. Twenty minutes. This is the difference between '
             'lasagne and soup.',
             'Außerhalb des Ofens ruhen lassen. Zwanzig Minuten. Das ist der '
             'Unterschied zwischen Lasagne und Suppe.', 1200),
    ],
    variants=[
        variant('classic', 'classic',
                ('Lasagne al Ragù', 'Lasagne al Ragù'),
                ('A two-hour ragù, a proper béchamel, and a rest you will want to skip.',
                 'Ein Zwei-Stunden-Ragù, eine echte Béchamel und eine Ruhezeit, die du '
                 'überspringen willst.'),
                ('sunday food, whatever day it is', 'Sonntagsessen, egal welcher Tag'),
                'hard', 200, 820, (44, 62, 42),
                attrs=['comfort', 'make-ahead', 'freezer-friendly'],
                tech=['simmer', 'bake'],
                is_base=True),
        variant('vegetarian', 'vegetarian',
                ('Mushroom & Lentil Lasagne', 'Pilz-Linsen-Lasagne'),
                ('Mushrooms browned until they squeak, lentils for body, the same slow '
                 'ragù discipline.',
                 'Pilze gebraten, bis sie quietschen, Linsen für Substanz, dieselbe '
                 'langsame Ragù-Disziplin.'),
                ('brown the mushrooms properly or do not bother',
                 'brate die Pilze richtig an oder lass es'),
                'hard', 170, 700, (28, 68, 32),
                attrs=['comfort', 'make-ahead'], tech=['simmer', 'bake'],
                patch=Patch(
                    drop=['beef-mince', 'bacon'],
                    swap={'red-wine': ing('red-wine', 150, 'ml')},
                    add=[
                        ing('mushroom', 500, 'g', 'chopped small', 'klein gehackt'),
                        ing('puy-lentils', 180, 'g'),
                        ing('stock-veg', 300, 'ml'),
                    ],
                    steps={
                        1: step('Push the vegetables aside and brown the chopped mushrooms hard '
                                'in the space, in batches. They must squeak and colour, not '
                                'stew.',
                                'Das Gemüse zur Seite schieben und die gehackten Pilze portions'
                                'weise kräftig anbraten. Sie müssen quietschen und Farbe nehmen, '
                                'nicht schmoren.', 720),
                        3: step('Tomatoes, lentils and stock in. Lid half on, lowest heat, until '
                                'the lentils are soft and the sauce is dark.',
                                'Tomaten, Linsen und Brühe dazu. Deckel halb auf, niedrigste '
                                'Hitze, bis die Linsen weich und die Sauce dunkel ist.', 4500),
                    },
                )),
        variant('vegan', 'vegan',
                ('Vegan Lasagne', 'Vegane Lasagne'),
                ('Oat béchamel behaves exactly like dairy béchamel. Nobody will ask.',
                 'Hafer-Béchamel verhält sich genau wie Milch-Béchamel. Niemand wird fragen.'),
                ('check the pasta for egg', 'prüf die Nudeln auf Ei'),
                'hard', 170, 640, (24, 74, 24),
                attrs=['comfort', 'make-ahead'], tech=['simmer', 'bake'],
                patch=Patch(
                    drop=['beef-mince', 'bacon'],
                    swap={
                        'whole-milk': ing('oat-milk', 700, 'ml'),
                        'butter': ing('vegan-butter', 60, 'g'),
                        'parmesan': ing('nutritional-yeast', 5, 'tbsp'),
                        'lasagne-sheets': ing('lasagne-sheets', 250, 'g', 'egg-free', 'ohne Ei'),
                    },
                    add=[
                        ing('mushroom', 400, 'g', 'chopped small', 'klein gehackt'),
                        ing('red-lentils', 150, 'g'),
                        ing('stock-veg', 350, 'ml'),
                        ing('walnuts', 60, 'g', 'chopped', 'gehackt'),
                    ],
                    steps={
                        1: step('Brown the mushrooms and walnuts hard in the cleared space, in '
                                'batches, until they squeak and darken.',
                                'Pilze und Walnüsse portionsweise in der freien Fläche kräftig '
                                'anbraten, bis sie quietschen und dunkeln.', 720),
                        3: step('Tomatoes, red lentils and stock in. Low heat until the lentils '
                                'have dissolved into the sauce.',
                                'Tomaten, rote Linsen und Brühe dazu. Niedrige Hitze, bis sich '
                                'die Linsen in der Sauce aufgelöst haben.', 3600),
                        4: step('Oat béchamel: melt the vegan butter, stir in the flour, cook '
                                'two minutes, then add the oat drink gradually while whisking. '
                                'Nutmeg, salt, half the nutritional yeast.',
                                'Hafer-Béchamel: vegane Butter schmelzen, Mehl einrühren, zwei '
                                'Minuten kochen, dann den Haferdrink nach und nach unter Rühren '
                                'zugeben. Muskat, Salz, die Hälfte der Hefeflocken.', 600),
                    },
                )),
        variant('gluten-free', 'gluten-free',
                ('Gluten-free Lasagne', 'Glutenfreie Lasagne'),
                ('Cornflour béchamel and gluten-free sheets, which need a wetter sauce '
                 'than wheat ones.',
                 'Béchamel mit Speisestärke und glutenfreie Platten, die eine feuchtere '
                 'Sauce brauchen als Weizenplatten.'),
                ('add a ladle more sauce than feels right',
                 'gib eine Kelle mehr Sauce dazu, als richtig scheint'),
                'hard', 200, 800, (42, 60, 40),
                attrs=['comfort', 'make-ahead'], tech=['simmer', 'bake'],
                patch=Patch(
                    swap={
                        'lasagne-sheets': ing('gf-pasta', 250, 'g', 'gluten-free lasagne sheets',
                                              'glutenfreie Lasagneplatten'),
                        'flour': ing('cornflour', 45, 'g'),
                    },
                    steps={
                        4: step('For the béchamel: melt the butter, whisk the cornflour into a '
                                'little cold milk first, then add the rest of the milk and '
                                'bring it to a bare boil, whisking constantly until thick.',
                                'Für die Béchamel: Butter schmelzen, Speisestärke zuerst in etwas '
                                'kalter Milch anrühren, dann die restliche Milch zugeben und '
                                'unter ständigem Rühren einmal aufkochen, bis es bindet.', 480),
                        5: step('Layer as usual, but with an extra ladle of sauce at each level '
                                '— gluten-free sheets drink more than wheat ones and will stay '
                                'chalky if you are stingy.',
                                'Wie gewohnt schichten, aber mit einer zusätzlichen Kelle Sauce '
                                'pro Lage — glutenfreie Platten trinken mehr als Weizenplatten '
                                'und bleiben sonst kreidig.'),
                    },
                )),
    ],
))

# ---------------------------------------------------------------------------
# 13. Curry
# ---------------------------------------------------------------------------
DISHES.append(dish(
    id='curry',
    name=('Curry', 'Curry'),
    hero=('Fry the spices in fat, not water. That one line is most of the recipe.',
          'Brate die Gewürze in Fett, nicht in Wasser. Diese eine Zeile ist fast das ganze Rezept.'),
    cap=('bloom the spices, always', 'Gewürze immer anrösten'),
    stripe='#C98A21',
    cuisines=['indian', 'asian'],
    categories=['one-pot', 'weeknight', 'comfort'],
    partition='core', secondary=['cuisine-asian'], tier=1,
    slots=['lunch', 'dinner'], servings=4,
    tags=['curry', 'spices', 'gewürze', 'coconut', 'rice'],
    base_ing=[
        ing('chicken-thigh', 600, 'g', 'cut into big pieces', 'in große Stücke geschnitten'),
        ing('onion', 2, 'piece'),
        ing('garlic', 4, 'clove'),
        ing('ginger', 30, 'g'),
        ing('tinned-tomatoes', 400, 'g'),
        ing('coconut-milk', 400, 'ml'),
        ing('garam-masala', 2, 'tsp'),
        ing('turmeric', 1, 'tsp'),
        ing('cumin', 2, 'tsp'),
        ing('coriander-seed', 2, 'tsp'),
        ing('chilli-flakes', 1, 'tsp'),
        ing('rapeseed-oil', 3, 'tbsp'),
        ing('jasmine-rice', 300, 'g'),
        ing('coriander-leaf', 25, 'g'),
        ing('lime', 1, 'piece'),
        ing('salt', 2, 'tsp'),
    ],
    base_steps=[
        step('Blitz the onion, garlic and ginger to a rough paste with a splash of '
             'water.',
             'Zwiebel, Knoblauch und Ingwer mit einem Schuss Wasser zu einer groben '
             'Paste mixen.'),
        step('Fry the paste in the oil over medium heat, stirring, until it stops '
             'smelling raw and starts sticking. Ten minutes minimum.',
             'Die Paste im Öl bei mittlerer Hitze unter Rühren braten, bis sie nicht '
             'mehr roh riecht und anzusetzen beginnt. Mindestens zehn Minuten.', 600),
        step('Dry spices straight into the fat. Thirty seconds, no longer — they burn '
             'in a heartbeat and burnt spice cannot be rescued.',
             'Die trockenen Gewürze direkt ins Fett. Dreißig Sekunden, nicht länger — '
             'sie verbrennen in Sekunden, und verbranntes Gewürz ist nicht zu retten.',
             30),
        step('Chicken in, turned until sealed on all sides in the spice paste.',
             'Das Hähnchen dazu, wenden, bis es rundherum von der Gewürzpaste '
             'überzogen ist.', 300),
        step('Tomatoes in, cooked down hard until the oil separates and floats. Then '
             'coconut milk, and a gentle simmer.',
             'Tomaten dazu, stark einkochen, bis sich das Öl absetzt. Dann Kokosmilch '
             'und sanft köcheln lassen.', 1500),
        step('Rice on while it simmers. Salt the curry at the end, lime over, '
             'coriander thrown on off the heat.',
             'Währenddessen den Reis aufsetzen. Das Curry zum Schluss salzen, Limette '
             'darüber, Koriander außerhalb der Hitze darauf.', 720),
    ],
    variants=[
        variant('classic', 'classic',
                ('Chicken Curry', 'Hähnchen-Curry'),
                ('The paste fried until it sticks, the tomatoes reduced until the oil '
                 'splits out.',
                 'Die Paste gebraten, bis sie ansetzt, die Tomaten reduziert, bis sich '
                 'das Öl absetzt.'),
                ('when the oil separates, you are there',
                 'wenn sich das Öl absetzt, bist du da'),
                'medium', 60, 620, (42, 58, 22),
                attrs=['one-pot', 'meal-prep', 'high-protein'], tech=['simmer', 'sauté'],
                is_base=True),
        variant('vegan', 'vegan',
                ('Chickpea & Spinach Curry', 'Kichererbsen-Spinat-Curry'),
                ('Tinned chickpeas, a bag of spinach, twenty-five minutes start to '
                 'finish.',
                 'Kichererbsen aus der Dose, eine Tüte Spinat, 25 Minuten von Anfang '
                 'bis Ende.'),
                ('the store-cupboard one', 'das Vorratsschrank-Curry'),
                'easy', 30, 520, (18, 68, 20),
                attrs=['one-pot', 'budget', 'meal-prep'], tech=['simmer', 'sauté'],
                patch=Patch(
                    swap={'chicken-thigh': ing('chickpeas', 480, 'g', 'two tins, drained',
                                               'zwei Dosen, abgetropft')},
                    add=[ing('spinach', 200, 'g')],
                    steps={
                        3: step('Chickpeas in, stirred through the paste so every one is '
                                'coated.',
                                'Kichererbsen dazu, in der Paste wenden, bis alle überzogen sind.',
                                120),
                        4: step('Tomatoes in, reduced until the oil separates, then the coconut '
                                'milk. Fold the spinach through at the very end and let it '
                                'collapse in the heat.',
                                'Tomaten dazu, einkochen, bis sich das Öl absetzt, dann '
                                'Kokosmilch. Den Spinat ganz zum Schluss unterheben und in der '
                                'Hitze zusammenfallen lassen.', 900),
                    },
                )),
        variant('keto', 'keto',
                ('Low-carb Curry', 'Low-Carb-Curry'),
                ('Cauliflower instead of rice, more coconut, no tomato sugar.',
                 'Blumenkohl statt Reis, mehr Kokos, kein Tomatenzucker.'),
                ('the sauce was never carrying the carbs', 'die Sauce war nie das Problem'),
                'medium', 50, 610, (44, 18, 42),
                attrs=['high-protein', 'one-pot'], tech=['simmer', 'sauté'],
                patch=Patch(
                    drop=['jasmine-rice'],
                    qty={'tinned-tomatoes': 200, 'coconut-milk': 500},
                    add=[ing('broccoli', 400, 'g', 'blitzed to rice-sized pieces',
                             'zu reisgroßen Stücken gehäckselt')],
                    steps={
                        5: step('Pulse the broccoli to rice-sized pieces and steam-fry it dry in '
                                'a hot pan for four minutes while the curry finishes.',
                                'Den Brokkoli zu reisgroßen Stücken häckseln und vier Minuten in '
                                'einer heißen Pfanne trocken anbraten, während das Curry fertig '
                                'wird.', 240),
                    },
                )),
        variant('low-fodmap', 'low-fodmap',
                ('Gentle Curry', 'Sanftes Curry'),
                ('No onion, no garlic, no tinned tomatoes. Ginger and infused oil hold '
                 'the base together.',
                 'Keine Zwiebel, kein Knoblauch, keine Dosentomaten. Ingwer und '
                 'aromatisiertes Öl tragen die Basis.'),
                ('spices do not need alliums to sing',
                 'Gewürze brauchen keine Zwiebeln zum Singen'),
                'medium', 45, 540, (40, 44, 24),
                attrs=['one-pot', 'high-protein'], tech=['simmer', 'sauté'],
                patch=Patch(
                    drop=['onion', 'garlic', 'tinned-tomatoes'],
                    qty={'ginger': 45},
                    add=[
                        ing('leek-greens', 2, 'piece', 'green tops only', 'nur das Grün'),
                        ing('olive-oil', 2, 'tbsp', 'garlic-infused', 'mit Knoblauch aromatisiert'),
                        ing('carrot', 2, 'piece', 'diced', 'gewürfelt'),
                    ],
                    steps={
                        0: step('Chop the green leek tops fine and grate the ginger. No blender '
                                'needed here.',
                                'Das Lauchgrün fein schneiden und den Ingwer reiben. Kein Mixer '
                                'nötig.'),
                        1: step('Fry the leek and ginger in both oils until soft and sweet — the '
                                'garlic-infused oil gives you the garlic note without the '
                                'fructans.',
                                'Lauch und Ingwer in beiden Ölen weich und süß braten — das '
                                'Knoblauchöl bringt die Knoblauchnote ohne Fruktane.', 480),
                        4: step('Carrots and coconut milk in, simmered until the carrots are '
                                'soft and the sauce has thickened.',
                                'Karotten und Kokosmilch dazu, köcheln, bis die Karotten weich '
                                'sind und die Sauce gebunden hat.', 1200),
                    },
                )),
    ],
))

# ---------------------------------------------------------------------------
# 14. Falafel Bowl
# ---------------------------------------------------------------------------
DISHES.append(dish(
    id='falafel-bowl',
    name=('Falafel Bowl', 'Falafel-Bowl'),
    hero=('Dried chickpeas, soaked. Tinned ones make a paste that falls apart.',
          'Getrocknete Kichererbsen, eingeweicht. Dosenware wird zu Brei und zerfällt.'),
    cap=('dried, soaked, never cooked', 'getrocknet, eingeweicht, nie gekocht'),
    stripe='#6E8C3A',
    cuisines=['middle-eastern', 'levantine'],
    categories=['bowl', 'meal-prep', 'weeknight'],
    partition='core', secondary=['cuisine-middle-eastern'], tier=1,
    slots=['lunch', 'dinner'], servings=3,
    tags=['falafel', 'chickpeas', 'kichererbsen', 'tahini', 'bowl'],
    base_ing=[
        ing('chickpeas', 250, 'g', 'dried, soaked overnight, NOT cooked',
            'getrocknet, über Nacht eingeweicht, NICHT gekocht'),
        ing('onion', 1, 'piece'),
        ing('garlic', 3, 'clove'),
        ing('parsley', 40, 'g'),
        ing('coriander-leaf', 30, 'g'),
        ing('cumin', 2, 'tsp'),
        ing('coriander-seed', 2, 'tsp'),
        ing('flour', 2, 'tbsp'),
        ing('bicarb', 0.5, 'tsp'),
        ing('rapeseed-oil', 500, 'ml', 'for frying', 'zum Frittieren'),
        ing('tahini', 4, 'tbsp'),
        ing('lemon', 1, 'piece'),
        ing('couscous', 180, 'g'),
        ing('cucumber', 1, 'piece'),
        ing('cherry-tomato', 200, 'g'),
        ing('red-onion', 0.5, 'piece'),
        ing('sumac', 1, 'tsp'),
        ing('salt', 2, 'tsp'),
    ],
    base_steps=[
        step('Drain the soaked chickpeas thoroughly and pat them dry. Any water left '
             'and the falafel will burst in the oil.',
             'Die eingeweichten Kichererbsen gründlich abtropfen und trocken tupfen. '
             'Bleibt Wasser zurück, platzen die Falafel im Öl.'),
        step('Pulse them with the onion, garlic, herbs, spices and salt to the texture '
             'of wet sand. Not a purée — you should still see individual specks.',
             'Mit Zwiebel, Knoblauch, Kräutern, Gewürzen und Salz zu nassem Sand '
             'hacken. Kein Püree — einzelne Stückchen sollen sichtbar bleiben.'),
        step('Stir in the flour and bicarbonate and chill the mixture. Cold mix holds '
             'its shape; warm mix does not.',
             'Mehl und Natron unterrühren und die Masse kalt stellen. Kalte Masse hält '
             'die Form, warme nicht.', 1800),
        step('Soak the couscous in an equal volume of boiling salted water under a '
             'plate, then fork it loose.',
             'Den Couscous mit der gleichen Menge kochendem Salzwasser unter einem '
             'Teller quellen lassen, dann mit der Gabel auflockern.', 600),
        step('Whisk the tahini with lemon juice and cold water. It will seize solid '
             'first — keep going, it loosens into cream.',
             'Tahin mit Zitronensaft und kaltem Wasser verrühren. Es wird zuerst fest '
             '— weitermachen, es wird cremig.'),
        step('Heat the oil to 170 °C and fry the falafel in small batches until deep '
             'brown. Drain on a rack, never on paper.',
             'Das Öl auf 170 °C erhitzen und die Falafel in kleinen Portionen dunkel'
             'braun frittieren. Auf einem Gitter abtropfen lassen, nie auf Papier.', 240),
        step('Couscous down, chopped salad over, falafel on top, tahini poured across, '
             'sumac scattered last.',
             'Couscous zuerst, gehackter Salat darüber, Falafel obenauf, Tahin darüber '
             'gießen, Sumach zuletzt.'),
    ],
    variants=[
        variant('classic', 'vegan',
                ('Falafel Bowl', 'Falafel-Bowl'),
                ('Deep-fried properly, tahini poured with a heavy hand.',
                 'Richtig frittiert, Tahin mit großzügiger Hand.'),
                ('never tinned. i will not budge.', 'nie aus der Dose. da bleibe ich hart.'),
                'medium', 60, 640, (22, 74, 28),
                attrs=['budget', 'meal-prep'], tech=['deep-fry'],
                tips=[('One test falafel first. If it falls apart, add another spoon of '
                       'flour; if it is dense, you over-blitzed.',
                       'Erst eine Test-Falafel. Zerfällt sie, noch einen Löffel Mehl; ist '
                       'sie kompakt, war der Mixer zu gründlich.')],
                is_base=True),
        variant('gluten-free', 'gluten-free',
                ('Gluten-free Falafel Bowl', 'Glutenfreie Falafel-Bowl'),
                ('Chickpea flour binds better than wheat anyway, and quinoa beats '
                 'couscous under a sauce.',
                 'Kichererbsenmehl bindet ohnehin besser als Weizen, und Quinoa schlägt '
                 'Couscous unter einer Sauce.'),
                ('an upgrade disguised as a substitution',
                 'ein Upgrade, getarnt als Ersatz'),
                'medium', 60, 620, (23, 70, 28),
                attrs=['budget', 'meal-prep'], tech=['deep-fry'],
                patch=Patch(
                    swap={
                        'flour': ing('gf-flour', 3, 'tbsp', 'chickpea flour is best',
                                     'Kichererbsenmehl ist am besten'),
                        'couscous': ing('quinoa', 180, 'g'),
                    },
                    steps={
                        3: step('Rinse the quinoa well, then simmer it in twice its volume of '
                                'salted water until the little tails uncurl.',
                                'Den Quinoa gut abspülen, dann in der doppelten Menge Salzwasser '
                                'köcheln, bis sich die kleinen Keimringe lösen.', 900),
                    },
                )),
        variant('light', 'light',
                ('Baked Falafel Bowl', 'Gebackene Falafel-Bowl'),
                ('Oven-baked with a brush of oil. Less crust, less oil, still good.',
                 'Im Ofen gebacken, mit Öl bepinselt. Weniger Kruste, weniger Öl, '
                 'trotzdem gut.'),
                ('flatten them slightly — more surface',
                 'leicht flach drücken — mehr Oberfläche'),
                'easy', 50, 470, (21, 66, 14),
                attrs=['light-meal', 'meal-prep', 'budget'], tech=['bake'],
                patch=Patch(
                    swap={'rapeseed-oil': ing('olive-oil', 3, 'tbsp', 'for brushing', 'zum Bepinseln')},
                    steps={
                        5: step('Heat the oven to 200 °C. Shape the mix into flattened patties, '
                                'brush both sides with oil and bake on a hot tray, turning once, '
                                'until crisp and browned.',
                                'Ofen auf 200 °C. Die Masse zu flachen Talern formen, beidseitig '
                                'mit Öl bepinseln und auf einem heißen Blech backen, einmal '
                                'wenden, bis knusprig und gebräunt.', 1500),
                    },
                )),
    ],
))
