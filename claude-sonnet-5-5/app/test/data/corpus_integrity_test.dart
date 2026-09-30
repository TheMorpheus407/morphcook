import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/models/faq.dart';
import 'package:morphcook/tooling/corpus_toolkit.dart';
import 'package:morphcook/tooling/mini_json_schema.dart';

Map<String, dynamic> readJson(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, dynamic>();

CorpusData loadData() => CorpusData(
  ontologyJson: readJson('assets/ontology.json'),
  ingredientsJson: readJson('assets/ingredients.json'),
  dishesJson: readJson('assets/dishes.json'),
  recipesJson: readJson('assets/recipes.json'),
  manifestJson: readJson('assets/partition-manifest.json'),
  guideJson: readJson('assets/ingredient-guide.json'),
  faqsJson: readJson('assets/faqs.json'),
);

MiniJsonSchema schema(String name) => MiniJsonSchema(readJson('../pipeline/schemas/$name'));

/// Every language string reachable in a JSON tree that looks like `{en: ..., de: ...}`.
Iterable<String> languageTexts(Object? node) sync* {
  if (node is Map) {
    final isLanguageMap =
        node.isNotEmpty && node.keys.every((k) => k == 'en' || k == 'de') && node.values.every((v) => v is String);
    if (isLanguageMap) {
      for (final v in node.values) {
        yield v as String;
      }
    } else {
      for (final v in node.values) {
        yield* languageTexts(v);
      }
    }
  } else if (node is List) {
    for (final v in node) {
      yield* languageTexts(v);
    }
  }
}

void main() {
  late CorpusData data;

  setUpAll(() => data = loadData());

  group('the shipped corpus passes every quality gate', () {
    test('no errors and no warnings', () {
      final issues = CorpusValidator(
        data,
        recipeSchema: schema('recipe.schema.json'),
        dishSchema: schema('dish.schema.json'),
        ontologySchema: schema('ontology.schema.json'),
      ).validate();
      expect(issues.map((i) => i.toString()), isEmpty);
    });

    test('generated files are current (run "dart run tool/corpus_tool.dart build" after editing recipes.json)', () {
      final files = CorpusBuilder(data).build();
      final stale = [
        for (final entry in files.entries)
          if (!File('assets/${entry.key}').existsSync() ||
              File('assets/${entry.key}').readAsStringSync() != '${entry.value}\n')
            entry.key,
      ];
      expect(stale, isEmpty);
    });

    test('normalizing is idempotent', () {
      final normalizer = CorpusNormalizer(data.ontology, data.ingredients);
      final once = normalizer.normalizeRecipes(data.recipeMaps);
      final twice = normalizer.normalizeRecipes(once);
      expect(jsonEncode(twice), jsonEncode(once));
      expect(jsonEncode(once), jsonEncode(data.recipeMaps), reason: 'recipes.json is stored normalized');
    });
  });

  group('partitions', () {
    late Map<String, dynamic> manifest;
    late Map<String, Set<String>> recipesByPartition;
    late Set<String> masterIds;

    setUpAll(() {
      manifest = readJson('assets/partition-manifest.json');
      masterIds = {for (final r in data.recipeMaps) r['id'] as String};
      recipesByPartition = {
        for (final p in (manifest['partitions'] as List))
          (p as Map)['id'] as String: {
            for (final r in (readJson('assets/${p['file']}')['recipes'] as List)) (r as Map)['id'] as String,
          },
      };
    });

    test('the manifest registers core, extended and the three cuisine partitions', () {
      expect(
        recipesByPartition.keys,
        unorderedEquals(['core', 'extended', 'cuisine-italian', 'cuisine-asian', 'cuisine-middle-eastern']),
      );
      expect(manifest['schema_version'], 1);
      expect(manifest['corpus_version'], isNotEmpty);
      expect((manifest['loading_strategy'] as Map)['launch'], ['core']);
    });

    test('the union of all partitions is exactly the master corpus, and no recipe is stored twice', () {
      final all = [for (final ids in recipesByPartition.values) ...ids];
      expect(all.toSet(), masterIds);
      expect(all.length, masterIds.length, reason: 'a recipe lives in exactly one partition');
    });

    test('each dish keeps all of its variants in its own partition', () {
      for (final dish in data.dishMaps) {
        final partition = dish['partition_id'] as String;
        for (final id in (dish['recipes'] as List).cast<String>()) {
          expect(recipesByPartition[partition], contains(id), reason: '${dish['id']} / $id');
        }
      }
    });

    test('the manifest counts match the files', () {
      for (final p in (manifest['partitions'] as List)) {
        final entry = (p as Map).cast<String, dynamic>();
        final ids = recipesByPartition[entry['id']]!;
        expect(entry['recipe_count'], ids.length, reason: entry['id'] as String);
        final dishes = data.dishMaps.where((d) => d['partition_id'] == entry['id']);
        expect(entry['dish_count'], dishes.length, reason: entry['id'] as String);
      }
    });

    test('core loads at launch, everything else on demand', () {
      final byId = {for (final p in (manifest['partitions'] as List)) (p as Map)['id']: p};
      expect(byId['core']!['load'], 'launch');
      for (final id in byId.keys.where((id) => id != 'core')) {
        expect(byId[id]!['load'], 'on_demand', reason: id as String);
      }
    });

    test('core holds the launch dishes and cuisines hold their tier "extended" dishes', () {
      for (final dish in data.dishMaps) {
        if (dish['frequency_tier'] == 'core') expect(dish['partition_id'], 'core', reason: dish['id'] as String);
        if (dish['frequency_tier'] == 'extended') {
          expect(dish['partition_id'], isNot('core'), reason: dish['id'] as String);
        }
      }
    });

    test('cuisine partitions cross-reference dishes of that cuisine that live elsewhere', () {
      final refs = (manifest['cross_references'] as Map).cast<String, dynamic>();
      expect(refs.keys, unorderedEquals(['cuisine-italian', 'cuisine-asian', 'cuisine-middle-eastern']));
      final italianCore = [
        for (final d in data.dishMaps)
          if ((d['cuisine_tags'] as List).contains('italian') && d['partition_id'] == 'core') d['id'] as String,
      ];
      expect(italianCore, isNotEmpty);
      expect((refs['cuisine-italian'] as List).cast<String>(), containsAll(italianCore));
      for (final d in data.dishMaps) {
        expect(d['secondary_partitions'], isA<List<Object?>>());
      }
    });

    test('each partition has a search index chunk with one entry per recipe', () {
      for (final p in (manifest['partitions'] as List)) {
        final entry = (p as Map).cast<String, dynamic>();
        final chunk = readJson('assets/${entry['search_index']}');
        final ids = {for (final e in (chunk['entries'] as List)) (e as Map)['r'] as String};
        expect(ids, recipesByPartition[entry['id']], reason: entry['id'] as String);
      }
    });

    test('the corpus is not one huge file: the launch partition is smaller than the whole', () {
      final launch = File('assets/core-recipes.json').lengthSync();
      final total = File('assets/recipes.json').lengthSync();
      expect(launch, lessThan(total));
    });
  });

  group('dishes', () {
    test('a dish has id, canonical name, hero text, caption, stripe colour, variants and routing fields', () {
      for (final dish in data.dishMaps) {
        for (final key in [
          'id',
          'name',
          'hero',
          'cap',
          'stripe',
          'recipes',
          'partition_id',
          'secondary_partitions',
          'cuisine_tags',
          'frequency_tier',
        ]) {
          expect(dish.containsKey(key), isTrue, reason: '${dish['id']} lacks $key');
        }
        expect(
          (dish['recipes'] as List).length,
          greaterThanOrEqualTo(3),
          reason: '${dish['id']} should offer several variants',
        );
      }
    });

    test('every dish offers a classic, a vegan and a gluten-free way or a documented reason', () {
      final byDish = <String, Set<String>>{};
      for (final r in data.recipeMaps) {
        (byDish[r['dish_id'] as String] ??= <String>{}).addAll((r['attributes'] as List).cast<String>());
      }
      for (final dish in data.dishMaps) {
        final attributes = byDish[dish['id']]!;
        expect(attributes, contains('vegan'), reason: dish['id'] as String);
        expect(attributes, contains('gluten-free'), reason: dish['id'] as String);
      }
    });
  });

  group('every user-visible text exists in German and English', () {
    void expectBilingual(String label, Object? json) {
      final texts = languageTexts(json).toList();
      expect(texts, isNotEmpty, reason: label);
      for (final t in texts) {
        expect(t.trim(), isNotEmpty, reason: label);
      }
    }

    test('recipes', () {
      for (final r in data.recipeMaps) {
        for (final key in ['title', 'blurb', 'tip']) {
          final text = (r[key] as Map?);
          if (key == 'tip' && text == null) continue;
          expect(text!['en'], isNotEmpty, reason: '${r['id']} $key en');
          expect(text['de'], isNotEmpty, reason: '${r['id']} $key de');
        }
        for (final step in (r['steps'] as List)) {
          final text = (step as Map)['text'] as Map;
          expect(text['en'], isNotEmpty, reason: r['id'] as String);
          expect(text['de'], isNotEmpty, reason: r['id'] as String);
        }
      }
    });

    test('ontology, ingredients, dishes, guide and FAQ', () {
      expectBilingual('ontology', data.ontologyJson['attributes']);
      expectBilingual('flags', data.ontologyJson['flags']);
      expectBilingual('dishes', data.dishesJson['dishes']);
      expectBilingual('guide', data.guideJson!['entries']);
      expectBilingual('faq', data.faqsJson!['entries']);
      for (final node in (data.ingredientsJson['nodes'] as List)) {
        final name = (node as Map)['name'] as Map;
        expect(name['en'], isNotEmpty, reason: node['id'] as String);
        expect(name['de'], isNotEmpty, reason: node['id'] as String);
      }
    });

    test('the interface strings', () {
      final table = (readJson('assets/i18n/strings.json')['strings'] as Map).cast<String, dynamic>();
      expect(table.length, greaterThan(300));
      for (final entry in table.entries) {
        final value = (entry.value as Map).cast<String, dynamic>();
        expect(value['en'], isNotEmpty, reason: '${entry.key} en');
        expect(value['de'], isNotEmpty, reason: '${entry.key} de');
        // Placeholders must agree between the languages.
        final en = RegExp(r'\{(\w+)\}').allMatches(value['en'] as String).map((m) => m.group(1)).toSet();
        final de = RegExp(r'\{(\w+)\}').allMatches(value['de'] as String).map((m) => m.group(1)).toSet();
        expect(de, en, reason: '${entry.key} placeholders differ between languages');
      }
    });
  });

  group('house style', () {
    test('no banned phrasing in the interface, help and kitchen reference', () {
      final texts = <String>[
        ...languageTexts(readJson('assets/i18n/strings.json')),
        ...languageTexts(data.faqsJson),
        ...languageTexts(data.guideJson),
        ...languageTexts(data.dishesJson),
      ];
      expect(texts, isNotEmpty);
      final offenders = [
        for (final t in texts)
          if (StyleRules.violatesStyle(t)) t,
      ];
      expect(offenders, isEmpty);
    });

    test('no banned phrasing in the README and the docs either', () {
      final files = <File>[
        File('../README.md'),
        File('../pipeline/README.md'),
        ...Directory('../docs').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.md')),
      ];
      expect(files.length, greaterThan(5), reason: 'the docs are where the test expects them');
      final offenders = <String>[];
      for (final file in files) {
        final text = file.readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
        if (StyleRules.violatesStyle(text)) offenders.add(file.path);
      }
      expect(offenders, isEmpty);
    });

    test('the style rules catch what they are meant to catch', () {
      for (final bad in [
        "it's not a diet, it's a way of eating",
        'not just quick, but delicious',
        'no yeast, no waiting',
        'nicht nur schnell, sondern lecker',
        'keine Sahne, kein Stress',
      ]) {
        expect(StyleRules.violatesStyle(bad), isTrue, reason: bad);
      }
      for (final fine in ['no yeast needed', 'a note, but a short one', 'kein Problem', 'not today']) {
        expect(StyleRules.violatesStyle(fine), isFalse, reason: fine);
      }
    });
  });

  group('FAQ and contextual help', () {
    late FaqLibrary library;

    setUpAll(() => library = FaqLibrary.fromJson(readJson('assets/faqs.json')));

    test('covers the four topics of the specification', () {
      final categories = {for (final c in library.categories) c.id};
      expect(categories.length, greaterThanOrEqualTo(4));
      final text = jsonEncode(readJson('assets/faqs.json')['entries']).toLowerCase();
      for (final topic in ['matching', 'visible', 'backup', 'shopping', 'cook mode', 'calorie']) {
        expect(text, contains(topic), reason: topic);
      }
    });

    test('every contextual help link in the interface points at an existing entry', () {
      final ids = {for (final e in library.entries) e.id};
      final links = <String>{};
      for (final file in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        links.addAll(RegExp(r"entryId: '([a-z0-9-]+)'").allMatches(file.readAsStringSync()).map((m) => m.group(1)!));
      }
      expect(links, isNotEmpty);
      expect(ids, containsAll(links));
    });

    test('search finds entries by question, answer and keyword, ignoring case and umlauts', () {
      expect(library.search('backup', 'en'), isNotEmpty);
      expect(library.search('BACKUP', 'en'), isNotEmpty);
      expect(library.search('sicherung', 'de'), isNotEmpty);
      expect(library.search('zzzzqq', 'en'), isEmpty);
    });

    test('a category filter narrows the list', () {
      final first = library.categories.first.id;
      final filtered = library.search('', 'en', category: first);
      expect(filtered, isNotEmpty);
      expect(filtered.every((e) => e.category == first), isTrue);
      expect(filtered.length, lessThan(library.entries.length));
    });
  });

  group('interface strings used by the code exist', () {
    test('every static key in lib/ has a translation', () {
      final table = (readJson('assets/i18n/strings.json')['strings'] as Map).cast<String, dynamic>();
      final namespaces = {for (final k in table.keys) k.split('.').first};
      final literal = RegExp("'([a-z]+(?:\\.[A-Za-z0-9_\$\\{\\}]+)+)'");
      final missing = <String>[];
      for (final file in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        for (final m in literal.allMatches(file.readAsStringSync())) {
          final key = m.group(1)!;
          if (!namespaces.contains(key.split('.').first) || key.endsWith('.v1') || key.endsWith('.json')) continue;
          if (key.contains(r'$')) {
            final prefix = key.substring(0, key.indexOf(r'$'));
            if (!table.keys.any((k) => k.startsWith(prefix))) missing.add('${file.path}: $key');
          } else if (!table.containsKey(key) && !(table.containsKey('$key.one') && table.containsKey('$key.other'))) {
            missing.add('${file.path}: $key');
          }
        }
      }
      expect(missing, isEmpty);
    });

    test('no key is left unused (keeps the string table honest)', () {
      final table = (readJson('assets/i18n/strings.json')['strings'] as Map).cast<String, dynamic>();
      final source = [
        for (final f in Directory(
          'lib',
        ).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')))
          f.readAsStringSync(),
      ].join('\n');
      final unused = <String>[];
      for (final key in table.keys) {
        if (key.startsWith('date.')) continue; // assembled from weekday and month numbers
        final base = key.replaceFirst(RegExp(r'\.(one|other)$'), '');
        final direct = source.contains("'$base'") || source.contains('"$base"');
        // Keys built from a prefix, for example 'insights.level.${...}'.
        final parts = base.split('.');
        var built = false;
        for (var i = parts.length - 1; i >= 1 && !built; i--) {
          built = source.contains("'${parts.sublist(0, i).join('.')}.\$");
        }
        if (!direct && !built) unused.add(key);
      }
      expect(unused, isEmpty, reason: 'remove or use these keys');
    });
  });

  group('the ingredient dictionary', () {
    test('is a proper tree: every parent exists and there are no cycles', () {
      final nodes = {for (final n in (data.ingredientsJson['nodes'] as List)) (n as Map)['id'] as String: n};
      for (final n in nodes.values) {
        final seen = <String>{};
        String? current = n['id'] as String;
        while (current != null) {
          expect(seen.add(current), isTrue, reason: 'cycle at ${n['id']}');
          final parent = (nodes[current] as Map)['parent'] as String?;
          if (parent != null) expect(nodes.containsKey(parent), isTrue, reason: '${n['id']} -> $parent');
          current = parent;
        }
      }
    });

    test('shows the example tree of the specification: dairy > cow-milk > whole-milk, tree nuts', () {
      final dict = data.ingredients;
      expect(dict.ancestorsOf('whole-milk'), containsAllInOrder(['cow-milk', 'dairy']));
      expect(
        dict.descendantsOf('dairy'),
        containsAll(['cow-milk', 'whole-milk', 'skim-milk', 'goat-milk', 'cheese', 'parmesan', 'feta']),
      );
      expect(dict.contains('walnuts') || dict.contains('walnut'), isTrue);
    });

    test('the typeahead finds parents and leaves, in both languages', () {
      final dict = data.ingredients;
      expect(dict.search('dairy', 'en').map((n) => n.id), contains('dairy'));
      expect(dict.search('parm', 'en').map((n) => n.id), contains('parmesan'));
      expect(dict.search('milch', 'de').map((n) => n.id), contains('cow-milk'));
      expect(dict.search('zzzz', 'en'), isEmpty);
    });

    test('the kitchen reference covers the ingredient guide entries used by recipes', () {
      final used = {for (final r in data.recipeMaps) ...(r['ingredient_ids'] as List).cast<String>()};
      final guided = {for (final e in (data.guideJson!['entries'] as List)) (e as Map)['ingredient_id'] as String};
      expect(guided.intersection(used).length, greaterThan(20));
    });
  });

  group('the app bundle lists the corpus files', () {
    test('pubspec.yaml bundles every partition and data file, and not the master copy', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final assets = RegExp(
        r'^\s+- (assets/\S+)$',
        multiLine: true,
      ).allMatches(pubspec).map((m) => m.group(1)!).toSet();
      for (final file in [
        'assets/partition-manifest.json',
        'assets/core-recipes.json',
        'assets/extended-recipes.json',
        'assets/cuisine-italian.json',
        'assets/cuisine-asian.json',
        'assets/cuisine-middle-eastern.json',
        'assets/dishes.json',
        'assets/ontology.json',
        'assets/ingredients.json',
        'assets/ingredient-guide.json',
        'assets/faqs.json',
        'assets/search/',
        'assets/i18n/',
      ]) {
        expect(assets, contains(file));
      }
      expect(assets, isNot(contains('assets/recipes.json')), reason: 'the master copy would double the app size');
    });

    test('fonts are bundled, not fetched at runtime', () {
      final fonts = Directory('assets/google_fonts').listSync().map((e) => e.path.split('/').last).toList();
      expect(fonts.any((f) => f.startsWith('PlayfairDisplay')), isTrue);
      expect(fonts.any((f) => f.startsWith('JetBrainsMono')), isTrue);
      expect(fonts.any((f) => f.startsWith('Caveat')), isTrue);
    });

    test('no HTTP client is configured: the app has no networking package', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final banned in ['http:', 'dio:', 'firebase', 'sentry', 'analytics']) {
        expect(pubspec.contains(RegExp('^  $banned', multiLine: true)), isFalse, reason: banned);
      }
    });
  });
}
