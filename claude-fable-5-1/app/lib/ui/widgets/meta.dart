import 'package:flutter/widgets.dart';

import '../../data/models/recipe.dart';
import '../../state/app_controller.dart';

/// Human labels for a recipe's variant identity, in the current language.
class RecipeMeta {
  const RecipeMeta(this.app, this.lang);
  final AppController app;
  final String lang;

  String diet(Recipe r) => app.repo.ontology.dimensionById['diet']?.value(r.diet)?.label.of(lang) ?? r.diet;
  String effort(Recipe r) => app.repo.ontology.labelForAttribute(r.effort).of(lang);
  String calorieLevel(Recipe r) =>
      app.repo.ontology.dimensionById['calorie_level']?.value(r.calorieLevel)?.label.of(lang) ?? r.calorieLevel;
  String kcal(Recipe r) => '~${r.caloriesPerServing} kcal';
  String time(Recipe r) => '${r.timeMinutes} min';

  /// "vegan · easy · ~520 kcal"
  List<String> tags(Recipe r) => [diet(r), effort(r), kcal(r)];

  /// "easy · 30 min · ~520 kcal"
  List<String> facts(Recipe r) => [effort(r), time(r), kcal(r)];

  String flag(String id) => app.repo.ontology.labelForFlag(id).of(lang);
  String attribute(String id) => app.repo.ontology.labelForAttribute(id).of(lang);
  String ingredient(String id) => app.repo.ingredients.byId[id]?.name.of(lang) ?? id;
  String unit(String id) => app.repo.ontology.unitById[id]?.label.of(lang) ?? id;
  String aisle(String id) => app.repo.ontology.aisleById[id]?.label.of(lang) ?? id;

  static RecipeMeta of(BuildContext context, AppController app) => RecipeMeta(app, app.lang);
}
