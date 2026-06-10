import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/brand_theme.dart';
import 'dish_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final isEn = provider.currentLanguage == 'en';

    // 1. Get visible dishes (dishes with at least one matching recipe variant)
    final visibleDishes = <Dish>[];
    final optimalRecipes = <String, Recipe>{}; // dishId -> optimal Recipe

    for (var dish in provider.dishes) {
      final optimal = provider.getOptimalVariantForDish(dish);
      if (optimal != null) {
        visibleDishes.add(dish);
        optimalRecipes[dish.id] = optimal;
      }
    }

    if (!provider.isLoaded) {
      return const Center(
        child: CircularProgressIndicator(color: BrandColors.coral),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Newspaper-Style Masthead Section
          Center(
            child: Column(
              children: [
                Text(
                  "the morphcook ledger",
                  style: BrandFonts.handwritten(fontSize: 20.0, color: BrandColors.coral),
                ),
                Text(
                  "MORPHCOOK",
                  style: BrandFonts.displaySerif(fontSize: 44.0, fontWeight: FontWeight.bold, italic: false),
                ),
                Text(
                  isEn ? "EVERY DISH FOR EVERY BODY • VOL. I NO. I" : "JEDES GERICHT FÜR JEDEN KÖRPER • BAND I NR. I",
                  style: BrandFonts.mono(fontSize: 9.0, color: BrandColors.softGrey),
                ),
                const SizedBox(height: 12.0),
                const DashedDivider(height: 1.5),
                const SizedBox(height: 16.0),
              ],
            ),
          ),

          if (visibleDishes.isEmpty) ...[
            const SizedBox(height: 40.0),
            Center(
              child: Column(
                children: [
                  Text(
                    isEn ? "nothing matches" : "keine treffer",
                    style: BrandFonts.displaySerif(fontSize: 24.0, italic: true),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    isEn
                        ? "your dietary profile is very restrictive.\ntry loosening it in settings!"
                        : "dein profil ist sehr einschränkend.\nversuche es in den einstellungen anzupassen!",
                    textAlign: TextAlign.center,
                    style: BrandFonts.mono(fontSize: 12.0, color: BrandColors.softGrey),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Featured Polaroid Card (The Load-Bearing Money Shot)
            _buildFeaturedSection(context, visibleDishes.first, optimalRecipes[visibleDishes.first.id]!, isEn),

            const SizedBox(height: 24.0),
            const DashedDivider(),
            const SizedBox(height: 24.0),

            // Section: Grid / List of Other Dishes
            Text(
              isEn ? "today's kitchen favorites" : "heutige küchenlieblinge",
              style: BrandFonts.displaySerif(fontSize: 22.0, italic: true),
            ),
            const SizedBox(height: 16.0),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleDishes.length - 1 < 0 ? 0 : visibleDishes.length - 1,
              separatorBuilder: (context, index) => const SizedBox(height: 16.0),
              itemBuilder: (context, index) {
                final dish = visibleDishes[index + 1];
                final optimalRecipe = optimalRecipes[dish.id]!;
                return _buildDishListItem(context, dish, optimalRecipe, provider);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeaturedSection(BuildContext context, Dish dish, Recipe recipe, bool isEn) {
    final stripeColor = Color(int.parse(dish.stripeColor));
    final title = recipe.name[isEn ? 'en' : 'de'] ?? dish.canonicalName[isEn ? 'en' : 'de'] ?? '';
    final caption = dish.capCaption[isEn ? 'en' : 'de'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isEn ? "DAILY SPECIAL //" : "TAGESGERICHT //",
              style: BrandFonts.mono(fontSize: 11.0, color: BrandColors.coral, fontWeight: FontWeight.bold),
            ),
            Text(
              "${recipe.timeMinutes} mins",
              style: BrandFonts.mono(fontSize: 11.0, color: BrandColors.softGrey),
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        Center(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DishDetailScreen(dish: dish)),
              );
            },
            child: PolaroidCard(
              rotation: 1.2,
              child: Container(
                width: 280.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StripedPlaceholder(
                      color: stripeColor,
                      caption: caption,
                      height: 180.0,
                    ),
                    const SizedBox(height: 16.0),
                    Text(
                      title.toLowerCase(),
                      style: BrandFonts.displaySerif(fontSize: 22.0, italic: true, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      recipe.description[isEn ? 'en' : 'de'] ?? '',
                      style: BrandFonts.body(fontSize: 13.0, color: BrandColors.softGrey),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${recipe.caloriesPerServing} kcal",
                          style: BrandFonts.mono(fontSize: 11.0, color: BrandColors.coral),
                        ),
                        Text(
                          recipe.attributes.contains('easy')
                              ? 'easy'
                              : recipe.attributes.contains('medium')
                                  ? 'medium'
                                  : 'hard',
                          style: BrandFonts.mono(fontSize: 11.0),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDishListItem(BuildContext context, Dish dish, Recipe recipe, AppProvider provider) {
    final isEn = provider.currentLanguage == 'en';
    final stripeColor = Color(int.parse(dish.stripeColor));
    final title = recipe.name[isEn ? 'en' : 'de'] ?? dish.canonicalName[isEn ? 'en' : 'de'] ?? '';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DishDetailScreen(dish: dish)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: BrandColors.charcoalInk, width: 0.5),
        ),
        child: Row(
          children: [
            // Striped card thumbnail
            Container(
              width: 80.0,
              height: 80.0,
              decoration: BoxDecoration(
                border: Border.all(color: BrandColors.charcoalInk, width: 0.5),
              ),
              child: CustomPaint(
                painter: _ThumbnailStripesPainter(color: stripeColor),
              ),
            ),
            const SizedBox(width: 16.0),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toLowerCase(),
                    style: BrandFonts.displaySerif(fontSize: 17.0, italic: true, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    recipe.description[isEn ? 'en' : 'de'] ?? '',
                    style: BrandFonts.body(fontSize: 12.0, color: BrandColors.softGrey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${recipe.caloriesPerServing} kcal • ${recipe.timeMinutes} mins",
                        style: BrandFonts.mono(fontSize: 10.0, color: BrandColors.softGrey),
                      ),
                      if (provider.profile.showVariantTags)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                          color: BrandColors.paleCream,
                          child: Text(
                            recipe.id.split('-').last,
                            style: BrandFonts.mono(fontSize: 8.0, color: BrandColors.coral, fontWeight: FontWeight.bold),
                          ),
                        ),
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

class _ThumbnailStripesPainter extends CustomPainter {
  final Color color;
  _ThumbnailStripesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = color.withOpacity(0.04);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final stripePaint = Paint()
      ..color = color.withOpacity(0.15)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const spacing = 10.0;
    for (double i = -size.height; i < size.width; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        stripePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
