"""Ontology: flag taxonomy, compound flags, attributes, dimensions.

Complete for day-1 launch. Extending is purely additive.
"""
from common import L

CONTAINS_FLAGS = {
    "pork": L("pork", "Schwein"),
    "beef": L("beef", "Rind"),
    "lamb": L("lamb", "Lamm"),
    "poultry": L("poultry", "Geflügel"),
    "fish": L("fish", "Fisch"),
    "shellfish": L("shellfish", "Schalentiere"),
    "molluscs": L("molluscs", "Weichtiere"),
    "egg": L("egg", "Ei"),
    "dairy": L("dairy", "Milch"),
    "gluten": L("gluten", "Gluten"),
    "soy": L("soy", "Soja"),
    "peanuts": L("peanuts", "Erdnüsse"),
    "tree-nuts": L("tree nuts", "Baumnüsse"),
    "almonds": L("almonds", "Mandeln"),
    "walnuts": L("walnuts", "Walnüsse"),
    "pistachios": L("pistachios", "Pistazien"),
    "cashews": L("cashews", "Cashews"),
    "sesame": L("sesame", "Sesam"),
    "mustard": L("mustard", "Senf"),
    "celery": L("celery", "Sellerie"),
    "lupin": L("lupin", "Lupinen"),
    "sulphites": L("sulphites", "Sulfite"),
    "alcohol": L("alcohol", "Alkohol"),
    "caffeine": L("caffeine", "Koffein"),
    "added-sugar": L("added sugar", "zugesetzter Zucker"),
    "high-fodmap": L("high FODMAP", "FODMAP-reich"),
    "gelatin-non-halal": L("non-halal gelatin", "nicht-halale Gelatine"),
    "gelatin-non-kosher": L("non-kosher gelatin", "nicht-koschere Gelatine"),
    "honey": L("honey", "Honig"),
}

# User-facing shortcuts that expand into contains-flags.
COMPOUND_FLAGS = {
    "vegan": ["pork", "beef", "lamb", "poultry", "fish", "shellfish", "molluscs",
              "egg", "dairy", "honey", "gelatin-non-halal", "gelatin-non-kosher"],
    "vegetarian": ["pork", "beef", "lamb", "poultry", "fish", "shellfish",
                   "gelatin-non-halal", "gelatin-non-kosher"],
    "pescatarian": ["pork", "beef", "lamb", "poultry", "gelatin-non-halal"],
    "halal": ["pork", "alcohol", "gelatin-non-halal"],
    "kosher": ["pork", "shellfish", "gelatin-non-kosher"],
    "low-fodmap": ["high-fodmap"],
    "sugar-free": ["added-sugar"],
    "lactose-free": ["dairy"],
    "nut-free": ["peanuts", "tree-nuts", "almonds", "walnuts", "pistachios", "cashews"],
}

COMPOUND_LABELS = {
    "vegan": L("vegan", "vegan"),
    "vegetarian": L("vegetarian", "vegetarisch"),
    "pescatarian": L("pescatarian", "pescetarisch"),
    "halal": L("halal", "halal"),
    "kosher": L("kosher", "koscher"),
    "low-fodmap": L("low FODMAP", "FODMAP-arm"),
    "sugar-free": L("sugar-free", "zuckerfrei"),
    "lactose-free": L("lactose-free", "laktosefrei"),
    "nut-free": L("nut-free", "nussfrei"),
}

# Positive descriptors; a profile may *require* these.
ATTRIBUTE_LABELS = {
    "halal": L("halal", "halal"),
    "kosher": L("kosher", "koscher"),
    "vegan": L("vegan", "vegan"),
    "vegetarian": L("vegetarian", "vegetarisch"),
    "gluten-free": L("gluten-free", "glutenfrei"),
    "high-protein": L("high protein", "proteinreich"),
    "low-carb": L("low carb", "kohlenhydratarm"),
    "comfort": L("comfort", "Komfort"),
    "weeknight": L("weeknight", "alltagstauglich"),
    "one-pan": L("one pan", "ein Topf"),
    "meal-prep": L("meal prep", "meal prep"),
    "kid-friendly": L("kid-friendly", "kinderfreundlich"),
    "alcohol-free": L("alcohol-free", "alkoholfrei"),
    "caffeine-free": L("caffeine-free", "koffeinfrei"),
}

