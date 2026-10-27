from __future__ import annotations

import os
from pathlib import Path

from .errors import ConfigurationError


PIPELINE_ROOT = Path(__file__).resolve().parent
REPO_ROOT = PIPELINE_ROOT.parent


def resolve_assets_dir(value: str | os.PathLike[str] | None = None) -> Path:
    configured = value if value is not None else os.environ.get("MORPHCOOK_ASSETS_DIR")
    path = Path(configured) if configured else REPO_ROOT / "app" / "assets"
    if not path.is_absolute():
        path = REPO_ROOT / path
    return path.resolve()


def ensure_within_repo(path: Path) -> Path:
    resolved = path.resolve()
    try:
        resolved.relative_to(REPO_ROOT)
    except ValueError as exc:
        raise ConfigurationError(f"Refusing to access corpus path outside the repository: {resolved}") from exc
    return resolved
