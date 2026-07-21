import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_router.dart';
import '../../core/corpus_repository.dart';
import '../../core/engine/matching.dart';
import '../../core/engine/pagination.dart';
import '../../core/engine/search.dart';
import '../../core/l10n.dart';
import '../../core/models/local_text.dart';
import '../../core/models/profile.dart';
import '../../core/models/recipe.dart';
import '../../core/storage/local_store.dart';
import '../../core/storage/profile_store.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/dashed_rule.dart';
import '../../shared/widgets/polaroid_card.dart';
import '../../shared/widgets/striped_image.dart';

/// Free-text + tag search across the whole corpus. Profile filters apply
/// inside [SearchEngine.search]; results paginate cursor-based, 20 per page.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _fieldController = TextEditingController();
  Timer? _debounce;

  bool _ready = false;
  String _query = '';
  final Set<String> _selectedTags = {};
  List<String> _allTags = [];

  /// Full (unpaged) result list the controller slices pages from.
  List<Recipe> _results = const [];
  List<Recipe> _browseList = const [];
  late final PaginationController<Recipe> _controller;
  int _lastPageStart = 0;

  /// Query texts already logged as content requests this session.
  final Set<String> _loggedEmptyQueries = {};

  ProfileStore? _profileStore;

  bool get _isBrowsing => _query.trim().isEmpty && _selectedTags.isEmpty;

  @override
  void initState() {
    super.initState();
    final engine = context.read<SearchEngine>();
    _controller = PaginationController<Recipe>(
      fetchPage: (cursor) async {
        _lastPageStart = cursor == null ? 0 : int.tryParse(cursor) ?? 0;
        return engine.page(_results, cursor);
      },
      nextCursorOf: (page) {
        final next = _lastPageStart + page.length;
        return next < _results.length ? next.toString() : null;
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = context.read<ProfileStore>();
    if (!identical(store, _profileStore)) {
      _profileStore?.removeListener(_onProfileChanged);
      _profileStore = store;
      _profileStore!.addListener(_onProfileChanged);
      _loadCorpus();
    }
  }

  Future<void> _loadCorpus() async {
    final corpus = context.read<CorpusRepository>();
    await corpus.ensureAllLoaded(); // search spans all partitions
    if (!mounted) return;
    setState(() {
      _ready = true;
      _allTags = corpus.recipes.values.expand((r) => r.tags).toSet().toList()
        ..sort();
    });
    _runSearch();
  }

  void _onProfileChanged() {
    if (!_ready || !mounted) return;
    _runSearch();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _query = value;
      _runSearch();
    });
  }

  void _toggleTag(String tag) {
    setState(() {
      if (!_selectedTags.remove(tag)) _selectedTags.add(tag);
    });
    _runSearch();
  }

  void _runSearch() {
    final profile = _profileStore?.profile ?? const UserProfile();
    if (_isBrowsing) {
      _results = const [];
      _browseList = _computeBrowse(profile);
    } else {
      _browseList = const [];
      _results = context.read<SearchEngine>().search(
        _query,
        profile,
        tags: _selectedTags,
      );
      if (_results.isEmpty) {
        final q = _query.trim();
        // Log a content gap once per query text (dedup lives in LocalStore).
        if (q.isNotEmpty && _loggedEmptyQueries.add(q)) {
          context.read<LocalStore>().logContentRequest(q);
        }
      }
    }
    setState(() {});
    _controller.refresh();
  }

  /// All visible dishes, best-ranked variant per dish.
  List<Recipe> _computeBrowse(UserProfile profile) {
    final ranked = context.read<MatchingEngine>().rankVisible(
      context.read<CorpusRepository>().recipes.values,
      profile,
      now: DateTime.now(),
      lastCookedAtByRecipe: context.read<LocalStore>().lastCookedAtByRecipe,
    );
    final seen = <String>{};
    return [
      for (final r in ranked)
        if (seen.add(r.dishId)) r,
    ];
  }

  bool _reduceMotion(UserProfile profile) =>
      profile.reduceMotion ??
      MediaQuery.maybeOf(context)?.disableAnimations ??
      false;

  @override
  void dispose() {
    _debounce?.cancel();
    _profileStore?.removeListener(_onProfileChanged);
    _fieldController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S(context);
    final profile = context.watch<ProfileStore>().profile;
    final reduceMotion = _reduceMotion(profile);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.t('search.title'), style: AppText.masthead(size: 30)),
            const SizedBox(height: 12),
            TextField(
              controller: _fieldController,
              onChanged: _onQueryChanged,
              style: AppText.body(size: 18),
              cursorColor: AppColors.coral,
              decoration: InputDecoration(
                hintText: s.t('search.hint'),
                hintStyle: AppText.headline(size: 18, color: AppColors.inkSoft),
                isDense: true,
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.inkSoft),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.coral, width: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_allTags.isNotEmpty) ...[
              SectionRule(label: s.t('search.tags_label')),
              const SizedBox(height: 8),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _allTags.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final tag = _allTags[i];
                    return FilterChip(
                      label: Text(tag.toLowerCase()),
                      labelStyle: AppText.monoLabel(
                        size: 10,
                        color: _selectedTags.contains(tag)
                            ? AppColors.ink
                            : AppColors.inkSoft,
                      ),
                      selected: _selectedTags.contains(tag),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => _toggleTag(tag),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: !_ready
                  ? _SkeletonList(reduceMotion: reduceMotion)
                  : _isBrowsing
                  ? _buildBrowse(s, profile, reduceMotion)
                  : _buildResults(s, profile, reduceMotion),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrowse(AppStrings s, UserProfile profile, bool reduceMotion) {
    if (_browseList.isEmpty) {
      return _EmptyNote(s: s, showHint: false);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionRule(label: s.t('search.browse_title')),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            itemCount: _browseList.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ResultCard(
                recipe: _browseList[i],
                profile: profile,
                s: s,
                rotation: reduceMotion ? 0 : (i.isEven ? -0.008 : 0.008),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResults(AppStrings s, UserProfile profile, bool reduceMotion) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final items = _controller.items;
        if (_controller.error != null && items.isEmpty) {
          return Center(
            child: Text(
              s.t('search.error'),
              style: AppText.handwritten(size: 22),
              textAlign: TextAlign.center,
            ),
          );
        }
        if (!_controller.isLoading && items.isEmpty) {
          return _EmptyNote(s: s, showHint: true);
        }
        final skeletons = _controller.isLoading ? (items.isEmpty ? 6 : 2) : 0;
        return ListView.builder(
          itemCount: items.length + skeletons,
          itemBuilder: (_, i) {
            if (i >= items.length) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _SkeletonCard(reduceMotion: reduceMotion),
              );
            }
            if (_controller.shouldLoadMore(i)) {
              // Prefetch the next page after this frame — notifying during
              // build would throw.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _controller.loadMore();
              });
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ResultCard(
                recipe: items[i],
                profile: profile,
                s: s,
                rotation: reduceMotion ? 0 : (i.isEven ? -0.008 : 0.008),
              ),
            );
          },
        );
      },
    );
  }
}

