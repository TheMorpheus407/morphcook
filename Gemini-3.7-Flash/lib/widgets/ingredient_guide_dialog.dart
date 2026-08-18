import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/ingredient_guide.dart';
import '../theme/vintage_theme.dart';
import '../widgets/vintage_widgets.dart';

class IngredientGuideDialog extends StatelessWidget {
  final IngredientGuideEntry entry;
  final String lang;

  const IngredientGuideDialog({
    super.key,
    required this.entry,
    required this.lang,
  });

  static void show(BuildContext context, IngredientGuideEntry entry, String lang) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IngredientGuideDialog(entry: entry, lang: lang),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: VintageColors.paperBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: VintageColors.paperBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'KITCHEN REFERENCE',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: VintageColors.terracotta,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close, size: 20, color: VintageColors.inkLight),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.name.get(lang),
            style: GoogleFonts.playfairDisplay(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              color: VintageColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            entry.description.get(lang),
            style: GoogleFonts.ebGaramond(
              fontSize: 16,
              color: VintageColors.ink,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          const VintageDivider(symbol: '§'),
          const SizedBox(height: 8),

          // Usage Tips
          _buildGuideSection(
            icon: Icons.lightbulb_outline,
            title: lang == 'de' ? 'Kulinarische Tipps' : 'Chef’s Technique',
            content: entry.usageTips.get(lang),
          ),
          const SizedBox(height: 14),

          // Storage
          _buildGuideSection(
            icon: Icons.inventory_2_outlined,
            title: lang == 'de' ? 'Lagerung & Haltbarkeit' : 'Storage & Shelf Life',
            content: entry.storage.get(lang),
          ),
          const SizedBox(height: 14),

          // Where to Find
          _buildGuideSection(
            icon: Icons.storefront_outlined,
            title: lang == 'de' ? 'Wo zu finden' : 'Where to Source',
            content: entry.whereToFind.get(lang),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildGuideSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: VintageColors.terracotta),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: VintageColors.inkLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: GoogleFonts.ebGaramond(
                  fontSize: 15,
                  color: VintageColors.ink,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
