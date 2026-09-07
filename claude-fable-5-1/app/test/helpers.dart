import 'dart:io';

import 'package:morphcook/data/asset_source.dart';
import 'package:morphcook/data/corpus_repository.dart';
import 'package:morphcook/data/local_store.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/data/models/recipe.dart';
import 'package:morphcook/domain/matching.dart';
import 'package:morphcook/state/app_controller.dart';

/// Loads the real bundled corpus from disk (tests run with cwd = app/).
Future<CorpusRepository> loadRepo({bool all = false}) async {
  final repo = CorpusRepository(FileAssetSource(Directory.current.path));
  await repo.load();
  if (all) await repo.loadAll();
  return repo;
}

Recipe recipeOf(CorpusRepository repo, String id) {
  final r = repo.recipeIfLoaded(id);
  if (r == null) throw StateError('recipe $id not loaded');
  return r;
}

MatchContext ctxFor(CorpusRepository repo, Profile p) => MatchContext.from(p, repo.ontology, repo.ingredients);

Future<AppController> newController({DateTime Function()? clock, Profile? profile, bool loadAll = false}) async {
  final repo = CorpusRepository(FileAssetSource(Directory.current.path));
  final profileStore = InMemoryProfileStore();
  if (profile != null) await profileStore.save(profile.toJson());
  final app = AppController(repo: repo, store: InMemoryStore(), profileStore: profileStore, clock: clock);
  await app.init();
  if (loadAll) await repo.loadAll();
  return app;
}
