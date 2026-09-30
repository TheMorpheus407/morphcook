import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/models.dart';
import '../core/pagination.dart';
import '../state/app_state.dart';
import 'theme.dart';

String t(
  BuildContext context,
  String key, [
  Map<String, Object> parameters = const {},
]) {
  final state = AppScope.of(context);
  var result = translate(
    state.repository.uiStrings[key] ?? {'en': key},
    state.profile.lang,
  );
  for (final entry in parameters.entries) {
    result = result.replaceAll('{${entry.key}}', '${entry.value}');
  }
  return result;
}

String textFor(BuildContext context, Localized text) =>
    translate(text, AppScope.of(context).profile.lang);
bool reducedMotion(BuildContext context) =>
    AppScope.of(context).profile.reduceMotion ??
    MediaQuery.disableAnimationsOf(context);
Duration motionDuration(BuildContext context, [int ms = 280]) =>
    Duration(milliseconds: reducedMotion(context) ? 0 : ms);

class MotionSize extends StatelessWidget {
  final Widget child;
  final AlignmentGeometry alignment;
  const MotionSize({
    super.key,
    required this.child,
    this.alignment = Alignment.topLeft,
  });
  @override
  Widget build(BuildContext context) => reducedMotion(context)
      ? child
      : AnimatedSize(
          duration: motionDuration(context),
          alignment: alignment,
          child: child,
        );
}

void toast(
  BuildContext context,
  String key, [
  Map<String, Object> parameters = const {},
]) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(t(context, key, parameters))));
}

class PaperScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  const PaperScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
  });
  @override
  Widget build(BuildContext context) => PaperSurface(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(
        top: appBar == null,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: body,
          ),
        ),
      ),
    ),
  );
}

class KitchenAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final List<Widget> actions;
  const KitchenAppBar({super.key, this.title, this.actions = const []});
  @override
  Size get preferredSize => const Size.fromHeight(64);
  @override
  Widget build(BuildContext context) => AppBar(
    title: Text(
      title ?? t(context, 'brand'),
      style: title == null
          ? serif(29, italic: true)
          : mono(13, color: KitchenColors.ink),
    ),
    centerTitle: false,
    titleSpacing: 22,
    actions: [...actions, const SizedBox(width: 10)],
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: DashedRule(),
    ),
  );
}

class PageHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? eyebrow;
  final Widget? trailing;
  const PageHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.eyebrow,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 25, 22, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(eyebrow!, style: mono(10, spacing: 1.5)),
          const SizedBox(height: 12),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(title, style: serif(34, italic: true))),
            ?trailing,
          ],
        ),
        const SizedBox(height: 10),
        Text(subtitle, style: mono(11)),
      ],
    ),
  );
}

class SectionHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const SectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const DashedRule(),
      const SizedBox(height: 22),
      Row(
        children: [
          Expanded(child: Text(title, style: serif(25, italic: true))),
          ?action,
        ],
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 7),
        Text(subtitle!, style: mono(11)),
      ],
      const SizedBox(height: 18),
    ],
  );
}

class EmptyPaper extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  final Widget? action;
  const EmptyPaper({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.menu_book_outlined,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: KitchenColors.wash,
          ),
          child: Icon(icon, size: 32, color: KitchenColors.teal),
        ),
        const SizedBox(height: 22),
        Text(
          title,
          style: serif(27, italic: true),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        Text(body, style: mono(12), textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 20), action!],
      ],
    ),
  );
}

class RecipeArt extends StatelessWidget {
  final Dish dish;
  final double? height;
  const RecipeArt({super.key, required this.dish, this.height});
  @override
  Widget build(BuildContext context) => Semantics(
    label: textFor(context, dish.name),
    image: true,
    child: ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: SvgPicture.asset(
          'assets/illustrations/${dish.id}.svg',
          fit: BoxFit.cover,
        ),
      ),
    ),
  );
}

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final bool selected;
  final bool selectionMode;
  final bool compact;
  const RecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
    this.selected = false,
    this.selectionMode = false,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dish = state.repository.dishes[recipe.dishId]!;
    final angle = reducedMotion(context)
        ? 0.0
        : (recipe.id.hashCode % 3 - 1) * .008;
    return Transform.rotate(
      angle: angle,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: KitchenColors.card,
          border: Border.all(
            color: selected ? KitchenColors.teal : KitchenColors.line,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: KitchenColors.ink.withValues(alpha: .055),
              offset: const Offset(2, 4),
              blurRadius: 6,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: compact ? 2.5 : 1.6,
                        child: RecipeArt(dish: dish),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: selectionMode
                            ? Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  selected
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: KitchenColors.teal,
                                ),
                              )
                            : IconButton(
                                tooltip: t(
                                  context,
                                  state.saved.containsKey(recipe.id)
                                      ? 'saved'
                                      : 'save',
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: KitchenColors.card
                                      .withValues(alpha: .88),
                                ),
                                iconSize: 19,
                                icon: Icon(
                                  state.saved.containsKey(recipe.id)
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  color: KitchenColors.teal,
                                ),
                                onPressed: () {
                                  state.toggleSaved(recipe.id);
                                },
                              ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
                    child: Text(
                      textFor(context, dish.name),
                      style: serif(compact ? 19 : 21, italic: true),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (state.profile.showVariantTags)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 1, 4, 4),
                      child: Text(
                        textFor(context, recipe.title),
                        style: mono(9),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 5, 4, 4),
                    child: Wrap(
                      spacing: 10,
                      children: [
                        Text(
                          t(context, 'minutes', {'count': recipe.timeMinutes}),
                          style: mono(9, color: KitchenColors.teal),
                        ),
                        Text(
                          t(context, 'kcal', {
                            'count': recipe.calories.round(),
                          }),
                          style: mono(9),
                        ),
                      ],
                    ),
                  ),
                  if (!state.isVisible(recipe))
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.info_outline,
                        size: 15,
                        color: KitchenColors.coral,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double recipeCardHeight(BuildContext context, double width) {
  final scale = MediaQuery.textScalerOf(context);
  final tags = AppScope.of(context).profile.showVariantTags;
  return (width - 16) / 1.6 +
      16 +
      12 +
      scale.scale(21) * 1.22 * 2 +
      (tags ? scale.scale(9) * 1.55 * 2 + 5 : 0) +
      9 +
      scale.scale(9) * 1.55 * (scale.scale(1) > 1.3 ? 2 : 1) +
      23;
}

