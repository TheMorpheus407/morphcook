import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/cook_controller.dart';
import '../../core/models.dart';
import '../../core/shopping.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';

class CookScreen extends StatefulWidget {
  final Recipe recipe;
  final int? initialServings;
  const CookScreen({super.key, required this.recipe, this.initialServings});
  @override
  State<CookScreen> createState() => _CookScreenState();
}

class _CookScreenState extends State<CookScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CookController? controller;
  late AnimationController flash;
  final gesture = OneHandedCookModeController();
  bool completed = false;
  bool alertShown = false;
  bool wasReduced = false;
  AppState? state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    flash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    state = AppScope.of(context);
    gesture.quickNextTapEnabled = state!.profile.quickNextTapEnabled;
    gesture.reduceMotion = reducedMotion(context);
    wasReduced = gesture.reduceMotion;
    if (controller == null) {
      final existing = state!.cookProgress;
      final progress = existing?['recipe_id'] == widget.recipe.id
          ? existing
          : {
              'step': 0,
              'servings': widget.initialServings ?? widget.recipe.servings,
            };
      controller = CookController(
        recipe: widget.recipe,
        progress: progress,
        persist: (value) {
          final snapshot = Map<String, dynamic>.of(value);
          Future.microtask(() {
            if (!completed) state!.persistCook(snapshot);
          });
        },
      );
      controller!.addListener(_onChange);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          state!.persistCook(controller!.toJson());
          _onChange();
        }
      });
    }
  }

  void _onChange() {
    if (!mounted) return;
    if (controller!.timerCompleted && !alertShown) {
      alertShown = true;
      if (state!.profile.visualAlertEnabled && !wasReduced) {
        flash.repeat(reverse: true);
      }
    } else if (!controller!.timerCompleted) {
      alertShown = false;
      flash.stop();
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) controller?.tick();
    if (lifecycle == AppLifecycleState.paused) {
      state?.persistCook(controller!.toJson());
      unawaited(state!.flush().catchError((Object _) {}));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.removeListener(_onChange);
    controller?.dispose();
    flash.dispose();
    super.dispose();
  }

  void pauseAndLeave() {
    if (!completed) controller!.pauseSession();
    Navigator.pop(context);
  }

  String timerText(int seconds) =>
      '${'${seconds ~/ 60}'.padLeft(2, '0')}:${'${seconds % 60}'.padLeft(2, '0')}';
  void advance() {
    if (controller!.step < widget.recipe.steps.length - 1) {
      controller!.move(1);
    } else if (!completed) {
      controller!.pauseSession();
      completed = true;
      state!.completeCook(widget.recipe, controller!.servings);
      flash.stop();
      setState(() {});
    }
  }

  void _ingredients() {
    kitchenSheet<void>(
      context,
      SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t(context, 'ingredients'), style: serif(28, italic: true)),
            const SizedBox(height: 10),
            Text(
              t(context, 'scaledNote', {'count': controller!.servings}),
              style: mono(11),
            ),
            const SizedBox(height: 15),
            ...widget.recipe.ingredients.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        textFor(
                          context,
                          state!.repository.dictionary.entries[item.id]!.name,
                        ),
                        style: mono(12),
                      ),
                    ),
                    Text(
                      '${quantityText(item.quantity * controller!.servings / widget.recipe.servings)} ${t(context, item.unit)}',
                      style: mono(11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cook = controller!;
    final step = widget.recipe.steps[cook.step];
    const light = Color(0xfff0ecdf);
    final visualAlert =
        cook.timerCompleted && state!.profile.visualAlertEnabled;
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && !completed) cook.pauseSession();
      },
      child: AnimatedBuilder(
        animation: flash,
        builder: (context, child) {
          final borderColor = visualAlert
              ? (reducedMotion(context)
                    ? KitchenColors.coral
                    : Color.lerp(
                        KitchenColors.coral,
                        const Color(0xff77b8a4),
                        flash.value,
                      )!)
              : Colors.transparent;
          return Scaffold(
            backgroundColor: KitchenColors.night,
            body: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: borderColor,
                  width: visualAlert ? 5 : 0,
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 750),
                    child: completed
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.restaurant_outlined,
                                  size: 55,
                                  color: Color(0xff9fbfa7),
                                ),
                                const SizedBox(height: 35),
                                Text(
                                  t(context, 'completeTitle'),
                                  style: serif(43, color: light, italic: true),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  t(context, 'completeBody'),
                                  style: mono(
                                    13,
                                    color: light.withValues(alpha: .7),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 30),
                                Text(
                                  textFor(context, widget.recipe.title),
                                  style: hand(
                                    31,
                                    color: const Color(0xff9fbfa7),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 50),
                                FilledButton(
                                  onPressed: () => Navigator.popUntil(
                                    context,
                                    (route) => route.isFirst,
                                  ),
                                  child: Text(t(context, 'backHome')),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  14,
                                  18,
                                  0,
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      tooltip: t(context, 'pauseSave'),
                                      onPressed: pauseAndLeave,
                                      icon: const Icon(
                                        Icons.close,
                                        color: light,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      t(context, 'cookMode'),
                                      style: mono(
                                        9,
                                        color: light.withValues(alpha: .65),
                                        spacing: 1.5,
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      tooltip: t(context, 'viewIngredients'),
                                      onPressed: _ingredients,
                                      icon: const Icon(
                                        Icons.list_alt_outlined,
                                        color: light,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 26,
                                  vertical: 16,
                                ),
                                child: Row(
                                  children: [
                                    for (
                                      var i = 0;
                                      i < widget.recipe.steps.length;
                                      i++
                                    )
                                      Expanded(
                                        child: Container(
                                          height: 3,
                                          margin: EdgeInsets.only(
                                            right:
                                                i ==
                                                    widget.recipe.steps.length -
                                                        1
                                                ? 0
                                                : 6,
                                          ),
                                          color: i <= cook.step
                                              ? const Color(0xff9fbfa7)
                                              : light.withValues(alpha: .15),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                    28,
                                    23,
                                    28,
                                    25,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        textFor(context, widget.recipe.title),
                                        style: hand(
                                          25,
                                          color: const Color(0xffa7c1ac),
                                        ),
                                      ),
                                      const SizedBox(height: 30),
                                      Text(
                                        t(context, 'stepCounter', {
                                          'step': cook.step + 1,
                                          'total': widget.recipe.steps.length,
                                        }),
                                        style: mono(
                                          11,
                                          color: light.withValues(alpha: .65),
                                          spacing: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 22),
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          if (gesture.acceptTap(
                                            DateTime.now(),
                                          )) {
                                            advance();
                                          }
                                        },
                                        child: AnimatedSwitcher(
                                          duration: motionDuration(context),
                                          child: Column(
                                            key: ValueKey(cook.step),
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                textFor(context, step.title),
                                                style: serif(
                                                  31,
                                                  color: light,
                                                  italic: true,
                                                ),
                                              ),
                                              const SizedBox(height: 22),
                                              Text(
                                                textFor(context, step.text),
                                                style: mono(
                                                  15,
                                                  color: light.withValues(
                                                    alpha: .85,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 28),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (gesture.quickNextTapEnabled)
                                        Text(
                                          t(context, 'tapToNext'),
                                          style: mono(
                                            10,
                                            color: const Color(0xffa7c1ac),
                                          ),
                                        ),
                                      if (step.timerSeconds > 0) ...[
                                        const SizedBox(height: 25),
                                        const DashedRule(
                                          color: Color(0xff4f5d54),
                                        ),
                                        const SizedBox(height: 22),
                                        Center(
                                          child: Text(
                                            timerText(
                                              cook.remainingSeconds > 0
                                                  ? cook.remainingSeconds
                                                  : step.timerSeconds,
                                            ),
                                            style: mono(48, color: light),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Center(
                                          child: FilledButton.icon(
                                            onPressed: cook.running
                                                ? cook.pauseTimer
                                                : cook.remainingSeconds > 0
                                                ? cook.resumeTimer
                                                : cook.startTimer,
                                            icon: Icon(
                                              cook.running
                                                  ? Icons.pause
                                                  : Icons.play_arrow,
                                              size: 20,
                                            ),
                                            label: Text(
                                              t(
                                                context,
                                                cook.running
                                                    ? 'pauseTimer'
                                                    : cook.remainingSeconds > 0
                                                    ? 'resumeTimer'
                                                    : 'startTimer',
                                                {
                                                  'time': timerText(
                                                    step.timerSeconds,
                                                  ),
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (cook.remainingSeconds > 0)
                                          Center(
                                            child: TextButton(
                                              onPressed: cook.startTimer,
                                              child: Text(
                                                t(context, 'resetTimer'),
                                                style: mono(
                                                  11,
                                                  color: const Color(
                                                    0xffa7c1ac,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                      if (cook.timerCompleted)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 20,
                                          ),
                                          child: Semantics(
                                            liveRegion: true,
                                            child: NoteCard(
                                              color: KitchenColors.coral,
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      t(context, 'timerDone'),
                                                      style: mono(
                                                        12,
                                                        color: light,
                                                      ),
                                                    ),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      cook.dismissAlert();
                                                      flash.stop();
                                                    },
                                                    child: Text(
                                                      t(context, 'dismiss'),
                                                      style: mono(
                                                        11,
                                                        color: light,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  28,
                                  10,
                                  28,
                                  10,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      t(context, 'servingsLabel'),
                                      style: mono(
                                        11,
                                        color: light.withValues(alpha: .7),
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      tooltip: t(context, 'lessServings'),
                                      onPressed: cook.servings <= 1
                                          ? null
                                          : () => cook.scaleServings(-1),
                                      icon: const Icon(
                                        Icons.remove,
                                        color: light,
                                        size: 19,
                                      ),
                                    ),
                                    Text(
                                      '${cook.servings}',
                                      style: mono(15, color: light),
                                    ),
                                    IconButton(
                                      tooltip: t(context, 'moreServings'),
                                      onPressed: cook.servings >= 20
                                          ? null
                                          : () => cook.scaleServings(1),
                                      icon: const Icon(
                                        Icons.add,
                                        color: light,
                                        size: 19,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  28,
                                  0,
                                  28,
                                  23,
                                ),
                                child: Row(
                                  children: [
                                    if (cook.step > 0) ...[
                                      IconButton(
                                        tooltip: t(context, 'previousStep'),
                                        onPressed: () => cook.move(-1),
                                        icon: const Icon(
                                          Icons.arrow_back,
                                          color: light,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: advance,
                                        child: Text(
                                          t(
                                            context,
                                            cook.step ==
                                                    widget.recipe.steps.length -
                                                        1
                                                ? 'finishCooking'
                                                : 'nextStep',
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
          );
        },
      ),
    );
  }
}
