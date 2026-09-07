import 'dart:convert';
import 'dart:typed_data';

import '../../data/app_state.dart';
import '../../models/personal_recipe.dart';
import '../../models/recipe_image.dart';
import '../../models/recipe_share.dart';
import 'recipe_share_archive.dart';

export '../../models/recipe_share.dart';

/// Exports either one recipe or the union of saved and personal recipes.
/// Bundled recipes become standalone editable copies in the current language.
Future<RecipeShareData> collectRecipeShare(
  AppState state, {
  String? recipeId,
  bool includeImages = false,
}) async {
  final lang = state.lang;
  final personal = {
    for (final recipe in state.personalRecipes) recipe.id: recipe,
  };
  final images = {
    if (includeImages)
      for (final image in state.recipeImages) image.recipeId: image,
  };
  final ids = recipeId == null
      ? {...state.saved.map((recipe) => recipe.recipeId), ...personal.keys}
      : {recipeId};
  if (ids.length > maxPersonalRecipes) {
    throw const RecipeShareException(RecipeShareFailure.tooLarge);
  }
  final exported = <PersonalRecipe>[];
  final exportedImages = <RecipeImage>[];
  for (final id in ids) {
    var recipe = personal[id];
    if (recipe == null) {
      final bundled = await state.corpus.recipeById(id);
      if (bundled == null) {
        throw const RecipeShareException(RecipeShareFailure.invalidFormat);
      }
      recipe = PersonalRecipe(
        id: sharedPersonalRecipeId('morphcook-bundled:$id:$lang'),
        title: bundled.title.of(lang),
        description: bundled.intro.of(lang),
        timeMinutes: bundled.timeMinutes,
        servings: bundled.servings,
        ingredients: [
          for (final ingredient in bundled.ingredients)
            PersonalRecipeIngredient(
              name:
                  ingredient.customName ??
                  state.corpus.dictionary
                      .byId(ingredient.ingredientId)
                      ?.name
                      .of(lang) ??
                  ingredient.ingredientId,
              qty: ingredient.qty,
              unit: ingredient.unit,
              hasQuantity: ingredient.hasQuantity,
              note: ingredient.note?.of(lang),
            ),
        ],
        steps: [
          for (final step in bundled.steps)
            PersonalRecipeStep(
              text: step.text.of(lang),
              timerMinutes: step.timerMinutes,
            ),
        ],
        // Fixed metadata avoids disclosing a user's save/export activity and
        // makes repeated exports/imports of the same bundled recipe stable.
        createdAt: DateTime.utc(1970),
        updatedAt: DateTime.utc(1970),
      );
    }
    exported.add(recipe);
    if (images[id] case final image?) {
      exportedImages.add(
        RecipeImage(
          recipeId: recipe.id,
          bytes: image.bytes,
          updatedAt: image.updatedAt,
        ),
      );
    }
  }
  return RecipeShareData(recipes: exported, images: exportedImages);
}

Uint8List encodeRecipeShare(RecipeShareData data) {
  final sink = _ShareBytesSink();
  final encoder = JsonUtf8Encoder().startChunkedConversion(sink);
  encoder.add({
    'format': recipeShareFormat,
    'version': recipeShareVersion,
    'recipes': data.recipes.map((recipe) => recipe.toJson()).toList(),
    if (data.images.isNotEmpty)
      'images': data.images.map((image) => image.toBackupJson()).toList(),
  });
  encoder.close();
  return sink.bytes.takeBytes();
}

RecipeShareData decodeRecipeShare(Uint8List bytes) {
  if (bytes.length > maxRecipeShareBytes) {
    throw const RecipeShareException(RecipeShareFailure.tooLarge);
  }
  try {
    if (bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4b) {
      bytes = decodeRecipeShareArchive(bytes, maxBytes: maxRecipeShareBytes);
    }
    final text = utf8.decode(bytes);
    _checkJsonDepth(text);
    final raw = jsonDecode(text);
    if (raw is! Map<String, dynamic> || raw['format'] != recipeShareFormat) {
      throw const RecipeShareException(RecipeShareFailure.invalidFormat);
    }
    if (raw['version'] is! int || raw['version'] != recipeShareVersion) {
      throw const RecipeShareException(RecipeShareFailure.unsupportedVersion);
    }
    // Reject unrelated backup/account fields instead of accepting a backup as
    // a recipe collection. The importer never applies any such state.
    if (raw.keys.any(
      (key) => !const {'format', 'version', 'recipes', 'images'}.contains(key),
    )) {
      throw const RecipeShareException(RecipeShareFailure.invalidFormat);
    }
    final recipes = raw['recipes'];
    final images = raw['images'] ?? const [];
    if (recipes is! List || images is! List) {
      throw const RecipeShareException(RecipeShareFailure.invalidFormat);
    }
    if (recipes.length > maxPersonalRecipes ||
        images.length > maxBackupRecipeImages) {
      throw const RecipeShareException(RecipeShareFailure.tooLarge);
    }
    final parsedRecipes = <PersonalRecipe>[];
    for (final recipe in recipes) {
      if (recipe is! Map<String, dynamic> ||
          recipe['ingredients'] is! List ||
          recipe['steps'] is! List) {
        throw const RecipeShareException(RecipeShareFailure.invalidFormat);
      }
      if ((recipe['ingredients'] as List).length >
              maxPersonalRecipeIngredients ||
          (recipe['steps'] as List).length > maxPersonalRecipeSteps) {
        throw const RecipeShareException(RecipeShareFailure.tooLarge);
      }
      parsedRecipes.add(PersonalRecipe.fromJson(recipe));
    }
    if (!personalRecipesFitBackup(parsedRecipes)) {
      throw const RecipeShareException(RecipeShareFailure.tooLarge);
    }
    final parsedImages = <RecipeImage>[];
    var imageBytes = 0;
    for (final image in images) {
      if (image is! Map<String, dynamic>) {
        throw const RecipeShareException(RecipeShareFailure.invalidFormat);
      }
      final parsed = RecipeImage.fromBackupJson(image);
      imageBytes += parsed.bytes.length;
      if (imageBytes > maxBackupImageBytes) {
        throw const RecipeShareException(RecipeShareFailure.tooLarge);
      }
      parsedImages.add(parsed);
    }
    return RecipeShareData(recipes: parsedRecipes, images: parsedImages);
  } on RecipeShareException {
    rethrow;
  } on RecipeImageException catch (error) {
    throw RecipeShareException(
      error.failure == RecipeImageFailure.tooLarge
          ? RecipeShareFailure.tooLarge
          : RecipeShareFailure.invalidFormat,
    );
  } catch (_) {
    throw const RecipeShareException(RecipeShareFailure.invalidFormat);
  }
}

