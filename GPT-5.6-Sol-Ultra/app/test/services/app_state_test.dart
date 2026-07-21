import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/domain/models.dart';
import 'package:morphcook/services/app_state.dart';
import 'package:morphcook/services/local_store.dart';
import 'package:morphcook/services/profile_store.dart';
import 'package:morphcook/services/shopping_service.dart';

void main() {
  test(
    'orchestrates profile, saved, history, meal plan and requests',
    () async {
      var id = 0;
      final profileStore = MemoryProfileStore();
      final localStore = MemoryLocalApplicationStore();
      final state = AppState(
        profileStore: profileStore,
        localStore: localStore,
        idGenerator: () => 'id-${id++}',
      );

      await state.initialize();
      expect(state.isInitialized, isTrue);
      expect(state.needsOnboarding, isTrue);

      final profile = UserProfile(name: 'Mira', languageCode: 'de');
      await state.completeOnboarding(profile);
      expect(state.profile, profile);
      expect(state.needsOnboarding, isFalse);

      expect(await state.toggleSaved('recipe-a'), isTrue);
      expect(state.savedRecipeIds, <String>{'recipe-a'});
      expect(await state.toggleSaved('recipe-a'), isFalse);
      expect(state.savedRecipeIds, isEmpty);

      final cooked = await state.recordCooked(
        'recipe-a',
        servings: 2,
        cookedAt: DateTime.utc(2026, 4, 18),
      );
      expect(cooked.id, 'id-0');
      expect(state.cookingHistory.single.recipeId, 'recipe-a');

      final monday = DateTime(2026, 4, 13);
      await state.assignMealPlanSlot(
        date: monday,
        slot: MealSlot.dinner,
        recipeId: 'recipe-a',
      );
      expect(state.mealPlan.at(monday, MealSlot.dinner)!.recipeId, 'recipe-a');
      await state.moveMealPlanSlot(
        fromDate: monday,
        fromSlot: MealSlot.dinner,
        toDate: monday.add(const Duration(days: 1)),
        toSlot: MealSlot.lunch,
      );
      expect(state.mealPlan.at(monday, MealSlot.dinner), isNull);
      expect(
        state.mealPlan
            .at(monday.add(const Duration(days: 1)), MealSlot.lunch)!
            .recipeId,
        'recipe-a',
      );

      await state.logContentRequest('sushi');
      expect(state.contentRequests.single.languageCode, 'de');
      expect(state.contentRequests.single.normalizedQuery, 'sushi');
      state.dispose();
    },
  );

  test(
    'aggregates and checks shopping entries through the local store',
    () async {
      final state = AppState(
        profileStore: MemoryProfileStore(profile: UserProfile(name: 'Mira')),
        localStore: MemoryLocalApplicationStore(),
      );
      await state.initialize();

      await state.addShoppingIngredients(const <ShoppingIngredientInput>[
        ShoppingIngredientInput(
          ingredientId: 'garlic',
          name: 'Garlic',
          quantity: 2,
          unit: 'clove',
          aisle: 'produce',
        ),
        ShoppingIngredientInput(
          ingredientId: 'garlic',
          name: 'Garlic',
          quantity: 3,
          unit: 'cloves',
          aisle: 'produce',
        ),
      ]);
      expect(state.shoppingEntries.single.quantity, 5);

      final id = state.shoppingEntries.single.id;
      await state.setShoppingChecked(id, true);
      expect(state.shoppingEntries.single.isChecked, isTrue);
      await state.clearCheckedShoppingEntries();
      expect(state.shoppingEntries, isEmpty);
      expect(state.shoppingInsights.varietyScore, 1);
      expect(state.shoppingInsights.topIngredients['Garlic'], 2);
      state.dispose();
    },
  );

  test(
    'persists quick-next and applies system reduce-motion fallback',
    () async {
      final profileStore = MemoryProfileStore(
        profile: UserProfile(name: 'Mira', reduceMotion: null),
      );
      final state = AppState(
        profileStore: profileStore,
        localStore: MemoryLocalApplicationStore(),
      );
      await state.initialize();
      await state.setQuickNextTapEnabled(true);
      expect(state.settings.quickNextTapEnabled, isTrue);
      expect((await profileStore.loadSettings()).quickNextTapEnabled, isTrue);

      final controllers = await state.createCookModeControllers(
        _recipe(),
        systemReduceMotion: true,
      );
      expect(controllers.session.reduceMotion, isTrue);
      expect(controllers.oneHanded.quickNextTapEnabled, isTrue);
      expect(controllers.oneHanded.transitionDuration, Duration.zero);
      controllers.dispose();
      state.dispose();
    },
  );

  test('reset clears all user-owned state', () async {
    final state = AppState(
      profileStore: MemoryProfileStore(
        profile: UserProfile(name: 'Mira'),
        settings: const AppSettings(onboardingComplete: true),
      ),
      localStore: MemoryLocalApplicationStore(),
    );
    await state.initialize();
    await state.toggleSaved('recipe-a');

    await state.resetAllUserData();
    expect(state.profile, isNull);
    expect(state.savedRecipeIds, isEmpty);
    expect(state.needsOnboarding, isTrue);
    state.dispose();
  });

  test('cook completion record IDs are idempotent', () async {
    final state = AppState(
      profileStore: MemoryProfileStore(profile: UserProfile(name: 'Mira')),
      localStore: MemoryLocalApplicationStore(),
    );
    await state.initialize();
    await state.recordCooked('recipe-a', entryId: 'cook-session-a');
    await state.recordCooked('recipe-a', entryId: 'cook-session-a');
    expect(state.cookingHistory, hasLength(1));
    state.dispose();
  });
}

Recipe _recipe() => Recipe(
  id: 'recipe-a',
  dishId: 'dish-a',
  name: LocalizedText(const <String, String>{'en': 'Recipe'}),
  description: LocalizedText(const <String, String>{'en': 'Description'}),
  timeMinutes: 20,
  caloriesPerServing: 500,
  servings: 2,
  nutrition: const Nutrition(
    calories: 500,
    proteinGrams: 20,
    carbohydrateGrams: 50,
    fatGrams: 15,
  ),
  steps: <RecipeStep>[
    RecipeStep(
      id: 'one',
      text: LocalizedText(const <String, String>{'en': 'Cook'}),
    ),
    RecipeStep(
      id: 'two',
      text: LocalizedText(const <String, String>{'en': 'Serve'}),
    ),
  ],
  partitionId: 'core',
);
