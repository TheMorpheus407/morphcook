import 'package:flutter/foundation.dart';

import '../domain/search/search_service.dart';

/// Lets any screen ask the tab shell to switch tabs, optionally with a search
/// pre-filled ("more italian dishes").
class NavRequests extends ChangeNotifier {
  int? _tab;
  SearchFilters? _filters;
  String? _query;

  /// Pending tab switch, cleared by [consumeTab].
  int? get pendingTab => _tab;

  SearchFilters? get pendingFilters => _filters;
  String? get pendingQuery => _query;

  void showTab(int tab) {
    _tab = tab;
    notifyListeners();
  }

  /// Switches to the search tab with [filters] and [query] applied.
  void showSearch({SearchFilters? filters, String? query}) {
    _filters = filters;
    _query = query;
    _tab = 1;
    notifyListeners();
  }

  int? consumeTab() {
    final tab = _tab;
    _tab = null;
    return tab;
  }

  /// Takes the pending search request, if any, and clears it.
  ({SearchFilters? filters, String? query})? consumeSearch() {
    if (_filters == null && _query == null) return null;
    final request = (filters: _filters, query: _query);
    _filters = null;
    _query = null;
    return request;
  }
}
