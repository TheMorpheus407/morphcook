#!/usr/bin/env python3
"""Build the bundled, authored starter cookbook. No runtime or network dependency.

Content is editorial seed material, not a claim of professional or human review.
Ingredient weights, cooked yields and nutritional values are estimates.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "app" / "assets"


def tr(en, de):
    return {"en": en, "de": de}


FLAGS = [
    ("pork", "Pork", "Schweinefleisch"), ("beef", "Beef", "Rindfleisch"),
    ("lamb", "Lamb", "Lamm"), ("poultry", "Poultry", "Geflügel"),
    ("fish", "Fish", "Fisch"), ("shellfish", "Shellfish", "Krebstiere"),
    ("molluscs", "Molluscs", "Weichtiere"), ("egg", "Eggs", "Eier"),
    ("dairy", "Dairy", "Milchprodukte"), ("lactose", "Lactose", "Laktose"),
    ("gluten", "Gluten", "Gluten"), ("soy", "Soy", "Soja"),
    ("nuts", "All nuts & peanuts", "Alle Nüsse & Erdnüsse"),
    ("peanuts", "Peanuts", "Erdnüsse"), ("tree-nuts", "Tree nuts", "Schalenfrüchte"),
    ("almonds", "Almonds", "Mandeln"), ("walnuts", "Walnuts", "Walnüsse"),
    ("pistachios", "Pistachios", "Pistazien"), ("cashews", "Cashews", "Cashewkerne"),
    ("sesame", "Sesame", "Sesam"), ("mustard", "Mustard", "Senf"),
    ("celery", "Celery", "Sellerie"), ("lupin", "Lupin", "Lupinen"),
    ("sulphites", "Sulphites", "Sulfite"), ("alcohol", "Alcohol", "Alkohol"),
    ("caffeine", "Caffeine", "Koffein"), ("added-sugar", "Added sugar", "Zugesetzter Zucker"),
    ("high-fodmap", "High FODMAP ingredients", "FODMAP-reiche Zutaten"),
    ("gelatin-non-halal", "Non-halal gelatin", "Nicht-halale Gelatine"),
    ("gelatin-non-kosher", "Non-kosher gelatin", "Nicht-koschere Gelatine"),
    ("honey", "Honey", "Honig"),
    ("animal-rennet", "Animal rennet", "Tierisches Lab"),
    ("rennet-non-halal", "Rennet without halal-compatible sourcing", "Lab ohne halal-kompatible Herkunft"),
    ("rennet-non-kosher", "Rennet without kosher-compatible sourcing", "Lab ohne koscher-kompatible Herkunft"),
    ("meat-dairy-combo", "Meat and dairy together", "Fleisch und Milch zusammen"),
]

MEAT = ["pork", "beef", "lamb", "poultry"]
ANIMAL = MEAT + ["fish", "shellfish", "molluscs", "egg", "dairy", "honey", "animal-rennet", "gelatin-non-halal", "gelatin-non-kosher"]

ontology = {
    "version": 1,
    "flags": [{"id": i, "name": tr(en, de)} for i, en, de in FLAGS],
    "compounds": {
        "vegan": ANIMAL,
        "vegetarian": MEAT + ["fish", "shellfish", "molluscs", "animal-rennet", "gelatin-non-halal", "gelatin-non-kosher"],
        "pescatarian": MEAT + ["animal-rennet", "gelatin-non-halal", "gelatin-non-kosher"],
        "halal": ["pork", "alcohol", "gelatin-non-halal", "rennet-non-halal"],
        "kosher": ["pork", "shellfish", "molluscs", "meat-dairy-combo", "gelatin-non-kosher", "rennet-non-kosher"],
        "low-fodmap": ["high-fodmap"], "sugar-free": ["added-sugar"], "lactose-free": ["lactose"],
    },
    "compound_labels": {
        "vegan": tr("Vegan", "Vegan"), "vegetarian": tr("Vegetarian", "Vegetarisch"),
        "pescatarian": tr("Pescatarian", "Pescetarisch"),
        "halal": tr("Halal-compatible ingredients", "Halal-kompatible Zutaten"),
        "kosher": tr("Kosher-compatible ingredients", "Koscher-kompatible Zutaten"),
        "low-fodmap": tr("Low FODMAP", "FODMAP-arm"),
        "sugar-free": tr("No added sugar", "Ohne zugesetzten Zucker"),
        "lactose-free": tr("Lactose-free", "Laktosefrei"),
    },
    "dimensions": [
        {"id": "diet", "label": tr("Diet", "Ernährung"), "values": [
            {"id": i, "label": tr(en, de)} for i, en, de in [
                ("classic", "Classic", "Klassisch"), ("vegetarian", "Vegetarian", "Vegetarisch"),
                ("vegan", "Vegan", "Vegan"), ("keto", "Keto", "Keto"),
                ("halal", "Halal-compatible", "Halal-kompatibel")]]},
        {"id": "effort", "label": tr("Effort", "Aufwand"), "values": [
            {"id": i, "label": tr(en, de)} for i, en, de in [
                ("easy", "Easy", "Einfach"), ("medium", "A little care", "Mit etwas Muße"),
                ("hard", "A kitchen project", "Ein Küchenprojekt")]]},
        {"id": "calorie_level", "label": tr("Calorie level", "Kalorien"), "values": [
            {"id": i, "label": tr(en, de)} for i, en, de in [
                ("light", "Light", "Leicht"), ("balanced", "Balanced", "Ausgewogen"),
                ("hearty", "Hearty", "Herzhaft")]]},
    ],
    "attributes": {
        "effort": ["easy", "medium", "hard"],
        "time_bucket": ["≤15", "≤30", "≤60", ">60"],
        "calorie_bucket": ["≤400", "≤600", "≤800", ">800"],
        "technique": ["bake", "sauté", "simmer", "raw", "grill", "fry", "steam", "roast", "broil", "pan-fry", "deep-fry", "stir-fry", "poach", "blanch"],
        "meal": ["breakfast", "lunch", "dinner"],
        "positive": ["halal", "kosher", "vegetarian", "vegan", "keto"],
    },
    "calorie_tolerance": 150,
    "sourcing_note": tr("Halal-compatible and kosher-compatible describe ingredients, not certification. Check labels, sourcing and your own preparation requirements.", "Halal-kompatibel und koscher-kompatibel beschreiben Zutaten, keine Zertifizierung. Prüfe Etiketten, Herkunft und deine Anforderungen an die Zubereitung."),
}

AISLES = {
    "produce": tr("Fruit & vegetables", "Obst & Gemüse"),
    "chilled": tr("Chilled & dairy", "Kühlregal & Milchprodukte"),
    "protein": tr("Meat & fish", "Fleisch & Fisch"),
    "pantry": tr("Pantry", "Vorrat"),
    "bakery": tr("Bread & bakery", "Brot & Backwaren"),
    "spices": tr("Herbs & spices", "Kräuter & Gewürze"),
}
ingredients = []


def ing(i, en, de, parent=None, flags=(), aisle="pantry"):
    ingredients.append({"id": i, "name": tr(en, de), "parent_id": parent,
                        "flags": list(flags), "aisle": AISLES[aisle]})


# Parent nodes are selectable: avoidance follows the complete ancestor chain.
ing("dairy", "Dairy", "Milchprodukte", flags=["dairy"], aisle="chilled")
ing("cow-milk", "Cow's milk", "Kuhmilch", "dairy", ["lactose"], "chilled")
ing("whole-milk", "Whole milk", "Vollmilch", "cow-milk", aisle="chilled")
ing("skim-milk", "Skimmed milk", "Magermilch", "cow-milk", aisle="chilled")
ing("goat-milk", "Goat's milk", "Ziegenmilch", "dairy", ["lactose"], "chilled")
ing("cheese", "Cheese", "Käse", "dairy", aisle="chilled")
ing("parmesan", "Parmesan with animal rennet", "Parmesan mit tierischem Lab", "cheese", ["animal-rennet", "rennet-non-halal", "rennet-non-kosher"], "chilled")
ing("vegetarian-hard-cheese", "Hard cheese with microbial rennet", "Hartkäse mit mikrobiellem Lab", "cheese", aisle="chilled")
ing("feta", "Feta with microbial rennet", "Feta mit mikrobiellem Lab", "cheese", ["lactose"], "chilled")
ing("halloumi", "Halloumi with microbial rennet", "Halloumi mit mikrobiellem Lab", "cheese", ["lactose"], "chilled")
ing("cream-cheese", "Cream cheese", "Frischkäse", "cheese", ["lactose"], "chilled")
ing("mozzarella", "Mozzarella with microbial rennet", "Mozzarella mit mikrobiellem Lab", "cheese", ["lactose"], "chilled")
ing("yogurt", "Plain yogurt", "Naturjoghurt", "dairy", ["lactose"], "chilled")
ing("butter", "Butter", "Butter", "dairy", ["lactose"], "chilled")
ing("cream", "Double cream", "Sahne", "dairy", ["lactose"], "chilled")
ing("nuts", "All nuts and peanuts", "Alle Nüsse und Erdnüsse", flags=["nuts"])
ing("tree-nuts", "Tree nuts", "Schalenfrüchte", "nuts", ["tree-nuts"])
for i, en, de in [("almonds", "Almonds", "Mandeln"), ("walnuts", "Walnuts", "Walnüsse"), ("pistachios", "Pistachios", "Pistazien"), ("cashews", "Cashews", "Cashewkerne")]:
    ing(i, en, de, "tree-nuts", [i])
ing("almond-flour", "Ground almonds", "Gemahlene Mandeln", "almonds")
ing("peanuts", "Peanuts", "Erdnüsse", "nuts", ["peanuts"])
ing("peanut-butter", "Unsweetened peanut butter", "Ungesüßtes Erdnussmus", "peanuts")
ing("sesame", "Sesame seeds", "Sesam", flags=["sesame"])
ing("tahini", "Tahini", "Tahin", "sesame")
ing("sesame-oil", "Toasted sesame oil", "Geröstetes Sesamöl", "sesame")
ing("soy", "Soy foods", "Sojaprodukte", flags=["soy"])
ing("tofu", "Firm tofu", "Fester Tofu", "soy", aisle="chilled")
ing("silken-tofu", "Silken tofu", "Seidentofu", "soy", aisle="chilled")
ing("tempeh", "Plain tempeh", "Natur-Tempeh", "soy", aisle="chilled")
ing("tamari", "Alcohol-free gluten-free tamari", "Alkoholfreies glutenfreies Tamari", "soy")
ing("miso", "Alcohol-free rice miso", "Alkoholfreies Reis-Miso", "soy")
ing("edamame", "Shelled edamame", "Geschälte Edamame", "soy", aisle="chilled")
ing("wheat", "Wheat", "Weizen", flags=["gluten", "high-fodmap"])
for i, en, de, aisle in [("pita", "Pita bread", "Fladenbrot", "bakery"), ("pasta", "Fettuccine", "Fettuccine", "pantry"), ("ramen-noodles", "Wheat ramen noodles", "Weizen-Ramennudeln", "pantry"), ("flour", "Plain flour", "Weizenmehl", "pantry"), ("bread", "Sourdough bread", "Sauerteigbrot", "bakery")]:
    ing(i, en, de, "wheat", aisle=aisle)
ing("meat", "Meat", "Fleisch", aisle="protein")
for i, en, de, flag in [("chicken", "Chicken breast", "Hähnchenbrust", "poultry"), ("chicken-thigh", "Boneless chicken thigh", "Hähnchenoberkeule ohne Knochen", "poultry"), ("beef-mince", "Beef mince", "Rinderhackfleisch", "beef"), ("lamb-mince", "Lamb mince", "Lammhackfleisch", "lamb"), ("pork-mince", "Pork mince", "Schweinehackfleisch", "pork"), ("bacon", "Smoked bacon", "Räucherspeck", "pork")]:
    ing(i, en, de, "meat", [flag], "protein")
ing("fish", "Fish", "Fisch", flags=["fish"], aisle="protein")
ing("salmon", "Salmon fillet", "Lachsfilet", "fish", aisle="protein")
ing("anchovies", "Anchovies in oil", "Sardellen in Öl", "fish", aisle="pantry")
ing("shellfish", "Shellfish", "Krebstiere", flags=["shellfish"], aisle="protein")
ing("prawns", "Raw peeled prawns", "Rohe geschälte Garnelen", "shellfish", aisle="protein")
ing("eggs", "Eggs", "Eier", flags=["egg"], aisle="chilled")
produce = [
    ("garlic", "Garlic", "Knoblauch", ["high-fodmap"]), ("onion", "Onion", "Zwiebel", ["high-fodmap"]),
    ("spring-onion", "Spring onion greens", "Frühlingszwiebelgrün", []),
    ("tomatoes", "Tomatoes", "Tomaten", []), ("cherry-tomatoes", "Cherry tomatoes", "Kirschtomaten", []),
    ("cucumber", "Cucumber", "Gurke", []), ("red-cabbage", "Red cabbage", "Rotkohl", []),
    ("lettuce", "Romaine lettuce", "Römersalat", []), ("spinach", "Spinach", "Spinat", []),
    ("mushrooms", "Mushrooms", "Pilze", ["high-fodmap"]), ("oyster-mushrooms", "Oyster mushrooms", "Austernpilze", []),
    ("courgette", "Courgette", "Zucchini", []), ("cauliflower", "Cauliflower", "Blumenkohl", ["high-fodmap"]),
    ("broccoli", "Broccoli florets", "Brokkoliröschen", []), ("carrots", "Carrots", "Karotten", []),
    ("potatoes", "Potatoes", "Kartoffeln", []), ("sweet-potato", "Sweet potato", "Süßkartoffel", []),
    ("bell-peppers", "Bell peppers", "Paprika", []), ("aubergine", "Aubergine", "Aubergine", []),
    ("pak-choi", "Pak choi", "Pak Choi", []), ("bean-sprouts", "Mung bean sprouts", "Mungobohnensprossen", []),
    ("lemon", "Lemon", "Zitrone", []), ("lime", "Lime", "Limette", []),
    ("ginger", "Fresh ginger", "Frischer Ingwer", []), ("avocado", "Avocado", "Avocado", ["high-fodmap"]),
    ("apples", "Apples", "Äpfel", ["high-fodmap"]), ("pears", "Pears", "Birnen", ["high-fodmap"]),
    ("banana", "Banana", "Banane", []), ("blueberries", "Blueberries", "Heidelbeeren", []),
    ("strawberries", "Strawberries", "Erdbeeren", []), ("peas", "Peas", "Erbsen", ["high-fodmap"]),
    ("asparagus", "Asparagus", "Spargel", ["high-fodmap"]), ("celery", "Celery", "Sellerie", ["celery"]),
]
for i, en, de, flags in produce:
    ing(i, en, de, "tomatoes" if i == "cherry-tomatoes" else None, flags, "produce")
for i, en, de in [("parsley", "Parsley", "Petersilie"), ("cilantro", "Cilantro", "Koriandergrün"), ("mint", "Mint", "Minze"), ("basil", "Basil", "Basilikum"), ("dill", "Dill", "Dill")]:
    ing(i, en, de, aisle="produce")
pantry = [
    ("olive-oil", "Olive oil", "Olivenöl", []), ("rapeseed-oil", "Rapeseed oil", "Rapsöl", []),
    ("rice", "Basmati rice", "Basmatireis", []), ("risotto-rice", "Arborio rice", "Arborio-Reis", []),
    ("rice-noodles", "Rice noodles", "Reisnudeln", []), ("rice-flour", "Rice flour", "Reismehl", []),
    ("gf-pasta", "Gluten-free fettuccine", "Glutenfreie Fettuccine", []),
    ("oats", "Certified gluten-free oats", "Zertifiziert glutenfreie Haferflocken", []),
    ("chickpeas", "Cooked chickpeas, drained", "Gekochte Kichererbsen, abgetropft", ["high-fodmap"]),
    ("lentils", "Cooked green lentils, drained", "Gekochte grüne Linsen, abgetropft", ["high-fodmap"]),
    ("red-lentils", "Dried red lentils", "Getrocknete rote Linsen", ["high-fodmap"]),
    ("kidney-beans", "Cooked kidney beans, drained", "Gekochte Kidneybohnen, abgetropft", ["high-fodmap"]),
    ("black-beans", "Cooked black beans, drained", "Gekochte schwarze Bohnen, abgetropft", ["high-fodmap"]),
    ("white-beans", "Cooked white beans, drained", "Gekochte weiße Bohnen, abgetropft", ["high-fodmap"]),
    ("canned-tomatoes", "Tinned chopped tomatoes", "Gehackte Tomaten aus der Dose", []),
    ("tomato-paste", "Tomato purée", "Tomatenmark", []),
    ("coconut-milk", "Unsweetened coconut milk", "Ungesüßte Kokosmilch", []),
    ("oat-milk", "Unsweetened gluten-free oat drink", "Ungesüßter glutenfreier Haferdrink", []),
    ("coconut-yogurt", "Unsweetened coconut yogurt", "Ungesüßter Kokosjoghurt", []),
    ("coconut-flakes", "Unsweetened coconut flakes", "Ungesüßte Kokosflocken", []),
    ("nutritional-yeast", "Nutritional yeast", "Hefeflocken", []),
    ("pumpkin-seeds", "Pumpkin seeds", "Kürbiskerne", []), ("sunflower-seeds", "Sunflower seeds", "Sonnenblumenkerne", []),
    ("chia-seeds", "Chia seeds", "Chiasamen", []), ("flaxseed", "Ground flaxseed", "Geschrotete Leinsamen", []),
    ("capers", "Capers in brine", "Kapern in Salzlake", []),
    ("mustard", "Alcohol-free Dijon mustard", "Alkoholfreier Dijon-Senf", ["mustard"]),
    ("tamarind", "Unsweetened tamarind paste", "Ungesüßte Tamarindenpaste", []),
    ("maple-syrup", "Maple syrup", "Ahornsirup", ["added-sugar"]),
    ("sugar", "Brown sugar", "Brauner Zucker", ["added-sugar"]),
    ("honey", "Honey", "Honig", ["honey", "added-sugar"]),
    ("dates", "Pitted dates", "Entsteinte Datteln", ["high-fodmap"]),
    ("baking-powder", "Gluten-free baking powder", "Glutenfreies Backpulver", []),
    ("water", "Water", "Wasser", []),
]
for i, en, de, flags in pantry:
    ing(i, en, de, "tomatoes" if i in ["canned-tomatoes", "tomato-paste"] else None, flags)
for i, en, de in [("salt", "Salt", "Salz"), ("black-pepper", "Black pepper", "Schwarzer Pfeffer"), ("cumin", "Ground cumin", "Gemahlener Kreuzkümmel"), ("paprika", "Smoked paprika", "Geräuchertes Paprikapulver"), ("chili", "Chili flakes", "Chiliflocken"), ("oregano", "Dried oregano", "Getrockneter Oregano"), ("thyme", "Dried thyme", "Getrockneter Thymian"), ("cinnamon", "Ground cinnamon", "Gemahlener Zimt"), ("cardamom", "Ground cardamom", "Gemahlener Kardamom"), ("turmeric", "Ground turmeric", "Gemahlene Kurkuma"), ("coriander", "Ground coriander", "Gemahlener Koriander"), ("vanilla", "Alcohol-free vanilla powder", "Alkoholfreies Vanillepulver")]:
    ing(i, en, de, aisle="spices")


def I(spec):
    """Compact authored quantity notation: ingredient quantity unit."""
    return [{"id": p[0], "quantity": float(p[1]), "unit": p[2]} for p in (x.split() for x in spec.split(","))]


recipes = []
dishes = []


def dish(i, en, de, subtitle_en, subtitle_de, caption_en, caption_de, color, cuisine, extended=False):
    dishes.append({"id": i, "name": tr(en, de), "subtitle": tr(subtitle_en, subtitle_de),
                   "caption": tr(caption_en, caption_de), "color": color, "variants": [],
                   "partition_id": "extended" if extended else "core", "secondary_partitions": [f"cuisine-{cuisine}"] if cuisine else [],
                   "cuisine_tags": [cuisine] if cuisine else ["comfort"],
                   "frequency_tier": "occasional" if extended else "everyday"})


def step(en, de, timer=0, title_en="A little kitchen magic", title_de="Ein wenig Küchenzauber"):
    return {"title": tr(title_en, title_de), "text": tr(en, de), "timer_seconds": timer}


def R(diet, en, de, desc_en, desc_de, effort, minutes, kcal, protein, carbs, fat, quantities, steps, techniques, meal="dinner", variant=None):
    d = dishes[-1]
    rid = f"{d['id']}-{variant or diet}"
    recipe = {"id": rid, "dish_id": d["id"], "title": tr(en, de), "description": tr(desc_en, desc_de),
              "diet": diet, "effort": effort, "calorie_level": "light" if kcal <= 400 else "balanced" if kcal <= 600 else "hearty",
              "time_minutes": minutes, "calories_per_serving": kcal, "servings": 2,
              "contains": [], "attributes": list(techniques) + [meal],
              "tags": list(d["cuisine_tags"]) + [diet, effort, meal] + list(techniques),
              "ingredients": I(quantities), "steps": steps,
              "nutrition": {"protein": protein, "carbs": carbs, "fat": fat},
              "nutrition_note": tr("Approximate values per serving; brands and portions vary.", "Ungefähre Werte pro Portion; Marken und Portionsgrößen variieren."),
              "review_status": "pending-human-review"}
    recipes.append(recipe)
    d["variants"].append(rid)


def write(name, value):
    (ASSETS / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


# Each variant below is a complete recipe with its own quantities and method.
dish("doener", "Döner", "Döner", "a corner-shop classic, made at home.", "Kioskgefühl aus deiner Küche.", "wrapped up in a good thing", "ein kleines Stück Geborgenheit", "#BD7157", "middle-eastern")
R("classic", "Chicken döner with lemon yogurt", "Hähnchen-Döner mit Zitronenjoghurt", "Crisp edges, soft bread, a very good lunch.", "Knusprige Ränder, weiches Brot, ein richtig gutes Mittagessen.", "medium", 30, 595, 44, 59, 20,
  "chicken-thigh 280 g,pita 160 g,yogurt 100 g,red-cabbage 100 g,cucumber 100 g,tomatoes 120 g,lemon 1 piece,garlic 1 clove,olive-oil 1 tbsp,cumin 1 tsp,paprika 1 tsp,salt 0.5 tsp",
  [step("Slice chicken thinly. Toss with oil, cumin, paprika and half the salt. Shred cabbage and slice cucumber and tomato.", "Hähnchen dünn schneiden. Mit Öl, Kreuzkümmel, Paprika und der Hälfte des Salzes mischen. Kohl hobeln, Gurke und Tomate schneiden.", title_en="Slice & season", title_de="Schneiden & würzen"),
   step("Heat a wide pan over medium-high heat. Cook chicken in one layer for 8–10 minutes, turning, until browned and the centre reaches 74°C.", "Eine große Pfanne stark erhitzen. Hähnchen 8–10 Minuten in einer Lage braten, dabei wenden, bis es braun ist und innen 74 °C erreicht.", 600, "Golden edges", "Goldene Ränder"),
   step("Grate garlic into yogurt. Add half the lemon juice and remaining salt. Massage cabbage with the other half of the juice.", "Knoblauch in den Joghurt reiben. Die Hälfte des Zitronensafts und das restliche Salz zugeben. Kohl mit dem übrigen Saft kneten.", title_en="The cool things", title_de="Die frischen Dinge"),
   step("Warm pita in the dry pan for 30 seconds per side. Open carefully and fill with yogurt, vegetables and hot chicken.", "Fladenbrot in der trockenen Pfanne je Seite 30 Sekunden erwärmen. Vorsichtig öffnen und mit Joghurt, Gemüse und heißem Hähnchen füllen.", 60, "Wrap it up", "Alles einpacken")], ["pan-fry"], "lunch")
R("vegetarian", "Halloumi & mint döner", "Halloumi-Minz-Döner", "Salty golden cheese, a tangle of fresh mint.", "Goldener, salziger Käse und eine Handvoll frische Minze.", "easy", 20, 675, 30, 60, 35,
  "halloumi 200 g,pita 160 g,yogurt 80 g,cucumber 150 g,tomatoes 120 g,mint 10 g,lemon 1 piece,olive-oil 1 tsp,paprika 0.5 tsp",
  [step("Pat halloumi dry and cut into 1 cm slabs. Slice cucumber and tomato; roughly tear the mint.", "Halloumi trocken tupfen und in 1 cm dicke Scheiben schneiden. Gurke und Tomate schneiden, Minze grob zupfen.", title_en="A fresh start", title_de="Frisch beginnen"),
   step("Brush cheese with oil and paprika. Fry in a hot non-stick pan for 2 minutes on each side until striped with gold.", "Käse mit Öl und Paprika bestreichen. In einer heißen beschichteten Pfanne je Seite 2 Minuten goldbraun braten.", 240, "Golden halloumi", "Goldener Halloumi"),
   step("Mix yogurt with lemon juice and mint. Warm the pita, spread with yogurt, then tuck in vegetables and halloumi. Eat while the cheese is warm.", "Joghurt mit Zitronensaft und Minze mischen. Brot erwärmen, mit Joghurt bestreichen und Gemüse und Halloumi hineinlegen. Essen, solange der Käse warm ist.", title_en="Fold & eat", title_de="Füllen & genießen")], ["pan-fry"], "lunch")
R("vegan", "Crispy oyster mushroom döner", "Knuspriger Austernpilz-Döner", "Smoky mushrooms and tahini tucked into warm bread.", "Rauchige Pilze und Tahin in warmem Fladenbrot.", "medium", 30, 560, 18, 68, 24,
  "oyster-mushrooms 350 g,pita 160 g,tahini 35 g,red-cabbage 120 g,cucumber 100 g,lemon 1 piece,garlic 1 clove,olive-oil 1 tbsp,paprika 1 tsp,cumin 1 tsp,water 40 ml,salt 0.5 tsp",
  [step("Heat the oven to 220°C. Tear mushrooms into wide strips, toss with oil, paprika, cumin and half the salt, and spread across a metal tray.", "Ofen auf 220 °C vorheizen. Pilze in breite Streifen zupfen, mit Öl, Paprika, Kreuzkümmel und halbem Salz mischen und auf einem Metallblech verteilen.", title_en="Tear & tumble", title_de="Zupfen & mischen"),
   step("Roast mushrooms for 20 minutes, turning halfway, until their edges are crisp. Keep pieces separated so they roast rather than steam.", "Pilze 20 Minuten rösten, nach der Hälfte wenden, bis die Ränder knusprig sind. Stücke mit Abstand verteilen, damit sie rösten.", 1200, "Crisp edges", "Knusprige Ränder"),
   step("Whisk tahini with grated garlic, half the lemon juice, water and remaining salt. Finely shred cabbage and massage with the rest of the lemon. Slice cucumber.", "Tahin mit geriebenem Knoblauch, halbem Zitronensaft, Wasser und übrigem Salz verrühren. Kohl fein hobeln und mit restlicher Zitrone kneten. Gurke schneiden.", title_en="Stir the sesame cream", title_de="Sesamcreme rühren"),
   step("Warm pita in the oven for 2 minutes. Fill with tahini, cabbage, cucumber and the hot mushrooms; spoon over the tray juices.", "Brot 2 Minuten im Ofen erwärmen. Mit Tahin, Kohl, Gurke und heißen Pilzen füllen; den Bratensaft darübergeben.", 120, "Your corner-shop moment", "Dein Kioskmoment")], ["roast"], "lunch")
R("keto", "Lamb döner lettuce bowls", "Lamm-Döner in Salatschalen", "Warm cumin lamb, cool leaves, no fork required.", "Warmes Kreuzkümmellamm und kühle Salatblätter.", "easy", 25, 510, 32, 12, 37,
  "lamb-mince 300 g,lettuce 160 g,cucumber 120 g,tomatoes 100 g,yogurt 100 g,lemon 1 piece,garlic 1 clove,cumin 1 tsp,paprika 1 tsp,olive-oil 1 tsp,salt 0.5 tsp",
  [step("Separate and wash lettuce leaves, then dry them well. Dice cucumber and tomato. Stir yogurt with grated garlic, lemon juice and a pinch of the salt.", "Salatblätter lösen, waschen und gut trocknen. Gurke und Tomate würfeln. Joghurt mit geriebenem Knoblauch, Zitronensaft und etwas Salz verrühren.", title_en="Cool & crunchy", title_de="Kühl & knackig"),
   step("Heat oil in a skillet. Press lamb into a thin layer and leave for 3 minutes. Break up, add cumin, paprika and remaining salt, then fry for 6 minutes until fully cooked to 71°C.", "Öl in einer Pfanne erhitzen. Lamm dünn hineindrücken und 3 Minuten braten. Zerteilen, Kreuzkümmel, Paprika und restliches Salz zugeben und 6 Minuten bis 71 °C Kerntemperatur fertig braten.", 540, "Sizzle the lamb", "Lamm anbraten"),
   step("Nest the leaves in two bowls. Add chopped vegetables, spoon over lamb and its juices, then finish with lemon yogurt.", "Blätter in zwei Schalen legen. Gemüse und Lamm samt Bratensaft hineinfüllen und mit Zitronenjoghurt abschließen.", title_en="Build your bowl", title_de="Schalen füllen")], ["pan-fry"], "lunch")
R("halal", "Spiced chicken & parsley döner", "Gewürz-Hähnchen-Döner mit Petersilie", "A bright, tahini-dressed pocket for the lunch hour.", "Eine frische Teigtasche mit Tahin für die Mittagspause.", "medium", 35, 575, 41, 62, 18,
  "chicken 300 g,pita 160 g,tahini 25 g,parsley 20 g,tomatoes 150 g,onion 50 g,lemon 1 piece,cumin 1 tsp,coriander 1 tsp,olive-oil 1 tbsp,water 40 ml,salt 0.5 tsp",
  [step("Choose chicken sourced for your halal requirements. Cut into strips and coat with oil, cumin, coriander and half the salt. Heat the oven to 210°C.", "Hähnchen passend zu deinen Halal-Anforderungen wählen. In Streifen schneiden, mit Öl, Kreuzkümmel, Koriander und halbem Salz mischen. Ofen auf 210 °C vorheizen.", title_en="Season with care", title_de="Sorgfältig würzen"),
   step("Spread chicken on a tray and roast for 18–22 minutes, turning once, until the thickest piece reaches 74°C.", "Hähnchen auf einem Blech verteilen und 18–22 Minuten rösten, einmal wenden, bis das dickste Stück 74 °C erreicht.", 1200, "Let the oven work", "Der Ofen übernimmt"),
   step("Thinly slice onion; toss with chopped parsley, tomato and half the lemon juice. Whisk tahini with water, remaining lemon juice and salt.", "Zwiebel dünn schneiden; mit gehackter Petersilie, Tomate und halbem Zitronensaft mischen. Tahin mit Wasser, restlichem Zitronensaft und Salz verrühren.", title_en="A parsley tangle", title_de="Petersilienfrische"),
   step("Warm the pita on the oven shelf for 2 minutes. Fill with the parsley salad and chicken, then spoon in the tahini sauce.", "Brot 2 Minuten auf dem Ofenrost erwärmen. Mit Petersiliensalat und Hähnchen füllen und Tahinsauce hineinlöffeln.", 120, "Tuck everything in", "Alles hineinpacken")], ["roast"], "lunch")

dish("alfredo", "Alfredo", "Alfredo", "a little silk, a little Sunday.", "Ein bisschen Seide, ein bisschen Sonntag.", "twirl slowly", "langsam aufdrehen", "#C9A35F", "italian")
R("classic", "Butter & parmesan fettuccine", "Fettuccine mit Butter und Parmesan", "The quiet luxury of three good ingredients.", "Der stille Luxus dreier guter Zutaten.", "easy", 20, 660, 25, 73, 29,
  "pasta 200 g,butter 45 g,parmesan 65 g,black-pepper 0.5 tsp,salt 0.5 tsp",
  [step("Bring a large pan of water to the boil and add salt. Cook fettuccine until just tender, following the packet timing, usually 10 minutes. Reserve 200 ml cooking water.", "Einen großen Topf Wasser aufkochen und salzen. Fettuccine nach Packung knapp gar kochen, meist 10 Minuten. 200 ml Kochwasser aufheben.", 600, "Put the kettle on", "Nudelwasser aufsetzen"),
   step("Finely grate parmesan. Melt butter in a wide pan on low heat with 60 ml of the pasta water; swirl until cloudy.", "Parmesan fein reiben. Butter in einer großen Pfanne bei kleiner Hitze mit 60 ml Nudelwasser schmelzen und schwenken, bis die Mischung trüb ist.", title_en="Make it silky", title_de="Seidig rühren"),
   step("Add drained pasta, turn off the heat and toss in parmesan in three additions. Add reserved water a spoon at a time until glossy. Finish with pepper and serve immediately.", "Abgegossene Nudeln zugeben, Herd ausschalten und Parmesan in drei Portionen unterschwenken. Löffelweise Kochwasser ergänzen, bis die Sauce glänzt. Pfeffern und sofort servieren.", title_en="Toss, don't rush", title_de="In Ruhe schwenken")], ["simmer"])
R("vegetarian", "Pea & lemon Alfredo", "Erbsen-Zitronen-Alfredo", "A green little daydream in a creamy bowl.", "Ein kleiner grüner Tagtraum in cremiger Sauce.", "easy", 25, 590, 26, 77, 20,
  "pasta 180 g,peas 150 g,cream-cheese 70 g,vegetarian-hard-cheese 30 g,lemon 1 piece,whole-milk 100 ml,basil 10 g,black-pepper 0.5 tsp,salt 0.5 tsp",
  [step("Cook pasta in salted boiling water according to the packet. Add peas for the final 3 minutes. Reserve a mug of cooking water before draining.", "Nudeln nach Packung in Salzwasser kochen. Erbsen die letzten 3 Minuten mitgaren. Vor dem Abgießen eine Tasse Kochwasser aufheben.", 600, "Pasta & peas", "Nudeln & Erbsen"),
   step("Warm cream cheese and milk gently in a saucepan. Whisk until smooth, then stir in lemon zest, pepper and finely grated hard cheese with microbial rennet.", "Frischkäse und Milch sanft in einem Topf erwärmen. Glatt rühren, dann Zitronenabrieb, Pfeffer und fein geriebenen Hartkäse mit mikrobiellem Lab einrühren.", title_en="The lemon cream", title_de="Die Zitronencreme"),
   step("Fold pasta and peas into the sauce. Loosen with cooking water as needed; finish with lemon juice to taste and torn basil.", "Nudeln und Erbsen unter die Sauce heben. Nach Bedarf mit Kochwasser lockern; mit Zitronensaft abschmecken und Basilikum darüberzupfen.", title_en="A green finish", title_de="Ein grüner Abschluss")], ["simmer"])
R("vegan", "Roasted cauliflower Alfredo", "Alfredo mit geröstetem Blumenkohl", "Velvety cauliflower, toasted edges and a generous twirl.", "Samtiger Blumenkohl, geröstete Ränder und eine große Gabel.", "medium", 35, 530, 19, 87, 13,
  "gf-pasta 180 g,cauliflower 350 g,white-beans 150 g,oat-milk 180 ml,nutritional-yeast 20 g,garlic 2 clove,olive-oil 1 tbsp,lemon 1 piece,salt 0.5 tsp,black-pepper 0.5 tsp",
  [step("Heat the oven to 220°C. Cut cauliflower into small florets, toss with half the oil and roast with unpeeled garlic for 20 minutes.", "Ofen auf 220 °C heizen. Blumenkohl klein zerteilen, mit halbem Öl mischen und mit ungeschältem Knoblauch 20 Minuten rösten.", 1200, "Roast the good bits", "Die guten Stücke rösten"),
   step("Cook gluten-free pasta according to its packet in salted water. Drain, reserving a mug of cooking water.", "Glutenfreie Nudeln nach Packung in Salzwasser kochen. Abgießen und eine Tasse Kochwasser aufheben.", 600, "A pot of pasta", "Ein Topf Nudeln"),
   step("Peel roasted garlic. Blend it with two-thirds of the cauliflower, beans, oat drink, yeast, remaining oil and lemon juice until very smooth. Season with pepper.", "Gerösteten Knoblauch schälen. Mit zwei Dritteln des Blumenkohls, Bohnen, Haferdrink, Hefeflocken, restlichem Öl und Zitronensaft ganz glatt pürieren. Pfeffern.", title_en="Blend to velvet", title_de="Samtig pürieren"),
   step("Warm the sauce over low heat, fold in pasta and loosen with cooking water. Scatter the remaining roasted florets on top.", "Sauce bei kleiner Hitze erwärmen, Nudeln unterheben und mit Kochwasser lockern. Übrige geröstete Röschen darüberstreuen.", title_en="The final twirl", title_de="Ein letztes Aufdrehen")], ["roast", "simmer"])
R("keto", "Courgette ribbons in parmesan cream", "Zucchinibänder in Parmesancreme", "A soft, peppery supper with a green ribbon through it.", "Ein sanftes, pfeffriges Abendessen mit grünen Bändern.", "easy", 20, 450, 22, 11, 35,
  "courgette 500 g,cream 100 ml,parmesan 60 g,butter 15 g,garlic 1 clove,pumpkin-seeds 20 g,black-pepper 0.5 tsp,salt 0.25 tsp",
  [step("Use a peeler to shave courgettes into broad ribbons, leaving the watery seed core. Toast pumpkin seeds in a dry pan for 2 minutes and set aside.", "Zucchini mit einem Sparschäler in breite Bänder schneiden; den wässrigen Kern aussparen. Kürbiskerne 2 Minuten trocken rösten und beiseitestellen.", 120, "Green ribbons", "Grüne Bänder"),
   step("Melt butter, add grated garlic and stir for 30 seconds. Pour in cream and simmer gently for 3 minutes. Turn heat low and stir in finely grated parmesan.", "Butter schmelzen, geriebenen Knoblauch 30 Sekunden darin rühren. Sahne zugeben und 3 Minuten sanft köcheln. Hitze reduzieren und fein geriebenen Parmesan einrühren.", 180, "A little cream", "Ein wenig Sahne"),
   step("Add courgette ribbons and toss for 2 minutes, just until flexible. Season with salt and pepper; serve at once with toasted seeds.", "Zucchinibänder zugeben und 2 Minuten schwenken, bis sie biegsam sind. Salzen, pfeffern und sofort mit gerösteten Kernen servieren.", 120, "Keep a little bite", "Biss bewahren")], ["sauté", "simmer"])
R("halal", "Chicken & spinach cream pasta", "Hähnchen-Spinat-Sahnepasta", "A generous supper for the table's favourite people.", "Ein großzügiges Abendessen für die liebsten Menschen am Tisch.", "medium", 30, 640, 47, 67, 21,
  "pasta 180 g,chicken 260 g,spinach 150 g,cream 80 ml,whole-milk 100 ml,garlic 1 clove,olive-oil 1 tbsp,lemon 1 piece,black-pepper 0.5 tsp,salt 0.5 tsp",
  [step("Use chicken and pasta suitable for your halal requirements. Boil the pasta in salted water according to the packet; reserve 150 ml of cooking water.", "Hähnchen und Nudeln passend zu deinen Halal-Anforderungen verwenden. Nudeln nach Packung in Salzwasser kochen; 150 ml Kochwasser aufheben.", 600, "Start the pasta", "Nudeln aufsetzen"),
   step("Slice chicken thinly. Heat oil and fry chicken for 7–9 minutes until the centre reaches 74°C. Add grated garlic for the final minute.", "Hähnchen dünn schneiden. Öl erhitzen und Fleisch 7–9 Minuten braten, bis es innen 74 °C erreicht. Knoblauch in der letzten Minute dazureiben.", 540, "Golden chicken", "Goldenes Hähnchen"),
   step("Add milk and cream to the pan. Simmer for 3 minutes, then wilt in the spinach. Add pasta and a splash of reserved water; finish with lemon zest, juice and pepper.", "Milch und Sahne in die Pfanne geben. 3 Minuten köcheln, dann Spinat zusammenfallen lassen. Nudeln und etwas Kochwasser zugeben; mit Zitronenabrieb, Saft und Pfeffer abschließen.", 180, "Bring it together", "Alles zusammenbringen")], ["pan-fry", "simmer"])

dish("pad-thai", "Pad Thai", "Pad Thai", "sweet, sour & a little kitchen clatter.", "Süß, sauer & ein wenig Küchenklappern.", "a squeeze of lime changes everything", "ein Spritzer Limette verändert alles", "#879B80", "asian")
R("classic", "Prawn pad Thai", "Pad Thai mit Garnelen", "Tamarind-tangled noodles with a peanut crunch.", "Nudeln in Tamarinde mit knackigen Erdnüssen.", "medium", 30, 575, 35, 72, 17,
  "rice-noodles 160 g,prawns 240 g,eggs 2 piece,bean-sprouts 120 g,peanuts 25 g,tamarind 25 g,tamari 1 tbsp,sugar 2 tsp,lime 1 piece,rapeseed-oil 1 tbsp,spring-onion 30 g",
  [step("Soak noodles following packet directions until flexible but not soft. Mix tamarind, tamari, sugar and 3 tbsp warm water. Chop peanuts and spring onion greens.", "Nudeln nach Packung einweichen, bis sie biegsam, aber noch fest sind. Tamarinde, Tamari, Zucker und 3 EL warmes Wasser verrühren. Erdnüsse und Zwiebelgrün hacken.", title_en="Everything within reach", title_de="Alles griffbereit"),
   step("Heat oil in a wok. Fry prawns for 3 minutes until opaque and 63°C inside. Push aside, crack in eggs and scramble for 1 minute until set.", "Öl im Wok erhitzen. Garnelen 3 Minuten braten, bis sie undurchsichtig sind und innen 63 °C erreichen. Zur Seite schieben, Eier hineinschlagen und 1 Minute vollständig stocken lassen.", 240, "A hot wok", "Ein heißer Wok"),
   step("Add drained noodles and sauce. Toss for 3–4 minutes, adding a little water if needed, until the noodles are tender. Add sprouts and cook for 2 minutes until piping hot.", "Abgetropfte Nudeln und Sauce zugeben. 3–4 Minuten schwenken, bei Bedarf etwas Wasser ergänzen, bis die Nudeln gar sind. Sprossen zugeben und 2 Minuten gründlich erhitzen.", 360, "Toss the noodles", "Nudeln schwenken"),
   step("Divide between bowls, scatter over peanuts and spring onion greens, and serve with lime wedges.", "Auf Schalen verteilen, Erdnüsse und Zwiebelgrün darüberstreuen und mit Limettenspalten servieren.", title_en="The lime moment", title_de="Der Limettenmoment")], ["stir-fry"])
R("vegetarian", "Golden egg & tofu pad Thai", "Pad Thai mit Ei und goldenem Tofu", "Soft egg ribbons, crisp tofu, a bright finish.", "Zarte Eierstreifen, knuspriger Tofu, frische Limette.", "medium", 30, 620, 30, 74, 23,
  "rice-noodles 160 g,tofu 200 g,eggs 2 piece,carrots 120 g,bean-sprouts 100 g,peanuts 20 g,tamarind 25 g,tamari 1 tbsp,sugar 2 tsp,lime 1 piece,rapeseed-oil 1 tbsp",
  [step("Soak noodles as directed. Pat tofu dry and cut into small cubes. Shave carrots into matchsticks. Stir tamarind, tamari, sugar and 50 ml water together.", "Nudeln nach Packung einweichen. Tofu trocken tupfen und klein würfeln. Karotten in feine Stifte schneiden. Tamarinde, Tamari, Zucker und 50 ml Wasser verrühren.", title_en="A little preparation", title_de="Ein wenig Vorbereitung"),
   step("Heat half the oil in a wok. Beat the eggs, pour in and swirl into a thin omelette. Cook until fully set, transfer to a board and cut into ribbons.", "Die Hälfte des Öls im Wok erhitzen. Eier verquirlen, hineingeben und zu einem dünnen Omelett schwenken. Ganz stocken lassen, auf ein Brett legen und in Streifen schneiden.", 120, "Make the egg ribbons", "Eierstreifen zubereiten"),
   step("Add remaining oil and fry tofu for 5 minutes until golden. Add carrot, drained noodles and sauce; toss for 4 minutes. Add sprouts and cook for 2 minutes, until thoroughly hot.", "Restliches Öl zugeben und Tofu 5 Minuten goldbraun braten. Karotte, abgetropfte Nudeln und Sauce zugeben; 4 Minuten schwenken. Sprossen zugeben und 2 Minuten gut durcherhitzen.", 660, "Noodles meet the wok", "Nudeln treffen Wok"),
   step("Fold through the egg ribbons. Finish with chopped peanuts and lime juice.", "Eierstreifen unterheben. Mit gehackten Erdnüssen und Limettensaft abschließen.", title_en="A bright finish", title_de="Ein frischer Abschluss")], ["stir-fry"])
R("vegan", "Tamarind tofu noodles", "Tamarinden-Tofu-Nudeln", "Sticky-sour noodles with sunflower crunch.", "Süßsaure Nudeln mit knackigen Sonnenblumenkernen.", "easy", 25, 560, 25, 74, 18,
  "rice-noodles 160 g,tofu 250 g,courgette 150 g,carrots 100 g,sunflower-seeds 20 g,tamarind 30 g,tamari 1 tbsp,maple-syrup 2 tsp,lime 1 piece,rapeseed-oil 1 tbsp,cilantro 10 g",
  [step("Soak rice noodles according to the packet. Cut tofu into thin triangles and pat dry. Julienne courgette and carrot. Mix tamarind, tamari, maple syrup and 60 ml water.", "Reisnudeln nach Packung einweichen. Tofu in dünne Dreiecke schneiden und trocken tupfen. Zucchini und Karotte in feine Streifen schneiden. Tamarinde, Tamari, Ahornsirup und 60 ml Wasser mischen.", title_en="Slice & soak", title_de="Schneiden & einweichen"),
   step("Toast sunflower seeds in a dry wok for 2 minutes, then remove. Heat oil and fry tofu for 5 minutes, turning halfway. Add vegetables and stir-fry for 2 minutes.", "Sonnenblumenkerne 2 Minuten trocken im Wok rösten und herausnehmen. Öl erhitzen und Tofu 5 Minuten braten, nach der Hälfte wenden. Gemüse zugeben und 2 Minuten pfannenrühren.", 540, "Golden triangles", "Goldene Dreiecke"),
   step("Add drained noodles and sauce. Toss for 3–4 minutes until tender and glossy, adding water if dry. Serve with sunflower seeds, cilantro and squeezed lime.", "Abgetropfte Nudeln und Sauce zugeben. 3–4 Minuten schwenken, bis sie gar und glänzend sind; bei Trockenheit Wasser ergänzen. Mit Kernen, Koriandergrün und Limettensaft servieren.", 240, "Tangle & serve", "Mischen & servieren")], ["stir-fry"])
R("keto", "Lime chicken cabbage noodles", "Limettenhähnchen auf Kohlnudeln", "A wok supper with plenty of crunch.", "Ein Wok-Abendessen mit viel Biss.", "easy", 25, 435, 41, 15, 23,
  "chicken 300 g,red-cabbage 250 g,eggs 2 piece,peanuts 25 g,tamari 1 tbsp,tamarind 10 g,lime 1 piece,rapeseed-oil 1 tbsp,spring-onion 30 g,ginger 15 g",
  [step("Shred cabbage into noodle-thin ribbons. Slice chicken very thinly. Grate ginger and mix tamari, tamarind, lime juice and 2 tbsp water.", "Kohl in nudeldünne Streifen hobeln. Hähnchen sehr dünn schneiden. Ingwer reiben und Tamari, Tamarinde, Limettensaft und 2 EL Wasser verrühren.", title_en="Cabbage ribbons", title_de="Kohlbänder"),
   step("Heat oil in a wok. Fry chicken with ginger for 7–9 minutes until it reaches 74°C. Move to a plate. Add cabbage and stir-fry for 3 minutes.", "Öl im Wok erhitzen. Hähnchen mit Ingwer 7–9 Minuten bis 74 °C braten. Auf einen Teller legen. Kohl in den Wok geben und 3 Minuten pfannenrühren.", 720, "Keep the wok hot", "Wok heiß halten"),
   step("Push cabbage aside, add beaten eggs and scramble until fully set. Return chicken, pour in the sauce and toss for a minute. Top with peanuts and sliced spring onion greens.", "Kohl zur Seite schieben, verquirlte Eier zugeben und ganz stocken lassen. Hähnchen zurückgeben, Sauce zugießen und eine Minute schwenken. Mit Erdnüssen und Zwiebelgrün bestreuen.", 120, "A final toss", "Zum Schluss schwenken")], ["stir-fry"])
R("halal", "Chicken & sesame pad Thai", "Pad Thai mit Hähnchen und Sesam", "Tamarind, tender chicken and toasted sesame.", "Tamarinde, zartes Hähnchen und gerösteter Sesam.", "medium", 30, 555, 40, 72, 14,
  "rice-noodles 170 g,chicken 300 g,carrots 120 g,bean-sprouts 100 g,sesame 20 g,tamarind 25 g,tamari 1 tbsp,sugar 2 tsp,lime 1 piece,rapeseed-oil 1 tbsp",
  [step("Select chicken for your halal requirements and alcohol-free tamari. Soak noodles according to the packet. Stir tamarind, tamari, sugar and 50 ml water together.", "Hähnchen nach deinen Halal-Anforderungen und alkoholfreies Tamari wählen. Nudeln nach Packung einweichen. Tamarinde, Tamari, Zucker und 50 ml Wasser verrühren.", title_en="A thoughtful beginning", title_de="Sorgfältig beginnen"),
   step("Toast sesame in a dry pan for 2 minutes and remove. Cut chicken into thin strips and carrots into matchsticks. Heat oil and stir-fry chicken for 7–9 minutes to 74°C.", "Sesam 2 Minuten trocken rösten und herausnehmen. Hähnchen dünn und Karotten in feine Stifte schneiden. Öl erhitzen und Hähnchen 7–9 Minuten bis 74 °C pfannenrühren.", 660, "Toast & sizzle", "Rösten & braten"),
   step("Add carrots for 2 minutes, then noodles and sauce for 3–4 minutes until noodles are tender. Fold in sprouts and cook thoroughly for 2 minutes. Finish with sesame and lime wedges.", "Karotten 2 Minuten mitbraten, dann Nudeln und Sauce 3–4 Minuten zugeben, bis die Nudeln gar sind. Sprossen unterheben und 2 Minuten gründlich erhitzen. Mit Sesam und Limettenspalten servieren.", 480, "Bring on the noodles", "Jetzt die Nudeln")], ["stir-fry"])

dish("shakshuka", "Shakshuka", "Shakshuka", "a pan of sunshine for a slow morning.", "Eine Pfanne Sonnenschein für einen langsamen Morgen.", "bring bread, bring a friend", "bring Brot, bring jemanden mit", "#BB6954", "middle-eastern")
R("classic", "Tomato & pepper shakshuka", "Tomaten-Paprika-Shakshuka", "Eggs nestled in a warm red blanket.", "Eier unter einer warmen roten Decke.", "easy", 30, 395, 18, 39, 18,
  "eggs 4 piece,canned-tomatoes 400 g,bell-peppers 180 g,onion 80 g,garlic 1 clove,olive-oil 1 tbsp,cumin 1 tsp,paprika 1 tsp,bread 80 g,parsley 10 g,salt 0.5 tsp",
  [step("Dice pepper and onion. Warm oil in a lidded frying pan and soften them for 7 minutes. Add chopped garlic, cumin and paprika; stir for 1 minute.", "Paprika und Zwiebel würfeln. Öl in einer Pfanne mit Deckel erwärmen und Gemüse 7 Minuten weich dünsten. Gehackten Knoblauch, Kreuzkümmel und Paprikapulver 1 Minute mitrühren.", 480, "Wake the spices", "Gewürze wecken"),
   step("Add tomatoes and salt. Simmer uncovered for 10 minutes, stirring, until the sauce is thick enough to hold a little hollow.", "Tomaten und Salz zugeben. Ohne Deckel 10 Minuten unter Rühren köcheln, bis die Sauce eine kleine Mulde hält.", 600, "A red blanket", "Eine rote Decke"),
   step("Make four hollows and crack in the eggs. Cover and cook on low for 7–9 minutes until whites and yolks are set. Scatter parsley and serve with toasted bread.", "Vier Mulden formen und Eier hineinschlagen. Zugedeckt bei kleiner Hitze 7–9 Minuten garen, bis Eiweiß und Eigelb fest sind. Petersilie darüberstreuen und mit geröstetem Brot servieren.", 540, "Nest the eggs", "Eier einbetten")], ["simmer", "poach"], "breakfast")
R("vegetarian", "Green feta shakshuka", "Grüne Feta-Shakshuka", "A small green garden, with eggs for company.", "Ein kleiner grüner Garten mit Eiern als Gesellschaft.", "easy", 25, 420, 26, 17, 29,
  "eggs 4 piece,spinach 250 g,peas 120 g,feta 80 g,spring-onion 40 g,yogurt 80 g,olive-oil 1 tbsp,dill 10 g,lemon 1 piece,black-pepper 0.5 tsp",
  [step("Slice spring onion greens and chop dill. Warm oil in a lidded skillet; add onion greens and peas with 60 ml water. Simmer for 4 minutes.", "Zwiebelgrün schneiden und Dill hacken. Öl in einer Pfanne mit Deckel erwärmen; Zwiebelgrün, Erbsen und 60 ml Wasser zugeben. 4 Minuten köcheln.", 240, "Start with green", "Grün beginnen"),
   step("Add spinach in handfuls until wilted. Stir in yogurt, lemon zest, half the dill and pepper. Make four wells and crack in the eggs.", "Spinat portionsweise zusammenfallen lassen. Joghurt, Zitronenabrieb, halben Dill und Pfeffer einrühren. Vier Mulden formen und Eier hineinschlagen.", title_en="Make little nests", title_de="Kleine Nester formen"),
   step("Crumble feta around the eggs, cover and cook gently for 8 minutes until eggs are fully set. Finish with remaining dill and a squeeze of lemon.", "Feta um die Eier bröseln, zudecken und 8 Minuten sanft garen, bis die Eier ganz gestockt sind. Mit restlichem Dill und etwas Zitronensaft abschließen.", 480, "A gentle finish", "Sanft fertig garen")], ["simmer", "poach"], "breakfast")
R("vegan", "Chickpea & silken tofu shakshuka", "Shakshuka mit Kichererbsen und Seidentofu", "Soft tofu clouds in a spiced tomato sea.", "Weiche Tofuwolken in einem würzigen Tomatenmeer.", "easy", 30, 385, 23, 35, 17,
  "silken-tofu 300 g,chickpeas 200 g,canned-tomatoes 400 g,bell-peppers 150 g,garlic 2 clove,olive-oil 1 tbsp,cumin 1 tsp,paprika 1 tsp,turmeric 0.25 tsp,parsley 15 g,salt 0.5 tsp",
  [step("Slice pepper and garlic. Fry in oil for 6 minutes. Add cumin, paprika and turmeric for 30 seconds, then stir in tomatoes and salt.", "Paprika und Knoblauch schneiden. In Öl 6 Minuten braten. Kreuzkümmel, Paprikapulver und Kurkuma 30 Sekunden mitrösten, dann Tomaten und Salz einrühren.", 390, "A warm beginning", "Ein warmer Anfang"),
   step("Add drained chickpeas and simmer uncovered for 12 minutes, until thick. Drain tofu carefully and use a large spoon to nest six pieces into the sauce.", "Abgetropfte Kichererbsen zugeben und 12 Minuten offen dicklich köcheln. Tofu vorsichtig abtropfen lassen und mit einem großen Löffel sechs Stücke in die Sauce setzen.", 720, "Tomato sea", "Tomatenmeer"),
   step("Cover and heat gently for 5 minutes without stirring, until tofu is hot through. Scatter chopped parsley and spoon into warm bowls.", "Zudecken und ohne Rühren 5 Minuten sanft erhitzen, bis der Tofu durchgehend heiß ist. Gehackte Petersilie darüberstreuen und in warme Schalen löffeln.", 300, "Keep the clouds whole", "Wolken ganz lassen")], ["simmer"], "breakfast")
R("keto", "Creamy aubergine & egg skillet", "Cremige Auberginen-Eier-Pfanne", "Slow-soft aubergine and rich eggs for a quiet morning.", "Weiche Aubergine und kräftige Eier für einen ruhigen Morgen.", "medium", 35, 480, 24, 16, 36,
  "eggs 4 piece,aubergine 250 g,canned-tomatoes 200 g,feta 80 g,cream 60 ml,olive-oil 1 tbsp,cumin 1 tsp,chili 0.25 tsp,parsley 10 g,salt 0.25 tsp",
  [step("Dice aubergine into 1 cm cubes. Fry with oil and salt for 8 minutes, turning often. Add 60 ml water and cover for 4 minutes to soften.", "Aubergine in 1 cm große Würfel schneiden. Mit Öl und Salz 8 Minuten unter Wenden braten. 60 ml Wasser zugeben und zugedeckt 4 Minuten weich garen.", 720, "Soften the aubergine", title_de="Aubergine weich garen"),
   step("Stir in cumin, chili and tomatoes. Simmer for 8 minutes, then fold through cream. Make four wells and add eggs.", "Kreuzkümmel, Chili und Tomaten einrühren. 8 Minuten köcheln, dann Sahne unterziehen. Vier Mulden formen und Eier hineingeben.", 480, "A creamy red sauce", "Eine cremige rote Sauce"),
   step("Scatter feta between the eggs. Cover and cook on low for 8 minutes until eggs are set. Finish with parsley.", "Feta zwischen die Eier streuen. Zugedeckt bei kleiner Hitze 8 Minuten garen, bis die Eier gestockt sind. Mit Petersilie abschließen.", 480, "Set the eggs softly", "Eier sanft stocken")], ["simmer", "poach"], "breakfast")
R("halal", "Cumin beef breakfast skillet", "Frühstückspfanne mit Kreuzkümmel-Rind", "A hearty pan with a bright parsley finish.", "Eine herzhafte Pfanne mit frischer Petersilie.", "medium", 30, 440, 36, 17, 25,
  "beef-mince 220 g,eggs 2 piece,canned-tomatoes 400 g,bell-peppers 150 g,onion 60 g,olive-oil 1 tsp,cumin 1 tsp,paprika 1 tsp,parsley 15 g,salt 0.5 tsp",
  [step("Choose beef according to your halal sourcing requirements. Dice onion and pepper. Heat oil and brown beef for 6 minutes, breaking it into small pieces.", "Rindfleisch gemäß deinen Halal-Anforderungen wählen. Zwiebel und Paprika würfeln. Öl erhitzen und Hack 6 Minuten krümelig anbraten.", 360, "Brown the beef", "Rind anbraten"),
   step("Add onion and pepper for 5 minutes, then cumin, paprika, tomatoes and salt. Simmer for 10 minutes. The beef must reach 71°C before adding eggs.", "Zwiebel und Paprika 5 Minuten mitbraten, dann Kreuzkümmel, Paprikapulver, Tomaten und Salz zugeben. 10 Minuten köcheln. Vor Zugabe der Eier muss das Hack 71 °C erreichen.", 900, "Let the sauce settle", "Sauce köcheln lassen"),
   step("Make two wells, add eggs and cover. Cook gently for 7–9 minutes until fully set. Scatter parsley and serve from the pan.", "Zwei Mulden formen, Eier zugeben und zudecken. 7–9 Minuten sanft garen, bis sie ganz gestockt sind. Petersilie darüberstreuen und aus der Pfanne servieren.", 540, "Breakfast is ready", "Frühstück ist fertig")], ["simmer", "poach"], "breakfast")

dish("risotto", "Risotto", "Risotto", "stir, breathe, repeat.", "Rühren, atmen, wiederholen.", "good things take a wooden spoon", "gute Dinge brauchen einen Holzlöffel", "#AA9978", "italian")
R("classic", "Mushroom & parmesan risotto", "Pilz-Parmesan-Risotto", "An unhurried bowl, earthy and soft.", "Eine Schale ohne Eile, erdig und sanft.", "medium", 40, 615, 19, 80, 23,
  "risotto-rice 180 g,mushrooms 250 g,onion 80 g,parmesan 50 g,butter 25 g,olive-oil 1 tbsp,garlic 1 clove,thyme 1 tsp,water 800 ml,salt 0.75 tsp,black-pepper 0.5 tsp",
  [step("Keep salted water hot in a saucepan. Slice mushrooms and fry in oil for 7 minutes until browned; remove half for topping.", "Salzwasser in einem Topf heiß halten. Pilze schneiden und in Öl 7 Minuten braun braten; die Hälfte zum Garnieren herausnehmen.", 420, "Brown the mushrooms", "Pilze bräunen"),
   step("Add chopped onion, garlic and half the butter to the pan for 4 minutes. Stir in rice and thyme for 1 minute. Add hot water a ladle at a time, stirring until each addition is absorbed.", "Gehackte Zwiebel, Knoblauch und halbe Butter 4 Minuten mitdünsten. Reis und Thymian 1 Minute einrühren. Heißes Wasser schöpfkellenweise zugeben und jeweils unter Rühren aufnehmen lassen.", title_en="A wooden-spoon rhythm", title_de="Holzlöffelrhythmus"),
   step("Continue for 20–23 minutes until rice is tender with a slight bite. Remove from heat, stir in grated parmesan and remaining butter, and rest 2 minutes. Top with mushrooms and pepper.", "20–23 Minuten fortfahren, bis der Reis mit leichtem Biss gar ist. Vom Herd nehmen, Parmesan und restliche Butter einrühren und 2 Minuten ruhen lassen. Pilze und Pfeffer darübergeben.", 1380, "Stir & rest", "Rühren & ruhen")], ["simmer"])
R("vegetarian", "Lemon asparagus risotto", "Zitronen-Spargel-Risotto", "Spring at the table, whatever the weather.", "Frühling am Tisch, bei jedem Wetter.", "medium", 35, 540, 19, 77, 17,
  "risotto-rice 170 g,asparagus 250 g,peas 100 g,vegetarian-hard-cheese 45 g,butter 20 g,spring-onion 40 g,lemon 1 piece,water 750 ml,salt 0.5 tsp,black-pepper 0.5 tsp",
  [step("Trim asparagus, cut stalks into small rounds and keep tips whole. Heat salted water in a saucepan. Soften sliced spring onion greens in half the butter for 2 minutes.", "Spargel putzen, Stangen klein schneiden und Spitzen ganz lassen. Salzwasser in einem Topf erhitzen. Zwiebelgrün in halber Butter 2 Minuten weich dünsten.", 120, "A spring beginning", "Ein Frühlingsanfang"),
   step("Add rice and stir for 1 minute. Add hot water a ladle at a time, stirring often. After 12 minutes add asparagus stalks; after another 5 minutes add tips and peas.", "Reis 1 Minute einrühren. Heißes Wasser unter häufigem Rühren schöpfkellenweise zugeben. Nach 12 Minuten Spargelstangen, weitere 5 Minuten später Spitzen und Erbsen zugeben.", 1020, "One ladle at a time", "Kelle für Kelle"),
   step("Cook 5 more minutes until rice and vegetables are tender. Off the heat, add grated cheese, remaining butter, lemon zest and juice. Season with pepper and rest 2 minutes.", "Weitere 5 Minuten garen, bis Reis und Gemüse weich sind. Abseits der Hitze geriebenen Käse, restliche Butter, Zitronenabrieb und Saft einrühren. Pfeffern und 2 Minuten ruhen lassen.", 300, "Bright & creamy", "Frisch & cremig")], ["simmer"])
R("vegan", "Roasted tomato & basil risotto", "Risotto mit Ofentomaten und Basilikum", "Jammy tomatoes, soft rice, green flecks.", "Schmelzende Tomaten, weicher Reis, grüne Tupfer.", "medium", 40, 510, 17, 82, 13,
  "risotto-rice 170 g,cherry-tomatoes 300 g,white-beans 180 g,onion 60 g,garlic 2 clove,olive-oil 1 tbsp,nutritional-yeast 20 g,basil 15 g,water 750 ml,salt 0.5 tsp,black-pepper 0.5 tsp",
  [step("Heat oven to 210°C. Toss tomatoes and whole peeled garlic with half the oil and roast for 25 minutes. Keep salted water hot on the hob.", "Ofen auf 210 °C heizen. Tomaten und ganze geschälte Knoblauchzehen mit halbem Öl mischen und 25 Minuten rösten. Salzwasser auf dem Herd heiß halten.", 1500, "Roast a little sweetness", "Süße rösten"),
   step("Soften finely chopped onion in remaining oil for 4 minutes. Stir in rice, then add hot water a ladle at a time for 20–23 minutes, stirring frequently.", "Fein gehackte Zwiebel in restlichem Öl 4 Minuten dünsten. Reis einrühren, dann 20–23 Minuten unter häufigem Rühren heißes Wasser schöpfkellenweise zugeben.", 1380, "The stirring hour", "Zeit zum Rühren"),
   step("Mash beans and roasted garlic together. Fold into the tender rice with yeast and all the tomato juices. Rest for 2 minutes; top with roasted tomatoes, basil and pepper.", "Bohnen und gerösteten Knoblauch zerdrücken. Mit Hefeflocken und sämtlichem Tomatensaft unter den garen Reis heben. 2 Minuten ruhen; mit Ofentomaten, Basilikum und Pfeffer abschließen.", 120, "A red & green finish", "Ein roter & grüner Abschluss")], ["roast", "simmer"])
R("keto", "Mushroom cauliflower risotto", "Blumenkohl-Pilz-Risotto", "All the spoonable comfort, with toasted hazy edges.", "Löffelweise Geborgenheit mit gerösteten Rändern.", "easy", 25, 425, 19, 17, 31,
  "cauliflower 450 g,mushrooms 250 g,cream 80 ml,parmesan 50 g,butter 20 g,garlic 1 clove,thyme 1 tsp,parsley 10 g,salt 0.25 tsp,black-pepper 0.5 tsp",
  [step("Pulse cauliflower into rice-sized grains. Slice mushrooms. Heat butter in a wide pan and brown mushrooms for 7 minutes without crowding.", "Blumenkohl zu reiskorngroßen Stückchen zerkleinern. Pilze schneiden. Butter in einer breiten Pfanne erhitzen und Pilze 7 Minuten mit genügend Platz bräunen.", 420, "A different kind of rice", "Eine andere Art Reis"),
   step("Add grated garlic and thyme for 30 seconds. Stir in cauliflower and 80 ml water; cover for 5 minutes. Uncover and stir until excess water evaporates.", "Geriebener Knoblauch und Thymian 30 Sekunden mitrühren. Blumenkohl und 80 ml Wasser zugeben; 5 Minuten zugedeckt garen. Öffnen und überschüssiges Wasser verdampfen lassen.", 300, "Gently soften", "Sanft weich garen"),
   step("Pour in cream and simmer for 3 minutes. Turn off heat, stir in parmesan, salt and pepper. Finish with chopped parsley.", "Sahne zugießen und 3 Minuten köcheln. Herd ausschalten, Parmesan, Salz und Pfeffer einrühren. Mit gehackter Petersilie abschließen.", 180, "Cream & comfort", "Sahne & Geborgenheit")], ["sauté", "simmer"])
R("halal", "Chicken & carrot golden rice", "Goldener Hähnchen-Karotten-Reis", "A golden one-pot supper with risotto softness.", "Ein goldener Eintopf mit der Weichheit eines Risottos.", "medium", 40, 570, 39, 73, 14,
  "risotto-rice 170 g,chicken 280 g,carrots 150 g,onion 60 g,olive-oil 1 tbsp,turmeric 0.5 tsp,cumin 0.5 tsp,parsley 15 g,lemon 1 piece,water 800 ml,salt 0.5 tsp",
  [step("Choose chicken for your halal requirements. Dice chicken and carrots small. Fry chicken in oil for 7 minutes to 74°C; remove to a clean plate. Keep salted water hot.", "Hähnchen nach deinen Halal-Anforderungen wählen. Fleisch und Karotten klein würfeln. Hähnchen in Öl 7 Minuten bis 74 °C braten; auf einen sauberen Teller legen. Salzwasser heiß halten.", 420, "A golden beginning", "Ein goldener Anfang"),
   step("Soften chopped onion and carrots in the same pan for 4 minutes. Add rice, turmeric and cumin. Stir in hot water a ladle at a time for 22 minutes until rice is tender.", "Gehackte Zwiebel und Karotten in derselben Pfanne 4 Minuten dünsten. Reis, Kurkuma und Kreuzkümmel zugeben. 22 Minuten heißes Wasser schöpfkellenweise einrühren, bis der Reis gar ist.", 1320, "Little by little", "Nach und nach"),
   step("Return chicken for the final 3 minutes, until piping hot. Finish with lemon juice and chopped parsley, then rest covered off the heat for 2 minutes.", "Hähnchen für die letzten 3 Minuten zugeben und gründlich erhitzen. Zitronensaft und Petersilie einrühren und abgedeckt ohne Hitze 2 Minuten ruhen lassen.", 180, "Supper settles", "Das Abendessen ruht")], ["simmer"])

dish("pancakes", "Pancakes", "Pancakes", "leave the morning a little room.", "Lass dem Morgen ein wenig Raum.", "one more, then the day can begin", "noch einer, dann beginnt der Tag", "#C99B81", "", False)
R("classic", "Buttermilk-style berry pancakes", "Joghurt-Pancakes mit Beeren", "A little stack for a very slow start.", "Ein kleiner Stapel für einen sehr langsamen Start.", "easy", 25, 580, 20, 83, 19,
  "flour 150 g,whole-milk 150 ml,yogurt 100 g,eggs 1 piece,butter 20 g,baking-powder 2 tsp,blueberries 120 g,maple-syrup 2 tbsp,salt 0.25 tsp",
  [step("Whisk flour, baking powder and salt. In another bowl whisk milk, yogurt and egg; fold into the dry ingredients just until combined. Rest for 5 minutes.", "Mehl, Backpulver und Salz mischen. Milch, Joghurt und Ei separat verquirlen; kurz unter die trockenen Zutaten heben. 5 Minuten ruhen lassen.", 300, "A bowl & a whisk", "Schüssel & Schneebesen"),
   step("Heat a non-stick pan on medium-low and melt a little butter. Spoon in small pancakes; dot with half the berries. Cook 2 minutes until bubbles appear, then turn and cook 2 minutes until set inside.", "Beschichtete Pfanne auf mittlerer bis kleiner Stufe erhitzen und etwas Butter schmelzen. Kleine Teigportionen hineingeben; mit halben Beeren belegen. 2 Minuten bis zur Bläschenbildung backen, wenden und weitere 2 Minuten innen durchbacken.", 240, "Wait for bubbles", "Auf Bläschen warten"),
   step("Repeat with remaining batter and butter, keeping cooked pancakes warm at 80°C. Stack and serve with remaining berries and maple syrup.", "Mit restlichem Teig und Butter wiederholen; fertige Pancakes bei 80 °C warm halten. Stapeln und mit übrigen Beeren und Ahornsirup servieren.", title_en="A small stack", title_de="Ein kleiner Stapel")], ["pan-fry"], "breakfast")
R("vegetarian", "Banana oat griddle cakes", "Bananen-Hafer-Pancakes", "Sweet banana, a golden edge, no hurry.", "Süße Banane, goldene Ränder, keine Eile.", "easy", 20, 460, 20, 64, 14,
  "oats 110 g,banana 150 g,eggs 2 piece,yogurt 120 g,whole-milk 80 ml,baking-powder 1 tsp,cinnamon 0.5 tsp,rapeseed-oil 2 tsp,strawberries 120 g",
  [step("Blend oats into flour. Add banana, eggs, milk, baking powder, cinnamon and half the yogurt. Blend briefly and rest for 3 minutes so the oats absorb moisture.", "Haferflocken zu Mehl mixen. Banane, Eier, Milch, Backpulver, Zimt und halben Joghurt zugeben. Kurz mixen und 3 Minuten quellen lassen.", 180, "The blender breakfast", "Frühstück aus dem Mixer"),
   step("Heat a lightly oiled pan on medium-low. Cook tablespoon-sized cakes for 2–3 minutes per side, turning only when edges are firm. The centres should be fully set.", "Leicht geölte Pfanne auf mittlerer bis kleiner Stufe erhitzen. Esslöffelgroße Küchlein je Seite 2–3 Minuten backen; erst bei festen Rändern wenden. Innen vollständig durchbacken.", 360, "Small is lovely", "Klein ist fein"),
   step("Slice strawberries. Divide cakes between plates and spoon over the remaining yogurt and berries.", "Erdbeeren schneiden. Küchlein auf Teller verteilen und übrigen Joghurt und Beeren darübergeben.", title_en="A spoon of yogurt", title_de="Ein Löffel Joghurt")], ["pan-fry"], "breakfast")
R("vegan", "Lemon pop-of-blueberry pancakes", "Zitronen-Heidelbeer-Pancakes", "Bright berries tucked into soft oat-milk batter.", "Frische Beeren in weichem Haferdrinkteig.", "easy", 25, 485, 10, 86, 12,
  "flour 150 g,oat-milk 220 ml,flaxseed 12 g,baking-powder 2 tsp,lemon 1 piece,blueberries 150 g,rapeseed-oil 1 tbsp,maple-syrup 1 tbsp,salt 0.25 tsp",
  [step("Mix flaxseed with 40 ml warm water and leave for 5 minutes. Whisk oat drink with lemon zest and 1 tbsp lemon juice.", "Leinsamen mit 40 ml warmem Wasser mischen und 5 Minuten stehen lassen. Haferdrink mit Zitronenabrieb und 1 EL Zitronensaft verquirlen.", 300, "A little patience", "Ein wenig Geduld"),
   step("Mix flour, baking powder and salt. Fold in the oat mixture, soaked flax and half the oil. Fold in blueberries without crushing them.", "Mehl, Backpulver und Salz mischen. Hafermischung, gequollene Leinsamen und halbes Öl unterheben. Heidelbeeren vorsichtig unterziehen.", title_en="Fold in the blue", title_de="Blau unterheben"),
   step("Brush a pan with remaining oil. Cook small pancakes over medium-low heat for 3 minutes per side until springy and cooked through. Drizzle with maple syrup and remaining lemon juice to taste.", "Pfanne mit restlichem Öl bepinseln. Kleine Pancakes bei mittlerer bis kleiner Hitze je Seite 3 Minuten elastisch und durchbacken. Mit Ahornsirup und nach Geschmack übrigem Zitronensaft beträufeln.", 360, "Golden little rounds", title_de="Goldene kleine Kreise")], ["pan-fry"], "breakfast")
R("keto", "Almond & cream cheese pancakes", "Mandel-Frischkäse-Pancakes", "Tender little pancakes with a strawberry blush.", "Zarte kleine Pancakes mit Erdbeerrosa.", "easy", 20, 485, 25, 13, 38,
  "almond-flour 70 g,cream-cheese 80 g,eggs 3 piece,baking-powder 0.5 tsp,vanilla 0.25 tsp,butter 10 g,strawberries 100 g,yogurt 60 g",
  [step("Whisk eggs and cream cheese until smooth. Stir in ground almonds, baking powder and vanilla; rest for 3 minutes.", "Eier und Frischkäse glatt verquirlen. Mandeln, Backpulver und Vanille einrühren; 3 Minuten ruhen lassen.", 180, "Whisk until smooth", "Glatt rühren"),
   step("Heat a non-stick pan on low-medium. Melt butter in batches and cook very small pancakes for 2–3 minutes each side. Wait for firm edges before turning; cook the egg batter through.", "Beschichtete Pfanne auf kleiner bis mittlerer Stufe erhitzen. Butter portionsweise schmelzen und sehr kleine Pancakes je Seite 2–3 Minuten backen. Erst bei festen Rändern wenden; Eierteig vollständig durchbacken.", 360, "A gentle griddle", "Sanft ausbacken"),
   step("Slice strawberries thinly. Serve pancakes with yogurt and berries; the batter needs no added sweetener.", "Erdbeeren dünn schneiden. Pancakes mit Joghurt und Beeren servieren; der Teig braucht keine zusätzliche Süße.", title_en="A berry finish", title_de="Ein beeriger Abschluss")], ["pan-fry"], "breakfast")
R("halal", "Date & cardamom breakfast pancakes", "Dattel-Kardamom-Pancakes", "Little golden rounds, fragrant as a quiet café.", "Kleine goldene Kreise, duftend wie ein stilles Café.", "medium", 30, 555, 17, 87, 15,
  "flour 140 g,whole-milk 180 ml,eggs 1 piece,dates 70 g,yogurt 100 g,baking-powder 1.5 tsp,cardamom 0.5 tsp,rapeseed-oil 1 tbsp,water 60 ml,salt 0.25 tsp",
  [step("Chop dates and simmer with 60 ml water and half the cardamom for 5 minutes. Mash into a spoonable sauce; add a splash more water if thick.", "Datteln hacken und mit 60 ml Wasser und halbem Kardamom 5 Minuten köcheln. Zu einer löffelbaren Sauce zerdrücken; falls nötig Wasser ergänzen.", 300, "A date-sweet morning", "Ein dattelsüßer Morgen"),
   step("Whisk flour, baking powder, salt and remaining cardamom. Whisk egg with milk and half the yogurt, then stir into the flour just until combined.", "Mehl, Backpulver, Salz und übrigen Kardamom mischen. Ei mit Milch und halbem Joghurt verquirlen und kurz unter das Mehl rühren.", title_en="Spice the batter", title_de="Teig würzen"),
   step("Cook small pancakes in a lightly oiled pan on medium-low for 2–3 minutes per side until fully set. Serve with date sauce and remaining yogurt. Check packaged ingredients against your halal sourcing needs.", "Kleine Pancakes in leicht geölter Pfanne bei mittlerer bis kleiner Hitze je Seite 2–3 Minuten durchbacken. Mit Dattelsauce und übrigem Joghurt servieren. Verpackte Zutaten anhand deiner Halal-Anforderungen prüfen.", 360, "A fragrant stack", title_de="Ein duftender Stapel")], ["pan-fry"], "breakfast")

dish("ramen", "Ramen", "Ramen", "a warm bowl for a rainy window.", "Eine warme Schale am Regenfenster.", "slurp with feeling", "mit Gefühl schlürfen", "#7F9596", "asian")
R("classic", "Ginger pork ramen", "Ingwer-Schweinefleisch-Ramen", "A savoury broth with a golden, crumbled topping.", "Würzige Brühe mit goldbraunen Hackfleischkrümeln.", "medium", 30, 630, 35, 66, 25,
  "ramen-noodles 160 g,pork-mince 220 g,pak-choi 200 g,eggs 2 piece,ginger 20 g,garlic 1 clove,miso 25 g,tamari 1 tbsp,sesame-oil 1 tsp,water 800 ml,spring-onion 30 g",
  [step("Boil eggs for 10 minutes, cool and peel. Brown pork in sesame oil for 7 minutes to 71°C, breaking it into crumbs. Add grated ginger and garlic for 1 minute.", "Eier 10 Minuten kochen, abschrecken und schälen. Hack in Sesamöl 7 Minuten bis 71 °C krümelig braten. Geriebenen Ingwer und Knoblauch 1 Minute mitbraten.", 600, "The savoury topping", "Der würzige Belag"),
   step("Bring water and tamari to a simmer. Add noodles and cook to packet instructions, adding quartered pak choi for the final 3 minutes.", "Wasser und Tamari aufkochen. Nudeln nach Packung darin garen, geviertelten Pak Choi die letzten 3 Minuten mitgaren.", 360, "Build the broth", "Brühe aufsetzen"),
   step("Take broth off the heat. Mix miso with a ladle of broth, then stir back in. Divide into bowls and top with pork, halved eggs and sliced spring onion greens.", "Brühe vom Herd nehmen. Miso mit einer Kelle Brühe verrühren und zurückgeben. Auf Schalen verteilen, mit Hack, halbierten Eiern und Zwiebelgrün belegen.", title_en="A bowl to hold", title_de="Eine Schale zum Wärmen")], ["simmer"])
R("vegetarian", "Miso mushroom & egg ramen", "Miso-Pilz-Ramen mit Ei", "An earthy bowl with a soft sesame finish.", "Eine erdige Schale mit sanftem Sesamabschluss.", "easy", 25, 490, 26, 61, 16,
  "ramen-noodles 150 g,mushrooms 200 g,eggs 2 piece,spinach 120 g,miso 30 g,tamari 1 tbsp,sesame 15 g,ginger 15 g,rapeseed-oil 1 tsp,water 800 ml",
  [step("Boil eggs for 10 minutes, cool and peel. Slice mushrooms and fry in oil for 6 minutes until browned. Grate ginger into the pan for 30 seconds.", "Eier 10 Minuten kochen, abschrecken und schälen. Pilze schneiden und in Öl 6 Minuten bräunen. Ingwer dazureiben und 30 Sekunden mitbraten.", 600, "Eggs & earthy edges", "Eier & Pilzränder"),
   step("Add water and tamari, bring to a boil, then cook noodles according to the packet. Stir in spinach for the final minute.", "Wasser und Tamari zugeben, aufkochen und Nudeln nach Packung darin garen. Spinat in der letzten Minute einrühren.", 360, "A gentle simmer", "Sanft köcheln"),
   step("Remove from heat and dissolve miso in a little broth before stirring it back in. Serve with egg halves and sesame seeds.", "Vom Herd nehmen, Miso in wenig Brühe auflösen und zurückrühren. Mit Eihälften und Sesam servieren.", title_en="Finish off the heat", title_de="Ohne Hitze abschließen")], ["simmer"])
R("vegan", "Sesame tofu rice-noodle ramen", "Sesam-Tofu-Ramen mit Reisnudeln", "A creamy broth, a crisp tofu corner.", "Cremige Brühe und ein knuspriges Stück Tofu.", "medium", 30, 550, 29, 60, 22,
  "rice-noodles 130 g,tofu 260 g,pak-choi 200 g,tahini 25 g,miso 25 g,tamari 1 tbsp,ginger 20 g,rapeseed-oil 1 tbsp,water 850 ml,spring-onion 30 g",
  [step("Press tofu between towels and cut into cubes. Fry in oil for 8 minutes, turning to colour all sides. Remove from the pan and set aside.", "Tofu zwischen Tüchern ausdrücken und würfeln. In Öl 8 Minuten unter Wenden rundum bräunen. Aus der Pfanne nehmen und beiseitestellen.", 480, "Golden little cubes", "Goldene kleine Würfel"),
   step("Simmer water with grated ginger and tamari for 5 minutes. Add rice noodles and cook as the packet directs; add sliced pak choi for the final 3 minutes.", "Wasser mit geriebenem Ingwer und Tamari 5 Minuten köcheln. Reisnudeln nach Packung darin garen; geschnittenen Pak Choi die letzten 3 Minuten zugeben.", 480, "Ginger-scented steam", "Ingwerduftender Dampf"),
   step("Whisk tahini and miso with a ladle of broth. Remove the pot from heat and stir the mixture in. Top bowls with tofu and spring onion greens.", "Tahin und Miso mit einer Kelle Brühe verquirlen. Topf vom Herd nehmen und die Mischung einrühren. Schalen mit Tofu und Zwiebelgrün belegen.", title_en="The sesame swirl", title_de="Der Sesamwirbel")], ["pan-fry", "simmer"])
R("keto", "Salmon & courgette noodle broth", "Lachsbrühe mit Zucchininudeln", "A clear, ginger-warm bowl with delicate salmon.", "Eine klare, ingwerwarme Schale mit zartem Lachs.", "easy", 25, 405, 34, 11, 25,
  "salmon 300 g,courgette 350 g,spinach 100 g,ginger 20 g,tamari 1 tbsp,sesame-oil 2 tsp,sesame 10 g,lime 1 piece,water 750 ml",
  [step("Cut courgette into fine ribbons. Simmer water, sliced ginger and tamari for 8 minutes to make a fragrant broth.", "Zucchini in feine Bänder schneiden. Wasser, geschnittenen Ingwer und Tamari 8 Minuten zu einer duftenden Brühe köcheln.", 480, "A fragrant pot", "Ein duftender Topf"),
   step("Cut salmon into four pieces. Lower into gently simmering broth and poach for 6–8 minutes until opaque and 63°C in the centre.", "Lachs in vier Stücke schneiden. In die leicht köchelnde Brühe legen und 6–8 Minuten pochieren, bis er undurchsichtig ist und innen 63 °C erreicht.", 480, "Poach gently", "Sanft pochieren"),
   step("Lift salmon into two bowls. Add courgette and spinach to the broth for 2 minutes. Ladle over salmon; finish with sesame oil, sesame seeds and lime.", "Lachs in zwei Schalen heben. Zucchini und Spinat 2 Minuten in der Brühe garen. Über den Lachs schöpfen; mit Sesamöl, Sesam und Limette abschließen.", 120, "A clear finish", title_de="Ein klarer Abschluss")], ["poach", "simmer"])
R("halal", "Chicken ginger noodle soup", "Hähnchen-Ingwer-Nudelsuppe", "A bright, clear bowl to warm your hands around.", "Eine klare, frische Schale zum Händewärmen.", "easy", 30, 480, 42, 62, 8,
  "rice-noodles 150 g,chicken 300 g,carrots 150 g,pak-choi 150 g,ginger 25 g,tamari 1 tbsp,lemon 1 piece,spring-onion 30 g,water 900 ml,rapeseed-oil 1 tsp",
  [step("Choose suitable halal-sourced chicken and alcohol-free tamari. Simmer water with sliced ginger, thin carrot rounds and tamari for 7 minutes.", "Passend halal bezogenes Hähnchen und alkoholfreies Tamari wählen. Wasser mit Ingwerscheiben, dünnen Karottenringen und Tamari 7 Minuten köcheln.", 420, "A clear beginning", "Ein klarer Anfang"),
   step("Add thinly sliced chicken and poach for 8 minutes until the centre reaches 74°C. Add noodles according to packet timing and pak choi for the final 3 minutes.", "Dünn geschnittenes Hähnchen zugeben und 8 Minuten bis 74 °C pochieren. Nudeln entsprechend ihrer Packungszeit und Pak Choi für die letzten 3 Minuten zugeben.", 660, "A gentle poach", title_de="Sanft pochieren"),
   step("Remove large ginger pieces if desired. Divide into bowls and finish with lemon juice, a little rapeseed oil and sliced spring onion greens.", "Große Ingwerstücke nach Wunsch entfernen. In Schalen geben und mit Zitronensaft, etwas Rapsöl und Zwiebelgrün abschließen.", title_en="Hold a warm bowl", title_de="Eine warme Schale halten")], ["poach", "simmer"])

dish("chili", "Chili", "Chili", "one pot, all the warm feelings.", "Ein Topf, lauter warme Gefühle.", "better with a second spoon", "mit einem zweiten Löffel noch besser", "#A56858", "")
R("classic", "Beef & kidney bean chili", "Chili mit Rind und Kidneybohnen", "A deep red pot with a slow-cooked feeling.", "Ein tiefroter Topf mit dem Gefühl von langem Köcheln.", "easy", 40, 530, 40, 42, 22,
  "beef-mince 280 g,kidney-beans 240 g,canned-tomatoes 400 g,onion 80 g,bell-peppers 150 g,garlic 2 clove,olive-oil 1 tbsp,cumin 1 tsp,paprika 1 tsp,chili 0.5 tsp,salt 0.5 tsp",
  [step("Dice onion and pepper; chop garlic. Brown beef in oil for 7 minutes, breaking it up. Add vegetables and cook for 5 minutes.", "Zwiebel und Paprika würfeln, Knoblauch hacken. Hack in Öl 7 Minuten krümelig anbraten. Gemüse zugeben und 5 Minuten mitbraten.", 720, "Build a deep base", title_de="Eine kräftige Basis"),
   step("Stir in cumin, paprika and chili for 30 seconds. Add tomatoes, drained beans, salt and 100 ml water. Bring to a bubble.", "Kreuzkümmel, Paprikapulver und Chili 30 Sekunden einrühren. Tomaten, abgetropfte Bohnen, Salz und 100 ml Wasser zugeben. Aufkochen.", title_en="A red pot", title_de="Ein roter Topf"),
   step("Simmer uncovered for 25 minutes, stirring occasionally, until thick. Check beef reaches 71°C. Rest for 3 minutes before spooning into bowls.", "25 Minuten offen unter gelegentlichem Rühren dicklich köcheln. Prüfen, dass das Hack 71 °C erreicht. Vor dem Servieren 3 Minuten ruhen lassen.", 1500, "Let it settle", title_de="Zur Ruhe kommen")], ["simmer"])
R("vegetarian", "Sweet potato chili with feta", "Süßkartoffel-Chili mit Feta", "Sweet orange cubes, tangy white crumbs.", "Süße orange Würfel, würzige weiße Krümel.", "easy", 35, 555, 23, 75, 18,
  "sweet-potato 300 g,black-beans 260 g,canned-tomatoes 400 g,feta 90 g,onion 60 g,olive-oil 1 tbsp,cumin 1 tsp,paprika 1 tsp,chili 0.25 tsp,lime 1 piece,cilantro 10 g,salt 0.25 tsp",
  [step("Peel sweet potato and cut into 1 cm cubes. Soften diced onion in oil for 4 minutes; stir in cumin, paprika and chili.", "Süßkartoffel schälen und in 1 cm große Würfel schneiden. Zwiebelwürfel in Öl 4 Minuten dünsten; Kreuzkümmel, Paprikapulver und Chili einrühren.", 240, "Little orange cubes", title_de="Kleine orange Würfel"),
   step("Add sweet potato, tomatoes, drained beans, salt and 150 ml water. Cover and simmer for 20 minutes until potatoes are tender; uncover for 5 minutes to thicken.", "Süßkartoffel, Tomaten, abgetropfte Bohnen, Salz und 150 ml Wasser zugeben. Zugedeckt 20 Minuten weich köcheln; ohne Deckel 5 Minuten eindicken.", 1500, "A patient simmer", title_de="Geduldig köcheln"),
   step("Stir in lime juice. Divide between bowls and crumble feta on top; finish with cilantro leaves.", "Limettensaft einrühren. Auf Schalen verteilen, Feta darüberbröseln und mit Korianderblättern abschließen.", title_en="Fresh on top", title_de="Frisches obendrauf")], ["simmer"])
R("vegan", "Smoky three-bean chili", "Rauchiges Drei-Bohnen-Chili", "A pantry supper with a green avocado crown.", "Ein Vorrats-Abendessen mit grüner Avocadokrone.", "easy", 30, 510, 22, 60, 18,
  "kidney-beans 180 g,black-beans 180 g,white-beans 180 g,canned-tomatoes 400 g,onion 80 g,garlic 2 clove,avocado 100 g,olive-oil 1 tsp,paprika 2 tsp,cumin 1 tsp,lime 1 piece,salt 0.5 tsp",
  [step("Chop onion and garlic. Soften in oil for 5 minutes. Add smoked paprika and cumin and stir for 30 seconds.", "Zwiebel und Knoblauch hacken. In Öl 5 Minuten dünsten. Geräuchertes Paprikapulver und Kreuzkümmel zugeben und 30 Sekunden rühren.", 330, "Wake the pantry", title_de="Vorräte wecken"),
   step("Add tomatoes, all the drained beans, salt and 100 ml water. Simmer uncovered for 20 minutes; mash a spoonful of beans against the pan to thicken.", "Tomaten, alle abgetropften Bohnen, Salz und 100 ml Wasser zugeben. 20 Minuten offen köcheln; einen Löffel Bohnen am Topfrand zerdrücken, um die Sauce zu binden.", 1200, "Three kinds of comfort", title_de="Dreierlei Geborgenheit"),
   step("Dice avocado and toss with lime juice. Serve the chili with avocado and any lime juice from its bowl.", "Avocado würfeln und mit Limettensaft mischen. Chili mit Avocado und dem übrigen Limettensaft aus der Schale servieren.", title_en="A green crown", title_de="Eine grüne Krone")], ["simmer"])
R("keto", "Beef, pepper & courgette chili", "Rind-Paprika-Zucchini-Chili", "A chunky, warming pot with a cool yogurt swirl.", "Ein wärmender Topf mit Stückchen und kühlem Joghurtwirbel.", "easy", 35, 450, 35, 18, 26,
  "beef-mince 300 g,courgette 250 g,bell-peppers 150 g,canned-tomatoes 250 g,yogurt 100 g,olive-oil 1 tsp,cumin 1 tsp,paprika 1 tsp,chili 0.5 tsp,salt 0.5 tsp",
  [step("Brown beef in oil for 7 minutes, breaking it into small pieces. Dice courgette and pepper, add to the pot and cook for 5 minutes.", "Hack in Öl 7 Minuten krümelig anbraten. Zucchini und Paprika würfeln, zugeben und 5 Minuten mitbraten.", 720, "Sizzle the base", title_de="Basis anbraten"),
   step("Add spices, salt, tomatoes and 100 ml water. Simmer uncovered for 20 minutes until thick and the beef reaches 71°C.", "Gewürze, Salz, Tomaten und 100 ml Wasser zugeben. Offen 20 Minuten köcheln, bis die Sauce dick ist und das Hack 71 °C erreicht.", 1200, "A slow red bubble", title_de="Langsames rotes Blubbern"),
   step("Let the chili stand for 2 minutes. Spoon into bowls and add yogurt in a loose swirl just before eating.", "Chili 2 Minuten stehen lassen. In Schalen löffeln und kurz vor dem Essen Joghurt locker hineinwirbeln.", 120, "A cool finish", title_de="Ein kühler Abschluss")], ["simmer"])
R("halal", "Chicken & chickpea chili", "Hähnchen-Kichererbsen-Chili", "Golden chicken in a tomato-and-lime pot.", "Goldenes Hähnchen in einem Tomaten-Limetten-Topf.", "easy", 35, 480, 44, 43, 14,
  "chicken-thigh 280 g,chickpeas 240 g,canned-tomatoes 400 g,bell-peppers 150 g,onion 60 g,olive-oil 1 tsp,cumin 1 tsp,paprika 1 tsp,lime 1 piece,parsley 10 g,salt 0.5 tsp",
  [step("Use chicken suited to your halal requirements. Dice chicken, onion and pepper. Brown chicken in oil for 6 minutes, then add vegetables for 4 minutes.", "Hähnchen passend zu deinen Halal-Anforderungen verwenden. Fleisch, Zwiebel und Paprika würfeln. Hähnchen 6 Minuten in Öl bräunen, dann Gemüse 4 Minuten mitbraten.", 600, "A golden pot", title_de="Ein goldener Topf"),
   step("Stir in cumin and paprika. Add tomatoes, chickpeas, salt and 100 ml water. Simmer for 20 minutes until the sauce thickens and chicken reaches 74°C.", "Kreuzkümmel und Paprikapulver einrühren. Tomaten, Kichererbsen, Salz und 100 ml Wasser zugeben. 20 Minuten köcheln, bis die Sauce eindickt und das Hähnchen 74 °C erreicht.", 1200, "A comforting bubble", title_de="Wohliges Blubbern"),
   step("Add lime juice and chopped parsley off the heat. Serve in deep bowls with the sauce spooned generously over the chicken.", "Abseits der Hitze Limettensaft und gehackte Petersilie zugeben. In tiefen Schalen mit reichlich Sauce über dem Hähnchen servieren.", title_en="Brighten the bowl", title_de="Schale auffrischen")], ["simmer"])

dish("shepherds-pie", "Shepherd's pie", "Shepherd's Pie", "a golden roof for a rainy day.", "Ein goldenes Dach für einen Regentag.", "the corners are the best part", "die Ecken sind das Beste", "#A89972", "", True)
R("classic", "Lamb & potato shepherd's pie", "Shepherd's Pie mit Lamm und Kartoffeln", "A fork-ridged top and a rich, cosy centre.", "Ein mit der Gabel geriffeltes Dach und eine kräftige Mitte.", "hard", 60, 665, 36, 54, 32,
  "lamb-mince 280 g,potatoes 450 g,carrots 120 g,onion 80 g,peas 80 g,tomato-paste 25 g,butter 20 g,whole-milk 80 ml,thyme 1 tsp,olive-oil 1 tsp,water 200 ml,salt 0.5 tsp",
  [step("Heat oven to 210°C. Peel and cube potatoes, boil in salted water for 15 minutes, then drain. Mash with butter and milk.", "Ofen auf 210 °C heizen. Kartoffeln schälen, würfeln und 15 Minuten in Salzwasser kochen, dann abgießen. Mit Butter und Milch stampfen.", 900, "Make the golden roof", title_de="Das goldene Dach"),
   step("Brown lamb in oil for 7 minutes. Add diced onion and carrot for 5 minutes. Stir in tomato purée, thyme, peas and measured water. Simmer 12 minutes; ensure lamb reaches 71°C.", "Lamm in Öl 7 Minuten anbraten. Zwiebel- und Karottenwürfel 5 Minuten mitbraten. Tomatenmark, Thymian, Erbsen und abgemessenes Wasser einrühren. 12 Minuten köcheln; Lamm muss 71 °C erreichen.", 1440, "A rich little filling", title_de="Eine kräftige Füllung"),
   step("Spoon filling into a small baking dish. Spread mash on top and draw ridges with a fork. Bake 20 minutes until bubbling and golden; rest 5 minutes before serving.", "Füllung in eine kleine Auflaufform geben. Püree daraufstreichen und mit einer Gabel Rillen ziehen. 20 Minuten goldbraun und blubbernd backen; vor dem Servieren 5 Minuten ruhen lassen.", 1200, "Bake the corners crisp", title_de="Ecken knusprig backen")], ["bake", "simmer"])
R("vegetarian", "Lentil cottage pie with cheddar-style crust", "Linsenauflauf mit Kartoffel-Käsekruste", "A cheesy roof over an earthy lentil supper.", "Ein Käsedach über einem erdigen Linsenabendessen.", "hard", 55, 560, 27, 75, 18,
  "lentils 300 g,potatoes 400 g,mushrooms 180 g,carrots 120 g,onion 60 g,vegetarian-hard-cheese 50 g,whole-milk 80 ml,tomato-paste 25 g,olive-oil 1 tbsp,thyme 1 tsp,water 150 ml,salt 0.5 tsp",
  [step("Heat oven to 210°C. Boil peeled potato chunks in salted water for 15 minutes. Drain and mash with milk and half the grated cheese.", "Ofen auf 210 °C heizen. Geschälte Kartoffelstücke 15 Minuten in Salzwasser kochen. Abgießen und mit Milch und halbem geriebenem Käse stampfen.", 900, "A cheesy mash", title_de="Ein käsiges Püree"),
   step("Chop mushrooms, carrots and onion small. Fry in oil for 10 minutes. Add lentils, tomato purée, thyme and measured water, then simmer 10 minutes until thick.", "Pilze, Karotten und Zwiebel klein hacken. In Öl 10 Minuten braten. Linsen, Tomatenmark, Thymian und abgemessenes Wasser zugeben; 10 Minuten dicklich köcheln.", 1200, "Earthy little pieces", title_de="Erdige kleine Stücke"),
   step("Spoon lentils into a baking dish, cover with mash and remaining cheese. Bake 20 minutes until golden; rest 5 minutes so portions hold together.", "Linsen in eine Auflaufform geben, mit Püree und übrigem Käse bedecken. 20 Minuten goldbraun backen; 5 Minuten ruhen lassen, damit Portionen zusammenhalten.", 1200, "A bubbling roof", title_de="Ein blubberndes Dach")], ["bake", "simmer"])
R("vegan", "Sweet potato & mushroom shepherd's pie", "Süßkartoffel-Pilz-Shepherd's-Pie", "An orange blanket over lentils and thyme.", "Eine orange Decke über Linsen und Thymian.", "hard", 55, 490, 21, 73, 13,
  "sweet-potato 400 g,lentils 300 g,mushrooms 250 g,carrots 100 g,onion 60 g,tomato-paste 25 g,olive-oil 1 tbsp,oat-milk 60 ml,thyme 1 tsp,nutritional-yeast 15 g,water 150 ml,salt 0.5 tsp",
  [step("Heat oven to 210°C. Peel and cube sweet potato; boil for 15 minutes until tender. Drain well and mash with oat drink, yeast and half the salt.", "Ofen auf 210 °C heizen. Süßkartoffel schälen und würfeln; 15 Minuten weich kochen. Gut abgießen und mit Haferdrink, Hefeflocken und halbem Salz stampfen.", 900, "An orange blanket", title_de="Eine orange Decke"),
   step("Chop mushrooms, onion and carrot. Fry in oil for 10 minutes, letting moisture evaporate. Stir in lentils, tomato purée, thyme, remaining salt and measured water; simmer 10 minutes.", "Pilze, Zwiebel und Karotte hacken. In Öl 10 Minuten braten und Flüssigkeit verdampfen lassen. Linsen, Tomatenmark, Thymian, übriges Salz und abgemessenes Wasser einrühren; 10 Minuten köcheln.", 1200, "Keep the filling thick", title_de="Füllung dick halten"),
   step("Fill a small baking dish with the lentil mixture. Cover with sweet potato mash and roughen with a fork. Bake 20 minutes and rest 5 minutes before spooning out.", "Linsenmischung in eine kleine Auflaufform geben. Mit Süßkartoffelpüree bedecken und mit einer Gabel aufrauen. 20 Minuten backen und vor dem Portionieren 5 Minuten ruhen lassen.", 1200, "Crisp the little ridges", title_de="Kleine Rillen rösten")], ["bake", "simmer"])
R("keto", "Beef pie with cauliflower mash", "Rindfleischauflauf mit Blumenkohlpüree", "A bubbling cottage pie with a soft white roof.", "Ein blubbernder Auflauf mit weichem weißem Dach.", "medium", 45, 540, 39, 17, 36,
  "beef-mince 300 g,cauliflower 450 g,mushrooms 180 g,cream-cheese 80 g,butter 15 g,tomato-paste 20 g,thyme 1 tsp,water 100 ml,salt 0.5 tsp,black-pepper 0.5 tsp",
  [step("Heat oven to 210°C. Steam cauliflower for 12 minutes until very soft. Drain thoroughly and blend with cream cheese, butter and half the salt.", "Ofen auf 210 °C heizen. Blumenkohl 12 Minuten sehr weich dämpfen. Gründlich abtropfen lassen und mit Frischkäse, Butter und halbem Salz pürieren.", 720, "A soft white roof", title_de="Ein weiches weißes Dach"),
   step("Brown beef in a dry pan for 7 minutes. Add chopped mushrooms for 6 minutes. Stir in tomato purée, thyme, remaining salt, pepper and water; simmer 5 minutes. Beef should reach 71°C.", "Hack in einer trockenen Pfanne 7 Minuten anbraten. Gehackte Pilze 6 Minuten mitbraten. Tomatenmark, Thymian, übriges Salz, Pfeffer und Wasser einrühren; 5 Minuten köcheln. Hack soll 71 °C erreichen.", 1080, "A rich base", title_de="Eine kräftige Basis"),
   step("Put beef in a baking dish and spread cauliflower mash over it. Bake for 18 minutes until the edges bubble, then rest for 5 minutes.", "Hack in eine Auflaufform geben und Blumenkohlpüree darüberstreichen. 18 Minuten backen, bis die Ränder blubbern, dann 5 Minuten ruhen lassen.", 1080, "Bake & pause", title_de="Backen & innehalten")], ["bake", "steam"])
R("halal", "Chicken & pea potato pie", "Hähnchen-Erbsen-Kartoffelauflauf", "A family-table pie with a parsley-flecked top.", "Ein Auflauf für den Familientisch mit Petersiliendach.", "hard", 55, 540, 40, 61, 16,
  "chicken 300 g,potatoes 450 g,peas 100 g,carrots 120 g,onion 60 g,olive-oil 1 tbsp,oat-milk 80 ml,parsley 15 g,thyme 1 tsp,tomato-paste 20 g,water 150 ml,salt 0.5 tsp",
  [step("Choose chicken for your halal requirements. Heat oven to 210°C. Boil peeled potato cubes for 15 minutes, then mash with oat drink, half the oil, salt and chopped parsley.", "Hähnchen nach deinen Halal-Anforderungen wählen. Ofen auf 210 °C heizen. Kartoffelwürfel 15 Minuten kochen, dann mit Haferdrink, halbem Öl, Salz und gehackter Petersilie stampfen.", 900, "Parsley mash", title_de="Petersilienpüree"),
   step("Dice chicken, onion and carrots. Fry in remaining oil for 10 minutes until chicken reaches 74°C. Add peas, thyme, tomato purée and water; simmer for 8 minutes until thick.", "Hähnchen, Zwiebel und Karotten würfeln. In restlichem Öl 10 Minuten bis 74 °C Kerntemperatur braten. Erbsen, Thymian, Tomatenmark und Wasser zugeben; 8 Minuten dicklich köcheln.", 1080, "A gentle filling", title_de="Eine sanfte Füllung"),
   step("Transfer filling to a small baking dish, spread mash on top and make fork ridges. Bake 20 minutes until golden, then rest 5 minutes.", "Füllung in eine kleine Auflaufform geben, Püree daraufstreichen und mit der Gabel rillen. 20 Minuten goldbraun backen, dann 5 Minuten ruhen lassen.", 1200, "A golden family supper", title_de="Ein goldenes Familienessen")], ["bake", "simmer"])

dish("caesar", "Caesar salad", "Caesar-Salat", "crunch, cream & a little lemon.", "Knackig, cremig & ein wenig Zitrone.", "salad can be the whole story", "Salat darf die ganze Geschichte sein", "#8C9A77", "")
R("classic", "Chicken Caesar with crisp croutons", "Hähnchen-Caesar mit knusprigen Croûtons", "The café classic, generously dressed.", "Der Café-Klassiker, großzügig angemacht.", "medium", 25, 520, 46, 29, 24,
  "chicken 280 g,lettuce 200 g,bread 80 g,parmesan 35 g,yogurt 100 g,anchovies 15 g,mustard 1 tsp,lemon 1 piece,olive-oil 1 tbsp,garlic 1 clove,black-pepper 0.5 tsp",
  [step("Cut bread into cubes. Toast in half the oil for 5 minutes; remove. Slice chicken into thin cutlets and fry in remaining oil for 8–10 minutes until 74°C inside. Rest 3 minutes.", "Brot würfeln. In halbem Öl 5 Minuten rösten; herausnehmen. Hähnchen dünn aufschneiden und in restlichem Öl 8–10 Minuten bis 74 °C braten. 3 Minuten ruhen lassen.", 900, "Crisp & golden", title_de="Knusprig & golden"),
   step("Mash anchovies with grated garlic. Whisk with yogurt, mustard, lemon juice, half the grated parmesan and pepper.", "Sardellen mit geriebenem Knoblauch zerdrücken. Mit Joghurt, Senf, Zitronensaft, halbem geriebenem Parmesan und Pfeffer verquirlen.", title_en="The dressing matters", title_de="Auf das Dressing kommt es an"),
   step("Wash and dry lettuce, then tear into large pieces. Toss with dressing and croutons; top with sliced chicken and remaining parmesan shavings.", "Salat waschen, trocknen und grob zupfen. Mit Dressing und Croûtons mischen; Hähnchenstreifen und restliche Parmesanspäne darübergeben.", title_en="Toss at the last moment", title_de="Erst zum Schluss mischen")], ["pan-fry"], "lunch")
R("vegetarian", "Crisp chickpea Caesar", "Caesar mit knusprigen Kichererbsen", "Crunchy chickpeas and a tangy caper dressing.", "Knackige Kichererbsen und ein würziges Kaperndressing.", "medium", 30, 505, 25, 49, 24,
  "chickpeas 300 g,lettuce 200 g,bread 60 g,vegetarian-hard-cheese 40 g,yogurt 100 g,capers 20 g,mustard 1 tsp,lemon 1 piece,olive-oil 1 tbsp,paprika 0.5 tsp",
  [step("Heat oven to 220°C. Dry chickpeas thoroughly, toss with half the oil and paprika and roast 20 minutes. Add bread cubes with remaining oil for the last 8 minutes.", "Ofen auf 220 °C heizen. Kichererbsen gut trocknen, mit halbem Öl und Paprika mischen und 20 Minuten rösten. Brotwürfel mit restlichem Öl die letzten 8 Minuten zugeben.", 1200, "A crunchy tray", title_de="Ein knuspriges Blech"),
   step("Finely chop capers. Mix with yogurt, mustard, lemon juice and half the grated cheese. Thin with a spoon of water if needed.", "Kapern fein hacken. Mit Joghurt, Senf, Zitronensaft und halbem geriebenem Käse mischen. Bei Bedarf mit einem Löffel Wasser verdünnen.", title_en="Caper cream", title_de="Kaperncreme"),
   step("Tear washed, dried lettuce into a bowl. Toss with dressing, add warm chickpeas and croutons, and finish with remaining cheese.", "Gewaschenen, trockenen Salat in eine Schale zupfen. Mit Dressing mischen, warme Kichererbsen und Croûtons zugeben und mit übrigem Käse abschließen.", title_en="Build a generous salad", title_de="Einen großzügigen Salat bauen")], ["roast"], "lunch")
R("vegan", "Tahini Caesar with smoky tofu", "Tahin-Caesar mit rauchigem Tofu", "Creamy sesame dressing and crisp, warm tofu.", "Cremiges Sesamdressing und knuspriger, warmer Tofu.", "easy", 25, 440, 30, 19, 29,
  "tofu 300 g,lettuce 220 g,tahini 35 g,capers 20 g,lemon 1 piece,nutritional-yeast 15 g,pumpkin-seeds 20 g,olive-oil 2 tsp,paprika 1 tsp,water 60 ml,garlic 1 clove",
  [step("Pat tofu dry and tear into bite-sized pieces. Toss with paprika and oil; fry in a wide pan for 10 minutes, turning until crisp at the edges.", "Tofu trocken tupfen und mundgerecht zupfen. Mit Paprika und Öl mischen; in einer breiten Pfanne 10 Minuten unter Wenden an den Rändern knusprig braten.", 600, "Tear for texture", title_de="Für mehr Struktur zupfen"),
   step("Whisk tahini with lemon juice, water, grated garlic, chopped capers and yeast. Toast pumpkin seeds in a dry pan for 2 minutes.", "Tahin mit Zitronensaft, Wasser, geriebenem Knoblauch, gehackten Kapern und Hefeflocken verquirlen. Kürbiskerne 2 Minuten trocken rösten.", 120, "Sesame & lemon", title_de="Sesam & Zitrone"),
   step("Wash and dry lettuce thoroughly. Tear into bowls, toss with dressing, and scatter warm tofu and toasted seeds on top.", "Salat waschen und gründlich trocknen. In Schalen zupfen, mit Dressing mischen und warmen Tofu und geröstete Kerne darüberstreuen.", title_en="A warm crunch", title_de="Ein warmer Biss")], ["pan-fry"], "lunch")
R("keto", "Salmon avocado Caesar", "Lachs-Avocado-Caesar", "A cool green salad with a golden salmon crown.", "Ein kühler grüner Salat mit goldener Lachskrone.", "easy", 20, 560, 35, 10, 41,
  "salmon 280 g,avocado 120 g,lettuce 200 g,parmesan 30 g,yogurt 100 g,capers 15 g,mustard 1 tsp,lemon 1 piece,olive-oil 1 tsp,black-pepper 0.5 tsp",
  [step("Heat oil in a non-stick pan. Cook salmon for 4–5 minutes per side until the centre reaches 63°C. Set aside while you prepare the salad.", "Öl in einer beschichteten Pfanne erhitzen. Lachs je Seite 4–5 Minuten bis 63 °C Kerntemperatur braten. Während der Salatzubereitung beiseitestellen.", 600, "Golden salmon", title_de="Goldener Lachs"),
   step("Mix yogurt, chopped capers, mustard, lemon juice, pepper and half the parmesan. Wash and dry lettuce; slice avocado just before serving.", "Joghurt, gehackte Kapern, Senf, Zitronensaft, Pfeffer und halben Parmesan mischen. Salat waschen und trocknen; Avocado kurz vor dem Servieren schneiden.", title_en="A cool green bowl", title_de="Eine kühle grüne Schale"),
   step("Toss lettuce with dressing. Arrange avocado and flaked salmon on top, then add remaining parmesan shavings.", "Salat mit Dressing mischen. Avocado und grob gezupften Lachs darauflegen und mit übrigen Parmesanspänen abschließen.", title_en="Finish with flakes", title_de="Mit Flocken abschließen")], ["pan-fry"], "lunch")
R("halal", "Lemon chicken crunch salad", "Knackiger Zitronen-Hähnchen-Salat", "A dairy-free Caesar-inspired lunch with a tahini heart.", "Ein milchfreies Mittagessen im Caesar-Stil mit Tahinherz.", "easy", 25, 470, 42, 29, 19,
  "chicken 300 g,lettuce 220 g,bread 80 g,tahini 25 g,capers 15 g,lemon 1 piece,olive-oil 2 tsp,garlic 1 clove,water 50 ml,parsley 10 g",
  [step("Choose chicken and bread for your halal sourcing needs. Rub thin chicken cutlets with half the oil and lemon zest. Fry 8–10 minutes to 74°C, then rest 3 minutes.", "Hähnchen und Brot nach deinen Halal-Anforderungen wählen. Dünne Hähnchenschnitzel mit halbem Öl und Zitronenabrieb einreiben. 8–10 Minuten bis 74 °C braten, dann 3 Minuten ruhen lassen.", 600, "Lemon-scented chicken", title_de="Hähnchen mit Zitronenduft"),
   step("Toast bread cubes in remaining oil for 4 minutes. Whisk tahini with lemon juice, water, grated garlic and finely chopped capers.", "Brotwürfel in restlichem Öl 4 Minuten rösten. Tahin mit Zitronensaft, Wasser, geriebenem Knoblauch und fein gehackten Kapern verquirlen.", 240, "Crunch & cream", title_de="Knusprig & cremig"),
   step("Toss clean, dry lettuce with dressing. Add sliced chicken, croutons and torn parsley, then serve immediately.", "Sauberen, trockenen Salat mit Dressing mischen. Hähnchenstreifen, Croûtons und gezupfte Petersilie zugeben und sofort servieren.", title_en="A generous lunch", title_de="Ein großzügiges Mittagessen")], ["pan-fry"], "lunch")

dish("curry", "Coconut curry", "Kokoscurry", "a golden pot at the end of the day.", "Ein goldener Topf am Ende des Tages.", "let the windows steam up", "lass die Fenster beschlagen", "#C2A15F", "asian")
R("classic", "Chicken coconut curry", "Hähnchen-Kokoscurry", "Tender chicken in a ginger-gold sauce.", "Zartes Hähnchen in ingwergoldener Sauce.", "easy", 35, 650, 39, 61, 28,
  "chicken-thigh 300 g,rice 130 g,coconut-milk 200 ml,bell-peppers 150 g,onion 60 g,ginger 20 g,garlic 1 clove,rapeseed-oil 1 tsp,turmeric 1 tsp,cumin 1 tsp,coriander 1 tsp,lime 1 piece,salt 0.5 tsp",
  [step("Rinse rice and cook in 260 ml water, covered, for 12 minutes, then rest off heat 5 minutes. Dice chicken and pepper; finely chop onion, garlic and ginger.", "Reis waschen und mit 260 ml Wasser zugedeckt 12 Minuten kochen, dann ohne Hitze 5 Minuten ruhen lassen. Hähnchen und Paprika würfeln; Zwiebel, Knoblauch und Ingwer fein hacken.", 720, "Rice on, kettle quiet", title_de="Reis aufsetzen"),
   step("Soften onion, garlic and ginger in oil for 4 minutes. Add spices for 30 seconds, then chicken and pepper for 5 minutes, stirring.", "Zwiebel, Knoblauch und Ingwer in Öl 4 Minuten dünsten. Gewürze 30 Sekunden, dann Hähnchen und Paprika 5 Minuten unter Rühren mitbraten.", 570, "Wake the golden spices", title_de="Goldene Gewürze wecken"),
   step("Pour in coconut milk and 100 ml water, add salt and simmer 15 minutes until chicken reaches 74°C. Finish with lime and serve over rice.", "Kokosmilch und 100 ml Wasser zugießen, salzen und 15 Minuten köcheln, bis das Hähnchen 74 °C erreicht. Mit Limette abschließen und auf Reis servieren.", 900, "A golden finish", title_de="Ein goldener Abschluss")], ["simmer"])
R("vegetarian", "Golden egg & spinach curry", "Goldenes Eier-Spinat-Curry", "A softly spiced bowl with a yogurt swirl.", "Eine sanft gewürzte Schale mit Joghurtwirbel.", "easy", 30, 505, 24, 59, 20,
  "eggs 4 piece,rice 120 g,spinach 200 g,canned-tomatoes 250 g,yogurt 120 g,onion 60 g,ginger 15 g,rapeseed-oil 1 tbsp,turmeric 0.5 tsp,cumin 1 tsp,coriander 1 tsp,salt 0.5 tsp",
  [step("Boil eggs for 10 minutes, cool and peel. Rinse rice and cook with 240 ml water for 12 minutes, then rest covered off heat for 5 minutes.", "Eier 10 Minuten kochen, abschrecken und schälen. Reis waschen und mit 240 ml Wasser 12 Minuten kochen, dann abgedeckt ohne Hitze 5 Minuten ruhen lassen.", 720, "Eggs & rice", title_de="Eier & Reis"),
   step("Soften chopped onion and ginger in oil for 5 minutes. Add spices, tomatoes, salt and 80 ml water; simmer 10 minutes. Stir in spinach until wilted.", "Gehackte Zwiebel und Ingwer in Öl 5 Minuten dünsten. Gewürze, Tomaten, Salz und 80 ml Wasser zugeben; 10 Minuten köcheln. Spinat zusammenfallen lassen.", 900, "A spiced tomato blanket", title_de="Eine würzige Tomatendecke"),
   step("Turn heat low and stir in yogurt slowly. Add halved eggs and warm gently for 2 minutes without boiling. Spoon over rice.", "Hitze reduzieren und Joghurt langsam einrühren. Halbierte Eier zugeben und 2 Minuten ohne Kochen erwärmen. Über Reis löffeln.", 120, "Keep it gentle", title_de="Sanft bleiben")], ["simmer"])
R("vegan", "Red lentil coconut dal", "Rotes Linsen-Kokos-Dal", "A spoon-soft supper for the tired evenings.", "Ein löffelweiches Abendessen für müde Abende.", "easy", 30, 480, 24, 57, 18,
  "red-lentils 170 g,coconut-milk 160 ml,canned-tomatoes 200 g,spinach 150 g,onion 60 g,ginger 20 g,garlic 2 clove,turmeric 1 tsp,cumin 1 tsp,rapeseed-oil 1 tsp,lime 1 piece,water 500 ml,salt 0.5 tsp",
  [step("Rinse lentils until water runs mostly clear. Finely chop onion, garlic and ginger. Soften in oil for 4 minutes; stir in turmeric and cumin.", "Linsen spülen, bis das Wasser weitgehend klar ist. Zwiebel, Knoblauch und Ingwer fein hacken. In Öl 4 Minuten dünsten; Kurkuma und Kreuzkümmel einrühren.", 240, "A small golden beginning", title_de="Ein kleiner goldener Anfang"),
   step("Add lentils, tomatoes, coconut milk, measured water and salt. Simmer gently for 20 minutes, stirring often, until lentils collapse; add water if the pot catches.", "Linsen, Tomaten, Kokosmilch, abgemessenes Wasser und Salz zugeben. Unter häufigem Rühren 20 Minuten sanft köcheln, bis die Linsen zerfallen; bei Bedarf Wasser ergänzen.", 1200, "Let the lentils soften", title_de="Linsen weich werden lassen"),
   step("Fold in spinach for 2 minutes until wilted. Stir in lime juice and rest 3 minutes; the dal thickens as it settles.", "Spinat 2 Minuten zusammenfallen lassen. Limettensaft einrühren und 3 Minuten ruhen lassen; dabei wird das Dal dicker.", 120, "A green swirl", title_de="Ein grüner Wirbel")], ["simmer"])
R("keto", "Prawn & broccoli coconut curry", "Garnelen-Brokkoli-Kokoscurry", "A quick, fragrant bowl with plenty of green.", "Eine schnelle, duftende Schale mit viel Grün.", "easy", 20, 390, 32, 16, 23,
  "prawns 300 g,broccoli 250 g,coconut-milk 200 ml,ginger 20 g,garlic 1 clove,rapeseed-oil 1 tsp,turmeric 0.5 tsp,coriander 1 tsp,lime 1 piece,water 100 ml,salt 0.5 tsp",
  [step("Cut broccoli into small florets. Grate ginger and garlic. Stir them in warm oil for 1 minute; add turmeric and coriander for 30 seconds.", "Brokkoli in kleine Röschen schneiden. Ingwer und Knoblauch reiben. In warmem Öl 1 Minute rühren; Kurkuma und Koriander 30 Sekunden mitrösten.", 90, "Warm the aromatics", title_de="Aromen erwärmen"),
   step("Add coconut milk, water, salt and broccoli. Simmer covered for 6 minutes until broccoli is almost tender.", "Kokosmilch, Wasser, Salz und Brokkoli zugeben. Zugedeckt 6 Minuten köcheln, bis der Brokkoli fast gar ist.", 360, "A coconut bath", title_de="Ein Kokosbad"),
   step("Add prawns and simmer for 4–5 minutes until opaque and 63°C inside. Remove from heat, squeeze in lime and serve in deep bowls.", "Garnelen zugeben und 4–5 Minuten köcheln, bis sie undurchsichtig sind und innen 63 °C erreichen. Vom Herd nehmen, Limette hineinpressen und in tiefen Schalen servieren.", 300, "Finish the prawns gently", title_de="Garnelen sanft fertig garen")], ["simmer"])
R("halal", "Beef & aubergine coconut curry", "Rind-Auberginen-Kokoscurry", "A rich, spice-warmed supper with soft aubergine.", "Ein kräftiges, gewürzwarmes Abendessen mit weicher Aubergine.", "medium", 40, 620, 30, 61, 29,
  "beef-mince 250 g,aubergine 250 g,rice 120 g,coconut-milk 180 ml,canned-tomatoes 200 g,ginger 20 g,cumin 1 tsp,coriander 1 tsp,turmeric 0.5 tsp,rapeseed-oil 1 tsp,water 100 ml,salt 0.5 tsp",
  [step("Choose beef for your halal requirements. Cook rinsed rice in 240 ml water for 12 minutes, then rest covered. Dice aubergine into 1 cm pieces.", "Rindfleisch nach deinen Halal-Anforderungen wählen. Gewaschenen Reis in 240 ml Wasser 12 Minuten kochen, dann abgedeckt ruhen lassen. Aubergine 1 cm groß würfeln.", 720, "Rice & aubergine", title_de="Reis & Aubergine"),
   step("Brown beef in oil for 7 minutes. Add aubergine and grated ginger for 5 minutes, stirring. Add cumin, coriander and turmeric.", "Hack in Öl 7 Minuten bräunen. Aubergine und geriebenen Ingwer 5 Minuten unter Rühren mitbraten. Kreuzkümmel, Koriander und Kurkuma zugeben.", 720, "A deep golden base", title_de="Eine tiefgoldene Basis"),
   step("Add tomatoes, coconut milk, measured water and salt. Simmer for 20 minutes until aubergine is soft and beef reaches 71°C. Serve over the warm rice.", "Tomaten, Kokosmilch, abgemessenes Wasser und Salz zugeben. 20 Minuten köcheln, bis die Aubergine weich ist und das Hack 71 °C erreicht. Auf warmem Reis servieren.", 1200, "A slow little simmer", title_de="Langsam köcheln")], ["simmer"])

dish("oatmeal", "Morning oats", "Morgenporridge", "the first kind thing you do today.", "Die erste liebevolle Geste des Tages.", "a warm bowl, an open window", "eine warme Schale, ein offenes Fenster", "#A7A68B", "", True)
R("classic", "Apple cinnamon porridge", "Apfel-Zimt-Porridge", "A warm apple morning in a favourite bowl.", "Ein warmer Apfelmorgen in der Lieblingsschale.", "easy", 15, 390, 14, 59, 11,
  "oats 100 g,whole-milk 300 ml,apples 180 g,walnuts 15 g,honey 2 tsp,cinnamon 0.5 tsp,water 100 ml",
  [step("Grate half the apple and dice the rest. Put oats, milk, water, grated apple and cinnamon in a saucepan.", "Die Hälfte des Apfels reiben, den Rest würfeln. Haferflocken, Milch, Wasser, geriebenen Apfel und Zimt in einen Topf geben.", title_en="An apple beginning", title_de="Ein Apfelanfang"),
   step("Bring to a gentle simmer and stir for 7–8 minutes until creamy. Add a splash of water if too thick.", "Sanft aufkochen und 7–8 Minuten cremig rühren. Falls zu dick, etwas Wasser ergänzen.", 480, "Stir the morning awake", title_de="Den Morgen wachrühren"),
   step("Divide into bowls, top with diced apple and chopped walnuts, and drizzle with honey.", "Auf Schalen verteilen, mit Apfelwürfeln und gehackten Walnüssen belegen und mit Honig beträufeln.", title_en="A little honey", title_de="Ein wenig Honig")], ["simmer"], "breakfast")
R("vegetarian", "Baked banana breakfast oats", "Gebackener Bananen-Frühstückshafer", "A spoonable little breakfast cake.", "Ein kleiner Frühstückskuchen zum Löffeln.", "medium", 35, 425, 19, 58, 14,
  "oats 100 g,banana 160 g,eggs 1 piece,whole-milk 150 ml,yogurt 120 g,blueberries 100 g,baking-powder 1 tsp,cinnamon 0.5 tsp,butter 5 g",
  [step("Heat oven to 190°C. Butter a small baking dish. Mash banana with egg and milk, then stir in oats, baking powder and cinnamon.", "Ofen auf 190 °C heizen. Kleine Auflaufform buttern. Banane mit Ei und Milch zerdrücken, dann Haferflocken, Backpulver und Zimt einrühren.", title_en="A breakfast batter", title_de="Ein Frühstücksteig"),
   step("Fold in half the berries and spread in the dish. Scatter remaining berries on top and bake 25 minutes until the centre is set and springs back gently.", "Die Hälfte der Beeren unterheben und Masse in der Form verteilen. Übrige Beeren darüberstreuen und 25 Minuten backen, bis die Mitte fest und leicht elastisch ist.", 1500, "Let breakfast bake", title_de="Frühstück backen lassen"),
   step("Rest for 5 minutes before spooning out. Serve warm with cool yogurt.", "Vor dem Portionieren 5 Minuten ruhen lassen. Warm mit kühlem Joghurt servieren.", 300, "Warm & cool", title_de="Warm & kühl")], ["bake"], "breakfast")
R("vegan", "Pear & tahini oat bowl", "Birnen-Tahin-Haferschale", "Soft pear, toasted sesame, a calm beginning.", "Weiche Birne, gerösteter Sesam, ein ruhiger Anfang.", "easy", 15, 415, 12, 59, 16,
  "oats 100 g,oat-milk 300 ml,pears 180 g,tahini 25 g,pumpkin-seeds 15 g,cardamom 0.25 tsp,water 100 ml",
  [step("Dice pear, keeping a few thin slices for topping. Put oats, oat drink, water, diced pear and cardamom in a small saucepan.", "Birne würfeln, einige dünne Scheiben zum Belegen aufheben. Haferflocken, Haferdrink, Wasser, Birnenwürfel und Kardamom in einen kleinen Topf geben.", title_en="A pear-scented pot", title_de="Ein Topf mit Birnenduft"),
   step("Simmer gently for 8 minutes, stirring, until oats and pear are soft. Stir in half the tahini off the heat.", "Unter Rühren 8 Minuten sanft köcheln, bis Hafer und Birne weich sind. Abseits der Hitze halbes Tahin einrühren.", 480, "A soft little simmer", title_de="Sanft weich köcheln"),
   step("Toast pumpkin seeds in a dry pan for 2 minutes. Serve porridge with pear slices, seeds and the remaining tahini loosened with a little warm water.", "Kürbiskerne 2 Minuten trocken rösten. Porridge mit Birnenscheiben, Kernen und restlichem, mit warmem Wasser verdünntem Tahin servieren.", 120, "A sesame ribbon", title_de="Ein Sesamband")], ["simmer"], "breakfast")
R("keto", "Warm almond chia breakfast bowl", "Warme Mandel-Chia-Frühstücksschale", "A cosy grain-free spoonful with berry brightness.", "Ein wohliger getreidefreier Löffel mit Beerenfrische.", "easy", 15, 420, 17, 15, 33,
  "chia-seeds 40 g,almond-flour 40 g,coconut-milk 160 ml,water 180 ml,yogurt 100 g,strawberries 100 g,cinnamon 0.5 tsp,vanilla 0.25 tsp",
  [step("Whisk chia seeds, ground almonds, coconut milk, water, cinnamon and vanilla in a saucepan. Leave for 5 minutes to hydrate.", "Chiasamen, gemahlene Mandeln, Kokosmilch, Wasser, Zimt und Vanille in einem Topf verquirlen. 5 Minuten quellen lassen.", 300, "Let the seeds drink", title_de="Samen trinken lassen"),
   step("Warm on low heat for 5 minutes, stirring constantly, until thick and steaming. Add a little more water if needed; do not boil hard.", "Bei kleiner Hitze unter ständigem Rühren 5 Minuten dick und dampfend erwärmen. Bei Bedarf Wasser ergänzen; nicht stark kochen.", 300, "Warm gently", title_de="Sanft erwärmen"),
   step("Spoon into two bowls and add yogurt and thinly sliced strawberries. Serve while warm.", "In zwei Schalen löffeln und mit Joghurt und dünnen Erdbeerscheiben belegen. Warm servieren.", title_en="A bright little topping", title_de="Ein frischer kleiner Belag")], ["simmer"], "breakfast")
R("halal", "Date & pistachio porridge", "Dattel-Pistazien-Porridge", "A cardamom-scented morning with a little crunch.", "Ein Morgen mit Kardamomduft und etwas Biss.", "easy", 15, 440, 16, 67, 14,
  "oats 100 g,whole-milk 300 ml,dates 60 g,pistachios 25 g,cardamom 0.5 tsp,water 150 ml",
  [step("Check packaged ingredients against your halal sourcing requirements. Chop dates finely and simmer with measured water and cardamom for 3 minutes.", "Verpackte Zutaten anhand deiner Halal-Anforderungen prüfen. Datteln fein hacken und mit abgemessenem Wasser und Kardamom 3 Minuten köcheln.", 180, "A fragrant date syrup", title_de="Ein duftender Dattelsud"),
   step("Add oats and milk. Simmer gently for 8 minutes, stirring often, until creamy and the dates have softened into the oats.", "Haferflocken und Milch zugeben. Unter häufigem Rühren 8 Minuten sanft köcheln, bis alles cremig ist und die Datteln weich geworden sind.", 480, "A creamy morning", title_de="Ein cremiger Morgen"),
   step("Roughly chop pistachios and toast in a dry pan for 1 minute. Divide porridge into bowls and scatter pistachios over the top.", "Pistazien grob hacken und 1 Minute trocken rösten. Porridge auf Schalen verteilen und Pistazien darüberstreuen.", 60, "A green little crunch", title_de="Ein kleiner grüner Biss")], ["simmer"], "breakfast")

# Additional authored siblings make effort and calorie dimensions traversable.
# Move an existing dish to the working position; restore editorial order below.
EDITORIAL_ORDER = [d["id"] for d in dishes]


def select_dish(dish_id):
    selected = next(d for d in dishes if d["id"] == dish_id)
    dishes.remove(selected)
    dishes.append(selected)


select_dish("doener")
R("classic", "Quick paprika chicken pita", "Schnelle Paprika-Hähnchen-Pita", "A warm pocket for an ordinary good day.", "Eine warme Tasche für einen gewöhnlich guten Tag.", "easy", 20, 520, 40, 55, 16,
  "chicken 280 g,pita 150 g,yogurt 100 g,cucumber 150 g,lemon 1 piece,olive-oil 2 tsp,paprika 1 tsp,salt 0.5 tsp",
  [step("Slice chicken into very thin strips and toss with paprika, oil and half the salt. Grate cucumber coarsely and squeeze out moisture.", "Hähnchen in sehr dünne Streifen schneiden und mit Paprika, Öl und halbem Salz mischen. Gurke grob reiben und ausdrücken.", title_en="A quick beginning", title_de="Ein schneller Anfang"),
   step("Fry chicken in a hot pan for 8 minutes, stirring, until it reaches 74°C. Mix cucumber with yogurt, lemon juice and remaining salt.", "Hähnchen in einer heißen Pfanne unter Rühren 8 Minuten bis 74 °C braten. Gurke mit Joghurt, Zitronensaft und übrigem Salz mischen.", 480, "One hot pan", title_de="Eine heiße Pfanne"),
   step("Warm pita in the dry pan for 30 seconds each side. Fill with cucumber yogurt and chicken; spoon the paprika pan juices over the filling.", "Brot in der trockenen Pfanne je Seite 30 Sekunden erwärmen. Mit Gurkenjoghurt und Hähnchen füllen; Paprika-Bratensaft darüberlöffeln.", 60, "Pocket-sized comfort", title_de="Geborgenheit im Taschenformat")], ["pan-fry"], "lunch", "classic-easy")
R("vegan", "Pan-crisp chickpea döner", "Pfannenknuspriger Kichererbsen-Döner", "Warm cumin crumbs, cucumber and sesame cream.", "Warme Kreuzkümmelkrümel, Gurke und Sesamcreme.", "easy", 20, 540, 21, 74, 17,
  "chickpeas 280 g,pita 150 g,cucumber 150 g,tahini 25 g,lemon 1 piece,olive-oil 2 tsp,cumin 1 tsp,paprika 1 tsp,water 40 ml,salt 0.5 tsp",
  [step("Drain and dry chickpeas, then crush roughly with a fork. Toss with cumin, paprika and half the salt.", "Kichererbsen abtropfen lassen, trocknen und mit einer Gabel grob zerdrücken. Mit Kreuzkümmel, Paprika und halbem Salz mischen.", title_en="Crush into rough crumbs", title_de="Grob zerdrücken"),
   step("Heat oil in a wide pan. Press chickpeas into one layer and fry for 7 minutes, turning only twice so a crust forms. Meanwhile whisk tahini with lemon, water and remaining salt.", "Öl in einer breiten Pfanne erhitzen. Kichererbsen flach hineindrücken und 7 Minuten braten; nur zweimal wenden, damit eine Kruste entsteht. Tahin mit Zitrone, Wasser und übrigem Salz verrühren.", 420, "Let a crust form", title_de="Eine Kruste entstehen lassen"),
   step("Slice cucumber. Warm pita for 1 minute, spread with sesame cream and tuck in cucumber and the crisp chickpea crumbles.", "Gurke schneiden. Brot 1 Minute erwärmen, mit Sesamcreme bestreichen und Gurke und knusprige Kichererbsenkrümel hineinlegen.", 60, "Scoop up the crisp bits", title_de="Knusprige Stücke aufheben")], ["pan-fry"], "lunch", "vegan-easy")
R("vegetarian", "Feta & warm lentil döner", "Döner mit Feta und warmen Linsen", "Soft lentils, cool feta and a minty squeeze of lemon.", "Weiche Linsen, kühler Feta und minzige Zitrone.", "easy", 20, 560, 27, 68, 20,
  "lentils 250 g,pita 150 g,feta 100 g,tomatoes 160 g,mint 10 g,lemon 1 piece,olive-oil 1 tsp,cumin 1 tsp,salt 0.25 tsp",
  [step("Warm lentils in a small saucepan with cumin, oil and 3 tbsp water for 5 minutes. Crush a few against the pan so the filling holds together.", "Linsen mit Kreuzkümmel, Öl und 3 EL Wasser in einem kleinen Topf 5 Minuten erwärmen. Einige am Topfrand zerdrücken, damit die Füllung zusammenhält.", 300, "Warm the lentils", title_de="Linsen erwärmen"),
   step("Dice tomatoes and mix with torn mint, lemon juice and salt. Crumble feta into the tomato salad just before filling.", "Tomaten würfeln und mit gezupfter Minze, Zitronensaft und Salz mischen. Feta erst kurz vor dem Füllen hineinbröseln.", title_en="A minty salad", title_de="Ein minziger Salat"),
   step("Toast pita in a dry pan for 1 minute per side. Open and spoon in warm lentils, then add the juicy tomato and feta salad.", "Brot in einer trockenen Pfanne je Seite 1 Minute rösten. Öffnen und warme Linsen hineinlöffeln, dann saftigen Tomaten-Feta-Salat zugeben.", 120, "Warm meets cool", title_de="Warm trifft kühl")], ["simmer"], "lunch", "vegetarian-easy")
R("halal", "Quick beef & tomato döner", "Schneller Rind-Tomaten-Döner", "Cumin beef, parsley and a bright chopped salad.", "Kreuzkümmelrind, Petersilie und frischer gehackter Salat.", "easy", 20, 580, 34, 56, 25,
  "beef-mince 250 g,pita 150 g,tomatoes 180 g,parsley 15 g,tahini 20 g,lemon 1 piece,cumin 1 tsp,paprika 1 tsp,water 40 ml,salt 0.5 tsp",
  [step("Choose beef for your halal requirements. Heat a dry skillet and brown mince for 8 minutes with cumin, paprika and half the salt, breaking into small pieces; reach 71°C.", "Rind nach deinen Halal-Anforderungen wählen. Hack in einer trockenen Pfanne mit Kreuzkümmel, Paprika und halbem Salz 8 Minuten krümelig bis 71 °C anbraten.", 480, "A sizzling start", title_de="Ein brutzelnder Anfang"),
   step("Chop tomato and parsley together. Toss with half the lemon juice. Whisk tahini with water, remaining lemon juice and salt.", "Tomate und Petersilie zusammen hacken. Mit halbem Zitronensaft mischen. Tahin mit Wasser, übrigem Zitronensaft und Salz verrühren.", title_en="Chop the fresh things", title_de="Frisches hacken"),
   step("Warm the pita in a dry pan for 1 minute each side. Fill with tahini sauce, hot beef and the chopped tomato salad.", "Brot in einer trockenen Pfanne je Seite 1 Minute erwärmen. Mit Tahinsauce, heißem Rind und gehacktem Tomatensalat füllen.", 120, "Tuck in", title_de="Hinein damit")], ["pan-fry"], "lunch", "halal-easy")
R("classic", "Lemon chicken döner salad", "Zitronen-Hähnchen-Dönersalat", "A bright bowl with a little toasted bread.", "Eine frische Schale mit etwas geröstetem Brot.", "medium", 30, 385, 38, 30, 12,
  "chicken 280 g,pita 70 g,yogurt 100 g,red-cabbage 150 g,cucumber 150 g,lemon 1 piece,olive-oil 1 tsp,cumin 1 tsp,paprika 1 tsp,salt 0.5 tsp",
  [step("Heat oven to 210°C. Coat chicken with oil, cumin, paprika and half the salt. Roast in a small tray for 20 minutes until the thickest part reaches 74°C.", "Ofen auf 210 °C heizen. Hähnchen mit Öl, Kreuzkümmel, Paprika und halbem Salz einreiben. In einer kleinen Form 20 Minuten bis 74 °C Kerntemperatur rösten.", 1200, "Roast the chicken", title_de="Hähnchen rösten"),
   step("Shred cabbage and massage with half the lemon juice. Slice cucumber. Mix yogurt with remaining juice and salt. Tear pita into shards and toast in the oven for 4 minutes.", "Kohl hobeln und mit halbem Zitronensaft kneten. Gurke schneiden. Joghurt mit übrigem Saft und Salz mischen. Brot zupfen und 4 Minuten im Ofen rösten.", 240, "A crunchy bowl", title_de="Eine knackige Schale"),
   step("Rest chicken for 3 minutes, then slice. Divide vegetables into bowls, add chicken and yogurt, and tuck toasted pita around the edges.", "Hähnchen 3 Minuten ruhen lassen, dann schneiden. Gemüse auf Schalen verteilen, Hähnchen und Joghurt zugeben und geröstetes Brot an die Ränder stecken.", 180, "Arrange a little lunch", title_de="Ein kleines Mittagessen anrichten")], ["roast"], "lunch", "classic-light")
R("vegan", "Roasted aubergine döner salad", "Dönersalat mit Ofenaubergine", "Silky aubergine, warm lentils and lemony greens.", "Seidige Aubergine, warme Linsen und zitroniges Grün.", "medium", 30, 380, 17, 44, 15,
  "aubergine 300 g,lentils 250 g,lettuce 120 g,tomatoes 160 g,tahini 25 g,lemon 1 piece,olive-oil 1 tsp,cumin 1 tsp,paprika 1 tsp,water 40 ml,salt 0.5 tsp",
  [step("Heat oven to 220°C. Cut aubergine into slim wedges, toss with oil, cumin, paprika and half the salt. Roast for 22 minutes, turning halfway, until soft and browned.", "Ofen auf 220 °C heizen. Aubergine in schmale Spalten schneiden und mit Öl, Kreuzkümmel, Paprika und halbem Salz mischen. 22 Minuten weich und braun rösten, nach der Hälfte wenden.", 1320, "Roast until silky", title_de="Seidig rösten"),
   step("Warm lentils with 3 tbsp water in a covered pan for 4 minutes. Whisk tahini with lemon juice, measured water and remaining salt.", "Linsen mit 3 EL Wasser zugedeckt 4 Minuten erwärmen. Tahin mit Zitronensaft, abgemessenem Wasser und restlichem Salz verrühren.", 240, "Warm lentils, cool sauce", title_de="Warme Linsen, kühle Sauce"),
   step("Tear lettuce and slice tomatoes into bowls. Add warm lentils and aubergine; spoon sesame dressing across the vegetables.", "Salat zupfen und Tomaten in Schalen schneiden. Warme Linsen und Aubergine zugeben; Sesamdressing über das Gemüse löffeln.", title_en="A bowl of good things", title_de="Eine Schale guter Dinge")], ["roast", "simmer"], "lunch", "vegan-light")
select_dish("alfredo")
R("classic", "Silky small-plate Alfredo", "Seidige Alfredo auf kleinem Teller", "Butter, parmesan and a bright little side of spinach.", "Butter, Parmesan und eine kleine grüne Spinatbeilage.", "easy", 20, 530, 23, 61, 22,
  "pasta 160 g,parmesan 50 g,butter 30 g,spinach 150 g,lemon 1 piece,black-pepper 0.5 tsp,salt 0.5 tsp",
  [step("Cook pasta in salted boiling water to packet instructions. Put spinach in a colander and drain the pasta over it, keeping 150 ml of cooking water first.", "Nudeln nach Packung in Salzwasser kochen. Spinat in ein Sieb geben und Nudeln darüber abgießen; vorher 150 ml Kochwasser aufheben.", 600, "One pot, a little green", title_de="Ein Topf, etwas Grün"),
   step("Melt butter in the warm empty pot with 50 ml cooking water. Add pasta and spinach, remove from heat and stir in finely grated parmesan a little at a time.", "Butter im warmen leeren Topf mit 50 ml Kochwasser schmelzen. Nudeln und Spinat zugeben, vom Herd nehmen und fein geriebenen Parmesan nach und nach einrühren.", title_en="A glossy little sauce", title_de="Eine kleine glänzende Sauce"),
   step("Loosen with more cooking water until silky. Finish with lemon zest and pepper; serve immediately on warm plates.", "Mit weiterem Kochwasser seidig lockern. Mit Zitronenabrieb und Pfeffer abschließen; sofort auf warmen Tellern servieren.", title_en="Serve while silky", title_de="Seidig servieren")], ["simmer"], "dinner", "classic-balanced")
R("vegan", "White bean & lemon quick Alfredo", "Schnelle Weiße-Bohnen-Zitronen-Alfredo", "A cupboard supper with a silky blender sauce.", "Ein Vorratsessen mit seidiger Mixersauce.", "easy", 20, 520, 23, 84, 12,
  "gf-pasta 170 g,white-beans 250 g,oat-milk 150 ml,nutritional-yeast 20 g,olive-oil 1 tbsp,lemon 1 piece,basil 10 g,garlic 1 clove,salt 0.5 tsp,black-pepper 0.5 tsp",
  [step("Cook gluten-free pasta in salted water according to the packet. Add the peeled garlic clove for the final 3 minutes; reserve 150 ml cooking water before draining.", "Glutenfreie Nudeln nach Packung in Salzwasser kochen. Die geschälte Knoblauchzehe die letzten 3 Minuten zugeben; vor dem Abgießen 150 ml Kochwasser aufheben.", 600, "A small pot of pasta", title_de="Ein kleiner Topf Nudeln"),
   step("Blend beans, cooked garlic, oat drink, yeast, oil and lemon juice until very smooth. Warm in a saucepan for 3 minutes, stirring.", "Bohnen, gegarten Knoblauch, Haferdrink, Hefeflocken, Öl und Zitronensaft ganz glatt mixen. In einem Topf unter Rühren 3 Minuten erwärmen.", 180, "Blend the pantry to cream", title_de="Vorräte cremig mixen"),
   step("Fold pasta into the sauce and add cooking water until it coats the ribbons loosely. Finish with torn basil, lemon zest and pepper.", "Nudeln unter die Sauce heben und Kochwasser zugeben, bis sie die Bänder locker umhüllt. Mit gezupftem Basilikum, Zitronenabrieb und Pfeffer abschließen.", title_en="A basil finish", title_de="Ein Basilikumabschluss")], ["simmer"], "dinner", "vegan-easy")
R("classic", "Brown-butter mushroom Alfredo", "Pilz-Alfredo mit brauner Butter", "A little attention turns butter into something nutty.", "Ein wenig Aufmerksamkeit macht Butter nussig.", "medium", 30, 580, 25, 66, 25,
  "pasta 170 g,mushrooms 250 g,parmesan 55 g,butter 35 g,thyme 1 tsp,lemon 1 piece,salt 0.5 tsp,black-pepper 0.5 tsp",
  [step("Slice mushrooms. Melt half the butter in a wide pan and fry mushrooms with thyme for 8 minutes until their moisture evaporates and edges brown.", "Pilze schneiden. Halbe Butter in einer breiten Pfanne schmelzen und Pilze mit Thymian 8 Minuten braten, bis die Feuchtigkeit verdampft und die Ränder bräunen.", 480, "Give mushrooms room", title_de="Pilzen Platz geben"),
   step("Cook pasta in salted water according to the packet; reserve 200 ml water. Remove mushrooms from their pan. Add remaining butter and swirl over medium heat until amber flecks appear, about 2 minutes.", "Nudeln nach Packung in Salzwasser kochen; 200 ml Wasser aufheben. Pilze aus der Pfanne nehmen. Restliche Butter zugeben und bei mittlerer Hitze etwa 2 Minuten bis zu bernsteinfarbenen Punkten schwenken.", 600, "Watch the butter", title_de="Butter beobachten"),
   step("Immediately add 60 ml pasta water to stop browning. Add pasta and mushrooms, turn off heat and toss in parmesan gradually. Loosen with more water; finish with lemon zest and pepper.", "Sofort 60 ml Nudelwasser zugeben, um das Bräunen zu stoppen. Nudeln und Pilze zugeben, Herd ausschalten und Parmesan nach und nach unterschwenken. Mit weiterem Wasser lockern; Zitronenabrieb und Pfeffer zugeben.", title_en="Catch the golden moment", title_de="Den goldenen Moment treffen")], ["sauté", "simmer"], "dinner", "classic-medium")
R("vegan", "Broccoli Alfredo bake", "Brokkoli-Alfredo-Auflauf", "A golden, spoonable project for a slow evening.", "Ein goldenes Löffelprojekt für einen langsamen Abend.", "hard", 50, 590, 25, 78, 21,
  "gf-pasta 160 g,broccoli 250 g,cashews 60 g,white-beans 180 g,oat-milk 200 ml,nutritional-yeast 25 g,garlic 2 clove,olive-oil 1 tsp,lemon 1 piece,pumpkin-seeds 15 g,salt 0.5 tsp",
  [step("Heat oven to 200°C. Cover cashews with boiling water for 15 minutes, then drain. Cook pasta 2 minutes less than packet timing, adding broccoli for the final 3 minutes; drain.", "Ofen auf 200 °C heizen. Cashews 15 Minuten mit kochendem Wasser bedecken, dann abgießen. Nudeln 2 Minuten kürzer als nach Packung kochen, Brokkoli die letzten 3 Minuten zugeben; abgießen.", 900, "Prepare the creamy heart", title_de="Die cremige Mitte vorbereiten"),
   step("Blend soaked cashews, beans, oat drink, yeast, peeled garlic, lemon juice and salt until completely smooth. Fold through pasta and broccoli in an oiled baking dish.", "Eingeweichte Cashews, Bohnen, Haferdrink, Hefeflocken, geschälten Knoblauch, Zitronensaft und Salz völlig glatt mixen. In einer geölten Auflaufform mit Nudeln und Brokkoli mischen.", title_en="Fold into the dish", title_de="In der Form mischen"),
   step("Chop pumpkin seeds and scatter over the top. Bake 25 minutes until the edges bubble and the top colours. Rest 5 minutes before serving.", "Kürbiskerne hacken und darüberstreuen. 25 Minuten backen, bis die Ränder blubbern und die Oberfläche Farbe bekommt. Vor dem Servieren 5 Minuten ruhen lassen.", 1500, "A golden oven finish", title_de="Ein goldener Ofenabschluss")], ["bake", "simmer"], "dinner", "vegan-hard")

dishes.sort(key=lambda d: EDITORIAL_ORDER.index(d["id"]))

ingredient_by_id = {i["id"]: i for i in ingredients}


def derived_flags(ingredient_id):
    node = ingredient_by_id[ingredient_id]
    result = set(node["flags"])
    if node["parent_id"]:
        result.update(derived_flags(node["parent_id"]))
    return result


for recipe in recipes:
    flags = set()
    for ingredient in recipe["ingredients"]:
        flags.update(derived_flags(ingredient["id"]))
    if flags.intersection(MEAT) and "dairy" in flags:
        flags.add("meat-dairy-combo")
    recipe["contains"] = sorted(flags)
    for positive in ["vegan", "vegetarian", "halal", "kosher"]:
        if not flags.intersection(ontology["compounds"][positive]):
            recipe["attributes"].append(positive)
    if recipe["diet"] == "keto":
        recipe["attributes"].append("keto")
    recipe["attributes"].append(recipe["effort"])
    recipe["attributes"].append("≤15" if recipe["time_minutes"] <= 15 else "≤30" if recipe["time_minutes"] <= 30 else "≤60" if recipe["time_minutes"] <= 60 else ">60")
    recipe["attributes"] = sorted(set(recipe["attributes"]))


GUIDE_DEFAULTS = {
    "produce": (tr("Fresh produce brings colour, moisture and texture to a dish.", "Frisches Obst und Gemüse bringt Farbe, Feuchtigkeit und Struktur ins Gericht."), tr("Wash before preparing; trim damaged parts and cut evenly for predictable cooking.", "Vorbereiten: waschen, beschädigte Stellen entfernen und gleichmäßig schneiden, damit alles gleichmäßig gart."), tr("Keep cool and dry; refrigerate cut produce in a closed container and use promptly.", "Kühl und trocken lagern; Angeschnittenes verschlossen kühlen und zeitnah verbrauchen."), tr("Look in the fruit, vegetable or fresh-herb section.", "Im Obst-, Gemüse- oder Frischkräuterregal zu finden.")),
    "chilled": (tr("A chilled ingredient that adds body, richness or protein.", "Eine gekühlte Zutat für Substanz, Fülle oder Eiweiß."), tr("Follow the recipe's preparation and check the label for allergens and sourcing details.", "Zubereitung im Rezept beachten und Etikett auf Allergene und Herkunft prüfen."), tr("Keep refrigerated according to the package and respect its use-by date.", "Nach Packungsangabe kühlen und das Verbrauchsdatum beachten."), tr("Look in the chilled dairy or plant-protein section.", "Im Kühlregal bei Milchprodukten oder pflanzlichem Eiweiß zu finden.")),
    "protein": (tr("A protein ingredient whose sourcing and handling are part of the recipe.", "Eine Eiweißzutat, bei der Herkunft und Umgang zur Zubereitung gehören."), tr("Keep raw ingredients separate from ready-to-eat foods; follow the recipe's centre-temperature instruction.", "Rohe Zutaten getrennt von verzehrfertigen Speisen halten; die Kerntemperatur im Rezept beachten."), tr("Refrigerate promptly at the package's recommended temperature. Follow use-by and freezing instructions.", "Zügig bei der aufgedruckten Temperatur kühlen. Verbrauchsdatum und Einfrierhinweise beachten."), tr("Look at the butcher or fish counter, or in the chilled meat and fish section.", "An der Fleisch- oder Fischtheke sowie im entsprechenden Kühlregal zu finden.")),
    "pantry": (tr("A useful pantry ingredient for everyday cooking.", "Eine nützliche Vorratszutat für die Alltagsküche."), tr("Measure before cooking. Check package instructions and allergen labels; brands can differ.", "Vor dem Kochen abmessen. Packungsanleitung und Allergenhinweise prüfen; Marken unterscheiden sich."), tr("Store unopened in a cool, dry cupboard. Once opened, follow the package's storage instructions.", "Ungeöffnet kühl und trocken im Schrank lagern. Nach dem Öffnen Lagerhinweise der Packung beachten."), tr("Look in the dry-goods, tinned-food or international-food aisle.", "Bei Trockenwaren, Konserven oder internationalen Lebensmitteln zu finden.")),
    "bakery": (tr("Bread adds a soft pocket or a crisp toasted edge.", "Brot bildet eine weiche Tasche oder einen knusprig gerösteten Rand."), tr("Warm shortly before serving. Older bread makes especially good croutons.", "Kurz vor dem Servieren erwärmen. Älteres Brot eignet sich besonders gut für Croûtons."), tr("Keep wrapped at room temperature for short storage, or freeze portions. Discard bread with mould.", "Kurzzeitig verpackt bei Raumtemperatur lagern oder portionsweise einfrieren. Schimmeliges Brot entsorgen."), tr("Look in the bakery or bread aisle; check gluten and other allergen labels.", "In der Bäckerei oder im Brotregal zu finden; Gluten- und weitere Allergenhinweise prüfen.")),
    "spices": (tr("A small seasoning with a noticeable effect on flavour.", "Ein kleines Würzmittel mit spürbarer Wirkung auf den Geschmack."), tr("Measure first and taste before adding more. Ground spices release their aroma in a little warm oil.", "Zuerst abmessen und vor dem Nachwürzen probieren. Gemahlene Gewürze entfalten in etwas warmem Öl ihr Aroma."), tr("Keep tightly closed in a dry, dark cupboard away from the hob's steam.", "Gut verschlossen, trocken und dunkel abseits des Herd­dampfs lagern."), tr("Look in the spice aisle or at a specialist grocer.", "Im Gewürzregal oder im Fachgeschäft zu finden.")),
}
CUSTOM_GUIDES = {
    "tahini": (
        tr("Tahini is a paste made from ground sesame seeds. It gives sauces a gentle, nutty richness.", "Tahin ist eine Paste aus gemahlenem Sesam. Es gibt Saucen eine milde, nussige Fülle."),
        tr("Stir separated oil back in. Lemon initially makes tahini thicken; whisk in water gradually until smooth.", "Abgesetztes Öl wieder einrühren. Zitrone macht Tahin zunächst fest; nach und nach Wasser glatt einrühren."),
        tr("Close tightly and follow the jar's guidance after opening; stir with a clean spoon.", "Gut verschließen und nach dem Öffnen den Glashinweisen folgen; einen sauberen Löffel verwenden."),
        tr("Find it with nut butters, international foods or Middle Eastern groceries. It contains sesame.", "Bei Nussmus, internationalen Lebensmitteln oder im orientalischen Laden. Enthält Sesam.")),
    "miso": (
        tr("Miso is a fermented soybean paste that brings savoury depth. This cookbook specifies alcohol-free rice miso.", "Miso ist eine fermentierte Sojabohnenpaste für würzige Tiefe. Hier wird alkoholfreies Reis-Miso verwendet."),
        tr("Dissolve in a little warm liquid before adding to soup off the heat. Check for barley, alcohol and other ingredients on the label.", "Erst in wenig warmer Flüssigkeit lösen, dann abseits der Hitze zur Suppe geben. Etikett auf Gerste, Alkohol und weitere Zutaten prüfen."),
        tr("Keep sealed in the refrigerator after opening, following the manufacturer's instructions.", "Nach dem Öffnen nach Herstellerangabe verschlossen im Kühlschrank aufbewahren."),
        tr("Look in Asian grocery shops or the international aisle. Miso contains soy; some kinds contain gluten.", "Im Asialaden oder internationalen Regal. Miso enthält Soja; manche Sorten enthalten Gluten.")),
    "tamarind": (
        tr("Tamarind is a tangy fruit pulp that gives noodle sauces their rounded sourness.", "Tamarinde ist säuerliches Fruchtmark und gibt Nudelsaucen eine runde Säure."),
        tr("This cookbook uses unsweetened, seedless paste. Dilute with warm water; concentrated brands may need a smaller amount.", "Hier wird ungesüßte, kernlose Paste verwendet. Mit warmem Wasser verdünnen; sehr konzentrierte Marken eventuell sparsamer dosieren."),
        tr("Refrigerate opened paste if the jar directs; always use a clean spoon.", "Geöffnete Paste nach Glashinweis kühlen und immer einen sauberen Löffel verwenden."),
        tr("Find it in Asian or South Asian grocery shops and larger international aisles.", "Im asiatischen oder südasiatischen Lebensmittelgeschäft und größeren internationalen Regalen.")),
    "nutritional-yeast": (
        tr("Inactive yeast flakes add a savoury, gently cheesy taste without dairy.", "Inaktive Hefeflocken geben einen würzigen, leicht käsigen Geschmack ohne Milch."),
        tr("Blend into sauces or sprinkle onto warm food. It does not raise dough; vitamin content depends on fortification.", "In Saucen mixen oder über warme Speisen streuen. Sie lassen Teig nicht aufgehen; Vitamingehalt hängt von der Anreicherung ab."),
        tr("Keep tightly sealed in a dry, dark cupboard.", "Gut verschlossen, trocken und dunkel im Schrank lagern."),
        tr("Look in health-food shops or the vegan and baking sections.", "Im Bioladen sowie im veganen oder Backregal zu finden.")),
    "tofu": (
        tr("Firm tofu is a soy-based curd that holds its shape in the pan.", "Fester Tofu ist ein Sojaprodukt, das beim Braten seine Form hält."),
        tr("Pat dry for a crisp surface. Tear into rough pieces for extra browned edges, or cut evenly for stir-fries.", "Für knusprige Oberflächen trocken tupfen. Für mehr Röstkanten grob zupfen oder für Wokgerichte gleichmäßig schneiden."),
        tr("Refrigerate and follow the use-by date. Store leftovers according to the package directions.", "Kühlen und Verbrauchsdatum beachten. Reste nach Packungsanweisung lagern."),
        tr("Look in the chilled plant-protein section or an Asian grocery. Contains soy.", "Im Kühlregal bei pflanzlichem Eiweiß oder im Asialaden. Enthält Soja.")),
    "silken-tofu": (
        tr("Silken tofu has a delicate, custard-like texture and breaks easily.", "Seidentofu hat eine zarte, puddingartige Struktur und zerbricht leicht."),
        tr("Lift pieces with a large spoon and avoid vigorous stirring. It also blends into very smooth sauces.", "Stücke mit einem großen Löffel heben und kräftiges Rühren vermeiden. Lässt sich auch zu sehr glatten Saucen mixen."),
        tr("Follow the package: some unopened packs are shelf-stable. Always refrigerate after opening.", "Packung beachten: Manche ungeöffneten Packungen sind ungekühlt haltbar. Nach dem Öffnen immer kühlen."),
        tr("Look in Asian groceries, health-food shops or the chilled vegan section. Contains soy.", "Im Asialaden, Bioladen oder veganen Kühlregal. Enthält Soja.")),
    "oats": (
        tr("Rolled oats thicken into a creamy porridge and can be blended into flour.", "Haferflocken werden zu cremigem Porridge und lassen sich zu Mehl mixen."),
        tr("These recipes specify certified gluten-free oats. Ordinary oats may have contact with wheat, barley or rye.", "Diese Rezepte verwenden zertifiziert glutenfreie Haferflocken. Gewöhnlicher Hafer kann Kontakt mit Weizen, Gerste oder Roggen haben."),
        tr("Store dry in an airtight container; keep away from heat and moisture.", "Trocken und luftdicht vor Hitze und Feuchtigkeit geschützt lagern."),
        tr("Look in the breakfast or gluten-free aisle and check the certification on the pack.", "Im Frühstücks- oder glutenfreien Regal; Zertifizierung auf der Packung prüfen.")),
    "tamari": (
        tr("Tamari is a savoury soy seasoning. This corpus specifically uses alcohol-free, gluten-free tamari.", "Tamari ist eine würzige Sojasauce. Dieser Rezeptbestand verwendet ausdrücklich alkoholfreies, glutenfreies Tamari."),
        tr("Use the measured amount, then taste before adding salt. Standard soy sauce is not equivalent for gluten or alcohol avoidance.", "Abgemessene Menge verwenden und vor dem Salzen probieren. Gewöhnliche Sojasauce ist bei Gluten- oder Alkoholvermeidung nicht gleichwertig."),
        tr("Close the bottle tightly and follow its refrigeration guidance after opening.", "Flasche gut verschließen und Kühlhinweise nach dem Öffnen beachten."),
        tr("Look in specialist Asian shops or the gluten-free aisle; verify both claims on the label.", "Im asiatischen Fachgeschäft oder glutenfreien Regal; beide Angaben auf dem Etikett prüfen.")),
}
guides = []
for ingredient in ingredients:
    aisle_id = next(k for k, v in AISLES.items() if v == ingredient["aisle"])
    description, usage, storage, where = CUSTOM_GUIDES.get(ingredient["id"], GUIDE_DEFAULTS[aisle_id])
    guides.append({"id": ingredient["id"], "description": description, "usage": usage, "storage": storage, "where": where})

faqs = []


def faq(i, cat_en, cat_de, q_en, q_de, a_en, a_de):
    faqs.append({"id": i, "category": tr(cat_en, cat_de), "question": tr(q_en, q_de), "answer": tr(a_en, a_de)})


faq("matching", "Your cookbook", "Dein Kochbuch", "How does my cookbook know what I eat?", "Woher weiß mein Kochbuch, was ich esse?", "Your profile sets ingredients and classes to avoid, positive requirements, a time budget and a calorie target. A recipe appears only when it passes all those checks. Each version has its own complete ingredient list and method.", "Dein Profil legt gemiedene Zutaten und Gruppen, positive Anforderungen, Zeitbudget und Kalorienziel fest. Ein Rezept erscheint nur, wenn es alle Prüfungen besteht. Jede Version hat eine eigene vollständige Zutatenliste und Zubereitung.")
faq("visibility", "Your cookbook", "Dein Kochbuch", "Why is a dish missing?", "Warum fehlt ein Gericht?", "There may be no version that meets every profile setting at once. Check your time budget, calorie target and avoidance list in Settings. On a dish page, the calorie override shows versions outside your target while keeping your other requirements.", "Vielleicht gibt es keine Version, die alle Profileinstellungen gleichzeitig erfüllt. Prüfe Zeitbudget, Kalorienziel und Vermeidungsliste in Einstellungen. Auf einer Gerichtseite zeigt der Kalorien-Schalter Versionen außerhalb deines Ziels; deine übrigen Anforderungen bleiben aktiv.")
faq("allergies", "Diet & ingredients", "Ernährung & Zutaten", "Can I rely on the app for allergy safety?", "Kann ich mich bei Allergien auf die App verlassen?", "Matching checks the listed ingredients and their ingredient families. Brand ingredients, manufacturing contact and your own kitchen can differ. Read product labels and follow your personal allergy guidance; the app does not certify an allergen-free meal.", "Die Zuordnung prüft aufgeführte Zutaten und ihre Zutatenfamilien. Markenrezepturen, Herstellungskontakt und deine Küche können abweichen. Lies Etiketten und beachte deine persönliche Allergieberatung; die App zertifiziert keine allergenfreie Mahlzeit.")
faq("avoidance", "Diet & ingredients", "Ernährung & Zutaten", "Can I avoid just one ingredient?", "Kann ich nur eine einzelne Zutat meiden?", "Yes. Search the ingredient dictionary in your profile and select an ingredient or a parent family. Avoiding cow's milk also avoids whole milk and skimmed milk. Class checkboxes and specific ingredient choices work together.", "Ja. Suche im Zutatenverzeichnis deines Profils und wähle eine Zutat oder Obergruppe. Kuhmilch zu meiden schließt auch Vollmilch und Magermilch aus. Gruppen-Kästchen und einzelne Zutaten wirken gemeinsam.")
faq("halal-kosher", "Diet & ingredients", "Ernährung & Zutaten", "What do halal-compatible and kosher-compatible mean?", "Was bedeuten halal-kompatibel und koscher-kompatibel?", "These describe ingredient compatibility, not certification. Sourcing, slaughter, supervision, labels and preparation remain your choice and responsibility. We never label a recipe halal-certified or kosher-certified.", "Die Begriffe beschreiben Zutatenkompatibilität, keine Zertifizierung. Herkunft, Schlachtung, Aufsicht, Etiketten und Zubereitung liegen weiterhin bei dir. Wir kennzeichnen kein Rezept als halal- oder koscher-zertifiziert.")
faq("calories", "Your cookbook", "Dein Kochbuch", "How does the calorie target work?", "Wie funktioniert das Kalorienziel?", "The target is per meal, with a tolerance of 150 kcal on either side. Nutrition values are estimates per serving. Use the per-dish calorie override when you want to browse beyond that range; it does not change your profile.", "Das Ziel gilt pro Mahlzeit mit 150 kcal Toleranz nach oben und unten. Nährwerte sind Schätzungen pro Portion. Mit dem Kalorien-Schalter eines Gerichts kannst du außerhalb dieses Bereichs stöbern; dein Profil wird dadurch nicht geändert.")
faq("switching", "Cooking", "Kochen", "Why is a version choice greyed out?", "Warum ist eine Versionsauswahl ausgegraut?", "Each row changes one dimension while preserving the other selections. A greyed-out choice has no available recipe for that combination and your profile. Try another effort or calorie level first; new recipes arrive with app releases.", "Jede Zeile ändert eine Eigenschaft und behält die anderen bei. Für eine ausgegraute Auswahl gibt es kein verfügbares Rezept mit dieser Kombination und deinem Profil. Probiere zunächst einen anderen Aufwand oder Kalorienbereich; neue Rezepte kommen mit App-Versionen.")
faq("saved", "Your cookbook", "Dein Kochbuch", "What exactly gets saved?", "Was genau wird gespeichert?", "You save the particular recipe you are viewing, including its own ingredients and method. Your vegan Döner and a classic Döner are separate saved recipes, even though they belong to the same dish.", "Du speicherst genau das angezeigte Rezept mit seinen eigenen Zutaten und Schritten. Dein veganer Döner und ein klassischer Döner sind getrennte gespeicherte Rezepte, obwohl sie zum selben Gericht gehören.")
faq("shopping", "Planning & shopping", "Planen & Einkaufen", "How are shopping quantities combined?", "Wie werden Einkaufsmengen zusammengezählt?", "The list combines the same ingredient across selected recipes and scales amounts with servings. Compatible units are converted, such as tablespoons and millilitres. Incompatible units remain separate so the list never guesses a weight from a piece count.", "Die Liste kombiniert gleiche Zutaten aus ausgewählten Rezepten und skaliert Mengen nach Portionen. Kompatible Einheiten wie Esslöffel und Milliliter werden umgerechnet. Unvereinbare Einheiten bleiben getrennt; die Liste errät kein Gewicht aus einer Stückzahl.")
faq("planning", "Planning & shopping", "Planen & Einkaufen", "How do I plan the week?", "Wie plane ich die Woche?", "Open the planner, choose a breakfast, lunch or dinner slot, and assign a saved or searched recipe. Drag a recipe to move it to another slot. Export the displayed week to the shopping list when you are ready.", "Öffne den Wochenplan, wähle Frühstück, Mittag- oder Abendessen und ordne ein gespeichertes oder gesuchtes Rezept zu. Ziehe ein Rezept in ein anderes Feld, um es zu verschieben. Übertrage die angezeigte Woche in die Einkaufsliste, wenn du bereit bist.")
faq("insights", "Planning & shopping", "Planen & Einkaufen", "What do Shopping Insights show?", "Was zeigen die Einkaufsstatistiken?", "Find them in Settings. Variety counts distinct ingredients added to shopping; frequency shows which ingredients you add most often. Monthly groups help you notice your own patterns. Everything is calculated from history stored on this device.", "Du findest sie in Einstellungen. Vielfalt zählt unterschiedliche zum Einkauf hinzugefügte Zutaten; Häufigkeit zeigt oft hinzugefügte Zutaten. Monatsgruppen machen eigene Muster sichtbar. Alles wird aus dem Verlauf auf diesem Gerät berechnet.")
faq("cook-mode", "Cooking", "Kochen", "Can I pause a recipe and come back?", "Kann ich ein Rezept pausieren und später fortsetzen?", "Yes. Cook mode keeps your step and progress locally. Use its pause and resume controls. Step timers help with waiting; check the food as well as the clock. Completing a recipe adds it to your local cooking history.", "Ja. Der Kochmodus speichert Schritt und Fortschritt lokal. Nutze Pause und Fortsetzen. Schritttimer helfen beim Warten; prüfe das Essen zusätzlich zur Uhr. Beim Abschließen wird das Rezept deinem lokalen Kochverlauf hinzugefügt.")
faq("accessibility", "Cooking", "Kochen", "Can I cook one-handed or use visual timer alerts?", "Kann ich einhändig kochen oder visuelle Timerhinweise nutzen?", "Enable quick-next tap in Settings to advance by tapping the step text. Taps are debounced to avoid accidental repeats. Visual timer alerts use coral and teal; reduced motion keeps feedback calm. Both features are optional.", "Aktiviere in Einstellungen das Weitertippen, um durch Tippen auf den Schritttext weiterzugehen. Schnelle Wiederholungen werden abgefangen. Visuelle Timerhinweise verwenden Koralle und Petrol; reduzierte Bewegung hält das Feedback ruhig. Beide Funktionen sind optional.")
faq("backup", "Backup & privacy", "Sicherung & Datenschutz", "How do I save a backup?", "Wie sichere ich meine Daten?", "In Settings, export a backup and save it through your device's share sheet. You get a JSON file and a smaller GZip file. Both include your profile, saved recipes, plans and history. Keep a copy somewhere you can find again.", "Exportiere in Einstellungen eine Sicherung und speichere sie über die Teilen-Funktion deines Geräts. Du erhältst eine JSON-Datei und eine kleinere GZip-Datei. Beide enthalten Profil, gespeicherte Rezepte, Pläne und Verlauf. Bewahre eine Kopie auffindbar auf.")
faq("encryption", "Backup & privacy", "Sicherung & Datenschutz", "Does a backup password protect both files?", "Schützt ein Sicherungspasswort beide Dateien?", "No. A password encrypts the JSON file with AES-256-GCM. The GZip copy remains unencrypted for compatibility and contains the same personal data. Share only the encrypted JSON when password protection is needed. Keep the password: it cannot be recovered.", "Nein. Ein Passwort verschlüsselt die JSON-Datei mit AES-256-GCM. Die GZip-Kopie bleibt aus Kompatibilitätsgründen unverschlüsselt und enthält dieselben persönlichen Daten. Teile bei gewünschtem Passwortschutz nur die verschlüsselte JSON-Datei. Bewahre das Passwort auf; es kann nicht wiederhergestellt werden.")
faq("restore", "Backup & privacy", "Sicherung & Datenschutz", "What is the difference between merge and replace?", "Was ist der Unterschied zwischen Zusammenführen und Ersetzen?", "Merge keeps existing collections and adds backup entries, resolving matching identifiers. Replace restores the backed-up state in place of your current state. Import validates the file first and never changes the bundled recipes.", "Zusammenführen behält vorhandene Sammlungen und ergänzt Sicherungseinträge anhand ihrer Kennungen. Ersetzen stellt den Sicherungsstand anstelle deines aktuellen Stands her. Der Import prüft zuerst die Datei und ändert niemals die mitgelieferten Rezepte.")
faq("offline", "Backup & privacy", "Sicherung & Datenschutz", "Does MorphCook send my information anywhere?", "Versendet MorphCook meine Informationen?", "No. Recipes, search, matching and personal history work on your device. There is no account, telemetry, cloud sync or live AI. Exporting through the share sheet is your own explicit action.", "Nein. Rezepte, Suche, Zuordnung und persönlicher Verlauf funktionieren auf deinem Gerät. Es gibt kein Konto, keine Telemetrie, Cloud-Synchronisierung oder Live-KI. Ein Export über die Teilen-Funktion ist deine ausdrückliche Aktion.")
faq("search-empty", "Troubleshooting", "Fehlerbehebung", "Why does my search have no results?", "Warum hat meine Suche keine Treffer?", "Try a shorter word, remove search tags or check your profile restrictions. The bundled cookbook is finite. Searches with no results are kept locally as content requests and can be included in your backup; they are never sent automatically.", "Versuche ein kürzeres Wort, entferne Such-Tags oder prüfe deine Profilregeln. Das mitgelieferte Kochbuch ist begrenzt. Suchen ohne Treffer werden lokal als Inhaltswünsche gespeichert und können in der Sicherung enthalten sein; sie werden nie automatisch versendet.")
faq("language", "Troubleshooting", "Fehlerbehebung", "Can I change the language later?", "Kann ich die Sprache später ändern?", "Yes. Switch between English and German in Settings. Your profile, saved recipe IDs and planning data remain the same.", "Ja. Wechsle in Einstellungen zwischen Englisch und Deutsch. Profil, gespeicherte Rezeptkennungen und Plandaten bleiben gleich.")


def build():
    ASSETS.mkdir(parents=True, exist_ok=True)
    for name, data in [("recipes.json", recipes), ("dishes.json", dishes), ("ingredients.json", ingredients),
                       ("ontology.json", ontology), ("ingredient-guide.json", guides), ("faqs.json", faqs)]:
        write(name, data)
    from corpus import rebuild_partitions
    rebuild_partitions(ASSETS)
    print(f"Built {len(dishes)} dish concepts, {len(recipes)} authored bilingual recipes, {len(ingredients)} ingredients and {len(faqs)} FAQs.")


if __name__ == "__main__":
    build()
