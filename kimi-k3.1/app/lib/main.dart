import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'localization/app_localizations.dart';
import 'services/local_store.dart';
import 'services/recipe_repository.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/paper_widgets.dart';

export 'app.dart' show MorphCookApp;
export 'screens/app_shell.dart' show AppShell;
export 'screens/onboarding_screen.dart' show OnboardingScreen;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const BootstrapApp());
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  late Future<AppState> future = load();
  AppState? state;

  Future<AppState> load() async {
    await initializeDateFormatting();
    final repository = RecipeRepository();
    final results = await Future.wait([
      repository.load(),
      HiveStateStore.open(),
    ]);
    final app = AppState(
      repository: repository,
      store: results[1] as LocalStateStore,
    );
    await app.initialize();
    if (app.initializationError != null) throw app.initializationError!;
    return app;
  }

  @override
  void dispose() {
    if (state != null) unawaited(state!.close());
    super.dispose();
  }

  MaterialApp frame(Widget home) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: WidgetsBinding.instance.platformDispatcher.locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: buildAppTheme(),
    home: home,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<AppState>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return frame(
          Scaffold(
            body: Paper(
              child: SafeArea(
                child: EmptyState(
                  title: context.l10n.t('load_error'),
                  body: snapshot.error.toString(),
                  action: FilledButton(
                    onPressed: () => setState(() => future = load()),
                    child: Text(context.l10n.t('retry')),
                  ),
                ),
              ),
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return frame(
          Scaffold(
            body: Paper(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'morphcook.',
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                    const SizedBox(height: 9),
                    Text(
                      context.l10n.t('tagline'),
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.handwritten,
                    ),
                    const SizedBox(height: 28),
                    const CircularProgressIndicator(strokeWidth: 1.2),
                    const SizedBox(height: 12),
                    Text(context.l10n.t('loading')),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      state ??= snapshot.data;
      return ChangeNotifierProvider.value(
        value: state!,
        child: const MorphCookApp(),
      );
    },
  );
}
