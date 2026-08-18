import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/recipe.dart';
import '../theme/vintage_theme.dart';
import '../widgets/vintage_widgets.dart';

class OneHandedCookModeController {
  final bool quickNextTapEnabled;
  DateTime? _lastTapTime;

  OneHandedCookModeController({this.quickNextTapEnabled = true});

  bool canTriggerTap() {
    if (!quickNextTapEnabled) return false;
    final now = DateTime.now();
    if (_lastTapTime == null || now.difference(_lastTapTime!).inMilliseconds > 300) {
      _lastTapTime = now;
      return true;
    }
    return false;
  }
}

class CookModeScreen extends StatefulWidget {
  final Recipe recipe;
  final int initialServings;

  const CookModeScreen({
    super.key,
    required this.recipe,
    this.initialServings = 2,
  });

  @override
  State<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends State<CookModeScreen> with TickerProviderStateMixin {
  int _currentStepIndex = 0;
  late int _servings;
  int _elapsedTotalSeconds = 0;
  Timer? _sessionTimer;

  // Step timer
  Timer? _stepCountdownTimer;
  int _stepRemainingSeconds = 0;
  bool _isStepTimerRunning = false;

  // Visual flash alert for accessibility
  bool _isFlashing = false;
  Color _flashColor = VintageColors.cookAccent;
  Timer? _flashTimer;

  late OneHandedCookModeController _oneHandedController;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _servings = widget.initialServings;

    final appState = Provider.of<AppState>(context, listen: false);
    final profile = appState.profile;

    _oneHandedController = OneHandedCookModeController(
      quickNextTapEnabled: profile.quickNextTapEnabled,
    );

    // Check if resuming active session
    if (appState.activeCookSession != null &&
        appState.activeCookSession!.recipeId == widget.recipe.id) {
      _currentStepIndex = appState.activeCookSession!.currentStepIndex.clamp(0, widget.recipe.steps.length - 1);
      _elapsedTotalSeconds = appState.activeCookSession!.elapsedSeconds;
      _servings = appState.activeCookSession!.servings;
    }

    _startSessionTimer();
    _initCurrentStepTimer();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _stepCountdownTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsedTotalSeconds++;
      });
      Provider.of<AppState>(context, listen: false).updateCookSession(
        stepIndex: _currentStepIndex,
        elapsedSeconds: _elapsedTotalSeconds,
      );
    });
  }

  void _initCurrentStepTimer() {
    _stepCountdownTimer?.cancel();
    _isStepTimerRunning = false;
    _stopVisualFlash();

    final step = widget.recipe.steps[_currentStepIndex];
    if (step.timerMinutes != null && step.timerMinutes! > 0) {
      _stepRemainingSeconds = step.timerMinutes! * 60;
    } else {
      _stepRemainingSeconds = 0;
    }
  }

  void _toggleStepTimer() {
    if (_isStepTimerRunning) {
      _stepCountdownTimer?.cancel();
      setState(() => _isStepTimerRunning = false);
    } else {
      if (_stepRemainingSeconds <= 0) return;
      setState(() => _isStepTimerRunning = true);
      _stepCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_stepRemainingSeconds > 1) {
          setState(() => _stepRemainingSeconds--);
        } else {
          _stepCountdownTimer?.cancel();
          setState(() {
            _stepRemainingSeconds = 0;
            _isStepTimerRunning = false;
          });
          _triggerTimerCompletedAlert();
        }
      });
    }
  }

  void _resetStepTimer() {
    _stepCountdownTimer?.cancel();
    _stopVisualFlash();
    setState(() {
      _isStepTimerRunning = false;
      final step = widget.recipe.steps[_currentStepIndex];
      _stepRemainingSeconds = (step.timerMinutes ?? 0) * 60;
    });
  }

  void _triggerTimerCompletedAlert() {
    HapticFeedback.heavyImpact();

    final appState = Provider.of<AppState>(context, listen: false);
    final visualEnabled = appState.profile.visualAlertEnabled;
    final reduceMotion = appState.profile.reduceMotion ?? false;

    if (visualEnabled && !reduceMotion) {
      int flashes = 0;
      _flashTimer?.cancel();
      _flashTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
        setState(() {
          _isFlashing = !_isFlashing;
          _flashColor = flashes % 2 == 0 ? VintageColors.cookAccent : VintageColors.cookFlashTeal;
        });
        flashes++;
        if (flashes >= 8) {
          timer.cancel();
          _stopVisualFlash();
        }
      });
    }
  }

  void _stopVisualFlash() {
    _flashTimer?.cancel();
    if (_isFlashing) {
      setState(() => _isFlashing = false);
    }
  }

  void _nextStep() {
    _stopVisualFlash();
    if (_currentStepIndex < widget.recipe.steps.length - 1) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentStepIndex++;
      });
      _initCurrentStepTimer();
    } else {
      _finishCooking();
    }
  }

  void _prevStep() {
    _stopVisualFlash();
    if (_currentStepIndex > 0) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentStepIndex--;
      });
      _initCurrentStepTimer();
    }
  }

  void _handleQuickTap() {
    if (_oneHandedController.canTriggerTap()) {
      _nextStep();
    }
  }

  void _finishCooking() {
    _sessionTimer?.cancel();
    _stepCountdownTimer?.cancel();
    _stopVisualFlash();

    final minutes = (_elapsedTotalSeconds / 60).ceil();
    Provider.of<AppState>(context, listen: false).completeCookSession(
      widget.recipe.id,
      minutes,
      _servings,
    );

    setState(() {
      _isCompleted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final lang = appState.lang;

    if (_isCompleted) {
      return _buildCompletionScreen(context, lang);
    }

    final step = widget.recipe.steps[_currentStepIndex];
    final totalSteps = widget.recipe.steps.length;
    final progress = (_currentStepIndex + 1) / totalSteps;

    return Scaffold(
      backgroundColor: _isFlashing ? _flashColor : VintageColors.cookBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: VintageColors.cookTextMuted),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  Column(
                    children: [
                      Text(
                        widget.recipe.title.get(lang).toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: VintageColors.cookTextMuted,
                        ),
                      ),
                      Text(
                        'STEP ${_currentStepIndex + 1} OF $totalSteps',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                          color: VintageColors.cookText,
                        ),
                      ),
                    ],
                  ),
                  // Elapsed time counter
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: VintageColors.cookCard,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: VintageColors.cookBorder),
                    ),
                    child: Text(
                      _formatDuration(_elapsedTotalSeconds),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: VintageColors.cookAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Linear Step Progress Bar
            Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: VintageColors.cookBorder,
                valueColor: const AlwaysStoppedAnimation<Color>(VintageColors.cookAccent),
              ),
            ),
            const SizedBox(height: 16),

            // Step Content (Quick-tap target)
            Expanded(
              child: GestureDetector(
                onTap: _handleQuickTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: VintageColors.cookCard,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: VintageColors.cookBorder),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'PHASE 0${_currentStepIndex + 1}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: VintageColors.cookAccent,
                              ),
                            ),
                            if (appState.profile.quickNextTapEnabled)
                              Text(
                                lang == 'de' ? 'Tippen zum Weitergehen' : 'Tap card to advance',
                                style: GoogleFonts.caveat(
                                  fontSize: 14,
                                  color: VintageColors.cookTextMuted,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          step.instruction.get(lang),
                          style: GoogleFonts.ebGaramond(
                            fontSize: 24,
                            height: 1.4,
                            color: VintageColors.cookText,
                          ),
                        ),
                        if (step.tip != null) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: VintageColors.cookBg,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: VintageColors.cookBorder),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.lightbulb, color: VintageColors.mustard, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    step.tip!.get(lang),
                                    style: GoogleFonts.caveat(
                                      fontSize: 17,
                                      color: VintageColors.cookText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Step Countdown Timer Widget
                        if (step.timerMinutes != null && step.timerMinutes! > 0) ...[
                          const SizedBox(height: 28),
                          _buildStepTimerWidget(lang),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bottom Navigation Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (_currentStepIndex > 0)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: VintageColors.cookText,
                        side: const BorderSide(color: VintageColors.cookBorder),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onPressed: _prevStep,
                      child: Text(
                        lang == 'de' ? 'Zurück' : 'Previous',
                        style: GoogleFonts.jetBrainsMono(),
                      ),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: VintageColors.cookAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    icon: Icon(
                      _currentStepIndex == totalSteps - 1 ? Icons.check_circle_outline : Icons.arrow_forward,
                    ),
                    label: Text(
                      _currentStepIndex == totalSteps - 1
                          ? (lang == 'de' ? 'GERICHT FERTIG' : 'FINISH COOKING')
                          : (lang == 'de' ? 'NÄCHSTER SCHRITT' : 'NEXT STEP'),
                      style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, letterSpacing: 1.1),
                    ),
                    onPressed: _nextStep,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepTimerWidget(String lang) {
    final mins = (_stepRemainingSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_stepRemainingSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VintageColors.cookBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _isStepTimerRunning ? VintageColors.cookAccent : VintageColors.cookBorder,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                color: _isStepTimerRunning ? VintageColors.cookAccent : VintageColors.cookTextMuted,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                '$mins:$secs',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _isStepTimerRunning ? VintageColors.cookAccent : VintageColors.cookText,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, color: VintageColors.cookTextMuted),
                onPressed: _resetStepTimer,
              ),
              const SizedBox(width: 4),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _isStepTimerRunning ? VintageColors.cookBorder : VintageColors.cookAccent,
                ),
                onPressed: _toggleStepTimer,
                child: Text(
                  _isStepTimerRunning
                      ? (lang == 'de' ? 'Pause' : 'Pause')
                      : (lang == 'de' ? 'Start' : 'Start'),
                  style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionScreen(BuildContext context, String lang) {
    return Scaffold(
      backgroundColor: VintageColors.paperBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: VintageColors.sage.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: VintageColors.sage, width: 2),
                  ),
                  child: const Icon(Icons.star, color: VintageColors.sage, size: 40),
                ),
                const SizedBox(height: 20),
                Text(
                  lang == 'de' ? 'Guten Appetit!' : 'Bon Appétit!',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    color: VintageColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.recipe.title.get(lang),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: VintageColors.terracotta,
                  ),
                ),
                const SizedBox(height: 16),
                const VintageDivider(symbol: '✦'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: VintageColors.paperCard,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: VintageColors.paperBorder),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(lang == 'de' ? 'Zubereitungszeit' : 'Time in Kitchen', style: GoogleFonts.ebGaramond(fontSize: 16)),
                          Text(_formatDuration(_elapsedTotalSeconds), style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(lang == 'de' ? 'Portionen zubereitet' : 'Servings Prepared', style: GoogleFonts.ebGaramond(fontSize: 16)),
                          Text('$_servings', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(lang == 'de' ? 'Kalorien / Portion' : 'Calories / Serving', style: GoogleFonts.ebGaramond(fontSize: 16)),
                          Text('~${widget.recipe.caloriesPerServing} kcal', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                HandwrittenNote(
                  text: lang == 'de'
                      ? 'Erfolgreich im Küchenjournal vermerkt.'
                      : 'Cook recorded in your kitchen chronicle history.',
                  author: 'MorphCook',
                ),
                const SizedBox(height: 28),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: VintageColors.terracotta,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    lang == 'de' ? 'ZURÜCK ZUM KOCHBUCH' : 'BACK TO NOTEBOOK',
                    style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
