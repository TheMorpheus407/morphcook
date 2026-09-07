import 'package:flutter/material.dart';

import 'app.dart';
import 'data/corpus_repository.dart';
import 'data/flutter_asset_source.dart';
import 'data/hive_store.dart';
import 'state/app_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(
    repo: CorpusRepository(const BundleAssetSource()),
    store: HiveStore(),
    profileStore: PrefsProfileStore(),
  );
  controller.init();
  runApp(MorphCookApp(controller: controller));
}
