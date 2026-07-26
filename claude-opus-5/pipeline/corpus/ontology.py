"""Flag taxonomy for MorphCook.

Extending is purely additive: append a row, regenerate. No schema migration,
no engine change, no breaking change for user data already on device.
"""

# id, en, de, category, allergen(EU 14 list)
CONTAINS_FLAGS = [
    ("pork", "Pork", "Schweinefleisch", "meat", False),
    ("beef", "Beef", "Rindfleisch", "meat", False),
    ("lamb", "Lamb", "Lammfleisch", "meat", False),
    ("poultry", "Poultry", "Geflügel", "meat", False),
    ("fish", "Fish", "Fisch", "seafood", True),
    ("shellfish", "Crustaceans", "Krebstiere", "seafood", True),
    ("molluscs", "Molluscs", "Weichtiere", "seafood", True),
    ("egg", "Egg", "Ei", "animal", True),
    ("dairy", "Dairy", "Milchprodukte", "animal", True),
    ("lactose", "Lactose", "Laktose", "animal", False),
    ("honey", "Honey", "Honig", "animal", False),
    ("gelatin-non-halal", "Non-halal gelatin", "Nicht-halal-Gelatine", "animal", False),
    ("gelatin-non-kosher", "Non-kosher gelatin", "Nicht-koschere Gelatine", "animal", False),
    ("meat-dairy-combo", "Meat & dairy together", "Fleisch & Milch zusammen", "animal", False),
    ("gluten", "Gluten", "Gluten", "grain", True),
    ("soy", "Soy", "Soja", "legume", True),
    ("peanuts", "Peanuts", "Erdnüsse", "legume", True),
    ("lupin", "Lupin", "Lupine", "legume", True),
    ("tree-nuts", "Tree nuts", "Schalenfrüchte", "nut", True),
    ("almonds", "Almonds", "Mandeln", "nut", True),
    ("walnuts", "Walnuts", "Walnüsse", "nut", True),
    ("pistachios", "Pistachios", "Pistazien", "nut", True),
    ("cashews", "Cashews", "Cashewkerne", "nut", True),
    ("hazelnuts", "Hazelnuts", "Haselnüsse", "nut", True),
    ("coconut", "Coconut", "Kokosnuss", "nut", False),
    ("sesame", "Sesame", "Sesam", "seed", True),
    ("mustard", "Mustard", "Senf", "seed", True),
    ("celery", "Celery", "Sellerie", "vegetable", True),
    ("nightshades", "Nightshades", "Nachtschattengewächse", "vegetable", False),
    ("corn", "Corn", "Mais", "grain", False),
    ("yeast", "Yeast", "Hefe", "other", False),
    ("sulphites", "Sulphites", "Sulfite", "other", True),
    ("alcohol", "Alcohol", "Alkohol", "other", False),
    ("caffeine", "Caffeine", "Koffein", "other", False),
    ("added-sugar", "Added sugar", "Zugesetzter Zucker", "other", False),
    ("high-fodmap", "High FODMAP", "Hoch-FODMAP", "other", False),
]

MEAT = ["pork", "beef", "lamb", "poultry"]
SEA = ["fish", "shellfish", "molluscs"]
NUTS = ["tree-nuts", "almonds", "walnuts", "pistachios", "cashews", "hazelnuts"]
GELATIN = ["gelatin-non-halal", "gelatin-non-kosher"]

