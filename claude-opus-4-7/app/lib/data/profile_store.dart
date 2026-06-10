import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile.dart';

class ProfileStore extends ChangeNotifier {
  static const _key = 'morphcook.profile.v1';
  Profile _profile = const Profile();
  bool _loaded = false;

  Profile get profile => _profile;
  bool get loaded => _loaded;
  bool get onboarded => _profile.onboarded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        _profile = Profile.fromJson(json.decode(raw) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('ProfileStore: failed to decode — $e');
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> save(Profile next) async {
    _profile = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(next.toJson()));
    notifyListeners();
  }

  Future<void> update(Profile Function(Profile) builder) =>
      save(builder(_profile));
}
