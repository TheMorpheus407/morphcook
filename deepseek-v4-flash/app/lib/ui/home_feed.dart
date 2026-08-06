import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../data/services.dart';
import '../logic/feed.dart';
import '../logic/pagination.dart';
import '../models/models.dart';
import 'dish_detail.dart';
import 'search.dart';
import 'widgets.dart';

const _weekdaysEn = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const _weekdaysDe = ['mo', 'di', 'mi', 'do', 'fr', 'sa', 'so'];
const _monthsEn = [
  'jan', 'feb', 'mar', 'apr', 'may', 'jun',
  'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
];
const _monthsDe = [
  'jan', 'feb', 'mär', 'apr', 'mai', 'jun',
  'jul', 'aug', 'sep', 'okt', 'nov', 'dez',
];

String _dateLine(DateTime now, String lang) {
  final wd = (lang == 'de' ? _weekdaysDe : _weekdaysEn)[now.weekday - 1];
  final mo = (lang == 'de' ? _monthsDe : _monthsEn)[now.month - 1];
  final day = now.day.toString().padLeft(2, '0');
  return '$wd $day $mo ${now.year}';
}

String _dishName(Dish dish, String lang) =>
    dish.canonicalName[lang]?.toString() ??
    dish.canonicalName['en']?.toString() ??
    dish.id;

/// The magazine issue: masthead, featured plate, resume strip, hero cards,
/// cookbook, quick & easy, rediscover and the colophon. Paginates a lazy
/// corpus load with a subtle footer while the rest of the paper dries.
class HomeFeed extends StatefulWidget {
  const HomeFeed({super.key});

  @override
  State<HomeFeed> createState() => _HomeFeedState();
}

class _HomeFeedState extends State<HomeFeed> {
  bool _corpusReady = false;
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadStarted) return;
    _loadStarted = true;
    _load();
  }

  Future<void> _load() async {
    final svc = Services.of(context);
    await svc.corpus.ensureAllLoaded();
    if (mounted) setState(() => _corpusReady = true);
  }

  @override
  Widget build(BuildContext context) {
    final svc = Services.of(context);
    final lang = svc.state.lang;
    String t(String k) => L10n.strings(lang, k);

    return ListenableBuilder(
      listenable: svc.state,
      builder: (context, _) {
        final snapshot = FeedSnapshot(
          now: DateTime.now(),
          corpus: svc.corpus,
          matcher: svc.matcher,
          profile: svc.state.profile,
          lastCooked: svc.state.lastCookedByRecipe,
        );
        final saved = snapshot.fromCookbook(svc.state.savedEntries);
        final rediscover = snapshot.rediscover();
        return SingleChildScrollView(
          child: Center(
            child: ZinePage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Masthead(
                    volLine: '${t(L10n.tVol)} · ${t(L10n.tIssue)}',
                    dateLine: _dateLine(snapshot.now, lang),
                  ),
                  const SizedBox(height: 10),
                  _searchBar(context, t),
                  if (snapshot.featured != null) ...[
                    SectionHeader(title: t(L10n.tFeatured), kicker: 'today'),
                    FractionallySizedBox(
                      widthFactor: 0.95,
                      child: _heroCard(context, snapshot.featured!, lang, t),
                    ),
                  ],
                  if (snapshot.rightNow != null) ...[
                    SectionHeader(title: t(L10n.tRightNow), kicker: 'kitchen'),
                    _rightNowRow(context, snapshot.rightNow!, t),
                  ],
                  SectionHeader(title: t(L10n.tHeroes), kicker: 'week'),
                  _strip(context, snapshot.rankedAll.take(6).toList(), lang, t),
                  if (saved.isNotEmpty) ...[
                    SectionHeader(title: t(L10n.tFromCookbook)),
                    _strip(context, saved.take(6).toList(), lang, t),
                  ],
                  SectionHeader(title: t(L10n.tQuickEasy)),
                  _strip(context, snapshot.quickAndEasy, lang, t),
                  if (rediscover.isNotEmpty) ...[
                    SectionHeader(title: t(L10n.tRediscover), kicker: 'stale'),
                    _strip(context, rediscover, lang, t),
                  ],
                  const SizedBox(height: 14),
                  const DottedDivider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      t(L10n.tColophon),
                      textAlign: TextAlign.center,
                      style: AppText.mono(
                          context, size: 9, color: AppColors.inkFaint),
                    ),
                  ),
                  Text(
                    'morphcook · vol. 1',
                    textAlign: TextAlign.center,
                    style: AppText.mono(
                        context, size: 10, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const BrowsePage(),
                      ),
                    ),
                    icon: const Icon(Icons.menu_book_outlined, size: 16),
                    label: Text(
                      t(L10n.tBrowseAll),
                      style: AppText.mono(context, size: 11),
                    ),
                  ),
                  if (!_corpusReady) ...[
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          t(L10n.tHomeLoading),
                          style: AppText.mono(
                              context, size: 10, color: AppColors.inkFaint),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _meta(Recipe r, String Function(String) t) =>
      '${r.timeMinutes} ${t(L10n.tMinutes).toLowerCase()} · ${r.calories} kcal';

  void _open(BuildContext context, FeedEntry e) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            DishDetailPage(dish: e.dish, initialRecipe: e.recipe),
      ),
    );
  }

  Widget _searchBar(BuildContext context, String Function(String) t) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const SearchPage()),
      ),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.paperBright,
          border: Border.all(color: AppColors.lineDotted),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 17, color: AppColors.inkFaint),
            const SizedBox(width: 8),
            Text(
              t(L10n.tSearchHint),
              style: AppText.mono(
                  context, size: 11, color: AppColors.inkFaint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroCard(
      BuildContext context, FeedEntry e, String lang, String Function(String) t) {
    return PolaroidCard(
      dish: e.dish,
      caption: _dishName(e.dish, lang),
      sub: _meta(e.recipe, t),
      onTap: () => _open(context, e),
    );
  }

  Widget _rightNowRow(BuildContext context, FeedEntry e, String Function(String) t) {
    final days = DateTime.now().difference(e.lastCookedAt!).inDays;
    return ZebraRow(
      index: 0,
      onTap: () => _open(context, e),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dishName(e.dish, Services.of(context).state.lang),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.serif(context, size: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  '${t(L10n.tCooked)} ${days}d ${t(L10n.tAgo)}',
                  style: AppText.mono(
                      context, size: 10, color: AppColors.inkFaint),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: t(L10n.tResume),
            onPressed: () => _open(context, e),
            icon: const Icon(Icons.play_arrow),
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }

  Widget _strip(
      BuildContext context,
      List<FeedEntry> entries,
      String lang,
      String Function(String) t) {
    return SizedBox(
      height: 224,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final e in entries)
            PolaroidCard(
              width: 150,
              dish: e.dish,
              caption: _dishName(e.dish, lang),
              sub: _meta(e.recipe, t),
              onTap: () => _open(context, e),
            ),
        ],
      ),
    );
  }
}

