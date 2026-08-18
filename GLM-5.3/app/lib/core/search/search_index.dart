import '../data/corpus.dart';
import '../models/dish.dart';
import '../models/localized_text.dart';
import '../models/recipe.dart';

/// A search result: the dish plus the variant that matched best.
class SearchHit {
  SearchHit({required this.dish, required this.recipe, required this.score});

  final Dish dish;
  final Recipe recipe;
  final double score;
}

/// Tag filters for search (diet values, cuisine tags, efforts, techniques).
class SearchFilters {
  SearchFilters({this.diets = const {}, this.cuisines = const {}, this.efforts = const {}, this.techniques = const {}});

  final Set<String> diets;
  final Set<String> cuisines;
  final Set<String> efforts;
  final Set<String> techniques;

  bool get isEmpty =>
      diets.isEmpty && cuisines.isEmpty && efforts.isEmpty && techniques.isEmpty;

  SearchFilters copy() => SearchFilters(
        diets: {...diets},
        cuisines: {...cuisines},
        efforts: {...efforts},
        techniques: {...techniques},
      );
}

/// The search index. Tokenizes dish names, recipe titles, cuisine tags,
/// techniques and ingredient names per language into token → dish postings
/// (built at startup from the bundled corpus — the "bundled index" of the
/// SPEC; partition-based loading happens before indexing).
class SearchIndex {
  SearchIndex(this._corpus, this._lang);

  final Corpus _corpus;
  final String _lang;

  final Map<String, Map<String, double>> _postings = {};
  bool _built = false;

  /// Rebuilds the index (called after partitions load / language change).
  void build() {
    _postings.clear();
    for (final dish in _corpus.dishes.values) {
      _add(_tokens(lt(dish.name, _lang)), dish.id, 3);
      for (final tag in dish.cuisineTags) {
        _add(_tokens(tag), dish.id, 1);
      }
      for (final recipeId in dish.variants) {
        final recipe = _corpus.recipe(recipeId);
        if (recipe == null) continue;
        _add(_tokens(lt(recipe.title, _lang)), dish.id, 2);
        for (final tech in recipe.tech) {
          _add(_tokens(tech), dish.id, 1);
        }
        _add({recipe.diet}, dish.id, 1);
        for (final ingredient in recipe.ingredients) {
          _add(_tokens(_corpus.ingredients.nameOf(ingredient.id, _lang)), dish.id, 1);
        }
      }
    }
    _built = true;
  }

  void _add(Set<String> tokens, String dishId, double weight) {
    for (final token in tokens) {
      final perDish = _postings.putIfAbsent(token, () => {});
      perDish[dishId] = (perDish[dishId] ?? 0) + weight;
    }
  }

  Set<String> _tokens(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9äöüß]+'))
        .where((t) => t.length >= 2)
        .toSet();
  }

  /// Raw query → ranked dish ids with score (before profile filtering).
  List<SearchHit> query(String queryString) {
    if (!_built) build();
    final q = queryString.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final scores = <String, double>{};
    for (final token in _tokens(q)) {
      final exact = _postings[token];
      if (exact != null) {
        exact.forEach((dishId, weight) {
          scores[dishId] = (scores[dishId] ?? 0) + weight * 2;
        });
      }
      // Prefix matches (search-as-you-type).
      _postings.forEach((postingToken, perDish) {
        if (postingToken.startsWith(token) && postingToken != token) {
          perDish.forEach((dishId, weight) {
            scores[dishId] = (scores[dishId] ?? 0) + weight;
          });
        }
      });
    }
    final hits = <SearchHit>[];
    scores.forEach((dishId, score) {
      final dish = _corpus.dishes[dishId];
      if (dish == null) return;
      // Any variant stands in as the hit recipe; the caller re-picks per
      // profile via Matcher.pickBest.
      final recipe = _corpus.recipe(dish.variants.first);
      if (recipe == null) return;
      hits.add(SearchHit(dish: dish, recipe: recipe, score: score));
    });
    hits.sort((a, b) => b.score != a.score
        ? b.score.compareTo(a.score)
        : a.dish.id.compareTo(b.dish.id));
    return hits;
  }

  /// Applies the tag filters to a hit list.
  List<SearchHit> applyFilters(List<SearchHit> hits, SearchFilters filters) {
    if (filters.isEmpty) return hits;
    return hits.where((hit) {
      if (filters.diets.isNotEmpty) {
        final hasDiet = hit.dish.variants
            .map((id) => _corpus.recipe(id))
            .whereType<Recipe>()
            .any((r) => filters.diets.contains(r.diet));
        if (!hasDiet) return false;
      }
      if (filters.cuisines.isNotEmpty) {
        final overlap = hit.dish.cuisineTags.any(filters.cuisines.contains);
        if (!overlap) return false;
      }
      if (filters.efforts.isNotEmpty && !filters.efforts.contains(hit.recipe.effort)) {
        return false;
      }
      if (filters.techniques.isNotEmpty) {
        final overlap = hit.recipe.tech.any(filters.techniques.contains);
        if (!overlap) return false;
      }
      return true;
    }).toList();
  }
}
