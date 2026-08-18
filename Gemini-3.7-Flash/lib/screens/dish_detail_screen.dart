import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/dish.dart';
import '../models/recipe.dart';
import '../theme/vintage_theme.dart';
import '../widgets/vintage_widgets.dart';
import '../widgets/ingredient_guide_dialog.dart';
import 'cook_mode_screen.dart';

class DishDetailScreen extends StatefulWidget {
  final Dish dish;
  final String? initialVariantId;

  const DishDetailScreen({
    super.key,
    required this.dish,
    this.initialVariantId,
  });

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> with SingleTickerProviderStateMixin {
  late Recipe _currentVariant;
  late int _servings;
  bool _overrideCalorie = false;

  // Dimension expansion toggles
  final Map<String, bool> _dimensionExpanded = {
    'diet': false,
    'effort': false,
    'calorie': false,
  };

  // Dimension values currently picked
  final Map<String, String> _selectedDimensions = {};

  late AnimationController _morphAnimController;
  late Animation<double> _morphFadeAnimation;

  @override
  void initState() {
    super.initState();
    _morphAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _morphFadeAnimation = CurvedAnimation(
      parent: _morphAnimController,
      curve: Curves.easeInOut,
    );
    _morphAnimController.value = 1.0;

    final appState = Provider.of<AppState>(context, listen: false);
    final variants = appState.corpus.getVariantsForDish(widget.dish.id);

    if (widget.initialVariantId != null) {
      _currentVariant = variants.firstWhere(
        (v) => v.id == widget.initialVariantId,
        orElse: () => variants.isNotEmpty ? variants.first : _dummyRecipe(),
      );
    } else {
      final best = appState.getBestVariantForDish(widget.dish);
      _currentVariant = best ?? (variants.isNotEmpty ? variants.first : _dummyRecipe());
    }

    _servings = _currentVariant.servings > 0 ? _currentVariant.servings : 2;
    _syncDimensionValues();
  }

  @override
  void dispose() {
    _morphAnimController.dispose();
    super.dispose();
  }

  Recipe _dummyRecipe() {
    return Recipe(
      id: widget.dish.variantRecipeIds.isNotEmpty ? widget.dish.variantRecipeIds.first : 'dummy',
      dishId: widget.dish.id,
      title: widget.dish.name,
      description: widget.dish.heroText,
      variantDimensionValues: {'diet': 'classic', 'effort': 'medium'},
      servings: 2,
      prepTimeMinutes: 10,
      cookTimeMinutes: 15,
      totalTimeMinutes: 25,
      caloriesPerServing: 500,
      macros: const RecipeMacros(calories: 500, protein: 20, carbs: 50, fat: 15),
      contains: [],
      ingredientIds: [],
      attributes: [],
      ingredients: [],
      steps: [],
    );
  }

  void _syncDimensionValues() {
    _selectedDimensions['diet'] = _currentVariant.variantDimensionValues['diet'] ?? 'classic';
    _selectedDimensions['effort'] = _currentVariant.variantDimensionValues['effort'] ?? 'medium';
    _selectedDimensions['calorie'] = _currentVariant.variantDimensionValues['calorie'] ?? '${_currentVariant.caloriesPerServing}';
  }

  void _switchVariant(Recipe newVariant) {
    if (newVariant.id == _currentVariant.id) return;

    _morphAnimController.forward(from: 0.0).then((_) {
      setState(() {
        _currentVariant = newVariant;
        _servings = newVariant.servings;
        _syncDimensionValues();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final lang = appState.lang;
    final isSaved = appState.isRecipeSaved(_currentVariant.id);
    final allVariants = appState.corpus.getVariantsForDish(widget.dish.id);
    final scaledIngredients = _currentVariant.getScaledIngredients(_servings);

    return Scaffold(
      backgroundColor: VintageColors.paperBg,
      appBar: AppBar(
        title: Text(widget.dish.name.get(lang)),
        actions: [
          IconButton(
            icon: Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: isSaved ? VintageColors.terracotta : VintageColors.ink,
            ),
            tooltip: lang == 'de' ? 'Variante im Kochbuch speichern' : 'Save variant to cookbook',
            onPressed: () {
              appState.toggleSaveRecipe(_currentVariant.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: VintageColors.paperCard,
                  content: Text(
                    isSaved
                        ? (lang == 'de' ? 'Aus dem Kochbuch entfernt' : 'Removed from cookbook')
                        : (lang == 'de' ? 'Variante im Kochbuch gesichert' : 'Variant saved to cookbook'),
                    style: GoogleFonts.jetBrainsMono(color: VintageColors.ink),
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _morphFadeAnimation,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Hero Photo Placeholder
            PolaroidCard(
              rotationAngle: 0.0,
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StripedPlaceholder(
                    hexColor: widget.dish.stripeColor,
                    height: 180,
                    label: widget.dish.name.get(lang),
                    caption: widget.dish.capCaption.get(lang),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _currentVariant.title.get(lang),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      color: VintageColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _currentVariant.description.get(lang),
                    style: GoogleFonts.ebGaramond(
                      fontSize: 16,
                      color: VintageColors.inkLight,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Per-Dimension Variant Switchers
            _buildDimensionSwitchers(allVariants, lang),
            const SizedBox(height: 16),

            // Halal / Kosher Compatibility Disclaimer Note
            if (_selectedDimensions['diet'] == 'halal' || _selectedDimensions['diet'] == 'kosher') ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: VintageColors.paperSurface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: VintageColors.paperBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: VintageColors.inkLight),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lang == 'de'
                            ? 'MorphCook zeigt halal-/koscher-kompatible Zutaten (kein Schwein/Alkohol). Zertifizierung ist lieferkettenabhängig.'
                            : 'MorphCook surfaces halal/kosher compatible ingredients (no pork/alcohol). Physical certification depends on supplier sourcing.',
                        style: GoogleFonts.ebGaramond(fontSize: 13, color: VintageColors.inkLight),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Macro Pills Bar
            _buildMacroBar(lang),
            const SizedBox(height: 10),

            // Per-dish Calorie Target Override Switch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: VintageColors.paperCard,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: VintageColors.paperBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    lang == 'de' ? 'Varianten außerhalb des Kalorienziels anzeigen' : 'Show versions outside calorie target',
                    style: GoogleFonts.ebGaramond(fontSize: 14),
                  ),
                  Switch(
                    activeTrackColor: VintageColors.terracotta,
                    value: _overrideCalorie,
                    onChanged: (val) {
                      setState(() {
                        _overrideCalorie = val;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Ingredients Header & Servings Scaler
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  lang == 'de' ? 'Zutaten' : 'Ingredients',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                // Servings Scaler
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: VintageColors.paperCard,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: VintageColors.paperBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: _servings > 1 ? () => setState(() => _servings--) : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '$_servings ${lang == 'de' ? 'Portionen' : 'servings'}',
                          style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: _servings < 12 ? () => setState(() => _servings++) : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Scaled Ingredients List
            Container(
              decoration: BoxDecoration(
                color: VintageColors.paperCard,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: VintageColors.paperBorder),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < scaledIngredients.length; i++) ...[
                    _buildIngredientRow(scaledIngredients[i], appState, lang),
                    if (i < scaledIngredients.length - 1)
                      Divider(height: 1, color: VintageColors.paperBorder.withValues(alpha: 0.5)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Method / Steps Section
            Text(
              lang == 'de' ? 'Zubereitung' : 'Method & Steps',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 10),

            ..._currentVariant.steps.map((step) => _buildStepCard(step, lang)),
            const SizedBox(height: 24),

            // Primary Action Buttons
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: VintageColors.terracotta,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    icon: const Icon(Icons.restaurant_menu),
                    label: Text(
                      lang == 'de' ? 'KOCHMODUS STARTEN' : 'START COOK MODE',
                      style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, letterSpacing: 1.1),
                    ),
                    onPressed: () {
                      appState.startCookSession(_currentVariant.id, _servings);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CookModeScreen(
                            recipe: _currentVariant,
                            initialServings: _servings,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: VintageColors.ink),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    icon: const Icon(Icons.add_shopping_cart, size: 18, color: VintageColors.ink),
                    label: Text(
                      lang == 'de' ? 'Einkaufsliste' : 'Market List',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: VintageColors.ink,
                      ),
                    ),
                    onPressed: () {
                      appState.addRecipeIngredientsToShoppingList(_currentVariant, _servings);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: VintageColors.paperCard,
                          content: Text(
                            lang == 'de' ? 'Zutaten zur Einkaufsliste hinzugefügt' : 'Added to your market basket',
                            style: GoogleFonts.jetBrainsMono(color: VintageColors.ink),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDimensionSwitchers(List<Recipe> allVariants, String lang) {
    // Extract available values per dimension across this dish's variants
    final allDiets = allVariants.map((v) => v.variantDimensionValues['diet'] ?? 'classic').toSet().toList();
    final allEfforts = ['easy', 'medium', 'hard'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VintageColors.paperCard,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: VintageColors.paperBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDimensionRow(
            dimensionKey: 'diet',
            title: lang == 'de' ? 'Ernährung' : 'Diet Dimension',
            currentValue: _selectedDimensions['diet'] ?? 'classic',
            availableValues: allDiets,
            allVariants: allVariants,
            lang: lang,
          ),
          const Divider(height: 16),
          _buildDimensionRow(
            dimensionKey: 'effort',
            title: lang == 'de' ? 'Aufwand' : 'Effort Dimension',
            currentValue: _selectedDimensions['effort'] ?? 'medium',
            availableValues: allEfforts,
            allVariants: allVariants,
            lang: lang,
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionRow({
    required String dimensionKey,
    required String title,
    required String currentValue,
    required List<String> availableValues,
    required List<Recipe> allVariants,
    required String lang,
  }) {
    final isExpanded = _dimensionExpanded[dimensionKey] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _dimensionExpanded[dimensionKey] = !isExpanded),
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '— $title —'.toUpperCase(),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: VintageColors.inkLight,
                ),
              ),
              Row(
                children: [
                  Text(
                    currentValue.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: VintageColors.terracotta,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: VintageColors.inkLight,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: availableValues.map((val) {
              // Check if a recipe exists for this dimension value combination
              final matchingVariant = allVariants.firstWhere(
                (v) => (v.variantDimensionValues[dimensionKey] == val),
                orElse: () => _dummyRecipe(),
              );

              final exists = matchingVariant.id != 'dummy' &&
                  allVariants.any((v) => v.id == matchingVariant.id);

              final isSelected = currentValue == val;

              return ActionChip(
                label: Text(val.toUpperCase()),
                labelStyle: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: !exists
                      ? VintageColors.inkMuted
                      : (isSelected ? Colors.white : VintageColors.ink),
                ),
                backgroundColor: isSelected
                    ? VintageColors.terracotta
                    : (exists ? VintageColors.paperSurface : VintageColors.paperCard.withValues(alpha: 0.5)),
                side: BorderSide(
                  color: isSelected
                      ? VintageColors.terracotta
                      : (exists ? VintageColors.paperBorder : VintageColors.paperBorder.withValues(alpha: 0.4)),
                ),
                onPressed: exists
                    ? () {
                        _switchVariant(matchingVariant);
                      }
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: VintageColors.paperCard,
                            content: Text(
                              lang == 'de'
                                  ? 'Noch keine Kombination für $val verfügbar.'
                                  : 'No $val version authored yet for this dish.',
                              style: GoogleFonts.jetBrainsMono(color: VintageColors.ink),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildMacroBar(String lang) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: VintageColors.paperSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: VintageColors.paperBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMacroItem(lang == 'de' ? 'Kalorien' : 'Calories', '${_currentVariant.caloriesPerServing} kcal'),
          _buildMacroItem(lang == 'de' ? 'Protein' : 'Protein', '${_currentVariant.macros.protein}g'),
          _buildMacroItem(lang == 'de' ? 'Kohlenhydrate' : 'Carbs', '${_currentVariant.macros.carbs}g'),
          _buildMacroItem(lang == 'de' ? 'Fett' : 'Fat', '${_currentVariant.macros.fat}g'),
        ],
      ),
    );
  }

  Widget _buildMacroItem(String label, String val) {
    return Column(
      children: [
        Text(val, style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: VintageColors.ink)),
        Text(label, style: GoogleFonts.ebGaramond(fontSize: 12, color: VintageColors.inkLight)),
      ],
    );
  }

  Widget _buildIngredientRow(RecipeIngredient ing, AppState appState, String lang) {
    final guideEntry = appState.corpus.guideMap[ing.guideId ?? ing.id];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: VintageColors.terracotta,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    ing.name.get(lang),
                    style: GoogleFonts.ebGaramond(fontSize: 16, color: VintageColors.ink),
                  ),
                ),
                if (guideEntry != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => IngredientGuideDialog.show(context, guideEntry, lang),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: VintageColors.mustard.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: VintageColors.mustard, width: 0.6),
                      ),
                      child: Text(
                        'info',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: VintageColors.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '${ing.amount.toStringAsFixed(ing.amount % 1 == 0 ? 0 : 1)} ${ing.unit}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: VintageColors.inkLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(RecipeStep step, String lang) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VintageColors.paperCard,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: VintageColors.paperBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STEP 0${step.stepNumber}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: VintageColors.terracotta,
                ),
              ),
              if (step.timerMinutes != null)
                VintageBadge(
                  label: '${step.timerMinutes} min',
                  icon: Icons.timer_outlined,
                  color: VintageColors.paperSurface,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            step.instruction.get(lang),
            style: GoogleFonts.ebGaramond(fontSize: 16, color: VintageColors.ink, height: 1.45),
          ),
          if (step.tip != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: const Color(0xFFE4D5B7)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.tips_and_updates_outlined, size: 16, color: VintageColors.mustard),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step.tip!.get(lang),
                      style: GoogleFonts.caveat(fontSize: 15, color: VintageColors.ink),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
