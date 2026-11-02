"""The ingredient dictionary and the flag rules that hang off it.

The tree drives three things at once:

  * the specific-avoidance typeahead (picking ``dairy`` excludes everything
    underneath it),
  * the aisle a shopping line belongs to, and
  * the contains-flags a recipe inherits from an ingredient.

The flag rules are the same knowledge the pipeline's flag-verifier applies,
expressed as data so the corpus stays self-consistent.
"""

# (id, label_en, label_de, parent, aisle, unit_system, aliases)
NODES = [
    # ── Produce ────────────────────────────────────────────────────────────
    ("produce", "Produce", "Obst & Gemüse", None, "produce", "any", ["veggies", "gemüse"]),
    ("produce.tomato", "Tomato", "Tomate", "produce", "produce", "count", ["tomaten"]),
    ("produce.tomato.cherry", "Cherry tomatoes", "Cherrytomaten", "produce.tomato", "produce", "count", []),
    ("produce.tomato.plum", "Plum tomatoes", "Strauchtomaten", "produce.tomato", "produce", "count", []),
    ("produce.onion", "Onion", "Zwiebel", "produce", "produce", "count", ["zwiebeln", "onion"]),
    ("produce.onion.red", "Red onion", "Rote Zwiebel", "produce.onion", "produce", "count", []),
    ("produce.onion.yellow", "Brown onion", "Zwiebel", "produce.onion", "produce", "count", []),
    ("produce.onion.spring", "Spring onions", "Frühlingszwiebeln", "produce.onion", "produce", "count", ["frühlingszwiebel"]),
    ("produce.garlic", "Garlic", "Knoblauch", "produce", "produce", "count", ["knoblauch"]),
    ("produce.pepper", "Bell pepper", "Paprika", "produce", "produce", "count", ["paprika", "bell pepper"]),
    ("produce.pepper.red", "Red pepper", "Rote Paprika", "produce.pepper", "produce", "count", []),
    ("produce.pepper.yellow", "Yellow pepper", "Gelbe Paprika", "produce.pepper", "produce", "count", []),
    ("produce.pepper.green", "Green pepper", "Grüne Paprika", "produce.pepper", "produce", "count", []),
    ("produce.pepper.chili", "Chilli", "Chilischote", "produce", "produce", "count", ["chilli", "chili"]),
    ("produce.herbs", "Fresh herbs", "Frische Kräuter", "produce", "produce", "count", ["kräuter"]),
    ("produce.herbs.cilantro", "Coriander", "Koriander", "produce.herbs", "produce", "count", ["cilantro"]),
    ("produce.herbs.basil", "Basil", "Basilikum", "produce.herbs", "produce", "count", []),
    ("produce.herbs.parsley", "Parsley", "Petersilie", "produce.herbs", "produce", "count", []),
    ("produce.herbs.thyme", "Thyme", "Thymian", "produce.herbs", "produce", "count", []),
    ("produce.herbs.rosemary", "Rosemary", "Rosmarin", "produce.herbs", "produce", "count", []),
    ("produce.herbs.mint", "Mint", "Minze", "produce.herbs", "produce", "count", []),
    ("produce.potato", "Potato", "Kartoffel", "produce", "produce", "count", ["kartoffeln"]),
    ("produce.potato.baby", "Baby potatoes", "Babykartoffeln", "produce.potato", "produce", "count", []),
    ("produce.carrot", "Carrot", "Karotte", "produce", "produce", "count", ["möhre", "karotte"]),
    ("produce.eggplant", "Aubergine", "Aubergine", "produce", "produce", "count", ["eggplant"]),
    ("produce.zucchini", "Courgette", "Zucchini", "produce", "produce", "count", ["zucchini"]),
    ("produce.lemon", "Lemon", "Zitrone", "produce", "produce", "count", ["zitrone"]),
    ("produce.lime", "Lime", "Limette", "produce", "produce", "count", ["limette"]),
    ("produce.apple", "Apple", "Apfel", "produce", "produce", "count", ["apfel"]),
    ("produce.banana", "Banana", "Banane", "produce", "produce", "count", []),
    ("produce.mushroom", "Mushroom", "Pilze", "produce", "produce", "count", ["champignons"]),
    ("produce.mushroom.chestnut", "Chestnut mushrooms", "Riesenchampignons", "produce.mushroom", "produce", "count", []),
    ("produce.lettuce", "Lettuce", "Salat", "produce", "produce", "count", []),
    ("produce.lettuce.romaine", "Romaine", "Römersalat", "produce.lettuce", "produce", "count", []),
    ("produce.spinach", "Spinach", "Spinat", "produce", "produce", "count", []),
    ("produce.kale", "Kale", "Grünkohl", "produce", "produce", "count", []),
    ("produce.ginger", "Ginger", "Ingwer", "produce", "produce", "count", ["ingwer"]),
    ("produce.cucumber", "Cucumber", "Gurke", "produce", "produce", "count", ["gurke"]),
    ("produce.pineapple", "Pineapple", "Ananas", "produce", "produce", "count", []),
    ("produce.avocado", "Avocado", "Avocado", "produce", "produce", "count", []),
    ("produce.corn", "Sweetcorn", "Mais", "produce", "produce", "count", []),
    ("produce.pea", "Peas", "Erbsen", "produce", "produce", "count", []),
    ("produce.pomegranate", "Pomegranate", "Granatapfel", "produce", "produce", "count", []),
    ("produce.olive", "Olives", "Oliven", "produce", "produce", "count", ["oliven"]),
    ("produce.olive.black", "Black olives", "Schwarze Oliven", "produce.olive", "produce", "count", []),
    ("produce.cabbage", "Cabbage", "Kohl", "produce", "produce", "count", []),
    ("produce.cabbage.red", "Red cabbage", "Rotkohl", "produce.cabbage", "produce", "count", []),
    ("produce.celery", "Celery", "Sellerie", "produce", "produce", "count", ["sellerie"]),
    ("produce.sweet-potato", "Sweet potato", "Süßkartoffel", "produce", "produce", "count", ["süßkartoffel"]),

    # ── Dairy ──────────────────────────────────────────────────────────────
    ("dairy", "Dairy", "Milchprodukte", None, "dairy", "any", ["milk products", "milchprodukte"]),
    ("dairy.milk", "Milk", "Milch", "dairy", "dairy", "volume", ["milch"]),
    ("dairy.milk.whole", "Whole milk", "Vollmilch", "dairy.milk", "dairy", "volume", ["vollmilch"]),
    ("dairy.milk.skim", "Skimmed milk", "Magermilch", "dairy.milk", "dairy", "volume", ["magermilch"]),
    ("dairy.milk.semi-skimmed", "Semi-skimmed milk", "Halbfettmilch", "dairy.milk", "dairy", "volume", []),
    ("dairy.milk.buttermilk", "Buttermilk", "Buttermilch", "dairy.milk", "dairy", "volume", []),
    ("dairy.cheese", "Cheese", "Käse", "dairy", "dairy", "mass", ["käse", "cheese"]),
    ("dairy.cheese.parmesan", "Parmesan", "Parmesan", "dairy.cheese", "dairy", "mass", []),
    ("dairy.cheese.feta", "Feta", "Feta", "dairy.cheese", "dairy", "mass", []),
    ("dairy.cheese.mozzarella", "Mozzarella", "Mozzarella", "dairy.cheese", "dairy", "mass", []),
    ("dairy.cheese.cheddar", "Cheddar", "Cheddar", "dairy.cheese", "dairy", "mass", []),
    ("dairy.cheese.ricotta", "Ricotta", "Ricotta", "dairy.cheese", "dairy", "mass", []),
    ("dairy.cheese.gruyere", "Gruyère", "Gruyère", "dairy.cheese", "dairy", "mass", []),
    ("dairy.cheese.halloumi", "Halloumi", "Halloumi", "dairy.cheese", "dairy", "mass", []),
    ("dairy.butter", "Butter", "Butter", "dairy", "dairy", "mass", ["butter"]),
    ("dairy.cream", "Cream", "Sahne", "dairy", "dairy", "volume", ["sahne", "cream"]),
    ("dairy.cream.heavy", "Double cream", "Schlagsahne", "dairy.cream", "dairy", "volume", []),
    ("dairy.cream.sour", "Sour cream", "Sauerrahm", "dairy.cream", "dairy", "volume", []),
    ("dairy.cream.crame-fraiche", "Crème fraîche", "Crème fraîche", "dairy.cream", "dairy", "volume", []),
    ("dairy.yogurt", "Yoghurt", "Joghurt", "dairy", "dairy", "volume", ["joghurt", "yogurt"]),
    ("dairy.yogurt.greek", "Greek yoghurt", "Griechischer Joghurt", "dairy.yogurt", "dairy", "volume", []),
    ("dairy.yogurt.plain", "Plain yoghurt", "Naturjoghurt", "dairy.yogurt", "dairy", "volume", []),

    # ── Proteins & meat ───────────────────────────────────────────────────
    ("proteins", "Protein", "Eiweiß", None, "meat-seafood", "any", []),
    ("proteins.egg", "Egg", "Ei", "proteins", "meat-seafood", "count", ["eier", "eggs"]),
    ("proteins.chicken", "Chicken", "Hähnchen", "proteins", "meat-seafood", "mass", ["hähnchen", "chicken"]),
    ("proteins.chicken.breast", "Chicken breast", "Hähnchenbrust", "proteins.chicken", "meat-seafood", "mass", []),
    ("proteins.chicken.thigh", "Chicken thigh", "Hähnchenschenkel", "proteins.chicken", "meat-seafood", "mass", []),
    ("proteins.beef", "Beef", "Rindfleisch", "proteins", "meat-seafood", "mass", ["rindfleisch", "beef"]),
    ("proteins.beef.mince", "Beef mince", "Hackfleisch", "proteins.beef", "meat-seafood", "mass", []),
    ("proteins.pork", "Pork", "Schweinefleisch", "proteins", "meat-seafood", "mass", ["schweinefleisch", "pork"]),
    ("proteins.pork.mince", "Pork mince", "Schweinehack", "proteins.pork", "meat-seafood", "mass", []),
    ("proteins.lamb", "Lamb", "Lammfleisch", "proteins", "meat-seafood", "mass", ["lamm", "lamb"]),
    ("proteins.turkey", "Turkey", "Truthahn", "proteins", "meat-seafood", "mass", []),
    ("proteins.tofu", "Tofu", "Tofu", "proteins", "meat-seafood", "mass", ["tofu"]),
    ("proteins.tofu.firm", "Firm tofu", "Fester Tofu", "proteins.tofu", "meat-seafood", "mass", []),
    ("proteins.tofu.silken", "Silken tofu", "Seidiger Tofu", "proteins.tofu", "meat-seafood", "mass", []),
    ("proteins.tempeh", "Tempeh", "Tempeh", "proteins", "meat-seafood", "mass", []),
    ("proteins.plant-mince", "Plant mince", "Sojageschrot", "proteins", "frozen", "mass", ["vegan mince", "sojageschrot"]),

    # ── Seafood ────────────────────────────────────────────────────────────
    ("seafood", "Seafood", "Fisch & Meeresfrüchte", None, "meat-seafood", "any", []),
    ("seafood.fish", "Fish", "Fisch", "seafood", "meat-seafood", "mass", ["fisch", "fish"]),
    ("seafood.fish.salmon", "Salmon", "Lachs", "seafood.fish", "meat-seafood", "mass", []),
    ("seafood.fish.tuna", "Tuna", "Thunfisch", "seafood.fish", "meat-seafood", "mass", []),
    ("seafood.fish.cod", "Cod", "Kabeljau", "seafood.fish", "meat-seafood", "mass", []),
    ("seafood.fish.tilapia", "Tilapia", "Tilapia", "seafood.fish", "meat-seafood", "mass", []),
    ("seafood.fish.anchovy", "Anchovies", "Anchovis", "seafood.fish", "meat-seafood", "mass", []),
    ("seafood.shellfish", "Shellfish", "Schalentiere", "seafood", "meat-seafood", "count", ["schalentiere"]),
    ("seafood.shellfish.shrimp", "Prawns", "Garnelen", "seafood.shellfish", "meat-seafood", "count", ["garnelen"]),
    ("seafood.shellfish.crab", "Crab", "Krabbe", "seafood.shellfish", "meat-seafood", "count", []),
    ("seafood.shellfish.mussel", "Mussels", "Muscheln", "seafood.shellfish", "meat-seafood", "count", []),
    ("seafood.shellfish.scallop", "Scallops", "JakobsMuscheln", "seafood.shellfish", "meat-seafood", "count", []),
    ("seafood.mollusc", "Molluscs", "Weichtiere", "seafood", "meat-seafood", "mass", []),
    ("seafood.mollusc.squid", "Squid", "Kalamaro", "seafood.mollusc", "meat-seafood", "mass", []),
    ("seafood.mollusc.octopus", "Octopus", "Oktopus", "seafood.mollusc", "meat-seafood", "mass", []),
    ("seafood.mollusc.clam", "Clams", "Venusmuscheln", "seafood.mollusc", "meat-seafood", "count", []),

    # ── Bakery ─────────────────────────────────────────────────────────────
    ("bakery", "Bakery", "Bäckerei", None, "bakery", "count", ["bäckerei"]),
    ("bakery.bread", "Bread", "Brot", "bakery", "bakery", "count", ["brot"]),
    ("bakery.bread.sourdough", "Sourdough", "Sauerteigbrot", "bakery.bread", "bakery", "count", []),
    ("bakery.bread.wholegrain", "Wholegrain bread", "Vollkornbrot", "bakery.bread", "bakery", "count", []),
    ("bakery.bagel", "Bagel", "Bagel", "bakery", "bakery", "count", []),
    ("bakery.pita", "Pita", "Pitabrot", "bakery", "bakery", "count", []),
    ("bakery.tortilla", "Tortilla", "Tortilla", "bakery", "bakery", "count", ["tortillas"]),
    ("bakery.tortilla.flour", "Flour tortilla", "Weizen-Tortilla", "bakery.tortilla", "bakery", "count", []),
    ("bakery.tortilla.corn", "Corn tortilla", "Maistortilla", "bakery.tortilla", "bakery", "count", []),
    ("bakery.bun", "Bun", "Brötchen", "bakery", "bakery", "count", []),
    ("bakery.cracker", "Crackers", "Cracker", "bakery", "bakery", "count", []),
    ("bakery.puff-pastry", "Puff pastry", "Blätterteig", "bakery", "bakery", "mass", ["blätterteig"]),

    # ── Pantry ─────────────────────────────────────────────────────────────
    ("pantry", "Pantry", "Vorratsschrank", None, "pantry", "any", ["vorrat"]),
    ("pantry.flour", "Flour", "Mehl", "pantry", "pantry", "mass", ["mehl"]),
    ("pantry.flour.plain", "Plain flour", "Weizenmehl", "pantry.flour", "pantry", "mass", []),
    ("pantry.flour.wholegrain", "Wholegrain flour", "Vollkornmehl", "pantry.flour", "pantry", "mass", []),
    ("pantry.flour.gluten-free", "Gluten-free flour blend", "Glutenfreie Mehlmischung", "pantry", "pantry", "mass", ["glutenfreies mehl"]),
    ("pantry.rice", "Rice", "Reis", "pantry", "pantry", "mass", ["reis"]),
    ("pantry.rice.basmati", "Basmati rice", "Basmati-Reis", "pantry.rice", "pantry", "mass", []),
    ("pantry.rice.brown", "Brown rice", "Vollkornreis", "pantry.rice", "pantry", "mass", []),
    ("pantry.rice.arborio", "Arborio rice", "Risotto-Reis", "pantry.rice", "pantry", "mass", []),
    ("pantry.pasta", "Pasta", "Nudeln", "pantry", "pantry", "mass", ["nudeln", "pasta"]),
    ("pantry.pasta.spaghetti", "Spaghetti", "Spaghetti", "pantry.pasta", "pantry", "mass", []),
    ("pantry.pasta.penne", "Penne", "Penne", "pantry.pasta", "pantry", "mass", []),
    ("pantry.pasta.rigatoni", "Rigatoni", "Rigatoni", "pantry.pasta", "pantry", "mass", []),
    ("pantry.pasta.lasagna-sheet", "Lasagne sheets", "Lasagneblätter", "pantry.pasta", "pantry", "mass", []),
    ("pantry.pasta.rice", "Rice pasta", "Reispasta", "pantry", "pantry", "mass", ["reispasta"]),
    ("pantry.legume", "Pulses", "Hülsenfrüchte", "pantry", "pantry", "mass", ["hülsenfrüchte"]),
    ("pantry.legume.lentil-red", "Red lentils", "Rote Linsen", "pantry.legume", "pantry", "mass", []),
    ("pantry.legume.lentil-green", "Green lentils", "Grüne Linsen", "pantry.legume", "pantry", "mass", []),
    ("pantry.legume.chickpea", "Chickpeas", "Kichererbsen", "pantry.legume", "pantry", "mass", []),
    ("pantry.legume.black-bean", "Black beans", "Schwarze Bohnen", "pantry.legume", "pantry", "mass", []),
    ("pantry.legume.kidney-bean", "Kidney beans", "Kidneybohnen", "pantry.legume", "pantry", "mass", []),
    ("pantry.nut", "Nuts", "Nüsse", "pantry", "pantry", "mass", ["nüsse", "nuts"]),
    ("pantry.nut.walnut", "Walnuts", "Walnüsse", "pantry.nut", "pantry", "mass", []),
    ("pantry.nut.almond", "Almonds", "Mandeln", "pantry.nut", "pantry", "mass", []),
    ("pantry.nut.cashew", "Cashews", "Cashewkerne", "pantry.nut", "pantry", "mass", []),
    ("pantry.nut.pistachio", "Pistachios", "Pistazien", "pantry.nut", "pantry", "mass", []),
    ("pantry.nut.hazelnut", "Hazelnuts", "Haselnüsse", "pantry.nut", "pantry", "mass", []),
    ("pantry.nut.peanut", "Peanuts", "Erdnüsse", "pantry.nut", "pantry", "mass", ["erdnüsse"]),
    ("pantry.seed", "Seeds", "Samen", "pantry", "pantry", "mass", ["samen"]),
    ("pantry.seed.sesame", "Sesame seeds", "Sesamsamen", "pantry.seed", "pantry", "mass", []),
    ("pantry.seed.pumpkin", "Pumpkin seeds", "Kürbiskerne", "pantry.seed", "pantry", "mass", []),
    ("pantry.seed.sunflower", "Sunflower seeds", "Sonnenblumenkerne", "pantry.seed", "pantry", "mass", []),
    ("pantry.seed.flax", "Flax seeds", "Leinsamen", "pantry.seed", "pantry", "mass", []),
    ("pantry.seed.chia", "Chia seeds", "Chiasamen", "pantry.seed", "pantry", "mass", []),
    ("pantry.oil", "Oil", "Öl", "pantry", "pantry", "volume", ["öl"]),
    ("pantry.oil.olive", "Olive oil", "Olivenöl", "pantry.oil", "pantry", "volume", []),
    ("pantry.oil.sunflower", "Sunflower oil", "Sonnenblumenöl", "pantry.oil", "pantry", "volume", []),
    ("pantry.oil.sesame", "Sesame oil", "Sesamöl", "pantry.oil", "pantry", "volume", []),
    ("pantry.oil.rapeseed", "Rapeseed oil", "Rapsöl", "pantry.oil", "pantry", "volume", []),
    ("pantry.sugar", "Sugar", "Zucker", "pantry", "pantry", "mass", ["zucker"]),
    ("pantry.sugar.caster", "Caster sugar", "Feiner Zucker", "pantry.sugar", "pantry", "mass", []),
    ("pantry.sugar.brown", "Brown sugar", "Brauner Zucker", "pantry.sugar", "pantry", "mass", []),
    ("pantry.honey", "Honey", "Honig", "pantry", "pantry", "volume", ["honig", "honey"]),
    ("pantry.maple-syrup", "Maple syrup", "Ahornsyrup", "pantry", "pantry", "volume", []),
    ("pantry.salt", "Salt", "Salz", "pantry", "pantry", "mass", ["salz", "salt"]),
    ("pantry.salt.sea", "Sea salt", "Meersalz", "pantry.salt", "pantry", "mass", []),
    ("pantry.pepper", "Pepper", "Pfeffer", "pantry", "pantry", "mass", ["pfeffer", "pepper"]),
    ("pantry.pepper.black", "Black pepper", "Schwarzer Pfeffer", "pantry.pepper", "pantry", "mass", []),
    ("pantry.stock", "Stock", "Brühe", "pantry", "pantry", "volume", ["brühe", "stock"]),
    ("pantry.stock.vegetable", "Vegetable stock", "Gemüsebrühe", "pantry.stock", "pantry", "volume", []),
    ("pantry.stock.chicken", "Chicken stock", "Hühnerbrühe", "pantry.stock", "pantry", "volume", []),
    ("pantry.stock.pork", "Pork stock", "Schweinebrühe", "pantry.stock", "pantry", "volume", []),
    ("pantry.canned-tomato", "Tinned tomatoes", "Dosentomaten", "pantry", "pantry", "mass", []),
    ("pantry.coconut-milk", "Coconut milk", "Kokosmilch", "pantry", "pantry", "volume", []),
    ("pantry.tahini", "Tahini", "Tahini", "pantry", "pantry", "mass", []),
    ("pantry.miso", "Miso", "Miso", "pantry", "pantry", "mass", []),
    ("pantry.soy-sauce", "Soy sauce", "Sojasauce", "pantry", "pantry", "volume", []),
    ("pantry.vinegar", "Vinegar", "Essig", "pantry", "pantry", "volume", ["essig"]),
    ("pantry.vinegar.cider", "Cider vinegar", "Apfelessig", "pantry.vinegar", "pantry", "volume", []),
    ("pantry.vinegar.balsamic", "Balsamic vinegar", "Balsamico", "pantry.vinegar", "pantry", "volume", []),
    ("pantry.vinegar.rice", "Rice vinegar", "Reisessig", "pantry.vinegar", "pantry", "volume", []),
    ("pantry.mustard", "Mustard", "Senf", "pantry", "pantry", "mass", ["senf", "mustard"]),
    ("pantry.mustard.dijon", "Dijon mustard", "Dijon", "pantry.mustard", "pantry", "mass", []),
    ("pantry.mustard.wholegrain", "Wholegrain mustard", "Grobkörniger Senf", "pantry.mustard", "pantry", "mass", []),
    ("pantry.ketchup", "Ketchup", "Ketchup", "pantry", "pantry", "volume", []),
    ("pantry.baking-powder", "Baking powder", "Backpulver", "pantry", "pantry", "mass", []),
    ("pantry.baking-soda", "Baking soda", "Natron", "pantry", "pantry", "mass", []),
    ("pantry.vanilla", "Vanilla", "Vanille", "pantry", "pantry", "volume", []),
    ("pantry.cinnamon", "Cinnamon", "Zimt", "pantry", "pantry", "mass", []),
    ("pantry.cumin", "Cumin", "Kreuzkümmel", "pantry", "pantry", "mass", []),
    ("pantry.paprika", "Paprika", "Paprikapulver", "pantry", "pantry", "mass", []),
    ("pantry.oregano", "Oregano", "Oregano", "pantry", "pantry", "mass", []),
    ("pantry.curry-powder", "Curry powder", "Currypulver", "pantry", "pantry", "mass", []),
    ("pantry.coriander-seed", "Coriander seeds", "Koriandersamen", "pantry", "pantry", "mass", []),
    ("pantry.turmeric", "Turmeric", "Kurkuma", "pantry", "pantry", "mass", []),
    ("pantry.nutmeg", "Nutmeg", "Muskatnuss", "pantry", "pantry", "mass", []),
    ("pantry.capers", "Capers", "Kapern", "pantry", "pantry", "mass", []),
    ("pantry.cornstarch", "Cornstarch", "Speisestärke", "pantry", "pantry", "mass", []),
    ("pantry.breadcrumbs", "Breadcrumbs", "Semmelbrösel", "pantry", "pantry", "mass", []),
    ("pantry.panko", "Panko breadcrumbs", "Panko", "pantry", "pantry", "mass", []),
    ("pantry.chocolate", "Dark chocolate", "Dunkle Schokolade", "pantry", "pantry", "mass", []),
    ("pantry.cocoa", "Cocoa powder", "Kakaopulver", "pantry", "pantry", "mass", []),
    ("pantry.nutritional-yeast", "Nutritional yeast", "Hefepulver", "pantry", "pantry", "mass", []),
    ("pantry.palm-sugar", "Palm sugar", "Palmzucker", "pantry", "pantry", "mass", []),
    ("pantry.tamari", "Tamari", "Tamari", "pantry", "pantry", "volume", []),
    ("pantry.tamarind", "Tamarind paste", "Tamarindenpaste", "pantry", "pantry", "mass", []),
    ("pantry.rice-noodle", "Rice noodles", "Reisnudeln", "pantry", "pantry", "mass", ["reisnudeln"]),
    ("pantry.ramen-noodle", "Ramen noodles", "Ramennudeln", "pantry", "pantry", "mass", ["ramennudeln"]),
    ("pantry.nori", "Nori seaweed", "Nori-Algen", "pantry", "pantry", "mass", ["nori", "algen"]),
    ("pantry.bay-leaf", "Bay leaves", "Lorbeerblätter", "pantry", "pantry", "count", ["lorbeerblatt"]),
    ("pantry.smoked-paprika", "Smoked paprika", "Geräucherte Paprika", "pantry", "pantry", "mass", ["räucherpaprika"]),

    # ── Beverages ──────────────────────────────────────────────────────────
    ("beverages", "Drinks", "Getränke", None, "beverages", "volume", ["getränke"]),
    ("beverages.coffee", "Coffee", "Kaffee", "beverages", "beverages", "volume", ["kaffee"]),
    ("beverages.black-tea", "Black tea", "Schwarzer Tee", "beverages", "beverages", "volume", []),
    ("beverages.green-tea", "Green tea", "Grüner Tee", "beverages", "beverages", "volume", []),
    ("beverages.wine", "Wine", "Wein", "beverages", "beverages", "volume", ["wein", "wine"]),
    ("beverages.wine.red", "Red wine", "Rotwein", "beverages.wine", "beverages", "volume", []),
    ("beverages.wine.white", "White wine", "Weißwein", "beverages.wine", "beverages", "volume", []),
    ("beverages.beer", "Beer", "Bier", "beverages", "beverages", "volume", ["bier"]),
    ("beverages.apple-juice", "Apple juice", "Apfelsaft", "beverages", "beverages", "volume", []),
    ("beverages.sparkling-water", "Sparkling water", "Sprudelwasser", "beverages", "beverages", "volume", []),
    ("beverages.soy-milk", "Soy milk", "Sojamilch", "beverages", "beverages", "volume", []),
    ("beverages.almond-milk", "Almond milk", "Mandelmilch", "beverages", "beverages", "volume", []),
    ("beverages.oat-milk", "Oat milk", "Hafermilch", "beverages", "beverages", "volume", []),

    # ── Frozen ─────────────────────────────────────────────────────────────
    ("frozen", "Frozen", "Tiefkühl", None, "frozen", "count", ["tiefkühl"]),
    ("frozen.pea", "Frozen peas", "Tiefkühlerbsen", "frozen", "frozen", "mass", []),
    ("frozen.berry", "Frozen berries", "Tiefkühlbeeren", "frozen", "frozen", "mass", []),
    ("frozen.spinach", "Frozen spinach", "Tiefkühlsalat", "frozen", "frozen", "mass", []),
]


