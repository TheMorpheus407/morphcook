import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/native_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'native PDF notices are bundled and available offline to the licenses page',
    () async {
      registerNativeLicenses();
      registerBundledFontLicenses();
      final entries = await LicenseRegistry.licenses.toList();
      String textFor(String package) => entries
          .where((entry) => entry.packages.contains(package))
          .expand((entry) => entry.paragraphs)
          .map((paragraph) => paragraph.text)
          .join('\n');

      for (final font in [
        'Atkinson Hyperlegible',
        'Caveat',
        'JetBrains Mono',
        'Playfair Display',
      ]) {
        expect(textFor(font), contains('SIL OPEN FONT LICENSE'), reason: font);
      }
      final pdf = textFor('PdfBox-Android 2.0.27.0');
      expect(pdf, contains('Apache License'));
      expect(pdf, contains('Copyright 2014 The Apache Software Foundation'));
      expect(pdf, contains('Adobe Font Metrics'));
      expect(pdf, contains('https://github.com/TomRoush/PdfBox-Android'));
      expect(textFor('Bouncy Castle 1.72'), contains('2000-2022'));
      expect(
        textFor('Bouncy Castle 1.72'),
        contains('Permission is hereby granted'),
      );
      expect(
        textFor('Liberation Fonts 2.1.5 (PDFBox)'),
        contains('SIL OPEN FONT LICENSE'),
      );
      expect(textFor('Unicode data (PDFBox)'), contains('UNICODE LICENSE V3'));
    },
  );
}
