import '../core/i18n/app_strings.dart';
import '../core/motion.dart';
import '../data/asset_source.dart';
import '../data/corpus.dart';
import '../data/models/profile.dart';
import '../domain/ranking.dart';
import '../domain/search/search_service.dart';
import '../domain/shopping/aggregator.dart';
import '../platform/platform_services.dart';
import 'backup_service.dart';
import 'catalog.dart';
import 'controllers/content_request_log.dart';
import 'controllers/cook_session_controller.dart';
import 'controllers/cookbook_controller.dart';
import 'controllers/history_controller.dart';
import 'controllers/meal_plan_controller.dart';
import 'controllers/one_handed_cook_mode_controller.dart';
import 'controllers/profile_controller.dart';
import 'controllers/shopping_controller.dart';
import 'storage/storage.dart';

/// Every long-lived object of the app, wired once at start-up.
class AppServices {
  AppServices._({
    required this.assets,
    required this.storage,
    required this.platform,
    required this.corpus,
    required this.stringsData,
    required this.ranking,
    required this.profile,
    required this.cookbook,
    required this.history,
    required this.mealPlan,
    required this.shopping,
    required this.contentRequests,
    required this.cook,
    required this.motion,
    required this.oneHanded,
    required this.catalog,
    required this.search,
    required this.aggregator,
    required this.backup,
    required this.clock,
  });

  final AssetSource assets;
  final AppStorage storage;
  final PlatformServices platform;
  final Corpus corpus;
  final AppStringsData stringsData;
  final Ranking ranking;
  final ProfileController profile;
  final CookbookController cookbook;
  final HistoryController history;
  final MealPlanController mealPlan;
  final ShoppingController shopping;
  final ContentRequestLog contentRequests;
  final CookSessionController cook;
  final MotionPreferences motion;
  final OneHandedCookModeController oneHanded;
  final Catalog catalog;
  final SearchService search;
  final ShoppingAggregator aggregator;
  final BackupService backup;
  final Clock clock;

  /// Loads the corpus, opens storage and wires everything together.
  ///
  /// [deviceLanguage] seeds the language of a fresh install when the corpus
  /// supports it; an existing profile keeps its own.
  static Future<AppServices> create({
    required AssetSource assets,
    required AppStorage storage,
    required PlatformServices platform,
    Clock? clock,
    String? deviceLanguage,
    bool autoTickTimers = true,
  }) async {
    final now = clock ?? DateTime.now;
    final corpus = await Corpus.load(assets);
    final stringsData = await AppStringsData.load(assets);
    final supported = {for (final l in corpus.ontology.languages) l.code};
    final lang = supported.contains(deviceLanguage) ? deviceLanguage! : corpus.ontology.defaultLanguage;

    final profile = ProfileController(
      storage.prefs,
      ontology: corpus.ontology,
      ingredients: corpus.ingredients,
      initial: Profile(lang: lang),
    );
    final cookbook = await CookbookController.open(storage);
    final history = await HistoryController.open(storage);
    final mealPlan = await MealPlanController.open(storage);
    final shopping = await ShoppingController.open(storage, corpus.ingredients);
    final contentRequests = await ContentRequestLog.open(storage);
    final cook = await CookSessionController.open(storage, clock: now, autoTick: autoTickTimers);
    final motion = MotionPreferences(profile);
    final oneHanded = OneHandedCookModeController(
      profile: profile,
      haptics: platform.haptics,
      reduceMotion: () => motion.reduceMotion,
      clock: now,
    );
    const ranking = Ranking();
    final catalog = Catalog(corpus: corpus, profileController: profile, history: history, ranking: ranking, clock: now);

    return AppServices._(
      assets: assets,
      storage: storage,
      platform: platform,
      corpus: corpus,
      stringsData: stringsData,
      ranking: ranking,
      profile: profile,
      cookbook: cookbook,
      history: history,
      mealPlan: mealPlan,
      shopping: shopping,
      contentRequests: contentRequests,
      cook: cook,
      motion: motion,
      oneHanded: oneHanded,
      catalog: catalog,
      search: SearchService(corpus: corpus, ranking: ranking),
      aggregator: ShoppingAggregator(corpus.ontology, corpus.ingredients),
      backup: BackupService(
        profile: profile,
        cookbook: cookbook,
        history: history,
        mealPlan: mealPlan,
        shopping: shopping,
        contentRequests: contentRequests,
        clock: now,
      ),
      clock: now,
    );
  }

  void dispose() {
    oneHanded.dispose();
    motion.dispose();
    cook.dispose();
    profile.dispose();
    cookbook.dispose();
    history.dispose();
    mealPlan.dispose();
    shopping.dispose();
    contentRequests.dispose();
  }
}
