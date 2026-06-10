import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../localization/i18n.dart';
import '../../matching/matching.dart';
import '../../matching/ranking.dart';
import '../../models/recipe.dart';
import '../../pagination/pagination_controller.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../widgets/dashed_rule.dart';
import '../../widgets/handwritten_note.dart';
import '../../widgets/masthead.dart';
import '../../widgets/paper_background.dart';
import '../../widgets/polaroid_card.dart';
import '../../widgets/tag_chip.dart';
import '../dish/dish_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  PaginationController<Recipe>? _pager;
  Timer? _debounce;
  bool _showFilters = false;
  bool _loggedRequest = false;

  // local filter overrides — does not modify profile
  final Set<String> _avoid = {};
  String? _effort;
  String? _calorieBucket;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initPager());
  }

  void _initPager() {
    final state = AppScope.of(context);
    _pager = PaginationController<Recipe>(
      pageSize: 20,
      maxRendered: 50,
      prefetchThreshold: 10,
      fetcher: ({required offset, required pageIndex, required pageSize, cursor}) async {
        final q = _ctrl.text.trim().toLowerCase();
        final lang = state.profileRepo.profile.lang;
        final all = state.recipeRepo.allRecipes();
        final profile = state.profileRepo.profile;
        final rankingCtx = RankingContext.fromHistory(
          state.historyRepo
              .lastCookedByRecipe()
              .entries
              .map((e) => MapEntry(e.key, e.value)),
        );

        var filtered = all.where((r) {
          if (!isVisible(
            r,
            profile,
            ontology: state.ontologyRepo.ontology,
            ingredients: state.ingredientRepo.tree,
          )) {
            return false;
          }
          for (final f in _avoid) {
            if (r.contains.contains(f)) return false;
          }
          if (_effort != null && r.effort != _effort) return false;
          if (_calorieBucket != null && r.calorieBucket != _calorieBucket) {
            return false;
          }
          if (q.isEmpty) return true;
          final dish = state.recipeRepo.dish(r.dishId);
          final hay = [
            r.name.resolve(lang),
            dish?.name.resolve(lang) ?? '',
            r.variantLabel.resolve(lang),
            ...r.ingredients.map((i) => i.name.resolve(lang)),
          ].join(' ').toLowerCase();
          return hay.contains(q);
        }).toList()
          ..sort((a, b) =>
              rank(b, profile, rankingCtx).compareTo(rank(a, profile, rankingCtx)));

        final pageItems = filtered.skip(offset).take(pageSize).toList();
        final hasMore = offset + pageItems.length < filtered.length;

        if (filtered.isEmpty && q.isNotEmpty && !_loggedRequest) {
          _loggedRequest = true;
          await state.contentRequestRepo.add(q);
        }

        return PageResult(items: pageItems, hasMore: hasMore);
      },
    );
    _pager!.loadMore();
    setState(() {});
  }

  void _onChanged() {
    _debounce?.cancel();
    _loggedRequest = false;
    _debounce = Timer(const Duration(milliseconds: 220), () {
      _pager?.refresh();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    _pager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = I18n.of(context);
    final state = AppScope.of(context);
    if (_pager == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final lang = state.profileRepo.profile.lang;

    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Masthead(title: s.tabSearch, align: TextAlign.left, titleSize: 32),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _ctrl,
                  decoration: InputDecoration(
                    hintText: s.searchHint,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _showFilters ? Icons.tune : Icons.tune_outlined,
                          color: _showFilters ? MCColors.coral : MCColors.inkSoft),
                      onPressed: () => setState(() => _showFilters = !_showFilters),
                    ),
                  ),
                  style: MCTypography.italic(size: 18),
                ),
              ),
              if (_showFilters) ...[
                const SizedBox(height: 10),
                _Filters(
                  avoid: _avoid,
                  effort: _effort,
                  calorieBucket: _calorieBucket,
                  onChange: () => _pager?.refresh(),
                  onSetEffort: (v) => setState(() => _effort = v),
                  onSetCalorie: (v) => setState(() => _calorieBucket = v),
                ),
              ],
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: DashedRule(),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: _pager!,
                  builder: (context, child) {
                    final items = _pager!.items;
                    if (items.isEmpty && _pager!.isExhausted) {
                      return _NoResults();
                    }
                    if (items.isEmpty && _ctrl.text.isEmpty) {
                      return Center(
                        child: HandwrittenNote(
                          text: s.searchEmpty,
                          color: MCColors.inkFaded,
                          size: 22,
                        ),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.7,
                      ),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        if (_pager!.shouldLoadMore(i)) _pager!.loadMore();
                        final r = items[i];
                        final dish = state.recipeRepo.dish(r.dishId);
                        if (dish == null) return const SizedBox.shrink();
                        return Center(
                          child: PolaroidCard(
                            title: dish.name.resolve(lang),
                            subtitle: r.variantLabel.resolve(lang),
                            eyebrow:
                                '${r.timeMinutes} min · ${r.effort}',
                            stripeColor: _hex(dish.stripeColor),
                            placeholderCaption: dish.capCaption.resolve(lang),
                            rotationTurns: i.isOdd ? 0.005 : -0.005,
                            width: 180,
                            compact: true,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DishDetailScreen(
                                  dishId: dish.id,
                                  initialRecipeId: r.id,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
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

class _Filters extends StatelessWidget {
  final Set<String> avoid;
  final String? effort;
  final String? calorieBucket;
  final VoidCallback onChange;
  final ValueChanged<String?> onSetEffort;
  final ValueChanged<String?> onSetCalorie;

  const _Filters({
    required this.avoid,
    required this.effort,
    required this.calorieBucket,
    required this.onChange,
    required this.onSetEffort,
    required this.onSetCalorie,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text('EFFORT', style: MCTypography.eyebrow()),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: ['easy', 'medium', 'hard'].map((e) {
              return TagChip(
                label: e,
                selected: effort == e,
                accent: MCColors.teal,
                onTap: () {
                  onSetEffort(effort == e ? null : e);
                  onChange();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Text('CALORIE BUCKET', style: MCTypography.eyebrow()),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: ['≤400', '≤600', '≤800', '>800'].map((c) {
              return TagChip(
                label: c,
                selected: calorieBucket == c,
                accent: MCColors.olive,
                onTap: () {
                  onSetCalorie(calorieBucket == c ? null : c);
                  onChange();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = I18n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.searchNoResults,
                textAlign: TextAlign.center,
                style: MCTypography.italic(size: 18)),
            const SizedBox(height: 8),
            Text(s.loggedAsRequest,
                style: MCTypography.eyebrow()),
          ],
        ),
      ),
    );
  }
}
