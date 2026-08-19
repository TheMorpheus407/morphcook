/// Cook mode: dark full-bleed, step-by-step, per-step timer, servings
/// scaler, prev/next, pause/resume with progress persistence, completion.
///
/// - Visual flash alert (coral/teal) on timer completion — accessibility for
///   deaf/hard-of-hearing users; controlled by `visualAlertEnabled`, respects
///   `reduceMotion`.
/// - Quick-tap gesture: single tap on step content advances with haptic
///   feedback; opt-in via `OneHandedCookModeController.quickNextTapEnabled`,
///   300 ms debounce, also respects `reduceMotion`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../l10n.dart';
import '../state/app_state.dart';
import '../ui/theme.dart';

/// Controls cook-mode navigation, timers, and the one-handed quick-tap.
class OneHandedCookModeController extends ChangeNotifier {
  final Recipe recipe;
  final bool quickNextTapEnabled;
  final bool reduceMotion;
  final bool visualAlertEnabled;
  final int initialStep;
  final int initialServings;

  int stepIndex = 0;
  int servings;
  Timer? _stepTimer;
  int _remainingSeconds = 0;
  bool _timerRunning = false;
  bool _completed = false;
  bool _paused = false;
  DateTime? _lastTap;

  OneHandedCookModeController({
    required this.recipe,
    required this.quickNextTapEnabled,
    required this.reduceMotion,
    required this.visualAlertEnabled,
    required this.initialStep,
    required this.initialServings,
  })  : servings = initialServings,
        stepIndex = initialStep;

  int get totalSteps => recipe.steps.length;
  RecipeStep get currentStep => recipe.steps[stepIndex];
  bool get isLast => stepIndex >= totalSteps - 1;
  bool get completed => _completed;
  bool get paused => _paused;
  bool get timerRunning => _timerRunning;
  int get remainingSeconds => _remainingSeconds;
  bool get hasTimer => currentStep.timerSeconds != null;

  /// Handles a tap on step content. Returns true when it advanced.
  bool handleContentTap() {
    if (!quickNextTapEnabled || _completed) return false;
    final now = DateTime.now();
    if (_lastTap != null &&
        now.difference(_lastTap!).inMilliseconds < 300) {
      return false; // debounce 300ms
    }
    _lastTap = now;
    HapticFeedback.lightImpact();
    next();
    return true;
  }

  void next() {
    if (isLast) {
      _completed = true;
      stopTimer();
      notifyListeners();
      return;
    }
    stopTimer();
    stepIndex++;
    _paused = false;
    notifyListeners();
  }

  void previous() {
    if (stepIndex == 0) return;
    stopTimer();
    stepIndex--;
    _paused = false;
    notifyListeners();
  }

  void jumpTo(int index) {
    if (index < 0 || index >= totalSteps) return;
    stopTimer();
    stepIndex = index;
    _paused = false;
    notifyListeners();
  }

  void setServings(int value) {
    if (value < 1 || value > 24) return;
    servings = value;
    notifyListeners();
  }

  void startTimer() {
    final seconds = currentStep.timerSeconds;
    if (seconds == null || _timerRunning) return;
    _remainingSeconds = _remainingSeconds > 0 ? _remainingSeconds : seconds;
    _timerRunning = true;
    _paused = false;
    _stepTimer?.cancel();
    _stepTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _remainingSeconds--;
      if (_remainingSeconds <= 0) {
        _remainingSeconds = 0;
        _timerRunning = false;
        _stepTimer?.cancel();
        HapticFeedback.heavyImpact();
        notifyListeners();
        onTimerFinished?.call();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void pauseTimer() {
    _stepTimer?.cancel();
    _timerRunning = false;
    _paused = true;
    notifyListeners();
  }

  void restartTimer() {
    _stepTimer?.cancel();
    _remainingSeconds = currentStep.timerSeconds ?? 0;
    _timerRunning = false;
    _paused = false;
    notifyListeners();
    startTimer();
  }

  void stopTimer() {
    _stepTimer?.cancel();
    _timerRunning = false;
    _remainingSeconds = 0;
    _paused = false;
  }

  /// Set by the screen to trigger the visual flash.
  VoidCallback? onTimerFinished;

  Map<String, dynamic> serialize() => {
        'step': stepIndex,
        'servings': servings,
        'saved_at': DateTime.now().toIso8601String(),
      };

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }
}

class CookModeScreen extends StatefulWidget {
  final String recipeId;
  const CookModeScreen({super.key, required this.recipeId});

