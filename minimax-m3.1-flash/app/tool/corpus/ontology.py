"""The flag taxonomy.

`contains_flags` are the primitives: what a recipe can have.
`avoid_flags` are the user-facing switches, each expanding into primitives.
`attributes` are the positive axes a recipe carries.

Extending the taxonomy is purely additive — a new line here plus regenerated
variants is the whole migration.
"""

CONTAINS_FLAGS = [
    # id, label_en, label_de, category
    ("pork", "Pork", "Schweinefleisch", "meat"),
    ("beef", "Beef", "Rindfleisch", "meat"),
    ("lamb", "Lamb", "Lamm", "meat"),
    ("poultry", "Poultry", "Geflügel", "meat"),
    ("fish", "Fish", "Fisch", "meat"),
    ("shellfish", "Shellfish", "Schalentiere", "meat"),
    ("molluscs", "Molluscs", "Weichtiere", "meat"),
    ("egg", "Egg", "Ei", "animal"),
    ("dairy", "Dairy", "Milchprodukte", "animal"),
    ("dairy-lactose", "Lactose", "Laktose", "animal"),
    ("honey", "Honey", "Honig", "animal"),
    ("gelatin-non-halal", "Non-halal gelatin", "Nicht-halal Gelatine", "animal"),
    ("gelatin-non-kosher", "Non-kosher gelatin", "Nicht-koscher Gelatine", "animal"),
    ("gluten", "Gluten", "Gluten", "allergen"),
    ("soy", "Soy", "Soja", "allergen"),
    ("peanuts", "Peanuts", "Erdnüsse", "allergen"),
    ("tree-nuts", "Tree nuts", "Schalenfrüchte", "allergen"),
    ("sesame", "Sesame", "Sesam", "allergen"),
    ("mustard", "Mustard", "Senf", "allergen"),
    ("celery", "Celery", "Sellerie", "allergen"),
    ("lupin", "Lupin", "Lupine", "allergen"),
    ("sulphites", "Sulphites", "Sulfite", "allergen"),
    ("alcohol", "Alcohol", "Alkohol", "other"),
    ("caffeine", "Caffeine", "Koffein", "other"),
    ("added-sugar", "Added sugar", "Zugesetzter Zucker", "other"),
    ("high-fodmap", "High FODMAP", "FODMAP-reich", "other"),
    ("meat-dairy-combo", "Meat and dairy", "Fleisch und Milchprodukte", "other"),
]


