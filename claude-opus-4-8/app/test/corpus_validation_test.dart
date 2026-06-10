import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/localized.dart';
import 'package:morphcook/data/corpus.dart';
import 'package:morphcook/logic/matching.dart' as mm;
import 'package:morphcook/models/profile.dart';

/// Loads the actual bundled corpus and applies the SPEC's "quality gates" to
/// the shipped data: schema integrity, ontology validity, flag↔ingredient
/// cross-checks, and dish/partition resolution.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Corpus corpus;

  setUpAll(() async {
    corpus = await Corpus.load();
  });

  test('loads dishes and recipes', () {
    expect(corpus.dishes.length, 10);
    expect(corpus.recipes.length, 26);
  });

  test('every dish variant resolves and back-references its dish', () {
    for (final dish in corpus.dishes) {
      expect(dish.variantRecipeIds, isNotEmpty);
      for (final rid in dish.variantRecipeIds) {
        final r = corpus.recipe(rid);
        expect(r, isNotNull, reason: 'missing recipe $rid for dish ${dish.id}');
        expect(r!.dishId, dish.id);
      }
    }
  });

  test('all recipe contains-flags exist in the ontology', () {
    final flagIds = corpus.ontology.containsFlags.map((f) => f.id).toSet();
    for (final r in corpus.recipes) {
      for (final c in r.contains) {
        expect(flagIds.contains(c), isTrue,
            reason: '${r.id} has unknown flag $c');
      }
    }
  });

  test('all recipe ingredient ids exist in the dictionary', () {
    for (final r in corpus.recipes) {
      for (final ing in r.ingredients) {
        expect(corpus.ingredients.node(ing.ingredientId), isNotNull,
            reason: '${r.id} uses unknown ingredient ${ing.ingredientId}');
      }
    }
  });

  test('every recipe has exactly one effort/time/calorie bucket', () {
    final effort = corpus.ontology.effort.map((e) => e.id).toSet();
    final timeB = corpus.ontology.timeBuckets.map((e) => e.id).toSet();
    final calB = corpus.ontology.calorieBuckets.map((e) => e.id).toSet();
    for (final r in corpus.recipes) {
      expect(r.attributes.where(effort.contains).length, 1, reason: r.id);
      expect(r.attributes.where(timeB.contains).length, 1, reason: r.id);
      expect(r.attributes.where(calB.contains).length, 1, reason: r.id);
    }
  });

  test('time and calorie buckets match the numeric values', () {
    String fitting(List buckets, int value) {
      for (final b in buckets) {
        if (value <= b.max) return b.id as String;
      }
      return (buckets.last).id as String;
    }

    for (final r in corpus.recipes) {
      final expectedTime = fitting(corpus.ontology.timeBuckets, r.timeMinutes);
      final expectedCal = fitting(corpus.ontology.calorieBuckets, r.calories);
      expect(r.attributes.contains(expectedTime), isTrue,
          reason: '${r.id}: time ${r.timeMinutes} should bucket $expectedTime');
      expect(r.attributes.contains(expectedCal), isTrue,
          reason: '${r.id}: ${r.calories}kcal should bucket $expectedCal');
    }
  });

  test('bilingual steps align and timers match step count', () {
    for (final r in corpus.recipes) {
      final en = r.steps['en'];
      final de = r.steps['de'];
      expect(en, isNotNull, reason: r.id);
      expect(de, isNotNull, reason: r.id);
      expect(en!.length, de!.length, reason: '${r.id} step count mismatch');
      expect(r.stepTimers.length, en.length, reason: '${r.id} timer count');
    }
  });

  test('variant_axes diet values exist in the diet axis', () {
    final dietAxis = corpus.ontology.axis('diet')!;
    final dietValues = dietAxis.values.map((v) => v.id).toSet();
    for (final r in corpus.recipes) {
      final diet = r.variantAxes['diet'];
      if (diet != null) {
        expect(dietValues.contains(diet), isTrue,
            reason: '${r.id} unknown diet $diet');
      }
    }
  });

  test('vegan diet integrity: no animal flags present', () {
    const animal = {
      'pork', 'beef', 'lamb', 'poultry', 'fish', 'shellfish', 'molluscs',
      'egg', 'dairy', 'honey', 'gelatin-non-halal', 'gelatin-non-kosher'
    };
    for (final r in corpus.recipes) {
      if (r.variantAxes['diet'] == 'vegan') {
        expect(r.contains.intersection(animal), isEmpty,
            reason: '${r.id} is vegan but contains ${r.contains.intersection(animal)}');
      }
    }
  });

  test('halal diet integrity: no pork/alcohol/non-halal gelatin', () {
    for (final r in corpus.recipes) {
      if (r.variantAxes['diet'] == 'halal') {
        expect(r.contains.intersection({'pork', 'alcohol', 'gelatin-non-halal'}),
            isEmpty,
            reason: '${r.id} halal violation');
      }
    }
  });

  test('cross-reference partitions resolve to real recipes', () {
    for (final entry in corpus.manifest.crossReferences.entries) {
      for (final rid in entry.value) {
        expect(corpus.recipe(rid), isNotNull,
            reason: '${entry.key} references missing $rid');
      }
    }
  });

  test('FAQ and ingredient guide loaded', () {
    expect(corpus.faqs.length, greaterThanOrEqualTo(14));
    expect(corpus.faqCategories, isNotEmpty);
    expect(corpus.guide.length, greaterThanOrEqualTo(10));
    // guide ingredient ids should exist in the dictionary
    for (final g in corpus.guide) {
      expect(corpus.ingredients.node(g.ingredientId), isNotNull,
          reason: 'guide for unknown ${g.ingredientId}');
    }
  });

  test('a vegan profile hides every dairy recipe and shows a vegan doener', () {
    final matcher = mm.Matcher(ontology: corpus.ontology, dict: corpus.ingredients)
        .forProfile(const Profile(avoidFlags: {'vegan'}));
    final doenerVegan = corpus.recipe('doener-vegan');
    expect(doenerVegan, isNotNull);
    expect(matcher.isVisible(doenerVegan!), isTrue);
    for (final r in corpus.recipes) {
      if (r.contains.contains('dairy')) {
        expect(matcher.isVisible(r), isFalse, reason: '${r.id} should be hidden');
      }
    }
  });

  test('localized text resolves in both languages', () {
    final d = corpus.dishes.first;
    expect(d.name.resolve(AppLang.en), isNotEmpty);
    expect(d.name.resolve(AppLang.de), isNotEmpty);
  });
}
