import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'data.dart';
import 'models.dart';

class RecipeMatcher {
  const RecipeMatcher._();

  static const calorieTolerance = 180;

  static bool isVisible(
    Recipe recipe,
    Profile profile,
    RecipeRepository repository, {
    bool ignoreCalories = false,
  }) {
    final avoidedFlags = repository.expandAvoidFlags(profile.avoidFlags);
    if (recipe.contains.intersection(avoidedFlags).isNotEmpty) return false;
    if (repository.ingredientIndex.intersectsAvoided(
      recipe.ingredientIds,
      profile.avoidIngredients,
    )) {
      return false;
    }
    if (!recipe.attributes.containsAll(profile.requiredAttributes)) {
      return false;
    }
    if (recipe.timeMinutes > profile.maxTimeMinutes) return false;
    if (!ignoreCalories &&
        (recipe.caloriesPerServing - profile.calorieTarget).abs() >
            calorieTolerance) {
      return false;
    }
    return true;
  }
}

class RecipeRanker {
  const RecipeRanker._();

  static int score(
    Recipe recipe,
    Profile profile,
    List<HistoryEntry> history, {
    DateTime? now,
  }) {
    final moment = now ?? DateTime.now();
    var score = 0;
    score +=
        recipe.attributes.intersection(profile.requiredAttributes).length * 500;
    if (recipe.axes['effort'] == profile.preferredEffort) score += 140;
    score += max(0, 60 - (recipe.timeMinutes - profile.maxTimeMinutes).abs());
    score += max(
      0,
      90 - (recipe.caloriesPerServing - profile.calorieTarget).abs() ~/ 3,
    );
    if (moment.hour >= 5 &&
        moment.hour < 11 &&
        recipe.mealTypes.contains('breakfast')) {
      score += 200;
    }
    if (moment.hour >= 17 &&
        moment.hour < 21 &&
        recipe.mealTypes.contains('dinner')) {
      score += 90;
    }
    if ((moment.weekday == DateTime.saturday ||
            moment.weekday == DateTime.sunday) &&
        (recipe.axes['effort'] == 'medium' ||
            recipe.axes['effort'] == 'hard')) {
      score += 90;
    }
    DateTime? lastCooked;
    for (final event in history.where((event) => event.recipeId == recipe.id)) {
      if (lastCooked == null || event.cookedAt.isAfter(lastCooked)) {
        lastCooked = event.cookedAt;
      }
    }
    if (lastCooked != null && moment.difference(lastCooked).inDays >= 30) {
      score += 50;
    }
    return score;
  }

  static List<Recipe> rank(
    Iterable<Recipe> recipes,
    Profile profile,
    List<HistoryEntry> history, {
    DateTime? now,
  }) {
    final ranked = recipes.toList();
    ranked.sort((a, b) {
      final difference =
          score(b, profile, history, now: now) -
          score(a, profile, history, now: now);
      return difference != 0 ? difference : a.id.compareTo(b.id);
    });
    return ranked;
  }
}

class PageResult<T> {
  const PageResult({required this.items, this.nextCursor});

  final List<T> items;
  final String? nextCursor;
}

class PaginationController<T> extends ChangeNotifier {
  PaginationController({
    required this.loader,
    this.prefetchThreshold = 10,
    this.maxRendered = 50,
  });

  final Future<PageResult<T>> Function(String? cursor) loader;
  final int prefetchThreshold;
  final int maxRendered;
  final List<T> items = [];
  String? _nextCursor;
  bool isLoading = false;
  Object? error;

  bool get hasMore => _nextCursor != null;

  bool shouldLoadMore(int index) =>
      !isLoading &&
      hasMore &&
      index >= max(0, items.length - prefetchThreshold);

  Future<void> refresh() async {
    items.clear();
    _nextCursor = '';
    error = null;
    await loadMore();
  }

  Future<void> reset() async => refresh();

  Future<void> loadMore() async {
    if (isLoading || (_nextCursor == null && items.isNotEmpty)) return;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final page = await loader(items.isEmpty ? null : _nextCursor);
      items.addAll(page.items);
      if (items.length > maxRendered) {
        items.removeRange(0, items.length - maxRendered);
      }
      _nextCursor = page.nextCursor;
    } catch (caught) {
      error = caught;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}

/// Owns the opt-in one-handed cook gesture and its accidental-tap guard.
class OneHandedCookModeController extends ChangeNotifier {
  OneHandedCookModeController({this.quickNextTapEnabled = false});

