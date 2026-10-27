import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../models/content.dart';
import '../models/localized_text.dart';
import '../models/recipe.dart';
import '../models/user_data.dart';
import '../services/matching.dart';
import '../services/shopping_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/paper_widgets.dart';
import 'cook_mode_screen.dart';
import 'faq_screen.dart';

class DishDetailScreen extends StatefulWidget {
  const DishDetailScreen({super.key, required this.dish, this.initialRecipeId});
  final Dish dish;
  final String? initialRecipeId;

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  List<Recipe> variants = [];
  Recipe? current;
  bool loading = true;
  bool ignoreCalories = false;
  String? expandedAxis;
  int tab = 0;
  int servings = 2;
  Set<String> previousIngredients = const {};
  String? unavailableMessage;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final app = context.read<AppState>();
    final loaded = await app.repository.recipesForDish(widget.dish);
    if (!mounted) return;
    final byId = <String, Recipe>{
      for (final recipe in loaded) recipe.id: recipe,
    };
    final selected =
        byId[widget.initialRecipeId] ??
        app.repository.matcher.bestVariant(
          widget.dish,
          byId,
          app.profile,
          now: app.clock(),
          lastCooked: app.lastCooked,
        ) ??
        (loaded.isEmpty ? null : loaded.first);
    setState(() {
      variants = loaded;
      current = selected;
      servings = selected?.servings ?? 2;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final locale = Localizations.localeOf(context);
    final recipe = current;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.dish.canonicalName.of(locale)),
        actions: [
          if (recipe != null)
            IconButton(
              onPressed: () {
                app.toggleSaved(recipe.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.l10n.t(
                        app.isSaved(recipe.id)
                            ? 'recipe_saved'
                            : 'recipe_unsaved',
                      ),
                    ),
                  ),
                );
              },
              icon: Icon(
                app.isSaved(recipe.id) ? Icons.bookmark : Icons.bookmark_border,
              ),
              tooltip: context.l10n.t(
                app.isSaved(recipe.id) ? 'saved_variant' : 'save_variant',
              ),
            ),
        ],
      ),
      body: Paper(
        child: loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 1.5))
            : recipe == null
            ? EmptyState(
                title: context.l10n.t('home_empty_title'),
                body: context.l10n.t('home_empty_body'),
              )
            : SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Polaroid(
                        turns: 0.002,
                        child: DishArtwork(
                          caption: widget.dish.capCaption.of(locale),
                          stripeColor: widget.dish.stripeColor,
                          height: 214,
                        ),
                      ),
                      const SizedBox(height: 23),
                      Text(
                        context.l10n.t('dish_variants'),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: AppColors.coral),
                      ),
                      const SizedBox(height: 6),
                      AnimatedSwitcher(
                        duration: motionDuration(
                          context,
                          const Duration(milliseconds: 260),
                        ),
                        child: Text(
                          recipe.title.of(locale),
                          key: ValueKey(recipe.id),
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        recipe.summary.of(locale),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 13),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          TagPill(
                            '${recipe.timeMinutes} min',
                            icon: Icons.schedule_outlined,
                          ),
                          TagPill(
                            '${recipe.caloriesPerServing} kcal',
                            icon: Icons.local_fire_department_outlined,
                          ),
                          if (app.profile.showVariantTags)
                            TagPill(recipe.diet, active: true),
                        ],
                      ),
                      const SizedBox(height: 18),
                      ...axes().map((axis) => dimensionRow(axis, recipe)),
                      if (unavailableMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            unavailableMessage!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.coral),
                          ),
                        ),
                      SwitchListTile(
                        value: ignoreCalories,
                        onChanged: toggleCalorieOverride,
                        contentPadding: EdgeInsets.zero,
                        title: Text(context.l10n.t('show_outside_calories')),
                        subtitle: ignoreCalories
                            ? Text(context.l10n.t('calorie_override_note'))
                            : null,
                        activeThumbColor: AppColors.teal,
                      ),
                      if (!app.repository.matcher.visible(
                        recipe,
                        app.profile,
                        ignoreCalories: ignoreCalories,
                      ))
                        Container(
                          padding: const EdgeInsets.all(11),
                          color: AppColors.coral.withValues(alpha: 0.09),
                          child: Text(
                            context.l10n.t('variant_profile_unavailable'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                app.toggleSaved(recipe.id);
                              },
                              icon: Icon(
                                app.isSaved(recipe.id)
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                              ),
                              label: Text(
                                context.l10n.t(
                                  app.isSaved(recipe.id)
                                      ? 'saved_variant'
                                      : 'save_variant',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => startCooking(recipe),
                              icon: const Icon(
                                Icons.restaurant_outlined,
                                size: 18,
                              ),
                              label: Text(
                                context.l10n.t(
                                  app.snapshot.cookProgress.containsKey(
                                        recipe.id,
                                      )
                                      ? 'resume_cooking'
                                      : 'start_cooking',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 27),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              context.l10n.t('ingredients'),
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          ServingScaler(
                            value: servings,
                            onChanged: (value) =>
                                setState(() => servings = value),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      recipeTabs(),
                      const SizedBox(height: 18),
                      AnimatedSwitcher(
                        duration: motionDuration(
                          context,
                          const Duration(milliseconds: 280),
                        ),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: KeyedSubtree(
                          key: ValueKey('${recipe.id}:$tab'),
                          child: tabContent(recipe),
                        ),
                      ),
                      const SizedBox(height: 25),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const FaqScreen(
                                initialFaqId: 'matching-how-it-works',
                              ),
                            ),
                          ),
                          child: Text(context.l10n.t('why_recipes')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  List<String> axes() {
    final ontologyAxes = context
        .read<AppState>()
        .repository
        .ontology
        .dimensions
        .keys
        .toList();
    final actual = variants.expand((recipe) => recipe.dimensions.keys).toSet();
    return [
      ...ontologyAxes.where(actual.contains),
      ...actual.where((axis) => !ontologyAxes.contains(axis)),
    ];
  }

  DimensionDefinition? dimension(String axis) =>
      context.read<AppState>().repository.ontology.dimensions[axis];

  String dimensionName(String axis) =>
      dimension(axis)?.name[context.lang] ?? axis.replaceAll('-', ' ');

  String valueName(String axis, String value) {
    if (axis == 'calorie' && (value == 'light' || value == 'regular')) {
      return context.l10n.t('tag_$value');
    }
    return dimension(axis)?.valueName(value)[context.lang] ??
        value.replaceAll('-', ' ');
  }

  List<String> valuesFor(String axis) {
    final defined =
        dimension(axis)?.values.map((value) => value.id).toList() ?? <String>[];
    final actual = variants
        .map((recipe) => recipe.dimensions[axis])
        .whereType<String>();
    return {...defined, ...actual}.toList();
  }

  Widget dimensionRow(String axis, Recipe recipe) {
    final app = context.read<AppState>();
    final expanded = expandedAxis == axis;
    final options = VariantResolver(app.repository.matcher).options(
      axis: axis,
      current: recipe,
      variants: variants,
      profile: app.profile,
      values: valuesFor(axis),
      ignoreCalories: ignoreCalories,
    );
    final selectedValue = axis == 'calorie'
        ? '~${recipe.caloriesPerServing} kcal'
        : valueName(axis, recipe.dimensions[axis] ?? '');
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() {
            expandedAxis = expanded ? null : axis;
            unavailableMessage = null;
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                SizedBox(
                  width: 86,
                  child: Text(
                    dimensionName(axis).toLowerCase(),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                const Expanded(child: DashedRule(height: 2)),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    selectedValue,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: AppColors.teal),
                  ),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: motionDuration(context, const Duration(milliseconds: 220)),
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: options.map((option) {
                        final selected =
                            recipe.dimensions[axis] == option.value;
                        final label = axis == 'calorie' && option.recipe != null
                            ? '${valueName(axis, option.value)} · ${option.recipe!.caloriesPerServing}'
                            : valueName(axis, option.value);
                        return Semantics(
                          button: true,
                          enabled: option.enabled,
                          label: label,
                          child: GestureDetector(
                            onTap: option.enabled
                                ? null
                                : () => setState(
                                    () => unavailableMessage = unavailableNote(
                                      axis,
                                      option,
                                    ),
                                  ),
                            child: ChoiceChip(
                              label: Text(selected ? '$label ●' : label),
                              selected: selected,
                              onSelected:
                                  option.enabled && option.recipe != null
                                  ? (_) => switchRecipe(option.recipe!)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  String unavailableNote(String axis, VariantOption option) {
    if (option.unavailableReason == VariantUnavailableReason.outsideProfile) {
      return context.l10n.t('variant_profile_unavailable');
    }
    final others = axes()
        .where((other) => other != axis)
        .map((other) => valueName(other, current!.dimensions[other] ?? ''))
        .join(' × ');
    return context.l10n.t('variant_unavailable', {
      'a': valueName(axis, option.value),
      'b': others,
    });
  }

  void switchRecipe(Recipe recipe) {
    setState(() {
      previousIngredients = current?.ingredientIds ?? const {};
      current = recipe;
      servings = recipe.servings;
      expandedAxis = null;
      unavailableMessage = null;
    });
  }

  void toggleCalorieOverride(bool value) {
    final app = context.read<AppState>();
    setState(() {
      ignoreCalories = value;
      unavailableMessage = null;
      if (!value && current != null) {
        final byId = {for (final recipe in variants) recipe.id: recipe};
        final best = app.repository.matcher.bestVariant(
          widget.dish,
          byId,
          app.profile,
          now: app.clock(),
          lastCooked: app.lastCooked,
        );
        if (best != null) {
          previousIngredients = current!.ingredientIds;
          current = best;
          servings = best.servings;
        }
      }
    });
  }

  Widget recipeTabs() {
    final labels = ['ingredients', 'method', 'macros'];
    return Row(
      children: List.generate(labels.length, (index) {
        final selected = tab == index;
        return Expanded(
          child: InkWell(
            onTap: () => setState(() => tab = index),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: selected
                        ? AppColors.coral
                        : AppColors.muted.withValues(alpha: 0.25),
                    width: selected ? 2 : 0.7,
                  ),
                ),
              ),
              child: Text(
                context.l10n.t(labels[index]).toUpperCase(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? AppColors.ink : AppColors.muted,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget tabContent(Recipe recipe) {
    if (tab == 1) return methodTab(recipe);
    if (tab == 2) return macrosTab(recipe);
    return Column(
      children: recipe.ingredients.map((ingredient) {
        final changed = !previousIngredients.contains(ingredient.id);
        final scaled = ingredient.amount == null
            ? null
            : ingredient.amount! * servings / recipe.servings;
        final amount = scaled == null
            ? ''
            : ShoppingService.formatNumber(scaled);
        return TweenAnimationBuilder<double>(
          key: ValueKey('${recipe.id}:${ingredient.id}'),
          tween: Tween(begin: 0, end: 1),
          duration: motionDuration(context, const Duration(milliseconds: 850)),
          builder: (context, value, child) => Container(
            color: changed && !reduceMotion(context)
                ? Color.lerp(
                    AppColors.coral.withValues(alpha: 0.24),
                    Colors.transparent,
                    value,
                  )
                : Colors.transparent,
            child: child,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 86,
                  child: Text(
                    ingredient.unit == 'to-taste'
                        ? context.l10n.unit(ingredient.unit)
                        : '$amount ${context.l10n.unit(ingredient.unit)}',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: AppColors.teal),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ingredient.name[context.lang],
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (ingredient.preparation[context.lang].isNotEmpty)
                        Text(
                          ingredient.preparation[context.lang],
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (context
                          .read<AppState>()
                          .repository
                          .ingredientGuide
                          .containsKey(ingredient.id))
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 28),
                            ),
                            onPressed: () => showGuide(ingredient.id),
                            child: Text(context.l10n.t('learn_more')),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget methodTab(Recipe recipe) => Column(
    children: List.generate(recipe.steps.length, (index) {
      final step = recipe.steps[index];
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.coral),
              ),
              child: Text(
                '${index + 1}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.text[context.lang],
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (step.timerSeconds != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: TagPill(
                        '${step.timerSeconds! ~/ 60}:${(step.timerSeconds! % 60).toString().padLeft(2, '0')}',
                        icon: Icons.timer_outlined,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }),
  );

  Widget macrosTab(Recipe recipe) => Column(
    children: [
      Text(
        context.l10n.t('per_serving'),
        style: Theme.of(context).textTheme.labelMedium,
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          macroCell('${recipe.caloriesPerServing}', 'kcal'),
          macroCell(
            ShoppingService.formatNumber(recipe.macros.protein),
            'protein',
          ),
          macroCell(ShoppingService.formatNumber(recipe.macros.carbs), 'carbs'),
          macroCell(ShoppingService.formatNumber(recipe.macros.fat), 'fat'),
        ],
      ),
      const SizedBox(height: 18),
      const DashedRule(),
      Text(
        'g / ${context.l10n.t('per_serving')}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );

  Widget macroCell(String value, String label) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(color: AppColors.teal),
        ),
        Text(
          label == 'kcal' ? label : context.l10n.t(label),
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    ),
  );

  void showGuide(String ingredientId) {
    final entry = context
        .read<AppState>()
        .repository
        .ingredientGuide[ingredientId];
    if (entry == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      showDragHandle: true,
      builder: (context) => Paper(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description[context.lang],
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 18),
                guideSection('usage', entry.usage),
                guideSection('storage', entry.storage),
                guideSection('where_to_find', entry.whereToFind),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget guideSection(String key, LocalizedText text) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.t(key).toUpperCase(),
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: AppColors.coral),
        ),
        const SizedBox(height: 6),
        Text(text[context.lang], style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );

  void startCooking(Recipe recipe) {
    final app = context.read<AppState>();
    final existing = app.snapshot.cookProgress[recipe.id];
    if (existing == null) {
      app.saveCookProgress(
        CookProgress(
          recipeId: recipe.id,
          stepIndex: 0,
          remainingSeconds: recipe.steps.first.timerSeconds ?? 0,
          servings: servings,
          isRunning: false,
          updatedAt: app.clock().toUtc(),
        ),
      );
    } else if (existing.servings != servings) {
      app.saveCookProgress(
        existing.copyWith(servings: servings, updatedAt: app.clock().toUtc()),
      );
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => CookModeScreen(recipe: recipe)));
  }
}
