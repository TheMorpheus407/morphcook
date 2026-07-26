import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/paper.dart';
import '../../domain/collections.dart';
import '../../domain/models.dart';
import '../../domain/units.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import 'cook_controller.dart';

/// Dark, full-bleed, one step at a time.
///
/// Everything here is sized for a phone propped against a bag of flour: big
/// type, big targets, no chrome competing for attention.
class CookScreen extends StatefulWidget {
  const CookScreen({
    super.key,
    required this.recipeId,
    this.servings,
    this.resume = false,
  });

  final String recipeId;
  final int? servings;
  final bool resume;

  @override
  State<CookScreen> createState() => _CookScreenState();
}

class _CookScreenState extends State<CookScreen> {
  final StepTimer _timer = StepTimer();

  int _index = 0;
  int _servings = 2;
  bool _finished = false;
  bool _flashing = false;
  bool _ready = false;

  late OneHandedCookModeController _oneHanded;

  @override
  void initState() {
    super.initState();
    _timer.onFinished = _onTimerFinished;
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  Recipe? get _recipe =>
      context.read<AppState>().repository.recipe(widget.recipeId);

  Future<void> _bootstrap() async {
    final state = context.read<AppState>();
    await state.repository.ensureRecipeLoaded(widget.recipeId);
    if (!mounted) return;
    final recipe = _recipe;
    if (recipe == null) return;

    var index = 0;
    var servings = widget.servings ?? recipe.servings;
    int? resumeTimer;

    final progress = state.cookProgress;
    if (widget.resume &&
        progress != null &&
        progress.recipeId == widget.recipeId) {
      index = progress.stepIndex.clamp(0, recipe.steps.length - 1);
      servings = progress.servings;
      resumeTimer = progress.remainingTimerSeconds;
    }

    setState(() {
      _index = index;
      _servings = servings;
      _ready = true;
    });
    _configureTimer(recipe, index, resumeAt: resumeTimer);
    await _persist();
  }

  void _configureTimer(Recipe recipe, int index, {int? resumeAt}) {
    _timer.configure(recipe.steps[index].timerSeconds, resumeAt: resumeAt);
  }

  Future<void> _persist() async {
    final state = context.read<AppState>();
    await state.saveCookProgress(
      CookProgress(
        recipeId: widget.recipeId,
        stepIndex: _index,
        servings: _servings,
        updatedAt: state.now,
        remainingTimerSeconds: _timer.hasTimer ? _timer.remaining : null,
      ),
    );
  }

  void _onTimerFinished() {
    final state = context.read<AppState>();
    HapticFeedback.heavyImpact();
    if (!state.profile.visualAlertEnabled) return;
    setState(() => _flashing = true);
    Future.delayed(Motion.gentle(context, MorphDurations.flash * 4), () {
      if (mounted) setState(() => _flashing = false);
    });
  }

  void _go(int next) {
    final recipe = _recipe;
    if (recipe == null) return;
    if (next < 0) return;
    if (next >= recipe.steps.length) {
      _finish();
      return;
    }
    setState(() => _index = next);
    _configureTimer(recipe, next);
    _persist();
  }

  Future<void> _finish() async {
    final state = context.read<AppState>();
    setState(() => _finished = true);
    await state.logCooked(widget.recipeId, servings: _servings);
    await state.saveCookProgress(null);
  }

  Future<void> _leave() async {
    final state = context.read<AppState>();
    final s = S(state.lang);
    if (_finished) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.cookExit),
        content: Text(s.cookExitConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(s.cookExit),
          ),
        ],
      ),
    );
    if (leave ?? false) {
      await _persist();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final recipe = _recipe;

    _oneHanded = OneHandedCookModeController(
      quickNextTapEnabled: state.profile.quickNextTapEnabled,
      reduceMotion: Motion.of(context),
    );

    if (!_ready || recipe == null) {
      return const Scaffold(
        backgroundColor: Paper.night,
        body: Center(child: CircularProgressIndicator(strokeWidth: 1.6)),
      );
    }

    return Theme(
      data: _nightTheme(context),
      child: PopScope(
        canPop: _finished,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: Scaffold(
          backgroundColor: Paper.night,
          body: Stack(
            children: [
              SafeArea(
                child: _finished
                    ? _CompletionView(
                        recipe: recipe,
                        servings: _servings,
                        s: s,
                        onClose: () => Navigator.of(context).pop(),
                      )
                    : _StepView(
                        recipe: recipe,
                        index: _index,
                        servings: _servings,
                        timer: _timer,
                        s: s,
                        oneHanded: _oneHanded,
                        onPrev: () => _go(_index - 1),
                        onNext: () => _go(_index + 1),
                        onServings: (v) {
                          setState(() => _servings = v);
                          _persist();
                        },
                        onExit: _leave,
                      ),
              ),
              if (_flashing) const _FlashOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  static ThemeData _nightTheme(BuildContext context) {
    final base = Theme.of(context);
    const night = MorphColors(
      paper: Paper.night,
      paperRaised: Paper.nightRaised,
      paperSunk: Color(0xFF0D0C0A),
      edge: Color(0xFF3A342C),
      ink: Color(0xFFF3EADA),
      inkSoft: Color(0xFFB9AE9B),
      inkFaint: Color(0xFF807668),
      accent: Color(0xFFE08A6C),
      accentSoft: Color(0xFF4A2E23),
      secondary: Color(0xFF74B3AD),
      secondarySoft: Color(0xFF1F3B39),
      mustard: Color(0xFFDDB55F),
      grainOpacity: 0.02,
    );
    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Paper.night,
      textTheme: MorphType.textTheme(night.ink, night.inkSoft),
      extensions: <ThemeExtension<dynamic>>[night],
    );
  }
}

class _StepView extends StatelessWidget {
  const _StepView({
    required this.recipe,
    required this.index,
    required this.servings,
    required this.timer,
    required this.s,
    required this.oneHanded,
    required this.onPrev,
    required this.onNext,
    required this.onServings,
    required this.onExit,
  });

  final Recipe recipe;
  final int index;
  final int servings;
  final StepTimer timer;
  final S s;
  final OneHandedCookModeController oneHanded;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<int> onServings;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final colors = context.colors;
    final step = recipe.steps[index];
    final scale = recipe.servings == 0 ? 1.0 : servings / recipe.servings;
    final relevant = ingredientsMentionedIn(
      step,
      recipe,
      state.repository.ingredients,
      s.lang,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.close, color: colors.inkSoft),
                onPressed: onExit,
                tooltip: s.cookExit,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      recipe.title(s.lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      s.cookStepOf(index + 1, recipe.steps.length),
                      style: MorphType.numeric(colors.inkFaint, size: 10.5),
                    ),
                  ],
                ),
              ),
              _ServingsPill(servings: servings, onChanged: onServings, s: s),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _ProgressTicks(count: recipe.steps.length, index: index),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (oneHanded.registerTap(state.now)) {
                HapticFeedback.selectionClick();
                onNext();
              }
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}'.padLeft(2, '0'),
                    style: MorphType.numeric(
                      colors.accent,
                      size: 46,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    step.text(s.lang),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(fontSize: 24, height: 1.5),
                  ),
                  if (relevant.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    DashedRule(
                      color: colors.edge,
                      label: Text(
                        s.cookIngredientsForStep.toUpperCase(),
                        style: MorphType.eyebrow(colors.inkFaint),
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final item in relevant)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 92,
                              child: Text(
                                _quantityLabel(item, scale, s.lang),
                                style: MorphType.numeric(
                                  colors.mustard,
                                  size: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                state.repository.ingredients[item.ingredientId]
                                        ?.label(s.lang) ??
                                    item.ingredientId,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  if (oneHanded.isActive) ...[
                    const SizedBox(height: 24),
                    Text(
                      s.cookQuickTapHint,
                      style: MorphType.numeric(colors.inkFaint, size: 10.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (timer.hasTimer) _TimerPanel(timer: timer, s: s),
        _CookNav(
          index: index,
          last: recipe.steps.length - 1,
          s: s,
          onPrev: onPrev,
          onNext: onNext,
        ),
      ],
    );
  }

  static String _quantityLabel(
    RecipeIngredient item,
    double scale,
    String lang,
  ) {
    final q = quantityOf(item.scaled(scale));
    return q == null ? '—' : UnitLabels.format(q, lang);
  }
}

class _ProgressTicks extends StatelessWidget {
  const _ProgressTicks({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: Motion.duration(context, MorphDurations.fade),
                height: i == index ? 3 : 1.4,
                color: i <= index ? colors.accent : colors.edge,
              ),
            ),
            if (i < count - 1) const SizedBox(width: 3),
          ],
        ],
      ),
    );
  }
}

