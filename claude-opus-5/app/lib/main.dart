import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/corpus_repository.dart';
import 'data/local_store.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final state = AppState(
    repository: CorpusRepository(),
    profileStore: await ProfileStore.open(),
    collections: CollectionsStore(await HiveJsonStore.open()),
  );

  runApp(MorphCookApp(state: state));
}
