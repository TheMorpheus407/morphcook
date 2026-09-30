import 'dart:math' as math;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/nav_requests.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/labels.dart';
import '../../core/pagination/pagination_controller.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../data/corpus.dart';
import '../../data/models/profile.dart';
import '../../domain/search/search_service.dart';
import '../../state/catalog.dart';
import '../../state/controllers/content_request_log.dart';
import '../../state/controllers/profile_controller.dart';
import '../../widgets/paginated_list.dart';
import '../../widgets/paper_controls.dart';
import '../../widgets/recipe_row.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/state_views.dart';
import 'filter_sheet.dart';

/// Free-text search plus tag filters. Results respect the profile filters and
/// arrive 20 at a time (cursor pagination); the index chunk of each recipe
/// partition is fetched on demand as the reader scrolls on.
///
/// Queries that find nothing are noted locally as content requests.
class SearchPanel extends StatefulWidget {
  const SearchPanel({super.key, required this.onOpen, this.listenToNavRequests = true});

  final void Function(BuildContext context, SearchHit hit) onOpen;

  /// The tab listens for "more italian dishes"-style requests; a picker does not.
  final bool listenToNavRequests;

  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> {
  final TextEditingController _query = TextEditingController();
  SearchFilters _filters = const SearchFilters();
  PaginationController<SearchHit>? _pages;
  Timer? _debounce;
  Timer? _logTimer;
  Profile? _profileSeen;
  NavRequests? _nav;

  @override
  void initState() {
    super.initState();
    if (widget.listenToNavRequests) {
      _nav = context.read<NavRequests>()..addListener(_onNavRequest);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = Provider.of<ProfileController>(context).profile;
    if (_profileSeen != profile) {
      _profileSeen = profile;
      _restart();
    }
  }

  @override
  void dispose() {
    _nav?.removeListener(_onNavRequest);
    _debounce?.cancel();
    _logTimer?.cancel();
    _pages?.dispose();
    _query.dispose();
    super.dispose();
  }

  void _onNavRequest() {
    final request = _nav?.consumeSearch();
    if (request == null || !mounted) return;
    _query.text = request.query ?? '';
    _filters = request.filters ?? const SearchFilters();
    _restart();
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 260), _restart);
    setState(() {});
  }

  void _restart() {
    _debounce?.cancel();
    _logTimer?.cancel();
    final catalog = context.read<Catalog>();
    final profile = context.read<ProfileController>().profile;
    final query = _query.text.trim();
    final session = context.read<SearchService>().session(
      query: query,
      filters: _filters,
      profile: profile,
      context: catalog.context,
    );
    final previous = _pages;
    final controller = PaginationController<SearchHit>.cursor(
      loader: (cursor, limit) async {
        final page = await session.fetch(cursor: cursor, limit: limit);
        return CursorPage<SearchHit>(page.hits, nextCursor: page.nextCursor);
      },
    );
    setState(() => _pages = controller);
    WidgetsBinding.instance.addPostFrameCallback((_) => previous?.dispose());
    controller.refresh().then((_) {
      if (!mounted || _pages != controller) return;
      // Nothing found anywhere: note the wish, once the reader has settled.
      if (controller.isEmpty && query.length >= 2) {
        _logTimer = Timer(const Duration(milliseconds: 1400), () {
          if (mounted && _pages == controller) context.read<ContentRequestLog>().add(query);
        });
      }
    });
  }

  void _submit(String value) {
    final query = value.trim();
    _debounce?.cancel();
    _restart();
    final pages = _pages;
    pages?.refresh().then((_) {
      if (mounted && pages.isEmpty && query.length >= 2) context.read<ContentRequestLog>().add(query);
    });
  }