/// Human-readable companion for messaging apps and recipients without MorphCook.
String recipeShareText(RecipeShareData data, {required String lang}) {
  final de = lang == 'de';
  final output = StringBuffer('MorphCook\n\n');
  for (final recipe in data.recipes) {
    output.writeln(recipe.title);
    output.writeln(
      '${recipe.timeMinutes} min · ${recipe.servings} ${de ? 'Portionen' : 'servings'}',
    );
    if (recipe.description.isNotEmpty) output.writeln(recipe.description);
    if (recipe.sourceUrl != null) {
      output.writeln('${de ? 'Quelle' : 'Source'}: ${recipe.sourceUrl}');
    }
    if (recipe.sourceAuthor != null) {
      output.writeln(
        '${de ? 'Autor (Angabe)' : 'Author (website claim)'}: ${recipe.sourceAuthor}',
      );
    }
    if (recipe.sourceDiet != null) {
      output.writeln(
        '${de ? 'Ernährung (ungeprüft)' : 'Diet (unverified)'}: ${recipe.sourceDiet}',
      );
    }
    output.writeln('\n${de ? 'Zutaten' : 'Ingredients'}:');
    for (final ingredient in recipe.ingredients) {
      final qty = ingredient.qty == ingredient.qty.roundToDouble()
          ? ingredient.qty.round().toString()
          : ingredient.qty.toString();
      output.writeln(
        '- ${ingredient.hasQuantity ? '$qty ${ingredient.unit} ' : ''}${ingredient.name}${ingredient.note == null ? '' : ' (${ingredient.note})'}',
      );
    }
    output.writeln('\n${de ? 'Zubereitung' : 'Method'}:');
    for (var index = 0; index < recipe.steps.length; index++) {
      final step = recipe.steps[index];
      output.writeln(
        '${index + 1}. ${step.text}${step.timerMinutes == null ? '' : ' (${de ? 'Timer' : 'timer'}: ${step.timerMinutes} min)'}',
      );
    }
    output.writeln();
  }
  return output.toString().trimRight();
}

class _ShareBytesSink implements Sink<List<int>> {
  final bytes = BytesBuilder(copy: false);

  @override
  void add(List<int> chunk) {
    if (bytes.length + chunk.length > maxRecipeShareBytes) {
      throw const RecipeShareException(RecipeShareFailure.tooLarge);
    }
    bytes.add(chunk);
  }

  @override
  void close() {}
}

void _checkJsonDepth(String text) {
  var depth = 0;
  var containers = 0;
  var tokens = 0;
  var inString = false;
  var escaped = false;
  for (final char in text.codeUnits) {
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == 92) {
        escaped = true;
      } else if (char == 34) {
        inString = false;
      }
    } else {
      // The valid format has at most 500 recipes with 100 ingredients and
      // 100 steps each. Bound wide structures as well as depth before Dart
      // allocates the decoded lists/maps. Two million tokens accommodates every
      // allowed ingredient/step field; delimiters also bound scalar lists.
      if (char == 34 ||
          char == 91 ||
          char == 123 ||
          char == 93 ||
          char == 125 ||
          char == 44 ||
          char == 58) {
        if (++tokens > 2000000) {
          throw const RecipeShareException(RecipeShareFailure.tooLarge);
        }
      }
      if (char == 34) {
        inString = true;
      } else if (char == 91 || char == 123) {
        if (++depth > 32 || ++containers > 120000) {
          throw const RecipeShareException(RecipeShareFailure.tooLarge);
        }
      } else if (char == 93 || char == 125) {
        depth--;
      }
    }
  }
}
