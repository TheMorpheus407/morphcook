"""Kitchen reference — only for ingredients that are genuinely easy to get wrong.

No entry for salt. Reached from the "Learn more" affordance in a recipe's
ingredient list.
"""

# ingredient_id, (en, de) for: summary, usage, storage, where_to_find
ENTRIES = [
    ('tahini',
     ('Ground sesame paste, somewhere between peanut butter and single cream when '
      'it is fresh. Good tahini pours; cheap tahini sets like concrete and tastes '
      'bitter.',
      'Gemahlene Sesampaste, frisch irgendwo zwischen Erdnussmus und Sahne. Gutes '
      'Tahin fließt; billiges wird fest wie Beton und schmeckt bitter.'),
     ('Whisk it with lemon juice and cold water and it will seize solid before it '
      'loosens into a pale cream — keep going through the seizing, that is normal.',
      'Mit Zitronensaft und kaltem Wasser verrühren: Es wird erst fest, bevor es zu '
      'heller Creme wird — durch das Festwerden hindurchrühren, das gehört dazu.'),
     ('Cupboard, upside down so the oil redistributes. It separates; stir it back '
      'in rather than pouring the oil off.',
      'Im Schrank, kopfüber, damit sich das Öl verteilt. Es trennt sich; unterrühren '
      'statt das Öl abzugießen.'),
     ('World foods, near the olives and pickles. Middle-Eastern shops sell better '
      'tahini for less.',
      'Weltküche, bei Oliven und Eingelegtem. Orientalische Läden verkaufen besseres '
      'Tahin für weniger.')),

    ('miso',
     ('Fermented soybean paste. White (shiro) is mild and sweet; red is older and '
      'much saltier. Recipes here mean white unless they say otherwise.',
      'Fermentierte Sojabohnenpaste. Helles (Shiro) ist mild und süßlich, rotes ist '
      'älter und deutlich salziger. Rezepte hier meinen helles, sofern nicht anders '
      'angegeben.'),
     ('Never boil it — high heat kills the aroma and makes it flat. Whisk it into a '
      'ladle of hot liquid first, then stir that back into the pot off the heat.',
      'Nie kochen — starke Hitze zerstört das Aroma. Erst in einer Kelle heißer '
      'Flüssigkeit auflösen, dann außerhalb der Hitze in den Topf rühren.'),
     ('Fridge, sealed. It keeps for the better part of a year and only gets darker.',
      'Kühlschrank, verschlossen. Es hält fast ein Jahr und wird nur dunkler.'),
     ('Chilled world-foods section, next to tofu and kimchi.',
      'Gekühlte Weltküche, neben Tofu und Kimchi.')),

    ('gochujang',
     ('Korean fermented chilli paste: sweet, savoury and hot in that order, with a '
      'texture like thick jam.',
      'Koreanische fermentierte Chilipaste: süß, herzhaft und scharf in dieser '
      'Reihenfolge, dick wie Marmelade.'),
     ('Loosen it with vinegar and a little water before it goes on food, otherwise '
      'it sits in a lump and burns in a pan.',
      'Vor dem Servieren mit Essig und etwas Wasser lockern, sonst bleibt sie ein '
      'Klumpen und brennt in der Pfanne an.'),
     ('Fridge after opening. It keeps for months.',
      'Nach dem Öffnen in den Kühlschrank. Hält Monate.'),
     ('World foods in a red tub. Many brands contain barley — check the label if '
      'you avoid gluten.',
      'Weltküche, im roten Becher. Viele Marken enthalten Gerste — bei Glutenverzicht '
      'das Etikett prüfen.')),

    ('nutritional-yeast',
     ('Deactivated yeast flakes with a savoury, cheesy taste. It does not rise '
      'anything; it is a seasoning, not a leavener.',
      'Inaktive Hefeflocken mit herzhaftem, käsigem Geschmack. Sie treiben nichts; '
      'sie sind Würze, kein Backtriebmittel.'),
     ('Stir it in at the end. Cooked hard for long it turns dusty and slightly '
      'bitter.',
      'Zum Schluss unterrühren. Lange stark gekocht werden sie staubig und leicht '
      'bitter.'),
     ('Airtight in the cupboard; it goes stale and loses its smell within a few '
      'months of opening.',
      'Luftdicht im Schrank; sie werden innerhalb weniger Monate nach dem Öffnen '
      'schal.'),
     ('Health-food aisle or the vegan section, usually in a paper carton.',
      'Reformregal oder vegane Abteilung, meist im Papierkarton.')),

    ('seitan',
     ('Wheat gluten cooked into a dense, chewy protein. Texture close to poultry '
      'thigh; entirely off-limits if you avoid gluten.',
      'Weizengluten zu dichtem, bissfestem Protein gekocht. Textur nahe an '
      'Geflügelschenkel; bei Glutenverzicht völlig ungeeignet.'),
     ('Tear it rather than slicing it — torn edges catch marinade and crisp far '
      'better than cut ones.',
      'Reißen statt schneiden — gerissene Kanten nehmen Marinade auf und werden viel '
      'knuspriger als geschnittene.'),
     ('Fridge in its liquid, or frozen. Freezing actually improves the texture.',
      'Im Kühlschrank in seiner Flüssigkeit oder eingefroren. Einfrieren verbessert '
      'die Textur sogar.'),
     ('Chilled vegan section, near tofu and tempeh.',
      'Gekühlte vegane Abteilung, bei Tofu und Tempeh.')),

    ('tofu',
     ('Pressed soy curd. Firm tofu holds its shape and fries; silken tofu collapses '
      'and blends. They are not interchangeable.',
      'Gepresster Sojaquark. Fester Tofu behält die Form und lässt sich braten; '
      'Seidentofu zerfällt und lässt sich mixen. Sie sind nicht austauschbar.'),
     ('Press firm tofu for at least twenty minutes under something heavy. Water is '
      'the only reason tofu ever tastes of nothing.',
      'Festen Tofu mindestens zwanzig Minuten unter Gewicht pressen. Wasser ist der '
      'einzige Grund, warum Tofu je nach nichts schmeckt.'),
     ('Fridge, submerged in fresh water, changed daily. Freezing makes it spongier '
      'and better at soaking up sauce.',
      'Im Kühlschrank, in frischem Wasser, täglich gewechselt. Eingefroren wird er '
      'schwammiger und saugt Sauce besser auf.'),
     ('Chilled section. Vacuum packs are firmer than tubs of water.',
      'Kühlregal. Vakuumpackungen sind fester als Becher in Wasser.')),

    ('tamarind',
     ('Sour fruit pulp, dark and sticky. The sourness is fruity rather than sharp, '
      'which is why lemon is not a straight substitute.',
      'Saures Fruchtmark, dunkel und klebrig. Die Säure ist fruchtig statt spitz — '
      'deshalb ist Zitrone kein direkter Ersatz.'),
     ('Paste from a jar is ready to use; a block needs soaking in hot water and '
      'pushing through a sieve to remove the stones.',
      'Paste aus dem Glas ist gebrauchsfertig; ein Block muss in heißem Wasser '
      'eingeweicht und durch ein Sieb gestrichen werden, um die Kerne zu entfernen.'),
     ('Fridge after opening; it lasts months and darkens slowly.',
      'Nach dem Öffnen in den Kühlschrank; hält Monate und dunkelt langsam nach.'),
     ('World foods, near the curry pastes. Asian shops sell blocks far cheaper.',
      'Weltküche, bei den Currypasten. Asienläden verkaufen Blöcke viel günstiger.')),

    ('sumac',
     ('Dried, ground berries with a clean lemony sourness and no liquid. It reads '
      'as citrus without wetting anything.',
      'Getrocknete, gemahlene Beeren mit klarer zitroniger Säure und ohne '
      'Flüssigkeit. Schmeckt nach Zitrus, ohne etwas nass zu machen.'),
     ('Scatter it at the end, over raw onion or yoghurt. Heat dulls it within '
      'seconds.',
      'Zum Schluss darüberstreuen, über rohe Zwiebeln oder Joghurt. Hitze macht es '
      'in Sekunden stumpf.'),
     ('Dark cupboard. It fades from deep red to brown as it ages, and pale sumac is '
      'old sumac.',
      'Dunkler Schrank. Es verblasst von tiefrot zu braun; blasses Sumach ist altes '
      'Sumach.'),
     ('Spice aisle or Middle-Eastern shops, where it is a fraction of the price.',
      'Gewürzregal oder orientalische Läden, wo es einen Bruchteil kostet.')),

    ('harissa',
     ('North African chilli paste with caraway, coriander and garlic. Heat varies '
      'wildly by brand — taste before committing a whole spoon.',
      'Nordafrikanische Chilipaste mit Kümmel, Koriander und Knoblauch. Die Schärfe '
      'schwankt stark je nach Marke — vor dem ganzen Löffel probieren.'),
     ('Fry it briefly in oil before adding liquid; it blooms the way dry spices do.',
      'Kurz in Öl anbraten, bevor Flüssigkeit dazukommt; sie blüht auf wie trockene '
      'Gewürze.'),
     ('Fridge after opening, with a film of oil on top to keep air off.',
      'Nach dem Öffnen in den Kühlschrank, mit einem Ölfilm obendrauf gegen Luft.'),
     ('World foods, in a tube or a small jar.',
      'Weltküche, in der Tube oder im kleinen Glas.')),

    ('jackfruit',
     ('Young, unripe jackfruit in brine — savoury and neutral, nothing like the '
      'sweet ripe fruit. It shreds into strands that read as slow-cooked meat.',
      'Junge, unreife Jackfrucht in Lake — herzhaft und neutral, nichts wie die süße '
      'reife Frucht. Sie zerfasert zu Strängen, die wie Schmorfleisch wirken.'),
     ('Drain, rinse and dry-fry it hard before seasoning. Skipping that step leaves '
      'it watery and faintly tinny.',
      'Abgießen, abspülen und vor dem Würzen trocken kräftig anbraten. Ohne diesen '
      'Schritt bleibt sie wässrig und schmeckt leicht nach Dose.'),
     ('Cupboard until opened, then fridge for three days.',
      'Ungeöffnet im Schrank, danach drei Tage im Kühlschrank.'),
     ('World foods, tinned. Make sure it says "young" or "in brine", not "in syrup".',
      'Weltküche, in der Dose. Auf „jung“ oder „in Lake“ achten, nicht „in Sirup“.')),

    ('ghee',
     ('Butter with the water and milk solids cooked out. It takes far more heat than '
      'butter before it burns and tastes nutty rather than creamy.',
      'Butter, aus der Wasser und Milcheiweiß herausgekocht wurden. Sie verträgt viel '
      'mehr Hitze als Butter und schmeckt nussig statt sahnig.'),
     ('Use it anywhere butter would burn — blooming spices, high-heat frying.',
      'Überall dort, wo Butter verbrennen würde — Gewürze anrösten, scharf braten.'),
     ('Cupboard, no refrigeration needed. It keeps for months at room temperature.',
      'Schrank, keine Kühlung nötig. Hält Monate bei Zimmertemperatur.'),
     ('World foods or the Indian section, in a jar.',
      'Weltküche oder indische Abteilung, im Glas.')),

    ('arborio-rice',
     ('Short, fat rice with a chalky centre and a lot of surface starch. That starch '
      'is the sauce in risotto — rinsing it away ruins the dish.',
      'Kurzer, dicker Reis mit kreidigem Kern und viel Oberflächenstärke. Diese '
      'Stärke ist die Sauce im Risotto — Abspülen ruiniert das Gericht.'),
     ('Toast the dry grains in fat until the edges turn glassy before any liquid '
      'goes in. Never rinse it.',
      'Die trockenen Körner in Fett rösten, bis die Ränder glasig werden, bevor '
      'Flüssigkeit dazukommt. Nie abspülen.'),
     ('Cupboard, airtight. It does not improve with age.',
      'Schrank, luftdicht. Es wird mit dem Alter nicht besser.'),
     ('Dry goods with the rice. Carnaroli is the same idea and slightly more '
      'forgiving.',
      'Trockenware beim Reis. Carnaroli ist dasselbe Prinzip und etwas '
      'nachsichtiger.')),

    ('rice-paper',
     ('Brittle translucent discs of rice starch that turn pliable in warm water in '
      'about two seconds.',
      'Spröde, durchscheinende Scheiben aus Reisstärke, die in warmem Wasser in etwa '
      'zwei Sekunden weich werden.'),
     ('Two seconds in the water, no more — it keeps softening while you work. Keep '
      'finished parcels apart; they weld to each other.',
      'Zwei Sekunden im Wasser, nicht mehr — es weicht beim Arbeiten weiter auf. '
      'Fertige Päckchen auseinanderlegen; sie verschweißen miteinander.'),
     ('Cupboard, flat and dry. Damp air makes the sheets stick together in the pack.',
      'Schrank, flach und trocken. Feuchte Luft verklebt die Blätter in der Packung.'),
     ('World foods, near the rice noodles.',
      'Weltküche, bei den Reisnudeln.')),

    ('erythritol',
     ('A sugar alcohol that reads as about 70 % as sweet as sugar with a cooling '
      'finish. It does not caramelise and does not feed browning.',
      'Ein Zuckeralkohol, etwa 70 % so süß wie Zucker, mit kühlem Abgang. Er '
      'karamellisiert nicht und trägt nicht zur Bräunung bei.'),
     ('Fine in custards and creams; poor in anything that relies on caramel or a '
      'chewy crumb. Expect a paler bake.',
      'Gut in Cremes und Puddings; schlecht in allem, was auf Karamell oder eine '
      'zähe Krume setzt. Das Gebäck bleibt heller.'),
     ('Cupboard. It clumps in humidity; break it up with a fork.',
      'Schrank. Bei Feuchtigkeit verklumpt er; mit der Gabel zerdrücken.'),
     ('Baking aisle, near the sugar alternatives.',
      'Backregal, bei den Zuckeralternativen.')),

    ('flaxseed',
     ('Ground flax mixed with water gels into a binder that behaves close enough to '
      'egg in batters and burgers.',
      'Gemahlene Leinsamen mit Wasser gelieren zu einem Bindemittel, das in Teigen '
      'und Bratlingen nah genug an Ei herankommt.'),
     ('One tablespoon ground flax to three tablespoons water, left five minutes, '
      'equals one egg. It binds but does not leaven — it will not make anything rise.',
      'Ein Esslöffel gemahlene Leinsamen auf drei Esslöffel Wasser, fünf Minuten '
      'stehen lassen, ergibt ein Ei. Es bindet, treibt aber nicht — es lässt nichts '
      'aufgehen.'),
     ('Ground flax goes rancid fast: fridge or freezer, and buy small bags.',
      'Gemahlene Leinsamen werden schnell ranzig: Kühlschrank oder Gefrierfach, und '
      'kleine Beutel kaufen.'),
     ('Health-food aisle. Buy them ready-ground unless you own a spice grinder.',
      'Reformregal. Fertig gemahlen kaufen, außer du hast eine Gewürzmühle.')),

    ('gf-oats',
     ('Oats do not contain gluten, but almost all of them are grown, milled or '
      'transported alongside wheat. "Certified gluten-free" is about the supply '
      'chain, not the grain.',
      'Hafer enthält kein Gluten, aber fast aller Hafer wird zusammen mit Weizen '
      'angebaut, gemahlen oder transportiert. „Zertifiziert glutenfrei“ bezieht sich '
      'auf die Lieferkette, nicht auf das Korn.'),
     ('Use them exactly like ordinary oats. Some people with coeliac disease still '
      'react to avenin — introduce them carefully.',
      'Genau wie normale Haferflocken verwenden. Manche Menschen mit Zöliakie '
      'reagieren dennoch auf Avenin — vorsichtig einführen.'),
     ('Cupboard, airtight. Oats go rancid faster than they go stale.',
      'Schrank, luftdicht. Hafer wird eher ranzig als altbacken.'),
     ('Free-from aisle, clearly marked. Never assume from the regular shelf.',
      'Frei-von-Regal, deutlich gekennzeichnet. Nie vom normalen Regal ausgehen.')),

    ('pea-protein-mince',
     ('Textured pea protein shaped into mince. Leaner than beef and with almost no '
      'connective tissue, so it cooks much faster.',
      'Texturiertes Erbsenprotein in Hackform. Magerer als Rind und fast ohne '
      'Bindegewebe, gart also deutlich schneller.'),
     ('Hotter pan, shorter time. It dries out where beef would still be fine, and '
      'it needs salt earlier because there is no fat carrying flavour.',
      'Heißere Pfanne, kürzere Zeit. Es trocknet aus, wo Rind noch in Ordnung wäre, '
      'und braucht früher Salz, weil kein Fett den Geschmack trägt.'),
     ('Fridge, or freezer for months. It thaws fast enough to use from frozen.',
      'Kühlschrank oder Gefrierfach für Monate. Es taut schnell genug für die '
      'direkte Verwendung.'),
     ('Chilled vegan section, sold in packs the size of mince.',
      'Gekühlte vegane Abteilung, in Packungen wie Hackfleisch.')),

    ('coconut-milk',
     ('Pressed coconut flesh and water. Full-fat tins separate into thick cream on '
      'top and thin liquid below; light versions are mostly water.',
      'Gepresstes Kokosfleisch mit Wasser. Vollfett-Dosen trennen sich in dicke Creme '
      'oben und dünne Flüssigkeit unten; leichte Varianten sind überwiegend Wasser.'),
     ('Do not shake the tin if you want the cream — scoop it off the top. Never boil '
      'it hard, or it splits into oil and grain.',
      'Nicht schütteln, wenn du die Creme willst — von oben abschöpfen. Nie stark '
      'kochen, sonst trennt sie sich in Öl und Körnung.'),
     ('Cupboard. Chill the tin overnight to get a firmer cream layer.',
      'Schrank. Die Dose über Nacht kalt stellen für eine festere Cremeschicht.'),
     ('World foods. Check the ingredients — good tins are coconut and water, nothing '
      'else.',
      'Weltküche. Zutaten prüfen — gute Dosen enthalten Kokos und Wasser, sonst '
      'nichts.')),

    ('polenta',
     ('Coarsely ground corn. Instant polenta is pre-cooked and takes minutes; '
      'traditional takes the better part of an hour and tastes noticeably better.',
      'Grob gemahlener Mais. Instant-Polenta ist vorgegart und braucht Minuten; '
      'traditionelle braucht fast eine Stunde und schmeckt deutlich besser.'),
     ('Rain it into the liquid while whisking, never dump it in — lumps do not come '
      'out afterwards. Also makes a coarse, loud gluten-free crumb coating.',
      'Unter Rühren einrieseln lassen, nie hineinschütten — Klumpen gehen nicht mehr '
      'raus. Ergibt auch eine grobe, laute glutenfreie Panade.'),
     ('Cupboard, airtight. Wholegrain polenta goes rancid within months.',
      'Schrank, luftdicht. Vollkorn-Polenta wird binnen Monaten ranzig.'),
     ('Dry goods, near the flour. Not the same as cornflour or cornstarch.',
      'Trockenware beim Mehl. Nicht dasselbe wie Speisestärke.')),
]
