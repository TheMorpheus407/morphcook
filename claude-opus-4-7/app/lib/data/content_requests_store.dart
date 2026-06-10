import 'package:flutter/foundation.dart';
import 'json_file_store.dart';

/// Local log of search queries that returned zero results.
/// Never leaves the device on its own — only exported via the backup file.
class ContentRequestsStore extends ChangeNotifier {
  final _store = JsonFileStore('content_requests.json');
  final List<String> _queries = [];
  bool _loaded = false;

  bool get loaded => _loaded;
  List<String> get queries => List.unmodifiable(_queries);

  Future<void> load() async {
    final raw = await _store.read(fallback: const []);
    _queries.clear();
    _queries.addAll((raw as List).map((e) => e.toString()));
    _loaded = true;
    notifyListeners();
  }

  Future<void> record(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return;
    if (_queries.contains(q)) return;
    _queries.add(q);
    await _persist();
  }

  Future<void> clear() async {
    _queries.clear();
    await _persist();
  }

  Future<void> replaceAll(List<String> incoming) async {
    _queries
      ..clear()
      ..addAll(incoming);
    await _persist();
  }

  Future<void> _persist() async {
    await _store.write(_queries);
    notifyListeners();
  }
}
