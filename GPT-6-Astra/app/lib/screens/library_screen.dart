import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/pagination.dart';
import '../core/repository.dart';
import '../ui/design.dart';

class LibraryScreen extends StatefulWidget {
  final AppState state;
  final void Function(Recipe) onOpen;
  final bool savedOnly;
  const LibraryScreen({
    super.key,
    required this.state,
    required this.onOpen,
    this.savedOnly = false,
  });
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final query = TextEditingController();
  String tag = 'all';
  bool loading = true;
  String? error;
  Timer? debounce;
  int revision = 0;
  late PaginationController<Recipe> pages;
  @override
  void initState() {
    super.initState();
    _createPages();
    widget.state.addListener(_changed);
    _load();
  }

  void _createPages() {
    pages = PaginationController<Recipe>(
      type: widget.savedOnly ? PaginationType.offset : PaginationType.cursor,
      pageSize: widget.savedOnly ? 30 : 20,
      prefetchThreshold: 10,
      loader: (request) async {
        final all = _results();
        return widget.savedOnly
            ? offsetPage(all, request)
            : cursorPage(all, request, (recipe) => recipe.id);
      },
    );
  }

  Future<void> _load() async {
    try {
      if (widget.savedOnly) {
        await Future.wait(
          widget.state.saved.map(widget.state.repo.loadForRecipe),
        );
      } else {
        await widget.state.repo.loadAll();
      }
      await pages.refresh();
      if (mounted) {
        setState(() => loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e.toString();
        });
      }
    }
  }

  void _changed() {
    pages.refresh();
    if (mounted) {
      setState(() => revision++);
    }
  }

  List<Recipe> _results() {
    final s = widget.state;
    var all = widget.savedOnly
        ? s.saved.map(s.repo.byId).whereType<Recipe>().toList()
        : s.visibleRecipes();
    final terms = normalizeSearch(
      query.text,
    ).trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty);
    all = all.where((r) {
      final text = s.repo.searchText(r, s.profile.lang);
      return terms.every(text.contains) &&
          (tag == 'all' ||
              tag == 'quick' && r.timeMinutes <= 30 ||
              r.tags.contains(tag) ||
              r.attributes.contains(tag) ||
              r.diet == tag);
    }).toList();
    return all;
  }

  void _search() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 300), () async {
      await pages.refresh();
      if (mounted) {
        setState(() {});
        if (!widget.savedOnly &&
            _results().isEmpty &&
            query.text.trim().isNotEmpty) {
          final terms = normalizeSearch(
            query.text,
          ).trim().split(RegExp(r'\s+'));
          final exists = widget.state.repo.recipes.any(
            (recipe) => terms.every(
              widget.state.repo
                  .searchText(recipe, widget.state.profile.lang)
                  .contains,
            ),
          );
          if (!exists) widget.state.recordContentRequest(query.text.trim());
        }
      }
    });
  }

  @override
  void dispose() {
    debounce?.cancel();
    query.dispose();
    pages.dispose();
    widget.state.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1140),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: widget.savedOnly
                    ? tr(s, 'the ones you love.', 'deine Lieblinge.')
                    : tr(s, 'follow your appetite.', 'folge deinem Appetit.'),
                subtitle: widget.savedOnly
                    ? tr(
                        s,
                        'Your recipes, kept close. A cookbook that feels like you.',
                        'Deine Rezepte, immer dabei. Ein Kochbuch, das zu dir passt.',
                      )
                    : tr(
                        s,
                        'A whole world of good food. There’s a place for you here.',
                        'Eine Welt voller gutem Essen. Hier ist Platz für dich.',
                      ),
              ),
              TextField(
                controller: query,
                onChanged: (_) => _search(),
                decoration: InputDecoration(
                  hintText: tr(
                    s,
                    'A dish, an ingredient, a little inspiration…',
                    'Ein Gericht, eine Zutat, ein bisschen Inspiration…',
                  ),
                  prefixIcon: const Icon(Icons.search, size: 21),
                  suffixIcon: query.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: tr(s, 'Clear search', 'Suche löschen'),
                          onPressed: () {
                            query.clear();
                            _search();
                          },
                          icon: const Icon(Icons.close, size: 18),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final item in [
                      ('all', tr(s, 'everything', 'alles')),
                      ('quick', tr(s, 'under 30 min', 'unter 30 Min.')),
                      ('breakfast', tr(s, 'breakfast', 'Frühstück')),
                      ('dinner', tr(s, 'dinner', 'Abendessen')),
                      ('vegan', 'vegan'),
                      ('italian', tr(s, 'Italian', 'italienisch')),
                      ('asian', tr(s, 'Asian', 'asiatisch')),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          showCheckmark: false,
                          selected: tag == item.$1,
                          label: Text(
                            item.$2,
                            style: TextStyle(
                              color: tag == item.$1
                                  ? Palette.white
                                  : Palette.ink,
                            ),
                          ),
                          onSelected: (_) {
                            setState(() => tag = item.$1);
                            _search();
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionLabel(
                widget.savedOnly
                    ? tr(
                        s,
                        '${_results().length} recipes, saved with love',
                        '${_results().length} Rezepte, mit Liebe gesammelt',
                      )
                    : tr(
                        s,
                        '${_results().length} recipes for your table',
                        '${_results().length} Rezepte für deinen Tisch',
                      ),
              ),
              Expanded(
                child: loading
                    ? _skeleton()
                    : error != null
                    ? Center(
                        child: PrimaryButton(
                          label: tr(s, 'Try again', 'Erneut versuchen'),
                          onPressed: () {
                            setState(() {
                              error = null;
                              loading = true;
                            });
                            _load();
                          },
                        ),
                      )
                    : AnimatedBuilder(
                        animation: pages,
                        builder: (context, _) {
                          if (pages.items.isEmpty) {
                            return SingleChildScrollView(
                              child: Column(
                                children: [
                                  EmptyState(
                                    title: widget.savedOnly
                                        ? tr(
                                            s,
                                            'a few favourites, soon.',
                                            'bald voller Lieblingsrezepte.',
                                          )
                                        : tr(
                                            s,
                                            'nothing simmering just yet.',
                                            'hier köchelt noch nichts.',
                                          ),
                                    message: widget.savedOnly
                                        ? tr(
                                            s,
                                            'Tap the bookmark on any recipe to make it yours.',
                                            'Tippe auf das Lesezeichen eines Rezepts, um es zu speichern.',
                                          )
                                        : tr(
                                            s,
                                            'Try another ingredient or check your dietary, time and calorie preferences. Missing dish ideas stay privately on this device.',
                                            'Versuche eine andere Zutat oder prüfe Ernährung, Zeit und Kalorien. Fehlende Gerichtsideen bleiben privat auf diesem Gerät.',
                                          ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return ListView.builder(
                            key: ValueKey('$tag-${query.text}'),
                            padding: const EdgeInsets.only(bottom: 28),
                            cacheExtent: 300,
                            itemBuilder: (context, index) {
                              if (index >= pages.items.length) {
                                if (pages.hasMore) {
                                  scheduleMicrotask(pages.loadMore);
                                  return const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                      ),
                                    ),
                                  );
                                }
                                return null;
                              }
                              if (pages.shouldLoadMore(index) &&
                                  pages.hasMore) {
                                scheduleMicrotask(pages.loadMore);
                              }
                              final recipe = pages.items[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _row(s, recipe, index),
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

  Widget _row(AppState s, Recipe r, int index) {
    final dish = s.repo.dishById(r.dishId);
    return Container(
      decoration: BoxDecoration(
        color: Palette.white,
        border: Border.all(color: Palette.line),
      ),
      child: InkWell(
        onTap: () => widget.onOpen(r),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 94,
                child: StripeArt(
                  height: 110,
                  color: stripeColor(dish?.color ?? '#647B69'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    display(
                      localized(r.title, s.profile.lang).toLowerCase(),
                      size: 23,
                    ),
                    const SizedBox(height: 8),
                    mono('${r.timeMinutes} MIN · ${r.calories} KCAL', size: 8),
                    if (s.profile.showVariantTags) ...[
                      const SizedBox(height: 7),
                      mono(dietLabel(s, r.diet), size: 8, color: Palette.coral),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: tr(
                  s,
                  s.isSaved(r.id) ? 'Remove saved recipe' : 'Save recipe',
                  s.isSaved(r.id) ? 'Rezept entfernen' : 'Rezept speichern',
                ),
                onPressed: () => s.toggleSaved(r.id),
                icon: Icon(
                  s.isSaved(r.id) ? Icons.bookmark : Icons.bookmark_border,
                  size: 21,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _skeleton() => ListView.builder(
    itemCount: 4,
    itemBuilder: (c, i) => Container(
      height: 125,
      margin: const EdgeInsets.only(bottom: 14),
      color: Palette.line.withValues(alpha: .3),
    ),
  );
}
