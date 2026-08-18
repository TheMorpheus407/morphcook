import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/recipe.dart';
import '../models/dish.dart';
import '../controllers/pagination_controller.dart';
import '../theme/vintage_theme.dart';
import '../widgets/vintage_widgets.dart';
import 'dish_detail_screen.dart';

class CookbookScreen extends StatefulWidget {
  const CookbookScreen({super.key});

  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late PaginationController<Recipe> _paginationController;

  @override
  void initState() {
    super.initState();
    _paginationController = PaginationController<Recipe>(
      type: PaginationType.offset,
      pageSize: 30,
      prefetchThreshold: 10,
      maxRendered: 50,
      fetchPage: _fetchSavedRecipes,
    );

    _scrollController.addListener(_onScroll);
    _paginationController.loadInitial();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _paginationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_paginationController.hasMore && !_paginationController.isLoading) {
        _paginationController.loadMore();
      }
    }
  }

  Future<PaginationResult<Recipe>> _fetchSavedRecipes(PaginationRequest request) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final lang = appState.lang;
    final query = _searchController.text.trim().toLowerCase();

    final savedIds = appState.savedRecipeIds.toList();
    final List<Recipe> savedRecipes = [];

    for (final id in savedIds) {
      final r = appState.corpus.getRecipe(id);
      if (r != null) {
        if (query.isNotEmpty) {
          final title = r.title.get(lang).toLowerCase();
          final desc = r.description.get(lang).toLowerCase();
          if (!title.contains(query) && !desc.contains(query)) continue;
        }
        savedRecipes.add(r);
      }
    }

    final startIndex = request.offset;
    final endIndex = (startIndex + request.limit).clamp(0, savedRecipes.length);

    if (startIndex >= savedRecipes.length) {
      return const PaginationResult(items: [], hasMore: false);
    }

    final pageItems = savedRecipes.sublist(startIndex, endIndex);
    return PaginationResult(
      items: pageItems,
      hasMore: endIndex < savedRecipes.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final lang = appState.lang;

    return Scaffold(
      backgroundColor: VintageColors.paperBg,
      appBar: AppBar(
        title: Text(lang == 'de' ? 'Mein Kochbuch' : 'My Kitchen Notebook'),
      ),
      body: Column(
        children: [
          // Filter / search within saved
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _paginationController.loadInitial(),
              decoration: InputDecoration(
                hintText: lang == 'de' ? 'Gespeicherte Rezepte durchsuchen...' : 'Search your saved recipes...',
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

          // Saved Count Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${appState.savedRecipeIds.length} ${lang == 'de' ? 'Gespeicherte Varianten' : 'Saved Recipe Variants'}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: VintageColors.inkLight,
                  ),
                ),
                Text(
                  lang == 'de' ? 'Speziell für dich' : 'Authored For You',
                  style: GoogleFonts.caveat(fontSize: 16, color: VintageColors.terracotta),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Saved List
          Expanded(
            child: appState.savedRecipeIds.isEmpty
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
                            child: const Icon(Icons.bookmark_border, color: VintageColors.inkMuted, size: 30),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            lang == 'de' ? 'Noch keine Rezepte gespeichert' : 'No Saved Variants Yet',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            lang == 'de'
                                ? 'Tippe auf das Lesezeichen-Symbol bei einem Gericht, um genau deine Variante zu sichern.'
                                : 'Tap the bookmark icon in any dish detail to save your personalized variant.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.ebGaramond(fontSize: 16, color: VintageColors.inkLight),
                          ),
                        ],
                      ),
                    ),
                  )
                : AnimatedBuilder(
                    animation: _paginationController,
                    builder: (context, _) {
                      final items = _paginationController.items;

                      if (_paginationController.isLoading && items.isEmpty) {
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: 4,
                          itemBuilder: (context, index) => Container(
                            height: 90,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: VintageColors.paperCard,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: VintageColors.paperBorder),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: items.length + (_paginationController.hasMore ? 1 : 0),
                        itemBuilder: (ctx, index) {
                          if (index >= items.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(color: VintageColors.terracotta),
                              ),
                            );
                          }

                          final recipe = items[index];
                          final dish = appState.corpus.getDish(recipe.dishId);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildSavedRecipeCard(context, appState, recipe, dish, lang),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedRecipeCard(
    BuildContext context,
    AppState appState,
    Recipe recipe,
    Dish? dish,
    String lang,
  ) {
    final stripeHex = dish?.stripeColor ?? '#C25E40';

    return Dismissible(
      key: Key('saved_${recipe.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: const Color(0xFFBA1A1A).withValues(alpha: 0.1),
        child: const Icon(Icons.bookmark_remove, color: Color(0xFFBA1A1A)),
      ),
      onDismissed: (_) {
        appState.toggleSaveRecipe(recipe.id);
        _paginationController.loadInitial();
      },
      child: GestureDetector(
        onTap: () {
          if (dish != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DishDetailScreen(dish: dish, initialVariantId: recipe.id),
              ),
            );
          }
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
                width: 80,
                height: 80,
                child: StripedPlaceholder(
                  hexColor: stripeHex,
                  height: 80,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            recipe.title.get(lang),
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.bookmark, color: VintageColors.terracotta, size: 22),
                          onPressed: () {
                            appState.toggleSaveRecipe(recipe.id);
                            _paginationController.loadInitial();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recipe.description.get(lang),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ebGaramond(fontSize: 14, color: VintageColors.inkLight),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        VintageBadge(label: '${recipe.totalTimeMinutes} min'),
                        const SizedBox(width: 6),
                        VintageBadge(label: '~${recipe.caloriesPerServing} kcal'),
                        const SizedBox(width: 6),
                        if (recipe.variantDimensionValues.containsKey('diet'))
                          VintageBadge(
                            label: recipe.variantDimensionValues['diet']!.toUpperCase(),
                            color: VintageColors.paperBg,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
