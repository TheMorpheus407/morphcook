import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/corpus_repository.dart';
import '../../core/l10n.dart';
import '../../core/models/dish.dart';
import '../../core/models/local_text.dart';
import '../../core/models/recipe.dart';
import '../../core/storage/local_store.dart';
import '../../core/storage/profile_store.dart';
import '../../core/theme/app_theme.dart';
import 'one_handed_controller.dart';

/// Cook mode: the one place the app goes dark. Full-bleed, step-by-step,
/// with per-step timers, a servings scaler and progress persistence.
class CookModeScreen extends StatefulWidget {
  const CookModeScreen({super.key, required this.recipeId});

  final String recipeId;

  @override
  State<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends State<CookModeScreen>
    with WidgetsBindingObserver {
  /// Near-black warm background.
  static const _bg = Color(0xFF1B1713);

  static const _paper = AppColors.paper;

  late final LocalStore _store;
  late final OneHandedCookModeController _oneHanded;

  Recipe? _recipe;
  Dish? _dish;
  bool _loading = true;

  int _stepIndex = 0;
  int _servings = 1;
  bool _resumed = false;
  bool _finished = false;
  bool _completionLogged = false;
  bool _miseExpanded = false;

  /// Step index whose timer just completed → full-screen alert.
  int? _alertStep;

  /// Timers keyed by step index so they keep running across step changes.
  final Map<int, _StepTimer> _timers = {};

  Color get _soft => _paper.withValues(alpha: 0.55);
  Color get _faint => _paper.withValues(alpha: 0.28);

  Color get _stripe =>
      _dish == null ? AppColors.coral : AppColors.stripe(_dish!.stripeColor);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _store = context.read<LocalStore>();
    final profile = context.read<ProfileStore>().profile;
    _oneHanded = OneHandedCookModeController(
      quickNextTapEnabled: profile.quickNextTapEnabled,
      reduceMotion: profile.reduceMotion ?? false,
    );
    _load();
  }

