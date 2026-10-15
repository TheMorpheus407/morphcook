import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'state/app_state.dart';
import 'theme/nostalgic_theme.dart';
import 'widgets/nostalgic_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  NostalgicTheme.ensureOfflineFontsConfigured();

  final appState = MorphCookAppState();
  await appState.initialize();

  runApp(MorphCookApp(appState: appState));
}

class MorphCookApp extends StatelessWidget {
  final MorphCookAppState appState;

  const MorphCookApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MorphCookAppState>.value(
      value: appState,
      child: Consumer<MorphCookAppState>(
        builder: (context, state, _) {
          return MaterialApp(
            title: 'MorphCook',
            debugShowCheckedModeBanner: false,
            theme: NostalgicTheme.lightTheme,
            locale: Locale(state.lang),
            supportedLocales: const [
              Locale('en'),
              Locale('de'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: !state.isInitialized
                ? const Scaffold(
                    body: PaperGrainBackground(
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  )
                : (state.profile.onboardingCompleted
                    ? const MainShell()
                    : const OnboardingScreen()),
          );
        },
      ),
    );
  }
}
