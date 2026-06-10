import 'dart:async';

import 'package:flutter/material.dart' hide Page;

import '../../core/context_ext.dart';
import '../../core/localized.dart';
import '../../logic/matching.dart';
import '../../logic/pagination.dart';
import '../../theme/app_theme.dart';
import '../../widgets/decor.dart';
import '../../widgets/recipe_card.dart';

/// Free-text + tag search over the corpus. Results respect the active profile
/// filters and stream in via cursor pagination. Quiet, paper-stationery look.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// Selected attribute ids (effort / technique / time bucket / calorie bucket)
  /// passed straight to the search index as `tagFilters`.
  final Set<String> _selectedTags = <String>{};

  /// The committed query the pagination controller is built from.
  String _query = '';

  /// Distinct empty-result queries we've already logged, so we log once.
  final Set<String> _loggedRequests = <String>{};

  Timer? _debounce;
  PaginationController<String>? _controller;

  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _textController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _onScroll() {
    final c = _controller;
    if (c == null) return;
    // Trigger a prefetch as the tail approaches.
    final lastVisible = c.items.length - 1;
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 600 &&
        c.shouldLoadMore(lastVisible)) {
      c.loadMore();
    }
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (value.trim() == _query.trim()) return;
      setState(() => _query = value);
      _rebuildController();
    });
  }

  void _toggleTag(String id) {
    setState(() {
      if (!_selectedTags.add(id)) _selectedTags.remove(id);
    });
    _rebuildController();
  }

  /// Build (or rebuild) the pagination controller for the current query + tags.
  /// The filtered id list is computed once per build; the fetcher just slices it.
  void _rebuildController() {
    _controller?.dispose();

    final scope = context.scope;
    final corpus = scope.corpus;
    final profile = scope.services.profile.profile;
    final ProfileMatcher matcher = scope.matcherFor(profile);

    final ids = corpus.searchIndex.query(
      _query,
      byId: corpus.recipeById,
      lang: context.lang,
      tagFilters: _selectedTags,
    );

    // Keep only recipes visible under the active profile.
    final filtered = <String>[];
    for (final id in ids) {
      final r = corpus.recipeById[id];
      if (r != null && matcher.isVisible(r)) filtered.add(id);
    }

    // Zero results for a real query: log the unmet demand once.
    if (_query.trim().isNotEmpty && filtered.isEmpty) {
      final q = _query.trim();
      if (_loggedRequests.add(q)) {
        scope.services.contentRequests.log(q);
      }
    }

    final controller = PaginationController<String>(
      type: PaginationType.cursor,
      pageSize: _pageSize,
      prefetchThreshold: 10,
      maxRendered: 50,
      fetcher: (cursor) async {
        final start = (cursor as int?) ?? 0;
        final end = (start + _pageSize).clamp(0, filtered.length);
        final slice = filtered.sublist(start, end);
        return Page<String>(
          items: slice,
          nextCursor: end,
          hasMore: end < filtered.length,
        );
      },
    );

    _controller = controller;
    controller.addListener(() {
      if (mounted) setState(() {});
    });
    controller.refresh();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scope = context.scope;
    return ListenableBuilder(
      listenable: scope.services.profile,
      builder: (context, _) {
        // The controller is profile-dependent (visibility filter); rebuild it
        // lazily on first build and whenever the profile notifies.
        if (_controller == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _controller == null) _rebuildController();
          });
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SearchField(
              controller: _textController,
              onChanged: _onTextChanged,
            ),
            _TagFilterRow(
              selected: _selectedTags,
              onToggle: _toggleTag,
            ),
            const SizedBox(height: 4),
            Expanded(child: _buildResults(context)),
          ],
        );
      },
    );
  }

  Widget _buildResults(BuildContext context) {
    final c = _controller;

    if (c == null) {
      return const _ResultsSkeleton();
    }

    if (c.error != null) {
      return _CenteredNote(
        note: context.lang == AppLang.de
            ? 'da ging etwas schief — nochmal?'
            : 'something went sideways — try again?',
        action: TextButton(
          onPressed: c.refresh,
          child: Text(context.tr('common.retry')),
        ),
      );
    }

    // No query and no tags yet: a gentle prompt, not an error.
    if (_query.trim().isEmpty && _selectedTags.isEmpty) {
      return _CenteredNote(
        note: context.lang == AppLang.de
            ? 'wonach ist dir heute?'
            : 'what are you in the mood for?',
      );
    }

    if (c.isLoading && !c.isInitialLoaded) {
      return const _ResultsSkeleton();
    }

    if (c.isEmpty) {
      return _CenteredNote(note: context.tr('search.no_results'));
    }

    final items = c.items;
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisSpacing: 18,
        crossAxisSpacing: 14,
        childAspectRatio: 0.66,
      ),
      itemCount: items.length + (c.hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= items.length) {
          return const _CardSkeleton();
        }
        final corpus = context.scope.corpus;
        final r = corpus.recipeById[items[i]];
        final dish = r == null ? null : corpus.dishOfRecipe(r.id);
        if (r == null || dish == null) return const SizedBox.shrink();
        return RecipeCard(
          recipe: r,
          dish: dish,
          rotation: i.isEven ? -0.02 : 0.018,
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFBF6EC),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: AppColors.inkFaint.withValues(alpha: 0.6)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(Icons.search, size: 18, color: AppColors.inkSoft),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                cursorColor: AppColors.terracotta,
                style: const TextStyle(
                  fontFamily: Fonts.mono,
                  fontSize: 14,
                  color: AppColors.ink,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: InputBorder.none,
                  hintText: context.tr('search.hint'),
                  hintStyle: const TextStyle(
                    fontFamily: Fonts.mono,
                    fontSize: 14,
                    color: AppColors.inkFaint,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagFilterRow extends StatelessWidget {
  const _TagFilterRow({required this.selected, required this.onToggle});
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final ontology = context.scope.corpus.ontology;

    // Build a small, curated set of filter chips from the ontology.
    final chips = <_TagOption>[
      for (final e in ontology.effort)
        _TagOption(e.id, context.loc(e.label)),
      for (final t in ontology.techniques.take(4))
        _TagOption(t.id, context.loc(t.label)),
      for (final b in ontology.timeBuckets)
        _TagOption(b.id, context.loc(b.label)),
      for (final b in ontology.calorieBuckets)
        _TagOption(b.id, context.loc(b.label)),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final chip = chips[i];
          final isOn = selected.contains(chip.id);
          return _FilterChipBox(
            label: chip.label,
            selected: isOn,
            onTap: () => onToggle(chip.id),
          );
        },
      ),
    );
  }
}

