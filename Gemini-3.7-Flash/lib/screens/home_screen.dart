import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/app_state.dart';
import '../models/dish.dart';
import '../models/recipe.dart';
import '../theme/vintage_theme.dart';
import '../widgets/vintage_widgets.dart';
import 'dish_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final lang = appState.lang;
    final dishes = appState.getRankedDishes();

    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(now).toUpperCase();

    if (dishes.isEmpty) {
      return Scaffold(
        backgroundColor: VintageColors.paperBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lang == 'de' ? 'Keine passenden Gerichte gefunden' : 'No Matching Dishes Found',
                  style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  lang == 'de'
                      ? 'Versuche deine Filter in den Profileinstellungen zu lockern.'
                      : 'Try broadening your filters in Profile Settings.',
                  style: GoogleFonts.ebGaramond(fontSize: 16, color: VintageColors.inkLight),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final featuredDish = dishes.first;
    final featuredVariant = appState.getBestVariantForDish(featuredDish);

    final quickDishes = dishes.where((d) {
      final v = appState.getBestVariantForDish(d);
      return v != null && (v.totalTimeMinutes <= 30 || v.attributes.contains('easy'));
    }).toList();

    return Scaffold(
      backgroundColor: VintageColors.paperBg,
      body: SafeArea(
        child: RefreshIndicator(
          color: VintageColors.terracotta,
          backgroundColor: VintageColors.paperCard,
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 200));
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Newspaper Masthead
              _buildMasthead(context, appState, dateStr, lang),
              const SizedBox(height: 16),

              // Editorial Note
              HandwrittenNote(
                text: lang == 'de'
                    ? '„Das selbe Gericht existiert für jeden Körper. Dein Döner, dein Alfredo, deine Küche.“'
                    : '“The same dish exists for every body. Your Döner, your Carbonara, your kitchen.”',
                author: appState.profile.name,
              ),
              const SizedBox(height: 20),

              // Section Header: Featured Today
              Text(
                lang == 'de' ? 'Gericht des Tages' : 'Featured Dish',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                  color: VintageColors.ink,
                ),
              ),
              const SizedBox(height: 10),

              // Featured Hero Polaroid Card
              _buildFeaturedCard(context, featuredDish, featuredVariant, lang),
              const SizedBox(height: 28),

              // Curated Section: Quick & Easy
              if (quickDishes.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lang == 'de' ? 'Schnell & Unkompliziert' : 'Quick & Effortless',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        color: VintageColors.ink,
                      ),
                    ),
                    Text(
                      '≤ 30 MIN',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: VintageColors.inkLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 250,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: quickDishes.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 14),
                    itemBuilder: (ctx, idx) {
                      final dish = quickDishes[idx];
                      final variant = appState.getBestVariantForDish(dish);
                      return _buildHorizontalDishCard(context, dish, variant, lang, idx % 2 == 0 ? -0.012 : 0.015);
                    },
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // Curated Section: All Seasonal Offerings (Grid)
              Text(
                lang == 'de' ? 'Ausgabe-Repertoire' : 'Curator’s Table',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                  color: VintageColors.ink,
                ),
              ),
              const SizedBox(height: 12),

              ...dishes.skip(1).map((dish) {
                final variant = appState.getBestVariantForDish(dish);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _buildDishListCard(context, dish, variant, lang),
                );
              }),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMasthead(BuildContext context, AppState appState, String dateStr, String lang) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'VOL. I • NO. 1',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                letterSpacing: 1.2,
                color: VintageColors.inkLight,
              ),
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: () => appState.setLanguage(lang == 'en' ? 'de' : 'en'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: VintageColors.paperCard,
                      border: Border.all(color: VintageColors.paperBorder),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      lang.toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: VintageColors.terracotta,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  dateStr,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    letterSpacing: 1.0,
                    color: VintageColors.inkLight,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(height: 1, color: VintageColors.ink),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'MorphCook',
            style: GoogleFonts.playfairDisplay(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              color: VintageColors.ink,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Center(
          child: Text(
            lang == 'de'
                ? 'DIE PERSÖNLICHE KÜCHENCHRONIK FÜR JEDEN KÖRPER'
                : 'THE PERSONAL KITCHEN CHRONICLE FOR EVERY BODY',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w600,
              color: VintageColors.inkLight,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(height: 1, color: VintageColors.ink),
      ],
    );
  }

  Widget _buildFeaturedCard(BuildContext context, Dish dish, Recipe? variant, String lang) {
    return PolaroidCard(
      rotationAngle: -0.008,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DishDetailScreen(dish: dish)),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StripedPlaceholder(
            hexColor: dish.stripeColor,
            height: 190,
            label: dish.name.get(lang),
            caption: dish.capCaption.get(lang),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  variant?.title.get(lang) ?? dish.name.get(lang),
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    color: VintageColors.ink,
                  ),
                ),
              ),
              if (variant != null)
                VintageBadge(
                  label: '${variant.totalTimeMinutes} min • ~${variant.caloriesPerServing} kcal',
                  color: VintageColors.paperSurface,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            variant?.description.get(lang) ?? dish.heroText.get(lang),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.ebGaramond(fontSize: 16, color: VintageColors.inkLight),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalDishCard(BuildContext context, Dish dish, Recipe? variant, String lang, double rotation) {
    return SizedBox(
      width: 220,
      child: PolaroidCard(
        rotationAngle: rotation,
        padding: const EdgeInsets.all(10),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DishDetailScreen(dish: dish)),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StripedPlaceholder(
              hexColor: dish.stripeColor,
              height: 120,
              label: dish.name.get(lang),
            ),
            const SizedBox(height: 8),
            Text(
              variant?.title.get(lang) ?? dish.name.get(lang),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.playfairDisplay(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (variant != null)
                  Text(
                    '${variant.totalTimeMinutes}m • ${variant.caloriesPerServing}kcal',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, color: VintageColors.inkLight),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDishListCard(BuildContext context, Dish dish, Recipe? variant, String lang) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DishDetailScreen(dish: dish)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: VintageColors.paperCard,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: VintageColors.paperBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              height: 90,
              child: StripedPlaceholder(
                hexColor: dish.stripeColor,
                height: 90,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          variant?.title.get(lang) ?? dish.name.get(lang),
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    variant?.description.get(lang) ?? dish.heroText.get(lang),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ebGaramond(fontSize: 14, color: VintageColors.inkLight),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (variant != null) ...[
                        VintageBadge(label: '${variant.totalTimeMinutes} min'),
                        const SizedBox(width: 6),
                        VintageBadge(label: '~${variant.caloriesPerServing} kcal'),
                        const SizedBox(width: 6),
                        if (variant.variantDimensionValues.containsKey('diet'))
                          VintageBadge(
                            label: variant.variantDimensionValues['diet']!.toUpperCase(),
                            color: VintageColors.paperBg,
                          ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
