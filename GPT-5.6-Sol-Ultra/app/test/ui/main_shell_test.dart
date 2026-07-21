import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:morphcook/data/bundled_recipe_repository.dart';
import 'package:morphcook/domain/models/user_profile.dart';
import 'package:morphcook/l10n/app_strings.dart';
import 'package:morphcook/services/app_state.dart';
import 'package:morphcook/services/backup_file_facade.dart';
import 'package:morphcook/services/backup_repository.dart';
import 'package:morphcook/services/backup_service.dart';
import 'package:morphcook/services/local_store.dart';
import 'package:morphcook/services/profile_store.dart';
import 'package:morphcook/ui/screens/main_shell.dart';
import 'package:morphcook/ui/theme/morph_theme.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets(
    'main shell renders the personalized offline home without errors',
    (tester) async {
      final state = await _pumpShell(tester);
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('MorphCook'), findsOneWidget);
      expect(find.textContaining('MARA'), findsWidgets);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);

      state.dispose();
    },
  );

  testWidgets('all main tabs support 200% text without layout errors', (
    tester,
  ) async {
    final state = await _pumpShell(tester, textScale: 2);
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);

    for (var index = 1; index < 5; index++) {
      await tester.tap(find.byType(NavigationDestination).at(index));
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull, reason: 'main tab $index');
    }
    state.dispose();
  });
}

Future<AppState> _pumpShell(WidgetTester tester, {double textScale = 1}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final profile = UserProfile(
    name: 'Mara',
    languageCode: 'en',
    calorieTarget: 550,
    calorieTolerance: 250,
    maxTimeMinutes: 90,
  );
  final profiles = MemoryProfileStore(
    profile: profile,
    settings: const AppSettings(onboardingComplete: true),
  );
  final local = MemoryLocalApplicationStore();
  final state = AppState(profileStore: profiles, localStore: local);
  final corpus = BundledRecipeRepository(
    assetLoader: (path) => File(path).readAsString(),
  );
  await tester.runAsync(() async {
    await Future.wait([
      initializeDateFormatting('en'),
      initializeDateFormatting('de'),
      state.initialize(),
      corpus.initialize(loadExtended: true),
    ]);
  });
  final codec = BackupService();
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        theme: MorphTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: MorphStringsScope(
          languageCode: 'en',
          child: MainShell(
            repository: corpus,
            backupRepository: BackupRepository(
              profileStore: profiles,
              localStore: local,
              backupService: codec,
            ),
            backupService: codec,
            backupGateway: const _NoopBackupGateway(),
          ),
        ),
      ),
    ),
  );
  return state;
}

class _NoopBackupGateway implements BackupFileGateway {
  const _NoopBackupGateway();

  @override
  Future<PickedBackupFile?> pickBackup() async => null;

  @override
  Future<void> shareBackup(
    BackupExportBundle bundle, {
    Rect? sharePositionOrigin,
    String title = 'MorphCook backup',
    String? text,
  }) async {}
}
