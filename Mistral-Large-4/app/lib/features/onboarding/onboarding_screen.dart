import 'package:flutter/material.dart' hide Typography;
import 'package:provider/provider.dart';

import '../../core/i18n/strings.dart';
import '../../core/model/profile.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../state/app_state.dart';
import '../../widgets/controls.dart';
import '../../widgets/ingredient_typeahead.dart';
import '../../widgets/paper.dart';

/// Onboarding: language → name → diet & allergies → calorie target + time
/// budget → confirm.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _page = 0;

  String _lang = 'en';
  String _name = '';
  final Set<String> _avoidFlags = {};
  Set<String> _avoidIngredients = {};
  final Set<String> _required = {};
  int _calorieTarget = 600;
  int _maxTime = 60;
  String _effort = 'medium';

  Strings get s => Strings(_lang);

  void _next() {
    if (_page < 4) {
      _pageController.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_page > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    }
  }

  Future<void> _finish() async {
    final appState = context.read<AppState>();
    await appState.updateProfile(UserProfile(
      name: _name.trim(),
      lang: _lang,
      avoidFlags: _avoidFlags,
      avoidIngredients: _avoidIngredients,
      requiredAttributes: _required,
      maxTimeMinutes: _maxTime,
      calorieTarget: _calorieTarget,
      preferredEffort: _effort,
      onboardingComplete: true,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _languagePage(),
      _namePage(),
      _dietPage(),
      _budgetPage(),
      _confirmPage(),
    ];
    return PaperScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  for (var i = 0; i < 5; i++)
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        color: i <= _page ? Palette.ink : Palette.line,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  if (_page > 0)
                    Expanded(
                      child: InkButton(
                        s.onbBack.toUpperCase(),
                        outlined: true,
                        onTap: _back,
                      ),
                    ),
                  if (_page > 0) const SizedBox(width: 10),
                  Expanded(
                    child: InkButton(
                      (_page == 4 ? s.onbStartCooking : s.onbNext).toUpperCase(),
                      onTap: _next,
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

  Widget _stepTitle(String text, String body) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: Typography.display(26)),
          const SizedBox(height: 8),
          Text(body, style: Typography.body(15, italic: true)),
          const SizedBox(height: 20),
        ],
      );

  Widget _languagePage() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(s.onbWelcome, style: Typography.display(30)),
            const SizedBox(height: 10),
            Text(s.onbWelcomeBody, style: Typography.body(15, italic: true)),
            const SizedBox(height: 28),
            Text(s.onbPickLanguage, style: Typography.mono(10, weight: FontWeight.w700, letterSpacing: 2.4, color: Palette.coral)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _langButton('en', 'english')),
                const SizedBox(width: 10),
                Expanded(child: _langButton('de', 'deutsch')),
              ],
            ),
          ],
        ),
      );

  Widget _langButton(String code, String label) {
    final selected = _lang == code;
    return GestureDetector(
      onTap: () => setState(() => _lang = code),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? Palette.ink : Palette.paper,
          border: Border.all(color: selected ? Palette.ink : Palette.line, width: 1.4),
        ),
        child: Center(
          child: Text(label, style: Typography.hand(22, color: selected ? Palette.paper : Palette.ink)),
        ),
      ),
    );
  }

  Widget _namePage() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            _stepTitle(s.onbYourName, ''),
            TextField(
              autofocus: true,
              style: Typography.hand(26),
              decoration: InputDecoration(
                hintText: s.onbNameHint,
                hintStyle: Typography.hand(26, color: Palette.inkFaint),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Palette.line, width: 1.4)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Palette.ink, width: 1.4)),
              ),
              onChanged: (v) => _name = v,
            ),
            const Spacer(),
            HandNote('— ${s.appName}', size: 22, color: Palette.inkFaint),
            const SizedBox(height: 24),
          ],
        ),
      );

  Widget _dietPage() => ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 24),
          _stepTitle(s.onbDietTitle, s.onbDietBody),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final flag in const [
                'vegan', 'vegetarian', 'pescatarian', 'halal', 'kosher',
                'sugar-free', 'low-fodmap', 'lactose-free',
                'dairy', 'nuts', 'pork', 'gluten', 'shellfish', 'egg', 'soy', 'sesame',
              ])
                PaperChip(
                  label: s.flagLabel(flag),
                  selected: _avoidFlags.contains(flag),
                  onTap: () => setState(() {
                    if (_avoidFlags.contains(flag)) {
                      _avoidFlags.remove(flag);
                    } else {
                      _avoidFlags.add(flag);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(s.onbAllergiesTitle, style: Typography.display(22)),
          const SizedBox(height: 6),
          Text(s.onbAllergiesBody, style: Typography.body(14, italic: true)),
          const SizedBox(height: 12),
          IngredientTypeahead(
            lang: _lang,
            selected: _avoidIngredients,
            onChanged: (v) => setState(() => _avoidIngredients = v),
            hint: s.onbAvoidIngredientHint,
          ),
          const SizedBox(height: 24),
        ],
      );

  Widget _budgetPage() => ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 24),
          _stepTitle(s.onbBudgetTitle, s.onbBudgetBody),
          _sliderRow(
            label: s.onbCalorieTarget,
            value: _calorieTarget.toDouble(),
            min: 300,
            max: 1200,
            step: 50,
            display: (v) => '${v.round()} ${s.onbKcal}',
            onChanged: (v) => setState(() => _calorieTarget = v.round()),
          ),
          const SizedBox(height: 20),
          _sliderRow(
            label: s.onbMaxTime,
            value: _maxTime.toDouble(),
            min: 15,
            max: 120,
            step: 5,
            display: (v) => '${v.round()} ${s.onbMinutes}',
            onChanged: (v) => setState(() => _maxTime = v.round()),
          ),
          const SizedBox(height: 20),
          Text(s.onbEffort, style: Typography.mono(10, weight: FontWeight.w700, letterSpacing: 2, color: Palette.inkFaint)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final e in ['easy', 'medium', 'hard'])
                PaperChip(
                  label: s.effortLabel(e),
                  selected: _effort == e,
                  onTap: () => setState(() => _effort = e),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      );

  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required double step,
    required String Function(double) display,
    required ValueChanged<double> onChanged,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: Typography.mono(10, weight: FontWeight.w700, letterSpacing: 2, color: Palette.inkFaint)),
              Text(display(value), style: Typography.mono(12, weight: FontWeight.w700, color: Palette.teal)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Palette.teal,
              inactiveTrackColor: Palette.line,
              thumbColor: Palette.ink,
              overlayColor: Palette.teal.withValues(alpha: 0.15),
              trackHeight: 2,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: ((max - min) / step).round(),
              onChanged: onChanged,
            ),
          ),
        ],
      );

  Widget _confirmPage() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(s.onbConfirmTitle, style: Typography.display(28)),
            const SizedBox(height: 16),
            _summaryRow(s.onbPickLanguage.split('—').last.trim(), _lang == 'de' ? 'deutsch' : 'english'),
            _summaryRow(s.onbYourName.replaceAll('?', ''), _name.trim().isEmpty ? '—' : _name.trim()),
            _summaryRow(
              s.onbDietTitle.replaceAll('?', ''),
              _avoidFlags.isEmpty ? '—' : _avoidFlags.map(s.flagLabel).join(', '),
            ),
            _summaryRow(
              s.onbAllergiesTitle.replaceAll('?', ''),
              _avoidIngredients.isEmpty ? '—' : '${_avoidIngredients.length} ${s.onbAvoidIngredientHint.replaceAll('…', '')}',
            ),
            _summaryRow(s.onbCalorieTarget, '$_calorieTarget ${s.onbKcal}'),
            _summaryRow(s.onbMaxTime, '$_maxTime ${s.onbMinutes}'),
            _summaryRow(s.onbEffort, s.effortLabel(_effort)),
            const SizedBox(height: 16),
            Text(s.onbConfirmBody, style: Typography.body(14, italic: true)),
          ],
        ),
      );

  Widget _summaryRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: Typography.mono(10, letterSpacing: 1.4, color: Palette.inkFaint))),
            Expanded(
              flex: 2,
              child: Text(value, style: Typography.body(15, italic: true, color: Palette.ink)),
            ),
          ],
        ),
      );
}
