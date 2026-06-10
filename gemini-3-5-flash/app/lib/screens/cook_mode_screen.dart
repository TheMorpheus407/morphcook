import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/brand_theme.dart';

class CookModeScreen extends StatefulWidget {
  final Recipe recipe;
  final int servings;

  const CookModeScreen({
    super.key,
    required this.recipe,
    required this.servings,
  });

  @override
  State<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends State<CookModeScreen> with SingleTickerProviderStateMixin {
  int _currentStepIndex = 0;
  bool _isCookComplete = false;

  // Timer fields
  Timer? _countdownTimer;
  int _secondsRemaining = 0;
  bool _isTimerRunning = false;
  int _originalTimerSeconds = 0;

  // Visual Alert Flashing fields
  bool _isFlashingAlert = false;
  Color _flashColor = Colors.transparent;
  Timer? _flashTimer;

  // Debounce for quick-tap next
  DateTime? _lastTapTime;

  // Settings mock variables (linked to provider preferences)
  bool _visualAlertEnabled = true;
  bool _quickNextTapEnabled = true;

  @override
  void initState() {
    super.initState();
    _initStepTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  void _initStepTimer() {
    _countdownTimer?.cancel();
    _isTimerRunning = false;
    _isFlashingAlert = false;
    _flashTimer?.cancel();

    final step = widget.recipe.steps[_currentStepIndex];
    _originalTimerSeconds = step.timerSeconds;
    _secondsRemaining = step.timerSeconds;
  }

  // Timer Controls
  void _startTimer() {
    if (_secondsRemaining <= 0) return;
    setState(() {
      _isTimerRunning = true;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        setState(() {
          _secondsRemaining = 0;
          _isTimerRunning = false;
        });
        _countdownTimer?.cancel();
        _onTimerCompleted();
      }
    });
  }

  void _pauseTimer() {
    setState(() {
      _isTimerRunning = false;
    });
    _countdownTimer?.cancel();
  }

  void _resetTimer() {
    _pauseTimer();
    setState(() {
      _secondsRemaining = _originalTimerSeconds;
      _isFlashingAlert = false;
      _flashTimer?.cancel();
    });
  }

  void _onTimerCompleted() {
    // Trigger standard haptic feedback
    HapticFeedback.vibrate();

    // Trigger visual flash alert (coral/teal) for accessibility
    final provider = Provider.of<AppProvider>(context, listen: false);
    final reduceMotion = provider.profile.reduceMotion ?? false;

    if (_visualAlertEnabled) {
      setState(() {
        _isFlashingAlert = true;
      });

      int flashCount = 0;
      _flashTimer = Timer.periodic(
        Duration(milliseconds: reduceMotion ? 1000 : 400),
        (timer) {
          if (flashCount < 6) {
            setState(() {
              _flashColor = flashCount % 2 == 0 ? BrandColors.coral : BrandColors.teal;
            });
            flashCount++;
          } else {
            setState(() {
              _isFlashingAlert = false;
              _flashColor = Colors.transparent;
            });
            _flashTimer?.cancel();
          }
        },
      );
    }
  }

  // Quick-tap gesture to advance with 300ms debounce & haptic feedback
  void _handleQuickTapAdvance() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final reduceMotion = provider.profile.reduceMotion ?? false;

    if (!_quickNextTapEnabled) return;

    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!) < const Duration(milliseconds: 300)) {
      return; // Debounce block
    }
    _lastTapTime = now;

    if (!reduceMotion) {
      HapticFeedback.mediumImpact();
    }

    _nextStep();
  }

  void _nextStep() {
    if (_currentStepIndex < widget.recipe.steps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
      _initStepTimer();
    } else {
      // Completed last step!
      setState(() {
        _isCookComplete = true;
      });
      // Log cooking to history
      Provider.of<AppProvider>(context, listen: false).logCooking(widget.recipe.id);
    }
  }

  void _prevStep() {
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
      });
      _initStepTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final isEn = provider.currentLanguage == 'en';
    final step = widget.recipe.steps[_currentStepIndex];
    final progress = _originalTimerSeconds > 0 ? _secondsRemaining / _originalTimerSeconds : 0.0;

    // Dark-theme visual colors
    const Color darkBg = Color(0xFF161616);
    const Color darkSurface = Color(0xFF222222);
    const Color darkText = Color(0xFFE5E0D8);
    const Color darkMuted = Color(0xFF9E9A90);

    return Scaffold(
      backgroundColor: darkBg,
      body: Stack(
        children: [
          // Main Body
          SafeArea(
            child: Column(
              children: [
                // Top header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: darkText),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        isEn ? "cook mode" : "kochmodus",
                        style: BrandFonts.handwritten(fontSize: 22.0, color: BrandColors.coral),
                      ),
                      Text(
                        "${_currentStepIndex + 1}/${widget.recipe.steps.length}",
                        style: BrandFonts.mono(fontSize: 14.0, color: darkMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 1.0,
                  color: darkSurface,
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: _isCookComplete 
                      ? _buildCompletionView(isEn, darkText, darkMuted)
                      : _buildActiveStepView(step, progress, isEn, darkText, darkMuted, darkSurface, darkBg),
                  ),
                ),

                // Footer Nav Bar
                if (!_isCookComplete) ...[
                  Container(height: 1.0, color: darkSurface),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _currentStepIndex > 0 ? _prevStep : null,
                          child: Text(
                            isEn ? "← PREV" : "← ZURÜCK",
                            style: BrandFonts.mono(
                              fontSize: 12.0, 
                              color: _currentStepIndex > 0 ? darkText : darkMuted,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _nextStep,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BrandColors.coral,
                            foregroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                          ),
                          child: Text(
                            _currentStepIndex == widget.recipe.steps.length - 1 
                              ? (isEn ? "FINISH" : "FERTIG") 
                              : (isEn ? "NEXT →" : "WEITER →"),
                            style: BrandFonts.mono(fontSize: 12.0, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Visual accessibility timer flash overlay
          if (_isFlashingAlert)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  color: _flashColor.withOpacity(0.35),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveStepView(
    RecipeStep step, 
    double progress, 
    bool isEn, 
    Color darkText, 
    Color darkMuted, 
    Color darkSurface,
    Color darkBg,
  ) {
    // Parse step text
    final stepText = step.text[isEn ? 'en' : 'de'] ?? '';

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Servings Info Note
        Text(
          isEn ? "scaled for ${widget.servings} servings" : "angepasst für ${widget.servings} portionen",
          style: BrandFonts.mono(fontSize: 11.0, color: BrandColors.teal),
        ),

        // Step Prose content with Quick-Tap listener
        GestureDetector(
          onTap: _handleQuickTapAdvance,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: darkSurface,
              border: Border.all(color: BrandColors.coral.withOpacity(0.3), width: 1.0),
            ),
            child: Column(
              children: [
                Text(
                  stepText,
                  style: BrandFonts.displaySerif(fontSize: 20.0, color: darkText, italic: true),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16.0),
                if (_quickNextTapEnabled)
                  Text(
                    isEn ? "(tap step content to advance)" : "(auf text tippen, um fortzufahren)",
                    style: BrandFonts.mono(fontSize: 9.0, color: darkMuted),
                  ),
              ],
            ),
          ),
        ),

        // Timer Panel (Only visible if step has timer_seconds > 0)
        if (_originalTimerSeconds > 0)
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: darkSurface,
              border: Border.all(color: darkMuted.withOpacity(0.2), width: 0.5),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.alarm, color: BrandColors.teal, size: 18.0),
                    const SizedBox(width: 8.0),
                    Text(
                      _formatDuration(_secondsRemaining),
                      style: BrandFonts.mono(fontSize: 28.0, color: darkText, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                // Tiny slider-like indicator
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: darkBg,
                  color: BrandColors.teal,
                  minHeight: 4.0,
                ),
                const SizedBox(height: 12.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_isTimerRunning)
                      IconButton(
                        icon: const Icon(Icons.play_arrow_outlined, color: BrandColors.teal, size: 32.0),
                        onPressed: _startTimer,
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.pause_outlined, color: BrandColors.orange, size: 32.0),
                        onPressed: _pauseTimer,
                      ),
                    const SizedBox(width: 16.0),
                    IconButton(
                      icon: Icon(Icons.replay_outlined, color: darkMuted, size: 24.0),
                      onPressed: _resetTimer,
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          const SizedBox(height: 80.0), // Spacer if no timer
      ],
    );
  }

  Widget _buildCompletionView(bool isEn, Color darkText, Color darkMuted) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PolaroidCard(
            rotation: 1.5,
            child: Container(
              width: 260.0,
              child: Column(
                children: [
                  const SizedBox(height: 12.0),
                  Text(
                    isEn ? "feast complete!" : "festmahl beendet!",
                    style: BrandFonts.handwritten(fontSize: 28.0, color: BrandColors.coral),
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    isEn 
                      ? "you cooked this dish beautifully.\nit has been recorded in your kitchen history." 
                      : "du hast dieses gericht wunderbar zubereitet.\nes wurde in deiner historie vermerkt.",
                    style: BrandFonts.body(fontSize: 13.0, color: BrandColors.softGrey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16.0),
                  const DashedDivider(),
                  const SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Exit cook mode
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BrandColors.charcoalInk,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      elevation: 0,
                    ),
                    child: Text(
                      isEn ? "BACK TO DISH" : "ZURÜCK ZUM GERICHT",
                      style: BrandFonts.mono(fontSize: 11.0, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }
}
