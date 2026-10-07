import 'package:flutter/material.dart' hide Typography;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/strings.dart';
import '../../core/model/guide.dart';
import '../../core/model/recipe.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../core/units.dart';
import '../../navigation.dart';
import '../../state/app_state.dart';
import '../../widgets/controls.dart';
import '../../widgets/help_link.dart';
import '../../widgets/paper.dart';
import '../../widgets/stripe_plate.dart';
import '../cook/cook_screen.dart';

/// Dish detail — the money shot. Per-dimension variant switchers (diet,
/// effort, calorie level), each collapsed by default showing the current
/// selection; tap to reveal alternatives. Unreachable combinations are
/// disabled with a note, never hidden.
class DishScreen extends StatefulWidget {
  final String dishId;

  const DishScreen({super.key, required this.dishId});

  @override
  State<DishScreen> createState() => _DishScreenState();
}

class _DishScreenState extends State<DishScreen> {
  List<Recipe>? _variants;
  String? _error;
  Recipe? _selected;
  String? _expanded; // 'diet' | 'effort' | 'calorie' | null
  bool _showOutsideTarget = false;
  Set<String> _previousIngredientIds = {};

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    appState.corpus.recipesOfDish(widget.dishId).then((variants) {
      if (!mounted) return;
      setState(() {
        _variants = variants;
        _selected = appState.matcher.pickBest(
          variants,
          appState.profile,
          ignoreCalorieTarget: _showOutsideTarget,
        ) ?? (variants.isNotEmpty ? variants.first : null);
        _previousIngredientIds = _selected?.ingredientIds ?? {};
      });
    }).catchError((e) {
      if (mounted) setState(() => _error = e.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final s = Strings(appState.profile.lang);
    final corpus = appState.corpus;
    final matcher = appState.matcher;
    final profile = appState.profile;
    final dish = corpus.dishById(widget.dishId);

    if (dish == null) {
      return PaperScaffold(body: Center(child: HandNote('not found', size: 24)));
    }

    final variants = _variants;
    if (_error != null) {
      return PaperScaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HandNote(s.commonError, size: 22),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(s.commonRetry)),
            ],
          ),
        ),
      );
    }
    if (variants == null || _selected == null) {
      return const PaperScaffold(body: Center(child: CircularProgressIndicator()));
    }
    final selected = _selected!;

    // Dimension values of the current selection.
    String bucketOf(Recipe r) => corpus.ontology.calorieBucketFor(r.caloriesPerServing);
    final current = _VariantSelection(
      diet: selected.diet,
      effort: selected.effort,
      calorie: bucketOf(selected),
    );

    // Availability of every option in every dimension, given the current
    // selection on the other two dimensions.
    _OptionState optionState(String dimension, String value) {
      final candidates = variants.where((v) {
        if (dimension != 'diet' && v.diet != current.diet) return false;
        if (dimension != 'effort' && v.effort != current.effort) return false;
        if (dimension != 'calorie' && bucketOf(v) != current.calorie) return false;
        if (dimension == 'diet' && v.diet != value) return false;
        if (dimension == 'effort' && v.effort != value) return false;
        if (dimension == 'calorie' && bucketOf(v) != value) return false;
        return true;
      }).toList();
      if (candidates.isEmpty) {
        final other = dimension == 'diet'
            ? '${s.effortLabel(current.effort)} × ${current.calorie}'
            : dimension == 'effort'
                ? '${s.dietLabel(current.diet)} × ${current.calorie}'
                : '${s.dietLabel(current.diet)} × ${s.effortLabel(current.effort)}';
        final dietName = dimension == 'diet' ? s.dietLabel(value) : null;
        return _OptionState(
          reachable: false,
          blocked: false,
          note: dietName != null
              ? s.dishUnreachable.replaceAll('{diet}', dietName).replaceAll('{effort}', other)
              : s.dishUnreachable.replaceAll('{diet}', other).replaceAll('{effort}', value),
        );
      }
      final visible = matcher.visibleVariants(candidates, profile,
          ignoreCalorieTarget: _showOutsideTarget);
      if (visible.isEmpty) {
        return _OptionState(reachable: true, blocked: true, note: s.dishBlockedByProfile);
      }
      return const _OptionState(reachable: true, blocked: false);
    }

    void select(String dimension, String value) {
      final state = optionState(dimension, value);
      if (!state.reachable || state.blocked) return;
      final next = _VariantSelection(
        diet: dimension == 'diet' ? value : current.diet,
        effort: dimension == 'effort' ? value : current.effort,
        calorie: dimension == 'calorie' ? value : current.calorie,
      );
      final candidates = variants.where((v) =>
          v.diet == next.diet && v.effort == next.effort && bucketOf(v) == next.calorie);
      final best = matcher.pickBest(candidates.toList(), profile,
          ignoreCalorieTarget: _showOutsideTarget);
      if (best == null) return;
      setState(() {
        _previousIngredientIds = selected.ingredientIds;
        _selected = best;
        _expanded = null;
      });
    }

    final changedIds = selected.ingredientIds.difference(_previousIngredientIds);

    return PaperScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(s.dishBackToPaper,
                  style: Typography.mono(10, letterSpacing: 1.4, color: Palette.teal)),
            ),
          ),
          StripedPlate(
            color: _color(dish.stripeColor),
            caption: selected.subtitle.resolve(s.lang),
            height: 200,
            tiltDeg: -0.5,
          ),
          const SizedBox(height: 12),
          Text(dish.name.resolve(s.lang), style: Typography.display(30)),
          const SizedBox(height: 4),
          Text(dish.hero.resolve(s.lang), style: Typography.body(16, italic: true)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              MetaPill(label: s.dishTime, value: '${selected.timeMinutes} ${s.commonMin}'),
              MetaPill(label: s.dishServes, value: '${selected.servings}'),
              MetaPill(
                  label: '~${selected.caloriesPerServing} ${s.commonKcal}', value: s.dishPerServing),
            ],
          ),
          const SizedBox(height: 16),
          _SwitcherRow(
            s: s,
            label: s.dishDimDiet,
            current: s.dietLabel(current.diet),
            expanded: _expanded == 'diet',
            onToggle: () => setState(() => _expanded = _expanded == 'diet' ? null : 'diet'),
            options: [
              for (final diet in corpus.ontology.dietOptions)
                if (variants.any((v) => v.diet == diet))
                  _option(optionState('diet', diet), s.dietLabel(diet),
                      () => select('diet', diet), selected: diet == current.diet),
            ],
          ),
          _SwitcherRow(
            s: s,
            label: s.dishDimEffort,
            current: s.effortLabel(current.effort),
            expanded: _expanded == 'effort',
            onToggle: () => setState(() => _expanded = _expanded == 'effort' ? null : 'effort'),
            options: [
              for (final effort in corpus.ontology.effortLevels)
                if (variants.any((v) => v.effort == effort))
                  _option(optionState('effort', effort), s.effortLabel(effort),
                      () => select('effort', effort), selected: effort == current.effort),
            ],
          ),
          _SwitcherRow(
            s: s,
            label: s.dishDimCalorie,
            current: '~${selected.caloriesPerServing} ${s.commonKcal}',
            expanded: _expanded == 'calorie',
            onToggle: () => setState(() => _expanded = _expanded == 'calorie' ? null : 'calorie'),
            options: [
              for (final bucket in corpus.ontology.calorieBuckets)
                if (variants.any((v) => bucketOf(v) == bucket))
                  _option(optionState('calorie', bucket), '$bucket ${s.commonKcal}',
                      () => select('calorie', bucket), selected: bucket == current.calorie),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(s.dishShowOutsideTarget, style: Typography.body(14, italic: true)),
              ),
              Switch(
                value: _showOutsideTarget,
                onChanged: (v) {
                  setState(() {
                    _showOutsideTarget = v;
                    _selected = matcher.pickBest(variants, profile, ignoreCalorieTarget: v) ??
                        matcher.pickBest(variants, profile, ignoreCalorieTarget: false) ??
                        selected;
                  });
                },
              ),
            ],
          ),
          Row(
            children: [
              Text(s.dishContains, style: Typography.mono(9.5, color: Palette.inkFaint)),
              const SizedBox(width: 6),
              HelpLink(faqId: 'visibility-why-hidden', onOpen: (id) => openFaq(context, initialId: id)),
            ],
          ),
          const SizedBox(height: 6),
          SectionLabel(s.dishIngredients),
          _IngredientList(
            key: ValueKey(selected.id),
            recipe: selected,
            lang: s.lang,
            changedIds: changedIds,
            onLearnMore: (ingredientId) => _showIngredientGuide(context, ingredientId, s.lang),
            reduceMotion: profile.reduceMotion ?? MediaQuery.of(context).disableAnimations,
          ),
          SectionLabel(s.dishMethod),
          for (var i = 0; i < selected.steps.length; i++)
            _StepRow(
              index: i,
              step: selected.steps[i],
              lang: s.lang,
              timerLabel: s.dishStepTimer,
            ),
          SectionLabel(s.dishMacros),
          _MacroRow(macros: selected.macros, s: s),
          const SizedBox(height: 4),
          Text(
            '${s.dishContains}: ${selected.contains.map(s.flagLabel).join(' · ')}',
            style: Typography.mono(9.5, color: Palette.inkFaint),
          ),
          const SizedBox(height: 20),
          InkButton(
            s.dishCookThis.toUpperCase(),
            icon: Icons.local_fire_department_outlined,
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CookScreen(recipe: selected),
              ));
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkButton(
                  (appState.isSaved(selected.id) ? s.dishSaved : s.dishSaveVersion).toUpperCase(),
                  outlined: true,
                  onTap: () {
                    appState.toggleSaved(selected.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(s.dishSaved)),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkButton(
            s.dishAddToMarket.toUpperCase(),
            sage: true,
            icon: Icons.add_shopping_cart_outlined,
            onTap: () async {
              await appState.addRecipeToShopping(selected);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(s.dishAddedToMarket)),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _option(_OptionState state, String label, VoidCallback onTap, {required bool selected}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PaperChip(
            label: label,
            selected: selected,
            enabled: state.reachable && !state.blocked,
            onTap: onTap,
          ),
          if (!state.reachable && state.note != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(state.note!, style: Typography.mono(8.5, color: Palette.inkFaint)),
            )
          else if (state.blocked)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(state.note ?? '', style: Typography.mono(8.5, color: Palette.inkFaint)),
            ),
        ],
      );

  Future<void> _showIngredientGuide(BuildContext context, String ingredientId, String lang) async {
    final appState = context.read<AppState>();
    final entry = await appState.corpus.loadIngredientGuideEntry(ingredientId);
    if (entry == null || !context.mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => _IngredientGuideSheet(entry: entry, lang: lang, s: Strings(lang)),
    );
  }
}

