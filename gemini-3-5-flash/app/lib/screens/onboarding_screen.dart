import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/brand_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Step 2 Name
  final TextEditingController _nameController = TextEditingController();

  // Step 3 Specific Avoidance search
  final TextEditingController _searchController = TextEditingController();
  List<IngredientNode> _suggestions = [];

  // Temporary onboarding state (cloned from default profile)
  late String _lang;
  late String _name;
  late Set<String> _avoidFlags;
  late Set<String> _avoidIngredients;
  late Set<String> _requiredAttributes;
  late int _maxTimeMinutes;
  late int _calorieTarget;
  late String _preferredEffort;

  // Selected compound diet shortcuts
  final Set<String> _selectedDiets = {};

  final Map<String, List<String>> _compoundMap = {
    'vegan': ['pork', 'beef', 'lamb', 'poultry', 'fish', 'shellfish', 'molluscs', 'egg', 'dairy', 'gelatin-non-halal', 'gelatin-non-kosher', 'honey'],
    'vegetarian': ['pork', 'beef', 'lamb', 'poultry', 'fish', 'shellfish', 'molluscs', 'gelatin-non-halal', 'gelatin-non-kosher'],
    'pescatarian': ['pork', 'beef', 'lamb', 'poultry', 'gelatin-non-halal', 'gelatin-non-kosher'],
    'gluten-free': ['gluten'],
    'lactose-free': ['dairy'],
  };

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppProvider>(context, listen: false);
    _lang = provider.currentLanguage;
    _name = provider.profile.name;
    _avoidFlags = Set.from(provider.profile.avoidFlags);
    _avoidIngredients = Set.from(provider.profile.avoidIngredients);
    _requiredAttributes = Set.from(provider.profile.requiredAttributes);
    _maxTimeMinutes = provider.profile.maxTimeMinutes;
    _calorieTarget = provider.profile.calorieTarget;
    _preferredEffort = provider.profile.preferredEffort;
    _nameController.text = _name;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentStep < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _toggleDiet(String dietKey) {
    setState(() {
      if (_selectedDiets.contains(dietKey)) {
        _selectedDiets.remove(dietKey);
        // Remove associated avoid flags
        if (dietKey == 'halal' || dietKey == 'kosher') {
          _requiredAttributes.remove(dietKey);
        } else {
          final components = _compoundMap[dietKey] ?? [];
          for (var comp in components) {
            _avoidFlags.remove(comp);
          }
        }
      } else {
        _selectedDiets.add(dietKey);
        // Add associated avoid flags
        if (dietKey == 'halal' || dietKey == 'kosher') {
          _requiredAttributes.add(dietKey);
        } else {
          final components = _compoundMap[dietKey] ?? [];
          _avoidFlags.addAll(components);
        }
      }
    });
  }

  void _searchIngredients(String query, List<IngredientNode> tree) {
    if (query.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    final list = <IngredientNode>[];
    void traverse(IngredientNode node) {
      final nameStr = node.name[_lang] ?? node.name['en'] ?? '';
      if (nameStr.toLowerCase().contains(query.toLowerCase())) {
        list.add(node);
      }
      for (var child in node.children) {
        traverse(child);
      }
    }

    for (var root in tree) {
      traverse(root);
    }
    setState(() => _suggestions = list.take(5).toList());
  }

  void _addAvoidIngredient(IngredientNode node) {
    setState(() {
      _avoidIngredients.add(node.id);
      _searchController.clear();
      _suggestions = [];
    });
  }

  void _finishOnboarding() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final finalProfile = UserProfile(
      name: _nameController.text.trim().isEmpty ? "Cook" : _nameController.text.trim(),
      lang: _lang,
      avoidFlags: _avoidFlags,
      avoidIngredients: _avoidIngredients,
      requiredAttributes: _requiredAttributes,
      maxTimeMinutes: _maxTimeMinutes,
      calorieTarget: _calorieTarget,
      preferredEffort: _preferredEffort,
    );
    provider.updateProfile(finalProfile);
    provider.completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    // Dynamic localized strings
    final isEn = _lang == 'en';
    final titleLanguage = isEn ? "select your language" : "sprache auswählen";
    final titleName = isEn ? "what should we call you?" : "wie sollen wir dich nennen?";
    final titleDiet = isEn ? "any dietary preferences?" : "ernährungspräferenzen?";
    final titleTarget = isEn ? "your daily targets" : "deine tagesziele";
    final titleConfirm = isEn ? "confirm your kitchen profile" : "küchenprofil bestätigen";

    return Scaffold(
      body: PaperGrainBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Custom Header Wordmark
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Column(
                  children: [
                    Text(
                      "morphcook",
                      style: BrandFonts.displaySerif(fontSize: 32.0, italic: true),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("est. 2026 ", style: BrandFonts.mono(fontSize: 10.0, color: BrandColors.softGrey)),
                        Text("&", style: BrandFonts.handwritten(fontSize: 16.0, color: BrandColors.coral)),
                        Text(" offline-first", style: BrandFonts.mono(fontSize: 10.0, color: BrandColors.softGrey)),
                      ],
                    ),
                  ],
                ),
              ),
              const DashedDivider(),

              // Steps PageView
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => setState(() => _currentStep = page),
                  children: [
                    _buildStepLanguage(titleLanguage),
                    _buildStepName(titleName),
                    _buildStepDiet(titleDiet, provider.ingredientsTree),
                    _buildStepTargets(titleTarget),
                    _buildStepConfirm(titleConfirm),
                  ],
                ),
              ),

              const DashedDivider(),
              // Navigation Controls Bottom Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStep > 0)
                      TextButton(
                        onPressed: _prevPage,
                        child: Text(
                          isEn ? "← back" : "← zurück",
                          style: BrandFonts.mono(fontSize: 14.0, color: BrandColors.softGrey),
                        ),
                      )
                    else
                      const SizedBox(width: 80.0),

                    // Step Indicator
                    Text(
                      "${_currentStep + 1} / 5",
                      style: BrandFonts.mono(fontSize: 14.0, color: BrandColors.charcoalInk),
                    ),

                    if (_currentStep < 4)
                      TextButton(
                        onPressed: _nextPage,
                        child: Text(
                          isEn ? "next →" : "weiter →",
                          style: BrandFonts.mono(fontSize: 14.0, color: BrandColors.charcoalInk, fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: _finishOnboarding,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BrandColors.coral,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                            side: BorderSide(color: BrandColors.charcoalInk, width: 1),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                        ),
                        child: Text(
                          isEn ? "get cooking!" : "lass uns kochen!",
                          style: BrandFonts.mono(fontSize: 14.0, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Step 1: Language ---
  Widget _buildStepLanguage(String title) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: BrandFonts.displaySerif(fontSize: 22.0, italic: true)),
          const SizedBox(height: 32.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLanguageCard("en", "English", _lang == 'en'),
              const SizedBox(width: 24.0),
              _buildLanguageCard("de", "Deutsch", _lang == 'de'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard(String code, String label, bool selected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _lang = code;
        });
      },
      child: Container(
        width: 120.0,
        height: 120.0,
        decoration: BoxDecoration(
          color: selected ? BrandColors.paleCream : Colors.white,
          border: Border.all(
            color: selected ? BrandColors.coral : BrandColors.charcoalInk,
            width: selected ? 2.0 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: BrandColors.coral.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              code.toUpperCase(),
              style: BrandFonts.displaySerif(
                fontSize: 28.0,
                color: selected ? BrandColors.coral : BrandColors.charcoalInk,
                italic: true,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(label, style: BrandFonts.mono(fontSize: 12.0)),
          ],
        ),
      ),
    );
  }

  // --- Step 2: Name ---
  Widget _buildStepName(String title) {
    final isEn = _lang == 'en';
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: BrandFonts.displaySerif(fontSize: 22.0, italic: true)),
          const SizedBox(height: 32.0),
          SizedBox(
            width: 300.0,
            child: TextField(
              controller: _nameController,
              cursorColor: BrandColors.charcoalInk,
              style: BrandFonts.mono(fontSize: 18.0),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: isEn ? "your name..." : "dein name...",
                hintStyle: BrandFonts.mono(fontSize: 16.0, color: BrandColors.softGrey),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: BrandColors.charcoalInk, width: 1.0),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: BrandColors.coral, width: 2.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 3: Diet & Allergies ---
  Widget _buildStepDiet(String title, List<IngredientNode> ingredientTree) {
    final isEn = _lang == 'en';
    final searchHint = isEn ? "avoid specific ingredient (e.g. cilantro)..." : "bestimmte zutat meiden (z.B. koriander)...";
    final diets = ['vegan', 'vegetarian', 'pescatarian', 'gluten-free', 'lactose-free', 'halal', 'kosher'];

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(title, style: BrandFonts.displaySerif(fontSize: 22.0, italic: true)),
          ),
          const SizedBox(height: 20.0),

          // Diet shortcuts grid
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: diets.map((diet) {
              final active = _selectedDiets.contains(diet);
              return FilterChip(
                label: Text(diet, style: BrandFonts.mono(fontSize: 12.0, color: active ? Colors.white : BrandColors.charcoalInk)),
                selected: active,
                selectedColor: BrandColors.coral,
                checkmarkColor: Colors.white,
                backgroundColor: BrandColors.paleCream,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                  side: BorderSide(color: BrandColors.charcoalInk, width: 0.5),
                ),
                onSelected: (_) => _toggleDiet(diet),
              );
            }).toList(),
          ),

          const SizedBox(height: 24.0),
          Text(
            isEn ? "avoid specific ingredients" : "bestimmte zutaten meiden",
            style: BrandFonts.displaySerif(fontSize: 16.0, italic: true),
          ),
          const SizedBox(height: 8.0),

          // Search Field for specific ingredients
          TextField(
            controller: _searchController,
            cursorColor: BrandColors.charcoalInk,
            style: BrandFonts.mono(fontSize: 14.0),
            decoration: InputDecoration(
              hintText: searchHint,
              hintStyle: BrandFonts.mono(fontSize: 12.0, color: BrandColors.softGrey),
              isDense: true,
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: BrandColors.charcoalInk),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: BrandColors.coral, width: 1.5),
              ),
            ),
            onChanged: (val) => _searchIngredients(val, ingredientTree),
          ),

          // Search suggestions
          if (_suggestions.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: BrandColors.charcoalInk, width: 0.5),
              ),
              child: Column(
                children: _suggestions.map((node) {
                  final nameStr = node.name[_lang] ?? node.name['en'] ?? '';
                  return ListTile(
                    title: Text(nameStr, style: BrandFonts.mono(fontSize: 13.0)),
                    dense: true,
                    onTap: () => _addAvoidIngredient(node),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 12.0),

          // List of avoided ingredients
          if (_avoidIngredients.isNotEmpty)
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 6.0,
                  runSpacing: 6.0,
                  children: _avoidIngredients.map((id) {
                    // Find name
                    String displayName = id;
                    void findInTree(IngredientNode n) {
                      if (n.id == id) {
                        displayName = n.name[_lang] ?? n.name['en'] ?? id;
                        return;
                      }
                      for (var child in n.children) {
                        findInTree(child);
                      }
                    }

                    for (var r in ingredientTree) {
                      findInTree(r);
                    }

                    return Chip(
                      label: Text("$displayName ✕", style: BrandFonts.mono(fontSize: 11.0, color: Colors.white)),
                      backgroundColor: BrandColors.charcoalInk,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      padding: EdgeInsets.zero,
                      onDeleted: () {
                        setState(() {
                          _avoidIngredients.remove(id);
                        });
                      },
                      deleteIconColor: Colors.white,
                    );
                  }).toList(),
                ),
              ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }

  // --- Step 4: Targets ---
  Widget _buildStepTargets(String title) {
    final isEn = _lang == 'en';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: BrandFonts.displaySerif(fontSize: 22.0, italic: true)),
          const SizedBox(height: 32.0),

          // Calorie Target Slider
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEn ? "calorie target per meal" : "kalorienziel pro mahlzeit", style: BrandFonts.displaySerif(fontSize: 16.0, italic: true)),
                  Text("${_calorieTarget} kcal", style: BrandFonts.mono(fontSize: 14.0, fontWeight: FontWeight.bold, color: BrandColors.coral)),
                ],
              ),
              Slider(
                value: _calorieTarget.toDouble(),
                min: 300,
                max: 1000,
                divisions: 14,
                activeColor: BrandColors.coral,
                inactiveColor: BrandColors.dashedLine,
                onChanged: (val) {
                  setState(() {
                    _calorieTarget = val.toInt();
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 32.0),

          // Time budget Slider
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEn ? "max cooking time budget" : "maximales zeitbudget", style: BrandFonts.displaySerif(fontSize: 16.0, italic: true)),
                  Text("${_maxTimeMinutes} mins", style: BrandFonts.mono(fontSize: 14.0, fontWeight: FontWeight.bold, color: BrandColors.teal)),
                ],
              ),
              Slider(
                value: _maxTimeMinutes.toDouble(),
                min: 15,
                max: 90,
                divisions: 5,
                activeColor: BrandColors.teal,
                inactiveColor: BrandColors.dashedLine,
                onChanged: (val) {
                  setState(() {
                    _maxTimeMinutes = val.toInt();
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Step 5: Summary Polaroid ---
  Widget _buildStepConfirm(String title) {
    final isEn = _lang == 'en';
    final textName = _nameController.text.trim().isEmpty ? "Cook" : _nameController.text.trim();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: BrandFonts.displaySerif(fontSize: 22.0, italic: true)),
          const SizedBox(height: 24.0),
          PolaroidCard(
            rotation: -1.0,
            child: Container(
              width: 250.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      "kitchen passport",
                      style: BrandFonts.handwritten(fontSize: 22.0, color: BrandColors.coral),
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Text("chef: $textName", style: BrandFonts.mono(fontSize: 12.0)),
                  const SizedBox(height: 6.0),
                  Text("language: ${isEn ? "english" : "deutsch"}", style: BrandFonts.mono(fontSize: 12.0)),
                  const SizedBox(height: 6.0),
                  Text(
                    "diets: ${_selectedDiets.isEmpty ? 'none' : _selectedDiets.join(', ')}",
                    style: BrandFonts.mono(fontSize: 12.0),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6.0),
                  Text(
                    "avoiding: ${_avoidIngredients.isEmpty ? 'nothing' : _avoidIngredients.length.toString() + ' items'}",
                    style: BrandFonts.mono(fontSize: 12.0),
                  ),
                  const SizedBox(height: 6.0),
                  Text("calorie level: ~$_calorieTarget kcal", style: BrandFonts.mono(fontSize: 12.0)),
                  const SizedBox(height: 6.0),
                  Text("time limit: ≤$_maxTimeMinutes mins", style: BrandFonts.mono(fontSize: 12.0)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
