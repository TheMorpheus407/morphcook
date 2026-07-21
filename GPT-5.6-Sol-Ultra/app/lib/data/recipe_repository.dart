import '../domain/domain.dart';

abstract interface class RecipeRepository {
  Future<void> initialize({bool loadExtended = false});

  bool get isInitialized;
  List<Dish> get dishes;
  List<Recipe> get recipes;
  Map<String, Dish> get dishesById;
  Map<String, Recipe> get recipesById;
  Ontology get ontology;
  IngredientDictionary get ingredients;
  List<IngredientGuideEntry> get ingredientGuideEntries;
  List<FaqEntry> get faqs;
  PartitionManifest get manifest;

  Dish? dishById(String id);
  Recipe? recipeById(String id);
  List<Recipe> recipesForDish(String dishId);
  Future<List<Recipe>> loadRecipesForDish(String dishId);
  Future<void> ensurePartitionLoaded(String partitionId);

  List<Recipe> visibleRecipes(
    UserProfile profile, {
    String? ignoreCaloriesForDishId,
  });

  List<RankedRecipe> rankedRecipes(
    UserProfile profile, {
    DateTime? now,
    Iterable<CookHistoryEntry> history = const [],
    String? ignoreCaloriesForDishId,
  });

  Future<SearchPage> search(SearchQuery query, UserProfile profile);
}
