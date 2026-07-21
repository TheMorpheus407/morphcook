import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/bundled_recipe_repository.dart';
import '../../domain/models/dish.dart';
import '../../domain/models/local_state.dart';
import '../../domain/models/recipe.dart';
import '../../l10n/app_strings.dart';
import '../../services/app_state.dart';
import '../../services/backup_file_facade.dart';
import '../../services/backup_repository.dart';
import '../../services/backup_service.dart';
import '../../services/shopping_service.dart';
import '../theme/morph_theme.dart';
import '../widgets/recipe_picker_sheet.dart';
import 'cook_mode_screen.dart';
import 'cookbook_screen.dart';
import 'dish_detail_screen.dart';
import 'faq_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'insights_screen.dart';
import 'meal_plan_screen.dart';
import 'profile_editor_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'shopping_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    required this.repository,
    required this.backupRepository,
    required this.backupService,
    required this.backupGateway,
    super.key,
  });

  final BundledRecipeRepository repository;
  final BackupRepository backupRepository;
  final BackupService backupService;
  final BackupFileGateway backupGateway;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _uuid = Uuid();
  var _index = 0;
  var _openingCookMode = false;

  Map<String, Dish> get _dishesById => {
    for (final dish in widget.repository.dishes) dish.id: dish,
  };

  Map<String, Recipe> get _recipesById => {
    for (final recipe in widget.repository.recipes) recipe.id: recipe,
  };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.profile!;
    final ranked = _uniqueDishes(
      widget.repository
          .rankedRecipes(profile, history: state.cookingHistory)
          .map((item) => item.recipe),
    );
    final visibleDishIds = ranked.map((recipe) => recipe.dishId).toSet();
    final outsideTarget = _uniqueDishes(
      widget.repository.ranker
          .rank(
            widget.repository.recipes.where(
              (recipe) => widget.repository.matcher.isVisible(
                recipe,
                profile,
                ignoreCalorieTarget: true,
              ),
            ),
            profile,
            history: state.cookingHistory,
            visibleOnly: false,
          )
          .map((item) => item.recipe),
    ).where((recipe) => !visibleDishIds.contains(recipe.dishId)).toList();
    final saved = state.savedRecipes.where((item) {
      final recipe = widget.repository.recipeById(item.recipeId);
      return recipe != null &&
          widget.repository.matcher.isVisible(recipe, profile);
    }).toList();

    final pages = <Widget>[
      HomeScreen(
        profile: profile,
        recipes: ranked,
        outsideTargetRecipes: outsideTarget,
        dishesById: _dishesById,
        isSaved: state.isSaved,
        shoppingCount: state.shoppingEntries
            .where((entry) => !entry.isChecked)
            .length,
        onOpenRecipe: _openRecipe,
        onToggleSaved: (recipe) => state.toggleSaved(recipe.id),
        onBrowseAll: () => setState(() => _index = 1),
        onAdjustProfile: _openProfile,
        onOpenShopping: _openShopping,
      ),
      RecipeSearchScreen(
        repository: widget.repository,
        profile: profile,
        dishesById: _dishesById,
        isSaved: state.isSaved,
        onToggleSaved: (recipe) => state.toggleSaved(recipe.id),
        onOpenRecipe: _openRecipe,
        onContentGap: state.logContentRequest,
      ),
      CookbookScreen(
        savedRecipes: saved,
        recipesById: _recipesById,
        dishesById: _dishesById,
        profile: profile,
        onOpenRecipe: _openRecipe,
        onRemoveSaved: (recipe) async {
          if (state.isSaved(recipe.id)) await state.toggleSaved(recipe.id);
        },
        onBrowse: () => setState(() => _index = 1),
      ),
      MealPlanScreen(
        mealPlan: state.mealPlan,
        recipesById: _recipesById,
        profile: profile,
        onPickRecipe: _pickRecipe,
        onAssign: (date, slot, recipe) => state.assignMealPlanSlot(
          date: date,
          slot: slot,
          recipeId: recipe.id,
        ),
        onMove: (source, date, slot) => state.moveMealPlanSlot(
          fromDate: source.date,
          fromSlot: source.slot,
          toDate: date,
          toSlot: slot,
        ),
        onRemove: state.removeMealPlanSlot,
        onExportWeek: _addRecipesToShopping,
      ),
      SettingsScreen(
        profile: profile,
        quickNextTapEnabled: state.settings.quickNextTapEnabled,
        onUpdateProfile: state.updateProfile,
        onQuickNextChanged: state.setQuickNextTapEnabled,
        onEditProfile: _openProfile,
        onOpenFaq: () => _openFaq(),
        onOpenMatchingFaq: () => _openFaq(initialCategory: 'matching'),
        onOpenInsights: _openInsights,
        onOpenHistory: _openHistory,
        onExportBackup: _exportBackup,
        onImportBackup: _importBackup,
      ),
    ];

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) setState(() => _index = 0);
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (index) => setState(() => _index = index),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: context.strings('nav.home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.search_rounded),
              label: context.strings('nav.search'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.bookmark_border_rounded),
              selectedIcon: const Icon(Icons.bookmark_rounded),
              label: context.strings('nav.cookbook'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.calendar_view_week_outlined),
              selectedIcon: const Icon(Icons.calendar_view_week_rounded),
              label: context.strings('nav.plan'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.more_horiz_rounded),
              label: context.strings('nav.more'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRecipe(Recipe requested) async {
    final state = context.read<AppState>();
    final profile = state.profile!;
    final variants = await widget.repository.loadRecipesForDish(
      requested.dishId,
    );
    if (!mounted) return;
    final safeVariants = variants
        .where(
          (recipe) => widget.repository.matcher.isVisible(
            recipe,
            profile,
            ignoreCalorieTarget: true,
          ),
        )
        .toList();
    if (safeVariants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.strings('dish.noSafeVariant')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final targetVariants = safeVariants
        .where((recipe) => widget.repository.matcher.isVisible(recipe, profile))
        .toList();
    var showOutsideCalories = false;
    if (targetVariants.isEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.strings('dish.outsidePromptTitle')),
          content: Text(context.strings('dish.outsidePromptBody')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.strings('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.strings('dish.outsidePromptConfirm')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      showOutsideCalories = true;
    }
    final availableForInitial = showOutsideCalories
        ? safeVariants
        : targetVariants;
    final initial =
        availableForInitial.any((recipe) => recipe.id == requested.id)
        ? requested
        : widget.repository.ranker
              .rank(
                availableForInitial,
                profile,
                history: state.cookingHistory,
                visibleOnly: false,
              )
              .first
              .recipe;
    final dish = widget.repository.dishById(requested.dishId);
    if (dish == null || !mounted) return;
    final guides = {
      for (final entry in widget.repository.ingredientGuideEntries)
        entry.ingredientId: entry,
    };
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (routeContext) => ChangeNotifierProvider.value(
          value: state,
          child: Consumer<AppState>(
            builder: (context, liveState, _) => MorphStringsScope(
              languageCode: liveState.profile!.languageCode,
              child: DishDetailScreen(
                dish: dish,
                variants: safeVariants,
                initialRecipe: initial,
                initialShowOutsideCalories: showOutsideCalories,
                profile: liveState.profile!,
                ingredients: widget.repository.ingredients,
                guideEntries: guides,
                isSaved: liveState.isSaved,
                onToggleSaved: (recipe) => liveState.toggleSaved(recipe.id),
                onAddToShopping: _addRecipeToShopping,
                onStartCooking: (recipe, servings) =>
                    unawaited(_startCooking(recipe, servings)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startCooking(Recipe recipe, int servings) async {
    if (_openingCookMode) return;
    _openingCookMode = true;
    final state = context.read<AppState>();
    CookModeControllers? controllers;
    var routeOwnsControllers = false;
    try {
      controllers = await state.createCookModeControllers(
        recipe,
        systemReduceMotion: MediaQuery.disableAnimationsOf(context),
      );
      if (!controllers.session.wasRestored) {
        controllers.session.setServings(servings.toDouble());
      }
      if (!mounted) return;
      final session = controllers.session;
      routeOwnsControllers = true;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CookModeScreen(
            recipe: recipe,
            languageCode: state.profile!.languageCode,
            session: session,
            oneHanded: controllers!.oneHanded,
            onCompleted: (recipe, servings) => state.recordCooked(
              recipe.id,
              entryId: session.completionRecordId,
              servings: servings,
            ),
          ),
        ),
      );
    } finally {
      if (!routeOwnsControllers) controllers?.dispose();
      _openingCookMode = false;
    }
  }

  Future<void> _addRecipeToShopping(Recipe recipe, int servings) =>
      _addRecipesToShopping([recipe], servingsByRecipe: {recipe.id: servings});

  Future<void> _addRecipesToShopping(
    List<Recipe> recipes, {
    Map<String, int> servingsByRecipe = const {},
  }) async {
    final state = context.read<AppState>();
    await state.addRecipesToShoppingList(
      recipes,
      ingredientDictionary: widget.repository.ingredients,
      servingsByRecipeId: servingsByRecipe.map(
        (recipeId, servings) => MapEntry(recipeId, servings.toDouble()),
      ),
    );
  }

  Future<Recipe?> _pickRecipe(DateTime date, MealSlot slot) async {
    final state = context.read<AppState>();
    await widget.repository.initialize(loadExtended: true);
    if (!mounted) return null;
    final recipes = widget.repository.visibleRecipes(state.profile!);
    return showModalBottomSheet<Recipe>(
      context: context,
      isScrollControlled: true,
      builder: (context) => MorphStringsScope(
        languageCode: state.profile!.languageCode,
        child: RecipePickerSheet(
          recipes: recipes,
          dishesById: _dishesById,
          profile: state.profile!,
          savedRecipeIds: state.savedRecipeIds,
        ),
      ),
    );
  }

  Future<void> _openShopping() async {
    final state = context.read<AppState>();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (routeContext) => ChangeNotifierProvider.value(
          value: state,
          child: Consumer<AppState>(
            builder: (context, liveState, _) => MorphStringsScope(
              languageCode: liveState.profile!.languageCode,
              child: ShoppingScreen(
                entries: liveState.shoppingEntries,
                onToggle: (entry, checked) =>
                    liveState.setShoppingChecked(entry.id, checked),
                onRemove: (entry) => liveState.removeShoppingEntry(entry.id),
                onClearChecked: liveState.clearCheckedShoppingEntries,
                onAddManual: (name, quantity, unit, aisle) {
                  return liveState.upsertShoppingEntry(
                    ShoppingEntry(
                      id: _uuid.v4(),
                      ingredientId: _slug(name),
                      name: name,
                      quantity: quantity,
                      unit: unit,
                      aisle: aisle,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openProfile() async {
    final state = context.read<AppState>();
    await widget.repository.initialize(loadExtended: true);
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MorphStringsScope(
          languageCode: state.profile!.languageCode,
          child: ProfileEditorScreen(
            profile: state.profile!,
            ingredients: widget.repository.ingredients,
            hasMatchingRecipe: (profile) =>
                widget.repository.visibleRecipes(profile).isNotEmpty,
            onSave: state.updateProfile,
            onOpenMatchingFaq: () => _openFaq(initialCategory: 'matching'),
          ),
        ),
      ),
    );
  }

  void _openFaq({String? initialQuery, String? initialCategory}) {
    final state = context.read<AppState>();
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MorphStringsScope(
          languageCode: state.profile!.languageCode,
          child: FaqScreen(
            entries: widget.repository.faqs,
            languageCode: state.profile!.languageCode,
            initialQuery: initialQuery,
            initialCategory: initialCategory,
          ),
        ),
      ),
    );
  }

  void _openInsights() {
    final state = context.read<AppState>();
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MorphStringsScope(
          languageCode: state.profile!.languageCode,
          child: ShoppingInsightsScreen(
            insights: state.shoppingInsights,
            languageCode: state.profile!.languageCode,
          ),
        ),
      ),
    );
  }

  void _openHistory() {
    final state = context.read<AppState>();
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MorphStringsScope(
          languageCode: state.profile!.languageCode,
          child: CookingHistoryScreen(
            entries: state.cookingHistory,
            recipesById: _recipesById,
            languageCode: state.profile!.languageCode,
            onOpenRecipe: _openRecipe,
          ),
        ),
      ),
    );
  }

  Future<void> _exportBackup(String? password) async {
    try {
      final facade = BackupFileFacade(
        repository: widget.backupRepository,
        gateway: widget.backupGateway,
      );
      final size = MediaQuery.sizeOf(context);
      await facade.exportAndShare(
        password: password,
        sharePositionOrigin: Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: 2,
          height: 2,
        ),
        title: context.strings('backup.shareTitle'),
        text: context.strings('backup.shareText'),
      );
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _importBackup() async {
    final appState = context.read<AppState>();
    final mode = await showDialog<RestoreMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.strings('settings.import')),
        content: Text(context.strings('backup.restoreChoiceBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.strings('common.cancel')),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, RestoreMode.replace),
            child: Text(context.strings('backup.replace')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, RestoreMode.merge),
            child: Text(context.strings('backup.merge')),
          ),
        ],
      ),
    );
    if (mode == null || !mounted) return;
    try {
      final file = await widget.backupGateway.pickBackup();
      if (file == null || !mounted) return;
      String? password;
      if (widget.backupService.detectEncoding(file.bytes) ==
          BackupEncoding.encrypted) {
        while (mounted) {
          password = await _askPassword();
          if (password == null) return;
          try {
            await widget.backupService.decryptJson(file.bytes, password);
            break;
          } on DecryptionException catch (error) {
            if (!mounted) return;
            final retry = await _showRetry(error);
            if (!retry) return;
          }
        }
      }
      final result = await widget.backupRepository.restoreBytes(
        file.bytes,
        password: password,
        mode: mode,
      );
      await appState.reload();
      await widget.repository.ensureRecipesLoaded({
        ...appState.savedRecipes.map((entry) => entry.recipeId),
        ...appState.cookingHistory.map((entry) => entry.recipeId),
        ...appState.mealPlan.entries.map((entry) => entry.recipeId),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.format('backup.restoreSuccess', {
              'saved': result.savedCount,
              'meals': result.mealPlanCount,
              'shopping': result.shoppingCount,
            }),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<String?> _askPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.strings('backup.encryptedTitle')),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(
            labelText: context.strings('settings.password'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.strings('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(context.strings('common.continue')),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<bool> _showRetry(DecryptionException error) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.strings('backup.decryptFailedTitle')),
          content: Text(_localizedBackupMessage(error)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
                _openFaq(initialQuery: context.strings('faq.backupQuery'));
              },
              child: Text(context.strings('common.help')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.strings('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.strings('common.retry')),
            ),
          ],
        ),
      ) ??
      false;

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_localizedBackupMessage(error)),
        backgroundColor: context.morph.coral,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: context.strings('common.help'),
          onPressed: () =>
              _openFaq(initialQuery: context.strings('faq.backupQuery')),
        ),
      ),
    );
  }

  String _localizedBackupMessage(Object error) {
    final source = switch (error) {
      DecryptionException value => value.message,
      BackupFormatException value => value.message,
      _ => '',
    };
    if (source.contains('enter its password')) {
      return context.strings('backup.passwordRequired');
    }
    if (source.contains('Incorrect password')) {
      return context.strings('backup.incorrectPassword');
    }
    if (source.contains('corrupted')) {
      return context.strings('backup.corrupted');
    }
    if (source.contains('could not be read')) {
      return context.strings('backup.unreadable');
    }
    if (source.contains('Unsupported backup schema')) {
      return context.strings('backup.unsupported');
    }
    if (source.contains('not a valid MorphCook backup')) {
      return context.strings('backup.invalid');
    }
    return context.strings('backup.unexpected');
  }
}

List<Recipe> _uniqueDishes(Iterable<Recipe> recipes) {
  final seen = <String>{};
  return [
    for (final recipe in recipes)
      if (seen.add(recipe.dishId)) recipe,
  ];
}

String _slug(String input) => input
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9äöüß]+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');
