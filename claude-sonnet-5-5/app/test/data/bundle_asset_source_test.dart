import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/asset_source.dart';
import 'package:morphcook/data/bundle_asset_source.dart';
import 'package:morphcook/data/corpus.dart';

/// What the app reads at runtime: the Flutter asset bundle, made of the files
/// that pubspec.yaml lists. Every other test reads the assets folder from disk,
/// so a file that is missing from the pubspec would slip through them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bundle = BundleAssetSource();
  const disk = FileAssetSource('assets');

  test('every partition and search chunk of the manifest is in the bundle', () async {
    final manifest = await bundle.loadJson('partition-manifest.json');
    final partitions = (manifest['partitions'] as List).cast<Map>();
    expect(partitions, isNotEmpty);
    for (final partition in partitions) {
      final recipes = await bundle.loadJson(partition['file'] as String);
      expect((recipes['recipes'] as List).length, partition['recipe_count'], reason: partition['id'] as String);
      final index = await bundle.loadJson(partition['search_index'] as String);
      expect(index['entries'], isNotEmpty, reason: partition['id'] as String);
    }
  });

  test('the shared files are in the bundle', () async {
    for (final name in [
      'dishes.json',
      'ontology.json',
      'ingredients.json',
      'ingredient-guide.json',
      'faqs.json',
      'i18n/strings.json',
    ]) {
      expect(jsonDecode(await bundle.loadString(name)), isNotNull, reason: name);
    }
  });

  test('the bundle and the disk hold the same bytes', () async {
    for (final name in [
      'partition-manifest.json',
      'core-recipes.json',
      'dishes.json',
      'ontology.json',
      'i18n/strings.json',
    ]) {
      expect(await bundle.loadString(name), await disk.loadString(name), reason: name);
    }
  });

  test('the master file stays out of the bundle: the partitions carry the same recipes', () async {
    await expectLater(bundle.loadString('recipes.json'), throwsA(anything));
    expect(File('assets/recipes.json').existsSync(), isTrue, reason: 'it lives in the repository for the tools');
  });

  test('the corpus loads from the bundle exactly as it does from disk', () async {
    final fromBundle = await Corpus.load(bundle);
    final fromDisk = await Corpus.load(disk);
    expect(fromBundle.dishes.keys.toSet(), fromDisk.dishes.keys.toSet());
    expect(fromBundle.dishes.length, 28);
    expect(fromBundle.isPartitionLoaded('core'), isTrue);
    for (final partition in fromBundle.manifest.partitions.where((p) => !p.loadsAtLaunch)) {
      await fromBundle.ensurePartition(partition.id);
      await fromDisk.ensurePartition(partition.id);
    }
    final recipes = [for (final dish in fromBundle.dishes.values) ...await fromBundle.loadDish(dish.id)];
    expect(recipes.length, 145);
    expect(
      {for (final r in recipes) r.id},
      {for (final dish in fromDisk.dishes.values) ...(await fromDisk.loadDish(dish.id)).map((r) => r.id)},
    );
  });

  test('the help center and the kitchen reference load from the bundle', () async {
    final corpus = await Corpus.load(bundle);
    expect((await corpus.faqs()).entries, isNotEmpty);
    expect((await corpus.guide()).has('tahini'), isTrue);
  });

  test('a file that is not in the bundle is an error, not an empty result', () async {
    await expectLater(bundle.loadString('nope.json'), throwsA(anything));
  });
}
