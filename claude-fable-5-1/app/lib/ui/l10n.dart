import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../core/strings.dart';
import '../state/app_controller.dart';

extension L10nContext on BuildContext {
  /// Strings for the current language; rebuilds when the language changes.
  S get s => S(select<AppController, String>((c) => c.lang));

  String get lang => select<AppController, String>((c) => c.lang);
}
