import 'package:flutter/services.dart';

const maxPdfImportBytes = 10 * 1024 * 1024;
const maxPdfImportPages = 50;
const maxPdfImportTextLength = 200000;

enum PdfImportFailure {
  tooLarge,
  encrypted,
  permissionDenied,
  tooManyPages,
  textTooLarge,
  noText,
  invalidPdf,
  unavailable,
}

class PdfImportException implements Exception {
  final PdfImportFailure failure;
  const PdfImportException(this.failure);
}

/// Extracts selectable PDF text locally. The platform never performs OCR or
/// follows document links, and enforces the same limits independently.
class PdfTextExtractor {
  final MethodChannel channel;
  const PdfTextExtractor({
    this.channel = const MethodChannel('morphcook/pdf_import'),
  });

  Future<String> extract(Uint8List bytes) async {
    if (bytes.length > maxPdfImportBytes) {
      throw const PdfImportException(PdfImportFailure.tooLarge);
    }
    if (bytes.isEmpty) {
      throw const PdfImportException(PdfImportFailure.invalidPdf);
    }
    try {
      final text = await channel.invokeMethod<String>('extractText', {
        'bytes': bytes,
      });
      if (text == null) {
        throw const PdfImportException(PdfImportFailure.invalidPdf);
      }
      if (text.length > maxPdfImportTextLength) {
        throw const PdfImportException(PdfImportFailure.textTooLarge);
      }
      if (text.trim().isEmpty) {
        throw const PdfImportException(PdfImportFailure.noText);
      }
      return text.trim();
    } on MissingPluginException {
      throw const PdfImportException(PdfImportFailure.unavailable);
    } on PlatformException catch (error) {
      throw PdfImportException(
        PdfImportFailure.values.firstWhere(
          (failure) => failure.name == error.code,
          orElse: () => PdfImportFailure.invalidPdf,
        ),
      );
    }
  }
}