class _TimerPanel extends StatelessWidget {
  const _TimerPanel({required this.timer, required this.s});

  final StepTimer timer;
  final S s;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedBuilder(
      animation: timer,
      builder: (context, _) {
        final done = timer.finished;
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: done ? colors.accentSoft : colors.paperRaised,
            border: Border.all(color: done ? colors.accent : colors.edge),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    _format(timer.remaining),
                    style: MorphType.numeric(
                      done ? colors.accent : colors.ink,
                      size: 34,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (done)
                    Text(
                      s.cookTimerDone,
                      style: MorphType.eyebrow(colors.accent),
                    )
                  else ...[
                    IconButton(
                      icon: Icon(
                        timer.running ? Icons.pause : Icons.play_arrow,
                        color: colors.ink,
                      ),
                      onPressed: timer.toggle,
                      tooltip: timer.running ? s.cookPause : s.cookStart,
                    ),
                    IconButton(
                      icon: Icon(Icons.replay, color: colors.inkSoft),
                      onPressed: timer.reset,
                      tooltip: s.cookReset,
                    ),
                  ],
                  if (done)
                    IconButton(
                      icon: Icon(Icons.replay, color: colors.accent),
                      onPressed: timer.reset,
                      tooltip: s.cookReset,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: timer.progress,
                minHeight: 2,
                backgroundColor: colors.paperSunk,
                color: done ? colors.accent : colors.secondary,
              ),
            ],
          ),
        );
      },
    );
  }

  static String _format(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }
}

