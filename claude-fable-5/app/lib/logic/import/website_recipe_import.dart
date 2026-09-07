import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:html/parser.dart' as html_parser;

import '../../models/personal_recipe.dart';
import '../../models/recipe_image.dart';

const maxWebsiteRecipePageBytes = 2 * 1024 * 1024;

enum WebsiteRecipeImportFailure {
  invalidUrl,
  network,
  timeout,
  tooLarge,
  unsupportedPage,
  noRecipe,
  invalidRecipe,
  unsupportedImage,
}

class WebsiteRecipeImportException implements Exception {
  final WebsiteRecipeImportFailure failure;

  const WebsiteRecipeImportException(this.failure);

  @override
  String toString() => 'WebsiteRecipeImportException: ${failure.name}';
}

/// A local, editable draft. Fetching the page never downloads [imageUrl].
class WebsiteRecipeImport {
  final PersonalRecipe recipe;
  final Uri? imageUrl;
  final bool usedDefaultTime;
  final bool usedDefaultServings;

  const WebsiteRecipeImport({
    required this.recipe,
    this.imageUrl,
    this.usedDefaultTime = false,
    this.usedDefaultServings = false,
  });
}

/// Makes only user-requested HTTP(S) requests, with no cookies or credentials.
/// A fresh client prevents website state carrying over between imports.
class WebsiteRecipeImporter {
  final Duration timeout;
  final int maxPageBytes;
  final int maxImageBytes;
  final int maxRedirects;
  final HttpClient Function()? clientFactory;

  const WebsiteRecipeImporter({
    this.timeout = const Duration(seconds: 20),
    this.maxPageBytes = maxWebsiteRecipePageBytes,
    this.maxImageBytes = maxRecipeImageBytes,
    this.maxRedirects = 5,
    this.clientFactory,
  });

  Future<List<WebsiteRecipeImport>> fetch(Uri uri) async {
    final result = await _download(uri, image: false);
    final encoding = Encoding.getByName(result.charset) ?? utf8;
    final page = encoding == utf8
        ? utf8.decode(result.bytes, allowMalformed: true)
        : encoding.decode(result.bytes);
    // Resolve relative links against the final page after redirects, and keep
    // that same page as the recipe's source for attribution.
    return parseWebsiteRecipes(page, result.uri);
  }

  Future<Uint8List> fetchImage(Uri uri) async {
    final result = await _download(uri, image: true);
    try {
      // Reuse image validation before returning bytes to the caller. The image
      // stays optional and will only enter private storage when the user saves.
      RecipeImage(
        recipeId: 'website-import',
        bytes: result.bytes,
        updatedAt: DateTime.now(),
      );
    } on RecipeImageException {
      throw const WebsiteRecipeImportException(
        WebsiteRecipeImportFailure.unsupportedImage,
      );
    }
    return result.bytes;
  }

