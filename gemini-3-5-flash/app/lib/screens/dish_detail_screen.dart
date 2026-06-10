import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/brand_theme.dart';
import 'cook_mode_screen.dart';

class DishDetailScreen extends StatefulWidget {
  final Dish dish;

  const DishDetailScreen({super.key, required this.dish});

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  late Recipe _currentRecipe;
  int _servings = 2;

  // Swapping states
  late String _selectedDiet;
  late String _selectedEffort;

  // Expansion of switcher rows
  bool _dietExpanded = false;
  bool _effortExpanded = false;

  // Map of recipe IDs to dimension attributes for this dish
  final Map<String, Map<String, String>> _dimensionsMap = {};

  @override
  void initState() {
    super.initState();
    _setupDimensions();
  }

  void _setupDimensions() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    // Load variants if not loaded
    provider.ensureDishVariantsLoaded(widget.dish);

    // Initial optimal recipe variant
    final optimal = provider.getOptimalVariantForDish(widget.dish) ?? 
                    provider.recipes[widget.dish.variantIds.first]!;
    _currentRecipe = optimal;

    // Build the dimensions mapping for this dish's variants
    for (var rId in widget.dish.variantIds) {
      if (rId == 'doener-classic') {
        _dimensionsMap[rId] = {'diet': 'classic', 'effort': 'medium'};
      } else if (rId == 'doener-vegan') {
        _dimensionsMap[rId] = {'diet': 'vegan', 'effort': 'easy'};
      } else if (rId == 'doener-halal') {
        _dimensionsMap[rId] = {'diet': 'halal', 'effort': 'medium'};
      } else if (rId == 'doener-keto') {
        _dimensionsMap[rId] = {'diet': 'keto', 'effort': 'medium'};
      } else if (rId == 'alfredo-classic') {
        _dimensionsMap[rId] = {'diet': 'classic', 'effort': 'medium'};
      } else if (rId == 'alfredo-gf') {
        _dimensionsMap[rId] = {'diet': 'gluten-free', 'effort': 'medium'};
      } else if (rId == 'alfredo-easy') {
        _dimensionsMap[rId] = {'diet': 'classic', 'effort': 'easy'};
      } else if (rId == 'padthai-classic') {
        _dimensionsMap[rId] = {'diet': 'classic', 'effort': 'medium'};
      } else if (rId == 'padthai-nutfree') {
        _dimensionsMap[rId] = {'diet': 'nut-free', 'effort': 'medium'};
      } else {
        // Fallback mapping using contains flags & attributes
        final r = provider.recipes[rId];
        if (r != null) {
          String diet = 'classic';
          if (r.containsFlags.contains('soy') && !r.containsFlags.contains('beef') && !r.containsFlags.contains('poultry')) diet = 'vegan';
          if (r.containsFlags.contains('sesame') && !r.containsFlags.contains('peanuts')) diet = 'nut-free';
          final effort = r.attributes.contains('easy') ? 'easy' : 'medium';
          _dimensionsMap[rId] = {'diet': diet, 'effort': effort};
        }
      }
    }

