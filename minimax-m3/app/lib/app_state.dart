import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'backup/backup_service.dart';
import 'data/content_request_repository.dart';
import 'data/cookbook_repository.dart';
import 'data/faq_repository.dart';
import 'data/history_repository.dart';
import 'data/ingredient_guide_repository.dart';
import 'data/local_storage.dart';
import 'data/meal_plan_repository.dart';
import 'data/ontology_repository.dart';
import 'data/profile_repository.dart';
import 'data/recipe_repository.dart';
import 'data/shopping_list_repository.dart';

/// Application-wide singletons. We wire everything together once at boot and
/// pass it down via an InheritedWidget — keeps the dependency graph explicit
/// and lets tests inject fakes.
class AppState {
  AppState({
    required this.storage,
    required this.profileRepo,
    required this.recipeRepo,
    required this.ontologyRepo,
    required this.ingredientRepo,
    required this.ingredientGuideRepo,
    required this.faqRepo,
    required this.cookbookRepo,
    required this.historyRepo,
    required this.mealPlanRepo,
    required this.shoppingListRepo,
    required this.contentRequestRepo,
  }) {
    backupService = BackupService(
      profileRepo: profileRepo,
      cookbookRepo: cookbookRepo,
      historyRepo: historyRepo,
      mealPlanRepo: mealPlanRepo,
      contentRequestRepo: contentRequestRepo,
    );
  }

  final LocalStorage storage;
  final ProfileRepository profileRepo;
  final RecipeRepository recipeRepo;
  final OntologyRepository ontologyRepo;
  final IngredientRepository ingredientRepo;
  final IngredientGuideRepository ingredientGuideRepo;
  final FaqRepository faqRepo;
  final CookbookRepository cookbookRepo;
  final HistoryRepository historyRepo;
  final MealPlanRepository mealPlanRepo;
  final ShoppingListRepository shoppingListRepo;
  final ContentRequestRepository contentRequestRepo;
  late final BackupService backupService;

  static Future<AppState> bootstrap() async {
    final storage = await LocalStorage.instance();
    final results = await Future.wait([
      ProfileRepository.load(storage),
      RecipeRepository.load(),
      OntologyRepository.load(),
      IngredientRepository.load(),
      IngredientGuideRepository.load(),
      FaqRepository.load(),
      CookbookRepository.load(storage),
      HistoryRepository.load(storage),
      MealPlanRepository.load(storage),
      ShoppingListRepository.load(storage),
      ContentRequestRepository.load(storage),
    ]);

    return AppState(
      storage: storage,
      profileRepo: results[0] as ProfileRepository,
      recipeRepo: results[1] as RecipeRepository,
      ontologyRepo: results[2] as OntologyRepository,
      ingredientRepo: results[3] as IngredientRepository,
      ingredientGuideRepo: results[4] as IngredientGuideRepository,
      faqRepo: results[5] as FaqRepository,
      cookbookRepo: results[6] as CookbookRepository,
      historyRepo: results[7] as HistoryRepository,
      mealPlanRepo: results[8] as MealPlanRepository,
      shoppingListRepo: results[9] as ShoppingListRepository,
      contentRequestRepo: results[10] as ContentRequestRepository,
    );
  }
}

class AppScope extends InheritedWidget {
  final AppState state;

  const AppScope({super.key, required this.state, required super.child});

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in tree');
    return scope!.state;
  }

  @override
  bool updateShouldNotify(covariant AppScope oldWidget) =>
      oldWidget.state != state;
}

/// Re-renders descendants when any of the supplied [Listenable]s notify.
class MultiListenableBuilder extends StatefulWidget {
  final List<Listenable> listenables;
  final WidgetBuilder builder;

  const MultiListenableBuilder({
    super.key,
    required this.listenables,
    required this.builder,
  });

  @override
  State<MultiListenableBuilder> createState() => _MultiListenableBuilderState();
}

class _MultiListenableBuilderState extends State<MultiListenableBuilder> {
  late Listenable _merged;

  @override
  void initState() {
    super.initState();
    _merged = Listenable.merge(widget.listenables);
    _merged.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant MultiListenableBuilder old) {
    super.didUpdateWidget(old);
    if (!listEquals(old.listenables, widget.listenables)) {
      _merged.removeListener(_onChanged);
      _merged = Listenable.merge(widget.listenables);
      _merged.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _merged.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
