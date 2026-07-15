import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../models/profile.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/decor.dart';

/// A light first-run welcome with optional dietary setup.
///
/// Opening the cookbook only requires choosing a language. People who want
/// tailored variants immediately can set diet and allergy preferences on one
/// additional screen; the full profile remains available in Settings.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  final Set<String> _avoidFlags = {};

  late String _lang;
  int _index = 0;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    final deviceLanguage =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    _lang = deviceLanguage == 'de' ? 'de' : 'en';
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    final duration = motionDuration(
      context,
      null,
      normal: const Duration(milliseconds: 220),
    );
    if (duration == Duration.zero) {
      _page.jumpToPage(index);
    } else {
      _page.animateToPage(
        index,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    final state = context.read<AppState>();
    try {
      await state.completeOnboarding(
        Profile(lang: _lang, avoidFlags: _avoidFlags),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _finishing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(S(_lang)('obSaveFailed'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final morph = MorphTheme.of(context);
    final s = S(_lang);
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index > 0) _goToPage(0);
      },
      child: Scaffold(
        body: PaperBackground(
          child: SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: 54,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_index > 0)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            key: const ValueKey('onboarding-back'),
                            tooltip: s('back'),
                            onPressed: () => _goToPage(0),
                            icon: const Icon(Icons.arrow_back),
                            color: morph.colors.ink,
                          ),
                        ),
                      Text(
                        'morphcook',
                        style: morph.text.display.copyWith(fontSize: 30),
                      ),
                    ],
                  ),
                ),
                Text(s('tagline'), style: morph.text.handAt(17)),
                const SizedBox(height: 6),
                Expanded(
                  child: PageView(
                    controller: _page,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) => setState(() => _index = index),
                    children: [_welcomePage(s), _dietPage(s)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _frame(
    String title,
    List<Widget> children, {
    String? subtitle,
    Widget? footer,
  }) {
    final morph = MorphTheme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      children: [
        Text(title, style: morph.text.display.copyWith(fontSize: 27)),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              subtitle,
              style: morph.text.handAt(18, color: morph.colors.inkSoft),
            ),
          ),
        const SizedBox(height: 22),
        ...children,
        const SizedBox(height: 28),
        if (footer != null) footer,
      ],
    );
  }

  Widget _primaryButton(String label, {required Key key}) {
    final morph = MorphTheme.of(context);
    return FilledButton(
      key: key,
      style: FilledButton.styleFrom(
        backgroundColor: morph.colors.ink,
        disabledBackgroundColor: morph.colors.inkSoft,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),
      onPressed: _finishing ? null : _finish,
      child: _finishing
          ? SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: morph.colors.paper,
              ),
            )
          : Text(
              morph.cased(label),
              style: morph.text.label(color: morph.colors.paper),
            ),
    );
  }

  Widget _welcomePage(S s) {
    final morph = MorphTheme.of(context);
    return _frame(
      s('obLanguageTitle'),
      [
        _bigChoice('english', _lang == 'en', () {
          setState(() => _lang = 'en');
        }),
        const SizedBox(height: 12),
        _bigChoice('deutsch', _lang == 'de', () {
          setState(() => _lang = 'de');
        }),
      ],
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _primaryButton(s('letsCook'), key: const ValueKey('onboarding-open')),
          const SizedBox(height: 8),
          TextButton.icon(
            key: const ValueKey('onboarding-personalize'),
            onPressed: _finishing ? null : () => _goToPage(1),
            icon: const Icon(Icons.tune, size: 18),
            label: Text(
              morph.cased(s('obPersonalize')),
              style: morph.text.label(color: morph.colors.inkSoft),
            ),
          ),
          Text(
            s('obSetupLater'),
            textAlign: TextAlign.center,
            style: morph.text.mono.copyWith(
              fontSize: 11,
              color: morph.colors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bigChoice(String label, bool selected, VoidCallback onTap) {
    final morph = MorphTheme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? morph.colors.ink : morph.colors.card,
        shape: Border.all(color: morph.colors.line),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              label,
              style: morph.text.display.copyWith(
                fontSize: 20,
                color: selected ? morph.colors.paper : morph.colors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dietPage(S s) {
    final morph = MorphTheme.of(context);
    final ontology = context.read<AppState>().corpus.ontology;
    return _frame(
      s('obDietTitle'),
      [
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            for (final compound in ontology.compoundFlags)
              MonoChip(
                label: compound.name.of(_lang),
                selected: _avoidFlags.contains(compound.id),
                onTap: () => setState(() {
                  if (!_avoidFlags.remove(compound.id)) {
                    _avoidFlags.add(compound.id);
                  }
                }),
              ),
          ],
        ),
        const DashedDivider(),
        Text(s('obAllergyTitle'), style: morph.text.label(size: 10)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            for (final flag in const [
              'dairy',
              'gluten',
              'egg',
              'soy',
              'peanuts',
              'tree-nuts',
              'fish',
              'shellfish',
              'sesame',
              'mustard',
              'celery',
              'sulphites',
              'alcohol',
              'caffeine',
            ])
              MonoChip(
                label: ontology.nameOf(flag, _lang),
                selected: _avoidFlags.contains(flag),
                onTap: () => setState(() {
                  if (!_avoidFlags.remove(flag)) _avoidFlags.add(flag);
                }),
              ),
          ],
        ),
      ],
      subtitle: s('obDietSub'),
      footer: _primaryButton(
        s('letsCook'),
        key: const ValueKey('onboarding-open-personalized'),
      ),
    );
  }
}
