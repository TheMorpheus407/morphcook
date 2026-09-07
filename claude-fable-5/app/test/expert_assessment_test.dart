import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/app_state.dart';
import 'package:morphcook/data/store.dart';
import 'package:morphcook/logic/backup/backup_service.dart';
import 'package:morphcook/logic/sharing/recipe_share.dart';
import 'package:morphcook/models/expert_assessment.dart';
import 'package:morphcook/models/personal_recipe.dart';

import 'helpers.dart';

PersonalRecipe recipe() => PersonalRecipe.create(
  title: 'Test soup',
  timeMinutes: 30,
  servings: 2,
  ingredients: [PersonalRecipeIngredient(name: 'carrots', qty: 200, unit: 'g')],
  steps: [PersonalRecipeStep(text: 'Simmer.')],
);

ExpertAssessment assessment(
  PersonalRecipe recipe, {
  String? id,
  String text = 'Use the assessment context provided by the reviewer.',
}) => ExpertAssessment(
  id: id,
  recipeId: recipe.id,
  recipeFingerprint: expertRecipeFingerprint(recipe.asRecipe()),
  expertName: 'Test reviewer',
  qualifications: 'Recorded qualification',
  assessment: text,
  source: 'Private consultation',
  reviewedAt: DateTime.utc(2026, 1, 2),
);

Future<AppState> stateForAssessments([MemoryStore? store]) async {
  final state = AppState(
    store: store ?? MemoryStore(),
    corpus: await loadRealCorpus(all: false),
  );
  await state.load();
  return state;
}

class FailingAssessmentStore extends MemoryStore {
  bool fail = false;
  @override
  Future<void> putCollection(String key, String value) async {
    await super.putCollection(key, value);
    if (fail && key == 'expert_assessments') {
      fail = false;
      throw const FileSystemException('after-write failure');
    }
  }
}

class PausedAssessmentStore extends MemoryStore {
  Completer<void>? release;
  final entered = Completer<void>();
  @override
  Future<void> putCollection(String key, String value) async {
    final gate = release;
    if (key == 'expert_assessments' && gate != null) {
      release = null;
      entered.complete();
      await gate.future;
    }
    await super.putCollection(key, value);
  }
}

