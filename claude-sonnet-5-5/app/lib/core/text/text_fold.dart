/// Diacritic folding and tokenizing shared by the app and the build tools.
///
/// The bundled search index is generated at build time with exactly this code,
/// so index tokens and query tokens always agree.
class TextFold {
  const TextFold._();

  static const Map<String, String> _fold = <String, String>{
    'ä': 'a',
    'ö': 'o',
    'ü': 'u',
    'ß': 'ss',
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ã': 'a',
    'å': 'a',
    'ā': 'a',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ē': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ø': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ñ': 'n',
    'ç': 'c',
    'œ': 'oe',
    'æ': 'ae',
  };

  static const Map<String, String> _expand = <String, String>{'ä': 'ae', 'ö': 'oe', 'ü': 'ue', 'ß': 'ss'};

  static final RegExp _splitter = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  /// Lower-cases and maps diacritics to their base letters (`Döner` -> `doner`).
  static String fold(String input) => _map(input.toLowerCase(), _fold);

  /// Like [fold] but spells umlauts the German way (`Döner` -> `doener`).
  static String expandUmlauts(String input) {
    final lower = input.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(_expand[ch] ?? _fold[ch] ?? ch);
    }
    return buffer.toString();
  }

  static String _map(String input, Map<String, String> table) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(table[ch] ?? ch);
    }
    return buffer.toString();
  }

  /// Splits into lower-cased words, dropping one-letter noise such as the `s`
  /// of "cow's". Digits are kept.
  static List<String> words(String input) {
    return input
        .toLowerCase()
        .split(_splitter)
        .where((w) => w.length > 1 || (w.length == 1 && RegExp(r'\d').hasMatch(w)))
        .toList();
  }

  /// A crude, language-agnostic plural stemmer. It is applied to index and
  /// query alike, so it only has to be consistent, not linguistically correct.
  static String stem(String word) {
    if (word.length < 5) return word;
    if (word.endsWith('ies')) return '${word.substring(0, word.length - 3)}y';
    for (final suffix in const ['en', 'es', 'er']) {
      if (word.endsWith(suffix) && word.length - suffix.length >= 3) {
        return word.substring(0, word.length - suffix.length);
      }
    }
    for (final suffix in const ['s', 'n', 'e']) {
      if (word.endsWith(suffix) && word.length - suffix.length >= 3) {
        return word.substring(0, word.length - suffix.length);
      }
    }
    return word;
  }

  /// All searchable spellings of one word: folded, German-expanded and their stems.
  static Set<String> variants(String word) {
    final folded = fold(word);
    final expanded = expandUmlauts(word);
    return <String>{folded, expanded, stem(folded), stem(expanded)};
  }

  /// Union of [variants] over every word of [text].
  static Set<String> tokens(String text) {
    final out = <String>{};
    for (final word in words(text)) {
      out.addAll(variants(word));
    }
    return out;
  }
}
