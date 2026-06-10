import 'package:flutter/foundation.dart';

import 'local_storage.dart';

/// Logs zero-result search queries — surfaces to maintainers what users
/// expected to find but didn't. Exported with backups.
class ContentRequestRepository extends ChangeNotifier {
  ContentRequestRepository._(this._storage, this._items);

  final LocalStorage _storage;
  final List<_Request> _items;

  static const _key = 'content_requests';

  static Future<ContentRequestRepository> load(LocalStorage storage) async {
    final raw = await storage.readJsonList(_key);
    final items = <_Request>[];
    if (raw != null) {
      for (final r in raw) {
        if (r is Map<String, dynamic>) {
          items.add(_Request.fromJson(r));
        } else if (r is String) {
          items.add(_Request(query: r, loggedAt: DateTime.now()));
        }
      }
    }
    return ContentRequestRepository._(storage, items);
  }

  List<String> queries() => _items.map((e) => e.query).toList();

  Future<void> add(String query) async {
    final norm = query.trim().toLowerCase();
    if (norm.isEmpty) return;
    if (_items.any((e) => e.query == norm)) return; // dedup
    _items.add(_Request(query: norm, loggedAt: DateTime.now()));
    await _persist();
  }

  Future<void> clear() async {
    _items.clear();
    await _persist();
  }

  Future<void> _persist() async {
    await _storage.writeJson(
      _key,
      _items.map((e) => e.toJson()).toList(),
    );
    notifyListeners();
  }

  List<Map<String, dynamic>> toBackup() =>
      _items.map((e) => e.toJson()).toList();

  Future<void> replaceFromBackup(Iterable<dynamic> raw) async {
    _items.clear();
    for (final r in raw) {
      if (r is Map<String, dynamic>) {
        _items.add(_Request.fromJson(r));
      } else if (r is String) {
        _items.add(_Request(query: r, loggedAt: DateTime.now()));
      }
    }
    await _persist();
  }
}

class _Request {
  final String query;
  final DateTime loggedAt;
  const _Request({required this.query, required this.loggedAt});

  Map<String, dynamic> toJson() => {
        'query': query,
        'logged_at': loggedAt.toIso8601String(),
      };

  factory _Request.fromJson(Map<String, dynamic> json) => _Request(
        query: (json['query'] as String?) ?? '',
        loggedAt:
            DateTime.tryParse(json['logged_at'] as String? ?? '') ?? DateTime.now(),
      );
}
