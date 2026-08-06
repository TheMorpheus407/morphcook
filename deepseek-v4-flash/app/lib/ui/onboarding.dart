import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;

import '../core/l10n.dart';
import '../core/theme.dart';
import '../data/services.dart';
import 'widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  late final TextEditingController _nameController;
  late final TextEditingController _calorieController;
  Timer? _calorieDebounce;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _calorieController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = Services.of(context).state.profile;
    _nameController.text = profile.name;
    _calorieController.text = profile.calorieTarget?.toString() ?? '';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _calorieController.dispose();
    _calorieDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = Services.of(context);
    final lang = svc.state.lang;
    String t(String k) => L10n.strings(lang, k);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _namePage(context, svc, t),
                  _languagePage(context, svc, lang, t),
                  _dietPage(context, svc, lang, t),
                  _windowsPage(context, svc, t),
                  _confirmPage(context, svc, lang, t),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 5; i++)
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page
                            ? AppColors.accent
                            : AppColors.lineDotted,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 88,
                    height: 40,
                    child: _page == 0
                        ? null
                        : OutlinedButton(
                            onPressed: _previous,
                            child: Text(t(L10n.tBack)),
                          ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _canContinue() ? _continue : null,
                    child: Text(
                        _page == 4 ? t(L10n.tConfirmProfile) : t(L10n.tNext)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canContinue() {
    if (_page == 0) return _nameController.text.trim().isNotEmpty;
    return true;
  }

  void _previous() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  void _continue() {
    final svc = Services.of(context);
    if (_page == 0) {
      svc.state.patchProfile((p) => p.name = _nameController.text.trim());
    }
    if (_page == 4) {
      svc.state.patchProfile((p) => p.completedOnboarding = true);
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  Widget _frame(Widget child) {
    return SingleChildScrollView(
      child: Center(
        child: ZinePage(child: child),
      ),
    );
  }

  Widget _namePage(
      BuildContext context, Services svc, String Function(String) t) {
    return _frame(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Masthead(
            volLine: t(L10n.tVol),
            dateLine: t(L10n.tIssue),
          ),
          const SizedBox(height: 40),
          Text(
            t(L10n.tWhatsYourName),
            style: AppText.serif(context, size: 26, weight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            t(L10n.tChooseName),
            style: AppText.mono(context, size: 10, color: AppColors.inkFaint),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            maxLength: 30,
            style: AppText.mono(context, size: 13),
            decoration: const InputDecoration(counterText: ''),
          ),
        ],
      ),
    );
  }

  Widget _languagePage(BuildContext context, Services svc, String lang,
      String Function(String) t) {
    return _frame(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            t(L10n.tChooseLanguage),
            style: AppText.serif(context, size: 24, weight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            t(L10n.tLanguage),
            style: AppText.mono(context, size: 10, color: AppColors.inkFaint),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _OnbToggle(
                label: 'english',
                selected: lang == L10n.en,
                onTap: () =>
                    svc.state.patchProfile((p) => p.lang = L10n.en),
              ),
              _OnbToggle(
                label: 'deutsch',
                selected: lang == L10n.de,
                onTap: () =>
                    svc.state.patchProfile((p) => p.lang = L10n.de),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dietPage(BuildContext context, Services svc, String lang,
      String Function(String) t) {
    final avoids = svc.corpus.ontology.compoundAvoids;
    final dietOrder = svc.corpus.ontology.dietOrder;
    final ordered = <String>[
      ...dietOrder.where(avoids.containsKey),
      ...avoids.keys.where((k) => !dietOrder.contains(k)),
    ];
    return _frame(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            t(L10n.tDietAllergies),
            style: AppText.serif(context, size: 24, weight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            t(L10n.tAvoidClass),
            style: AppText.mono(context, size: 10, color: AppColors.inkFaint),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in ordered)
                _OnbToggle(
                  label: T(avoids[id]!.label, lang),
                  selected: svc.state.profile.avoidFlags.contains(id),
                  onTap: () => svc.state.patchProfile((p) {
                    final flags = Set.of(p.avoidFlags);
                    if (!flags.remove(id)) flags.add(id);
                    p.avoidFlags = flags;
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _windowsPage(
      BuildContext context, Services svc, String Function(String) t) {
    return _frame(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            t(L10n.tYourWindows),
            style: AppText.serif(context, size: 24, weight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          Text(
            t(L10n.tCalorieTarget).toUpperCase(),
            style: AppText.mono(context, size: 10, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _calorieController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppText.mono(context, size: 12),
                  onChanged: (v) {
                    _calorieDebounce?.cancel();
                    _calorieDebounce = Timer(const Duration(milliseconds: 400),
                        () => _applyCalorie(svc, v));
                  },
                  onSubmitted: (v) {
                    _calorieDebounce?.cancel();
                    _applyCalorie(svc, v);
                  },
                ),
              ),
            ],
          ),
          Text(
            t(L10n.tCalorieToleranceNote),
            style: AppText.mono(context, size: 10, color: AppColors.inkFaint),
          ),
          const SizedBox(height: 10),
          Text(
            t(L10n.tTimeBudget).toUpperCase(),
            style: AppText.mono(context, size: 10, color: AppColors.inkSoft),
          ),
          Slider(
            value: ((svc.state.profile.maxTimeMinutes ?? 0).clamp(0, 120))
                .toDouble(),
            min: 0,
            max: 120,
            divisions: 24,
            label:
                '${svc.state.profile.maxTimeMinutes ?? 0} ${t(L10n.tMinutes)}',
            onChanged: (v) => svc.state.patchProfile((p) {
              p.maxTimeMinutes = v.round() == 0 ? null : v.round();
            }),
          ),
        ],
      ),
    );
  }

  void _applyCalorie(Services svc, String v) {
    if (!mounted) return;
    final parsed = int.tryParse(v.trim());
    final current = svc.state.profile.calorieTarget;
    if (v.trim().isEmpty) {
      if (current != null) {
        svc.state.patchProfile((p) => p.calorieTarget = null);
      }
    } else if (parsed != null && parsed != current) {
      svc.state.patchProfile((p) => p.calorieTarget = parsed);
    }
  }

  Widget _confirmPage(BuildContext context, Services svc, String lang,
      String Function(String) t) {
    final profile = svc.state.profile;
    final avoids = svc.corpus.ontology.compoundAvoids;
    final flagLabels = profile.avoidFlags.where(avoids.containsKey).map((id) {
      return T(avoids[id]!.label, lang);
    }).toList();
    final windows = <(String, String)>[
      (
        t(L10n.tLanguage),
        profile.lang == L10n.de ? 'deutsch' : 'english',
      ),
      (
        t(L10n.tCalorieTarget),
        profile.calorieTarget?.toString() ?? t(L10n.tAny),
      ),
      (
        t(L10n.tTimeBudget),
        profile.maxTimeMinutes == null
            ? t(L10n.tAny)
            : '${profile.maxTimeMinutes} ${t(L10n.tMinutes)}',
      ),
    ];
    return _frame(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            t(L10n.tConfirmProfile),
            style: AppText.serif(context, size: 24, weight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          for (final (label, value) in windows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      style: AppText.mono(
                          context, size: 10, color: AppColors.inkSoft),
                    ),
                  ),
                  Text(
                    value,
                    style: AppText.mono(context, size: 11),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            '— ${flagLabels.isEmpty ? t(L10n.tAny) : flagLabels.join(', ')} —',
            textAlign: TextAlign.center,
            style: AppText.mono(context, size: 10, color: AppColors.inkFaint),
          ),
          const DottedDivider(),
          Text(
            t(L10n.tOnboardingReady),
            style: AppText.script(context, size: 26, color: AppColors.accent),
          ),
        ],
      ),
    );
  }
}

class _OnbToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _OnbToggle({required this.label, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final border = selected ? AppColors.accent : AppColors.lineDotted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          border: Border.all(color: border, width: 1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: AppText.mono(
            context,
            size: 10,
            color: selected ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}