  Future<_Downloaded> _download(Uri initialUri, {required bool image}) async {
    _validateUri(initialUri);
    final limit = image ? maxImageBytes : maxPageBytes;
    if (limit <= 0 || timeout <= Duration.zero || maxRedirects < 0) {
      throw ArgumentError('invalid website import limits');
    }
    final client = (clientFactory ?? HttpClient.new)();
    client.connectionTimeout = timeout;
    client.userAgent = 'MorphCook/1.0 (user-requested recipe import)';
    try {
      return await (() async {
        var uri = initialUri;
        for (var redirects = 0; ; redirects++) {
          _validateUri(uri);
          final request = await client.getUrl(uri);
          request.followRedirects = false;
          request.headers.set(
            HttpHeaders.acceptHeader,
            image
                ? 'image/jpeg,image/png,image/webp'
                : 'text/html,application/xhtml+xml',
          );
          final response = await request.close();
          if (const [301, 302, 303, 307, 308].contains(response.statusCode)) {
            final location = response.headers.value(HttpHeaders.locationHeader);
            if (location == null || redirects >= maxRedirects) {
              throw const WebsiteRecipeImportException(
                WebsiteRecipeImportFailure.network,
              );
            }
            uri = uri.resolve(location);
            _validateUri(uri);
            // Do not drain an unbounded redirect body before proceeding.
            await response.listen((_) {}).cancel();
            continue;
          }
          if (response.statusCode != HttpStatus.ok) {
            throw const WebsiteRecipeImportException(
              WebsiteRecipeImportFailure.network,
            );
          }
          final contentType = response.headers.contentType;
          final mime = contentType?.mimeType;
          if (!image &&
              mime != null &&
              !const ['text/html', 'application/xhtml+xml'].contains(mime)) {
            throw const WebsiteRecipeImportException(
              WebsiteRecipeImportFailure.unsupportedPage,
            );
          }
          if (response.contentLength > limit) {
            throw const WebsiteRecipeImportException(
              WebsiteRecipeImportFailure.tooLarge,
            );
          }
          final bytes = BytesBuilder(copy: false);
          await for (final chunk in response) {
            if (bytes.length + chunk.length > limit) {
              throw const WebsiteRecipeImportException(
                WebsiteRecipeImportFailure.tooLarge,
              );
            }
            bytes.add(chunk);
          }
          return _Downloaded(bytes.takeBytes(), uri, contentType?.charset);
        }
      })().timeout(timeout);
    } on TimeoutException {
      throw const WebsiteRecipeImportException(
        WebsiteRecipeImportFailure.timeout,
      );
    } on WebsiteRecipeImportException {
      rethrow;
    } on FormatException {
      throw const WebsiteRecipeImportException(
        WebsiteRecipeImportFailure.invalidUrl,
      );
    } on IOException {
      throw const WebsiteRecipeImportException(
        WebsiteRecipeImportFailure.network,
      );
    } finally {
      client.close(force: true);
    }
  }
}

class _Downloaded {
  final Uint8List bytes;
  final Uri uri;
  final String? charset;

  const _Downloaded(this.bytes, this.uri, this.charset);
}

