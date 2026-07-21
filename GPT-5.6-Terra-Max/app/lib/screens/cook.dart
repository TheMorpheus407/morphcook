import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../app_state.dart';
import '../copy.dart';
import '../models.dart';
import '../services.dart';
import '../theme.dart';

class CookModeScreen extends StatefulWidget {
  const CookModeScreen({super.key, required this.recipeId});
  final String recipeId;

  @override
  State<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends State<CookModeScreen> {
  Timer? _timer;
  Recipe? _recipe;
  var _stepIndex = 0;
  var _servings = 2;
  var _remaining = 0;
  var _running = false;
  var _alert = false;
  var _alertColor = MorphColors.coral;
  var _loaded = false;
  final _quickNextController = OneHandedCookModeController();
  MorphCookState? _state;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final state = MorphCookScope.of(context);
    _state = state;
    _recipe = state.recipeById(widget.recipeId);
    final progress = state.cookProgress[widget.recipeId];
    if (_recipe != null) {
      _stepIndex = progress?.stepIndex.clamp(0, _recipe!.steps.length - 1) ?? 0;
      _servings = progress?.servings ?? _recipe!.servings;
      _remaining =
          progress?.remainingSeconds ??
          _recipe!.steps[_stepIndex].timerSeconds ??
          0;
      _running = false;
    }
    _loaded = true;
  }

  @override
  void dispose() {
    _persist();
    _timer?.cancel();
    _quickNextController.dispose();
    super.dispose();
  }

  void _persist() {
    final recipe = _recipe;
    if (recipe == null) return;
    final state = _state;
    if (state == null) return;
    unawaited(
      state.saveCookProgress(
        CookProgress(
          recipeId: recipe.id,
          stepIndex: _stepIndex,
          servings: _servings,
          remainingSeconds: _remaining,
          isTimerRunning: false,
        ),
      ),
    );
  }

