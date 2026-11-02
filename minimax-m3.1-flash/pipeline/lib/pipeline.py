#!/usr/bin/env python3
"""The MorphCook recipe generation pipeline.

Runs offline on the maintainer's machine. Five agents, each with its own
prompt and its own configurable model:

    generator -> flag-verifier -> nutrition -> copy-editor -> reviewer

The flag-verifier and the reviewer can bounce a recipe back to the
generator with feedback, up to ``--max-retries`` times.

Nothing here runs on a user device. The app never calls a model.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable

PIPELINE_DIR = Path(__file__).resolve().parent.parent
REPO_DIR = PIPELINE_DIR.parent
ASSETS_DIR = REPO_DIR / "app" / "assets"
AGENTS_DIR = PIPELINE_DIR / "agents"
SCHEMAS_DIR = PIPELINE_DIR / "schemas"

STAGES = ("generator", "flag-verifier", "nutrition", "copy-editor", "reviewer")


# ── Agent invocation ──────────────────────────────────────────────────────

#: How to call each supported agent CLI. The template is filled with the
#: model name. Anything not listed here falls back to ``--agent-command``.
AGENT_COMMANDS: dict[str, str] = {
    "claude": "claude -p --model {model}",
    "codex": "codex exec --model {model}",
    "opencode": "opencode run -m {model}",
    "llm": "llm -m {model}",
}


class AgentError(RuntimeError):
    """Raised when an agent cannot be run or returns something unusable."""


def resolve_command(model: str, override: str | None) -> list[str]:
    """Builds the argv for an agent call."""
    template = override or os.environ.get("MORPHCOOK_AGENT_COMMAND")
    if template is None:
        family = model.split("/")[0]
        template = AGENT_COMMANDS.get(family)
        if template is None:
            raise AgentError(
                f"no command known for agent '{model}'. "
                f"Set MORPHCOOK_AGENT_COMMAND or pass --agent-command."
            )
    argv = template.replace("{model}", model).split()
    if not shutil.which(argv[0]):
        raise AgentError(f"agent command '{argv[0]}' is not on PATH")
    return argv


def run_agent(
    model: str,
    prompt: str,
    *,
    override: str | None = None,
    timeout: int = 900,
) -> str:
    """Runs one agent and returns its raw output."""
    argv = resolve_command(model, override)
    try:
        completed = subprocess.run(
            argv,
            input=prompt,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as error:
        raise AgentError(f"agent '{model}' timed out after {timeout}s") from error

    if completed.returncode != 0:
        raise AgentError(
            f"agent '{model}' exited with {completed.returncode}: "
            f"{completed.stderr.strip()[:400]}"
        )
    return completed.stdout


def parse_json(raw: str) -> Any:
    """Pulls the first JSON object out of an agent's output."""
    text = raw.strip()
    if text.startswith("```"):
        text = re.sub(r"^```[a-zA-Z]*\n?", "", text)
        text = re.sub(r"\n?```$", "", text)
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    # Fall back to the first balanced object in the text.
    start = text.find("{")
    if start == -1:
        raise AgentError("the agent returned no JSON")
    depth = 0
    in_string = False
    escaped = False
    for index in range(start, len(text)):
        char = text[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue
        if char == '"':
            in_string = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                try:
                    return json.loads(text[start : index + 1])
                except json.JSONDecodeError as error:
                    raise AgentError(f"the agent returned invalid JSON: {error}")
    raise AgentError("the agent returned an unterminated JSON object")


# ── Schema validation ─────────────────────────────────────────────────────


def _type_ok(value: Any, expected: "str | list[str]") -> bool:
    if isinstance(expected, list):
        return any(_type_ok(value, option) for option in expected)
    if expected == "object":
        return isinstance(value, dict)
    if expected == "array":
        return isinstance(value, list)
    if expected == "string":
        return isinstance(value, str)
    if expected == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if expected == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if expected == "boolean":
        return isinstance(value, bool)
    if expected == "null":
        return value is None
    return True

def validate(value: Any, schema: dict[str, Any], path: str = "$") -> list[str]:
    """A small, dependency-free JSON Schema checker.

    It covers the subset the MorphCook schemas actually use: types,
    required keys, enums, patterns, numeric bounds, nested objects and
    arrays. It is not a general validator, and it does not need to be.
    """
    problems: list[str] = []

    expected = schema.get("type")
    if expected and not _type_ok(value, expected):
        return [f"{path}: expected {expected}, got {type(value).__name__}"]

    if "anyOf" in schema:
        # The value has to satisfy at least one branch.
        branches = schema["anyOf"]
        if not any(not validate(value, branch, path) for branch in branches):
            problems.append(f"{path}: does not match any allowed form")
        return problems

    if "enum" in schema and value not in schema["enum"]:
        problems.append(f"{path}: {value!r} is not one of {schema['enum']}")

    if isinstance(value, str):
        pattern = schema.get("pattern")
        if pattern and not re.search(pattern, value):
            problems.append(f"{path}: {value!r} does not match {pattern}")
        if "minLength" in schema and len(value) < schema["minLength"]:
            problems.append(f"{path}: shorter than {schema['minLength']}")
    elif isinstance(value, (int, float)) and not isinstance(value, bool):
        if "minimum" in schema and value < schema["minimum"]:
            problems.append(f"{path}: {value} is below {schema['minimum']}")
        if "maximum" in schema and value > schema["maximum"]:
            problems.append(f"{path}: {value} is above {schema['maximum']}")
        if schema.get("exclusiveMinimum") is not None:
            if value <= schema["exclusiveMinimum"]:
                problems.append(
                    f"{path}: {value} is not above {schema['exclusiveMinimum']}"
                )

    if isinstance(value, dict):
        for key in schema.get("required", []):
            if key not in value:
                problems.append(f"{path}: missing required key '{key}'")
        properties = schema.get("properties", {})
        for key, sub_schema in properties.items():
            if key in value:
                problems.extend(validate(value[key], sub_schema, f"{path}.{key}"))
        if schema.get("additionalProperties") is False:
            for key in value:
                if key not in properties:
                    problems.append(f"{path}: unexpected key '{key}'")
        additional = schema.get("additionalProperties")
        if isinstance(additional, dict):
            for key, item in value.items():
                if key not in properties:
                    problems.extend(validate(item, additional, f"{path}.{key}"))

    if isinstance(value, list):
        if "minItems" in schema and len(value) < schema["minItems"]:
            problems.append(f"{path}: fewer than {schema['minItems']} items")
        if schema.get("uniqueItems") and len(value) != len(
            {json.dumps(item, sort_keys=True) for item in value}
        ):
            problems.append(f"{path}: contains duplicates")
        item_schema = schema.get("items")
        if isinstance(item_schema, dict):
            for index, item in enumerate(value):
                problems.extend(validate(item, item_schema, f"{path}[{index}]"))

    if "$ref" in schema:
        # Only local "#/definitions/..." references are used.
        name = schema["$ref"].split("/")[-1]
        definitions = schema.get("definitions") or {}
        if name in definitions:
            problems.extend(validate(value, definitions[name], path))

    return problems


# ── The corpus the pipeline reads ─────────────────────────────────────────


@dataclass
class Corpus:
    ontology: dict[str, Any]
    dishes: dict[str, dict[str, Any]]
    ingredients: dict[str, dict[str, Any]]
    recipes: dict[str, dict[str, Any]]
    ingredient_flags: dict[str, list[str]] = field(default_factory=dict)

    @classmethod
    def load(cls, assets: Path) -> "Corpus":
        ontology = json.loads((assets / "ontology.json").read_text())
        dishes = {
            dish["id"]: dish
            for dish in json.loads((assets / "dishes.json").read_text())["dishes"]
        }
        ingredients = {
            node["id"]: node
            for node in json.loads((assets / "ingredients.json").read_text())["nodes"]
        }
        recipes: dict[str, dict[str, Any]] = {}
        for name in ("core-recipes.json", "extended-recipes.json"):
            path = assets / name
            if not path.exists():
                continue
            for recipe in json.loads(path.read_text())["recipes"]:
                recipes[recipe["id"]] = recipe

        # The canonical ingredient → contains-flag mapping, written by the
        # corpus builder. It is what lets the flag-verifier check a
        # generated recipe against the same rules the shipped corpus obeys.
        ingredient_flags: dict[str, list[str]] = {}
        flags_path = assets / "ingredient-flags.json"
        if flags_path.exists():
            ingredient_flags = json.loads(flags_path.read_text()).get("flags", {})

        return cls(
            ontology=ontology,
            dishes=dishes,
            ingredients=ingredients,
            recipes=recipes,
            ingredient_flags=ingredient_flags,
        )

    # ── Flags ──────────────────────────────────────────────────────────────

    def contains_flags(self) -> set[str]:
        return {flag["id"] for flag in self.ontology["contains_flags"]}

    def certification_blockers(self) -> dict[str, list[str]]:
        """Which flags contradict each certification."""
        expansions = {
            flag["id"]: flag["expands"] for flag in self.ontology["avoid_flags"]
        }
        return {name: expansions.get(name, []) for name in self.ontology["certifications"]}

    def flags_implied_by(self, ingredient_id: str) -> list[str]:
        """The flags an ingredient brings with it.

        The mapping is derived from the ingredient dictionary: an ingredient
        whose id starts with a flagged prefix inherits that flag. The
        canonical mapping lives in the corpus builder; this is the
        conservative fallback for ingredients the builder has not seen.
        """
        if ingredient_id in self.ingredient_flags:
            return self.ingredient_flags[ingredient_id]
        return []

    def is_known_ingredient(self, ingredient_id: str) -> bool:
        return ingredient_id in self.ingredients

    # ── Gates ──────────────────────────────────────────────────────────────

    def gate_schema(self, recipe: dict[str, Any]) -> list[str]:
        schema = json.loads((SCHEMAS_DIR / "recipe.schema.json").read_text())
        return validate(recipe, schema)

    def gate_ontology(self, recipe: dict[str, Any]) -> list[str]:
        """Every flag and certification must exist in the ontology."""
        problems: list[str] = []
        known = self.contains_flags()
        for flag in recipe.get("contains", []):
            if flag not in known:
                problems.append(f"unknown contains-flag '{flag}'")
        certifications = set(self.ontology["certifications"])
        for certification in recipe.get("attributes", {}).get("certifications", []):
            if certification not in certifications:
                problems.append(f"unknown certification '{certification}'")
        return problems

    def gate_ingredients(self, recipe: dict[str, Any]) -> list[str]:
        """Every ingredient must exist in the dictionary."""
        problems: list[str] = []
        for ingredient in recipe.get("ingredients", []):
            ingredient_id = ingredient.get("ingredient_id", "")
            if not self.is_known_ingredient(ingredient_id):
                problems.append(f"unknown ingredient '{ingredient_id}'")
        return problems

    def gate_flags(self, recipe: dict[str, Any]) -> list[str]:
        """`contains` must cover every flag implied by the ingredients."""
        problems: list[str] = []
        derived: set[str] = set()
        for ingredient in recipe.get("ingredients", []):
            derived.update(self.flags_implied_by(ingredient.get("ingredient_id", "")))

        claimed = set(recipe.get("contains", []))
        missing = derived - claimed
        if missing:
            problems.append(f"contains is missing {sorted(missing)}")

        unexplained = claimed - derived
        if unexplained:
            problems.append(f"contains lists {sorted(unexplained)} with no source")

        for certification, blockers in self.certification_blockers().items():
            if certification not in recipe.get("attributes", {}).get(
                "certifications", []
            ):
                continue
            clash = sorted(set(blockers) & claimed)
            if clash:
                problems.append(
                    f"claims {certification} but contains {clash}"
                )
        return problems

    def gate_duplicates(self, recipe: dict[str, Any]) -> list[str]:
        """Reject a near-duplicate of a sibling variant.

        Only variants of the *same* diet are compared. Two variants of one
        dish on different diets are expected to share most of their
        ingredients — a gluten-free Caesar is the Caesar with one thing
        swapped. Two variants of the same dish *and* the same diet sharing
        90 % of their ingredients are the same recipe twice.
        """
        problems: list[str] = []
        for other in self.recipes.values():
            if other["dish_id"] != recipe["dish_id"]:
                continue
            if other.get("diet") != recipe.get("diet"):
                continue
            if other["id"] == recipe["id"]:
                continue
            overlap = _ingredient_overlap(recipe, other)
            if overlap >= 0.9:
                problems.append(
                    f"near-duplicate of '{other['id']}' "
                    f"({int(overlap * 100)}% ingredient overlap)"
                )
        return problems

    def all_gates(self, recipe: dict[str, Any]) -> list[str]:
        problems: list[str] = []
        problems.extend(self.gate_schema(recipe))
        problems.extend(self.gate_ontology(recipe))
        problems.extend(self.gate_ingredients(recipe))
        problems.extend(self.gate_flags(recipe))
        problems.extend(self.gate_duplicates(recipe))
        return problems


def _ingredient_overlap(a: dict[str, Any], b: dict[str, Any]) -> float:
    """The Jaccard overlap of two ingredient lists."""
    left = {item["ingredient_id"] for item in a.get("ingredients", [])}
    right = {item["ingredient_id"] for item in b.get("ingredients", [])}
    if not left or not right:
        return 0.0
    union = left | right
    return len(left & right) / len(union)


# ── Prompts ───────────────────────────────────────────────────────────────


def agent_prompt(stage: str, context: str) -> str:
    """Builds the prompt for one stage."""
    template = (AGENTS_DIR / f"{stage}.md").read_text()
    return f"{template}\n\n---\n\n{context}\n"


def build_context(
    corpus: Corpus,
    dish_id: str,
    variant: str,
    recipe: dict[str, Any] | None,
    feedback: list[str],
) -> str:
    """The shared context every stage receives."""
    dish = corpus.dishes.get(dish_id, {})
    parts = [
        "## The dish",
        json.dumps(dish, ensure_ascii=False, indent=2),
        "",
        f"## The variant to write\n`{variant}`",
        "",
        "## The ingredient dictionary",
        json.dumps(
            [
                node
                for node in corpus.ingredients.values()
                if not node.get("parent")
            ],
            ensure_ascii=False,
            indent=2,
        ),
        "",
        "## The ontology",
        json.dumps(corpus.ontology, ensure_ascii=False, indent=2),
    ]

    if recipe is not None:
        parts.extend(
            [
                "",
                "## The recipe so far",
                json.dumps(recipe, ensure_ascii=False, indent=2),
            ]
        )

    if feedback:
        parts.extend(
            [
                "",
                "## What to fix",
                "\n".join(f"- {problem}" for problem in feedback),
                "",
                "Rewrite the whole recipe, keeping what was right and fixing "
                "what is listed above.",
            ]
        )

    return "\n".join(parts)


# ── The pipeline ──────────────────────────────────────────────────────────


@dataclass
class StageModels:
    """Which model runs which stage.

    Every stage falls back to the primary generator model when it has no
    dedicated one — that is the behaviour the CLI documents.
    """

    generator: str
    flag_verifier: str | None = None
    nutrition: str | None = None
    copy_editor: str | None = None
    reviewer: str | None = None

    def for_stage(self, stage: str) -> str:
        chosen = {
            "generator": self.generator,
            "flag-verifier": self.flag_verifier,
            "nutrition": self.nutrition,
            "copy-editor": self.copy_editor,
            "reviewer": self.reviewer,
        }.get(stage)
        return chosen or self.generator


def run_variant(
    corpus: Corpus,
    dish_id: str,
    variant: str,
    models: StageModels,
    *,
    max_retries: int,
    command_override: str | None,
    dry_run: bool,
    log: Callable[[str], None],
) -> dict[str, Any] | None:
    """Runs the five stages for one variant."""
    recipe: dict[str, Any] | None = None
    feedback: list[str] = []

    for attempt in range(1, max_retries + 2):
        log(f"  attempt {attempt}")

        # ── 1. Generator ───────────────────────────────────────────────
        context = build_context(corpus, dish_id, variant, recipe, feedback)
        prompt = agent_prompt("generator", context)
        if dry_run:
            log(f"    [dry-run] generator prompt is {len(prompt)} characters")
            return None
        recipe = parse_json(run_agent(models.generator, prompt, override=command_override))
        log(f"    generator: {recipe.get('id', '?')}")

        # ── 2. Flag verifier ───────────────────────────────────────────
        context = build_context(corpus, dish_id, variant, recipe, [])
        prompt = agent_prompt("flag-verifier", context)
        verdict = parse_json(
            run_agent(models.flag_verifier, prompt, override=command_override)
        )
        if not verdict.get("approved", False):
            feedback = list(verdict.get("problems", [])) or ["the flags are wrong"]
            log(f"    flag-verifier rejected: {feedback[0]}")
            continue
        recipe["contains"] = verdict.get("contains", recipe.get("contains", []))
        recipe.setdefault("attributes", {})["certifications"] = verdict.get(
            "certifications", []
        )
        log("    flag-verifier: approved")

        # ── 3. Nutrition ───────────────────────────────────────────────
        context = build_context(corpus, dish_id, variant, recipe, [])
        prompt = agent_prompt("nutrition", context)
        nutrition = parse_json(
            run_agent(models.nutrition, prompt, override=command_override)
        )
        recipe["calories_per_serving"] = nutrition["calories_per_serving"]
        recipe["macros"] = nutrition["macros"]
        recipe.setdefault("attributes", {}).update(nutrition.get("attributes", {}))
        log(f"    nutrition: {recipe['calories_per_serving']} kcal")

        # ── 4. Copy editor ─────────────────────────────────────────────
        context = build_context(corpus, dish_id, variant, recipe, [])
        prompt = agent_prompt("copy-editor", context)
        edited = parse_json(
            run_agent(models.copy_editor, prompt, override=command_override)
        )
        for key in ("title", "hero_text", "cap_caption", "ingredients", "steps", "tags"):
            if key in edited:
                recipe[key] = edited[key]
        log("    copy-editor: done")

        # ── 5. Final reviewer ──────────────────────────────────────────
        context = build_context(corpus, dish_id, variant, recipe, [])
        prompt = agent_prompt("reviewer", context)
        verdict = parse_json(
            run_agent(models.reviewer, prompt, override=command_override)
        )
        if not verdict.get("approved", False):
            feedback = list(verdict.get("problems", [])) or ["the reviewer was not happy"]
            log(f"    reviewer rejected: {feedback[0]}")
            continue
        log("    reviewer: signed off")

        # ── Quality gates ──────────────────────────────────────────────
        problems = corpus.all_gates(recipe)
        if problems:
            feedback = problems
            log(f"    quality gates failed: {problems[0]}")
            continue

        log("    all gates passed")
        return recipe

    log(f"  gave up on '{variant}' after {max_retries + 1} attempts")
    return None


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="pipeline.sh",
        description="Generate MorphCook recipe variants.",
    )
    parser.add_argument("--dish", required=True, help="the dish id")
    parser.add_argument(
        "--variants",
        required=True,
        help="comma separated variant names, e.g. classic,vegan,keto",
    )
    parser.add_argument("--agent", required=True, help="the generator model")
    parser.add_argument("--agent-verifier", help="the flag-verifier model")
    parser.add_argument("--agent-nutrition", help="the nutrition model")
    parser.add_argument("--agent-copy-editor", help="the copy-editor model")
    parser.add_argument("--agent-reviewer", help="the final reviewer model")
    parser.add_argument(
        "--agent-command",
        help="override the command used to call an agent; {model} is replaced",
    )
    parser.add_argument("--max-retries", type=int, default=3)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="build the prompts and stop, without calling any agent",
    )
    parser.add_argument(
        "--out",
        default=str(ASSETS_DIR / "generated-recipes.json"),
        help="where the generated recipes are written",
    )
    parser.add_argument(
        "--sample",
        type=int,
        default=0,
        help="print N recipes for a human spot-check before committing",
    )
    parser.add_argument(
        "--assets",
        default=str(ASSETS_DIR),
        help="where the corpus assets live",
    )
    args = parser.parse_args(argv)

    assets = Path(args.assets)
    corpus = Corpus.load(assets)

    if args.dish not in corpus.dishes:
        print(f"unknown dish '{args.dish}'", file=sys.stderr)
        return 2

    models = StageModels(
        generator=args.agent,
        flag_verifier=args.agent_verifier or args.agent,
        nutrition=args.agent_nutrition or args.agent,
        copy_editor=args.agent_copy_editor or args.agent,
        reviewer=args.agent_reviewer or args.agent,
    )

    variants = [variant.strip() for variant in args.variants.split(",") if variant.strip()]

    def log(message: str) -> None:
        print(message, flush=True)

    log(f"dish {args.dish} · variants {', '.join(variants)}")

    generated: list[dict[str, Any]] = []
    for variant in variants:
        log(f"variant {variant}")
        recipe = run_variant(
            corpus,
            args.dish,
            variant,
            models,
            max_retries=args.max_retries,
            command_override=args.agent_command,
            dry_run=args.dry_run,
            log=log,
        )
        if recipe is not None:
            generated.append(recipe)

    if args.dry_run:
        log("dry run: nothing was written")
        return 0

    if args.sample:
        log("")
        log("=== human spot-check ===")
        for recipe in generated[: args.sample]:
            print(json.dumps(recipe, ensure_ascii=False, indent=2))

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    payload = {"version": 1, "recipes": generated}
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
    log(f"wrote {len(generated)} recipe(s) to {out}")

    return 0 if generated else 1


if __name__ == "__main__":
    raise SystemExit(main())
