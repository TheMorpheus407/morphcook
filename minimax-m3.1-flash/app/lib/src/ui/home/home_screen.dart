import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/rules.dart';
import '../../domain/ranking.dart';
import '../../l10n/strings.dart';
import '../../models/dish.dart';
import '../../models/recipe.dart';
import '../../state/app_state.dart';
import '../dish/dish_detail_screen.dart';
import '../settings/settings_screen.dart';
import '../widgets/recipe_card.dart';

/// The home feed — a newspaper front page for the cook's own cookbook.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().corpus.loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.profile.profile;
    final strings = state.strings;
    final corpus = state.corpus;

    final visible = corpus.allRecipes
        .where((recipe) => state.matcher.isVisible(recipe, profile))
        .toList();

    final lastCooked = state.history.lastCookedAt;
    final now = DateTime.now();

    final ranked = Ranking.sort(
      visible,
      now: now,
      lastCookedAt: lastCooked,
    );

    final featured = ranked.isEmpty ? null : ranked.first;
    final quick = ranked
        .where((recipe) => recipe.effort == 'easy')
        .take(6)
        .toList();
    final weekend = ranked
        .where((recipe) => recipe.effort == 'medium' || recipe.effort == 'hard')
        .take(6)
        .toList();
    final forgotten = ranked
        .where((recipe) {
          final last = lastCooked[recipe.id];
          return last != null && now.difference(last).inDays >= 30;
        })
        .take(6)
        .toList();

    final savedRecipes = state.cookbook.resolve(corpus.allRecipes);

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: _Masthead(
            name: profile.name,
            strings: strings,
            onSettings: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ),
        if (featured == null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'no recipes fit your profile yet',
                style: Type.script(size: 18),
              ),
            ),
          )
        else ...<Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: SectionHeading(title: strings.homeFeatured),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: _FeaturedCard(
                recipe: featured,
                dish: corpus.dish(featured.dishId),
                strings: strings,
                onTap: () => _openDish(context, featured.dishId),
              ),
            ),
          ),
          if (quick.isNotEmpty)
            SliverToBoxAdapter(
              child: FeedSection(
                title: strings.homeQuick,
                child: _RecipeStrip(recipes: quick, strings: strings),
              ),
            ),
          if (weekend.isNotEmpty)
            SliverToBoxAdapter(
              child: FeedSection(
                title: strings.homeWeekend,
                child: _RecipeStrip(recipes: weekend, strings: strings),
              ),
            ),
          if (forgotten.isNotEmpty)
            SliverToBoxAdapter(
              child: FeedSection(
                title: strings.homeFreshIdeas,
                child: _RecipeStrip(recipes: forgotten, strings: strings),
              ),
            ),
          if (savedRecipes.isNotEmpty)
            SliverToBoxAdapter(
              child: FeedSection(
                title: strings.homeFromCookbook,
                child: _RecipeStrip(recipes: savedRecipes.take(6).toList(), strings: strings),
              ),
            ),
          SliverToBoxAdapter(
            child: FeedSection(
              title: strings.homeCuisines,
              child: _CuisineRow(strings: strings),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ],
    );
  }

  void _openDish(BuildContext context, String dishId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DishDetailScreen(dishId: dishId)),
    );
  }
}

/// The newspaper masthead.
class _Masthead extends StatelessWidget {
  const _Masthead({
    required this.name,
    required this.strings,
    required this.onSettings,
  });

  final String name;
  final Strings strings;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 14,
        14,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      strings.appName.toLowerCase(),
                      style: Type.display(size: 36),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      strings.tagline,
                      style: Type.scriptSmall(size: 15),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onSettings,
                icon: const Icon(Icons.tune_rounded),
                color: MC.inkSoft,
                tooltip: strings.settingsTitle,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const DashedRule(),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  strings.greeting(name),
                  style: Type.title(size: 19),
                ),
              ),
              Eyebrow(_dateLine(now)),
            ],
          ),
        ],
      ),
    );
  }

  String _dateLine(DateTime now) {
    const months = <String>[
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec',
    ];
    return '${now.day} ${months[now.month - 1]}';
  }
}

/// The large featured card.
class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.recipe,
    required this.dish,
    required this.strings,
    required this.onTap,
  });

  final Recipe recipe;
  final Dish? dish;
  final Strings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = parseStripeColor(dish?.stripeColor ?? recipe.stripeColor);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: MC.card,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: MC.ruleFaint),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x142C2823),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                child: AspectRatio(
                  aspectRatio: 1.5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      _Stripes(color: color),
                      Center(
                        child: Text(
                          dish?.name.resolve('en') ?? recipe.title.resolve('en'),
                          style: Type.scriptLarge(size: 30, color: MC.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(recipe.title.resolve('en'), style: Type.title(size: 22)),
                    const SizedBox(height: 6),
                    Text(
                      recipe.heroText.resolve('en'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Type.body(size: 14.5),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        _Fact(
                          icon: Icons.schedule_rounded,
                          text: '${recipe.timeMinutes} ${strings.dishMinutes}',
                        ),
                        const SizedBox(width: 14),
                        _Fact(
                          icon: Icons.local_fire_department_outlined,
                          text: '${recipe.calories} kcal',
                        ),
                        const SizedBox(width: 14),
                        _Fact(
                          icon: Icons.people_outline_rounded,
                          text: '${recipe.servings}',
                        ),
                        const Spacer(),
                        Icon(Icons.arrow_forward_rounded, size: 18, color: MC.coral),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stripes extends StatelessWidget {
  const _Stripes({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StripePainter(color));
  }
}

class _StripePainter extends CustomPainter {
  const _StripePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Color.lerp(MC.paper, color, 0.10)!;
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final stripe = Paint()..color = color.withValues(alpha: 0.7);
    const width = 8.0;
    const period = width * 2;
    final diagonal = (size.width * size.width + size.height * size.height);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.7853981634);
    final bands = (diagonal / period).ceil() + 2;
    for (var i = -bands; i <= bands; i++) {
      canvas.drawRect(
        Rect.fromLTWH(i * period, -diagonal, width, diagonal * 2),
        stripe,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StripePainter old) => old.color != color;
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 13, color: MC.inkFaint),
        const SizedBox(width: 4),
        Text(text, style: Type.label(size: 9.5)),
      ],
    );
  }
}

/// A horizontal strip of recipe cards.
class _RecipeStrip extends StatelessWidget {
  const _RecipeStrip({required this.recipes, required this.strings});

  final List<Recipe> recipes;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final corpus = context.read<AppState>().corpus;
    return SizedBox(
      height: 258,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: recipes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final recipe = recipes[index];
          return SizedBox(
            width: 172,
            child: RecipeCard(
              recipe: recipe,
              dish: corpus.dish(recipe.dishId),
              showTags: false,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DishDetailScreen(dishId: recipe.dishId),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Cuisine browsing, driven by the cuisine partitions.
class _CuisineRow extends StatelessWidget {
  const _CuisineRow({required this.strings});
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final corpus = state.corpus;
    final partitions = corpus.manifest.partitions.values
        .where((partition) => partition.type == 'index')
        .toList();

    if (partitions.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: partitions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final partition = partitions[index];
          final color = _palette[index % _palette.length];
          return Container(
            width: 168,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  partition.id.replaceAll('-', ' '),
                  style: Type.title(size: 17),
                ),
                Text(
                  '${partition.recipeIds.length} ${strings.cookbookCount}',
                  style: Type.label(size: 9.5),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static const List<Color> _palette = <Color>[
    MC.coral,
    MC.teal,
    MC.mustard,
    MC.plum,
    MC.inkBlue,
  ];
}
