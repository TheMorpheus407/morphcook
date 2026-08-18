import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/profile.dart';
import 'strings.dart';
import 'theme.dart';
import 'widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _page = 0;
  String _lang = 'en';
  String _name = '';
  final Set<String> _avoidFlags = {};
  final Set<String> _avoidIngredients = {};
  int? _calories;
  int? _time;
  String _effort = 'easy';

  S get s => S(_lang);

  @override
  Widget build(BuildContext context) {
    final p = LedgerScope.colors(context);
    final page = switch (_page) {
      0 => _language(),
      1 => _namePage(),
      2 => _diet(),
      3 => _targets(),
      _ => _confirm(),
    };
    return PaperBackdrop(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'morphcook',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: (_page + 1) / 5,
                minHeight: 2,
                color: p.clay,
                backgroundColor: p.line,
              ),
              const SizedBox(height: 28),
              Expanded(child: page),
              Row(
                children: [
                  if (_page > 0)
                    TextButton(
                      onPressed: () => setState(() => _page--),
                      child: Text(s('back')),
                    ),
                  const Spacer(),
                  QuietButton(
                    label: _page == 4 ? s('letsCook') : s('next'),
                    onPressed: _advance,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _advance() async {
    if (_page < 4) {
      setState(() => _page++);
      return;
    }
    final state = context.read<AppState>();
    await state.completeOnboarding(
      Profile(
        name: _name.trim(),
        lang: _lang,
        avoidFlags: Set.of(_avoidFlags),
        avoidIngredients: Set.of(_avoidIngredients),
        calorieTarget: _calories,
        maxTimeMinutes: _time,
        preferredEffort: _effort,
      ),
    );
  }

  Widget _language() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s('obLanguageTitle'), style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          children: [
            SoftChip(
              label: 'english',
              selected: _lang == 'en',
              onTap: () => setState(() => _lang = 'en'),
            ),
            SoftChip(
              label: 'deutsch',
              selected: _lang == 'de',
              onTap: () => setState(() => _lang = 'de'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _namePage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s('obNameTitle'), style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 24),
        TextField(
          autofocus: true,
          onChanged: (v) => _name = v,
          decoration: InputDecoration(
            hintText: s('obNameHint'),
            border: const UnderlineInputBorder(),
          ),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ],
    );
  }

  Widget _diet() {
    final state = context.watch<AppState>();
    final compounds = state.corpus.ontology.compoundFlags;
    return ListView(
      children: [
        Text(s('obDietTitle'), style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 8),
        Text(s('obDietSub')),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in compounds)
              SoftChip(
                label: c.name.of(_lang),
                selected: _avoidFlags.contains(c.id),
                onTap: () => setState(() {
                  if (!_avoidFlags.add(c.id)) _avoidFlags.remove(c.id);
                }),
              ),
          ],
        ),
        const SizedBox(height: 28),
        Text(s('obAllergyTitle'), style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in state.corpus.ontology.containsFlags.take(16))
              SoftChip(
                label: f.name.of(_lang),
                selected: _avoidFlags.contains(f.id),
                onTap: () => setState(() {
                  if (!_avoidFlags.add(f.id)) _avoidFlags.remove(f.id);
                }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _targets() {
    return ListView(
      children: [
        Text(s('obTargetsTitle'), style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 20),
        Text(s('obCalories')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final cal in [null, 400, 550, 700, 900])
              SoftChip(
                label: cal == null ? s('noLimit') : '$cal kcal',
                selected: _calories == cal,
                onTap: () => setState(() => _calories = cal),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(s('obTime')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final t in [null, 15, 30, 45, 60, 90])
              SoftChip(
                label: t == null ? s('noLimit') : '$t ${s('minutes')}',
                selected: _time == t,
                onTap: () => setState(() => _time = t),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(s('preferredEffort')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final e in ['easy', 'medium', 'hard'])
              SoftChip(
                label: e,
                selected: _effort == e,
                onTap: () => setState(() => _effort = e),
              ),
          ],
        ),
      ],
    );
  }

  Widget _confirm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s('obConfirmTitle'), style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 16),
        Text(s('obConfirmBody'), style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 24),
        if (_name.trim().isNotEmpty)
          Text(
            _name.trim(),
            style: const TextStyle(
              fontFamily: LedgerTheme.caveat,
              fontSize: 32,
            ),
          ),
      ],
    );
  }
}
