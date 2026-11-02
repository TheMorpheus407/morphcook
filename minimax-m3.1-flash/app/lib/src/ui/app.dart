import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../data/corpus.dart';
import '../data/repositories.dart';
import '../design/motion.dart';
import '../design/typography.dart';
import '../state/app_state.dart';
import '../state/cookbook_controller.dart';
import '../state/history_controller.dart';
import '../state/meal_plan_controller.dart';
import '../state/profile_controller.dart';
import '../state/shopping_controller.dart';
import 'onboarding/onboarding_screen.dart';
import 'shell/home_shell.dart';

/// The application root.
class MorphCookApp extends StatelessWidget {
  const MorphCookApp({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: state),
        ChangeNotifierProvider<ProfileController>.value(value: state.profile),
        ChangeNotifierProvider<CookbookController>.value(value: state.cookbook),
        ChangeNotifierProvider<MealPlanController>.value(value: state.mealPlan),
        ChangeNotifierProvider<ShoppingController>.value(value: state.shopping),
        ChangeNotifierProvider<HistoryController>.value(value: state.history),
        // The corpus is a ChangeNotifier: it announces when a lazily loaded
        // partition arrives, so it has to be provided as one.
        ChangeNotifierProvider<Corpus>.value(value: state.corpus),
        Provider<FaqRepository>.value(value: state.faqs),
        Provider<IngredientGuideRepository>.value(value: state.ingredientGuide),
      ],
      child: const _MorphCookMaterialApp(),
    );
  }
}

class _MorphCookMaterialApp extends StatelessWidget {
  const _MorphCookMaterialApp();

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileController>();
    final lang = profile.lang;

    return MaterialApp(
      title: 'MorphCook',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: Locale(lang),
      supportedLocales: const <Locale>[Locale('en'), Locale('de')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return MotionScope(
          reduceMotion: profile.profile.reduceMotion,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const _RootRouter(),
    );
  }
}

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileController>();
    if (!profile.profile.onboardingComplete) return const OnboardingScreen();
    return const HomeShell();
  }
}
