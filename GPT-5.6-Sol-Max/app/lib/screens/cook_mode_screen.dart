import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/brand.dart';
import '../core/copy.dart';
import '../models/localized_text.dart';
import '../models/recipe.dart';
import '../state/app_controller.dart';
import '../state/cook_session_controller.dart';
import '../widgets/paper.dart';

class CookModeScreen extends StatefulWidget {
  const CookModeScreen({
    super.key,
    required this.recipe,
    required this.initialServings,
  });

  final Recipe recipe;
  final int initialServings;

  @override
  State<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends State<CookModeScreen>
    with WidgetsBindingObserver {
  CookSessionController? _session;
  bool _recorded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_session == null) {
      final app = context.read<AppController>();
      final reduce =
          app.profile.reduceMotion ?? MediaQuery.disableAnimationsOf(context);
      _session = CookSessionController(
        app: app,
        recipe: widget.recipe,
        reduceMotion: reduce,
      )..addListener(_sessionChanged);
      if (_session!.servings == widget.recipe.servings &&
          widget.initialServings != widget.recipe.servings) {
        _session!.setServings(widget.initialServings);
      }
      WidgetsBinding.instance.addObserver(this);
    }
  }

  void _sessionChanged() {
    final session = _session!;
    if (session.completed && !_recorded) {
      _recorded = true;
      session.app.completeCook(widget.recipe, session.servings);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _session?.paused == false) {
      _session?.pauseTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session
      ?..removeListener(_sessionChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) return const SizedBox.shrink();
    return ChangeNotifierProvider<CookSessionController>.value(
      value: session,
      child: const _CookModeBody(),
    );
  }
}

