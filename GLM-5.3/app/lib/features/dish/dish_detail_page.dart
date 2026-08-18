import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/matching/variant_matrix.dart';
import '../../core/models/ingredient_guide.dart';
import '../../core/models/recipe.dart';
import '../../core/services/profile_store.dart';
import '../../core/shopping/units.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/chips.dart';
import '../../core/theme/dashed_rule.dart';
import '../../core/theme/paper.dart';
import '../../core/theme/striped_placeholder.dart';
import '../../l10n/tr.dart';
import '../../state/app_state.dart';
import '../routes.dart';
import 'variant_switcher.dart';

/// Dish detail with the per-dimension variant switchers — the money shot.
class DishDetailPage extends StatefulWidget {
  const DishDetailPage({super.key, required this.dishId});

  final String dishId;

  @override
  State<DishDetailPage> createState() => _DishDetailPageState();
}

class _DishDetailPageState extends State<DishDetailPage> {
  String? _diet;
  String? _effort;
  String? _calorieBucket;
  Recipe? _previous;
  bool _resumeChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkResume());
  }

  void _checkResume() {
    if (_resumeChecked || !mounted) return;
    _resumeChecked = true;
    final state = context.read<AppState>();
    final progress = state.cookProgress.load();
    final dish = state.corpus.dishes[widget.dishId];
    if (progress == null || dish == null) return;
    if (!dish.variants.contains(progress.recipeId)) return;
    final recipe = state.corpus.recipe(progress.recipeId);
    if (recipe == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.paperCard,
        title:
            Text(dialogContext.trRead('dish.resumeCook'), style: AppFonts.display(size: 20)),
        content: Text(
          dialogContext.trRead('dish.resumeCookBody', {'n': '${progress.stepIndex + 1}'}),
          style: AppFonts.serif(size: 14, color: AppColors.inkSoft),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              openCook(dialogContext, recipe, resume: progress);
            },
            child: Text(dialogContext.trRead('common.next')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.trRead('dish.startOver')),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dish = state.corpus.dishes[widget.dishId];
    if (dish == null) {
      return PaperScaffold(
        appBar: AppBar(backgroundColor: AppColors.paper, elevation: 0),
        body: Center(child: Text(context.tr('common.error'))),
      );
    }
    final variants = state.allVariantsOf(dish);
    final matrix = VariantMatrix(variants);
    final best = state.bestVariantFor(dish);
    if (_diet == null) {
      final anchor = best ?? (variants.isEmpty ? null : variants.first);
      if (anchor != null) {
        _diet = anchor.diet;
        _effort = anchor.effort;
        _calorieBucket = anchor.calorieBucket;
      }
    }
    final recipe = matrix.resolve(_diet, _effort, _calorieBucket);
    final outsideProfile = best == null && recipe != null;
    final reduceMotion =
        state.profile.reduceMotion ?? MediaQuery.of(context).disableAnimations;

    return PaperScaffold(
      seed: dish.id.hashCode,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
        title: Text('morphcook', style: AppFonts.display(size: 20)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.localized(dish.name),
              style: AppFonts.display(size: 38, color: AppColors.ink),
            ),
            const SizedBox(height: 4),
            Text(
              state.localized(dish.hero),
              style: AppFonts.serif(size: 14, color: AppColors.inkSoft, height: 1.4),
            ),
            const SizedBox(height: 12),
            StripedPlaceholder(
              stripeColor: dish.stripeColor,
              caption: state.localized(dish.cap),
              aspect: 1.7,
              seed: dish.id.hashCode,
            ),
            const SizedBox(height: 8),
            const DashedRule(glyph: '×'),
            if (variants.isNotEmpty)
              VariantSwitcher(
                matrix: matrix,
                selected: recipe ?? variants.first,
                ontology: state.corpus.ontology,
                lang: state.lang,
                reduceMotion: reduceMotion,
                labels: {
                  VariantDimension.diet: context.tr('common.diet'),
                  VariantDimension.effort: context.tr('common.effort'),
                  VariantDimension.calorie: context.tr('common.calorieLevel'),
                },
                disabledReason: (value, dim) =>
                    _profileBlockNote(state, variants, value, dim, dish.id),
                onSelect: (dim, value) {
                  setState(() {
                    _previous = recipe;
                    switch (dim) {
                      case VariantDimension.diet:
                        _diet = value;
                      case VariantDimension.effort:
                        _effort = value;
                      case VariantDimension.calorie:
                        _calorieBucket = value;
                    }
                  });
                },
              ),
            if (state.profile.calorieTarget != null) _overrideRow(state, dish.id),
            const DashedRule(glyph: '&'),
            if (outsideProfile) _outsideNote(context),
            if (recipe != null)
              _MorphPanel(
                key: ValueKey('panel-${recipe.id}'),
                recipe: recipe,
                previous: _previous,
                reduceMotion: reduceMotion,
              ),
          ],
        ),
      ),
    );
  }
  Widget _overrideRow(AppState state, String dishId) {
    final enabled = state.calorieOverride(dishId);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('dish.calorieOverride'),
                  style: AppFonts.mono(size: 11, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            activeColor: AppColors.teal,
            onChanged: (v) => state.setCalorieOverride(dishId, v),
          ),
          QuietLink(
            label: context.tr('common.why'),
            onTap: () => openFaq(context, 'faq-calorie-override'),
          ),
        ],
      ),
    );
  }

  Widget _outsideNote(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              context.tr('dish.noVariant'),
              style: AppFonts.hand(size: 18, color: AppColors.coralDeep),
            ),
          ),
          QuietLink(label: context.tr('common.why'), onTap: () => openFaq(context, 'faq-dish-missing')),
        ],
      ),
    );
  }

  /// Reason a chip's value would collide with the profile, or null when the
  /// value is fine. Used to disable chips with a note, never to hide them.
  String? _profileBlockNote(
    AppState state,
    List<Recipe> variants,
    String value,
    VariantDimension dim,
    String dishId,
  ) {
    Iterable<Recipe> candidates;
    switch (dim) {
      case VariantDimension.diet:
        candidates = variants.where((r) => r.diet == value);
      case VariantDimension.effort:
        candidates = variants.where((r) => r.effort == value);
      case VariantDimension.calorie:
        candidates = variants.where((r) => r.calorieBucket == value);
    }
    // If every recipe behind that value is invisible, disable the chip.
    for (final recipe in candidates) {
      if (state.isVisible(recipe, dishId: dishId)) return null;
    }
    final first = candidates.isEmpty ? null : candidates.first;
    if (first == null) return null;
    final reason = state.matcher.blockingReason(first, state.profile, state.ontologyRef);
    if (reason == null) return null;
    if (reason.startsWith('flag:')) {
      final flag = reason.substring(5);
      final label = state.corpus.ontology.flagLabel(flag, state.lang);
      return '${state.lang == 'de' ? 'enthält' : 'contains'}: $label';
    }
    if (reason.startsWith('ingredient:')) {
      final id = reason.substring(11);
      return state.corpus.ingredients.nameOf(id, state.lang);
    }
    if (reason == 'time') {
      return state.lang == 'de'
          ? 'über deinem zeitbudget'
          : 'over your time budget';
    }
    if (reason == 'calorie') {
      return state.lang == 'de'
          ? 'außerhalb deines kalorienziels'
          : 'outside your calorie target';
    }
    return reason;
  }
}

