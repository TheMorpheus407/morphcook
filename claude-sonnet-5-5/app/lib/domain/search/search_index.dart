import '../../core/i18n/localized_text.dart';
import '../../core/text/text_fold.dart';
import '../../data/models/dish.dart';
import '../../data/models/ingredient.dart';
import '../../data/models/ontology.dart';
import '../../data/models/recipe.dart';

/// Search tokens of one recipe in one language, split by field so titles
/// outrank tags and tags outrank ingredients.
class EntryTokens {
  const EntryTokens({required this.title, required this.tags, required this.ingredients});

  final Set<String> title;
  final Set<String> tags;
  final Set<String> ingredients;

  factory EntryTokens.fromJson(Map<String, dynamic> json) => EntryTokens(
    title: (json['t'] as List).map((e) => e.toString()).toSet(),
    tags: (json['g'] as List).map((e) => e.toString()).toSet(),
    ingredients: (json['i'] as List).map((e) => e.toString()).toSet(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    't': title.toList()..sort(),
    'g': tags.toList()..sort(),
    'i': ingredients.toList()..sort(),
  };
}

/// One recipe in the bundled search index: just enough to match, filter by
/// profile, rank and render a result row without loading the recipe partition.
class IndexEntry implements RecipeMeta {
  const IndexEntry({
    required this.id,
    required this.dishId,
    required this.title,
    required this.diet,
    required this.effort,
    required this.timeMinutes,
    required this.caloriesPerServing,
    required this.contains,
    required this.ingredientIds,
    required this.attributes,
    required this.meal,
    required this.tokens,
  });

  @override
  final String id;
  @override
  final String dishId;
  final LocalizedText title;
  final String diet;
  @override
  final String effort;
  @override
  final int timeMinutes;
  @override
  final int caloriesPerServing;
  @override
  final Set<String> contains;
  @override
  final Set<String> ingredientIds;
  @override
  final Set<String> attributes;
  @override
  final List<String> meal;
  final Map<String, EntryTokens> tokens;

  factory IndexEntry.fromJson(Map<String, dynamic> json) => IndexEntry(
    id: json['r'] as String,
    dishId: json['d'] as String,
    title: LocalizedText.fromJson(json['t']),
    diet: json['diet'] as String,
    effort: json['e'] as String,
    timeMinutes: (json['m'] as num).toInt(),
    caloriesPerServing: (json['k'] as num).toInt(),
    contains: (json['c'] as List).map((e) => e.toString()).toSet(),
    ingredientIds: (json['i'] as List).map((e) => e.toString()).toSet(),
    attributes: (json['a'] as List).map((e) => e.toString()).toSet(),
    meal: (json['ml'] as List).map((e) => e.toString()).toList(),
    tokens: {
      for (final e in (json['tok'] as Map).entries)
        e.key.toString(): EntryTokens.fromJson((e.value as Map).cast<String, dynamic>()),
    },
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'r': id,
    'd': dishId,
    't': title.toJson(),
    'diet': diet,
    'e': effort,
    'm': timeMinutes,
    'k': caloriesPerServing,
    'c': contains.toList()..sort(),
    'i': ingredientIds.toList()..sort(),
    'a': attributes.toList()..sort(),
    'ml': meal,
    'tok': {for (final e in tokens.entries) e.key: e.value.toJson()},
  };
}

/// Generates the per-partition search index chunks at build time
/// (`dart run tool/corpus_tool.dart build`).
class SearchIndexBuilder {
  const SearchIndexBuilder({required this.ontology, required this.ingredients, required this.dishes});

  final Ontology ontology;
  final IngredientDictionary ingredients;
  final Map<String, Dish> dishes;

  IndexEntry entryFor(Recipe recipe) {
    final dish = dishes[recipe.dishId]!;
    final tokens = <String, EntryTokens>{};
    for (final language in ontology.languages) {
      final lang = language.code;
      final title = <String>{
        ...TextFold.tokens(recipe.title.resolve(lang)),
        ...TextFold.tokens(dish.name.resolve(lang)),
        ...TextFold.tokens(dish.id),
      };

      final tagIds = <String>{recipe.diet, recipe.effort, ...recipe.techniques, ...recipe.tags, ...recipe.attributes};
      final tags = <String>{};
      for (final id in tagIds) {
        tags.addAll(TextFold.tokens(id));
        tags.addAll(TextFold.tokens(ontology.label(id, lang)));
      }
      for (final cuisine in dish.cuisineTags) {
        tags.addAll(TextFold.tokens(ontology.label(cuisine, lang)));
        tags.addAll(TextFold.tokens(cuisine));
      }
      for (final meal in recipe.meal) {
        tags.addAll(TextFold.tokens(ontology.label(meal, lang)));
      }

      final ingredientTokens = <String>{};
      for (final id in recipe.ingredientIds) {
        ingredientTokens.addAll(ingredients.tokensOf(id, lang));
        for (final ancestor in ingredients.ancestorsOf(id)) {
          ingredientTokens.addAll(ingredients.tokensOf(ancestor, lang));
        }
      }
      tokens[lang] = EntryTokens(title: title, tags: tags, ingredients: ingredientTokens);
    }
    return IndexEntry(
      id: recipe.id,
      dishId: recipe.dishId,
      title: recipe.title,
      diet: recipe.diet,
      effort: recipe.effort,
      timeMinutes: recipe.timeMinutes,
      caloriesPerServing: recipe.caloriesPerServing,
      contains: recipe.contains,
      ingredientIds: recipe.ingredientIds,
      attributes: recipe.attributes,
      meal: recipe.meal,
      tokens: tokens,
    );
  }

  /// The JSON of one chunk file, entries in recipe order.
  Map<String, dynamic> buildChunk(String partitionId, Iterable<Recipe> recipes) => <String, dynamic>{
    'partition': partitionId,
    'schema_version': 1,
    'entries': [for (final r in recipes) entryFor(r).toJson()],
  };
}
