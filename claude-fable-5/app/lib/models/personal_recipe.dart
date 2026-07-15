import 'dart:convert';
import 'dart:math';

import 'localized.dart';
import 'recipe.dart';

const maxPersonalRecipeTitleLength = 200;
const maxPersonalRecipeDescriptionLength = 5000;
const maxPersonalRecipeIngredients = 100;
const maxPersonalRecipeSteps = 100;
const maxPersonalIngredientNameLength = 200;
const maxPersonalIngredientNoteLength = 500;
const maxPersonalStepLength = 5000;
const maxPersonalRecipes = 500;
const maxPersonalRecipeBackupBytes = 8 * 1024 * 1024;

enum PersonalRecipeLimitReason { count, backupSize }

class PersonalRecipeLimitException implements Exception {
  final PersonalRecipeLimitReason reason;

  const PersonalRecipeLimitException(this.reason);

  @override
  String toString() => 'PersonalRecipeLimitException: ${reason.name}';
}

/// One free-text ingredient authored by the device owner.
class PersonalRecipeIngredient {
  final String name;
  final double qty;
  final String unit;
  final String? note;

  PersonalRecipeIngredient._({
    required this.name,
    required this.qty,
    required this.unit,
    this.note,
  });

  factory PersonalRecipeIngredient({
    required String name,
    required double qty,
    required String unit,
    String? note,
  }) {
    final value = PersonalRecipeIngredient._(
      name: name.trim(),
      qty: qty,
      unit: unit.trim(),
      note: _trimToNull(note),
    );
    value._validate();
    return value;
  }

  factory PersonalRecipeIngredient.fromJson(Map<String, dynamic> json) =>
      PersonalRecipeIngredient(
        name: json['name'] as String,
        qty: (json['qty'] as num).toDouble(),
        unit: json['unit'] as String,
        note: json['note'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    'qty': qty,
    'unit': unit,
    if (note != null) 'note': note,
  };

  void _validate() {
    if (name.isEmpty || name.length > maxPersonalIngredientNameLength) {
      throw const FormatException('invalid personal ingredient name');
    }
    if (!qty.isFinite || qty <= 0 || qty > 1000000) {
      throw const FormatException('invalid personal ingredient quantity');
    }
    if (unit.isEmpty || unit.length > 30) {
      throw const FormatException('invalid personal ingredient unit');
    }
    if (note != null && note!.length > maxPersonalIngredientNoteLength) {
      throw const FormatException('personal ingredient note is too long');
    }
  }
}

/// One authored instruction, optionally carrying a cook-mode timer.
class PersonalRecipeStep {
  final String text;
  final int? timerMinutes;

  PersonalRecipeStep._({required this.text, this.timerMinutes});

  factory PersonalRecipeStep({required String text, int? timerMinutes}) {
    final value = PersonalRecipeStep._(
      text: text.trim(),
      timerMinutes: timerMinutes,
    );
    value._validate();
    return value;
  }

  factory PersonalRecipeStep.fromJson(Map<String, dynamic> json) =>
      PersonalRecipeStep(
        text: json['text'] as String,
        timerMinutes: (json['timer_minutes'] as num?)?.round(),
      );

  Map<String, dynamic> toJson() => {
    'text': text,
    if (timerMinutes != null) 'timer_minutes': timerMinutes,
  };

  void _validate() {
    if (text.isEmpty || text.length > maxPersonalStepLength) {
      throw const FormatException('invalid personal recipe step');
    }
    if (timerMinutes != null && (timerMinutes! <= 0 || timerMinutes! > 1440)) {
      throw const FormatException('invalid personal recipe timer');
    }
  }
}

/// A recipe that exists only in this installation (and in its backups).
///
/// It deliberately stays separate from the immutable lattice corpus. The
/// [asRecipe] adapter lets existing cook-mode, meal-plan and shopping flows
/// use it without pretending it has variants or calculated nutrition.
class PersonalRecipe {
  final String id;
  final String title;
  final String description;
  final int timeMinutes;
  final int servings;
  final List<PersonalRecipeIngredient> ingredients;
  final List<PersonalRecipeStep> steps;
  final DateTime createdAt;
  final DateTime updatedAt;

