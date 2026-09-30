import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/models/history_entry.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/domain/backup/backup_codec.dart';
import 'package:morphcook/features/backup/backup_screen.dart';
import 'package:morphcook/features/faq/faq_screen.dart';
import 'package:morphcook/platform/platform_services.dart';
import 'package:morphcook/state/app_services.dart';

import '../support/test_app.dart';

void main() {
  final now = DateTime(2026, 9, 28, 18);

  late FakeBackupFileGateway gateway;

  Future<AppServices> open(WidgetTester tester, {bool filled = true}) async {
    usePhone(tester);
    await loadBundledFonts(tester);
    gateway = FakeBackupFileGateway();
    final services = await buildServices(
      tester,
      profile: const Profile(name: 'Sam', lang: 'en', avoidFlags: {'dairy'}),
      now: now,
      platform: PlatformServices(
        files: gateway,
        alerts: FakeTimerAlerts(),
        awake: FakeScreenAwake(),
        haptics: FakeHaptics(),
      ),
    );
    if (filled) {
      await services.cookbook.save('doener-vegan', at: DateTime(2026, 9, 1));
      await services.cookbook.save('pancakes-vegan', at: DateTime(2026, 9, 2));
      await services.history.add(HistoryEntry(recipeId: 'chili-vegan', cookedAt: DateTime(2026, 9, 10), servings: 4));
    }
    await pumpApp(tester, services, home: const BackupScreen());
    await settle(tester, frames: 12);
    return services;
  }

  /// A second, empty install that a backup is restored into.
  Future<AppServices> emptyInstall(WidgetTester tester) async {
    final services = await buildServices(
      tester,
      onboarded: false,
      now: now,
      platform: PlatformServices(
        files: gateway,
        alerts: FakeTimerAlerts(),
        awake: FakeScreenAwake(),
        haptics: FakeHaptics(),
      ),
    );
    await pumpApp(tester, services, home: const BackupScreen());
    await settle(tester, frames: 12);
    return services;
  }

  Future<void> realTime(WidgetTester tester, {int rounds = 30}) => settleAsync(tester, rounds: rounds);

  Future<Uint8List> exportedJson(WidgetTester tester, AppServices services, {String? password}) async {
    final bundle = await tester.runAsync(() => services.backup.export(password: password));
    return bundle!.json;
  }

  group('export', () {
    testWidgets('writes both files and hands them to the OS share sheet', (tester) async {
      await open(tester);
      await tester.tap(find.text('EXPORT BACKUP'));
      await realTime(tester, rounds: 10);
      expect(gateway.shared, hasLength(1));
      final files = gateway.shared.single;
      expect(files.map((f) => f.name), ['morphcook-backup.json', 'morphcook-backup.json.gz']);
      expect(files[0].mimeType, 'application/json');
      final json = jsonDecode(utf8.decode(files[0].bytes)) as Map<String, dynamic>;
      expect(json['schema_version'], 1);
      expect(json['saved'], ['doener-vegan', 'pancakes-vegan']);
      expect(files[1].bytes.take(2), [0x1f, 0x8b]);
      expect(gzip.decode(files[1].bytes), files[0].bytes, reason: 'the GZip file holds the same JSON');
      expect(find.textContaining('shared: json'), findsOneWidget);
      expect(find.textContaining('smaller'), findsOneWidget);
    });

    testWidgets('a password encrypts the JSON and leaves the GZip readable', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField).first, 'open sesame');
      await tester.pump();
      expect(find.text('you will need this password to restore the .json file.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'open sesame');
      await tester.tap(find.text('EXPORT BACKUP'));
      await realTime(tester, rounds: 40);
      expect(gateway.shared, hasLength(1));
      final files = gateway.shared.single;
      expect(BackupCodec.isEncrypted(files[0].bytes), isTrue);
      expect(files[0].bytes.take(3), [0x45, 0x4E, 0x43]);
      expect(files[0].mimeType, 'application/octet-stream');
      expect(BackupCodec.isGzip(files[1].bytes), isTrue);
      expect(
        utf8.decode(gzip.decode(files[1].bytes)),
        contains('doener-vegan'),
        reason: 'the GZip file is never encrypted',
      );
    });

    testWidgets('a mismatch between the two passwords stops the export', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField).first, 'one');
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, 'two');
      await tester.tap(find.text('EXPORT BACKUP'));
      await settle(tester);
      expect(find.text('the passwords do not match.'), findsOneWidget);
      expect(gateway.shared, isEmpty);
    });

    testWidgets('the password can be shown and hidden', (tester) async {
      await open(tester);
      expect(tester.widget<EditableText>(find.byType(EditableText).first).obscureText, isTrue);
      await tester.tap(find.byTooltip('show password'));
      await tester.pump();
      expect(tester.widget<EditableText>(find.byType(EditableText).first).obscureText, isFalse);
      await tester.tap(find.byTooltip('hide password'));
      await tester.pump();
      expect(tester.widget<EditableText>(find.byType(EditableText).first).obscureText, isTrue);
    });

    testWidgets('help is one tap away', (tester) async {
      await open(tester);
      await tester.tap(find.text('how does backup work?'));
      await settle(tester, frames: 15);
      await pumpUntilFound(tester, find.byType(FaqScreen));
      await pumpUntilFound(tester, find.textContaining('creates two files'));
    });
  });

  group('import', () {
    testWidgets('a plain JSON backup is restored after choosing merge or replace', (tester) async {
      final source = await open(tester);
      final bytes = await exportedJson(tester, source);
      final target = await emptyInstall(tester);
      gateway.nextPick = bytes;
      await tester.tap(find.text('CHOOSE BACKUP FILE'));
      await realTime(tester, rounds: 6);
      await settle(tester);
      expect(find.text('restore this backup?'), findsOneWidget);
      expect(find.text('2 saved · 1 cooked · 0 planned'), findsOneWidget);
      await tester.tap(find.text('merge'));
      await realTime(tester, rounds: 10);
      expect(find.text('restored: 2 saved, 1 cooked, 0 planned'), findsOneWidget);
      expect(target.cookbook.saved.map((s) => s.recipeId), unorderedEquals(['doener-vegan', 'pancakes-vegan']));
      expect(target.history.count, 1);
      expect(target.profile.profile.name, 'Sam');
    });

    testWidgets('a GZip backup is detected without being told', (tester) async {
      final source = await open(tester);
      final bundle = await tester.runAsync(() => source.backup.export());
      final target = await emptyInstall(tester);
      gateway.nextPick = bundle!.gzip;
      await tester.tap(find.text('CHOOSE BACKUP FILE'));
      await realTime(tester, rounds: 6);
      await settle(tester);
      await tester.tap(find.text('replace'));
      await realTime(tester, rounds: 10);
      expect(find.textContaining('restored: 2 saved'), findsOneWidget);
      expect(target.cookbook.count, 2);
    });

    testWidgets('an encrypted backup asks for the password, and a wrong one can be corrected', (tester) async {
      final source = await open(tester);
      final bytes = await exportedJson(tester, source, password: 'right one');
      final target = await emptyInstall(tester);
      gateway.nextPick = bytes;
      await tester.tap(find.text('CHOOSE BACKUP FILE'));
      await realTime(tester, rounds: 6);
      await settle(tester);
      expect(find.text('password needed'), findsOneWidget);
      expect(find.text('this backup is encrypted.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'wrong one');
      await tester.tap(find.text('unlock'));
      await realTime(tester, rounds: 40);
      await settle(tester);
      expect(find.text('Incorrect password. Please try again.'), findsOneWidget);
      expect(find.text('password needed'), findsOneWidget, reason: 'the dialog stays open for another try');

      await tester.enterText(find.byType(TextField).last, 'right one');
      await tester.tap(find.text('unlock'));
      await realTime(tester, rounds: 40);
      await settle(tester);
      expect(find.text('restore this backup?'), findsOneWidget);
      await tester.tap(find.text('merge'));
      await realTime(tester, rounds: 10);
      expect(target.cookbook.count, 2);
    });

    testWidgets('giving up at the password prompt restores nothing and shows no error', (tester) async {
      final source = await open(tester);
      final bytes = await exportedJson(tester, source, password: 'secret');
      final target = await emptyInstall(tester);
      gateway.nextPick = bytes;
      await tester.tap(find.text('CHOOSE BACKUP FILE'));
      await realTime(tester, rounds: 6);
      await settle(tester);
      await tester.tap(find.text('cancel'));
      await settle(tester);
      expect(target.cookbook.count, 0);
      expect(find.text('Incorrect password. Please try again.'), findsNothing);
      expect(find.text('This file is not a valid MorphCook backup.'), findsNothing);
    });

    testWidgets('cancelling at the merge or replace question restores nothing', (tester) async {
      final source = await open(tester);
      final bytes = await exportedJson(tester, source);
      final target = await emptyInstall(tester);
      gateway.nextPick = bytes;
      await tester.tap(find.text('CHOOSE BACKUP FILE'));
      await realTime(tester, rounds: 6);
      await settle(tester);
      await tester.tap(find.text('cancel'));
      await settle(tester);
      expect(target.cookbook.count, 0);
    });

    testWidgets('closing the file picker does nothing', (tester) async {
      await open(tester);
      gateway.nextPick = null;
      await tester.tap(find.text('CHOOSE BACKUP FILE'));
      await realTime(tester, rounds: 4);
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('a file that is not a backup says so', (tester) async {
      await open(tester);
      gateway.nextPick = Uint8List.fromList(utf8.encode('this is not a backup'));
      await tester.tap(find.text('CHOOSE BACKUP FILE'));
      await realTime(tester, rounds: 6);
      await settle(tester);
      expect(find.text('This file is not a valid MorphCook backup.'), findsOneWidget);
    });

    testWidgets('a damaged file says it is corrupted', (tester) async {
      final source = await open(tester);
      final bundle = await tester.runAsync(() => source.backup.export());
      final broken = Uint8List.fromList([...bundle!.gzip.take(12), ...List<int>.filled(30, 7)]);
      gateway.nextPick = broken;
      await tester.tap(find.text('CHOOSE BACKUP FILE'));
      await realTime(tester, rounds: 6);
      await settle(tester);
      expect(find.text('Backup file is corrupted and cannot be restored.'), findsOneWidget);
    });

    testWidgets('a backup from a newer version asks to update', (tester) async {
      await open(tester);
      gateway.nextPick = Uint8List.fromList(utf8.encode('{"schema_version": 9, "profile": {}}'));
      await tester.tap(find.text('CHOOSE BACKUP FILE'));
      await realTime(tester, rounds: 6);
      await settle(tester);
      expect(
        find.text('This backup was created by a newer version of MorphCook. Please update the app.'),
        findsOneWidget,
      );
    });

    testWidgets('German error messages and copy', (tester) async {
      usePhone(tester);
      await loadBundledFonts(tester);
      gateway = FakeBackupFileGateway();
      final services = await buildServices(
        tester,
        profile: const Profile(lang: 'de'),
        now: now,
        platform: PlatformServices(
          files: gateway,
          alerts: FakeTimerAlerts(),
          awake: FakeScreenAwake(),
          haptics: FakeHaptics(),
        ),
      );
      await pumpApp(tester, services, home: const BackupScreen());
      await settle(tester, frames: 12);
      expect(find.text('sicherung & wiederherstellung'), findsOneWidget);
      gateway.nextPick = Uint8List.fromList(utf8.encode('nope'));
      await tester.ensureVisible(find.text('SICHERUNG AUSWÄHLEN'));
      await tester.pump();
      await tester.tap(find.text('SICHERUNG AUSWÄHLEN'));
      await realTime(tester, rounds: 6);
      await settle(tester);
      expect(find.textContaining('keine gültige MorphCook-Sicherung'), findsOneWidget);
    });
  });
}
