#!/usr/bin/env python3
"""Pipeline contract tests — mechanical quality gates, no agents required."""
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
PIPELINE = HERE.parent
ASSETS = PIPELINE.parent / "app" / "assets"
GEN = ASSETS / "_gen"

failures = []


def check(name, cond, detail=""):
    status = "ok" if cond else "FAIL"
    print(f"[{status}] {name}{(' — ' + detail) if detail and not cond else ''}")
    if not cond:
        failures.append(name)


def load(path):
    return json.loads(Path(path).read_text())


def load_all_gen():
    recipes = []
    for f in sorted(GEN.glob("*.json")):
        recipes += load(f)["recipes"]
    return recipes


def main():
    recipes = load_all_gen()
    ontology = load(ASSETS / "ontology.json")
    nodes = {n["id"]: n for n in load(ASSETS / "ingredients.json")["nodes"]}
    dishes = {d["id"]: d for d in load(ASSETS / "dishes.json")["dishes"]}

    # ---- schema validation (structural subset of recipe.schema.json) ----
    units = {"g", "kg", "mg", "ml", "l", "tbsp", "tsp", "pinch", "dash",
             "piece", "clove", "stick", "bunch"}
    for r in recipes:
        rid = r["id"]
        for key in ("id", "dish_id", "title", "subtitle", "diet", "servings",
                    "time_minutes", "effort", "calories_per_serving",
                    "macros", "contains", "ingredients", "steps"):
            check(f"schema:{rid}:{key}", key in r)
        check(f"schema:{rid}:effort", r.get("effort") in {"easy", "medium", "hard"})
        check(f"schema:{rid}:servings", isinstance(r.get("servings"), int) and r["servings"] >= 1)
        for ing in r.get("ingredients", []):
            check(f"schema:{rid}:unit:{ing['id']}", ing["unit"] in units)
        for step in r.get("steps", []):
            ts = step.get("timer_seconds")
            check(f"schema:{rid}:timer", ts is None or (isinstance(ts, int) and ts >= 5))

    # ---- ontology validation ----
    flag_names = set(ontology["contains_flags"]) | set(ontology["compound_flags"])
    diet_names = set(ontology["diet_labels"])
    for r in recipes:
        for f in r["contains"]:
            check(f"ontology:{r['id']}:{f}", f in flag_names)
        check(f"ontology:{r['id']}:diet", r["diet"] in diet_names)

    # ---- cross-check: contains ⊇ derived flags ----
    def derived(ing_id):
        out = set()
        cur = nodes.get(ing_id)
        while cur:
            if cur.get("flag"):
                out.add(cur["flag"])
            cur = nodes.get(cur.get("parent")) if cur.get("parent") else None
        return out

    for r in recipes:
        need = set()
        for ing in r["ingredients"]:
            need |= derived(ing["id"])
        missing = need - set(r["contains"])
        check(f"cross:{r['id']}", not missing, f"missing {sorted(missing)}")

    # ---- duplicate detection: near-identical variants of one dish ----
    by_dish = {}
    for r in recipes:
        by_dish.setdefault(r["dish_id"], []).append(r)
    for dish_id, variants in by_dish.items():
        for i in range(len(variants)):
            for j in range(i + 1, len(variants)):
                a, b = variants[i], variants[j]
                ia = {x["id"] for x in a["ingredients"]}
                ib = {x["id"] for x in b["ingredients"]}
                if not ia or not ib:
                    continue
                overlap = len(ia & ib) / len(ia | ib)
                check(
                    f"duplicate:{a['id']}~{b['id']}",
                    overlap < 0.95,
                    f"ingredient overlap {overlap:.0%}",
                )

    # ---- dry-run leaves no writes ----
    with tempfile.TemporaryDirectory() as td:
        snapshot = {p: p.stat().st_mtime for p in GEN.glob("*.json")}
        result = subprocess.run(
            ["./pipeline.sh", "--dish", "doener", "--variants", "classic",
             "--agent", "test", "--dry-run"],
            cwd=PIPELINE, capture_output=True, text=True)
        check("dry-run:exit0", result.returncode == 0, result.stderr[:200])
        after = {p: p.stat().st_mtime for p in GEN.glob("*.json")}
        check("dry-run:no-writes", snapshot == after)

    # ---- dishes stay consistent with recipes ----
    for dish_id, d in dishes.items():
        for vid in d["variants"]:
            check(f"dish:{dish_id}:{vid}", any(r["id"] == vid for r in recipes))

    print()
    if failures:
        print(f"{len(failures)} FAILURE(S)")
        sys.exit(1)
    print("pipeline contract tests passed")


if __name__ == "__main__":
    main()