void _validateUri(Uri uri) {
  if (!const ['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.toString().length > 4096) {
    throw const WebsiteRecipeImportException(
      WebsiteRecipeImportFailure.invalidUrl,
    );
  }
}

/// Parses schema.org JSON-LD used by Chefkoch, Allrecipes and many other
/// recipe websites. HTML scripts are read as data and never executed.
List<WebsiteRecipeImport> parseWebsiteRecipes(String html, Uri source) {
  _validateUri(source);
  if (html.length > maxWebsiteRecipePageBytes ||
      utf8.encode(html).length > maxWebsiteRecipePageBytes) {
    throw const WebsiteRecipeImportException(
      WebsiteRecipeImportFailure.tooLarge,
    );
  }
  final document = html_parser.parse(html);
  final nodes = <Map<String, dynamic>>[];
  final references = <String, Map<String, dynamic>>{};
  var visited = 0;
  for (final script in document.querySelectorAll('script')) {
    if (script.attributes['type']?.split(';').first.trim().toLowerCase() !=
        'application/ld+json') {
      continue;
    }
    dynamic decoded;
    try {
      _checkJsonDepth(script.text);
      decoded = jsonDecode(script.text.trim());
    } on FormatException {
      // One broken analytics/schema script must not hide another valid recipe.
      continue;
    }
    final pending = <(dynamic, int)>[(decoded, 0)];
    while (pending.isNotEmpty) {
      final (node, depth) = pending.removeLast();
      if (++visited > 50000 || depth > 128) {
        throw const WebsiteRecipeImportException(
          WebsiteRecipeImportFailure.tooLarge,
        );
      }
      if (node is List) {
        for (final child in node.reversed) {
          pending.add((child, depth + 1));
        }
      } else if (node is Map<String, dynamic>) {
        final id = node['@id'];
        if (id is String && node.length > 1) references[id] = node;
        if (_hasType(node['@type'], 'Recipe')) nodes.add(node);
        for (final child in node.values.toList().reversed) {
          if (child is Map || child is List) pending.add((child, depth + 1));
        }
      }
    }
  }
  if (nodes.isEmpty) {
    throw const WebsiteRecipeImportException(
      WebsiteRecipeImportFailure.noRecipe,
    );
  }
  final result = <WebsiteRecipeImport>[];
  final seen = <String>{};
  for (final node in nodes) {
    try {
      final title = _text(node['name']);
      final ingredients = _ingredientLines(
        node['recipeIngredient'] ?? node['ingredients'],
        references,
      ).take(maxPersonalRecipeIngredients + 1).map(_ingredient).toList();
      final steps = _instructionLines(node['recipeInstructions'], references)
          .take(maxPersonalRecipeSteps + 1)
          .map((text) => PersonalRecipeStep(text: text))
          .toList();
      final total = _duration(node['totalTime']);
      final parts =
          (_duration(node['prepTime']) ?? 0) +
          (_duration(node['cookTime']) ?? 0);
      final time = total ?? (parts > 0 && parts <= 1440 ? parts : null);
      final servings = _servings(node['recipeYield']);
      final recipe = PersonalRecipe.create(
        title: title,
        description: _text(node['description']),
        sourceUrl: source.toString(),
        sourceAuthor: _metadata(node['author'], references),
        sourceDiet: _metadata(node['suitableForDiet'], references),
        timeMinutes: time ?? 30,
        servings: servings ?? 2,
        ingredients: ingredients,
        steps: steps,
      );
      final signature = jsonEncode([
        recipe.title,
        recipe.ingredients.map((i) => i.toJson()).toList(),
        recipe.steps.map((s) => s.toJson()).toList(),
      ]);
      if (!seen.add(signature)) continue;
      result.add(
        WebsiteRecipeImport(
          recipe: recipe,
          imageUrl: _imageUri(node['image'], source, references),
          usedDefaultTime: time == null,
          usedDefaultServings: servings == null,
        ),
      );
      if (result.length > 50) {
        throw const WebsiteRecipeImportException(
          WebsiteRecipeImportFailure.tooLarge,
        );
      }
    } on FormatException {
      // Suggested/related recipe stubs often omit ingredients or instructions.
      // They do not prevent importing complete recipes on the same page.
      continue;
    }
  }
  if (result.isEmpty) {
    throw const WebsiteRecipeImportException(
      WebsiteRecipeImportFailure.invalidRecipe,
    );
  }
  return result;
}

bool _hasType(dynamic value, String expected) {
  final names = [
    expected,
    'https://schema.org/$expected',
    'http://schema.org/$expected',
  ];
  return value is List ? value.any(names.contains) : names.contains(value);
}

/// Bound nesting before JSON decoding and all subsequent tree traversals.
void _checkJsonDepth(String text) {
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (final char in text.codeUnits) {
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == 92) {
        escaped = true;
      } else if (char == 34) {
        inString = false;
      }
    } else if (char == 34) {
      inString = true;
    } else if (char == 91 || char == 123) {
      if (++depth > 128) {
        throw const WebsiteRecipeImportException(
          WebsiteRecipeImportFailure.tooLarge,
        );
      }
    } else if (char == 93 || char == 125) {
      depth--;
    }
  }
}

String _text(dynamic value, {int maxLength = maxPersonalStepLength}) {
  if (value is! String) return '';
  // Reject large referenced leaves before repeatedly parsing/expanding them.
  if (value.length > maxLength) {
    throw const FormatException('recipe text is too long');
  }
  // Fragment.text does not insert spaces between block elements on its own.
  final separated = value.replaceAll(
    RegExp(r'<\s*(?:br\s*/?|/p|/div|/li|/h[1-6])\s*>', caseSensitive: false),
    '\n',
  );
  final fragment = html_parser.parseFragment(separated);
  for (final element in fragment.querySelectorAll('script,style')) {
    element.remove();
  }
  return (fragment.text ?? '')
      .replaceAll('\u00a0', ' ')
      .split(RegExp(r'[\r\n]+'))
      .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
}

dynamic _resolve(dynamic value, Map<String, Map<String, dynamic>> references) {
  if (value is Map && value.length == 1 && value['@id'] is String) {
    return references[value['@id']] ?? value;
  }
  return value;
}

