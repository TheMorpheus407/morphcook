import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/l10n.dart';
import 'package:morphcook/logic/one_handed_cook_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocaleController', () {
    test('defaults to en and persists changes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final loc = LocaleController(prefs);
      expect(loc.lang, 'en');
      loc.setLang('de');
      expect(loc.lang, 'de');
      expect(prefs.getString('lang'), 'de');
    });

    test('reads stored language', () async {
      SharedPreferences.setMockInitialValues({'lang': 'de'});
      final prefs = await SharedPreferences.getInstance();
      expect(LocaleController(prefs).lang, 'de');
    });

    test('rejects unsupported languages', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final loc = LocaleController(prefs);
      loc.setLang('fr');
      expect(loc.lang, 'en');
    });
  });

  group('translations', () {
    late LocaleController en;
    late LocaleController de;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      en = LocaleController(prefs);
      de = LocaleController(prefs)..lang = 'de';
    });

    test('key lookup with fallback to en', () {
      expect(en.t('appName'), 'MorphCook');
      expect(de.t('appName'), 'MorphCook');
      expect(en.t('no.such.key'), 'no.such.key');
    });

    test('template placeholder replacement', () {
      final label = en.t('shAddSelected').replaceAll('{n}', '3');
      expect(label, 'add 3 to list');
    });

    test('all supported languages resolve every dish detail key', () {
      final keys = [
        'dishDiet', 'dishEffort', 'dishCalorieLevel', 'dishIngredients',
        'dishMethod', 'dishMacros', 'dishOverride', 'dishSave', 'dishCook',
      ];
      for (final k in keys) {
        expect(en.t(k), isNot(k), reason: 'en $k');
        expect(de.t(k), isNot(k), reason: 'de $k');
      }
    });

    test('effort / buckets / meals are translated in both languages', () {
      for (final e in ['easy', 'medium', 'hard']) {
        expect(en.t('effort.$e'), isNot(contains('effort.')));
        expect(de.t('effort.$e'), isNot(contains('effort.')));
      }
      for (final b in ['le15', 'le30', 'le60', 'gt60']) {
        expect(en.t('time.$b'), contains('min'));
        expect(de.t('time.$b'), contains('min'));
      }
      for (final m in ['breakfast', 'lunch', 'dinner', 'snack']) {
        expect(en.t('meal.$m'), isNotEmpty);
        expect(de.t('meal.$m'), isNotEmpty);
      }
    });

    test('aisles and months are complete', () {
      for (final a in ['produce', 'dairy', 'meat', 'fish', 'bakery', 'pantry', 'spices', 'baking', 'other']) {
        expect(en.t('aisle.$a'), isNot(contains('aisle.')), reason: a);
      }
      for (var m = 1; m <= 12; m++) {
        expect(en.t('month.$m'), isNot(contains('month.')), reason: 'month $m');
      }
    });

    test('backup error messages match the spec wording exactly (EN)', () {
      // spec: "Incorrect password. Please try again."
      expect(
        en.t('buWrongPassword'),
        'Incorrect password. Please try again.',
      );
      expect(
        en.t('buCorrupted'),
        'Backup file is corrupted and cannot be restored.',
      );
      expect(
        en.t('buInvalid'),
        'This file is not a valid MorphCook backup.',
      );
    });
  });

  group('OneHandedCookModeController', () {
    test('disabled by default — taps never advance', () {
      final c = OneHandedCookModeController();
      expect(c.tryAdvance(), isFalse);
    });

    test('single tap advances when enabled', () {
      final c = OneHandedCookModeController(quickNextTapEnabled: true);
      expect(c.tryAdvance(), isTrue);
    });

    test('300 ms debounce blocks rapid double-taps', () async {
      final c = OneHandedCookModeController(quickNextTapEnabled: true);
      expect(c.tryAdvance(), isTrue);
      expect(c.tryAdvance(), isFalse); // too fast
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(c.tryAdvance(), isTrue); // debounce elapsed
    });

    test('reduce-motion flag is carried', () {
      final c = OneHandedCookModeController(reduceMotion: true);
      expect(c.reduceMotion, isTrue);
    });
  });
}
