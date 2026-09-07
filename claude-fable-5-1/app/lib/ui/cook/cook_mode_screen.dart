import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models/history_entry.dart';
import '../../data/models/recipe.dart';
import '../../domain/cook_session.dart';
import '../../state/app_controller.dart';
import '../../theme/motion.dart';
import '../../theme/palette.dart';
import '../../theme/theme.dart';
import '../../theme/typography.dart';
import '../../theme/widgets.dart';
import '../dish/ingredient_list.dart';
import '../l10n.dart';

/// Dark, full-bleed, one step at a time.
class CookModeScreen extends StatefulWidget {
  const CookModeScreen({super.key, required this.recipe, this.servings, this.resume = false});
  final Recipe recipe;
  final int? servings;
  final bool resume;

  @override
  State<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends State<CookModeScreen> with SingleTickerProviderStateMixin {
  late final AppController _app;
  late final CookModeController _cook;
  late final OneHandedCookModeController _oneHanded;
  late final AnimationController _flash;
  int _seenAlerts = 0;
  bool _bannerVisible = false;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    final app = _app = context.read<AppController>();
    final resume = widget.resume ? app.progressFor(widget.recipe.id) : null;
    _cook = CookModeController(
      recipe: widget.recipe,
      servings: widget.servings,
      resume: resume,
      onProgress: (p) => app.saveProgress(p),
    );
    _seenAlerts = _cook.alertCount;
    _oneHanded = OneHandedCookModeController(quickNextTapEnabled: app.profile.quickNextTapEnabled);
    _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _cook.addListener(_onCook);
    if (resume == null) app.saveProgress(_cook.snapshot());
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(systemNavigationBarColor: Palette.night));
  }

  void _onCook() {
    if (_cook.alertCount != _seenAlerts) {
      _seenAlerts = _cook.alertCount;
      _timerEnded();
    }
    if (mounted) setState(() {});
  }

  Future<void> _timerEnded() async {
    HapticFeedback.heavyImpact();
    if (!_app.profile.visualAlertEnabled) return;
    if (Motion.reduced(context)) {
      setState(() => _bannerVisible = true);
      _bannerTimer?.cancel();
      _bannerTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _bannerVisible = false);
      });
      return;
    }
    for (var i = 0; i < 6 && mounted; i++) {
      await _flash.forward(from: 0);
      await _flash.reverse();
    }
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _cook.removeListener(_onCook);
    // No context lookups here: the element may already be deactivated.
    if (!_cook.completed) _app.saveProgress(_cook.snapshot());
    _cook.dispose();
    _flash.dispose();
    _oneHanded.dispose();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(systemNavigationBarColor: Palette.paper));
    super.dispose();
  }

  Future<void> _finish() async {
    _cook.complete();
    await _app.addHistory(HistoryEntry(recipeId: widget.recipe.id, dishId: widget.recipe.dishId, cookedAt: _app.now(), servings: _cook.servings));
    await _app.clearProgress(widget.recipe.id);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final lang = context.lang;
    final app = context.watch<AppController>();
    final quick = app.profile.quickNextTapEnabled;
    _oneHanded.quickNextTapEnabled = quick;
    final r = widget.recipe;
    final step = _cook.step;
    final timer = _cook.timer;

    return Theme(
      data: MorphTheme.night(),
      child: Scaffold(
        backgroundColor: Palette.night,
        body: Stack(
          children: [
            SafeArea(
              child: _cook.completed
                  ? _Completion(recipe: r, onClose: () => Navigator.of(context).pop())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TopBar(cook: _cook, onLeave: () => Navigator.of(context).pop()),
                        LinearProgressIndicator(value: _cook.progress, minHeight: 2, color: Palette.nightInk, backgroundColor: Palette.nightRule),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: quick
                                ? () {
                                    if (_cook.isLast) return;
                                    _oneHanded.handleTap(_cook, haptic: HapticFeedback.mediumImpact);
                                  }
                                : null,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                              child: AnimatedSwitcher(
                                duration: Motion.duration(context, const Duration(milliseconds: 220)),
                                child: Column(
                                  key: ValueKey(_cook.stepIndex),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.title.of(lang).toLowerCase(), style: AppText.title(size: 15, italic: true, color: Palette.nightInkFaint)),
                                    const SizedBox(height: 18),
                                    Text('${_cook.stepIndex + 1}.', style: AppText.display(size: 30, color: Palette.nightInkFaint)),
                                    const SizedBox(height: 8),
                                    Text(step?.text.of(lang) ?? '', style: AppText.body(color: Palette.nightInk, size: 22).copyWith(height: 1.45)),
                                    if (quick) ...[
                                      const SizedBox(height: 18),
                                      HandNote(s('cook.quickTapHint'), color: Palette.nightInkFaint, size: 18),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_bannerVisible)
                          Container(
                            color: Palette.flashCoral,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(child: Text(s('cook.timerEnded').toUpperCase(), style: AppText.mono(color: Palette.night, size: 13, weight: FontWeight.w700))),
                          ),
                        _TimerPanel(cook: _cook, timer: timer),
                        _BottomBar(cook: _cook, onFinish: _finish, onIngredients: () => _showIngredients(context)),
                      ],
                    ),
            ),
            if (_cook.paused && !_cook.completed) _PausedOverlay(onResume: _cook.resumeSession, onLeave: () => Navigator.of(context).pop()),
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _flash,
                builder: (_, _) {
                  if (_flash.value == 0) return const SizedBox.shrink();
                  final coral = (_seenAlerts % 2 == 0);
                  return Container(
                    color: (coral ? Palette.flashCoral : Palette.flashTeal).withValues(alpha: 0.55 * _flash.value),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showIngredients(BuildContext context) {
    final s = context.s;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Palette.nightSurface,
      builder: (_) => Theme(
        data: MorphTheme.night(),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.94,
          builder: (context, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 30),
            children: [
              MonoLabel(s('cook.allIngredients'), color: Palette.nightInkFaint),
              const SizedBox(height: 4),
              Text(s.servings(_cook.servings), style: AppText.title(size: 20, italic: true, color: Palette.nightInk)),
              const SizedBox(height: 12),
              IngredientList(recipe: widget.recipe, scale: _cook.scale, dark: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.cook, required this.onLeave});
  final CookModeController cook;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.close, color: Palette.nightInk), tooltip: s('cook.leave'), onPressed: onLeave),
          Expanded(child: MonoLabel(s('cook.step', {'n': '${cook.stepIndex + 1}', 'total': '${cook.stepCount}'}), color: Palette.nightInkSoft)),
          IconButton(
            icon: const Icon(Icons.pause_circle_outline, color: Palette.nightInk),
            tooltip: s('cook.pause'),
            onPressed: cook.pauseSession,
          ),
          _Stepper(value: cook.servings, onChanged: cook.setServings),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(icon: const Icon(Icons.remove, size: 18, color: Palette.nightInk), onPressed: value > 1 ? () => onChanged(value - 1) : null, visualDensity: VisualDensity.compact),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$value', style: AppText.title(size: 17, color: Palette.nightInk)),
            MonoLabel(s('cook.servings'), color: Palette.nightInkFaint, size: 9),
          ],
        ),
        IconButton(icon: const Icon(Icons.add, size: 18, color: Palette.nightInk), onPressed: () => onChanged(value + 1), visualDensity: VisualDensity.compact),
      ],
    );
  }
}

