import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'data/corpus_repository.dart';
import 'state/kv_store.dart';
import 'state/library_store.dart';
import 'state/profile_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts ship in assets/google_fonts; never fetch at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await PrefsKvStore.open();
  final hive = await HiveKvStore.open();

  runApp(
    MorphCookApp(
      repo: CorpusRepository(),
      profile: ProfileController(prefs, deviceLang: PlatformDispatcher.instance.locale.languageCode),
      library: LibraryStore(hive),
    ),
  );
}
