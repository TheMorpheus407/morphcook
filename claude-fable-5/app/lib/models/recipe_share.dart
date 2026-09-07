import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/sha256.dart';

import 'personal_recipe.dart';
import 'recipe_image.dart';

const recipeShareFormat = 'morphcook-recipes';
const recipeShareVersion = 1;
const maxRecipeShareBytes = 48 * 1024 * 1024;

enum RecipeShareFailure { invalidFormat, unsupportedVersion, tooLarge, empty }

class RecipeShareException implements Exception {
  final RecipeShareFailure failure;
  const RecipeShareException(this.failure);

  @override
  String toString() => 'RecipeShareException: ${failure.name}';
}

/// A deliberately narrow transfer format: recipes and selected local photos.
/// It never contains a profile, saved dates, plans, history or shopping data.
class RecipeShareData {
  final List<PersonalRecipe> recipes;
  final List<RecipeImage> images;

  RecipeShareData._(this.recipes, this.images);

  factory RecipeShareData({
    required List<PersonalRecipe> recipes,
    List<RecipeImage> images = const [],
  }) {
    if (recipes.isEmpty) {
      throw const RecipeShareException(RecipeShareFailure.empty);
    }
    if (recipes.length > maxPersonalRecipes ||
        !personalRecipesFitBackup(recipes) ||
        images.length > maxBackupRecipeImages ||
        images.fold<int>(0, (size, image) => size + image.bytes.length) >
            maxBackupImageBytes) {
      throw const RecipeShareException(RecipeShareFailure.tooLarge);
    }
    final ids = recipes.map((recipe) => recipe.id).toSet();
    if (ids.length != recipes.length ||
        images.map((image) => image.recipeId).toSet().length != images.length ||
        images.any((image) => !ids.contains(image.recipeId))) {
      throw const RecipeShareException(RecipeShareFailure.invalidFormat);
    }
    return RecipeShareData._(
      List.unmodifiable(recipes),
      List.unmodifiable(images),
    );
  }
}

/// Compare authored content, independent of local identities and edit dates.
String recipeShareContent(PersonalRecipe recipe) => jsonEncode(
  recipe.toJson()
    ..remove('id')
    ..remove('created_at')
    ..remove('updated_at'),
);

String recipeShareDigest(List<int> bytes) => SHA256Digest()
    .process(bytes is Uint8List ? bytes : Uint8List.fromList(bytes))
    .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
    .join();

String sharedPersonalRecipeId(String identity) =>
    'personal-${recipeShareDigest(utf8.encode(identity)).substring(0, 32)}';

PersonalRecipe remapSharedRecipe(PersonalRecipe recipe, String id) =>
    PersonalRecipe.fromJson({...recipe.toJson(), 'id': id});