class _TimerPanel extends StatelessWidget {
  const _TimerPanel({required this.cook, required this.timer});
  final CookModeController cook;
  final StepTimer? timer;

  static String _fmt(int secs) {
    final m = secs ~/ 60;
    final sec = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final t = timer;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Palette.nightRule))),
      child: t == null
          ? Row(
              children: [
                MonoLabel(s('cook.timer.custom'), color: Palette.nightInkFaint),
                const SizedBox(width: 12),
                for (final m in const [1, 3, 5, 10, 15])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => cook.startTimer(m * 60),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(border: Border.all(color: Palette.nightRule), borderRadius: BorderRadius.circular(4)),
                        child: Text('$m', style: AppText.mono(color: Palette.nightInk, size: 12)),
                      ),
                    ),
                  ),
              ],
            )
          : Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MonoLabel(t.done ? s('cook.timerEnded') : s('cook.timer.done'), color: t.done ? Palette.flashCoral : Palette.nightInkFaint),
                    Text(_fmt(t.remaining), style: AppText.mono(color: Palette.nightInk, size: 34, weight: FontWeight.w600).copyWith(height: 1.1, fontFeatures: const [FontFeature.tabularFigures()])),
                  ],
                ),
                const Spacer(),
                IconButton(icon: const Icon(Icons.remove, color: Palette.nightInkSoft), tooltip: '-1 min', onPressed: () => cook.adjustTimer(-60), visualDensity: VisualDensity.compact),
                IconButton(icon: const Icon(Icons.add, color: Palette.nightInkSoft), tooltip: '+1 min', onPressed: () => cook.adjustTimer(60), visualDensity: VisualDensity.compact),
                const SizedBox(width: 6),
                if (t.done)
                  PaperButton(label: s('cook.timer.reset'), kind: PaperButtonKind.secondary, dark: true, onPressed: cook.resetTimer)
                else if (t.running)
                  PaperButton(label: s('cook.timer.pause'), kind: PaperButtonKind.secondary, dark: true, icon: Icons.pause, onPressed: cook.pauseTimer)
                else
                  PaperButton(
                    label: t.remaining == t.total ? s('cook.timer.start') : s('cook.timer.resume'),
                    dark: true,
                    icon: Icons.play_arrow,
                    onPressed: t.remaining == t.total ? () => cook.startTimer() : cook.resumeTimer,
                  ),
              ],
            ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.cook, required this.onFinish, required this.onIngredients});
  final CookModeController cook;
  final Future<void> Function() onFinish;
  final VoidCallback onIngredients;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      child: Row(
        children: [
          PaperButton(label: s('cook.prev'), kind: PaperButtonKind.secondary, dark: true, icon: Icons.chevron_left, onPressed: cook.isFirst ? null : cook.prev),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.list_alt_outlined, color: Palette.nightInk), tooltip: s('cook.allIngredients'), onPressed: onIngredients),
          const Spacer(),
          if (cook.isLast)
            PaperButton(label: s('cook.finish'), dark: true, icon: Icons.check, onPressed: onFinish)
          else
            PaperButton(label: s('cook.next'), dark: true, icon: Icons.chevron_right, onPressed: cook.next),
        ],
      ),
    );
  }
}

