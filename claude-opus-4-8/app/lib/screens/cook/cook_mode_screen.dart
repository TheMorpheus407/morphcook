import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/context_ext.dart';
import '../../logic/cook_mode_controller.dart';
import '../../models/recipe.dart';
import '../../theme/app_theme.dart';

/// Dark, full-bleed, step-by-step cooking. Per-step timers, servings scaler,
/// pause/resume with persistence, a completion screen, an accessible visual
/// flash on timer end, and an opt-in one-handed quick-advance tap.
class CookModeScreen extends StatefulWidget {
  const CookModeScreen({super.key, required this.recipe});
  final Recipe recipe;

  @override
  State<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends State<CookModeScreen>
    with SingleTickerProviderStateMixin {
  late OneHandedCookModeController _c;
  late List<String> _steps;
  late AnimationController _flash;
  bool _flashing = false;

  @override
  void initState() {
    super.initState();
    _flash = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _flash.addStatusListener((s) {
      if (s == AnimationStatus.completed) setState(() => _flashing = false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final profile = context.scope.services.profile.profile;
    _steps = widget.recipe.stepsFor(context.lang);
    final reduce = profile.reduceMotion ??
        MediaQuery.maybeOf(context)?.disableAnimations ??
        false;
    _c = OneHandedCookModeController(
      stepCount: _steps.length,
      stepTimers: widget.recipe.stepTimers,
      baseServings: widget.recipe.servings,
      reduceMotion: reduce,
      quickNextTapEnabled: profile.quickNextTapEnabled,
      onTimerComplete: _onTimerComplete,
    );
    _c.addListener(_persist);
    _maybeOfferResume();
  }

  bool _initialized = false;

  void _persist() {
    if (!_c.isFinished) {
      context.scope.services.cookProgress
          .save(widget.recipe.id, _c.step, _c.servings);
    }
  }

  Future<void> _maybeOfferResume() async {
    final saved = context.scope.services.cookProgress.load(widget.recipe.id);
    if (saved == null || saved.step == 0) return;
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    final resume = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cookBg,
        title: Text(context.tr('cook.resume_prompt'),
            style: const TextStyle(color: AppColors.cookInk, fontFamily: Fonts.display)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cook.step'),
                style: const TextStyle(color: AppColors.inkFaint)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.flashCoral),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('cook.resume')),
          ),
        ],
      ),
    );
    if (resume == true) {
      _c.setServings(saved.servings == 0 ? widget.recipe.servings : saved.servings);
      _c.goTo(saved.step);
    }
  }

  void _onTimerComplete() {
    HapticFeedback.heavyImpact();
    final visual = context.scope.services.profile.profile.visualAlertEnabled;
    if (visual && !_c.reduceMotion) {
      setState(() => _flashing = true);
      _flash.forward(from: 0);
    } else if (visual) {
      setState(() => _flashing = true); // static banner, no strobe
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: AppColors.flashTeal,
            content: Text(context.tr('cook.timer_done'))),
      );
    }
  }

  Future<void> _finish() async {
    final services = context.scope.services;
    await services.history.record(widget.recipe.id);
    await services.cookProgress.clear(widget.recipe.id);
    _c.goTo(_steps.length); // marks finished
  }

  @override
  void dispose() {
    _c.removeListener(_persist);
    _c.dispose();
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.cookDark(),
      child: Scaffold(
        backgroundColor: AppColors.cookBg,
        body: ListenableBuilder(
          listenable: _c,
          builder: (context, _) {
            if (_c.isFinished) return _Completion(recipe: widget.recipe);
            return Stack(
              children: [
                SafeArea(child: _stepView()),
                if (_flashing) _flashOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _flashOverlay() {
    if (_c.reduceMotion) {
      return Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          child: Container(
            color: AppColors.flashCoral,
            padding: const EdgeInsets.all(16),
            child: Text(context.tr('cook.timer_done'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: Fonts.mono, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _flash,
        builder: (context, _) {
          // alternate coral/teal a few times, fading out
          final t = _flash.value;
          final phase = (t * 6).floor().isEven;
          final color = (phase ? AppColors.flashCoral : AppColors.flashTeal)
              .withValues(alpha: (1 - t) * 0.55);
          return Container(color: color);
        },
      ),
    );
  }

  Widget _stepView() {
    final s = context.s;
    return Column(
      children: [
        _header(),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_c.quickNext()) HapticFeedback.selectionClick();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${s.t('cook.step')} ${_c.step + 1} ${s.t('cook.of')} ${_steps.length}',
                          style: const TextStyle(
                              fontFamily: Fonts.mono,
                              fontSize: 13,
                              letterSpacing: 2,
                              color: AppColors.flashCoral)),
                      const SizedBox(height: 22),
                      Text(_steps[_c.step],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontFamily: Fonts.display,
                              fontSize: 28,
                              color: AppColors.cookInk,
                              height: 1.35)),
                      const SizedBox(height: 28),
                      if (_c.hasTimer) _timer(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        _footer(),
      ],
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.cookInk),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(context.loc(widget.recipe.name),
                style: const TextStyle(
                    fontFamily: Fonts.display,
                    fontStyle: FontStyle.italic,
                    fontSize: 18,
                    color: AppColors.cookInk),
                overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            icon: const Icon(Icons.remove, color: AppColors.cookInk),
            onPressed: () => _c.setServings(_c.servings - 1),
          ),
          Text('${_c.servings}',
              style: const TextStyle(
                  fontFamily: Fonts.mono, fontSize: 16, color: AppColors.cookInk)),
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.cookInk),
            onPressed: () => _c.setServings(_c.servings + 1),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.people_outline, size: 16, color: AppColors.inkFaint),
          ),
        ],
      ),
    );
  }

  Widget _timer() {
    final mm = (_c.remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (_c.remainingSeconds % 60).toString().padLeft(2, '0');
    final showCountdown = _c.timerRunning || _c.remainingSeconds > 0;
    return Column(
      children: [
        if (showCountdown)
          Text('$mm:$ss',
              style: const TextStyle(
                  fontFamily: Fonts.mono,
                  fontSize: 52,
                  color: AppColors.flashTeal,
                  fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (!showCountdown)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.flashTeal,
                side: const BorderSide(color: AppColors.flashTeal)),
            onPressed: _c.startTimer,
            icon: const Icon(Icons.timer_outlined),
            label: Text('${context.tr('cook.start_timer')} · ${_c.currentStepTimer ~/ 60}:${(_c.currentStepTimer % 60).toString().padLeft(2, '0')}'),
          )
        else
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.cookInk,
                side: const BorderSide(color: AppColors.inkFaint)),
            onPressed: _c.timerRunning ? _c.pauseTimer : _c.resumeTimer,
            icon: Icon(_c.timerRunning ? Icons.pause : Icons.play_arrow),
            label: Text(context.tr(_c.timerRunning ? 'cook.pause' : 'cook.resume')),
          ),
      ],
    );
  }

  Widget _footer() {
    final isLast = _c.step == _steps.length - 1;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (_c.step > 0)
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.cookInk,
                      side: const BorderSide(color: AppColors.inkFaint),
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: _c.prev,
                  child: Text(context.tr('cook.prev')),
                ),
              ),
            if (_c.step > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.flashCoral,
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: isLast ? _finish : _c.next,
                child: Text(context.tr(isLast ? 'cook.finish' : 'cook.next'),
                    style: const TextStyle(
                        fontFamily: Fonts.mono, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Completion extends StatelessWidget {
  const _Completion({required this.recipe});
  final Recipe recipe;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_dining, size: 56, color: AppColors.flashCoral),
            const SizedBox(height: 20),
            Text(context.tr('cook.done_title'),
                style: const TextStyle(
                    fontFamily: Fonts.display,
                    fontStyle: FontStyle.italic,
                    fontSize: 40,
                    color: AppColors.cookInk)),
            const SizedBox(height: 10),
            Text(context.tr('cook.done_sub'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: Fonts.hand, fontSize: 22, color: AppColors.inkFaint)),
            const SizedBox(height: 28),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.flashTeal),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('common.done')),
            ),
          ],
        ),
      ),
    );
  }
}
