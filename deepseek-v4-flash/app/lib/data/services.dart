import 'package:flutter/widgets.dart';

import '../data/app_state.dart';
import '../data/corpus.dart';
import '../logic/matching.dart';

/// Inherited service locator: corpus (read models), app state (user data),
/// matcher (pure logic). One instance is created in `main()`.
class Services extends InheritedWidget {
  final Corpus corpus;
  final AppState state;
  final RecipeMatcher matcher;

  const Services({
    super.key,
    required this.corpus,
    required this.state,
    required this.matcher,
    required super.child,
  });

  static Services of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<Services>();
    assert(s != null, 'Services not available in this context');
    return s!;
  }

  @override
  bool updateShouldNotify(Services old) =>
      corpus != old.corpus || state != old.state || matcher != old.matcher;
}