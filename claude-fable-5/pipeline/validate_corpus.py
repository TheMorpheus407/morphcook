#!/usr/bin/env python3
"""Mechanical validator for the wave-4 lattice corpus.

Modes (all need --ctx pointing at a dir with ontology.json + ingredients.json):
  --plan FILE            validate one dish plan
  --column FILE          validate one authored column/extras file (recipes only)
  --dish FILE --plan-file FILE
                         validate a merged per-dish file against its plan
  --dishes DIR --plans DIR [--current DIR]
                         validate the whole corpus: every dish + cross-dish
Exit 0 = no errors (warnings allowed). Prints a report; --json for machine use.
"""
import argparse, json, math, re, sys
from pathlib import Path

CORE_DIETS = ["classic", "vegetarian", "vegan"]
EXTRA_DIETS = {"gluten-free", "low-fodmap"}
EFFORTS = {"easy", "medium", "hard"}
CAL_BUCKETS = ["le400", "le600", "le800", "gt800"]
UNITS = {"g", "kg", "ml", "l", "tsp", "tbsp", "cup", "piece",
         "clove", "slice", "can", "bunch", "pinch", "sprig"}
MEALS = {"breakfast", "lunch", "dinner"}
SERVINGS = {2, 3, 4, 6}
NUT_FLAGS = {"peanuts", "tree-nuts", "almonds", "walnuts", "cashews",
             "hazelnuts", "pistachios", "pine-nuts"}
RETIRED_ATTRS = {"keto", "high-protein", "light", "nut-free", "classic"}
TITLE_BANS = [r"vegan\w*", r"vegetar\w*", r"veggie", r"classic\w*",
              r"klassi\w*", r"keto", r"halal", r"kosher", r"koscher",
              r"gluten\w*", r"fodmap", r"sugar.?free", r"zucker.?frei\w*",
              r"protein\w*", r"light", r"leicht\w*", r"lactose\w*",
              r"laktose\w*", r"pescatari\w*", r"nut.?free", r"kalorien\w*",
              r"calorie\w*", r"low.?carb", r"diaet", r"diät\w*"]
TITLE_BAN_RE = re.compile(r"\b(" + "|".join(TITLE_BANS) + r")\b", re.I)
SALT_HINT = re.compile(r"salt|salz|soy-sauce|sojasauce|tamari|miso|stock|"
                       r"broth|brühe|feta|parmesan|pecorino|caper|anchov|"
                       r"olive|pickle|fish-sauce|cheese|käse|bacon|halloumi|"
                       r"kimchi|gochujang", re.I)

def effort_time_ok(effort, minutes):
    return {"easy": minutes <= 45,
            "medium": 25 <= minutes <= 95,
            "hard": minutes >= 60}[effort]

def cal_bucket(c):
    return "le400" if c <= 400 else "le600" if c <= 600 \
        else "le800" if c <= 800 else "gt800"

def time_bucket(m):
    return "le15" if m <= 15 else "le30" if m <= 30 \
        else "le60" if m <= 60 else "gt60"

class Ctx:
    def __init__(self, d):
        d = Path(d)
        self.ont = json.loads((d / "ontology.json").read_text())
        ing = json.loads((d / "ingredients.json").read_text())
        self.contains_flags = {f["id"] for f in self.ont["contains_flags"]}
        self.compounds = {c["id"]: set(c["expands_to"])
                          for c in self.ont["compound_flags"]}
        self.techniques = set(self.ont["attributes"]["technique"])
        self.ing_flags = {}   # id -> inherited flag set
        def walk(node, inherited):
            flags = set(node.get("flags", [])) | inherited
            self.ing_flags[node["id"]] = flags
            for ch in node.get("children", []):
                walk(ch, flags)
        for root in ing["nodes"]:
            walk(root, set())

def loc_ok(v):
    return (isinstance(v, dict) and isinstance(v.get("en"), str)
            and isinstance(v.get("de"), str) and v["en"].strip()
            and v["de"].strip())

