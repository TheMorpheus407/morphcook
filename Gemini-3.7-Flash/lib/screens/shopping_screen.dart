import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/shopping_item.dart';
import '../theme/vintage_theme.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController(text: '1');
  final TextEditingController _unitController = TextEditingController(text: 'pieces');
  String _selectedAisle = 'Produce';

  final List<String> _aisles = [
    'Produce',
    'Dairy & Eggs',
    'Pantry & Spices',
    'Meat & Seafood',
    'Bakery',
    'Oils & Condiments',
    'Plant Proteins',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _showAddItemDialog(BuildContext context, String lang) {
    _nameController.clear();
    _amountController.text = '1';
    _unitController.text = 'pieces';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VintageColors.paperCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: VintageColors.paperBorder),
        ),
        title: Text(
          lang == 'de' ? 'Zutat hinzufügen' : 'Add Custom Ingredient',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: lang == 'de' ? 'Zutat (z. B. Frische Minze)' : 'Ingredient Name (e.g. Fresh Mint)',
                  labelStyle: GoogleFonts.ebGaramond(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: lang == 'de' ? 'Menge' : 'Amount',
                        labelStyle: GoogleFonts.ebGaramond(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _unitController,
                      decoration: InputDecoration(
                        labelText: lang == 'de' ? 'Einheit' : 'Unit',
                        labelStyle: GoogleFonts.ebGaramond(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedAisle,
                decoration: InputDecoration(
                  labelText: lang == 'de' ? 'Abteilung' : 'Aisle',
                  labelStyle: GoogleFonts.ebGaramond(),
                ),
                items: _aisles.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedAisle = val);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang == 'de' ? 'Abbrechen' : 'Cancel', style: GoogleFonts.jetBrainsMono(color: VintageColors.inkLight)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: VintageColors.terracotta),
            onPressed: () {
              final name = _nameController.text.trim();
              if (name.isNotEmpty) {
                final amt = double.tryParse(_amountController.text.trim()) ?? 1.0;
                final unit = _unitController.text.trim();
                Provider.of<AppState>(context, listen: false).addCustomShoppingItem(
                  name,
                  name,
                  amt,
                  unit,
                  _selectedAisle,
                );
                Navigator.pop(ctx);
              }
            },
            child: Text(lang == 'de' ? 'Hinzufügen' : 'Add', style: GoogleFonts.jetBrainsMono()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final lang = appState.lang;
    final items = appState.shoppingList;

    // Group items by aisle
    final Map<String, List<ShoppingItem>> groupedByAisle = {};
    for (final item in items) {
      groupedByAisle.putIfAbsent(item.aisle, () => []).add(item);
    }

    final checkedCount = items.where((i) => i.isChecked).length;

    return Scaffold(
      backgroundColor: VintageColors.paperBg,
      appBar: AppBar(
        title: Text(lang == 'de' ? 'Einkaufsliste' : 'Market List'),
        actions: [
          if (checkedCount > 0)
            IconButton(
              icon: const Icon(Icons.playlist_remove),
              tooltip: lang == 'de' ? 'Erledigte löschen' : 'Clear Checked',
              onPressed: () => appState.clearCheckedShoppingItems(),
            ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: lang == 'de' ? 'Zutat hinzufügen' : 'Add Item',
            onPressed: () => _showAddItemDialog(context, lang),
          ),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: VintageColors.paperCard,
                        shape: BoxShape.circle,
                        border: Border.all(color: VintageColors.paperBorder),
                      ),
                      child: const Icon(Icons.shopping_bag_outlined, color: VintageColors.inkMuted, size: 30),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      lang == 'de' ? 'Deine Speisekammer ist leer' : 'Your Market Basket is Empty',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lang == 'de'
                          ? 'Füge Zutaten aus Rezepten oder dem Wochenplan hinzu, um sie automatisch zusammenzufassen.'
                          : 'Add ingredients from recipes or your weekly meal plan. Compatible units will aggregate automatically.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ebGaramond(fontSize: 16, color: VintageColors.inkLight),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: VintageColors.terracotta),
                      ),
                      icon: const Icon(Icons.add, color: VintageColors.terracotta),
                      label: Text(
                        lang == 'de' ? 'Eigene Zutat eintragen' : 'Add Custom Item',
                        style: GoogleFonts.jetBrainsMono(color: VintageColors.terracotta),
                      ),
                      onPressed: () => _showAddItemDialog(context, lang),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Summary Bar
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: VintageColors.paperCard,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: VintageColors.paperBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${items.length} ${lang == 'de' ? 'Zutaten' : 'items'} • $checkedCount ${lang == 'de' ? 'erledigt' : 'checked'}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          color: VintageColors.inkLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (items.isNotEmpty)
                        GestureDetector(
                          onTap: () => appState.clearAllShoppingItems(),
                          child: Text(
                            lang == 'de' ? 'Alles leeren' : 'Clear All',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              color: VintageColors.terracotta,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Grouped Aisle Sections
                for (final entry in groupedByAisle.entries) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Text(
                          entry.key.toUpperCase(),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: VintageColors.inkLight,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: VintageColors.paperBorder,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...entry.value.map((item) => _buildShoppingRow(context, appState, item, lang)),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }

  Widget _buildShoppingRow(BuildContext context, AppState appState, ShoppingItem item, String lang) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: const Color(0xFFBA1A1A).withValues(alpha: 0.1),
        child: const Icon(Icons.delete_outline, color: Color(0xFFBA1A1A)),
      ),
      onDismissed: (_) => appState.removeShoppingItem(item.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: item.isChecked ? VintageColors.paperSurface.withValues(alpha: 0.5) : VintageColors.paperCard,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: item.isChecked ? VintageColors.paperBorder.withValues(alpha: 0.6) : VintageColors.paperBorder,
          ),
        ),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          leading: Checkbox(
            activeColor: VintageColors.sage,
            value: item.isChecked,
            onChanged: (_) => appState.toggleShoppingItemChecked(item.id),
          ),
          title: Text(
            item.name.get(lang),
            style: GoogleFonts.ebGaramond(
              fontSize: 17,
              decoration: item.isChecked ? TextDecoration.lineThrough : null,
              color: item.isChecked ? VintageColors.inkMuted : VintageColors.ink,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: VintageColors.paperBg,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: VintageColors.paperBorder),
            ),
            child: Text(
              '${item.amount.toStringAsFixed(item.amount % 1 == 0 ? 0 : 1)} ${item.unit}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: item.isChecked ? VintageColors.inkMuted : VintageColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
