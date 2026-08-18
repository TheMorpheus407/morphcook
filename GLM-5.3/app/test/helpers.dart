import 'dart:io';

import 'package:morphcook/core/data/corpus.dart';

/// Loads the bundled corpus straight from disk for tests (`flutter test`
/// runs with the package root as CWD, and rootBundle has no assets there).
Future<Corpus> loadTestCorpus() {
  return Corpus.load(reader: (path) => File(path).readAsString());
}