  PersonalRecipe._({
    required this.id,
    required this.title,
    required this.description,
    required this.timeMinutes,
    required this.servings,
    required this.ingredients,
    required this.steps,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PersonalRecipe({
    required String id,
    required String title,
    String description = '',
    required int timeMinutes,
    required int servings,
    required List<PersonalRecipeIngredient> ingredients,
    required List<PersonalRecipeStep> steps,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    final value = PersonalRecipe._(
      id: id,
      title: title.trim(),
      description: description.trim(),
      timeMinutes: timeMinutes,
      servings: servings,
      ingredients: List.unmodifiable(ingredients),
      steps: List.unmodifiable(steps),
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
    );
    value._validate();
    return value;
  }

  factory PersonalRecipe.create({
    required String title,
    String description = '',
    required int timeMinutes,
    required int servings,
    required List<PersonalRecipeIngredient> ingredients,
    required List<PersonalRecipeStep> steps,
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    return PersonalRecipe(
      id: _newPersonalRecipeId(),
      title: title,
      description: description,
      timeMinutes: timeMinutes,
      servings: servings,
      ingredients: ingredients,
      steps: steps,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  factory PersonalRecipe.fromJson(Map<String, dynamic> json) => PersonalRecipe(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    timeMinutes: (json['time_minutes'] as num).round(),
    servings: (json['servings'] as num).round(),
    ingredients: (json['ingredients'] as List)
        .map(
          (e) => PersonalRecipeIngredient.fromJson(e as Map<String, dynamic>),
        )
        .toList(),
    steps: (json['steps'] as List)
        .map((e) => PersonalRecipeStep.fromJson(e as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  String get dishId => 'personal-dish-${id.substring('personal-'.length)}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (description.isNotEmpty) 'description': description,
    'time_minutes': timeMinutes,
    'servings': servings,
    'ingredients': ingredients.map((i) => i.toJson()).toList(),
    'steps': steps.map((s) => s.toJson()).toList(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  PersonalRecipe copyWith({
    String? title,
    String? description,
    int? timeMinutes,
    int? servings,
    List<PersonalRecipeIngredient>? ingredients,
    List<PersonalRecipeStep>? steps,
    DateTime? updatedAt,
  }) => PersonalRecipe(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    timeMinutes: timeMinutes ?? this.timeMinutes,
    servings: servings ?? this.servings,
    ingredients: ingredients ?? this.ingredients,
    steps: steps ?? this.steps,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
  );

  Recipe asRecipe() {
    final localizedTitle = LocalizedText({'en': title, 'de': title});
    final localizedDescription = description.isEmpty
        ? LocalizedText.empty
        : LocalizedText({'en': description, 'de': description});
    final effort = timeMinutes <= 30
        ? 'easy'
        : timeMinutes <= 60
        ? 'medium'
        : 'hard';
    return Recipe(
      id: id,
      dishId: dishId,
      title: localizedTitle,
      caption: localizedDescription,
      intro: localizedDescription,
      variant: VariantCoords(diet: 'classic', effort: effort, calorie: 'le600'),
      contains: const {},
      attributes: {effort},
      meal: const ['breakfast', 'lunch', 'dinner'],
      timeMinutes: timeMinutes,
      servings: servings,
      caloriesPerServing: 0,
      macros: const Macros(calories: 0, proteinG: 0, carbsG: 0, fatG: 0),
      hasNutrition: false,
      ingredients: [
        for (final ingredient in ingredients)
          RecipeIngredient(
            ingredientId: _personalIngredientId(ingredient.name),
            qty: ingredient.qty,
            unit: ingredient.unit,
            customName: ingredient.name,
            note: ingredient.note == null
                ? null
                : LocalizedText({
                    'en': ingredient.note!,
                    'de': ingredient.note!,
                  }),
          ),
      ],
      steps: [
        for (final step in steps)
          RecipeStep(
            text: LocalizedText({'en': step.text, 'de': step.text}),
            timerMinutes: step.timerMinutes,
          ),
      ],
      tags: const LocalizedList({}),
    );
  }

  void _validate() {
    if (!RegExp(r'^personal-[a-f0-9]{32}$').hasMatch(id)) {
      throw const FormatException('invalid personal recipe id');
    }
    if (title.isEmpty || title.length > maxPersonalRecipeTitleLength) {
      throw const FormatException('invalid personal recipe title');
    }
    if (description.length > maxPersonalRecipeDescriptionLength) {
      throw const FormatException('personal recipe description is too long');
    }
    if (timeMinutes <= 0 || timeMinutes > 1440) {
      throw const FormatException('invalid personal recipe time');
    }
    if (servings <= 0 || servings > 1000) {
      throw const FormatException('invalid personal recipe servings');
    }
    if (ingredients.isEmpty ||
        ingredients.length > maxPersonalRecipeIngredients) {
      throw const FormatException('invalid personal recipe ingredients');
    }
    if (steps.isEmpty || steps.length > maxPersonalRecipeSteps) {
      throw const FormatException('invalid personal recipe steps');
    }
    if (updatedAt.isBefore(createdAt)) {
      throw const FormatException('invalid personal recipe timestamps');
    }
  }
}

String _newPersonalRecipeId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return 'personal-${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
}

String _personalIngredientId(String name) {
  final normalized = name.trim().toLowerCase();
  final encoded = base64Url.encode(utf8.encode(normalized)).replaceAll('=', '');
  return 'personal-ingredient-$encoded';
}

String? _trimToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// Conservative UTF-8 JSON estimate used before materializing a whole backup.
/// Per-object overhead covers field names, punctuation, timestamps and numbers.
int estimatedPersonalRecipeBackupBytes(Iterable<PersonalRecipe> recipes) {
  var total = 2; // surrounding JSON array
  for (final recipe in recipes) {
    total +=
        256 +
        _jsonStringBytes(recipe.id) +
        _jsonStringBytes(recipe.title) +
        _jsonStringBytes(recipe.description);
    for (final ingredient in recipe.ingredients) {
      total +=
          128 +
          _jsonStringBytes(ingredient.name) +
          _jsonStringBytes(ingredient.unit) +
          _jsonStringBytes(ingredient.note ?? '');
    }
    for (final step in recipe.steps) {
      total += 96 + _jsonStringBytes(step.text);
    }
    if (total > maxPersonalRecipeBackupBytes) return total;
  }
  return total;
}

bool personalRecipesFitBackup(Iterable<PersonalRecipe> recipes) =>
    estimatedPersonalRecipeBackupBytes(recipes) <= maxPersonalRecipeBackupBytes;

int _jsonStringBytes(String value) => utf8.encode(json.encode(value)).length;
