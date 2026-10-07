import 'package:flutter/material.dart' hide Typography;
import 'package:provider/provider.dart';

import '../../core/i18n/strings.dart';
import '../../core/model/recipe.dart';
import '../../core/pagination.dart';
import '../../core/search.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../navigation.dart';
import '../../state/app_state.dart';
import '../../widgets/controls.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/paginated_list.dart';
import '../../widgets/paper.dart';

/// Search the paper: free text + tag filters, results respect profile
/// filters. Cursor-based pagination, 20 items per page, prefetch at 10.
class SearchScreen extends StatefulWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _query = '';
  final Set<String> _tagFilters = {};
  PaginationController<Recipe>? _controller;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery ?? '';
    _queryController.text = _query;
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _queryController.dispose();
    _focus.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _rebuild(AppState appState) {
    _controller?.dispose();
    final engine = SearchEngine(corpus: appState.corpus, matcher: appState.matcher);
    _controller = engine.searchController(
      _query,
      profile: appState.profile,
      tagFilters: _tagFilters,
    );
    if (_query.trim().isNotEmpty) {
      // Log zero-result queries to content_requests (exported with backups).
      engine
          .matchingIds(_query, profile: appState.profile, tagFilters: _tagFilters)
          .then((ids) {
        if (ids.isEmpty && mounted) appState.logContentRequest(_query);
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final s = Strings(appState.profile.lang);
    _controller ??= SearchEngine(corpus: appState.corpus, matcher: appState.matcher)
        .searchController(_query, profile: appState.profile, tagFilters: _tagFilters);

    final ontology = appState.corpus.ontology;
    final filterTags = <String>[
      ...ontology.dietOptions,
      ...ontology.effortLevels,
    ];

    return PaperScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                      child: Text('←', style: Typography.mono(14, color: Palette.teal)),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Palette.paperDeep.withValues(alpha: 0.4),
                        border: Border.all(color: Palette.ink, width: 1.4),
                      ),
                      child: TextField(
                        controller: _queryController,
                        focusNode: _focus,
                        style: Typography.hand(19),
                        decoration: InputDecoration(
                          hintText: s.searchHint,
                          hintStyle: Typography.hand(19, color: Palette.inkFaint),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (v) {
                          _query = v;
                          _rebuild(appState);
                        },
                        onSubmitted: (_) => _rebuild(appState),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => setState(() => _showFilters = !_showFilters),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _tagFilters.isNotEmpty || _showFilters ? Palette.coral : Palette.line,
                          width: 1.2,
                        ),
                        color: Palette.paper,
                      ),
                      child: Text(s.searchFilters.toUpperCase(),
                          style: Typography.mono(10, letterSpacing: 1.4,
                              color: _tagFilters.isNotEmpty || _showFilters ? Palette.coral : Palette.inkSoft)),
                    ),
                  ),
                ],
              ),
            ),
            if (_showFilters)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in filterTags)
                      PaperChip(
                        label: tag.startsWith('easy') || tag.startsWith('medium') || tag.startsWith('hard')
                            ? s.effortLabel(tag)
                            : s.dietLabel(tag),
                        selected: _tagFilters.contains(tag),
                        onTap: () {
                          setState(() {
                            if (_tagFilters.contains(tag)) {
                              _tagFilters.remove(tag);
                            } else {
                              _tagFilters.add(tag);
                            }
                          });
                          _rebuild(appState);
                        },
                      ),
                  ],
                ),
              ),
            const DashedRule(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8)),
            Expanded(
              child: PaginatedListView<Recipe>(
                controller: _controller!,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                emptyState: EmptyState(
                  title: s.searchNoResults,
                  body: s.searchNoResultsBody,
                ),
                itemBuilder: (context, recipe, index) {
                  final dish = appState.corpus.dishById(recipe.dishId);
                  return GestureDetector(
                    onTap: () => openDish(context, recipe.dishId),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 56,
                            height: 42,
                            child: StripedPlatePlaceholder(color: dish != null ? _color(dish.stripeColor) : Palette.coral),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(recipe.title.resolve(s.lang), style: Typography.hand(20)),
                                Text(
                                  '${recipe.timeMinutes} ${s.commonMin} · ~${recipe.caloriesPerServing} ${s.commonKcal} · ${s.dietLabel(recipe.diet)}',
                                  style: Typography.mono(9.5, color: Palette.inkFaint),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 16, color: Palette.inkFaint),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StripedPlatePlaceholder extends StatelessWidget {
  final Color color;

  const StripedPlatePlaceholder({super.key, required this.color});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(3)),
        child: CustomPaint(painter: _MiniStripePainter(color)),
      );
}

class _MiniStripePainter extends CustomPainter {
  final Color color;

  _MiniStripePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color.withValues(alpha: 0.13));
    final paint = Paint()
      ..shader = LinearGradient(
        begin: const Alignment(-0.906, -0.423),
        end: const Alignment(0.906, 0.423),
        colors: [
          Colors.transparent,
          color.withValues(alpha: 0.8),
          Colors.transparent,
          color.withValues(alpha: 0.47),
          Colors.transparent,
          color.withValues(alpha: 0.47),
          Colors.transparent,
          color.withValues(alpha: 0.47),
          Colors.transparent,
          color.withValues(alpha: 0.8),
          Colors.transparent,
        ],
        stops: const [0, 0.18, 0.26, 0.37, 0.44, 0.55, 0.63, 0.73, 0.81, 0.92, 1],
        tileMode: TileMode.repeated,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniStripePainter oldDelegate) => oldDelegate.color != color;
}

Color _color(String hex) {
  final digits = hex.replaceFirst('#', '');
  final value = int.tryParse(digits, radix: 16);
  if (value == null) return Palette.coral;
  return Color(digits.length == 6 ? 0xFF000000 | value : value);
}