def hashable(v):
    """JSON scalars are safe set members / dict keys; containers are not."""
    return isinstance(v, (str, int, float, bool)) or v is None

def str_set(value, field, err):
    """Coerce a JSON value into a set of strings, reporting defects."""
    if value is None:
        return set()
    if not isinstance(value, list):
        err(f"{field} is not a list")
        return set()
    bad = [x for x in value if not isinstance(x, str)]
    if bad:
        err(f"{field} has non-string entries {bad!r}")
    return {x for x in value if isinstance(x, str)}

def contains_set(r):
    c = r.get("contains")
    return {x for x in c if isinstance(x, str)} if isinstance(c, list) \
        else set()

def check_recipe(r, ctx, errors, warnings, dish_id=None):
    # Tolerate arbitrarily malformed input: this validator sits inside an
    # LLM feedback loop, so every defect must become an error message,
    # never a crash.
    if not isinstance(r, dict):
        errors.append("<recipe>: not a JSON object")
        return
    rid = r.get("id", "<no id>")
    def err(msg): errors.append(f"{rid}: {msg}")
    def warn(msg): warnings.append(f"{rid}: {msg}")

    if not isinstance(rid, str) or not re.fullmatch(r"[a-z0-9-]+", rid):
        err("bad id")
        rid = str(rid)
    if dish_id and r.get("dish_id") != dish_id:
        err(f"dish_id {r.get('dish_id')} != {dish_id}")
    for f in ("title", "caption", "intro"):
        if not loc_ok(r.get(f)):
            err(f"{f} missing en/de")
    v = r.get("variant") if isinstance(r.get("variant"), dict) else {}
    diet, effort, cal = v.get("diet"), v.get("effort"), v.get("calorie")
    if not isinstance(diet, str) or diet not in set(CORE_DIETS) | EXTRA_DIETS:
        err(f"diet '{diet}' not allowed")
    if not isinstance(effort, str) or effort not in EFFORTS:
        err(f"effort '{effort}' invalid")
    if not isinstance(cal, str) or cal not in CAL_BUCKETS:
        err(f"calorie '{cal}' invalid")
    # Column purity: the diet coordinate is a promise about contains.
    diet_bans = {"vegan": ctx.compounds.get("vegan", set()),
                 "vegetarian": ctx.compounds.get("vegetarian", set()),
                 "gluten-free": {"gluten"},
                 "low-fodmap": {"high-fodmap"}}
    clash = contains_set(r) & set(diet_bans.get(diet, ()))
    if clash:
        err(f"diet '{diet}' but contains {sorted(clash)}")

    if loc_ok(r.get("title")):
        for lang in ("en", "de"):
            m = TITLE_BAN_RE.search(r["title"][lang])
            if m:
                err(f"title[{lang}] contains banned diet word '{m.group(0)}'")
            if len(r["title"][lang]) > 60:
                warn(f"title[{lang}] over 60 chars")
    if loc_ok(r.get("caption")):
        if len(r["caption"]["en"]) > 60 or len(r["caption"]["de"]) > 60:
            warn("caption over 60 chars")
    if loc_ok(r.get("intro")):
        for lang in ("en", "de"):
            if not 100 <= len(r["intro"][lang]) <= 480:
                warn(f"intro[{lang}] length {len(r['intro'][lang])} "
                     "outside 100-480")

    ings = r.get("ingredients") if isinstance(r.get("ingredients"), list) \
        else []
    if not 5 <= len(ings) <= 10:
        err(f"{len(ings)} ingredients (need 5-10)")
    for i in ings:
        if not isinstance(i, dict):
            err(f"ingredient entry {i!r} is not an object")
    ings = [i for i in ings if isinstance(i, dict)]
    seen_ing, implied = set(), set()
    for i in ings:
        iid = i.get("ingredient_id")
        if not isinstance(iid, str):
            err(f"bad ingredient_id {iid!r}")
            iid = repr(iid)
        if iid in seen_ing:
            err(f"duplicate ingredient {iid}")
        seen_ing.add(iid)
        if iid not in ctx.ing_flags:
            err(f"unknown ingredient '{iid}'")
        else:
            implied |= ctx.ing_flags[iid]
        unit = i.get("unit")
        if not isinstance(unit, str) or unit not in UNITS:
            err(f"bad unit '{unit}' on {iid}")
        qty = i.get("qty")
        if not (isinstance(qty, (int, float)) and not isinstance(qty, bool)
                and qty > 0):
            err(f"bad qty on {iid}")
        if "note" in i and i["note"] is not None and not loc_ok(i["note"]):
            err(f"note on {iid} missing en/de")

    contains = str_set(r.get("contains"), "contains", err)
    unknown = contains - ctx.contains_flags
    if unknown:
        err(f"unknown contains flags {sorted(unknown)}")
    missing = implied - contains
    if missing:
        err(f"contains missing ingredient-implied flags {sorted(missing)}")

    attrs = str_set(r.get("attributes"), "attributes", err)
    retired = attrs & RETIRED_ATTRS
    if retired:
        err(f"retired attributes {sorted(retired)}")
    for cid, expansion in ctx.compounds.items():
        qualifies = not (contains & expansion)
        if cid == "lactose-free":
            if cid in attrs and not qualifies:
                err("claims lactose-free but contains dairy-expansion flag")
            continue
        if qualifies and cid not in attrs:
            err(f"qualifies for {cid} but does not declare it")
        if not qualifies and cid in attrs:
            err(f"claims {cid} but contains "
                f"{sorted(contains & expansion)}")
    gf = "gluten" not in contains
    if ("gluten-free" in attrs) != gf:
        err("gluten-free attribute inconsistent with contains")

    steps = r.get("steps") if isinstance(r.get("steps"), list) else []
    if not 4 <= len(steps) <= 8:
        err(f"{len(steps)} steps (need 4-8)")
    steps = [s for s in steps if isinstance(s, dict)]
    timers = 0
    for idx, s in enumerate(steps):
        if not loc_ok(s.get("text")):
            err(f"step {idx+1} text missing en/de")
        t = s.get("timer_minutes")
        if t is not None:
            timers += 1
            if not (isinstance(t, int) and not isinstance(t, bool)
                    and 1 <= t <= 240):
                err(f"step {idx+1} timer {t} out of range")
    if timers < 2:
        err(f"only {timers} timed steps (need >=2)")

    def num(value, field):
        if isinstance(value, (int, float)) and not isinstance(value, bool):
            return value
        err(f"{field} is not a number")
        return 0

    tm = num(r.get("time_minutes", 0), "time_minutes")
    if time_bucket(tm) not in attrs:
        err(f"time bucket {time_bucket(tm)} not in attributes")
    if isinstance(effort, str) and effort in EFFORTS:
        if effort not in attrs:
            err("effort missing from attributes")
        if not effort_time_ok(effort, tm):
            warn(f"time {tm}min unusual for effort '{effort}'")
    cps = num(r.get("calories_per_serving", 0), "calories_per_serving")
    if cal in CAL_BUCKETS:
        if cal != cal_bucket(cps):
            err(f"{cps} kcal is bucket {cal_bucket(cps)}, variant says {cal}")
        if cal not in attrs:
            err("calorie bucket missing from attributes")
    m = r.get("macros") if isinstance(r.get("macros"), dict) else {}
    if not isinstance(r.get("macros"), dict):
        err("macros missing or not an object")
    if m.get("calories") != r.get("calories_per_serving"):
        err("macros.calories != calories_per_serving")
    energy = 4 * num(m.get("protein_g", 0), "macros.protein_g") \
        + 4 * num(m.get("carbs_g", 0), "macros.carbs_g") \
        + 9 * num(m.get("fat_g", 0), "macros.fat_g")
    if cps and abs(energy - cps) / cps > 0.16:
        err(f"macro energy {energy} vs {cps} kcal off by >16%")

    if not (attrs & ctx.techniques):
        err("no technique attribute")
    if len(attrs & ctx.techniques) > 3:
        warn("more than 3 technique tags")
    sv = r.get("servings")
    if isinstance(sv, bool) or not hashable(sv) or sv not in SERVINGS:
        err(f"servings {sv!r} not in {sorted(SERVINGS)}")
    meals = r.get("meal", [])
    if (not isinstance(meals, list) or not meals
            or not all(isinstance(m, str) for m in meals)
            or not set(meals) <= MEALS):
        err(f"bad meal field {meals}")
    tags = r.get("tags") if isinstance(r.get("tags"), dict) else {}
    for lang in ("en", "de"):
        tl = tags.get(lang) if isinstance(tags.get(lang), list) else []
        if not 2 <= len(tl) <= 4:
            warn(f"{len(tl)} tags[{lang}] (want 2-4)")
    blob = json.dumps([i.get("ingredient_id") for i in ings]) + \
        json.dumps([s.get("text", {}) for s in steps], ensure_ascii=False)
    if not SALT_HINT.search(blob):
        warn("no salt or salty ingredient apparent")

