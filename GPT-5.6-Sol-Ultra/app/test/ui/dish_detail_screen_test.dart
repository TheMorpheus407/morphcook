import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:morphcook/data/bundled_recipe_repository.dart';
import 'package:morphcook/domain/models/user_profile.dart';
import 'package:morphcook/l10n/app_strings.dart';
import 'package:morphcook/ui/screens/dish_detail_screen.dart';
import 'package:morphcook/ui/theme/morph_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets(
    'variant rows morph recipes and expose authored unavailable choices',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = BundledRecipeRepository(
        assetLoader: (path) => File(path).readAsString(),
      );
      await tester.runAsync(() => repository.initialize(loadExtended: true));
      final dish = repository.dishById('doener')!;
      final variants = repository.recipesForDish(dish.id);
      final initial = repository.recipeById('doener-classic-easy-balanced')!;
      final profile = UserProfile(
        name: 'Mara',
        calorieTarget: 600,
        calorieTolerance: 1000,
        maxTimeMinutes: 90,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: MorphTheme.light,
          home: MorphStringsScope(
            languageCode: 'en',
            child: DishDetailScreen(
              dish: dish,
              variants: variants,
              initialRecipe: initial,
              profile: profile,
              ingredients: repository.ingredients,
              guideEntries: repository.ingredientGuideById,
              isSaved: (_) => false,
              onToggleSaved: (_) async {},
              onAddToShopping: (_, _) async {},
              onStartCooking: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.ensureVisible(find.text('DIET'));
      await tester.tap(find.text('DIET'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('vegan'));
      await tester.pumpAndSettle();
      expect(find.text('Crisp Tofu Döner'), findsOneWidget);

      await tester.ensureVisible(find.text('EFFORT'));
      await tester.tap(find.text('EFFORT'));
      await tester.pumpAndSettle();
      expect(find.text('slow project'), findsOneWidget);
      expect(find.text('No vegan × easy version yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
