import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Remembers where the user paused in cook mode so they can pick it up later.
class CookProgress {
  CookProgress(this.step, this.servings);
  final int step;
  final int servings;
}

class CookProgressService extends ChangeNotifier {
  CookProgressService(this._box);
  final Box _box;

  CookProgress? load(String recipeId) {
    final raw = _box.get(recipeId) as Map?;
    if (raw == null) return null;
    return CookProgress(
      (raw['step'] as num?)?.toInt() ?? 0,
      (raw['servings'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> save(String recipeId, int step, int servings) async {
    await _box.put(recipeId, {'step': step, 'servings': servings});
  }

  Future<void> clear(String recipeId) async {
    await _box.delete(recipeId);
  }
}
