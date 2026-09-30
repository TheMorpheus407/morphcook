import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:morphcook/app/app.dart';
import 'package:morphcook/data/asset_source.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/platform/platform_services.dart';
import 'package:morphcook/state/app_services.dart';
import 'package:morphcook/state/catalog.dart';
import 'package:morphcook/state/storage/storage.dart';

/// Wires the real app services against the assets on disk and in-memory storage.
Future<AppServices> makeServices({
  Profile? profile,
  bool onboarded = true,
  DateTime? now,
  Clock? clock,
  AppStorage? storage,
  PlatformServices? platform,
}) async {
  final store = storage ?? AppStorage.memory();
  final services = await AppServices.create(
    assets: const FileAssetSource('assets'),
    storage: store,
    platform: platform ?? PlatformServices.fake(),
    clock: clock ?? (now == null ? null : () => now),
    autoTickTimers: false,
  );
  if (profile != null) await services.profile.setProfile(profile);
  if (onboarded) await services.profile.completeOnboarding(profile ?? services.profile.profile);
  return services;
}

/// [makeServices] inside the test's real-async zone (file and storage I/O).
Future<AppServices> buildServices(
  WidgetTester tester, {
  Profile? profile,
  bool onboarded = true,
  DateTime? now,
  Clock? clock,
  AppStorage? storage,
  PlatformServices? platform,
}) async {
  return (await tester.runAsync(
    () => makeServices(
      profile: profile,
      onboarded: onboarded,
      now: now,
      clock: clock,
      storage: storage,
      platform: platform,
    ),
  ))!;
}

/// Makes the fonts bundled under assets/google_fonts available to the test engine.
Future<void> loadBundledFonts(WidgetTester tester) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await tester.runAsync(() async {
    await GoogleFonts.pendingFonts([
      GoogleFonts.playfairDisplay(),
      GoogleFonts.playfairDisplay(fontStyle: FontStyle.italic),
      GoogleFonts.playfairDisplay(fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
      GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700),
      GoogleFonts.playfairDisplay(fontStyle: FontStyle.italic, fontWeight: FontWeight.w700),
      GoogleFonts.jetBrainsMono(),
      GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w500),
      GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700),
      GoogleFonts.caveat(),
      GoogleFonts.caveat(fontWeight: FontWeight.w700),
    ]);
  });
}

/// Loads the Material icon font so screenshots show real icons instead of boxes.
Future<void> loadMaterialIcons(WidgetTester tester) async {
  final roots = <String>[
    if (Platform.environment['FLUTTER_ROOT'] != null) Platform.environment['FLUTTER_ROOT']!,
    File(Platform.resolvedExecutable).parent.parent.path,
  ];
  for (final root in roots) {
    final file = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (!file.existsSync()) continue;
    await tester.runAsync(() async {
      final bytes = Uint8List.fromList(await file.readAsBytes());
      final loader = FontLoader('MaterialIcons')..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
      await loader.load();
    });
    return;
  }
}

/// A phone-sized surface.
void usePhone(WidgetTester tester, {Size size = const Size(390, 844), double ratio = 2}) {
  tester.view.physicalSize = Size(size.width * ratio, size.height * ratio);
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
}

Future<void> pumpApp(WidgetTester tester, AppServices services, {Widget? home}) async {
  await tester.pumpWidget(MorphCookApp(services: services, home: home));
  await tester.pump(const Duration(milliseconds: 50));
}

/// Settles animations that would otherwise repeat forever.
Future<void> settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Lets real async work (asset reads, storage) finish while frames keep
/// pumping. Returns as soon as [until] holds (when given).
Future<void> settleAsync(WidgetTester tester, {int rounds = 12, bool Function()? until}) async {
  for (var i = 0; i < rounds; i++) {
    if (until != null && until()) return;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps until [finder] matches something (real async included).
Future<void> pumpUntilFound(WidgetTester tester, Finder finder, {int rounds = 60}) async {
  await settleAsync(tester, rounds: rounds, until: () => finder.evaluate().isNotEmpty);
  expect(finder, findsWidgets, reason: 'expected ${finder.describeMatch(Plurality.many)} to appear');
}

Directory screenshotDir() => Directory('build/screenshots')..createSync(recursive: true);
