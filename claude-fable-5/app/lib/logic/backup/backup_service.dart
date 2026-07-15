import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../models/collections.dart';
import '../../models/personal_recipe.dart';
import '../../models/profile.dart';
import '../../models/recipe_image.dart';
import 'crypto.dart';

const backupSchemaVersion = 2;
const maxBackupDecodedBytes = 48 * 1024 * 1024;
// GZip can be slightly larger than incompressible input; encrypted files also
// carry a small authenticated envelope. The decoded JSON remains capped below.
const maxBackupFileBytes = maxBackupDecodedBytes + 1024 * 1024;

/// The full exportable state (SPEC "Backup format").
class BackupData {
  final Profile profile;
  final List<SavedRecipe> saved;
  final MealPlanData mealPlan;
  final List<HistoryEntry> history;
  final List<ShoppingItem> shoppingHistory;
  final List<String> contentRequests;
  final List<PersonalRecipe> personalRecipes;
  final List<RecipeImage> recipeImages;

  const BackupData({
    required this.profile,
    required this.saved,
    required this.mealPlan,
    required this.history,
    this.shoppingHistory = const [],
    this.contentRequests = const [],
    this.personalRecipes = const [],
    this.recipeImages = const [],
  });

  Map<String, dynamic> toJson(DateTime exportedAt) => {
    'schema_version': backupSchemaVersion,
    'exported_at': exportedAt.toUtc().toIso8601String(),
    'profile': profile.toJson(),
    'saved': saved.map((s) => s.recipeId).toList(),
    'saved_meta': saved.map((s) => s.toJson()).toList(),
    'meal_plan': mealPlan,
    'history': history.map((h) => h.toJson()).toList(),
    'shopping_history': shoppingHistory.map((s) => s.toJson()).toList(),
    if (contentRequests.isNotEmpty) 'content_requests': contentRequests,
    if (personalRecipes.isNotEmpty)
      'personal_recipes': personalRecipes.map((r) => r.toJson()).toList(),
    if (recipeImages.isNotEmpty)
      'recipe_images': recipeImages
          .map((image) => image.toBackupJson())
          .toList(),
  };

  factory BackupData.fromJson(Map<String, dynamic> json) {
    try {
      final version = json['schema_version'];
      if (version is! int || version > backupSchemaVersion || version < 1) {
        throw const DecryptionException(DecryptionFailure.invalidFormat);
      }
      final profileJson = json['profile'];
      if (profileJson is! Map<String, dynamic>) {
        throw const DecryptionException(DecryptionFailure.invalidFormat);
      }
      final savedMeta = json['saved_meta'] as List?;
      final saved = savedMeta != null
          ? savedMeta
                .map((e) => SavedRecipe.fromJson(e as Map<String, dynamic>))
                .toList()
          : (json['saved'] as List? ?? const [])
                .map(
                  (id) => SavedRecipe(
                    recipeId: id as String,
                    savedAt: DateTime.fromMillisecondsSinceEpoch(
                      0,
                      isUtc: true,
                    ),
                  ),
                )
                .toList();
      final personalJson = json['personal_recipes'] as List? ?? const [];
      if (personalJson.length > maxPersonalRecipes) {
        throw const DecryptionException(DecryptionFailure.invalidFormat);
      }
      final imageJson = json['recipe_images'] as List? ?? const [];
      if (imageJson.length > maxBackupRecipeImages) {
        throw const DecryptionException(DecryptionFailure.invalidFormat);
      }
      final images = <RecipeImage>[];
      final imageIds = <String>{};
      var totalImageBytes = 0;
      for (final raw in imageJson) {
        final image = RecipeImage.fromBackupJson(raw as Map<String, dynamic>);
        totalImageBytes += image.bytes.length;
        if (totalImageBytes > maxBackupImageBytes ||
            !imageIds.add(image.recipeId)) {
          throw const DecryptionException(DecryptionFailure.invalidFormat);
        }
        images.add(image);
      }
      final personalRecipes = personalJson
          .map((e) => PersonalRecipe.fromJson(e as Map<String, dynamic>))
          .toList();
      if (personalRecipes.map((recipe) => recipe.id).toSet().length !=
          personalRecipes.length) {
        throw const DecryptionException(DecryptionFailure.invalidFormat);
      }
      if (!personalRecipesFitBackup(personalRecipes)) {
        throw const DecryptionException(DecryptionFailure.tooLarge);
      }
      return BackupData(
        profile: Profile.fromJson(profileJson),
        saved: saved,
        mealPlan: (json['meal_plan'] as Map<String, dynamic>? ?? const {}).map(
          (week, slots) => MapEntry(
            week,
            (slots as Map<String, dynamic>).map(
              (slot, id) => MapEntry(slot, id as String),
            ),
          ),
        ),
        history: (json['history'] as List? ?? const [])
            .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        shoppingHistory: (json['shopping_history'] as List? ?? const [])
            .map((e) => ShoppingItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        contentRequests: List<String>.from(
          json['content_requests'] as List? ?? const [],
        ),
        personalRecipes: personalRecipes,
        recipeImages: images,
      );
    } on DecryptionException {
      rethrow;
    } catch (_) {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }
  }
}

class ExportedBackup {
  /// `morphcook-backup.json` — encrypted bytes if a password was given,
  /// otherwise human-readable JSON.
  final Uint8List jsonFile;

