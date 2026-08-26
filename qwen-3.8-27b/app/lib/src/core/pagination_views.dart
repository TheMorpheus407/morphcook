import 'pagination.dart';

class CookbookPagination extends PaginationController<String> {
  CookbookPagination({required this.allIds, this.pageSize = 30});

  /// Saved ids in stable (saved-date) order, newest first.
  final List<String> allIds;

  @override
  String nextCursorOf(List<String> page) =>
      page.isEmpty ? '' : (allIds.indexOf(page.last) + 1).toString();

  @override
  Future<List<String>> fetchPage(String cursorToken) async {
    await Future<void>.delayed(Duration.zero);
    final offset =
        cursorToken.isEmpty ? 0 : (int.tryParse(cursorToken) ?? 0);
    if (offset >= allIds.length) return const [];
    final end = (offset + pageSize).clamp(0, allIds.length);
    return List.of(allIds.sublist(offset, end));
  }
}

/// Time-based pager: items already ordered newest-first; the UI groups them
/// into weekly sections from [timestampOf].
class HistoryPagination extends PaginationController<String> {
  HistoryPagination(
      {required this.all, this.pageSize = 30, required this.timestampOf});

  final List<String> all;
  final int Function(String id) timestampOf;

  @override
  String nextCursorOf(List<String> page) =>
      page.isEmpty ? '' : (all.indexOf(page.last) + 1).toString();

  @override
  Future<List<String>> fetchPage(String cursorToken) async {
    await Future<void>.delayed(Duration.zero);
    final offset =
        cursorToken.isEmpty ? 0 : (int.tryParse(cursorToken) ?? 0);
    if (offset >= all.length) return const [];
    final end = (offset + pageSize).clamp(0, all.length);
    return List.of(all.sublist(offset, end));
  }
}

/// Search pager with a stable composite cursor (`score:id`) so items with
/// equal scores are neither dropped nor duplicated even if the corpus
/// changes between pages.
class SearchPagination extends PaginationController<SearchResult> {
  SearchPagination({required this.ranked, this.pageSize = 20});

  /// Ranked (score desc, then id asc).
  final List<SearchResult> ranked;

  static String _token(SearchResult r) => '${r.score}:${r.recipe.id}';

  ({int score, String id})? _parse(String token) {
    final i = token.lastIndexOf(':');
    if (i <= 0) return null;
    final s = int.tryParse(token.substring(0, i));
    if (s == null) return null;
    return (score: s, id: token.substring(i + 1));
  }

  @override
  String nextCursorOf(List<SearchResult> page) =>
      page.isEmpty ? '' : _token(page.last);

  bool _afterCursor(SearchResult r, ({int score, String id})? c) {
    if (c == null) return true;
    if (r.score != c.score) return r.score < c.score;
    return r.recipe.id > c.id;
  }

  @override
  Future<List<SearchResult>> fetchPage(String cursorToken) async {
    await Future<void>.delayed(Duration.zero);
    if (cursorToken.isEmpty) {
      return List.of(ranked.take(pageSize));
    }
    final c = _parse(cursorToken);
    final page = <SearchResult>[];
    for (final r in ranked) {
      if (_afterCursor(r, c)) page.add(r);
      if (page.length >= pageSize) break;
    }
    return page;
  }
}
