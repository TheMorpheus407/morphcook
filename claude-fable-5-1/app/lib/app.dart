import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'state/app_controller.dart';
import 'theme/motion.dart';
import 'theme/palette.dart';
import 'theme/paper.dart';
import 'theme/theme.dart';
import 'theme/typography.dart';
import 'ui/l10n.dart';
import 'ui/onboarding/onboarding_flow.dart';
import 'ui/shell/app_shell.dart';

class MorphCookApp extends StatelessWidget {
  const MorphCookApp({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppController>.value(
      value: controller,
      child: Builder(
        builder: (context) {
          final reduce = context.select<AppController, bool?>((c) => c.profile.reduceMotion);
          final lang = context.lang;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent, systemNavigationBarColor: Palette.paper),
            child: MaterialApp(
              title: 'MorphCook',
              debugShowCheckedModeBanner: false,
              theme: MorphTheme.light(),
              locale: Locale(lang),
              supportedLocales: const [Locale('en'), Locale('de')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) {
                final system = MediaQuery.of(context).disableAnimations;
                return Motion(
                  reduceMotion: reduce ?? system,
                  child: PaperBackground(child: child ?? const SizedBox.shrink()),
                );
              },
              home: const _Root(),
            ),
          );
        },
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    if (app.initError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(context.s('error.load', {'error': '${app.initError}'}), style: AppText.body(), textAlign: TextAlign.center),
          ),
        ),
      );
    }
    if (!app.initialized) return const _Splash();
    if (!app.profile.onboardingComplete) return const OnboardingFlow();
    return const AppShell();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('morphcook', style: AppText.display(size: 36)),
              const SizedBox(height: 8),
              Text('opening the book…', style: AppText.mono(color: Palette.inkFaint)),
            ],
          ),
        ),
      );
}