  bool quickNextTapEnabled;
  DateTime? _lastTrigger;

  bool canTrigger([DateTime? now]) {
    if (!quickNextTapEnabled) return false;
    final moment = now ?? DateTime.now();
    if (_lastTrigger != null &&
        moment.difference(_lastTrigger!).inMilliseconds < 300) {
      return false;
    }
    _lastTrigger = moment;
    return true;
  }

  void setEnabled(bool value) {
    if (quickNextTapEnabled == value) return;
    quickNextTapEnabled = value;
    notifyListeners();
  }
}

class ShoppingLine {
  const ShoppingLine({
    required this.ingredient,
    required this.amount,
    required this.unit,
    required this.optional,
  });

  final Ingredient? ingredient;
  final double amount;
  final String unit;
  final bool optional;

  String amountLabel() {
    final number = amount == amount.roundToDouble()
        ? amount.toInt().toString()
        : amount.toStringAsFixed(amount < 10 ? 1 : 0);
    return '$number $unit'.trim();
  }
}

class ShoppingAggregator {
  const ShoppingAggregator._();

  static const _volumeToMl = <String, double>{
    'ml': 1,
    'l': 1000,
    'tbsp': 15,
    'tsp': 5,
    'cup': 240,
  };

  static List<ShoppingLine> aggregate(
    Iterable<Recipe> recipes,
    IngredientIndex ingredients,
  ) {
    final buckets = <String, _AmountBucket>{};
    for (final recipe in recipes) {
      for (final ingredient in recipe.ingredients) {
        final bucket = buckets.putIfAbsent(
          ingredient.id,
          () => _AmountBucket(ingredient.id),
        );
        bucket.add(ingredient);
      }
    }
    final lines = buckets.values
        .map((bucket) => bucket.toLine(ingredients.ingredients[bucket.id]))
        .toList();
    lines.sort((a, b) {
      final aisle = (a.ingredient?.aisle ?? '').compareTo(
        b.ingredient?.aisle ?? '',
      );
      if (aisle != 0) return aisle;
      return (a.ingredient?.name['en'] ?? '').compareTo(
        b.ingredient?.name['en'] ?? '',
      );
    });
    return lines;
  }

  static Map<String, List<ShoppingLine>> byAisle(List<ShoppingLine> lines) {
    final result = <String, List<ShoppingLine>>{};
    for (final line in lines) {
      result
          .putIfAbsent(line.ingredient?.aisle ?? 'pantry', () => [])
          .add(line);
    }
    return result;
  }
}

class _AmountBucket {
  _AmountBucket(this.id);

  final String id;
  final Map<String, double> _units = {};
  var optional = true;

  void add(RecipeIngredient ingredient) {
    optional = optional && ingredient.optional;
    final conversion = ShoppingAggregator._volumeToMl[ingredient.unit];
    if (conversion != null) {
      _units['ml'] = (_units['ml'] ?? 0) + ingredient.amount * conversion;
    } else {
      _units[ingredient.unit] =
          (_units[ingredient.unit] ?? 0) + ingredient.amount;
    }
  }

  ShoppingLine toLine(Ingredient? ingredient) {
    final entry = _units.entries.first;
    return ShoppingLine(
      ingredient: ingredient,
      amount: entry.value,
      unit: entry.key,
      optional: optional,
    );
  }
}

class IngredientFrequency {
  const IngredientFrequency(this.ingredientId, this.count);

  final String ingredientId;
  final int count;
}

class ShoppingInsights {
  const ShoppingInsights({
    required this.varietyScore,
    required this.topIngredients,
    required this.seasonalBreakdown,
  });

  final int varietyScore;
  final List<IngredientFrequency> topIngredients;
  final Map<int, int> seasonalBreakdown;

  factory ShoppingInsights.fromEvents(List<ShoppingEvent> events) {
    final counts = <String, int>{};
    final months = <int, int>{};
    for (final event in events) {
      for (final id in event.ingredientIds) {
        counts[id] = (counts[id] ?? 0) + 1;
        months[event.createdAt.month] =
            (months[event.createdAt.month] ?? 0) + 1;
      }
    }
    final top =
        counts.entries
            .map((entry) => IngredientFrequency(entry.key, entry.value))
            .toList()
          ..sort((a, b) => b.count.compareTo(a.count));
    return ShoppingInsights(
      varietyScore: counts.length,
      topIngredients: top.take(5).toList(),
      seasonalBreakdown: months,
    );
  }
}

class DecryptionException implements Exception {
  const DecryptionException(this.message, {this.needsPassword = false});

