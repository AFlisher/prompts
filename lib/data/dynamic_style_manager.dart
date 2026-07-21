import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/style_model.dart';
import '../services/api_service.dart';
import '../services/local_cache_service.dart';
import '../services/network_client.dart';

class CategoryModel {
  final String id;
  final String name;
  final List<StyleModel> styles;

  /// Whether this category's style set has ever been successfully resolved
  /// (from cache or network) at least once this session - independent of
  /// whether the resolved set turned out to be empty. Without this,
  /// `styles.isEmpty` can't distinguish "never loaded" from "loaded, and
  /// genuinely has zero styles," which caused empty categories to reload
  /// forever (every notifyListeners() re-triggered a reload that could
  /// never make `styles` non-empty).
  final bool hasLoadedStyles;

  CategoryModel({
    required this.id,
    required this.name,
    required this.styles,
    this.hasLoadedStyles = false,
  });

  CategoryModel copyWith({
    String? id,
    String? name,
    List<StyleModel>? styles,
    bool? hasLoadedStyles,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      styles: styles ?? this.styles,
      hasLoadedStyles: hasLoadedStyles ?? this.hasLoadedStyles,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'styles': styles.map((s) => s.toJson()).toList(),
      };

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      styles: (json['styles'] as List<dynamic>?)
              ?.map((s) => StyleModel.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// The category catalog: the category list, per-category lazy-loaded
/// styles, and their loading/error state. This is its own [ChangeNotifier]
/// (not folded into [DynamicStyleManager] itself) so that a category or its
/// styles loading only rebuilds widgets that actually listen to *this*
/// notifier - Trending/Recommended/filter-only widgets never see it fire.
///
/// Every method here is byte-for-byte the same lazy-loading/caching logic
/// that used to live directly on DynamicStyleManager - this is purely an
/// "extract class" move to change *which* Listenable each mutation notifies,
/// not a behavior change.
class CategoryCatalogNotifier extends ChangeNotifier {
  CategoryCatalogNotifier(this._apiService, this._cacheService);

  final ApiService _apiService;
  final LocalCacheService _cacheService;

  List<CategoryModel> _categories = [];
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  // Active future requests deduplication map
  final Map<String, Future<void>> _activeStyleFetches = {};

  // Track loading state for each category ID
  final Set<String> _loadingCategoryIds = {};

  List<CategoryModel> get categories => List.unmodifiable(_categories);
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool isCategoryLoading(String categoryId) => _loadingCategoryIds.contains(categoryId);

  /// Initialize and load categories from cache first, then sync categories from backend API
  Future<void> init() async {
    if (_isInitialized) return;

    // Load cached categories immediately
    await _loadCategoriesFromCache();

    // Start background sync
    fetchCategories().then((_) {
      _isInitialized = true;
    }).catchError((e) {
      _isInitialized = true;
      debugPrint("[CategoryCatalogNotifier] Background sync initialization error: $e");
    });
  }

  /// Loads Categories immediately from local cache (without loading all styles)
  Future<void> _loadCategoriesFromCache() async {
    try {
      final cachedCats = await _cacheService.getCachedData('categories_cache');
      if (cachedCats is List) {
        final List<CategoryModel> loaded = [];
        for (final catJson in cachedCats) {
          if (catJson is Map) {
            final String catId = (catJson['id'] as String?) ?? '';
            final String catName = (catJson['name'] as String?) ?? '';

            loaded.add(CategoryModel(
              id: catId,
              name: catName,
              styles: [], // Styles are lazy-loaded
            ));
          }
        }
        if (loaded.isNotEmpty) {
          _categories = loaded;
          notifyListeners();
          debugPrint("[CategoryCatalogNotifier] Loaded ${loaded.length} categories from cache (lazy styles).");
        }
      }
    } catch (e) {
      debugPrint("[CategoryCatalogNotifier] Error loading cached categories: $e");
    }
  }

  Future<void>? _activeCategoriesFetch;

  /// Fetches Categories from backend (does not fetch styles).
  ///
  /// [forceRefresh] bypasses the 24h cache TTL entirely - used for explicit
  /// user-initiated refresh (pull-to-refresh), so a still-valid local cache
  /// can never mask categories added/removed on the backend when the user
  /// has explicitly asked for fresh data. Normal app-startup calls leave
  /// this false and keep the existing cache behavior unchanged.
  ///
  /// Plain (non-forced) calls are deduplicated: [init] and Home's own
  /// mount-time check can both trigger this within the same cold-start
  /// window, and without this they'd fire two concurrent network requests
  /// for the same data. A forceRefresh call always runs fresh instead of
  /// reusing whatever plain fetch happens to already be in flight -
  /// pull-to-refresh must never silently resolve to a cached/in-flight
  /// result.
  Future<void> fetchCategories({bool forceRefresh = false}) {
    if (!forceRefresh) {
      final active = _activeCategoriesFetch;
      if (active != null) {
        debugPrint("[CategoryCatalogNotifier] Deduplicating fetchCategories(): awaiting active future.");
        return active;
      }
    }

    final fetch = _fetchCategoriesInternal(forceRefresh: forceRefresh);
    if (forceRefresh) return fetch;

    final tracked = fetch.whenComplete(() {
      _activeCategoriesFetch = null;
    });
    _activeCategoriesFetch = tracked;
    return tracked;
  }

  Future<void> _fetchCategoriesInternal({bool forceRefresh = false}) async {
    final hasCachedCategories = _categories.isNotEmpty;
    if (!hasCachedCategories) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      // Categories Cache TTL: 24 hours (86400000 ms)
      final int? timestamp = await _cacheService.getCacheTimestamp('categories_cache');
      final bool isCacheValid = !forceRefresh &&
          timestamp != null &&
          (DateTime.now().millisecondsSinceEpoch - timestamp) < 86400000;

      if (isCacheValid && hasCachedCategories) {
        debugPrint("[CategoryCatalogNotifier] Categories cache still valid. Skipping network load.");
        if (_isLoading) {
          _isLoading = false;
          notifyListeners();
        }
        return;
      }

      final cats = await _apiService.getCategories();
      // Filter enabled and sort categories
      final enabledCats = cats.where((c) => c.isEnabled).toList();
      enabledCats.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      final List<Map<String, String>> categoriesCacheList = enabledCats.map((cat) => {
        'id': cat.id,
        'name': cat.name,
      }).toList();

      final String newCatsJson = json.encode(categoriesCacheList);
      final oldCatsJson = await _cacheService.getCachedData('categories_cache');
      final String oldCatsStr = oldCatsJson != null ? json.encode(oldCatsJson) : '';

      // forceRefresh always takes this branch, even when the backend list is
      // byte-identical to the cache - a successful force refresh must still
      // update the cache timestamp so the 24h TTL window restarts from now.
      if (newCatsJson != oldCatsStr || !hasCachedCategories || forceRefresh) {
        final List<CategoryModel> updated = [];
        for (final catMap in categoriesCacheList) {
          final String catId = catMap['id']!;
          final String catName = catMap['name']!;

          final existingIdx = _categories.indexWhere((c) => c.id == catId);
          final List<StyleModel> existingStyles = existingIdx != -1 ? _categories[existingIdx].styles : [];
          final bool existingHasLoadedStyles = existingIdx != -1 && _categories[existingIdx].hasLoadedStyles;

          updated.add(CategoryModel(
            id: catId,
            name: catName,
            styles: existingStyles,
            hasLoadedStyles: existingHasLoadedStyles,
          ));
        }

        _categories = updated;
        await _cacheService.cacheData('categories_cache', categoriesCacheList);
        debugPrint("[CategoryCatalogNotifier] Categories updated successfully.");

        _isLoading = false;
        _error = null;
        notifyListeners();
      } else {
        debugPrint("[CategoryCatalogNotifier] Categories are up to date.");
        if (_isLoading) {
          _isLoading = false;
          _error = null;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("[CategoryCatalogNotifier] Error fetching categories: $e");
      if (!hasCachedCategories) {
        _error = friendlyNetworkErrorMessage(e);
        _isLoading = false;
        notifyListeners();
      } else {
        if (_isLoading) {
          _isLoading = false;
          notifyListeners();
        }
      }
    }
  }

  /// Lazy-loads styles for a specific category
  Future<void> loadStylesForCategory(String categoryId) async {
    // 1. Request Deduplication: reuse active future if currently fetching
    if (_activeStyleFetches.containsKey(categoryId)) {
      debugPrint("[CategoryCatalogNotifier] Deduplicating request: awaiting active future for category $categoryId");
      return _activeStyleFetches[categoryId];
    }

    final fetchFuture = _loadStylesForCategoryInternal(categoryId);
    _activeStyleFetches[categoryId] = fetchFuture;

    try {
      await fetchFuture;
    } finally {
      _activeStyleFetches.remove(categoryId);
    }
  }

  /// Loads favorited styles from active memory or SharedPreferences cache maps without polluting active RAM
  Future<List<StyleModel>> loadFavoriteStyles(List<String> favoriteIds) async {
    final List<StyleModel> favorites = [];
    if (favoriteIds.isEmpty) return favorites;

    for (final cat in _categories) {
      // 1. Read from memory if styles are already loaded
      if (cat.styles.isNotEmpty) {
        favorites.addAll(cat.styles.where((s) => favoriteIds.contains(s.id)));
        continue;
      }

      // 2. Otherwise read from specific category cache store
      final String cacheKey = 'styles_cache_v3_${cat.id}';
      try {
        final cachedData = await _cacheService.getCachedData(cacheKey);
        if (cachedData is List) {
          for (final sJson in cachedData) {
            if (sJson is Map) {
              final style = StyleModel.fromJson(sJson as Map<String, dynamic>);
              if (favoriteIds.contains(style.id)) {
                favorites.add(style);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[CategoryCatalogNotifier] Error reading cache during favorites check for category ${cat.id}: $e');
      }
    }
    return favorites;
  }

  Future<void> _loadStylesForCategoryInternal(String categoryId) async {
    var catIdx = _categories.indexWhere((c) => c.id == categoryId);
    if (catIdx == -1) return;

    final hasStylesInMemory = _categories[catIdx].styles.isNotEmpty;
    // v3: v2 entries were written before minImages/maxImages were serialized,
    // so a stale cache would render a multi-image style with one picker (and
    // a server-rejected generate) until the TTL expired. New namespace = one-time refetch.
    final String cacheKey = 'styles_cache_v3_$categoryId';

    // Load cached styles immediately (without blocking UI)
    final cachedStylesList = await _cacheService.getCachedData(cacheKey);
    final List<StyleModel> loadedFromCache = [];

    if (cachedStylesList is List) {
      for (final sJson in cachedStylesList) {
        if (sJson is Map) {
          loadedFromCache.add(StyleModel.fromJson(sJson as Map<String, dynamic>));
        }
      }
      catIdx = _categories.indexWhere((c) => c.id == categoryId);
      if (catIdx == -1) return;
      if (loadedFromCache.isNotEmpty && !hasStylesInMemory) {
        _categories[catIdx] = _categories[catIdx].copyWith(styles: loadedFromCache, hasLoadedStyles: true);
        notifyListeners();
        debugPrint("[CategoryCatalogNotifier] Loaded ${loadedFromCache.length} styles from cache for category $categoryId.");
      }
    }

    // Styles Cache TTL: 6 hours (21600000 ms)
    final int? timestamp = await _cacheService.getCacheTimestamp(cacheKey);
    final bool isCacheValid = timestamp != null &&
        (DateTime.now().millisecondsSinceEpoch - timestamp) < 21600000;

    // cachedStylesList != null (not loadedFromCache.isNotEmpty) so a
    // genuinely-empty-but-cached category still counts as a valid,
    // fresh cache hit instead of always falling through to the network.
    if (isCacheValid && cachedStylesList != null) {
      debugPrint("[CategoryCatalogNotifier] Styles cache valid for category $categoryId. Skipping API call.");
      catIdx = _categories.indexWhere((c) => c.id == categoryId);
      if (catIdx != -1 && !_categories[catIdx].hasLoadedStyles) {
        _categories[catIdx] = _categories[catIdx].copyWith(hasLoadedStyles: true);
        notifyListeners();
      }
      return;
    }

    catIdx = _categories.indexWhere((c) => c.id == categoryId);
    if (catIdx == -1) return;

    // Show loading spinner locally inside the category list if no styles are in RAM/cache yet
    final showLoading = _categories[catIdx].styles.isEmpty;
    if (showLoading) {
      _loadingCategoryIds.add(categoryId);
      notifyListeners();
    }

    try {
      final styles = await _apiService.getStylesByCategory(categoryId);
      final enabledStyles = styles.where((s) => s.isEnabled).toList();
      enabledStyles.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      final List<StyleModel> styleModels = enabledStyles.map((s) => s.toStyleModel()).toList();
      final List<Map<String, dynamic>> stylesJsonList = styleModels.map((s) => s.toJson()).toList();

      final String newStylesStr = json.encode(stylesJsonList);
      final String oldStylesStr = cachedStylesList != null ? json.encode(cachedStylesList) : '';

      final bool isDifferent = newStylesStr != oldStylesStr;

      catIdx = _categories.indexWhere((c) => c.id == categoryId);
      if (catIdx == -1) return;

      if (isDifferent || !_categories[catIdx].hasLoadedStyles) {
        _categories[catIdx] = _categories[catIdx].copyWith(styles: styleModels, hasLoadedStyles: true);
        await _cacheService.cacheData(cacheKey, stylesJsonList);
        debugPrint("[CategoryCatalogNotifier] Cached styles updated for category $categoryId.");

        _loadingCategoryIds.remove(categoryId);
        notifyListeners();
      } else {
        debugPrint("[CategoryCatalogNotifier] Backend styles match cache for category $categoryId.");
        if (_loadingCategoryIds.remove(categoryId)) {
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("[CategoryCatalogNotifier] Error fetching styles for category $categoryId: $e");
      if (_loadingCategoryIds.remove(categoryId)) {
        notifyListeners();
      }
      // Offline fallback: continue displaying the cached version
    }
  }

  /// Preserves API contract and refreshes Categories along with active Categories' styles.
  /// This is the user-initiated refresh path (pull-to-refresh, error-state
  /// retry), so it always force-refreshes the category list regardless of
  /// the 24h cache TTL.
  Future<void> fetchFromApi() async {
    await fetchCategories(forceRefresh: true);

    final activeIds = _categories.where((c) => c.styles.isNotEmpty).map((c) => c.id).toList();
    for (final catId in activeIds) {
      try {
        final catIdx = _categories.indexWhere((c) => c.id == catId);
        if (catIdx != -1) {
          final styles = await _apiService.getStylesByCategory(catId);
          final enabledStyles = styles.where((s) => s.isEnabled).toList();
          enabledStyles.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

          final List<StyleModel> styleModels = enabledStyles.map((s) => s.toStyleModel()).toList();
          final List<Map<String, dynamic>> stylesJsonList = styleModels.map((s) => s.toJson()).toList();

          final String newStylesStr = json.encode(stylesJsonList);
          final String cacheKey = 'styles_cache_v3_$catId';
          final oldCatsJson = await _cacheService.getCachedData(cacheKey);
          final String oldStylesStr = oldCatsJson != null ? json.encode(oldCatsJson) : '';

          if (newStylesStr != oldStylesStr || _categories[catIdx].styles.isEmpty) {
            _categories[catIdx] = _categories[catIdx].copyWith(styles: styleModels);
            await _cacheService.cacheData(cacheKey, stylesJsonList);
            notifyListeners();
          }
        }
      } catch (e) {
        debugPrint("[CategoryCatalogNotifier] Error refreshing active category $catId: $e");
      }
    }
  }

  /// Full wipe on sign-out: every category/style cache (in-memory and
  /// on-disk). A signed-out user lands on the Guest Home screen, which never
  /// reads this notifier - but the backend now also rejects categories/
  /// styles requests without a valid JWT, so nothing here should survive a
  /// logout to be shown (or silently reused) before the next account's own
  /// fetch.
  Future<void> clear() async {
    for (final cat in _categories) {
      await _cacheService.clearCache('styles_cache_v3_${cat.id}');
    }
    await _cacheService.clearCache('categories_cache');

    _categories = [];
    _isInitialized = false;
    _isLoading = false;
    _error = null;
    _loadingCategoryIds.clear();
    _activeStyleFetches.clear();
    notifyListeners();
  }
}

/// Home's category filter chips (selectedCategoryFilterIds). Its own
/// [ChangeNotifier] so applying/clearing a filter never rebuilds
/// Trending/Recommended/category-catalog-only widgets - only whatever
/// actually reads the filter set.
class CategoryFilterNotifier extends ChangeNotifier {
  // Home screen's search category filter. Lives here (not as local State on
  // HomeScreen) so it survives a tab switch away and back - MainShell tears
  // down and rebuilds HomeScreen's own State on every tab change (see
  // KeyedSubtree(key: ValueKey<int>(currentIndex)) in main_shell.dart), but
  // this notifier is a single instance held for the app's lifetime.
  Set<String> _selectedCategoryFilterIds = {};

  Set<String> get selectedCategoryFilterIds => Set.unmodifiable(_selectedCategoryFilterIds);

  /// Replaces the whole filter set at once - used when applying the picker
  /// bottom sheet's selection.
  void setCategoryFilters(Set<String> categoryIds) {
    if (setEquals(_selectedCategoryFilterIds, categoryIds)) return;
    _selectedCategoryFilterIds = Set.from(categoryIds);
    notifyListeners();
  }

  /// Removes a single category from the active filter - used by a chip's
  /// own remove (x) button.
  void removeCategoryFilter(String categoryId) {
    if (_selectedCategoryFilterIds.remove(categoryId)) {
      notifyListeners();
    }
  }

  /// Used by both "Clear All" below the search bar and "Reset" inside the
  /// picker sheet.
  void clearCategoryFilters() {
    if (_selectedCategoryFilterIds.isEmpty) return;
    _selectedCategoryFilterIds = {};
    notifyListeners();
  }
}

/// Trending Styles section (GET /api/styles?trending=true). Its own
/// [ChangeNotifier] so a trending refresh only rebuilds Trending-dependent
/// widgets, never Categories/Recommended/Filters.
class TrendingNotifier extends ChangeNotifier {
  TrendingNotifier(this._apiService);

  final ApiService _apiService;

  List<StyleModel> _trendingStyles = [];
  bool _isTrendingLoading = false;
  bool _hasLoadedTrending = false;
  Future<void>? _activeTrendingFetch;

  List<StyleModel> get trendingStyles => List.unmodifiable(_trendingStyles);
  bool get isTrendingLoading => _isTrendingLoading;

  /// True once a trending fetch has completed (successfully or not) this
  /// session - lets the Home section distinguish "still loading" from
  /// "loaded, and nothing is trending" so it can collapse instead of
  /// showing an empty header forever.
  bool get hasLoadedTrending => _hasLoadedTrending;

  Future<void> loadTrendingStyles() {
    // Deduplicate: multiple sections/rebuilds share one in-flight request.
    final active = _activeTrendingFetch;
    if (active != null) return active;

    final fetch = _loadTrendingStylesInternal().whenComplete(() {
      _activeTrendingFetch = null;
    });
    _activeTrendingFetch = fetch;
    return fetch;
  }

  Future<void> _loadTrendingStylesInternal() async {
    _isTrendingLoading = _trendingStyles.isEmpty;
    // These loaders are triggered from initState, so yield before the first
    // notifyListeners - notifying synchronously would mark widgets dirty
    // mid-build ("setState() called during build"). A microtask (not a
    // Timer) so widget tests don't trip the pending-timer invariant; it
    // drains only after the current frame's synchronous work completes.
    await Future<void>.microtask(() {});
    if (_isTrendingLoading) notifyListeners();

    try {
      final styles = await _apiService.getTrendingStyles();
      final enabled = styles.where((s) => s.isEnabled).toList();
      enabled.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      _trendingStyles = enabled.map((s) => s.toStyleModel()).toList();
    } catch (e) {
      debugPrint("[TrendingNotifier] Error fetching trending styles: $e");
      // Keep whatever was already displayed.
    } finally {
      _isTrendingLoading = false;
      _hasLoadedTrending = true;
      notifyListeners();
    }
  }

  /// Wipes trending state and its dedup future on sign-out. Unlike the
  /// category catalog, there's no on-disk cache for trending to clear - it's
  /// re-fetched fresh every time Home's Trending section mounts.
  void clear() {
    _trendingStyles = [];
    _isTrendingLoading = false;
    _hasLoadedTrending = false;
    _activeTrendingFetch = null;
    notifyListeners();
  }
}

/// Recommended For You section (GET /api/styles?recommended=true). Its own
/// [ChangeNotifier] so a recommendation refresh only rebuilds
/// Recommended-dependent widgets, never Categories/Trending/Filters.
class RecommendedNotifier extends ChangeNotifier {
  RecommendedNotifier(this._apiService);

  final ApiService _apiService;

  List<StyleModel> _recommendedStyles = [];
  bool _isRecommendedLoading = false;
  bool _hasLoadedRecommended = false;
  Future<void>? _activeRecommendedFetch;

  List<StyleModel> get recommendedStyles => List.unmodifiable(_recommendedStyles);
  bool get isRecommendedLoading => _isRecommendedLoading;

  /// Same "loaded vs. genuinely empty" distinction as [TrendingNotifier.hasLoadedTrending]:
  /// the backend returns an empty list whenever the section shouldn't show
  /// (personalization off, anonymous, not enough history), and the Home
  /// section hides itself only once this is true.
  bool get hasLoadedRecommended => _hasLoadedRecommended;

  Future<void> loadRecommendedStyles() {
    final active = _activeRecommendedFetch;
    if (active != null) return active;

    final fetch = _loadRecommendedStylesInternal().whenComplete(() {
      _activeRecommendedFetch = null;
    });
    _activeRecommendedFetch = fetch;
    return fetch;
  }

  Future<void> _loadRecommendedStylesInternal() async {
    _isRecommendedLoading = _recommendedStyles.isEmpty;
    // Same mid-build guard as TrendingNotifier._loadTrendingStylesInternal.
    await Future<void>.microtask(() {});
    if (_isRecommendedLoading) notifyListeners();

    try {
      final styles = await _apiService.getRecommendedStyles();
      final enabled = styles.where((s) => s.isEnabled).toList();
      // Server-side ranking order is the whole point of this endpoint -
      // do not re-sort by sortOrder here.
      _recommendedStyles = enabled.map((s) => s.toStyleModel()).toList();
    } catch (e) {
      debugPrint("[RecommendedNotifier] Error fetching recommended styles: $e");
    } finally {
      _isRecommendedLoading = false;
      _hasLoadedRecommended = true;
      notifyListeners();
    }
  }

  /// Wipes only the personalized "Recommended For You" state on sign-out.
  /// [recommendedStyles] is ranked server-side from *this* account's own
  /// favorite/creation history, so leaving it populated would let the next
  /// account's Home screen render Account A's personalized picks for a frame
  /// before the next fetch (which only _RecommendedSectionWidgetState.initState
  /// triggers, not this clear) overwrites it.
  void clearPersonalizedState() {
    _recommendedStyles = [];
    _isRecommendedLoading = false;
    _hasLoadedRecommended = false;
    _activeRecommendedFetch = null;
    notifyListeners();
  }
}

/// Composition root over the four independent slices that used to be one
/// large ChangeNotifier: [categoryCatalog], [categoryFilter], [trending],
/// and [recommended]. Each fires its own notifications independently, so a
/// change in one (e.g. Trending refreshing) no longer rebuilds widgets that
/// only depend on another (e.g. a Category section, or the filter chips
/// row).
///
/// This class itself still extends [ChangeNotifier] only so it remains a
/// valid `InheritedNotifier` payload (see StyleProvider in main.dart) for
/// dependency-injection purposes - it never calls its own [notifyListeners].
/// Widgets that need to rebuild on a specific slice's changes should listen
/// to that slice's notifier directly (e.g. `styleManager.trending`), not to
/// this manager - see home_screen.dart for the pattern.
///
/// Every method below is a thin pass-through preserving the exact same
/// public API (names, signatures, and behavior) DynamicStyleManager always
/// had, so no existing caller needs to change *how* it invokes these members
/// - only how it *listens* for the resulting change.
class DynamicStyleManager extends ChangeNotifier {
  DynamicStyleManager()
      : _apiService = ApiService(),
        _cacheService = LocalCacheService() {
    categoryCatalog = CategoryCatalogNotifier(_apiService, _cacheService);
    categoryFilter = CategoryFilterNotifier();
    trending = TrendingNotifier(_apiService);
    recommended = RecommendedNotifier(_apiService);
  }

  final ApiService _apiService;
  final LocalCacheService _cacheService;

  /// Categories + their lazily-loaded styles. Listen to this directly (not
  /// this manager) for category-only rebuilds.
  late final CategoryCatalogNotifier categoryCatalog;

  /// Home's category filter chips. Listen to this directly for filter-only
  /// rebuilds.
  late final CategoryFilterNotifier categoryFilter;

  /// Trending Styles section. Listen to this directly for trending-only
  /// rebuilds.
  late final TrendingNotifier trending;

  /// Recommended For You section. Listen to this directly for
  /// recommended-only rebuilds.
  late final RecommendedNotifier recommended;

  // ---------------------------------------------------------------------
  // Category catalog facade
  // ---------------------------------------------------------------------

  List<CategoryModel> get categories => categoryCatalog.categories;
  bool get isInitialized => categoryCatalog.isInitialized;
  bool get isLoading => categoryCatalog.isLoading;
  String? get error => categoryCatalog.error;

  bool isCategoryLoading(String categoryId) => categoryCatalog.isCategoryLoading(categoryId);

  Future<void> init() => categoryCatalog.init();

  Future<void> fetchCategories({bool forceRefresh = false}) =>
      categoryCatalog.fetchCategories(forceRefresh: forceRefresh);

  Future<void> loadStylesForCategory(String categoryId) =>
      categoryCatalog.loadStylesForCategory(categoryId);

  Future<List<StyleModel>> loadFavoriteStyles(List<String> favoriteIds) =>
      categoryCatalog.loadFavoriteStyles(favoriteIds);

  Future<void> fetchFromApi() => categoryCatalog.fetchFromApi();

  // ---------------------------------------------------------------------
  // Category filter facade
  // ---------------------------------------------------------------------

  Set<String> get selectedCategoryFilterIds => categoryFilter.selectedCategoryFilterIds;

  void setCategoryFilters(Set<String> categoryIds) => categoryFilter.setCategoryFilters(categoryIds);

  void removeCategoryFilter(String categoryId) => categoryFilter.removeCategoryFilter(categoryId);

  void clearCategoryFilters() => categoryFilter.clearCategoryFilters();

  // ---------------------------------------------------------------------
  // Trending facade (GET /api/styles?trending=true)
  // ---------------------------------------------------------------------

  List<StyleModel> get trendingStyles => trending.trendingStyles;
  bool get isTrendingLoading => trending.isTrendingLoading;
  bool get hasLoadedTrending => trending.hasLoadedTrending;

  Future<void> loadTrendingStyles() => trending.loadTrendingStyles();

  // ---------------------------------------------------------------------
  // Recommended facade (GET /api/styles?recommended=true)
  // ---------------------------------------------------------------------

  List<StyleModel> get recommendedStyles => recommended.recommendedStyles;
  bool get isRecommendedLoading => recommended.isRecommendedLoading;
  bool get hasLoadedRecommended => recommended.hasLoadedRecommended;

  Future<void> loadRecommendedStyles() => recommended.loadRecommendedStyles();

  // ---------------------------------------------------------------------
  // Similar styles (GET /api/styles/:id/similar)
  // ---------------------------------------------------------------------

  /// Returns styles similar to [styleId], ranked server-side. Unlike the
  /// sections above this is per-anchor-style, so the result is handed back
  /// to the caller (Style Details keeps it in local widget state) instead of
  /// being stored on any slice. Errors degrade to an empty list, which
  /// collapses the "You may also like" section.
  Future<List<StyleModel>> loadSimilarStyles(String styleId, {int limit = 10}) async {
    try {
      final styles = await _apiService.getSimilarStyles(styleId, limit: limit);
      final enabled = styles.where((s) => s.isEnabled).toList();
      return enabled.map((s) => s.toStyleModel()).toList();
    } catch (e) {
      debugPrint("[DynamicStyleManager] Error fetching similar styles for $styleId: $e");
      return [];
    }
  }

  /// Wipes only the personalized "Recommended For You" state on sign-out.
  /// Deliberately does NOT touch categories/trendingStyles/style caches -
  /// those are the shared platform catalog, identical for every account, so
  /// keeping them cached across a logout/login is not a privacy leak and
  /// avoids an unnecessary refetch.
  void clearPersonalizedState() => recommended.clearPersonalizedState();

  /// Full wipe on sign-out: every category/style/trending cache (in-memory
  /// and on-disk) plus everything [clearPersonalizedState] already covers.
  /// A signed-out user lands on the Guest Home screen, which never reads
  /// this manager - but the backend now also rejects categories/styles
  /// requests without a valid JWT, so nothing here should survive a logout
  /// to be shown (or silently reused) before the next account's own fetch.
  ///
  /// Each slice clears and notifies independently (categoryCatalog, then
  /// trending, then recommended) - so only whatever's actually listening to
  /// that particular slice rebuilds, instead of every Home section rebuilding
  /// together on every logout regardless of which data it depends on.
  Future<void> clear() async {
    await categoryCatalog.clear();
    trending.clear();
    recommended.clearPersonalizedState();
  }

  @override
  void dispose() {
    categoryCatalog.dispose();
    categoryFilter.dispose();
    trending.dispose();
    recommended.dispose();
    super.dispose();
  }
}
