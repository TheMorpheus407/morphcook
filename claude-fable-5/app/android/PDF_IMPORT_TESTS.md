# Native PDF extraction tests

Connect an Android device or start an emulator, run `flutter pub get` from the
app directory, then run from this directory:

```sh
./gradlew -PmorphcookPdfTestApp=true :app:connectedDebugAndroidTest
```

The optional property gives the debug app the application ID
`de.themorpheus.morphcook.pdfimporttest`, so installing the test app does not
replace the store-signed app or touch its saved recipes. Release builds never use
this suffix. On an x86_64 emulator, `-Ptarget-platform=android-x64` limits the
Flutter build to the emulator ABI.

`PdfTextExtractorTest` generates real PDF fixtures on the device and exercises the
production extractor. It checks compressed text with an embedded Unicode font,
byte/page/text/content-operation limits, password encryption (including an empty
password), extraction permissions, corrupt/recursive files, an image-only scan,
and cleanup of actual scratch files after both successful and rejected extraction.
JPEG2000 fixtures also prove that text extraction skips image XObjects without
the optional decoder, while a malformed JPEG2000-filtered page-content stream
returns an import error without crashing.

`app/proguard-rules.pro` suppresses only the optional `JP2Decoder` reference
reported by R8. PDFBox checks that decoder's availability before attempting to
use it. A normal release APK build is also required to verify this packaging
rule; the native tests themselves run against the debug variant.

The Dart method-channel contract is checked separately from the app directory:

```sh
flutter test test/pdf_text_extractor_test.dart
```

For the Nix-packaged Flutter 3.38.3 SDK used for the production verification,
Gradle additionally needs the writable cache arguments shown by
`flutter build apk --debug -v`. The successful API 34 emulator invocation used:

```sh
PDF_GRADLE_CACHE="$HOME/.cache/flutter/nix-flutter-tools-gradle/13e658725d"
./gradlew \
  --project-cache-dir="$PDF_GRADLE_CACHE/cache" \
  -Pkotlin.project.persistent.dir="$PDF_GRADLE_CACHE/kotlin" \
  -Ptarget-platform=android-x64 \
  -PmorphcookPdfTestApp=true \
  :app:connectedDebugAndroidTest
```

Use the installed Android Studio JDK via `JAVA_HOME` and the actual Flutter SDK
path via `FLUTTER_ROOT` when invoking Gradle directly on that installation. Cache
paths differ with the SDK version; use the paths printed by Flutter locally.
