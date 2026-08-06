import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/corpus_repository.dart';
import '../../domain/pagination.dart';
import '../../state/app_model.dart';
import '../../state/library_model.dart';
import '../dish/dish_screen.dart';
import '../widgets.dart';

/// Cookbook (saved). Offset-based pagination, 30 per page, sorted by
/// saved date. You save *your* variant — a specific recipe id.
class CookbookScreen extends StatefulWidget {
  const CookbookScreen({super.key});

  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen> {
  PaginationController<String>? _controller;
  int _savedCount = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final library = context.read<LibraryModel>();
    final count = library.savedMap().length;
    if (_controller == null || count != _savedCount) {
      _savedCount = count;
      _controller?.dispose();
      _controller = PaginationController<String>(
        pageSize: 30,
        prefetchThreshold: 10,
        maxRendered: 50,
        fetchPage: (offset, limit) async {
          final ids = library.savedByDateDesc();
          return ids.skip(offset).take(limit).toList();
        },
      )..loadMore();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppModel>();
    final library = context.watch<LibraryModel>();
    final corpus = context.read<CorpusRepository>();
    final s = app.strings;
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();

    // Rebuild items when the saved set changes.
    final items = controller.items
        .where((id) => library.isSaved(id))
        .toList();

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.get('cookbook'), style: Type.displayBold(size: 30)),
                const SizedBox(height: 4),
                Text('${items.length} ${s.get('saved').toLowerCase()}',
                    style: Type.mono(size: 11, color: Paper.inkSoft)),
                const SizedBox(height: 8),
                const DashedLine(),
              ],
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                if (controller.isLoading && controller.items.isEmpty) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(14),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: 4,
                    itemBuilder: (_, _) => const SkeletonCard(),
                  );
                }
                if (items.isEmpty) {
                  return EmptyNote(
                    title: s.get('empty'),
                    note: s.get('emptyCookbook'),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(14),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: items.length + (controller.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= items.length) {
                      if (controller.shouldLoadMore(index - 1)) {
                        controller.loadMore();
                      }
                      return const SkeletonCard();
                    }
                    if (controller.shouldLoadMore(index)) {
                      controller.loadMore();
                    }
                    final recipeId = items[index];
                    final recipe = corpus.recipe(recipeId);
                    if (recipe == null) return const SizedBox.shrink();
                    final rotation =
                        (index.isEven ? -1 : 1) * (0.006 + (index % 3) * 0.004);
                    return RecipeCard(
                      recipe: recipe,
                      rotation: rotation,
                      saved: true,
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => DishScreen(
                            dishId: recipe.dishId,
                            initialRecipeId: recipe.id,
                          ),
                        ));
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
