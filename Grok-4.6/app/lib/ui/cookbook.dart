import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../logic/pagination.dart';
import '../models/recipe.dart';
import 'home.dart';
import 'strings.dart';
import 'theme.dart';

class CookbookScreen extends StatefulWidget {
  const CookbookScreen({super.key});

  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen> {
  PaginationController<Recipe>? _pager;
  String _savedKey = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final key = context
        .read<AppState>()
        .saved
        .map((s) => s.recipeId)
        .join('|');
    if (key != _savedKey) {
      _savedKey = key;
      _rebuild();
    }
  }

  Future<void> _rebuild() async {
    final state = context.read<AppState>();
    final sorted = [...state.saved]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    final recipes = <Recipe>[];
    for (final saved in sorted) {
      final r = await state.corpus.recipeById(saved.recipeId);
      if (r != null) recipes.add(r);
    }
    if (!mounted) return;
    _pager?.dispose();
    _pager = PaginationController<Recipe>(
      fetch: offsetPager(recipes),
      pageSize: 30,
      prefetchThreshold: 10,
      maxRendered: 50,
    )..addListener(() {
        if (mounted) setState(() {});
      });
    await _pager!.loadMore();
  }

  @override
  void dispose() {
    _pager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final p = LedgerScope.colors(context);
    final pager = _pager;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s('yourCookbook'), style: Theme.of(context).textTheme.displayMedium),
            Text(
              '${s('editionFor')} ${state.profile.name.isEmpty ? '—' : state.profile.name}',
              style: const TextStyle(fontFamily: LedgerTheme.caveat, fontSize: 22),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: pager == null || pager.isEmpty
                  ? Center(
                      child: Text(
                        s('cookbookEmpty'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: LedgerTheme.caveat,
                          fontSize: 24,
                          color: p.walnutSoft,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: pager.items.length + (pager.hasMore ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (pager.shouldLoadMore(i)) pager.loadMore();
                        if (i >= pager.items.length) {
                          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                        }
                        final recipe = pager.items[i];
                        final dish = state.corpus.dishById(recipe.dishId);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(recipe.title.of(state.lang)),
                          subtitle: Text(dish?.name.of(state.lang) ?? recipe.dishId),
                          trailing: IconButton(
                            icon: Icon(Icons.bookmark, color: p.clay),
                            onPressed: () async {
                              await state.toggleSaved(recipe.id);
                              await _rebuild();
                            },
                          ),
                          onTap: () => openDish(context, recipe.dishId, recipeId: recipe.id),
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
