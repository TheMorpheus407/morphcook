import 'package:flutter/foundation.dart';

import '../models/profile.dart';
import 'local_storage.dart';

class ProfileRepository extends ChangeNotifier {
  ProfileRepository._(this._storage, this._profile);

  final LocalStorage _storage;
  Profile _profile;

  Profile get profile => _profile;

  static const _key = 'profile';

  static Future<ProfileRepository> load(LocalStorage storage) async {
    final raw = await storage.readJsonMap(_key);
    final profile = raw == null ? const Profile() : Profile.fromJson(raw);
    return ProfileRepository._(storage, profile);
  }

  Future<void> save(Profile next) async {
    _profile = next;
    await _storage.writeJson(_key, next.toJson());
    notifyListeners();
  }

  Future<void> update(Profile Function(Profile) edit) => save(edit(_profile));
}
