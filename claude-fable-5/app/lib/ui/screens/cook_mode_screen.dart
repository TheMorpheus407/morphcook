import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../logic/cook/cook_controller.dart';
import '../../logic/units.dart';
import '../../models/recipe.dart';
import '../strings.dart';
import '../theme.dart';

/// Cook mode: dark, full-bleed, one step at a time. Per-step timers,
/// servings scaler, pause/resume with persisted progress, completion
/// screen, visual flash alert on timer end, optional one-handed quick-tap.
class CookModeScreen extends StatefulWidget {
  final Recipe recipe;
  const CookModeScreen({super.key, required this.recipe});

  @override
  State<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends State<CookModeScreen> {
  late CookSessionController _session;
  late OneHandedCookModeController _oneHanded;
  bool _flashing = false;
  Color _flashColor = MorphColors.coral;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final resume = state.cookProgress?.recipeId == widget.recipe.id
        ? state.cookProgress
        : null;
    _session = CookSessionController(
      recipe: widget.recipe,
      persist: state.persistCookProgress,
      resumeFrom: resume,
    );
    _oneHanded = OneHandedCookModeController(
        quickNextTapEnabled: state.profile.quickNextTapEnabled);
    _session.addListener(_onSession);
  }

  void _onSession() {
    if (_session.timerJustFinished) {
      _session.consumeTimerAlert();
      _triggerFlash();
    }
    if (mounted) setState(() {});
  }