class _ExpansionBudget {
  int _remaining = 5000;
  void visit() {
    if (--_remaining < 0) {
      throw const FormatException('too many referenced recipe fields');
    }
  }
}

Iterable<String> _ingredientLines(
  dynamic value,
  Map<String, Map<String, dynamic>> references, [
  int depth = 0,
  _ExpansionBudget? budget,
]) sync* {
  final traversal = budget ?? _ExpansionBudget();
  traversal.visit();
  if (depth > 32) throw const FormatException('nested ingredients');
  value = _resolve(value, references);
  if (value is String) {
    yield* _text(value).split('\n').where((line) => line.isNotEmpty);
  } else if (value is List) {
    for (final child in value) {
      yield* _ingredientLines(child, references, depth + 1, traversal);
    }
  } else if (value is Map) {
    if (value['itemListElement'] != null || value['item'] != null) {
      yield* _ingredientLines(
        value['itemListElement'] ?? value['item'],
        references,
        depth + 1,
        traversal,
      );
    } else if (_hasType(value['@type'], 'PropertyValue')) {
      final name = _text(value['name']);
      final amount = value['value'];
      final unit = _text(value['unitText']);
      if (name.isEmpty) throw const FormatException('missing ingredient name');
      yield [
        if (amount is String || amount is num) '$amount',
        if (unit.isNotEmpty) unit,
        name,
      ].join(' ');
    } else {
      throw const FormatException('unsupported ingredient');
    }
  } else if (value != null) {
    throw const FormatException('unsupported ingredient');
  }
}

Iterable<String> _instructionLines(
  dynamic value,
  Map<String, Map<String, dynamic>> references, [
  int depth = 0,
  _ExpansionBudget? budget,
]) sync* {
  final traversal = budget ?? _ExpansionBudget();
  traversal.visit();
  if (depth > 32) throw const FormatException('nested instructions');
  value = _resolve(value, references);
  if (value is String) {
    yield* _text(value).split('\n').where((line) => line.isNotEmpty);
  } else if (value is List) {
    for (final child in value) {
      yield* _instructionLines(child, references, depth + 1, traversal);
    }
  } else if (value is Map) {
    final children =
        value['itemListElement'] ?? value['steps'] ?? value['item'];
    if (children != null) {
      final lines = _instructionLines(
        children,
        references,
        depth + 1,
        traversal,
      ).take(maxPersonalRecipeSteps + 1).toList();
      final heading = _text(value['name']);
      if (_hasType(value['@type'], 'HowToSection') &&
          heading.isNotEmpty &&
          lines.isNotEmpty) {
        if (heading.length + lines[0].length + 2 > maxPersonalStepLength) {
          throw const FormatException('recipe section is too long');
        }
        lines[0] = '$heading: ${lines[0]}';
      }
      yield* lines;
    } else {
      final text = _text(value['text']);
      if (text.isEmpty) throw const FormatException('missing instruction text');
      yield text;
    }
  } else if (value != null) {
    throw const FormatException('unsupported instruction');
  }
}

String? _metadata(
  dynamic value,
  Map<String, Map<String, dynamic>> references, [
  int depth = 0,
  _ExpansionBudget? budget,
]) {
  final traversal = budget ?? _ExpansionBudget();
  traversal.visit();
  if (depth > 16) return null;
  value = _resolve(value, references);
  if (value is List) {
    final output = StringBuffer();
    for (final part in value) {
      final text = _metadata(part, references, depth + 1, traversal);
      if (text == null || text.isEmpty) continue;
      if (output.length + text.length + 2 > 1000) {
        throw const FormatException('recipe attribution is too long');
      }
      if (output.isNotEmpty) output.write(', ');
      output.write(text);
    }
    return output.isEmpty ? null : output.toString();
  }
  if (value is Map) {
    return _metadata(
      value['name'] ?? value['@id'],
      references,
      depth + 1,
      traversal,
    );
  }
  final text = _text(value, maxLength: 1000);
  return text.isEmpty ? null : text;
}

