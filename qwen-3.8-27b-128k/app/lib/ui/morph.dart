/// Root injection: corpus (lazy-loaded partitions), app store, language.
/// Screens read via [Morph.of] and rebuild via [ListenableBuilder].
library;

import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

import '../core/corpus.dart';
import '../core/l10n.dart';
import '../core/matching.dart';
import '../core/models.dart';
import '../state/store.dart';

class CorpusNotifier extends ChangeNotifier {
  CorpusNotifier(this._corpus);
  Corpus _corpus;

  set corpus(Corpus c) {
    _corpus = c;
    notifyListeners();
  }

  Corpus get corpus => _corpus;
}

class MorphData {
  MorphData(this.store, this.corpus, this.loc, this.appStart);
  final AppStore store;
  final CorpusNotifier corpus;
  final LanguageNotifier loc;
  final DateTime appStart;

  String get lang => loc.lang;
  String t(String key) => L10n.t(key, loc.lang);
  String tf(String key, Map<String, String> args) =>
      L10n.tf(key, loc.lang, args);

  Corpus get c => corpus.corpus;
  Profile get profile => store.profile;

  // ---- profile-derived sets ---------------------------------------------
  Map<String, List<String>> expansionMap() {
    final m = <String, List<String>>{};
    for (final f in c.compoundFlags) {
      m[f.id] = f.expandsTo;
    }
    return m;
  }

  Set<String> get expandedAvoidFlags =>
      expandAvoidFlags(profile.avoidFlags, expansionMap());

  Set<String> get avoidedIngredients {
    final out = <String>{};
    for (final id in profile.avoidIngredients) {
      out.add(id);
      final members = c.tree[id];
      if (members != null) out.addAll(members);
    }
    return out;
  }

  // ---- spec matching -------------------------------------------------------
  VisResult check(Recipe r, {bool calorieOverride = false}) => visibleRecipe(
        r,
        profile,
        expandedAvoidFlags,
        avoidedIngredients,
        calorieOverride: calorieOverride,
      );

  bool visible(Recipe r, {bool calorieOverride = false}) =>
      check(r, calorieOverride: calorieOverride).ok;

  int score(Recipe r) {
    var matched = 0;
    for (final req in profile.requiredAttributes) {
      if (r.tags.contains(req)) matched++;
    }
    return rankScore(
      r,
      profile,
      requiredMatchCount: matched,
      lastCookedAt: store.lastCooked(r.id),
    );
  }

  /// The variant of [dish] the profile prefers, or null if none is visible.
  Recipe? bestVariant(Dish dish, {bool calorieOverride = false}) {
    Recipe? best;
    int? bestScore;
    for (final id in dish.variantRecipeIds) {
      final r = c.recipes[id];
      if (r == null) continue;
      if (!visible(r, calorieOverride: calorieOverride)) continue;
      final s = score(r);
      if (bestScore == null || s > bestScore) {
        bestScore = s;
        best = r;
      }
    }
    return best;
  }

  List<Recipe> visibleRecipes({bool calorieOverride = false}) {
    final out = <Recipe>[];
    for (final r in c.recipes.values) {
      if (visible(r, calorieOverride: calorieOverride)) out.add(r);
    }
    out.sort((a, b) {
      final d = score(b).compareTo(score(a));
      if (d != 0) return d;
      return a.id.compareTo(b.id);
    });
    return out;
  }

  List<Dish> visibleDishes({bool calorieOverride = false}) {
    final out = <Dish>[];
    for (final d in c.dishes.values) {
      if (bestVariant(d, calorieOverride: calorieOverride) != null) out.add(d);
    }
    out.sort((a, b) {
      final ra = bestVariant(a, calorieOverride: calorieOverride)!;
      final rb = bestVariant(b, calorieOverride: calorieOverride)!;
      final d2 = score(rb).compareTo(score(ra));
      if (d2 != 0) return d2;
      return a.id.compareTo(b.id);
    });
    return out;
  }
}

class Morph extends InheritedWidget {
  const Morph({super.key, required this.data, required super.child});
  final MorphData data;

  static MorphData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Morph>()!.data;

  @override
  bool updateShouldNotify(covariant Morph oldWidget) =>
      oldWidget.data != data;
}

List<String> _coreAssets() => [
      'assets/data/core-recipes.json',
      'assets/data/dishes.json',
      'assets/data/ontology.json',
      'assets/data/ingredients.json',
      'assets/data/faqs.json',
      'assets/data/ingredient-guide.json',
    ];

Corpus _corpusFrom(List<String> parts, List<String> others) => corpusFromJson(
    parts, others[0], others[1], others[2], others[3], others[4]);

/// Loads the corpus: core partition eagerly, extended partition lazily
/// (spec: partition-based chunk loading), plus all shared assets.
Future<CorpusNotifier> bootCorpus() async {
  final assets = _coreAssets();
  final strings = await Future.wait<String>(
      assets.map((p) => rootBundle.loadString(p)));
  final core = strings[0];
  final others = strings.sublist(1);
  final notifier = CorpusNotifier(_corpusFrom([core], others));

  // Lazy partition (spec): fetch the extended partition on demand, in the
  // background, once the core is on screen.
  unawaited(() async {
    try {
      final extended =
          await rootBundle.loadString('assets/data/extended-recipes.json');
      notifier.corpus = _corpusFrom([core, extended], others);
    } catch (_) {
      // stay on the core partition rather than fail the app
    }
  }());

  return notifier;
}
