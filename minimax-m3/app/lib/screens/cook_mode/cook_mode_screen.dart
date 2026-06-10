import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_state.dart';
import '../../localization/i18n.dart';
import '../../models/history_entry.dart';
import '../../models/recipe.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../../theme/typography.dart';

/// Full-bleed dark cook mode with per-step timer, visual flash alert,
/// servings scaler, quick-tap step advance (opt-in), and a finish flow that
/// logs the recipe to history.
class CookModeScreen extends StatefulWidget {
  final Recipe recipe;
  const CookModeScreen({super.key, required this.recipe});

  @override
  State<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends State<CookModeScreen> {
  int _index = 0;
  bool _paused = false;
  bool _flashing = false;
  int _remainingSec = 0;
  Timer? _timer;
  DateTime? _lastQuickTap;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _resetTimerForStep();
  }

  @override
  void dispose() {
    _timer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _resetTimerForStep() {
    _timer?.cancel();
    final step = widget.recipe.steps[_index];
    _remainingSec = (step.timeMinutes ?? 0) * 60;
    setState(() {});
  }

  void _toggleTimer() {
    if (_remainingSec <= 0) {
      // Start: use step time as default; if none, prompt nothing.
      final step = widget.recipe.steps[_index];
      _remainingSec = (step.timeMinutes ?? 0) * 60;
      if (_remainingSec <= 0) return;
    }
    if (_timer != null && _timer!.isActive) {
      _timer?.cancel();
      setState(() => _paused = true);
    } else {
      _paused = false;
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_remainingSec <= 1) {
          t.cancel();
          _onTimerComplete();
        } else {
          setState(() => _remainingSec--);
        }
      });
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(I18n.of(context).timerStarted),
        duration: const Duration(milliseconds: 1200),
      ));
    }
  }

  Future<void> _onTimerComplete() async {
    HapticFeedback.heavyImpact();
    final profile = AppScope.of(context).profileRepo.profile;
    final reduce = profile.reduceMotion ?? (MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    if (!profile.visualAlertEnabled) {
      setState(() => _remainingSec = 0);
      return;
    }
    setState(() {
      _remainingSec = 0;
      _flashing = true;
    });
    final flashes = reduce ? 1 : 4;
    for (var i = 0; i < flashes; i++) {
      await Future.delayed(Duration(milliseconds: reduce ? 600 : 280));
      if (!mounted) return;
      setState(() => _flashing = !_flashing);
    }
    setState(() => _flashing = false);
  }

  void _next() {
    if (_index < widget.recipe.steps.length - 1) {
      setState(() => _index++);
      _resetTimerForStep();
    } else {
      _finish();
    }
  }

  void _prev() {
    if (_index > 0) {
      setState(() => _index--);
      _resetTimerForStep();
    }
  }

  void _quickTap() {
    final profile = AppScope.of(context).profileRepo.profile;
    if (!profile.quickNextTapEnabled) return;
    final now = DateTime.now();
    if (_lastQuickTap != null &&
        now.difference(_lastQuickTap!).inMilliseconds < 300) {
      return;
    }
    _lastQuickTap = now;
    HapticFeedback.lightImpact();
    _next();
  }

  void _finish() {
    setState(() => _completed = true);
  }

  Future<void> _logToHistory() async {
    final state = AppScope.of(context);
    await state.historyRepo.add(HistoryEntry(
      recipeId: widget.recipe.id,
      cookedAt: DateTime.now(),
    ));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = I18n.of(context);
    final theme = buildCookModeTheme();
    final step = widget.recipe.steps[_index];
    final state = AppScope.of(context);
    final lang = state.profileRepo.profile.lang;

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: _flashing ? MCColors.coral : MCColors.cookInk,
        body: SafeArea(
          child: GestureDetector(
            onTap: _quickTap,
            behavior: HitTestBehavior.opaque,
            child: _completed ? _CompletionView(
              onLog: _logToHistory,
              onSkip: () => Navigator.of(context).pop(),
            ) : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: MCColors.cookCream),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.recipe.name.resolve(lang).toLowerCase(),
                          style: MCTypography.italic(size: 18, color: MCColors.cookCream),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        s.stepOf
                            .replaceAll('{a}', '${_index + 1}')
                            .replaceAll('{b}', '${widget.recipe.steps.length}'),
                        style: MCTypography.eyebrow(color: MCColors.cookCream),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        step.text.resolve(lang),
                        style: MCTypography.body(
                          size: 28,
                          color: MCColors.cookCream,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (step.timeMinutes != null)
                    _TimerCard(
                      seconds: _remainingSec,
                      paused: _paused,
                      onToggle: _toggleTimer,
                    ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _index == 0 ? null : _prev,
                          icon: const Icon(Icons.chevron_left, size: 18),
                          label: Text(s.prev),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: MCColors.cookCream,
                            side: const BorderSide(color: MCColors.cookCream, width: 0.7),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _next,
                          icon: const Icon(Icons.chevron_right, size: 18),
                          label: Text(
                            _index == widget.recipe.steps.length - 1
                                ? s.finishCooking
                                : s.nextStep,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MCColors.coral,
                            foregroundColor: MCColors.cookCream,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (state.profileRepo.profile.quickNextTapEnabled)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Center(
                        child: Text(
                          s.quickTapAdvance,
                          style: MCTypography.eyebrow(color: MCColors.cookCream),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimerCard extends StatelessWidget {
  final int seconds;
  final bool paused;
  final VoidCallback onToggle;

  const _TimerCard({
    required this.seconds,
    required this.paused,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final s = I18n.of(context);
    final m = (seconds / 60).floor();
    final sec = seconds % 60;
    return InkWell(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          border: Border.all(color: MCColors.cookCream.withValues(alpha: 0.4), width: 0.7),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, color: MCColors.teal),
            const SizedBox(width: 12),
            Text(
              '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}',
              style: MCTypography.mono(size: 26, color: MCColors.cookCream),
            ),
            const Spacer(),
            Text(
              paused ? s.resume.toUpperCase() : s.pause.toUpperCase(),
              style: MCTypography.eyebrow(color: MCColors.cookCream),
            ),
            const SizedBox(width: 8),
            Icon(
              paused ? Icons.play_arrow : Icons.pause,
              color: MCColors.cookCream,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionView extends StatelessWidget {
  final VoidCallback onLog;
  final VoidCallback onSkip;

  const _CompletionView({required this.onLog, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final s = I18n.of(context);
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.cookingDone, style: MCTypography.display(size: 56, color: MCColors.cookCream)),
          const SizedBox(height: 14),
          Text(
            s.cookingDoneBody,
            style: MCTypography.italic(size: 20, color: MCColors.cookCream),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: onLog,
            icon: const Icon(Icons.menu_book, size: 18),
            label: Text(s.logToHistory),
            style: ElevatedButton.styleFrom(
              backgroundColor: MCColors.coral,
              foregroundColor: MCColors.cookCream,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onSkip,
            style: OutlinedButton.styleFrom(
              foregroundColor: MCColors.cookCream,
              side: const BorderSide(color: MCColors.cookCream),
            ),
            child: Text(s.done),
          ),
        ],
      ),
    );
  }
}
