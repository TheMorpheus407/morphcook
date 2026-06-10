import 'package:flutter/widgets.dart';

import '../data/corpus.dart';
import '../logic/matching.dart';
import '../logic/ranking.dart';
import '../models/profile.dart';
import '../services/backup_service.dart';
import '../services/stores.dart';

/// Provides the loaded corpus and all services to the widget tree. Services are
/// `ChangeNotifier`s — widgets listen to the specific ones they care about.
class AppScope extends InheritedWidget {
  AppScope({
    super.key,
    required this.corpus,
    required this.services,
    required super.child,
  }) : backup = BackupService(services);

  final Corpus corpus;
  final Services services;
  final BackupService backup;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in context');
    return scope!;
  }

  /// Read without subscribing — for callbacks/actions.
  static AppScope read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!;

  ProfileMatcher matcherFor(Profile profile) => corpus.matcher.forProfile(profile);

  /// A ranker wired with the current clock and cooking history (staleness).
  Ranker rankerFor(Profile profile, {DateTime? now}) => Ranker(
        profile: profile,
        now: now,
        lastCooked: services.history.lastCookedByRecipe(),
      );

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      corpus != oldWidget.corpus || services != oldWidget.services;
}
