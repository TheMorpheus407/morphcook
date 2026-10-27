from __future__ import annotations

import argparse
import copy
import json
import os
import re
import sys
from typing import Any, Callable

from .agents import AgentRunner
from .assets import AssetBuilder, write_json_files
from .errors import CommitCancelled, ConfigurationError, PipelineError
from .generation import RecipeGenerationPipeline, emit_spot_check
from .paths import REPO_ROOT, resolve_assets_dir


_ID = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
_STAGE_OPTIONS = {
    "verifier": "--agent-verifier",
    "nutrition": "--agent-nutrition",
    "copy-editor": "--agent-copy-editor",
    "reviewer": "--agent-reviewer",
}


def _non_negative_int(value: str) -> int:
    try:
        parsed = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("must be an integer") from exc
    if parsed < 0:
        raise argparse.ArgumentTypeError("must be zero or greater")
    return parsed


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="pipeline.sh",
        description="Run the offline MorphCook recipe maintainer pipeline.",
        epilog=(
            "Agent values are executable command prefixes, parsed without a shell. Each command receives "
            "{protocol_version,stage,prompt,payload} as JSON on stdin and must return one stage-appropriate "
            "JSON object on stdout. Stage agents default to --agent. MORPHCOOK_ASSETS_DIR overrides app/assets; "
            "MORPHCOOK_SPOT_CHECK_N sets the sample size (default 3); MORPHCOOK_AGENT_TIMEOUT sets seconds."
        ),
    )
    parser.add_argument("--dish", required=True, help="Existing dish ID from dishes.json")
    parser.add_argument("--variants", required=True, help="Comma-separated variant slugs")
    parser.add_argument("--agent", help="Primary maintainer agent command")
    for option in _STAGE_OPTIONS.values():
        parser.add_argument(option, help=f"Override the primary agent for {option.removeprefix('--agent-') or 'verifier'}")
    parser.add_argument("--max-retries", type=_non_negative_int, default=3, help="Retries after the initial attempt")
    parser.add_argument("--dry-run", action="store_true", help="Print the resolved plan without agents or writes")
    args = parser.parse_args(argv)

    if not _ID.fullmatch(args.dish):
        parser.error("--dish must be a lowercase slug such as 'doener'")
    raw_variants = args.variants.split(",")
    if any(not item.strip() for item in raw_variants):
        parser.error("--variants must be a comma list without empty entries")
    variants = [item.strip() for item in raw_variants]
    invalid = [item for item in variants if not _ID.fullmatch(item)]
    if invalid:
        parser.error(f"invalid variant slug(s): {', '.join(invalid)}")
    if len(set(variants)) != len(variants):
        parser.error("--variants must not contain duplicates")
    args.variants = variants
    if not args.dry_run and not args.agent:
        parser.error("--agent is required unless --dry-run is used")
    return args


def resolve_agents(args: argparse.Namespace) -> dict[str, str]:
    agents = {"generator": args.agent}
    for stage, option in _STAGE_OPTIONS.items():
        value = getattr(args, option.removeprefix("--").replace("-", "_"))
        agents[stage] = value or args.agent
    return agents


def _environment_number(name: str, default: float, integer: bool = False) -> float:
    raw = os.environ.get(name)
    if raw is None:
        return default
    try:
        value = int(raw) if integer else float(raw)
    except ValueError as exc:
        raise ConfigurationError(f"{name} must be {'an integer' if integer else 'a number'}") from exc
    if value < 0 or (name == "MORPHCOOK_AGENT_TIMEOUT" and value == 0):
        raise ConfigurationError(f"{name} must be {'positive' if name == 'MORPHCOOK_AGENT_TIMEOUT' else 'zero or greater'}")
    return value


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    agents = resolve_agents(args)
    assets_dir = resolve_assets_dir()
    if args.dry_run:
        plan = {
            "dry_run": True,
            "dish": args.dish,
            "variants": args.variants,
            "recipe_ids": [f"{args.dish}-{variant}" for variant in args.variants],
            "agents": agents,
            "max_retries": args.max_retries,
            "stages": ["generator", "verifier", "nutrition", "copy-editor", "reviewer"],
            "assets_dir": str(assets_dir),
            "would_write": False,
        }
        print(json.dumps(plan, ensure_ascii=False, indent=2, sort_keys=True))
        return 0

    try:
        timeout = _environment_number("MORPHCOOK_AGENT_TIMEOUT", 300.0)
        sample_size = int(_environment_number("MORPHCOOK_SPOT_CHECK_N", 3, integer=True))
        builder = AssetBuilder.load(assets_dir)
        pipeline = RecipeGenerationPipeline(
            runner=AgentRunner(cwd=REPO_ROOT, timeout_seconds=timeout),
            agents=agents,
            validator=builder.validator,
            dishes=builder.dishes,
            existing_recipes=builder.recipes,
            max_retries=args.max_retries,
            logger=lambda message: print(message, file=sys.stderr),
        )
        accepted = pipeline.generate_all(args.dish, args.variants)
        emit_spot_check(accepted, sample_size)
        print(f"\nNo corpus files have been written. Destination: {assets_dir}")
        try:
            answer = input("Type 'commit' after reviewing the sample; anything else cancels: ")
        except EOFError:
            answer = ""
        if answer.strip().casefold() != "commit":
            raise CommitCancelled("Commit cancelled; no corpus files were written.")

        updated_dishes = copy.deepcopy(builder.dishes)
        dish = next(item for item in updated_dishes["dishes"] if item["id"] == args.dish)
        for recipe in accepted:
            if recipe["id"] not in dish["variant_ids"]:
                dish["variant_ids"].append(recipe["id"])
        result = builder.build(accepted, dishes=updated_dishes)
        written = write_json_files(assets_dir, result.files)
    except PipelineError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(f"Committed {len(accepted)} recipe(s); wrote {len(written)} changed file(s).")
    for path in written:
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
