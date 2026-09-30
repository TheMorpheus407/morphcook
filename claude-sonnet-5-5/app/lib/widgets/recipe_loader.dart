import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/corpus.dart';
import '../data/models/dish.dart';
import '../data/models/recipe.dart';

/// Builds with the recipe (and its dish) once its partition is loaded. The
/// load starts once per id, so a rebuild never restarts it.
class RecipeLoader extends StatefulWidget {
  const RecipeLoader({super.key, required this.recipeId, required this.builder});

  final String recipeId;

  /// [recipe] and [dish] are `null` while loading, or when the id no longer
  /// exists in the bundled corpus.
  final Widget Function(BuildContext context, Recipe? recipe, Dish? dish) builder;

  @override
  State<RecipeLoader> createState() => _RecipeLoaderState();
}

class _RecipeLoaderState extends State<RecipeLoader> {
  Recipe? _recipe;
  late Corpus _corpus;
  String? _loadedId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _corpus = context.read<Corpus>();
    _ensure();
  }

  @override
  void didUpdateWidget(RecipeLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recipeId != widget.recipeId) _ensure();
  }

  void _ensure() {
    final id = widget.recipeId;
    if (_loadedId == id) return;
    _loadedId = id;
    _recipe = _corpus.recipeSync(id);
    if (_recipe == null) {
      _corpus.loadRecipe(id).then((recipe) {
        if (mounted && _loadedId == id) setState(() => _recipe = recipe);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = _recipe;
    return widget.builder(context, recipe, recipe == null ? null : _corpus.dishOfRecipe(recipe.id));
  }
}
