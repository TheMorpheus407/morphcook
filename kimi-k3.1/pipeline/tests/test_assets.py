from __future__ import annotations

import copy
import json
import unittest

from pipeline.assets import AssetBuilder, build_assets, tokenize, write_json_files
from pipeline.errors import ConfigurationError, CorpusValidationError
from pipeline.tests.helpers import dish, dishes, recipe, vegan_recipe, repo_tempdir, write_base_assets, write_json


class AssetBuilderTests(unittest.TestCase):
    def _two_partition_assets(self, root):
        classic = recipe()
        salad = recipe("salad-classic", "salad")
        dish_document = {
            "schema_version": 1,
            "dishes": [
                dish(variant_ids=[classic["id"]]),
                dish("salad", "extended", [salad["id"]]),
            ],
        }
        write_base_assets(root, dish_document)
        write_json(root, "core-recipes.json", {"schema_version": 1, "partition_id": "core", "recipes": [classic]})
        write_json(
            root,
            "extended-recipes.json",
            {"schema_version": 1, "partition_id": "extended", "recipes": [salad]},
        )
        return classic, salad

    def test_build_preserves_sources_routes_index_and_is_deterministic(self) -> None:
        with repo_tempdir() as root:
            classic, salad = self._two_partition_assets(root)
            builder = AssetBuilder.load(root)
            result = builder.build()
            self.assertEqual(
                set(result.files), {"core-recipes.json", "extended-recipes.json", "recipes.json", "search-index.json"}
            )
            self.assertEqual(result.files["core-recipes.json"]["partition_id"], "core")
            self.assertEqual(result.files["extended-recipes.json"]["partition_id"], "extended")
            self.assertEqual([item["id"] for item in result.files["recipes.json"]["recipes"]], sorted([classic["id"], salad["id"]]))
            entries = {item["recipe_id"]: item for item in result.files["search-index.json"]["entries"]}
            self.assertEqual(entries[classic["id"]]["partition_id"], "core")
            self.assertEqual(entries[salad["id"]]["partition_id"], "extended")
            self.assertIn("classic", entries[classic["id"]]["tokens_by_lang"]["en"])
            self.assertIn("mehl", entries[classic["id"]]["tokens_by_lang"]["de"])
            self.assertIn("comfort", entries[classic["id"]]["tokens_by_lang"]["de"])

            written = write_json_files(root, result.files)
            self.assertEqual(len(written), 4)
            snapshots = {path.name: path.read_bytes() for path in root.glob("*.json")}
            second = build_assets(root)
            self.assertEqual(result.files, second.files)
            self.assertEqual(snapshots, {path.name: path.read_bytes() for path in root.glob("*.json")})

    def test_source_partition_must_match_dish_primary_route(self) -> None:
        with repo_tempdir() as root:
            classic, salad = self._two_partition_assets(root)
            core_path = root / "core-recipes.json"
            core = json.loads(core_path.read_text(encoding="utf-8"))
            core["recipes"].append(salad)
            core_path.write_text(json.dumps(core), encoding="utf-8")
            (root / "extended-recipes.json").write_text(
                json.dumps({"schema_version": 1, "partition_id": "extended", "recipes": []}), encoding="utf-8"
            )
            with self.assertRaisesRegex(CorpusValidationError, "routes to 'extended'"):
                AssetBuilder.load(root).build()

    def test_combined_only_input_is_partitioned_via_dishes(self) -> None:
        with repo_tempdir() as root:
            classic, salad = self._two_partition_assets(root)
            (root / "core-recipes.json").unlink()
            (root / "extended-recipes.json").unlink()
            write_json(root, "recipes.json", {"schema_version": 1, "recipes": [salad, classic]})
            result = AssetBuilder.load(root).build()
            self.assertEqual([item["id"] for item in result.files["core-recipes.json"]["recipes"]], [classic["id"]])
            self.assertEqual([item["id"] for item in result.files["extended-recipes.json"]["recipes"]], [salad["id"]])

    def test_new_recipe_is_linked_and_routed_to_existing_source(self) -> None:
        with repo_tempdir() as root:
            classic = recipe()
            write_base_assets(root, dishes([classic["id"]]))
            write_json(root, "core-recipes.json", {"schema_version": 1, "partition_id": "core", "recipes": [classic]})
            builder = AssetBuilder.load(root)
            vegan = vegan_recipe()
            updated_dishes = copy.deepcopy(builder.dishes)
            updated_dishes["dishes"][0]["variant_ids"].append(vegan["id"])
            result = builder.build([vegan], dishes=updated_dishes)
            self.assertEqual(
                [item["id"] for item in result.files["core-recipes.json"]["recipes"]],
                [classic["id"], vegan["id"]],
            )
            self.assertEqual(len(result.files["search-index.json"]["entries"]), 2)
            self.assertIn("dishes.json", result.files)

    def test_dangling_variant_link_fails_corpus_validation(self) -> None:
        with repo_tempdir() as root:
            classic = recipe()
            write_base_assets(root, dishes([classic["id"], "doener-missing"]))
            write_json(root, "core-recipes.json", {"schema_version": 1, "partition_id": "core", "recipes": [classic]})
            with self.assertRaisesRegex(CorpusValidationError, "links missing recipe"):
                AssetBuilder.load(root).build()

    def test_manifest_preserves_custom_partition_filename(self) -> None:
        with repo_tempdir() as root:
            classic = recipe()
            write_base_assets(root, dishes([classic["id"]]))
            write_json(root, "partitions/main.json", {"schema_version": 1, "partition_id": "core", "recipes": [classic]})
            write_json(root, "partition-manifest.json", {"partitions": [{"id": "core", "file": "partitions/main.json"}]})
            result = AssetBuilder.load(root).build()
            self.assertIn("partitions/main.json", result.files)
            self.assertNotIn("core-recipes.json", result.files)

    def test_manifest_cannot_escape_assets_directory(self) -> None:
        with repo_tempdir() as root:
            write_base_assets(root)
            write_json(root, "partition-manifest.json", {"partitions": ["../outside.json"]})
            with self.assertRaisesRegex(ConfigurationError, "must stay inside"):
                AssetBuilder.load(root)

    def test_manifest_skips_discovery_cross_reference_files(self) -> None:
        with repo_tempdir() as root:
            classic, salad = self._two_partition_assets(root)
            write_json(root, "cuisine-italian.json", {
                "schema_version": 1,
                "partition_id": "cuisine-italian",
                "recipe_ids": [classic["id"], salad["id"]],
            })
            write_json(root, "partition-manifest.json", {"partitions": [
                {"id": "core", "file": "core-recipes.json", "strategy": "launch"},
                {"id": "extended", "file": "extended-recipes.json", "strategy": "on-demand"},
                {"id": "cuisine-italian", "file": "cuisine-italian.json", "strategy": "discovery"},
            ]})
            result = AssetBuilder.load(root).build()
            self.assertEqual(len(result.recipes), 2)
            self.assertNotIn("cuisine-italian.json", result.files)

    def test_search_index_includes_dimensions_and_derived_quick_tag(self) -> None:
        with repo_tempdir() as root:
            classic, _ = self._two_partition_assets(root)
            result = AssetBuilder.load(root).build()
            entries = {item["recipe_id"]: item for item in result.files["search-index.json"]["entries"]}
            tags = set(entries[classic["id"]]["tags"])
            self.assertTrue({"classic", "easy", "quick"} <= tags)
            self.assertIn("classic", entries[classic["id"]]["tokens_by_lang"]["en"])

    def test_tokenization_is_casefolded_unicode(self) -> None:
        self.assertEqual(tokenize("  DÖNER comfort-food "), {"döner", "comfort", "food"})


if __name__ == "__main__":
    unittest.main()