class _VariantSelection {
  final String diet;
  final String effort;
  final String calorie;

  _VariantSelection({required this.diet, required this.effort, required this.calorie});
}

class _OptionState {
  final bool reachable;
  final bool blocked;
  final String? note;

  const _OptionState({required this.reachable, required this.blocked, this.note});
}

/// One switcher row: collapsed shows only the current selection; tap the
/// chevron to reveal the option chips.
class _SwitcherRow extends StatelessWidget {
  final Strings s;
  final String label;
  final String current;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> options;

  const _SwitcherRow({
    required this.s,
    required this.label,
    required this.current,
    required this.expanded,
    required this.onToggle,
    required this.options,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Palette.line, width: 1)),
              ),
              child: Row(
                children: [
                  Text('— $label', style: Typography.mono(11, weight: FontWeight.w700, letterSpacing: 1.6, color: Palette.inkFaint)),
                  const Spacer(),
                  Text(current, style: Typography.body(16, italic: true, color: Palette.ink)),
                  const SizedBox(width: 8),
                  Text(expanded ? '⌃' : '⌄', style: Typography.mono(12, color: Palette.coral)),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Wrap(spacing: 8, runSpacing: 6, children: options),
            ),
        ],
      );
}

class _IngredientList extends StatelessWidget {
  final Recipe recipe;
  final String lang;
  final Set<String> changedIds;
  final void Function(String ingredientId) onLearnMore;
  final bool reduceMotion;

