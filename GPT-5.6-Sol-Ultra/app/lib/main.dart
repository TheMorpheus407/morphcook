import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'data/bundled_recipe_repository.dart';
import 'domain/models/user_profile.dart';
import 'l10n/app_strings.dart';
import 'services/app_state.dart';
import 'services/backup_file_facade.dart';
import 'services/backup_repository.dart';
import 'services/backup_service.dart';
import 'services/local_store.dart';
import 'services/profile_store.dart';
import 'ui/screens/main_shell.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/theme/morph_theme.dart';
import 'ui/widgets/morph_components.dart';
import 'ui/widgets/paper_surface.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await Future.wait([
    initializeDateFormatting('en'),
    initializeDateFormatting('de'),
  ]);
  _registerFontLicenses();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFF7F0E2),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MorphCookBootstrap());
}

void _registerFontLicenses() {
  for (final entry in const {
    'Playfair Display': 'assets/fonts/OFL-PlayfairDisplay.txt',
    'JetBrains Mono': 'assets/fonts/OFL-JetBrainsMono.txt',
    'Caveat': 'assets/fonts/OFL-Caveat.txt',
  }.entries) {
    LicenseRegistry.addLicense(() async* {
      final license = await rootBundle.loadString(entry.value);
      yield LicenseEntryWithLineBreaks([entry.key], license);
    });
  }
}

class MorphCookBootstrap extends StatefulWidget {
  const MorphCookBootstrap({super.key});

  @override
  State<MorphCookBootstrap> createState() => _MorphCookBootstrapState();
}

class _MorphCookBootstrapState extends State<MorphCookBootstrap> {
  _Runtime? _runtime;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profileStore = await SharedPreferencesProfileStore.create();
      final localStore = HiveLocalApplicationStore();
      final repository = BundledRecipeRepository();
      final appState = AppState(
        profileStore: profileStore,
        localStore: localStore,
      );
      final backupService = BackupService();
      final backupRepository = BackupRepository(
        profileStore: profileStore,
        localStore: localStore,
        backupService: backupService,
      );
      await Future.wait([repository.initialize(), appState.initialize()]);
      if (appState.needsOnboarding) {
        await repository.initialize(loadExtended: true);
      }
      await repository.ensureRecipesLoaded({
        ...appState.savedRecipes.map((entry) => entry.recipeId),
        ...appState.cookingHistory.map((entry) => entry.recipeId),
        ...appState.mealPlan.entries.map((entry) => entry.recipeId),
      });
      final runtime = _Runtime(
        repository: repository,
        appState: appState,
        backupService: backupService,
        backupRepository: backupRepository,
        backupGateway: const PlatformBackupFileGateway(),
      );
      if (!mounted) {
        await appState.shutdown();
        appState.dispose();
        return;
      }
      setState(() {
        _runtime = runtime;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    final state = _runtime?.appState;
    if (state != null) {
      unawaited(state.shutdown());
      state.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runtime = _runtime;
    if (_loading || runtime == null) {
      final deviceLanguage =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      final language = deviceLanguage == 'de' ? 'de' : 'en';
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: Locale(language),
        supportedLocales: MorphStrings.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: MorphTheme.light,
        builder: (context, child) => MorphStringsScope(
          languageCode: language,
          child: child ?? const SizedBox.shrink(),
        ),
        home: Scaffold(
          body: PaperSurface(
            child: _error == null
                ? const _LoadingKitchen()
                : MorphErrorState(
                    message: MorphStrings(language)('common.errorBody'),
                    onRetry: _start,
                  ),
          ),
        ),
      );
    }

    return ChangeNotifierProvider.value(
      value: runtime.appState,
      child: Consumer<AppState>(
        builder: (context, state, _) {
          final deviceLanguage =
              WidgetsBinding.instance.platformDispatcher.locale.languageCode;
          final language =
              state.profile?.languageCode ??
              (deviceLanguage == 'de' ? 'de' : 'en');
          return MaterialApp(
            title: 'MorphCook',
            debugShowCheckedModeBanner: false,
            locale: Locale(language),
            supportedLocales: MorphStrings.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: MorphTheme.light,
            darkTheme: MorphTheme.dark,
            themeMode: ThemeMode.light,
            builder: (context, child) {
              final profileMotion = state.profile?.reduceMotion;
              final media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(
                  disableAnimations: profileMotion ?? media.disableAnimations,
                ),
                child: MorphStringsScope(
                  languageCode: language,
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
            home: state.needsOnboarding
                ? OnboardingScreen(
                    initialProfile:
                        state.profile ??
                        UserProfile.empty(languageCode: language),
                    ingredients: runtime.repository.ingredients,
                    hasMatchingRecipe: (profile) =>
                        runtime.repository.visibleRecipes(profile).isNotEmpty,
                    onComplete: state.completeOnboarding,
                  )
                : MainShell(
                    repository: runtime.repository,
                    backupRepository: runtime.backupRepository,
                    backupService: runtime.backupService,
                    backupGateway: runtime.backupGateway,
                  ),
          );
        },
      ),
    );
  }
}

class _Runtime {
  const _Runtime({
    required this.repository,
    required this.appState,
    required this.backupService,
    required this.backupRepository,
    required this.backupGateway,
  });

  final BundledRecipeRepository repository;
  final AppState appState;
  final BackupService backupService;
  final BackupRepository backupRepository;
  final BackupFileGateway backupGateway;
}

class _LoadingKitchen extends StatelessWidget {
  const _LoadingKitchen();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('MorphCook', style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 8),
          Text(
            context.strings('app.loading'),
            style: morphHandwriting(context, size: 23),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 150,
            child: LinearProgressIndicator(
              minHeight: 3,
              color: context.morph.coral,
              backgroundColor: context.morph.paperDeep,
            ),
          ),
        ],
      ),
    );
  }
}
