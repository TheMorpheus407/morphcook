"""Hierarchical ingredient dictionary with aisles and unit forms.

Avoidance propagates to children: avoiding a parent node excludes every
descendant. `form` drives unit-aware shopping aggregation (liquids convert
ml <-> tbsp; countables keep their natural unit).
"""
from common import L

AISLES = [
    {"id": "produce", "name": L("produce", "Obst & Gemüse"), "order": 0},
    {"id": "bakery", "name": L("bakery", "Bäckerei"), "order": 1},
    {"id": "dairy-eggs", "name": L("dairy & eggs", "Milch & Eier"), "order": 2},
    {"id": "meat-fish", "name": L("meat & fish", "Fleisch & Fisch"), "order": 3},
    {"id": "pantry", "name": L("pantry", "Vorratskammer"), "order": 4},
    {"id": "spices", "name": L("spices & herbs", "Gewürze & Kräuter"), "order": 5},
]


def node(id, en, de, form="solid", children=None):
    n = {"id": id, "name": L(en, de), "form": form}
    if children:
        n["children"] = children
    return n


TREE = [
    node("vegetables", "vegetables", "Gemüse", children=[
        node("tomato", "tomatoes", "Tomaten"),
        node("cherry-tomato", "cherry tomatoes", "Kirschtomaten"),
        node("garlic", "garlic", "Knoblauch", form="count"),
        node("onion", "onions", "Zwiebeln"),
        node("red-onion", "red onions", "rote Zwiebeln"),
        node("scallion", "scallions", "Frühlingszwiebeln", form="count"),
        node("leek", "leek", "Lauch"),
        node("shallot", "shallots", "Schalotten"),
        node("bell-pepper", "bell peppers", "Paprika"),
        node("chili", "fresh chili", "frische Chili", form="count"),
        node("cucumber", "cucumber", "Gurke"),
        node("carrot", "carrots", "Karotten"),
        node("zucchini", "zucchini", "Zucchini"),
        node("broccoli", "broccoli", "Brokkoli"),
        node("cauliflower", "cauliflower", "Blumenkohl"),
        node("spinach", "spinach", "Spinat"),
        node("lettuce", "lettuce", "Salat"),
        node("romaine", "romaine", "Römersalat"),
        node("arugula", "arugula", "Rucola"),
        node("cabbage", "cabbage", "Weißkohl"),
        node("celery", "celery", "Sellerie"),
        node("radish", "radishes", "Radieschen"),
        node("mushroom", "mushrooms", "Champignons"),
        node("peas", "peas", "Erbsen"),
        node("green-beans", "green beans", "grüne Bohnen"),
        node("potato", "potatoes", "Kartoffeln"),
        node("sweet-potato", "sweet potatoes", "Süßkartoffeln"),
        node("ginger", "ginger", "Ingwer"),
        node("beet", "beet", "Rote Bete"),
    ]),
    node("fresh-herbs", "fresh herbs", "frische Kräuter", children=[
        node("basil", "basil", "Basilikum", form="count"),
        node("mint", "mint", "Minze", form="count"),
        node("parsley", "parsley", "Petersilie", form="count"),
        node("cilantro", "cilantro", "Koriandergrün", form="count"),
        node("dill", "dill", "Dill", form="count"),
        node("chives", "chives", "Schnittlauch", form="count"),
        node("rosemary", "rosemary", "Rosmarin", form="count"),
        node("thyme", "thyme", "Thymian", form="count"),
    ]),
    node("fruit", "fruit", "Obst", children=[
        node("lemon", "lemons", "Zitronen", form="count"),
        node("lime", "limes", "Limetten", form="count"),
        node("apple", "apples", "Äpfel", form="count"),
        node("banana", "bananas", "Bananen", form="count"),
        node("mango", "mango", "Mango", form="count"),
        node("berries", "berries", "Beeren"),
        node("avocado", "avocado", "Avocado", form="count"),
        node("dates", "dates", "Datteln"),
    ]),
    node("bakery-goods", "bakery", "Backwaren", children=[
        node("flour", "flour", "Mehl", children=[
            node("wheat-flour", "wheat flour", "Weizenmehl"),
            node("spelt-flour", "spelt flour", "Dinkelmehl"),
            node("almond-flour", "almond flour", "Mandelmehl"),
        ]),
        node("bread", "bread", "Brot", children=[
            node("sourdough", "sourdough", "Sauerteigbrot"),
            node("flatbread", "flatbread", "Fladenbrot", form="count"),
            node("pita", "pita", "Pita", form="count"),
            node("brioche", "brioche", "Brioche"),
            node("baguette", "baguette", "Baguette", form="count"),
        ]),
        node("pasta", "pasta", "Pasta", children=[
            node("spaghetti", "spaghetti", "Spaghetti"),
            node("penne", "penne", "Penne"),
            node("lasagne-sheets", "lasagne sheets", "Lasagneplatten"),
            node("gnocchi", "gnocchi", "Gnocchi"),
        ]),
        node("pizza-dough", "pizza dough", "Pizzateig"),
        node("breadcrumbs", "breadcrumbs", "Semmelbrösel"),
        node("baking-powder", "baking powder", "Backpulver"),
    ]),
    node("dairy", "dairy", "Milchprodukte", children=[
        node("cow-milk", "cow's milk", "Kuhmilch", form="liquid", children=[
            node("whole-milk", "whole milk", "Vollmilch", form="liquid"),
            node("skim-milk", "skim milk", "fettarme Milch", form="liquid"),
        ]),
        node("goat-milk", "goat's milk", "Ziegenmilch", form="liquid"),
        node("oat-milk", "oat milk", "Hafermilch", form="liquid"),
        node("butter", "butter", "Butter"),
        node("cream", "cream", "Sahne", form="liquid"),
        node("cheese", "cheese", "Käse", children=[
            node("parmesan", "parmesan", "Parmesan"),
            node("feta", "feta", "Feta"),
            node("mozzarella", "mozzarella", "Mozzarella"),
            node("cheddar", "cheddar", "Cheddar"),
            node("cream-cheese", "cream cheese", "Frischkäse"),
            node("halloumi", "halloumi", "Halloumi"),
        ]),
        node("yogurt", "yogurt", "Joghurt", children=[
            node("greek-yogurt", "greek yogurt", "griechischer Joghurt"),
        ]),
        node("sour-cream", "sour cream", "Schmand"),
    ]),
    node("egg", "eggs", "Eier", form="count"),
    node("meat", "meat", "Fleisch", children=[
        node("beef", "beef", "Rindfleisch", children=[
            node("ground-beef", "ground beef", "Rinderhack"),
            node("beef-slices", "beef slices", "Rindergeschnetzeltes"),
        ]),
        node("poultry", "poultry", "Geflügel", children=[
            node("chicken-breast", "chicken breast", "Hähnchenbrust"),
            node("chicken-thigh", "chicken thighs", "Hähnchenschenkel"),
        ]),
        node("lamb", "lamb", "Lamm", children=[
            node("ground-lamb", "ground lamb", "Lammhack"),
        ]),
        node("pork", "pork", "Schweinefleisch", children=[
            node("bacon", "bacon", "Bacon"),
            node("sucuk", "sucuk", "Sucuk"),
        ]),
    ]),
    node("fish-seafood", "fish & seafood", "Fisch & Meeresfrüchte", children=[
        node("salmon", "salmon", "Lachs"),
        node("tuna", "tuna", "Thunfisch"),
        node("shrimp", "shrimp", "Garnelen"),
        node("anchovy", "anchovies", "Sardellen"),
    ]),
    node("oils-vinegars", "oils & vinegars", "Öle & Essig", children=[
        node("olive-oil", "olive oil", "Olivenöl", form="liquid"),
        node("vegetable-oil", "vegetable oil", "Pflanzenöl", form="liquid"),
        node("sesame-oil", "sesame oil", "Sesamöl", form="liquid"),
        node("balsamic", "balsamic vinegar", "Balsamico", form="liquid"),
        node("apple-cider-vinegar", "apple cider vinegar", "Apfelessig", form="liquid"),
        node("rice-vinegar", "rice vinegar", "Reisessig", form="liquid"),
    ]),
    node("canned-jarred", "canned & jarred", "Konserven & Gläser", children=[
        node("canned-tomato", "canned tomatoes", "Dosentomaten", form="liquid"),
        node("tomato-paste", "tomato paste", "Tomatenmark"),
        node("chickpeas", "chickpeas", "Kichererbsen"),
        node("kidney-beans", "kidney beans", "Kidneybohnen"),
        node("lentils", "lentils", "Linsen", children=[
            node("red-lentils", "red lentils", "rote Linsen"),
            node("brown-lentils", "brown lentils", "braune Linsen"),
        ]),
        node("coconut-milk", "coconut milk", "Kokosmilch", form="liquid"),
        node("vegetable-stock", "vegetable stock", "Gemüsebrühe", form="liquid"),
        node("olives", "olives", "Oliven"),
    ]),
    node("grains-cereals", "grains & cereals", "Getreide & Cerealien", children=[
        node("rice", "rice", "Reis", children=[
            node("basmati", "basmati rice", "Basmatireis"),
            node("jasmine-rice", "jasmine rice", "Jasminreis"),
            node("arborio", "arborio rice", "Arborioreis"),
        ]),
        node("quinoa", "quinoa", "Quinoa"),
        node("couscous", "couscous", "Couscous"),
        node("bulgur", "bulgur", "Bulgur"),
        node("oats", "oats", "Haferflocken"),
        node("rice-noodles", "rice noodles", "Reisnudeln"),
        node("ramen-noodles", "ramen noodles", "Ramen-Nudeln"),
    ]),
    node("sweets-sweeteners", "sweeteners", "Süßungsmittel", children=[
        node("sugar", "sugar", "Zucker"),
        node("brown-sugar", "brown sugar", "brauner Zucker"),
        node("maple-syrup", "maple syrup", "Ahornsirup", form="liquid"),
        node("honey", "honey", "Honig", form="liquid"),
    ]),
    node("nuts-seeds", "nuts & seeds", "Nüsse & Samen", children=[
        node("peanuts", "peanuts", "Erdnüsse"),
        node("tree-nuts", "tree nuts", "Baumnüsse", children=[
            node("walnuts", "walnuts", "Walnüsse"),
            node("almonds", "almonds", "Mandeln"),
            node("pistachios", "pistachios", "Pistazien"),
            node("cashews", "cashews", "Cashews"),
        ]),
        node("sesame-seeds", "sesame seeds", "Sesamsamen"),
        node("peanut-butter", "peanut butter", "Erdnussbutter"),
        node("tahini", "tahini", "Tahini", form="liquid"),
    ]),
    node("spices-dried", "spices", "Gewürze", children=[
        node("salt", "salt", "Salz"),
        node("pepper", "black pepper", "schwarzer Pfeffer"),
        node("cumin", "cumin", "Kreuzkümmel"),
        node("paprika", "paprika", "Paprikapulver"),
        node("smoked-paprika", "smoked paprika", "geräucherte Paprika"),
        node("oregano", "dried oregano", "getrockneter Oregano"),
        node("chili-flakes", "chili flakes", "Chiliflocken"),
        node("cinnamon", "cinnamon", "Zimt"),
        node("nutmeg", "nutmeg", "Muskatnuss"),
        node("turmeric", "turmeric", "Kurkuma"),
        node("curry-powder", "curry powder", "Currypulver"),
        node("sumac", "sumac", "Sumach"),
        node("zaatar", "za'atar", "Za'atar"),
    ]),
    node("condiments", "condiments & pastes", "Würzsaucen & Pasten", children=[
        node("soy-sauce", "soy sauce", "Sojasauce", form="liquid"),
        node("fish-sauce", "fish sauce", "Fischsauce", form="liquid"),
        node("mustard", "mustard", "Senf"),
        node("miso", "miso paste", "Misopaste"),
        node("curry-paste", "curry paste", "Currypaste"),
        node("gochujang", "gochujang", "Gochujang"),
        node("nutritional-yeast", "nutritional yeast", "Hefeflocken"),
        node("hot-sauce", "hot sauce", "scharfe Sauce", form="liquid"),
        node("mayonnaise", "mayonnaise", "Mayonnaise"),
        node("ketchup", "ketchup", "Ketchup"),
    ]),
    node("plant-protein", "plant protein", "pflanzliches Protein", children=[
        node("tofu", "tofu", "Tofu"),
        node("tempeh", "tempeh", "Tempeh"),
        node("seitan", "seitan", "Seitan"),
    ]),
    node("drinks", "drinks", "Getränke", children=[
        node("coffee", "coffee", "Kaffee"),
        node("tea", "tea", "Tee"),
        node("orange-juice", "orange juice", "Orangensaft", form="liquid"),
    ]),
]


def _walk(nodes, aisle):
    out = []
    for n in nodes:
        n = dict(n)
        n["aisle"] = aisle
        if "children" in n:
            n["children"] = _walk(n["children"], aisle)
        out.append(n)
    return out


def build():
    tree = []
    for top in TREE:
        aisle = top["id"]
        if aisle == "vegetables" or aisle == "fresh-herbs" or aisle == "fruit":
            aisle = "produce"
        elif aisle == "bakery-goods":
            aisle = "bakery"
        elif aisle in ("dairy", "egg"):
            aisle = "dairy-eggs"
        elif aisle in ("meat", "fish-seafood"):
            aisle = "meat-fish"
        else:
            aisle = "pantry"
        if aisle == "spices-dried":
            aisle = "spices"
        n = dict(top)
        n["aisle"] = aisle
        if "children" in n:
            n["children"] = _walk(n["children"], aisle)
        tree.append(n)
    return {
        "schema_version": 1,
        "aisles": AISLES,
        "tree": tree,
    }
