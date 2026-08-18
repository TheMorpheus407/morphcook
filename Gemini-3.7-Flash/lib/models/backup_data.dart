import 'profile.dart';
import 'cooking_history_item.dart';
import 'shopping_item.dart';

class BackupData {
  final int schemaVersion;
  final String exportedAt;
  final UserProfile profile;
  final List<String> saved;
  final Map<String, Map<String, String>> mealPlan;
  final List<CookingHistoryItem> history;
  final List<ShoppingItem> shoppingList;
  final List<String> contentRequests;

  const BackupData({
    this.schemaVersion = 1,
    required this.exportedAt,
    required this.profile,
    required this.saved,
    required this.mealPlan,
    required this.history,
    required this.shoppingList,
    required this.contentRequests,
  });

  factory BackupData.fromJson(Map<String, dynamic> json) {
    final schema = json['schema_version'] as int? ?? 1;
    final exported = json['exported_at'] as String? ?? DateTime.now().toIso8601String();
    final prof = json['profile'] != null
        ? UserProfile.fromJson(json['profile'] as Map<String, dynamic>)
        : UserProfile.defaultProfile();

    final savedList = (json['saved'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();

    final mp = <String, Map<String, String>>{};
    if (json['meal_plan'] is Map) {
      (json['meal_plan'] as Map<String, dynamic>).forEach((weekKey, slotsVal) {
        if (slotsVal is Map) {
          final slotMap = <String, String>{};
          slotsVal.forEach((slotKey, rId) {
            if (rId != null) slotMap[slotKey.toString()] = rId.toString();
          });
          mp[weekKey] = slotMap;
        }
      });
    }

    final hist = (json['history'] as List<dynamic>? ?? [])
        .map((e) => CookingHistoryItem.fromJson(e as Map<String, dynamic>))
        .toList();

    final shop = (json['shopping_list'] as List<dynamic>? ?? [])
        .map((e) => ShoppingItem.fromJson(e as Map<String, dynamic>))
        .toList();

    final reqs = (json['content_requests'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();

    return BackupData(
      schemaVersion: schema,
      exportedAt: exported,
      profile: prof,
      saved: savedList,
      mealPlan: mp,
      history: hist,
      shoppingList: shop,
      contentRequests: reqs,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'exported_at': exportedAt,
    'profile': profile.toJson(),
    'saved': saved,
    'meal_plan': mealPlan,
    'history': history.map((e) => e.toJson()).toList(),
    'shopping_list': shoppingList.map((e) => e.toJson()).toList(),
    'content_requests': contentRequests,
  };
}
