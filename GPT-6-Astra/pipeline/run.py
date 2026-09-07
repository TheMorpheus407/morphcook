#!/usr/bin/env python3
"""Maintainer-only multi-agent recipe workflow. Never imported by the Flutter app.

An explicit runner bridges model names to a local provider CLI. It receives
--agent MODEL --stage STAGE --input FILE --output FILE --prompt FILE.
No shell interpolation, hardcoded model tiers or automatic corpus publication.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile

from corpus import ValidationError, indexed, read_json, rebuild_partitions, validate_assets, validate_recipe, write_json

ROOT = Path(__file__).resolve().parents[1]
PIPELINE = ROOT / "pipeline"
STAGES = ("generator", "flag-verifier", "nutrition", "copy-editor", "reviewer")


def local_path(raw):
    path = Path(raw).expanduser().resolve()
    if not path.is_relative_to(ROOT):
        raise ValidationError(f"All pipeline file paths must stay inside this project: {path}")
    return path


def digest(recipes):
    return hashlib.sha256(json.dumps(recipes, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode()).hexdigest()


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dish", help="Existing dish concept ID")
    parser.add_argument("--variants", default="classic,vegan", help="Comma-separated target variant briefs or diet IDs")
    parser.add_argument("--agent", default=os.environ.get("MORPHCOOK_AGENT"), help="Primary model/provider identifier; no model tier is assumed")
    parser.add_argument("--agent-verifier")
    parser.add_argument("--agent-nutrition")
    parser.add_argument("--agent-editor", "--agent-copy-editor", dest="agent_editor")
    parser.add_argument("--agent-reviewer")
    parser.add_argument("--runner", default=os.environ.get("MORPHCOOK_AGENT_RUNNER"), help="Explicit adapter executable and optional arguments (parsed with shlex; no shell)")
    parser.add_argument("--max-retries", type=int, default=3)
    parser.add_argument("--sample-size", type=int, default=5)
    parser.add_argument("--timeout", type=int, default=600, help="Per-stage adapter timeout in seconds")
    parser.add_argument("--output-dir", default=str(PIPELINE / "out"))
    parser.add_argument("--assets", default=str(ROOT / "app" / "assets"))
    parser.add_argument("--dry-run", action="store_true", help="Validate and print stage plan without invoking agents or writing anything")
    parser.add_argument("--validate", action="store_true", help="Validate all bundled assets, partition references and translations")
    parser.add_argument("--commit-reviewed", metavar="REVIEW_FORM", help="Commit a previously generated batch with a completed human review form")
    return parser.parse_args(argv)


def agent_models(args):
    return dict(zip(STAGES, [args.agent, args.agent_verifier or args.agent, args.agent_nutrition or args.agent,
                             args.agent_editor or args.agent, args.agent_reviewer or args.agent]))


def call_agent(runner, model, stage, payload, directory, timeout):
    input_path = directory / f"{stage}.input.json"
    output_path = directory / f"{stage}.output.json"
    write_json(input_path, payload)
    output_path.unlink(missing_ok=True)
    command = shlex.split(runner) + ["--agent", model, "--stage", stage, "--input", str(input_path),
                                    "--output", str(output_path), "--prompt", str(PIPELINE / "agents" / f"{stage}.md")]
    try:
        completed = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=timeout, check=False)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise ValidationError(f"{stage} adapter failed: {error}") from error
    if completed.returncode:
        raise ValidationError(f"{stage} adapter exited {completed.returncode}: {completed.stderr.strip()[:1000]}")
    if not output_path.exists():
        raise ValidationError(f"{stage} adapter did not write {output_path.name}")
    try:
        result = read_json(output_path)
    except (ValueError, OSError) as error:
        raise ValidationError(f"{stage} returned invalid JSON: {error}") from error
    if not isinstance(result, dict):
        raise ValidationError(f"{stage} output must be a JSON object")
    return result


def recipe_from(result):
    return result.get("recipe", result)


def approved(result, stage):
    if result.get("approved") is not True:
        raise ValidationError(f"{stage} rejected: {result.get('feedback', 'no approval or reason provided')}")


def run_variant(args, variant, models, context, batch, work):
    feedback = None
    errors = []
    for attempt in range(args.max_retries + 1):
        attempt_dir = work / f"attempt-{attempt + 1}"
        attempt_dir.mkdir()
        payload = {**context, "target_variant": variant, "feedback": feedback, "attempt": attempt + 1}
        try:
            recipe = recipe_from(call_agent(args.runner, models["generator"], "generator", payload, attempt_dir, args.timeout))
            if recipe.get("dish_id") != args.dish:
                raise ValidationError("Generator returned a different dish than the requested concept")
            if variant in {"classic", "vegetarian", "vegan", "keto", "halal"} and recipe.get("diet") != variant:
                raise ValidationError(f"Generator did not satisfy requested diet {variant}")
            validate_recipe(recipe, context["ingredient_dictionary"], context["ontology"], context["dishes_by_id"], context["existing_recipes"] + batch, PIPELINE / "schemas")
            approved(call_agent(args.runner, models["flag-verifier"], "flag-verifier", {**payload, "recipe": recipe}, attempt_dir, args.timeout), "flag-verifier")
            nutrition_result = call_agent(args.runner, models["nutrition"], "nutrition", {**payload, "recipe": recipe}, attempt_dir, args.timeout)
            if "recipe" in nutrition_result:
                updated = nutrition_result["recipe"]
                for immutable in ("id", "dish_id", "ingredients", "servings", "diet", "contains", "attributes", "effort", "steps"):
                    if updated.get(immutable) != recipe.get(immutable):
                        raise ValidationError(f"Nutrition stage changed protected field {immutable}")
                recipe = updated
            else:
                recipe["nutrition"] = nutrition_result["nutrition"]
                recipe["calories_per_serving"] = nutrition_result["calories_per_serving"]
                recipe["calorie_level"] = "light" if recipe["calories_per_serving"] <= 400 else "balanced" if recipe["calories_per_serving"] <= 600 else "hearty"
                recipe["nutrition_note"] = nutrition_result.get("nutrition_note", {"en": "Estimated per serving.", "de": "Pro Portion geschätzt."})
            edited = recipe_from(call_agent(args.runner, models["copy-editor"], "copy-editor", {**payload, "recipe": recipe}, attempt_dir, args.timeout))
            for immutable in ("id", "dish_id", "ingredients", "contains", "attributes", "nutrition", "calories_per_serving", "servings", "diet", "effort", "time_minutes"):
                if edited.get(immutable) != recipe.get(immutable):
                    raise ValidationError(f"Copy editor changed protected factual field: {immutable}")
            if [s.get("timer_seconds") for s in edited.get("steps", [])] != [s.get("timer_seconds") for s in recipe.get("steps", [])]:
                raise ValidationError("Copy editor changed step count or timers")
            recipe = edited
            validate_recipe(recipe, context["ingredient_dictionary"], context["ontology"], context["dishes_by_id"], context["existing_recipes"] + batch, PIPELINE / "schemas")
            approved(call_agent(args.runner, models["reviewer"], "reviewer", {**payload, "recipe": recipe}, attempt_dir, args.timeout), "reviewer")
            recipe["review_status"] = "pending-human-review"
            return recipe
        except (ValidationError, KeyError, TypeError) as error:
            feedback = str(error)
            errors.append({"attempt": attempt + 1, "feedback": feedback})
            write_json(attempt_dir / "rejection.json", errors[-1])
    raise ValidationError(f"{variant}: exhausted {args.max_retries + 1} attempts. Last feedback: {feedback}")


def commit_reviewed(args):
    form_path = local_path(args.commit_reviewed)
    form = read_json(form_path)
    batch_path = local_path(form_path.parent / form.get("batch_file", "recipes.pending.json"))
    batch = read_json(batch_path)
    if form.get("batch_sha256") != digest(batch):
        raise ValidationError("Review checksum differs from candidate batch; review the current batch again")
    if form.get("approved") is not True or not str(form.get("reviewed_by", "")).strip() or not str(form.get("reviewed_at", "")).strip():
        raise ValidationError("Human review form must explicitly set approved=true, reviewed_by and reviewed_at before commit")
    assets = local_path(args.assets)
    validate_assets(assets)
    recipes = read_json(assets / "recipes.json")
    dishes = read_json(assets / "dishes.json")
    ingredients = indexed(read_json(assets / "ingredients.json"), "ingredients")
    ontology = read_json(assets / "ontology.json")
    dish_map = indexed(dishes, "dishes")
    for recipe in batch:
        validate_recipe(recipe, ingredients, ontology, dish_map, recipes, PIPELINE / "schemas")
        recipe["review_status"] = "human-spot-checked"
        recipe["review"] = {"reviewed_by": form["reviewed_by"], "reviewed_at": form["reviewed_at"], "scope": "batch-spot-check", "source_batch_sha256": form["batch_sha256"]}
        recipes.append(recipe)
        dish_map[recipe["dish_id"]]["variants"].append(recipe["id"])
    # Stage and validate every derived asset before replacing the source files.
    with tempfile.TemporaryDirectory(prefix=".commit-", dir=PIPELINE) as directory:
        staging = Path(directory)
        for name in ("ingredients.json", "ontology.json", "ingredient-guide.json", "faqs.json"):
            write_json(staging / name, read_json(assets / name))
        write_json(staging / "recipes.json", recipes)
        write_json(staging / "dishes.json", dishes)
        rebuild_partitions(staging)
        validate_assets(staging)
        changed = [p for p in staging.glob("*.json") if p.name not in {"ingredients.json", "ontology.json", "ingredient-guide.json", "faqs.json"}]
        previous = {p.name: (assets / p.name).read_bytes() if (assets / p.name).exists() else None for p in changed}
        try:
            for path in changed:
                os.replace(path, assets / path.name)
        except OSError:
            for name, contents in previous.items():
                if contents is None:
                    (assets / name).unlink(missing_ok=True)
                else:
                    (assets / name).write_bytes(contents)
            raise
    return {"committed": len(batch), "recipes": len(recipes), "reviewed_by": form["reviewed_by"]}


def main(argv=None):
    args = parse_args(argv)
    try:
        assets = local_path(args.assets)
        if args.max_retries < 0 or args.sample_size < 1 or args.timeout < 1:
            raise ValidationError("Retries must be non-negative; sample size and timeout must be positive")
        if args.commit_reviewed:
            if args.dry_run:
                raise ValidationError("--dry-run cannot be combined with --commit-reviewed")
            print(json.dumps(commit_reviewed(args), ensure_ascii=False, indent=2))
            return 0
        summary = validate_assets(assets)
        if args.validate:
            print(json.dumps({"valid": True, **summary}, indent=2))
            return 0
        if not args.agent or not args.dish:
            raise ValidationError("Generation requires --dish and --agent (or MORPHCOOK_AGENT)")
        dishes = indexed(read_json(assets / "dishes.json"), "dishes")
        if args.dish not in dishes:
            raise ValidationError(f"Unknown dish {args.dish!r}; add an authored dish concept first")
        variants = [v.strip() for v in args.variants.split(",") if v.strip()]
        if not variants or len(set(variants)) != len(variants):
            raise ValidationError("Provide at least one distinct target variant")
        models = agent_models(args)
        plan = {"dish": args.dish, "variants": variants, "max_retries": args.max_retries,
                "stages": [{"stage": s, "agent": models[s], "prompt": str(PIPELINE / "agents" / f"{s}.md")} for s in STAGES],
                "human_review_required": True, "corpus": summary}
        if args.dry_run:
            print(json.dumps({"dry_run": True, **plan}, ensure_ascii=False, indent=2))
            return 0
        if not args.runner:
            raise ValidationError("Provide --runner or MORPHCOOK_AGENT_RUNNER for your local model CLI adapter. See pipeline/agents/ADAPTER.md")
        output = local_path(args.output_dir)
        output.mkdir(parents=True, exist_ok=True)
        if (output / "recipes.pending.json").exists():
            raise ValidationError("Output already contains a pending batch; choose a new --output-dir to preserve it")
        context = {"dish": dishes[args.dish], "dishes_by_id": dishes, "ontology": read_json(assets / "ontology.json"),
                   "ingredient_dictionary": indexed(read_json(assets / "ingredients.json"), "ingredients"),
                   "existing_recipes": read_json(assets / "recipes.json"), "languages": ["en", "de"],
                   "recipe_schema": read_json(PIPELINE / "schemas" / "recipe.schema.json")}
        batch = []
        write_json(output / "plan.json", plan)
        with tempfile.TemporaryDirectory(prefix=".agents-", dir=output) as directory:
            work = Path(directory)
            for index, variant in enumerate(variants):
                variant_work = work / str(index)
                variant_work.mkdir()
                recipe = run_variant(args, variant, models, context, batch, variant_work)
                batch.append(recipe)
                print(f"Prepared {recipe['id']} ({index + 1}/{len(variants)}); human review pending.", file=sys.stderr)
        write_json(output / "recipes.pending.json", batch)
        # Deterministic evenly spaced sample; no publication happens here.
        count = min(args.sample_size, len(batch))
        sample_ids = sorted({round(i * (len(batch) - 1) / max(1, count - 1)) for i in range(count)})
        write_json(output / "review-sample.json", [batch[i] for i in sample_ids])
        write_json(output / "review-form.json", {"batch_file": "recipes.pending.json", "batch_sha256": digest(batch),
                   "sample_file": "review-sample.json", "sample_recipe_ids": [batch[i]["id"] for i in sample_ids],
                   "approved": False, "reviewed_by": "", "reviewed_at": "", "notes": "Check sourcing, allergens, actual cooking steps, quantities, nutritional estimates and bilingual meaning. No automatic human-review claim."})
        print(json.dumps({"prepared": len(batch), "review_form": str(output / "review-form.json"), "committed": False}, indent=2))
        return 0
    except (ValidationError, ValueError, OSError, KeyError) as error:
        print(f"MorphCook pipeline: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
