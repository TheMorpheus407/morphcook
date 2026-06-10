import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/brand_theme.dart';
import 'dish_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  String _selectedCuisineTag = '';
  String _searchQuery = '';

  // Pagination state
  final List<Dish> _renderedDishes = [];
  int _currentCursorPage = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  static const int _pageSize = 20;
  static const int _prefetchThreshold = 10;
  static const int _maxRenderedItems = 50;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _performSearch(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    
    // Estimate if we are within prefetch threshold of the end
    // Item height average of 100.0, prefetch at 10 items (1000px before end)
    if (maxScroll - currentScroll <= 1000.0) {
      _loadMore();
    }
  }

  /// Filters dishes based on search query, tags, and user's profile
  List<Dish> _getFilteredDishes(AppProvider provider) {
    final query = _searchQuery.trim().toLowerCase();
    final matches = <Dish>[];

    for (var dish in provider.dishes) {
      // 1. Cuisine Tag filter
      if (_selectedCuisineTag.isNotEmpty && !dish.cuisineTags.contains(_selectedCuisineTag)) {
        continue;
      }

      // 2. Profile visibility check (Must have at least one visible variant recipe)
      final optimalRecipe = provider.getOptimalVariantForDish(dish);
      if (optimalRecipe == null) {
        continue;
      }

      // 3. Search query matching (matches canonical names, tags, or ingredient names in current language)
      if (query.isNotEmpty) {
        final nameEn = (dish.canonicalName['en'] ?? '').toLowerCase();
        final nameDe = (dish.canonicalName['de'] ?? '').toLowerCase();
        
        bool matchesQuery = nameEn.contains(query) || nameDe.contains(query);

        // Check ingredients of the optimal recipe
        if (!matchesQuery) {
          for (var ing in optimalRecipe.ingredients) {
            final ingNameEn = (ing.name['en'] ?? '').toLowerCase();
            final ingNameDe = (ing.name['de'] ?? '').toLowerCase();
            if (ingNameEn.contains(query) || ingNameDe.contains(query)) {
              matchesQuery = true;
              break;
            }
          }
        }

        // Check cuisine tags
        if (!matchesQuery) {
          for (var tag in dish.cuisineTags) {
            if (tag.toLowerCase().contains(query)) {
              matchesQuery = true;
              break;
            }
          }
        }

        if (!matchesQuery) {
          continue;
        }
      }

      matches.add(dish);
    }

    // Log zero-result searches to content_requests gap-logging in provider
    if (query.isNotEmpty && matches.isEmpty) {
      provider.logZeroResultSearch(query);
    }

    return matches;
  }

  void _performSearch({bool reset = false}) {
    if (reset) {
      setState(() {
        _currentCursorPage = 0;
        _renderedDishes.clear();
        _hasMore = true;
        _isLoadingMore = false;
      });
    }

    final provider = Provider.of<AppProvider>(context, listen: false);
    final allResults = _getFilteredDishes(provider);

    final startIdx = _currentCursorPage * _pageSize;
    if (startIdx >= allResults.length) {
      setState(() {
        _hasMore = false;
      });
      return;
    }

    final endIdx = (startIdx + _pageSize) > allResults.length ? allResults.length : (startIdx + _pageSize);
    final nextPageItems = allResults.sublist(startIdx, endIdx);

    setState(() {
      _renderedDishes.addAll(nextPageItems);
      // Cap maximum rendered items at 50 to maintain performance
      if (_renderedDishes.length > _maxRenderedItems) {
        _renderedDishes.removeRange(0, _renderedDishes.length - _maxRenderedItems);
      }
      _currentCursorPage++;
      _hasMore = endIdx < allResults.length;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() {
      _isLoadingMore = true;
    });

    // Simulate slight offline loading delay for pagination feel
    await Future.delayed(const Duration(milliseconds: 150));
    _performSearch();
    setState(() {
      _isLoadingMore = false;
    });
  }

  void _onTagSelected(String tag) {
    setState(() {
      _selectedCuisineTag = _selectedCuisineTag == tag ? '' : tag;
    });
    _performSearch(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final isEn = provider.currentLanguage == 'en';

    final textSearch = isEn ? "search recipes..." : "rezepte suchen...";
    final textAll = isEn ? "all cuisines" : "alle küchen";

    final cuisineTags = ['italian', 'asian', 'middle-eastern'];

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: TextField(
            controller: _searchController,
            cursorColor: BrandColors.charcoalInk,
            style: BrandFonts.mono(fontSize: 14.0),
            decoration: InputDecoration(
              hintText: textSearch,
              hintStyle: BrandFonts.mono(fontSize: 12.0, color: BrandColors.softGrey),
              prefixIcon: const Icon(Icons.search, color: BrandColors.charcoalInk, size: 20.0),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: BrandColors.charcoalInk, size: 18.0),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                        _performSearch(reset: true);
                      },
                    )
                  : null,
              isDense: true,
              fillColor: Colors.white,
              filled: true,
              enabledBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: BrandColors.charcoalInk, width: 0.5),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: BrandColors.coral, width: 1.5),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
              _performSearch(reset: true);
            },
          ),
        ),

        // Cuisine Tags Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 16.0, bottom: 12.0),
          child: Row(
            children: [
              // All Option
              GestureDetector(
                onTap: () {
                  setState(() => _selectedCuisineTag = '');
                  _performSearch(reset: true);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  margin: const EdgeInsets.only(right: 8.0),
                  decoration: BoxDecoration(
                    color: _selectedCuisineTag.isEmpty ? BrandColors.charcoalInk : Colors.white,
                    border: Border.all(color: BrandColors.charcoalInk, width: 0.5),
                  ),
                  child: Text(
                    textAll,
                    style: BrandFonts.mono(
                      fontSize: 11.0,
                      color: _selectedCuisineTag.isEmpty ? Colors.white : BrandColors.charcoalInk,
                    ),
                  ),
                ),
              ),

              ...cuisineTags.map((tag) {
                final active = _selectedCuisineTag == tag;
                return GestureDetector(
                  onTap: () => _onTagSelected(tag),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    margin: const EdgeInsets.only(right: 8.0),
                    decoration: BoxDecoration(
                      color: active ? BrandColors.coral : Colors.white,
                      border: Border.all(color: active ? BrandColors.coral : BrandColors.charcoalInk, width: 0.5),
                    ),
                    child: Text(
                      tag,
                      style: BrandFonts.mono(
                        fontSize: 11.0,
                        color: active ? Colors.white : BrandColors.charcoalInk,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),

        const DashedDivider(),

        // Search Results List (Cursor-paginated with prefetch)
        Expanded(
          child: _renderedDishes.isEmpty
              ? _buildEmptyState(isEn)
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _renderedDishes.length + (_hasMore ? 1 : 0),
                  separatorBuilder: (context, index) => const SizedBox(height: 12.0),
                  itemBuilder: (context, index) {
                    if (index == _renderedDishes.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: CircularProgressIndicator(color: BrandColors.coral, strokeWidth: 2.0),
                        ),
                      );
                    }

                    final dish = _renderedDishes[index];
                    final optimalRecipe = provider.getOptimalVariantForDish(dish)!;
                    return _buildDishSearchItem(context, dish, optimalRecipe, provider);
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
            isEn ? "no dishes found" : "keine gerichte gefunden",
            style: BrandFonts.displaySerif(fontSize: 20.0, italic: true),
          ),
          const SizedBox(height: 8.0),
          Text(
            isEn 
              ? "try a different query or loosen filters."
              : "versuche einen anderen suchbegriff.",
            style: BrandFonts.mono(fontSize: 12.0, color: BrandColors.softGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildDishSearchItem(BuildContext context, Dish dish, Recipe recipe, AppProvider provider) {
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
            // Colored stripe thumb
            Container(
              width: 60.0,
              height: 60.0,
              decoration: BoxDecoration(
                border: Border.all(color: BrandColors.charcoalInk, width: 0.5),
              ),
              child: CustomPaint(
                painter: _SearchStripesPainter(color: stripeColor),
              ),
            ),
            const SizedBox(width: 16.0),

            // Text details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toLowerCase(),
                    style: BrandFonts.displaySerif(fontSize: 16.0, italic: true, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    "${recipe.caloriesPerServing} kcal • ${recipe.timeMinutes} mins",
                    style: BrandFonts.mono(fontSize: 11.0, color: BrandColors.softGrey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14.0, color: BrandColors.charcoalInk),
          ],
        ),
      ),
    );
  }
}

class _SearchStripesPainter extends CustomPainter {
  final Color color;
  _SearchStripesPainter({required this.color});

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
