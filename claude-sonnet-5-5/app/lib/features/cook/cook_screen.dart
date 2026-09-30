import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/labels.dart';
import '../../core/motion.dart';
import '../../core/text_scale.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../data/corpus.dart';
import '../../data/models/recipe.dart';
import '../../platform/platform_services.dart';
import '../../state/app_services.dart';
import '../../state/controllers/cook_session_controller.dart';
import '../../state/controllers/cookbook_controller.dart';
import '../../state/controllers/history_controller.dart';
import '../../state/controllers/one_handed_cook_mode_controller.dart';
import '../../state/controllers/profile_controller.dart';
import '../../widgets/paper.dart';
import '../../widgets/paper_controls.dart';
import '../dish/ingredient_list.dart';
import 'timer_widgets.dart';

/// Cook mode: dark and full bleed, one step at a time, a timer per step, a
/// servings scaler, pause and resume with progress that survives leaving.
class CookScreen extends StatefulWidget {
  const CookScreen({super.key, required this.recipeId, this.servings, this.resume = false});

  final String recipeId;
  final double? servings;
  final bool resume;

  @override
  State<CookScreen> createState() => _CookScreenState();
}

class _CookScreenState extends State<CookScreen> with WidgetsBindingObserver {
  Recipe? _recipe;
  PageController? _pages;
  StreamSubscription<TimerDone>? _sub;
  Timer? _flashTimer;
  int? _flashStep;
  bool _finished = false;
  bool _sliding = false;
  bool _logged = false;

  // Read once in initState: dispose() may not look them up through the context.
  late final CookSessionController _cook;
  late final PlatformServices _platform;
  late final ProfileController _profile;