class _CookNav extends StatelessWidget {
  const _CookNav({
    required this.index,
    required this.last,
    required this.s,
    required this.onPrev,
    required this.onNext,
  });

  final int index;
  final int last;
  final S s;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: index == 0 ? null : onPrev,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.ink,
                  side: BorderSide(color: colors.edge),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: Text(s.cookPrev),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Paper.night,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: Text(index == last ? s.cookFinish : s.cookNext),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServingsPill extends StatelessWidget {
  const _ServingsPill({
    required this.servings,
    required this.onChanged,
    required this.s,
  });

  final int servings;
  final ValueChanged<int> onChanged;
  final S s;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: colors.edge)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: servings > 1 ? () => onChanged(servings - 1) : null,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.remove, size: 14, color: colors.inkSoft),
            ),
          ),
          Text(
            '$servings',
            style: MorphType.numeric(
              colors.ink,
              size: 14,
              weight: FontWeight.w700,
            ),
          ),
          InkWell(
            onTap: servings < 12 ? () => onChanged(servings + 1) : null,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.add, size: 14, color: colors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

/// Coral/teal flash for timers, for anyone who will not hear a beep.
/// Reduced motion turns the pulse into a single steady hold.
class _FlashOverlay extends StatelessWidget {
  const _FlashOverlay();

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.of(context);
    if (reduced) {
      return IgnorePointer(
        child: Container(color: Paper.coral.withValues(alpha: 0.4)),
      );
    }
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 6),
        duration: MorphDurations.flash * 6,
        builder: (context, t, _) {
          final phase = t % 2;
          final color = phase < 1 ? Paper.coral : Paper.teal;
          final alpha = 0.45 * (1 - (phase % 1));
          return Container(
            color: color.withValues(alpha: alpha.clamp(0.0, 1.0)),
          );
        },
      ),
    );
  }
}

class _CompletionView extends StatelessWidget {
  const _CompletionView({
    required this.recipe,
    required this.servings,
    required this.s,
    required this.onClose,
  });

  final Recipe recipe;
  final int servings;
  final S s;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.cookDoneTitle.toLowerCase(),
            style: Theme.of(context).textTheme.displayLarge,
          ),
          const SizedBox(height: 14),
          DashedRule(color: colors.edge),
          const SizedBox(height: 18),
          Text(
            recipe.title(s.lang),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            '${s.servings(servings)} · ${s.kcal(recipe.caloriesPerServing)}',
            style: MorphType.numeric(colors.inkSoft, size: 12),
          ),
          const SizedBox(height: 20),
          Text(s.cookDoneBody, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 18),
          HandNote(s.cookDoneHand, size: 26, color: colors.accent),
          const SizedBox(height: 34),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onClose,
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Paper.night,
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              child: Text(s.done),
            ),
          ),
        ],
      ),
    );
  }
}
