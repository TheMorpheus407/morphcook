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

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _selectedDietFilter;
  String? _selectedEffortFilter;
  int? _selectedTimeFilter;

  late PaginationController<Recipe> _paginationController;

  @override
  void initState() {
    super.initState();
    _paginationController = PaginationController<Recipe>(
      type: PaginationType.cursor,
      pageSize: 20,
      prefetchThreshold: 10,
      maxRendered: 50,
      fetchPage: _fetchSearchResults,
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

  Future<PaginationResult<Recipe>> _fetchSearchResults(PaginationRequest request) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final lang = appState.lang;
    final query = _searchController.text.trim().toLowerCase();

    // Get all available recipes across loaded partitions
    final allRecipes = appState.corpus.recipes;

    // Filter matching recipes
    final matching = allRecipes.where((recipe) {
      // 1. Profile visibility check
      if (!appState.isRecipeVisible(recipe)) return false;

      // 2. Diet filter
      if (_selectedDietFilter != null) {
        final dietVal = recipe.variantDimensionValues['diet'];
        if (dietVal != _selectedDietFilter) return false;
      }

      // 3. Effort filter
      if (_selectedEffortFilter != null) {
        if (!recipe.attributes.contains(_selectedEffortFilter) &&
            recipe.variantDimensionValues['effort'] != _selectedEffortFilter) {
          return false;
        }
      }

      // 4. Time filter
      if (_selectedTimeFilter != null) {
        if (recipe.totalTimeMinutes > _selectedTimeFilter!) return false;
      }

      // 5. Query matching: title, description, tags, ingredient names
      if (query.isNotEmpty) {
        final title = recipe.title.get(lang).toLowerCase();
        final desc = recipe.description.get(lang).toLowerCase();
        final ingredientsText = recipe.ingredients.map((i) => i.name.get(lang).toLowerCase()).join(' ');
        final attrs = recipe.attributes.join(' ').toLowerCase();

        final tokens = query.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
        final matchesAll = tokens.every((token) =>
            title.contains(token) ||
            desc.contains(token) ||
            ingredientsText.contains(token) ||
            attrs.contains(token));

        if (!matchesAll) return false;
      }

      return true;
    }).toList();

    // Log zero-result searches to content_requests for gap analytics
    if (query.isNotEmpty && matching.isEmpty && request.offset == 0) {
      appState.logContentRequest(query);
    }

    // Cursor/offset slicing
    final startIndex = request.offset;
    final endIndex = (startIndex + request.limit).clamp(0, matching.length);

    if (startIndex >= matching.length) {
      return const PaginationResult(items: [], nextCursor: null, hasMore: false);
    }

    final pageItems = matching.sublist(startIndex, endIndex);
    final nextCursor = endIndex < matching.length ? '$endIndex' : null;

    return PaginationResult(
      items: pageItems,
      nextCursor: nextCursor,
      hasMore: nextCursor != null,
    );
  }

  void _onSearchChanged() {
    _paginationController.loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final lang = appState.lang;

    return Scaffold(
      backgroundColor: VintageColors.paperBg,
      appBar: AppBar(
        title: Text(lang == 'de' ? 'Katalog & Suche' : 'Index & Search'),
      ),
      body: Column(
        children: [
          // Search Input Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _onSearchChanged(),
              decoration: InputDecoration(
                hintText: lang == 'de' ? 'Nach Gericht, Zutat oder Tag suchen...' : 'Search by dish, ingredient, or tag...',
                hintStyle: GoogleFonts.ebGaramond(fontSize: 16, color: VintageColors.inkMuted),
                prefixIcon: const Icon(Icons.search, color: VintageColors.inkLight),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged();
                        },
                      )
                    : null,
                filled: true,
                fillColor: VintageColors.paperCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: VintageColors.paperBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: VintageColors.terracotta, width: 1.5),
                ),
              ),
            ),
          ),

          // Horizontal Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildDietFilterChip('vegan', 'Vegan'),
                const SizedBox(width: 6),
                _buildDietFilterChip('halal', 'Halal'),
                const SizedBox(width: 6),
                _buildDietFilterChip('gluten-free', 'Gluten-Free'),
                const SizedBox(width: 6),
                _buildEffortFilterChip('easy', lang == 'de' ? 'Einfach' : 'Easy'),
                const SizedBox(width: 6),
                _buildTimeFilterChip(30, '≤ 30 min'),
                const SizedBox(width: 6),
                _buildTimeFilterChip(15, '≤ 15 min'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Paginated Results List
          Expanded(
            child: AnimatedBuilder(
              animation: _paginationController,
              builder: (context, _) {
                final items = _paginationController.items;

                if (_paginationController.isLoading && items.isEmpty) {
                  return _buildSkeletonLoader();
                }

                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search_off, size: 48, color: VintageColors.inkMuted),
                          const SizedBox(height: 12),
                          Text(
                            lang == 'de' ? 'Keine Rezepte gefunden' : 'No Recipes Found',
                            style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            lang == 'de'
                                ? 'Deine Suche wurde in den Inhaltslücken protokolliert.'
                                : 'Your query has been logged to content request records.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.ebGaramond(fontSize: 15, color: VintageColors.inkLight),
                          ),
                        ],
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
                      child: _buildRecipeCard(context, recipe, dish, lang),
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

  Widget _buildDietFilterChip(String value, String label) {
    final isSelected = _selectedDietFilter == value;
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
      onSelected: (val) {
        setState(() => _selectedDietFilter = val ? value : null);
        _paginationController.loadInitial();
      },
    );
  }

  Widget _buildEffortFilterChip(String value, String label) {
    final isSelected = _selectedEffortFilter == value;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        color: isSelected ? Colors.white : VintageColors.ink,
      ),
      selectedColor: VintageColors.sage,
      backgroundColor: VintageColors.paperCard,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(color: isSelected ? VintageColors.sage : VintageColors.paperBorder),
      ),
      onSelected: (val) {
        setState(() => _selectedEffortFilter = val ? value : null);
        _paginationController.loadInitial();
      },
    );
  }

  Widget _buildTimeFilterChip(int minutes, String label) {
    final isSelected = _selectedTimeFilter == minutes;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        color: isSelected ? Colors.white : VintageColors.ink,
      ),
      selectedColor: VintageColors.mustard,
      backgroundColor: VintageColors.paperCard,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(color: isSelected ? VintageColors.mustard : VintageColors.paperBorder),
      ),
      onSelected: (val) {
        setState(() => _selectedTimeFilter = val ? minutes : null);
        _paginationController.loadInitial();
      },
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        height: 100,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: VintageColors.paperCard,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: VintageColors.paperBorder),
        ),
      ),
    );
  }

  Widget _buildRecipeCard(BuildContext context, Recipe recipe, Dish? dish, String lang) {
    final stripeHex = dish?.stripeColor ?? '#C25E40';

    return GestureDetector(
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
                  Text(
                    recipe.title.get(lang),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                    ),
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
                      VintageBadge(label: '${recipe.totalTimeMinutes}m'),
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
    );
  }
}
