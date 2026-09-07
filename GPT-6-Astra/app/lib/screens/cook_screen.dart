import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../ui/design.dart';

/// Opt-in one-handed navigation with protection against rapid repeated taps.
class OneHandedCookModeController extends ChangeNotifier {
  bool _quickNextTapEnabled;
  DateTime? _lastAcceptedTap;
  final Duration debounce;
  OneHandedCookModeController({
    bool quickNextTapEnabled = false,
    this.debounce = const Duration(milliseconds: 300),
  }) : _quickNextTapEnabled = quickNextTapEnabled;
  bool get quickNextTapEnabled => _quickNextTapEnabled;
  set quickNextTapEnabled(bool value) {
    if (_quickNextTapEnabled == value) return;
    _quickNextTapEnabled = value;
    _lastAcceptedTap = null;
    notifyListeners();
  }

  bool handleQuickTap(VoidCallback onAdvance, {DateTime? timestamp}) {
    if (!_quickNextTapEnabled) return false;
    final now = timestamp ?? DateTime.now();
    if (_lastAcceptedTap != null &&
        now.difference(_lastAcceptedTap!) < debounce) {
      return false;
    }
    _lastAcceptedTap = now;
    onAdvance();
    return true;
  }
}

class CookScreen extends StatefulWidget {
  final AppState state;
  final Recipe recipe;
  final double? servings;
  const CookScreen({
    super.key,
    required this.state,
    required this.recipe,
    this.servings,
  });
  @override
  State<CookScreen> createState() => _CookScreenState();
}

