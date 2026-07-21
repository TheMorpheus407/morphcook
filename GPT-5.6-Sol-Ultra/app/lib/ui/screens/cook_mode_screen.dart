import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/recipe.dart';
import '../../l10n/app_strings.dart';
import '../../services/cook_session_controller.dart';
import '../theme/morph_theme.dart';
import '../widgets/morph_components.dart';

class CookModeScreen extends StatefulWidget {
  const CookModeScreen({
    required this.recipe,
    required this.languageCode,
    required this.session,
    required this.oneHanded,
    required this.onCompleted,
    super.key,
  });

  final Recipe recipe;
  final String languageCode;
  final CookSessionController session;
  final OneHandedCookModeController oneHanded;
  final Future<void> Function(Recipe recipe, int servings) onCompleted;

  @override
  State<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends State<CookModeScreen> {
  var _finishing = false;

  @override
  void dispose() {
    widget.session.flush();
    widget.oneHanded.dispose();
    widget.session.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      await widget.onCompleted(widget.recipe, widget.session.servings.round());
      await widget.session.discard();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF111312),
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Color(0xFF111312),
      ),
      child: MorphStringsScope(
        languageCode: widget.languageCode,
        child: Theme(
          data: MorphTheme.cookMode,
          child: AnimatedBuilder(
            animation: Listenable.merge([widget.session, widget.oneHanded]),
            builder: (context, _) {
              final session = widget.session;
              return Scaffold(
                body: Stack(
                  fit: StackFit.expand,
                  children: [
                    SafeArea(
                      child: session.isComplete
                          ? _CompletionView(
                              recipe: widget.recipe,
                              language: widget.languageCode,
                              finishing: _finishing,
                              onFinish: _finish,
                            )
                          : _StepView(
                              recipe: widget.recipe,
                              language: widget.languageCode,
                              session: session,
                              oneHanded: widget.oneHanded,
                            ),
                    ),
                    if (session.visualAlert case final alert?)
                      _VisualTimerAlert(
                        alert: alert,
                        onDismiss: session.dismissVisualAlert,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StepView extends StatelessWidget {
  const _StepView({
    required this.recipe,
    required this.language,
    required this.session,
    required this.oneHanded,
  });

  final Recipe recipe;
  final String language;
  final CookSessionController session;
  final OneHandedCookModeController oneHanded;

  @override
  Widget build(BuildContext context) {
    final step = recipe.steps[session.currentStepIndex];
    final timer = session.timers[session.currentStepIndex];
    final strings = context.strings;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                tooltip: strings('common.close'),
                icon: const Icon(Icons.close_rounded),
              ),
              Expanded(
                child: Text(
                  recipe.name.resolve(language),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: session.isPaused ? session.resume : session.pause,
                tooltip: session.isPaused
                    ? strings('cook.resume')
                    : strings('cook.pause'),
                icon: Icon(
                  session.isPaused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                ),
              ),
            ],
          ),
        ),
        LinearProgressIndicator(
          value: (session.currentStepIndex + 1) / session.totalSteps,
          minHeight: 3,
          color: context.morph.coral,
          backgroundColor: context.morph.paperDeep,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: [
                    Text(
                      strings.format('cook.step', {
                        'current': session.currentStepIndex + 1,
                        'total': session.totalSteps,
                      }).toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.morph.teal,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Semantics(
                      button: oneHanded.quickNextTapEnabled,
                      hint: oneHanded.quickNextTapEnabled
                          ? strings('cook.tapNextHint')
                          : null,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: oneHanded.quickNextTapEnabled
                            ? oneHanded.onStepContentTap
                            : null,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 210),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: oneHanded.transitionDuration,
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(.025, 0),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  ),
                              child: Text(
                                step.text.resolve(language),
                                key: ValueKey(step.id),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineLarge
                                    ?.copyWith(height: 1.25),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (step.tip case final tip?) ...[
                      const SizedBox(height: 18),
                      Transform.rotate(
                        angle: -.018,
                        child: Text(
                          tip.resolve(language),
                          textAlign: TextAlign.center,
                          style: morphHandwriting(
                            context,
                            size: 25,
                            color: context.morph.mustard,
                          ),
                        ),
                      ),
                    ],
                    if (step.timerSeconds != null || timer != null) ...[
                      const SizedBox(height: 28),
                      _StepTimer(
                        stepIndex: session.currentStepIndex,
                        suggestedSeconds: step.timerSeconds,
                        timer: timer,
                        session: session,
                      ),
                    ],
                    const SizedBox(height: 28),
                    _ServingControl(session: session),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: session.canGoPrevious
                      ? session.previousStep
                      : null,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(strings('cook.previous')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: session.nextStep,
                  icon: Icon(
                    session.currentStepIndex == session.totalSteps - 1
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                  ),
                  label: Text(
                    session.currentStepIndex == session.totalSteps - 1
                        ? strings('cook.finish')
                        : strings('cook.next'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepTimer extends StatelessWidget {
  const _StepTimer({
    required this.stepIndex,
    required this.suggestedSeconds,
    required this.timer,
    required this.session,
  });

  final int stepIndex;
  final int? suggestedSeconds;
  final CookStepTimer? timer;
  final CookSessionController session;

  @override
  Widget build(BuildContext context) {
    if (timer == null) {
      final seconds = suggestedSeconds ?? 300;
      return OutlinedButton.icon(
        onPressed: () =>
            session.startTimer(stepIndex, Duration(seconds: seconds)),
        icon: const Icon(Icons.timer_outlined),
        label: Text('${context.strings('cook.timer')} · ${_clock(seconds)}'),
      );
    }
    final completed = timer!.status == CookTimerStatus.completed;
    final running = timer!.status == CookTimerStatus.running;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 13, 10, 13),
      decoration: BoxDecoration(
        border: Border.all(
          color: completed ? context.morph.coral : context.morph.teal,
          width: completed ? 2 : 1,
        ),
        color: context.morph.paperDeep.withValues(alpha: .35),
      ),
      child: Row(
        children: [
          Icon(
            completed ? Icons.alarm_on_rounded : Icons.timer_outlined,
            color: completed ? context.morph.coral : context.morph.teal,
          ),
          const SizedBox(width: 12),
          Text(
            _clock(timer!.remainingSeconds),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Spacer(),
          if (!completed)
            IconButton(
              onPressed: running
                  ? () => session.pauseTimer(stepIndex)
                  : () => session.resumeTimer(stepIndex),
              tooltip: running
                  ? context.strings('cook.pause')
                  : context.strings('cook.resume'),
              icon: Icon(running ? Icons.pause : Icons.play_arrow),
            ),
          IconButton(
            onPressed: () => session.resetTimer(stepIndex),
            tooltip: context.strings('cook.resetTimer'),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _ServingControl extends StatelessWidget {
  const _ServingControl({required this.session});

  final CookSessionController session;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.outlined(
          onPressed: session.servings > 1
              ? () => session.setServings(session.servings - 1)
              : null,
          tooltip: context.strings('common.fewerServings'),
          icon: const Icon(Icons.remove),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            children: [
              Text(
                '${session.servings.round()}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                context.strings('common.servings').toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
        IconButton.outlined(
          onPressed: session.servings < 12
              ? () => session.setServings(session.servings + 1)
              : null,
          tooltip: context.strings('common.moreServings'),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _VisualTimerAlert extends StatelessWidget {
  const _VisualTimerAlert({required this.alert, required this.onDismiss});

  final TimerVisualAlert alert;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final color = alert.tone == TimerAlertTone.coral
        ? context.morph.coral
        : context.morph.teal;
    const alertForeground = Color(0xFF181A19);
    final overlay = BlockSemantics(
      child: Semantics(
        container: true,
        scopesRoute: true,
        namesRoute: true,
        liveRegion: true,
        label:
            '${context.strings('cook.timerComplete')}. ${context.strings('cook.tapDismiss')}',
        button: true,
        onTap: onDismiss,
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: ColoredBox(
              color: color.withValues(alpha: .94),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.alarm_on_rounded,
                      size: 76,
                      color: alertForeground,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      context.strings('cook.timerComplete'),
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(color: alertForeground),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.strings('cook.tapDismiss'),
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: alertForeground),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (!alert.shouldAnimate) return overlay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.scale(scale: .96 + value * .04, child: child),
      ),
      child: overlay,
    );
  }
}

class _CompletionView extends StatelessWidget {
  const _CompletionView({
    required this.recipe,
    required this.language,
    required this.finishing,
    required this.onFinish,
  });

  final Recipe recipe;
  final String language;
  final bool finishing;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 72,
                color: context.morph.mustard,
              ),
              const SizedBox(height: 24),
              Text(
                context.strings('cook.completeTitle'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 12),
              Text(
                recipe.name.resolve(language),
                textAlign: TextAlign.center,
                style: morphHandwriting(
                  context,
                  size: 30,
                  color: context.morph.coral,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                context.strings('cook.completeBody'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              InkButton(
                label: context.strings('common.done'),
                icon: Icons.check_rounded,
                expand: true,
                onPressed: finishing ? null : onFinish,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _clock(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
}
