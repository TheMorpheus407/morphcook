#!/usr/bin/env python3
"""Bridge any local JSON-capable model CLI to MorphCook's agent protocol.

Pass --command as a JSON argv array. `{agent}` and `{stage}` are replaced in
individual arguments. The stage prompt plus input JSON are sent on stdin.
The command's stdout must be one JSON object. No shell is involved.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--command", required=True, help='JSON argv, e.g. ["local-model", "--model", "{agent}"]')
    for field in ("agent", "stage", "input", "output", "prompt"):
        parser.add_argument("--" + field, required=True)
    args = parser.parse_args()
    command = json.loads(args.command)
    if not isinstance(command, list) or not command or not all(isinstance(v, str) for v in command):
        raise ValueError("--command must be a nonempty JSON array of strings")
    command = [v.replace("{agent}", args.agent).replace("{stage}", args.stage) for v in command]
    prompt = Path(args.prompt).read_text(encoding="utf-8")
    payload = Path(args.input).read_text(encoding="utf-8")
    result = subprocess.run(command, input=prompt + "\n\nINPUT JSON:\n" + payload, capture_output=True, text=True, check=True)
    response = json.loads(result.stdout)
    if not isinstance(response, dict):
        raise ValueError("Model CLI must return one JSON object on stdout")
    Path(args.output).write_text(json.dumps(response, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1)
