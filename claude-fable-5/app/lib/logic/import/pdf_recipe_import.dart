import '../../models/personal_recipe.dart';
import 'website_recipe_import.dart' show parseImportedIngredientLine;

const maxPdfRecipeTextCharacters = 200000;
// Heading/metadata recognition is intentionally narrow. Oversized lines still
// remain in sourceText, and model limits turn uncertain drafts into a fallback.
const _maxPdfMetadataLineLength = 512;

enum PdfRecipeTextFailure { empty, tooLarge }

class PdfRecipeTextException implements Exception {
  final PdfRecipeTextFailure failure;
  const PdfRecipeTextException(this.failure);

  @override
  String toString() => 'PdfRecipeTextException: ${failure.name}';
}

/// A structured, editable recipe when headings make its sections clear.
/// Otherwise [recipe] is null and the complete [sourceText] remains available
/// for copying/manual entry. Neither path guesses missing ingredients.
class PdfRecipeImport {
  final PersonalRecipe? recipe;
  final String sourceText;
  final bool usedDefaultTime;
  final bool usedDefaultServings;

  const PdfRecipeImport({
    this.recipe,
    required this.sourceText,
    this.usedDefaultTime = false,
    this.usedDefaultServings = false,
  });

  bool get isStructured => recipe != null;
}

List<PdfRecipeImport> parsePdfRecipeText(String text, {String? filename}) {
  if (text.length > maxPdfRecipeTextCharacters) {
    throw const PdfRecipeTextException(PdfRecipeTextFailure.tooLarge);
  }
  if (text.trim().isEmpty) {
    throw const PdfRecipeTextException(PdfRecipeTextFailure.empty);
  }
  // Split only explicit recipe title markers, and only when every resulting
  // segment has a complete ingredient/method structure. Ambiguous documents
  // stay together instead of silently dropping cover pages or partial recipes.
  final titleMarkers = RegExp(r'^.*$', multiLine: true)
      .allMatches(text)
      .where((match) => _explicitTitle(match.group(0)!) != null)
      .toList();
  if (titleMarkers.length > 1) {
    final entries = <PdfRecipeImport>[];
    for (var i = 0; i < titleMarkers.length; i++) {
      final start = i == 0 ? 0 : titleMarkers[i].start;
      final end = i + 1 < titleMarkers.length
          ? titleMarkers[i + 1].start
          : text.length;
      final entry = _structured(text.substring(start, end), filename);
      if (entry == null) return [PdfRecipeImport(sourceText: text)];
      entries.add(entry);
      if (entries.length > 50) return [PdfRecipeImport(sourceText: text)];
    }
    return entries;
  }
  return [_structured(text, filename) ?? PdfRecipeImport(sourceText: text)];
}

