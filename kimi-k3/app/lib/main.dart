import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_router.dart';
import 'core/corpus_repository.dart';
import 'core/engine/matching.dart';
import 'core/engine/search.dart';
import 'core/l10n.dart';
import 'core/storage/local_store.dart';
import 'core/storage/profile_store.dart';
import 'core/theme/app_theme.dart';
import 'features/cookbook/strings.dart' as cookbook_strings;
import 'features/cookbook/cookbook_screen.dart';
import 'features/cookmode/strings.dart' as cookmode_strings;
import 'features/dish/strings.dart' as dish_strings;
import 'features/faq/strings.dart' as faq_strings;
import 'features/home/home_screen.dart';
import 'features/home/strings.dart' as home_strings;
import 'features/mealplan/meal_plan_screen.dart';
import 'features/mealplan/strings.dart' as mealplan_strings;
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/strings.dart' as onboarding_strings;
import 'features/search/search_screen.dart';
import 'features/search/strings.dart' as search_strings;
import 'features/settings/strings.dart' as settings_strings;
import 'features/shopping/shopping_screen.dart';
import 'features/shopping/strings.dart' as shopping_strings;
import 'shared/widgets/paper_grain.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  for (final map in [
    onboarding_strings.strings,
    home_strings.strings,
    dish_strings.strings,
    cookbook_strings.strings,
    search_strings.strings,
    cookmode_strings.strings,
    mealplan_strings.strings,
    shopping_strings.strings,
    settings_strings.strings,
    faq_strings.strings,
  ]) {
    AppStrings.register(map);
  }

  final profileStore = ProfileStore();
  final localStore = LocalStore();
  final corpus = CorpusRepository();
  await Future.wait([
    profileStore.load(),
    localStore.init(),
    corpus.loadCore(),
  ]);

  runApp(MorphCookApp(
    profileStore: profileStore,
    localStore: localStore,
    corpus: corpus,
  ));
}

class MorphCookApp extends StatelessWidget {
  final ProfileStore profileStore;
  final LocalStore localStore;
  final CorpusRepository corpus;

  const MorphCookApp({
    super.key,
    required this.profileStore,
    required this.localStore,
    required this.corpus,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: profileStore),
        ChangeNotifierProvider.value(value: localStore),
        Provider.value(value: corpus),
        Provider(
            create: (_) =>
                MatchingEngine(corpus.ontology, corpus.ingredientDictionary)),
        Provider(create: (ctx) => SearchEngine(corpus, ctx.read())),
      ],
      child: MaterialApp(
        title: 'MorphCook',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        onGenerateRoute: onGenerateRoute,
        home: const AppGate(),
      ),
    );
  }
}

/// Routes to onboarding or the main shell depending on profile state.
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final profileStore = context.watch<ProfileStore>();
    if (!profileStore.onboarded) {
      return const OnboardingScreen();
    }
    return const HomeShell();
  }
}

/// Bottom-tab shell: home / cookbook / search / plan / shopping.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final s = S(context);
    final tabs = [
      const HomeScreen(),
      const CookbookScreen(),
      const SearchScreen(),
      const MealPlanScreen(),
      const ShoppingScreen(),
    ];
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _index, children: tabs),
          const Positioned.fill(child: PaperGrain()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.paperDark,
        indicatorColor: AppColors.tealSoft,
        labelTextStyle: WidgetStatePropertyAll(AppText.monoLabel(size: 10)),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: s.t('nav.home')),
          NavigationDestination(
              icon: const Icon(Icons.bookmark_border),
              selectedIcon: const Icon(Icons.bookmark),
              label: s.t('nav.cookbook')),
          NavigationDestination(
              icon: const Icon(Icons.search), label: s.t('nav.search')),
          NavigationDestination(
              icon: const Icon(Icons.calendar_today_outlined),
              selectedIcon: const Icon(Icons.calendar_today),
              label: s.t('nav.plan')),
          NavigationDestination(
              icon: const Icon(Icons.shopping_basket_outlined),
              selectedIcon: const Icon(Icons.shopping_basket),
              label: s.t('nav.shopping')),
        ],
      ),
    );
  }
}
