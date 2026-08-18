import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../core/l10n.dart';
import '../data/corpus.dart';
import '../data/stores.dart';
import '../logic/matching.dart';
import '../logic/ranking.dart';
import '../models/recipe.dart';

export '../data/corpus.dart';
export '../data/stores.dart';
export '../logic/matching.dart';
export '../logic/ranking.dart';

/// Convenient context lookups used across all screens.
extension AppContext on BuildContext {
  AppStore get store => read<AppStore>();
  LocaleController get loc => read<LocaleController>();
  Corpus get corpus => read<Corpus>();
  Matcher get matcher => read<Matcher>();
  Ranker get ranker => read<Ranker>();

  String get lang => loc.lang;
  String t(String key) => loc.t(key);
  String pick(Map<String, String> m) => loc.pick(m);

  /// Localized name of a recipe.
  String recipeName(Recipe r) => loc.pick(r.name);

  /// Localized name of an ingredient id, falling back to the raw id.
  String ingredientName(String id) {
    final node = corpus.ingredientTree.byId(id);
    if (node == null) return id;
    return loc.pick(node.name);
  }

  /// Aisle label for an aisle id.
  String aisleLabel(String aisle) =>
      t('aisle.$aisle') == 'aisle.$aisle' ? t('aisle.other') : t('aisle.$aisle');
}

class AppScope extends StatelessWidget {
  const AppScope({
    super.key,
    required this.corpus,
    required this.store,
    required this.loc,
    required this.child,
  });

  final Corpus corpus;
  final AppStore store;
  final LocaleController loc;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: loc),
        ChangeNotifierProvider.value(value: store),
        Provider<Corpus>.value(value: corpus),
        Provider<Matcher>.value(
          value: Matcher(ingredientTree: corpus.ingredientTree),
        ),
        Provider<Ranker>.value(value: const Ranker()),
      ],
      child: child,
    );
  }
}
