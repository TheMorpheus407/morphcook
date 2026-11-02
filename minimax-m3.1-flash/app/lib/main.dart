import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/data/corpus.dart';
import 'src/data/repositories.dart';
import 'src/design/fonts.dart';
import 'src/design/widgets/paper.dart';
import 'src/state/app_state.dart';
import 'src/state/cookbook_controller.dart';
import 'src/state/history_controller.dart';
import 'src/state/local_store.dart';
import 'src/state/meal_plan_controller.dart';
import 'src/state/profile_controller.dart';
import 'src/state/shopping_controller.dart';
import 'src/ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Typography is bundled, so warm the cache before the first frame — no
  // flash of fallback text, no network request.
  await Fonts.preload();
  await GrainTexture.load();

  final preferences = await SharedPreferences.getInstance();
  final store = await LocalStore.open();
  final corpus = await Corpus.load();
  final faqs = await FaqRepository.load();
  final guide = await IngredientGuideRepository.load();

  final state = AppState(
    corpus: corpus,
    faqs: faqs,
    ingredientGuide: guide,
    profile: ProfileController(preferences),
    cookbook: CookbookController(store),
    mealPlan: MealPlanController(store),
    shopping: ShoppingController(store),
    history: HistoryController(store),
    store: store,
  );

  runApp(MorphCookApp(state: state));
}
