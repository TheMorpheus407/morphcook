import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../logic/cook.dart';
import '../logic/units.dart';
import '../models/recipe.dart';
import 'strings.dart';
import 'theme.dart';

class CookModeScreen extends StatefulWidget {
  final Recipe recipe;
  const CookModeScreen({super.key, required this.recipe});

  @override
  State<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends State<CookModeScreen> {
  late CookSessionController _session;
  late OneHandedCookModeController _oneHand;
  bool _flashOn = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final resume = state.cookProgress?.recipeId == widget.recipe.id
        ? state.cookProgress
        : null;
    _session = CookSessionController(
      recipe: widget.recipe,
      persist: state.persistCookProgress,
      resumeFrom: resume,
    )..addListener(_onSession);
    _oneHand = OneHandedCookModeController(
      quickNextTapEnabled: state.profile.quickNextTapEnabled,
    );
  }

  bool _reduceMotion(AppState state) {
    if (state.profile.reduceMotion != null) return state.profile.reduceMotion!;
    return MediaQuery.disableAnimationsOf(context);
  }

  void _onSession() {
    if (_session.timerJustFinished) {
      _session.consumeTimerAlert();
      _alert();
    }
    setState(() {});
  }

  Future<void> _alert() async {
    final state = context.read<AppState>();
    if (!state.profile.visualAlertEnabled) return;
    if (_reduceMotion(state)) {
      setState(() => _flashOn = true);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) setState(() => _flashOn = false);
      return;
    }
    for (var i = 0; i < 6; i++) {
      if (!mounted) return;
      setState(() => _flashOn = !_flashOn);
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
    if (mounted) setState(() => _flashOn = false);
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final flashColor = !_flashOn
        ? InkPalette.night
        : (DateTime.now().millisecond % 2 == 0
            ? const Color(0xFFE07A5F)
            : const Color(0xFF5F8A86));

    if (_session.isCompleted) {
      return Scaffold(
        backgroundColor: InkPalette.night,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Text(
                  s('cookedIt'),
                  style: const TextStyle(
                    fontFamily: LedgerTheme.playfair,
                    fontStyle: FontStyle.italic,
                    fontSize: 36,
                    color: InkPalette.cream,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  s('cookAgainNote'),
                  style: const TextStyle(
                    fontFamily: LedgerTheme.caveat,
                    fontSize: 24,
                    color: Color(0xFFC4B6A2),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    await state.logCooked(widget.recipe.id);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: Text(
                    s('backToRecipe'),
                    style: const TextStyle(color: InkPalette.cream),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final step = widget.recipe.steps[_session.stepIndex];
    final remaining = _session.remainingSeconds;
    return Scaffold(
      backgroundColor: flashColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: InkPalette.cream),
                  ),
                  const Spacer(),
                  Text(
                    '${s('step')} ${_session.stepIndex + 1} ${s('of')} ${widget.recipe.steps.length}',
                    style: const TextStyle(
                      fontFamily: LedgerTheme.mono,
                      fontSize: 12,
                      color: Color(0xFFC4B6A2),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '${s('servings')}: ${_session.servings}',
                    style: const TextStyle(
                      fontFamily: LedgerTheme.mono,
                      color: Color(0xFFC4B6A2),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _session.setServings(_session.servings - 1),
                    icon: const Icon(Icons.remove, color: InkPalette.cream),
                  ),
                  IconButton(
                    onPressed: () => _session.setServings(_session.servings + 1),
                    icon: const Icon(Icons.add, color: InkPalette.cream),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_oneHand.handleTap()) {
                      if (!_reduceMotion(state)) {
                        HapticFeedback.selectionClick();
                      }
                      _session.nextStep();
                    }
                  },
                  child: ListView(
                    children: [
                      Text(
                        step.text.of(state.lang),
                        style: const TextStyle(
                          fontFamily: LedgerTheme.playfair,
                          fontSize: 26,
                          height: 1.35,
                          color: InkPalette.cream,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ...widget.recipe.ingredients.map((ing) {
                        final qty = Quantity(ing.qty, ing.unit)
                            .scaled(_session.scaleFactor);
                        final name = state.corpus.dictionary
                            .nameOf(ing.ingredientId, state.lang);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '${qty.display}  $name',
                            style: const TextStyle(
                              fontFamily: LedgerTheme.mono,
                              fontSize: 13,
                              color: Color(0xFFC4B6A2),
                            ),
                          ),
                        );
                      }),
                      if (state.profile.quickNextTapEnabled)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Text(
                            s('quickTapHint'),
                            style: const TextStyle(
                              fontFamily: LedgerTheme.caveat,
                              fontSize: 20,
                              color: Color(0xFF8E8272),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (remaining != null) ...[
                Text(
                  _fmt(remaining),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: LedgerTheme.mono,
                    fontSize: 42,
                    color: InkPalette.cream,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_session.isTimerRunning && !_session.isTimerPaused)
                      TextButton(
                        onPressed: _session.startTimer,
                        child: Text(
                          s('startTimer'),
                          style: const TextStyle(color: InkPalette.cream),
                        ),
                      ),
                    if (_session.isTimerRunning)
                      TextButton(
                        onPressed: _session.pauseTimer,
                        child: Text(
                          s('pause'),
                          style: const TextStyle(color: InkPalette.cream),
                        ),
                      ),
                    if (_session.isTimerPaused)
                      TextButton(
                        onPressed: _session.resumeTimer,
                        child: Text(
                          s('resume'),
                          style: const TextStyle(color: InkPalette.cream),
                        ),
                      ),
                  ],
                ),
              ],
              Row(
                children: [
                  TextButton(
                    onPressed:
                        _session.stepIndex == 0 ? null : _session.previousStep,
                    child: Text(
                      s('back'),
                      style: const TextStyle(color: Color(0xFFC4B6A2)),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _session.nextStep,
                    child: Text(
                      _session.isLastStep ? s('finishCooking') : s('next'),
                      style: const TextStyle(
                        color: InkPalette.cream,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }
}