# id, label_en, label_de, description_en, description_de, expands, category
AVOID_FLAGS = [
    (
        "vegan",
        "Vegan",
        "Vegan",
        "No animal products at all.",
        "Keinerlei tierische Produkte.",
        [
            "pork",
            "beef",
            "lamb",
            "poultry",
            "fish",
            "shellfish",
            "molluscs",
            "egg",
            "dairy",
            "dairy-lactose",
            "honey",
            "gelatin-non-halal",
            "gelatin-non-kosher",
        ],
        "diet",
    ),
    (
        "vegetarian",
        "Vegetarian",
        "Vegetarisch",
        "No meat or fish.",
        "Kein Fleisch, kein Fisch.",
        [
            "pork",
            "beef",
            "lamb",
            "poultry",
            "fish",
            "shellfish",
            "molluscs",
            "gelatin-non-halal",
            "gelatin-non-kosher",
        ],
        "diet",
    ),
    (
        "pescatarian",
        "Pescatarian",
        "Pesk-etarisch",
        "Fish is fine, meat is not.",
        "Fisch ist okay, Fleisch nicht.",
        ["pork", "beef", "lamb", "poultry", "gelatin-non-halal"],
        "diet",
    ),
    (
        "halal",
        "Halal",
        "Halal",
        "No pork, no alcohol, no non-halal gelatin.",
        "Kein Schweinefleisch, kein Alkohol, keine nicht-halal Gelatine.",
        ["pork", "alcohol", "gelatin-non-halal"],
        "diet",
    ),
    (
        "kosher",
        "Kosher",
        "Koscher",
        "No pork, no shellfish, no non-kosher gelatin.",
        "Kein Schweinefleisch, keine Schalentiere, keine nicht-koscher Gelatine.",
        ["pork", "shellfish", "gelatin-non-kosher", "meat-dairy-combo"],
        "diet",
    ),
    (
        "dairy",
        "All dairy",
        "Alle Milchprodukte",
        "Milk, cream, butter and every cheese.",
        "Milch, Sahne, Butter und jeder Käse.",
        ["dairy", "dairy-lactose"],
        "class",
    ),
    (
        "lactose-free",
        "Lactose",
        "Laktose",
        "Milk and soft cream, but hard cheese is fine.",
        "Milch und weiche Sahne, Hartkäse ist okay.",
        ["dairy-lactose"],
        "class",
    ),
    (
        "nuts",
        "All nuts",
        "Alle Nüsse",
        "Tree nuts and peanuts.",
        "Schalenfrüchte und Erdnüsse.",
        ["tree-nuts", "peanuts"],
        "class",
    ),
    (
        "shellfish",
        "All shellfish",
        "Alle Schalentiere",
        "Prawns, crab, mussels, scallops.",
        "Garnelen, Krabben, Muscheln, Jakobsmuscheln.",
        ["shellfish"],
        "class",
    ),
    (
        "tree-nuts", "Tree nuts", "Schalenfrüchte", "Almonds, walnuts, cashews and more.", "Mandeln, Walnüsse, Cashews und mehr.", ["tree-nuts"], "class"),
    ("peanuts", "Peanuts", "Erdnüsse", "Peanuts and peanut oil.", "Erdnüsse und Erdnussöl.", ["peanuts"], "class"),
    ("gluten", "Gluten", "Gluten", "Wheat, rye, barley and the bread made of them.", "Weizen, Roggen, Gerste und das Brot daraus.", ["gluten"], "class"),
    ("soy", "Soy", "Soja", "Tofu, tempeh, soy sauce.", "Tofu, Tempeh, Sojasauce.", ["soy"], "class"),
    ("egg", "Egg", "Ei", "Eggs and anything set with them.", "Eier und alles, was damit geliert wird.", ["egg"], "class"),
    ("pork", "Pork", "Schweinefleisch", "Pork and bacon.", "Schweinefleisch und Speck.", ["pork"], "class"),
    ("beef", "Beef", "Rindfleisch", "Beef and veal.", "Rind- und Kalbsfleisch.", ["beef"], "class"),
    ("fish", "Fish", "Fisch", "All fish.", "Alle Fische.", ["fish"], "class"),
    ("sesame", "Sesame", "Sesam", "Seeds and sesame oil.", "Samen und Sesamöl.", ["sesame"], "class"),
    ("mustard", "Mustard", "Senf", "Mustard seeds and prepared mustard.", "Senfsamen und fertiger Senf.", ["mustard"], "class"),
    ("celery", "Celery", "Sellerie", "Celery stalks and celeriac.", "Selleriestangen und Knollensellerie.", ["celery"], "class"),
    ("lupin", "Lupin", "Lupine", "Lupin flour and lupin seeds.", "Lupinenmehl und Lupinensamen.", ["lupin"], "class"),
    ("sulphites", "Sulphites", "Sulfite", "Preserved fruit, wine, some dried fruit.", "Konservierte Früchte, Wein, manche Trockenfrüchte.", ["sulphites"], "class"),
    ("alcohol", "Alcohol", "Alkohol", "Anything fermented or distilled.", "Alles Fermentierte oder Destillierte.", ["alcohol"], "class"),
    ("caffeine", "Caffeine", "Koffein", "Coffee, tea, cola, energy drinks.", "Kaffee, Tee, Cola, Energydrinks.", ["caffeine"], "class"),
    ("added-sugar", "Added sugar", "Zugesetzter Zucker", "Sugar and syrups added by us.", "Zucker und Sirupe, die wir dazugeben.", ["added-sugar"], "class"),
    ("low-fodmap", "Low FODMAP", "Low FODMAP", "Avoid onion, garlic and wheat-heavy dishes.", "Vermeide Zwiebel, Knoblauch und weizenlastige Gerichte.", ["high-fodmap"], "class"),
    ("sugar-free", "Sugar-free", "Zuckerfrei", "No added sugar at all.", "Kein zugegebter Zucker.", ["added-sugar"], "class"),
    ("gelatin-non-halal", "Non-halal gelatin", "Nicht-halal Gelatine", "Gelatin from non-halal sources.", "Gelatine aus nicht-halal Quellen.", ["gelatin-non-halal"], "class"),
]


