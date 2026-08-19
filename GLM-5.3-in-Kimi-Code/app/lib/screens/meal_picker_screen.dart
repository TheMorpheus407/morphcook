/// Slot picker: assign a recipe from cookbook or full search.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../state/app_state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class MealPickerScreen extends StatefulWidget {
  final String weekKey;
  final String slotId;
  const MealPickerScreen({super.key, required this.weekKey, required this.slotId});

  @override
  State<MealPickerScreen> createState() => _MealPickerScreenState();
}

class _MealPickerScreenState extends State<MealPickerScreen> {
  int _mode = 0; // 0 = cookbook, 1 = all
  String _query = '';
  bool _searching = false;

  void _select(String recipeId) => Navigator.of(context).pop(recipeId);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.profile.lang;
    final parts = widget.slotId.split('.');

    return Scaffold(
      appBar: AppBar(
        title: Text(L.f(lang, 'mpSlotOf', {
          'day': L.t(lang, 'day_${parts[0]}'),
          'meal': L.t(lang, 'mp${parts[1][0].toUpperCase()}${parts[1].substring(1)}'),
        })),
        actions: [
          if (app.mealPlan.slot(widget.weekKey, widget.slotId) != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop(''),
              child: Text(
                L.t(lang, 'mpClearSlot'),
                style: const TextStyle(
                    fontFamily: AppTheme.mono,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: AppTheme.coral),
              ),
            ),
        ],
      ),
      body: PaperGrain(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(children: [
              StampChip(
                label: L.t(lang, 'mpPickCookbook'),
                color: AppTheme.teal,
                selected: _mode == 0,
                onTap: () => setState(() {
                  _mode = 0;
                  _query = '';
                }),
              ),
              const SizedBox(width: 10),
              StampChip(
                label: L.t(lang, 'mpPickSearch'),
                color: AppTheme.teal,
                selected: _mode == 1,
                onTap: () => setState(() => _mode = 1),
              ),
            ]),
          ),
          if (_mode == 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: TextField(
                onChanged: (v) {
                  setState(() => _searching = true);
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted) setState(() => _searching = false);
                  });
                  setState(() => _query = v);
                },
                decoration: InputDecoration(
                  hintText: L.t(lang, 'scHint'),
                  hintStyle: const TextStyle(
                      fontFamily: AppTheme.hand,
                      fontSize: 18,
                      color: AppTheme.inkFaint),
                  border: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.ink, width: 1.4)),
                ),
                style: const TextStyle(fontFamily: AppTheme.display, fontSize: 17),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _mode == 0 ? _cookbookList(app, lang) : _searchList(app, lang),
          ),
        ]),
      ),
    );
  }

  Widget _cookbookList(AppState app, Lang lang) {
    final saved = app.savedRecipeIds.where((id) => app.recipe(id) != null).toList();
    if (saved.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Text(
            L.t(lang, 'cbEmptyBody'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: AppTheme.display,
                fontSize: 15,
                height: 1.5,
                color: AppTheme.inkSoft),
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: saved.length,
      itemBuilder: (context, i) {
        final recipe = app.recipe(saved[i])!;
        final dish = app.dish(recipe.dishId)!;
        return _row(app, lang, dish.canonicalName.get(lang),
            recipe.title.get(lang), recipe, dish.color);
      },
    );
  }

  Widget _searchList(AppState app, Lang lang) {
    if (_query.trim().isEmpty || _searching) {
      // show all dishes as candidates
      final dishes = app.corpus!.dishes.values.toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      return ListView.builder(
        itemCount: dishes.length,
        itemBuilder: (context, i) {
          final dish = dishes[i];
          final rep = app.defaultRecipeFor(dish.id);
          if (rep == null) return const SizedBox.shrink();
          return _row(app, lang, dish.canonicalName.get(lang),
              rep.title.get(lang), rep, dish.color);
        },
      );
    }
    final res = app.search(_query);
    if (res.hits.isEmpty) {
      return Center(child: HandNote(text: L.t(lang, 'scNoResults')));
    }
    return ListView.builder(
      itemCount: res.hits.length,
      itemBuilder: (context, i) {
        final hit = res.hits[i];
        return _row(app, lang, hit.dish.canonicalName.get(lang),
            hit.recipe.title.get(lang), hit.recipe, hit.dish.color);
      },
    );
  }

  Widget _row(AppState app, Lang lang, String title, String subtitle,
      dynamic recipe, Color color) {
    return ListTile(
      leading: SizedBox(
        width: 40,
        height: 40,
        child: StripedPlate(color: color, caption: '', height: 40),
      ),
      title: Text(title,
          style: const TextStyle(fontFamily: AppTheme.hand, fontSize: 20, color: AppTheme.ink)),
      subtitle: Text(
        '$subtitle · ${recipe.timeMinutes} ${L.t(lang, 'minutes')}',
        style: const TextStyle(fontFamily: AppTheme.mono, fontSize: 9.5, color: AppTheme.inkFaint),
      ),
      onTap: () => _select(recipe.id as String),
    );
  }
}
