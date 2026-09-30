import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/domain/backup/backup_codec.dart';
import 'package:morphcook/platform/platform_services.dart';
import 'package:morphcook/platform/real_platform_services.dart';
import 'package:share_plus/share_plus.dart';

/// The real export gateway with a temporary folder and a stand-in for the share
/// sheet: what it writes, when it deletes and what it leaves alone.
void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('morphcook_share'));
  tearDown(() => temp.deleteSync(recursive: true));

  BackupFile file(String name, List<int> bytes, [String mime = 'application/json']) =>
      BackupFile(name: name, bytes: Uint8List.fromList(bytes), mimeType: mime);

  SystemBackupFileGateway gateway({
    Future<void> Function(List<XFile> files, Rect? origin)? share,
    bool cleanUp = false,
  }) {
    return SystemBackupFileGateway(
      tempDirectory: () async => temp,
      share: share ?? (files, origin) async {},
      cleanUp: cleanUp,
    );
  }

  File inTemp(String name) => File('${temp.path}/$name');

  test('the files it may delete are the two of a backup', () {
    expect(SystemBackupFileGateway.fileNames, ['morphcook-backup.json', 'morphcook-backup.json.gz']);
  });

  test('writes both files and hands them to the share sheet with their types', () async {
    late List<XFile> shared;
    Rect? sharedOrigin;
    await gateway(
      share: (files, origin) async {
        shared = files;
        sharedOrigin = origin;
      },
    ).shareFiles([
      file(BackupCodec.jsonFileName, [1, 2, 3]),
      file(BackupCodec.gzipFileName, [4, 5], 'application/gzip'),
    ], origin: const Rect.fromLTWH(10, 20, 30, 40));

    expect(shared.map((f) => f.name), [BackupCodec.jsonFileName, BackupCodec.gzipFileName]);
    expect(shared.map((f) => f.mimeType), ['application/json', 'application/gzip']);
    expect(sharedOrigin, const Rect.fromLTWH(10, 20, 30, 40));
    expect(inTemp(BackupCodec.jsonFileName).readAsBytesSync(), [1, 2, 3]);
    expect(inTemp(BackupCodec.gzipFileName).readAsBytesSync(), [4, 5]);
  });

  test('the files are readable while the share sheet is open and still there after it closed', () async {
    // On Android the target app reads the file after the share sheet is gone.
    final read = <List<int>>[];
    await gateway(
      share: (files, origin) async {
        for (final f in files) {
          read.add(await f.readAsBytes());
        }
      },
    ).shareFiles([
      file(BackupCodec.jsonFileName, [9, 9]),
    ]);
    expect(read, [
      [9, 9],
    ]);
    expect(inTemp(BackupCodec.jsonFileName).existsSync(), isTrue, reason: 'nothing is deleted after the share');
    expect(inTemp(BackupCodec.jsonFileName).readAsBytesSync(), [9, 9]);
  });

  test('the next export replaces the leftovers of the last one', () async {
    final g = gateway();
    await g.shareFiles([
      file(BackupCodec.jsonFileName, [1]),
      file(BackupCodec.gzipFileName, [2]),
    ]);
    await g.shareFiles([
      file(BackupCodec.jsonFileName, [3]),
    ]);
    expect(inTemp(BackupCodec.jsonFileName).readAsBytesSync(), [3]);
    expect(inTemp(BackupCodec.gzipFileName).existsSync(), isFalse, reason: 'the old zip is gone');
  });

  test('removeLeftovers deletes the backup files and nothing else', () async {
    inTemp(BackupCodec.jsonFileName).writeAsBytesSync([1]);
    inTemp(BackupCodec.gzipFileName).writeAsBytesSync([2]);
    inTemp('cache-of-something-else.bin').writeAsBytesSync([3]);
    await gateway().removeLeftovers();
    expect(temp.listSync().map((e) => e.uri.pathSegments.last).toList(), ['cache-of-something-else.bin']);
  });

  test('removing leftovers when there are none is fine', () async {
    await gateway().removeLeftovers();
    expect(temp.listSync(), isEmpty);
  });

  test('starting the gateway cleans up what an earlier run left behind', () async {
    inTemp(BackupCodec.jsonFileName).writeAsBytesSync([1]);
    gateway(cleanUp: true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(inTemp(BackupCodec.jsonFileName).existsSync(), isFalse);
  });

  test('a temporary folder that cannot be read never crashes the app', () async {
    final broken = SystemBackupFileGateway(
      tempDirectory: () async => throw const FileSystemException('gone'),
      share: (files, origin) async {},
      cleanUp: false,
    );
    await broken.removeLeftovers();
  });

  test('a failing share sheet reports the error and leaves the files for the next cleanup', () async {
    final g = gateway(share: (files, origin) async => throw StateError('no share sheet'));
    await expectLater(
      g.shareFiles([
        file(BackupCodec.jsonFileName, [1]),
      ]),
      throwsStateError,
    );
    expect(inTemp(BackupCodec.jsonFileName).existsSync(), isTrue);
    await g.removeLeftovers();
    expect(inTemp(BackupCodec.jsonFileName).existsSync(), isFalse);
  });
}
