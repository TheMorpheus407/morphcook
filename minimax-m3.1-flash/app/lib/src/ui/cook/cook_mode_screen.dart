import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/buttons.dart';
import '../../l10n/strings.dart';
import '../../models/recipe.dart';
import '../../state/app_state.dart';
import '../../state/history_controller.dart';
import '../../domain/cook_mode_controller.dart';

/// Cook mode — a dark, full-bleed, hands-busy-friendly recipe view.
class CookModeScreen extends StatefulWidget {
  const CookModeScreen({required this.recipeId, super.key});

  final String recipeId;

  @override
  State<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends State<CookModeScreen>
    with SingleTickerProviderStateMixin {
  OneHandedCookModeController? _controller;
  StreamSubscription<CookTimerAlert>? _alertSubscription;

  /// The flash overlay controller — drives the accessibility flash when a
  /// timer finishes.
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  bool _flashVisible = false;
  Color _flashColor = MC.coral;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  Future<void> _prepare() async {
    final state = context.read<AppState>();
    final recipe = state.corpus.recipe(widget.recipeId);
    if (recipe == null) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }

    final store = state.store;
    final saved = OneHandedCookModeController.restore(store, recipe.id);

    final controller = OneHandedCookModeController(
      recipe: recipe,
      store: store,
      initialServings: (saved?['servings'] as num?)?.toInt(),
      initialStep: (saved?['step'] as num?)?.toInt() ?? 0,
    );
    controller.quickNextTapEnabled = state.profile.profile.quickNextTapEnabled;

    _alertSubscription = controller.alerts.listen((alert) {
      if (!mounted) return;
      _triggerFlash();
    });

    setState(() => _controller = controller);
  }

  void _triggerFlash() {
    final state = context.read<AppState>();
    final reduce = MotionScope.reduceOf(context);
    final enabled = state.profile.profile.visualAlertEnabled;

    _flashColor = _flashColor == MC.coral ? MC.teal : MC.coral;

    if (!enabled) {
      // The setting is off — a plain haptic is all the user gets.
      HapticFeedback.heavyImpact();
      return;
    }

    HapticFeedback.heavyImpact();

    if (reduce) {
      // Reduced motion: a steady banner instead of a flashing screen.
      setState(() => _flashVisible = true);
      _flashTimer?.cancel();
      _flashTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _flashVisible = false);
      });
      return;
    }

    setState(() => _flashVisible = true);
    _flash.repeat(reverse: true);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      _flash.stop();
      setState(() => _flashVisible = false);
    });
  }

  @override
  void dispose() {
    _alertSubscription?.cancel();
    _flashTimer?.cancel();
    _flash.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final controller = _controller;

    if (controller == null) {
      return const Scaffold(
        backgroundColor: MC.ink,
        body: Center(
          child: CircularProgressIndicator(color: MC.card),
        ),
      );
    }

    final recipe = controller.recipe;
    final finished = controller.isLastStep && controller.timerRemaining == 0;

    return Scaffold(
      backgroundColor: const Color(0xFF221F1B),
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: _InkBackground(recipe: recipe)),
          SafeArea(
            child: Column(
              children: <Widget>[
                _CookHeader(
                  controller: controller,
                  strings: strings,
                  onExit: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: _StepPane(
                    controller: controller,
                    strings: strings,
                    onQuickTap: controller.handleQuickTap,
                  ),
                ),
                _CookFooter(
                  controller: controller,
                  strings: strings,
                  onFinish: () => _finish(context, recipe),
                  finished: finished,
                ),
              ],
            ),
          ),
          if (_flashVisible)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _flash,
                  builder: (context, _) {
                    final opacity = _flash.isAnimating
                        ? 0.30 + (0.18 * _flash.value)
                        : 0.30;
                    return ColoredBox(
                      color: _flashColor.withValues(alpha: opacity),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _finish(BuildContext context, Recipe recipe) async {
    HapticFeedback.mediumImpact();
    context.read<HistoryController>().record(
          recipe.id,
          servings: _controller?.servings ?? recipe.servings,
        );
    OneHandedCookModeController.clear(context.read<AppState>().store);
    if (!context.mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => _CompletionScreen(recipe: recipe)),
    );
  }
}

/// A soft, warm wash behind the dark cook mode.
class _InkBackground extends StatelessWidget {
  const _InkBackground({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final color = _parse(recipe.stripeColor);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          radius: 1.4,
          colors: <Color>[
            Color.lerp(const Color(0xFF221F1B), color, 0.16)!,
            const Color(0xFF221F1B),
          ],
          stops: const <double>[0.0, 1.0],
        ),
      ),
    );
  }

  Color _parse(String value) {
    final hex = value.replaceFirst('#', '');
    if (hex.length != 6) return MC.coral;
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? MC.coral : Color(0xFF000000 | parsed);
  }
}

class _CookHeader extends StatelessWidget {
  const _CookHeader({
    required this.controller,
    required this.strings,
    required this.onExit,
  });

  final OneHandedCookModeController controller;
  final Strings strings;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onExit,
            icon: const Icon(Icons.close_rounded),
            color: MC.card,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  controller.recipe.title.resolve(strings.lang),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Type.title(size: 16, color: MC.card),
                ),
                Text(
                  '${strings.cookStep} ${controller.currentStep + 1} '
                  '${strings.cookOf} ${controller.stepCount}',
                  style: Type.label(size: 9, color: MC.inkGhost),
                ),
              ],
            ),
          ),
          _ServingScaler(controller: controller, strings: strings),
        ],
      ),
    );
  }
}

