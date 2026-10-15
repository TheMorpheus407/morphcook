import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dish.dart';
import '../models/recipe.dart';
import '../services/matching_engine.dart';
import '../state/app_state.dart';
import '../theme/nostalgic_theme.dart';
import '../widgets/nostalgic_widgets.dart';
import 'cook_mode_screen.dart';
import 'faq_screen.dart';

class DishDetailScreen extends StatefulWidget {
  final Dish dish;
  final Recipe initialRecipe;

  const DishDetailScreen({
    super.key,
    required this.dish,
    required this.initialRecipe,
  });

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  late Recipe _currentRecipe;
  List<Recipe> _allVariants = [];
  Set<String> _changedIngredientIds = {};
  bool _ignoreCalorieFilter = false;
  int _selectedServings = 2;
  int _activeTab = 0; // 0: ingredients, 1: method, 2: macros
  int _morphGeneration = 0;

  @override
  void initState() {
    super.initState();
    _currentRecipe = widget.initialRecipe;
    _selectedServings = widget.initialRecipe.servings;
    _loadVariants();
  }

  Future<void> _loadVariants() async {
    final appState = context.read<MorphCookAppState>();
    final variants = await appState.corpus.variantsForDish(widget.dish.id);
    if (!mounted) return;
    setState(() {
      _allVariants = variants.isNotEmpty ? variants : [_currentRecipe];
    });
  }