  @override
  State<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends State<CookModeScreen> {
  late OneHandedCookModeController _controller;
  bool _flashOn = false;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    final recipe = app.recipe(widget.recipeId)!;
    final saved = app.stores.cookProgress(widget.recipeId);
    _controller = OneHandedCookModeController(
      recipe: recipe,
      quickNextTapEnabled: app.profile.quickNextTapEnabled,
      reduceMotion: app.profile.reduceMotion ?? false,
      visualAlertEnabled: app.profile.visualAlertEnabled,
      initialStep: (saved?['step'] as num?)?.toInt() ?? 0,
      initialServings: (saved?['servings'] as num?)?.toInt() ?? recipe.servings,
    );
    _controller.onTimerFinished = _flash;
    // persist progress on every step change
    _controller.addListener(_persist);
  }

  void _persist() {
    final app = context.read<AppState>();
    if (!_controller.completed) {
      app.stores.saveCookProgress(widget.recipeId, _controller.serialize());
    }
  }

  void _flash() {
    final app = context.read<AppState>();
    if (!app.profile.visualAlertEnabled) return;
    setState(() => _flashOn = true);
    _flashTimer?.cancel();
    // coral/teal alternating flash, shorter when reduce-motion
    final dur = app.profile.reduceMotion ?? false
        ? const Duration(milliseconds: 500)
        : const Duration(milliseconds: 2500);
    var toggles = app.profile.reduceMotion ?? false ? 2 : 6;
    _flashTimer = Timer.periodic(
        dur ~/ toggles == Duration.zero ? const Duration(milliseconds: 200) : dur ~/ toggles,
        (t) {
      setState(() => _flashOn = !_flashOn);
      toggles--;
      if (toggles <= 0) {
        t.cancel();
        setState(() => _flashOn = false);
      }
    });
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _controller.removeListener(_persist);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish(AppState app) async {
    await app.logCooked(widget.recipeId);
    await app.stores.clearCookProgress(widget.recipeId);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.profile.lang;
    final dish = app.dish(_controller.recipe.dishId)!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final c = _controller;
        return Scaffold(
          backgroundColor: AppTheme.cookBg,
          body: GestureDetector(
            onTap: () => c.handleContentTap(),
            child: Stack(children: [
              // visual flash overlay
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    color: _flashOn ? AppTheme.coral : Colors.transparent,
                  ),
                ),
              ),
              SafeArea(
                child: Column(children: [
                  // header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(children: [
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: AppTheme.cookPaper, size: 22),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Column(children: [
                          Text(
                            '${dish.canonicalName.get(lang)} — ${c.recipe.title.get(lang)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontFamily: AppTheme.display,
                                fontStyle: FontStyle.italic,
                                fontSize: 16,
                                color: AppTheme.cookPaper.withValues(alpha: .9)),
                          ),
                          Text(
                            c.completed
                                ? L.t(lang, 'ckTitle')
                                : L.f(lang, 'ckStepOf', {
                                    'a': '${c.stepIndex + 1}',
                                    'b': '${c.totalSteps}',
                                  }),
                            style: TextStyle(
                                fontFamily: AppTheme.mono,
                                fontSize: 9.5,
                                letterSpacing: 1.6,
                                color: AppTheme.cookPaper.withValues(alpha: .5)),
                          ),
                        ]),
                      ),
                      // servings scaler
                      _ServingsScaler(controller: c),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  // progress rail
                  Row(
                    children: [
                      for (var i = 0; i < c.totalSteps; i++)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => c.jumpTo(i),
                            child: Container(
                              height: 3,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              color: i <= c.stepIndex
                                  ? AppTheme.coral
                                  : AppTheme.cookPaper.withValues(alpha: .15),
                            ),
                          ),
                        ),
                    ],
                  ),

                  Expanded(
                    child: c.completed
                        ? _CompletionView(
                            lang: lang,
                            recipe: c.recipe,
                            onFinish: () {
                              _finish(app);
                              Navigator.of(context).pop();
                            },
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 26, vertical: 18),
                            child: Column(children: [
                              Expanded(
                                child: Center(
                                  child: SingleChildScrollView(
                                    child: Text(
                                      c.currentStep.text.get(lang),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontFamily: AppTheme.display,
                                          fontSize: 24,
                                          height: 1.5,
                                          color: AppTheme.cookPaper),
                                    ),
                                  ),
                                ),
                              ),
                              if (app.profile.quickNextTapEnabled)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    L.t(lang, 'ckQuickTapHint'),
                                    style: TextStyle(
                                        fontFamily: AppTheme.mono,
                                        fontSize: 9,
                                        letterSpacing: 1.2,
                                        color: AppTheme.cookPaper
                                            .withValues(alpha: .45)),
                                  ),
                                ),
                            ]),
                          ),
                  ),

                  // timer zone
                  if (!c.completed && c.hasTimer)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 26),
                      child: _TimerPanel(controller: c, lang: lang),
                    ),
                  if (!c.completed && c.paused)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        L.t(lang, 'ckPaused'),
                        style: const TextStyle(
                            fontFamily: AppTheme.hand,
                            fontSize: 17,
                            color: AppTheme.mustard),
                      ),
                    ),

                  // nav buttons
                  if (!c.completed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                      child: Row(children: [
                        Expanded(
                          child: _CookButton(
                            label: L.t(lang, 'ckPrev'),
                            enabled: c.stepIndex > 0,
                            onTap: c.previous,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _CookButton(
                            label: L.t(lang, 'ckNext'),
                            primary: true,
                            onTap: c.next,
                          ),
                        ),
                      ]),
                    ),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _ServingsScaler extends StatelessWidget {
  final OneHandedCookModeController controller;
  const _ServingsScaler({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        visualDensity: VisualDensity.compact,
        icon: Icon(Icons.remove,
            size: 16, color: AppTheme.cookPaper.withValues(alpha: .7)),
        onPressed: () => controller.setServings(controller.servings - 1),
      ),
      Text(
        '${controller.servings}',
        style: const TextStyle(
            fontFamily: AppTheme.mono,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.cookPaper),
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        icon: Icon(Icons.add,
            size: 16, color: AppTheme.cookPaper.withValues(alpha: .7)),
        onPressed: () => controller.setServings(controller.servings + 1),
      ),
    ]);
  }
}

