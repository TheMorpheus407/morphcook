import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class LocalStorage {
  Future<Map<String, dynamic>?> readProfile();
  Future<Map<String, dynamic>?> readCollections();
  Future<void> writeProfile(Map<String, dynamic> profile);
  Future<void> writeCollections(Map<String, dynamic> collections);
}

class DeviceStorage implements LocalStorage {
  late SharedPreferences _preferences;
  late Box<String> _box;
  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    await Hive.initFlutter();
    _box = await Hive.openBox<String>('morphcook_v1');
  }

  Map<String, dynamic>? _decode(String? value) => value == null
      ? null
      : Map<String, dynamic>.from(jsonDecode(value) as Map);
  @override
  Future<Map<String, dynamic>?> readProfile() async =>
      _decode(_preferences.getString('profile'));
  @override
  Future<Map<String, dynamic>?> readCollections() async =>
      _decode(_box.get('collections'));
  @override
  Future<void> writeProfile(Map<String, dynamic> profile) async {
    if (!await _preferences.setString('profile', jsonEncode(profile))) {
      throw StateError('Could not save profile');
    }
  }

  @override
  Future<void> writeCollections(Map<String, dynamic> collections) async {
    await _box.put('collections', jsonEncode(collections));
    await _box.flush();
  }
}

class MemoryStorage implements LocalStorage {
  Map<String, dynamic>? profile;
  Map<String, dynamic>? collections;
  @override
  Future<Map<String, dynamic>?> readProfile() async => profile;
  @override
  Future<Map<String, dynamic>?> readCollections() async => collections;
  @override
  Future<void> writeProfile(Map<String, dynamic> profile) async {
    this.profile = jsonDecode(jsonEncode(profile)) as Map<String, dynamic>;
  }

  @override
  Future<void> writeCollections(Map<String, dynamic> collections) async {
    this.collections =
        jsonDecode(jsonEncode(collections)) as Map<String, dynamic>;
  }
}