PdfRecipeImport? _structured(String source, String? filename) {
  final lines = source
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\f', '\n')
      .replaceAll('\u00a0', ' ')
      .split('\n');
  final ingredientHeaders = <int>[];
  final methodHeaders = <int>[];
  for (var i = 0; i < lines.length; i++) {
    switch (_section(lines[i])) {
      case _Section.ingredients:
        ingredientHeaders.add(i);
      case _Section.method:
        methodHeaders.add(i);
      default:
        break;
    }
  }
  // Repeated full sections without explicit recipe boundaries are ambiguous.
  if (ingredientHeaders.length != 1 ||
      methodHeaders.length != 1 ||
      ingredientHeaders.single >= methodHeaders.single) {
    return null;
  }
  final ingredientsAt = ingredientHeaders.single;
  final methodAt = methodHeaders.single;
  var notesAt = lines.length;
  for (var i = methodAt + 1; i < lines.length; i++) {
    if (_section(lines[i]) == _Section.notes) {
      notesAt = i;
      break;
    }
  }
  final preamble = lines.take(ingredientsAt).toList();
  var titleIndex = preamble.indexWhere((line) => _explicitTitle(line) != null);
  if (titleIndex < 0) {
    titleIndex = preamble.indexWhere(
      (line) =>
          line.trim().isNotEmpty && !_isMetadata(line) && !_isPageNumber(line),
    );
  }
  final title = titleIndex < 0
      ? _filenameTitle(filename)
      : _explicitTitle(preamble[titleIndex]) ??
            _cleanHeading(preamble[titleIndex]);
  final descriptionLines = [
    for (var i = 0; i < preamble.length; i++)
      if (i != titleIndex &&
          !_isMetadata(preamble[i]) &&
          !_isPageNumber(preamble[i]))
        preamble[i].trim(),
    if (notesAt < lines.length)
      ...lines.skip(notesAt).map((line) => line.trim()),
  ];
  final metadataLines = [...preamble, lines[ingredientsAt]];
  final time = _time(metadataLines);
  final servings = _servings(metadataLines);
  try {
    final ingredientDrafts = _ingredients(
      lines.sublist(ingredientsAt + 1, methodAt),
    );
    final steps = _steps(lines.sublist(methodAt + 1, notesAt));
    final recipe = PersonalRecipe.create(
      title: title,
      description: descriptionLines.join('\n').trim(),
      timeMinutes: time ?? 30,
      servings: servings ?? 2,
      ingredients: ingredientDrafts,
      steps: steps.map((text) => PersonalRecipeStep(text: text)).toList(),
    );
    return PdfRecipeImport(
      recipe: recipe,
      sourceText: source,
      usedDefaultTime: time == null,
      usedDefaultServings: servings == null,
    );
  } on FormatException {
    // Model limits never cause partial/truncated drafts. Keep the full source.
    return null;
  }
}

enum _Section { ingredients, method, notes }

String _cleanHeading(String line) {
  final cleaned = line
      .trim()
      .replaceFirst(RegExp(r'^#{1,6}\s+'), '')
      .replaceAll('**', '');
  // An unanchored trailing-marker regex retries at every internal underscore
  // when a long run does not reach the end. Scan only the actual edges.
  var start = 0;
  var end = cleaned.length;
  bool isMarker(int index) =>
      cleaned.codeUnitAt(index) == 42 || cleaned.codeUnitAt(index) == 95;
  while (start < end && isMarker(start)) {
    start++;
  }
  while (end > start && isMarker(end - 1)) {
    end--;
  }
  return cleaned
      .substring(start, end)
      .replaceFirst(RegExp(r'^\d+[.)]\s+'), '')
      .trim();
}

_Section? _section(String line) {
  if (line.length > _maxPdfMetadataLineLength) return null;
  final heading = _cleanHeading(
    line,
  ).replaceFirst(RegExp(r'[:.]\s*$'), '').trim();
  if (RegExp(
    r'^(?:ingredients|zutaten)(?:\s*\([^)]*\)|\s+(?:for|für)\s+.+)?$',
    caseSensitive: false,
  ).hasMatch(heading)) {
    return _Section.ingredients;
  }
  if (RegExp(
    r'^(?:instructions|directions|method|preparation|steps|zubereitung|anleitung|zubereitungsschritte|arbeitsschritte)$',
    caseSensitive: false,
  ).hasMatch(heading)) {
    return _Section.method;
  }
  if (RegExp(
    r'^(?:notes|tips|variations|serving suggestions|nutrition|hinweise|notizen|tipps|variationen|serviervorschläge|nährwerte)$',
    caseSensitive: false,
  ).hasMatch(heading)) {
    return _Section.notes;
  }
  return null;
}

String? _explicitTitle(String line) {
  if (line.length > _maxPdfMetadataLineLength) return null;
  final cleaned = _cleanHeading(line);
  final marker = RegExp(
    r'^(?:recipe|rezept|title|titel)\s*(?:\d+\s*)?[:.]\s*(.+)$',
    caseSensitive: false,
  ).firstMatch(cleaned);
  if (marker != null) return marker.group(1)!.trim();
  if (RegExp(r'^\s*#{1,2}\s+').hasMatch(line) &&
      _section(line) == null &&
      !_isMetadata(line)) {
    return cleaned;
  }
  return null;
}

String _filenameTitle(String? filename) {
  final base = filename
      ?.split(RegExp(r'[/\\]'))
      .last
      .trim()
      .replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '')
      .trim();
  return base == null || base.isEmpty ? 'PDF recipe' : base;
}

