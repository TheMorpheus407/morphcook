import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'data/app_state.dart';
import 'data/corpus.dart';
import 'data/store.dart';
import 'ui/onboarding.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final corpus = CorpusRepository(bundle: rootBundle);
  final state = AppState(store: HiveStore(), corpus: corpus);
  await corpus.initialize();
  await state.load();
  runApp(MorphCookApp(state: state));
}

class MorphCookApp extends StatelessWidget {
  final AppState state;
  const MorphCookApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: Consumer<AppState>(
        builder: (context, app, _) {
          return MaterialApp(
            title: 'MorphCook',
            debugShowCheckedModeBanner: false,
            theme: LedgerTheme.of(InkPalette.morning),
            darkTheme: LedgerTheme.of(InkPalette.evening),
            builder: (context, child) {
              final dark = Theme.of(context).brightness == Brightness.dark;
              final reduce = app.profile.reduceMotion ??
                  MediaQuery.disableAnimationsOf(context);
              return LedgerScope(
                palette: dark ? InkPalette.evening : InkPalette.morning,
                reduceMotion: reduce,
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: app.onboarded ? const AppShell() : const OnboardingScreen(),
          );
        },
      ),
    );
  }
}