class _CookScreenState extends State<CookScreen> with WidgetsBindingObserver {
  static const _night = Color(0xFF223441);
  static const _light = Color(0xFFF4F1E9);
  int _step = 0;
  late double _servings;
  int _remaining = 0;
  DateTime? _deadline;
  bool _timerStarted = false;
  bool _finished = false;
  bool _alert = false;
  bool _paused = false;
  bool _resumeTimerOnResume = false;
  late final OneHandedCookModeController _oneHanded;
  Timer? _ticker;
  Timer? _flashTimer;
  int _flashCount = 0;
  AppState get s => widget.state;
  Recipe get recipe => widget.recipe;
  RecipeStep get step => recipe.steps[_step];
  bool get _running => _deadline != null;
  bool get _reduceMotion =>
      s.profile.reduceMotion ?? MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _oneHanded = OneHandedCookModeController(
      quickNextTapEnabled: s.profile.quickNextTapEnabled,
    );
    _servings = widget.servings ?? recipe.servings.toDouble();
    final progress = s.cookProgress;
    if (progress['recipe_id'] == recipe.id && recipe.steps.isNotEmpty) {
      _step = ((progress['step'] as num?)?.toInt() ?? 0).clamp(
        0,
        recipe.steps.length - 1,
      );
      _servings = (progress['servings'] as num?)?.toDouble() ?? _servings;
      _remaining = (progress['remaining_seconds'] as num?)?.toInt() ?? 0;
      _timerStarted = progress['timer_started'] == true;
      _deadline = DateTime.tryParse(progress['deadline']?.toString() ?? '');
      _paused = progress['paused'] == true;
      _resumeTimerOnResume = progress['resume_timer_on_resume'] == true;
    }
    if (!_timerStarted && recipe.steps.isNotEmpty) {
      _remaining = step.timerSeconds;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _tick();
        _persist();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) _tick();
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.inactive) {
      _persist();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _flashTimer?.cancel();
    _oneHanded.dispose();
    super.dispose();
  }

  void _persist() {
    if (_finished) return;
    s.setCookProgress({
      'recipe_id': recipe.id,
      'step': _step,
      'servings': _servings,
      'remaining_seconds': _remaining,
      'timer_started': _timerStarted,
      'deadline': _deadline?.toIso8601String(),
      'paused': _paused,
      'resume_timer_on_resume': _resumeTimerOnResume,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  void _tick() {
    if (!mounted || _deadline == null || _finished) return;
    final seconds = math.max(
      0,
      (_deadline!.difference(DateTime.now()).inMilliseconds / 1000).ceil(),
    );
    if (seconds != _remaining) setState(() => _remaining = seconds);
    if (seconds <= 0) {
      setState(() {
        _deadline = null;
        _remaining = 0;
        _alert = s.profile.visualAlertEnabled;
      });
      HapticFeedback.heavyImpact();
      _persist();
      if (_alert && !_reduceMotion) {
        _flashCount = 0;
        _flashTimer?.cancel();
        _flashTimer = Timer.periodic(const Duration(milliseconds: 650), (
          timer,
        ) {
          if (!mounted || _flashCount >= 5) {
            timer.cancel();
            return;
          }
          setState(() => _flashCount++);
        });
      }
    }
  }

  void _toggleTimer() {
    setState(() {
      _alert = false;
      if (_running) {
        _remaining = math.max(
          0,
          (_deadline!.difference(DateTime.now()).inMilliseconds / 1000).ceil(),
        );
        _deadline = null;
      } else {
        if (_remaining <= 0) _remaining = step.timerSeconds;
        _timerStarted = true;
        _paused = false;
        _deadline = DateTime.now().add(Duration(seconds: _remaining));
      }
    });
    _persist();
  }

  void _go(int index) {
    if (_paused || index < 0 || index >= recipe.steps.length) return;
    _flashTimer?.cancel();
    setState(() {
      _step = index;
      _remaining = step.timerSeconds;
      _deadline = null;
      _timerStarted = false;
      _alert = false;
    });
    _persist();
  }

  void _quickTap() {
    if (!s.profile.quickNextTapEnabled || _paused || _finished) return;
    _oneHanded.quickNextTapEnabled = s.profile.quickNextTapEnabled;
    _oneHanded.handleQuickTap(() {
      if (_step < recipe.steps.length - 1) {
        HapticFeedback.selectionClick();
        _go(_step + 1);
      }
    });
  }

  void _togglePause() {
    setState(() {
      _paused = !_paused;
      if (_paused) _resumeTimerOnResume = _deadline != null;
      if (_paused && _deadline != null) {
        _remaining = math.max(
          0,
          (_deadline!.difference(DateTime.now()).inMilliseconds / 1000).ceil(),
        );
        _deadline = null;
      } else if (!_paused && _resumeTimerOnResume && _remaining > 0) {
        _deadline = DateTime.now().add(Duration(seconds: _remaining));
        _resumeTimerOnResume = false;
      }
    });
    _persist();
  }

  void _complete() {
    _ticker?.cancel();
    _flashTimer?.cancel();
    setState(() {
      _finished = true;
      _deadline = null;
      _alert = false;
    });
    s.completeCooking(recipe);
    HapticFeedback.mediumImpact();
  }

  void _ingredients() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.paper,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .65,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                display(
                  tr(s, 'everything, at hand.', 'alles griffbereit.'),
                  size: 28,
                ),
                const SizedBox(height: 8),
                mono(
                  tr(
                    s,
                    'FOR ${_number(_servings)} SERVINGS',
                    'FÜR ${_number(_servings)} PORTIONEN',
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView.builder(
                    itemCount: recipe.ingredients.length,
                    itemBuilder: (context, i) {
                      final ingredient = recipe.ingredients[i];
                      final name =
                          s.repo.ingredientById(ingredient.id)?.name ??
                          {'en': ingredient.id};
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Palette.line),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(localized(name, s.profile.lang)),
                            ),
                            const SizedBox(width: 14),
                            mono(
                              '${_number(ingredient.quantity * _servings / recipe.servings)} ${_unit(ingredient.unit)}',
                              size: 11,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: tr(s, 'Back to the kitchen', 'Zurück in die Küche'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
  String _unit(String unit) => s.profile.lang == 'de'
      ? const {
              'piece': 'Stk.',
              'clove': 'Zehe',
              'tbsp': 'EL',
              'tsp': 'TL',
              'bunch': 'Bund',
            }[unit] ??
            unit
      : unit;

  @override
  Widget build(BuildContext context) {
    final alertColor = _flashCount.isEven
        ? Palette.coral
        : const Color(0xFF6AA99D);
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _night,
        colorScheme: const ColorScheme.dark(
          primary: _light,
          secondary: Palette.coral,
          surface: _night,
        ),
        iconTheme: const IconThemeData(color: _light),
      ),
      child: Scaffold(
        backgroundColor: _night,
        body: SafeArea(
          child: AnimatedContainer(
            duration: _reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 240),
            decoration: BoxDecoration(
              border: Border.all(
                color: _alert ? alertColor : Colors.transparent,
                width: 5,
              ),
            ),
            child: _finished
                ? _completion()
                : recipe.steps.isEmpty
                ? _missingSteps()
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1050),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                            child: Row(
                              children: [
                                IconButton(
                                  tooltip: tr(
                                    s,
                                    'Save and leave cook mode',
                                    'Speichern und Kochmodus verlassen',
                                  ),
                                  onPressed: () {
                                    _persist();
                                    Navigator.pop(context);
                                  },
                                  icon: const Icon(Icons.close, color: _light),
                                ),
                                Expanded(
                                  child: Text(
                                    localized(recipe.title, s.profile.lang),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _light,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: _paused
                                      ? tr(s, 'Resume cooking', 'Weiterkochen')
                                      : tr(
                                          s,
                                          'Pause cooking',
                                          'Kochen pausieren',
                                        ),
                                  onPressed: _togglePause,
                                  icon: Icon(
                                    _paused ? Icons.play_arrow : Icons.pause,
                                    color: _light,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Row(
                              children: [
                                for (var i = 0; i < recipe.steps.length; i++)
                                  Expanded(
                                    child: Container(
                                      height: 3,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      color: i <= _step
                                          ? Palette.coral
                                          : _light.withValues(alpha: .15),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                28,
                                30,
                                28,
                                20,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: mono(
                                          tr(
                                            s,
                                            'STEP ${_step + 1} OF ${recipe.steps.length}',
                                            'SCHRITT ${_step + 1} VON ${recipe.steps.length}',
                                          ),
                                          color: Palette.coral,
                                          size: 11,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _ingredients,
                                        child: Text(
                                          tr(s, 'ingredients ↗', 'Zutaten ↗'),
                                          style: const TextStyle(
                                            color: _light,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  Semantics(
                                    button: s.profile.quickNextTapEnabled,
                                    label: s.profile.quickNextTapEnabled
                                        ? tr(
                                            s,
                                            'Tap instruction to advance to the next step',
                                            'Anleitung antippen für den nächsten Schritt',
                                          )
                                        : null,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: _quickTap,
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            display(
                                              _paused
                                                  ? tr(
                                                      s,
                                                      'take your time.',
                                                      'nimm dir Zeit.',
                                                    )
                                                  : localized(
                                                      step.title,
                                                      s.profile.lang,
                                                    ),
                                              size:
                                                  MediaQuery.sizeOf(
                                                        context,
                                                      ).width <
                                                      400
                                                  ? 37
                                                  : 46,
                                              color: _light,
                                            ),
                                            const SizedBox(height: 24),
                                            Text(
                                              _paused
                                                  ? tr(
                                                      s,
                                                      'Your place is saved. Take a breath, and resume when you’re ready.',
                                                      'Dein Fortschritt ist gespeichert. Atme durch und koche weiter, wenn du bereit bist.',
                                                    )
                                                  : localized(
                                                      step.text,
                                                      s.profile.lang,
                                                    ),
                                              style: TextStyle(
                                                color: _light.withValues(
                                                  alpha: .85,
                                                ),
                                                fontSize: 18,
                                                height: 1.8,
                                              ),
                                            ),
                                            const SizedBox(height: 26),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (s.profile.quickNextTapEnabled && !_paused)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 20,
                                      ),
                                      child: mono(
                                        tr(
                                          s,
                                          'ONE HAND? TAP THE WORDS TO CONTINUE.',
                                          'EINE HAND? TIPPE AUF DEN TEXT.',
                                        ),
                                        size: 9,
                                        color: _light.withValues(alpha: .5),
                                      ),
                                    ),
                                  if (_paused)
                                    FilledButton.icon(
                                      onPressed: _togglePause,
                                      icon: const Icon(Icons.play_arrow),
                                      label: Text(
                                        tr(s, 'Resume cooking', 'Weiterkochen'),
                                      ),
                                    )
                                  else if (step.timerSeconds > 0)
                                    _timerCard(alertColor),
                                  const SizedBox(height: 28),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(
                                          color: _light.withValues(alpha: .15),
                                        ),
                                        bottom: BorderSide(
                                          color: _light.withValues(alpha: .15),
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: mono(
                                            tr(s, 'AT THE TABLE', 'AM TISCH'),
                                            color: _light.withValues(alpha: .6),
                                            size: 10,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: tr(
                                            s,
                                            'Fewer servings',
                                            'Weniger Portionen',
                                          ),
                                          onPressed: _servings <= 1
                                              ? null
                                              : () {
                                                  setState(() => _servings--);
                                                  _persist();
                                                },
                                          icon: Icon(
                                            Icons.remove,
                                            color: _servings <= 1
                                                ? Colors.white24
                                                : _light,
                                            size: 18,
                                          ),
                                        ),
                                        Text(
                                          _number(_servings),
                                          style: const TextStyle(
                                            color: _light,
                                            fontSize: 18,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: tr(
                                            s,
                                            'More servings',
                                            'Mehr Portionen',
                                          ),
                                          onPressed: _servings >= 24
                                              ? null
                                              : () {
                                                  setState(() => _servings++);
                                                  _persist();
                                                },
                                          icon: const Icon(
                                            Icons.add,
                                            color: _light,
                                            size: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                            child: Row(
                              children: [
                                OutlinedButton(
                                  onPressed: _step == 0 || _paused
                                      ? null
                                      : () => _go(_step - 1),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: _light.withValues(alpha: .25),
                                    ),
                                    foregroundColor: _light,
                                    disabledForegroundColor: Colors.white24,
                                  ),
                                  child: const Icon(Icons.arrow_back),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _paused
                                        ? null
                                        : () => _step == recipe.steps.length - 1
                                              ? _complete()
                                              : _go(_step + 1),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _light,
                                      foregroundColor: _night,
                                      disabledBackgroundColor: Colors.white12,
                                    ),
                                    child: Text(
                                      _step == recipe.steps.length - 1
                                          ? tr(
                                              s,
                                              'Ready to enjoy ✓',
                                              'Fertig zum Genießen ✓',
                                            )
                                          : tr(
                                              s,
                                              'Next step →',
                                              'Nächster Schritt →',
                                            ),
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
          ),
        ),
      ),
    );
  }

  Widget _timerCard(Color alertColor) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: _alert
          ? alertColor.withValues(alpha: .16)
          : _light.withValues(alpha: .045),
      border: Border.all(
        color: _alert ? alertColor : _light.withValues(alpha: .22),
      ),
    ),
    child: Column(
      children: [
        mono(
          _timerStarted && _remaining == 0
              ? tr(s, 'TIME’S UP — HAVE A LOOK', 'ZEIT VORBEI — SCHAU MAL NACH')
              : tr(s, 'A LITTLE PATIENCE', 'EIN WENIG GEDULD'),
          color: _alert ? alertColor : _light.withValues(alpha: .6),
        ),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: _remaining == 0,
          label:
              '${_remaining ~/ 60} ${tr(s, 'minutes', 'Minuten')}, ${_remaining % 60} ${tr(s, 'seconds', 'Sekunden')}',
          child: Text(
            '${(_remaining ~/ 60).toString().padLeft(2, '0')}:${(_remaining % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(
              fontFamily: 'Playfair Display',
              fontSize: 58,
              color: _light,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 7),
        TextButton.icon(
          onPressed: _toggleTimer,
          icon: Icon(_running ? Icons.pause : Icons.play_arrow, size: 19),
          label: Text(
            _running
                ? tr(s, 'Pause timer', 'Timer pausieren')
                : _timerStarted && _remaining > 0
                ? tr(s, 'Resume timer', 'Timer fortsetzen')
                : _timerStarted
                ? tr(s, 'Start again', 'Erneut starten')
                : tr(s, 'Start timer', 'Timer starten'),
          ),
          style: TextButton.styleFrom(foregroundColor: _light),
        ),
        if (_alert)
          TextButton(
            onPressed: () {
              _flashTimer?.cancel();
              setState(() => _alert = false);
            },
            style: TextButton.styleFrom(foregroundColor: _light),
            child: Text(tr(s, 'Got it', 'Alles klar')),
          ),
      ],
    ),
  );
  Widget _completion() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.restaurant, color: Palette.coral, size: 42),
          const SizedBox(height: 32),
          mono(
            tr(s, 'MADE BY YOU, FOR YOU', 'VON DIR, FÜR DICH'),
            color: Palette.coral,
          ),
          const SizedBox(height: 24),
          display(
            tr(s, 'and now,\nenjoy.', 'und jetzt,\ngenießen.'),
            size: 65,
            color: _light,
          ),
          const SizedBox(height: 26),
          Text(
            localized(recipe.title, s.profile.lang),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, height: 1.6, color: _light),
          ),
          const SizedBox(height: 15),
          Text(
            tr(
              s,
              'A meal made. A memory saved in your cooking history.',
              'Ein Essen gekocht. Eine Erinnerung in deinem Kochverlauf.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: _light.withValues(alpha: .6), height: 1.6),
          ),
          const SizedBox(height: 36),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: _light,
              foregroundColor: _night,
            ),
            child: Text(tr(s, 'Back to the recipe', 'Zurück zum Rezept')),
          ),
          const SizedBox(height: 25),
          hand(
            tr(s, 'you made something good.', 'du hast etwas Gutes gemacht.'),
            color: Palette.coral,
            size: 28,
          ),
        ],
      ),
    ),
  );
  Widget _missingSteps() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          display(
            tr(s, 'a page is missing.', 'eine Seite fehlt.'),
            color: _light,
          ),
          const SizedBox(height: 20),
          Text(
            tr(
              s,
              'This recipe has no cooking steps. Please choose another recipe.',
              'Dieses Rezept hat keine Kochschritte. Bitte wähle ein anderes Rezept.',
            ),
            style: const TextStyle(color: _light),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(s, 'Go back', 'Zurück')),
          ),
        ],
      ),
    ),
  );
}
