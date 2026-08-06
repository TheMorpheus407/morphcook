import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/corpus_repository.dart';
import '../../data/models.dart';
import '../../state/app_model.dart';
import '../../state/library_model.dart';

/// Cook mode: dark full-bleed, step-by-step, per-step timer, servings
/// scaler, prev/next, pause/resume with progress persistence, completion
/// screen. Visual flash alert on timer completion; quick-tap advances.
class CookScreen extends StatefulWidget {
  final String recipeId;
  const CookScreen({super.key, required this.recipeId});

  @override
  State<CookScreen> createState() => _CookScreenState();
}

class _CookScreenState extends State<CookScreen>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  int _servings = 2;
  bool _paused = false;
  bool _done = false;

  // Timer state for the current step.
  int? _timerTotal;
  int _timerRemaining = 0;
  bool _timerRunning = false;
  bool _timerFinished = false;
  Timer? _ticker;

  // Flash alert animation.
  late final AnimationController _flashController;
  bool _flashActive = false;

  DateTime _lastQuickTap = DateTime.fromMillisecondsSinceEpoch(0);

  Recipe? _recipe;

  bool get _reduceMotion {
    final profile = context.read<AppModel>().profile;
    return profile.reduceMotion ??
        MediaQuery.of(context).disableAnimations;
  }

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_recipe != null) return;
    final corpus = context.read<CorpusRepository>();
    final recipe = corpus.recipe(widget.recipeId);
    if (recipe == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }
    _recipe = recipe;
    _servings = recipe.servings;
    // Resume persisted progress.
    final library = context.read<LibraryModel>();
    final saved = library.cookProgress()[widget.recipeId];
    if (saved != null && saved > 0 && saved < recipe.steps.length) {
      _step = saved;
      _paused = true;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _flashController.dispose();
    super.dispose();
  }

  void _configureTimerForStep() {
    _ticker?.cancel();
    final recipe = _recipe!;
    final timer = recipe.steps[_step].timerSeconds;
    _timerTotal = timer;
    _timerRemaining = timer ?? 0;
    _timerRunning = false;
    _timerFinished = false;
    _flashActive = false;
    _flashController.stop();
  }

  void _startTimer() {
    if (_timerTotal == null || _timerRunning || _timerFinished) return;
    setState(() => _timerRunning = true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _timerRemaining--;
        if (_timerRemaining <= 0) {
          _timerRemaining = 0;
          _timerRunning = false;
          _timerFinished = true;
          _ticker?.cancel();
          _onTimerDone();
        }
      });
    });
  }

  void _pauseTimer() {
    _ticker?.cancel();
    setState(() => _timerRunning = false);
  }

  void _onTimerDone() {
    final profile = context.read<AppModel>().profile;
    if (!profile.visualAlertEnabled) return;
    if (_reduceMotion) {
      // Static highlight instead of flashing.
      setState(() => _flashActive = true);
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _flashActive = false);
      });
      return;
    }
    setState(() => _flashActive = true);
    _flashController.repeat(reverse: true);
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      _flashController.stop();
      setState(() => _flashActive = false);
    });
  }

  void _goto(int index) {
    final recipe = _recipe!;
    if (index < 0 || index >= recipe.steps.length) return;
    setState(() {
      _step = index;
      _configureTimerForStep();
    });
    context
        .read<LibraryModel>()
        .saveCookProgress(widget.recipeId, index);
  }

  void _next() {
    final recipe = _recipe!;
    if (_step + 1 >= recipe.steps.length) {
      _complete();
    } else {
      _goto(_step + 1);
    }
  }

  void _prev() => _goto(_step - 1);

  void _complete() {
    final library = context.read<LibraryModel>();
    library.clearCookProgress(widget.recipeId);
    library.recordCooked(widget.recipeId);
    setState(() => _done = true);
  }

  void _quickTapAdvance() {
    final profile = context.read<AppModel>().profile;
    if (!profile.quickNextTapEnabled) return;
    final now = DateTime.now();
    if (now.difference(_lastQuickTap).inMilliseconds < 300) return;
    _lastQuickTap = now;
    HapticFeedback.lightImpact();
    _next();
  }

  void _pause() {
    _pauseTimer();
    context
        .read<LibraryModel>()
        .saveCookProgress(widget.recipeId, _step);
    setState(() => _paused = true);
  }

  void _resume() {
    setState(() => _paused = false);
  }

  String _fmt(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppModel>();
    final s = app.strings;
    final lang = app.lang;
    final recipe = _recipe;
    if (recipe == null) {
      return const Scaffold(
          backgroundColor: Paper.night, body: SizedBox.shrink());
    }

    if (_done) {
      return _CompletionScreen(
        recipe: recipe,
        onAgain: () => setState(() {
          _done = false;
          _step = 0;
          _configureTimerForStep();
        }),
        onExit: () => Navigator.of(context).pop(),
      );
    }

    final step = recipe.steps[_step];
    final progress = (_step + 1) / recipe.steps.length;
    final scaleFactor = _servings / recipe.servings;

    return Scaffold(
      backgroundColor: Paper.night,
      body: AnimatedBuilder(
        animation: _flashController,
        builder: (context, child) {
          final flashColor = _flashActive
              ? Color.lerp(
                  Paper.coral,
                  Paper.teal,
                  _reduceMotion ? 0 : _flashController.value,
                )!.withValues(alpha: _reduceMotion ? 0.25 : 0.4)
              : Colors.transparent;
          return Container(
            decoration: BoxDecoration(
              border: Border.all(color: flashColor, width: 14),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: Column(
            children: [
              // ---- top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        _pause();
                        Navigator.of(context).pop();
                      },
                      child: Text('✕',
                          style: Type.mono(
                              size: 16, color: Paper.nightInk)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        tx(recipe.title, lang),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Type.display(size: 17, color: Paper.nightInk),
                      ),
                    ),
                    GestureDetector(
                      onTap: _paused ? _resume : _pause,
                      child: Text(
                        _paused ? '▶ ${s.get('resume')}' : '❚❚ ${s.get('pause')}',
                        style: Type.mono(size: 11, color: Paper.coralSoft),
                      ),
                    ),
                  ],
                ),
              ),
              // ---- progress rule
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: Paper.nightSoft,
                    color: Paper.coral,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    Text(
                      '${s.get('step')} ${_step + 1} ${s.get('of')} ${recipe.steps.length}',
                      style: Type.mono(size: 10.5, color: Paper.tealSoft),
                    ),
                    const Spacer(),
                    // ---- servings scaler
                    Text('${s.get('servings')}:',
                        style:
                            Type.mono(size: 10.5, color: Paper.nightInk)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() {
                        if (_servings > 1) _servings--;
                      }),
                      child: Text('−',
                          style: Type.mono(
                              size: 16, color: Paper.nightInk)),
                    ),
                    const SizedBox(width: 10),
                    Text('$_servings',
                        style: Type.mono(
                            size: 13, color: Paper.nightInk)),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => setState(() {
                        if (_servings < 12) _servings++;
                      }),
                      child: Text('+',
                          style: Type.mono(
                              size: 16, color: Paper.nightInk)),
                    ),
                  ],
                ),
              ),
              // ---- step content (tap target for quick advance)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _quickTapAdvance,
                  child: _paused
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(s.get('pause'),
                                  style: Type.display(
                                      size: 34, color: Paper.nightInk)),
                              const SizedBox(height: 18),
                              GestureDetector(
                                onTap: _resume,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 26, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Paper.coralSoft),
                                  ),
                                  child: Text('▶ ${s.get('resume')}',
                                      style: Type.mono(
                                          size: 12,
                                          color: Paper.coralSoft)),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 26, vertical: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (app.profile.quickNextTapEnabled)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(s.get('quickTapHint'),
                                      style: Type.mono(
                                          size: 9.5,
                                          color: Paper.nightInk
                                              .withValues(alpha: 0.4))),
                                ),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx(step.text, lang),
                                        style: Type.display(
                                            size: 26,
                                            color: Paper.nightInk),
                                      ),
                                      const SizedBox(height: 20),
                                      // scaled ingredients hint for this step
                                      if (step.timerSeconds != null)
                                        _TimerBlock(
                                          total: _timerTotal!,
                                          remaining: _timerRemaining,
                                          running: _timerRunning,
                                          finished: _timerFinished,
                                          fmt: _fmt,
                                          onStart: _startTimer,
                                          onPause: _pauseTimer,
                                          startLabel: s.get('start'),
                                          pauseLabel: s.get('pause'),
                                          doneLabel: s.get('timerDone'),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              // ---- scaled ingredient strip
              if (!_paused)
                SizedBox(
                  height: 66,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      for (final i in recipe.ingredients)
                        if (!i.optional)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Paper.nightInk
                                      .withValues(alpha: 0.25)),
                            ),
                            child: Text(
                              '${_fmtQty(i.qty * scaleFactor)} ${i.unit} ${tx(context.read<CorpusRepository>().ingredients[i.ingredientId]?.name, lang)}',
                              style: Type.mono(
                                  size: 10, color: Paper.nightInk),
                            ),
                          ),
                    ],
                  ),
                ),
              // ---- prev / next
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _step > 0 ? _prev : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 13),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _step > 0
                                ? Paper.nightInk
                                : Paper.nightInk.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text('← ${s.get('prev')}',
                            style: Type.mono(
                                size: 12,
                                color: _step > 0
                                    ? Paper.nightInk
                                    : Paper.nightInk
                                        .withValues(alpha: 0.25))),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _next,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 26, vertical: 13),
                        decoration: const BoxDecoration(
                          color: Paper.coral,
                        ),
                        child: Text(
                          _step + 1 >= recipe.steps.length
                              ? '${s.get('done')} ✓'
                              : '${s.get('next')} →',
                          style: Type.mono(size: 12, color: Paper.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtQty(double qty) {
    if ((qty - qty.roundToDouble()).abs() < 0.05) return qty.round().toString();
    return qty.toStringAsFixed(1);
  }
}

class _TimerBlock extends StatelessWidget {
  final int total;
  final int remaining;
  final bool running;
  final bool finished;
  final String Function(int) fmt;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final String startLabel;
  final String pauseLabel;
  final String doneLabel;

  const _TimerBlock({
    required this.total,
    required this.remaining,
    required this.running,
    required this.finished,
    required this.fmt,
    required this.onStart,
    required this.onPause,
    required this.startLabel,
    required this.pauseLabel,
    required this.doneLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: finished
            ? Paper.teal.withValues(alpha: 0.25)
            : Paper.nightSoft,
        border: Border.all(
          color: finished ? Paper.tealSoft : Paper.nightInk.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Text(
            fmt(remaining),
            style: Type.mono(size: 26, color: Paper.nightInk),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : 1 - remaining / total,
                minHeight: 4,
                backgroundColor: Paper.night,
                color: finished ? Paper.tealSoft : Paper.coral,
              ),
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: finished ? null : (running ? onPause : onStart),
            child: Text(
              finished ? '✓ $doneLabel' : (running ? '❚❚' : '▶'),
              style: Type.mono(size: 14, color: Paper.coralSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionScreen extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onAgain;
  final VoidCallback onExit;

  const _CompletionScreen({
    required this.recipe,
    required this.onAgain,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: Paper.night,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('✳', style: Type.mono(size: 30, color: Paper.coral)),
                const SizedBox(height: 18),
                Text(s.get('wellDone'),
                    style: Type.display(size: 38, color: Paper.nightInk)),
                const SizedBox(height: 8),
                Text(tx(recipe.title, S.of(context).lang),
                    style: Type.hand(size: 22, color: Paper.tealSoft)),
                const SizedBox(height: 36),
                GestureDetector(
                  onTap: onAgain,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Paper.nightInk),
                    ),
                    child: Text(s.get('again'),
                        style:
                            Type.mono(size: 12, color: Paper.nightInk)),
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: onExit,
                  child: Text(s.get('exit'),
                      style: Type.mono(size: 11, color: Paper.tealSoft)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