    final currentDims = _dimensionsMap[_currentRecipe.id] ?? {'diet': 'classic', 'effort': 'medium'};
    _selectedDiet = currentDims['diet']!;
    _selectedEffort = currentDims['effort']!;
  }

  /// Tries to find a recipe variant matching the given dimensions
  Recipe? _findRecipeWith(String diet, String effort) {
    for (var entry in _dimensionsMap.entries) {
      if (entry.value['diet'] == diet && entry.value['effort'] == effort) {
        final r = Provider.of<AppProvider>(context, listen: false).recipes[entry.key];
        if (r != null) return r;
      }
    }
    return null;
  }

  void _selectCombination(String diet, String effort) {
    final recipe = _findRecipeWith(diet, effort);
    if (recipe != null) {
      setState(() {
        _selectedDiet = diet;
        _selectedEffort = effort;
        _currentRecipe = recipe;
      });
    }
  }

  void _showIngredientGuide(String ingredientId, String fallbackName) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final isEn = provider.currentLanguage == 'en';
    final guide = provider.ingredientGuide[ingredientId];

    showModalBottomSheet(
      context: context,
      backgroundColor: BrandColors.creamBg,
      shape: const Border(
        top: BorderSide(color: BrandColors.charcoalInk, width: 1.0),
      ),
      builder: (context) {
        return PaperGrainBackground(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      guide != null 
                        ? (guide['name'][isEn ? 'en' : 'de'] ?? fallbackName).toLowerCase() 
                        : fallbackName.toLowerCase(),
                      style: BrandFonts.displaySerif(fontSize: 24.0, italic: true, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: BrandColors.charcoalInk),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const DashedDivider(),
                const SizedBox(height: 16.0),
                if (guide != null) ...[
                  Text(
                    guide['description'][isEn ? 'en' : 'de'] ?? '',
                    style: BrandFonts.body(fontSize: 14.0),
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    isEn ? "kitchen tips:" : "küchentipps:",
                    style: BrandFonts.mono(fontSize: 11.0, color: BrandColors.coral, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    guide['tips'][isEn ? 'en' : 'de'] ?? '',
                    style: BrandFonts.body(fontSize: 13.0, color: BrandColors.charcoalInk),
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    isEn ? "how to store:" : "lagerung:",
                    style: BrandFonts.mono(fontSize: 11.0, color: BrandColors.teal, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    guide['storage'][isEn ? 'en' : 'de'] ?? '',
                    style: BrandFonts.body(fontSize: 13.0, color: BrandColors.charcoalInk),
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    isEn ? "where to find:" : "einkaufsort:",
                    style: BrandFonts.mono(fontSize: 11.0, color: BrandColors.softGrey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    guide['find'][isEn ? 'en' : 'de'] ?? '',
                    style: BrandFonts.body(fontSize: 13.0, color: BrandColors.charcoalInk),
                  ),
                ] else ...[
                  Text(
                    isEn 
                      ? "no kitchen reference guide is available for this ingredient yet."
                      : "für diese zutat ist noch kein küchenratgeber verfügbar.",
                    style: BrandFonts.body(fontSize: 14.0, color: BrandColors.softGrey),
                  ),
                ],
                const SizedBox(height: 24.0),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final isEn = provider.currentLanguage == 'en';

    final isSaved = provider.isRecipeSaved(_currentRecipe.id);
    final stripeColor = Color(int.parse(widget.dish.stripeColor));
    final recipeTitle = _currentRecipe.name[isEn ? 'en' : 'de'] ?? widget.dish.canonicalName[isEn ? 'en' : 'de'] ?? '';

    // Extracted available dimension sets
    final diets = _dimensionsMap.values.map((v) => v['diet']!).toSet().toList();
    final efforts = _dimensionsMap.values.map((v) => v['effort']!).toSet().toList();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: BrandColors.creamBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: BrandColors.charcoalInk, size: 18.0),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.dish.canonicalName[isEn ? 'en' : 'de']!.toLowerCase(),
          style: BrandFonts.displaySerif(fontSize: 20.0, italic: true, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Bookmark/Save button for specific variant!
          IconButton(
            icon: Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: isSaved ? BrandColors.coral : BrandColors.charcoalInk,
            ),
            onPressed: () {
              provider.toggleSavedRecipe(_currentRecipe.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: BrandColors.charcoalInk,
                  content: Text(
                    isSaved 
                      ? (isEn ? "removed from cookbook" : "aus dem kochbuch entfernt")
                      : (isEn ? "saved specific variant to cookbook" : "spezifische variante im kochbuch gespeichert"),
                    style: BrandFonts.mono(fontSize: 12.0, color: Colors.white),
                  ),
                ),
              );
            },
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: DashedDivider(),
        ),
      ),
      body: PaperGrainBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Polaroid Hero Section
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: PolaroidCard(
                    rotation: -0.8,
                    child: Container(
                      width: 280.0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StripedPlaceholder(
                            color: stripeColor,
                            caption: widget.dish.capCaption[isEn ? 'en' : 'de'] ?? '',
                            height: 180.0,
                          ),
                          const SizedBox(height: 16.0),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: KeyedSubtree(
                              key: ValueKey(_currentRecipe.id),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    recipeTitle.toLowerCase(),
                                    style: BrandFonts.displaySerif(fontSize: 22.0, italic: true, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8.0),
                                  Text(
                                    _currentRecipe.description[isEn ? 'en' : 'de'] ?? '',
                                    style: BrandFonts.body(fontSize: 13.0, color: BrandColors.softGrey),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const DashedDivider(),

              // 2. Per-Dimension Variant Switchers
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? "adapt this dish" : "gericht anpassen",
                      style: BrandFonts.mono(fontSize: 11.0, color: BrandColors.coral, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12.0),

                    // Diet Row
                    _buildDimensionRow(
                      label: isEn ? "diet" : "ernährung",
                      currentValue: _selectedDiet,
                      expanded: _dietExpanded,
                      onToggle: () => setState(() => _dietExpanded = !_dietExpanded),
                      options: diets,
                      isSelected: (opt) => opt == _selectedDiet,
                      isEnabled: (opt) => _findRecipeWith(opt, _selectedEffort) != null,
                      onSelect: (opt) => _selectCombination(opt, _selectedEffort),
                      note: (opt) => isEn 
                        ? "no $_selectedEffort × $opt version yet" 
                        : "noch keine $_selectedEffort x $opt version verfügbar",
                    ),

                    const SizedBox(height: 8.0),

                    // Effort Row
                    _buildDimensionRow(
                      label: isEn ? "effort" : "aufwand",
                      currentValue: _selectedEffort,
                      expanded: _effortExpanded,
                      onToggle: () => setState(() => _effortExpanded = !_effortExpanded),
                      options: efforts,
                      isSelected: (opt) => opt == _selectedEffort,
                      isEnabled: (opt) => _findRecipeWith(_selectedDiet, opt) != null,
                      onSelect: (opt) => _selectCombination(_selectedDiet, opt),
                      note: (opt) => isEn 
                        ? "no $opt × $_selectedDiet version yet" 
                        : "noch keine $opt x $_selectedDiet version verfügbar",
                    ),
                  ],
                ),
              ),

              const DashedDivider(),

              // 3. Servings Scaler & Info
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEn ? "servings scaler" : "portionsrechner",
                          style: BrandFonts.displaySerif(fontSize: 16.0, italic: true),
                        ),
                        Text(
                          isEn ? "multiplies quantities" : "multipliziert mengen",
                          style: BrandFonts.mono(fontSize: 10.0, color: BrandColors.softGrey),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _buildServingsButton(Icons.remove, () {
                          if (_servings > 1) setState(() => _servings--);
                        }),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            "$_servings",
                            style: BrandFonts.mono(fontSize: 18.0, fontWeight: FontWeight.bold),
                          ),
                        ),
                        _buildServingsButton(Icons.add, () {
                          setState(() => _servings++);
                        }),
                      ],
                    ),
                  ],
                ),
              ),

              const DashedDivider(),

              // 4. Recipe Details (Ingredients with Learn More, Method, Macros)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: KeyedSubtree(
                  key: ValueKey(_currentRecipe.id),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Metadata
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMetaBadge(Icons.timer_outlined, "${_currentRecipe.timeMinutes}m"),
                            _buildMetaBadge(Icons.bolt_outlined, "${_currentRecipe.caloriesPerServing * (_servings / 2.0).round()} kcal"),
                            _buildMetaBadge(Icons.restaurant_outlined, _selectedEffort),
                          ],
                        ),
                        const SizedBox(height: 24.0),

                        // Ingredients header
                        Text(
                          isEn ? "ingredients" : "zutaten",
                          style: BrandFonts.displaySerif(fontSize: 20.0, italic: true, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12.0),

                        // Ingredients list
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _currentRecipe.ingredients.length,
                          itemBuilder: (context, idx) {
                            final ing = _currentRecipe.ingredients[idx];
                            // Scale amount based on servings (recipes are written for 2 servings base)
                            final double scaledAmount = ing.amount * (_servings / 2.0);
                            final formattedAmount = scaledAmount == 0 
                              ? "" 
                              : scaledAmount % 1 == 0 
                                ? scaledAmount.toInt().toString() 
                                : scaledAmount.toStringAsFixed(1);
                            final ingName = ing.name[isEn ? 'en' : 'de'] ?? ing.id;

                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: BrandColors.dashedLine, width: 0.5)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Text(
                                          "$formattedAmount ${ing.unit}  ",
                                          style: BrandFonts.mono(fontSize: 13.0, color: BrandColors.coral, fontWeight: FontWeight.bold),
                                        ),
                                        Expanded(
                                          child: Text(
                                            ingName,
                                            style: BrandFonts.body(fontSize: 14.0),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Learn More button
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () => _showIngredientGuide(ing.id, ingName),
                                    child: Text(
                                      isEn ? "learn more" : "info",
                                      style: BrandFonts.handwritten(fontSize: 14.0, color: BrandColors.teal),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 28.0),

                        // Macros Row
                        _buildMacrosRow(isEn),

                        const SizedBox(height: 32.0),

                        // Big Cook Mode Trigger Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CookModeScreen(
                                    recipe: _currentRecipe,
                                    servings: _servings,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BrandColors.charcoalInk,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(16.0),
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                              elevation: 0,
                            ),
                            child: Text(
                              isEn ? "ENTER COOK MODE" : "KOCHMODUS STARTEN",
                              style: BrandFonts.mono(fontSize: 14.0, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDimensionRow({
    required String label,
    required String currentValue,
    required bool expanded,
    required VoidCallback onToggle,
    required List<String> options,
    required bool Function(String) isSelected,
    required bool Function(String) isEnabled,
    required Function(String) onSelect,
    required String Function(String) note,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BrandColors.charcoalInk, width: 0.5),
      ),
      child: Column(
        children: [
          // Header Row
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "$label //",
                    style: BrandFonts.mono(fontSize: 12.0, color: BrandColors.softGrey),
                  ),
                  Row(
                    children: [
                      Text(
                        currentValue,
                        style: BrandFonts.mono(fontSize: 12.0, fontWeight: FontWeight.bold, color: BrandColors.coral),
                      ),
                      const SizedBox(width: 8.0),
                      Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        size: 16.0,
                        color: BrandColors.charcoalInk,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Options Chips (Visible if expanded)
          if (expanded) ...[
            const DashedDivider(),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: options.map((opt) {
                  final active = isSelected(opt);
                  final enabled = isEnabled(opt);

                  return GestureDetector(
                    onTap: () {
                      if (enabled) {
                        onSelect(opt);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: BrandColors.charcoalInk,
                            duration: const Duration(seconds: 2),
                            content: Text(
                              note(opt),
                              style: BrandFonts.mono(fontSize: 11.0, color: Colors.white),
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                      decoration: BoxDecoration(
                        color: active 
                          ? BrandColors.coral 
                          : enabled 
                            ? BrandColors.paleCream 
                            : Colors.white.withOpacity(0.5),
                        border: Border.all(
                          color: active 
                            ? BrandColors.coral 
                            : enabled 
                              ? BrandColors.charcoalInk 
                              : BrandColors.dashedLine,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        opt,
                        style: BrandFonts.mono(
                          fontSize: 11.0, 
                          color: active 
                            ? Colors.white 
                            : enabled 
                              ? BrandColors.charcoalInk 
                              : BrandColors.softGrey,
                          fontWeight: active ? FontWeight.bold : FontWeight.normal,
                        ).copyWith(
                          decoration: enabled ? TextDecoration.none : TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildServingsButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(6.0),
        decoration: BoxDecoration(
          color: BrandColors.paleCream,
          border: Border.all(color: BrandColors.charcoalInk, width: 0.5),
        ),
        child: Icon(icon, size: 16.0, color: BrandColors.charcoalInk),
      ),
    );
  }

  Widget _buildMetaBadge(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16.0, color: BrandColors.softGrey),
        const SizedBox(width: 4.0),
        Text(text, style: BrandFonts.mono(fontSize: 12.0, color: BrandColors.charcoalInk)),
      ],
    );
  }

  Widget _buildMacrosRow(bool isEn) {
    final scale = _servings / 2.0;
    final cal = (_currentRecipe.nutrition['calories'] as num? ?? 0) * scale;
    final prot = (_currentRecipe.nutrition['protein'] as num? ?? 0) * scale;
    final carbs = (_currentRecipe.nutrition['carbs'] as num? ?? 0) * scale;
    final fat = (_currentRecipe.nutrition['fat'] as num? ?? 0) * scale;

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: BrandColors.paleCream,
        border: Border.all(color: BrandColors.dashedLine, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMacroItem(isEn ? "Calories" : "Kalorien", "${cal.round()} kcal"),
          _buildMacroItem(isEn ? "Protein" : "Protein", "${prot.round()}g"),
          _buildMacroItem(isEn ? "Carbs" : "Kohlenh.", "${carbs.round()}g"),
          _buildMacroItem(isEn ? "Fat" : "Fett", "${fat.round()}g"),
        ],
      ),
    );
  }

  Widget _buildMacroItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: BrandFonts.mono(fontSize: 9.0, color: BrandColors.softGrey)),
        const SizedBox(height: 4.0),
        Text(value, style: BrandFonts.mono(fontSize: 12.0, fontWeight: FontWeight.bold, color: BrandColors.charcoalInk)),
      ],
    );
  }
}
