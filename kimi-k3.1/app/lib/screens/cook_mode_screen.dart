import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/cook_mode_controller.dart';
import '../localization/app_localizations.dart';
import '../models/recipe.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/paper_widgets.dart';

class CookModeScreen extends StatefulWidget {
  const CookModeScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  State<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends State<CookModeScreen> {
  late CookModeController _controller;
  late bool _quickNextActive;
  late int _visibleStepIndex;
  final ScrollController _scrollController = ScrollController();

  bool _dependenciesReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dependenciesReady) {
      _dependenciesReady = true;
      _createController();
    }
  }

  void _createController() {
    final appState = context.read<AppState>();
    final profile = appState.profile;
    final reduceMotion =
        profile.reduceMotion ?? MediaQuery.of(context).disableAnimations;
    _quickNextActive = profile.quickNextTapEnabled && !reduceMotion;
    _controller = CookModeController(
      recipe: widget.recipe,
      initialProgress: appState.snapshot.cookProgress[widget.recipe.id],
      visualAlertEnabled: profile.visualAlertEnabled,
      reduceMotion: reduceMotion,
      onPersist: (progress, notify) =>
          appState.saveCookProgress(progress, notify: notify),
      onCompleted: appState.completeCook,
    );
    _controller.configureQuickNext(profile.quickNextTapEnabled);
    _controller.addListener(_handleControllerChanged);
    _visibleStepIndex = _controller.stepIndex;
  }

  @override
  void didUpdateWidget(covariant CookModeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.recipe, widget.recipe)) {
      _controller.removeListener(_handleControllerChanged);
      _controller.dispose();
      _createController();
    }
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    if (_visibleStepIndex != _controller.stepIndex) {
      _visibleStepIndex = _controller.stepIndex;
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    }
    setState(() {});
  }

  void _handleStepContentTap() {
    _controller.quickNext.handleTap();
  }

  void _goBack() {
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _cookTheme(Theme.of(context)),
      child: Builder(
        builder: (context) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: AppColors.dark,
            body: Stack(
              fit: StackFit.expand,
              children: [
                Paper(
                  color: AppColors.dark,
                  child: SafeArea(
                    child: _controller.completed
                        ? _CompletionView(
                            recipe: widget.recipe,
                            onBack: _goBack,
                          )
                        : _buildCookingView(context),
                  ),
                ),
                if (!_controller.completed && _controller.alertVisible)
                  _buildTimerAlert(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCookingView(BuildContext context) {
    final l10n = context.l10n;
    final stepLabel = l10n.t('step', {
      'current': '${_controller.stepIndex + 1}',
      'total': '${widget.recipe.steps.length}',
    });
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 20, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: _goBack,
                tooltip: l10n.t('back'),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stepLabel,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ),
        Semantics(
          label: stepLabel,
          child: LinearProgressIndicator(
            value: _controller.progress,
            minHeight: 3,
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth >= 600
                  ? 32.0
                  : 20.0;
              return SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  24,
                  horizontalPadding,
                  30,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.recipe.title[context.lang],
                          style: Theme.of(
                            context,
                          ).textTheme.displaySmall?.copyWith(fontSize: 32),
                        ),
                        DashedRule(
                          color: AppColors.darkPaper.withValues(alpha: 0.55),
                          height: 20,
                        ),
                        Wrap(
                          spacing: 20,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              l10n.t('method'),
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: AppColors.coral),
                            ),
                            ServingScaler(
                              value: _controller.servings,
                              onChanged: _controller.setServings,
                              dark: true,
                            ),
                          ],
                        ),
                        if (_quickNextActive)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.touch_app_outlined,
                                  size: 18,
                                  color: AppColors.coral,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l10n.t('quick_next_hint'),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 22),
                        _buildStepContent(context),
                        if (_controller.currentTimerSeconds > 0) ...[
                          const SizedBox(height: 18),
                          _buildTimer(context),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        _buildStepNavigation(context),
      ],
    );
  }

  Widget _buildStepContent(BuildContext context) {
    final step = widget.recipe.steps[_controller.stepIndex];
    return Material(
      color: AppColors.darkPaper.withValues(alpha: 0.045),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: AppColors.darkPaper.withValues(alpha: 0.24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _quickNextActive ? _handleStepContentTap : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: AppColors.coral, width: 3)),
          ),
          child: Text(
            step.text[context.lang],
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 24,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimer(BuildContext context) {
    final l10n = context.l10n;
    final timerAction = _controller.isRunning
        ? 'pause_timer'
        : _controller.remainingSeconds > 0 &&
              _controller.remainingSeconds < _controller.currentTimerSeconds
        ? 'resume_timer'
        : 'start_timer';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: AppColors.coral),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _formatTime(_controller.remainingSeconds),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontFamily: 'JetBrains Mono',
                    fontStyle: FontStyle.normal,
                    fontSize: 38,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _controller.toggleTimer,
                icon: Icon(
                  _controller.isRunning ? Icons.pause : Icons.play_arrow,
                  size: 19,
                ),
                label: Text(l10n.t(timerAction)),
              ),
              OutlinedButton.icon(
                onPressed: _controller.resetTimer,
                icon: const Icon(Icons.replay, size: 19),
                label: Text(l10n.t('reset_timer')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepNavigation(BuildContext context) {
    final l10n = context.l10n;
    final isLastStep = _controller.stepIndex == widget.recipe.steps.length - 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DashedRule(
          color: AppColors.darkPaper.withValues(alpha: 0.45),
          height: 1,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _controller.canGoBack
                      ? _controller.previous
                      : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_back, size: 18),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          l10n.t('previous_step'),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _controller.next,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          l10n.t(isLastStep ? 'finish_recipe' : 'next_step'),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Icon(
                        isLastStep ? Icons.check : Icons.arrow_forward,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimerAlert(BuildContext context) {
    final alertColor = _controller.reduceMotion
        ? AppColors.teal
        : _controller.alertPhase.isOdd
        ? AppColors.teal
        : AppColors.coral;
    return Semantics(
      liveRegion: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _controller.dismissAlert,
        child: ColoredBox(
          color: alertColor.withValues(
            alpha: _controller.reduceMotion ? 0.08 : 0.15,
          ),
          child: SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Material(
                    color: AppColors.darkPaper,
                    elevation: 10,
                    shadowColor: Colors.black54,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(color: alertColor, width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 6, 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.timer_off_outlined,
                            color: alertColor == AppColors.teal
                                ? AppColors.ink
                                : AppColors.coral,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              context.l10n.t('timer_done'),
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: AppColors.ink),
                            ),
                          ),
                          IconButton(
                            onPressed: _controller.dismissAlert,
                            tooltip: context.l10n.t('close'),
                            icon: const Icon(Icons.close, color: AppColors.ink),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  static ThemeData _cookTheme(ThemeData base) {
    final muted = AppColors.darkPaper.withValues(alpha: 0.68);
    final textTheme = base.textTheme
        .apply(
          bodyColor: AppColors.darkPaper,
          displayColor: AppColors.darkPaper,
        )
        .copyWith(
          bodySmall: base.textTheme.bodySmall?.copyWith(color: muted),
          labelMedium: base.textTheme.labelMedium?.copyWith(color: muted),
        );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(3),
    );
    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.dark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.darkPaper,
        onPrimary: AppColors.dark,
        secondary: AppColors.teal,
        onSecondary: AppColors.paperLight,
        tertiary: AppColors.coral,
        surface: AppColors.dark,
        onSurface: AppColors.darkPaper,
        onSurfaceVariant: muted,
        outline: AppColors.darkPaper.withValues(alpha: 0.4),
      ),
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: AppColors.darkPaper),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.coral,
        linearTrackColor: AppColors.darkPaper.withValues(alpha: 0.12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.darkPaper,
          foregroundColor: AppColors.dark,
          disabledBackgroundColor: AppColors.darkPaper.withValues(alpha: 0.2),
          disabledForegroundColor: AppColors.dark.withValues(alpha: 0.55),
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          textStyle: textTheme.labelLarge,
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkPaper,
          disabledForegroundColor: muted.withValues(alpha: 0.55),
          side: BorderSide(color: AppColors.darkPaper.withValues(alpha: 0.5)),
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          textStyle: textTheme.labelLarge,
          shape: buttonShape,
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(AppColors.darkPaper),
          minimumSize: WidgetStatePropertyAll(Size(48, 48)),
        ),
      ),
    );
  }
}

class _CompletionView extends StatelessWidget {
  const _CompletionView({required this.recipe, required this.onBack});

  final Recipe recipe;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(26),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight > 52
                ? constraints.maxHeight - 52
                : 0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.teal.withValues(alpha: 0.15),
                      border: Border.all(color: AppColors.teal, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 42,
                      color: AppColors.darkPaper,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    l10n.t('cook_complete_kicker'),
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: AppColors.coral),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.t('cook_complete_title', {
                      'recipe': recipe.title[context.lang],
                    }),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 18),
                  DashedRule(
                    color: AppColors.darkPaper.withValues(alpha: 0.5),
                    height: 1,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.t('cook_complete_body'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 30),
                  FilledButton.icon(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: Text(l10n.t('back_to_dish')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
