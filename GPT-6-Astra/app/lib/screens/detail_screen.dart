import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/matching.dart';
import '../ui/design.dart';
import 'cook_screen.dart';
import 'help_screen.dart';

class DetailScreen extends StatefulWidget {
  final AppState state;
  final Recipe recipe;
  const DetailScreen({super.key, required this.state, required this.recipe});
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Recipe recipe;
  late double servings;
  bool ignoreCalories = false;
  int tab = 0;
  final expanded = <String>{};
  Set<String> changed = {};
  final checked = <String>{};
  @override
  void initState() {
    super.initState();
    recipe = widget.recipe;
    servings = recipe.servings.toDouble();
    _load();
  }

  Future<void> _load() async {
    final dish = widget.state.repo.dishById(recipe.dishId);
    if (dish != null) await widget.state.repo.loadForDish(dish);
    if (mounted) {
      setState(() {});
    }
  }

  String _value(Recipe r, String id) => switch (id) {
    'diet' => r.diet,
    'effort' => r.effort,
    'calorie_level' => r.calorieLevel,
    _ => r.dimensions[id] ?? '',
  };
  bool _allowed(Recipe r) => visible(
    r,
    widget.state.profile,
    ingredients: widget.state.repo.ingredients,
    ontology: widget.state.repo.ontology,
    ignoreCalories: ignoreCalories,
  );
  List<Map<String, dynamic>> get dimensions {
    final raw = widget.state.repo.ontology['dimensions'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [
      {
        'id': 'diet',
        'label': {'en': 'diet', 'de': 'Ernährung'},
        'values': ['classic', 'vegetarian', 'vegan', 'keto', 'halal']
            .map(
              (x) => {
                'id': x,
                'label': {'en': x, 'de': x},
              },
            )
            .toList(),
      },
      {
        'id': 'effort',
        'label': {'en': 'effort', 'de': 'Aufwand'},
        'values': ['easy', 'medium', 'hard']
            .map(
              (x) => {
                'id': x,
                'label': {'en': x, 'de': x},
              },
            )
            .toList(),
      },
      {
        'id': 'calorie_level',
        'label': {'en': 'calorie level', 'de': 'Kalorien'},
        'values': ['light', 'balanced', 'hearty']
            .map(
              (x) => {
                'id': x,
                'label': {'en': x, 'de': x},
              },
            )
            .toList(),
      },
    ];
  }

  void _switch(Recipe next) {
    final prev = recipe.ingredients
        .map((i) => '${i.id}:${i.quantity}:${i.unit}')
        .toSet();
    setState(() {
      changed = next.ingredients
          .where((i) => !prev.contains('${i.id}:${i.quantity}:${i.unit}'))
          .map((i) => i.id)
          .toSet();
      recipe = next;
      checked.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final dish = s.repo.dishById(recipe.dishId)!;
    return AnimatedBuilder(
      animation: s,
      builder: (context, _) => PaperScaffold(
        appBar: AppBar(
          title: Text(localized(dish.name, s.profile.lang)),
          actions: [
            IconButton(
              tooltip: tr(s, 'Help with recipes', 'Hilfe zu Rezepten'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => HelpScreen(state: s)),
              ),
              icon: const Icon(Icons.help_outline, size: 21),
            ),
            IconButton(
              tooltip: tr(
                s,
                s.isSaved(recipe.id)
                    ? 'Remove from cookbook'
                    : 'Save this recipe',
                s.isSaved(recipe.id)
                    ? 'Aus Kochbuch entfernen'
                    : 'Dieses Rezept speichern',
              ),
              onPressed: () {
                s.toggleSaved(recipe.id);
                toast(
                  context,
                  tr(
                    s,
                    s.isSaved(recipe.id)
                        ? 'A keeper. Saved to your cookbook.'
                        : 'Removed from your cookbook.',
                    s.isSaved(recipe.id)
                        ? 'Ein Lieblingsrezept. Im Kochbuch gespeichert.'
                        : 'Aus deinem Kochbuch entfernt.',
                  ),
                );
              },
              icon: Icon(
                s.isSaved(recipe.id) ? Icons.bookmark : Icons.bookmark_border,
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
          decoration: const BoxDecoration(
            color: Palette.paper,
            border: Border(top: BorderSide(color: Palette.line)),
          ),
          child: SafeArea(
            top: false,
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: _allowed(recipe)
                            ? () {
                                s.addRecipesToShopping([
                                  recipe,
                                ], multiplier: servings / recipe.servings);
                                toast(
                                  context,
                                  tr(
                                    s,
                                    'Ingredients added to your shopping list.',
                                    'Zutaten zur Einkaufsliste hinzugefügt.',
                                  ),
                                );
                              }
                            : null,
                        icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                        label: Text(
                          tr(s, 'Add to list', 'Auf die Liste'),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        label: tr(s, 'Let’s cook', 'Loskochen'),
                        icon: Icons.arrow_forward,
                        onPressed: _allowed(recipe)
                            ? () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => CookScreen(
                                    state: s,
                                    recipe: recipe,
                                    servings: servings,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 940),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      color: Palette.white,
                      padding: const EdgeInsets.fromLTRB(9, 9, 9, 15),
                      child: Column(
                        children: [
                          StripeArt(
                            color: stripeColor(dish.color),
                            height: 230,
                            label: localized(
                              dish.name,
                              s.profile.lang,
                            ).toLowerCase(),
                          ),
                          const SizedBox(height: 12),
                          hand(
                            localized(dish.caption, s.profile.lang),
                            size: 26,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    mono(
                      tr(
                        s,
                        'SOMETHING GOOD IS COOKING',
                        'HIER ENTSTEHT ETWAS GUTES',
                      ),
                      size: 9,
                      color: Palette.coral,
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: Duration(
                        milliseconds: MediaQuery.of(context).disableAnimations
                            ? 0
                            : 260,
                      ),
                      child: Align(
                        key: ValueKey(recipe.id),
                        alignment: Alignment.centerLeft,
                        child: display(
                          localized(recipe.title, s.profile.lang).toLowerCase(),
                          size: 42,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      localized(recipe.description, s.profile.lang),
                      style: const TextStyle(
                        color: Palette.muted,
                        fontSize: 12,
                        height: 1.9,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 23,
                      runSpacing: 10,
                      children: [
                        mono(
                          '${recipe.timeMinutes} MIN',
                          size: 10,
                          color: Palette.ink,
                        ),
                        mono(
                          '${recipe.calories} KCAL',
                          size: 10,
                          color: Palette.ink,
                        ),
                        mono(
                          effortLabel(s, recipe.effort).toUpperCase(),
                          size: 10,
                          color: Palette.ink,
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    const DashedRule(),
                    const SizedBox(height: 12),
                    ...dimensions.map((d) => _dimension(s, d)),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        tr(
                          s,
                          'Explore beyond my calorie target',
                          'Außerhalb meines Kalorienziels entdecken',
                        ),
                        style: const TextStyle(fontSize: 11),
                      ),
                      subtitle: Text(
                        tr(
                          s,
                          'Dietary and ingredient preferences always apply.',
                          'Ernährungs- und Zutatenwünsche gelten weiterhin.',
                        ),
                        style: const TextStyle(
                          fontSize: 9,
                          color: Palette.muted,
                        ),
                      ),
                      value: ignoreCalories,
                      onChanged: (value) {
                        setState(() => ignoreCalories = value);
                        if (!value && !_allowed(recipe)) {
                          final next = s.repo.recipes
                              .where(
                                (r) => r.dishId == recipe.dishId && _allowed(r),
                              )
                              .firstOrNull;
                          if (next != null) {
                            _switch(next);
                          }
                        }
                      },
                    ),
                    if (!_allowed(recipe))
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Palette.butter.withValues(alpha: .5),
                        child: Text(
                          tr(
                            s,
                            'This saved recipe no longer fits your preferences. Choose an available version above, or review your settings.',
                            'Dieses gespeicherte Rezept passt nicht mehr zu deinen Wünschen. Wähle oben eine verfügbare Version oder prüfe die Einstellungen.',
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        for (final item in [
                          (0, tr(s, 'ingredients', 'Zutaten')),
                          (1, tr(s, 'method', 'Zubereitung')),
                          (2, tr(s, 'nutrition', 'Nährwerte')),
                        ])
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => tab = item.$1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: tab == item.$1
                                          ? Palette.ink
                                          : Palette.line,
                                      width: tab == item.$1 ? 2 : 1,
                                    ),
                                  ),
                                ),
                                child: Center(
                                  child: mono(
                                    item.$2.toUpperCase(),
                                    size: 9,
                                    color: tab == item.$1
                                        ? Palette.ink
                                        : Palette.muted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    if (tab == 0)
                      _ingredients(s)
                    else if (tab == 1)
                      _method(s)
                    else
                      _nutrition(s),
                    const SizedBox(height: 20),
                    const DashedRule(),
                    const SizedBox(height: 20),
                    Center(
                      child: hand(
                        tr(
                          s,
                          'take your time. taste as you go.',
                          'lass dir Zeit. probier zwischendurch.',
                        ),
                        size: 26,
                        color: Palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dimension(AppState s, Map<String, dynamic> d) {
    final id = d['id'].toString();
    final values = (d['values'] as List? ?? [])
        .map(
          (v) => v is Map
              ? Map<String, dynamic>.from(v)
              : <String, dynamic>{
                  'id': v.toString(),
                  'label': {'en': v.toString(), 'de': v.toString()},
                },
        )
        .toList();
    final selected = values
        .where((v) => v['id'] == _value(recipe, id))
        .firstOrNull;
    final label = localized(
      localizedMap(selected?['label'] ?? {'en': _value(recipe, id)}),
      s.profile.lang,
    );
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Palette.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(
              () => expanded.contains(id)
                  ? expanded.remove(id)
                  : expanded.add(id),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 17),
              child: Row(
                children: [
                  mono(
                    localized(
                      localizedMap(d['label']),
                      s.profile.lang,
                    ).toUpperCase(),
                    size: 9,
                  ),
                  const SizedBox(width: 15),
                  const Expanded(child: DashedRule()),
                  const SizedBox(width: 15),
                  Flexible(
                    child: Text(label, style: const TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    expanded.contains(id)
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (expanded.contains(id))
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: values.map((v) {
                      final value = v['id'].toString();
                      final candidates = s.repo.recipes
                          .where(
                            (r) =>
                                r.dishId == recipe.dishId &&
                                _value(r, id) == value &&
                                dimensions
                                    .where((other) => other['id'] != id)
                                    .every(
                                      (other) =>
                                          _value(r, other['id'].toString()) ==
                                          _value(
                                            recipe,
                                            other['id'].toString(),
                                          ),
                                    ) &&
                                _allowed(r),
                          )
                          .toList();
                      final current = _value(recipe, id) == value;
                      return Tooltip(
                        message: candidates.isEmpty
                            ? tr(
                                s,
                                'This combination is not available for your preferences yet.',
                                'Diese Kombination ist für deine Wünsche noch nicht verfügbar.',
                              )
                            : '',
                        child: ChoiceChip(
                          showCheckmark: false,
                          selected: current,
                          label: Text(
                            localized(localizedMap(v['label']), s.profile.lang),
                            style: TextStyle(
                              color: current
                                  ? Palette.white
                                  : candidates.isEmpty
                                  ? Palette.muted
                                  : Palette.ink,
                            ),
                          ),
                          onSelected: candidates.isEmpty
                              ? null
                              : (_) => _switch(candidates.first),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 9),
                  mono(
                    tr(
                      s,
                      'Faded options: this combination isn’t available yet.',
                      'Blasse Optionen: diese Kombination gibt es noch nicht.',
                    ),
                    size: 8,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _ingredients(AppState s) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: hand(
              tr(s, 'a little of this & that', 'ein bisschen hiervon & davon'),
              size: 26,
            ),
          ),
          IconButton(
            tooltip: tr(s, 'Fewer servings', 'Weniger Portionen'),
            onPressed: servings > 1 ? () => setState(() => servings--) : null,
            icon: const Icon(Icons.remove_circle_outline, size: 20),
          ),
          mono(
            '${servings.toInt()} ${tr(s, 'SERVINGS', 'PORTIONEN')}',
            size: 8,
            color: Palette.ink,
          ),
          IconButton(
            tooltip: tr(s, 'More servings', 'Mehr Portionen'),
            onPressed: servings < 24 ? () => setState(() => servings++) : null,
            icon: const Icon(Icons.add_circle_outline, size: 20),
          ),
        ],
      ),
      const SizedBox(height: 10),
      ...recipe.ingredients.map((item) {
        final ingredient = s.repo.ingredientById(item.id);
        final quantity = item.quantity * servings / recipe.servings;
        return TweenAnimationBuilder<double>(
          key: ValueKey('${recipe.id}-${item.id}'),
          duration: Duration(
            milliseconds: MediaQuery.of(context).disableAnimations ? 0 : 1200,
          ),
          tween: Tween(begin: changed.contains(item.id) ? 1 : 0, end: 0),
          builder: (context, highlight, child) => Container(
            color: Palette.butter.withValues(alpha: highlight * .7),
            child: child,
          ),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Palette.line)),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: checked.contains(item.id),
                  onChanged: (_) => setState(
                    () => checked.contains(item.id)
                        ? checked.remove(item.id)
                        : checked.add(item.id),
                  ),
                ),
                Expanded(
                  child: Text(
                    localized(
                      ingredient?.name ?? {'en': item.id},
                      s.profile.lang,
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      decoration: checked.contains(item.id)
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                Text(
                  '${_quantity(quantity)} ${_unit(s, item.unit)}',
                  style: const TextStyle(fontSize: 10),
                ),
                IconButton(
                  tooltip: tr(s, 'Learn more', 'Mehr erfahren'),
                  onPressed: () => _guide(s, item.id),
                  icon: const Icon(
                    Icons.info_outline,
                    size: 17,
                    color: Palette.muted,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    ],
  );
  String _quantity(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);
  String _unit(AppState s, String unit) => s.profile.lang == 'de'
      ? {
              'tbsp': 'EL',
              'tsp': 'TL',
              'clove': 'Zehe(n)',
              'cloves': 'Zehen',
              'piece': 'Stück',
              'pieces': 'Stück',
              'pinch': 'Prise',
              'can': 'Dose',
              'bunch': 'Bund',
            }[unit] ??
            unit
      : unit;
  Widget _method(AppState s) => Column(
    children: List.generate(
      recipe.steps.length,
      (i) => Padding(
        padding: const EdgeInsets.only(bottom: 25),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 42,
              child: display(
                '${i + 1}'.padLeft(2, '0'),
                size: 26,
                color: Palette.coral,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  display(
                    localized(recipe.steps[i].title, s.profile.lang),
                    size: 23,
                  ),
                  const SizedBox(height: 9),
                  Text(
                    localized(recipe.steps[i].text, s.profile.lang),
                    style: const TextStyle(fontSize: 12, height: 1.9),
                  ),
                  if (recipe.steps[i].timerSeconds > 0) ...[
                    const SizedBox(height: 10),
                    mono(
                      '${(recipe.steps[i].timerSeconds / 60).ceil()} MIN',
                      size: 9,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _nutrition(AppState s) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      hand(tr(s, 'the little details', 'die kleinen Details'), size: 28),
      const SizedBox(height: 18),
      ...[
        (tr(s, 'Energy', 'Energie'), '${recipe.calories} kcal'),
        (tr(s, 'Protein', 'Eiweiß'), '${recipe.nutrition['protein'] ?? 0} g'),
        (
          tr(s, 'Carbohydrates', 'Kohlenhydrate'),
          '${recipe.nutrition['carbs'] ?? 0} g',
        ),
        (tr(s, 'Fat', 'Fett'), '${recipe.nutrition['fat'] ?? 0} g'),
      ].map(
        (entry) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(entry.$1),
              mono(entry.$2, color: Palette.ink),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      Text(
        tr(
          s,
          'Estimates per serving. Ingredients and brands can vary.',
          'Schätzwerte pro Portion. Zutaten und Marken können abweichen.',
        ),
        style: const TextStyle(color: Palette.muted, fontSize: 10),
      ),
    ],
  );
  void _guide(AppState s, String id) {
    final ingredient = s.repo.ingredientById(id);
    final guide = s.repo.guides.where((g) => g['id'] == id).firstOrNull;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              mono(
                tr(s, 'THE KITCHEN REFERENCE', 'DAS KÜCHENLEXIKON'),
                size: 9,
              ),
              const SizedBox(height: 12),
              display(
                localized(ingredient?.name ?? {'en': id}, s.profile.lang),
                size: 34,
              ),
              const SizedBox(height: 20),
              if (guide == null)
                Text(
                  '${tr(s, 'Find this ingredient in', 'Du findest diese Zutat bei')} ${localized(ingredient?.aisle ?? {}, s.profile.lang)}.',
                )
              else
                ...[
                  (
                    'description',
                    tr(s, 'A little introduction', 'Kurz vorgestellt'),
                  ),
                  ('usage', tr(s, 'In the kitchen', 'In der Küche')),
                  ('storage', tr(s, 'Keep it fresh', 'Frisch halten')),
                  ('where', tr(s, 'Where to find it', 'Wo du es findest')),
                ].map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionLabel(e.$2),
                        Text(
                          localized(localizedMap(guide[e.$1]), s.profile.lang),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
