import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../domain/backup/backup_codec.dart';
import 'platform_services.dart';

/// Share sheet and document picker.
///
/// Export writes the files to the app's temporary folder and hands them to the
/// share sheet. They stay there afterwards: on Android the share sheet closes
/// as soon as a target is chosen, and the target app may read the file after
/// that. The leftovers are removed before the next export and when the app
/// starts, so a backup never lingers for long. The folder is private to the app.
class SystemBackupFileGateway implements BackupFileGateway {
  SystemBackupFileGateway({
    Future<Directory> Function()? tempDirectory,
    Future<void> Function(List<XFile> files, Rect? origin)? share,
    bool cleanUp = true,
  }) : _tempDirectory = tempDirectory ?? getTemporaryDirectory,
       _share = share ?? _sharePlus {
    if (cleanUp) unawaited(removeLeftovers());
  }

  /// The files an export writes. Nothing else in the temporary folder is touched.
  static const List<String> fileNames = <String>[BackupCodec.jsonFileName, BackupCodec.gzipFileName];

  final Future<Directory> Function() _tempDirectory;
  final Future<void> Function(List<XFile> files, Rect? origin) _share;

  static Future<void> _sharePlus(List<XFile> files, Rect? origin) async {
    await SharePlus.instance.share(ShareParams(files: files, sharePositionOrigin: origin, title: 'MorphCook backup'));
  }

  /// Deletes the backup files an earlier export left in the temporary folder.
  Future<void> removeLeftovers() async {
    try {
      final dir = await _tempDirectory();
      for (final name in fileNames) {
        final file = File('${dir.path}/$name');
        if (await file.exists()) await file.delete();
      }
    } catch (_) {
      // The operating system clears the folder sooner or later anyway.
    }
  }

  @override
  Future<void> shareFiles(List<BackupFile> files, {Rect? origin}) async {
    await removeLeftovers();
    final dir = await _tempDirectory();
    final written = <XFile>[];
    for (final file in files) {
      final target = File('${dir.path}/${file.name}');
      await target.writeAsBytes(file.bytes, flush: true);
      written.add(XFile(target.path, mimeType: file.mimeType));
    }
    await _share(written, origin);
  }

  @override
  Future<Uint8List?> pickBackupFile() async {
    final picked = await FilePicker.pickFile(type: FileType.any);
    return picked?.readAsBytes();
  }
}

/// Chime, vibration pulses. The visual flash is drawn by the cook screen.
class SystemTimerAlerts implements TimerAlerts {
  AudioPlayer? _player;
  bool _stopped = false;

  @override
  Future<void> alert({required bool sound}) async {
    _stopped = false;
    // The vibration never waits for the audio system, which can be slow to wake.
    unawaited(_pulse());
    if (sound) unawaited(_chime());
  }

  Future<void> _chime() async {
    try {
      _player ??= AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.stop);
      await _player!.play(AssetSource('sounds/timer-chime.wav'));
    } catch (_) {
      // A device without audio output still gets the vibration and the flash.
    }
  }

  Future<void> _pulse() async {
    for (var i = 0; i < 4 && !_stopped; i++) {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    // Silencing the chime is not waited for either: the alert is over when the person says so.
    final player = _player;
    if (player != null) unawaited(player.stop().catchError((Object _) {}));
  }
}

class SystemScreenAwake implements ScreenAwake {
  @override
  Future<void> keepAwake(bool on) async {
    try {
      await (on ? WakelockPlus.enable() : WakelockPlus.disable());
    } catch (_) {
      // Not available on this platform: the screen simply follows the system timeout.
    }
  }
}

class SystemHaptics implements Haptics {
  @override
  void tap() => HapticFeedback.lightImpact();

  @override
  void heavy() => HapticFeedback.heavyImpact();
}

PlatformServices systemPlatformServices() => PlatformServices(
  files: SystemBackupFileGateway(),
  alerts: SystemTimerAlerts(),
  awake: SystemScreenAwake(),
  haptics: SystemHaptics(),
);
