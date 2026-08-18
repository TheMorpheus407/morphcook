import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/vintage_theme.dart';
import '../widgets/vintage_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  String _selectedLang = 'en';
  final TextEditingController _nameController = TextEditingController(text: 'Home Chef');
  final Set<String> _selectedAvoidFlags = {};
  final Set<String> _selectedAvoidIngredients = {};
  final TextEditingController _ingredientSearchController = TextEditingController();

  int _maxTimeMinutes = 60;
  int _calorieTarget = 600;
  String _preferredEffort = 'medium';

  @override
  void initState() {
    super.initState();
    final profile = Provider.of<AppState>(context, listen: false).profile;
    _selectedLang = profile.lang;
    _nameController.text = profile.name;
    _selectedAvoidFlags.addAll(profile.avoidFlags);
    _selectedAvoidIngredients.addAll(profile.avoidIngredients);
    _maxTimeMinutes = profile.maxTimeMinutes;
    _calorieTarget = profile.calorieTarget;
    _preferredEffort = profile.preferredEffort;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ingredientSearchController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentStep < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
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

  void _finishOnboarding() {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.profile.name = _nameController.text.trim().isEmpty ? 'Home Chef' : _nameController.text.trim();
    appState.profile.lang = _selectedLang;
    appState.profile.avoidFlags = _selectedAvoidFlags;
    appState.profile.avoidIngredients = _selectedAvoidIngredients;
    appState.profile.maxTimeMinutes = _maxTimeMinutes;
    appState.profile.calorieTarget = _calorieTarget;
    appState.profile.preferredEffort = _preferredEffort;
    appState.profile.onboardingCompleted = true;

    appState.saveProfile();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VintageColors.paperBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Progress Bar & Masthead
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'MORPHCOOK',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: VintageColors.terracotta,
                    ),
                  ),
                  Text(
                    '${_currentStep + 1} / 5',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      color: VintageColors.inkLight,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: LinearProgressIndicator(
                value: (_currentStep + 1) / 5,
                backgroundColor: VintageColors.paperBorder,
                valueColor: const AlwaysStoppedAnimation<Color>(VintageColors.terracotta),
              ),
            ),
            const SizedBox(height: 12),

            // Page View
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentStep = idx),
                children: [
                  _buildStep1Language(),
                  _buildStep2Name(),
                  _buildStep3Diets(),
                  _buildStep4Targets(),
                  _buildStep5Confirm(),
                ],
              ),
            ),

            // Bottom Navigation Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: _prevPage,
                      child: Text(
                        _selectedLang == 'de' ? 'Zurück' : 'Back',
                        style: GoogleFonts.jetBrainsMono(color: VintageColors.inkLight),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: VintageColors.terracotta,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: _nextPage,
                    child: Text(
                      _currentStep == 4
                          ? (_selectedLang == 'de' ? 'Küche betreten' : 'Enter Kitchen')
                          : (_selectedLang == 'de' ? 'Weiter' : 'Continue'),
                      style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1Language() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            _selectedLang == 'de' ? 'Wähle deine Sprache' : 'Choose Your Language',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedLang == 'de'
                ? 'MorphCook ist vollständig zweisprachig verfasst.'
                : 'MorphCook is authored fully in English and German.',
            style: GoogleFonts.ebGaramond(fontSize: 17, color: VintageColors.inkLight),
          ),
          const SizedBox(height: 32),
          _buildLanguageOption('en', 'English', 'Original English Recipe Corpus'),
          const SizedBox(height: 14),
          _buildLanguageOption('de', 'Deutsch', 'Deutsche Rezeptausgabe & Maße'),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(String code, String title, String subtitle) {
    final isSelected = _selectedLang == code;
    return GestureDetector(
      onTap: () => setState(() => _selectedLang = code),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? VintageColors.paperCard : VintageColors.paperBg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? VintageColors.terracotta : VintageColors.paperBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? VintageColors.terracotta : VintageColors.inkMuted,
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: VintageColors.ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.ebGaramond(fontSize: 14, color: VintageColors.inkLight),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2Name() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            _selectedLang == 'de' ? 'Wie dürfen wir dich nennen?' : 'What should we call you?',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedLang == 'de'
                ? 'Dein Kochbuch wird nach dir benannt.'
                : 'Every cookbook needs an author on its front cover.',
            style: GoogleFonts.ebGaramond(fontSize: 17, color: VintageColors.inkLight),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            style: GoogleFonts.playfairDisplay(fontSize: 22, color: VintageColors.ink),
            decoration: InputDecoration(
              labelText: _selectedLang == 'de' ? 'Dein Name / Spitzname' : 'Your Name / Nickname',
              labelStyle: GoogleFonts.ebGaramond(fontSize: 16),
              filled: true,
              fillColor: VintageColors.paperCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: VintageColors.paperBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: VintageColors.terracotta, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Diets() {
    final appState = Provider.of<AppState>(context, listen: false);
    final ontology = appState.corpus.ontology;
    final ingredientDict = appState.corpus.ingredientDictionary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedLang == 'de' ? 'Ernährung & Ausschlüsse' : 'Diet & Allergies',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedLang == 'de'
                ? 'Wähle deinen Lebensstil. Gerichte passen sich automatisch an dich an.'
                : 'Select dietary styles or allergies. Every dish will adapt its variant for you.',
            style: GoogleFonts.ebGaramond(fontSize: 16, color: VintageColors.inkLight),
          ),
          const SizedBox(height: 16),

          // Compound Diet Chips
          if (ontology != null) ...[
            Text(
              _selectedLang == 'de' ? 'ERNÄHRUNGSFORMEN' : 'DIETARY LIFESTYLES',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: VintageColors.inkLight,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ontology.compoundAvoidFlags.values.map((f) {
                final isSelected = _selectedAvoidFlags.contains(f.id);
                return FilterChip(
                  selected: isSelected,
                  label: Text(f.label.get(_selectedLang)),
                  labelStyle: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : VintageColors.ink,
                  ),
                  selectedColor: VintageColors.terracotta,
                  backgroundColor: VintageColors.paperCard,
                  checkmarkColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: BorderSide(
                      color: isSelected ? VintageColors.terracotta : VintageColors.paperBorder,
                    ),
                  ),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedAvoidFlags.add(f.id);
                      } else {
                        _selectedAvoidFlags.remove(f.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 20),

          // Specific Avoidances with Typeahead
          Text(
            _selectedLang == 'de' ? 'SPEZIFISCHE ZUTATEN AUSSCHLIESSEN' : 'SPECIFIC INGREDIENTS TO AVOID',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: VintageColors.inkLight,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ingredientSearchController,
            decoration: InputDecoration(
              hintText: _selectedLang == 'de' ? 'z. B. Koriander, Äpfel, Sellerie...' : 'e.g. Cilantro, Apples, Celery...',
              hintStyle: GoogleFonts.ebGaramond(color: VintageColors.inkMuted),
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: VintageColors.paperCard,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: VintageColors.paperBorder),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),

          // Search results from dictionary
          if (ingredientDict != null && _ingredientSearchController.text.trim().isNotEmpty) ...[
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              decoration: BoxDecoration(
                color: VintageColors.paperCard,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: VintageColors.paperBorder),
              ),
              child: ListView(
                shrinkWrap: true,
                children: ingredientDict
                    .search(_ingredientSearchController.text, _selectedLang)
                    .take(6)
                    .map((node) {
                  final isAvoided = _selectedAvoidIngredients.contains(node.id);
                  return ListTile(
                    dense: true,
                    title: Text(node.name.get(_selectedLang), style: GoogleFonts.ebGaramond(fontSize: 16)),
                    trailing: isAvoided
                        ? const Icon(Icons.check, color: VintageColors.terracotta, size: 18)
                        : const Icon(Icons.add, size: 18),
                    onTap: () {
                      setState(() {
                        if (isAvoided) {
                          _selectedAvoidIngredients.remove(node.id);
                        } else {
                          _selectedAvoidIngredients.add(node.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ],

          // Selected avoided chips
          if (_selectedAvoidIngredients.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _selectedAvoidIngredients.map((id) {
                final node = ingredientDict?.getNode(id);
                final label = node != null ? node.name.get(_selectedLang) : id;
                return Chip(
                  label: Text(label),
                  labelStyle: GoogleFonts.jetBrainsMono(fontSize: 11, color: VintageColors.ink),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  backgroundColor: VintageColors.paperSurface,
                  onDeleted: () => setState(() => _selectedAvoidIngredients.remove(id)),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep4Targets() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedLang == 'de' ? 'Zeit, Kalorien & Aufwand' : 'Time, Calories & Effort',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedLang == 'de'
                ? 'Passe deine täglichen Präferenzen für Zubereitungszeit und Kalorien an.'
                : 'Set your routine cooking budget and preferred energy level.',
            style: GoogleFonts.ebGaramond(fontSize: 16, color: VintageColors.inkLight),
          ),
          const SizedBox(height: 24),

          // Time budget slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedLang == 'de' ? 'Max. Zubereitungszeit' : 'Max Time Budget',
                style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              VintageBadge(label: '$_maxTimeMinutes min'),
            ],
          ),
          Slider(
            value: _maxTimeMinutes.toDouble(),
            min: 15,
            max: 120,
            divisions: 7,
            activeColor: VintageColors.terracotta,
            onChanged: (val) => setState(() => _maxTimeMinutes = val.round()),
          ),
          const SizedBox(height: 16),

          // Calorie Target slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedLang == 'de' ? 'Kalorien-Ziel pro Portion' : 'Calorie Target / Serving',
                style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              VintageBadge(label: '$_calorieTarget kcal'),
            ],
          ),
          Slider(
            value: _calorieTarget.toDouble(),
            min: 300,
            max: 900,
            divisions: 12,
            activeColor: VintageColors.mustard,
            onChanged: (val) => setState(() => _calorieTarget = val.round()),
          ),
          const SizedBox(height: 16),

          // Preferred Effort level
          Text(
            _selectedLang == 'de' ? 'Bevorzugter Aufwand' : 'Preferred Effort Mood',
            style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildEffortChip('easy', _selectedLang == 'de' ? 'Einfach' : 'Easy'),
              const SizedBox(width: 8),
              _buildEffortChip('medium', _selectedLang == 'de' ? 'Ausgewogen' : 'Balanced'),
              const SizedBox(width: 8),
              _buildEffortChip('hard', _selectedLang == 'de' ? 'Gourmet' : 'Gourmet'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEffortChip(String value, String label) {
    final isSelected = _preferredEffort == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _preferredEffort = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? VintageColors.sage : VintageColors.paperCard,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected ? VintageColors.sage : VintageColors.paperBorder,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : VintageColors.ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep5Confirm() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            _selectedLang == 'de' ? 'Dein persönliches Kochbuch' : 'Your Kitchen Notebook',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedLang == 'de'
                ? 'Hier ist deine Konfiguration. Alles ist bereit!'
                : 'Here is your personalized setup. Ready when you are.',
            style: GoogleFonts.ebGaramond(fontSize: 16, color: VintageColors.inkLight),
          ),
          const SizedBox(height: 20),

          // Polaroid Summary
          PolaroidCard(
            rotationAngle: 0.01,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nameController.text.trim().isEmpty ? 'Home Chef' : _nameController.text.trim(),
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    color: VintageColors.terracotta,
                  ),
                ),
                const SizedBox(height: 8),
                const VintageDivider(symbol: '✦'),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  _selectedLang == 'de' ? 'Sprache' : 'Language',
                  _selectedLang == 'de' ? 'Deutsch' : 'English',
                ),
                _buildSummaryRow(
                  _selectedLang == 'de' ? 'Ernährung' : 'Diet Filters',
                  _selectedAvoidFlags.isEmpty ? (_selectedLang == 'de' ? 'Alles' : 'None') : _selectedAvoidFlags.join(', '),
                ),
                _buildSummaryRow(
                  _selectedLang == 'de' ? 'Zeitbudget' : 'Time Budget',
                  '≤ $_maxTimeMinutes min',
                ),
                _buildSummaryRow(
                  _selectedLang == 'de' ? 'Kalorien' : 'Calorie Target',
                  '~$_calorieTarget kcal',
                ),
                _buildSummaryRow(
                  _selectedLang == 'de' ? 'Aufwand' : 'Effort Level',
                  _preferredEffort,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          HandwrittenNote(
            text: _selectedLang == 'de'
                ? 'Jedes Gericht existiert für jeden Körper. Keine Kompromisse, kein Verzicht.'
                : 'Every human\'s way of eating deserves a complete recipe book, not a filtered subset.',
            author: 'MorphCook',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.ebGaramond(fontSize: 15, color: VintageColors.inkLight)),
          Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: VintageColors.ink)),
        ],
      ),
    );
  }
}
