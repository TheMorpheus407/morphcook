import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_router.dart';
import '../../core/corpus_repository.dart';
import '../../core/engine/matching.dart';
import '../../core/l10n.dart';
import '../../core/models/dish.dart';
import '../../core/models/ingredient_guide.dart';
import '../../core/models/local_text.dart';
import '../../core/models/profile.dart';
import '../../core/models/recipe.dart';
import '../../core/storage/local_store.dart';
import '../../core/storage/profile_store.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/dashed_rule.dart';
import '../../shared/widgets/striped_image.dart';

/// Dish detail: hero, generic variant-lattice switchers, and the selected
/// variant's ingredients / method / macros. Variants morph in place.
class DishScreen extends StatefulWidget {
  final String dishId;
  const DishScreen({super.key, required this.dishId});

  @override
  State<DishScreen> createState() => _DishScreenState();
}

class _DishScreenState extends State<DishScreen> {
  bool _loading = true;
  Dish? _dish;
  List<Recipe> _variants = const [];

  /// Currently picked lattice coordinates (dimension key → value).
  Map<String, String> _selection = {};
  final Set<String> _expandedDims = {};

  int _servings = 2;

  /// Ingredient ids to flash-highlight after a variant morph.
  Set<String> _flashIds = {};
  int _flashToken = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final corpus = context.read<CorpusRepository>();
    final dish = corpus.dishById(widget.dishId);
    if (dish != null) {
      await corpus.ensureDishLoaded(dish);
    }
    if (!mounted) return;
    final variants = dish == null ? const <Recipe>[] : corpus.variantsOf(dish);
    if (variants.isNotEmpty) {
      final profile = context.read<ProfileStore>().profile;
      final overrideOn = context.read<ProfileStore>().hasCalorieOverride(
        widget.dishId,
      );
      final initial = _pickDefault(variants, profile, overrideOn);
      _selection = Map.of(initial.dimensions);
      _servings = initial.servings;
    }
    setState(() {
      _dish = dish;
      _variants = variants;
      _loading = false;
    });
  }

  /// Profile-picked default: highest-scoring visible variant (calorie target
  /// relaxed when the per-dish override is on), else the nearest by score —
  /// the profile preselects, it never locks.
  Recipe _pickDefault(
    List<Recipe> variants,
    UserProfile profile,
    bool overrideOn,
  ) {
    final matching = context.read<MatchingEngine>();
    Recipe? best;
    var bestScore = -1 << 30;
    for (final r in variants) {
      if (!matching.visible(r, profile, ignoreCalorieTarget: overrideOn)) {
        continue;
      }
      final s = matching.score(r, profile);
      if (s > bestScore) {
        bestScore = s;
        best = r;
      }
    }
    if (best != null) return best;
    for (final r in variants) {
      final s = matching.score(r, profile);
      if (s > bestScore) {
        bestScore = s;
        best = r;
      }
    }
    return best ?? variants.first;
  }

  /// The variant matching every currently selected coordinate.
  Recipe get _current => _variants.firstWhere(
    (r) => _selection.entries.every((e) => r.dimensions[e.key] == e.value),
    orElse: () => _variants.first,
  );

  /// Dimension keys in order of first appearance across variants.
  List<String> get _dimKeys {
    final keys = <String>[];
    for (final v in _variants) {
      for (final k in v.dimensions.keys) {
        if (!keys.contains(k)) keys.add(k);
      }
    }
    return keys;
  }

  List<String> _dimValues(String key) {
    final values = <String>[];
    for (final v in _variants) {
      final value = v.dimensions[key];
      if (value != null && !values.contains(value)) values.add(value);
    }
    return values;
  }

  /// The variant a chip would morph to, or null when the combination does
  /// not exist (sparse lattice) — those chips stay visible but disabled.
  Recipe? _targetFor(String dimKey, String value) {
    for (final r in _variants) {
      if (r.dimensions[dimKey] != value) continue;
      var fits = true;
      for (final e in _selection.entries) {
        if (e.key == dimKey) continue;
        if (r.dimensions[e.key] != e.value) {
          fits = false;
          break;
        }
      }
      if (fits) return r;
    }
    return null;
  }

  void _select(String dimKey, String value) {
    final target = _targetFor(dimKey, value);
    if (target == null) return;
    final old = _current;
    if (old.id == target.id) {
      setState(() => _selection = {..._selection, dimKey: value});
      return;
    }
    setState(() {
      _selection = {..._selection, dimKey: value};
      _flashIds = _changedIngredientIds(old, target);
      _flashToken++;
      _servings = target.servings;
    });
  }

  /// Ids of ingredients that are new or whose amount/unit changed.
  Set<String> _changedIngredientIds(Recipe from, Recipe to) {
    final before = {for (final i in from.ingredients) i.id: i};
    return {
      for (final i in to.ingredients)
        if (before[i.id] == null ||
            before[i.id]!.amount != i.amount ||
            before[i.id]!.unit != i.unit)
          i.id,
    };
  }

  String _unitLabel(String unit, AppStrings s) {
    if (unit == 'g' || unit == 'ml') return unit;
    final key = 'unit.$unit';
    final t = s.t(key);
    return t == key ? unit : t;
  }

  /// Rounds sensibly: integers when clean, halves below 10, whole above.
  String _fmtAmount(double value) {
    final whole = value.round();
    if ((value - whole).abs() < 0.05) return '$whole';
    if (value < 10) {
      final half = (value * 2).round() / 2;
      if ((half - half.round()).abs() < 0.01) return '${half.round()}';
      return half.toStringAsFixed(1);
    }
    return '$whole';
  }

  String _dimLabel(AppStrings s, String dimKey) {
    final key = 'dim.$dimKey';
    final t = s.t(key);
    return t == key ? dimKey.replaceAll('_', ' ') : t;
  }

  String _valueLabel(AppStrings s, String dimKey, String value) {
    // Core l10n already carries diet.*/effort.*/calorie.* labels.
    const aliases = {'calorie_level': 'calorie'};
    for (final key in [
      '$dimKey.$value',
      '${aliases[dimKey] ?? dimKey}.$value',
    ]) {
      final t = s.t(key);
      if (t != key) return t;
    }
    return value;
  }

  Future<void> _toggleSaved(Recipe recipe) async {
    await context.read<LocalStore>().toggleSaved(recipe.id);
  }

  Future<void> _addToShopping(Recipe recipe, AppStrings s) async {
    await context.read<LocalStore>().addToShoppingList(
      recipe.id,
      ingredientIds: recipe.ingredientIds,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.t('dish.addedShopping')),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openGuide(Ingredient ingredient) {
    final entry = context
        .read<CorpusRepository>()
        .ingredientGuide[ingredient.id];
    if (entry == null) return;
    final lang = context.read<ProfileStore>().profile.lang;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.paper,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (context) => _GuideSheet(
        entry: entry,
        ingredientName: localize(ingredient.name, lang),
        lang: lang,
        s: S(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S(context);
    if (_loading) {
      final peek = context.read<CorpusRepository>().dishById(widget.dishId);
      return Scaffold(
        appBar: AppBar(),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: StripedImage(
            stripeColor: peek?.stripeColor ?? '#C4573B',
            caption: s.t('dish.loading'),
            height: 220,
          ),
        ),
      );
    }

    final dish = _dish;
    if (dish == null || _variants.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(s.t('dish.notFound'), style: AppText.handwritten()),
        ),
      );
    }

    final profileStore = context.watch<ProfileStore>();
    final localStore = context.watch<LocalStore>();
    final matching = context.read<MatchingEngine>();
    final profile = profileStore.profile;
    final lang = profile.lang;
    final overrideOn = profileStore.hasCalorieOverride(widget.dishId);
    final reduceMotion =
        profile.reduceMotion ?? MediaQuery.disableAnimationsOf(context);

    final recipe = _current;
    final saved = localStore.isSaved(recipe.id);
    final outside = !matching.visible(
      recipe,
      profile,
      ignoreCalorieTarget: overrideOn,
    );

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: s.t(saved ? 'dish.saved' : 'dish.save'),
            icon: Icon(
              saved ? Icons.bookmark : Icons.bookmark_border,
              color: saved ? AppColors.coral : AppColors.ink,
            ),
            onPressed: () => _toggleSaved(recipe),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
        children: [
          StripedImage(
            stripeColor: dish.stripeColor,
            caption: localize(dish.capCaption, lang),
            height: 220,
          ),
          const SizedBox(height: 20),
          _header(dish, recipe, saved, lang, s, profile),
          const SizedBox(height: 20),
          ..._switchers(s, profile, overrideOn),
          if (outside)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                s.t('dish.outsideProfile'),
                style: AppText.handwritten(size: 17, color: AppColors.teal),
              ),
            ),
          const SizedBox(height: 8),
          _calorieOverrideRow(profileStore, overrideOn, s),
          const SizedBox(height: 24),
          _ingredientsSection(recipe, lang, s, reduceMotion),
          const SizedBox(height: 28),
          _methodSection(recipe, lang, s, reduceMotion),
          const SizedBox(height: 28),
          _macrosSection(recipe, s),
        ],
      ),
    );
  }

  Widget _header(
    Dish dish,
    Recipe recipe,
    bool saved,
    String lang,
    AppStrings s,
    UserProfile profile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                localize(dish.name, lang),
                style: AppText.masthead(size: 34),
              ),
            ),
            IconButton(
              tooltip: s.t(saved ? 'dish.saved' : 'dish.save'),
              icon: Icon(
                saved ? Icons.bookmark : Icons.bookmark_border,
                color: saved ? AppColors.coral : AppColors.ink,
              ),
              onPressed: () => _toggleSaved(recipe),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(s.t('dish.handNote'), style: AppText.handwritten(size: 17)),
        const SizedBox(height: 10),
        Text(
          localize(dish.heroText, lang),
          style: AppText.body(size: 15, color: AppColors.inkSoft),
        ),
        if (profile.showVariantTags && recipe.dimensions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in recipe.dimensions.entries)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.paperDark,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: AppColors.inkSoft.withValues(alpha: 0.4),
                      width: 0.6,
                    ),
                  ),
                  child: Text(
                    _valueLabel(s, e.key, e.value),
                    style: AppText.monoLabel(size: 9),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// One collapsible switcher row per dimension present in the lattice.
  List<Widget> _switchers(AppStrings s, UserProfile profile, bool overrideOn) {
    final matching = context.read<MatchingEngine>();
    final rows = <Widget>[];
    for (final dimKey in _dimKeys) {
      final expanded = _expandedDims.contains(dimKey);
      final currentValue = _selection[dimKey] ?? '';
      final values = _dimValues(dimKey);
      var anyDisabled = false;
      final chips = <Widget>[
        for (final value in values)
          () {
            final target = _targetFor(dimKey, value);
            final enabled = target != null;
            if (!enabled) anyDisabled = true;
            final selected = value == currentValue && enabled;
            final muted =
                target != null &&
                !matching.visible(
                  target,
                  profile,
                  ignoreCalorieTarget: overrideOn,
                );
            return _VariantChip(
              label: _valueLabel(s, dimKey, value),
              selected: selected,
              enabled: enabled,
              muted: muted,
              onTap: enabled ? () => _select(dimKey, value) : null,
            );
          }(),
      ];
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => setState(() {
                  expanded
                      ? _expandedDims.remove(dimKey)
                      : _expandedDims.add(dimKey);
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        '— ${_dimLabel(s, dimKey)}',
                        style: AppText.monoLabel(),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(child: DashedRule()),
                      const SizedBox(width: 10),
                      Text(
                        _valueLabel(s, dimKey, currentValue),
                        style: AppText.monoLabel(color: AppColors.ink),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 16,
                        color: AppColors.inkSoft,
                      ),
                    ],
                  ),
                ),
              ),
              if (expanded) ...[
                Wrap(spacing: 8, runSpacing: 8, children: chips),
                if (anyDisabled)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      s.t('dish.notWritten'),
                      style: AppText.handwritten(size: 15),
                    ),
                  ),
              ],
            ],
          ),
        ),
      );
    }
    return rows;
  }

  Widget _calorieOverrideRow(
    ProfileStore profileStore,
    bool overrideOn,
    AppStrings s,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            s.t('dish.calorieOverride'),
            style: AppText.monoLabel(size: 10),
          ),
        ),
        Switch(
          value: overrideOn,
          activeThumbColor: AppColors.teal,
          activeTrackColor: AppColors.tealSoft,
          onChanged: (v) => profileStore.setCalorieOverride(widget.dishId, v),
        ),
      ],
    );
  }

  Widget _ingredientsSection(
    Recipe recipe,
    String lang,
    AppStrings s,
    bool reduceMotion,
  ) {
    final guide = context.read<CorpusRepository>().ingredientGuide;
    final scale = _servings / recipe.servings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionRule(label: s.t('dish.ingredients')),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(s.t('common.servings'), style: AppText.monoLabel(size: 10)),
            const Spacer(),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              color: AppColors.inkSoft,
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: _servings > 1
                  ? () => setState(() => _servings--)
                  : null,
            ),
            Text(
              '$_servings',
              style: AppText.monoLabel(size: 14, color: AppColors.ink),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              color: AppColors.inkSoft,
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _servings < 12
                  ? () => setState(() => _servings++)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final ing in recipe.ingredients)
          _maybeFlash(
            flash: _flashIds.contains(ing.id),
            token: '${recipe.id}:${ing.id}:$_flashToken',
            reduceMotion: reduceMotion,
            child: _ingredientRow(
              ing,
              lang,
              s,
              scale,
              guide.containsKey(ing.id),
            ),
          ),
        const SizedBox(height: 14),
        Center(
          child: TextButton.icon(
            onPressed: () => _addToShopping(recipe, s),
            icon: const Icon(
              Icons.shopping_basket_outlined,
              size: 16,
              color: AppColors.ink,
            ),
            label: Text(
              s.t('dish.addShopping'),
              style: AppText.monoLabel(size: 11, color: AppColors.ink),
            ),
          ),
        ),
      ],
    );
  }

  Widget _ingredientRow(
    Ingredient ingredient,
    String lang,
    AppStrings s,
    double scale,
    bool hasGuide,
  ) {
    final note = localize(ingredient.note, lang);
    final amount =
        '${_fmtAmount(ingredient.amount * scale)} ${_unitLabel(ingredient.unit, s)}'
            .trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                amount,
                style: AppText.monoLabel(size: 12, color: AppColors.ink),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localize(ingredient.name, lang),
                  style: AppText.headline(size: 16),
                ),
                if (note.isNotEmpty)
                  Text(note, style: AppText.handwritten(size: 15)),
                if (hasGuide)
                  InkWell(
                    onTap: () => _openGuide(ingredient),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        s.t('dish.learnMore'),
                        style: AppText.monoLabel(
                          size: 10,
                          color: AppColors.teal,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodSection(
    Recipe recipe,
    String lang,
    AppStrings s,
    bool reduceMotion,
  ) {
    final steps = Column(
      key: ValueKey('method:${recipe.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < recipe.steps.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _stepRow(i + 1, recipe.steps[i], lang, s),
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionRule(label: s.t('dish.method')),
        const SizedBox(height: 12),
        reduceMotion
            ? steps
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: steps,
              ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.ink, width: 1.2),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.cook,
              arguments: recipe.id,
            ),
            child: Text(
              s.t('dish.startCooking'),
              style: AppText.monoLabel(size: 12, color: AppColors.ink),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stepRow(int number, RecipeStep step, String lang, AppStrings s) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 30,
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              '$number.',
              style: AppText.monoLabel(size: 12, color: AppColors.coral),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(localize(step.text, lang), style: AppText.body(size: 15)),
              if (step.timerSeconds != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.inkSoft, width: 0.7),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 11,
                          color: AppColors.inkSoft,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(step.timerSeconds! / 60).ceil()} ${s.t('common.minutes')}',
                          style: AppText.monoLabel(size: 10),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _macrosSection(Recipe recipe, AppStrings s) {
    final rows = [
      (s.t('common.kcal'), '${recipe.caloriesPerServing}'),
      (s.t('dish.protein'), '${_fmtAmount(recipe.macros.proteinG)} g'),
      (s.t('dish.carbs'), '${_fmtAmount(recipe.macros.carbsG)} g'),
      (s.t('dish.fat'), '${_fmtAmount(recipe.macros.fatG)} g'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionRule(label: s.t('dish.macros')),
        const SizedBox(height: 4),
        Text(s.t('dish.perServing'), style: AppText.handwritten(size: 15)),
        const SizedBox(height: 8),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(row.$1, style: AppText.monoLabel(size: 11)),
                const SizedBox(width: 10),
                const Expanded(child: DashedRule()),
                const SizedBox(width: 10),
                Text(
                  row.$2,
                  style: AppText.monoLabel(size: 11, color: AppColors.ink),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Changed/added rows fade in over a coral-soft flash that melts away.
  Widget _maybeFlash({
    required bool flash,
    required String token,
    required bool reduceMotion,
    required Widget child,
  }) {
    if (!flash || reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey('flash:$token'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOut,
      builder: (context, t, child) {
        final bg = AppColors.coralSoft.withValues(alpha: (1 - t) * 0.9);
        return Opacity(
          opacity: t < 0.25 ? t / 0.25 : 1,
          child: Container(color: bg, child: child),
        );
      },
      child: child,
    );
  }
}

/// A lattice-value chip. Selected = filled with ●. Sparse (non-existent)
/// combinations render greyed. Values whose target variant falls outside the
/// profile render muted (lower opacity, dashed border) but stay tappable.
class _VariantChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final bool muted;
  final VoidCallback? onTap;

  const _VariantChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.muted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = !enabled
        ? AppColors.disabled
        : selected
        ? AppColors.ink
        : AppColors.inkSoft;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Text(
        selected ? '● $label' : label,
        style: AppText.monoLabel(size: 11, color: textColor),
      ),
    );
    final decorated = muted
        ? CustomPaint(
            painter: _DashedBorderPainter(
              color: AppColors.inkSoft.withValues(alpha: 0.7),
            ),
            child: content,
          )
        : Container(
            decoration: BoxDecoration(
              color: selected ? AppColors.tealSoft : AppColors.paperDark,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: !enabled
                    ? AppColors.disabled.withValues(alpha: 0.6)
                    : selected
                    ? AppColors.ink
                    : AppColors.inkSoft.withValues(alpha: 0.6),
                width: selected ? 1.0 : 0.6,
              ),
            ),
            child: content,
          );
    return Opacity(
      opacity: muted ? 0.55 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: decorated,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  const _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(4)),
      );
    const dash = 4.0, gap = 3.0;
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        canvas.drawPath(
          metric.extractPath(dist, math.min(dist + dash, metric.length)),
          paint,
        );
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Calm bottom sheet with the ingredient guide entry.
class _GuideSheet extends StatelessWidget {
  final IngredientGuideEntry entry;
  final String ingredientName;
  final String lang;
  final AppStrings s;

  const _GuideSheet({
    required this.entry,
    required this.ingredientName,
    required this.lang,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final sections = <(String, String)>[
      (s.t('dish.guide.about'), localize(entry.description, lang)),
      (s.t('dish.guide.usage'), localize(entry.usage, lang)),
      (s.t('dish.guide.storage'), localize(entry.storage, lang)),
      (s.t('dish.guide.whereToFind'), localize(entry.whereToFind, lang)),
    ];
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: 24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.inkSoft.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(ingredientName, style: AppText.headline(size: 24)),
          const SizedBox(height: 12),
          for (final (label, text) in sections)
            if (text.isNotEmpty) ...[
              Text(label, style: AppText.monoLabel(size: 10)),
              const SizedBox(height: 4),
              Text(
                text,
                style: AppText.body(size: 14, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }
}
