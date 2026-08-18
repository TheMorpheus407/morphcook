import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/vintage_theme.dart';

class FaqScreen extends StatefulWidget {
  final String? initialCategory;

  const FaqScreen({super.key, this.initialCategory});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final lang = appState.lang;
    final allFaqs = appState.corpus.faqs;
    final query = _searchController.text.trim().toLowerCase();

    final filteredFaqs = allFaqs.where((f) {
      if (_selectedCategory != null && f.category != _selectedCategory) {
        return false;
      }
      if (query.isNotEmpty) {
        final q = f.question.get(lang).toLowerCase();
        final a = f.answer.get(lang).toLowerCase();
        return q.contains(query) || a.contains(query);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: VintageColors.paperBg,
      appBar: AppBar(
        title: Text(lang == 'de' ? 'Hilfe & Handbuch' : 'FAQ & Knowledge Base'),
      ),
      body: Column(
        children: [
          // Search Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: lang == 'de' ? 'Thema oder Frage suchen...' : 'Search questions or topics...',
                hintStyle: GoogleFonts.ebGaramond(fontSize: 16, color: VintageColors.inkMuted),
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: VintageColors.paperCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: VintageColors.paperBorder),
                ),
              ),
            ),
          ),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildCategoryChip(null, lang == 'de' ? 'Alle' : 'All'),
                const SizedBox(width: 6),
                _buildCategoryChip('matching', lang == 'de' ? 'Ernährung & Matching' : 'Dietary Matching'),
                const SizedBox(width: 6),
                _buildCategoryChip('visibility', lang == 'de' ? 'Sichtbarkeit' : 'Recipe Visibility'),
                const SizedBox(width: 6),
                _buildCategoryChip('features', lang == 'de' ? 'Funktionen' : 'Features'),
                const SizedBox(width: 6),
                _buildCategoryChip('troubleshooting', lang == 'de' ? 'Datensicherung' : 'Backup & Security'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // FAQ List
          Expanded(
            child: filteredFaqs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        lang == 'de' ? 'Keine passenden Fragen gefunden.' : 'No matching FAQ articles found.',
                        style: GoogleFonts.ebGaramond(fontSize: 16, color: VintageColors.inkLight),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredFaqs.length,
                    itemBuilder: (ctx, idx) {
                      final faq = filteredFaqs[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: VintageColors.paperCard,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: VintageColors.paperBorder),
                        ),
                        child: ExpansionTile(
                          shape: const Border(),
                          collapsedShape: const Border(),
                          title: Text(
                            faq.question.get(lang),
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(color: VintageColors.paperBorder),
                                  const SizedBox(height: 4),
                                  Text(
                                    faq.answer.get(lang),
                                    style: GoogleFonts.ebGaramond(
                                      fontSize: 16,
                                      color: VintageColors.ink,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String? category, String label) {
    final isSelected = _selectedCategory == category;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        color: isSelected ? Colors.white : VintageColors.ink,
      ),
      selectedColor: VintageColors.terracotta,
      backgroundColor: VintageColors.paperCard,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(color: isSelected ? VintageColors.terracotta : VintageColors.paperBorder),
      ),
      onSelected: (_) => setState(() => _selectedCategory = category),
    );
  }
}
