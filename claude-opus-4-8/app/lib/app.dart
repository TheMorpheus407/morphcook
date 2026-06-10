import 'package:flutter/material.dart';

import 'core/app_scope.dart';
import 'models/profile.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'screens/root_shell.dart';
import 'theme/app_theme.dart';

/// Root app widget. Rebuilds on profile changes (language + onboarding state),
/// routing between the onboarding flow and the main shell.
class MorphCookApp extends StatelessWidget {
  const MorphCookApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.services.profile,
      builder: (context, _) {
        final Profile profile = scope.services.profile.profile;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'MorphCook',
          theme: AppTheme.light(),
          home: profile.onboarded ? const RootShell() : const OnboardingFlow(),
        );
      },
    );
  }
}
