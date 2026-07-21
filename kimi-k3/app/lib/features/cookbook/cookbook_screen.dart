import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../app_router.dart';
import '../../core/corpus_repository.dart';
import '../../core/engine/pagination.dart';
import '../../core/engine/week.dart';
import '../../core/l10n.dart';
import '../../core/models/dish.dart';
import '../../core/models/local_text.dart';
import '../../core/models/recipe.dart';
import '../../core/storage/local_store.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/dashed_rule.dart';
import '../../shared/widgets/polaroid_card.dart';
import '../../shared/widgets/striped_image.dart';

/// The cookbook: saved variants ("your seitan döner") plus cooking history
/// grouped by ISO week. Saved uses offset pagination (30/page, prefetch 10,
/// max 50 rendered); history paginates by week (7 weeks first, +1 per load).
class CookbookScreen extends StatefulWidget {
  const CookbookScreen({super.key});

  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen> {
  late final LocalStore _store;
  late final CorpusRepository _corpus;

  late final PaginationController<SavedRecipe> _savedCtl;
  late final PaginationController<CookEvent> _historyCtl;

  int _tab = 0;
  bool _ready = false;

  // Fetch bookkeeping: the controllers cap `items` at maxRendered by dropping
  // entries, so "how far have we read" must live outside the item list.
  int _savedFetchedEnd = 0;
  int _historyWeeksCovered = 0;
  DateTime? _historyOldestWindowStart;

  // Loop guards for live refresh on store changes.
  int _lastSavedCount = -1;
  int _lastHistoryCount = -1;

  @override
  void initState() {
    super.initState();
    _store = context.read<LocalStore>();
    _corpus = context.read<CorpusRepository>();

    _savedCtl = PaginationController<SavedRecipe>(
      pageSize: 30,
      prefetchThreshold: 10,
      maxRendered: 50,
      fetchPage: _fetchSaved,
      nextCursorOf: _savedNextCursor,
    );
    _historyCtl = PaginationController<CookEvent>(
      pageSize: 7, // weeks on the first load; one week per loadMore after
      prefetchThreshold: 1,
      maxRendered: 50,
      fetchPage: _fetchHistory,
      nextCursorOf: _historyNextCursor,
    );

    // Recipe ids may live in lazy partitions — load everything once up front.
    _corpus.ensureAllLoaded().catchError((_) {}).then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _savedCtl.refresh();
      _historyCtl.refresh();
    });
  }

  @override
  void dispose() {
    _savedCtl.dispose();
    _historyCtl.dispose();
    super.dispose();
  }

  // ---- saved: offset pagination over localStore.saved (newest first) -------

  Future<List<SavedRecipe>> _fetchSaved(String? cursor) async {
    final offset = int.tryParse(cursor ?? '') ?? 0;
    final all = _store.saved
        .where((s) => _corpus.recipeById(s.recipeId) != null)
        .toList();
    final page = all.skip(offset).take(30).toList();
    _savedFetchedEnd = offset + page.length;
    return page;
  }

  String? _savedNextCursor(List<SavedRecipe> page) {
    final total = _store.saved
        .where((s) => _corpus.recipeById(s.recipeId) != null)
        .length;
    return _savedFetchedEnd < total ? '$_savedFetchedEnd' : null;
  }

  // ---- history: week-window pagination --------------------------------------

  bool _hasHistoryBefore(DateTime moment) => _store.history.any(
    (e) => DateTime.fromMillisecondsSinceEpoch(e.cookedAt).isBefore(moment),
  );

  Future<List<CookEvent>> _fetchHistory(String? cursor) async {
    final monday = mondayOf(DateTime.now());
    var covered = int.tryParse(cursor ?? '') ?? 0;
    var toFetch = covered == 0 ? 7 : 1;

    List<CookEvent> events;
    DateTime start;
    // Skip over silent weeks: keep extending the window backwards until a
    // week yields events or nothing older exists.
    while (true) {
      start = monday.subtract(Duration(days: 7 * (covered + toFetch - 1)));
      final end = monday.subtract(Duration(days: 7 * (covered - 1)));
      events = _store.history.where((e) {
        final d = DateTime.fromMillisecondsSinceEpoch(e.cookedAt);
        return _corpus.recipeById(e.recipeId) != null &&
            !d.isBefore(start) &&
            d.isBefore(end);
      }).toList();
      covered += toFetch;
      toFetch = 1;
      if (events.isNotEmpty || !_hasHistoryBefore(start)) break;
    }
    _historyWeeksCovered = covered;
    _historyOldestWindowStart = start;
    return events;
  }

  String? _historyNextCursor(List<CookEvent> page) {
    final start = _historyOldestWindowStart;
    if (start == null || !_hasHistoryBefore(start)) return null;
    return '$_historyWeeksCovered';
  }

  // ---- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final s = S(context);
    final store = context.watch<LocalStore>();

    // Live-refresh on unsave / new cook events, guarded against loops.
    if (_ready &&
        (store.saved.length != _lastSavedCount ||
            store.history.length != _lastHistoryCount)) {
      _lastSavedCount = store.saved.length;
      _lastHistoryCount = store.history.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _savedCtl.refresh();
        _historyCtl.refresh();
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('cookbook.title'),
                    style: AppText.masthead(size: 34),
                  ),
                  const SizedBox(height: 14),
                  _SegmentedTabs(
                    labels: [
                      s.t('cookbook.tab.saved'),
                      s.t('cookbook.tab.history'),
                    ],
                    selected: _tab,
                    onSelect: (i) => setState(() => _tab = i),
                  ),
                ],
              ),
            ),
            Expanded(child: _tab == 0 ? _buildSaved(s) : _buildHistory(s)),
          ],
        ),
      ),
    );
  }

  // ---- saved tab ---------------------------------------------------------------

  Widget _buildSaved(AppStrings s) {
    return AnimatedBuilder(
      animation: _savedCtl,
      builder: (context, _) {
        if (!_ready || (_savedCtl.isLoading && _savedCtl.items.isEmpty)) {
          return _SkeletonList(card: true);
        }
        if (_savedCtl.items.isEmpty) {
          return _EmptyState(
            note: s.t('cookbook.empty.saved.note'),
            cta: s.t('cookbook.empty.saved.cta'),
          );
        }
        final showTailLoader = _savedCtl.isLoading;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          itemCount: _savedCtl.items.length + (showTailLoader ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _savedCtl.items.length) {
              return _LoadingRow(label: s.t('common.loading'));
            }
            if (_savedCtl.shouldLoadMore(index)) {
              Future.microtask(_savedCtl.loadMore);
            }
            final saved = _savedCtl.items[index];
            final recipe = _corpus.recipeById(saved.recipeId);
            if (recipe == null) return const SizedBox.shrink();
            final dish = _corpus.dishById(recipe.dishId);
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _SavedCard(
                key: ValueKey(saved.recipeId),
                saved: saved,
                recipe: recipe,
                dish: dish,
                rotation:
                    (index.isEven ? -1.0 : 1.0) * (0.010 + 0.004 * (index % 3)),
                onUnsave: () => _store.toggleSaved(saved.recipeId),
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.dish,
                  arguments: recipe.dishId,
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---- history tab -------------------------------------------------------------

  Widget _buildHistory(AppStrings s) {
    return AnimatedBuilder(
      animation: _historyCtl,
      builder: (context, _) {
        if (!_ready || (_historyCtl.isLoading && _historyCtl.items.isEmpty)) {
          return _SkeletonList(card: false);
        }
        if (_historyCtl.items.isEmpty) {
          return _EmptyState(
            note: s.t('cookbook.empty.history.note'),
            cta: s.t('cookbook.empty.history.cta'),
          );
        }

        // Flatten events into week sections: String header / CookEvent row.
        final rows = <Object>[];
        String? lastWeek;
        for (final e in _historyCtl.items) {
          final date = DateTime.fromMillisecondsSinceEpoch(e.cookedAt);
          final key = isoWeekKey(date);
          if (key != lastWeek) {
            lastWeek = key;
            rows.add(_weekLabel(s, mondayOf(date)));
          }
          rows.add(e);
        }

        final showTailLoader = _historyCtl.isLoading;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          itemCount: rows.length + (showTailLoader ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= rows.length) {
              return _LoadingRow(label: s.t('common.loading'));
            }
            if (_historyCtl.shouldLoadMore(index)) {
              Future.microtask(_historyCtl.loadMore);
            }
            final row = rows[index];
            if (row is String) {
              return Padding(
                padding: EdgeInsets.only(top: index == 0 ? 2 : 18, bottom: 8),
                child: SectionRule(label: row),
              );
            }
            final event = row as CookEvent;
            final recipe = _corpus.recipeById(event.recipeId);
            if (recipe == null) return const SizedBox.shrink();
            final dish = _corpus.dishById(recipe.dishId);
            return _HistoryRow(
              event: event,
              recipe: recipe,
              dish: dish,
              dateLabel: _dateLabel(
                s,
                DateTime.fromMillisecondsSinceEpoch(event.cookedAt),
              ),
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.dish,
                arguments: recipe.dishId,
              ),
            );
          },
        );
      },
    );
  }

  // ---- localized dates (no intl date-symbol init needed) ------------------------

  List<String> _months(AppStrings s) => s.t('cookbook.months').split(',');

  /// "week of 13 july" / "woche vom 13. juli"
  String _weekLabel(AppStrings s, DateTime monday) {
    final month = _months(s)[monday.month - 1];
    final day = s.lang == 'de' ? '${monday.day}.' : '${monday.day}';
    return '${s.t('cookbook.weekOf')} $day $month';
  }

  /// "13 july" / "13. juli"
  String _dateLabel(AppStrings s, DateTime date) {
    final month = _months(s)[date.month - 1];
    return s.lang == 'de' ? '${date.day}. $month' : '${date.day} $month';
  }
}