def plan_diets(plan, err=None):
    diets = plan.get("diets", CORE_DIETS)
    ok = (isinstance(diets, list) and diets
          and all(isinstance(d, str) for d in diets)
          and diets[0] == "classic"
          and set(diets) <= set(CORE_DIETS)
          and len(diets) == len(set(diets)))
    if not ok and err:
        err(f"bad diets {diets} (must be classic [+ vegetarian] [+ vegan])")
    if ok and len(diets) < 3 and err and not plan.get("diets_reason"):
        err(f"diets {diets} reduced without diets_reason")
    return diets if ok else CORE_DIETS

def check_plan(plan, ctx, errors, warnings, current=None):
    if not isinstance(plan, dict):
        errors.append("plan: not a JSON object")
        return
    did = plan.get("dish_id", "<dish>")
    def err(m): errors.append(f"plan {did}: {m}")
    diets = plan_diets(plan, err)
    ep = plan.get("effort_pair") \
        if isinstance(plan.get("effort_pair"), list) else []
    cp = plan.get("calorie_pair") \
        if isinstance(plan.get("calorie_pair"), list) else []
    if not (len(ep) == 2 and all(isinstance(e, str) for e in ep)
            and set(ep) <= EFFORTS and ep[0] != ep[1]):
        err(f"bad effort_pair {ep}")
    if not (len(cp) == 2 and all(isinstance(c, str) for c in cp)
            and set(cp) <= set(CAL_BUCKETS) and cp[0] != cp[1]):
        err(f"bad calorie_pair {cp}")
    elif abs(CAL_BUCKETS.index(cp[0]) - CAL_BUCKETS.index(cp[1])) != 1:
        warnings.append(f"plan {did}: non-adjacent calorie pair {cp}")
    # Downstream set/tuple building needs hashable members.
    ep = [e for e in ep if isinstance(e, str)]
    cp = [c for c in cp if isinstance(c, str)]
    raw_cells = plan.get("cells") if isinstance(plan.get("cells"), list) \
        else []
    cells = [c for c in raw_cells if isinstance(c, dict)]
    if len(cells) != len(raw_cells):
        err("cells contains non-object entries")
    extras = plan.get("extras") if isinstance(plan.get("extras"), list) \
        else []
    extras = [x for x in extras if isinstance(x, dict)]
    def coord(c, k):
        value = c.get(k)
        return value if hashable(value) else repr(value)

    want = {(d, e, c) for d in diets for e in ep for c in cp}
    got = {(coord(c, "diet"), coord(c, "effort"), coord(c, "calorie"))
           for c in cells}
    if len(cells) != len(want) or got != want:
        err(f"cells do not form the {len(diets)}x2x2 lattice "
            f"(got {len(cells)}, missing {sorted(want - got, key=repr)}, "
            f"stray {sorted(got - want, key=repr)})")
    ids = [coord(c, "recipe_id") for c in cells] + \
        [coord(x, "recipe_id") for x in extras]
    if len(ids) != len(set(ids)):
        err("duplicate recipe ids in plan")
    for x in extras:
        d = x.get("diet")
        if not isinstance(d, str) or d not in EXTRA_DIETS:
            err(f"extra diet {d} not allowed")
        if x.get("effort") not in ep or x.get("calorie") not in cp:
            err(f"extra {x.get('recipe_id')} coords outside dish pairs")
    cov = plan.get("coverage_cells") \
        if isinstance(plan.get("coverage_cells"), list) else []
    cov = [c for c in cov if isinstance(c, dict)]
    cov_ids = [coord(c, "recipe_id") for c in cov]
    if len(set(cov_ids) | set(ids)) != len(set(cov_ids)) + len(set(ids)) \
            or len(cov_ids) != len(set(cov_ids)):
        err("coverage cell ids collide with cells/extras or each other")
    base_diets = {coord(c, "diet") for c in cells} | \
        {coord(x, "diet") for x in extras}
    for c in cov:
        if not isinstance(c.get("recipe_id"), str):
            err(f"coverage cell has non-string recipe_id "
                f"{c.get('recipe_id')!r}")
        if coord(c, "diet") not in base_diets:
            err(f"coverage {c.get('recipe_id')} diet outside dish columns")
        if c.get("effort") not in ep or c.get("calorie") not in cp:
            err(f"coverage {c.get('recipe_id')} coords outside dish pairs")
        fo = c.get("free_of")
        fo_set = {x for x in fo if isinstance(x, str)} \
            if isinstance(fo, list) else set()
        if not fo_set or (isinstance(fo, list) and len(fo) != len(fo_set)) \
                or fo_set - ctx.contains_flags:
            err(f"coverage {c.get('recipe_id')} bad free_of {fo}")
    if current is not None:
        lmap = plan.get("legacy_map") \
            if isinstance(plan.get("legacy_map"), list) else []
        lmap = [m for m in lmap if isinstance(m, dict)]
        legacy = {r["id"] for r in current.get("recipes", [])}
        mapped = {coord(m, "id") for m in lmap}
        if legacy - mapped:
            err(f"legacy ids unaccounted: {sorted(legacy - mapped)}")
        reused = {coord(m, "id") for m in lmap
                  if m.get("action") == "reuse"}
        if reused - set(ids):
            err(f"legacy ids marked reuse but absent from cells/extras: "
                f"{sorted(reused - set(ids), key=repr)}")

