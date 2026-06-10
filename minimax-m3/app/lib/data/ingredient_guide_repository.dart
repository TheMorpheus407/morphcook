import '../models/ingredient_guide.dart';
import 'local_storage.dart';

class IngredientGuideRepository {
  final Map<String, IngredientGuideEntry> _byId;

  const IngredientGuideRepository(this._byId);

  static Future<IngredientGuideRepository> load() async {
    final json = await loadJsonAsset('assets/ingredient-guide.json');
    final byId = <String, IngredientGuideEntry>{};
    for (final raw in (json['entries'] as List)) {
      final e = IngredientGuideEntry.fromJson(raw as Map<String, dynamic>);
      byId[e.id] = e;
    }
    return IngredientGuideRepository(byId);
  }

  IngredientGuideEntry? entry(String id) => _byId[id];
  List<IngredientGuideEntry> all() => _byId.values.toList();
}
