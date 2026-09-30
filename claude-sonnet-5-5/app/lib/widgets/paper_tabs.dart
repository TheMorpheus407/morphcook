import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../core/theme/palette.dart';
import '../core/theme/typography.dart';

/// Tabs as mono capitals with a coral underline: `[ingredients] [method] [macros]`.
class PaperTabs extends StatelessWidget {
  const PaperTabs({super.key, required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Palette.rule)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                label: labels[i],
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => onChanged(i),
                  child: SizedBox(
                    height: 50,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Like the navigation bar: the labels follow the text size up
                        // to a point and then shrink to their slot instead of breaking.
                        MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1.3,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                labels[i].toUpperCase(),
                                style: AppText.label(
                                  size: 11.5,
                                  color: i == index ? Palette.ink : Palette.inkFaint,
                                  weight: i == index ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 0,
                          child: AnimatedContainer(
                            duration: context.motion(const Duration(milliseconds: 180)),
                            height: 3,
                            color: i == index ? Palette.coral : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
