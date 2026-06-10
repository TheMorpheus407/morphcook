import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/cookbook_store.dart';
import '../data/corpus.dart';
import '../l10n/strings.dart';
import '../pagination/pagination_controller.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../widgets/masthead.dart';
import '../widgets/paper_background.dart';
import '../widgets/polaroid_card.dart';
import '../widgets/striped_placeholder.dart';
import 'dish_detail_screen.dart';

class CookbookScreen extends StatefulWidget {
  const CookbookScreen({super.key});

  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen> {
  late PaginationController<Recipe> _ctrl;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _ctrl = PaginationController<Recipe>(
      mode: PaginationMode.offset,
      pageSize: 30,
      prefetchThreshold: 10,
      maxRendered: 50,
      fetcher: (req) async {
        final corpus = context.read<Corpus>();
        final saved = context.read<CookbookStore>().savedRecipeIds;
        final all = saved
            .map((id) => corpus.recipesById[id])
            .whereType<Recipe>()
            .toList();
        final slice = all.skip(req.offset).take(req.limit).toList();
        return PageResult(
          items: slice,
          hasMore: req.offset + slice.length < all.length,
        );
      },
    );
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.loadMore());
    context.read<CookbookStore>().addListener(_onCookbookChanged);
  }

  void _onCookbookChanged() {
    _ctrl.refresh();
  }

  void _onScroll() {
    final idx =
        (_scroll.position.pixels / 220).clamp(0, _ctrl.items.length).round();
    if (_ctrl.shouldLoadMore(idx)) _ctrl.loadMore();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    context.read<CookbookStore>().removeListener(_onCookbookChanged);
    _scroll.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final corpus = context.watch<Corpus>();
    return PaperBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (ctx, _) {
              return CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverToBoxAdapter(
                    child: Masthead(
                      title: 'cookbook',
                      edition: l.t('cookbook.title'),
                      leftMeta: '${_ctrl.items.length} saved',
                      rightMeta: 'yours',
                    ),
                  ),
                  if (_ctrl.state == PageState.empty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(l.t('cookbook.empty'),
                              style:
                                  MorphType.body(size: 16),
                              textAlign: TextAlign.center),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(8),
                      sliver: SliverGrid.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          childAspectRatio: 0.66,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                        itemCount: _ctrl.items.length,
                        itemBuilder: (ctx, i) {
                          final r = _ctrl.items[i];
                          final d = corpus.dishesById[r.dishId];
                          if (d == null) return const SizedBox.shrink();
                          return PolaroidCard(
                            width: 200,
                            rotation: rotationFor(r.id),
                            image: StripedPlaceholder(
                              stripeColor:
                                  MorphColors.parseHex(d.stripeColor),
                              caption: d.capCaption.get(l.lang),
                              dense: true,
                            ),
                            title: d.name.get(l.lang),
                            subtitle:
                                '${r.variantTag.get(l.lang)} · ${r.timeMinutes} min',
                            onTap: () => Navigator.of(ctx).push(
                              MaterialPageRoute(
                                builder: (_) => DishDetailScreen(
                                  dishId: d.id,
                                  initialRecipeId: r.id,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (_ctrl.state == PageState.loading)
                    const SliverToBoxAdapter(
                      child: Center(
                          child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                            color: MorphColors.ink,
                            strokeWidth: 1.5),
                      )),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
