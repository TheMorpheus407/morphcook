import 'package:flutter/foundation.dart';

import '../../core/text/text_fold.dart';
import '../storage/storage.dart';

/// Searches that found nothing, kept on the device only.
///
/// They tell the corpus team which dishes are missing; the list travels with a
/// backup and is never sent anywhere.
class ContentRequestLog extends ChangeNotifier {
  ContentRequestLog._(this._box) {
    _load();
  }

  static Future<ContentRequestLog> open(AppStorage storage) async {
    return ContentRequestLog._(await storage.records.open(Boxes.contentRequests));
  }

  static const int maxEntries = 200;

  final RecordBox _box;
  final List<_Request> _requests = <_Request>[];

  /// Oldest first, as exported.
  List<String> get queries => [for (final r in _requests) r.query];
  int get count => _requests.length;

  static String normalize(String query) => TextFold.words(query).map(TextFold.fold).join(' ');

  void _load() {
    for (final entry in _box.entries) {
      final json = _box.getJson(entry.key);
      final query = json?['query'] as String?;
      final at = DateTime.tryParse((json?['at'] as String?) ?? '');
      if (query != null && at != null) _requests.add(_Request(entry.key, query, at));
    }
    _requests.sort((a, b) => a.at.compareTo(b.at));
  }

  /// Logs a query with no results. Keeps only the most specific spelling: a
  /// shorter logged prefix ("pad") is replaced by "pad thai".
  Future<void> add(String query, {DateTime? at}) async {
    final key = normalize(query);
    if (key.length < 2) return;
    if (_requests.any((r) => r.key == key)) return;
    // A longer earlier request already covers this one.
    if (_requests.any((r) => r.key.startsWith(key))) return;
    final covered = _requests.where((r) => key.startsWith(r.key)).toList();
    for (final r in covered) {
      _requests.remove(r);
      await _box.delete(r.key);
    }
    final when = at ?? DateTime.now();
    _requests.add(_Request(key, query.trim(), when));
    while (_requests.length > maxEntries) {
      final oldest = _requests.removeAt(0);
      await _box.delete(oldest.key);
    }
    notifyListeners();
    await _box.putJson(key, <String, dynamic>{'query': query.trim(), 'at': when.toUtc().toIso8601String()});
  }

  Future<void> restore(Iterable<String> queries, {required bool replace}) async {
    if (replace) {
      _requests.clear();
      await _box.clear();
    }
    for (final q in queries) {
      await add(q);
    }
    notifyListeners();
  }

  Future<void> clear() async {
    _requests.clear();
    await _box.clear();
    notifyListeners();
  }
}

class _Request {
  _Request(this.key, this.query, this.at);
  final String key;
  final String query;
  final DateTime at;
}
