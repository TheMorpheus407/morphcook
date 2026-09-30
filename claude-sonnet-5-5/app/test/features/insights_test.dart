import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/features/insights/insights_screen.dart';
import 'package:morphcook/state/app_services.dart';

import '../support/test_app.dart';

void main() {
  Future<AppServices> open(
    WidgetTester tester, {
    Profile profile = const Profile(name: 'Sam'),
    Future<void> Function(AppServices s)? prepare,
  }) async {
    usePhone(tester, size: const Size(390, 1400));
    await loadBundledFonts(tester);
    final services = await buildServices(tester, profile: profile, now: DateTime(2026, 9, 28, 18));
    if (prepare != null) await prepare(services);
    await pumpApp(tester, services, home: const InsightsScreen());
    await settle(tester, frames: 12);
    return services;
  }

  Future<void> shop(WidgetTester tester, AppServices s, String recipeId, DateTime at, {int times = 1}) async {
    final recipe = await tester.runAsync(() => s.corpus.loadRecipe(recipeId));
    for (var i = 0; i < times; i++) {
      await s.shopping.addRecipe(recipe!, at: at.add(Duration(minutes: i)));
    }
  }

  group('shopping insights', () {
    testWidgets('an empty log invites to start', (tester) async {
      await open(tester);
      expect(find.text('insights'), findsOneWidget);
      expect(find.text('nothing to read yet.'), findsOneWidget);
      expect(find.text('VARIETY SCORE'), findsNothing);
    });

    testWidgets('variety score is the number of unique ingredients, with a level word', (tester) async {
      final services = await open(tester, prepare: (s) async {});
      await shop(tester, services, 'chili-vegan', DateTime(2026, 9, 1));
      await pumpApp(tester, services, home: const InsightsScreen());
      await settle(tester, frames: 12);
      final unique = services.shopping.insights.varietyScore;
      expect(find.text('VARIETY SCORE'), findsOneWidget);
      expect(
        find.text('$unique'),
        findsWidgets,
        reason: 'the big score, and the month count when every addition fell in one month',
      );
      expect(
        find.text(unique < 10 ? 'just getting started' : (unique < 25 ? 'growing nicely' : 'wonderfully varied')),
        findsOneWidget,
      );
      expect(
        find.textContaining('unique ingredients across ${services.shopping.insights.totalAdds} additions'),
        findsOneWidget,
      );
    });

    testWidgets('top added ingredients show frequency counts, most first', (tester) async {
      final services = await open(tester);
      for (var i = 0; i < 3; i++) {
        await shop(tester, services, 'doener-vegan', DateTime(2026, 6, 1 + i));
      }
      await shop(tester, services, 'chili-vegan', DateTime(2026, 7, 1));
      await pumpApp(tester, services, home: const InsightsScreen());
      await settle(tester, frames: 12);
      expect(find.text('most added'), findsOneWidget);
      expect(find.text('your pantry favorites.'), findsOneWidget);
      // garlic: 4 cloves lines per doener add (two lines) x3 + 1 chili line = 7 additions
      final counts = services.shopping.insights.topIngredients;
      expect(counts.length, lessThanOrEqualTo(10));
      expect(counts.first.count, greaterThanOrEqualTo(counts.last.count));
      expect(find.text('×${counts.first.count}'), findsWidgets);
    });

    testWidgets('the seasonal breakdown groups by month across the year', (tester) async {
      final services = await open(tester);
      await shop(tester, services, 'pancakes-vegan', DateTime(2026, 3, 5));
      await shop(tester, services, 'chili-vegan', DateTime(2026, 10, 12));
      await pumpApp(tester, services, home: const InsightsScreen());
      await settle(tester, frames: 12);
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pump();
      expect(find.text('through the year'), findsOneWidget);
      for (final month in ['JAN', 'MAR', 'JUN', 'OCT', 'DEC']) {
        expect(find.text(month), findsOneWidget, reason: month);
      }
      final march = services.shopping.insights.months[2].count;
      final october = services.shopping.insights.months[9].count;
      expect(find.text('$march'), findsWidgets);
      expect(find.text('$october'), findsWidgets);
      expect(find.textContaining('×'), findsWidgets, reason: 'top ingredients per month');
    });

    testWidgets('it updates when the list changes', (tester) async {
      final services = await open(tester);
      expect(find.text('nothing to read yet.'), findsOneWidget);
      await shop(tester, services, 'pancakes-vegan', DateTime(2026, 4, 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('nothing to read yet.'), findsNothing);
      expect(find.text('VARIETY SCORE'), findsOneWidget);
    });

    testWidgets('German copy', (tester) async {
      final services = await open(tester, profile: const Profile(lang: 'de'));
      await shop(tester, services, 'pancakes-vegan', DateTime(2026, 4, 1));
      await pumpApp(tester, services, home: const InsightsScreen());
      await settle(tester, frames: 12);
      expect(find.text('einblicke'), findsOneWidget);
      expect(find.text('am häufigsten'), findsOneWidget);
      expect(find.text('VIELFALTSWERT'), findsOneWidget);
    });
  });
}