  void _toggleTimer() {
    if (_remaining <= 0) return;
    setState(() => _running = !_running);
    if (_running) {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_running) return;
        if (_remaining <= 1) {
          _timer?.cancel();
          _timer = null;
          setState(() {
            _remaining = 0;
            _running = false;
            _alertColor = _alertColor == MorphColors.coral
                ? MorphColors.teal
                : MorphColors.coral;
            _alert = MorphCookScope.of(context).profile.visualAlertEnabled;
          });
          HapticFeedback.heavyImpact();
          Timer(const Duration(milliseconds: 900), () {
            if (mounted) setState(() => _alert = false);
          });
        } else {
          setState(() => _remaining--);
        }
      });
    }
    _persist();
  }

  void _goTo(int step) {
    final recipe = _recipe!;
    if (step < 0 || step >= recipe.steps.length) return;
    setState(() {
      _timer?.cancel();
      _timer = null;
      _running = false;
      _alert = false;
      _stepIndex = step;
      _remaining = recipe.steps[step].timerSeconds ?? 0;
    });
    _persist();
  }

  void _quickAdvance() {
    final state = MorphCookScope.of(context);
    _quickNextController.setEnabled(state.profile.quickNextTapEnabled);
    if (!_quickNextController.canTrigger()) return;
    HapticFeedback.lightImpact();
    if (_stepIndex == _recipe!.steps.length - 1) {
      _finish();
    } else {
      _goTo(_stepIndex + 1);
    }
  }

  Future<void> _finish() async {
    final state = MorphCookScope.of(context);
    final recipe = _recipe!;
    _timer?.cancel();
    await state.recordCooked(recipe.id);
    await state.clearCookProgress(recipe.id);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => CookCompleteScreen(recipe: recipe)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipe = _recipe;
    if (recipe == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final state = MorphCookScope.of(context);
    final step = recipe.steps[_stepIndex];
    final reduced =
        state.profile.reduceMotion ?? MediaQuery.of(context).disableAnimations;
    return PopScope(
      onPopInvokedWithResult: (_, _) => _persist(),
      child: Scaffold(
        backgroundColor: MorphColors.night,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 5, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          color: MorphColors.nightPaper,
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.close),
                        ),
                        Expanded(
                          child: Text(
                            recipe.titleFor(state.lang),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: MorphColors.nightPaper,
                              fontFamily: 'Georgia',
                              fontStyle: FontStyle.italic,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        Text(
                          '${_stepIndex + 1}/${recipe.steps.length}',
                          style: const TextStyle(
                            color: MorphColors.nightPaper,
                            fontFamily: 'Courier',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      color: MorphColors.teal,
                      backgroundColor: Colors.white.withValues(alpha: .12),
                      value: (_stepIndex + 1) / recipe.steps.length,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _quickAdvance,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 22,
                        ),
                        child: AnimatedSwitcher(
                          duration: reduced
                              ? Duration.zero
                              : const Duration(milliseconds: 250),
                          child: Column(
                            key: ValueKey(_stepIndex),
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_stepIndex + 1}'.padLeft(2, '0'),
                                style: const TextStyle(
                                  color: MorphColors.coral,
                                  fontFamily: 'Courier',
                                  fontSize: 18,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                localize(step.text, state.lang),
                                style: const TextStyle(
                                  color: Color(0xfff5eee2),
                                  fontFamily: 'Georgia',
                                  fontSize: 31,
                                  height: 1.13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 27),
                              if (step.timerSeconds != null)
                                _TimerFace(
                                  remaining: _remaining,
                                  running: _running,
                                  onToggle: _toggleTimer,
                                  lang: state.lang,
                                ),
                              const SizedBox(height: 25),
                              _ServingStepper(
                                servings: _servings,
                                label: Copybook.t('servings', state.lang),
                                onChanged: (value) {
                                  setState(() => _servings = value);
                                  _persist();
                                },
                              ),
                              const SizedBox(height: 9),
                              _ScaledIngredients(
                                recipe: recipe,
                                servings: _servings,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                state.profile.quickNextTapEnabled
                                    ? (state.lang == 'de'
                                          ? 'einmal auf den Schritt tippen zum Weitergehen'
                                          : 'tap the step once to advance')
                                    : '',
                                style: const TextStyle(
                                  color: Color(0xffaaa397),
                                  fontFamily: 'Courier',
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: MorphColors.nightPaper,
                            side: const BorderSide(color: Color(0xff8e9287)),
                          ),
                          onPressed: _stepIndex == 0
                              ? null
                              : () => _goTo(_stepIndex - 1),
                          icon: const Icon(Icons.arrow_back, size: 17),
                          label: Text(Copybook.t('previous', state.lang)),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: MorphColors.teal,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _stepIndex == recipe.steps.length - 1
                              ? _finish
                              : () => _goTo(_stepIndex + 1),
                          icon: Icon(
                            _stepIndex == recipe.steps.length - 1
                                ? Icons.check
                                : Icons.arrow_forward,
                          ),
                          label: Text(
                            _stepIndex == recipe.steps.length - 1
                                ? Copybook.t('finish', state.lang)
                                : Copybook.t('next', state.lang),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              IgnorePointer(
                child: AnimatedOpacity(
                  duration: reduced
                      ? Duration.zero
                      : const Duration(milliseconds: 100),
                  opacity: _alert ? .92 : 0,
                  child: ColoredBox(
                    color: _alertColor,
                    child: Center(
                      child: Icon(
                        Icons.timer_outlined,
                        size: 96,
                        color: MorphColors.paper.withValues(alpha: .92),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimerFace extends StatelessWidget {
  const _TimerFace({
    required this.remaining,
    required this.running,
    required this.onToggle,
    required this.lang,
  });
  final int remaining;
  final bool running;
  final VoidCallback onToggle;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;
    return Row(
      children: [
        Text(
          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
          style: const TextStyle(
            color: MorphColors.mustard,
            fontFamily: 'Courier',
            fontSize: 37,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 13),
        IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: MorphColors.mustard,
            foregroundColor: MorphColors.night,
          ),
          onPressed: onToggle,
          icon: Icon(running ? Icons.pause : Icons.play_arrow),
          tooltip: running
              ? Copybook.t('pause', lang)
              : Copybook.t('resume', lang),
        ),
      ],
    );
  }
}

class _ServingStepper extends StatelessWidget {
  const _ServingStepper({
    required this.servings,
    required this.label,
    required this.onChanged,
  });
  final int servings;
  final String label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Color(0xffaaa397),
          fontFamily: 'Courier',
          fontSize: 11,
        ),
      ),
      const SizedBox(width: 12),
      IconButton(
        visualDensity: VisualDensity.compact,
        color: MorphColors.nightPaper,
        onPressed: servings <= 1 ? null : () => onChanged(servings - 1),
        icon: const Icon(Icons.remove_circle_outline),
      ),
      Text(
        '$servings',
        style: const TextStyle(
          color: MorphColors.nightPaper,
          fontFamily: 'Courier',
          fontSize: 18,
        ),
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        color: MorphColors.nightPaper,
        onPressed: servings >= 12 ? null : () => onChanged(servings + 1),
        icon: const Icon(Icons.add_circle_outline),
      ),
    ],
  );
}

class _ScaledIngredients extends StatelessWidget {
  const _ScaledIngredients({required this.recipe, required this.servings});

  final Recipe recipe;
  final int servings;

  @override
  Widget build(BuildContext context) {
    final state = MorphCookScope.of(context);
    final scale = servings / recipe.servings;
    return Wrap(
      spacing: 7,
      runSpacing: 6,
      children: recipe.ingredients.map((ingredient) {
        final adjusted = ingredient.amount * scale;
        final number = adjusted == adjusted.roundToDouble()
            ? adjusted.toInt().toString()
            : adjusted.toStringAsFixed(1);
        final name =
            state.repository.ingredients[ingredient.id]?.nameFor(state.lang) ??
            ingredient.id;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xff5e6963)),
          ),
          child: Text(
            '$number ${ingredient.unit} $name'.trim(),
            style: const TextStyle(
              color: Color(0xffc7c0b4),
              fontFamily: 'Courier',
              fontSize: 10,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class CookCompleteScreen extends StatelessWidget {
  const CookCompleteScreen({super.key, required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final state = MorphCookScope.of(context);
    return Scaffold(
      backgroundColor: MorphColors.night,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Text(
                '✦',
                style: TextStyle(color: MorphColors.mustard, fontSize: 44),
              ),
              const SizedBox(height: 14),
              Text(
                Copybook.t('cooked', state.lang),
                style: const TextStyle(
                  color: MorphColors.nightPaper,
                  fontFamily: 'Georgia',
                  fontSize: 39,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                recipe.titleFor(state.lang),
                style: const TextStyle(
                  color: Color(0xffaaa397),
                  fontFamily: 'Courier',
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: MorphColors.teal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(Copybook.t('cookAgain', state.lang)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
