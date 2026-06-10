import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/content_requests_store.dart';
import '../data/corpus.dart';
import '../data/profile_store.dart';
import '../l10n/strings.dart';
import '../matching/matcher.dart';
import '../models/recipe.dart';
import '../search/search_engine.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../widgets/chip_tag.dart';
import '../widgets/dashed_rule.dart';
import '../widgets/masthead.dart';
import '../widgets/paper_background.dart';
import '../widgets/striped_placeholder.dart';
import 'dish_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<Recipe> _results = const [];
  final Set<String> _activeTags = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _run(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      final corpus = context.read<Corpus>();
      final profile = context.read<ProfileStore>().profile;
      final engine = SearchEngine(corpus);
      final matcher =
          Matcher(ontology: corpus.ontology, dict: corpus.ingredientDict);
      final res = engine.search(
        q,
        matcher: matcher,
        profile: profile,
        mustTags: _activeTags.toList(),
      );
      if (res.isEmpty && q.trim().isNotEmpty) {
        context.read<ContentRequestsStore>().record(q);
      }
      setState(() => _results = res);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final corpus = context.watch<Corpus>();
    // Tag suggestions: cuisines + a few popular attributes.
    final tagSet = <String>{};
    for (final r in corpus.recipes) {
      tagSet.addAll(r.cuisineTags);
    }
    tagSet.addAll(['breakfast', 'dinner', 'lunch', 'easy', 'vegan', 'vegetarian']);

    return PaperBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Masthead(
                title: 'index',
                edition: l.t('nav.search'),
                leftMeta: '${_results.length} results',
                rightMeta: l.t('search.respect'),
              ),
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  cursorColor: MorphColors.ink,
                  style: MorphType.headline(size: 22),
                  onChanged: _run,
                  decoration: InputDecoration(
                    hintText: l.t('search.placeholder'),
                    prefixIcon:
                        const Icon(Icons.search, color: MorphColors.ink),
                  ),
                ),
              ),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    for (final tag in tagSet.take(20))
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChipTag(
                          label: tag,
                          selected: _activeTags.contains(tag),
                          onTap: () {
                            setState(() {
                              if (_activeTags.contains(tag)) {
                                _activeTags.remove(tag);
                              } else {
                                _activeTags.add(tag);
                              }
                            });
                            _run(_ctrl.text);
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const DashedRule(),
              Expanded(
                child: _results.isEmpty &&
                        _ctrl.text.trim().isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Text(l.t('search.empty'),
                              textAlign: TextAlign.center,
                              style: MorphType.body(size: 16)),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 12),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const DashedRule(),
                        itemBuilder: (ctx, i) {
                          final r = _results[i];
                          final d = corpus.dishesById[r.dishId];
                          if (d == null) return const SizedBox.shrink();
                          return _ResultTile(recipe: r, lang: l.lang);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final Recipe recipe;
  final String lang;
  const _ResultTile({required this.recipe, required this.lang});

  @override
  Widget build(BuildContext context) {
    final corpus = context.read<Corpus>();
    final dish = corpus.dishesById[recipe.dishId];
    if (dish == null) return const SizedBox.shrink();
    return ListTile(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DishDetailScreen(
              dishId: dish.id, initialRecipeId: recipe.id),
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      leading: StripedSwatch(
        color: MorphColors.parseHex(dish.stripeColor),
        size: 44,
      ),
      title: Text(recipe.name.get(lang),
          style: MorphType.headline(size: 18)),
      subtitle: Text(
        '${recipe.variantTag.get(lang)} · ${recipe.timeMinutes} min · ${recipe.caloriesPerServing} kcal',
        style: MorphType.smallCaps(size: 10),
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
