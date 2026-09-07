/// Shared by the build-time indexer and the runtime search so both agree.
String normalizeSearchText(String s) {
  final sb = StringBuffer();
  for (final rune in s.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    sb.write(_fold[ch] ?? ch);
  }
  return sb.toString();
}

const Map<String, String> _fold = {
  'ä': 'a', 'à': 'a', 'á': 'a', 'â': 'a', 'å': 'a', 'ã': 'a',
  'ö': 'o', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'ø': 'o', 'õ': 'o',
  'ü': 'u', 'ù': 'u', 'ú': 'u', 'û': 'u',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ç': 'c', 'ñ': 'n', 'ß': 'ss', 'ğ': 'g', 'ş': 's', 'ı': 'i',
  '’': '', '\'': '',
};

final RegExp _splitter = RegExp(r'[^a-z0-9]+');

/// Lowercased, diacritics folded, split on non-alphanumerics, ≥2 chars,
/// duplicates removed, order preserved.
List<String> tokenize(String text) {
  final out = <String>[];
  final seen = <String>{};
  for (final t in normalizeSearchText(text).split(_splitter)) {
    if (t.length < 2) continue;
    if (seen.add(t)) out.add(t);
  }
  return out;
}
