import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/dish.dart';
import '../models/recipe.dart';
import '../models/ontology.dart';
import '../models/ingredient_dict.dart';
import '../models/faq.dart';

class CuisinePartition {
  final String id;
  final Map<String, String> name; // raw lang map (kept loose)
  final List<String> recipeIds;
  final List<String> dishIds;

  const CuisinePartition({
    required this.id,
    required this.name,
    required this.recipeIds,
    required this.dishIds,
  });
}

class Corpus {
  final Map<String, Dish> dishesById;
  final Map<String, Recipe> recipesById;
  final Ontology ontology;
  final IngredientDict ingredientDict;
  final Map<String, IngredientGuideEntry> guide;
  final List<FaqEntry> faqs;
  final List<CuisinePartition> cuisines;

  const Corpus({
    required this.dishesById,
    required this.recipesById,
    required this.ontology,
    required this.ingredientDict,
    required this.guide,
    required this.faqs,
    required this.cuisines,
  });

  List<Dish> get dishes => dishesById.values.toList();
  List<Recipe> get recipes => recipesById.values.toList();

  List<Recipe> variantsOf(String dishId) {
    final dish = dishesById[dishId];
    if (dish == null) return const [];
    return [
      for (final id in dish.variantIds)
        if (recipesById.containsKey(id)) recipesById[id]!,
    ];
  }

  Dish? dishOfRecipe(String recipeId) {
    final r = recipesById[recipeId];
    if (r == null) return null;
    return dishesById[r.dishId];
  }
}

class CorpusLoader {
  static Future<Corpus> load() async {
    final results = await Future.wait([
      rootBundle.loadString('assets/dishes.json'),
      rootBundle.loadString('assets/ontology.json'),
      rootBundle.loadString('assets/ingredients.json'),
      rootBundle.loadString('assets/ingredient-guide.json'),
      rootBundle.loadString('assets/faqs.json'),
      rootBundle.loadString('assets/core-recipes.json'),
      rootBundle.loadString('assets/extended-recipes.json'),
      rootBundle.loadString('assets/cuisine-italian.json'),
      rootBundle.loadString('assets/cuisine-asian.json'),
      rootBundle.loadString('assets/cuisine-middle-eastern.json'),
    ]);

    final dishesJson = json.decode(results[0]) as Map<String, dynamic>;
    final ontologyJson = json.decode(results[1]) as Map<String, dynamic>;
    final ingredientsJson = json.decode(results[2]) as Map<String, dynamic>;
    final guideJson = json.decode(results[3]) as Map<String, dynamic>;
    final faqsJson = json.decode(results[4]) as Map<String, dynamic>;
    final coreJson = json.decode(results[5]) as Map<String, dynamic>;
    final extJson = json.decode(results[6]) as Map<String, dynamic>;
    final italian = json.decode(results[7]) as Map<String, dynamic>;
    final asian = json.decode(results[8]) as Map<String, dynamic>;
    final me = json.decode(results[9]) as Map<String, dynamic>;

    final dishes = (dishesJson['dishes'] as List)
        .map((e) => Dish.fromJson(e as Map<String, dynamic>))
        .toList();
    final dishesById = {for (final d in dishes) d.id: d};

    final coreRecipes = (coreJson['recipes'] as List)
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>));
    final extRecipes = (extJson['recipes'] as List)
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>));
    final recipesById = <String, Recipe>{};
    for (final r in coreRecipes) {
      recipesById[r.id] = r;
    }
    for (final r in extRecipes) {
      recipesById[r.id] = r;
    }

    final ontology = Ontology.fromJson(ontologyJson);
    final dict = IngredientDict.fromJson(ingredientsJson);

    final guide = <String, IngredientGuideEntry>{};
    for (final e in (guideJson['entries'] as List)) {
      final entry = IngredientGuideEntry.fromJson(e as Map<String, dynamic>);
      guide[entry.ingredientId] = entry;
    }

    final faqs = (faqsJson['faqs'] as List)
        .map((e) => FaqEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    final cuisines = <CuisinePartition>[];
    for (final raw in [italian, asian, me]) {
      cuisines.add(CuisinePartition(
        id: raw['partition_id'] as String,
        name: ((raw['name'] as Map?)?.map((k, v) =>
                MapEntry(k.toString(), v.toString()))) ??
            const {},
        recipeIds: (raw['recipe_ids'] as List?)?.cast<String>() ?? const [],
        dishIds: (raw['dish_ids'] as List?)?.cast<String>() ?? const [],
      ));
    }

    debugPrint(
        '[corpus] dishes=${dishes.length} recipes=${recipesById.length} faqs=${faqs.length} cuisines=${cuisines.length}');

    return Corpus(
      dishesById: dishesById,
      recipesById: recipesById,
      ontology: ontology,
      ingredientDict: dict,
      guide: guide,
      faqs: faqs,
      cuisines: cuisines,
    );
  }
}
