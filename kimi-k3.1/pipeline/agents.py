from __future__ import annotations

import json
import shlex
import shutil
import subprocess
from pathlib import Path
from typing import Any

from .errors import AgentConfigurationError, AgentProtocolError


STAGE_PROMPTS = {
    "generator": "generator.md",
    "verifier": "flag-verifier.md",
    "nutrition": "nutrition.md",
    "copy-editor": "copy-editor.md",
    "reviewer": "reviewer.md",
}

STAGE_OPTIONS = {
    "generator": "--agent",
    "verifier": "--agent-verifier",
    "nutrition": "--agent-nutrition",
    "copy-editor": "--agent-copy-editor",
    "reviewer": "--agent-reviewer",
}


class PromptStore:
    def __init__(self, agents_dir: Path | str | None = None):
        self.agents_dir = Path(agents_dir) if agents_dir else Path(__file__).resolve().parent / "agents"

    def read(self, stage: str) -> str:
        try:
            return (self.agents_dir / STAGE_PROMPTS[stage]).read_text(encoding="utf-8")
        except (KeyError, FileNotFoundError) as exc:
            raise AgentConfigurationError(f"No prompt is configured for stage {stage!r}") from exc


class AgentRunner:
    """Runs an argv command with a JSON request on stdin; no shell is involved."""

    def __init__(self, cwd: Path | str, timeout_seconds: float = 300.0):
        self.cwd = Path(cwd)
        self.timeout_seconds = timeout_seconds

    def run(self, stage: str, command: str | None, prompt: str, payload: dict[str, Any]) -> dict[str, Any]:
        if stage not in STAGE_PROMPTS:
            raise AgentConfigurationError(f"Unknown agent stage {stage!r}")
        option = STAGE_OPTIONS[stage]
        if not command or not command.strip():
            raise AgentConfigurationError(
                f"No command configured for {stage}. Set --agent or the stage-specific {option}."
            )
        try:
            argv = shlex.split(command, posix=True)
        except ValueError as exc:
            raise AgentConfigurationError(f"Invalid {stage} command for {option}: {exc}") from exc
        if not argv:
            raise AgentConfigurationError(f"Command for {option} is empty.")
        command_path = Path(argv[0])
        if not command_path.is_absolute() and (len(command_path.parts) > 1 or argv[0].startswith(".")):
            command_path = self.cwd / command_path
        executable = shutil.which(str(command_path))
        if executable is None:
            raise AgentConfigurationError(
                f"Command {argv[0]!r} for {stage} ({option}) was not found on PATH or is not executable. "
                "Install it or configure an executable command that reads the MorphCook JSON request "
                "from stdin and writes one JSON response to stdout."
            )
        argv[0] = executable
        request = {"protocol_version": 1, "stage": stage, "prompt": prompt, "payload": payload}
        try:
            completed = subprocess.run(
                argv,
                input=json.dumps(request, ensure_ascii=False),
                text=True,
                capture_output=True,
                cwd=str(self.cwd),
                timeout=self.timeout_seconds,
                check=False,
            )
        except subprocess.TimeoutExpired as exc:
            raise AgentProtocolError(
                f"Agent command for {stage} exceeded {self.timeout_seconds:g}s; "
                "increase MORPHCOOK_AGENT_TIMEOUT or fix the command."
            ) from exc
        except OSError as exc:
            raise AgentConfigurationError(f"Could not execute {stage} command {argv[0]!r}: {exc}") from exc

        if completed.returncode != 0:
            detail = _excerpt(completed.stderr) or _excerpt(completed.stdout) or "no diagnostic output"
            raise AgentProtocolError(
                f"Agent command for {stage} exited with status {completed.returncode}: {detail}"
            )
        try:
            response = json.loads(completed.stdout)
        except json.JSONDecodeError as exc:
            detail = _excerpt(completed.stdout) or "empty stdout"
            raise AgentProtocolError(
                f"Agent command for {stage} must write exactly one JSON object to stdout; "
                f"received {detail!r}. Configure a protocol-compatible wrapper for {option}."
            ) from exc
        if not isinstance(response, dict):
            raise AgentProtocolError(f"Agent response for {stage} must be a JSON object.")
        return response


def _excerpt(value: str | None, limit: int = 1000) -> str:
    if not value:
        return ""
    normalized = value.strip()
    if len(normalized) <= limit:
        return normalized
    return normalized[:limit] + "…"
