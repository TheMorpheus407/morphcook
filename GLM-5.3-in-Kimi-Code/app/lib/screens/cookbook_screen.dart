/// Cookbook (saved variants) + cooking history, both paginated.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../logic/pagination.dart';
import '../state/app_state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'dish_screen.dart';
import 'history_screen.dart';

class CookbookScreen extends StatefulWidget {
  const CookbookScreen({super.key});

  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen> {
  late PaginationController<String> _pager;
  late final AppState _app;

  @override
  void initState() {
    super.initState();
    _app = context.read<AppState>();
    _pager = PaginationController<String>(
      policy: PaginationPolicy.cookbook,
      fetchPage: (cursor) async {
        final app = _app;
        final start = int.tryParse(cursor ?? '0') ?? 0;
        // offset-based over saved ids sorted by save date (store order)
        return app.savedRecipeIds
            .where((id) => app.recipe(id) != null)
            .skip(start)
            .take(PaginationPolicy.cookbook.pageSize)
            .toList();
      },
    );
    // refresh whenever saves change
    _pager.refresh();
    _app.addListener(_onAppChange);
  }

  void _onAppChange() {
    if (!mounted) return;
    _pager.refresh();
  }

  @override
  void dispose() {
    _app.removeListener(_onAppChange);
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.profile.lang;

    return Scaffold(
      appBar: AppBar(
        title: Text(L.t(lang, 'cbTitle'),
            style: const TextStyle(
                fontFamily: AppTheme.display,
                fontStyle: FontStyle.italic,
                fontSize: 22)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const HistoryScreen())),
            child: Text(
              L.t(lang, 'cbHistory'),
              style: const TextStyle(
                  fontFamily: AppTheme.mono,
                  fontSize: 10,
                  letterSpacing: 1.4,
                  color: AppTheme.teal),
            ),
          ),
        ],
      ),
      body: PaperGrain(
        child: AnimatedBuilder(
          animation: _pager,
          builder: (context, _) {
            if (_pager.items.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(30),
                children: [
                  const SizedBox(height: 40),
                  HandNote(text: L.t(lang, 'cbEmpty')),
                  const SizedBox(height: 12),
                  Text(
                    L.t(lang, 'cbEmptyBody'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: AppTheme.display,
                        fontSize: 15,
                        height: 1.5,
                        color: AppTheme.inkSoft),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: _pager.items.length + 1,
              itemBuilder: (context, i) {
                if (i == _pager.items.length) {
                  if (_pager.status == PageStatus.loadingMore) {
                    return const Padding(
                      padding: EdgeInsets.all(14),
                      child: Center(
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppTheme.inkFaint))),
                    );
                  }
                  return const SizedBox(height: 8);
                }
                if (_pager.shouldLoadMore(i)) _pager.loadMore();
                final id = _pager.items[i];
                final recipe = app.recipe(id)!;
                final dish = app.dish(recipe.dishId)!;
                final dietLabel = app.ontology.dietLabels[recipe.diet]?.label.get(lang) ?? recipe.diet;
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: PolaroidCard(
                    stripeColor: dish.color,
                    title: dish.canonicalName.get(lang),
                    subtitle: recipe.title.get(lang),
                    meta:
                        '$dietLabel · ${recipe.effort} · ${recipe.timeMinutes} ${L.t(lang, 'minutes')} · ~${recipe.caloriesPerServing} ${L.t(lang, 'kcal')}',
                    tag: app.profile.showVariantTags ? dietLabel : null,
                    rotation: i.isEven ? -0.4 : 0.5,
                    plateHeight: 150,
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => DishScreen(dishId: dish.id))),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
