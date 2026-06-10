import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Logs search queries that returned zero results — local-only signal about
/// content gaps, exportable in the backup to inform the corpus team. No network.
class ContentRequestsService extends ChangeNotifier {
  ContentRequestsService(this._box);
  static const _key = 'queries';
  final Box _box;

  List<String> queries() =>
      ((_box.get(_key) as List?) ?? const []).cast<String>();

  Future<void> log(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return;
    final list = queries();
    if (list.contains(q)) return; // dedup
    list.add(q);
    await _box.put(_key, list);
    notifyListeners();
  }

  Future<void> clear() async {
    await _box.delete(_key);
    notifyListeners();
  }

  Future<void> import(List<dynamic> raw, {bool replace = false}) async {
    final existing = replace ? <String>{} : queries().toSet();
    existing.addAll(raw.cast<String>());
    await _box.put(_key, existing.toList());
    notifyListeners();
  }
}