# id, en, de, expands_to, en note, de note
COMPOUND_FLAGS = [
    (
        "vegan", "Vegan", "Vegan",
        MEAT + SEA + ["egg", "dairy", "lactose", "honey"] + GELATIN,
        "Nothing that came from an animal.",
        "Nichts, was von einem Tier stammt.",
    ),
    (
        "vegetarian", "Vegetarian", "Vegetarisch",
        MEAT + SEA + GELATIN,
        "No meat, no fish, no animal gelatin. Eggs and dairy stay.",
        "Kein Fleisch, kein Fisch, keine Gelatine. Eier und Milch bleiben.",
    ),
    (
        "pescatarian", "Pescatarian", "Pescetarisch",
        MEAT + GELATIN,
        "Fish and seafood stay on the table.",
        "Fisch und Meeresfrüchte bleiben auf dem Tisch.",
    ),
    (
        "halal", "Halal-compatible ingredients", "Halal-kompatible Zutaten",
        ["pork", "alcohol", "gelatin-non-halal"],
        "Ingredient-level only. We never claim certification — that is a "
        "property of sourcing and supervision, not of a recipe text.",
        "Nur auf Zutatenebene. Wir behaupten nie eine Zertifizierung — die "
        "hängt an Herkunft und Aufsicht, nicht am Rezepttext.",
    ),
    (
        "kosher", "Kosher-compatible ingredients", "Koscher-kompatible Zutaten",
        ["pork", "shellfish", "molluscs", "meat-dairy-combo", "gelatin-non-kosher"],
        "Ingredient-level only. We never claim certification — that is a "
        "property of sourcing and supervision, not of a recipe text.",
        "Nur auf Zutatenebene. Wir behaupten nie eine Zertifizierung — die "
        "hängt an Herkunft und Aufsicht, nicht am Rezepttext.",
    ),
    (
        "gluten-free", "Gluten-free", "Glutenfrei", ["gluten"],
        "No wheat, rye, barley or spelt.",
        "Kein Weizen, Roggen, Gerste oder Dinkel.",
    ),
    (
        "lactose-free", "Lactose-free", "Laktosefrei", ["lactose"],
        "Aged cheese, butter and ghee are usually fine — only the "
        "lactose-carrying dairy is excluded.",
        "Gereifter Käse, Butter und Ghee sind meist in Ordnung — "
        "ausgeschlossen wird nur laktosehaltige Milch.",
    ),
    (
        "dairy-free", "Dairy-free", "Milchfrei", ["dairy", "lactose"],
        "Nothing from milk at all.",
        "Gar nichts aus Milch.",
    ),
    (
        "nut-free", "Nut-free", "Nussfrei", NUTS + ["peanuts"],
        "Tree nuts and peanuts both excluded.",
        "Schalenfrüchte und Erdnüsse ausgeschlossen.",
    ),
    (
        "low-fodmap", "Low FODMAP", "Low FODMAP", ["high-fodmap"],
        "Gentle on a sensitive gut.",
        "Schonend für einen empfindlichen Darm.",
    ),
    (
        "sugar-free", "No added sugar", "Ohne Zuckerzusatz", ["added-sugar"],
        "Natural sugars in fruit and vegetables stay.",
        "Natürlicher Zucker aus Obst und Gemüse bleibt.",
    ),
    (
        "alcohol-free", "Alcohol-free", "Alkoholfrei", ["alcohol"],
        "Including alcohol that would cook off.",
        "Auch Alkohol, der beim Kochen verdampfen würde.",
    ),
    (
        "caffeine-free", "Caffeine-free", "Koffeinfrei", ["caffeine"],
        "No coffee, no black tea, no cacao nibs.",
        "Kein Kaffee, kein Schwarztee, keine Kakaonibs.",
    ),
    (
        "shellfish-free", "Shellfish-free", "Ohne Krebs- & Weichtiere",
        ["shellfish", "molluscs"],
        "Crustaceans and molluscs both excluded.",
        "Krebstiere und Weichtiere ausgeschlossen.",
    ),
    (
        "egg-free", "Egg-free", "Ohne Ei", ["egg"],
        "No eggs, not even as a binder.",
        "Keine Eier, auch nicht als Bindemittel.",
    ),
    (
        "soy-free", "Soy-free", "Ohne Soja", ["soy"],
        "No tofu, tempeh, edamame or soy sauce.",
        "Kein Tofu, Tempeh, Edamame oder Sojasauce.",
    ),
]

EFFORT_LEVELS = [
    ("easy", "easy", "einfach", "Hands-on, barely.", "Kaum Aufwand."),
    ("medium", "medium", "mittel", "A real cook, still a weeknight.",
     "Richtig kochen, trotzdem werktags machbar."),
    ("hard", "involved", "aufwendig", "You chose this on purpose.",
     "Das hast du dir bewusst ausgesucht."),
]

TIME_BUCKETS = [
    ("t15", 15, "≤ 15 min", "≤ 15 Min."),
    ("t30", 30, "≤ 30 min", "≤ 30 Min."),
    ("t60", 60, "≤ 60 min", "≤ 60 Min."),
    ("t60plus", 10_000, "over an hour", "über eine Stunde"),
]

CALORIE_BUCKETS = [
    ("light", 400, "light", "leicht", "≤ 400 kcal"),
    ("balanced", 600, "balanced", "ausgewogen", "≤ 600 kcal"),
    ("hearty", 800, "hearty", "herzhaft", "≤ 800 kcal"),
    ("feast", 100_000, "feast", "Festmahl", "over 800 kcal"),
]

TECHNIQUES = [
    ("bake", "bake", "backen"),
    ("sauté", "sauté", "anbraten"),
    ("simmer", "simmer", "köcheln"),
    ("raw", "raw", "roh"),
    ("grill", "grill", "grillen"),
    ("fry", "fry", "braten"),
    ("steam", "steam", "dämpfen"),
    ("roast", "roast", "rösten"),
    ("broil", "broil", "überbacken"),
    ("pan-fry", "pan-fry", "in der Pfanne braten"),
    ("deep-fry", "deep-fry", "frittieren"),
    ("stir-fry", "stir-fry", "pfannenrühren"),
    ("poach", "poach", "pochieren"),
    ("blanch", "blanch", "blanchieren"),
]