// ---- widgets ---------------------------------------------------------------------

/// Mono lowercase tab switcher on a paper-tinted, ink-outlined pill row.
class _SegmentedTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  const _SegmentedTabs({
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.paperDark,
        border: Border.all(color: AppColors.ink, width: 1.1),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: i == selected
                        ? AppColors.tealSoft
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: AppText.monoLabel(
                      size: 11,
                      color: i == selected ? AppColors.ink : AppColors.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A saved variant as a polaroid: stripes + dish name + handwritten variant
/// title + mono meta, with a bookmark button that fades the card out calmly.
class _SavedCard extends StatefulWidget {
  final SavedRecipe saved;
  final Recipe recipe;
  final Dish? dish;
  final double rotation;
  final VoidCallback onUnsave;
  final VoidCallback onTap;

  const _SavedCard({
    super.key,
    required this.saved,
    required this.recipe,
    required this.dish,
    required this.rotation,
    required this.onUnsave,
    required this.onTap,
  });

  @override
  State<_SavedCard> createState() => _SavedCardState();
}

class _SavedCardState extends State<_SavedCard> {
  bool _fading = false;

  Future<void> _unsave() async {
    if (_fading) return;
    setState(() => _fading = true);
    await Future.delayed(const Duration(milliseconds: 340));
    if (mounted) widget.onUnsave();
  }

  @override
  Widget build(BuildContext context) {
    final s = S(context);
    final recipe = widget.recipe;
    final dish = widget.dish;
    final meta =
        '${recipe.timeMinutes} ${s.t('common.minutes')} • ${recipe.caloriesPerServing} ${s.t('common.kcal')}';

    return AnimatedOpacity(
      opacity: _fading ? 0 : 1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      child: PolaroidCard(
        rotation: widget.rotation,
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StripedImage(
              stripeColor: dish?.stripeColor ?? '#C4573B',
              caption: dish == null ? '' : localize(dish.capCaption, s.lang),
              height: 150,
            ),
            const SizedBox(height: 10),
            Text(
              dish == null ? '' : localize(dish.name, s.lang),
              style: AppText.headline(size: 20),
            ),
            const SizedBox(height: 2),
            Text(
              localize(recipe.title, s.lang),
              style: AppText.handwritten(size: 22, color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text(meta, style: AppText.monoLabel(size: 10))),
                IconButton(
                  onPressed: _unsave,
                  tooltip: s.t('cookbook.unsave.tooltip'),
                  icon: const Icon(
                    Icons.bookmark,
                    size: 20,
                    color: AppColors.coral,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One cooked entry: small striped thumb, dish + variant, cooked date in mono.
class _HistoryRow extends StatelessWidget {
  final CookEvent event;
  final Recipe recipe;
  final Dish? dish;
  final String dateLabel;
  final VoidCallback onTap;

  const _HistoryRow({
    required this.event,
    required this.recipe,
    required this.dish,
    required this.dateLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = S(context);
    final d = dish;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: StripedImage(
                stripeColor: dish?.stripeColor ?? '#C4573B',
                height: 42,
                showCaption: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d == null ? '' : localize(d.name, s.lang),
                    style: AppText.headline(size: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    localize(recipe.title, s.lang),
                    style: AppText.handwritten(size: 18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(dateLabel, style: AppText.monoLabel(size: 10)),
          ],
        ),
      ),
    );
  }
}

/// Caveat handwritten note + a quiet outlined button to the search tab.
class _EmptyState extends StatelessWidget {
  final String note;
  final String cta;

  const _EmptyState({required this.note, required this.cta});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: -0.02,
              child: Text(
                note,
                textAlign: TextAlign.center,
                style: AppText.handwritten(size: 26),
              ),
            ),
            const SizedBox(height: 22),
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.search),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.ink, width: 1.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
              ),
              child: Text(cta, style: AppText.monoLabel(size: 11)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quiet shimmer placeholders while the first page loads.
class _SkeletonList extends StatelessWidget {
  final bool card;
  const _SkeletonList({required this.card});

  @override
  Widget build(BuildContext context) {
    final bars = [
      for (var i = 0; i < 3; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: PolaroidCard(
            rotation: (i.isEven ? -1.0 : 1.0) * 0.01,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: card ? 150 : 42, color: AppColors.paperDark),
                const SizedBox(height: 10),
                Container(
                  height: 14,
                  width: 160 - i * 24.0,
                  color: AppColors.paperDark,
                ),
                const SizedBox(height: 6),
                Container(
                  height: 12,
                  width: 110 - i * 12.0,
                  color: AppColors.paperDark,
                ),
              ],
            ),
          ),
        ),
    ];
    return ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: bars,
        )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1400.ms,
          color: AppColors.polaroid.withValues(alpha: 0.7),
        );
  }
}

class _LoadingRow extends StatelessWidget {
  final String label;
  const _LoadingRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(child: Text(label, style: AppText.monoLabel(size: 10))),
    );
  }
}
