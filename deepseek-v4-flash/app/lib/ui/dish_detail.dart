import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../data/corpus.dart';
import '../data/services.dart';
import '../logic/matching.dart';
import '../logic/shopping.dart';
import '../models/models.dart';
import 'cook_mode.dart';
import 'widgets.dart';

/// A dish page with a variant switcher: diet × effort × calorie bucket.
/// The geometry settles the other two dimensions when one changes; the
/// best-ranked recipe of the settled selection is shown.
class DishDetailPage extends StatefulWidget {
  final Dish dish;
  final Recipe? initialRecipe;

  const DishDetailPage({super.key, required this.dish, this.initialRecipe});

  @override
  State<DishDetailPage> createState() => _DishDetailPageState();
}

class _DishDetailPageState extends State<DishDetailPage> {
  String? _diet;
  String? _effort;
  String? _bucket;
  int _servings = 2;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final svc = Services.of(context);
    await svc.corpus.ensureDishLoaded(widget.dish);
    if (!mounted) return;
    setState(() => _loaded = true);
  }

  UserProfile get _profile => Services.of(context).state.profile;

  String t(String k) => L10n.strings(_profile.lang, k);

  String _dishName() =>
      widget.dish.canonicalName[_profile.lang]?.toString() ??
      widget.dish.canonicalName['en']?.toString() ??
      widget.dish.id;

  @override
  Widget build(BuildContext context) {
    final svc = Services.of(context);

    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_dishName(),
              style: AppText.serif(context, size: 18, weight: FontWeight.w700)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final variants = svc.corpus.recipesForDish(widget.dish.id);
    final geometry = VariantGeometry(dish: widget.dish, variants: variants);
    final seed = widget.initialRecipe;

    final diet = _diet ??
        (seed != null && geometry.dietOptions.contains(seed.diet)
            ? seed.diet
            : geometry.defaultDiet(_profile));
    final effort = _effort ??
        (seed != null &&
                seed.effort != null &&
                geometry.effortOptions.contains(seed.effort!)
            ? seed.effort
            : geometry.defaultEffort(_profile));
    final bucket = _bucket ??
        (seed != null &&
                seed.calorieBucket != null &&
                geometry.bucketOptions.contains(seed.calorieBucket!)
            ? seed.calorieBucket
            : geometry.defaultBucket(_profile));

    final settled = geometry.settle(
      diet: diet,
      effort: effort,
      bucket: bucket,
      profile: _profile,
    );

    final choices =
        geometry.select(settled.diet, settled.effort, settled.bucket);
    final Recipe? recipe = choices.isEmpty
        ? null
        : choices.reduce((a, b) =>
            svc.matcher.rankScore(b, _profile) >
                    svc.matcher.rankScore(a, _profile)
                ? b
                : a);
    final visible = recipe != null && svc.matcher.visible(recipe, _profile);

    return Scaffold(
      appBar: AppBar(
        title: Text(_dishName(),
            style: AppText.serif(context, size: 18, weight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: t(L10n.tSave),
            icon: Icon(svc.state.isSaved(recipe?.id ?? '')
                ? Icons.favorite
                : Icons.favorite_border),
            onPressed: recipe == null
                ? null
                : () => setState(() => svc.state.toggleSaved(recipe.id)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 30),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ZinePage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FractionallySizedBox(
                    widthFactor: 0.9,
                    child: PolaroidCard(
                      dish: widget.dish,
                      caption: _dishName(),
                      sub: recipe == null ? null : _metaLine(recipe),
                      selected: visible,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _variantSelector(geometry, settled),
                  if (recipe == null)
                    _missingCard()
                  else ...[
                    const SizedBox(height: 14),
                    _recipeBlock(recipe, visible),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _metaLine(Recipe r) =>
      '${r.timeMinutes} ${t(L10n.tMinutes).toLowerCase()} · ${r.calories} kcal';

  Widget _variantSelector(
      VariantGeometry geometry,
      ({String? diet, String? effort, String? bucket}) settled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dimension(
          label: t(L10n.tDiet),
          options: geometry.dietOptions,
          selected: settled.diet,
          onSelect: (v) => setState(() {
            _diet = v;
          }),
        ),
        _dimension(
          label: t(L10n.tEffort),
          options: geometry.effortOptions,
          selected: settled.effort,
          onSelect: (v) => setState(() {
            _effort = v;
          }),
        ),
        _dimension(
          label: t(L10n.tCalorieLevel),
          options: geometry.bucketOptions,
          selected: settled.bucket,
          onSelect: (v) => setState(() {
            _bucket = v;
          }),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _varRequestDialog,
            icon: const Icon(Icons.edit_note, size: 15),
            label: Text(t(L10n.tStringIt)),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.inkSoft,
                textStyle: AppText.mono(context, size: 11)),
          ),
        ),
      ],
    );
  }

  Widget _dimension({
    required String label,
    required List<String> options,
    required String? selected,
    required void Function(String) onSelect,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(label.toUpperCase(),
                  style: AppText.mono(context, size: 9, color: AppColors.inkFaint)
                      .copyWith(letterSpacing: 1.2)),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final o in options)
                  _choiceChip(o, selected == o, () => onSelect(o)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _choiceChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : Colors.transparent,
          border: Border.all(
              color: selected ? AppColors.accent : AppColors.lineDotted,
              width: selected ? 1.4 : 1.2),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          _pretty(label),
          style: AppText.mono(context,
              size: 10, color: selected ? Colors.white : AppColors.ink),
        ),
      ),
    );
  }

  /// Diet labels keep their '≤400' / '>800' bucket shape; others become
  /// "Gluten Free" style words.
  String _pretty(String label) {
    if (label.contains('≤') || label.contains('>')) return label;
    return label.split('-').map(_capWord).join(' ');
  }

  String _capWord(String w) =>
      w.isEmpty ? w : w[0].toUpperCase() + w.substring(1);

  Future<void> _varRequestDialog() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t(L10n.tStringIt),
            style:
                AppText.serif(context, size: 18, weight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 140,
          maxLines: 3,
          style: AppText.mono(context, size: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t(L10n.tCancel)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(t(L10n.tSave)),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    if (!mounted) return;
    Services.of(context).state.addContentRequest(text.trim());
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t(L10n.tRequestSaved))));
  }

  Widget _missingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(
              t(L10n.tNoVariantYet).replaceFirst('{x}', _dishName()),
              style: AppText.mono(context, size: 11, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _varRequestDialog,
              icon: const Icon(Icons.edit_note, size: 15),
              label: Text(t(L10n.tStringIt)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recipeBlock(Recipe recipe, bool visible) {
    final svc = Services.of(context);
    final corpus = svc.corpus;
    final lang = _profile.lang;

    int servings = _servings <= 0 ? recipe.servings : _servings;
    _servings = servings;

    final notes =
        recipe.kitchenNotes == null ? '' : T(recipe.kitchenNotes!, lang);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!visible) ...[
          _outOfRangeNote(),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            PressChip(label: '${recipe.timeMinutes} ${t(L10n.tMinutes)}'),
            PressChip(label: '${recipe.calories} kcal'),
            PressChip(label: '${recipe.protein}g'),
            PressChip(label: '${recipe.carbs}g'),
            PressChip(label: '${recipe.fat}g'),
          ],
        ),
        _servingsRow(servings),
        SectionHeader(title: t(L10n.tIngredients)),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Column(
            children: [
              for (var i = 0; i < recipe.ingredients.length; i++)
                _ingredientRow(corpus, recipe, servings, i, lang),
            ],
          ),
        ),
        SectionHeader(title: t(L10n.tMethod)),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Column(
            children: [
              for (var i = 0; i < recipe.steps.length; i++)
                _stepRow(recipe.steps[i], i),
            ],
          ),
        ),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.paperDark,
              border: Border.all(color: AppColors.lineDotted),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(notes,
                style: AppText.mono(context,
                    size: 11, color: AppColors.inkSoft, height: 1.5)),
          ),
        ],
        if (recipe.tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in recipe.tags)
                PressChip(label: tag, color: AppColors.inkSoft),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _actionRow(recipe, servings),
      ],
    );
  }

  Widget _outOfRangeNote() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.highlight,
        border: Border.all(color: AppColors.lineDotted),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(t(L10n.tOutOfRange),
          style: AppText.mono(context, size: 10, color: AppColors.inkSoft)),
    );
  }

  Widget _servingsRow(int servings) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(t(L10n.tServingsScale).toUpperCase(),
                  style: AppText.mono(context,
                          size: 9, color: AppColors.inkFaint)
                      .copyWith(letterSpacing: 1.2)),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 1; i <= 6; i++)
                  _choiceChip('$i', servings == i, () {
                    setState(() => _servings = i);
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ingredientRow(Corpus corpus, Recipe recipe, int servings, int i,
      String lang) {
    final ing = recipe.ingredients[i];
    return ZebraRow(
      index: i,
      onTap: corpus.guideFor(ing.id) == null
          ? null
          : () => _showGuide(ing.id),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(corpus.labelOf(ing.id, lang),
                style: AppText.serif(context, size: 15)),
          ),
          const SizedBox(width: 8),
          Text(
            _fmtAmount(recipe.amountFor(servings, ing)),
            style: AppText.mono(context, size: 11, color: AppColors.ink),
          ),
          const SizedBox(width: 4),
          Text(
            UnitConverter.isCountUnit(ing.unit)
                ? UnitConverter.countLabel(ing.unit, lang)
                : ing.unit,
            style: AppText.mono(context, size: 11, color: AppColors.inkFaint),
          ),
        ],
      ),
    );
  }

  String _fmtAmount(double v) {
    final r = v.roundToDouble();
    return v == r ? r.round().toString() : v.toString();
  }

  Widget _stepRow(StepData step, int i) {
    return ZebraRow(
      index: i,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Text('${i + 1}.',
                style: AppText.mono(context, size: 12, color: AppColors.accent)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(T(step.text, _profile.lang),
                    style: AppText.serif(context, size: 15, height: 1.45)),
                if (step.timerSeconds > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${t(L10n.tTimer)}: '
                    '${step.timerSeconds < 60 ? '${step.timerSeconds}s' : '${step.timerSeconds ~/ 60}min'}',
                    style:
                        AppText.mono(context, size: 10, color: AppColors.accent),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showGuide(String ingredientId) {
    final corpus = Services.of(context).corpus;
    final guide = corpus.guideFor(ingredientId);
    if (guide == null) return;
    final lang = _profile.lang;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paperBright,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(corpus.labelOf(ingredientId, lang),
                  style: AppText.serif(context,
                      size: 20, weight: FontWeight.w700)),
              const SizedBox(height: 10),
              _guideSection(t(L10n.tGuideWhat), guide.description, lang),
              _guideSection(t(L10n.tGuideTips), guide.tips, lang),
              _guideSection(t(L10n.tGuideStorage), guide.storage, lang),
              _guideSection(t(L10n.tGuideFind), guide.whereToFind, lang),
            ],
          ),
        ),
      ),
    );
  }

  Widget _guideSection(String title, Map<String, dynamic>? map, String lang) {
    if (map == null) return const SizedBox.shrink();
    final body = T(map, lang);
    if (body.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: AppText.mono(context, size: 9, color: AppColors.accent)
                  .copyWith(letterSpacing: 1.2)),
          const SizedBox(height: 3),
          Text(body, style: AppText.serif(context, size: 14, height: 1.4)),
        ],
      ),
    );
  }

  Widget _actionRow(Recipe recipe, int servings) {
    final svc = Services.of(context);
    final inList = svc.state.shoppingLineFor(recipe.id) != null;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: () => setState(() {
            if (svc.state.shoppingLineFor(recipe.id) == null) {
              svc.state.addShoppingLine(recipe.id, servings: servings);
            } else {
              svc.state.removeShoppingLine(recipe.id);
            }
          }),
          icon: Icon(
              inList ? Icons.remove_shopping_cart : Icons.add_shopping_cart,
              size: 16),
          label: Text(
              inList ? t(L10n.tRemoveShopping) : t(L10n.tAddToShopping)),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    CookModePage(recipe: recipe, servings: servings),
              ),
            );
          },
          icon: const Icon(Icons.local_fire_department, size: 16),
          label: Text(t(L10n.tStartCooking)),
        ),
      ],
    );
  }
}