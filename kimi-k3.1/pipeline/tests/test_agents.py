from __future__ import annotations

import json
import shlex
import sys
import unittest

from pipeline.agents import AgentRunner
from pipeline.errors import AgentConfigurationError, AgentProtocolError
from pipeline.tests.helpers import repo_tempdir


class AgentRunnerTests(unittest.TestCase):
    def test_stdin_stdout_protocol_without_shell(self) -> None:
        with repo_tempdir() as root:
            capture = root / "request.json"
            script = root / "agent.py"
            script.write_text(
                "import json, sys\n"
                "request = json.load(sys.stdin)\n"
                "json.dump(request, open(sys.argv[1], 'w'))\n"
                "json.dump({'ok': True, 'stage': request['stage']}, sys.stdout)\n",
                encoding="utf-8",
            )
            command = f"{shlex.quote(sys.executable)} {shlex.quote(str(script))} {shlex.quote(str(capture))}"
            response = AgentRunner(cwd=root).run("generator", command, "PROMPT", {"value": "Döner"})
            self.assertEqual(response, {"ok": True, "stage": "generator"})
            request = json.loads(capture.read_text(encoding="utf-8"))
            self.assertEqual(request["protocol_version"], 1)
            self.assertEqual(request["prompt"], "PROMPT")
            self.assertEqual(request["payload"], {"value": "Döner"})

    def test_relative_executable_is_resolved_from_runner_directory(self) -> None:
        with repo_tempdir() as root:
            script = root / "relative-agent"
            script.write_text(
                "#!/usr/bin/env python3\nimport json, sys\njson.load(sys.stdin)\njson.dump({'relative': True}, sys.stdout)\n",
                encoding="utf-8",
            )
            script.chmod(0o755)
            response = AgentRunner(cwd=root).run("generator", "./relative-agent", "prompt", {})
            self.assertEqual(response, {"relative": True})

    def test_missing_command_has_stage_specific_action(self) -> None:
        with repo_tempdir() as root:
            with self.assertRaises(AgentConfigurationError) as caught:
                AgentRunner(cwd=root).run("verifier", "definitely-no-morphcook-agent", "prompt", {})
        message = str(caught.exception)
        self.assertIn("--agent-verifier", message)
        self.assertIn("not found on PATH", message)
        self.assertIn("stdin", message)

    def test_unterminated_command_is_actionable(self) -> None:
        with repo_tempdir() as root:
            with self.assertRaisesRegex(AgentConfigurationError, "Invalid generator command"):
                AgentRunner(cwd=root).run("generator", "'unterminated", "prompt", {})

    def test_nonzero_exit_includes_stderr(self) -> None:
        with repo_tempdir() as root:
            script = root / "agent.py"
            script.write_text("import sys\nsys.stderr.write('useful failure')\nsys.exit(7)\n", encoding="utf-8")
            command = f"{shlex.quote(sys.executable)} {shlex.quote(str(script))}"
            with self.assertRaises(AgentProtocolError) as caught:
                AgentRunner(cwd=root).run("reviewer", command, "prompt", {})
        self.assertIn("status 7", str(caught.exception))
        self.assertIn("useful failure", str(caught.exception))

    def test_non_json_stdout_is_a_protocol_error(self) -> None:
        with repo_tempdir() as root:
            script = root / "agent.py"
            script.write_text("print('not json')", encoding="utf-8")
            command = f"{shlex.quote(sys.executable)} {shlex.quote(str(script))}"
            with self.assertRaisesRegex(AgentProtocolError, "exactly one JSON object"):
                AgentRunner(cwd=root).run("nutrition", command, "prompt", {})


if __name__ == "__main__":
    unittest.main()
