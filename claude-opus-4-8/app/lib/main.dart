import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/app_scope.dart';
import 'data/corpus.dart';
import 'services/stores.dart';
import 'theme/app_theme.dart';
import 'widgets/paper_background.dart';

void main() {
  // Fonts are bundled in assets — never fetch at runtime (offline-only app).
  GoogleFonts.config.allowRuntimeFetching = false;
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Bootstrap());
}

/// Loads services + the bundled corpus, then mounts the app. Shows a calm
/// paper splash while loading — no spinner theatre.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();
  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late final Future<(Services, Corpus)> _future = _load();

  Future<(Services, Corpus)> _load() async {
    await initializeDateFormatting();
    final services = await Services.open();
    final corpus = await Corpus.load();
    return (services, corpus);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(Services, Corpus)>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _Splash();
        }
        if (snap.hasError) {
          return _Splash(error: snap.error.toString());
        }
        final (services, corpus) = snap.data!;
        return AppScope(
          corpus: corpus,
          services: services,
          child: const MorphCookApp(),
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({this.error});
  final String? error;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: PaperBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('MorphCook',
                  style: TextStyle(
                      fontFamily: Fonts.display,
                      fontStyle: FontStyle.italic,
                      fontSize: 40,
                      color: AppColors.ink)),
              const SizedBox(height: 8),
              Text(
                error == null ? 'setting the table…' : 'something went wrong',
                style: const TextStyle(
                    fontFamily: Fonts.hand, fontSize: 22, color: AppColors.clay),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(error!,
                      style: const TextStyle(
                          fontFamily: Fonts.mono,
                          fontSize: 11,
                          color: AppColors.inkSoft)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