/// Full index of every dish, ranked like the feed, paged in tens with a
/// tag filter row up top.
class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key});

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  late final PaginationController<FeedEntry> _controller;
  final Set<String> _selectedTags = {};
  List<FeedEntry> _all = const [];
  bool _init = false;

  @override
  void initState() {
    super.initState();
    _controller = PaginationController<FeedEntry>();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final svc = Services.of(context);
    final snapshot = FeedSnapshot(
      now: DateTime.now(),
      corpus: svc.corpus,
      matcher: svc.matcher,
      profile: svc.state.profile,
      lastCooked: svc.state.lastCookedByRecipe,
    );
    _all = snapshot.rankedAll;
    if (_init) return;
    _init = true;
    _controller.setFetcher((cursor, page) async {
      final all = _filtered();
      return PageResult<FeedEntry>(
        items: paginate(all, page, pageSize: 10),
        hasMore: page * 10 < all.length,
        nextCursor: page * 10,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<FeedEntry> _filtered() => _all
      .where((e) =>
          _selectedTags.isEmpty ||
          e.recipe.tags.any(_selectedTags.contains))
      .toList();

  void _toggleTag(String tag) {
    setState(() {
      if (!_selectedTags.add(tag)) _selectedTags.remove(tag);
    });
    _controller.reset();
    _controller.loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Services.of(context).state.lang;
    String t(String k) => L10n.strings(lang, k);
    final svc = Services.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t(L10n.tIndexTitle),
          style: AppText.serif(context, size: 18, weight: FontWeight.w700),
        ),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final items = _controller.items;
          final tags = svc.corpus.allTags.take(14).toList();
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t(L10n.tTags).toUpperCase(),
                        style: AppText.mono(
                            context, size: 9, color: AppColors.accent)
                            .copyWith(letterSpacing: 1.4),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in tags)
                            InkWell(
                              onTap: () => _toggleTag(tag),
                              borderRadius: BorderRadius.circular(4),
                              child: PressChip(
                                label: tag,
                                filled: _selectedTags.contains(tag),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: items.length + 1,
                itemBuilder: (context, i) {
                  if (i >= items.length) return _footer(context, t);
                  _controller.shouldLoadMore(i);
                  final e = items[i];
                  return ZebraRow(
                    index: i,
                    onTap: () => _open(context, e),
                    child: _row(context, e, lang, t),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  String _meta(Recipe r, String Function(String) t) =>
      '${r.timeMinutes} ${t(L10n.tMinutes).toLowerCase()} · ${r.calories} kcal'
      ' · ${r.effort ?? '-'}';

  void _open(BuildContext context, FeedEntry e) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            DishDetailPage(dish: e.dish, initialRecipe: e.recipe),
      ),
    );
  }

  Widget _row(BuildContext context, FeedEntry e, String lang, String Function(String) t) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _dishName(e.dish, lang),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.serif(context, size: 16),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _meta(e.recipe, t),
          style: AppText.mono(context, size: 10, color: AppColors.inkFaint),
        ),
      ],
    );
  }

  Widget _footer(BuildContext context, String Function(String) t) {
    if (_controller.hasMore && _controller.error == null) {
      _controller.loadMore();
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            t(L10n.tHomeLoading),
            style: AppText.mono(context, size: 10, color: AppColors.inkFaint),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          t(L10n.tTheEnd),
          style: AppText.mono(context, size: 10, color: AppColors.inkFaint),
        ),
      ),
    );
  }
}
