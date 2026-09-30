import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/corpus_repository.dart';
import '../../i18n/strings.dart';
import '../../models/profile.dart';
import '../../state/profile_controller.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/paper.dart';
import '../widgets/profile_editors.dart';

/// language → name → diet & allergies → calories + time → confirm.
/// Every choice is written through immediately (so the language switch is
/// live); the profile only counts as onboarded after the last step.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _steps = 5;
  final _pager = PageController();
  late final TextEditingController _name = TextEditingController(text: context.read<ProfileController>().profile.name);
  int _page = 0;

  @override
  void dispose() {
    _pager.dispose();
    _name.dispose();
    super.dispose();
  }

  void _go(int page) {
    FocusScope.of(context).unfocus();
    setState(() => _page = page);
    final d = motionRead(context, const Duration(milliseconds: 380));
    if (d == Duration.zero) {
      _pager.jumpToPage(page);
    } else {
      _pager.animateToPage(page, duration: d, curve: Curves.easeOutCubic);
    }
  }

  void _update(Profile p) => context.read<ProfileController>().replace(p);

  Future<void> _finish() async {
    final ctrl = context.read<ProfileController>();
    await ctrl.update((p) => p.copyWith(name: _name.text.trim(), onboarded: true));
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final profile = context.watch<ProfileController>().profile;
    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                child: Row(
                  children: [
                    Text('MorphCook', style: MT.display(22)),
                    const Spacer(),
                    MonoLabel(tr('ob.step', {'n': _page + 1, 'total': _steps})),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                child: Row(
                  children: [
                    for (var i = 0; i < _steps; i++)
                      Expanded(
                        child: AnimatedContainer(
                          duration: motion(context, const Duration(milliseconds: 250)),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 3,
                          color: i <= _page ? MC.coral : MC.rule,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pager,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _StepLanguage(profile: profile, onChanged: _update),
                    _StepPage(
                      title: tr('ob.name.title'),
                      body: tr('ob.name.body'),
                      child: TextField(
                        key: const Key('ob-name'),
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        style: MT.display(26),
                        decoration: InputDecoration(hintText: tr('ob.name.hint')),
                        onSubmitted: (_) => _go(2),
                      ),
                    ),
                    _StepPage(
                      title: tr('ob.diet.title'),
                      body: tr('ob.diet.body'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MonoLabel(tr('ob.diet.ways')),
                          const SizedBox(height: 10),
                          DietChoicesEditor(profile: profile, onChanged: _update),
                          if (profile.avoidFlags.any(
                            context.read<CorpusRepository>().ontology.certificationSensitive.contains,
                          )) ...[
                            const SizedBox(height: 14),
                            CertificationNote(onMore: () => openFaq(context, entryId: 'halal-kosher')),
                          ],
                          const SizedBox(height: 24),
                          MonoLabel(tr('ob.diet.classes')),
                          const SizedBox(height: 6),
                          ClassAvoidanceEditor(profile: profile, onChanged: _update),
                          const SizedBox(height: 24),
                          MonoLabel(tr('ob.diet.specific')),
                          const SizedBox(height: 10),
                          IngredientAvoidPicker(profile: profile, onChanged: _update),
                        ],
                      ),
                    ),
                    _StepPage(
                      title: tr('ob.limits.title'),
                      body: tr('ob.limits.body'),
                      child: LimitsEditor(profile: profile, onChanged: _update),
                    ),
                    _StepPage(
                      title: _name.text.trim().isEmpty
                          ? tr('ob.confirm.title.anon')
                          : tr('ob.confirm.title', {'name': _name.text.trim()}),
                      body: tr('ob.confirm.body'),
                      child: ProfileSummaryCard(profile: profile),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  children: [
                    if (_page > 0)
                      PaperButton(label: tr('ob.back'), onPressed: () => _go(_page - 1))
                    else
                      const SizedBox.shrink(),
                    const Spacer(),
                    if (_page < _steps - 1)
                      InkButton(
                        key: const Key('ob-next'),
                        label: tr('ob.next'),
                        icon: Icons.arrow_forward,
                        onPressed: () => _go(_page + 1),
                      )
                    else
                      InkButton(
                        key: const Key('ob-start'),
                        label: tr('ob.start'),
                        color: MC.coralDeep,
                        onPressed: _finish,
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
}

class _StepPage extends StatelessWidget {
  const _StepPage({required this.title, required this.body, required this.child});
  final String title;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
    children: [
      Text(title, style: MT.display(36)),
      const SizedBox(height: 10),
      Text(body, style: MT.serif(16, color: MC.inkSoft)),
      const SizedBox(height: 26),
      child,
    ],
  );
}

class _StepLanguage extends StatelessWidget {
  const _StepLanguage({required this.profile, required this.onChanged});
  final Profile profile;
  final ProfileChanged onChanged;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    Widget choice(String lang, String label, String sample) {
      final selected = profile.lang == lang;
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Material(
          color: selected ? MC.ink : MC.card,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: selected ? MC.ink : MC.rule),
            borderRadius: BorderRadius.circular(2),
          ),
          child: InkWell(
            key: Key('lang-$lang'),
            onTap: () => onChanged(profile.copyWith(lang: lang)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: MT.display(28, color: selected ? MC.card : MC.ink)),
                        const SizedBox(height: 4),
                        Text(sample, style: MT.hand(20, color: selected ? MC.mustard : MC.coralDeep)),
                      ],
                    ),
                  ),
                  if (selected) const Icon(Icons.check, color: MC.card),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      children: [
        Text(tr('ob.lang.title'), style: MT.display(40)),
        const SizedBox(height: 8),
        HandNote(tr('app.tagline'), size: 24),
        const SizedBox(height: 18),
        Text(tr('ob.lang.body'), style: MT.serif(16, color: MC.inkSoft)),
        const SizedBox(height: 26),
        choice('en', 'english', 'a cookbook for every body'),
        choice('de', 'deutsch', 'ein kochbuch für jeden körper'),
      ],
    );
  }
}