ATTRIBUTES = {
    "effort": {
        "label": {"en": "Effort", "de": "Aufwand"},
        "values": [
            {"id": "easy", "label": {"en": "easy", "de": "einfach"}},
            {"id": "medium", "label": {"en": "medium", "de": "mittel"}},
            {"id": "hard", "label": {"en": "hard", "de": "aufwendig"}},
        ],
    },
    "time_bucket": {
        "label": {"en": "Time", "de": "Zeit"},
        "values": [
            {"id": "≤15", "label": {"en": "≤ 15 min", "de": "≤ 15 Min."}},
            {"id": "≤30", "label": {"en": "≤ 30 min", "de": "≤ 30 Min."}},
            {"id": "≤60", "label": {"en": "≤ 60 min", "de": "≤ 60 Min."}},
            {"id": ">60", "label": {"en": "> 60 min", "de": "> 60 Min."}},
        ],
    },
    "calorie_bucket": {
        "label": {"en": "Calories", "de": "Kalorien"},
        "values": [
            {"id": "≤400", "label": {"en": "≤ 400", "de": "≤ 400"}},
            {"id": "≤600", "label": {"en": "≤ 600", "de": "≤ 600"}},
            {"id": "≤800", "label": {"en": "≤ 800", "de": "≤ 800"}},
            {"id": ">800", "label": {"en": "> 800", "de": "> 800"}},
        ],
    },
    "technique": {
        "label": {"en": "Technique", "de": "Technik"},
        "multi_valued": True,
        "values": [
            {"id": "bake", "label": {"en": "bake", "de": "backen"}},
            {"id": "sauté", "label": {"en": "sauté", "de": "schwenken"}},
            {"id": "simmer", "label": {"en": "simmer", "de": "schmoren"}},
            {"id": "raw", "label": {"en": "raw", "de": "roh"}},
            {"id": "grill", "label": {"en": "grill", "de": "grillen"}},
            {"id": "fry", "label": {"en": "fry", "de": "frittieren"}},
            {"id": "steam", "label": {"en": "steam", "de": "dämpfen"}},
            {"id": "roast", "label": {"en": "roast", "de": "rösten"}},
            {"id": "broil", "label": {"en": "broil", "de": "überbacken"}},
            {"id": "pan-fry", "label": {"en": "pan-fry", "de": "anbraten"}},
            {"id": "deep-fry", "label": {"en": "deep-fry", "de": "frittieren"}},
            {"id": "stir-fry", "label": {"en": "stir-fry", "de": "pfannenrühren"}},
            {"id": "poach", "label": {"en": "poach", "de": "pochieren"}},
            {"id": "blanch", "label": {"en": "blanch", "de": "blanchieren"}},
            {"id": "boil", "label": {"en": "boil", "de": "kochen"}},
        ],
    },
}

CERTIFICATIONS = ["vegan", "vegetarian", "pescatarian", "halal", "kosher"]

# Flags that make a recipe incompatible with each certification.
CERTIFICATION_BLOCKERS = {
    "vegan": [
        "pork",
        "beef",
        "lamb",
        "poultry",
        "fish",
        "shellfish",
        "molluscs",
        "egg",
        "dairy",
        "honey",
        "gelatin-non-halal",
        "gelatin-non-kosher",
    ],
    "vegetarian": [
        "pork",
        "beef",
        "lamb",
        "poultry",
        "fish",
        "shellfish",
        "molluscs",
        "gelatin-non-halal",
        "gelatin-non-kosher",
    ],
    "pescatarian": ["pork", "beef", "lamb", "poultry", "gelatin-non-halal"],
    "halal": ["pork", "alcohol", "gelatin-non-halal"],
    "kosher": ["pork", "shellfish", "gelatin-non-kosher", "meat-dairy-combo"],
}

# Flags that make a recipe incompatible with the *diet* it claims.
#
# A diet is the user-facing label of a variant ("gluten-free"), a
# certification is the positive marker it may carry ("vegan"). A
# gluten-free recipe that contains gluten is a contradiction the corpus
# builder refuses to ship.
DIET_BLOCKERS = {
    "vegan": CERTIFICATION_BLOCKERS["vegan"],
    "vegetarian": CERTIFICATION_BLOCKERS["vegetarian"],
    "pescatarian": CERTIFICATION_BLOCKERS["pescatarian"],
    "halal": CERTIFICATION_BLOCKERS["halal"],
    "kosher": CERTIFICATION_BLOCKERS["kosher"],
    "gluten-free": ["gluten"],
    "dairy-free": ["dairy", "dairy-lactose"],
    "lactose-free": ["dairy-lactose"],
    "nut-free": ["tree-nuts", "peanuts"],
}
