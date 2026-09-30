import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/corpus_repository.dart';
import '../../i18n/dates.dart';
import '../../i18n/strings.dart';
import '../../logic/feed.dart';
import '../../state/library_store.dart';
import '../../state/profile_controller.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/paper.dart';
import '../widgets/recipe_card.dart';
import '../widgets/stripes.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // The feed is time-aware; refresh it on the hour so "right about now"
  // follows the clock without the reader doing anything.
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      final n = DateTime.now();
      if (n.hour != _now.hour) setState(() => _now = n);
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CorpusRepository>();
    final profileCtrl = context.watch<ProfileController>();
    final library = context.watch<LibraryStore>();
    final profile = profileCtrl.profile;
    final tr = context.tr;
    final lang = tr.lang;
    final feed = buildFeed(
      dishes: repo.dishes.values,
      variantsOf: repo.recipesForDish,
      recipeById: repo.recipe,
      profile: profile,
      ctx: profileCtrl.matchContext(repo),
      now: _now,
      lastCooked: library.lastCooked,
      savedNewestFirst: library.savedNewestFirst,
      calorieOverride: library.calorieOverride,
      lang: lang,
    );

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        key: const PageStorageKey('home'),
        slivers: [
          SliverToBoxAdapter(
            child: _Masthead(now: _now, name: profile.name),
          ),
          if (feed.isEmpty && !repo.allLoaded)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (feed.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                title: tr('home.empty.title'),
                body: tr('home.empty.body'),
                action: InkButton(label: tr('home.empty.cta'), onPressed: () => openSettings(context)),
              ),
            )
          else ...[
            if (feed.featured != null) SliverToBoxAdapter(child: _Featured(item: feed.featured!)),
            ..._section(context, tr('home.section.now'), feed.now),
            ..._section(context, tr('home.section.quick'), feed.quick),
            ..._section(context, tr('home.section.cookbook'), feed.fromCookbook),
            ..._section(context, tr('home.section.rediscover'), feed.rediscover),
            if (feed.byCuisine.length > 1) SliverToBoxAdapter(child: _CuisineStrip(feed: feed)),
            ..._section(context, tr('home.section.all'), feed.all, limit: 1000),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: Column(
                  children: [
                    const DashedRule(),
                    const SizedBox(height: 10),
                    TextLink(tr('home.why'), onTap: () => openFaq(context, entryId: 'how-matching-works')),
                    const SizedBox(height: 4),
                    Text('— fin —', style: MT.mono(10, color: MC.inkFaint)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _section(BuildContext context, String title, List<FeedItem> items, {int limit = 4}) {
    if (items.isEmpty) return const [];
    final shown = items.take(limit).toList();
    return [
      SliverToBoxAdapter(child: SectionHeader(title)),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 22,
            crossAxisSpacing: 18,
            childAspectRatio: 0.64,
          ),
          delegate: SliverChildBuilderDelegate((context, i) {
            final item = shown[i];
            return RecipePolaroid(
              dish: item.dish,
              recipe: item.recipe,
              onTap: () => openDish(context, item.dish.id, recipeId: item.recipe.id),
            );
          }, childCount: shown.length),
        ),
      ),
    ];
  }
}

class _Masthead extends StatelessWidget {
  const _Masthead({required this.now, required this.name});
  final DateTime now;
  final String name;

  String _weatherKey(int month) => switch (month) {
    12 || 1 || 2 => 'home.weather.winter',
    3 || 4 || 5 => 'home.weather.spring',
    6 || 7 || 8 => 'home.weather.summer',
    _ => 'home.weather.autumn',
  };

  String _part(int h) => h >= 5 && h < 12
      ? 'morning'
      : h >= 12 && h < 17
      ? 'afternoon'
      : h >= 17 && h < 22
      ? 'evening'
      : 'night';

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final lang = tr.lang;
    final issue = now.difference(DateTime(now.year)).inDays + 1;
    final part = tr('home.part.${_part(now.hour)}');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MonoLabel('${tr('home.vol')} · ${tr('home.no', {'n': issue})}', size: 10),
              const Spacer(),
              IconButton(
                key: const Key('open-settings'),
                tooltip: tr('settings.title'),
                visualDensity: VisualDensity.compact,
                onPressed: () => openSettings(context),
                icon: const Icon(Icons.tune, size: 20, color: MC.inkSoft),
              ),
            ],
          ),
          const DoubleRule(),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'the ',
                    style: MT.display(26, color: MC.inkSoft),
                  ),
                  TextSpan(
                    text: 'MorphCook',
                    style: MT.display(54, weight: FontWeight.w700),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Center(child: Text(tr('app.tagline'), style: MT.mono(10.5, spacing: 2.2))),
          const SizedBox(height: 8),
          const DoubleRule(),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: MonoLabel(longDate(now, lang), size: 10)),
              if (name.isNotEmpty) MonoLabel(tr('home.printedfor', {'name': name.toLowerCase()}), size: 10),
            ],
          ),
          const SizedBox(height: 4),
          MonoLabel(tr(_weatherKey(now.month)), size: 10, color: MC.inkFaint),
          const SizedBox(height: 18),
          HandNote(
            name.isEmpty ? tr('home.greeting.anon', {'part': part}) : tr('home.greeting', {'part': part, 'name': name}),
            size: 28,
          ),
        ],
      ),
    );
  }
}

class _Featured extends StatelessWidget {
  const _Featured({required this.item});
  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final lang = tr.lang;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoLabel(tr('home.featured'), color: MC.coralDeep, weight: FontWeight.w700),
          const SizedBox(height: 12),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Polaroid(
                tilt: -0.012,
                aspectRatio: 4 / 3,
                onTap: () => openDish(context, item.dish.id, recipeId: item.recipe.id),
                semanticLabel: item.recipe.title.of(lang),
                image: StripedPlaceholder(
                  color: item.dish.stripeColor,
                  caption: item.dish.caption.of(lang),
                  stripeWidth: 11,
                ),
                caption: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.recipe.title.of(lang).toLowerCase(), style: MT.display(30)),
                      const SizedBox(height: 4),
                      Text(item.dish.hero.of(lang), style: MT.hand(21)),
                      const SizedBox(height: 8),
                      Text(
                        item.recipe.blurb.of(lang),
                        style: MT.serif(14.5, color: MC.inkSoft),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: Text(recipeMeta(context, item.recipe), style: MT.mono(10.5))),
                          DietTag(item.recipe),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Positioned(top: -8, left: 0, right: 0, child: Center(child: Tape())),
            ],
          ),
        ],
      ),
    );
  }
}

/// "near & far": one small stamp per cuisine, tap to open its top dish.
class _CuisineStrip extends StatelessWidget {
  const _CuisineStrip({required this.feed});
  final Feed feed;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final onto = context.read<CorpusRepository>().ontology;
    final lang = tr.lang;
    final entries = feed.byCuisine.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(tr('home.section.world')),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final e = entries[i];
              final top = e.value.first;
              return SizedBox(
                width: 118,
                child: Polaroid(
                  tilt: tiltFor(e.key, maxDegrees: 3),
                  aspectRatio: 1.35,
                  onTap: () => openDish(context, top.dish.id, recipeId: top.recipe.id),
                  image: StripedPlaceholder(color: top.dish.stripeColor, showCaption: false, stripeWidth: 6),
                  caption: Text(onto.label('cuisine', e.key, lang), style: MT.hand(19, color: MC.ink), maxLines: 1),
                  footer: Text(
                    '${e.value.length} · ${top.dish.name.of(lang).toLowerCase()}',
                    style: MT.mono(9),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
