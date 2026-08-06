import 'dart:async';

import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../data/services.dart';
import '../models/models.dart';

/// Guided step-by-step cooking. Per-step countdown timers, pause/resume,
/// restart and an in-page completion screen that writes cooking history.
/// With quick-tap enabled the whole step area advances on tap.
class CookModePage extends StatefulWidget {
  final Recipe recipe;
  final int servings;

  const CookModePage({super.key, required this.recipe, required this.servings});

  @override
  State<CookModePage> createState() => _CookModePageState();
}

class _CookModePageState extends State<CookModePage> {
  int _step = 0;
  Duration _remaining = Duration.zero;
  Timer? _timer;
  bool _paused = false;
  bool _finished = false;
  bool _flashing = false;
  bool _pulse = false;
  Timer? _flashTimer;
  Timer? _pulseTimer;

  late bool _quickTap;
  late bool _visualAlert;
  late bool _reduceMotion;
  late String _lang;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = Services.of(context).state.profile;
    _quickTap = profile.quickNextTapEnabled;
    _visualAlert = profile.visualAlertEnabled;
    _reduceMotion = Services.of(context).state.reduceMotionEnabled;
    _lang = profile.lang;
  }

  @override
  void initState() {
    super.initState();
    _startStep();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flashTimer?.cancel();
    _pulseTimer?.cancel();
    super.dispose();
  }

  String t(String k) => L10n.strings(_lang, k);

  /// (Re)starts the current step's timer with no rebuild.
  void _startStep() {
    _timer?.cancel();
    _timer = null;
    _flashTimer?.cancel();
    _pulseTimer?.cancel();
    _flashing = false;
    _pulse = false;
    _paused = false;
    final secs = widget.recipe.steps[_step].timerSeconds;
    _remaining = Duration(seconds: secs);
    if (secs > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    }
  }

  void _goTo(int step) {
    setState(() {
      _step = step;
      _startStep();
    });
  }

  void _next() =>
      _step >= widget.recipe.steps.length - 1 ? _finish() : _goTo(_step + 1);

  void _prev() {
    if (_step > 0) _goTo(_step - 1);
  }

  void _startFresh() {
    setState(() {
      _finished = false;
      _step = 0;
      _startStep();
    });
  }

  void _finish() {
    Services.of(context).state.recordCook(widget.recipe.id);
    setState(() => _finished = true);
  }

  void _togglePause() => setState(() => _paused = !_paused);

  void _tick(Timer t) {
    if (!mounted) return;
    if (_paused) return;
    if (_remaining.inSeconds <= 1) {
      t.cancel();
      _timer = null;
      setState(() => _remaining = Duration.zero);
      _onTimerZero();
    } else {
      setState(() => _remaining -= const Duration(seconds: 1));
    }
  }

  void _onTimerZero() {
    if (_visualAlert && !_reduceMotion) {
      setState(() {
        _flashing = true;
        _pulse = true;
      });
      _pulseTimer = Timer.periodic(const Duration(milliseconds: 400), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => _pulse = !_pulse);
      });
      _flashTimer = Timer(const Duration(seconds: 3), () {
        _pulseTimer?.cancel();
        if (!mounted) return;
        setState(() {
          _flashing = false;
          _pulse = false;
        });
        if (_quickTap) _next();
      });
    } else if (_quickTap) {
      _next();
    }
  }

  String _mmss(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.recipe.steps;
    if (_finished || steps.isEmpty) {
      return Scaffold(body: _completion(context));
    }
    final step = steps[_step];
    final isLast = _step == steps.length - 1;
    return Scaffold(
      body: GestureDetector(
        onTap: _quickTap ? _next : null,
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _step / steps.length,
                    minHeight: 3,
                    backgroundColor: AppColors.lineDotted,
                    color: AppColors.accent,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${t(L10n.tStep)} ${_step + 1} of ${steps.length}',
                        style: AppText.serif(context,
                            size: 14, color: AppColors.inkSoft),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        T(step.text, _lang),
                        style: AppText.serif(context,
                            size: 26, weight: FontWeight.w700, height: 1.35),
                      ),
                      if (step.timerSeconds > 0) ...[
                        const SizedBox(height: 22),
                        Center(child: _timerChip()),
                      ],
                      if (_quickTap) ...[
                        const SizedBox(height: 18),
                        Center(
                          child: Text(t(L10n.tTapToAdvance),
                              style: AppText.mono(context,
                                  size: 10, color: AppColors.inkFaint)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (!_quickTap)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _step > 0 ? _prev : null,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const Spacer(),
                      if (!isLast)
                        IconButton(
                          onPressed: _next,
                          icon: const Icon(Icons.arrow_forward),
                        ),
                    ],
                  ),
                ),
              _bottomBar(isLast),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timerChip() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: _flashing
            ? (_pulse ? AppColors.highlight : AppColors.paperBright)
            : AppColors.paperBright,
        border: Border.all(
          color: _flashing
              ? (_pulse ? AppColors.error : AppColors.accent)
              : AppColors.lineDotted,
          width: _flashing ? 3 : 1.2,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _mmss(_remaining),
        style: AppText.mono(
          context,
          size: 30,
          color: _flashing ? AppColors.error : AppColors.ink,
        ),
      ),
    );
  }

  Widget _bottomBar(bool isLast) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              onPressed: _togglePause,
              icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
              tooltip: _paused ? t(L10n.tResume) : t(L10n.tPause),
            ),
            IconButton(
              onPressed: _startFresh,
              icon: const Icon(Icons.replay),
              tooltip: t(L10n.tStartFresh),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
            const Spacer(),
            if (isLast)
              FilledButton.icon(
                onPressed: _finish,
                icon: const Icon(Icons.check),
                label: Text(t(L10n.tDone)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _completion(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t(L10n.tCooked),
                textAlign: TextAlign.center,
                style: AppText.mono(context, size: 10, color: AppColors.accent)
                    .copyWith(letterSpacing: 2),
              ),
              const SizedBox(height: 10),
              Text(
                t(L10n.tYouDidIt),
                textAlign: TextAlign.center,
                style: AppText.serif(context,
                    size: 34, weight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                t(L10n.tCompletionLine),
                textAlign: TextAlign.center,
                style: AppText.serif(context,
                    size: 16, color: AppColors.inkSoft, height: 1.4),
              ),
              const SizedBox(height: 26),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: Text(t(L10n.tDone)),
                  ),
                  FilledButton.icon(
                    onPressed: _startFresh,
                    icon: const Icon(Icons.replay),
                    label: Text(t(L10n.tStartFresh)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}