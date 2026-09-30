import '../data/models/dish.dart';
import '../data/models/ontology.dart';
import '../data/models/recipe.dart';
import '../domain/search/search_index.dart';
import 'i18n/app_strings.dart';

/// Short descriptive line under a recipe title, in mono capitals:
/// `VEGAN · 45 MIN · 640 KCAL`. The diet label is left out when the person
/// switched variant tags off.
String metaLine(
  AppStrings s,
  Ontology ontology, {
  required String diet,
  required int minutes,
  required int kcal,
  bool showDiet = true,
}) {
  return [
    if (showDiet && diet != 'classic') ontology.label(diet, s.lang),
    s.minutes(minutes),
    s.kcal(kcal),
  ].join(' · ');
}

String recipeMeta(AppStrings s, Ontology ontology, Recipe recipe, {bool showDiet = true}) => metaLine(
  s,
  ontology,
  diet: recipe.diet,
  minutes: recipe.timeMinutes,
  kcal: recipe.caloriesPerServing,
  showDiet: showDiet,
);

String entryMeta(AppStrings s, Ontology ontology, IndexEntry entry, {bool showDiet = true}) => metaLine(
  s,
  ontology,
  diet: entry.diet,
  minutes: entry.timeMinutes,
  kcal: entry.caloriesPerServing,
  showDiet: showDiet,
);

/// Display headings are lowercase, as in the design.
String lower(String text) => text.toLowerCase();

/// Rounds calories to the nearest ten, as shown in `~520`.
int roundKcal(int kcal) => (kcal / 10).round() * 10;

String dishName(AppStrings s, Dish dish) => dish.name.resolve(s.lang);