def _flag_rules() -> dict[str, list[str]]:
    """Which contains-flags each ingredient brings with it.

    Keyed by exact ingredient id. A rule on a parent node applies to all of
    its children — ``dairy.milk`` covers ``dairy.milk.whole`` and friends.
    """
    return {
        # Dairy
        "dairy.milk": ["dairy", "dairy-lactose"],
        "dairy.cheese": ["dairy"],
        "dairy.butter": ["dairy"],
        "dairy.cream": ["dairy", "dairy-lactose"],
        "dairy.yogurt": ["dairy", "dairy-lactose"],
        # Animal products
        "proteins.egg": ["egg"],
        "proteins.chicken": ["poultry"],
        "proteins.turkey": ["poultry"],
        "proteins.beef": ["beef"],
        "proteins.pork": ["pork"],
        "proteins.lamb": ["lamb"],
        "proteins.tofu": ["soy"],
        "proteins.tempeh": ["soy"],
        # Seafood
        "seafood.fish": ["fish"],
        "seafood.shellfish": ["shellfish"],
        "seafood.mollusc": ["molluscs"],
        # Gluten
        "pantry.flour": ["gluten"],
        "pantry.pasta": ["gluten"],
        "bakery.bread": ["gluten"],
        "bakery.bagel": ["gluten"],
        "bakery.pita": ["gluten"],
        "bakery.tortilla.flour": ["gluten"],
        "bakery.bun": ["gluten"],
        "bakery.cracker": ["gluten"],
        "pantry.breadcrumbs": ["gluten"],
        "pantry.ramen-noodle": ["gluten"],
        "pantry.stock.chicken": ["poultry"],
        "pantry.stock.pork": ["pork"],
        "pantry.maple-syrup": ["added-sugar"],
        "pantry.panko": ["gluten"],
        "pantry.soy-sauce": ["soy", "gluten"],
        # Nuts, seeds, soy
        "pantry.nut.walnut": ["tree-nuts"],
        "pantry.nut.almond": ["tree-nuts"],
        "pantry.nut.cashew": ["tree-nuts"],
        "pantry.nut.pistachio": ["tree-nuts"],
        "pantry.nut.hazelnut": ["tree-nuts"],
        "pantry.nut.peanut": ["peanuts"],
        "pantry.seed.sesame": ["sesame"],
        "pantry.miso": ["soy"],
        # Other allergens and diet markers
        "pantry.honey": ["honey"],
        "pantry.mustard": ["mustard"],
        "pantry.sugar": ["added-sugar"],
        "produce.celery": ["celery"],
        "produce.garlic": ["high-fodmap"],
        "produce.onion": ["high-fodmap"],
        "beverages.beer": ["alcohol"],
        "beverages.wine": ["alcohol", "sulphites"],
        "beverages.coffee": ["caffeine"],
        "beverages.black-tea": ["caffeine"],
        "beverages.green-tea": ["caffeine"],
    }


def build_tree() -> tuple[list[dict], dict[str, list[str]]]:
    """Returns the ingredient nodes and the resolved flag rules."""
    nodes: list[dict] = []
    for node_id, en, de, parent, aisle, system, aliases in NODES:
        nodes.append(
            {
                "id": node_id,
                "label": {"en": en, "de": de},
                "parent": parent,
                "aisle": aisle,
                "unit_system": system,
                "aliases": aliases,
            }
        )

    rules = _flag_rules()
    resolved: dict[str, list[str]] = {}
    for node_id, *_ in NODES:
        flags: list[str] = []
        current = node_id
        guard = 0
        while current is not None and guard < 32:
            if current in rules:
                for flag in rules[current]:
                    if flag not in flags:
                        flags.append(flag)
            parent = next(
                (node[3] for node in NODES if node[0] == current),
                None,
            )
            current = parent
            guard += 1
        resolved[node_id] = flags
    return nodes, resolved
