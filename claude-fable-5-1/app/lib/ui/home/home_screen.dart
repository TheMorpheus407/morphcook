import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_controller.dart';
import '../../theme/palette.dart';
import '../../theme/paper.dart';
import '../../theme/typography.dart';
import '../../theme/widgets.dart';
import '../l10n.dart';
import '../navigation.dart';
import '../widgets/dish_card.dart';
import '../widgets/help_link.dart';
import '../widgets/meta.dart';

/// The front page: newspaper masthead, one featured dish, then sections.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final s = context.s;
    final feed = app.buildFeed();
    final now = app.now();
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Masthead(now: now)),
          if (feed.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                title: s('home.empty.title'),
                note: s('home.empty.note'),
                icon: Icons.menu_book_outlined,
                action: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PaperButton(label: s('common.settings'), kind: PaperButtonKind.secondary, onPressed: () => Routes.openSettings(context)),
                    const SizedBox(height: 8),
                    HelpLink(faqId: 'why-dish-missing', label: s('home.why'), align: TextAlign.center),
                  ],
                ),
              ),
            )
          else ...[
            if (feed.featured != null) SliverToBoxAdapter(child: _Featured(card: feed.featured!, moment: feed.moment)),
            for (final section in feed.sections)
              if (section.id == 'all')
                ..._wholeBook(context, section, feed)
              else
                SliverToBoxAdapter(child: _sectionRow(context, section)),
            SliverToBoxAdapter(child: _Colophon(hidden: feed.hiddenDishCount)),
          ],
        ],
      ),
    );
  }

  Widget _sectionRow(BuildContext context, FeedSection section) {
    final s = context.s;
    switch (section.id) {
      case 'now':
        final moment = section.arg ?? 'day';
        return DishRow(title: s('home.section.now.$moment'), kicker: s('home.section.now'), cards: section.cards);
      case 'quick':
        return DishRow(title: s('home.section.quick'), kicker: s('home.section.quick.kicker'), cards: section.cards);
      case 'saved':
        return DishRow(title: s('home.section.saved'), kicker: s('nav.cookbook'), cards: section.cards);
      case 'again':
        return DishRow(title: s('home.section.again'), kicker: s('home.section.again.kicker'), cards: section.cards);
      case 'cuisine':
        return DishRow(title: s('home.section.cuisine.${section.arg}'), kicker: section.arg ?? '', cards: section.cards);
    }
    return const SizedBox.shrink();
  }

  List<Widget> _wholeBook(BuildContext context, FeedSection section, FeedModel feed) {
    final s = context.s;
    return [
      SliverToBoxAdapter(
        child: SectionHeader(title: s('home.section.all'), kicker: s('home.section.all.kicker', {'n': '${feed.visibleDishCount}'})),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200, mainAxisExtent: 262),
          delegate: SliverChildBuilderDelegate(
            (context, i) => DishCardTile(dish: section.cards[i].dish, recipe: section.cards[i].recipe, width: double.infinity),
            childCount: section.cards.length,
          ),
        ),
      ),
    ];
  }
}

class _Masthead extends StatelessWidget {
  const _Masthead({required this.now});
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final name = context.select<AppController, String>((c) => c.profile.name);
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: MonoLabel(s('home.masthead.vol', {'n': '$dayOfYear'}))),
              IconButton(
                onPressed: () => Routes.openSettings(context),
                icon: const Icon(Icons.tune),
                tooltip: s('common.settings'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          Text(s('app.name'), style: AppText.display(size: 44)),
          const OrnamentRule(padding: EdgeInsets.fromLTRB(0, 6, 8, 8)),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: MetaLine([
              s.longDate(now),
              name.isEmpty ? s('home.masthead.kitchen') : s('home.masthead.for', {'name': name}),
            ], color: Palette.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _Featured extends StatelessWidget {
  const _Featured({required this.card, required this.moment});
  final DishCard card;
  final String moment;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final app = context.read<AppController>();
    final lang = context.lang;
    final meta = RecipeMeta(app, lang);
    final seed = card.dish.id.hashCode;
    final kicker = switch (moment) {
      'morning' => s('home.featured.morning'),
      'evening' => s('home.featured.evening'),
      _ => s('home.featured'),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
      child: InkWell(
        onTap: () => Routes.openDish(context, card.dish.id, recipeId: card.recipe.id),
        borderRadius: BorderRadius.circular(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MonoLabel('— $kicker —'),
            const SizedBox(height: 10),
            Polaroid(
              seed: seed,
              tape: true,
              caption: card.dish.caption.of(lang),
              child: StripedPlaceholder(color: Color(card.dish.stripeColor), seed: seed, aspectRatio: 16 / 10),
            ),
            const SizedBox(height: 16),
            Text(card.dish.name.of(lang).toLowerCase(), style: AppText.display(size: 32)),
            const SizedBox(height: 4),
            Text(card.recipe.title.of(lang), style: AppText.title(size: 17)),
            const SizedBox(height: 6),
            MetaLine(meta.tags(card.recipe), color: Palette.inkSoft),
            const SizedBox(height: 10),
            Text(card.dish.heroText.of(lang), style: AppText.bodyItalic(size: 15)),
            const SizedBox(height: 8),
            HandNote(card.recipe.marginNote.of(lang), color: Palette.terracotta, size: 21),
          ],
        ),
      ),
    );
  }
}

class _Colophon extends StatelessWidget {
  const _Colophon({required this.hidden});
  final int hidden;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DashedRule(),
          const SizedBox(height: 12),
          if (hidden > 0) ...[
            HandNote(s('home.hidden.note', {'n': '$hidden'}), size: 18, color: Palette.inkFaint),
            HelpLink(faqId: 'why-dish-missing', label: s('home.why')),
            const SizedBox(height: 10),
          ],
          MonoLabel(s('home.colophon'), color: Palette.inkFaint, size: 10),
        ],
      ),
    );
  }
}
