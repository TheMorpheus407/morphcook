import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/import/pdf_text_extractor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('morphcook/pdf_import');
  const extractor = PdfTextExtractor();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('passes PDF bytes and returns local Unicode text', () async {
    final bytes = Uint8List.fromList('%PDF-fixture'.codeUnits);
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'extractText');
      expect((call.arguments as Map)['bytes'], bytes);
      return ' Kartoffelsuppe für zwei\n½ EL Öl\n';
    });
    expect(await extractor.extract(bytes), 'Kartoffelsuppe für zwei\n½ EL Öl');
  });

  test('bounds bytes before sending them to native code', () async {
    var invoked = false;
    messenger.setMockMethodCallHandler(channel, (_) async {
      invoked = true;
      return 'text';
    });
    await expectLater(
      extractor.extract(Uint8List(maxPdfImportBytes + 1)),
      fails(PdfImportFailure.tooLarge),
    );
    await expectLater(
      extractor.extract(Uint8List(0)),
      fails(PdfImportFailure.invalidPdf),
    );
    expect(invoked, isFalse);
  });

  test('maps encrypted, scanned, page and content limit failures', () async {
    for (final failure in PdfImportFailure.values) {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: failure.name),
      );
      await expectLater(extractor.extract(Uint8List(1)), fails(failure));
    }
  });

  test('validates returned text and unavailable platforms', () async {
    for (final result in [null, ' \n\t', 'a' * (maxPdfImportTextLength + 1)]) {
      messenger.setMockMethodCallHandler(channel, (_) async => result);
      await expectLater(
        extractor.extract(Uint8List(1)),
        fails(
          result == null
              ? PdfImportFailure.invalidPdf
              : result.trim().isEmpty
              ? PdfImportFailure.noText
              : PdfImportFailure.textTooLarge,
        ),
      );
    }
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw MissingPluginException(),
    );
    await expectLater(
      extractor.extract(Uint8List(1)),
      fails(PdfImportFailure.unavailable),
    );
  });
}

Matcher fails(PdfImportFailure failure) => throwsA(
  isA<PdfImportException>().having(
    (error) => error.failure,
    'failure',
    failure,
  ),
);