bool _isPageNumber(String line) =>
    line.length <= _maxPdfMetadataLineLength &&
    RegExp(
      r'^\s*(?:page|seite)\s+\d+\s*(?:(?:of|von|/)\s*\d+)?\s*$',
      caseSensitive: false,
    ).hasMatch(line);

bool _isMetadata(String line) =>
    line.length <= _maxPdfMetadataLineLength &&
    (RegExp(
          r'^\s*(?:servings?|yield|makes|portionen|portion|für|ergibt|prep(?:aration)?\s*time|cook(?:ing)?\s*time|total\s*time|time|ready\s*in|vorbereitungszeit|zubereitungszeit|kochzeit|backzeit|gesamtzeit|zeit)\s*[:\s]',
          caseSensitive: false,
        ).hasMatch(_cleanHeading(line)) ||
        RegExp(
          r'^\s*\d+(?:\s*[-–—]\s*\d+)?\s+(?:servings?|portions?|portionen|personen)\s*$',
          caseSensitive: false,
        ).hasMatch(line));

int? _servings(List<String> lines) {
  for (final line in lines) {
    if (line.length > _maxPdfMetadataLineLength) continue;
    if (RegExp(r'\d\s*[-–—]\s*\d').hasMatch(line)) continue;
    final normalized = _cleanHeading(line);
    final match =
        RegExp(
          r'^(?:servings?|yield|makes|portionen|portion|für|ergibt)\s*:?\s*(\d+)\s*(?:servings?|portions?|portionen|personen|people)?\s*$',
          caseSensitive: false,
        ).firstMatch(normalized) ??
        RegExp(
          r'(?:^|[^\d.,])(\d+)\s+(?:servings?|portions?|portionen|personen|people)\b',
          caseSensitive: false,
        ).firstMatch(normalized);
    if (match == null) continue;
    final count = int.tryParse(match.group(1)!);
    if (count != null && count > 0 && count <= 1000) return count;
  }
  return null;
}

int? _time(List<String> lines) {
  int? total;
  int? prep;
  int? cook;
  for (final line in lines) {
    if (line.length > _maxPdfMetadataLineLength) continue;
    final clean = _cleanHeading(line);
    final label = RegExp(
      r'^(prep(?:aration)?\s*time|cook(?:ing)?\s*time|total\s*time|time|ready\s*in|vorbereitungszeit|zubereitungszeit|kochzeit|backzeit|gesamtzeit|zeit)\s*:?\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(clean);
    if (label == null) continue;
    final minutes = _minutes(label.group(2)!);
    if (minutes == null) continue;
    final kind = label.group(1)!.toLowerCase();
    if (kind.startsWith('prep') || kind == 'vorbereitungszeit') {
      prep = minutes;
    } else if (kind.startsWith('cook') ||
        kind == 'kochzeit' ||
        kind == 'backzeit') {
      cook = minutes;
    } else {
      total = minutes;
    }
  }
  if (total != null) return total;
  final sum = (prep ?? 0) + (cook ?? 0);
  return sum > 0 && sum <= 1440 ? sum : null;
}

int? _minutes(String value) {
  // Avoid retrying a numeric-duration regex at every digit in a long malformed
  // value. Normal hour/minute/second combinations are much shorter than this.
  if (value.length > 128) return null;
  if (RegExp(r'\d\s*[-–—]\s*\d|[.,]\d{3}').hasMatch(value)) return null;
  var minutes = 0.0;
  final duration = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(hours?|hrs?|stunden?|std\.?|h|minutes?|minuten|mins?|min\.?|seconds?|secs?|sekunden|sek\.?)\b',
    caseSensitive: false,
  );
  final remainder = value
      .replaceAll(duration, '')
      .replaceAll(RegExp(r'\b(?:and|und)\b', caseSensitive: false), '');
  if (remainder.replaceAll(RegExp(r'[\s,.+]+'), '').isNotEmpty) return null;
  for (final match in duration.allMatches(value)) {
    final amount = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    if (amount == null || !amount.isFinite) return null;
    final unit = match.group(2)!.toLowerCase();
    minutes +=
        amount *
        (unit.startsWith('h') || unit.startsWith('st')
            ? 60
            : unit.startsWith('s')
            ? 1 / 60
            : 1);
  }
  return minutes.isFinite && minutes > 0 && minutes <= 1440
      ? minutes.ceil()
      : null;
}

