import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/repository.dart';
import 'state/app_state.dart';
import 'state/storage.dart';
import 'ui/theme.dart';
import 'ui/shell.dart';
import 'ui/screens/onboarding_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: KitchenColors.paper,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MorphCookBootstrap());
}

class MorphCookBootstrap extends StatefulWidget {
  const MorphCookBootstrap({super.key});
  @override
  State<MorphCookBootstrap> createState() => _MorphCookBootstrapState();
}

class _MorphCookBootstrapState extends State<MorphCookBootstrap> {
  AppState? state;
  bool error = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => error = false);
    try {
      final storage = DeviceStorage();
      await storage.initialize();
      final value = AppState(repository: RecipeRepository(), storage: storage);
      await value.initialize();
      if (mounted) {
        setState(() => state = value);
      } else {
        value.dispose();
      }
    } catch (_) {
      if (mounted) setState(() => error = true);
    }
  }

  @override
  void dispose() {
    state?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => state != null
      ? MorphCookApp(state: state!)
      : MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: kitchenTheme(),
          home: PaperSurface(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('morphcook.', style: serif(44, italic: true)),
                      const SizedBox(height: 22),
                      if (!error)
                        const CircularProgressIndicator(strokeWidth: 2),
                      if (error)
                        FilledButton.icon(
                          onPressed: load,
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            WidgetsBinding
                                        .instance
                                        .platformDispatcher
                                        .locale
                                        .languageCode ==
                                    'de'
                                ? 'Erneut versuchen'
                                : 'Try again',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
}

class MorphCookApp extends StatelessWidget {
  final AppState state;
  final Widget? home;
  const MorphCookApp({super.key, required this.state, this.home});
  @override
  Widget build(BuildContext context) => AppScope(
    state: state,
    child: ListenableBuilder(
      listenable: state,
      builder: (context, _) => MaterialApp(
        title: 'MorphCook',
        debugShowCheckedModeBanner: false,
        theme: kitchenTheme(),
        locale: Locale(state.profile.lang),
        supportedLocales: const [Locale('en'), Locale('de')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        themeAnimationDuration: state.profile.reduceMotion == true
            ? Duration.zero
            : const Duration(milliseconds: 200),
        home:
            home ??
            (state.profile.onboarded
                ? const KitchenShell()
                : const OnboardingScreen()),
      ),
    ),
  );
}
