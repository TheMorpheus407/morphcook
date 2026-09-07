import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../data/models/dish.dart';
import '../../data/models/recipe.dart';
import '../../domain/search_engine.dart';
import '../../state/app_controller.dart';
import '../../theme/palette.dart';
import '../../theme/paper.dart';
import '../../theme/typography.dart';
import '../../theme/widgets.dart';
import '../l10n.dart';
import '../widgets/dish_card.dart';

/// Bottom sheet that returns the chosen recipe id (or null).
Future<String?> pickRecipeForSlot(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _SlotPicker(),
  );
}

class _SlotPicker extends StatefulWidget {
  const _SlotPicker();

  @override
  State<_SlotPicker> createState() => _SlotPickerState();
}

class _SlotPickerState extends State<_SlotPicker> {
  bool _searchTab = false;
  bool _autoSwitched = false;
  final _query = TextEditingController();
  Timer? _debounce;
  List<SearchHit> _hits = const [];
  bool _searching = false;
  List<(Recipe, Dish)>? _saved;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final app = context.read<AppController>();
    final out = <(Recipe, Dish)>[];
    for (final id in app.savedIdsNewestFirst) {
      final r = await app.recipe(id);
      final d = r == null ? null : app.dish(r.dishId);
      if (r != null && d != null) out.add((r, d));
    }
    if (!mounted) return;
    setState(() {
      _saved = out;
      if (out.isEmpty && !_autoSwitched) {
        _autoSwitched = true;
        _searchTab = true;
      }
    });
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    final app = context.read<AppController>();
    if (q.trim().isEmpty) {
      if (mounted) setState(() => _hits = const []);
      return;
    }
    setState(() => _searching = true);
    final page = await app.search.search(SearchQuery(text: q), lang: app.lang, ctx: app.matchContext, pageSize: 20);
    if (!mounted) return;
    setState(() {
      _hits = page.items;
      _searching = false;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.94,
      minChildSize: 0.4,
      builder: (context, scroll) {
        final saved = _saved;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s('plan.pick.title'), style: AppText.display(size: 26)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      PaperChip(label: s('plan.pick.cookbook'), selected: !_searchTab, onTap: () => setState(() => _searchTab = false)),
                      const SizedBox(width: 8),
                      PaperChip(label: s('plan.pick.search'), selected: _searchTab, onTap: () => setState(() => _searchTab = true)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_searchTab)
                    TextField(
                      controller: _query,
                      autofocus: saved != null && saved.isEmpty,
                      onChanged: _onQueryChanged,
                      textInputAction: TextInputAction.search,
                      style: AppText.body(size: 14.5),
                      decoration: InputDecoration(hintText: s('search.hint'), prefixIcon: const Icon(Icons.search, size: 18)),
                    ),
                  const SizedBox(height: 10),
                  const DashedRule(),
                ],
              ),
            ),
            Expanded(
              child: _searchTab ? _searchList(scroll, s) : _savedList(scroll, s),
            ),
          ],
        );
      },
    );
  }

  Widget _savedList(ScrollController scroll, S s) {
    final saved = _saved;
    if (saved == null) {
      return ListView(controller: scroll, padding: const EdgeInsets.all(20), children: const [SkeletonBox(height: 48), SizedBox(height: 10), SkeletonBox(height: 48)]);
    }
    if (saved.isEmpty) {
      return ListView(
        controller: scroll,
        padding: const EdgeInsets.all(22),
        children: [HandNote(s('plan.pick.empty'), color: Palette.inkFaint)],
      );
    }
    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: saved.length,
      itemBuilder: (context, i) {
        final (r, d) = saved[i];
        return RecipeRowTile(recipe: r, dish: d, dense: true, onTap: () => Navigator.of(context).pop(r.id));
      },
    );
  }

  Widget _searchList(ScrollController scroll, S s) {
    if (_searching) {
      return ListView(controller: scroll, padding: const EdgeInsets.all(20), children: const [SkeletonBox(height: 48), SizedBox(height: 10), SkeletonBox(height: 48)]);
    }
    if (_query.text.trim().isEmpty) {
      return ListView(
        controller: scroll,
        padding: const EdgeInsets.all(22),
        children: [HandNote(s('search.idle.note'), color: Palette.inkFaint)],
      );
    }
    if (_hits.isEmpty) {
      return ListView(
        controller: scroll,
        padding: const EdgeInsets.all(22),
        children: [HandNote(s('search.empty.title'), color: Palette.inkFaint)],
      );
    }
    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: _hits.length,
      itemBuilder: (context, i) {
        final h = _hits[i];
        return RecipeRowTile(recipe: h.recipe, dish: h.dish, dense: true, onTap: () => Navigator.of(context).pop(h.recipe.id));
      },
    );
  }
}
