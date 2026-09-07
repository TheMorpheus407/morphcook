import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../ui/design.dart';

class PlannerScreen extends StatefulWidget {
  final AppState state;
  final void Function(Recipe)? onOpenRecipe;
  final DateTime? initialDate;
  const PlannerScreen({
    super.key,
    required this.state,
    this.onOpenRecipe,
    this.initialDate,
  });
  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  late DateTime _monday;
  @override
  void initState() {
    super.initState();
    _monday = mondayOfWeek(widget.initialDate ?? DateTime.now());
  }

  DateTime _offsetDay(int days) =>
      DateTime(_monday.year, _monday.month, _monday.day + days);
  final _days = const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  final _meals = const ['breakfast', 'lunch', 'dinner'];
  AppState get s => widget.state;
  String get _week => weekKey(_monday);
  Recipe? _recipe(String? id) {
    if (id == null) return null;
    for (final r in s.repo.recipes) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<void> _pick(String slot) async {
    final choice = await showModalBottomSheet<Recipe>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Palette.paper,
      builder: (_) => _RecipePicker(state: s),
    );
    if (choice != null) s.assignMeal(_week, slot, choice.id);
  }

  Future<void> _slotActions(String slot, Recipe recipe) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Palette.paper,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              display(localized(recipe.title, s.profile.lang), size: 27),
              const SizedBox(height: 18),
              if (widget.onOpenRecipe != null)
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(tr(s, 'Open recipe', 'Rezept öffnen')),
                  onTap: () => Navigator.pop(context, 'open'),
                ),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text(
                  tr(s, 'Choose another recipe', 'Anderes Rezept wählen'),
                ),
                onTap: () => Navigator.pop(context, 'change'),
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: Text(tr(s, 'Clear this meal', 'Mahlzeit entfernen')),
                onTap: () => Navigator.pop(context, 'clear'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'open') widget.onOpenRecipe?.call(recipe);
    if (choice == 'change') _pick(slot);
    if (choice == 'clear') s.assignMeal(_week, slot, null);
  }

  void _export() {
    final recipes = (s.mealPlan[_week] ?? {}).values
        .map(_recipe)
        .whereType<Recipe>()
        .toList();
    if (recipes.isEmpty) return;
    s.addRecipesToShopping(recipes);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(
            s,
            '${recipes.length} meals added to your shopping list.',
            '${recipes.length} Mahlzeiten zur Einkaufsliste hinzugefügt.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: s,
    builder: (context, _) {
      final selected = s.mealPlan[_week] ?? {};
      final end = _offsetDay(6);
      final names = s.profile.lang == 'de'
          ? ['MO', 'DI', 'MI', 'DO', 'FR', 'SA', 'SO']
          : ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
      final labels = [
        tr(s, 'breakfast', 'Frühstück'),
        tr(s, 'lunch', 'Mittag'),
        tr(s, 'dinner', 'Abend'),
      ];
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  title: tr(s, 'a week, well fed.', 'eine gute Woche.'),
                  subtitle: tr(
                    s,
                    'A little intention. A lot to look forward to.',
                    'Ein kleiner Plan. Viel Vorfreude.',
                  ),
                ),
                const SizedBox(height: 25),
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Palette.ink),
                      bottom: BorderSide(color: Palette.ink),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: tr(s, 'Previous week', 'Vorherige Woche'),
                        onPressed: () =>
                            setState(() => _monday = _offsetDay(-7)),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            mono(
                              '${_monday.day.toString().padLeft(2, '0')}.${_monday.month.toString().padLeft(2, '0')} — ${end.day.toString().padLeft(2, '0')}.${end.month.toString().padLeft(2, '0')} / ${end.year}',
                              size: 12,
                            ),
                            TextButton(
                              onPressed: () => setState(
                                () => _monday = mondayOfWeek(DateTime.now()),
                              ),
                              child: Text(tr(s, 'this week', 'diese Woche')),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: tr(s, 'Next week', 'Nächste Woche'),
                        onPressed: () =>
                            setState(() => _monday = _offsetDay(7)),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    const SizedBox(width: 46),
                    for (final label in labels)
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: mono(label.toUpperCase(), size: 9),
                          ),
                        ),
                      ),
                  ],
                ),
                ...List.generate(7, (day) {
                  final date = _offsetDay(day);
                  final today = DateUtils.isSameDay(date, DateTime.now());
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 46,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 17),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                mono(
                                  names[day],
                                  size: 9,
                                  color: today ? Palette.coral : Palette.muted,
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: today
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: today ? Palette.coral : Palette.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        for (var meal = 0; meal < 3; meal++)
                          Expanded(
                            child: _slot(
                              '${_days[day]}.${_meals[meal]}',
                              _recipe(
                                selected['${_days[day]}.${_meals[meal]}'],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.touch_app_outlined,
                      size: 17,
                      color: Palette.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr(
                          s,
                          'Tap to plan. Hold a recipe to move it to another day.',
                          'Tippen zum Planen. Rezept halten und auf einen anderen Tag ziehen.',
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Palette.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                PrimaryButton(
                  label: tr(
                    s,
                    'Make this week’s shopping list',
                    'Einkaufsliste für diese Woche',
                  ),
                  icon: Icons.shopping_bag_outlined,
                  onPressed: selected.isEmpty ? null : _export,
                ),
                const SizedBox(height: 12),
                hand(
                  tr(
                    s,
                    'leave a little room for spontaneity.',
                    'ein bisschen Platz für Spontanität.',
                  ),
                  color: Palette.coral,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _slot(String slot, Recipe? recipe) {
    return DragTarget<_MealDrag>(
      onWillAcceptWithDetails: (details) =>
          details.data.sourceSlot != slot || details.data.sourceWeek != _week,
      onAcceptWithDetails: (details) {
        final drag = details.data;
        s.assignMeal(drag.sourceWeek, drag.sourceSlot, recipe?.id);
        s.assignMeal(_week, slot, drag.recipeId);
      },
      builder: (context, candidates, rejects) {
        final card = Container(
          margin: const EdgeInsets.fromLTRB(3, 0, 3, 7),
          constraints: const BoxConstraints(minHeight: 94),
          decoration: BoxDecoration(
            color: candidates.isNotEmpty
                ? Palette.sage
                : recipe == null
                ? Colors.transparent
                : const Color(0xFFEAEDE2),
            border: Border.all(
              color: candidates.isNotEmpty ? Palette.ink : Palette.line,
            ),
          ),
          child: InkWell(
            onTap: () =>
                recipe == null ? _pick(slot) : _slotActions(slot, recipe),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: recipe == null
                  ? const Center(
                      child: Icon(Icons.add, size: 19, color: Palette.muted),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          localized(recipe.title, s.profile.lang),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                            color: Palette.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        mono(
                          '${recipe.timeMinutes} MIN',
                          size: 8,
                          color: Palette.muted,
                        ),
                      ],
                    ),
            ),
          ),
        );
        if (recipe == null) return card;
        return LongPressDraggable<_MealDrag>(
          data: _MealDrag(recipe.id, _week, slot),
          feedback: Material(
            elevation: 8,
            color: Palette.sage,
            child: SizedBox(
              width: 150,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  localized(recipe.title, s.profile.lang),
                  style: const TextStyle(color: Palette.ink),
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: card),
          child: card,
        );
      },
    );
  }
}

class _MealDrag {
  final String recipeId, sourceWeek, sourceSlot;
  const _MealDrag(this.recipeId, this.sourceWeek, this.sourceSlot);
}

class _RecipePicker extends StatefulWidget {
  final AppState state;
  const _RecipePicker({required this.state});
  @override
  State<_RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends State<_RecipePicker> {
  String _query = '';
  bool _savedOnly = false;
  bool _loading = true;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await widget.state.repo.loadAll();
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final recipes = s
        .visibleRecipes()
        .where(
          (r) =>
              (!_savedOnly || s.saved.contains(r.id)) &&
              normalizeSearch(_query)
                  .split(RegExp(r'\s+'))
                  .every(s.repo.searchText(r, s.profile.lang).contains),
        )
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height:
              (MediaQuery.sizeOf(context).height * .82 -
                      MediaQuery.viewInsetsOf(context).bottom)
                  .clamp(240.0, double.infinity),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: display(
                        tr(s, 'what sounds good?', 'worauf hast du Lust?'),
                        size: 28,
                      ),
                    ),
                    IconButton(
                      tooltip: tr(s, 'Close', 'Schließen'),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  autofocus: true,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: tr(s, 'Find a recipe…', 'Rezept finden…'),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(tr(s, 'All recipes', 'Alle Rezepte')),
                      selected: !_savedOnly,
                      onSelected: (_) => setState(() => _savedOnly = false),
                    ),
                    ChoiceChip(
                      label: Text(tr(s, 'My cookbook', 'Mein Kochbuch')),
                      selected: _savedOnly,
                      onSelected: (_) => setState(() => _savedOnly = true),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _failed
                      ? Center(
                          child: TextButton(
                            onPressed: () {
                              setState(() => _loading = true);
                              _load();
                            },
                            child: Text(
                              tr(
                                s,
                                'Couldn’t open the cookbook. Try again.',
                                'Kochbuch konnte nicht geöffnet werden. Erneut versuchen.',
                              ),
                            ),
                          ),
                        )
                      : recipes.isEmpty
                      ? SingleChildScrollView(
                          child: EmptyState(
                            title: tr(s, 'a blank page.', 'eine leere Seite.'),
                            message: tr(
                              s,
                              'No matching recipes. Try another search or check your preferences.',
                              'Keine passenden Rezepte. Probiere eine andere Suche oder prüfe deine Vorlieben.',
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: recipes.length,
                          itemBuilder: (context, index) {
                            final r = recipes[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                              leading: Container(
                                width: 42,
                                height: 48,
                                color: Palette.sage,
                                child: const Icon(
                                  Icons.restaurant,
                                  size: 18,
                                  color: Palette.ink,
                                ),
                              ),
                              title: Text(localized(r.title, s.profile.lang)),
                              subtitle: Text(
                                '${r.timeMinutes} min · ${r.calories} kcal',
                              ),
                              trailing: const Icon(Icons.add, size: 19),
                              onTap: () => Navigator.pop(context, r),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