class RecipeGrid extends StatelessWidget {
  final List<Recipe> recipes;
  final void Function(Recipe) onOpen;
  const RecipeGrid({super.key, required this.recipes, required this.onOpen});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 750 ? 3 : 2;
      final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
      final cardHeight = recipeCardHeight(context, width);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        addAutomaticKeepAlives: false,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 18,
          crossAxisSpacing: 16,
          mainAxisExtent: cardHeight,
        ),
        itemCount: recipes.length,
        itemBuilder: (context, index) => RecipeCard(
          recipe: recipes[index],
          onTap: () => onOpen(recipes[index]),
        ),
      );
    },
  );
}

class PagedRecipes extends StatelessWidget {
  final PaginationController<Recipe> controller;
  final void Function(Recipe) onOpen;
  final bool selectionMode;
  final Set<String> selectedIds;
  final Widget? empty;
  const PagedRecipes({
    super.key,
    required this.controller,
    required this.onOpen,
    this.selectionMode = false,
    this.selectedIds = const {},
    this.empty,
  });
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      if (controller.items.isEmpty &&
          !controller.loading &&
          controller.error == null &&
          !controller.hasMore) {
        return SingleChildScrollView(child: empty ?? const SizedBox.shrink());
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 750 ? 3 : 2;
          final width =
              (constraints.maxWidth - 44 - (columns - 1) * 16) / columns;
          final height = recipeCardHeight(context, width);
          final rows = (controller.items.length / columns).ceil();
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
            cacheExtent: 100,
            addAutomaticKeepAlives: false,
            itemBuilder: (context, row) {
              if (row > rows) return null;
              if (row == rows) {
                if (controller.loading) return const RecipeSkeleton();
                if (controller.error != null) {
                  return Center(
                    child: TextButton.icon(
                      onPressed: controller.loadMore,
                      icon: const Icon(Icons.refresh),
                      label: Text(t(context, 'retry')),
                    ),
                  );
                }
                if (controller.hasMore) {
                  return Center(
                    child: TextButton(
                      onPressed: controller.loadMore,
                      child: Text(t(context, 'loadMore')),
                    ),
                  );
                }
                return const SizedBox(height: 14);
              }
              final index = row * columns;
              if (controller.shouldLoadMore(index)) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => controller.loadMore(),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: SizedBox(
                  height: height,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var col = 0; col < columns; col++) ...[
                        if (col > 0) const SizedBox(width: 16),
                        Expanded(
                          child: index + col < controller.items.length
                              ? RecipeCard(
                                  recipe: controller.items[index + col],
                                  selectionMode: selectionMode,
                                  selected: selectedIds.contains(
                                    controller.items[index + col].id,
                                  ),
                                  onTap: () =>
                                      onOpen(controller.items[index + col]),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    },
  );
}

class RecipeSkeleton extends StatelessWidget {
  const RecipeSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: t(context, 'loading'),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          for (var i = 0; i < 2; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: KitchenColors.line.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class ServingsControl extends StatelessWidget {
  final int servings;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  const ServingsControl({
    super.key,
    required this.servings,
    required this.onMinus,
    required this.onPlus,
  });
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: t(context, 'lessServings'),
        onPressed: servings <= 1 ? null : onMinus,
        icon: const Icon(Icons.remove, size: 18),
      ),
      Text(
        t(context, 'servings', {'count': servings}),
        style: mono(11, color: KitchenColors.ink),
      ),
      IconButton(
        tooltip: t(context, 'moreServings'),
        onPressed: servings >= 20 ? null : onPlus,
        icon: const Icon(Icons.add, size: 18),
      ),
    ],
  );
}

class NoteCard extends StatelessWidget {
  final Widget child;
  final Color color;
  const NoteCard({
    super.key,
    required this.child,
    this.color = KitchenColors.wash,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(4),
    ),
    child: child,
  );
}

class ChipStrip extends StatelessWidget {
  final List<String> values;
  final String Function(String) label;
  final bool Function(String) selected;
  final void Function(String) onTap;
  const ChipStrip({
    super.key,
    required this.values,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 54,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      itemCount: values.length,
      separatorBuilder: (context, index) => const SizedBox(width: 8),
      itemBuilder: (context, index) => Center(
        child: FilterChip(
          label: Text(label(values[index])),
          selected: selected(values[index]),
          onSelected: (_) => onTap(values[index]),
          showCheckmark: false,
        ),
      ),
    ),
  );
}

Future<T?> kitchenSheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .9,
          maxWidth: 750,
        ),
        child: child,
      ),
    );
