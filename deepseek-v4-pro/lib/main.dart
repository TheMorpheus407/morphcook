import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/l10n.dart';
import 'data/corpus.dart';
import 'data/stores.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final prefs = await SharedPreferences.getInstance();
  final store = await AppStore.init();
  final loc = LocaleController(prefs);
  final corpus = await Corpus.load();
  runApp(MorphCookApp(corpus: corpus, store: store, loc: loc));
}
