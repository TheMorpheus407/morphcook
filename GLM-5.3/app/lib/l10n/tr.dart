import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'strings.dart';

/// `context.tr('key', {'n': '3'})` — translates against the profile
/// language and rebuilds the widget when the language (or any state) changes.
extension TrX on BuildContext {
  String tr(String key, [Map<String, String>? params]) {
    final lang = watch<AppState>().profile.lang;
    return AppL.t(lang, key, params);
  }

  /// Same lookup without subscribing (for callbacks and snackbars).
  String trRead(String key, [Map<String, String>? params]) {
    final lang = read<AppState>().profile.lang;
    return AppL.t(lang, key, params);
  }

  String get appLang => watch<AppState>().profile.lang;
}
