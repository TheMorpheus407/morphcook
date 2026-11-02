import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/rules.dart';
import '../../design/widgets/states.dart';
import '../../domain/pagination_controller.dart';
import '../../l10n/strings.dart';
import '../../models/recipe.dart';
import '../../state/app_state.dart';
import '../../state/cookbook_controller.dart';
import '../dish/dish_detail_screen.dart';
import '../widgets/recipe_card.dart';

/// The cookbook — the recipes the user saved.
///
/// Offset-based pagination, sorted by saved date, 30 to a page.
class CookbookScreen extends StatefulWidget {
  const CookbookScreen({super.key});

  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen> {
  late final PaginationController<Recipe> _pagination;

  @override
  void initState() {
    super.initState();
    _pagination = PaginationController<Recipe>(
      type: PaginationType.offset,
      pageSize: 30,
      prefetchThreshold: 10,
      maxRendered: 50,
      fetchPage: (request) async {
        final state = context.read<AppState>();
        final saved = state.cookbook.resolve(state.corpus.allRecipes);
        final slice = saved
            .skip(request.offset)
            .take(request.limit)
            .toList(growable: false);
        return PageResult<Recipe>(
          items: slice,
          hasMore: request.offset + slice.length < saved.length,
        );
      },
    );
  }

  @override
  void dispose() {
    _pagination.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final cookbook = context.watch<CookbookController>();

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 18,
              20,
              6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(strings.cookbookTitle, style: Type.display(size: 30)),
                const SizedBox(height: 4),
                Text(
                  cookbook.length == 1
                      ? '1 ${strings.cookbookCount}'
                      : '${cookbook.length} ${strings.cookbookCount}',
                  style: Type.scriptSmall(size: 15),
                ),
                const SizedBox(height: 12),
                const DashedRule(),
              ],
            ),
          ),
        ),
        if (cookbook.length == 0)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              title: strings.cookbookEmptyTitle,
              message: strings.cookbookEmptyBody,
              glyph: '✎',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            sliver: SliverList.builder(
              itemCount: _pagination.items.length,
              itemBuilder: (context, index) {
                final recipe = _pagination.items[index];
                if (_pagination.shouldLoadMore(index)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _pagination.loadMore();
                  });
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _CookbookRow(
                    recipe: recipe,
                    strings: strings,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            DishDetailScreen(dishId: recipe.dishId),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        SliverToBoxAdapter(
          child: PageLoadingIndicator(
            visible: _pagination.isLoading && _pagination.items.isNotEmpty,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

/// A saved recipe, laid out as a horizontal entry.
class _CookbookRow extends StatelessWidget {
  const _CookbookRow({
    required this.recipe,
    required this.strings,
    required this.onTap,
  });

  final Recipe recipe;
  final Strings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final dish = state.corpus.dish(recipe.dishId);
    final color = parseStripeColor(dish?.stripeColor ?? recipe.stripeColor);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MC.card,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: MC.ruleFaint),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 74,
                height: 74,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: CustomPaint(
                    painter: _MiniStripePainter(color),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      recipe.title.resolve(strings.lang),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Type.title(size: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${recipe.timeMinutes} min · ${recipe.calories} kcal · '
                      '${strings.dietLabel(recipe.diet)}',
                      style: Type.label(size: 9.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => context.read<CookbookController>().remove(recipe.id),
                icon: const Icon(Icons.bookmark_rounded, size: 18),
                color: MC.coral,
                tooltip: strings.cookbookRemove,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStripePainter extends CustomPainter {
  const _MiniStripePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color.lerp(MC.paper, color, 0.12)!,
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final stripe = Paint()..color = color.withValues(alpha: 0.7);
    const width = 6.0;
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
  bool shouldRepaint(_MiniStripePainter old) => old.color != color;
}
