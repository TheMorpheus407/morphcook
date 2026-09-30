import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/i18n/app_strings.dart';
import '../core/motion.dart';
import '../core/theme/app_theme.dart';
import '../data/corpus.dart';
import '../domain/search/search_service.dart';
import '../domain/shopping/aggregator.dart';
import '../features/onboarding/onboarding_flow.dart';
import '../state/app_services.dart';
import '../state/backup_service.dart';
import '../state/catalog.dart';
import '../state/controllers/content_request_log.dart';
import '../state/controllers/cook_session_controller.dart';
import '../state/controllers/cookbook_controller.dart';
import '../state/controllers/history_controller.dart';
import '../state/controllers/meal_plan_controller.dart';
import '../state/controllers/one_handed_cook_mode_controller.dart';
import '../state/controllers/profile_controller.dart';
import '../state/controllers/shopping_controller.dart';
import 'home_shell.dart';
import 'nav_requests.dart';

/// The whole app around an already wired [AppServices].
class MorphCookApp extends StatelessWidget {
  const MorphCookApp({super.key, required this.services, this.home});

  final AppServices services;

  /// Replaces the start screen (tests).
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppServices>.value(value: services),
        ChangeNotifierProvider<NavRequests>(create: (_) => NavRequests()),
        Provider<Corpus>.value(value: services.corpus),
        Provider<Catalog>.value(value: services.catalog),
        Provider<SearchService>.value(value: services.search),
        Provider<ShoppingAggregator>.value(value: services.aggregator),
        Provider<BackupService>.value(value: services.backup),
        ChangeNotifierProvider<ProfileController>.value(value: services.profile),
        ChangeNotifierProvider<CookbookController>.value(value: services.cookbook),
        ChangeNotifierProvider<HistoryController>.value(value: services.history),
        ChangeNotifierProvider<MealPlanController>.value(value: services.mealPlan),
        ChangeNotifierProvider<ShoppingController>.value(value: services.shopping),
        ChangeNotifierProvider<ContentRequestLog>.value(value: services.contentRequests),
        ChangeNotifierProvider<CookSessionController>.value(value: services.cook),
        ChangeNotifierProvider<MotionPreferences>.value(value: services.motion),
        ChangeNotifierProvider<OneHandedCookModeController>.value(value: services.oneHanded),
        ProxyProvider<ProfileController, AppStrings>(
          update: (context, profile, previous) {
            if (previous != null && previous.lang == profile.lang) return previous;
            return AppStrings(services.stringsData, profile.lang);
          },
          updateShouldNotify: (a, b) => a.lang != b.lang,
        ),
      ],
      child: Consumer<ProfileController>(
        builder: (context, profile, _) {
          final languages = [for (final l in services.corpus.ontology.languages) Locale(l.code)];
          return MaterialApp(
            title: 'MorphCook',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            locale: Locale(profile.lang),
            supportedLocales: languages,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MotionScope(child: child ?? const SizedBox.shrink()),
            home: home ?? const RootGate(),
          );
        },
      ),
    );
  }
}

/// Onboarding until it has been completed once, then the tabs.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final onboarded = context.select<ProfileController, bool>((p) => p.onboarded);
    return AnimatedSwitcher(
      duration: context.motion(const Duration(milliseconds: 420)),
      child: onboarded ? const HomeShell(key: ValueKey('shell')) : const OnboardingFlow(key: ValueKey('onboarding')),
    );
  }
}
