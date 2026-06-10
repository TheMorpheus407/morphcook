import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'backup/backup_service.dart';
import 'data/content_requests_store.dart';
import 'data/cookbook_store.dart';
import 'data/corpus.dart';
import 'data/history_store.dart';
import 'data/meal_plan_store.dart';
import 'data/profile_store.dart';
import 'data/shopping_list_store.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/root_shell.dart';
import 'theme/app_theme.dart';
import 'theme/colors.dart';
import 'widgets/paper_background.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MorphCookApp());
}

class MorphCookApp extends StatefulWidget {
  const MorphCookApp({super.key});
  @override
  State<MorphCookApp> createState() => _MorphCookAppState();
}

class _MorphCookAppState extends State<MorphCookApp> {
  late final ProfileStore _profile;
  late final CookbookStore _cookbook;
  late final MealPlanStore _mealPlan;
  late final HistoryStore _history;
  late final ShoppingListStore _shopping;
  late final ContentRequestsStore _content;
  late final Future<Corpus> _corpusFuture;

  @override
  void initState() {
    super.initState();
    _profile = ProfileStore();
    _cookbook = CookbookStore();
    _mealPlan = MealPlanStore();
    _history = HistoryStore();
    _shopping = ShoppingListStore();
    _content = ContentRequestsStore();
    _corpusFuture = _bootstrap();
  }

  Future<Corpus> _bootstrap() async {
    // load profile + stores + corpus in parallel
    final results = await Future.wait<dynamic>([
      _profile.load(),
      _cookbook.load(),
      _mealPlan.load(),
      _history.load(),
      _shopping.load(),
      _content.load(),
      CorpusLoader.load(),
    ]);
    return results.last as Corpus;
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ProfileStore>.value(value: _profile),
        ChangeNotifierProvider<CookbookStore>.value(value: _cookbook),
        ChangeNotifierProvider<MealPlanStore>.value(value: _mealPlan),
        ChangeNotifierProvider<HistoryStore>.value(value: _history),
        ChangeNotifierProvider<ShoppingListStore>.value(value: _shopping),
        ChangeNotifierProvider<ContentRequestsStore>.value(value: _content),
        Provider<BackupService>(
          create: (_) => BackupService(
            profile: _profile,
            cookbook: _cookbook,
            mealPlan: _mealPlan,
            history: _history,
            contentRequests: _content,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'MorphCook',
        debugShowCheckedModeBanner: false,
        theme: MorphTheme.light(),
        supportedLocales: const [
          Locale('en'),
          Locale('de'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: FutureBuilder<Corpus>(
          future: _corpusFuture,
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const _SplashScreen();
            }
            if (snap.hasError || snap.data == null) {
              return _ErrorScreen(error: snap.error);
            }
            return Provider<Corpus>.value(
              value: snap.data!,
              child: const _RootGate(),
            );
          },
        ),
      ),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();
  @override
  Widget build(BuildContext context) {
    final onboarded = context.watch<ProfileStore>().onboarded;
    return onboarded ? const RootShell() : const OnboardingScreen();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) {
    return PaperBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('morphcook',
                  style: MorphType.display(size: 56)),
              const SizedBox(height: 6),
              Text('a cookbook for every body',
                  style: MorphType.hand(
                      size: 22, color: MorphColors.coral)),
              const SizedBox(height: 40),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: MorphColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final Object? error;
  const _ErrorScreen({required this.error});
  @override
  Widget build(BuildContext context) {
    return PaperBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('something went wrong',
                    style: MorphType.display(size: 30)),
                const SizedBox(height: 12),
                Text('$error',
                    textAlign: TextAlign.center,
                    style: MorphType.body(size: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
