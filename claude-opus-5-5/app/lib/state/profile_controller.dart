import 'package:flutter/foundation.dart';

import '../data/corpus_repository.dart';
import '../logic/matching.dart';
import '../models/profile.dart';
import 'kv_store.dart';

class ProfileController extends ChangeNotifier {
  ProfileController(this._store, {String? deviceLang}) {
    final raw = _store.read(_key);
    _profile = raw is Map<String, dynamic> ? Profile.fromJson(raw) : Profile(lang: _supported(deviceLang));
  }

  static const _key = 'profile';
  static const supportedLangs = ['en', 'de'];

  final KvStore _store;
  late Profile _profile;
  MatchContext? _ctx;
  Object? _ctxFor;

  Profile get profile => _profile;
  String get lang => _profile.lang;

  static String _supported(String? lang) => supportedLangs.contains(lang) ? lang! : 'en';

  Future<void> update(Profile Function(Profile) change) async {
    _profile = change(_profile);
    _ctx = null;
    notifyListeners();
    await _store.write(_key, _profile.toJson());
  }

  Future<void> replace(Profile p) => update((_) => p);

  /// The profile resolved against the ontology, cached until it changes.
  MatchContext matchContext(CorpusRepository repo) {
    if (_ctx == null || !identical(_ctxFor, _profile)) {
      _ctx = MatchContext.fromProfile(_profile, repo.ontology, repo.ingredients);
      _ctxFor = _profile;
    }
    return _ctx!;
  }
}
