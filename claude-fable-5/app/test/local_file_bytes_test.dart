import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/local_file_bytes.dart';

void main() {
  test('picker streams are read within the configured bound', () async {
    final file = PlatformFile(
      name: 'photo.png',
      size: 4,
      readStream: Stream<List<int>>.fromIterable(const [
        [1, 2],
        [3, 4],
      ]),
    );

    expect(
      await readPickedFileBytes(file, maxBytes: 4),
      orderedEquals([1, 2, 3, 4]),
    );
  });

  test('declared and streamed oversize files are stopped', () async {
    await expectLater(
      readPickedFileBytes(
        PlatformFile(name: 'huge', size: 11, bytes: Uint8List(0)),
        maxBytes: 10,
      ),
      throwsA(isA<LocalFileTooLargeException>()),
    );
    await expectLater(
      readPickedFileBytes(
        PlatformFile(
          name: 'grew',
          size: 0,
          readStream: Stream<List<int>>.value(List<int>.filled(11, 0)),
        ),
        maxBytes: 10,
      ),
      throwsA(isA<LocalFileTooLargeException>()),
    );
  });

  test('stale backup cleanup includes the share_plus Android cache', () async {
    final root = await Directory.systemTemp.createTemp('morphcook-cleanup-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final export = await Directory(
      '${root.path}/morphcook-export-test',
    ).create();
    final shareCache = await Directory('${root.path}/share_plus').create();
    final unrelated = await Directory('${root.path}/keep-me').create();
    await File('${export.path}/morphcook-backup.json').writeAsString('backup');
    await File(
      '${shareCache.path}/morphcook-backup.json',
    ).writeAsString('copied backup');
    await File('${unrelated.path}/unrelated.txt').writeAsString('keep');

    await clearMorphCookTemporaryFilesIn(root);

    expect(await export.exists(), isFalse);
    expect(await shareCache.exists(), isFalse);
    expect(await unrelated.exists(), isTrue);
  });
}
