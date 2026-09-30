import 'package:flutter/material.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../data/models/recipe.dart';
import '../../widgets/paper_controls.dart';

/// The numbered method with a timer tag on steps that have one.
class MethodView extends StatelessWidget {
  const MethodView({super.key, required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < recipe.steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 44,
                  child: Text('${i + 1}', style: AppText.display(size: 38, color: Palette.coral)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          recipe.steps[i].text.resolve(s.lang),
                          style: AppText.serif(size: 16.5, height: 1.55),
                        ),
                      ),
                      if (recipe.steps[i].timerSeconds != null) ...[
                        const SizedBox(height: 8),
                        MonoTag('⏱ ${_duration(recipe.steps[i].timerSeconds!, s)}', color: Palette.tealDeep),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (recipe.tip.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 4), child: HandNote(recipe.tip.resolve(s.lang), size: 23)),
      ],
    );
  }
}

/// `10 min`, `1 h 30 min`, `45 s`.
String _duration(int seconds, AppStrings s) {
  if (seconds < 60) return s('unit.sec', {'n': seconds});
  final minutes = (seconds / 60).round();
  if (minutes < 60) return s.minutes(minutes);
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? s('unit.hours', {'n': hours}) : '${s('unit.hours', {'n': hours})} ${s.minutes(rest)}';
}

/// Formats a duration for timers and tags.
String formatDuration(int seconds, AppStrings s) => _duration(seconds, s);
