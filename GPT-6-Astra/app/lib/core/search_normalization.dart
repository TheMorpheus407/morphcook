// Latin compatibility forms generated from Unicode NFKD + casefold.
// Bundled index generation uses the same normalization; combining marks are
// stripped separately so decomposed spellings behave identically.
const _latinSearchGroups = <String, String>{
  'a': 'ªàáâãäåāăąǎǟǡǻȁȃȧᵃḁạảấầẩẫậắằẳẵặ',
  'b': 'ᵇḃḅḇ',
  'c': 'çćĉċčᶜḉ',
  'd': 'ďᵈḋḍḏḑḓⅆ',
  'dz': 'ǆǳ',
  'e': 'èéêëēĕėęěȅȇȩᵉḕḗḙḛḝẹẻẽếềểễệℯⅇ',
  'f': 'ᶠḟ',
  'ff': 'ﬀ',
  'ffi': 'ﬃ',
  'ffl': 'ﬄ',
  'fi': 'ﬁ',
  'fl': 'ﬂ',
  'g': 'ĝğġģǧǵᵍḡℊ',
  'h': 'ĥȟḣḥḧḩḫẖℎ',
  'i': 'ìíîïĩīĭįǐȉȋᵢḭḯỉịℹⅈ',
  'ij': 'ĳ',
  'j': 'ĵǰⅉ',
  'k': 'ķǩᵏḱḳḵ',
  'l': 'ĺļľḷḹḻḽℓ',
  'lj': 'ǉ',
  'm': 'ᵐḿṁṃ',
  'n': 'ñńņňǹṅṇṉṋ',
  'nj': 'ǌ',
  'o': 'ºòóôõöōŏőơǒǫǭȍȏȫȭȯȱᵒṍṏṑṓọỏốồổỗộớờởỡợℴ',
  'p': 'ᵖṕṗ',
  'r': 'ŕŗřȑȓᵣṙṛṝṟ',
  's': 'śŝşšſșṡṣṥṧṩẛ',
  'ss': 'ß',
  'st': 'ﬅﬆ',
  't': 'ţťțᵗṫṭṯṱẗ',
  'u': 'ùúûüũūŭůűųưǔǖǘǚǜȕȗᵘᵤṳṵṷṹṻụủứừửữự',
  'v': 'ᵛᵥṽṿ',
  'w': 'ŵẁẃẅẇẉẘ',
  'x': 'ẋẍ',
  'y': 'ýÿŷȳẏẙỳỵỷỹ',
  'z': 'źżžᶻẑẓẕ',
};

final _searchReplacements = <int, String>{
  for (final entry in _latinSearchGroups.entries)
    for (final rune in entry.value.runes) rune: entry.key,
  0x03c2: 'σ', // Greek final sigma casefold.
};

String normalizeSearch(String text) {
  final folded = text.toLowerCase().runes.map((rune) {
    // NFKD folds full-width letters and digits into their ASCII forms.
    final code = rune >= 0xff01 && rune <= 0xff5e ? rune - 0xfee0 : rune;
    return _searchReplacements[code] ?? String.fromCharCode(code);
  }).join();
  return folded
      .replaceAll(
        RegExp(
          r'[\u0300-\u036f\u1ab0-\u1aff\u1dc0-\u1dff\u20d0-\u20ff\ufe20-\ufe2f]',
        ),
        '',
      )
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();
}
