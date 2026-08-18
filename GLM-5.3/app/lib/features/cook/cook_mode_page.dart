import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/localized_text.dart';
import '../../core/models/recipe.dart';
import '../../core/services/haptics.dart';
import '../../core/services/profile_store.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/chips.dart';
import '../../l10n/tr.dart';
import '../../state/app_state.dart';
import 'one_handed_controller.dart';

/// Dark full-bleed cook mode (SPEC): step-by-step, per-step timer with
/// coral/teal visual flash + haptics on completion (accessibility), servings
/// scaler, prev/next, pause/resume with progress persistence, quick-tap
/// one-handed advancing, completion screen.
class CookModePage extends StatefulWidget {
  const CookModePage({super.key, required this.recipe, this.resume});

  final Recipe recipe;
  final CookProgress? resume;

  @override
  State<CookModePage> createState() => _CookModePageState();
}

class _CookModePageState extends State<CookModePage> with WidgetsBindingObserver {
  late int _stepIndex;
  late int _servings;
  int? _remaining;
  bool _running = false;
  Timer? _ticker;
  bool _finished = false;
  bool _recorded = false;
  late final OneHandedCookModeController _oneHanded;
  int _flashTick = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = context.read<AppState>();
    _oneHanded = OneHandedCookModeController(
      quickNextTapEnabled: state.profileStore.quickNextTapEnabled,
      reduceMotion:
          state.profile.reduceMotion ?? MediaQuery.of(context).disableAnimations,
    );
    _oneHanded.onAdvance = _nextStep;
    final resume = widget.resume;
    if (resume != null && resume.recipeId == widget.recipe.id) {
      _stepIndex =
          resume.stepIndex.clamp(0, widget.recipe.steps.length - 1).toInt();
      _servings = resume.servings;
      _remaining = resume.timerRemainingSeconds;
      _running = false;
    } else {
      _stepIndex = 0;
      _servings = widget.recipe.servings;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    // SPEC: pause/resume with progress persistence.
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.inactive) {
      _pauseTimer(persist: true);
    }
  }

  AppState get _state => context.read<AppState>();

  void _persist() {
    _state.cookProgress.save(CookProgress(
      recipeId: widget.recipe.id,
      stepIndex: _stepIndex,
      servings: _servings,
      timerRemainingSeconds: _remaining,
      timerRunning: _running,
      updatedAt: DateTime.now(),
    ));
  }
  void _startTimer() {
    final seconds = widget.recipe.steps[_stepIndex].timerSeconds;
    if (seconds == null) return;
    setState(() {
      _remaining ??= seconds;
      _running = true;
    });
    _persist();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_running) return;
      setState(() {
        _remaining = (_remaining ?? 1) - 1;
        if (_remaining! <= 0) {
          _remaining = 0;
          _running = false;
          _ticker?.cancel();
          _onTimerDone();
        }
      });
      if (_running || _remaining == 0) _persist();
    });
  }

  void _onTimerDone() {
    Haptics.impact();
    final state = _state;
    // SPEC: visual flash alert (coral/teal) for accessibility, gated by the
    // visualAlertEnabled setting; respects reduceMotion (instant flash).
    if (state.profile.visualAlertEnabled) {
      setState(() => _flashTick += 1);
    }
  }

  void _pauseTimer({bool persist = true}) {
    if (_running) {
      setState(() => _running = false);
    }
    _ticker?.cancel();
    if (persist) _persist();
  }

  void _resumeTimer() {
    if (_remaining == null || _remaining! <= 0) return;
    setState(() => _running = true);
    _persist();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_running) return;
      setState(() {
        _remaining = _remaining! - 1;
        if (_remaining! <= 0) {
          _remaining = 0;
          _running = false;
          _ticker?.cancel();
          _onTimerDone();
        }
      });
      if (_running || _remaining == 0) _persist();
    });
  }

  void _resetTimer() {
    _ticker?.cancel();
    setState(() {
      _remaining = null;
      _running = false;
    });
    _persist();
  }

  void _goStep(int index) {
    _ticker?.cancel();
    setState(() {
      _stepIndex = index.clamp(0, widget.recipe.steps.length - 1).toInt();
      _remaining = null;
      _running = false;
    });
    _persist();
  }

  void _nextStep() {
    if (_stepIndex >= widget.recipe.steps.length - 1) {
      _finish();
    } else {
      _goStep(_stepIndex + 1);
    }
  }

  void _finish() {
    _ticker?.cancel();
    if (!_recorded) {
      _recorded = true;
      _state.recordCooked(widget.recipe.id, servings: _servings);
      _state.cookProgress.clear();
    }
    Haptics.success();
    setState(() => _finished = true);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.lang;
    return Scaffold(
      backgroundColor: AppColors.cookBg,
      body: SafeArea(
        child: Stack(
          children: [
            if (_finished)
              _CompletionScreen(
                  recipe: widget.recipe, onBackToDish: () => Navigator.of(context).pop())
            else
              _buildSteps(lang, state),
            // Visual flash alert overlay (coral → teal fade).
            if (_flashTick > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: _FlashOverlay(
                    key: ValueKey('flash-$_flashTick'),
                    reduceMotion: _oneHanded.reduceMotion,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  Widget _buildSteps(String lang, AppState state) {
    final step = widget.recipe.steps[_stepIndex];
    final isLast = _stepIndex == widget.recipe.steps.length - 1;
    final hasTimer = step.timerSeconds != null;
    return Column(
      children: [
        // ---- header ----
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('cook.stepOf', {
                        'n': '${_stepIndex + 1}',
                        'm': '${widget.recipe.steps.length}'
                      }),
                      style:
                          AppFonts.mono(size: 10, color: AppColors.mustard, letterSpacing: 1.6),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lt(widget.recipe.title, lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.serif(size: 15, color: AppColors.cookInk),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.cookInk),
                onPressed: () {
                  _pauseTimer(persist: true);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
        // ---- quick-tap toggle + servings scaler ----
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              QuietLink(
                label: context.tr(_oneHanded.quickNextTapEnabled
                    ? 'cook.quickNext'
                    : 'cook.quickNextOff'),
                color: _oneHanded.quickNextTapEnabled
                    ? AppColors.mustard
                    : AppColors.inkFaint,
                onTap: () => setState(() => _oneHanded.toggleQuickNext()),
              ),
              const Spacer(),
              _servingsButton(Icons.remove, () {
                if (_servings > 1) setState(() => _servings -= 1);
                _persist();
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '$_servings',
                  style: AppFonts.mono(size: 13, color: AppColors.cookInk, weight: FontWeight.w700),
                ),
              ),
              _servingsButton(Icons.add, () {
                if (_servings < 12) setState(() => _servings += 1);
                _persist();
              }),
            ],
          ),
        ),
        // ---- step content (quick-tap surface) ----
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _oneHanded.handleQuickTap(),
            child: AnimatedSwitcher(
              duration: _oneHanded.reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 300),
              child: Padding(
                key: ValueKey('step-$_stepIndex'),
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Center(
                  child: Text(
                    lt(step.text, lang),
                    textAlign: TextAlign.center,
                    style:
                        AppFonts.display(size: 26, color: AppColors.cookInk, height: 1.5),
                  ),
                ),
              ),
            ),
          ),
        ),
        // ---- timer ----
        if (hasTimer) _timerPanel(step.timerSeconds!),
        // ---- footer nav ----
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
          child: Row(
            children: [
              TextButton(
                onPressed: _stepIndex > 0 ? () => _goStep(_stepIndex - 1) : null,
                child: Text(context.tr('cook.prev'),
                    style: AppFonts.mono(size: 12, color: AppColors.cookInk)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: (_stepIndex + 1) / widget.recipe.steps.length,
                      minHeight: 3,
                      backgroundColor: AppColors.ink.withOpacity(0.3),
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.mustard),
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: _nextStep,
                child: Text(
                  context.tr(isLast ? 'cook.finish' : 'cook.next'),
                  style: AppFonts.mono(
                      size: 12, color: AppColors.mustard, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _servingsButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(border: Border.all(color: AppColors.inkFaint)),
        child: Icon(icon, size: 14, color: AppColors.cookInk),
      ),
    );
  }
  Widget _timerPanel(int seconds) {
    final remaining = _remaining ?? seconds;
    final mm = (remaining ~/ 60).toString().padLeft(2, '0');
    final ss = (remaining % 60).toString().padLeft(2, '0');
    final done = remaining == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          border:
              Border.all(color: done ? AppColors.coral : AppColors.mustard, width: 1.4),
        ),
        child: Row(
          children: [
            Text(
              '$mm:$ss',
              style: AppFonts.mono(
                  size: 28,
                  color: done ? AppColors.coral : AppColors.cookInk,
                  weight: FontWeight.w700),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: LinearProgressIndicator(
                value: seconds == 0 ? 0 : 1 - remaining / seconds,
                minHeight: 3,
                backgroundColor: AppColors.ink.withOpacity(0.3),
                valueColor:
                    AlwaysStoppedAnimation(done ? AppColors.coral : AppColors.teal),
              ),
            ),
            const SizedBox(width: 10),
            if (done)
              Text(context.tr('cook.done'),
                  style: AppFonts.mono(size: 11, color: AppColors.coral))
            else if (_running)
              IconButton(
                icon: const Icon(Icons.pause, color: AppColors.cookInk),
                onPressed: _pauseTimer,
              )
            else
              IconButton(
                icon: const Icon(Icons.play_arrow, color: AppColors.cookInk),
                onPressed:
                    _remaining != null && _remaining! > 0 ? _resumeTimer : _startTimer,
              ),
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.inkFaint, size: 18),
              onPressed: _resetTimer,
            ),
          ],
        ),
      ),
    );
  }
}

/// The coral → teal flash overlay shown when a timer completes.
class _FlashOverlay extends StatefulWidget {
  const _FlashOverlay({super.key, required this.reduceMotion});

  final bool reduceMotion;

  @override
  State<_FlashOverlay> createState() => _FlashOverlayState();
}

class _FlashOverlayState extends State<_FlashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.reduceMotion ? const Duration(milliseconds: 120) : const Duration(milliseconds: 1100),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        // Coral first half, teal second half, both fading out.
        final Color color =
            t < 0.5 ? AppColors.coral : AppColors.teal;
        final opacity = (1 - t) * 0.55;
        return Container(color: color.withOpacity(opacity));
      },
    );
  }
}

/// The completion screen — "guten appetit".
class _CompletionScreen extends StatelessWidget {
  const _CompletionScreen({required this.recipe, required this.onBackToDish});

  final Recipe recipe;
  final VoidCallback onBackToDish;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '&',
              style: AppFonts.display(size: 64, color: AppColors.mustard),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('cook.completeTitle'),
              style: AppFonts.display(size: 42, color: AppColors.cookInk),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('cook.completeBody'),
              style: AppFonts.hand(size: 22, color: AppColors.mustard),
            ),
            const SizedBox(height: 28),
            Text(
              context.tr('cook.backToDish'),
              style: AppFonts.mono(size: 12, color: AppColors.teal),
            ),
            const SizedBox(height: 28),
            TextButton(
              onPressed: onBackToDish,
              child: Text(
                '← ${context.tr('common.close')}',
                style: AppFonts.mono(size: 12, color: AppColors.cookInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
