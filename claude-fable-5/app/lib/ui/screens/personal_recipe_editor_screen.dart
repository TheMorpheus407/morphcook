import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../models/personal_recipe.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/decor.dart';

/// Editor for recipes that remain on this device (unless exported in a
/// backup). The compact runtime [Recipe] is derived only after validation.
class PersonalRecipeEditorScreen extends StatefulWidget {
  final PersonalRecipe? recipe;

  const PersonalRecipeEditorScreen({super.key, this.recipe});

  @override
  State<PersonalRecipeEditorScreen> createState() =>
      _PersonalRecipeEditorScreenState();
}

class _PersonalRecipeEditorScreenState
    extends State<PersonalRecipeEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _time;
  late final TextEditingController _servings;
  late final List<_IngredientDraft> _ingredients;
  late final List<_StepDraft> _steps;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final recipe = widget.recipe;
    _title = TextEditingController(text: recipe?.title);
    _description = TextEditingController(text: recipe?.description);
    _time = TextEditingController(text: recipe?.timeMinutes.toString() ?? '30');
    _servings = TextEditingController(text: recipe?.servings.toString() ?? '2');
    _ingredients = recipe == null
        ? [_IngredientDraft()]
        : recipe.ingredients.map(_IngredientDraft.fromIngredient).toList();
    _steps = recipe == null
        ? [_StepDraft()]
        : recipe.steps.map(_StepDraft.fromStep).toList();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _time.dispose();
    _servings.dispose();
    for (final ingredient in _ingredients) {
      ingredient.dispose();
    }
    for (final step in _steps) {
      step.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final morph = MorphTheme.of(context);
    final editing = widget.recipe != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          editing ? s('editRecipe') : s('newRecipe'),
          style: morph.text.display.copyWith(fontSize: 22),
        ),
      ),
      body: PaperBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              s('privateRecipeHint'),
              style: morph.text.handAt(17, color: morph.colors.inkSoft),
            ),
            const SizedBox(height: 16),
            _textField(
              controller: _title,
              label: s('recipeTitle'),
              key: const ValueKey('recipe-title'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _textField(
              controller: _description,
              label: s('recipeDescription'),
              key: const ValueKey('recipe-description'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _textField(
                    controller: _time,
                    label: s('recipeTime'),
                    key: const ValueKey('recipe-time'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _textField(
                    controller: _servings,
                    label: s('servings'),
                    key: const ValueKey('recipe-servings'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            SectionHeader(title: s('ingredients')),
            for (var i = 0; i < _ingredients.length; i++) _ingredientCard(i, s),
            TextButton.icon(
              onPressed: () => setState(() {
                _ingredients.add(_IngredientDraft());
                _error = null;
              }),
              icon: const Icon(Icons.add, size: 18),
              label: Text(s('addIngredient')),
            ),
            SectionHeader(title: s('method')),
            for (var i = 0; i < _steps.length; i++) _stepCard(i, s),
            TextButton.icon(
              onPressed: () => setState(() {
                _steps.add(_StepDraft());
                _error = null;
              }),
              icon: const Icon(Icons.add, size: 18),
              label: Text(s('addStep')),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  _error!,
                  key: const ValueKey('recipe-editor-error'),
                  style: morph.text.mono.copyWith(
                    fontSize: 12,
                    color: morph.colors.coral,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey('save-personal-recipe'),
              onPressed: _saving ? null : () => _save(state, s),
              style: FilledButton.styleFrom(
                backgroundColor: morph.colors.ink,
                foregroundColor: morph.colors.paper,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              child: Text(
                morph.cased(editing ? s('saveChanges') : s('createRecipe')),
                style: morph.text.label(color: morph.colors.paper),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ingredientCard(int index, S s) {
    final morph = MorphTheme.of(context);
    final draft = _ingredients[index];
    return Container(
      key: ValueKey('ingredient-$index'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: morph.colors.card,
        border: Border.all(color: morph.colors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _textField(
                  controller: draft.name,
                  label: s('ingredientName'),
                  key: ValueKey('ingredient-name-$index'),
                  textInputAction: TextInputAction.next,
                ),
              ),
              IconButton(
                tooltip: s('removeIngredient'),
                onPressed: _ingredients.length == 1
                    ? null
                    : () => setState(() {
                        _ingredients.removeAt(index).dispose();
                        _error = null;
                      }),
                icon: const Icon(Icons.remove_circle_outline, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _textField(
                  controller: draft.qty,
                  label: s('quantity'),
                  key: ValueKey('ingredient-qty-$index'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _textField(
                  controller: draft.unit,
                  label: s('unit'),
                  key: ValueKey('ingredient-unit-$index'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _textField(
            controller: draft.note,
            label: s('ingredientNote'),
            key: ValueKey('ingredient-note-$index'),
          ),
        ],
      ),
    );
  }

  Widget _stepCard(int index, S s) {
    final morph = MorphTheme.of(context);
    final draft = _steps[index];
    return Container(
      key: ValueKey('step-$index'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: morph.colors.card,
        border: Border.all(color: morph.colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, right: 10),
                child: Text(
                  '${index + 1}.',
                  style: morph.text.display.copyWith(
                    fontSize: 20,
                    color: morph.colors.terracotta,
                  ),
                ),
              ),
              Expanded(
                child: _textField(
                  controller: draft.text,
                  label: s('stepInstructions'),
                  key: ValueKey('step-text-$index'),
                  maxLines: 3,
                ),
              ),
              IconButton(
                tooltip: s('removeStep'),
                onPressed: _steps.length == 1
                    ? null
                    : () => setState(() {
                        _steps.removeAt(index).dispose();
                        _error = null;
                      }),
                icon: const Icon(Icons.remove_circle_outline, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 190,
            child: _textField(
              controller: draft.timer,
              label: s('timerMinutesOptional'),
              key: ValueKey('step-timer-$index'),
              keyboardType: TextInputType.number,
            ),
          ),
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required Key key,
    int maxLines = 1,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
  }) => TextField(
    key: key,
    controller: controller,
    maxLines: maxLines,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    decoration: InputDecoration(labelText: label),
  );

  Future<void> _save(AppState state, S s) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final ingredients = [
        for (final draft in _ingredients)
          PersonalRecipeIngredient(
            name: draft.name.text,
            qty: double.parse(draft.qty.text.trim().replaceAll(',', '.')),
            unit: draft.unit.text,
            note: draft.note.text,
          ),
      ];
      final steps = [
        for (final draft in _steps)
          PersonalRecipeStep(
            text: draft.text.text,
            timerMinutes: draft.timer.text.trim().isEmpty
                ? null
                : int.parse(draft.timer.text.trim()),
          ),
      ];
      final existing = widget.recipe;
      final recipe = existing == null
          ? PersonalRecipe.create(
              title: _title.text,
              description: _description.text,
              timeMinutes: int.parse(_time.text.trim()),
              servings: int.parse(_servings.text.trim()),
              ingredients: ingredients,
              steps: steps,
            )
          : existing.copyWith(
              title: _title.text,
              description: _description.text,
              timeMinutes: int.parse(_time.text.trim()),
              servings: int.parse(_servings.text.trim()),
              ingredients: ingredients,
              steps: steps,
              updatedAt: DateTime.now(),
            );
      await state.savePersonalRecipe(recipe);
      if (!mounted) return;
      Navigator.of(context).pop(recipe.id);
    } on PersonalRecipeLimitException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = switch (error.reason) {
          PersonalRecipeLimitReason.count => s('personalRecipeLimit'),
          PersonalRecipeLimitReason.backupSize => s(
            'personalRecipeBackupLimit',
          ),
        };
      });
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = s('recipeValidation');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = s('personalRecipeSaveFailed');
      });
    }
  }
}

class _IngredientDraft {
  final TextEditingController name;
  final TextEditingController qty;
  final TextEditingController unit;
  final TextEditingController note;

  _IngredientDraft({
    String name = '',
    String qty = '1',
    String note = '',
    String unit = 'piece',
  }) : name = TextEditingController(text: name),
       qty = TextEditingController(text: qty),
       unit = TextEditingController(text: unit),
       note = TextEditingController(text: note);

  factory _IngredientDraft.fromIngredient(PersonalRecipeIngredient value) =>
      _IngredientDraft(
        name: value.name,
        qty: _number(value.qty),
        note: value.note ?? '',
        unit: value.unit,
      );

  void dispose() {
    name.dispose();
    qty.dispose();
    unit.dispose();
    note.dispose();
  }
}

class _StepDraft {
  final TextEditingController text;
  final TextEditingController timer;

  _StepDraft({String text = '', String timer = ''})
    : text = TextEditingController(text: text),
      timer = TextEditingController(text: timer);

  factory _StepDraft.fromStep(PersonalRecipeStep value) =>
      _StepDraft(text: value.text, timer: value.timerMinutes?.toString() ?? '');

  void dispose() {
    text.dispose();
    timer.dispose();
  }
}

String _number(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toString();
