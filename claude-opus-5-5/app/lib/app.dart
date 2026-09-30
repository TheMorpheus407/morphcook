import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/corpus_repository.dart';
import 'i18n/strings.dart';
import 'logic/search_engine.dart';
import 'state/backup_service.dart';
import 'state/library_store.dart';
import 'state/profile_controller.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets/common.dart';
import 'ui/widgets/paper.dart';

class MorphCookApp extends StatelessWidget {
  const MorphCookApp({super.key, required this.repo, required this.profile, required this.library});

  final CorpusRepository repo;
  final ProfileController profile;
  final LibraryStore library;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: repo),
        ChangeNotifierProvider.value(value: profile),
        ChangeNotifierProvider.value(value: library),
        Provider(create: (_) => SearchEngine(repo)),
        Provider(
          create: (_) => BackupService(profile: profile, library: library),
        ),
      ],
      child: Builder(
        builder: (context) {
          final lang = context.select<ProfileController, String>((p) => p.lang);
          return MaterialApp(
            title: 'MorphCook',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            locale: Locale(lang),
            supportedLocales: const [Locale('en'), Locale('de')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const RootGate(),
          );
        },
      ),
    );
  }
}

/// Loads the corpus, then routes to onboarding or the main shell.
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  late final Future<void> _init;

  @override
  void initState() {
    super.initState();
    final repo = context.read<CorpusRepository>();
    _init = repo.isReady ? Future.value() : repo.init();
    _init.then((_) {
      // Remaining partitions load after the first frame, off the critical path.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        Future<void>.delayed(const Duration(milliseconds: 400), repo.prefetchRemaining);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _init,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: PaperBackground(
              child: Center(
                child: EmptyState(title: 'MorphCook', body: '${snap.error}'),
              ),
            ),
          );
        }
        if (snap.connectionState != ConnectionState.done) return const _Splash();
        final onboarded = context.select<ProfileController, bool>((p) => p.profile.onboarded);
        return AnimatedSwitcher(
          duration: motion(context, const Duration(milliseconds: 500)),
          child: onboarded ? const HomeShell(key: ValueKey('shell')) : const OnboardingScreen(key: ValueKey('ob')),
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PaperBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('MorphCook', style: MT.display(40)),
              const SizedBox(height: 6),
              HandNote(context.tr('home.loading'), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
