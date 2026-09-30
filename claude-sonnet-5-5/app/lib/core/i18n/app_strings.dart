import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../data/asset_source.dart';
import 'localized_text.dart';

/// The UI string table (`assets/i18n/strings.json`): every key maps to a
/// `Map<lang, String>`, so a new language is a data addition.
class AppStringsData {
  AppStringsData(this._table);

  factory AppStringsData.fromJson(Map<String, dynamic> json) {
    return AppStringsData({
      for (final e in (json['strings'] as Map).entries) e.key.toString(): LocalizedText.fromJson(e.value),
    });
  }

  static Future<AppStringsData> load(AssetSource source) async =>
      AppStringsData.fromJson(await source.loadJson('i18n/strings.json'));

  final Map<String, LocalizedText> _table;

  Iterable<String> get keys => _table.keys;
  bool has(String key) => _table.containsKey(key);
  LocalizedText? entry(String key) => _table[key];
}

/// Looks up UI text for one language. Call it like a function: `s('home.title')`.
class AppStrings {
  const AppStrings(this.data, this.lang);

  final AppStringsData data;
  final String lang;

  /// Finds [key] in the current language, falling back to English. `{name}`
  /// placeholders are filled from [args]. An unknown key returns the key itself
  /// so the gap is visible instead of blank.
  String call(String key, [Map<String, Object?>? args]) => t(key, args);

  String t(String key, [Map<String, Object?>? args]) {
    final entry = data.entry(key);
    if (entry == null) return key;
    var text = entry.resolve(lang);
    if (args != null) {
      args.forEach((name, value) => text = text.replaceAll('{$name}', '$value'));
    }
    return text;
  }

  bool has(String key) => data.has(key);

  /// `key.one` for exactly 1, else `key.other`; `{n}` is filled with [count].
  String plural(String key, num count, [Map<String, Object?>? args]) {
    final form = count == 1 ? '$key.one' : '$key.other';
    return t(form, {'n': _number(count), ...?args});
  }

  String _number(num n) {
    final text = n == n.roundToDouble() ? n.round().toString() : n.toStringAsFixed(1);
    return lang == 'de' ? text.replaceAll('.', ',') : text;
  }

  // ---- dates in the paper voice (lowercase weekday and month names)

  String weekday(int weekday, {bool short = false}) => t('date.wd.${short ? 's' : 'l'}.$weekday');

  String month(int month, {bool short = false}) => t('date.m.${short ? 's' : 'l'}.$month');

  /// `monday, 28 september 2026`
  String longDate(DateTime d) =>
      '${weekday(d.weekday)}, ${d.day}${lang == 'de' ? '.' : ''} ${month(d.month)} ${d.year}';

  /// `mon 28 sep`
  String shortDate(DateTime d) =>
      '${weekday(d.weekday, short: true)} ${d.day}${lang == 'de' ? '.' : ''} ${month(d.month, short: true)}';

  String minutes(int minutes) => t('unit.min', {'n': minutes});

  String kcal(int kcal) => t('unit.kcal', {'n': kcal});

  AppStrings withLanguage(String newLang) => AppStrings(data, newLang);
}

extension AppStringsContext on BuildContext {
  /// UI text for the current language; rebuilds when the language changes.
  AppStrings get s => Provider.of<AppStrings>(this);

  /// UI text without listening (event handlers, initState).
  AppStrings get sRead => Provider.of<AppStrings>(this, listen: false);
}
