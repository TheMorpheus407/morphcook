import 'package:flutter/widgets.dart';

import 'app_state.dart';

class MorphCookScope extends InheritedNotifier<MorphCookState> {
  const MorphCookScope({
    super.key,
    required MorphCookState state,
    required super.child,
  }) : super(notifier: state);

  static MorphCookState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MorphCookScope>();
    assert(scope != null, 'MorphCookScope is missing above this context.');
    return scope!.notifier!;
  }
}