  const _IngredientList({
    super.key,
    required this.recipe,
    required this.lang,
    required this.changedIds,
    required this.onLearnMore,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final corpus = context.read<AppState>().corpus;
    return Column(
      children: [
        for (final line in recipe.ingredients)
          Builder(builder: (context) {
            final changed = changedIds.contains(line.ingredientId);
            final row = Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0x80D8CDB8), width: 0.7)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      corpus.ingredients.nameOf(line.ingredientId, lang) +
                          (line.note != null ? ' — ${line.note!.resolve(lang)}' : ''),
                      style: Typography.body(15, color: Palette.ink),
                    ),
                  ),
                  Text(
                    Units.format(line.amount, line.unit),
                    style: Typography.mono(11, weight: FontWeight.w700, color: Palette.teal),
                  ),
                  const SizedBox(width: 8),
                  LearnMoreLink(
                    label: Strings(lang).dishLearnMore,
                    onTap: () => onLearnMore(line.ingredientId),
                  ),
                ],
              ),
            );
            if (!changed) return row;
            // Highlight flash on changed ingredients when switching variants.
            return row
                .animate(target: 1)
                .custom(
                  duration: reduceMotion ? Motion.fastReduced : const Duration(milliseconds: 1400),
                  builder: (context, value, child) => DecoratedBox(
                    decoration: BoxDecoration(
                      color: Palette.mustard.withValues(alpha: 0.35 * (1 - value)),
                    ),
                    child: child,
                  ),
                );
          }),
      ],
    ).animate(key: ValueKey(recipe.id)).fadeIn(
          duration: reduceMotion ? Motion.fastReduced : Motion.morph,
        );
  }
}

