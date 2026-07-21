import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/brand.dart';
import '../core/copy.dart';
import 'paper.dart';

class MorphMasthead extends StatelessWidget {
  const MorphMasthead({
    super.key,
    required this.language,
    required this.onSettings,
  });

  final String language;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final locale = language == 'de' ? 'de_DE' : 'en_US';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 7),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat(
                    'EEEE · d MMMM yyyy',
                    locale,
                  ).format(DateTime.now()).toLowerCase(),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              Semantics(
                label: Copy.text('settings', language),
                button: true,
                child: IconButton(
                  onPressed: onSettings,
                  icon: const Icon(Icons.tune, size: 22),
                ),
              ),
            ],
          ),
        ),
        const DashedRule(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    'MorphCook',
                    style: Theme.of(
                      context,
                    ).textTheme.displayLarge?.copyWith(fontSize: 55),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 118,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomRight,
                  child: Transform.rotate(
                    angle: -.06,
                    child: Text(
                      Copy.text('today', language),
                      style: const TextStyle(
                        fontFamily: 'Caveat',
                        fontSize: 24,
                        color: BrandColors.coral,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(thickness: 2),
        const SizedBox(height: 2),
        const Divider(),
      ],
    );
  }
}

class EditorialSectionTitle extends StatelessWidget {
  const EditorialSectionTitle({super.key, required this.title, this.note});

  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 22, 16, 11),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
        ),
        if (note != null)
          Text(
            note!,
            style: const TextStyle(
              fontFamily: 'Caveat',
              fontSize: 19,
              color: BrandColors.coral,
            ),
          ),
      ],
    ),
  );
}
