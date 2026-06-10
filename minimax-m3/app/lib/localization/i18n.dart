import 'package:flutter/material.dart';

import 'strings.dart';

/// InheritedNotifier scope that holds the current language and rebuilds any
/// widget that asks for it via [I18n.of].
class I18n extends InheritedNotifier<LanguageNotifier> {
  const I18n({
    super.key,
    required LanguageNotifier notifier,
    required super.child,
  }) : super(notifier: notifier);

  static Strings of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<I18n>();
    final lang = widget?.notifier?.lang ?? 'en';
    return Strings(lang);
  }

  static LanguageNotifier notifierOf(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<I18n>();
    return widget?.notifier ?? LanguageNotifier('en');
  }
}

class LanguageNotifier extends ChangeNotifier {
  LanguageNotifier(this._lang);
  String _lang;
  String get lang => _lang;

  void setLang(String lang) {
    if (lang == _lang) return;
    _lang = lang;
    notifyListeners();
  }
}