  /// Optional `morphcook-backup.json.gz` — plain GZip (never encrypted),
  /// for passwordless compatibility exports.
  final Uint8List? gzipFile;

  const ExportedBackup({required this.jsonFile, this.gzipFile});
}

class BackupService {
  /// Builds the JSON export and, when requested, its plain GZip companion.
  static ExportedBackup export(
    BackupData data, {
    String? password,
    DateTime? exportedAt,
    bool includePlainGzip = true,
  }) {
    if (!personalRecipesFitBackup(data.personalRecipes)) {
      throw const DecryptionException(DecryptionFailure.tooLarge);
    }
    if (data.personalRecipes.length > maxPersonalRecipes ||
        data.personalRecipes.map((recipe) => recipe.id).toSet().length !=
            data.personalRecipes.length ||
        data.recipeImages.length > maxBackupRecipeImages ||
        data.recipeImages.map((image) => image.recipeId).toSet().length !=
            data.recipeImages.length ||
        data.recipeImages.fold<int>(
              0,
              (total, image) => total + image.bytes.length,
            ) >
            maxBackupImageBytes) {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }
    final sink = _LimitedBytesSink(maxBackupDecodedBytes);
    try {
      final encoder = JsonUtf8Encoder('  ').startChunkedConversion(sink);
      encoder.add(data.toJson(exportedAt ?? DateTime.now()));
      encoder.close();
    } on _BackupTooLarge {
      throw const DecryptionException(DecryptionFailure.tooLarge);
    }
    final plainBytes = sink.takeBytes();

    final jsonFile = (password != null && password.isNotEmpty)
        ? encryptBackupBytes(plainBytes, password)
        : plainBytes;
    final gzipFile = includePlainGzip
        ? Uint8List.fromList(gzip.encode(plainBytes))
        : null;

    return ExportedBackup(jsonFile: jsonFile, gzipFile: gzipFile);
  }

  /// True when [bytes] need a password to import.
  static bool isEncrypted(List<int> bytes) => hasEncryptionMagic(bytes);

  /// Auto-detecting import: encryption magic first, then GZip magic, then
  /// plain JSON. Throws [DecryptionException] with a specific reason —
  /// `needsPassword` when an encrypted file is given without a password.
  static BackupData import(List<int> bytes, {String? password}) {
    if (bytes.length > maxBackupFileBytes) {
      throw const DecryptionException(DecryptionFailure.tooLarge);
    }
    String jsonText;
    if (hasEncryptionMagic(bytes)) {
      if (bytes.length >
          maxBackupDecodedBytes + encryptionEnvelopeOverheadBytes) {
        throw const DecryptionException(DecryptionFailure.tooLarge);
      }
      if (password == null || password.isEmpty) {
        throw const DecryptionException(DecryptionFailure.needsPassword);
      }
      jsonText = decryptBackup(bytes, password);
    } else if (hasGzipMagic(bytes)) {
      try {
        jsonText = utf8.decode(_decodeGzipBounded(bytes));
      } on _BackupTooLarge {
        throw const DecryptionException(DecryptionFailure.tooLarge);
      } catch (_) {
        throw const DecryptionException(DecryptionFailure.corrupted);
      }
    } else {
      if (bytes.length > maxBackupDecodedBytes) {
        throw const DecryptionException(DecryptionFailure.tooLarge);
      }
      try {
        jsonText = utf8.decode(bytes);
      } catch (_) {
        throw const DecryptionException(DecryptionFailure.invalidFormat);
      }
    }

    final dynamic decoded;
    try {
      decoded = json.decode(jsonText);
    } catch (_) {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }
    return BackupData.fromJson(decoded);
  }

