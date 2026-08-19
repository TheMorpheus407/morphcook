import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'state/app_state.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MorphCookApp());
}

/// The production MaterialApp configuration — shared with widget tests so
/// the localization setup (locale support, delegates) can never drift
/// between test and prod.
MaterialApp morphCookMaterialApp({required Lang lang, required Widget home}) {
  return MaterialApp(
    title: 'MorphCook',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(lang),
    locale: Locale(lang.name),
    supportedLocales: const [Locale('en'), Locale('de')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
  );
}

class MorphCookApp extends StatelessWidget {
  const MorphCookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const _App(),
    );
  }
}

class _App extends StatefulWidget {
  const _App();

  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  AppState? _app;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app ??= context.read<AppState>()..bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.profile.lang;

    return morphCookMaterialApp(
      lang: lang,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: !app.loaded
            ? const _Boot()
            : app.onboarded
                ? const HomeShell(key: ValueKey('home'))
                : OnboardingScreen(key: const ValueKey('onboarding')),
      ),
    );
  }
}

class _Boot extends StatelessWidget {
  const _Boot();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.paper,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'morphcook',
            style: TextStyle(
              fontFamily: AppTheme.display,
              fontStyle: FontStyle.italic,
              fontSize: 40,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(
            width: 120,
            child: LinearProgressIndicator(
              color: AppTheme.coral,
              backgroundColor: AppTheme.line,
            ),
          ),
        ]),
      ),
    );
  }
}