class _StepRow extends StatelessWidget {
  final int index;
  final CookStep step;
  final String lang;
  final String timerLabel;

  const _StepRow({required this.index, required this.step, required this.lang, required this.timerLabel});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('0${index + 1}', style: Typography.mono(11, weight: FontWeight.w700, color: Palette.coral)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.text.resolve(lang), style: Typography.body(15, color: Palette.ink)),
                  if (step.timerMinutes != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text('⏱ $timerLabel ${step.timerMinutes} ${Strings(lang).commonMin}',
                          style: Typography.mono(9.5, color: Palette.inkFaint)),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _MacroRow extends StatelessWidget {
  final Macros macros;
  final Strings s;

  const _MacroRow({required this.macros, required this.s});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (final (value, label) in [
            (macros.kcal.toString(), s.commonKcal),
            ('${macros.proteinG}g', 'protein'),
            ('${macros.carbsG}g', 'carbs'),
            ('${macros.fatG}g', 'fat'),
          ])
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(border: Border.all(color: Palette.line)),
                child: Column(
                  children: [
                    Text(value, style: Typography.mono(14, weight: FontWeight.w700, color: Palette.ink)),
                    const SizedBox(height: 2),
                    Text(label, style: Typography.mono(8.5, color: Palette.inkFaint)),
                  ],
                ),
              ),
            ),
        ],
      );
}

class _IngredientGuideSheet extends StatelessWidget {
  final IngredientGuideEntry entry;
  final String lang;
  final Strings s;

  const _IngredientGuideSheet({required this.entry, required this.lang, required this.s});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.name.resolve(lang), style: Typography.display(24)),
            const SizedBox(height: 10),
            Text(entry.description.resolve(lang), style: Typography.body(15, italic: true)),
            const SizedBox(height: 12),
            _guideLine('tips', entry.usageTips.resolve(lang)),
            _guideLine('storage', entry.storage.resolve(lang)),
            _guideLine('find', entry.whereToFind.resolve(lang)),
            const SizedBox(height: 12),
          ],
        ),
      );

  Widget _guideLine(String label, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 70,
              child: Text(label.toUpperCase(), style: Typography.mono(9, weight: FontWeight.w700, letterSpacing: 1.6, color: Palette.teal)),
            ),
            Expanded(child: Text(text, style: Typography.body(14, color: Palette.ink))),
          ],
        ),
      );
}

Color _color(String hex) {
  final digits = hex.replaceFirst('#', '');
  final value = int.tryParse(digits, radix: 16);
  if (value == null) return Palette.coral;
  return Color(digits.length == 6 ? 0xFF000000 | value : value);
}
