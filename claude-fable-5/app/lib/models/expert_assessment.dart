import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/digests/sha256.dart';

import 'recipe.dart';

const maxExpertAssessments = 500;
const maxExpertAssessmentBytes = 1024 * 1024;

/// Strict calendar input: DateTime.parse alone normalizes impossible dates.
DateTime? parseExpertReviewDate(String value, {DateTime? now}) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
  final date = DateTime.tryParse('${value}T00:00:00Z');
  final today = now ?? DateTime.now();
  if (date == null ||
      date.year < 1900 ||
      date.toIso8601String().substring(0, 10) != value ||
      date.isAfter(DateTime.utc(today.year, today.month, today.day))) {
    return null;
  }
  return date;
}

/// An attributed private note, never a verified credential or dietary label.
class ExpertAssessment {
  final String id;
  final String recipeId;
  final String recipeFingerprint;
  final String expertName;
  final String qualifications;
  final String assessment;
  final String source;
  final DateTime reviewedAt;

  ExpertAssessment({
    String? id,
    required this.recipeId,
    required this.recipeFingerprint,
    required String expertName,
    required String qualifications,
    required String assessment,
    String source = '',
    required this.reviewedAt,
  }) : id = id ?? _newId(),
       expertName = expertName.trim(),
       qualifications = qualifications.trim(),
       assessment = assessment.trim(),
       source = source.trim() {
    if (!RegExp(r'^assessment-[a-f0-9]{32}$').hasMatch(this.id) ||
        recipeId.isEmpty ||
        recipeId.length > 200 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(recipeFingerprint) ||
        this.expertName.isEmpty ||
        this.expertName.length > 120 ||
        this.qualifications.isEmpty ||
        this.qualifications.length > 300 ||
        this.assessment.isEmpty ||
        this.assessment.length > 4000 ||
        this.source.length > 1000 ||
        reviewedAt.year < 1900 ||
        reviewedAt.year > 2200) {
      throw const FormatException('invalid expert assessment');
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'recipe_id': recipeId,
    'recipe_fingerprint': recipeFingerprint,
    'expert_name': expertName,
    'qualifications': qualifications,
    'assessment': assessment,
    'source': source,
    'reviewed_at': reviewedAt.toUtc().toIso8601String(),
  };

  factory ExpertAssessment.fromJson(Map<String, dynamic> json) =>
      ExpertAssessment(
        id: json['id'] as String,
        recipeId: json['recipe_id'] as String,
        recipeFingerprint: json['recipe_fingerprint'] as String,
        expertName: json['expert_name'] as String,
        qualifications: json['qualifications'] as String,
        assessment: json['assessment'] as String,
        source: json['source'] as String? ?? '',
        reviewedAt: DateTime.parse(json['reviewed_at'] as String),
      );
}

bool expertAssessmentsFit(Iterable<ExpertAssessment> assessments) {
  var count = 0;
  var bytes = 0;
  final ids = <String>{};
  for (final entry in assessments) {
    if (++count > maxExpertAssessments || !ids.add(entry.id)) return false;
    bytes += utf8.encode(jsonEncode(entry.toJson())).length;
    if (bytes > maxExpertAssessmentBytes) return false;
  }
  return true;
}

/// Changes to the recipe invalidate its old assessment's current-version mark.
String expertRecipeFingerprint(Recipe recipe) {
  final data = {
    'title': [recipe.title.of('en'), recipe.title.of('de')],
    'intro': [recipe.intro.of('en'), recipe.intro.of('de')],
    'servings': recipe.servings,
    'time': recipe.timeMinutes,
    'ingredients': [
      for (final ingredient in recipe.ingredients)
        [
          ingredient.ingredientId,
          ingredient.customName,
          ingredient.qty,
          ingredient.unit,
          ingredient.hasQuantity,
          ingredient.note?.of('en'),
          ingredient.note?.of('de'),
        ],
    ],
    'steps': [
      for (final step in recipe.steps)
        [step.text.of('en'), step.text.of('de'), step.timerMinutes],
    ],
    'contains': recipe.contains.toList()..sort(),
    'attributes': recipe.attributes.toList()..sort(),
    'nutrition': [
      recipe.hasNutrition,
      recipe.caloriesPerServing,
      recipe.macros.calories,
      recipe.macros.proteinG,
      recipe.macros.carbsG,
      recipe.macros.fatG,
    ],
  };
  return SHA256Digest()
      .process(Uint8List.fromList(utf8.encode(jsonEncode(data))))
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

String _newId() {
  final random = Random.secure();
  return 'assessment-${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
}
