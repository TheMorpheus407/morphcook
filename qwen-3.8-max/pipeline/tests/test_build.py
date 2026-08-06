#!/usr/bin/env python3
"""Pipeline tests: rebuild the corpus and re-check the quality gates.

Run from anywhere:  python3 pipeline/tests/test_build.py
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PIPELINE = os.path.dirname(HERE)
ROOT = os.path.dirname(PIPELINE)
ASSETS = os.path.join(ROOT, "app", "assets")


def test_build_runs_clean():
    result = subprocess.run(
        [sys.executable, os.path.join(PIPELINE, "corpus", "build.py")],
        capture_output=True, text=True,
    )
    assert result.returncode == 0, result.stderr


def test_assets_exist():
    for name in [
        "partition-manifest.json", "core-recipes.json",
        "extended-recipes.json", "cuisine-italian.json",
        "cuisine-asian.json", "cuisine-middle-eastern.json",
        "dishes.json", "ontology.json", "ingredients.json",
        "ingredient-guide.json", "faqs.json",
    ]:
        path = os.path.join(ASSETS, name)
        assert os.path.exists(path), f"missing asset {name}"
        with open(path, encoding="utf-8") as fh:
            json.load(fh)  # every asset parses


def test_exactly_once_primary():
    with open(os.path.join(ASSETS, "core-recipes.json"), encoding="utf-8") as fh:
        core = json.load(fh)
    with open(os.path.join(ASSETS, "extended-recipes.json"), encoding="utf-8") as fh:
        extended = json.load(fh)
    core_ids = {r["id"] for r in core["recipes"]}
    extended_ids = {r["id"] for r in extended["recipes"]}
    assert not core_ids & extended_ids, "recipe in two primary partitions"


def test_bilingual_completeness():
    with open(os.path.join(ASSETS, "core-recipes.json"), encoding="utf-8") as fh:
        core = json.load(fh)
    with open(os.path.join(ASSETS, "extended-recipes.json"), encoding="utf-8") as fh:
        extended = json.load(fh)
    for recipe in core["recipes"] + extended["recipes"]:
        for field in ("title", "blurb"):
            if field in recipe:
                assert recipe[field].get("en"), f'{recipe["id"]}: missing en {field}'
                assert recipe[field].get("de"), f'{recipe["id"]}: missing de {field}'
        for step in recipe["steps"]:
            assert step["text"].get("en"), f'{recipe["id"]}: step missing en'
            assert step["text"].get("de"), f'{recipe["id"]}: step missing de'


if __name__ == "__main__":
    test_build_runs_clean()
    test_assets_exist()
    test_exactly_once_primary()
    test_bilingual_completeness()
    print("pipeline tests passed")