  /// Visual timer alert for deaf / hard-of-hearing users: alternating
  /// coral/teal full-screen flashes. Skipped when motion is reduced —
  /// a steady banner is shown instead.
  Future<void> _triggerFlash() async {
    final state = context.read<AppState>();
    if (!state.profile.visualAlertEnabled) return;
    HapticFeedback.heavyImpact();
    final reduce = state.profile.reduceMotion ??
        MediaQuery.maybeDisableAnimationsOf(context) ??
        false;
    if (reduce) {
      setState(() {
        _flashing = true;
        _flashColor = MorphColors.coral;
      });
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) setState(() => _flashing = false);
      return;
    }
    for (var i = 0; i < 4; i++) {
      if (!mounted) return;
      setState(() {
        _flashing = true;
        _flashColor = i.isEven ? MorphColors.coral : MorphColors.teal;
      });
      await Future.delayed(const Duration(milliseconds: 240));
    }
    if (mounted) setState(() => _flashing = false);
  }

  void _quickTap() {
    if (_oneHanded.handleTap()) {
      HapticFeedback.selectionClick();
      _session.nextStep();
    }
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final lang = state.lang;
    final recipe = widget.recipe;

    if (_session.isCompleted) return _completion(state, s);

    final step = recipe.steps[_session.stepIndex];
    final remaining = _session.remainingSeconds;

    return Scaffold(
      backgroundColor: _flashing ? _flashColor : MorphColors.night,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(recipe.title.of(lang).toLowerCase(),
                        style: MorphText.display.copyWith(
                            fontSize: 20, color: MorphColors.cream)),
                  ),
                  _servingsScaler(s),
                  IconButton(
                    icon: const Icon(Icons.format_list_bulleted,
                        size: 20, color: MorphColors.cream),
                    tooltip: s('ingredients'),
                    onPressed: () => _showScaledIngredients(state, s),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: MorphColors.cream),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    '${s('step')} ${_session.stepIndex + 1} ${s('of')} ${recipe.steps.length}'
                        .toLowerCase(),
                    style: MorphText.label(color: MorphColors.inkFaint),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LinearProgressIndicator(
                      value:
                          (_session.stepIndex + 1) / recipe.steps.length,
                      backgroundColor: MorphColors.nightCard,
                      color: MorphColors.terracotta,
                      minHeight: 2,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _quickTap,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_session.stepIndex + 1}.',
                          style: MorphText.display.copyWith(
                              fontSize: 44,
                              color: MorphColors.terracotta)),
                      const SizedBox(height: 12),
                      Text(
                        step.text.of(lang),
                        style: MorphText.serif.copyWith(
                            fontSize: 21, color: MorphColors.cream),
                      ),
                      if (_session.quickTapHintVisible(state))
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(s('quickTapHint'),
                              style: MorphText.hand.copyWith(
                                  fontSize: 17,
                                  color: MorphColors.inkFaint)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (remaining != null) _timerBar(remaining, s),
            _navBar(s),
          ],
        ),
      ),
    );
  }

  /// Ingredient list scaled to the session's servings — what the
  /// servings scaler actually changes at the stove.
  void _showScaledIngredients(AppState state, S s) {
    final lang = state.lang;
    final factor = _session.scaleFactor;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MorphColors.nightCard,
      builder: (context) => ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        shrinkWrap: true,
        children: [
          Center(
            child: Text(
              '${s('ingredients')} · ${_session.servings} ${s('servings')}'
                  .toLowerCase(),
              style: MorphText.label(color: MorphColors.inkFaint),
            ),
          ),
          const SizedBox(height: 10),
          for (final ing in widget.recipe.ingredients)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      Quantity(ing.qty * factor, ing.unit).display,
                      style: MorphText.mono.copyWith(
                          fontSize: 12, color: MorphColors.terracotta),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      state.corpus.dictionary
                              .byId(ing.ingredientId)
                              ?.name
                              .of(lang) ??
                          ing.ingredientId,
                      style: MorphText.mono.copyWith(
                          fontSize: 12.5, color: MorphColors.cream),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _servingsScaler(S s) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: MorphColors.nightCard),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _scaleButton(Icons.remove,
              () => _session.setServings(_session.servings - 1)),
          Text('${_session.servings}',
              style:
                  MorphText.mono.copyWith(color: MorphColors.cream)),
          _scaleButton(Icons.add,
              () => _session.setServings(_session.servings + 1)),
        ],
      ),
    );
  }

  Widget _scaleButton(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 16, color: MorphColors.inkFaint),
        ),
      );

  Widget _timerBar(int remaining, S s) {
    final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');
    final running = _session.isTimerRunning;
    final paused = _session.isTimerPaused;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: MorphColors.nightCard,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Text('$minutes:$seconds',
              style: MorphText.mono.copyWith(
                  fontSize: 26,
                  color: remaining == 0
                      ? MorphColors.coral
                      : MorphColors.cream)),
          const Spacer(),
          if (remaining == 0)
            Text(s('timerDone'),
                style: MorphText.hand
                    .copyWith(fontSize: 18, color: MorphColors.coral))
          else
            TextButton(
              onPressed: running
                  ? _session.pauseTimer
                  : (paused ? _session.resumeTimer : _session.startTimer),
              child: Text(
                (running
                        ? s('pause')
                        : paused
                            ? s('resume')
                            : s('startTimer'))
                    .toLowerCase(),
                style: MorphText.label(color: MorphColors.teal),
              ),
            ),
        ],
      ),
    );
  }

  Widget _navBar(S s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          IconButton(
            onPressed:
                _session.stepIndex > 0 ? _session.previousStep : null,
            icon: const Icon(Icons.arrow_back, color: MorphColors.cream),
          ),
          const Spacer(),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: MorphColors.terracotta,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            ),
            onPressed: _session.isLastStep
                ? _session.complete
                : _session.nextStep,
            child: Text(
              (_session.isLastStep ? s('finishCooking') : s('next'))
                  .toLowerCase(),
              style: MorphText.label(color: MorphColors.cream),
            ),
          ),
        ],
      ),
    );
  }

  Widget _completion(AppState state, S s) {
    return Scaffold(
      backgroundColor: MorphColors.night,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('&', style: MorphText.hand.copyWith(
                    fontSize: 60, color: MorphColors.terracotta)),
                const SizedBox(height: 12),
                Text(s('cookedIt'),
                    textAlign: TextAlign.center,
                    style: MorphText.display.copyWith(
                        fontSize: 30, color: MorphColors.cream)),
                const SizedBox(height: 8),
                Text(s('cookAgainNote'),
                    style: MorphText.label(color: MorphColors.inkFaint)),
                const SizedBox(height: 32),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: MorphColors.terracotta,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                  ),
                  onPressed: () async {
                    await state.logCooked(widget.recipe.id);
                    if (!mounted) return;
                    // ignore: use_build_context_synchronously
                    Navigator.of(context).pop();
                  },
                  child: Text(s('done').toLowerCase(),
                      style: MorphText.label(color: MorphColors.cream)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on CookSessionController {
  bool quickTapHintVisible(AppState state) =>
      state.profile.quickNextTapEnabled && stepIndex == 0;
}
