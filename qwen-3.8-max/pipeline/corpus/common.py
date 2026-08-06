"""Shared helpers for the MorphCook corpus build."""


def L(en, de):
    """Bilingual text: Map<lang, String>."""
    return {"en": en, "de": de}


def ingredient(ingredient_id, qty, unit, en=None, de=None, optional=False):
    item = {"ingredient_id": ingredient_id, "qty": qty, "unit": unit}
    if en or de:
        item["note"] = L(en or "", de or "")
    if optional:
        item["optional"] = True
    return item


def step(en, de, timer_seconds=None):
    s = {"text": L(en, de)}
    if timer_seconds:
        s["timer_seconds"] = timer_seconds
    return s


TIME_BUCKETS = [("t15", 15), ("t30", 30), ("t60", 60), ("t60plus", 10 ** 9)]


def time_bucket(minutes):
    for bucket, limit in TIME_BUCKETS:
        if minutes <= limit:
            return bucket
    return "t60plus"


def calorie_bucket(calories):
    if calories <= 400:
        return "c400"
    if calories <= 600:
        return "c600"
    if calories <= 800:
        return "c800"
    return "c800plus"


def finalize_recipe(r):
    """Derive computed fields so authored data stays terse."""
    r["schema_version"] = 1
    r["time_bucket"] = time_bucket(r["time_minutes"])
    r["calorie_bucket"] = calorie_bucket(r["calories_per_serving"])
    r["ingredient_ids"] = sorted({i["ingredient_id"] for i in r["ingredients"]})
    if "attributes" not in r:
        r["attributes"] = []
    axes = r["axes"]
    if axes.get("diet") == "vegan" and "vegan" not in r["attributes"]:
        r["attributes"].append("vegan")
    if axes.get("diet") == "halal" and "halal" not in r["attributes"]:
        r["attributes"].append("halal")
    if axes.get("diet") == "gluten-free" and "gluten-free" not in r["attributes"]:
        r["attributes"].append("gluten-free")
    r["attributes"] = sorted(r["attributes"])
    return r