final _bullet = RegExp(r'^\s*(?:[•●▪◦]\s*|[-–—*]\s+)(.+)$');
final _numbered = RegExp(
  r'^\s*(?:(?:step|schritt)\s+\d+\s*[:.)]\s*|\(?\d+[.)]\s+)(.+)$',
  caseSensitive: false,
);

List<PersonalRecipeIngredient> _ingredients(List<String> lines) {
  // Leave room for a normal quantity/unit prefix in addition to the model's
  // name. Longer candidates remain available in the complete source fallback.
  const maxCandidateLength = maxPersonalIngredientNameLength + 100;
  final bulletStyle = lines.any(
    (line) => _bullet.hasMatch(line) || _numbered.hasMatch(line),
  );
  final collected = <({String text, String? group})>[];
  String? group;
  for (final original in lines) {
    final line = original.trim();
    if (line.isEmpty || _isPageNumber(line)) continue;
    final bullet = _bullet.firstMatch(line) ?? _numbered.firstMatch(line);
    if (bullet == null &&
        line.endsWith(':') &&
        !RegExp(r'^\d').hasMatch(line)) {
      group = _cleanHeading(line).replaceFirst(RegExp(r':$'), '');
      continue;
    }
    final value = bullet?.group(1)?.trim() ?? line;
    if (value.length > maxCandidateLength) {
      throw const FormatException('PDF ingredient exceeds model limits');
    }
    final newQuantity = RegExp(r'^(?:\d|[¼½¾⅓⅔⅛⅜⅝⅞])').hasMatch(value);
    final continuation =
        bullet == null &&
        !newQuantity &&
        collected.isNotEmpty &&
        (bulletStyle ||
            collected.last.text.endsWith(',') ||
            value.startsWith('('));
    if (continuation && collected.last.group == group) {
      if (collected.last.text.length + 1 + value.length > maxCandidateLength) {
        throw const FormatException('PDF ingredient exceeds model limits');
      }
      collected[collected.length - 1] = (
        text: '${collected.last.text} $value',
        group: group,
      );
    } else {
      collected.add((text: value, group: group));
    }
    if (collected.length > maxPersonalRecipeIngredients) {
      throw const FormatException('too many PDF ingredients');
    }
  }
  return [
    for (final line in collected) _ingredientWithGroup(line.text, line.group),
  ];
}

PersonalRecipeIngredient _ingredientWithGroup(String line, String? group) {
  final parsed = parseImportedIngredientLine(line);
  return PersonalRecipeIngredient(
    name: parsed.name,
    qty: parsed.qty,
    unit: parsed.unit,
    hasQuantity: parsed.hasQuantity,
    note: [
      if (group != null) group,
      if (parsed.note != null) parsed.note!,
    ].join(' · '),
  );
}

List<String> _steps(List<String> lines) {
  final numberedStyle = lines.any(
    (line) => _numbered.hasMatch(line) || _bullet.hasMatch(line),
  );
  final steps = <String>[];
  var paragraphBreak = true;
  for (final original in lines) {
    final line = original.trim();
    if (_isPageNumber(line)) continue;
    if (line.isEmpty) {
      paragraphBreak = true;
      continue;
    }
    final marker = _numbered.firstMatch(line) ?? _bullet.firstMatch(line);
    final text = marker?.group(1)?.trim() ?? line;
    if (steps.isEmpty || marker != null || (!numberedStyle && paragraphBreak)) {
      steps.add(text);
    } else {
      steps[steps.length - 1] = '${steps.last} $text';
    }
    paragraphBreak = false;
    if (steps.length > maxPersonalRecipeSteps ||
        steps.last.length > maxPersonalStepLength) {
      throw const FormatException('PDF instructions exceed model limits');
    }
  }
  return steps;
}
