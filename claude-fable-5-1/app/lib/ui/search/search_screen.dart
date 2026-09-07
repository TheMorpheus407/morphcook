import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/profile.dart';
import '../../domain/pagination.dart';
import '../../domain/search_engine.dart';
import '../../state/app_controller.dart';
import '../../theme/palette.dart';
import '../../theme/paper.dart';
import '../../theme/typography.dart';
import '../../theme/widgets.dart';
import '../l10n.dart';
import '../widgets/dish_card.dart';
import '../widgets/help_link.dart';

/// Free text + tag filters; results respect the profile and page by cursor.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _text = TextEditingController();
  final Set<String> _tags = {};
  bool _ignoreCalories = false;
  Timer? _debounce;
  String _query = '';

  PaginationController<SearchHit, String>? _controller;
  int _totalCandidates = -1;
  String? _loggedQuery;

  Profile? _lastProfile;
  String? _lastLang;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      if (value.trim() == _query) {
        setState(() {});
        return;
      }
      setState(() => _query = value.trim());
      _rebuildController();
    });
  }

  void _rebuildController() {
    final app = context.read<AppController>();
    _controller?.dispose();
    _totalCandidates = -1;
    final query = SearchQuery(text: _query, tags: Set.of(_tags));
    final ignore = _ignoreCalories;
    if (query.isEmpty) {
      _controller = null;
      setState(() {});
      return;
    }
    final c = PaginationController<SearchHit, String>(
      pageSize: 20,
      prefetchThreshold: 10,
      maxRendered: 50,
      loader: (cursor, pageSize) async {
        final page = await app.search.search(
          query,
          lang: app.lang,
          ctx: app.matchContext,
          cursor: cursor,
          pageSize: pageSize,
          ignoreCalories: ignore,
        );
        if (cursor == null) _totalCandidates = page.totalCandidates;
        return page;
      },
    );
    _controller = c;
    c.addListener(_onPage);
    c.loadMore();
    setState(() {});
  }

  void _onPage() {
    if (!mounted) return;
    final c = _controller;
    if (c != null && c.loadedOnce && !c.isLoading && c.items.isEmpty && _totalCandidates == 0 && _query.isNotEmpty && _loggedQuery != _query) {
      _loggedQuery = _query;
      context.read<AppController>().logContentRequest(_query);
    }
    setState(() {});
  }

  void _syncWithApp(AppController app) {
    final profile = app.profile;
    final lang = app.lang;
    if (_lastProfile == null) {
      _lastProfile = profile;
      _lastLang = lang;
      return;
    }
    if (profile != _lastProfile || lang != _lastLang) {
      _lastProfile = profile;
      _lastLang = lang;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller != null) _rebuildController();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final app = context.watch<AppController>();
    _syncWithApp(app);
    final s = context.s;
    final vocab = app.repo.searchIndex.tagVocabulary;
    final controller = _controller;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(s('search.title'), style: AppText.title(size: 24, italic: true)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _text,
              onChanged: _onTextChanged,
              textInputAction: TextInputAction.search,
              style: AppText.body(size: 15),
              decoration: InputDecoration(
                hintText: s('search.hint'),
                prefixIcon: const Icon(Icons.search, size: 20, color: Palette.inkFaint),
                suffixIcon: _text.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: s('common.clear'),
                        onPressed: () {
                          _text.clear();
                          _debounce?.cancel();
                          setState(() => _query = '');
                          _rebuildController();
                        },
                      ),
              ),
            ),
          ),
          if (vocab.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                itemCount: vocab.length,
                separatorBuilder: (context, index) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final tag = vocab[i];
                  final selected = _tags.contains(tag);
                  return PaperChip(
                    label: tag.replaceAll('-', ' '),
                    selected: selected,
                    onTap: () {
                      setState(() {
                        if (!_tags.remove(tag)) _tags.add(tag);
                      });
                      _rebuildController();
                    },
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
            child: Row(
              children: [
                Expanded(child: MonoLabel(s('search.showOutside'), color: Palette.inkSoft)),
                Switch(
                  value: _ignoreCalories,
                  onChanged: (v) {
                    setState(() => _ignoreCalories = v);
                    _rebuildController();
                  },
                ),
              ],
            ),
          ),
          const DashedRule(padding: EdgeInsets.symmetric(horizontal: 20)),
          Expanded(child: _body(context, controller)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, PaginationController<SearchHit, String>? controller) {
    final s = context.s;
    if (controller == null) {
      return EmptyState(title: s('search.idle.title'), note: s('search.idle.note'), icon: Icons.search);
    }
    if (controller.loadedOnce && !controller.isLoading && controller.items.isEmpty) {
      if (_totalCandidates == 0) {
        return EmptyState(title: s('search.empty.title'), note: s('search.empty.note'), icon: Icons.edit_note_outlined);
      }
      return EmptyState(
        title: s('search.empty.title'),
        note: s('search.empty.filtered'),
        icon: Icons.filter_alt_outlined,
        action: HelpLink(faqId: 'why-dish-missing', label: s('home.why'), align: TextAlign.center),
      );
    }
    final items = controller.items;
    return ListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 24),
      itemCount: null,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: MonoLabel(controller.loadedOnce ? s('search.results', {'n': '${items.length}${controller.hasMore ? '+' : ''}'}) : s('common.loading')),
          );
        }
        final i = index - 1;
        if (i < items.length) {
          if (controller.shouldLoadMore(i)) {
            WidgetsBinding.instance.addPostFrameCallback((_) => controller.loadMore());
          }
          final hit = items[i];
          return RecipeRowTile(recipe: hit.recipe, dish: hit.dish);
        }
        if (i == items.length) {
          if (controller.isLoading) return const _SkeletonRow();
          if (controller.capReached) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: MonoLabel(s('search.cap', {'n': '${controller.maxRendered}'})),
            );
          }
          if (controller.error != null) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: PaperButton(label: s('common.retry'), kind: PaperButtonKind.secondary, onPressed: controller.loadMore),
            );
          }
          return null;
        }
        return null;
      },
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          children: [
            SkeletonBox(height: 54, width: 54),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(height: 15, width: 180),
                  SizedBox(height: 8),
                  SkeletonBox(height: 11, width: 120),
                ],
              ),
            ),
          ],
        ),
      );
}