def check_dish(dish, plan, ctx, errors, warnings):
    if not isinstance(dish, dict):
        errors.append("dish: not a JSON object")
        return
    if not isinstance(plan, dict):
        errors.append("dish: plan is not a JSON object")
        plan = {}
    did = dish.get("dish_id", "<dish>")
    recipes = dish.get("recipes") if isinstance(dish.get("recipes"), list) \
        else []
    for r in recipes:
        check_recipe(r, ctx, errors, warnings, dish_id=did)
    recipes = [r for r in recipes if isinstance(r, dict)]
    # Coverage variants share a base cell's coordinates on purpose — they
    # re-author the cell without specific allergens. They are exempt from
    # the duplicate-triple rule but must match their registered cell.
    cov_raw = plan.get("coverage_cells") \
        if isinstance(plan.get("coverage_cells"), list) else []
    cov_by_id = {c.get("recipe_id"): c for c in cov_raw
                 if isinstance(c, dict)
                 and isinstance(c.get("recipe_id"), str)}
    triples = {}
    for r in recipes:
        v = r.get("variant") if isinstance(r.get("variant"), dict) else {}
        key = tuple(v.get(k) if hashable(v.get(k)) else repr(v.get(k))
                    for k in ("diet", "effort", "calorie"))
        cov_cell = cov_by_id.get(r.get("id"))
        if cov_cell is not None:
            for k in ("diet", "effort", "calorie"):
                if v.get(k) != cov_cell.get(k):
                    errors.append(f"{did}: coverage {r.get('id')} {k} "
                                  f"'{v.get(k)}' != registered "
                                  f"'{cov_cell.get(k)}'")
            free_of = {x for x in (cov_cell.get("free_of") or [])
                       if isinstance(x, str)}
            clash = contains_set(r) & free_of
            if clash:
                errors.append(f"{did}: coverage {r.get('id')} declares "
                              f"free_of {sorted(free_of)} but contains "
                              f"{sorted(clash)}")
            continue
        if key in triples:
            errors.append(f"{did}: duplicate variant triple {key}")
        triples[key] = r
    ep = plan.get("effort_pair") \
        if isinstance(plan.get("effort_pair"), list) else []
    cp = plan.get("calorie_pair") \
        if isinstance(plan.get("calorie_pair"), list) else []
    ep = [e for e in ep if isinstance(e, str)]
    cp = [c for c in cp if isinstance(c, str)]
    want = {(d, e, c) for d in plan_diets(plan) for e in ep for c in cp}
    missing = want - set(triples)
    if missing:
        errors.append(f"{did}: lattice incomplete, missing "
                      f"{sorted(missing, key=repr)}")
    for key in set(triples) - want:
        if key[0] not in EXTRA_DIETS:
            errors.append(f"{did}: stray non-extra cell {key}")
        elif key[1] not in ep or key[2] not in cp:
            errors.append(f"{did}: extra {key} outside dish pairs")
    for lang in ("en", "de"):
        titles = [r["title"][lang].strip().lower() for r in recipes
                  if loc_ok(r.get("title"))]
        dupes = {t for t in titles if titles.count(t) > 1}
        if dupes:
            errors.append(f"{did}: duplicate titles[{lang}] {sorted(dupes)}")
        caps = [r["caption"][lang].strip().lower() for r in recipes
                if loc_ok(r.get("caption"))]
        cdup = {c for c in caps if caps.count(c) > 1}
        if cdup:
            warnings.append(f"{did}: duplicate captions[{lang}] {sorted(cdup)}")
    # soul-rule coverage
    exc_raw = plan.get("exceptions") \
        if isinstance(plan.get("exceptions"), list) else []
    exceptions = {e.get("profile") for e in exc_raw
                  if isinstance(e, dict) and hashable(e.get("profile"))}
    profiles = {
        "vegan": ctx.compounds["vegan"], "vegetarian": ctx.compounds["vegetarian"],
        "halal": ctx.compounds["halal"], "kosher": ctx.compounds["kosher"],
        "gluten": {"gluten"}, "dairy": {"dairy"}, "egg": {"egg"},
        "nuts": NUT_FLAGS, "soy": {"soy"},
    }
    for name, avoid in profiles.items():
        if any(not (contains_set(r) & avoid) for r in recipes):
            continue
        msg = f"{did}: no recipe visible for {name}-avoiding profile"
        if name in exceptions:
            warnings.append(msg + " (declared exception)")
        elif name in ("nuts", "soy"):
            warnings.append(msg)
        else:
            errors.append(msg)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ctx", required=True)
    ap.add_argument("--plan")
    ap.add_argument("--column")
    ap.add_argument("--dish")
    ap.add_argument("--plan-file")
    ap.add_argument("--dishes")
    ap.add_argument("--plans")
    ap.add_argument("--current")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    ctx = Ctx(a.ctx)
    errors, warnings = [], []

    def load(p): return json.loads(Path(p).read_text())

    if a.plan and not a.dish:
        plan_doc = load(a.plan)
        cur = None
        if a.current:
            did = plan_doc.get("dish_id") \
                if isinstance(plan_doc, dict) else None
            cp = Path(a.current) / f"{did}.json"
            cur = load(cp) if isinstance(did, str) and cp.exists() \
                else {"recipes": []}
        check_plan(plan_doc, ctx, errors, warnings, current=cur)
    if a.column:
        col = load(a.column)
        for r in col.get("recipes", []):
            check_recipe(r, ctx, errors, warnings,
                         dish_id=col.get("dish_id"))
        if a.plan_file:
            plan = load(a.plan_file)
            cells_raw = plan.get("cells") \
                if isinstance(plan.get("cells"), list) else []
            cells_p = [c for c in cells_raw if isinstance(c, dict)]
            extras_raw = plan.get("extras") \
                if isinstance(plan.get("extras"), list) else []
            extras_p = [x for x in extras_raw if isinstance(x, dict)]
            coverage_raw = plan.get("coverage_cells") \
                if isinstance(plan.get("coverage_cells"), list) else []
            coverage_p = [c for c in coverage_raw if isinstance(c, dict)]
            slots = {c.get("recipe_id"): c
                     for c in cells_p + extras_p + coverage_p
                     if isinstance(c.get("recipe_id"), str)}
            seen = set()
            for r in col.get("recipes", []):
                if not isinstance(r, dict):
                    continue  # already reported by check_recipe
                rid = r.get("id")
                slot = slots.get(rid) if isinstance(rid, str) else None
                if slot is None:
                    errors.append(f"{rid!r}: not a planned cell")
                    continue
                seen.add(rid)
                v = r.get("variant") \
                    if isinstance(r.get("variant"), dict) else {}
                for k in ("diet", "effort", "calorie"):
                    if v.get(k) != slot.get(k):
                        errors.append(f"{rid}: {k} '{v.get(k)}' != "
                                      f"planned '{slot.get(k)}'")
            which = col.get("diet")
            if which == "extras":
                expected = {x.get("recipe_id") for x in extras_p
                            if isinstance(x.get("recipe_id"), str)}
            else:
                expected = {c.get("recipe_id") for c in cells_p
                            if isinstance(c.get("recipe_id"), str)
                            and c.get("diet") == which}
            if expected - seen:
                errors.append(f"column {col.get('dish_id')}/{which}: "
                              f"missing planned cells {sorted(expected - seen)}")
    if a.dish:
        check_dish(load(a.dish), load(a.plan_file or a.plan), ctx,
                   errors, warnings)
    if a.dishes:
        all_ids = {}
        for f in sorted(Path(a.dishes).glob("*.json")):
            dish = load(f)
            plan = load(Path(a.plans) / f.name)
            if a.current:
                cur_p = Path(a.current) / f.name
                cur = load(cur_p) if cur_p.exists() else {"recipes": []}
                check_plan(plan, ctx, errors, warnings, current=cur)
            check_dish(dish, plan, ctx, errors, warnings)
            for r in dish.get("recipes", []):
                rid = r.get("id") if isinstance(r, dict) else None
                if not isinstance(rid, str):
                    continue  # already reported by check_recipe
                if rid in all_ids:
                    errors.append(f"global duplicate id {rid} "
                                  f"({all_ids[rid]} and {f.name})")
                all_ids[rid] = f.name

    if a.json:
        print(json.dumps({"errors": errors, "warnings": warnings}, indent=1))
    else:
        for e in errors:
            print(f"ERROR   {e}")
        for w in warnings:
            print(f"warning {w}")
        print(f"-- {len(errors)} errors, {len(warnings)} warnings")
    sys.exit(1 if errors else 0)

if __name__ == "__main__":
    main()
