import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Gradle dependencies are not part of Flutter's generated package notices.
/// Register their bundled notices for the same offline licenses page.
void registerNativeLicenses() {
  LicenseRegistry.addLicense(() async* {
    final pdfLicense = await rootBundle.loadString(
      'assets/licenses/pdfbox-android-LICENSE.txt',
    );
    final pdfNotice = await rootBundle.loadString(
      'assets/licenses/pdfbox-android-NOTICE.txt',
    );
    yield LicenseEntryWithLineBreaks(
      const ['PdfBox-Android 2.0.27.0'],
      'https://github.com/TomRoush/PdfBox-Android/tree/v2.0.27.0\n\n'
      '$pdfNotice\n$pdfLicense',
    );
    for (final entry in const [
      (
        'Bouncy Castle 1.72',
        'bouncycastle-LICENSE.txt',
        'https://github.com/bcgit/bc-java/tree/r1rv72',
      ),
      (
        'Liberation Fonts 2.1.5 (PDFBox)',
        'liberation-fonts-LICENSE.txt',
        'https://github.com/liberationfonts/liberation-fonts/tree/2.1.5',
      ),
      (
        'Unicode data (PDFBox)',
        'unicode-LICENSE.txt',
        'https://www.unicode.org/license.txt',
      ),
    ]) {
      final license = await rootBundle.loadString(
        'assets/licenses/${entry.$2}',
      );
      yield LicenseEntryWithLineBreaks([entry.$1], '${entry.$3}\n\n$license');
    }
  });
}
