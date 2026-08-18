import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/app_state.dart';
import 'package:morphcook/data/corpus.dart';
import 'package:morphcook/data/store.dart';
import 'package:morphcook/logic/backup.dart';
import 'package:morphcook/models/collections.dart';
import 'package:morphcook/models/profile.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('profile save and cookbook toggle persist', () async {
    final store = MemoryStore();
    final state = AppState(
      store: store,
      corpus: CorpusRepository(bundle: rootBundle),
    );
    await state.load();
    await state.updateProfile(const Profile(name: 'ada', lang: 'de'));
    expect(store.loadProfile()?.name, 'ada');
    await state.toggleSaved('doener-vegan');
    expect(state.isSaved('doener-vegan'), isTrue);
    await state.toggleSaved('doener-vegan');
    expect(state.isSaved('doener-vegan'), isFalse);
  });

  test('meal plan move swaps slots', () async {
    final state = AppState(
      store: MemoryStore(),
      corpus: CorpusRepository(bundle: rootBundle),
    );
    await state.load();
    await state.assignMeal('2026-W16', 'mon.dinner', 'a');
    await state.assignMeal('2026-W16', 'tue.dinner', 'b');
    await state.moveMeal('2026-W16', 'mon.dinner', 'tue.dinner');
    expect(state.mealPlan['2026-W16']?['tue.dinner'], 'a');
    expect(state.mealPlan['2026-W16']?['mon.dinner'], 'b');
  });

  test('backup apply replace never touches corpus', () async {
    final state = AppState(
      store: MemoryStore(),
      corpus: CorpusRepository(bundle: rootBundle),
    );
    await state.load();
    await state.toggleSaved('keep-me');
    await state.applyBackup(
      BackupData(
        profile: const Profile(name: 'bea'),
        saved: [
          SavedRecipe(recipeId: 'new', savedAt: DateTime.utc(2026)),
        ],
        mealPlan: const {},
        history: const [],
      ),
      merge: false,
    );
    expect(state.profile.name, 'bea');
    expect(state.saved.map((s) => s.recipeId), ['new']);
    expect(state.onboarded, isTrue);
  });

  test('content requests log unique queries', () async {
    final state = AppState(
      store: MemoryStore(),
      corpus: CorpusRepository(bundle: rootBundle),
    );
    await state.load();
    await state.logContentRequest('Pad Thai');
    await state.logContentRequest('pad thai');
    expect(state.contentRequests, ['pad thai']);
  });
}
