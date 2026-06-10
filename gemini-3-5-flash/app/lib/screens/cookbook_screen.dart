import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/brand_theme.dart';
import 'dish_detail_screen.dart';

class CookbookScreen extends StatefulWidget {
  const CookbookScreen({super.key});

  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen> {
  final ScrollController _scrollController = ScrollController();

  // Offset-based pagination state
  final List<Recipe> _renderedRecipes = [];
  int _currentOffset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  static const int _pageSize = 30;
  static const int _prefetchThreshold = 10;
  static const int _maxRenderedItems = 50;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadSavedRecipes(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // Estimate if we are within prefetch threshold
    if (maxScroll - currentScroll <= 800.0) {
      _loadMore();
    }
  }

  List<Recipe> _getSavedRecipes(AppProvider provider) {
    final list = <Recipe>[];
    for (var id in provider.savedRecipeIds) {
      final recipe = provider.recipes[id];
      if (recipe != null) {
        list.add(recipe);
      }
    }
    return list;
  }

  void _loadSavedRecipes({bool reset = false}) {
    if (reset) {
      setState(() {
        _currentOffset = 0;
        _renderedRecipes.clear();
        _hasMore = true;
        _isLoadingMore = false;
      });
    }

    final provider = Provider.of<AppProvider>(context, listen: false);
    final allSaved = _getSavedRecipes(provider);

    if (_currentOffset >= allSaved.length) {
      setState(() {
        _hasMore = false;
      });
      return;
    }

    final endIdx = (_currentOffset + _pageSize) > allSaved.length 
      ? allSaved.length 
      : (_currentOffset + _pageSize);
    final nextPageItems = allSaved.sublist(_currentOffset, endIdx);

    setState(() {
      _renderedRecipes.addAll(nextPageItems);
      if (_renderedRecipes.length > _maxRenderedItems) {
        _renderedRecipes.removeRange(0, _renderedRecipes.length - _maxRenderedItems);
      }
      _currentOffset = endIdx;
      _hasMore = endIdx < allSaved.length;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() {
      _isLoadingMore = true;
    });

    await Future.delayed(const Duration(milliseconds: 150));
    _loadSavedRecipes();
    setState(() {
      _isLoadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final isEn = provider.currentLanguage == 'en';

    // Reload list on provider notifications in case items are removed elsewhere
    final currentSavedCount = provider.savedRecipeIds.length;
    final cachedAllSaved = _getSavedRecipes(provider);

    // If external changes happened, re-sync our paginated list
    if (cachedAllSaved.length != _renderedRecipes.length && !_isLoadingMore && !_hasMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSavedRecipes(reset: true);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEn ? "your custom cookbook" : "dein persönliches kochbuch",
                style: BrandFonts.displaySerif(fontSize: 22.0, italic: true),
              ),
              Text(
                isEn 
                  ? "saving specific, tailored variants that fit you" 
                  : "gespeicherte, auf dich abgestimmte rezeptvarianten",
                style: BrandFonts.mono(fontSize: 10.0, color: BrandColors.softGrey),
              ),
            ],
          ),
        ),
        const DashedDivider(),

        Expanded(
          child: _renderedRecipes.isEmpty
              ? _buildEmptyState(isEn)
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _renderedRecipes.length + (_hasMore ? 1 : 0),
                  separatorBuilder: (context, index) => const SizedBox(height: 24.0),
                  itemBuilder: (context, index) {
                    if (index == _renderedRecipes.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: CircularProgressIndicator(color: BrandColors.coral),
                        ),
                      );
                    }

                    final recipe = _renderedRecipes[index];
                    // Find associated dish
                    final dish = provider.dishes.firstWhere((d) => d.id == recipe.dishId);
                    return _buildSavedPolaroidCard(context, recipe, dish, provider);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isEn) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isEn ? "cookbook is empty" : "das kochbuch ist leer",
            style: BrandFonts.displaySerif(fontSize: 20.0, italic: true),
          ),
          const SizedBox(height: 8.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              isEn 
                ? "save your favorite customized recipe variants from the dish detail pages!" 
                : "speichere deine liebsten angepassten rezepte von den detailseiten!",
              textAlign: TextAlign.center,
              style: BrandFonts.mono(fontSize: 12.0, color: BrandColors.softGrey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedPolaroidCard(BuildContext context, Recipe recipe, Dish dish, AppProvider provider) {
    final isEn = provider.currentLanguage == 'en';
    final stripeColor = Color(int.parse(dish.stripeColor));
    final recipeTitle = recipe.name[isEn ? 'en' : 'de'] ?? dish.canonicalName[isEn ? 'en' : 'de'] ?? '';

    return Center(
      child: Stack(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DishDetailScreen(dish: dish)),
              );
            },
            child: PolaroidCard(
              rotation: 1.0,
              child: Container(
                width: 270.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StripedPlaceholder(
                      color: stripeColor,
                      caption: dish.capCaption[isEn ? 'en' : 'de'] ?? '',
                      height: 150.0,
                    ),
                    const SizedBox(height: 12.0),
                    Text(
                      recipeTitle.toLowerCase(),
                      style: BrandFonts.displaySerif(fontSize: 18.0, italic: true, fontWeight: FontWeight.bold),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
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
            ),
          ),

          // Action Button to Unsave
          Positioned(
            top: 16.0,
            right: 16.0,
            child: GestureDetector(
              onTap: () {
                provider.toggleSavedRecipe(recipe.id);
              },
              child: Container(
                padding: const EdgeInsets.all(4.0),
                color: Colors.white,
                child: const Icon(Icons.bookmark_remove, color: BrandColors.coral, size: 20.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