  final String message;
  final bool needsPassword;

  @override
  String toString() => message;
}

class BackupFiles {
  const BackupFiles({required this.jsonFile, required this.gzipFile});

  final File jsonFile;
  final File gzipFile;
}

class BackupService {
  const BackupService._();

  static const _magic = [0x45, 0x4e, 0x43];

  static String prettyJson(Map<String, dynamic> payload) =>
      const JsonEncoder.withIndent('  ').convert(payload);

  static Future<BackupFiles> writeBackup(
    Map<String, dynamic> payload, {
    String? password,
  }) async {
    final raw = utf8.encode(prettyJson(payload));
    final temporary = await getTemporaryDirectory();
    final jsonFile = File('${temporary.path}/morphcook-backup.json');
    final gzipFile = File('${temporary.path}/morphcook-backup.json.gz');
    final hasPassword = password != null && password.trim().isNotEmpty;
    await jsonFile.writeAsBytes(
      hasPassword ? await encrypt(raw, password) : raw,
      flush: true,
    );
    await gzipFile.writeAsBytes(gzip.encode(raw), flush: true);
    return BackupFiles(jsonFile: jsonFile, gzipFile: gzipFile);
  }

  static Future<Uint8List> encrypt(List<int> input, String password) async {
    final salt = randomBytes(16);
    final nonce = randomBytes(12);
    final secretKey = await _deriveKey(password, salt);
    final box = await AesGcm.with256bits().encrypt(
      input,
      secretKey: secretKey,
      nonce: nonce,
    );
    return Uint8List.fromList([
      ..._magic,
      ...salt,
      ...nonce,
      ...box.mac.bytes,
      ...box.cipherText,
    ]);
  }

  static Future<Map<String, dynamic>> decode(
    List<int> bytes, {
    String? password,
  }) async {
    try {
      List<int> plain;
      if (_hasPrefix(bytes, _magic)) {
        if (password == null || password.isEmpty) {
          throw const DecryptionException(
            'This backup is password-protected. Enter its password to continue.',
            needsPassword: true,
          );
        }
        plain = await _decrypt(bytes, password);
      } else if (_hasPrefix(bytes, const [0x1f, 0x8b])) {
        plain = gzip.decode(bytes);
      } else {
        plain = bytes;
      }
      final decoded = jsonDecode(utf8.decode(plain));
      if (decoded is! Map) {
        throw const DecryptionException(
          'This file is not a valid MorphCook backup.',
        );
      }
      final value = decoded.map((key, value) => MapEntry('$key', value));
      if (value['schema_version'] != 1) {
        throw const DecryptionException(
          'This backup uses an unsupported schema version.',
        );
      }
      return value;
    } on DecryptionException {
      rethrow;
    } on SecretBoxAuthenticationError {
      throw const DecryptionException('Incorrect password. Please try again.');
    } on FormatException {
      throw const DecryptionException(
        'Backup file is corrupted and cannot be restored.',
      );
    } catch (_) {
      throw const DecryptionException(
        'This file is not a valid MorphCook backup.',
      );
    }
  }

  static Future<List<int>> _decrypt(List<int> bytes, String password) async {
    if (bytes.length < 47) {
      throw const DecryptionException(
        'Backup file is corrupted and cannot be restored.',
      );
    }
    final salt = bytes.sublist(3, 19);
    final nonce = bytes.sublist(19, 31);
    final mac = bytes.sublist(31, 47);
    final cipherText = bytes.sublist(47);
    final secretKey = await _deriveKey(password, salt);
    try {
      return await AesGcm.with256bits().decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: secretKey,
      );
    } on SecretBoxAuthenticationError {
      throw const DecryptionException('Incorrect password. Please try again.');
    }
  }

  static Future<SecretKey> _deriveKey(String password, List<int> salt) =>
      Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: 10000,
        bits: 256,
      ).deriveKeyFromPassword(password: password, nonce: salt);

  static bool _hasPrefix(List<int> bytes, List<int> prefix) =>
      bytes.length >= prefix.length &&
      Iterable<int>.generate(
        prefix.length,
      ).every((index) => bytes[index] == prefix[index]);
}
