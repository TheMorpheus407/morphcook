import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/palette.dart';
import '../core/paper.dart';
import '../core/theme.dart';
import '../logic/one_handed_cook_mode.dart';
import '../models/recipe.dart';
import '../state/app_state.dart';

/// Cook mode: dark full-bleed, step-by-step, per-step timer,
/// servings scaler, prev/next, pause/resume with progress persistence,
/// completion screen, visual flash alert, quick-tap gesture.
class CookModeScreen extends StatefulWidget {
  const CookModeScreen({super.key, required this.recipeId});

  final String recipeId;

  @override
  State<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends State<CookModeScreen> {
  late final OneHandedCookModeController _oneHanded;
  int _step = 0;
  int _servings = 1;
  int _tab = 1; // 0 ingredients, 1 method
  bool _paused = false;
  bool _completed = false;

  // timer state
  Timer? _ticker;
  int _totalSeconds = 0;
  int _remainingSeconds = 0;
  bool _timerRunning = false;
  int _flashCount = 0;
  Timer? _flashTicker;

  Recipe? get _recipe => context.corpus.recipe(widget.recipeId);

  late final AppStore _store;

  @override
  void initState() {
    super.initState();
    _store = context.read<AppStore>();
    final profile = _store.profile;
    _oneHanded = OneHandedCookModeController(
      quickNextTapEnabled: profile.quickNextTapEnabled,
      reduceMotion: profile.reduceMotion,
    );
    final saved = _store.readCookProgress(widget.recipeId);
    if (saved != null) {
      _step = (saved['step'] as int? ?? 0).clamp(0, 9999);
      _servings = saved['servings'] as int? ?? 1;
      final remaining = saved['timer_remaining'] as int?;
      final timerTotal = saved['timer_total'] as int?;
      if (remaining != null && timerTotal != null && remaining > 0) {
        _remainingSeconds = remaining;
        _totalSeconds = timerTotal;
      }
    }
    final recipe = _recipe;
    if (recipe != null) {
      _servings = _servings <= 0 ? recipe.servings : _servings;
      _servings = _servings.clamp(1, 24);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _flashTicker?.cancel();
    _persist();
    super.dispose();
  }

  void _persist() {
    if (_completed) {
      _store.clearCookProgress(widget.recipeId);
    } else {
      _store.saveCookProgress(widget.recipeId, {
        'step': _step,
        'servings': _servings,
        'timer_total': _totalSeconds,
        'timer_remaining': _remainingSeconds,
      });
    }
  }

  void _next() {
    final recipe = _recipe;
    if (recipe == null) return;
    if (_step >= recipe.steps.length - 1) {
      _finish();
      return;
    }
    setState(() {
      _step++;
      _stopTimer();
    });
    _persist();
    HapticFeedback.selectionClick();
  }

  void _prev() {
    if (_step == 0) return;
    setState(() {
      _step--;
      _stopTimer();
    });
    _persist();
    HapticFeedback.selectionClick();
  }

  void _finish() {
    setState(() {
      _completed = true;
      _stopTimer();
    });
    _store.recordCooked(widget.recipeId);
    _store.clearCookProgress(widget.recipeId);
    HapticFeedback.heavyImpact();
  }

  // ------------------------------------------------------------- timer

  void _startTimer(int minutes) {
    _ticker?.cancel();
    setState(() {
      _totalSeconds = minutes * 60;
      _remainingSeconds = minutes * 60;
      _timerRunning = true;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_paused) return;
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          _onTimerComplete();
        }
      });
    });
  }

  void _pauseTimer() {
    setState(() {
      _paused = true;
      _timerRunning = false;
    });
    _persist();
  }

  void _resumeTimer() {
    if (_remainingSeconds <= 0) return;
    setState(() {
      _paused = false;
      _timerRunning = true;
    });
    _persist();
  }

  void _resetTimer() {
    setState(() {
      _remainingSeconds = _totalSeconds;
      _timerRunning = false;
      _paused = false;
    });
  }

  void _stopTimer() {
    _ticker?.cancel();
    _ticker = null;
    _timerRunning = false;
    _paused = false;
    _remainingSeconds = 0;
    _totalSeconds = 0;
  }

  void _onTimerComplete() {
    _ticker?.cancel();
    _ticker = null;
    _timerRunning = false;
    _remainingSeconds = 0;

    final profile = _store.profile;
    final reduceMotion = profile.reduceMotion;
    flashHaptic();
    if (profile.visualAlertEnabled) {
      _flashCount = reduceMotion ? 2 : 6;
      _flashTicker?.cancel();
      _flashTicker = Timer.periodic(
        Duration(milliseconds: reduceMotion ? 400 : 280),
        (_) {
          if (!mounted) return;
          setState(() {
            _flashCount--;
            if (_flashCount <= 0) {
              _flashTicker?.cancel();
              _flashTicker = null;
            }
          });
        },
      );
    }
    _persist();
  }

  String _fmt(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // -------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final recipe = _recipe;
    if (recipe == null) {
      return const Scaffold(
        backgroundColor: MC.night,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: MC.night,
      body: Stack(
        children: [
          SafeArea(
            child: _completed
                ? _completion(context, recipe)
                : _cook(context, recipe),
          ),
          if (_flashCount > 0)
            IgnorePointer(
              child: Container(
                color: _flashCount.isEven
                    ? MC.flashCoral.withValues(alpha: 0.85)
                    : MC.flashTeal.withValues(alpha: 0.85),
              ).animate().fadeIn(duration: 80.ms),
            ),
        ],
      ),
    );
  }

  Widget _completion(BuildContext context, Recipe recipe) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              context.t('cmDone'),
              style: const TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontSize: 44,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                color: MC.nightInk,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.t('cmDoneSub'),
              style: TextStyle(
                fontFamily: 'Caveat',
                fontSize: 22,
                color: MC.inkFaint,
              ),
            ),
            const SizedBox(height: 30),
            const DashedOrnament(color: MC.nightRule),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: MC.nightInk,
                foregroundColor: MC.night,
              ),
              onPressed: () => setState(() {
                _completed = false;
                _step = 0;
              }),
              child: Text(context.t('cmCookAgain')),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                context.t('close'),
                style: const TextStyle(color: MC.inkFaint),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 500.ms).move(begin: const Offset(0, 20)),
      ),
    );
  }

  Widget _cook(BuildContext context, Recipe recipe) {
    final steps = recipe.steps;
    final step = steps[_step.clamp(0, steps.length - 1)];
    final scale = _servings / recipe.servings;

    return Column(
      children: [
        // top bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: MC.nightInk, size: 22),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.pick(recipe.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 19,
                        fontStyle: FontStyle.italic,
                        color: MC.nightInk,
                      ),
                    ),
                    Text(
                      '${_step + 1} ${context.t('of')} ${steps.length}',
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 10,
                        letterSpacing: 1.2,
                        color: MC.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              _servingsControl(context, recipe),
            ],
          ),
        ),
        const SizedBox(height: 4),
        _progressBar(context, steps.length),
        const SizedBox(height: 10),
        // tabs
        Row(
          children: [
            _tabButton(context, 0, context.t('dishIngredients')),
            _tabButton(context, 1, context.t('cmSteps')),
          ],
        ),
        Expanded(
          child: _tab == 0
              ? _ingredients(context, recipe, scale)
              : _steps(context, recipe, step),
        ),
        // quick-tap hint
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text(
            _oneHanded.quickNextTapEnabled
                ? context.t('cmQuickTapOn')
                : context.t('cmQuickTapOff'),
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 9.5,
              letterSpacing: 0.8,
              color: MC.inkFaint,
            ),
          ),
        ),
        if (_paused)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              context.t('cmPausedNote'),
              style: const TextStyle(
                fontFamily: 'Caveat',
                fontSize: 16,
                color: MC.flashTeal,
              ),
            ),
          ),
        _navBar(context, steps.length),
      ],
    );
  }

  Widget _servingsControl(BuildContext context, Recipe recipe) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: MC.nightRule),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _servingButton(Icons.remove, () {
            if (_servings > 1) {
              setState(() => _servings--);
              _persist();
            }
          }),
          SizedBox(
            width: 58,
            child: Column(
              children: [
                Text(
                  '$_servings',
                  style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: MC.nightInk,
                  ),
                ),
                Text(
                  context.t('servings').toLowerCase(),
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 8,
                    letterSpacing: 0.8,
                    color: MC.inkFaint,
                  ),
                ),
              ],
            ),
          ),
          _servingButton(Icons.add, () {
            if (_servings < 24) {
              setState(() => _servings++);
              _persist();
            }
          }),
        ],
      ),
    );
  }

  Widget _servingButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Icon(icon, size: 16, color: MC.nightInk),
      ),
    );
  }

  Widget _progressBar(BuildContext context, int total) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: (_step + 1) / total,
          minHeight: 4,
          backgroundColor: MC.nightRaised,
          color: MC.flashCoral,
        ),
      ),
    );
  }

  Widget _tabButton(BuildContext context, int tab, String label) {
    final active = _tab == tab;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? MC.nightInk : MC.nightRule,
                width: active ? 2 : 1,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 11,
              letterSpacing: 0.8,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: active ? MC.nightInk : MC.inkFaint,
            ),
          ),
        ),
      ),
    );
  }

  Widget _ingredients(BuildContext context, Recipe recipe, double scale) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
      children: [
        for (final ing in recipe.ingredients)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(top: 7),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: MC.flashCoral,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.ingredientName(ing.id),
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 13,
                      color: MC.nightInk,
                    ),
                  ),
                ),
                Text(
                  '${_fmtAmount(ing.amount * scale)} ${ing.unit}',
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MC.flashTeal,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _steps(BuildContext context, Recipe recipe, dynamic step) {
    final title = context.pick(step.title as Map<String, String>);
    final text = context.pick(step.text as Map<String, String>);
    final timerMinutes = step.timerMinutes as int?;

    final content = ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
      children: [
        Text(
          '${_step + 1}.',
          style: const TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: 40,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            color: MC.flashCoral,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: 27,
            fontWeight: FontWeight.w600,
            color: MC.nightInk,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          text,
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 15,
            height: 1.65,
            color: MC.nightInk.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 22),
        if (timerMinutes != null) _timerCard(context, timerMinutes),
        const SizedBox(height: 30),
      ],
    );

    // quick-tap gesture: single tap on step content advances
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (_) {
        if (_oneHanded.tryAdvance()) {
          flashHaptic();
          _next();
        }
      },
      child: content,
    );
  }

  Widget _timerCard(BuildContext context, int minutes) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MC.nightRaised,
        border: Border.all(color: MC.nightRule),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('cmTimer').toUpperCase(),
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 10,
              letterSpacing: 1.6,
              color: MC.inkFaint,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _fmt(_remainingSeconds > 0 || _timerRunning
                ? _remainingSeconds
                : minutes * 60),
            style: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 46,
              fontWeight: FontWeight.w700,
              color: MC.nightInk,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (!_timerRunning && !_paused)
                _timerButton(
                  context,
                  context.t('cmStartTimer'),
                  Icons.play_arrow,
                  () => _startTimer(minutes),
                  filled: true,
                ),
              if (_timerRunning)
                _timerButton(
                  context,
                  context.t('cmPause'),
                  Icons.pause,
                  _pauseTimer,
                ),
              if (_paused && _remainingSeconds > 0)
                _timerButton(
                  context,
                  context.t('cmResume'),
                  Icons.play_arrow,
                  _resumeTimer,
                ),
              if ((_timerRunning || _paused) && _remainingSeconds > 0)
                _timerButton(
                  context,
                  context.t('cmReset'),
                  Icons.refresh,
                  _resetTimer,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timerButton(BuildContext context, String label, IconData icon,
      VoidCallback onTap,
      {bool filled = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: MC.nightInk,
          backgroundColor: filled ? MC.flashCoral : null,
          side: BorderSide(
            color: filled ? MC.flashCoral : MC.nightRule,
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        label: Text(label),
      ),
    );
  }

  Widget _navBar(BuildContext context, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: MC.nightInk,
              side: const BorderSide(color: MC.nightRule),
            ),
            onPressed: _step == 0 ? null : _prev,
            child: Text(context.t('cmPrev')),
          ),
          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MC.flashCoral,
              foregroundColor: MC.night,
            ),
            onPressed: _next,
            child: Text(
              _step >= total - 1 ? context.t('done') : context.t('next'),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtAmount(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}
