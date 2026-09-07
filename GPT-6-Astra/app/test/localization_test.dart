import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/app_state.dart';
import 'package:morphcook/core/models.dart';
import 'package:morphcook/core/repository.dart';
import 'package:morphcook/ui/design.dart';

void main() {
  test(
    'a language added as data supplies static and interpolated interface text',
    () {
      final state = AppState.inMemory(
        repo: Repository.empty(),
        profile: Profile(lang: 'fr'),
      );
      state.repo.uiStrings.addAll({
        '@languageNames': {'en': 'English', 'de': 'Deutsch', 'fr': 'Français'},
        'Settings': {'en': 'Settings', 'de': 'Einstellungen', 'fr': 'Réglages'},
        '{0} recipes for {1}': {
          'en': '{0} recipes for {1}',
          'de': '{0} Rezepte für {1}',
          'fr': 'Pour {1} : {0} recettes',
        },
      });
      expect(languageNames(state)['fr'], 'Français');
      expect(tr(state, 'Settings', 'Einstellungen'), 'Réglages');
      expect(
        tr(state, '12 recipes for Marie', '12 Rezepte für Marie'),
        'Pour Marie : 12 recettes',
      );
      expect(tr(state, 'Unknown copy', 'Unbekannter Text'), 'Unknown copy');
      expect(
        translateUi(
          state,
          'de',
          '12 recipes for Marie',
          '12 Rezepte für Marie',
        ),
        '12 Rezepte für Marie',
      );
    },
  );
}