class _TagOption {
  const _TagOption(this.id, this.label);
  final String id;
  final String label;
}

class _FilterChipBox extends StatelessWidget {
  const _FilterChipBox({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.terracotta.withValues(alpha: 0.14)
                : Colors.transparent,
            border: Border.all(
              color: selected ? AppColors.terracotta : AppColors.inkFaint,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: Fonts.mono,
              fontSize: 10,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w500,
              color: selected ? AppColors.terracotta : AppColors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

/// A centred warm note for empty / prompt / error states.
class _CenteredNote extends StatelessWidget {
  const _CenteredNote({required this.note, this.action});
  final String note;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HandNote(note, size: 24),
            if (action != null) ...[
              const SizedBox(height: 12),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Grey paper placeholders shown while the first page loads.
class _ResultsSkeleton extends StatelessWidget {
  const _ResultsSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisSpacing: 18,
        crossAxisSpacing: 14,
        childAspectRatio: 0.66,
      ),
      itemCount: 6,
      itemBuilder: (_, i) => const _CardSkeleton(),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    Color grey(double a) => AppColors.inkFaint.withValues(alpha: a);
    return PolaroidCard(
      rotation: -0.01,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 150, color: grey(0.35)),
          const SizedBox(height: 10),
          Container(height: 14, width: 140, color: grey(0.4)),
          const SizedBox(height: 8),
          Container(height: 10, width: 90, color: grey(0.3)),
        ],
      ),
    );
  }
}