/// Compact polaroid row: striped thumb, dish name, variant title, mono meta.
class _ResultCard extends StatelessWidget {
  final Recipe recipe;
  final UserProfile profile;
  final AppStrings s;
  final double rotation;

  const _ResultCard({
    required this.recipe,
    required this.profile,
    required this.s,
    required this.rotation,
  });

  @override
  Widget build(BuildContext context) {
    final corpus = context.read<CorpusRepository>();
    final dish = corpus.dishById(recipe.dishId);
    final lang = profile.lang;
    final meta =
        '${recipe.timeMinutes} ${s.t('common.minutes')} • ${recipe.caloriesPerServing} ${s.t('common.kcal')} • ${s.t('effort.${recipe.effort}')}';

    return PolaroidCard(
      rotation: rotation,
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.dish,
        arguments: recipe.dishId,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: StripedImage(
              stripeColor: dish?.stripeColor ?? '#C4573B',
              height: 64,
              showCaption: false,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The dish concept name — never a diet-prefixed variant name.
                Text(
                  localize(dish?.name, lang),
                  style: AppText.headline(size: 17),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  localize(recipe.title, lang),
                  style: AppText.handwritten(size: 17),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(meta, style: AppText.monoLabel(size: 10)),
                if (profile.showVariantTags && recipe.tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final tag in recipe.tags)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.paperDark,
                            border: Border.all(
                              color: AppColors.inkSoft,
                              width: 0.6,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tag.toLowerCase(),
                            style: AppText.monoLabel(size: 9),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Gentle zero-results note; the query was logged as a content request.
class _EmptyNote extends StatelessWidget {
  final AppStrings s;
  final bool showHint;

  const _EmptyNote({required this.s, required this.showHint});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              s.t('search.empty_note'),
              style: AppText.handwritten(size: 24),
              textAlign: TextAlign.center,
            ),
            if (showHint) ...[
              const SizedBox(height: 10),
              Text(
                s.t('search.empty_hint'),
                style: AppText.monoLabel(size: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  final bool reduceMotion;
  const _SkeletonList({required this.reduceMotion});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _SkeletonCard(reduceMotion: reduceMotion),
      ),
    );
  }
}

/// Shimmer placeholder shaped like a result card. Static when reduced
/// motion is requested.
class _SkeletonCard extends StatefulWidget {
  final bool reduceMotion;
  const _SkeletonCard({required this.reduceMotion});

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (!widget.reduceMotion) _anim.repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      height: 12,
      decoration: BoxDecoration(
        color: AppColors.paperDark,
        borderRadius: BorderRadius.circular(3),
      ),
    );
    final card = Container(
      height: 84,
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(color: AppColors.polaroid),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.paperDark,
              border: Border.all(color: AppColors.inkSoft, width: 0.6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FractionallySizedBox(widthFactor: 0.6, child: bar),
                const SizedBox(height: 8),
                FractionallySizedBox(widthFactor: 0.4, child: bar),
                const SizedBox(height: 8),
                FractionallySizedBox(widthFactor: 0.8, child: bar),
              ],
            ),
          ),
        ],
      ),
    );
    if (widget.reduceMotion) return card;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Opacity(
        opacity: 0.5 + 0.5 * (0.5 - (_anim.value - 0.5).abs()) * 2,
        child: child,
      ),
      child: card,
    );
  }
}
