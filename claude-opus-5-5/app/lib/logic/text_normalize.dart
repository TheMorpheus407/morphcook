/// Text normalisation shared by the build-time search index generator
/// (`tool/build_corpus.dart`) and the runtime query tokenizer. Both sides must
/// agree byte for byte, so this file stays free of Flutter imports.
library;

const _folds = {
  'ä': 'a',
  'ö': 'o',
  'ü': 'u',
  'ß': 'ss',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ç': 'c',
  'ñ': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ı': 'i',
  'ş': 's',
  'ğ': 'g',
  'œ': 'oe',
  'æ': 'ae',
  'ø': 'o',
  'å': 'a',
};

String foldText(String input) {
  final lower = input.toLowerCase();
  final buf = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buf.write(_folds[ch] ?? ch);
  }
  return buf.toString();
}

final _splitter = RegExp(r'[^a-z0-9]+');

/// Lower-cases, folds diacritics and splits into tokens of at least 2 chars.
List<String> tokenize(String input) =>
    foldText(input).split(_splitter).where((t) => t.length >= 2).toList(growable: false);
