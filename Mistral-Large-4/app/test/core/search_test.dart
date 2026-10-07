import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/search.dart';

void main() {
  group('SearchEngine.tokenize', () {
    test('lowercases and splits on non-word characters', () {
      expect(SearchEngine.tokenize('Spaghetti Carbonara!'), ['spaghetti', 'carbonara']);
      expect(SearchEngine.tokenize('  one-pot,  30 min '), ['one', 'pot', '30', 'min']);
    });

    test('keeps german umlauts and accented letters', () {
      expect(SearchEngine.tokenize('Käse Spätzle'), ['käse', 'spätzle']);
      expect(SearchEngine.tokenize('Crème fraîche'), ['crème', 'fraîche']);
      expect(SearchEngine.tokenize('Döner Kebab'), ['döner', 'kebab']);
    });

    test('drops tokens shorter than 2 characters', () {
      expect(SearchEngine.tokenize('a 1 ab 2 go'), ['ab', 'go']);
    });

    test('empty and punctuation-only input yields no tokens', () {
      expect(SearchEngine.tokenize(''), []);
      expect(SearchEngine.tokenize('— … !'), []);
    });

    test('digits are kept', () {
      expect(SearchEngine.tokenize('30 min'), ['30', 'min']);
    });
  });

  group('SearchIndexEntry', () {
    test('json roundtrip keeps per-language tokens', () {
      final entry = SearchIndexEntry.fromJson({
        'recipe_id': 'doener-classic',
        'tokens': {
          'en': ['döner', 'kebab'],
          'de': ['döner', 'kebap'],
        },
      });
      expect(entry.recipeId, 'doener-classic');
      expect(entry.tokens['en'], ['döner', 'kebab']);
      expect(entry.tokens['de'], ['döner', 'kebap']);
    });
  });
}