  Future<void> _load() async {
    final corpus = context.read<CorpusRepository>();
    await corpus.ensureAllLoaded();
    if (!mounted) return;
    final recipe = corpus.recipeById(widget.recipeId);
    setState(() {
      _recipe = recipe;
      _dish = recipe == null ? null : corpus.dishById(recipe.dishId);
      _servings = recipe?.servings ?? 1;
      final saved = _store.cookProgress[widget.recipeId];
      if (recipe != null &&
          saved != null &&
          saved > 0 &&
          saved < recipe.steps.length) {
        _stepIndex = saved;
        _resumed = true;
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final t in _timers.values) {
      t.ticker?.cancel();
    }
    if (!_finished && _recipe != null) {
      _store.saveCookProgress(widget.recipeId, _stepIndex);
    }
    _oneHanded.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !_finished && _recipe != null) {
      _store.saveCookProgress(widget.recipeId, _stepIndex);
    }
  }

  // ---- navigation ---------------------------------------------------------

  void _goTo(int index) {
    final recipe = _recipe;
    if (recipe == null || recipe.steps.isEmpty) return;
    final clamped = index.clamp(0, recipe.steps.length - 1).toInt();
    if (clamped == _stepIndex) return;
    setState(() {
      _stepIndex = clamped;
      _resumed = false;
    });
    _store.saveCookProgress(widget.recipeId, clamped);
  }

  void _next() {
    final recipe = _recipe;
    if (recipe == null) return;
    if (_stepIndex >= recipe.steps.length - 1) {
      _finish();
    } else {
      _goTo(_stepIndex + 1);
    }
  }

  void _finish() {
    if (_finished) return;
    setState(() => _finished = true);
    if (!_completionLogged) {
      _completionLogged = true;
      _store.logCooked(widget.recipeId);
      _store.clearCookProgress(widget.recipeId);
    }
  }

  // ---- timers --------------------------------------------------------------

  _StepTimer _timerFor(int stepIndex) => _timers.putIfAbsent(
    stepIndex,
    () => _StepTimer(_recipe!.steps[stepIndex].timerSeconds!),
  );

  void _toggleTimer(int stepIndex) {
    final t = _timers[stepIndex]!;
    setState(() {
      if (t.running) {
        t.running = false;
        t.ticker?.cancel();
      } else {
        if (t.done) {
          t.remaining = t.totalSeconds;
          t.done = false;
        }
        t.running = true;
        t.ticker = Timer.periodic(
          const Duration(seconds: 1),
          (_) => _tickTimer(stepIndex),
        );
      }
    });
  }

  void _tickTimer(int stepIndex) {
    final t = _timers[stepIndex];
    if (t == null || !t.running || !mounted) return;
    setState(() {
      t.remaining--;
      if (t.remaining <= 0) {
        t.remaining = 0;
        t.running = false;
        t.done = true;
        t.ticker?.cancel();
        HapticFeedback.mediumImpact();
        _alertStep = stepIndex;
      }
    });
  }

  void _resetTimer(int stepIndex) {
    final t = _timers[stepIndex]!;
    setState(() {
      t.ticker?.cancel();
      t.running = false;
      t.done = false;
      t.remaining = t.totalSeconds;
    });
  }

  // ---- helpers --------------------------------------------------------------

  static String _clock(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static String _amount(double value) {
    final rounded = (value * 10).round() / 10;
    if (rounded == rounded.roundToDouble()) {
      return rounded.toInt().toString();
    }
    return rounded.toStringAsFixed(1);
  }

  // ---- build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final s = S(context);
    final profile = context.watch<ProfileStore>().profile;
    final reduceMotion =
        profile.reduceMotion ??
        MediaQuery.maybeDisableAnimationsOf(context) ??
        false;
    _oneHanded.sync(
      quickNextTapEnabled: profile.quickNextTapEnabled,
      reduceMotion: reduceMotion,
    );

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          SafeArea(child: _buildBody(context, s, profile.lang, reduceMotion)),
          if (_alertStep != null &&
              (reduceMotion || profile.visualAlertEnabled))
            _TimerAlertOverlay(
              flash: profile.visualAlertEnabled && !reduceMotion,
              doneLabel: s.t('cook.timer.done'),
              dismissLabel: s.t('cook.dismiss'),
              onDismiss: () => setState(() => _alertStep = null),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppStrings s,
    String lang,
    bool reduceMotion,
  ) {
    if (_loading) {
      return Center(
        child: Text(
          s.t('common.loading'),
          style: AppText.monoLabel(color: _soft),
        ),
      );
    }
    final recipe = _recipe;
    if (recipe == null || recipe.steps.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.t('cook.missing'), style: AppText.body(color: _soft)),
            const SizedBox(height: 16),
            _outlineButton(
              label: s.t('common.back'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
    if (_finished) return _buildCompletion(s, lang);

    final n = recipe.steps.length;
    final isLast = _stepIndex >= n - 1;

    return Column(
      children: [
        _progressBar((_stepIndex + 1) / n),
        _header(s),
        if (_resumed)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              s.t('cook.resumed'),
              style: AppText.handwritten(size: 18, color: AppColors.mustard),
            ),
          ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _oneHanded.onTap(() {
              HapticFeedback.lightImpact();
              _next();
            }),
            child: AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 250),
              child: _buildStep(s, lang, key: ValueKey(_stepIndex)),
            ),
          ),
        ),
        _bottomBar(s, isLast),
      ],
    );
  }

  Widget _progressBar(double fraction) {
    return SizedBox(
      height: 3,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction.clamp(0.0, 1.0).toDouble(),
          child: Container(color: _stripe),
        ),
      ),
    );
  }

  Widget _header(AppStrings s) {
    final n = _recipe!.steps.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: _soft, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          Text(
            '${s.t('cook.step')} ${_stepIndex + 1} / $n',
            style: AppText.monoLabel(size: 12, color: _soft),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(AppStrings s, String lang, {required Key key}) {
    final recipe = _recipe!;
    final step = recipe.steps[_stepIndex];
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_stepIndex + 1}',
            style: AppText.masthead(size: 72, color: _stripe),
          ),
          const SizedBox(height: 20),
          Text(
            localize(step.text, lang),
            style: AppText.body(size: 26, color: _paper),
          ),
          if (step.timerSeconds != null) ...[
            const SizedBox(height: 28),
            _timerCard(s, _stepIndex),
          ],
          const SizedBox(height: 28),
          _servingsRow(s),
          const SizedBox(height: 12),
          _miseSection(s, lang),
        ],
      ),
    );
  }

  Widget _timerCard(AppStrings s, int stepIndex) {
    final t = _timerFor(stepIndex);
    final label = t.done
        ? s.t('cook.timer.done')
        : t.running
        ? s.t('cook.timer.pause')
        : (t.remaining < t.totalSeconds
              ? s.t('cook.timer.resume')
              : s.t('cook.timer.start'));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: _faint, width: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          if (t.done)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                s.t('cook.timer.done'),
                style: AppText.handwritten(size: 24, color: AppColors.coral),
              ),
            ),
          Text(
            _clock(t.remaining),
            style: TextStyle(
              fontFamily: AppText.mono,
              fontSize: 44,
              fontWeight: FontWeight.w500,
              color: t.done ? AppColors.coral : _paper,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _outlineButton(
                label: label,
                onPressed: () => _toggleTimer(stepIndex),
              ),
              const SizedBox(width: 12),
              _outlineButton(
                label: s.t('cook.timer.reset'),
                onPressed: () => _resetTimer(stepIndex),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _servingsRow(AppStrings s) {
    return Row(
      children: [
        Text(
          s.t('cook.servings'),
          style: AppText.monoLabel(size: 11, color: _soft),
        ),
        const Spacer(),
        _stepperButton(
          icon: Icons.remove,
          onPressed: _servings > 1 ? () => setState(() => _servings--) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '$_servings',
            style: AppText.monoLabel(size: 14, color: _paper),
          ),
        ),
        _stepperButton(
          icon: Icons.add,
          onPressed: _servings < 12 ? () => setState(() => _servings++) : null,
        ),
      ],
    );
  }

  Widget _miseSection(AppStrings s, String lang) {
    final recipe = _recipe!;
    final factor = _servings / recipe.servings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _miseExpanded = !_miseExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(
                  s.t('cook.mise'),
                  style: AppText.monoLabel(size: 11, color: _soft),
                ),
                const Spacer(),
                Icon(
                  _miseExpanded ? Icons.expand_less : Icons.expand_more,
                  color: _soft,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        if (_miseExpanded)
          ...recipe.ingredients.map((i) {
            final note = localize(i.note, lang);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      '${_amount(i.amount * factor)} ${i.unit}',
                      style: AppText.monoLabel(size: 12, color: _soft),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      note.isEmpty
                          ? localize(i.name, lang)
                          : '${localize(i.name, lang)} — $note',
                      style: AppText.monoLabel(
                        size: 12,
                        color: _faint,
                      ).copyWith(letterSpacing: 0.4, height: 1.4),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _bottomBar(AppStrings s, bool isLast) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Row(
        children: [
          _outlineButton(
            label: s.t('cook.prev'),
            onPressed: _stepIndex > 0 ? () => _goTo(_stepIndex - 1) : null,
          ),
          const Spacer(),
          _outlineButton(
            label: isLast ? s.t('cook.finish') : s.t('cook.next'),
            onPressed: _next,
          ),
        ],
      ),
    );
  }

  Widget _buildCompletion(AppStrings s, String lang) {
    final name = _dish != null
        ? localize(_dish!.name, lang)
        : localize(_recipe!.title, lang);
    return Column(
      children: [
        _progressBar(1),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.t('cook.done'),
                  style: AppText.masthead(size: 64, color: _paper),
                ),
                const SizedBox(height: 8),
                Text(
                  s.t('cook.plates'),
                  style: AppText.handwritten(
                    size: 28,
                    color: AppColors.tealSoft,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name.toLowerCase(),
                  style: AppText.monoLabel(size: 12, color: _soft),
                ),
                const SizedBox(height: 40),
                _outlineButton(
                  label: s.t('cook.back.recipe'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---- small widgets ---------------------------------------------------------

  Widget _outlineButton({required String label, VoidCallback? onPressed}) {
    final enabled = onPressed != null;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: enabled ? _paper.withValues(alpha: 0.7) : _faint,
            width: 0.8,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: AppText.monoLabel(size: 12, color: enabled ? _paper : _faint),
        ),
      ),
    );
  }

  Widget _stepperButton({required IconData icon, VoidCallback? onPressed}) {
    final enabled = onPressed != null;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: enabled ? _soft : _faint, width: 0.8),
        ),
        child: Icon(icon, size: 16, color: enabled ? _paper : _faint),
      ),
    );
  }
}

/// Mutable state of one step's countdown timer.
class _StepTimer {
  _StepTimer(this.totalSeconds) : remaining = totalSeconds;

  final int totalSeconds;
  int remaining;
  bool running = false;
  bool done = false;
  Timer? ticker;
}

/// Full-screen timer alert. With [flash], alternates coral/teal three times
/// (~600ms per cycle) for deaf/hard-of-hearing users, then settles into a
/// calm teal banner. Without [flash] (reduce motion), only the calm banner.
/// Tap anywhere to dismiss.
class _TimerAlertOverlay extends StatefulWidget {
  const _TimerAlertOverlay({
    required this.flash,
    required this.doneLabel,
    required this.dismissLabel,
    required this.onDismiss,
  });

  final bool flash;
  final String doneLabel;
  final String dismissLabel;
  final VoidCallback onDismiss;

  @override
  State<_TimerAlertOverlay> createState() => _TimerAlertOverlayState();
}

class _TimerAlertOverlayState extends State<_TimerAlertOverlay> {
  /// 3 full coral→teal cycles = 6 half-cycles of 300ms.
  static const _halfCycles = 6;

  int _phase = 0;
  Timer? _ticker;

  bool get _flashing => widget.flash && _phase < _halfCycles;

  @override
  void initState() {
    super.initState();
    if (widget.flash) {
      _ticker = Timer.periodic(const Duration(milliseconds: 300), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => _phase++);
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _flashing && _phase.isOdd ? AppColors.teal : AppColors.coral;
    return GestureDetector(
      onTap: widget.onDismiss,
      child: Container(
        color: _flashing
            ? color.withValues(alpha: 0.94)
            : AppColors.teal.withValues(alpha: 0.97),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.doneLabel,
                  style: AppText.masthead(size: 56, color: AppColors.paper),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.dismissLabel,
                  style: AppText.monoLabel(
                    size: 12,
                    color: AppColors.paper.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
