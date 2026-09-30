import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/i18n/app_strings.dart';
import 'package:morphcook/core/i18n/localized_text.dart';
import 'package:morphcook/core/text/text_fold.dart';

void main() {
  group('TextFold', () {
    test('fold lower-cases and drops diacritics', () {
      expect(TextFold.fold('Döner'), 'doner');
      expect(TextFold.fold('Crème fraîche'), 'creme fraiche');
      expect(TextFold.fold('Straße'), 'strasse');
      expect(TextFold.fold('Jalapeño'), 'jalapeno');
    });

    test('expandUmlauts spells umlauts the German way', () {
      expect(TextFold.expandUmlauts('Döner'), 'doener');
      expect(TextFold.expandUmlauts('Käse'), 'kaese');
      expect(TextFold.expandUmlauts('Süß'), 'suess');
    });

    test('words split on punctuation and drop one-letter noise, keeping digits', () {
      expect(TextFold.words("Cow's milk, 2% fat"), ['cow', 'milk', '2', 'fat']);
      expect(TextFold.words('  '), isEmpty);
    });

    test('stemming is a consistent plural folding', () {
      expect(TextFold.stem('tomatoes'), 'tomato');
      expect(TextFold.stem('berries'), 'berry');
      expect(TextFold.stem('kartoffeln'), 'kartoffel');
      expect(TextFold.stem('eggs'), 'eggs', reason: 'short words stay; prefix matching still finds them');
      expect(TextFold.stem('rice'), 'rice');
    });

    test('variants cover folded, expanded and stemmed spellings', () {
      final v = TextFold.variants('Döner');
      expect(v, containsAll(['doner', 'doener']));
    });

    test('a query token reaches an index token in both spellings', () {
      final index = TextFold.tokens('Käsespätzle');
      final query = TextFold.tokens('kaesespaetzle');
      expect(index.intersection(query), isNotEmpty);
      expect(TextFold.tokens('Spätzle').intersection(TextFold.tokens('spaetzle')), isNotEmpty);
    });
  });

  group('LocalizedText', () {
    test('resolves the language, then English, then anything', () {
      const text = LocalizedText({'en': 'cheese', 'de': 'Käse'});
      expect(text.resolve('de'), 'Käse');
      expect(text.resolve('fr'), 'cheese');
      expect(const LocalizedText({'de': 'Käse'}).resolve('fr'), 'Käse');
      expect(const LocalizedText({'en': '', 'de': 'Käse'}).resolve('en'), 'Käse', reason: 'empty is missing');
      expect(LocalizedText.empty.resolve('en'), '');
    });

    test('reads a map, a bare string and null', () {
      expect(LocalizedText.fromJson({'en': 'a', 'de': 'b'}).resolve('de'), 'b');
      expect(LocalizedText.fromJson('plain').resolve('de'), 'plain');
      expect(LocalizedText.fromJson(null).isEmpty, isTrue);
      expect(() => LocalizedText.fromJson(42), throwsFormatException);
    });

    test('a new language is a data addition: any code works', () {
      const text = LocalizedText({'en': 'bread', 'fr': 'pain'});
      expect(text.resolve('fr'), 'pain');
      expect(text.hasLanguage('fr'), isTrue);
      expect(text.hasLanguage('de'), isFalse);
      expect(text.languages, ['en', 'fr']);
    });

    test('equality and JSON', () {
      const a = LocalizedText({'en': 'a', 'de': 'b'});
      expect(a, const LocalizedText({'de': 'b', 'en': 'a'}));
      expect(a == const LocalizedText({'en': 'a'}), isFalse);
      expect(a.toJson(), {'en': 'a', 'de': 'b'});
    });
  });

  group('AppStrings', () {
    final data = AppStringsData({
      'hello': const LocalizedText({'en': 'hello {name}', 'de': 'hallo {name}'}),
      'item.one': const LocalizedText({'en': '{n} item', 'de': '{n} Stück'}),
      'item.other': const LocalizedText({'en': '{n} items', 'de': '{n} Stücke'}),
      'only.en': const LocalizedText({'en': 'english only'}),
      'date.wd.l.1': const LocalizedText({'en': 'monday', 'de': 'montag'}),
      'date.wd.s.1': const LocalizedText({'en': 'mon', 'de': 'mo'}),
      'date.m.l.9': const LocalizedText({'en': 'september', 'de': 'september'}),
      'date.m.s.9': const LocalizedText({'en': 'sep', 'de': 'sep'}),
    });

    test('fills placeholders and follows the language', () {
      expect(AppStrings(data, 'en')('hello', {'name': 'Sam'}), 'hello Sam');
      expect(AppStrings(data, 'de')('hello', {'name': 'Sam'}), 'hallo Sam');
    });

    test('falls back to English, and an unknown key shows itself', () {
      expect(AppStrings(data, 'de')('only.en'), 'english only');
      expect(AppStrings(data, 'de')('missing.key'), 'missing.key');
    });

    test('plurals: one for exactly 1, other otherwise, decimal comma in German', () {
      final en = AppStrings(data, 'en');
      expect(en.plural('item', 1), '1 item');
      expect(en.plural('item', 0), '0 items');
      expect(en.plural('item', 2.5), '2.5 items');
      expect(AppStrings(data, 'de').plural('item', 2.5), '2,5 Stücke');
    });

    test('dates read in the paper voice', () {
      final en = AppStrings(data, 'en');
      expect(en.longDate(DateTime(2026, 9, 28)), 'monday, 28 september 2026');
      expect(en.shortDate(DateTime(2026, 9, 28)), 'mon 28 sep');
      expect(AppStrings(data, 'de').shortDate(DateTime(2026, 9, 28)), 'mo 28. sep');
    });

    test('withLanguage switches without reloading', () {
      final en = AppStrings(data, 'en');
      expect(en.withLanguage('de')('hello', {'name': 'A'}), 'hallo A');
    });
  });
}
