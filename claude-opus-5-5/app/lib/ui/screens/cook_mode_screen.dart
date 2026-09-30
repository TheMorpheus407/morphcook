import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/corpus_repository.dart';
import '../../i18n/strings.dart';
import '../../logic/quantities.dart';
import '../../models/recipe.dart';
import '../../state/cook_mode.dart';
import '../../state/library_store.dart';
import '../../state/profile_controller.dart';
import '../theme.dart';
import '../widgets/paper.dart';

/// Dark, full-bleed, one step at a time.
class CookModeScreen extends StatefulWidget {
  const CookModeScreen({super.key, required this.recipeId, this.servings});
  final String recipeId;
  final int? servings;

  @override
  State<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends State<CookModeScreen> with WidgetsBindingObserver {
  CookSession? _session;
  late final OneHandedCookModeController _oneHanded;
  bool _flashing = false;
  Timer? _flashTimer;
  int _direction = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final profile = context.read<ProfileController>().profile;
    _oneHanded = OneHandedCookModeController(quickNextTapEnabled: profile.quickNextTapEnabled);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final repo = context.read<CorpusRepository>();
    final library = context.read<LibraryStore>();
    await repo.ensureRecipes([widget.recipeId]);
    final recipe = repo.recipe(widget.recipeId);
    if (recipe == null || !mounted) return;
    var resume = library.progressFor(recipe.id);
    if (resume != null) {
      final tr = context.trRead;
      final yes = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(tr('cook.resume.title')),
          content: Text(tr('cook.resume.body', {'n': resume!.step + 1, 's': resume.servings})),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('cook.resume.no'), style: MT.mono(12)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: MC.ink),
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('cook.resume.yes'), style: MT.mono(12, color: MC.card)),
            ),
          ],
        ),
      );
      if (yes != true) {
        await library.clearProgress(recipe.id);
        resume = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _session = CookSession(recipe: recipe, library: library, servings: widget.servings, resumeFrom: resume)
        ..onTimerDone = _onTimerDone;
    });
    _session!.persist();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _session?.persist();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flashTimer?.cancel();
    final s = _session;
    if (s != null && !s.completed) s.pauseSession();
    s?.dispose();
    _oneHanded.dispose();
    super.dispose();
  }

  void _onTimerDone() {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    final profile = context.read<ProfileController>().profile;
    if (!profile.visualAlertEnabled || !mounted) return;
    setState(() => _flashing = true);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 3600), () {
      if (mounted) setState(() => _flashing = false);
    });
  }

  void _next() {
    _direction = 1;
    _session?.next();
  }

  void _prev() {
    _direction = -1;
    _session?.previous();
  }

  Future<void> _pause() async {
    await _session?.pauseSession();
    if (!mounted) return;
    final tr = context.trRead;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(tr('cook.paused'))));
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    _oneHanded.reduceMotion = reduce;
    final session = _session;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: MC.night,
        body: PaperBackground(
          color: MC.night,
          dark: true,
          child: session == null
              ? const Center(child: CircularProgressIndicator(color: MC.coral))
              : ListenableBuilder(
                  listenable: session,
                  builder: (context, _) => Stack(
                    children: [
                      SafeArea(
                        child: session.completed
                            ? _Completion(session: session)
                            : _StepView(
                                session: session,
                                oneHanded: _oneHanded,
                                direction: _direction,
                                onNext: _next,
                                onPrev: _prev,
                                onPause: _pause,
                              ),
                      ),
                      if (_flashing) Positioned.fill(child: _VisualAlert(reduceMotion: reduce)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _StepView extends StatelessWidget {
  const _StepView({
    required this.session,
    required this.oneHanded,
    required this.direction,
    required this.onNext,
    required this.onPrev,
    required this.onPause,
  });

  final CookSession session;
  final OneHandedCookModeController oneHanded;
  final int direction;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final lang = tr.lang;
    final recipe = session.recipe;
    final duration = oneHanded.transitionDuration;
    return Column(
      children: [
        // top bar
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 12, 0),
          child: Row(
            children: [
              IconButton(
                key: const Key('cook-close'),
                tooltip: tr('common.close'),
                onPressed: onPause,
                icon: const Icon(Icons.close, color: MC.nightInk),
              ),
              Expanded(
                child: Text(
                  recipe.title.of(lang).toLowerCase(),
                  style: MT.display(18, color: MC.nightInk),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _ServingsControl(session: session),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
          child: Row(
            children: [
              Text(
                tr('cook.step', {'n': session.step + 1, 'total': session.stepCount}),
                style: MT.mono(11, color: MC.nightSoft),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _showIngredients(context),
                child: Row(
                  children: [
                    const Icon(Icons.format_list_bulleted, size: 15, color: MC.nightSoft),
                    const SizedBox(width: 4),
                    Text(tr('cook.ingredients'), style: MT.mono(11, color: MC.nightSoft)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: session.progress,
              minHeight: 3,
              backgroundColor: MC.nightCard,
              color: MC.coral,
            ),
          ),
        ),
        // step content — the quick-tap target
        Expanded(
          child: GestureDetector(
            key: const Key('step-content'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (oneHanded.registerTap()) onNext();
            },
            child: AnimatedSwitcher(
              duration: duration,
              transitionBuilder: (child, anim) {
                if (duration == Duration.zero) return child;
                final offset = Tween<Offset>(begin: Offset(0.06 * direction, 0), end: Offset.zero).animate(anim);
                return FadeTransition(
                  opacity: anim,
                  child: SlideTransition(position: offset, child: child),
                );
              },
              child: SingleChildScrollView(
                key: ValueKey(session.step),
                padding: const EdgeInsets.fromLTRB(28, 30, 28, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${session.step + 1}.', style: MT.display(64, color: MC.coral)),
                    const SizedBox(height: 8),
                    Text(session.current.text.of(lang), style: MT.serif(25, color: MC.nightInk, height: 1.45)),
                    if (oneHanded.quickNextTapEnabled) ...[
                      const SizedBox(height: 18),
                      Text(tr('cook.tap.hint'), style: MT.hand(19, color: MC.nightSoft)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (session.hasTimer) _TimerPanel(session: session),
        // bottom controls
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: _NightButton(
                  key: const Key('cook-prev'),
                  label: tr('cook.prev'),
                  icon: Icons.arrow_back,
                  onPressed: session.isFirst ? null : onPrev,
                ),
              ),
              const SizedBox(width: 10),
              _NightButton(
                key: const Key('cook-pause'),
                label: tr('cook.pause'),
                icon: Icons.pause,
                onPressed: onPause,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _NightButton(
                  key: const Key('cook-next'),
                  label: session.isLast ? tr('cook.finish') : tr('cook.next'),
                  icon: session.isLast ? Icons.check : Icons.arrow_forward,
                  filled: true,
                  onPressed: onNext,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showIngredients(BuildContext context) {
    final repo = context.read<CorpusRepository>();
    final lang = context.trRead.lang;
    final recipe = session.recipe;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MC.nightCard,
      builder: (context) => ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          for (final ing in recipe.ingredients)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      formatAmount(scaleQty(ing.qty, recipe.servings, session.servings), ing.unit, repo.ontology, lang),
                      style: MT.mono(12, color: MC.mustard),
                    ),
                  ),
                  Expanded(
                    child: Text(repo.ingredients.name(ing.id, lang), style: MT.serif(16, color: MC.nightInk)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ServingsControl extends StatelessWidget {
  const _ServingsControl({required this.session});
  final CookSession session;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('cook-servings-minus'),
          visualDensity: VisualDensity.compact,
          onPressed: session.servings > 1 ? () => session.setServings(session.servings - 1) : null,
          icon: const Icon(Icons.remove, size: 18, color: MC.nightInk),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${session.servings}', style: MT.display(20, color: MC.nightInk)),
            Text(tr('dish.servings'), style: MT.mono(8, color: MC.nightSoft)),
          ],
        ),
        IconButton(
          key: const Key('cook-servings-plus'),
          visualDensity: VisualDensity.compact,
          onPressed: () => session.setServings(session.servings + 1),
          icon: const Icon(Icons.add, size: 18, color: MC.nightInk),
        ),
      ],
    );
  }
}

class _TimerPanel extends StatelessWidget {
  const _TimerPanel({required this.session});
  final CookSession session;

  String _fmt(int s) {
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    final mm = m.toString().padLeft(2, '0'), ss = sec.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final total = session.current.timerSeconds ?? 1;
    final status = session.timerStatus;
    final done = status == TimerStatus.done;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: MC.nightCard, borderRadius: BorderRadius.circular(3)),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CustomPaint(
              painter: _RingPainter(progress: 1 - session.remaining / total, done: done),
              child: Center(
                child: Icon(
                  done ? Icons.notifications_active : Icons.timer_outlined,
                  color: done ? MC.coral : MC.nightInk,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  done ? tr('cook.timer.done') : _fmt(session.remaining),
                  key: const Key('timer-text'),
                  style: done ? MT.hand(30, color: MC.coral) : MT.mono(30, color: MC.nightInk, weight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    if (status == TimerStatus.idle)
                      _SmallNight(
                        key: const Key('timer-start'),
                        label: tr('cook.timer.start'),
                        onTap: session.startTimer,
                      ),
                    if (status == TimerStatus.running)
                      _SmallNight(
                        key: const Key('timer-pause'),
                        label: tr('cook.timer.pause'),
                        onTap: session.pauseTimer,
                      ),
                    if (status == TimerStatus.paused)
                      _SmallNight(
                        key: const Key('timer-resume'),
                        label: tr('cook.timer.resume'),
                        onTap: session.startTimer,
                      ),
                    if (status != TimerStatus.idle)
                      _SmallNight(
                        key: const Key('timer-reset'),
                        label: tr('cook.timer.reset'),
                        onTap: session.resetTimer,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.done});
  final double progress;
  final bool done;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = MC.night;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = done ? MC.coral : MC.teal;
    canvas.drawArc(rect.deflate(3), 0, 2 * pi, false, track);
    canvas.drawArc(rect.deflate(3), -pi / 2, 2 * pi * progress.clamp(0, 1), false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress || old.done != done;
}

class _SmallNight extends StatelessWidget {
  const _SmallNight({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Text(
        label,
        style: MT
            .mono(12, color: MC.mustard)
            .copyWith(decoration: TextDecoration.underline, decorationColor: MC.mustard),
      ),
    ),
  );
}

class _NightButton extends StatelessWidget {
  const _NightButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: filled ? MC.coral : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(color: filled ? MC.coral : (enabled ? MC.nightSoft : MC.nightCard)),
      ),
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: filled ? MC.night : (enabled ? MC.nightInk : MC.nightCard)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: MT.mono(
                    13,
                    color: filled ? MC.night : (enabled ? MC.nightInk : MC.nightCard),
                    weight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Coral/teal flash for deaf and hard-of-hearing cooks. Under reduced motion
/// it is a steady two-colour frame instead of a flash.
class _VisualAlert extends StatefulWidget {
  const _VisualAlert({required this.reduceMotion});
  final bool reduceMotion;

  @override
  State<_VisualAlert> createState() => _VisualAlertState();
}

class _VisualAlertState extends State<_VisualAlert> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

  @override
  void initState() {
    super.initState();
    if (!widget.reduceMotion) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Semantics(
        liveRegion: true,
        label: context.tr('cook.timer.done'),
        child: widget.reduceMotion
            ? Container(
                key: const Key('visual-alert-static'),
                decoration: BoxDecoration(border: Border.all(color: MC.coral, width: 14)),
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: MC.teal, width: 8)),
                ),
              )
            : AnimatedBuilder(
                key: const Key('visual-alert-flash'),
                animation: _c,
                builder: (_, __) {
                  final coral = _c.value < 0.5;
                  final strength = sin(_c.value * 2 * pi).abs();
                  return ColoredBox(color: (coral ? MC.coral : MC.teal).withValues(alpha: 0.25 + 0.4 * strength));
                },
              ),
      ),
    );
  }
}

class _Completion extends StatelessWidget {
  const _Completion({required this.session});
  final CookSession session;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final library = context.watch<LibraryStore>();
    final Recipe recipe = session.recipe;
    final saved = library.isSaved(recipe.id);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('&', style: MT.display(120, color: MC.coral)),
            Text(
              tr('cook.done.title'),
              style: MT.display(40, color: MC.nightInk),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              recipe.title.of(tr.lang).toLowerCase(),
              style: MT.hand(26, color: MC.mustard),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              tr('cook.done.body'),
              style: MT.serif(16, color: MC.nightSoft),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            if (!saved) ...[
              _NightButton(
                key: const Key('done-save'),
                label: tr('cook.done.save'),
                icon: Icons.bookmark_border,
                onPressed: () => library.toggleSaved(recipe.id),
              ),
              const SizedBox(height: 12),
            ],
            _NightButton(
              key: const Key('done-back'),
              label: tr('cook.done.back'),
              icon: Icons.arrow_back,
              filled: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
