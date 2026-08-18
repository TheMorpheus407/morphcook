import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/data/corpus.dart';
import 'core/services/collection_store.dart';
import 'core/services/profile_store.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await Hive.initFlutter();
  final box = await Hive.openBox('morphcook');

  final corpus = await Corpus.load();
  final state = AppState(
    corpus: corpus,
    profileStore: ProfileStore(prefs),
    collections: CollectionStore(box),
  );
  await state.load();

  runApp(MorphCookApp(state: state));
}
