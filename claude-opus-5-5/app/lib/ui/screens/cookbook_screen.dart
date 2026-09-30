import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/corpus_repository.dart';
import '../../i18n/strings.dart';
import '../../logic/matching.dart';
import '../../logic/pagination.dart';
import '../../models/recipe.dart';
import '../../state/library_store.dart';
import '../../state/profile_controller.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/recipe_card.dart';
import 'history_screen.dart';

class CookbookScreen extends StatefulWidget {
  const CookbookScreen({super.key});

  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Text(tr('cookbook.title'), style: MT.display(38)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                InkChip(label: tr('cookbook.saved'), selected: _tab == 0, onTap: () => setState(() => _tab = 0)),
                const SizedBox(width: 8),
                InkChip(
                  key: const Key('cookbook-cooked'),
                  label: tr('cookbook.cooked'),
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                SavedRecipesList(onPick: (r) => openDish(context, r.dishId, recipeId: r.id)),
                const HistoryList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Saved variants, newest first, offset-paginated (30 per page).
class SavedRecipesList extends StatefulWidget {
  const SavedRecipesList({super.key, required this.onPick});
  final ValueChanged<Recipe> onPick;

  @override
  State<SavedRecipesList> createState() => _SavedRecipesListState();
}

class _SavedRecipesListState extends State<SavedRecipesList> {
  late final LibraryStore _library = context.read<LibraryStore>();
  late final CorpusRepository _repo = context.read<CorpusRepository>();
  late final PaginationController<String> _pages = PaginationController<String>(
    config: PaginationConfig.cookbook,
    fetcher: (token, size) async {
      final page = await _library.savedPage(token, size);
      await _repo.ensureRecipes(page.items);
      return page;
    },
  );
  int _savedCount = -1;

  @override
  void initState() {
    super.initState();
    _library.addListener(_onLibrary);
    _savedCount = _library.savedCount;
    _pages.loadMore();
  }

  void _onLibrary() {
    if (_library.savedCount != _savedCount) {
      _savedCount = _library.savedCount;
      _pages.refresh();
    }
  }

  @override
  void dispose() {
    _library.removeListener(_onLibrary);
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final repo = context.watch<CorpusRepository>();
    final profileCtrl = context.watch<ProfileController>();
    final ctx = profileCtrl.matchContext(repo);
    return ListenableBuilder(
      listenable: _pages,
      builder: (context, _) {
        if (!_pages.isInitialised) {
          return ListView.builder(itemCount: 4, itemBuilder: (_, __) => const RecipeRowSkeleton());
        }
        if (_pages.isEmpty) {
          return SingleChildScrollView(
            child: EmptyState(title: tr('cookbook.empty.title'), body: tr('cookbook.empty.body')),
          );
        }
        final items = _pages.items;
        final offset = _pages.hasPrevious ? 1 : 0;
        return ListView.builder(
          key: const Key('saved-list'),
          padding: const EdgeInsets.only(bottom: 30),
          itemBuilder: (context, i) {
            if (offset == 1 && i == 0) {
              return Center(
                child: TextLink(tr('cookbook.earlier'), icon: Icons.expand_less, onTap: _pages.loadPrevious),
              );
            }
            final idx = i - offset;
            if (idx < items.length) {
              if (_pages.shouldLoadMore(idx)) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _pages.loadMore());
              }
              final r = repo.recipe(items[idx]);
              if (r == null) return const RecipeRowSkeleton();
              final dish = repo.dishes[r.dishId]!;
              final fits = isVisible(r, ctx, ignoreCalories: context.read<LibraryStore>().calorieOverride(dish.id));
              return Dismissible(
                key: ValueKey('saved-${r.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: MC.coral.withValues(alpha: 0.2),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  child: Text(tr('common.remove'), style: MT.mono(12, color: MC.coralDeep)),
                ),
                onDismissed: (_) => context.read<LibraryStore>().toggleSaved(r.id),
                child: RecipeRow(
                  dish: dish,
                  recipe: r,
                  dimmed: !fits,
                  note: fits ? null : tr('cookbook.nofit'),
                  onTap: () => widget.onPick(r),
                ),
              );
            }
            if (idx == items.length && _pages.hasMore) return const RecipeRowSkeleton();
            return null;
          },
        );
      },
    );
  }
}