void main() {
  test(
    'assessment date rejects calendar normalization, future dates and malformed input',
    () {
      final now = DateTime(2026, 9, 7);
      for (final date in [
        '2026-02-31',
        '2026-09-08',
        '2200-01-01',
        '2026-1-02',
        '0000-01-01',
        'not a date',
      ]) {
        expect(parseExpertReviewDate(date, now: now), isNull, reason: date);
      }
      expect(
        parseExpertReviewDate('2024-02-29', now: now),
        DateTime.utc(2024, 2, 29),
      );
      expect(
        parseExpertReviewDate('2026-09-07', now: now),
        DateTime.utc(2026, 9, 7),
      );
    },
  );

  for (final operation in ['delete recipe', 'reset', 'replace backup']) {
    test(
      'pending note deletion cannot resurrect data after $operation',
      () async {
        final store = PausedAssessmentStore();
        final state = await stateForAssessments(store);
        final emptyBackup = state.buildBackup();
        final r = recipe();
        await state.savePersonalRecipe(r);
        final first = assessment(r);
        await state.saveExpertAssessment(first);
        await state.saveExpertAssessment(assessment(r, text: 'Second note'));
        final release = Completer<void>();
        store.release = release;
        final deletingNote = state.deleteExpertAssessment(first.id);
        await store.entered.future;
        var completed = false;
        final subsequent = (switch (operation) {
          'delete recipe' => state.deletePersonalRecipe(r.id),
          'reset' => state.resetEverything(),
          _ => state.applyBackup(emptyBackup, merge: false),
        }).then((_) => completed = true);
        await Future<void>.delayed(Duration.zero);
        expect(
          completed,
          isFalse,
          reason: 'destructive mutation waits for the pending note write',
        );
        release.complete();
        await Future.wait([deletingNote, subsequent]);
        expect(state.expertAssessments, isEmpty);
        expect((await stateForAssessments(store)).expertAssessments, isEmpty);
        expect(state.personalRecipes, isEmpty);
      },
    );
  }

  test(
    'attributed notes roundtrip, bound input and do not accept fake verification metadata',
    () {
      final r = recipe();
      final entry = assessment(r);
      final raw = {...entry.toJson(), 'verified': true};
      final restored = ExpertAssessment.fromJson(raw);
      expect(restored.toJson(), entry.toJson());
      expect(restored.toJson().containsKey('verified'), isFalse);
      expect(() => assessment(r, text: 'x' * 4001), throwsFormatException);
      expect(expertAssessmentsFit([entry, entry]), isFalse);
      expect(
        expertAssessmentsFit(List.generate(501, (_) => assessment(r))),
        isFalse,
      );
      expect(
        expertAssessmentsFit(
          List.generate(300, (_) => assessment(r, text: 'x' * 4000)),
        ),
        isFalse,
      );
    },
  );

  test(
    'notes persist privately and full backup merges without duplicate or lost notes',
    () async {
      final store = MemoryStore();
      final state = await stateForAssessments(store);
      final r = recipe();
      await state.savePersonalRecipe(r);
      final first = assessment(r);
      final second = assessment(r, text: 'A second assessment.');
      await Future.wait([
        state.saveExpertAssessment(first),
        state.saveExpertAssessment(second),
      ]);
      final reopened = await stateForAssessments(store);
      expect(reopened.expertAssessments.length, 2);
      final shared = await collectRecipeShare(state, recipeId: r.id);
      final sharedText = utf8.decode(encodeRecipeShare(shared));
      expect(sharedText, isNot(contains('expert_assessments')));
      expect(sharedText, isNot(contains('Test reviewer')));
      final data = BackupService.import(
        BackupService.export(state.buildBackup()).jsonFile,
      );
      expect(
        data.expertAssessments.map((e) => e.toJson()),
        state.expertAssessments.map((e) => e.toJson()),
      );
      final destination = await stateForAssessments();
      await destination.applyBackup(data, merge: false);
      await destination.applyBackup(data, merge: true);
      expect(destination.expertAssessments.length, 2);
      expect(
        destination.personalRecipes.single.asRecipe().hasNutrition,
        isFalse,
      );
      await destination.deletePersonalRecipe(r.id);
      expect(destination.expertAssessments, isEmpty);
      await state.resetEverything();
      expect(state.expertAssessments, isEmpty);
    },
  );

  test('old backups remain compatible and replace removes notes', () async {
    final state = await stateForAssessments();
    final old = state.buildBackup();
    expect(
      BackupData.fromJson(old.toJson(DateTime.utc(2026))).expertAssessments,
      isEmpty,
    );
    final r = recipe();
    await state.savePersonalRecipe(r);
    await state.saveExpertAssessment(assessment(r));
    await state.applyBackup(old, merge: false);
    expect(state.expertAssessments, isEmpty);
  });

  test(
    'write failure rolls back storage and memory, later retry succeeds',
    () async {
      final store = FailingAssessmentStore();
      final state = await stateForAssessments(store);
      final r = recipe();
      await state.savePersonalRecipe(r);
      final entry = assessment(r);
      store.fail = true;
      await expectLater(
        state.saveExpertAssessment(entry),
        throwsA(isA<FileSystemException>()),
      );
      expect(state.expertAssessments, isEmpty);
      expect((await stateForAssessments(store)).expertAssessments, isEmpty);
      await state.saveExpertAssessment(entry);
      store.fail = true;
      await expectLater(
        state.deleteExpertAssessment(entry.id),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        (await stateForAssessments(store)).expertAssessments.single.id,
        entry.id,
      );
      await state.deleteExpertAssessment(entry.id);
      expect(state.expertAssessments, isEmpty);
    },
  );

  test(
    'recipe edits mark old assessments stale and reject a stale form save',
    () async {
      final state = await stateForAssessments();
      final r = recipe();
      await state.savePersonalRecipe(r);
      final entry = assessment(r);
      await state.saveExpertAssessment(entry);
      final changed = r.copyWith(servings: 4);
      await state.savePersonalRecipe(changed);
      expect(
        expertRecipeFingerprint(changed.asRecipe()),
        isNot(entry.recipeFingerprint),
      );
      expect(state.expertAssessments.single.id, entry.id);
      await expectLater(
        state.saveExpertAssessment(assessment(r)),
        throwsFormatException,
      );
      final invalidReference = state.buildBackup().toJson(DateTime.utc(2026));
      invalidReference['personal_recipes'] = [];
      await expectLater(
        state.applyBackup(BackupData.fromJson(invalidReference), merge: false),
        throwsA(isA<Exception>()),
      );
    },
  );

  test(
    'conflicting assessment ids in backup merge are rejected before overwriting',
    () async {
      final state = await stateForAssessments();
      final r = recipe();
      await state.savePersonalRecipe(r);
      final entry = assessment(r);
      await state.saveExpertAssessment(entry);
      final raw = state.buildBackup().toJson(DateTime.utc(2026));
      raw['expert_assessments'] = [
        assessment(r, id: entry.id, text: 'Different record').toJson(),
      ];
      await expectLater(
        state.applyBackup(BackupData.fromJson(raw), merge: true),
        throwsA(isA<Exception>()),
      );
      expect(state.expertAssessments.single.assessment, entry.assessment);
    },
  );
}
