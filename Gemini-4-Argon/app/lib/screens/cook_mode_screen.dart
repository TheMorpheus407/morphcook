import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dish.dart';
import '../models/history_entry.dart';
import '../models/recipe.dart';
import '../services/one_handed_cook_mode_controller.dart';
import '../state/app_state.dart';
import '../theme/nostalgic_theme.dart';
import '../widgets/nostalgic_widgets.dart';

class CookModeScreen extends StatefulWidget {
  final Recipe recipe;
  final Dish? dish;
  final int initialServings;
  final ActiveCookSession? restoredSession;

  const CookModeScreen({
    super.key,
    required this.recipe,
    this.dish,
    this.initialServings = 2,
    this.restoredSession,
  });

  @override
  State<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends State<CookModeScreen> {
  late int _stepIndex;
  late int _servings;
  int? _remainingSeconds;
  bool _timerRunning = false;
  bool _isCompleted = false;
  Set<String> _checkedIngredientIds = {};

  Timer? _countdownTimer;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    final restored = widget.restoredSession;
    if (restored != null && restored.recipeId == widget.recipe.id) {
      _stepIndex = restored.currentStepIndex.clamp(
        0,
        widget.recipe.steps.length - 1,
      );
      _servings = restored.scaledServings;
      _remainingSeconds = restored.remainingTimerSeconds ??
          widget.recipe.steps[_stepIndex].timerSeconds;
      _checkedIngredientIds = Set<String>.from(restored.checkedIngredientIds);
    } else {
      _stepIndex = 0;
      _servings = widget.initialServings;
      _remainingSeconds = widget.recipe.steps.isNotEmpty
          ? widget.recipe.steps.first.timerSeconds
          : null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _persistProgress());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  RecipeStep get _currentStep => widget.recipe.steps[_stepIndex];

  void _persistProgress({bool isPaused = false}) {
    if (!mounted || _isCompleted) return;
    final appState = context.read<MorphCookAppState>();
    appState.saveCookSession(
      ActiveCookSession(
        recipeId: widget.recipe.id,
        currentStepIndex: _stepIndex,
        scaledServings: _servings,
        remainingTimerSeconds: _remainingSeconds,
        isPaused: isPaused || !_timerRunning,
        updatedAt: appState.now,
        checkedIngredientIds: _checkedIngredientIds,
      ),
    );
  }

  void _startOrPauseTimer() {
    final controller = context.read<MorphCookAppState>().cookModeController;
    controller.dismissVisualAlert();
    _flashTimer?.cancel();

    if (_timerRunning) {
      _countdownTimer?.cancel();
      setState(() => _timerRunning = false);
      _persistProgress(isPaused: true);
      return;
    }

    _remainingSeconds ??= _currentStep.timerSeconds ?? 180;
    if (_remainingSeconds! <= 0) {
      _remainingSeconds = _currentStep.timerSeconds ?? 180;
    }

    setState(() => _timerRunning = true);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if ((_remainingSeconds ?? 0) > 1) {
        setState(() => _remainingSeconds = _remainingSeconds! - 1);
      } else {
        timer.cancel();
        _onTimerFinished();
      }
    });
  }

  void _onTimerFinished() {
    final appState = context.read<MorphCookAppState>();
    final controller = appState.cookModeController;
    final sysReduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    setState(() {
      _remainingSeconds = 0;
      _timerRunning = false;
    });

    controller.triggerTimerVisualAlert(systemReduceMotion: sysReduce);
    _flashTimer?.cancel();
    if (controller.visualAlertEnabled &&
        !controller.effectiveReduceMotion(systemReduceMotion: sysReduce)) {
      _flashTimer = Timer.periodic(const Duration(milliseconds: 450), (t) {
        if (!mounted || !controller.isVisualAlertActive) {
          t.cancel();
          return;
        }
        controller.stepFlashPhase(systemReduceMotion: sysReduce);
        setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  void _resetStepTimer() {
    _countdownTimer?.cancel();
    _flashTimer?.cancel();
    context.read<MorphCookAppState>().cookModeController.dismissVisualAlert();
    setState(() {
      _timerRunning = false;
      _remainingSeconds = _currentStep.timerSeconds;
    });
    _persistProgress();
  }

  void _goToStep(int newIndex) {
    _countdownTimer?.cancel();
    _flashTimer?.cancel();
    context.read<MorphCookAppState>().cookModeController.dismissVisualAlert();

    if (newIndex >= widget.recipe.steps.length) {
      setState(() {
        _isCompleted = true;
        _timerRunning = false;
      });
      return;
    }

    final clamped = newIndex.clamp(0, widget.recipe.steps.length - 1);
    setState(() {
      _stepIndex = clamped;
      _timerRunning = false;
      _remainingSeconds = widget.recipe.steps[clamped].timerSeconds;
    });
    _persistProgress();
  }

  String _formatSeconds(int totalSeconds) {
    final mins = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MorphCookAppState>();
    final controller = appState.cookModeController;
    final lang = appState.lang;
    final isDe = lang == 'de';
    final sysReduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final reduceMotion =
        controller.effectiveReduceMotion(systemReduceMotion: sysReduce);

    final isFlashing = controller.isVisualAlertActive;
    final alertColor = controller.currentAlertColor;

    return Scaffold(
      backgroundColor: NostalgicPalette.cookDarkBg,
      body: AnimatedContainer(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: isFlashing
              ? alertColor.withValues(alpha: 0.24)
              : NostalgicPalette.cookDarkBg,
          border: isFlashing
              ? Border.all(color: alertColor, width: 6)
              : null,
        ),
        child: SafeArea(
          child: _isCompleted
              ? _buildCompletionScreen(appState, lang)
              : _buildStepView(
                  context,
                  appState,
                  controller,
                  lang,
                  isDe,
                  reduceMotion,
                ),
        ),
      ),
    );
  }

  Widget _buildStepView(
    BuildContext context,
    MorphCookAppState appState,
    OneHandedCookModeController controller,
    String lang,
    bool isDe,
    bool reduceMotion,
  ) {
    final totalSteps = widget.recipe.steps.length;
    final step = _currentStep;
    final scaleFactor = _servings / widget.recipe.servings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top bar: Pause & Exit, Title, Ingredients Drawer & Accessibility Quick-Tap toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              OutlinedButton.icon(
                key: const ValueKey('cook_mode_pause_exit_btn'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: NostalgicPalette.cookDarkInk,
                  side: const BorderSide(color: NostalgicPalette.cookDarkMuted),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.pause, size: 15),
                label: Text(
                  isDe ? 'pausieren' : 'pause',
                  style: NostalgicTheme.mono(
                    fontSize: 11,
                    color: NostalgicPalette.cookDarkInk,
                  ),
                ),
                onPressed: () {
                  _countdownTimer?.cancel();
                  _persistProgress(isPaused: true);
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.recipe.title.resolve(lang),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NostalgicTheme.serifDisplay(
                    fontSize: 17,
                    color: NostalgicPalette.cookDarkInk,
                  ),
                ),
              ),
              IconButton(
                tooltip: isDe ? 'Zutaten & Portionen' : 'Ingredients & Servings',
                icon: const Icon(
                  Icons.checklist_rtl,
                  color: NostalgicPalette.cookDarkInk,
                ),
                onPressed: () =>
                    _showIngredientsSheet(context, lang, scaleFactor),
              ),
            ],
          ),
        ),

        // Step Progress Indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: List.generate(totalSteps, (idx) {
              final active = idx <= _stepIndex;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: active
                        ? NostalgicPalette.terracotta
                        : NostalgicPalette.cookDarkCard,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ),

        // Visual Flash Alert Banner (Coral/Teal) when Timer Completes
        if (controller.isVisualAlertActive)
          Container(
            key: const ValueKey('visual_flash_alert_banner'),
            margin: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: controller.currentAlertColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.notifications_active,
                  color: NostalgicPalette.cookDarkBg,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isDe
                        ? 'TIMER ABGELAUFEN — Schritt 0${step.stepNumber} bereit!'
                        : 'TIMER COMPLETE — Step 0${step.stepNumber} ready!',
                    style: NostalgicTheme.mono(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: NostalgicPalette.cookDarkBg,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _flashTimer?.cancel();
                    controller.dismissVisualAlert();
                    setState(() {});
                  },
                  child: Text(
                    isDe ? 'OK' : 'DISMISS',
                    style: NostalgicTheme.mono(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: NostalgicPalette.cookDarkBg,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Servings & Quick-Tap Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
          child: Row(
            children: [
              Text(
                '${isDe ? "schritt" : "step"} 0${_stepIndex + 1} / 0$totalSteps',
                style: NostalgicTheme.mono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: NostalgicPalette.saffron,
                ),
              ),
              const Spacer(),
              // Servings scaler in Cook Mode
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.remove_circle_outline,
                  size: 18,
                  color: NostalgicPalette.cookDarkMuted,
                ),
                onPressed: _servings > 1
                    ? () {
                        setState(() => _servings -= 1);
                        _persistProgress();
                      }
                    : null,
              ),
              Text(
                '$_servings ${isDe ? "Port." : "serv"}',
                style: NostalgicTheme.mono(
                  fontSize: 11.5,
                  color: NostalgicPalette.cookDarkInk,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.add_circle_outline,
                  size: 18,
                  color: NostalgicPalette.cookDarkMuted,
                ),
                onPressed: _servings < 12
                    ? () {
                        setState(() => _servings += 1);
                        _persistProgress();
                      }
                    : null,
              ),
              const SizedBox(width: 6),
              FilterChip(
                key: const ValueKey('cook_mode_quick_tap_chip'),
                selected: controller.quickNextTapEnabled,
                backgroundColor: NostalgicPalette.cookDarkSurface,
                selectedColor: NostalgicPalette.terracotta,
                label: Text(
                  isDe ? '1-Hand-Tipp' : 'Quick-Tap',
                  style: NostalgicTheme.mono(
                    fontSize: 10.5,
                    color: NostalgicPalette.cookDarkInk,
                  ),
                ),
                onSelected: (val) {
                  appState.updateProfile(
                    appState.profile.copyWith(quickNextTapEnabled: val),
                  );
                },
              ),
            ],
          ),
        ),

        // Main Step Content Card (supports One-Handed Quick-Tap gesture with 300ms debounce)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
            child: GestureDetector(
              key: const ValueKey('cook_mode_step_content_area'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                controller.handleStepContentTap(
                  () => _goToStep(_stepIndex + 1),
                );
              },
              child: AnimatedSwitcher(
                duration: controller.stepTransitionDuration(
                  systemReduceMotion: reduceMotion,
                ),
                child: Container(
                  key: ValueKey('cook_step_${step.stepNumber}'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: NostalgicPalette.cookDarkSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: NostalgicPalette.cookDarkMuted.withValues(alpha: 0.35),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title.resolve(lang),
                          style: NostalgicTheme.serifDisplay(
                            fontSize: 26,
                            color: NostalgicPalette.cookDarkInk,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          step.instruction.resolve(lang),
                          style: NostalgicTheme.serifBody(
                            fontSize: 19,
                            color: NostalgicPalette.cookDarkInk,
                            height: 1.55,
                          ),
                        ),
                        if (step.tip != null) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: NostalgicPalette.cookDarkCard,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '✎ ${step.tip!.resolve(lang)}',
                              style: NostalgicTheme.handwritten(
                                fontSize: 20,
                                color: NostalgicPalette.saffron,
                              ),
                            ),
                          ),
                        ],
                        if (controller.quickNextTapEnabled) ...[
                          const SizedBox(height: 18),
                          Text(
                            isDe
                                ? '✦ Einhand-Modus aktiv: Tippe auf diese Karte für den nächsten Schritt (300ms Entprellung)'
                                : '✦ One-handed mode active: Tap anywhere on this card to advance (300ms debounce)',
                            style: NostalgicTheme.mono(
                              fontSize: 10.5,
                              color: NostalgicPalette.cookDarkMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Per-Step Timer Card
        if (_remainingSeconds != null || step.timerSeconds != null)
          Container(
            margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: NostalgicPalette.cookDarkCard,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: NostalgicPalette.saffron.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  color: NostalgicPalette.saffron,
                ),
                const SizedBox(width: 10),
                Text(
                  _formatSeconds(_remainingSeconds ?? step.timerSeconds ?? 0),
                  key: const ValueKey('cook_mode_timer_display'),
                  style: NostalgicTheme.mono(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: NostalgicPalette.cookDarkInk,
                  ),
                ),
                const Spacer(),
                FilledButton.tonal(
                  key: const ValueKey('cook_mode_timer_toggle_btn'),
                  onPressed: _startOrPauseTimer,
                  child: Text(
                    _timerRunning
                        ? (isDe ? 'Pause' : 'Pause')
                        : (isDe ? 'Start' : 'Start'),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  key: const ValueKey('cook_mode_timer_reset_btn'),
                  tooltip: isDe ? 'Timer zurücksetzen' : 'Reset timer',
                  icon: const Icon(
                    Icons.refresh,
                    color: NostalgicPalette.cookDarkMuted,
                  ),
                  onPressed: _resetStepTimer,
                ),
                IconButton(
                  key: const ValueKey('cook_mode_timer_complete_now_btn'),
                  tooltip: isDe
                      ? 'Timer-Alarm testen'
                      : 'Trigger timer completion alert',
                  icon: const Icon(
                    Icons.flash_on,
                    color: NostalgicPalette.coralAlert,
                  ),
                  onPressed: _onTimerFinished,
                ),
              ],
            ),
          ),

        // Prev / Next Bottom Navigation Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('cook_mode_prev_btn'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NostalgicPalette.cookDarkInk,
                    side: const BorderSide(color: NostalgicPalette.cookDarkMuted),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed:
                      _stepIndex > 0 ? () => _goToStep(_stepIndex - 1) : null,
                  child: Text(
                    isDe ? '← zurück' : '← prev step',
                    style: NostalgicTheme.mono(
                      fontSize: 12.5,
                      color: _stepIndex > 0
                          ? NostalgicPalette.cookDarkInk
                          : NostalgicPalette.cookDarkMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  key: const ValueKey('cook_mode_next_btn'),
                  style: FilledButton.styleFrom(
                    backgroundColor: NostalgicPalette.terracotta,
                    foregroundColor: NostalgicPalette.cardStock,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => _goToStep(_stepIndex + 1),
                  child: Text(
                    _stepIndex < totalSteps - 1
                        ? (isDe ? 'nächster schritt →' : 'next step →')
                        : (isDe ? 'gericht fertigstellen ✦' : 'finish cooking ✦'),
                    style: NostalgicTheme.mono(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: NostalgicPalette.cardStock,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionScreen(MorphCookAppState appState, String lang) {
    final isDe = lang == 'de';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: NostalgicPalette.cookDarkSurface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: NostalgicPalette.saffron, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_outlined,
                size: 48,
                color: NostalgicPalette.saffron,
              ),
              const SizedBox(height: 12),
              Text(
                isDe ? 'Guten Appetit!' : 'Bon Appétit!',
                style: NostalgicTheme.serifDisplay(
                  fontSize: 30,
                  color: NostalgicPalette.cookDarkInk,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.recipe.title.resolve(lang),
                textAlign: TextAlign.center,
                style: NostalgicTheme.handwritten(
                  fontSize: 22,
                  color: NostalgicPalette.saffron,
                ),
              ),
              const SizedBox(height: 16),
              const DashedRule(color: NostalgicPalette.cookDarkMuted),
              const SizedBox(height: 16),
              Text(
                isDe
                    ? '$_servings Portionen zubereitet — wird in deinem Koch-Tagebuch vermerkt.'
                    : 'Prepared $_servings servings — ready to stamp into your cooking history.',
                textAlign: TextAlign.center,
                style: NostalgicTheme.serifBody(
                  fontSize: 15,
                  color: NostalgicPalette.cookDarkMuted,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('cook_mode_complete_done_btn'),
                  style: FilledButton.styleFrom(
                    backgroundColor: NostalgicPalette.terracotta,
                    foregroundColor: NostalgicPalette.cardStock,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    await appState.recordCookedRecipe(
                      widget.recipe,
                      servingsCooked: _servings,
                    );
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(
                    isDe
                        ? 'ins koch-tagebuch eintragen ✦'
                        : 'log to cooking history & close ✦',
                    style: NostalgicTheme.mono(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: NostalgicPalette.cardStock,
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

  void _showIngredientsSheet(
    BuildContext context,
    String lang,
    double scaleFactor,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: NostalgicPalette.cookDarkSurface,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lang == 'de'
                          ? 'zutaten ($_servings portionen)'
                          : 'ingredients ($_servings servings)',
                      style: NostalgicTheme.mono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: NostalgicPalette.saffron,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: widget.recipe.ingredients.map((ing) {
                          final checked =
                              _checkedIngredientIds.contains(ing.id);
                          return CheckboxListTile(
                            value: checked,
                            activeColor: NostalgicPalette.terracotta,
                            title: Text(
                              '${ing.formattedAmount(scaleFactor)} ${ing.unit}  ${ing.name.resolve(lang)}',
                              style: NostalgicTheme.serifBody(
                                fontSize: 15,
                                color: NostalgicPalette.cookDarkInk,
                              ),
                            ),
                            onChanged: (v) {
                              setSheetState(() {
                                if (v == true) {
                                  _checkedIngredientIds.add(ing.id);
                                } else {
                                  _checkedIngredientIds.remove(ing.id);
                                }
                              });
                              _persistProgress();
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
