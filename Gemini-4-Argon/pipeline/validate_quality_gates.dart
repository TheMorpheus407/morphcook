import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  String dishFilter = 'all';
  int sampleCount = 2;
  for (int i = 0; i < args.length - 1; i++) {
    if (args[i] == '--dish') dishFilter = args[i + 1];
    if (args[i] == '--sample') sampleCount = int.tryParse(args[i + 1]) ?? 2;
  }

  final ontology = jsonDecode(File('app/assets/ontology.json').readAsStringSync())
      as Map<String, dynamic>;
  final validContains =
      (ontology['contains_flags'] as Map<String, dynamic>).keys.toSet();

  final ingredientsJson =
      jsonDecode(File('app/assets/ingredients.json').readAsStringSync())
          as Map<String, dynamic>;
  final validIngredients = <String>{};
  void visit(List<dynamic> nodes) {
    for (final n in nodes) {
      final m = n as Map<String, dynamic>;
      validIngredients.add(m['id'] as String);
      visit(m['children'] as List<dynamic>? ?? []);
    }
  }
  visit(ingredientsJson['tree'] as List<dynamic>);

  final recipesJson =
      jsonDecode(File('app/assets/recipes.json').readAsStringSync())
          as Map<String, dynamic>;
  final recipes = (recipesJson['recipes'] as List<dynamic>)
      .cast<Map<String, dynamic>>();

  // Quality Gate 1 & 2: Schema & Ontology Validation
  for (final r in recipes) {
    final id = r['id'] as String;
    if (dishFilter != 'all' && r['dish_id'] != dishFilter) continue;

    for (final reqKey in [
      'id',
      'dish_id',
      'title',
      'diet_dimension',
      'effort',
      'time_minutes',
      'calories_per_serving',
      'contains',
      'attributes',
      'ingredient_ids',
      'ingredients',
      'steps',
    ]) {
      if (!r.containsKey(reqKey)) {
        throw StateError('Quality Gate Failed: Recipe $id missing $reqKey');
      }
    }

    final contains = (r['contains'] as List<dynamic>).cast<String>().toSet();
    for (final flag in contains) {
      if (!validContains.contains(flag)) {
        throw StateError('Ontology Gate Failed: $id has unknown flag $flag');
      }
    }

    // Quality Gate 3: Cross-check contains flags vs contradictions (e.g. vegan + honey/dairy/meat)
    if (r['diet_dimension'] == 'vegan') {
      const forbiddenVegan = {
        'pork', 'beef', 'lamb', 'poultry', 'fish', 'shellfish',
        'egg', 'dairy', 'lactose', 'honey', 'gelatin'
      };
      final intersection = contains.intersection(forbiddenVegan);
      if (intersection.isNotEmpty) {
        throw StateError(
          'Contradiction Gate Failed: Vegan recipe $id contains $intersection',
        );
      }
    }
  }

  // Quality Gate 4: Duplicate detection across variants of the same dish
  final byDish = <String, List<Map<String, dynamic>>>{};
  for (final r in recipes) {
    byDish.putIfAbsent(r['dish_id'] as String, () => []).add(r);
  }
  for (final entry in byDish.entries) {
    final variants = entry.value;
    for (int i = 0; i < variants.length; i++) {
      for (int j = i + 1; j < variants.length; j++) {
        final a = (variants[i]['ingredient_ids'] as List<dynamic>).toSet();
        final b = (variants[j]['ingredient_ids'] as List<dynamic>).toSet();
        final jaccard = a.intersection(b).length / a.union(b).length;
        if (jaccard > 0.95 &&
            variants[i]['diet_dimension'] == variants[j]['diet_dimension']) {
          throw StateError(
            'Duplicate Gate Failed: ${variants[i]['id']} and ${variants[j]['id']} are near-duplicates',
          );
        }
      }
    }
  }

  stdout.writeln('[PASS] Quality Gates 1-4: Schema, Ontology, Flag Cross-Check & Duplicate Detection passed.');
  stdout.writeln('[SPOT-CHECK] Outputting sample of $sampleCount recipes:');
  for (final sample in recipes.take(sampleCount)) {
    stdout.writeln('  - ${sample['id']}: ${(sample['title'] as Map)['en']} (${sample['calories_per_serving']} kcal)');
  }
}
