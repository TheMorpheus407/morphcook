import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/nav_requests.dart';
import '../../app/routes.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/labels.dart';
import '../../core/text_scale.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../data/corpus.dart';
import '../../data/models/ontology.dart';
import '../../data/models/profile.dart';
import '../../data/models/recipe.dart';
import '../../domain/plan/meal_plan.dart';
import '../../domain/search/search_service.dart';
import '../../state/catalog.dart';
import '../../state/controllers/cook_session_controller.dart';
import '../../state/controllers/history_controller.dart';
import '../../state/controllers/meal_plan_controller.dart';
import '../../state/controllers/profile_controller.dart';
import '../../widgets/layout.dart';
import '../../widgets/paper.dart';
import '../../widgets/paper_controls.dart';
import '../../widgets/polaroid_card.dart';
import '../../widgets/stripe_placeholder.dart';

/// Newspaper front page: masthead, the featured dish and grid sections.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenTab});

  final ValueChanged<int>? onOpenTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<FeedSection>>? _cuisines;
  Profile? _cuisineProfile;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final profileController = context.watch<ProfileController>();
    // Rebuild when the history changes: staleness and "back on the table" depend on it.
    context.watch<HistoryController>();
    context.watch<MealPlanController>();
    final catalog = context.read<Catalog>();
    final corpus = context.read<Corpus>();
    final profile = profileController.profile;
    final feed = catalog.buildFeed();
    final now = catalog.clock();

    if (_cuisines == null || _cuisineProfile != profile) {
      _cuisineProfile = profile;
      _cuisines = catalog.cuisineSections();
    }

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Masthead(now: now),
                  const SizedBox(height: 18),
                  _Greeting(dayPart: catalog.dayPart(now), name: profile.name),
                  const SizedBox(height: 10),
                  _EffortToday(profile: profile),
                  const _ResumeBanner(),
                  _TodayPlan(now: now),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
          if (feed.isEmpty)
            SliverToBoxAdapter(
              child: ContentWidth(child: _EmptyFeed(profile: profile)),
            )
          else ...[
            SliverToBoxAdapter(
              child: ContentWidth(child: _Featured(pick: feed.featured!)),
            ),
            for (final section in feed.sections) _sectionSliver(context, section),
            SliverToBoxAdapter(
              child: FutureBuilder<List<FeedSection>>(
                future: _cuisines,
                builder: (context, snapshot) {
                  final sections = snapshot.data ?? const <FeedSection>[];
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Column(
                      key: ValueKey(sections.length),
                      children: [
                        for (final section in sections)
                          _SectionBlock(section: section, onMore: () => _moreOfCuisine(context, section)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: ContentWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 36),
                child: Column(
                  children: [
                    const DoubleRule(),
                    const SizedBox(height: 14),
                    Text(
                      s('home.footer', {'n': corpus.dishes.length}),
                      textAlign: TextAlign.center,
                      style: AppText.hand(size: 21, color: Palette.inkSoft),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionSliver(BuildContext context, FeedSection section) {
    return SliverToBoxAdapter(
      child: _SectionBlock(
        section: section,
        onMore: section.id == 'back' ? () => context.read<NavRequests>().showTab(2) : null,
      ),
    );
  }

  void _moreOfCuisine(BuildContext context, FeedSection section) {
    final cuisine = section.cuisine;
    if (cuisine == null) return;
    context.read<NavRequests>().showSearch(filters: SearchFilters(cuisines: {cuisine}));
  }
}

class _Masthead extends StatelessWidget {
  const _Masthead({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final dayOfYear = now.difference(DateTime(now.year)).inDays + 1;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              PaperIconButton(icon: Icons.help_outline, tooltip: s('nav.help'), onPressed: () => openFaq(context)),
              PaperIconButton(
                icon: Icons.settings_outlined,
                tooltip: s('nav.settings'),
                onPressed: () => openSettings(context),
              ),
            ],
          ),
          const DoubleRule(),
          const SizedBox(height: 6),
          // The wordmark is a logo: it shrinks to the line at large text sizes and never breaks.
          Semantics(
            header: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('morphcook', style: AppText.display(size: 56)),
            ),
          ),
          HandNote(s('brand.tagline'), size: 24, angle: -0.012),
          const SizedBox(height: 8),
          const DashedRule(color: Palette.ink),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 4,
              spacing: 12,
              children: [
                Text(
                  s('home.edition', {
                    'vol': (now.year - 2025).toString().padLeft(2, '0'),
                    'no': dayOfYear,
                  }).toUpperCase(),
                  style: AppText.label(size: 10),
                ),
                Text(s.longDate(now).toUpperCase(), style: AppText.label(size: 10)),
              ],
            ),
          ),
          const DoubleRule(),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.dayPart, required this.name});

  final String dayPart;
  final String name;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final key = name.isEmpty ? 'home.greeting.$dayPart' : 'home.greetingName.$dayPart';
    return Semantics(header: true, child: Text(s(key, {'name': name}), style: AppText.display(size: 32)));
  }
}

class _EffortToday extends StatelessWidget {
  const _EffortToday({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final ontology = context.read<Corpus>().ontology;
    final label = Text(s('home.effortToday'), style: AppText.hand(size: 22, color: Palette.inkSoft));
    final chips = Wrap(
      spacing: 6,
      runSpacing: 0,
      children: [
        for (final id in const ['easy', 'medium', 'hard'])
          PaperChip(
            label: ontology.label(id, s.lang),
            dense: true,
            selected: profile.preferredEffort == id,
            onTap: () => context.read<ProfileController>().updateProfile((p) => p.copyWith(preferredEffort: id)),
          ),
      ],
    );
    // At large text the label goes above the chips, which then have the whole width.
    if (context.largeText) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [label, chips]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        label,
        const SizedBox(width: 10),
        Expanded(child: chips),
      ],
    );
  }
}

/// "Continue cooking" when a run was left in the middle.
class _ResumeBanner extends StatelessWidget {
  const _ResumeBanner();

  @override
  Widget build(BuildContext context) {
    final cook = context.watch<CookSessionController>();
    final stored = cook.storedSession;
    if (stored == null || cook.isActive) return const SizedBox.shrink();
    final s = context.s;
    final corpus = context.read<Corpus>();
    return FutureBuilder<Recipe?>(
      future: corpus.loadRecipe(stored.recipeId),
      builder: (context, snapshot) {
        final recipe = snapshot.data;
        if (recipe == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: InkWell(
            onTap: () => openCook(context, recipe.id, resume: true),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Palette.night,
                borderRadius: BorderRadius.circular(3),
                boxShadow: [BoxShadow(color: Palette.coral.withValues(alpha: 0.8), offset: const Offset(3, 3))],
              ),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_outline, color: Palette.nightInk, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s('home.resume.title'), style: AppText.label(size: 10, color: Palette.nightSoft)),
                        const SizedBox(height: 2),
                        Text(
                          recipe.title.resolve(s.lang),
                          style: AppText.serifItalic(size: 18, color: Palette.nightInk),
                        ),
                        Text(
                          s('home.resume.step', {'n': stored.stepIndex + 1, 'total': recipe.steps.length}),
                          style: AppText.mono(size: 11, color: Palette.nightSoft),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward, color: Palette.nightInk, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Today's planned meals, when there are any.
class _TodayPlan extends StatelessWidget {
  const _TodayPlan({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<MealPlanController>().plan;
    final week = WeekKey.fromDate(now);
    final day = planDays[now.weekday - 1];
    final planned = [
      for (final meal in planMeals)
        if (plan.recipeAt(week, slotKey(day, meal)) != null) (meal, plan.recipeAt(week, slotKey(day, meal))!),
    ];
    if (planned.isEmpty) return const SizedBox.shrink();
    final s = context.s;
    final corpus = context.read<Corpus>();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoLabel(s('home.todayPlan')),
          const SizedBox(height: 4),
          for (final (meal, recipeId) in planned)
            FutureBuilder<Recipe?>(
              future: corpus.loadRecipe(recipeId),
              builder: (context, snapshot) {
                final recipe = snapshot.data;
                if (recipe == null) return const SizedBox.shrink();
                return InkWell(
                  onTap: () => openDish(context, recipe.dishId, recipeId: recipe.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 84,
                          child: Text(
                            corpus.ontology.label(meal, s.lang),
                            style: AppText.hand(size: 21, color: Palette.coralDeep),
                          ),
                        ),
                        Expanded(child: Text(recipe.title.resolve(s.lang), style: AppText.serifItalic(size: 17))),
                        const Icon(Icons.chevron_right, size: 18, color: Palette.inkFaint),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          HandNote(s('home.empty.note'), size: 26, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(
            s('home.empty.body'),
            textAlign: TextAlign.center,
            style: AppText.serif(size: 16, color: Palette.inkSoft),
          ),
          const SizedBox(height: 18),
          PaperButton(label: s('home.empty.action'), icon: Icons.tune, onPressed: () => openSettings(context)),
          const SizedBox(height: 4),
          PaperButton(
            label: s('help.whyNothing'),
            style: PaperButtonStyle.quiet,
            onPressed: () => openFaq(context, entryId: 'recipe-visibility'),
          ),
        ],
      ),
    );
  }
}

/// The lead story.
class _Featured extends StatelessWidget {
  const _Featured({required this.pick});

  final DishPick pick;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final ontology = context.read<Corpus>().ontology;
    final showTags = context.select<ProfileController, bool>((p) => p.profile.showVariantTags);
    final recipe = pick.recipe;
    final stripe = Palette.fromHex(pick.dish.stripe);
    return Semantics(
      button: true,
      label: '${recipe.title.resolve(s.lang)}, ${s('home.featured')}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => openDish(context, pick.dish.id, recipeId: recipe.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Transform.rotate(
                  angle: polaroidAngle(pick.dish.id) * 0.6,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Palette.paperLight,
                      border: Border.all(color: Palette.paperEdge),
                      boxShadow: [
                        BoxShadow(
                          color: Palette.ink.withValues(alpha: 0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: StripePlaceholder(
                      color: stripe,
                      caption: pick.dish.cap.resolve(s.lang),
                      aspectRatio: 16 / 10,
                      stripeWidth: 14,
                      captionInset: 10,
                    ),
                  ),
                ),
                const Positioned(top: -6, left: 26, child: TapeStrip(angle: -0.18, width: 66)),
                const Positioned(top: -4, right: 30, child: TapeStrip(angle: 0.14, width: 66, color: Palette.sage)),
              ],
            ),
            const SizedBox(height: 16),
            MonoLabel(s('home.featured'), color: Palette.coralDeep),
            const SizedBox(height: 4),
            Semantics(header: true, child: Text(lower(recipe.title.resolve(s.lang)), style: AppText.display(size: 40))),
            const SizedBox(height: 6),
            Text(recipeMeta(s, ontology, recipe, showDiet: showTags).toUpperCase(), style: AppText.label(size: 10.5)),
            const SizedBox(height: 10),
            Text(
              pick.dish.hero.resolve(s.lang),
              style: AppText.serifItalic(size: 18, color: Palette.inkSoft, height: 1.4),
            ),
            const SizedBox(height: 4),
            Text(recipe.blurb.resolve(s.lang), style: AppText.serif(size: 15.5, height: 1.5)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: PaperButton(
                label: s('home.readRecipe'),
                style: PaperButtonStyle.quiet,
                icon: Icons.arrow_forward,
                onPressed: () => openDish(context, pick.dish.id, recipeId: recipe.id),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A titled two-column grid of polaroids.
class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.section, this.onMore});

  final FeedSection section;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final ontology = context.read<Corpus>().ontology;
    final showTags = context.select<ProfileController, bool>((p) => p.profile.showVariantTags);
    final title = section.id == 'cuisine'
        ? s('home.section.cuisine', {'cuisine': ontology.label(section.cuisine!, s.lang)})
        : s('home.section.${section.id}');
    final note = section.id == 'cuisine' ? null : s('home.section.${section.id}.note');
    final picks = section.picks;
    return ContentWidth(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              title,
              note: note,
              trailing: onMore == null
                  ? null
                  : PaperButton(label: s('common.more'), style: PaperButtonStyle.quiet, dense: true, onPressed: onMore),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < picks.length; i += 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _card(context, s, ontology, picks[i], showTags)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: i + 1 < picks.length
                          ? Padding(
                              padding: const EdgeInsets.only(top: 22),
                              child: _card(context, s, ontology, picks[i + 1], showTags),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, AppStrings s, Ontology ontology, DishPick pick, bool showTags) {
    return PolaroidCard(
      seed: pick.dish.id,
      title: pick.recipe.title.resolve(s.lang),
      subtitle: recipeMeta(s, ontology, pick.recipe, showDiet: showTags),
      caption: pick.dish.cap.resolve(s.lang),
      stripe: Palette.fromHex(pick.dish.stripe),
      onTap: () => openDish(context, pick.dish.id, recipeId: pick.recipe.id),
    );
  }
}
