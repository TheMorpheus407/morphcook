import '../models/ingredient.dart';
import '../models/ontology.dart';
import '../models/profile.dart';
import '../models/recipe.dart';

enum HiddenReason {
  avoidedFlag,
  avoidedIngredient,
  missingAttribute,
  overTimeBudget,
  outsideCalorieTarget,
}

Set<String> expandAvoidFlags(Set<String> avoidFlags, Ontology ontology) {
  final expanded = <String>{};
  for (final flag in avoidFlags) {
    final compound = ontology.compound(flag);
    if (compound != null) {
      expanded.addAll(compound.expandsTo);
    } else {
      expanded.add(flag);
    }
  }
  return expanded;
}

class Matcher {
  final Ontology ontology;
  final IngredientDictionary dictionary;

  const Matcher({required this.ontology, required this.dictionary});

  List<HiddenReason> reasons(
    Recipe recipe,
    Profile profile, {
    bool ignoreCalories = false,
  }) {
    final out = <HiddenReason>[];

    final avoided = expandAvoidFlags(profile.avoidFlags, ontology);
    if (recipe.contains.intersection(avoided).isNotEmpty) {
      out.add(HiddenReason.avoidedFlag);
    }

    final avoidedIngredients = dictionary.expandAvoided(profile.avoidIngredients);
    if (recipe.ingredientIds.intersection(avoidedIngredients).isNotEmpty) {
      out.add(HiddenReason.avoidedIngredient);
    }

    if (!profile.requiredAttributes
        .every((attr) => recipe.attributes.contains(attr))) {
      out.add(HiddenReason.missingAttribute);
    }

    final maxTime = profile.maxTimeMinutes;
    if (maxTime != null && recipe.timeMinutes > maxTime) {
      out.add(HiddenReason.overTimeBudget);
    }

    final target = profile.calorieTarget;
    if (!ignoreCalories &&
        target != null &&
        (recipe.caloriesPerServing - target).abs() > Profile.calorieTolerance) {
      out.add(HiddenReason.outsideCalorieTarget);
    }

    return out;
  }

  bool isVisible(
    Recipe recipe,
    Profile profile, {
    bool ignoreCalories = false,
  }) =>
      reasons(recipe, profile, ignoreCalories: ignoreCalories).isEmpty;

  bool hiddenOnlyByCalories(Recipe recipe, Profile profile) {
    final r = reasons(recipe, profile);
    return r.length == 1 && r.single == HiddenReason.outsideCalorieTarget;
  }
}
