import 'package:flutter/material.dart' hide Typography;
import 'package:provider/provider.dart';

import '../../core/i18n/strings.dart';
import '../../core/model/recipe.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../core/units.dart';
import '../../state/app_state.dart';
import '../../state/cook_controller.dart';

/// Cook mode: dark, full-bleed, one step at a time. Per-step timer with
/// pause/resume (progress persisted across exits), servings scaler, prev/next,
/// a tappable progress rail, and a coral/teal flash alert when a timer
/// completes (for deaf / hard-of-hearing users). The opt-in quick-tap
/// gesture advances to the next step on a single tap, debounced by 300 ms.
class CookScreen extends StatefulWidget {
  final Recipe recipe;

  const CookScreen({super.key, required this.recipe});

  @override
  State<CookScreen> createState() => _CookScreenState();
}

class _CookScreenState extends State<CookScreen> with SingleTickerProviderStateMixin {
  late final OneHandedCookModeController _controller;
  late final AnimationController _flash;
  bool _showIngredients = false;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    final profile = appState.profile;
    _controller = OneHandedCookModeController(
      recipe: widget.recipe,
      reduceMotion: profile.reduceMotion ?? MediaQuery.of(context).disableAnimations,
      visualAlertEnabled: profile.visualAlertEnabled,
      quickNextTapEnabled: profile.quickNextTapEnabled,
      onFinished: () => context.read<AppState>().addToHistory(widget.recipe.id),
    );
    _controller.flash.addListener(_onFlash);
    _flash = AnimationController(vsync: this);
    _flash.addListener(() => setState(() {}));
  }

  void _onFlash() {
    if (_controller.flash.value > 0 && !_flash.isAnimating) {
      _flash.duration =
          _controller.reduceMotion ? Motion.timerFlashReduced : Motion.timerFlash;
      _flash.forward(from: 0).whenComplete(() {
        if (mounted) {
          _controller.clearFlash();
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.flash.removeListener(_onFlash);
    _flash.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final s = Strings(appState.profile.lang);
    final lang = appState.profile.lang;
    final dish = appState.corpus.dishById(widget.recipe.dishId);
    final dishName = dish?.name.resolve(lang) ?? widget.recipe.title.resolve(lang);

    final flashOn = _controller.flash.value > 0 && _flash.isAnimating;
    final toggles =
        _controller.reduceMotion ? Motion.timerFlashTogglesReduced : Motion.timerFlashToggles;
    final flashColor = flashOn
        ? (((_flash.value * toggles).floor() % 2 == 0) ? Palette.coral : Palette.teal)
        : Colors.transparent;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _controller.exit();
      },
      child: Theme(
        data: AppTheme.cook,
        child: Scaffold(
          backgroundColor: Palette.cookBg,
          body: Stack(
            children: [
              SafeArea(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => _controller.isFinished
                      ? _DoneView(
                          s: s,
                          dishName: dishName,
                          onDone: () => Navigator.of(context).pop(),
                        )
                      : _CookingView(
                          s: s,
                          lang: lang,
                          dishName: dishName,
                          controller: _controller,
                          showIngredients: _showIngredients,
                          onToggleIngredients: () =>
                              setState(() => _showIngredients = !_showIngredients),
                          onExit: () {
                            _controller.exit();
                            Navigator.of(context).pop();
                          },
                        ),
                ),
              ),
              // Visual timer alert: full-bleed coral/teal flash, alternating.
              if (flashOn)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 90),
                      color: flashColor.withValues(alpha: 0.32),
                    ),
                  ),
                ),
              if (flashOn)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 120,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: Palette.cookBg.withValues(alpha: 0.85),
                        child: Text(
                          '⏱ ${s.cookTimerDone}'.toUpperCase(),
                          style: Typography.mono(11, weight: FontWeight.w700,
                              letterSpacing: 2, color: Palette.mustard),
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

/// The cooking view: header, progress rail, step content, timer, controls.
class _CookingView extends StatelessWidget {
  final Strings s;
  final String lang;
  final String dishName;
  final OneHandedCookModeController controller;
  final bool showIngredients;
  final VoidCallback onToggleIngredients;
  final VoidCallback onExit;

  const _CookingView({
    required this.s,
    required this.lang,
    required this.dishName,
    required this.controller,
    required this.showIngredients,
    required this.onToggleIngredients,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final step = controller.currentStep;

    return Column(
      children: [
        // header: exit, dish name, servings scaler
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              GestureDetector(
                onTap: onExit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Text('← ${s.cookExit}', style: Typography.mono(10, letterSpacing: 1.2, color: Palette.cookPaper.withValues(alpha: 0.7))),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    dishName,
                    style: Typography.display(20, color: Palette.cookPaper),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              _ServingsScaler(s: s, controller: controller),
            ],
          ),
        ),
        // progress rail: one tappable segment per step
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              for (var i = 0; i < controller.stepCount; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => controller.goTo(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      color: i < controller.step
                          ? Palette.teal
                          : i == controller.step
                              ? Palette.coral
                              : Palette.cookPaper.withValues(alpha: 0.2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              Text(
                s.cookStepOf
                    .replaceAll('{i}', (controller.step + 1).toString())
                    .replaceAll('{n}', controller.stepCount.toString())
                    .toUpperCase(),
                style: Typography.mono(10, weight: FontWeight.w700, letterSpacing: 2, color: Palette.cookPaper.withValues(alpha: 0.6)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onToggleIngredients,
                child: Text(
                  s.dishIngredients.toUpperCase(),
                  style: Typography.mono(10, letterSpacing: 1.6,
                      color: showIngredients ? Palette.mustard : Palette.cookPaper.withValues(alpha: 0.6)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GestureDetector(
            // Quick-tap gesture (opt-in): single tap on the step content
            // advances to the next step, debounced by the controller.
            onTap: () => controller.quickTapAdvance(),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              children: [
                if (showIngredients) _ScaledIngredients(s: s, lang: lang, controller: controller),
                Text(
                  '0${controller.step + 1}',
                  style: Typography.mono(13, weight: FontWeight.w700, color: Palette.coral),
                ),
                const SizedBox(height: 8),
                Text(
                  step.text.resolve(lang),
                  style: Typography.display(24, color: Palette.cookPaper, height: 1.35),
                ),
                if (controller.hasTimer) ...[
                  const SizedBox(height: 24),
                  _TimerPanel(s: s, controller: controller),
                ],
                if (controller.quickNextTapEnabled) ...[
                  const SizedBox(height: 28),
                  Center(
                    child: Text(
                      s.cookQuickTapHint,
                      style: Typography.hand(19, color: Palette.cookPaper.withValues(alpha: 0.55)),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        // prev / next
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Row(
            children: [
              Expanded(
                child: _CookButton(
                  label: s.cookPrev.toUpperCase(),
                  icon: Icons.chevron_left,
                  enabled: controller.step > 0,
                  onTap: controller.previous,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _CookButton(
                  label: (controller.step == controller.stepCount - 1 ? s.cookDone : s.cookNext).toUpperCase(),
                  icon: controller.step == controller.stepCount - 1 ? Icons.check : Icons.chevron_right,
                  solid: true,
                  onTap: controller.next,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Servings scaler: − n +, scales the ingredient list live.
class _ServingsScaler extends StatelessWidget {
  final Strings s;
  final OneHandedCookModeController controller;

  const _ServingsScaler({required this.s, required this.controller});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepButton(Icons.remove, controller.servings > 1, () => controller.setServings(controller.servings - 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${controller.servings} ${s.cookServings.toLowerCase()}',
              style: Typography.mono(10.5, color: Palette.cookPaper.withValues(alpha: 0.8)),
            ),
          ),
          _stepButton(Icons.add, controller.servings < 99, () => controller.setServings(controller.servings + 1)),
        ],
      );

  Widget _stepButton(IconData icon, bool enabled, VoidCallback onTap) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border.all(color: Palette.cookPaper.withValues(alpha: enabled ? 0.7 : 0.25)),
          ),
          child: Icon(icon, size: 14, color: Palette.cookPaper.withValues(alpha: enabled ? 1 : 0.3)),
        ),
      );
}

/// The scaled ingredient list (mise en place), amounts follow the scaler.
class _ScaledIngredients extends StatelessWidget {
  final Strings s;
  final String lang;
  final OneHandedCookModeController controller;

  const _ScaledIngredients({required this.s, required this.lang, required this.controller});

  @override
  Widget build(BuildContext context) {
    final corpus = context.read<AppState>().corpus;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.cookPanel,
        border: Border.all(color: Palette.cookPaper.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.dishIngredients.toUpperCase(),
              style: Typography.mono(9.5, weight: FontWeight.w700, letterSpacing: 2, color: Palette.mustard)),
          const SizedBox(height: 8),
          for (final line in controller.scaledIngredients)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      corpus.ingredients.nameOf(line.ingredientId, lang) +
                          (line.note != null ? ' — ${line.note!.resolve(lang)}' : ''),
                      style: Typography.body(14, color: Palette.cookPaper.withValues(alpha: 0.85)),
                    ),
                  ),
                  Text(
                    Units.format(line.amount, line.unit),
                    style: Typography.mono(11, weight: FontWeight.w700, color: Palette.mustard),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Per-step timer panel: big countdown + start / pause / resume.
class _TimerPanel extends StatelessWidget {
  final Strings s;
  final OneHandedCookModeController controller;

  const _TimerPanel({required this.s, required this.controller});

  @override
  Widget build(BuildContext context) {
    final remaining = controller.remainingSeconds ?? (controller.stepTimerMinutes ?? 0) * 60;
    final m = remaining ~/ 60;
    final sec = remaining % 60;
    final label = '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';

    final String actionLabel;
    final VoidCallback? action;
    if (!controller.isRunning) {
      actionLabel = s.cookStartTimer;
      action = controller.startTimer;
    } else if (controller.isPaused) {
      actionLabel = s.cookResume;
      action = controller.resumeTimer;
    } else {
      actionLabel = s.cookPause;
      action = controller.pauseTimer;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: Palette.cookPanel,
        border: Border.all(color: Palette.cookPaper.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 38,
              fontWeight: FontWeight.w700,
              color: controller.isRunning && !controller.isPaused ? Palette.mustard : Palette.cookPaper,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          _CookButton(label: actionLabel.toUpperCase(), icon: Icons.timer_outlined, solid: true, onTap: action),
        ],
      ),
    );
  }
}

/// Completion screen: the dish is cooked — it lands in the history.
class _DoneView extends StatelessWidget {
  final Strings s;
  final String dishName;
  final VoidCallback onDone;

  const _DoneView({required this.s, required this.dishName, required this.onDone});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('⏱', style: TextStyle(fontSize: 30, color: Palette.mustard)),
              const SizedBox(height: 12),
              Text(s.cookDoneTitle, style: Typography.display(34, color: Palette.cookPaper)),
              const SizedBox(height: 10),
              Text(
                s.cookDoneBody.replaceAll('{dish}', dishName),
                style: Typography.body(16, italic: true, color: Palette.cookPaper.withValues(alpha: 0.75)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: _CookButton(
                  label: s.cookDone.toUpperCase(),
                  icon: Icons.check,
                  solid: true,
                  onTap: onDone,
                ),
              ),
            ],
          ),
        ),
      );
}

/// Cook-mode button: outlined paper on dark; solid = mustard with ink text.
class _CookButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool solid;
  final bool enabled;
  final VoidCallback? onTap;

  const _CookButton({
    required this.label,
    this.icon,
    this.solid = false,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg;
    final Color border;
    if (!enabled) {
      fg = Palette.cookPaper.withValues(alpha: 0.3);
      border = Palette.cookPaper.withValues(alpha: 0.2);
    } else if (solid) {
      fg = Palette.ink;
      border = Palette.mustard;
    } else {
      fg = Palette.cookPaper;
      border = Palette.cookPaper.withValues(alpha: 0.6);
    }
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
        decoration: BoxDecoration(
          color: solid ? Palette.mustard : Colors.transparent,
          border: Border.all(color: border, width: 1.3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 8),
            ],
            Text(label,
                style: Typography.mono(11, weight: FontWeight.w700, letterSpacing: 1.8, color: fg)),
          ],
        ),
      ),
    );
  }
}
