import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/dish.dart';
import '../../core/models/localized_text.dart';
import '../../core/models/recipe.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/chips.dart';
import '../../core/theme/polaroid_card.dart';
import '../../l10n/tr.dart';
import '../../state/app_state.dart';
import '../routes.dart';

/// The standard polaroid card for a dish with its currently-best visible
/// variant. Tapping opens the dish page.
class DishCard extends StatelessWidget {
  const DishCard({super.key, required this.dish, this.recipe, this.onTap});

  final Dish dish;
  final Recipe? recipe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final shown = recipe ?? state.bestVariantFor(dish);
    final lang = state.lang;
    final subtitle = _subtitle(context, state, dish, shown);
    return PolaroidCard(
      id: dish.id,
      stripeColor: dish.stripeColor,
      caption: lt(dish.cap, lang),
      title: lt(dish.name, lang),
      subtitle: subtitle,
      onTap: onTap ?? () => openDish(context, dish.id),
      trailing: shown == null
          ? null
          : Icon(Icons.menu_book_outlined,
              size: 14, color: state.isSaved(shown.id) ? AppColors.coral : Colors.transparent),
    );
  }

  String _subtitle(BuildContext context, AppState state, Dish dish, Recipe? shown) {
    if (shown == null) {
      return context.tr('dish.noVariant').split('—').first.trim();
    }
    final base = '${shown.timeMinutes} ${context.trRead('common.min')} · ~${shown.cal} ${context.trRead('common.kcal')}';
    if (!state.profile.showVariantTags) return base;
    final diet = state.corpus.ontology.attrLabel(shown.diet, state.lang);
    return '$diet · $base';
  }
}

/// Compact one-line row version used in pickers and the history ledger.
class DishRow extends StatelessWidget {
  const DishRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.stripeColor,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final Color stripeColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(width: 4, height: 34, color: stripeColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.display(size: 17)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.mono(size: 10, color: const Color(0xFF6B6455))),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