class _ServingScaler extends StatelessWidget {
  const _ServingScaler({required this.controller, required this.strings});

  final OneHandedCookModeController controller;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: MC.inkGhost.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _ScalerButton(
            icon: Icons.remove_rounded,
            onTap: () => controller.scaleServings(-1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${controller.servings}',
                  style: Type.mono(size: 14, color: MC.card),
                ),
                Text(
                  strings.cookServings,
                  style: Type.label(size: 7.5, color: MC.inkGhost),
                ),
              ],
            ),
          ),
          _ScalerButton(
            icon: Icons.add_rounded,
            onTap: () => controller.scaleServings(1),
          ),
        ],
      ),
    );
  }
}

class _ScalerButton extends StatelessWidget {
  const _ScalerButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Icon(icon, size: 16, color: MC.card),
      ),
    );
  }
}

/// The step content. A single tap advances when quick-tap is enabled.
class _StepPane extends StatelessWidget {
  const _StepPane({
    required this.controller,
    required this.strings,
    required this.onQuickTap,
  });

  final OneHandedCookModeController controller;
  final Strings strings;
  final bool Function() onQuickTap;

  @override
  Widget build(BuildContext context) {
    final step = controller.step;
    if (step == null) return const SizedBox.shrink();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!controller.quickNextTapEnabled) return;
        final advanced = onQuickTap();
        if (advanced) HapticFeedback.selectionClick();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 26, 26, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${controller.currentStep + 1}',
              style: Type.display(size: 54, color: MC.card.withValues(alpha: 0.22)),
            ),
            const SizedBox(height: 10),
            Text(
              step.instruction.resolve(strings.lang),
              style: Type.body(size: 21, color: MC.card).copyWith(height: 1.45),
            ),
            if (controller.hasTimer) ...<Widget>[
              const SizedBox(height: 26),
              _TimerDial(controller: controller, strings: strings),
            ],
          ],
        ),
      ),
    );
  }
}

/// The circular timer.
class _TimerDial extends StatelessWidget {
  const _TimerDial({required this.controller, required this.strings});

  final OneHandedCookModeController controller;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final total = controller.timerTotal;
    final remaining = controller.timerRemaining;
    final fraction = total == 0 ? 0.0 : remaining / total;
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;

    return Column(
      children: <Widget>[
        SizedBox(
          width: 168,
          height: 168,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: fraction,
                  strokeWidth: 3,
                  backgroundColor: MC.inkGhost.withValues(alpha: 0.22),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    controller.timerRunning ? MC.coral : MC.inkGhost,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '$minutes:${seconds.toString().padLeft(2, '0')}',
                    style: Type.monoLarge(size: 34, color: MC.card),
                  ),
                  Text(
                    controller.timerRunning
                        ? strings.cookPause
                        : (remaining == 0
                            ? strings.cookTimerFinished
                            : strings.cookStartTimer),
                    style: Type.label(size: 8.5, color: MC.inkGhost),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            GhostButton(
              label: controller.timerRunning
                  ? strings.cookPause
                  : (remaining < total && remaining > 0
                      ? strings.cookResume
                      : strings.cookStartTimer),
              icon: controller.timerRunning
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              accent: MC.card,
              onPressed: () {
                if (controller.timerRunning) {
                  controller.pauseTimer();
                } else if (controller.timerRemaining > 0 &&
                    controller.timerRemaining < controller.timerTotal) {
                  controller.resumeTimer();
                } else {
                  controller.startTimer();
                }
              },
            ),
            const SizedBox(width: 10),
            GhostButton(
              label: strings.genericCancel,
              icon: Icons.restart_alt_rounded,
              accent: MC.inkGhost,
              onPressed: controller.resetTimer,
            ),
          ],
        ),
      ],
    );
  }
}

class _CookFooter extends StatelessWidget {
  const _CookFooter({
    required this.controller,
    required this.strings,
    required this.onFinish,
    required this.finished,
  });

  final OneHandedCookModeController controller;
  final Strings strings;
  final VoidCallback onFinish;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
      child: Row(
        children: <Widget>[
          GhostButton(
            label: strings.cookPrevious,
            icon: Icons.arrow_back_rounded,
            accent: MC.inkGhost,
            onPressed: controller.currentStep == 0
                ? null
                : () => controller.previous(),
          ),
          const Spacer(),
          if (controller.isLastStep)
            PaperButton(
              label: strings.cookDone,
              icon: Icons.check_rounded,
              accent: MC.coral,
              onPressed: onFinish,
            )
          else
            PaperButton(
              label: strings.cookNext,
              icon: Icons.arrow_forward_rounded,
              accent: MC.coral,
              onPressed: () => controller.next(),
            ),
        ],
      ),
    );
  }
}

/// The end-of-cook screen.
class _CompletionScreen extends StatelessWidget {
  const _CompletionScreen({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final strings = context.read<AppState>().strings;
    return Scaffold(
      backgroundColor: const Color(0xFF221F1B),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('✳', style: Type.scriptLarge(size: 56, color: MC.coral)),
                const SizedBox(height: 10),
                Text(
                  strings.cookFinishedTitle,
                  style: Type.display(size: 34, color: MC.card),
                ),
                const SizedBox(height: 6),
                Text(
                  strings.cookFinishedBody,
                  style: Type.script(size: 21, color: MC.inkGhost),
                ),
                const SizedBox(height: 28),
                PaperButton(
                  label: strings.cookDone,
                  accent: MC.coral,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