  void _setFilters(SearchFilters filters) {
    _filters = filters;
    _restart();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final corpus = context.read<Corpus>();
    final ontology = corpus.ontology;
    final showTags = context.select<ProfileController, bool>((p) => p.profile.showVariantTags);
    final rowExtent = RecipeRowMetrics.of(context).extent;
    final pages = _pages;
    final idle = _query.text.trim().isEmpty && _filters.isEmpty;
    final mealGroup = ontology.filterGroups.firstWhere((g) => g.kind == 'meal');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _query,
          onChanged: _onQueryChanged,
          onSubmitted: _submit,
          textInputAction: TextInputAction.search,
          style: AppText.serifItalic(size: 20),
          decoration: InputDecoration(
            hintText: s('search.hint'),
            prefixIcon: const Icon(Icons.search, size: 22),
            suffixIcon: _query.text.isEmpty
                ? null
                : IconButton(
                    tooltip: s('common.clear'),
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      _query.clear();
                      _restart();
                    },
                  ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          // The chips are at least 48 dp tall and grow with the text.
          height: math.max(48, MediaQuery.textScalerOf(context).scale(12) * 1.35 + 22),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              PaperChip(
                label: _filters.count == 0 ? s('search.filters') : s('search.filtersCount', {'n': _filters.count}),
                icon: Icons.tune,
                style: PaperChipStyle.mono,
                selected: _filters.count > 0,
                onTap: () async {
                  final result = await showFilterSheet(context, _filters);
                  if (result != null) _setFilters(result);
                },
              ),
              const SizedBox(width: 8),
              for (final meal in mealGroup.values) ...[
                PaperChip(
                  label: ontology.label(meal, s.lang),
                  style: PaperChipStyle.mono,
                  selected: _filters.meals.contains(meal),
                  onTap: () {
                    final meals = {..._filters.meals};
                    if (!meals.remove(meal)) meals.add(meal);
                    _setFilters(_filters.copyWith(meals: meals));
                  },
                ),
                const SizedBox(width: 8),
              ],
              for (final attribute in _filters.attributes) ...[
                PaperChip(
                  label: ontology.label(attribute, s.lang),
                  style: PaperChipStyle.mono,
                  selected: true,
                  icon: Icons.close,
                  onTap: () => _setFilters(_filters.copyWith(attributes: {..._filters.attributes}..remove(attribute))),
                ),
                const SizedBox(width: 8),
              ],
              for (final cuisine in _filters.cuisines) ...[
                PaperChip(
                  label: ontology.label(cuisine, s.lang),
                  style: PaperChipStyle.mono,
                  selected: true,
                  icon: Icons.close,
                  onTap: () => _setFilters(_filters.copyWith(cuisines: {..._filters.cuisines}..remove(cuisine))),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        if (idle)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: HandNote(s('search.idleNote'), size: 21, color: Palette.inkSoft),
          ),
        const SizedBox(height: 4),
        Expanded(
          child: pages == null
              ? const SizedBox.shrink()
              : PaginatedList<SearchHit>(
                  controller: pages,
                  itemExtent: (_, _) => rowExtent,
                  padding: const EdgeInsets.only(bottom: 24),
                  skeletonBuilder: (_) => const SingleChildScrollView(child: SkeletonList(count: 6)),
                  emptyBuilder: (context) {
                    final query = _query.text.trim();
                    return EmptyState(
                      title: query.isEmpty ? s('search.empty.filters') : s('search.empty.title', {'query': query}),
                      body: query.isEmpty ? s('search.empty.filtersBody') : s('search.empty.body'),
                      action: _filters.isEmpty ? null : s('search.clearFilters'),
                      onAction: _filters.isEmpty ? null : () => _setFilters(const SearchFilters()),
                      icon: Icons.filter_alt_off_outlined,
                    );
                  },
                  errorBuilder: (context, retry) => ErrorState(onRetry: retry),
                  itemBuilder: (context, hit, index) => RecipeRow(
                    seed: hit.dish.id,
                    title: hit.entry.title.resolve(s.lang),
                    meta: entryMeta(s, ontology, hit.entry, showDiet: showTags),
                    stripe: Palette.fromHex(hit.dish.stripe),
                    onTap: () => widget.onOpen(context, hit),
                  ),
                ),
        ),
      ],
    );
  }
}
