import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../localization/i18n.dart';
import '../../data/cookbook_repository.dart';
import '../../pagination/pagination_controller.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../widgets/handwritten_note.dart';
import '../../widgets/masthead.dart';
import '../../widgets/paper_background.dart';
import '../../widgets/polaroid_card.dart';
import '../dish/dish_detail_screen.dart';

class CookbookScreen extends StatefulWidget {
  const CookbookScreen({super.key});

  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen> {
  PaginationController<String>? _ctrl;
  CookbookRepository? _cookbookRepo;
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _cookbookRepo = AppScope.of(context).cookbookRepo;
    _seeded = true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCtrl());
  }

  void _initCtrl() {
    final repo = _cookbookRepo;
    if (repo == null) return;
    _ctrl = PaginationController<String>(
      pageSize: 30,
      maxRendered: 50,
      prefetchThreshold: 10,
      fetcher: ({required offset, required pageIndex, required pageSize, cursor}) async {
        final page = repo.page(offset: offset, limit: pageSize);
        return PageResult(
          items: page,
          hasMore: offset + page.length < repo.total,
        );
      },
    );
    repo.addListener(_refresh);
    _ctrl!.loadMore();
  }

  void _refresh() {
    if (!mounted) return;
    _ctrl?.refresh();
  }

  @override
  void dispose() {
    _cookbookRepo?.removeListener(_refresh);
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = I18n.of(context);
    final lang = state.profileRepo.profile.lang;

    if (_ctrl == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _ctrl!,
            builder: (context, child) {
              final ids = _ctrl!.items;
              if (ids.isEmpty && _ctrl!.isExhausted) {
                return _Empty();
              }
              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                    sliver: SliverToBoxAdapter(
                      child: Masthead(
                        title: s.cookbookHeader,
                        subtitle: '${ids.length} ${s.savedToCookbook}',
                        align: TextAlign.left,
                        titleSize: 44,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.7,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          if (_ctrl!.shouldLoadMore(i)) _ctrl!.loadMore();
                          final id = ids[i];
                          final recipe = state.recipeRepo.recipe(id);
                          if (recipe == null) {
                            return const SizedBox.shrink();
                          }
                          final dish = state.recipeRepo.dish(recipe.dishId);
                          if (dish == null) return const SizedBox.shrink();
                          return Center(
                            child: PolaroidCard(
                              title: dish.name.resolve(lang),
                              subtitle: recipe.variantLabel.resolve(lang),
                              eyebrow: '${recipe.timeMinutes} min · ${recipe.effort}',
                              stripeColor: _hex(dish.stripeColor),
                              placeholderCaption: dish.capCaption.resolve(lang),
                              rotationTurns: (i.isEven ? -0.006 : 0.006),
                              width: 180,
                              compact: true,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DishDetailScreen(
                                    dishId: dish.id,
                                    initialRecipeId: recipe.id,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: ids.length,
                      ),
                    ),
                  ),
                  if (_ctrl!.isLoading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 60)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Color _hex(String s) {
    final c = s.replaceFirst('#', '');
    final v = int.tryParse(c.length == 6 ? 'FF$c' : c, radix: 16);
    return v == null ? MCColors.stripeFallback : Color(v);
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = I18n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.cookbookEmpty, style: MCTypography.display(size: 32), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            HandwrittenNote(
              text: s.cookbookEmptyBody,
              color: MCColors.inkFaded,
              size: 22,
              align: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
