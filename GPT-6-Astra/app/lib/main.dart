import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/app_state.dart';
import 'core/models.dart';
import 'ui/design.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/detail_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/planner_screen.dart';
import 'screens/shopping_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    for (final font in ['PlayfairDisplay', 'JetBrainsMono', 'Caveat']) {
      yield LicenseEntryWithLineBreaks([
        font,
      ], await rootBundle.loadString('assets/fonts/$font-OFL.txt'));
    }
  });
  runApp(const MorphCookApp());
}

class MorphCookApp extends StatefulWidget {
  final AppState? state;
  const MorphCookApp({super.key, this.state});
  @override
  State<MorphCookApp> createState() => _MorphCookAppState();
}

class _MorphCookAppState extends State<MorphCookApp> {
  AppState? state;
  Object? error;
  @override
  void initState() {
    super.initState();
    state = widget.state;
    if (state == null) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final loaded = await AppState.load();
      if (mounted) {
        setState(() => state = loaded);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = state;
    if (s == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: morphTheme(),
        home: PaperScaffold(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                display('morphcook', size: 56),
                const SizedBox(height: 20),
                hand(
                  error == null
                      ? 'a little kitchen of your own.'
                      : 'let’s try that again.',
                ),
                const SizedBox(height: 32),
                if (error == null)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                else
                  PrimaryButton(
                    label: 'Retry / Erneut versuchen',
                    onPressed: () {
                      setState(() => error = null);
                      _load();
                    },
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return AnimatedBuilder(
      animation: s,
      builder: (context, _) => MaterialApp(
        title: 'MorphCook',
        debugShowCheckedModeBanner: false,
        theme: morphTheme(),
        locale: Locale(
          GlobalMaterialLocalizations.delegate.isSupported(
                Locale(s.profile.lang),
              )
              ? s.profile.lang
              : 'en',
        ),
        supportedLocales: languageNames(s).keys
            .map(Locale.new)
            .where(GlobalMaterialLocalizations.delegate.isSupported)
            .toList(),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              disableAnimations:
                  s.profile.reduceMotion ?? media.disableAnimations,
            ),
            child: child!,
          );
        },
        home: s.profile.onboarded
            ? KitchenShell(state: s)
            : ProfileScreen(state: s, onboarding: true),
      ),
    );
  }
}

class KitchenShell extends StatefulWidget {
  final AppState state;
  const KitchenShell({super.key, required this.state});
  @override
  State<KitchenShell> createState() => _KitchenShellState();
}

class _KitchenShellState extends State<KitchenShell> {
  int tab = 0;
  void open(Recipe recipe) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DetailScreen(state: widget.state, recipe: recipe),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final labels = [
      tr(s, 'the kitchen', 'die Küche'),
      tr(s, 'discover', 'entdecken'),
      tr(s, 'cookbook', 'Kochbuch'),
      tr(s, 'meal plan', 'Wochenplan'),
      tr(s, 'shopping', 'Einkaufen'),
    ];
    final icons = [
      Icons.cottage_outlined,
      Icons.search,
      Icons.bookmarks_outlined,
      Icons.calendar_month_outlined,
      Icons.shopping_bag_outlined,
    ];
    final page = switch (tab) {
      0 => HomeScreen(
        state: s,
        onOpen: open,
        onDiscover: () => setState(() => tab = 1),
      ),
      1 => LibraryScreen(state: s, onOpen: open),
      2 => LibraryScreen(state: s, onOpen: open, savedOnly: true),
      3 => PlannerScreen(state: s, onOpenRecipe: open),
      _ => ShoppingScreen(state: s),
    };
    return PaperScaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        title: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            children: [
              const Icon(Icons.spa_outlined, size: 18),
              const SizedBox(width: 10),
              Flexible(
                child: mono(
                  tr(
                    s,
                    'A LITTLE EVERYDAY MAGIC',
                    'EIN BISSCHEN ALLTAGSZAUBER',
                  ),
                  size: 9,
                  color: Palette.ink,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: tr(s, 'Settings', 'Einstellungen'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => ProfileScreen(state: s)),
            ),
            icon: const Icon(Icons.tune, size: 20),
          ),
          const SizedBox(width: 12),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Palette.paper,
          border: Border(top: BorderSide(color: Palette.line)),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Row(
                children: List.generate(
                  5,
                  (i) => Expanded(
                    child: Semantics(
                      selected: tab == i,
                      child: InkWell(
                        onTap: () => setState(() => tab = i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icons[i],
                                color: tab == i ? Palette.ink : Palette.muted,
                                size: 22,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                labels[i],
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: tab == i ? Palette.ink : Palette.muted,
                                  fontWeight: tab == i
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                height: 3,
                                width: 18,
                                color: tab == i
                                    ? Palette.coral
                                    : Colors.transparent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      child: KeyedSubtree(key: ValueKey(tab), child: page),
    );
  }
}
