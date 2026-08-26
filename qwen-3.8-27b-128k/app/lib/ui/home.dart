/// Home: newspaper-style masthead, featured dish, the ranked shelf.
library;

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/theme.dart';
import 'dish_page.dart';
import 'morph.dart';
import 'settings.dart';
import 'widgets.dart';

const List<String> _enMonth =
    ['', 'jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
const List<String> _enWeekday =
    ['', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const List<String> _deMonth =
    ['', 'jan', 'feb', 'm\u00e4r', 'apr', 'mai', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'dez'];
const List<String> _deWeekday = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

String dateLine(MorphData m) {
  final d = DateTime.now();
  final wd = m.lang == 'de' ? _deWeekday[d.weekday - 1] : _enWeekday[d.weekday];
  final mo = m.lang == 'de' ? _deMonth[d.month] : _enMonth[d.month];
  return '${d.day.toString().padLeft(2, '0')} $mo \u00b7 $wd ${d.year}';
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final m = Morph.of(context);
    final dishes = m.visibleDishes();

    Widget settingsAction() => IconButton(
          icon: Icon(Icons.settings_outlined, color: Palette.ink),
          tooltip: m.t('nav.settings'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(m.t('home.masthead')),
        actions: [settingsAction()],
      ),
      body: dishes.isEmpty
          ? EmptyState(
              title: m.t('home.none'),
              sub: m.profile.name.isNotEmpty
                  ? '${m.profile.name} — ${m.t('ob.sub')}'
                  : m.t('ob.sub'),
              action: InkButton(
                label: m.t('set.onboard'),
                icon: Icons.tune,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen()),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(m.t('home.dateline'),
                        style: T.section.copyWith(letterSpacing: 2.4)),
                    Text(dateLine(m),
                        style: T.mono.copyWith(color: Palette.inkSoft)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  m.t('app.name'),
                  style: const TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontStyle: FontStyle.italic,
                      fontSize: 46,
                      color: Palette.ink,
                      height: 1),
                ),
                const SizedBox(height: 6),
                Text(
                  m.profile.name.isNotEmpty
                      ? '${m.profile.name} · ${m.t('ob.welcome')}'
                      : m.t('ob.welcome'),
                  style: T.hand.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 12),
                Container(height: 2.2, color: Palette.ink.withValues(alpha: 0.8)),
                const SizedBox(height: 3),
                Container(height: 1, color: Palette.ink.withValues(alpha: 0.8)),

                const SizedBox(height: 20),
                _featured(context, m, dishes.first),

                const SizedBox(height: 22),
                Text(m.t('home.grid'),
                    style: T.section.copyWith(letterSpacing: 2.4)),
                const SizedBox(height: 4),
                Text('${dishes.length} dishes',
                    style: T.mono.copyWith(color: Palette.inkFaint)),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: dishes.length,
                  itemBuilder: (context, i) {
                     final dish = dishes[i];
                     return _ShelfTile(
                       dishId: dish.id,
                       rotation: i.isEven ? 0.012 : -0.012,
                     );
                  },
                ),
              ],
            ),
    );
  }

  Widget _featured(BuildContext context, MorphData m, Dish dish) {
    final id = dish.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(m.t('home.featured'),
            style: T.section.copyWith(letterSpacing: 2.4)),
        const SizedBox(height: 6),
        _FeaturedTile(dishId: id),
      ],
    );
  }
}

class _FeaturedTile extends StatelessWidget {
  const _FeaturedTile({required this.dishId});
  final String dishId;

  @override
  Widget build(BuildContext context) {
    final m = Morph.of(context);
    final lang = m.lang;
    final dish = m.c.dish(dishId)!;
    final recipe = m.bestVariant(dish)!;
    return Polaroid(
      rotation: 0.008,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => DishScreen(dishId: dishId)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: StripedPlaceholder(
              color: stripeColor(dish.stripeColorHex),
              caption: dish.capCaption.s(lang),
              height: 190,
              radius: 8,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  dish.canonicalName.s(lang),
                  style: const TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontStyle: FontStyle.italic,
                      fontSize: 22,
                      color: Palette.ink),
                ),
              ),
              Icon(Icons.chevron_right, color: Palette.inkFaint),
            ],
          ),
          const SizedBox(height: 8),
          MetaRow(
            minutes: recipe.timeMinutes,
            kcal: recipe.caloriesPerServing,
            effortLabel: m.t('effort.${recipe.effort}'),
          ),
          const SizedBox(height: 2),
          Text(recipe.name.s(lang), style: T.mono),
        ],
      ),
    );
  }
}

class _ShelfTile extends StatelessWidget {
  const _ShelfTile({required this.dishId, this.rotation = 0.01});
  final String dishId;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    final m = Morph.of(context);
    final lang = m.lang;
    final dish = m.c.dish(dishId)!;
    final recipe = m.bestVariant(dish);
    if (recipe == null) {
      return const SizedBox.shrink();
    }
    return Polaroid(
      rotation: rotation,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => DishScreen(dishId: dishId)),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: StripedPlaceholder(
                color: stripeColor(dish.stripeColorHex),
                caption: dish.capCaption.s(lang),
                height: 110,
                radius: 7,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            dish.canonicalName.s(lang),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontStyle: FontStyle.italic,
                fontSize: 15,
                color: Palette.ink),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 12, color: Palette.inkFaint),
              const SizedBox(width: 3),
              Text('${recipe.timeMinutes} min',
                  style: T.mono.copyWith(fontSize: 11)),
              const Spacer(),
              if (m.store.isSaved(recipe.id))
                Icon(Icons.bookmark, size: 13, color: Palette.coral),
            ],
          ),
        ],
      ),
    );
  }
}
