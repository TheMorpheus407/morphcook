import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/history_store.dart';
import '../data/profile_store.dart';
import '../l10n/strings.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../widgets/dashed_rule.dart';
import '../widgets/ink_button.dart';

/// Controller exposed publicly per SPEC §Cook mode quick-tap gesture.
class OneHandedCookModeController extends ChangeNotifier {
  bool quickNextTapEnabled;
  static const int debounceMs = 300;
  DateTime? _lastTap;

  OneHandedCookModeController({this.quickNextTapEnabled = false});

  /// Returns true if the tap should advance.
  bool registerTap() {
    if (!quickNextTapEnabled) return false;
    final now = DateTime.now();
    if (_lastTap != null &&
        now.difference(_lastTap!).inMilliseconds < debounceMs) {
      return false;
    }
    _lastTap = now;
    return true;
  }
}

class CookModeScreen extends StatefulWidget {
  final Recipe recipe;
  final int servings;
  const CookModeScreen({super.key, required this.recipe, required this.servings});

  @override
  State<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends State<CookModeScreen>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  Timer? _timer;
  int _remaining = 0;
  bool _running = false;
  late final AnimationController _flashCtrl;
  late OneHandedCookModeController _tapCtrl;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileStore>().profile;
    _tapCtrl = OneHandedCookModeController(
      quickNextTapEnabled: profile.quickNextTapEnabled,
    );
    _flashCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _resetTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flashCtrl.dispose();
    super.dispose();
  }

  void _resetTimer() {
    _timer?.cancel();
    _running = false;
    _remaining = widget.recipe.steps[_index].timerSeconds;
  }

  void _toggleTimer() {
    if (_remaining == 0) return;
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() {
          _remaining -= 1;
          if (_remaining <= 0) {
            t.cancel();
            _running = false;
            _onTimerComplete();
          }
        });
      });
      setState(() => _running = true);
    }
  }

  void _onTimerComplete() {
    HapticFeedback.heavyImpact();
    final profile = context.read<ProfileStore>().profile;
    final reduce = profile.reduceMotion ?? MediaQuery.disableAnimationsOf(context);
    if (profile.visualAlertEnabled && !reduce) {
      _flashCtrl.forward(from: 0).whenComplete(() {
        _flashCtrl.reverse();
      });
    }
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_index >= widget.recipe.steps.length - 1) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _resetTimer();
    });
  }

  void _prev() {
    if (_index <= 0) return;
    setState(() {
      _index--;
      _resetTimer();
    });
  }

  Future<void> _finish() async {
    await context
        .read<HistoryStore>()
        .record(widget.recipe.id, servings: widget.servings);
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => _DonePanel(recipe: widget.recipe),
    );
  }

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final lang = l.lang;
    final step = widget.recipe.steps[_index];
    return Scaffold(
      backgroundColor: MorphColors.ink,
      body: Stack(
        children: [
          SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (_tapCtrl.registerTap()) _next();
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                            '${l.t('cook.step').toUpperCase()} ${_index + 1} ${l.t('cook.of').toUpperCase()} ${widget.recipe.steps.length}',
                            style: MorphType.smallCaps(
                                size: 11, color: MorphColors.paper)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: MorphColors.paper),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: l.t('cook.exit'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(widget.recipe.name.get(lang).toLowerCase(),
                        style: MorphType.headline(size: 22)
                            .copyWith(color: MorphColors.paper)),
                    const SizedBox(height: 10),
                    DashedRule(color: MorphColors.paperShadow),
                    const Spacer(),
                    Text(
                      step.text.get(lang),
                      style: MorphType.body(
                          size: 26, color: MorphColors.paper).copyWith(
                          height: 1.35),
                    ),
                    const SizedBox(height: 24),
                    if (step.timerSeconds > 0) ...[
                      Center(
                        child: Text(_fmt(_remaining),
                            style: MorphType.display(
                                size: 72, style: FontStyle.normal).copyWith(
                                color: MorphColors.paper)),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: InkButton(
                          label: _running ? l.t('cook.pause')
                              : (_remaining < step.timerSeconds && _remaining > 0
                                  ? l.t('cook.resume')
                                  : l.t('cook.start')),
                          icon: _running ? Icons.pause : Icons.play_arrow,
                          primary: false,
                          onPressed: _toggleTimer,
                        ),
                      ),
                    ] else
                      Center(
                          child: Text(l.t('cook.no_timer'),
                              style: MorphType.smallCaps(
                                  size: 10,
                                  color: MorphColors.paperShadow))),
                    const Spacer(),
                    if (context
                        .watch<ProfileStore>()
                        .profile
                        .quickNextTapEnabled)
                      Center(
                          child: Text(l.t('cook.tap_to_advance'),
                              style: MorphType.smallCaps(
                                  size: 10,
                                  color:
                                      MorphColors.paperShadow))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkButton(
                            label: l.t('cook.prev'),
                            icon: Icons.chevron_left,
                            primary: false,
                            onPressed: _index > 0 ? _prev : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkButton(
                            label: _index == widget.recipe.steps.length - 1
                                ? l.t('cook.done')
                                : l.t('cook.next'),
                            icon: Icons.chevron_right,
                            onPressed: _next,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Visual alert flash for timer completion
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _flashCtrl,
              builder: (ctx, child) => Container(
                color: Color.lerp(Colors.transparent,
                        MorphColors.coral, _flashCtrl.value * 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonePanel extends StatelessWidget {
  final Recipe recipe;
  const _DonePanel({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return AlertDialog(
      backgroundColor: MorphColors.paper,
      title: Text(l.t('cook.done').toUpperCase(),
          style: MorphType.smallCaps(size: 11)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(recipe.name.get(l.lang).toLowerCase(),
              style: MorphType.display(size: 28)),
          const SizedBox(height: 8),
          Text('— well plated —',
              style: MorphType.hand(
                  size: 22, color: MorphColors.coral)),
        ],
      ),
      actions: [
        InkButton(
          label: l.t('app.done'),
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