EFFORT = ["easy", "medium", "hard"]
EFFORT_LABELS = {
    "easy": L("easy", "einfach"),
    "medium": L("medium", "mittel"),
    "hard": L("hard", "anspruchsvoll"),
}

TIME_BUCKET_LABELS = {
    "t15": L("≤ 15 min", "≤ 15 Min"),
    "t30": L("≤ 30 min", "≤ 30 Min"),
    "t60": L("≤ 60 min", "≤ 60 Min"),
    "t60plus": L("> 60 min", "> 60 Min"),
}

CALORIE_BUCKET_LABELS = {
    "c400": L("≤ 400 kcal", "≤ 400 kcal"),
    "c600": L("≤ 600 kcal", "≤ 600 kcal"),
    "c800": L("≤ 800 kcal", "≤ 800 kcal"),
    "c800plus": L("> 800 kcal", "> 800 kcal"),
}

TECHNIQUES = ["bake", "saute", "simmer", "raw", "grill", "fry", "steam",
              "roast", "broil", "pan-fry", "deep-fry", "stir-fry", "poach", "blanch"]
TECHNIQUE_LABELS = {
    "bake": L("bake", "backen"),
    "saute": L("sauté", "anbraten"),
    "simmer": L("simmer", "köcheln"),
    "raw": L("raw", "roh"),
    "grill": L("grill", "grillen"),
    "fry": L("fry", "braten"),
    "steam": L("steam", "dämpfen"),
    "roast": L("roast", "rösten"),
    "broil": L("broil", "gratinieren"),
    "pan-fry": L("pan-fry", "in der Pfanne braten"),
    "deep-fry": L("deep-fry", "frittieren"),
    "stir-fry": L("stir-fry", "wok-braten"),
    "poach": L("poach", "pochieren"),
    "blanch": L("blanch", "blanchieren"),
}

# Per-dimension variant switcher axes.
DIET_AXES = ["classic", "vegetarian", "vegan", "keto", "halal", "gluten-free",
             "low-carb", "pescatarian"]
DIET_AXIS_LABELS = {
    "classic": L("classic", "klassisch"),
    "vegetarian": L("vegetarian", "vegetarisch"),
    "vegan": L("vegan", "vegan"),
    "keto": L("keto", "keto"),
    "halal": L("halal", "halal"),
    "gluten-free": L("gluten-free", "glutenfrei"),
    "low-carb": L("low-carb", "kohlenhydratarm"),
    "pescatarian": L("pescatarian", "pescetarisch"),
}

CALORIE_LEVELS = ["light", "standard", "hearty"]
CALORIE_LEVEL_LABELS = {
    "light": L("light", "leicht"),
    "standard": L("standard", "standard"),
    "hearty": L("hearty", "deftig"),
}


def build():
    return {
        "schema_version": 1,
        "contains_flags": {k: {"label": v} for k, v in CONTAINS_FLAGS.items()},
        "compound_flags": {
            k: {"label": COMPOUND_LABELS[k], "expands_to": v}
            for k, v in COMPOUND_FLAGS.items()
        },
        "attributes": {k: {"label": v} for k, v in ATTRIBUTE_LABELS.items()},
        "effort": {
            "values": EFFORT,
            "labels": EFFORT_LABELS,
        },
        "time_bucket": {"labels": TIME_BUCKET_LABELS},
        "calorie_bucket": {"labels": CALORIE_BUCKET_LABELS},
        "techniques": {"values": TECHNIQUES, "labels": TECHNIQUE_LABELS},
        "dimensions": {
            "diet": {"values": DIET_AXES, "labels": DIET_AXIS_LABELS},
            "effort": {"values": EFFORT, "labels": EFFORT_LABELS},
            "calorie_level": {"values": CALORIE_LEVELS, "labels": CALORIE_LEVEL_LABELS},
        },
    }