  @override
  void initState() {
    super.initState();
    _cook = context.read<CookSessionController>();
    _platform = context.read<AppServices>().platform;
    _profile = context.read<ProfileController>();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  Future<void> _start() async {
    final corpus = context.read<Corpus>();
    final recipe = await corpus.loadRecipe(widget.recipeId);
    if (!mounted) return;
    if (recipe == null) {
      unawaited(Navigator.of(context).maybePop());
      return;
    }
    await _cook.begin(recipe, servings: widget.servings, resume: widget.resume);
    if (!mounted) return;
    _pages = PageController(initialPage: _cook.stepIndex);
    _sub = _cook.timerDone.listen(_onTimerDone);
    _cook.addListener(_onCookChanged);
    await _platform.awake.keepAwake(true);
    if (mounted) setState(() => _recipe = recipe);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Timers keep the wall-clock moment they end; catch up when we come back.
    if (state == AppLifecycleState.resumed) _cook.tick();
  }

  void _onCookChanged() {
    final pages = _pages;
    if (pages != null && pages.hasClients && !_cook.completed && _cook.isActive) {
      final current = pages.page?.round() ?? pages.initialPage;
      if (current != _cook.stepIndex) {
        if (context.read<OneHandedCookModeController>().animateTransitions) {
          // Touches are ignored while the page slides: a finger landing on a
          // moving page would stop it half way and leave the text one step
          // behind the counter.
          setState(() => _sliding = true);
          unawaited(
            pages
                .animateToPage(_cook.stepIndex, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic)
                .whenComplete(() {
                  if (mounted) setState(() => _sliding = false);
                }),
          );
        } else {
          pages.jumpToPage(_cook.stepIndex);
        }
      }
    }
    if (_cook.completed && !_finished && mounted) setState(() => _finished = true);
    // "previous" on the completion screen goes back into the recipe. Logging or
    // leaving ends the run (inactive) and must keep the completion screen up.
    if (!_cook.completed && _finished && _cook.isActive && mounted) setState(() => _finished = false);
  }

  void _onTimerDone(TimerDone event) {
    final settings = _profile.settings;
    _platform.alerts.alert(sound: settings.timerSoundEnabled);
    if (settings.visualAlertEnabled && mounted) {
      setState(() => _flashStep = event.stepIndex);
      _flashTimer?.cancel();
      _flashTimer = Timer(const Duration(seconds: 12), _dismissFlash);
    }
  }

  void _dismissFlash() {
    _flashTimer?.cancel();
    _platform.alerts.stop();
    if (mounted) setState(() => _flashStep = null);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _flashTimer?.cancel();
    _cook.removeListener(_onCookChanged);
    _pages?.dispose();
    _platform.alerts.stop();
    _platform.awake.keepAwake(false);
    if (_cook.completed) {
      _cook.abandon();
    } else if (_cook.isActive) {
      _cook.suspend();
    }
    super.dispose();
  }

  Future<void> _leave() async {
    await _cook.suspend();
    if (mounted) unawaited(Navigator.of(context).maybePop());
  }

  Future<void> _logIt() async {
    final entry = await _cook.complete();
    if (!mounted) return;
    await context.read<HistoryController>().add(entry);
    if (mounted) setState(() => _logged = true);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final recipe = _recipe;
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: Palette.night,
        dialogTheme: DialogThemeData(
          backgroundColor: Palette.nightSurface,
          titleTextStyle: AppText.display(size: 26, color: Palette.nightInk),
          contentTextStyle: AppText.serif(size: 15.5, color: Palette.nightInk),
        ),
        textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Palette.nightInk)),
      ),
      child: PopScope(
        canPop: true,
        child: Scaffold(
          backgroundColor: Palette.night,
          body: PaperBackground(
            color: Palette.night,
            child: Stack(
              children: [
                SafeArea(
                  child: recipe == null
                      ? Center(
                          child: Text(s('cook.loading'), style: AppText.serifItalic(color: Palette.nightSoft)),
                        )
                      : (_finished
                            ? _Completion(
                                recipe: recipe,
                                logged: _logged,
                                onLog: _logIt,
                                onClose: () => Navigator.of(context).maybePop(),
                              )
                            : _body(context, recipe)),
                ),
                if (_flashStep != null && recipe != null)
                  Positioned.fill(
                    child: TimerFlashOverlay(
                      message: s('cook.timerDone', {'n': _flashStep! + 1}),
                      dismissLabel: s('cook.dismiss'),
                      onDismiss: _dismissFlash,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Recipe recipe) {
    final s = context.s;
    final cook = context.watch<CookSessionController>();
    if (!cook.isActive) return const SizedBox.shrink();
    final oneHanded = context.watch<OneHandedCookModeController>();
    final running = cook.runningTimerSteps.where((i) => i != cook.stepIndex).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Row(
            children: [
              PaperIconButton(icon: Icons.close, color: Palette.nightInk, tooltip: s('cook.leave'), onPressed: _leave),
              Expanded(
                child: _StepDashes(count: cook.stepCount, current: cook.stepIndex, onTap: cook.goTo),
              ),
              PaperIconButton(
                icon: cook.paused ? Icons.play_arrow : Icons.pause,
                color: Palette.nightInk,
                tooltip: cook.paused ? s('cook.resume') : s('cook.pause'),
                onPressed: cook.paused ? cook.resume : cook.pause,
              ),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _cookMeta(context, recipe, cook)),
        if (running.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              children: [
                for (final step in running)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _PillButton(
                      icon: Icons.timer_outlined,
                      label: '${s('cook.stepShort', {'n': step + 1})}  ${clockText(cook.remainingSeconds(step))}',
                      accent: true,
                      onTap: () => cook.goTo(step),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              IgnorePointer(
                ignoring: _sliding,
                child: PageView.builder(
                  controller: _pages,
                  itemCount: cook.stepCount,
                  onPageChanged: cook.goTo,
                  itemBuilder: (context, index) =>
                      _StepPage(recipe: recipe, index: index, onQuickTap: () => oneHanded.handleQuickTap(cook.next)),
                ),
              ),
              if (cook.paused) Positioned.fill(child: _PausedOverlay(onResume: cook.resume)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: Row(
            children: [
              _RoundNav(
                icon: Icons.arrow_back,
                tooltip: s('cook.previous'),
                onTap: cook.isFirstStep ? null : cook.previous,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PaperButton(
                  label: cook.isLastStep ? s('cook.finish') : s('cook.next'),
                  icon: cook.isLastStep ? Icons.check : Icons.arrow_forward,
                  expand: true,
                  color: Palette.nightInk,
                  onPressed: cook.paused ? null : cook.next,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The recipe title with the step counter, and the servings and ingredients
  /// buttons. Side by side normally, stacked when the text is large.
  Widget _cookMeta(BuildContext context, Recipe recipe, CookSessionController cook) {
    final s = context.s;
    final title = Text(
      '${lower(recipe.title.resolve(s.lang))}  ·  ${s('cook.stepOf', {'n': cook.stepIndex + 1, 'total': cook.stepCount})}',
      maxLines: context.largeText ? 3 : 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.label(size: 10.5, color: Palette.nightSoft),
    );
    final people = _PillButton(
      icon: Icons.people_outline,
      label: s.plural('dish.people', cook.servings.round()),
      onTap: () => _showIngredients(context, recipe),
    );
    final ingredients = _PillButton(
      icon: Icons.list_alt,
      label: s('cook.ingredients'),
      onTap: () => _showIngredients(context, recipe),
    );
    if (context.largeText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [people, ingredients]),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: title),
        people,
        const SizedBox(width: 6),
        ingredients,
      ],
    );
  }

  void _showIngredients(BuildContext context, Recipe recipe) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Palette.nightSurface,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (sheetContext) => _IngredientsSheet(recipe: recipe),
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({required this.recipe, required this.index, required this.onQuickTap});

  final Recipe recipe;
  final int index;
  final VoidCallback onQuickTap;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final cook = context.watch<CookSessionController>();
    final step = recipe.steps[index];
    final seconds = step.timerSeconds;
    final quick = context.watch<OneHandedCookModeController>().quickNextTapEnabled;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onQuickTap,
      child: Semantics(
        label: s('cook.stepOf', {'n': index + 1, 'total': recipe.steps.length}),
        hint: quick ? s('cook.quickTapHint') : null,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The numeral is a graphic and stays as it is. The step text already
              // starts at 26 pt, so it follows the system text size only up to 1.5 times.
              MediaQuery.withNoTextScaling(
                child: Text('${index + 1}', style: AppText.display(size: 92, color: Palette.coral)),
              ),
              const SizedBox(height: 4),
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.5,
                child: Text(
                  step.text.resolve(s.lang),
                  style: AppText.serif(size: 26, color: Palette.nightInk, height: 1.5),
                ),
              ),
              if (seconds != null) ...[
                const SizedBox(height: 28),
                Center(
                  child: _TimerCard(step: index, total: seconds, cook: cook),
                ),
              ],
              if (quick) ...[
                const SizedBox(height: 26),
                Center(
                  child: Text(s('cook.tapAnywhere'), style: AppText.hand(size: 21, color: Palette.nightSoft)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({required this.step, required this.total, required this.cook});

  final int step;
  final int total;
  final CookSessionController cook;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final running = cook.isTimerRunning(step);
    final finished = cook.isTimerFinished(step);
    final remaining = cook.remainingSeconds(step);
    final started = cook.timerAt(step) != null;
    return Column(
      children: [
        Semantics(
          label: s('cook.timerSemantics', {'time': clockText(remaining)}),
          child: TimerRing(remaining: remaining, total: total, running: running, finished: finished, size: 210),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PaperButton(
              label: finished
                  ? s('cook.timerAgain')
                  : (running ? s('cook.timerPause') : (started ? s('cook.timerResume') : s('cook.timerStart'))),
              icon: running ? Icons.pause : Icons.play_arrow,
              color: Palette.nightInk,
              style: PaperButtonStyle.outline,
              onPressed: cook.paused ? null : () => cook.toggleTimer(step),
            ),
            if (started) ...[
              const SizedBox(width: 8),
              PaperIconButton(
                icon: Icons.replay,
                color: Palette.nightSoft,
                tooltip: s('cook.timerReset'),
                onPressed: () => cook.resetTimer(step),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _StepDashes extends StatelessWidget {
  const _StepDashes({required this.count, required this.current, required this.onTap});

  final int count;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    // The dashes are a shortcut for sighted cooks. Screen readers get the
    // position ("step 3 of 6") and the previous and next buttons instead.
    return Semantics(
      label: context.s('cook.stepOf', {'n': current + 1, 'total': count}),
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < count; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: SizedBox(
                    height: 48,
                    child: Center(
                      child: AnimatedContainer(
                        duration: context.motion(const Duration(milliseconds: 200)),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: i == current ? 5 : 3,
                        decoration: BoxDecoration(
                          color: i < current ? Palette.nightSoft : (i == current ? Palette.coral : Palette.nightRule),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.icon, required this.label, required this.onTap, this.accent = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? Palette.teal : Palette.nightSoft;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: color.withValues(alpha: 0.7)),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: color),
                  const SizedBox(width: 6),
                  Text(label, style: AppText.mono(size: 11, color: accent ? Palette.nightInk : Palette.nightSoft)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundNav extends StatelessWidget {
  const _RoundNav({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            border: Border.all(color: enabled ? Palette.nightSoft : Palette.nightRule, width: 1.4),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Icon(icon, color: enabled ? Palette.nightInk : Palette.nightRule),
        ),
      ),
    );
  }
}

class _PausedOverlay extends StatelessWidget {
  const _PausedOverlay({required this.onResume});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Container(
      color: Palette.night.withValues(alpha: 0.9),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s('cook.paused'), style: AppText.display(size: 50, color: Palette.nightInk)),
            HandNote(s('cook.pausedNote'), size: 24, color: Palette.nightSoft),
            const SizedBox(height: 22),
            PaperButton(label: s('cook.resume'), icon: Icons.play_arrow, color: Palette.nightInk, onPressed: onResume),
          ],
        ),
      ),
    );
  }
}

class _IngredientsSheet extends StatelessWidget {
  const _IngredientsSheet({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final corpus = context.read<Corpus>();
    final cook = context.watch<CookSessionController>();
    final count = cook.servings.round();
    final scale = cook.scale;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: Palette.nightRule, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(s('cook.ingredients'), style: AppText.display(size: 32, color: Palette.nightInk)),
              ),
              PaperIconButton(
                icon: Icons.close,
                color: Palette.nightInk,
                tooltip: s('common.close'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Row(
            children: [
              Text(s('dish.servingsFor'), style: AppText.hand(size: 22, color: Palette.nightSoft)),
              const SizedBox(width: 6),
              PaperIconButton(
                icon: Icons.remove_circle_outline,
                color: Palette.nightInk,
                tooltip: s('dish.fewer'),
                onPressed: count > 1 ? () => cook.setServings((count - 1).toDouble()) : null,
              ),
              SizedBox(
                width: 74,
                child: Center(
                  child: Text(
                    s.plural('dish.people', count),
                    style: AppText.mono(size: 13, color: Palette.nightInk, weight: FontWeight.w700),
                  ),
                ),
              ),
              PaperIconButton(
                icon: Icons.add_circle_outline,
                color: Palette.nightInk,
                tooltip: s('dish.more'),
                onPressed: count < 12 ? () => cook.setServings((count + 1).toDouble()) : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final line in recipe.ingredients)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Palette.nightRule)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      ingredientAmountText(corpus.ontology, line, scale, s.lang).ifEmpty(s('unit.toTaste')),
                      style: AppText.mono(size: 13, color: Palette.nightInk, weight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${ingredientNameText(corpus.ingredients, line, scale, s.lang)}${line.note.isEmpty ? '' : ', ${line.note.resolve(s.lang)}'}',
                      style: AppText.serif(size: 17, color: Palette.nightInk, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

class _Completion extends StatelessWidget {
  const _Completion({required this.recipe, required this.logged, required this.onLog, required this.onClose});

  final Recipe recipe;
  final bool logged;
  final VoidCallback onLog;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final cookbook = context.watch<CookbookController>();
    final saved = cookbook.isSaved(recipe.id);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s('cook.done.title'), style: AppText.display(size: 64, color: Palette.nightInk)),
            const SizedBox(height: 6),
            Text(
              lower(recipe.title.resolve(s.lang)),
              textAlign: TextAlign.center,
              style: AppText.serifItalic(size: 22, color: Palette.nightSoft),
            ),
            const SizedBox(height: 10),
            HandNote(
              logged ? s('cook.done.logged') : s('cook.done.note'),
              size: 26,
              color: Palette.coral,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            if (!logged)
              PaperButton(label: s('cook.done.log'), icon: Icons.check, color: Palette.nightInk, onPressed: onLog)
            else
              PaperButton(
                label: s('common.close'),
                icon: Icons.home_outlined,
                color: Palette.nightInk,
                onPressed: onClose,
              ),
            const SizedBox(height: 10),
            if (!saved)
              PaperButton(
                label: s('dish.save'),
                icon: Icons.bookmark_border,
                style: PaperButtonStyle.quiet,
                color: Palette.nightSoft,
                onPressed: () => cookbook.save(recipe.id),
              )
            else
              Text(s('cook.done.inCookbook'), style: AppText.mono(size: 12, color: Palette.nightSoft)),
            if (!logged)
              PaperButton(
                label: s('cook.done.skip'),
                style: PaperButtonStyle.quiet,
                color: Palette.nightSoft,
                onPressed: onClose,
              ),
          ],
        ),
      ),
    );
  }
}