class _CookModeBody extends StatelessWidget {
  const _CookModeBody();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CookSessionController>();
    final app = context.read<AppController>();
    final lang = app.language;
    if (session.completed) return _Completion(session: session, language: lang);
    final alertColor = session.timerFinished
        ? (session.alertAlternate ? BrandColors.teal : BrandColors.coral)
        : BrandColors.cookInk;
    return Scaffold(
      backgroundColor: alertColor,
      body: AnimatedContainer(
        duration: session.reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 180),
        color: alertColor,
        child: PaperBackground(
          dark: true,
          color: alertColor,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(7, 5, 12, 3),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        color: BrandColors.cookPaper,
                        icon: const Icon(Icons.close),
                      ),
                      Expanded(
                        child: Text(
                          session.recipe.title.value(lang),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            fontSize: 19,
                            color: BrandColors.cookPaper,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            session.setServings(session.servings - 1),
                        color: BrandColors.cookPaper,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '${session.servings}',
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontWeight: FontWeight.bold,
                          color: BrandColors.cookPaper,
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            session.setServings(session.servings + 1),
                        color: BrandColors.cookPaper,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ),
                LinearProgressIndicator(
                  value: session.progress,
                  minHeight: 4,
                  backgroundColor: Colors.white12,
                  color: BrandColors.coralLight,
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: session.quickNext,
                    child: AnimatedSwitcher(
                      duration: session.reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 300),
                      child: SingleChildScrollView(
                        key: ValueKey(session.stepIndex),
                        padding: const EdgeInsets.fromLTRB(24, 36, 24, 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${Copy.text('step', lang).toUpperCase()} ${session.stepIndex + 1} / ${session.recipe.steps.length}',
                              style: const TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 1.2,
                                color: BrandColors.coralLight,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              session.step.text.value(lang),
                              style: const TextStyle(
                                fontFamily: 'PlayfairDisplay',
                                fontSize: 34,
                                fontWeight: FontWeight.w600,
                                height: 1.18,
                                color: BrandColors.cookPaper,
                              ),
                            ),
                            if (session.step.tip.isNotEmpty) ...[
                              const SizedBox(height: 25),
                              Transform.rotate(
                                angle: -.015,
                                child: Text(
                                  session.step.tip.value(lang),
                                  style: const TextStyle(
                                    fontFamily: 'Caveat',
                                    fontSize: 25,
                                    height: 1.05,
                                    color: BrandColors.tealLight,
                                  ),
                                ),
                              ),
                            ],
                            if (session.oneHanded.quickNextTapEnabled) ...[
                              const SizedBox(height: 24),
                              Text(
                                lang == 'de'
                                    ? 'einmal tippen → weiter'
                                    : 'single tap → next',
                                style: const TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 10,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (session.step.timerSeconds != null)
                  _TimerPanel(session: session, language: lang),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: BrandColors.cookPaper,
                            side: const BorderSide(
                              color: BrandColors.cookPaper,
                            ),
                          ),
                          onPressed: session.hasPrevious
                              ? session.previous
                              : null,
                          icon: const Icon(Icons.arrow_back),
                          label: Text(
                            Copy.text('previous', lang).toUpperCase(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: BrandColors.cookPaper,
                            foregroundColor: BrandColors.cookInk,
                          ),
                          onPressed: session.next,
                          icon: Icon(
                            session.hasNext ? Icons.arrow_forward : Icons.check,
                          ),
                          label: Text(
                            Copy.text(
                              session.hasNext ? 'next' : 'finish',
                              lang,
                            ).toUpperCase(),
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
    );
  }
}

class _TimerPanel extends StatelessWidget {
  const _TimerPanel({required this.session, required this.language});
  final CookSessionController session;
  final String language;

  @override
  Widget build(BuildContext context) {
    final minutes = session.remainingSeconds ~/ 60;
    final seconds = session.remainingSeconds % 60;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      decoration: BoxDecoration(
        color: session.timerFinished
            ? Colors.white.withValues(alpha: .2)
            : Colors.white.withValues(alpha: .07),
        border: Border.all(color: BrandColors.cookPaper.withValues(alpha: .75)),
      ),
      child: Row(
        children: [
          Icon(
            session.timerFinished
                ? Icons.notifications_active
                : Icons.timer_outlined,
            color: BrandColors.cookPaper,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.timerFinished
                      ? Copy.text('timer_done', language).toUpperCase()
                      : '$minutes:${seconds.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: BrandColors.cookPaper,
                  ),
                ),
              ],
            ),
          ),
          if (session.timerFinished)
            IconButton(
              onPressed: session.dismissAlert,
              color: BrandColors.cookPaper,
              icon: const Icon(Icons.close),
            )
          else ...[
            IconButton(
              tooltip: Copy.text('reset', language),
              onPressed: session.resetTimer,
              color: BrandColors.cookPaper,
              icon: const Icon(Icons.replay),
            ),
            IconButton(
              tooltip: Copy.text(session.paused ? 'resume' : 'pause', language),
              onPressed: session.paused
                  ? session.startTimer
                  : session.pauseTimer,
              color: BrandColors.cookPaper,
              icon: Icon(session.paused ? Icons.play_arrow : Icons.pause),
            ),
          ],
        ],
      ),
    );
  }
}

class _Completion extends StatelessWidget {
  const _Completion({required this.session, required this.language});
  final CookSessionController session;
  final String language;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BrandColors.cookInk,
    body: PaperBackground(
      dark: true,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: BrandColors.tealLight,
                  size: 72,
                ),
                const SizedBox(height: 25),
                Text(
                  Copy.text('cooked', language),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontStyle: FontStyle.italic,
                    fontSize: 45,
                    fontWeight: FontWeight.w600,
                    color: BrandColors.cookPaper,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  session.recipe.title.value(language),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 22,
                    color: BrandColors.cookPaper,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  Copy.text('cooked_note', language),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Caveat',
                    fontSize: 25,
                    color: BrandColors.coralLight,
                  ),
                ),
                const SizedBox(height: 35),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: BrandColors.cookPaper,
                    foregroundColor: BrandColors.cookInk,
                  ),
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  child: Text(Copy.text('return_home', language).toUpperCase()),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
