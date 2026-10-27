from __future__ import annotations

import argparse
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from pipeline.assets import AssetBuilder, write_json_files
from pipeline.errors import PipelineError
from pipeline.paths import resolve_assets_dir


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate and deterministically rebuild recipe partitions, recipes.json, and search-index.json."
    )
    parser.add_argument(
        "--assets-dir",
        help="Corpus assets directory (default: MORPHCOOK_ASSETS_DIR or app/assets).",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        assets_dir = resolve_assets_dir(args.assets_dir)
        builder = AssetBuilder.load(assets_dir)
        result = builder.build()
        written = write_json_files(assets_dir, result.files)
    except PipelineError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    print(f"Validated {len(result.recipes)} recipes; wrote {len(written)} changed file(s) in {assets_dir}.")
    for path in written:
        print(path.relative_to(Path.cwd()) if path.is_relative_to(Path.cwd()) else path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