  void _switchVariant(Recipe nextRecipe) {
    if (nextRecipe.id == _currentRecipe.id) return;
    final previousIds = _currentRecipe.ingredientIds;
    final previousAmounts = {
      for (final ing in _currentRecipe.ingredients) ing.id: ing.amount,
    };

    final changed = <String>{};
    for (final ing in nextRecipe.ingredients) {
      if (!previousIds.contains(ing.id) ||
          previousAmounts[ing.id] != ing.amount) {
        changed.add(ing.id);
      }
    }

    setState(() {
      _currentRecipe = nextRecipe;
      _selectedServings = nextRecipe.servings;
      _changedIngredientIds = changed;
      _morphGeneration += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MorphCookAppState>();
    final lang = appState.lang;
    final isDe = lang == 'de';
    final isSaved = appState.isRecipeSaved(_currentRecipe.id);

    final variants =
        _allVariants.isNotEmpty ? _allVariants : [_currentRecipe];

    final matrix = MatchingEngine.buildDimensionMatrix(
      allDishVariants: variants,
      currentRecipe: _currentRecipe,
      profile: appState.profile,
      ontology: appState.ontology,
      dictionary: appState.ingredients,
      ignoreCalorieFilter:
          _ignoreCalorieFilter || !appState.profile.calorieFilterEnabled,
    );

    final scaleFactor = _selectedServings / _currentRecipe.servings;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.dish.canonicalName.resolve(lang).toLowerCase(),
          style: NostalgicTheme.serifDisplay(fontSize: 22),
        ),
        actions: [
          IconButton(
            tooltip: isDe ? 'Hilfe & FAQ' : 'Help & FAQ',
            icon: const Icon(Icons.help_outline, size: 20),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const FaqScreen(initialContextKey: 'variant_switcher'),
                ),
              );
            },
          ),
          IconButton(
            key: const ValueKey('dish_detail_save_btn'),
            tooltip: isDe ? 'Variante im Kochbuch speichern' : 'Save variant to Cookbook',
            icon: Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: isSaved
                  ? NostalgicPalette.terracotta
                  : NostalgicPalette.ink,
            ),
            onPressed: () => appState.toggleSaveRecipe(_currentRecipe.id),
          ),
        ],
      ),
      body: PaperGrainBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Polaroid Hero Image with Striped Placeholder & Handwritten Caption
              StripedPlaceholderArtwork(
                stripeColor: widget.dish.stripeColor,
                caption: widget.dish.capCaption.resolve(lang),
                badgeText:
                    '${_currentRecipe.dietDimension}  ·  ${_currentRecipe.timeMinutes}m  ·  ~${_currentRecipe.caloriesPerServing} kcal',
                height: 170,
              ),
              const SizedBox(height: 14),

              // Active Recipe Title & Subtitle (AnimatedSwitcher for smooth morph)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: Column(
                  key: ValueKey(_currentRecipe.id),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentRecipe.title.resolve(lang),
                      style: NostalgicTheme.serifDisplay(fontSize: 25),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _currentRecipe.subtitle.resolve(lang),
                      style: NostalgicTheme.serifBody(
                        fontSize: 15,
                        color: NostalgicPalette.fadedInk,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const DashedRule(),
              const SizedBox(height: 6),

              // Per-Dimension Variant Switchers ("the money shot" from SPEC.md)
              DimensionVariantSwitcher(
                dimensionLabel: isDe ? 'ernährung' : 'diet',
                activeValueLabel: _currentRecipe.dietDimension,
                options: matrix.dietOptions,
                onSelectRecipe: _switchVariant,
              ),
              DimensionVariantSwitcher(
                dimensionLabel: isDe ? 'aufwand' : 'effort',
                activeValueLabel: _currentRecipe.effort,
                options: matrix.effortOptions,
                onSelectRecipe: _switchVariant,
              ),
              DimensionVariantSwitcher(
                dimensionLabel: isDe ? 'kalorien-stufe' : 'calorie level',
                activeValueLabel: '~${_currentRecipe.caloriesPerServing}',
                options: matrix.calorieOptions,
                onSelectRecipe: _switchVariant,
              ),

              // Per-dish calorie target override switch
              if (appState.profile.calorieFilterEnabled)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tune,
                        size: 15,
                        color: NostalgicPalette.terracotta,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isDe
                              ? 'Versionen außerhalb des Kalorienziels zeigen'
                              : 'Show versions outside calorie target',
                          style: NostalgicTheme.mono(
                            fontSize: 11,
                            color: NostalgicPalette.fadedInk,
                          ),
                        ),
                      ),
                      Switch(
                        key: const ValueKey('per_dish_calorie_override_switch'),
                        value: _ignoreCalorieFilter,
                        activeThumbColor: NostalgicPalette.terracotta,
                        onChanged: (v) =>
                            setState(() => _ignoreCalorieFilter = v),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 6),
              const DashedRule(),
              const SizedBox(height: 12),

              // Quick Action Bar: Start Cook Mode, Shopping List, Meal Plan
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('start_cook_mode_btn'),
                      style: FilledButton.styleFrom(
                        backgroundColor: NostalgicPalette.ink,
                        foregroundColor: NostalgicPalette.cardStock,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.outdoor_grill_outlined, size: 18),
                      label: Text(
                        isDe ? 'kochmodus starten' : 'start cook mode',
                        style: NostalgicTheme.mono(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: NostalgicPalette.cardStock,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CookModeScreen(
                              recipe: _currentRecipe,
                              dish: widget.dish,
                              initialServings: _selectedServings,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('add_to_shopping_btn'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: NostalgicPalette.ink,
                      side: const BorderSide(color: NostalgicPalette.mutedRule),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.shopping_basket_outlined, size: 17),
                    label: Text(
                      isDe ? '+ einkauf' : '+ shop',
                      style: NostalgicTheme.mono(
                        fontSize: 11.5,
                        color: NostalgicPalette.ink,
                      ),
                    ),
                    onPressed: () async {
                      await appState.addRecipeToShoppingList(
                        _currentRecipe,
                        targetServings: _selectedServings,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isDe
                                ? 'Zutaten zur Einkaufsliste hinzugefügt.'
                                : 'Added ingredients to Smart Shopping List.',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: isDe ? 'Zum Wochenplan' : 'Add to Meal Plan',
                    icon: const Icon(Icons.calendar_today_outlined, size: 17),
                    onPressed: () => _showMealPlanAssignDialog(context, appState),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Section Switcher Tabs: [ingredients] [method] [macros] + Servings Scaler
              Row(
                children: [
                  _tabChip(
                    index: 0,
                    label: isDe ? 'zutaten' : 'ingredients',
                  ),
                  const SizedBox(width: 8),
                  _tabChip(
                    index: 1,
                    label: isDe ? 'zubereitung' : 'method',
                  ),
                  const SizedBox(width: 8),
                  _tabChip(
                    index: 2,
                    label: isDe ? 'nährwerte' : 'macros',
                  ),
                  const Spacer(),
                  // Servings scaler
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: NostalgicPalette.cardStock,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: NostalgicPalette.mutedRule),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          key: const ValueKey('servings_dec_btn'),
                          onTap: _selectedServings > 1
                              ? () => setState(() => _selectedServings -= 1)
                              : null,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.remove, size: 14),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '$_selectedServings ${isDe ? "Port." : "serv"}',
                            style: NostalgicTheme.mono(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: NostalgicPalette.ink,
                            ),
                          ),
                        ),
                        InkWell(
                          key: const ValueKey('servings_inc_btn'),
                          onTap: _selectedServings < 12
                              ? () => setState(() => _selectedServings += 1)
                              : null,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.add, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (_activeTab == 0)
                _buildIngredientsList(appState, lang, scaleFactor),
              if (_activeTab == 1) _buildMethodSteps(lang),
              if (_activeTab == 2) _buildMacrosCard(lang),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabChip({required int index, required String label}) {
    final active = _activeTab == index;
    return InkWell(
      key: ValueKey('dish_tab_$index'),
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? NostalgicPalette.ink
              : NostalgicPalette.cardStock,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: active
                ? NostalgicPalette.ink
                : NostalgicPalette.mutedRule,
          ),
        ),
        child: Text(
          '[$label]',
          style: NostalgicTheme.mono(
            fontSize: 11.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active
                ? NostalgicPalette.cardStock
                : NostalgicPalette.fadedInk,
          ),
        ),
      ),
    );
  }

  Widget _buildIngredientsList(
    MorphCookAppState appState,
    String lang,
    double scaleFactor,
  ) {
    final isDe = lang == 'de';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _currentRecipe.ingredients.map((ing) {
        final isHighlighted = _changedIngredientIds.contains(ing.id);
        final guideEntry = appState.ingredientGuide[ing.id];

        return TweenAnimationBuilder<double>(
          key: ValueKey('${_currentRecipe.id}_${ing.id}_$_morphGeneration'),
          tween: Tween<double>(begin: isHighlighted ? 1.0 : 0.0, end: 0.0),
          duration: const Duration(milliseconds: 900),
          builder: (context, flashValue, child) {
            final bgColor = Color.lerp(
              NostalgicPalette.cardStock,
              NostalgicPalette.saffron.withValues(alpha: 0.42),
              flashValue,
            )!;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isHighlighted
                      ? NostalgicPalette.terracotta.withValues(alpha: 0.65)
                      : NostalgicPalette.mutedRule,
                ),
              ),
              child: child,
            );
          },
          child: Row(
            children: [
              SizedBox(
                width: 78,
                child: Text(
                  '${ing.formattedAmount(scaleFactor)} ${ing.unit}',
                  style: NostalgicTheme.mono(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: NostalgicPalette.terracotta,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  ing.name.resolve(lang),
                  style: NostalgicTheme.serifBody(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (guideEntry != null)
                TextButton.icon(
                  key: ValueKey('learn_more_${ing.id}'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(
                    Icons.menu_book_outlined,
                    size: 14,
                    color: NostalgicPalette.sage,
                  ),
                  label: Text(
                    isDe ? 'Mehr erfahren' : 'Learn more',
                    style: NostalgicTheme.mono(
                      fontSize: 10.5,
                      color: NostalgicPalette.sage,
                    ),
                  ),
                  onPressed: () {
                    IngredientLearnMoreSheet.show(
                      context,
                      entry: guideEntry,
                      lang: lang,
                    );
                  },
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMethodSteps(String lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _currentRecipe.steps.map((step) {
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: NostalgicPalette.cardStock,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: NostalgicPalette.mutedRule),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: NostalgicPalette.agedPaper,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'step 0${step.stepNumber}',
                      style: NostalgicTheme.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: NostalgicPalette.terracotta,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      step.title.resolve(lang),
                      style: NostalgicTheme.serifDisplay(
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  if (step.timerSeconds != null)
                    Text(
                      '⏱ ${(step.timerSeconds! / 60).round()}m',
                      style: NostalgicTheme.mono(
                        fontSize: 11,
                        color: NostalgicPalette.sage,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                step.instruction.resolve(lang),
                style: NostalgicTheme.serifBody(fontSize: 15),
              ),
              if (step.tip != null) ...[
                const SizedBox(height: 8),
                Text(
                  '✎ ${step.tip!.resolve(lang)}',
                  style: NostalgicTheme.handwritten(
                    fontSize: 17.5,
                    color: NostalgicPalette.fadedInk,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMacrosCard(String lang) {
    final isDe = lang == 'de';
    final m = _currentRecipe.macros;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NostalgicPalette.cardStock,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: NostalgicPalette.mutedRule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isDe ? 'nährwerte pro portion' : 'nutrition per serving',
            style: NostalgicTheme.mono(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: NostalgicPalette.ink,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _macroStat('kcal', '${m.calories}'),
              _macroStat(isDe ? 'protein' : 'protein', '${m.proteinG}g'),
              _macroStat(isDe ? 'kohlenh.' : 'carbs', '${m.carbsG}g'),
              _macroStat(isDe ? 'fett' : 'fat', '${m.fatG}g'),
              _macroStat(isDe ? 'ballastst.' : 'fiber', '${m.fiberG}g'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: NostalgicTheme.serifDisplay(
            fontSize: 20,
            color: NostalgicPalette.terracotta,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: NostalgicTheme.mono(fontSize: 11),
        ),
      ],
    );
  }

  Future<void> _showMealPlanAssignDialog(
    BuildContext context,
    MorphCookAppState appState,
  ) async {
    final isDe = appState.lang == 'de';
    final weekKey = MorphCookAppState.isoWeekKey(appState.now);
    const days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    const meals = ['breakfast', 'lunch', 'dinner'];
    String selectedDay = 'mon';
    String selectedMeal = 'dinner';

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: NostalgicPalette.parchment,
              title: Text(
                isDe ? 'Im Wochenplan einplanen' : 'Assign to Weekly Meal Plan',
                style: NostalgicTheme.serifDisplay(fontSize: 21),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentRecipe.title.resolve(appState.lang),
                    style: NostalgicTheme.serifBody(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDay,
                    decoration: InputDecoration(
                      labelText: isDe ? 'Wochentag' : 'Day',
                    ),
                    items: days
                        .map((d) => DropdownMenuItem(
                              value: d,
                              child: Text(d.toUpperCase()),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedDay = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMeal,
                    decoration: InputDecoration(
                      labelText: isDe ? 'Mahlzeit' : 'Meal',
                    ),
                    items: meals
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedMeal = v);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(isDe ? 'Abbrechen' : 'Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    await appState.assignMealSlot(
                      weekKey: weekKey,
                      slotKey: '$selectedDay.$selectedMeal',
                      recipeId: _currentRecipe.id,
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: Text(isDe ? 'Einplanen' : 'Assign'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
