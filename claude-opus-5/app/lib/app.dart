import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'design/motion.dart';
import 'design/palette.dart';
import 'design/theme.dart';
import 'design/widgets/common.dart';
import 'design/widgets/paper.dart';
import 'l10n/strings.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/shell.dart';
import 'state/app_state.dart';

class MorphCookApp extends StatefulWidget {
  const MorphCookApp({super.key, required this.state});

  final AppState state;

  @override
  State<MorphCookApp> createState() => _MorphCookAppState();
}

class _MorphCookAppState extends State<MorphCookApp> {
  @override
  void initState() {
    super.initState();
    widget.state.initialise();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: widget.state,
      child: Consumer<AppState>(
        builder: (context, state, _) {
          final locale = Locale(state.isReady ? state.profile.lang : 'en');
          return MaterialApp(
            title: 'MorphCook',
            debugShowCheckedModeBanner: false,
            theme: MorphTheme.light(),
            darkTheme: MorphTheme.dark(),
            themeMode: ThemeMode.system,
            locale: locale,
            supportedLocales: S.supported.map(Locale.new),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => Motion(
              reduced: Motion.resolve(
                state.isReady ? state.profile.reduceMotion : null,
                context,
              ),
              child: PaperGrain(child: child ?? const SizedBox.shrink()),
            ),
            home: const _Entry(),
          );
        },
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.initError != null) {
      return _StartupFailure(error: state.initError!);
    }
    if (!state.isReady) return const _Splash();
    if (!state.profile.onboardingComplete) return const OnboardingScreen();
    return const AppShell();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('morphcook', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 10),
            SizedBox(width: 120, child: DashedRule(color: colors.edge)),
            const SizedBox(height: 10),
            HandNote(const S('en').tagline, size: 19),
          ],
        ),
      ),
    );
  }
}

class _StartupFailure extends StatelessWidget {
  const _StartupFailure({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EmptyNote(
        headline: 'The cookbook would not open',
        body:
            'The bundled recipe files could not be read. Reinstalling the app '
            'restores them — nothing you saved lives in those files.\n\n$error',
        icon: Icons.error_outline,
      ),
    );
  }
}
