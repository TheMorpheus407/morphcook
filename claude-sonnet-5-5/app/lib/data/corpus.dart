import 'asset_source.dart';
import 'models/dish.dart';
import 'models/faq.dart';
import 'models/ingredient.dart';
import 'models/ingredient_guide.dart';
import 'models/ontology.dart';
import 'models/partition_manifest.dart';
import 'models/recipe.dart';

/// The bundled recipe corpus.
///
/// Small files (manifest, dishes, ontology, ingredient dictionary) load up
/// front. Recipe partitions load through [ensurePartition]: the launch
/// partitions (`core`) before the first frame, everything else on demand.
class Corpus {
  Corpus._({
    required this.source,
    required this.manifest,
    required this.ontology,
    required this.ingredients,
    required this.dishes,
  }) {
    for (final dish in dishes.values) {
      for (final recipeId in dish.recipeIds) {
        _dishByRecipe[recipeId] = dish.id;
      }
    }
  }

  final AssetSource source;
  final PartitionManifest manifest;
  final Ontology ontology;
  final IngredientDictionary ingredients;

  /// All dishes in editorial order (a dish is light: no recipe bodies).
  final Map<String, Dish> dishes;

  final Map<String, String> _dishByRecipe = <String, String>{};
  final Map<String, Recipe> _recipes = <String, Recipe>{};
  final Map<String, Future<void>> _partitionLoads = <String, Future<void>>{};
  final Set<String> _loadedPartitions = <String>{};
  Future<FaqLibrary>? _faqs;
  Future<IngredientGuide>? _guide;

  static Future<Corpus> load(AssetSource source, {bool loadLaunchPartitions = true}) async {
    final manifest = PartitionManifest.fromJson(await source.loadJson('partition-manifest.json'));
    final ontology = Ontology.fromJson(await source.loadJson('ontology.json'));
    final ingredients = IngredientDictionary.fromJson(await source.loadJson('ingredients.json'));
    final dishJson = await source.loadJson('dishes.json');
    final dishes = <String, Dish>{
      for (final d in (dishJson['dishes'] as List))
        (d as Map)['id'] as String: Dish.fromJson(d.cast<String, dynamic>()),
    };
    final corpus = Corpus._(
      source: source,
      manifest: manifest,
      ontology: ontology,
      ingredients: ingredients,
      dishes: dishes,
    );
    if (loadLaunchPartitions) {
      for (final id in manifest.launchOrder) {
        await corpus.ensurePartition(id);
      }
    }
    return corpus;
  }

  bool isPartitionLoaded(String id) => _loadedPartitions.contains(id);

  /// Loads a recipe partition once; concurrent callers share the same future.
  Future<void> ensurePartition(String id) {
    if (_loadedPartitions.contains(id)) return Future<void>.value();
    return _partitionLoads.putIfAbsent(id, () async {
      final info = manifest.partition(id);
      if (info == null) throw StateError('Unknown partition "$id"');
      final json = await source.loadJson(info.file);
      for (final r in (json['recipes'] as List)) {
        final recipe = Recipe.fromJson((r as Map).cast<String, dynamic>());
        _recipes[recipe.id] = recipe;
      }
      _loadedPartitions.add(id);
    });
  }

  Dish? dish(String id) => dishes[id];

  Dish? dishOfRecipe(String recipeId) {
    final id = _dishByRecipe[recipeId];
    return id == null ? null : dishes[id];
  }

  /// A recipe that is already in memory.
  Recipe? recipeSync(String id) => _recipes[id];

  Future<Recipe?> loadRecipe(String id) async {
    final dish = dishOfRecipe(id);
    if (dish == null) return null;
    await ensurePartition(dish.partitionId);
    return _recipes[id];
  }

  /// Every variant of [dishId], loading its partition when needed.
  Future<List<Recipe>> loadDish(String dishId) async {
    final dish = dishes[dishId];
    if (dish == null) return const <Recipe>[];
    await ensurePartition(dish.partitionId);
    return recipesOfDishSync(dishId);
  }

  /// Variants of [dishId] that are currently in memory.
  List<Recipe> recipesOfDishSync(String dishId) {
    final dish = dishes[dishId];
    if (dish == null) return const <Recipe>[];
    return [
      for (final id in dish.recipeIds)
        if (_recipes[id] != null) _recipes[id]!,
    ];
  }

  Iterable<Recipe> get loadedRecipes => _recipes.values;

  /// Dishes stored in, or cross-referenced from, a partition (discovery).
  List<Dish> dishesInPartition(String partitionId) {
    final referenced = manifest.crossReferences[partitionId] ?? const <String>[];
    return [
      for (final dish in dishes.values)
        if (dish.partitionId == partitionId || referenced.contains(dish.id)) dish,
    ];
  }

  List<Dish> dishesInCuisine(String cuisine) => [
    for (final dish in dishes.values)
      if (dish.cuisineTags.contains(cuisine)) dish,
  ];

  Future<FaqLibrary> faqs() => _faqs ??= source.loadJson('faqs.json').then(FaqLibrary.fromJson);

  Future<IngredientGuide> guide() => _guide ??= source.loadJson('ingredient-guide.json').then(IngredientGuide.fromJson);
}