Uri? _imageUri(
  dynamic value,
  Uri source,
  Map<String, Map<String, dynamic>> references, [
  int depth = 0,
  _ExpansionBudget? budget,
]) {
  final traversal = budget ?? _ExpansionBudget();
  traversal.visit();
  if (depth > 16) return null;
  value = _resolve(value, references);
  if (value is List) {
    for (final candidate in value) {
      final uri = _imageUri(
        candidate,
        source,
        references,
        depth + 1,
        traversal,
      );
      if (uri != null) return uri;
    }
  } else if (value is Map) {
    return _imageUri(
      value['contentUrl'] ?? value['url'] ?? value['@id'],
      source,
      references,
      depth + 1,
      traversal,
    );
  } else if (value is String && value.trim().isNotEmpty) {
    try {
      final uri = source.resolve(value.trim());
      _validateUri(uri);
      return uri;
    } on FormatException {
      return null;
    } on WebsiteRecipeImportException {
      return null;
    }
  }
  return null;
}

int? _duration(dynamic value) {
  if (value is! String) return null;
  final match = RegExp(
    r'^P(?:(\d+(?:\.\d+)?)D)?(?:T(?:(\d+(?:\.\d+)?)H)?(?:(\d+(?:\.\d+)?)M)?(?:(\d+(?:\.\d+)?)S)?)?$',
    caseSensitive: false,
  ).firstMatch(value.trim());
  if (match == null) return null;
  double part(int i) => double.tryParse(match.group(i) ?? '') ?? 0;
  final number = part(1) * 1440 + part(2) * 60 + part(3) + part(4) / 60;
  if (!number.isFinite || number > 1440) return null;
  final minutes = number.ceil();
  return minutes > 0 && minutes <= 1440 ? minutes : null;
}

int? _servings(dynamic value) {
  if (value is List) {
    for (final part in value) {
      final servings = _servings(part);
      if (servings != null) return servings;
    }
    return null;
  }
  if (value is Map) {
    final unit = _text(value['unitText']);
    if (unit.isNotEmpty &&
        !RegExp(
          r'^(?:servings?|portions?|portionen|personen|people)$',
          caseSensitive: false,
        ).hasMatch(unit)) {
      return null;
    }
    return _servings(value['value']);
  }
  final text = value is num ? '$value' : _text(value);
  final match = RegExp(
    r'^\s*(\d+)(?:\s*(?:servings?|portions?|portionen|personen|people))?\s*$',
    caseSensitive: false,
  ).firstMatch(text);
  if (match == null) return null;
  final servings = int.tryParse(match.group(1)!);
  return servings != null && servings > 0 && servings <= 1000 ? servings : null;
}

const _fractionValues = <String, String>{
  '¼': '1/4',
  '½': '1/2',
  '¾': '3/4',
  '⅓': '1/3',
  '⅔': '2/3',
  '⅛': '1/8',
  '⅜': '3/8',
  '⅝': '5/8',
  '⅞': '7/8',
};

const _ingredientUnits = <String, String>{
  'g': 'g',
  'gram': 'g',
  'grams': 'g',
  'gramm': 'g',
  'kg': 'kg',
  'kilogram': 'kg',
  'kilograms': 'kg',
  'kilogramm': 'kg',
  'ml': 'ml',
  'milliliter': 'ml',
  'milliliters': 'ml',
  'l': 'l',
  'liter': 'l',
  'liters': 'l',
  'litre': 'l',
  'litres': 'l',
  'tl': 'tsp',
  'tsp': 'tsp',
  'teaspoon': 'tsp',
  'teaspoons': 'tsp',
  'el': 'tbsp',
  'tbsp': 'tbsp',
  'tablespoon': 'tbsp',
  'tablespoons': 'tbsp',
  'cup': 'cup',
  'cups': 'cup',
  'piece': 'piece',
  'pieces': 'piece',
  'stück': 'piece',
  'stk': 'piece',
  'clove': 'clove',
  'cloves': 'clove',
  'zehe': 'clove',
  'zehen': 'clove',
  'slice': 'slice',
  'slices': 'slice',
  'scheibe': 'slice',
  'scheiben': 'slice',
  'can': 'can',
  'cans': 'can',
  'dose': 'can',
  'dosen': 'can',
  'bunch': 'bunch',
  'bunches': 'bunch',
  'bund': 'bunch',
  'pinch': 'pinch',
  'pinches': 'pinch',
  'prise': 'pinch',
  'prisen': 'pinch',
  'sprig': 'sprig',
  'sprigs': 'sprig',
  'zweig': 'sprig',
  'zweige': 'sprig',
  'oz': 'oz',
  'ounce': 'oz',
  'ounces': 'oz',
  'lb': 'lb',
  'lbs': 'lb',
  'pound': 'lb',
  'pounds': 'lb',
  'pint': 'pint',
  'pints': 'pint',
  'quart': 'quart',
  'quarts': 'quart',
};

