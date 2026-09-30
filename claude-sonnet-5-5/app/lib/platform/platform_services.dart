import 'dart:typed_data';
import 'dart:ui';

/// A file handed to the OS share sheet.
class BackupFile {
  const BackupFile({required this.name, required this.bytes, required this.mimeType});

  final String name;
  final Uint8List bytes;
  final String mimeType;
}

/// Share sheet for export, document picker for import. Nothing else leaves or
/// enters the app: no OAuth, no cloud, no platform-specific storage APIs.
abstract class BackupFileGateway {
  /// Opens the OS share sheet with every file in [files].
  Future<void> shareFiles(List<BackupFile> files, {Rect? origin});

  /// Lets the person choose a backup file; `null` when cancelled.
  Future<Uint8List?> pickBackupFile();
}

/// What happens when a cooking timer finishes.
abstract class TimerAlerts {
  /// Vibrates and, when [sound] is on, rings a short chime.
  Future<void> alert({required bool sound});
  Future<void> stop();
}

abstract class ScreenAwake {
  Future<void> keepAwake(bool on);
}

abstract class Haptics {
  void tap();
  void heavy();
}

class PlatformServices {
  const PlatformServices({required this.files, required this.alerts, required this.awake, required this.haptics});

  final BackupFileGateway files;
  final TimerAlerts alerts;
  final ScreenAwake awake;
  final Haptics haptics;

  /// Recording doubles for tests.
  factory PlatformServices.fake() => PlatformServices(
    files: FakeBackupFileGateway(),
    alerts: FakeTimerAlerts(),
    awake: FakeScreenAwake(),
    haptics: FakeHaptics(),
  );
}

class FakeBackupFileGateway implements BackupFileGateway {
  final List<List<BackupFile>> shared = <List<BackupFile>>[];
  Uint8List? nextPick;

  @override
  Future<void> shareFiles(List<BackupFile> files, {Rect? origin}) async => shared.add(files);

  @override
  Future<Uint8List?> pickBackupFile() async => nextPick;
}

class FakeTimerAlerts implements TimerAlerts {
  int alerts = 0;
  int stops = 0;
  bool? lastSound;

  @override
  Future<void> alert({required bool sound}) async {
    alerts++;
    lastSound = sound;
  }

  @override
  Future<void> stop() async => stops++;
}

class FakeScreenAwake implements ScreenAwake {
  bool on = false;

  @override
  Future<void> keepAwake(bool on) async => this.on = on;
}

class FakeHaptics implements Haptics {
  int taps = 0;
  int heavies = 0;

  @override
  void tap() => taps++;

  @override
  void heavy() => heavies++;
}
