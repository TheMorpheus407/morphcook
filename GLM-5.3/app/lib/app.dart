import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_fonts.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/shell.dart';
import 'state/app_state.dart';

/// The root widget: paper theme, provider wiring, onboarding gate.
class MorphCookApp extends StatelessWidget {
  const MorphCookApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return MaterialApp(
            title: 'morphcook',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: appState.onboardingDone
                ? const Shell()
                : OnboardingFlow(profile: appState.profile),
          );
        },
      ),
    );
  }
}

/// Call once in tests before pumping to avoid google_fonts HTTP fetches.
void configureAppForTests() {
  AppFonts.googleFontsEnabled = false;
}