/// Conservatively parse an imported ingredient, preserving uncertain amounts
/// as an unscaled original line. Shared by website and selectable-text PDF imports.
PersonalRecipeIngredient parseImportedIngredientLine(String line) =>
    _ingredient(line);

PersonalRecipeIngredient _ingredient(String line) {
  PersonalRecipeIngredient raw() => PersonalRecipeIngredient(
    name: line,
    qty: 1,
    unit: 'raw',
    hasQuantity: false,
  );
  var normalized = line;
  for (final fraction in _fractionValues.entries) {
    normalized = normalized.replaceAll(fraction.key, ' ${fraction.value} ');
  }
  normalized = normalized.trim().replaceAll(RegExp(r'\s+'), ' ');
  final match = RegExp(
    r'^(\d+\s+\d+/\d+|\d+/\d+|\d+(?:[.,]\d+)?)\s*(.*)$',
  ).firstMatch(normalized);
  if (match == null) return raw();
  final amount = match.group(1)!;
  // A separator followed by three digits can be either a decimal or a
  // thousands group. Without a trusted locale, retain the original amount.
  if (RegExp(r'[.,]\d{3}$').hasMatch(amount)) return raw();
  double qty;
  if (amount.contains('/')) {
    final parts = amount.split(' ');
    final fraction = parts.last.split('/');
    final denominator = double.parse(fraction.last);
    if (denominator == 0) return raw();
    qty = double.parse(fraction.first) / denominator;
    if (parts.length > 1) qty += double.parse(parts.first);
  } else {
    qty = double.parse(amount.replaceAll(',', '.'));
  }
  if (!qty.isFinite || qty <= 0 || qty > 1000000) return raw();
  var remaining = match.group(2)!.trim();
  // Equivalents, alternatives and extra measured amounts cannot be scaled
  // independently. Preserve the original line whenever another number occurs.
  if (RegExp(r'\d').hasMatch(remaining)) return raw();
  if (remaining.isEmpty || RegExp(r'^[\d\-–—/(]').hasMatch(remaining)) {
    return raw();
  }
  final unitMatch = RegExp(r'^([^\s.]+)\.?\s+(.+)$').firstMatch(remaining);
  final unit = unitMatch == null
      ? null
      : _ingredientUnits[unitMatch.group(1)!.toLowerCase()];
  if (unit != null) {
    remaining = unitMatch!.group(2)!;
    // Compound measures must scale together; retaining the full line avoids
    // scaling only the first quantity and silently changing the recipe.
    if (RegExp(
      r'^(?:plus\b|and\b|und\b|\+)',
      caseSensitive: false,
    ).hasMatch(remaining)) {
      return raw();
    }
  } else {
    // Keep unfamiliar measures and imprecise phrases intact. Only clear
    // unitless counts such as "2 eggs" can safely receive a piece quantity.
    if (!RegExp(
      r'^(?:eggs?|eier?|onions?|zwiebeln?|tomatoes?|tomaten?|potatoes?|kartoffeln?|carrots?|karotten?|bananas?|bananen?|lemons?|zitronen?|limes?|limetten?|apples?|äpfel|apfel|garlic cloves?|knoblauchzehen?)(?:\s|,|$)',
      caseSensitive: false,
    ).hasMatch(remaining)) {
      return raw();
    }
  }
  return PersonalRecipeIngredient(
    name: remaining,
    qty: qty,
    unit: unit ?? 'piece',
  );
}