# Positive, non-derivable descriptors a recipe can carry.
ATTRIBUTES = [
    ("high-protein", "high protein", "proteinreich"),
    ("one-pot", "one pot", "ein Topf"),
    ("meal-prep", "meal prep friendly", "meal-prep-tauglich"),
    ("kid-friendly", "kid friendly", "kinderfreundlich"),
    ("budget", "budget", "günstig"),
    ("make-ahead", "make ahead", "vorzubereiten"),
    ("comfort", "comfort food", "Seelenfutter"),
    ("light-meal", "light", "leicht"),
    ("freezer-friendly", "freezes well", "einfrierbar"),
    ("no-cook", "no cooking required", "ohne Kochen"),
    ("sharing", "for sharing", "zum Teilen"),
]

# The variant switcher is data-driven: one row per entry, in this order.
DIMENSIONS = [
    ("diet", "diet", "Ernährung",
     "Same dish, written for a different body.",
     "Dasselbe Gericht, für einen anderen Körper geschrieben."),
    ("effort", "effort", "Aufwand",
     "How much of you it asks for today.",
     "Wie viel es heute von dir verlangt."),
    ("calorie_level", "calorie level", "Kalorienstufe",
     "Portion weight, roughly.",
     "Ungefähres Portionsgewicht."),
]

DIET_AXIS_VALUES = [
    ("classic", "classic", "klassisch"),
    ("vegetarian", "vegetarian", "vegetarisch"),
    ("vegan", "vegan", "vegan"),
    ("pescatarian", "pescatarian", "pescetarisch"),
    ("gluten-free", "gluten-free", "glutenfrei"),
    ("dairy-free", "dairy-free", "milchfrei"),
    ("nut-free", "nut-free", "nussfrei"),
    ("keto", "keto", "keto"),
    ("halal", "halal-compatible", "halal-kompatibel"),
    ("kosher", "kosher-compatible", "koscher-kompatibel"),
    ("low-fodmap", "low FODMAP", "low FODMAP"),
    ("sugar-free", "no added sugar", "ohne Zuckerzusatz"),
    ("alcohol-free", "without alcohol", "ohne Alkohol"),
    ("caffeine-free", "caffeine-free", "koffeinfrei"),
    ("light", "light", "leicht"),
]

MEAL_SLOTS = [
    ("breakfast", "breakfast", "Frühstück"),
    ("lunch", "lunch", "Mittag"),
    ("dinner", "dinner", "Abend"),
    ("snack", "snack", "Snack"),
    ("dessert", "dessert", "Nachtisch"),
]


def _l(en, de):
    return {"en": en, "de": de}


def build():
    return {
        "schema_version": 1,
        "contains_flags": [
            {
                "id": i,
                "label": _l(en, de),
                "category": cat,
                "eu_allergen": allergen,
            }
            for (i, en, de, cat, allergen) in CONTAINS_FLAGS
        ],
        "compound_flags": [
            {
                "id": i,
                "label": _l(en, de),
                "expands_to": exp,
                "note": _l(nen, nde),
            }
            for (i, en, de, exp, nen, nde) in COMPOUND_FLAGS
        ],
        "attributes": {
            "effort": [
                {"id": i, "label": _l(en, de), "note": _l(nen, nde)}
                for (i, en, de, nen, nde) in EFFORT_LEVELS
            ],
            "time_bucket": [
                {"id": i, "max_minutes": mx, "label": _l(en, de)}
                for (i, mx, en, de) in TIME_BUCKETS
            ],
            "calorie_bucket": [
                {"id": i, "max_kcal": mx, "label": _l(en, de), "range": rng}
                for (i, mx, en, de, rng) in CALORIE_BUCKETS
            ],
            "technique": [
                {"id": i, "label": _l(en, de)} for (i, en, de) in TECHNIQUES
            ],
            "descriptor": [
                {"id": i, "label": _l(en, de)} for (i, en, de) in ATTRIBUTES
            ],
        },
        "dimensions": [
            {"id": i, "label": _l(en, de), "note": _l(nen, nde)}
            for (i, en, de, nen, nde) in DIMENSIONS
        ],
        "axis_values": {
            "diet": [
                {"id": i, "label": _l(en, de)} for (i, en, de) in DIET_AXIS_VALUES
            ],
        },
        "meal_slots": [
            {"id": i, "label": _l(en, de)} for (i, en, de) in MEAL_SLOTS
        ],
        "certification_note": _l(
            "MorphCook describes ingredients, never certification. A recipe can "
            "use halal- or kosher-compatible ingredients; whether a meal is "
            "certified depends on sourcing, slaughter and supervision, which no "
            "recipe text can promise.",
            "MorphCook beschreibt Zutaten, nie Zertifizierungen. Ein Rezept kann "
            "halal- oder koscher-kompatible Zutaten verwenden; ob eine Mahlzeit "
            "zertifiziert ist, hängt von Herkunft, Schlachtung und Aufsicht ab — "
            "das kann kein Rezepttext versprechen.",
        ),
    }
