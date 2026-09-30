import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/tooling/corpus_files.dart';
import 'package:morphcook/tooling/corpus_toolkit.dart';

import '../support/corpus_data.dart';

/// The corpus folder on disk, the option parser and the schemas the tools load.
void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('morphcook_corpus_files'));
  tearDown(() => temp.deleteSync(recursive: true));

  group('parseOptions', () {
    test('reads values, bare flags and the --key=value form', () {
      expect(parseOptions(['--dish', 'doener', '--strict', '--count=5', '--lang', 'de']), {
        'dish': 'doener',
        'strict': 'true',
        'count': '5',
        'lang': 'de',
      });
    });

    test('a flag before another option reads as a bare flag', () {
      expect(parseOptions(['--dry-run', '--file', 'a.json']), {'dry-run': 'true', 'file': 'a.json'});
    });

    test('positional words are ignored, and a value may contain an equals sign', () {
      expect(parseOptions(['stray', '--query=a=b', 'more']), {'query': 'a=b'});
    });

    test('nothing gives nothing', () {
      expect(parseOptions(const []), isEmpty);
    });
  });

  group('CorpusFiles', () {
    void copy(String name) => File('assets/$name').copySync('${temp.path}/$name');

    test('a folder without an ontology cannot be loaded', () {
      expect(
        () => CorpusFiles(temp.path).load(),
        throwsA(isA<FileSystemException>().having((e) => e.path, 'path', contains('ontology.json'))),
      );
    });

    test('a folder without an ingredient dictionary cannot be loaded either', () {
      copy('ontology.json');
      expect(
        () => CorpusFiles(temp.path).load(),
        throwsA(isA<FileSystemException>().having((e) => e.path, 'path', contains('ingredients.json'))),
      );
    });

    test('recipes, dishes and the optional files may be missing', () {
      copy('ontology.json');
      copy('ingredients.json');
      final data = CorpusFiles(temp.path).load();
      expect(data.recipeMaps, isEmpty);
      expect(data.dishMaps, isEmpty);
      expect(data.manifestJson, isNull);
      expect(data.guideJson, isNull);
      expect(data.faqsJson, isNull);
    });

    test('the shipped folder loads completely', () {
      final data = const CorpusFiles('assets').load();
      expect(data.recipeMaps, hasLength(145));
      expect(data.dishMaps, hasLength(28));
      expect(data.manifestJson, isNotNull);
      expect(data.guideJson, isNotNull);
      expect(data.faqsJson, isNotNull);
    });

    test('writing the masters and reading them back round-trips, with a trailing newline', () {
      copy('ontology.json');
      copy('ingredients.json');
      final files = CorpusFiles(temp.path);
      final source = loadShippedCorpus();
      files.writeMasters(recipes: source.recipeMaps.take(3).toList(), dishes: source.dishMaps.take(2).toList());
      final back = files.load();
      expect(back.recipeMaps.map((r) => r['id']), source.recipeMaps.take(3).map((r) => r['id']));
      expect(back.dishMaps.map((d) => d['id']), source.dishMaps.take(2).map((d) => d['id']));
      expect(File('${temp.path}/recipes.json').readAsStringSync(), endsWith('}\n'));
      expect(jsonDecode(File('${temp.path}/recipes.json').readAsStringSync())['schema_version'], 1);
    });

    test('write creates missing folders', () {
      CorpusFiles(temp.path).write('search/core.json', '{}');
      expect(File('${temp.path}/search/core.json').readAsStringSync(), '{}\n');
    });
  });

  group('schemas', () {
    test('a missing schema is null, an existing one loads', () {
      expect(loadSchema(temp.path, 'recipe.schema.json'), isNull);
      expect(loadSchema('../pipeline/schemas', 'recipe.schema.json'), isNotNull);
    });

    test('the pipeline schemas load together, and a missing one is named', () {
      expect(loadSchemas().ontology, isNotNull);
      expect(
        () => loadPipelineSchemas(temp.path),
        throwsA(isA<FileSystemException>().having((e) => e.message, 'message', contains('Missing schema'))),
      );
    });

    test('the validator of the tools checks the ontology as well', () {
      final broken = loadShippedCorpus();
      final ontology = deepCopy(broken.ontologyJson);
      (ontology['flags'] as Map)['pork']['group'] = 'mystery';
      ontology.remove('aisles');
      final data = CorpusData(
        ontologyJson: ontology,
        ingredientsJson: broken.ingredientsJson,
        dishesJson: broken.dishesJson,
        recipesJson: {'recipes': <Object?>[]},
      );
      final issues = validatorFor(
        data,
        '../pipeline/schemas',
      ).validate().where((i) => i.where == 'ontology').map((i) => i.message).toList();
      expect(issues, contains(r'$: missing required "aisles"'));
      expect(issues.join('\n'), contains(r'$.flags.pork.group: "mystery" is not one of'));
    });

    test('the shipped ontology satisfies its schema', () {
      final data = loadShippedCorpus();
      expect(loadSchemas().ontology!.validate(data.ontologyJson), isEmpty);
    });
  });
}
