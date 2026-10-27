from __future__ import annotations

import copy
import io
import unittest

from pipeline.errors import QualityGateError
from pipeline.generation import RecipeGenerationPipeline, emit_spot_check
from pipeline.tests import helpers
from pipeline.validation import CorpusValidator


class FakeRunner:
    def __init__(self) -> None:
        self.calls = []
        self.handlers = {}
        self.reject_remaining = {}

    def run(self, stage, command, prompt, payload):
        self.calls.append({"stage": stage, "command": command, "prompt": prompt, "payload": copy.deepcopy(payload)})
        if self.reject_remaining.get(stage, 0):
            self.reject_remaining[stage] -= 1
            return {"approved": False, "feedback": [f"{stage} needs correction"]}
        if stage in self.handlers:
            return self.handlers[stage](payload)
        if stage == "generator":
            return {"recipe": helpers.recipe(payload["recipe_id"], payload["dish"]["id"])}
        if stage in ("nutrition", "copy-editor"):
            value = copy.deepcopy(payload["recipe"])
            if stage == "nutrition":
                value["calories_per_serving"] = 555
            else:
                value["title"]["en"] = "Edited classic flatbread"
            return {"recipe": value}
        return {"approved": True, "feedback": []}


class GenerationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.validator = CorpusValidator(helpers.ontology(), helpers.ingredients())
        self.runner = FakeRunner()
        self.agents = {
            "generator": "generate",
            "verifier": "verify",
            "nutrition": "nutrition",
            "copy-editor": "copy",
            "reviewer": "review",
        }

    def pipeline(self, existing=None, retries=3):
        return RecipeGenerationPipeline(
            runner=self.runner,
            agents=self.agents,
            validator=self.validator,
            dishes=helpers.dishes(),
            existing_recipes=existing or [],
            max_retries=retries,
        )

    def test_happy_path_uses_all_stages_in_order(self) -> None:
        accepted = self.pipeline().generate_all("doener", ["classic"])
        self.assertEqual(len(accepted), 1)
        self.assertEqual(accepted[0]["calories_per_serving"], 555)
        self.assertEqual(accepted[0]["title"]["en"], "Edited classic flatbread")
        self.assertEqual(
            [call["stage"] for call in self.runner.calls],
            ["generator", "verifier", "nutrition", "copy-editor", "reviewer"],
        )
        self.assertEqual(
            [call["command"] for call in self.runner.calls],
            ["generate", "verify", "nutrition", "copy", "review"],
        )
        self.assertTrue(all(call["prompt"] for call in self.runner.calls))

    def test_verifier_rejection_returns_feedback_to_generator(self) -> None:
        self.runner.reject_remaining["verifier"] = 1
        self.pipeline(retries=1).generate_all("doener", ["classic"])
        generator_calls = [call for call in self.runner.calls if call["stage"] == "generator"]
        self.assertEqual(len(generator_calls), 2)
        self.assertEqual(generator_calls[0]["payload"]["feedback"], [])
        self.assertIn("flag-verifier: verifier needs correction", generator_calls[1]["payload"]["feedback"])

    def test_reviewer_rejection_bounces_through_whole_pipeline(self) -> None:
        self.runner.reject_remaining["reviewer"] = 1
        self.pipeline(retries=1).generate_all("doener", ["classic"])
        self.assertEqual(len([call for call in self.runner.calls if call["stage"] == "generator"]), 2)
        self.assertEqual(len([call for call in self.runner.calls if call["stage"] == "reviewer"]), 2)

    def test_nutrition_cannot_change_servings(self) -> None:
        attempts = []

        def nutrition(payload):
            value = copy.deepcopy(payload["recipe"])
            attempts.append(value)
            if len(attempts) == 1:
                value["servings"] = 99
            return {"recipe": value}

        self.runner.handlers["nutrition"] = nutrition
        self.pipeline(retries=1).generate_all("doener", ["classic"])
        self.assertEqual(len(attempts), 2)
        generator_calls = [call for call in self.runner.calls if call["stage"] == "generator"]
        self.assertIn("changed immutable field $.servings", generator_calls[1]["payload"]["feedback"][0])

    def test_invalid_generator_output_exhausts_retries_before_verifier(self) -> None:
        def invalid(payload):
            value = helpers.recipe(payload["recipe_id"])
            value["contains"].remove("dairy")
            return {"recipe": value}

        self.runner.handlers["generator"] = invalid
        with self.assertRaisesRegex(QualityGateError, "ingredient-derived flags: dairy"):
            self.pipeline(retries=1).generate_all("doener", ["classic"])
        self.assertFalse(any(call["stage"] == "verifier" for call in self.runner.calls))

    def test_near_duplicate_is_rejected_before_reviewer(self) -> None:
        existing = helpers.recipe("doener-existing")
        with self.assertRaisesRegex(QualityGateError, "near-duplicate.*doener-existing"):
            self.pipeline(existing=[existing], retries=0).generate_all("doener", ["classic"])
        self.assertFalse(any(call["stage"] == "reviewer" for call in self.runner.calls))

    def test_unknown_dish_is_actionable(self) -> None:
        with self.assertRaisesRegex(QualityGateError, "does not exist"):
            self.pipeline().generate_all("missing", ["classic"])

    def test_spot_check_outputs_exactly_n_recipes(self) -> None:
        output = io.StringIO()
        values = [helpers.recipe(f"doener-v{index}") for index in range(4)]
        sample = emit_spot_check(values, 2, output)
        self.assertEqual(len(sample), 2)
        self.assertIn("Human spot-check: 2 of 4", output.getvalue())
        self.assertEqual(output.getvalue().count("--- doener-"), 2)


if __name__ == "__main__":
    unittest.main()