  /// Merge strategy: union of saved/history/content requests, incoming
  /// meal-plan slots win per slot, incoming profile wins.
  static BackupData merge(BackupData current, BackupData incoming) {
    if (current.personalRecipes.map((recipe) => recipe.id).toSet().length !=
            current.personalRecipes.length ||
        incoming.personalRecipes.map((recipe) => recipe.id).toSet().length !=
            incoming.personalRecipes.length ||
        current.recipeImages.map((image) => image.recipeId).toSet().length !=
            current.recipeImages.length ||
        incoming.recipeImages.map((image) => image.recipeId).toSet().length !=
            incoming.recipeImages.length) {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }
    final savedIds = current.saved.map((s) => s.recipeId).toSet();
    final saved = [
      ...current.saved,
      ...incoming.saved.where((s) => !savedIds.contains(s.recipeId)),
    ];

    final mealPlan = <String, Map<String, String>>{
      for (final e in current.mealPlan.entries) e.key: {...e.value},
    };
    for (final week in incoming.mealPlan.entries) {
      mealPlan.putIfAbsent(week.key, () => {}).addAll(week.value);
    }

    final historyKeys = current.history
        .map((h) => '${h.recipeId}|${h.cookedAt.toIso8601String()}')
        .toSet();
    final history = [
      ...current.history,
      ...incoming.history.where(
        (h) => !historyKeys.contains(
          '${h.recipeId}|${h.cookedAt.toIso8601String()}',
        ),
      ),
    ];

    final personalById = <String, PersonalRecipe>{
      for (final recipe in current.personalRecipes) recipe.id: recipe,
    };
    for (final recipe in incoming.personalRecipes) {
      final existing = personalById[recipe.id];
      if (existing == null || !existing.updatedAt.isAfter(recipe.updatedAt)) {
        personalById[recipe.id] = recipe;
      }
    }
    if (personalById.length > maxPersonalRecipes) {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }
    if (!personalRecipesFitBackup(personalById.values)) {
      throw const DecryptionException(DecryptionFailure.tooLarge);
    }

    final imagesByRecipe = <String, RecipeImage>{
      for (final image in current.recipeImages) image.recipeId: image,
    };
    for (final image in incoming.recipeImages) {
      final existing = imagesByRecipe[image.recipeId];
      if (existing == null || !existing.updatedAt.isAfter(image.updatedAt)) {
        imagesByRecipe[image.recipeId] = image;
      }
    }
    if (imagesByRecipe.length > maxBackupRecipeImages ||
        imagesByRecipe.values.fold<int>(
              0,
              (total, image) => total + image.bytes.length,
            ) >
            maxBackupImageBytes) {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }

    return BackupData(
      profile: incoming.profile,
      saved: saved,
      mealPlan: mealPlan,
      history: history,
      shoppingHistory: [
        ...current.shoppingHistory,
        ...incoming.shoppingHistory,
      ],
      contentRequests: {
        ...current.contentRequests,
        ...incoming.contentRequests,
      }.toList(),
      personalRecipes: personalById.values.toList(),
      recipeImages: imagesByRecipe.values.toList(),
    );
  }
}

Uint8List _decodeGzipBounded(List<int> bytes) {
  final sink = _LimitedBytesSink(maxBackupDecodedBytes);
  final decoder = gzip.decoder.startChunkedConversion(sink);
  const chunkSize = 64 * 1024;
  for (var offset = 0; offset < bytes.length; offset += chunkSize) {
    final end = offset + chunkSize < bytes.length
        ? offset + chunkSize
        : bytes.length;
    decoder.add(bytes.sublist(offset, end));
  }
  decoder.close();
  return sink.takeBytes();
}

class _BackupTooLarge implements Exception {}

class _LimitedBytesSink extends ByteConversionSinkBase {
  final int limit;
  final BytesBuilder _builder = BytesBuilder(copy: false);
  int _length = 0;

  _LimitedBytesSink(this.limit);

  @override
  void add(List<int> chunk) {
    _length += chunk.length;
    if (_length > limit) throw _BackupTooLarge();
    _builder.add(chunk);
  }

  @override
  void close() {}

  Uint8List takeBytes() => _builder.takeBytes();
}