/// The recipe panel that morphs when the variant changes: the panel fades
/// and changed ingredient lines flash (SPEC: highlight flash + fade),
/// unless reduce-motion is on.
class _MorphPanel extends StatelessWidget {
  const _MorphPanel({
    super.key,
    required this.recipe,
    required this.previous,
    required this.reduceMotion,
  });

  final Recipe recipe;
  final Recipe? previous;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.lang;
    final changed = <String>{};
    if (previous != null && previous!.id != recipe.id) {
      changed.addAll(recipe.ingredientIds.difference(previous!.ingredientIds));
      changed.addAll(previous!.ingredientIds.difference(recipe.ingredientIds));
    }
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 260),
      child: Column(
        key: ValueKey(recipe.id),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  state.localized(recipe.title),
                  style: AppFonts.display(size: 26, color: AppColors.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _actionRow(context, state),
          const SizedBox(height: 12),
          if (state.profile.showVariantTags) _tagsRow(context, state, lang),
          _sectionLabel('${context.tr('common.ingredients')} — '
              '${context.tr('dish.ingredientsFor', {'n': '${recipe.servings}'})}'),
          for (final line in recipe.ingredients)
            _IngredientLine(
              line: line,
              flash: changed.contains(line.id),
              reduceMotion: reduceMotion,
            ),
          const SizedBox(height: 10),
          _sectionLabel(context.tr('common.method')),
          for (var i = 0; i < recipe.steps.length; i++)
            _MethodStep(stepIndex: i, recipe: recipe, lang: lang),
          const SizedBox(height: 10),
          _sectionLabel(context.tr('common.macros')),
          _macrosRow(context),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
  Widget _actionRow(BuildContext context, AppState state) {
    final saved = state.isSaved(recipe.id);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ActionChip(
          icon: saved ? Icons.bookmark : Icons.bookmark_border,
          label: context.tr(saved ? 'dish.unsave' : 'dish.save'),
          onTap: () {
            state.toggleSaved(recipe.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.trRead(saved ? 'dish.unsave' : 'dish.saved'))),
            );
          },
        ),
        _ActionChip(
          icon: Icons.local_fire_department_outlined,
          label: context.tr('dish.cook'),
          onTap: () => openCook(context, recipe),
        ),
        _ActionChip(
          icon: Icons.shopping_bag_outlined,
          label: context.tr('dish.shop'),
          onTap: () async {
            await state.addRecipesToShopping([recipe]);
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(context.trRead('shop.added'))));
            }
          },
        ),
        _ActionChip(
          icon: Icons.history_edu_outlined,
          label: context.tr('dish.markCooked'),
          onTap: () {
            state.recordCooked(recipe.id);
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(context.trRead('dish.markedCooked'))));
          },
        ),
      ],
    );
  }

  Widget _tagsRow(BuildContext context, AppState state, String lang) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          TagChip(label: state.corpus.ontology.attrLabel(recipe.diet, lang)),
          TagChip(label: state.corpus.ontology.attrLabel(recipe.effort, lang)),
          TagChip(
              label:
                  '${recipe.timeMinutes} ${context.trRead('common.min')}'),
          TagChip(label: '~${recipe.cal} ${context.trRead('common.kcal')}'),
          for (final flag in recipe.contains.take(4))
            TagChip(
              label: state.corpus.ontology.flagLabel(flag, lang),
              color: AppColors.coral,
            ),
        ],
      ),
    );
  }

  Widget _macrosRow(BuildContext context) {
    final columns = [
      ['${recipe.cal}', context.tr('common.kcal')],
      ['${recipe.protein} g', context.tr('common.protein')],
      ['${recipe.carbs} g', context.tr('common.carbs')],
      ['${recipe.fat} g', context.tr('common.fat')],
    ];
    return Row(
      children: [
        for (var i = 0; i < columns.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 34,
              color: AppColors.inkFaint,
              margin: const EdgeInsets.symmetric(horizontal: 10),
            ),
          Expanded(
            child: Column(
              children: [
                Text(columns[i][0],
                    style: AppFonts.display(size: 19, color: AppColors.tealDeep)),
                Text(columns[i][1],
                    style: AppFonts.mono(size: 9, color: AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Text(
        text,
        style: AppFonts.mono(size: 10, color: AppColors.coral, letterSpacing: 1.4),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.teal),
          color: AppColors.teal.withOpacity(0.08),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.teal),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppFonts.mono(size: 11, color: AppColors.teal, weight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
/// One ingredient line: mono quantity, serif name, optional "learn more"
/// opening the ingredient guide (SPEC kitchen reference).
class _IngredientLine extends StatelessWidget {
  const _IngredientLine({
    required this.line,
    required this.flash,
    required this.reduceMotion,
  });

  final RecipeIngredient line;
  final bool flash;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final guide = state.corpus.guide.forIngredient(line.id);
    final name = state.corpus.ingredients.nameOf(line.id, state.lang);
    final qty = '${formatQty(line.qty)} ${line.unit}';
    return _FlashWrap(
      flash: flash,
      reduceMotion: reduceMotion,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 84,
              child: Text(qty,
                  style: AppFonts.mono(size: 12, color: AppColors.teal, weight: FontWeight.w600)),
            ),
            Expanded(child: Text(name, style: AppFonts.serif(size: 15))),
            if (guide != null)
              QuietLink(
                label: context.tr('common.learnMore'),
                onTap: () => _openGuide(context, guide),
              ),
          ],
        ),
      ),
    );
  }

  void _openGuide(BuildContext context, GuideEntry guideEntry) {
    final state = context.read<AppState>();
    final lang = state.lang;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.paperCard,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.corpus.ingredients.nameOf(line.id, lang),
                  style: AppFonts.display(size: 26),
                ),
                const SizedBox(height: 8),
                _guideBlock('✎', guideEntry.summary[lang] ?? guideEntry.summary['en'] ?? ''),
                _guideBlock('⌘', guideEntry.usage[lang] ?? guideEntry.usage['en'] ?? ''),
                _guideBlock('⌂', guideEntry.storage[lang] ?? guideEntry.storage['en'] ?? ''),
                _guideBlock('⌖', guideEntry.whereToFind[lang] ?? guideEntry.whereToFind['en'] ?? ''),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _guideBlock(String glyph, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(glyph, style: AppFonts.mono(size: 12, color: AppColors.coral)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: AppFonts.serif(size: 14, color: AppColors.inkSoft, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

/// Highlight flash wrapper for changed ingredient lines.
class _FlashWrap extends StatefulWidget {
  const _FlashWrap({required this.flash, required this.reduceMotion, required this.child});

  final bool flash;
  final bool reduceMotion;
  final Widget child;

  @override
  State<_FlashWrap> createState() => _FlashWrapState();
}

class _FlashWrapState extends State<_FlashWrap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.reduceMotion ? Duration.zero : const Duration(milliseconds: 900),
    );
    if (widget.flash) _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant _FlashWrap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.flash && !oldWidget.flash) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.flash) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOut.transform(1 - _controller.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.mustard.withOpacity(0.45 * t),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// One numbered method step with its optional timer chip.
class _MethodStep extends StatelessWidget {
  const _MethodStep({required this.stepIndex, required this.recipe, required this.lang});

  final int stepIndex;
  final Recipe recipe;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final step = recipe.steps[stepIndex];
    final minutes = step.timerSeconds == null
        ? null
        : (step.timerSeconds! / 60).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '${stepIndex + 1}.',
              style: AppFonts.mono(size: 12, color: AppColors.coral, weight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              step.text[lang] ?? step.text['en'] ?? '',
              style: AppFonts.serif(size: 15, height: 1.45),
            ),
          ),
          if (minutes != null)
            TagChip(label: '⏱ $minutes ${context.trRead('common.min')}'),
        ],
      ),
    );
  }
}