class _PausedOverlay extends StatelessWidget {
  const _PausedOverlay({required this.onResume, required this.onLeave});
  final VoidCallback onResume;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Positioned.fill(
      child: Container(
        color: Palette.night.withValues(alpha: 0.92),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(s('cook.paused'), textAlign: TextAlign.center, style: AppText.display(size: 28, color: Palette.nightInk)),
            const SizedBox(height: 10),
            HandNote(s('cook.leave.note'), color: Palette.nightInkSoft, align: TextAlign.center),
            const SizedBox(height: 26),
            PaperButton(label: s('cook.timer.resume'), dark: true, icon: Icons.play_arrow, onPressed: onResume),
            const SizedBox(height: 10),
            PaperButton(label: s('cook.leave'), kind: PaperButtonKind.quiet, dark: true, onPressed: onLeave),
          ],
        ),
      ),
    );
  }
}

class _Completion extends StatelessWidget {
  const _Completion({required this.recipe, required this.onClose});
  final Recipe recipe;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final app = context.watch<AppController>();
    final saved = app.isSaved(recipe.id);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('&', style: AppText.display(size: 64, color: Palette.nightInkFaint)),
          const SizedBox(height: 8),
          Text(s('cook.done.title'), style: AppText.display(size: 36, color: Palette.nightInk)),
          const SizedBox(height: 12),
          HandNote(s('cook.done.note'), color: Palette.nightInkSoft, size: 21),
          const SizedBox(height: 30),
          if (!saved)
            PaperButton(label: s('cook.done.save'), dark: true, icon: Icons.bookmark_border, onPressed: () => app.toggleSaved(recipe.id))
          else
            MonoLabel(s('dish.saved'), color: Palette.nightInkFaint),
          const SizedBox(height: 10),
          PaperButton(label: s('cook.done.close'), kind: PaperButtonKind.secondary, dark: true, onPressed: onClose),
        ],
      ),
    );
  }
}
