import 'package:morphcook/core/models.dart';
import 'package:morphcook/core/repository.dart';
import 'package:morphcook/state/app_state.dart';
import 'package:morphcook/state/storage.dart';

Recipe makeRecipe({
  String id = 'test',
  Set<String> contains = const {},
  Set<String> attributes = const {},
  Set<String> tags = const {},
  String effort = 'easy',
  String diet = 'classic',
  int minutes = 20,
  int calories = 500,
  List<Map<String, dynamic>>? ingredients,
  List<Map<String, dynamic>>? steps,
}) => Recipe.fromJson({
  'id': id,
  'dish_id': 'test-dish',
  'title': {'en': 'Test recipe', 'de': 'Testrezept'},
  'description': {
    'en': 'A complete recipe.',
    'de': 'Ein vollständiges Rezept.',
  },
  'contains': contains.toList(),
  'attributes': attributes.toList(),
  'tags': tags.toList(),
  'dimensions': {'diet': diet, 'effort': effort, 'calorie-level': 'balanced'},
  'time_minutes': minutes,
  'servings': 2,
  'calories_per_serving': calories,
  'macros': {'protein': 20, 'carbs': 50, 'fat': 10},
  'ingredients':
      ingredients ??
      [
        {'id': 'carrot', 'quantity': 200, 'unit': 'g'},
      ],
  'steps':
      steps ??
      [
        {
          'title': {'en': 'Prepare', 'de': 'Vorbereiten'},
          'text': {
            'en': 'Prepare the ingredients.',
            'de': 'Zutaten vorbereiten.',
          },
          'timer_seconds': 60,
        },
        {
          'title': {'en': 'Finish', 'de': 'Abschließen'},
          'text': {
            'en': 'Finish and serve.',
            'de': 'Fertigstellen und servieren.',
          },
          'timer_seconds': 0,
        },
      ],
});

Future<AppState> testState({
  bool onboarded = true,
  String lang = 'en',
  bool all = true,
}) async {
  final state = AppState(
    repository: RecipeRepository(),
    storage: MemoryStorage(),
  );
  await state.initialize();
  if (all) await state.repository.loadAll();
  state.profile = Profile(
    name: 'Alex',
    lang: lang,
    onboarded: onboarded,
    reduceMotion: true,
  );
  return state;
}

Map<String, dynamic> backupFixture() => {
  'schema_version': 1,
  'exported_at': '2026-09-30T10:00:00Z',
  'profile': Profile(name: 'Alex', onboarded: true).toJson(),
  'saved': ['doener-mushroom'],
  'meal_plan': {
    '2026-W40': {'mon.dinner': 'doener-mushroom'},
  },
  'history': [
    CookingRecord('doener-mushroom', DateTime.utc(2026, 9, 20), 2).toJson(),
  ],
  'content_requests': ['sushi'],
};
