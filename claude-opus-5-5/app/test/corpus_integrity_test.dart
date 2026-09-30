import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/localized.dart';

import 'support.dart';

/// Quality gates from the spec, run against the shipped assets.
void main() {
  final c = Corpus.instance;
  const langs = ['en', 'de'];

  void bilingual(LText t, String where) {
    for (final l in langs) {
      expect(t.values[l]?.trim(), isNotEmpty, reason: '$where missing $l');
    }
  }

  test('corpus is a meaningful size', () {
    expect(c.dishes.length, greaterThanOrEqualTo(15));
    expect(c.recipes.length, greaterThanOrEqualTo(55));
    for (final d in c.dishes.values) {
      expect(d.variants.length, greaterThanOrEqualTo(3), reason: d.id);
    }
  });

  test('every dish variant exists and links back to its dish', () {
    for (final d in c.dishes.values) {
      for (final id in d.variants) {
        expect(c.recipes[id], isNotNull, reason: '${d.id} → $id');
        expect(c.recipes[id]!.dishId, d.id);
        expect(c.recipes[id]!.partitionId, d.partitionId, reason: id);
      }
    }
    expect(c.dishes.values.expand((d) => d.variants).length, c.recipes.length);
  });

  test('all flags exist in the ontology', () {
    for (final r in c.recipes.values) {
      for (final f in r.contains) {
        expect(c.ontology.flagParents.containsKey(f), isTrue, reason: '${r.id}: $f');
      }
    }
    for (final n in c.tree.nodes.values) {
      for (final f in n.flags) {
        expect(c.ontology.flagParents.containsKey(f), isTrue, reason: '${n.id}: $f');
      }
    }
    for (final comp in c.ontology.compounds.values) {
      for (final f in comp) {
        expect(c.ontology.isKnownFlag(f), isTrue, reason: f);
      }
    }
  });

  test('recipe.contains ⊇ flags derivable from its ingredients', () {
    for (final r in c.recipes.values) {
      final derived = <String>{};
      for (final id in r.ingredientIds) {
        for (final n in c.tree.pathOf(id)) {
          derived.addAll(n.flags);
        }
      }
      final withAncestors = c.ontology.withAncestors(derived);
      expect(
        r.contains.containsAll(withAncestors),
        isTrue,
        reason: '${r.id} missing ${withAncestors.difference(r.contains)}',
      );
    }
  });

  test('no vegan-labelled recipe contains animal products (vegan + honey etc.)', () {
    final animal = c.ontology.expandAvoidFlags({'vegan'});
    for (final r in c.recipes.values.where((r) => r.diet == 'vegan')) {
      expect(r.contains.intersection(animal), isEmpty, reason: r.id);
    }
    for (final r in c.recipes.values.where((r) => r.diet == 'gluten-free')) {
      expect(r.contains, isNot(contains('gluten')), reason: r.id);
    }
    for (final r in c.recipes.values.where((r) => r.diet == 'halal')) {
      expect(r.contains.intersection(c.ontology.expandAvoidFlags({'halal'})), isEmpty, reason: r.id);
    }
    for (final r in c.recipes.values.where((r) => r.diet == 'nut-free')) {
      expect(r.contains.intersection({'tree-nuts', 'peanuts'}), isEmpty, reason: r.id);
    }
    for (final r in c.recipes.values.where((r) => r.diet == 'sugar-free')) {
      expect(r.contains, isNot(contains('added-sugar')), reason: r.id);
    }
    for (final r in c.recipes.values.where((r) => r.diet == 'low-fodmap')) {
      expect(r.contains, isNot(contains('high-fodmap')), reason: r.id);
    }
  });

  test('ingredients and units resolve', () {
    for (final r in c.recipes.values) {
      for (final i in r.ingredients) {
        expect(c.tree[i.id], isNotNull, reason: '${r.id}: ${i.id}');
        expect(c.ontology.units[i.unit], isNotNull, reason: '${r.id}: ${i.unit}');
      }
    }
  });

  test('variant dimension tuples are unique within each dish', () {
    for (final d in c.dishes.values) {
      final tuples = c.variants(d.id).map((r) => c.ontology.dimensions.map((dim) => r.dimension(dim.id)).join('|'));
      expect(tuples.toSet().length, d.variants.length, reason: d.id);
    }
  });

  test('all user-visible corpus text exists in EN and DE', () {
    for (final d in c.dishes.values) {
      bilingual(d.name, '${d.id}.name');
      bilingual(d.hero, '${d.id}.hero');
      bilingual(d.caption, '${d.id}.caption');
    }
    for (final r in c.recipes.values) {
      bilingual(r.title, '${r.id}.title');
      bilingual(r.blurb, '${r.id}.blurb');
      bilingual(r.note, '${r.id}.note');
      for (var i = 0; i < r.steps.length; i++) {
        bilingual(r.steps[i].text, '${r.id}.steps[$i]');
      }
      for (final t in r.tags) {
        bilingual(t, '${r.id}.tag');
      }
    }
    for (final n in c.tree.nodes.values) {
      bilingual(n.name, 'ingredient ${n.id}');
    }
    for (final e in c.faqs.entries) {
      bilingual(e.question, 'faq ${e.id}');
      bilingual(e.answer, 'faq ${e.id}');
    }
  });

  test('FAQ: categories exist, related links resolve', () {
    final cats = c.faqs.categories.map((c) => c.id).toSet();
    for (final e in c.faqs.entries) {
      expect(cats, contains(e.category), reason: e.id);
      for (final r in e.related) {
        expect(c.faqs.byId(r), isNotNull, reason: '${e.id} → $r');
      }
    }
    // contextual links used by the UI
    for (final id in [
      'how-matching-works',
      'variant-switchers',
      'unreachable-combo',
      'halal-kosher',
      'search-empty',
      'backup',
      'calorie-target',
      'cook-mode',
      'class-vs-specific',
    ]) {
      expect(c.faqs.byId(id), isNotNull, reason: id);
    }
    expect(c.faqs.search('halal', lang: 'en').first.id, 'halal-kosher');
    expect(c.faqs.search('passwort', lang: 'de').map((e) => e.id), contains('backup'));
    expect(c.faqs.search('', category: 'privacy', lang: 'en').every((e) => e.category == 'privacy'), isTrue);
  });

  test('ingredient guide entries point at real ingredients, EN+DE', () {
    expect(c.guide.length, greaterThanOrEqualTo(20));
    for (final id in c.tree.nodes.keys) {
      final g = c.guide[id];
      if (g == null) continue;
      bilingual(g.description, 'guide $id');
      bilingual(g.usage, 'guide $id');
      bilingual(g.storage, 'guide $id');
      bilingual(g.whereToFind, 'guide $id');
    }
  });

  test('partition manifest matches the partition files', () {
    final parts = c.manifest['partitions'] as List;
    expect(
      parts.map((p) => p['id']),
      containsAll(['core', 'extended', 'cuisine-italian', 'cuisine-asian', 'cuisine-middle-eastern']),
    );
    expect(parts.where((p) => p['load'] == 'eager').map((p) => p['id']), ['core']);
    for (final p in parts) {
      final n = c.recipes.values.where((r) => r.partitionId == p['id']).length;
      expect(p['recipe_count'], n, reason: p['id'] as String);
      expect(File(p['file'] as String).existsSync(), isTrue);
    }
    // core carries the majority of recipes ("top 80%" by usage tier)
    final core = c.recipes.values.where((r) => r.partitionId == 'core').length;
    expect(core / c.recipes.length, greaterThan(0.4));
    for (final d in c.dishes.values) {
      expect(d.cuisineTags, isNotEmpty);
      expect(['high', 'medium', 'low'], contains(d.frequencyTier));
    }
  });

  test('specific-avoidance examples from the spec exist in the dictionary', () {
    for (final id in [
      'apples',
      'cilantro',
      'bell-pepper',
      'dairy',
      'cow-milk',
      'whole-milk',
      'skim-milk',
      'goat-milk',
      'cheese',
      'parmesan',
      'feta',
      'nuts',
      'tree-nuts',
      'walnuts',
      'almonds',
      'pistachios',
      'peanuts',
    ]) {
      expect(c.tree[id], isNotNull, reason: id);
    }
    expect(c.tree.descendantsOf('dairy'), containsAll(['whole-milk', 'parmesan', 'feta']));
    expect(c.tree.descendantsOf('nuts'), containsAll(['walnuts', 'almonds', 'pistachios', 'peanuts']));
    expect(c.tree.search('apple', 'de').map((n) => n.id), contains('apples'));
    expect(c.tree.search('kori', 'de').first.id, 'cilantro');
  });

  test('halal/kosher are compound flags and certification-sensitive', () {
    expect(c.ontology.certificationSensitive, {'halal', 'kosher'});
    expect(c.ontology.compoundLabels['halal']!.of('en'), contains('compatible'));
  });
}
