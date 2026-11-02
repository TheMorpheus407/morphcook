import 'package:flutter/foundation.dart';

import '../data/corpus.dart';
import '../data/repositories.dart';
import '../domain/matching.dart';
import '../l10n/strings.dart';
import '../models/recipe.dart';
import 'cookbook_controller.dart';
import 'history_controller.dart';
import 'local_store.dart';
import 'meal_plan_controller.dart';
import 'profile_controller.dart';
import 'shopping_controller.dart';

/// The root of the app's state.
///
/// Everything the app knows lives here: the bundled corpus, the repositories
/// that read it, the matcher, and the user's own collections.
class AppState extends ChangeNotifier {
  AppState({
    required this.corpus,
    required this.faqs,
    required this.ingredientGuide,
    required this.profile,
    required this.cookbook,
    required this.mealPlan,
    required this.shopping,
    required this.history,
    required this.store,
  }) : matcher = RecipeMatcher(
          ontology: corpus.ontology,
          ingredients: corpus.ingredients,
        );

  final Corpus corpus;
  final FaqRepository faqs;
  final IngredientGuideRepository ingredientGuide;

  final ProfileController profile;
  final CookbookController cookbook;
  final MealPlanController mealPlan;
  final ShoppingController shopping;
  final HistoryController history;

  /// The on-device collection store.
  final KeyValueStore store;

  final RecipeMatcher matcher;

  String get lang => profile.lang;

  Strings get strings => Strings(lang);

  /// The recipes the user can currently see, across the whole corpus.
  List<Recipe> visibleRecipes() {
    final current = profile.profile;
    return corpus.allRecipes
        .where((recipe) => matcher.isVisible(recipe, current))
        .toList();
  }
}
