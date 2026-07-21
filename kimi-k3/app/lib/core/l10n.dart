import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'storage/profile_store.dart';

/// Tiny string-table localization (EN + DE, N-ready).
///
/// Core keys live here; feature modules contribute their own maps via
/// [AppStrings.register] at startup to avoid a single giant file.
class AppStrings {
  static final Map<String, Map<String, String>> _table = {
    ..._core,
  };

  static void register(Map<String, Map<String, String>> entries) {
    entries.forEach((key, langs) {
      _table.putIfAbsent(key, () => langs);
    });
  }

  final String lang;
  const AppStrings(this.lang);

  String t(String key) =>
      _table[key]?[lang] ?? _table[key]?['en'] ?? key;

  static AppStrings of(BuildContext context) =>
      AppStrings(context.watch<ProfileStore>().profile.lang);

  static const Map<String, Map<String, String>> _core = {
    'app.name': {'en': 'MorphCook', 'de': 'MorphCook'},
    'nav.home': {'en': 'home', 'de': 'start'},
    'nav.cookbook': {'en': 'cookbook', 'de': 'kochbuch'},
    'nav.search': {'en': 'search', 'de': 'suchen'},
    'nav.plan': {'en': 'plan', 'de': 'plan'},
    'nav.shopping': {'en': 'shopping', 'de': 'einkauf'},
    'common.save': {'en': 'save', 'de': 'speichern'},
    'common.cancel': {'en': 'cancel', 'de': 'abbrechen'},
    'common.delete': {'en': 'delete', 'de': 'löschen'},
    'common.close': {'en': 'close', 'de': 'schließen'},
    'common.back': {'en': 'back', 'de': 'zurück'},
    'common.next': {'en': 'next', 'de': 'weiter'},
    'common.done': {'en': 'done', 'de': 'fertig'},
    'common.minutes': {'en': 'min', 'de': 'min'},
    'common.kcal': {'en': 'kcal', 'de': 'kcal'},
    'common.servings': {'en': 'servings', 'de': 'portionen'},
    'common.loading': {'en': 'loading…', 'de': 'lädt…'},
    'common.empty': {'en': 'nothing here yet', 'de': 'hier ist noch nichts'},
    'effort.easy': {'en': 'easy', 'de': 'einfach'},
    'effort.medium': {'en': 'medium', 'de': 'mittel'},
    'effort.hard': {'en': 'hard', 'de': 'aufwendig'},
    'diet.classic': {'en': 'classic', 'de': 'klassisch'},
    'diet.vegetarian': {'en': 'vegetarian', 'de': 'vegetarisch'},
    'diet.vegan': {'en': 'vegan', 'de': 'vegan'},
    'calorie.light': {'en': 'lighter', 'de': 'leichter'},
    'calorie.hearty': {'en': 'hearty', 'de': 'deftig'},
  };
}

/// Convenience shorthand.
AppStrings S(BuildContext context) => AppStrings.of(context);
