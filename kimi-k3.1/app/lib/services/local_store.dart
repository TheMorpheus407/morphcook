import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';
import '../models/user_data.dart';

abstract class LocalStateStore {
  Future<Profile?> loadProfile();
  Future<void> saveProfile(Profile profile);
  Future<UserSnapshot> loadSnapshot();
  Future<void> saveSnapshot(UserSnapshot snapshot);
  Future<void> close() async {}
}

class HiveStateStore implements LocalStateStore {
  HiveStateStore._(this.preferences, this.box);

  final SharedPreferences preferences;
  final Box<dynamic> box;
  static const _profileKey = 'morphcook.profile.v1';
  static const _snapshotKey = 'morphcook.snapshot.v1';

  static Future<HiveStateStore> open() async {
    final directory = await getApplicationDocumentsDirectory();
    Hive.init('${directory.path}/morphcook-hive');
    final box = await Hive.openBox<dynamic>('local-state-v1');
    final preferences = await SharedPreferences.getInstance();
    return HiveStateStore._(preferences, box);
  }

  @override
  Future<Profile?> loadProfile() async {
    final source = preferences.getString(_profileKey);
    if (source == null) return null;
    try {
      return Profile.fromJson(jsonDecode(source));
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> saveProfile(Profile profile) =>
      preferences.setString(_profileKey, jsonEncode(profile.toJson()));

  @override
  Future<UserSnapshot> loadSnapshot() async {
    final source = box.get(_snapshotKey);
    if (source is! String || source.isEmpty) return const UserSnapshot();
    try {
      return UserSnapshot.fromJson(jsonDecode(source));
    } on FormatException {
      return const UserSnapshot();
    }
  }

  @override
  Future<void> saveSnapshot(UserSnapshot snapshot) =>
      box.put(_snapshotKey, jsonEncode(snapshot.toJson()));

  @override
  Future<void> close() => box.close();
}

class MemoryStateStore implements LocalStateStore {
  MemoryStateStore({this.profile, this.snapshot = const UserSnapshot()});

  Profile? profile;
  UserSnapshot snapshot;
  int profileWrites = 0;
  int snapshotWrites = 0;

  @override
  Future<Profile?> loadProfile() async => profile;

  @override
  Future<void> saveProfile(Profile value) async {
    profile = value;
    profileWrites++;
  }

  @override
  Future<UserSnapshot> loadSnapshot() async => snapshot;

  @override
  Future<void> saveSnapshot(UserSnapshot value) async {
    snapshot = value;
    snapshotWrites++;
  }

  @override
  Future<void> close() async {}
}