class _TimerPanel extends StatelessWidget {
  final OneHandedCookModeController controller;
  final Lang lang;
  const _TimerPanel({required this.controller, required this.lang});

  String _fmt(int s) {
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final done = c.hasTimer && c.remainingSeconds == 0 && !c.timerRunning;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.cookPanel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: done ? AppTheme.coral : AppTheme.cookPaper.withValues(alpha: .2)),
      ),
      child: Row(children: [
        Text(
          done ? L.t(lang, 'ckTimerDone') : _fmt(c.remainingSeconds),
          style: TextStyle(
              fontFamily: AppTheme.mono,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: done ? AppTheme.coral : AppTheme.cookPaper),
        ),
        const Spacer(),
        if (done)
          _CookButton(
            label: L.t(lang, 'ckRestart'),
            onTap: c.restartTimer,
          )
        else if (c.timerRunning)
          _CookButton(label: L.t(lang, 'ckPause'), onTap: c.pauseTimer)
        else
          _CookButton(
              label: c.remainingSeconds > 0
                  ? L.t(lang, 'ckResume')
                  : L.t(lang, 'ckTimerStart'),
              primary: true,
              onTap: c.startTimer),
      ]),
    );
  }
}

class _CookButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool primary;
  final VoidCallback onTap;
  const _CookButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = primary ? AppTheme.cookBg : AppTheme.cookPaper;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: primary ? AppTheme.cookPaper : Colors.transparent,
          border: Border.all(
              color: enabled
                  ? AppTheme.cookPaper.withValues(alpha: .5)
                  : AppTheme.cookPaper.withValues(alpha: .15)),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
              fontFamily: AppTheme.mono,
              fontSize: 10,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
              color: enabled ? fg : AppTheme.cookPaper.withValues(alpha: .3)),
        ),
      ),
    );
  }
}

class _CompletionView extends StatelessWidget {
  final Lang lang;
  final Recipe recipe;
  final VoidCallback onFinish;
  const _CompletionView({
    required this.lang,
    required this.recipe,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // scaled ingredient recap
          Text(
            L.t(lang, 'ckCompleted'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: AppTheme.display,
                fontStyle: FontStyle.italic,
                fontSize: 34,
                height: 1.2,
                color: AppTheme.cookPaper),
          ),
          const SizedBox(height: 14),
          Text(
            L.t(lang, 'ckCompletedBody'),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: AppTheme.display,
                fontSize: 16,
                height: 1.5,
                color: AppTheme.cookPaper.withValues(alpha: .7)),
          ),
          const SizedBox(height: 26),
          _CookButton(label: L.t(lang, 'ckDone'), primary: true, onTap: onFinish),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              L.t(lang, 'ckBackToRecipe'),
              style: TextStyle(
                  fontFamily: AppTheme.mono,
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: AppTheme.cookPaper.withValues(alpha: .6)),
            ),
          ),
        ]),
      ),
    );
  }
}
