# PDFBox documents JPEG2000 decoding as optional. Its JPXFilter checks
# Class.forName before using JP2Decoder and reports a missing decoder as an
# IOException. Text extraction skips image XObjects, so no JP2 native library
# is needed. Restrict this rule to the one optional type R8 reports missing.
# https://github.com/TomRoush/PdfBox-Android/tree/v2.0.27.0#optional-dependencies
-dontwarn com.gemalto.jp2.JP2Decoder
