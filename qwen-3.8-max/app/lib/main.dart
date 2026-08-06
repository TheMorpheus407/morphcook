import 'package:flutter/material.dart';

import 'app.dart';
import 'data/corpus_repository.dart';
import 'state/app_model.dart';
import 'state/library_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appModel = AppModel();
  final library = LibraryModel();
  final corpus = CorpusRepository();

  await Future.wait([
    appModel.init(),
    library.init(),
    corpus.init(),
  ]);

  runApp(MorphCookApp(
    appModel: appModel,
    library: library,
    corpus: corpus,
  ));
}
