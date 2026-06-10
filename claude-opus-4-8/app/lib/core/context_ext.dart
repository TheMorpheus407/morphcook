import 'package:flutter/widgets.dart';

import 'app_scope.dart';
import 'localized.dart';
import 'strings.dart';

/// Ergonomic accessors used everywhere in the UI.
extension AppContext on BuildContext {
  AppScope get scope => AppScope.of(this);
  AppLang get lang => AppScope.of(this).services.profile.lang;
  S get s => S(lang);

  /// Static UI string by key.
  String tr(String key) => S(lang).t(key);

  /// Resolve a corpus [LocalizedText] for the current language.
  String loc(LocalizedText text) => text.resolve(lang);
}
