import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Loads the bundled typefaces before the first frame.
///
/// MorphCook ships its fonts inside the app, so there is no runtime fetch
/// and no flash of fallback text. `google_fonts` is told to never hit the
/// network; the assets are resolved from the app bundle instead.
abstract final class Fonts {
  const Fonts._();

  static bool _preloaded = false;

  /// Preloads every weight and style the app uses.
  static Future<void> preload() async {
    if (_preloaded) return;
    _preloaded = true;

    // Runtime fetching is off: if a font is missing from the bundle the app
    // should fall back to the system face, not silently phone home.
    GoogleFonts.config.allowRuntimeFetching = false;

    for (final weight in <FontWeight>[
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
    ]) {
      GoogleFonts.playfairDisplay(fontWeight: weight);
      GoogleFonts.jetBrainsMono(fontWeight: weight);
      GoogleFonts.caveat(fontWeight: weight);
    }

    GoogleFonts.playfairDisplay(
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.italic,
    );
    GoogleFonts.playfairDisplay(
      fontWeight: FontWeight.w700,
      fontStyle: FontStyle.italic,
    );
    GoogleFonts.jetBrainsMono(
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.italic,
    );

    await GoogleFonts.pendingFonts();
  }
}
