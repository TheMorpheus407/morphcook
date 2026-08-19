import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/backup.dart';

BackupData sampleData() => BackupData(
      profile: {'name': 'mo', 'lang': 'en'},
      saved: ['doener-vegan', 'alfredo-classic'],
      mealPlan: {'2026-W34': {'mon.dinner': 'doener-vegan'}},
      history: [
        {'recipe_id': 'doener-vegan', 'cooked_at': '2026-08-18T19:00:00Z'}
      ],
      shoppingList: {
        'checked': [],
        'sources': {'doener-vegan': 1.0},
        'events': [],
      },
      contentRequests: ['sushi bowl', 'kumpir'],
    );

void main() {
  group('format detection', () {
    test('encrypted file starts with ENC magic bytes', () {
      final enc = BackupCodec.encrypt(
          Uint8List.fromList(utf8.encode('hello')), 'pw');
      expect(enc[0], 0x45);
      expect(enc[1], 0x4E);
      expect(enc[2], 0x43);
      expect(BackupCodec.detectFormat(enc), BackupFormat.encrypted);
    });

    test('gzip file starts with 1f 8b', () {
      final gz = Uint8List.fromList(
          BackupCodec.gzip(Uint8List.fromList(utf8.encode('x'))));
      expect(gz[0], 0x1F);
      expect(gz[1], 0x8B);
      expect(BackupCodec.detectFormat(gz), BackupFormat.gzip);
    });

    test('plain json detected', () {
      final bytes =
          Uint8List.fromList(utf8.encode('{"schema_version": 1}'));
      expect(BackupCodec.detectFormat(bytes), BackupFormat.plainJson);
    });
  });

  group('gzip', () {
    test('roundtrip', () {
      final data = Uint8List.fromList(utf8.encode(jsonEncode(sampleData().toJson())));
      final gz = Uint8List.fromList(BackupCodec.gzip(data));
      expect(BackupCodec.gunzip(gz), data);
    });

    test('compression achieves meaningful reduction', () {
      final raw = Uint8List.fromList(
          utf8.encode(const JsonEncoder.withIndent('  ').convert(sampleData().toJson())));
      final gz = Uint8List.fromList(BackupCodec.gzip(raw));
      // indented json compresses far better than 30%
      expect(gz.length, lessThan(raw.length * 7 ~/ 10));
    });
  });

  group('encryption', () {
    test('encrypt → decrypt roundtrip with correct password', () {
      final plaintext =
          Uint8List.fromList(utf8.encode(jsonEncode(sampleData().toJson())));
      final enc = BackupCodec.encrypt(plaintext, 'hunter2');
      final dec = BackupCodec.decrypt(enc, 'hunter2');
      expect(dec, plaintext);
    });

    test('wrong password throws DecryptionException(wrongPassword)', () {
      final enc =
          BackupCodec.encrypt(Uint8List.fromList(utf8.encode('secret')), 'a');
      expect(
        () => BackupCodec.decrypt(enc, 'b'),
        throwsA(isA<DecryptionException>()
            .having((e) => e.reason, 'reason', 'wrongPassword')),
      );
    });

    test('truncated data fails to decrypt (corrupted or wrongPassword)', () {
      final enc =
          BackupCodec.encrypt(Uint8List.fromList(utf8.encode('secret')), 'a');
      // truncating ciphertext can surface as an auth failure — both reasons
      // are non-recoverable, which is the contract that matters
      expect(
        () => BackupCodec.decrypt(
            Uint8List.sublistView(enc, 0, enc.length - 5), 'a'),
        throwsA(isA<DecryptionException>()),
      );
      // an over-truncated (header-only) blob is definitely corrupted
      expect(
        () => BackupCodec.decrypt(
            Uint8List.sublistView(enc, 0, 8), 'a'),
        throwsA(isA<DecryptionException>()
            .having((e) => e.reason, 'reason', 'corrupted')),
      );
    });

    test('each encryption uses a fresh salt/iv (unique output)', () {
      final pt = Uint8List.fromList(utf8.encode('same same'));
      final a = BackupCodec.encrypt(pt, 'pw');
      final b = BackupCodec.encrypt(pt, 'pw');
      expect(a, isNot(equals(b)));
    });
  });

  group('export/import pipeline', () {
    test('export without password → readable json + gzip pair', () {
      final files = buildExportFiles(sampleData());
      expect(files.length, 2);
      expect(files[0].$1, 'morphcook-backup.json');
      expect(files[1].$1, 'morphcook-backup.json.gz');

      // json parses as human-readable
      final json = jsonDecode(utf8.decode(files[0].$2));
      expect(json['schema_version'], 1);
      expect(json['saved'], ['doener-vegan', 'alfredo-classic']);
      expect(json['content_requests'], ['sushi bowl', 'kumpir']);

      // gz detects as gzip and parses back
      expect(BackupCodec.detectFormat(files[1].$2), BackupFormat.gzip);
      final restored = parseImport(files[1].$2);
      expect(restored.saved, json['saved']);
      expect(restored.contentRequests, ['sushi bowl', 'kumpir']);
    });

    test('export with password → encrypted json, unencrypted gz', () {
      final files = buildExportFiles(sampleData(), password: 'pw');
      expect(BackupCodec.detectFormat(files[0].$2), BackupFormat.encrypted);
      expect(BackupCodec.detectFormat(files[1].$2), BackupFormat.gzip);
    });

    test('import of encrypted file without password asks for it', () {
      final files = buildExportFiles(sampleData(), password: 'pw');
      expect(
        () => parseImport(files[0].$2),
        throwsA(isA<DecryptionException>()
            .having((e) => e.reason, 'reason', 'needsPassword')),
      );
    });

    test('import of encrypted file with password restores data', () {
      final files = buildExportFiles(sampleData(), password: 'pw');
      final restored = parseImport(files[0].$2, password: 'pw');
      expect(restored.profile['name'], 'mo');
      expect(restored.mealPlan['2026-W34']['mon.dinner'], 'doener-vegan');
    });

    test('invalid json is rejected as invalidFormat', () {
      expect(
        () => parseImport(Uint8List.fromList(utf8.encode('not json at all'))),
        throwsA(isA<DecryptionException>()
            .having((e) => e.reason, 'reason', 'invalidFormat')),
      );
    });

    test('wrong schema version is rejected', () {
      final bad = Uint8List.fromList(utf8.encode('{"schema_version": 99}'));
      expect(
        () => parseImport(bad),
        throwsA(isA<DecryptionException>()
            .having((e) => e.reason, 'reason', 'invalidFormat')),
      );
    });

    test('import auto-detects all three formats of the same data', () {
      final data = sampleData();
      final files = buildExportFiles(data, password: 'pw');
      // encrypted json (with pw), plain gz
      final a = parseImport(files[0].$2, password: 'pw');
      final b = parseImport(files[1].$2);
      final plain = buildExportFiles(data)[0];
      final c = parseImport(plain.$2);
      expect(a.saved, b.saved);
      expect(b.saved, c.saved);
    });
  });
}
