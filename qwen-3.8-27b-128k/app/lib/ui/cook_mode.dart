/// Cook mode: dark full-bleed, one step at a time, per-step timer,
/// pause/resume with persisted progress, visual flash alert on timer
/// completion, quick-tap to advance.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../core/models.dart';
import '../state/store.dart';
import 'morph.dart';

class CookModeScreen extends StatefulWidget {
  const CookModeScreen({
    super.key,
    required this.recipeId,
    this.servings = 2,
  });
  final String recipeId;
  final int servings;

  @override
  State<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends State<CookModeScreen> {
  int stepIndex = 0;
  int servings = 2;
  bool paused = false;
  bool finished = false;
  DateTime? _deadline; // when the current step's timer ends
  Timer? _tick;
  DateTime? _lastTap;
  final Set<int> _done = {};

  Recipe? get _recipe => Morph.of(context).c.recipes[widget.recipeId];

  int _stepSeconds() {
    final r = _recipe;
    return r != null ? r.steps[stepIndex].seconds : 0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startFromSession();
    });
  }

  void _startFromSession() {
    final m = Morph.of(context);
    final r = _recipe;
    if (r == null) return;
    servings = widget.servings;
    final session = m.store.cookSession;
    if (session != null && session.recipeId == r.id) {
      stepIndex = session.stepIndex;
      servings = session.servings;
      paused = session.paused;
    }
    if (_stepSeconds() > 0 && !paused) {
      _startTimer();
    }
  }

  void _startTimer() {
    final secs = _stepSeconds();
    if (secs <= 0) return;
    _deadline = DateTime.now().add(Duration(seconds: secs));
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _pauseTimer() {
    paused = true;
    _tick?.cancel();
    _persist();
  }

  void _resumeTimer() {
    paused = false;
    if (_deadline != null && _deadline!.isAfter(DateTime.now())) {
      _tick?.cancel();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    } else {
      _startTimer();
    }
    _persist();
  }

  void _onTick() {
    if (!mounted) return;
    setState(() {});
    final now = DateTime.now();
    final dl = _deadline;
    if (dl != null && now.isAfter(dl)) {
      // timer complete
      _tick?.cancel();
      _deadline = null;
      if (Morph.of(context).profile.visualAlerts) {
        _flash();
      }
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _flash() async {
    if (Morph.of(context).profile.reduceMotion) return;
    const cycle = [Palette.cook, Palette.coral, Palette.cook, Palette.teal, Palette.cook];
    for (final c in cycle) {
      if (!mounted) return;
      if (c != Palette.cook) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: c,
          systemNavigationBarColor: c,
        ));
      }
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }
    if (!mounted) return;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  }

  void _persist() {
    final m = Morph.of(context);
    m.store.setSession(CookSession(
      recipeId: widget.recipeId,
      stepIndex: stepIndex,
      servings: servings,
      paused: paused,
      stepStartedAtEpochMs:
          DateTime.now().millisecondsSinceEpoch,
    ));
  }

  void _next() {
    final n = _recipe?.steps.length ?? 0;
    if (stepIndex + 1 >= n) {
      _finish();
      return;
    }
    setState(() {
      _done.add(stepIndex);
      stepIndex++;
    });
    _persist();
    _startTimerIfAny();
  }

  void _prev() {
    if (stepIndex > 0) {
      setState(() => stepIndex--);
      _persist();
      _startTimerIfAny();
    }
  }

  void _startTimerIfAny() {
    if (_stepSeconds() > 0) {
      paused = false;
      _startTimer();
    } else {
      _deadline = null;
      _tick?.cancel();
    }
    _persist();
  }

  void _finish() {
    if (finished) return;
    setState(() => finished = true);
    _tick?.cancel();
    final m = Morph.of(context);
    m.store.logCooked(widget.recipeId, servings: servings);
    m.store.setSession(null);
  }

  /// Quick-tap: tap anywhere on the step content advances. 300 ms debounce.
  void _quickTap() {
    final m = Morph.of(context);
    if (!m.profile.quickNextTap) return;
    if (m.profile.reduceMotion) return;
    final now = DateTime.now();
    if (_lastTap != null &&
        now.difference(_lastTap!).inMilliseconds < 300) {
      return;
    }
    _lastTap = now;
    HapticFeedback.selectionClick();
    _next();
  }

  int _remainingSeconds() {
    final dl = _deadline;
    if (dl == null) return 0;
    final s = dl.difference(DateTime.now()).inSeconds;
    return s.isNegative ? 0 : s;
  }

  String _fmt(int s) {
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = Morph.of(context);
    final r = _recipe;
    if (r == null) {
      return const Scaffold(
          backgroundColor: Palette.cook,
          body: Center(child: Text('recipe not found',
              style: TextStyle(color: Palette.paper))));
    }

    if (finished) {
      return _finishScreen(m);
    }

    final step = r.steps[stepIndex];
    final bg = Palette.cook;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                    icon: Icon(Icons.close, color: Palette.paper),
                    tooltip: m.t('common.close'),
                    onPressed: () => Navigator.pop(context)),
                const Spacer(),
                Text(m.t('cook.title').toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white54,
                        fontFamily: 'JetBrainsMono',
                        letterSpacing: 3,
                        fontSize: 11)),
                const Spacer(),
                SizedBox(
                    width: 24), // balance
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text('${m.t('cook.step')} ${stepIndex + 1}',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontFamily: 'JetBrainsMono',
                          fontSize: 13)),
                  Text(' / ${r.steps.length}',
                      style: const TextStyle(
                          color: Colors.white38,
                          fontFamily: 'JetBrainsMono',
                          fontSize: 13)),
                  const Spacer(),
                  Text('${m.t('cook.servings')}: $servings',
                      style: const TextStyle(
                          color: Colors.white54,
                          fontFamily: 'JetBrainsMono',
                          fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (stepIndex + 1) / r.steps.length,
                  minHeight: 4,
                  backgroundColor: Colors.white12,
                  color: Palette.coral,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GestureDetector(
                onTap: _quickTap,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (step.seconds > 0) ...[
                          const SizedBox(height: 6),
                          Text(
                            paused ? m.t('cook.pause') : _fmt(_remainingSeconds()),
                            style: const TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 44,
                                color: Palette.paper,
                                fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(m.t('cook.timer'),
                              style: const TextStyle(
                                  color: Colors.white54,
                                  fontFamily: 'JetBrainsMono',
                                  letterSpacing: 2,
                                  fontSize: 11)),
                          const SizedBox(height: 18),
                        ],
                        Text(
                          step.text.s(m.lang),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 17,
                              height: 1.5,
                              color: Palette.paper),
                        ),
                        if (m.profile.quickNextTap &&
                            !m.profile.reduceMotion) ...[
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.touch_app,
                                  size: 14, color: Colors.white38),
                              const SizedBox(width: 6),
                              Text(m.t('cook.quicktap'),
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontFamily: 'JetBrainsMono',
                                      fontSize: 11)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                  border:
                      Border(top: BorderSide(color: Colors.white12))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _DarkButton(
                      label: m.t('cook.prev'),
                      icon: Icons.chevron_left,
                      onTap: _prev,
                      enabled: stepIndex > 0),
                  const SizedBox(width: 12),
                  if (step.seconds > 0)
                    _DarkButton(
                        label: paused
                            ? m.t('cook.resume')
                            : m.t('cook.pause'),
                        icon:
                            paused ? Icons.play_arrow : Icons.pause,
                        onTap: () {
                          if (paused) {
                            _resumeTimer();
                          } else {
                            _pauseTimer();
                          }
                          setState(() {});
                        },
                        filled: !paused),
                  const SizedBox(width: 12),
                  _DarkButton(
                      label: (stepIndex + 1 >= r.steps.length)
                          ? m.t('cook.finish')
                          : m.t('cook.next'),
                      icon: Icons.chevron_right,
                      onTap: _next,
                      filled: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _finishScreen(MorphData m) {
    final r = _recipe!;
    return Scaffold(
      backgroundColor: Palette.cook,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check, size: 56, color: Palette.sage),
              const SizedBox(height: 18),
              Text(
                m.t('cook.done-title'),
                style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontStyle: FontStyle.italic,
                    fontSize: 28,
                    color: Palette.paper),
              ),
              const SizedBox(height: 10),
              Text(
                '${r.name.s(m.lang)} · ${m.t('cook.servings')} $servings',
                style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'JetBrainsMono',
                    fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(m.t('cook.logged'),
                  style: const TextStyle(
                      color: Colors.white54,
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12)),
              const SizedBox(height: 6),
              Text(m.t('cook.done-sub'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white38,
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12,
                      height: 1.5)),
              const SizedBox(height: 28),
              Align(
                alignment: Alignment.centerRight,
                child: _DarkButton(
                    label: m.t('common.close'), onTap: () => Navigator.pop(context), filled: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DarkButton extends StatelessWidget {
  const _DarkButton(
      {required this.label,
      required this.onTap,
      this.icon,
      this.filled = false,
      this.enabled = true});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool filled;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? Palette.coral : Colors.transparent;
    final fg =
        filled ? Colors.white : Colors.white.withValues(alpha: enabled ? 0.9 : 0.35);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: filled
                  ? Palette.coral
                  : Colors.white.withValues(alpha: enabled ? 0.4 : 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: fg,
                    fontFamily: 'JetBrainsMono')),
          ],
        ),
      ),
    );
  }
}
