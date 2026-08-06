import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../data/corpus_repository.dart';
import '../data/models.dart';
import '../state/app_model.dart';

/// Polaroid-ish recipe card: striped placeholder, slight rotation,
/// mono meta line.
class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final double rotation;
  final bool saved;

  const RecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
    this.rotation = 0,
    this.saved = false,
  });

  @override
  Widget build(BuildContext context) {
    final corpus = context.read<CorpusRepository>();
    final lang = context.watch<AppModel>().lang;
    final dish = corpus.dish(recipe.dishId);
    final color = dish?.stripeColor ?? '#C2703F';
    final caption = tx(dish?.capCaption, lang);

    return GestureDetector(
      onTap: onTap,
      child: Transform.rotate(
        angle: rotation,
        child: Container(
          margin: const EdgeInsets.all(6),
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Paper.white,
            boxShadow: [
              BoxShadow(
                color: Paper.ink.withValues(alpha: 0.10),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRect(
                child: SizedBox(
                  height: 96,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: MiniStripes(StripedPlaceholder.parseHex(color)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tx(recipe.title, lang),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Type.display(size: 16),
              ),
              const SizedBox(height: 4),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Type.hand(size: 14),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${recipe.timeMinutes} min · ${recipe.caloriesPerServing} kcal',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Type.mono(size: 9.5, color: Paper.inkSoft),
                    ),
                  ),
                  if (saved)
                    Text('●',
                        style: Type.mono(size: 10, color: Paper.coral)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MiniStripes extends CustomPainter {
  final Color color;
  MiniStripes(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = Paper.deep);
    final stripe = Paint()..color = color.withValues(alpha: 0.75);
    const width = 10.0;
    const gap = 8.0;
    final slant = size.height * 0.4;
    var x = -slant - width;
    while (x < size.width + slant) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + slant, 0)
        ..lineTo(x + slant + width, 0)
        ..lineTo(x + width, size.height)
        ..close();
      canvas.drawPath(path, stripe);
      x += width + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Small mono metadata row: effort · time · calories.
class MetaLine extends StatelessWidget {
  final Recipe recipe;
  const MetaLine({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppModel>().lang;
    final ontology = context.read<CorpusRepository>().ontology;
    final effortLabel = tx(ontology.effortLabels[recipe.effort], lang);
    return Text(
      '$effortLabel · ${recipe.timeMinutes} min · ${recipe.caloriesPerServing} kcal',
      style: Type.mono(size: 10.5, color: Paper.inkSoft),
    );
  }
}

/// Quiet empty state with a handwritten note.
class EmptyNote extends StatelessWidget {
  final String title;
  final String? note;
  const EmptyNote({super.key, required this.title, this.note});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Text(title, style: Type.display(size: 20)),
          if (note != null) ...[
            const SizedBox(height: 10),
            Text(note!,
                textAlign: TextAlign.center,
                style: Type.mono(size: 11, color: Paper.inkSoft)),
          ],
        ],
      ),
    );
  }
}

/// Skeleton loader shown during pagination fetches.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Paper.white.withValues(alpha: 0.6),
        border: Border.all(color: Paper.rule.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 96, color: Paper.deep),
          const SizedBox(height: 10),
          Container(height: 12, width: 120, color: Paper.deep),
          const SizedBox(height: 8),
          Container(height: 10, width: 80, color: Paper.deep),
        ],
      ),
    );
  }
}

/// Paper-styled primary button.
class PaperButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  const PaperButton(
      {super.key, required this.label, this.onTap, this.primary = true});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        decoration: BoxDecoration(
          color: !enabled
              ? Paper.deep
              : primary
                  ? Paper.ink
                  : Paper.white,
          border: Border.all(
            color: !enabled ? Paper.rule : Paper.ink,
          ),
        ),
        child: Text(
          label,
          style: Type.mono(
            size: 12,
            color: !enabled
                ? Paper.inkFaint
                : primary
                    ? Paper.white
                    : Paper.ink,
          ),
        ),
      ),
    );
  }
}

/// Paper-styled text field.
class PaperField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final TextInputType keyboardType;

  const PaperField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Paper.white,
        border: Border.all(color: Paper.rule),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        keyboardType: keyboardType,
        style: Type.mono(size: 13),
        cursorColor: Paper.coral,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: Type.mono(size: 12, color: Paper.inkFaint),
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}
