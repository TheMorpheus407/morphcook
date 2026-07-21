import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/services/backup_service.dart';

void main() {
  final service = BackupService();
  final payload = <String, Object?>{
    'profile': {'name': 'Mara', 'lang': 'de'},
    'saved': ['recipe-one'],
    'meal_plan': {
      '2026-W28': {'fri.dinner': 'recipe-one'},
    },
    'history': <Object?>[],
  };

  test('plain and gzip backups round-trip the same schema', () async {
    final bundle = await service.create(payload);
    expect(bundle.gzipBytes.take(2), BackupService.gzipMagic);
    expect((await service.read(bundle.jsonBytes))['schema_version'], 1);
    expect((await service.read(bundle.gzipBytes))['saved'], ['recipe-one']);
  });

  test('encrypted backup uses ENC magic and round-trips', () async {
    final bundle = await service.create(payload, password: 'correct horse');
    expect(bundle.jsonBytes.take(3), BackupService.encryptionMagic);
    final restored = await service.read(
      bundle.jsonBytes,
      password: 'correct horse',
    );
    expect((restored['profile'] as Map)['name'], 'Mara');
    expect(bundle.gzipBytes.take(2), BackupService.gzipMagic);
  });

  test('uses unique salt and IV for each encryption', () async {
    final first = await service.create(payload, password: 'secret');
    final second = await service.create(payload, password: 'secret');
    expect(first.jsonBytes, isNot(equals(second.jsonBytes)));
  });

  test('reports missing and incorrect passwords actionably', () async {
    final bundle = await service.create(payload, password: 'secret');
    for (final password in <String?>[null, 'wrong']) {
      try {
        await service.read(bundle.jsonBytes, password: password);
        fail('expected decryption to fail');
      } on DecryptionException catch (error) {
        expect(error.reason, DecryptionFailure.wrongPassword);
        expect(error.message('en'), contains('Incorrect password'));
      }
    }
  });

  test('distinguishes encrypted corruption from a wrong password', () async {
    final bundle = await service.create(payload, password: 'secret');
    final corrupted = [...bundle.jsonBytes];
    corrupted[35] ^= 0xff;
    try {
      await service.read(corrupted, password: 'secret');
      fail('expected corruption to fail');
    } on DecryptionException catch (error) {
      expect(error.reason, DecryptionFailure.corrupted);
      expect(error.message('de'), contains('beschädigt'));
    }
  });

  test('rejects unrelated and unsupported JSON', () async {
    for (final bytes in [
      [1],
      '{"schema_version":2}'.codeUnits,
      'not json'.codeUnits,
    ]) {
      expect(
        () => service.read(bytes),
        throwsA(
          isA<DecryptionException>().having(
            (error) => error.reason,
            'reason',
            DecryptionFailure.invalidFormat,
          ),
        ),
      );
    }
  });
}
