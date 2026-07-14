import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/style_model.dart';
import '../services/api_service.dart';
import '../services/local_cache_service.dart';

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

const String _trendingCacheKey = 'styles_cache_trending';
const String _recommendedCacheKey = 'styles_cache_recommended';

class DynamicStyleManager extends ChangeNotifier {
  List<CategoryModel> _categories = [];
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  // Trending is not a category - it's a dynamic collection of every enabled
  // style with isTrending == true, drawn from across all real categories. A
  // trending style keeps living in its own category's list too; this is a
  // second, independently-cached view of the same rows, not a copy of them.
  List<StyleModel> _trendingStyles = [];
  bool _hasLoadedTrending = false;
  bool _isTrendingLoading = false;
  Future<void>? _activeTrendingFetch;

  // "Recommended For You" - server-ranked (RecommendationService), never
  // re-sorted client-side. Empty means either personalization is off or
  // there isn't enough favorite/creation history yet to personalize from;
  // either way the Home screen simply doesn't render the section.
  List<StyleModel> _recommendedStyles = [];
  bool _hasLoadedRecommended = false;
  bool _isRecommendedLoading = false;
  Future<void>? _activeRecommendedFetch;

  final ApiService _apiService = ApiService();
  final LocalCacheService _cacheService = LocalCacheService();

  // Active future requests deduplication map
  final Map<String, Future<void>> _activeStyleFetches = {};

  // Track loading state for each category ID
  final Set<String> _loadingCategoryIds = {};

  List<CategoryModel> get categories => List.unmodifiable(_categories);
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<StyleModel> get trendingStyles => List.unmodifiable(_trendingStyles);
  bool get hasLoadedTrending => _hasLoadedTrending;
  bool get isTrendingLoading => _isTrendingLoading;

  List<StyleModel> get recommendedStyles => List.unmodifiable(_recommendedStyles);
  bool get hasLoadedRecommended => _hasLoadedRecommended;
  bool get isRecommendedLoading => _isRecommendedLoading;

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
      debugPrint("[DynamicStyleManager] Background sync initialization error: $e");
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
          debugPrint("[DynamicStyleManager] Loaded ${loaded.length} categories from cache (lazy styles).");
        }
      }
    } catch (e) {
      debugPrint("[DynamicStyleManager] Error loading cached categories: $e");
    }
  }

  /// Fetches Categories from backend (does not fetch styles).
  ///
  /// [forceRefresh] bypasses the 24h cache TTL entirely - used for explicit
  /// user-initiated refresh (pull-to-refresh), so a still-valid local cache
  /// can never mask categories added/removed on the backend when the user
  /// has explicitly asked for fresh data. Normal app-startup calls leave
  /// this false and keep the existing cache behavior unchanged.
  Future<void> fetchCategories({bool forceRefresh = false}) async {
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
        debugPrint("[DynamicStyleManager] Categories cache still valid. Skipping network load.");
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
        debugPrint("[DynamicStyleManager] Categories updated successfully.");

        _isLoading = false;
        _error = null;
        notifyListeners();
      } else {
        debugPrint("[DynamicStyleManager] Categories are up to date.");
        if (_isLoading) {
          _isLoading = false;
          _error = null;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("[DynamicStyleManager] Error fetching categories: $e");
      if (!hasCachedCategories) {
        _error = 'Failed to load categories: $e';
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
      debugPrint("[DynamicStyleManager] Deduplicating request: awaiting active future for category $categoryId");
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

  /// Lazy-loads the Trending collection (every enabled, isTrending style
  /// across all categories). Mirrors [loadStylesForCategory]'s cache-first,
  /// TTL, and in-flight-dedup behavior exactly, so Trending gets the same
  /// performance characteristics as a normal category section.
  Future<void> loadTrendingStyles() async {
    if (_activeTrendingFetch != null) {
      debugPrint("[DynamicStyleManager] Deduplicating request: awaiting active future for trending styles");
      return _activeTrendingFetch;
    }

    final fetchFuture = _loadTrendingStylesInternal();
    _activeTrendingFetch = fetchFuture;

    try {
      await fetchFuture;
    } finally {
      _activeTrendingFetch = null;
    }
  }

  Future<void> _loadTrendingStylesInternal() async {
    final hasStylesInMemory = _trendingStyles.isNotEmpty;

    // Load cached styles immediately (without blocking UI)
    final cachedStylesList = await _cacheService.getCachedData(_trendingCacheKey);
    final List<StyleModel> loadedFromCache = [];

    if (cachedStylesList is List) {
      for (final sJson in cachedStylesList) {
        if (sJson is Map) {
          loadedFromCache.add(StyleModel.fromJson(sJson as Map<String, dynamic>));
        }
      }
      if (loadedFromCache.isNotEmpty && !hasStylesInMemory) {
        _trendingStyles = loadedFromCache;
        _hasLoadedTrending = true;
        notifyListeners();
        debugPrint("[DynamicStyleManager] Loaded ${loadedFromCache.length} trending styles from cache.");
      }
    }

    // Styles Cache TTL: 6 hours (21600000 ms) - same as a category's styles cache.
    final int? timestamp = await _cacheService.getCacheTimestamp(_trendingCacheKey);
    final bool isCacheValid = timestamp != null &&
        (DateTime.now().millisecondsSinceEpoch - timestamp) < 21600000;

    if (isCacheValid && cachedStylesList != null) {
      debugPrint("[DynamicStyleManager] Trending styles cache still valid. Skipping API call.");
      if (!_hasLoadedTrending) {
        _hasLoadedTrending = true;
        notifyListeners();
      }
      return;
    }

    final showLoading = _trendingStyles.isEmpty;
    if (showLoading) {
      _isTrendingLoading = true;
      notifyListeners();
    }

    try {
      final styles = await _apiService.getTrendingStyles();
      final enabledStyles = styles.where((s) => s.isEnabled).toList();
      // Reuse the same ordering the backend and every category section rely
      // on (sortOrder, tie-broken by createdAt) so admins control Trending
      // card order the same way they control every other style list -
      // no separate ordering concept needed.
      enabledStyles.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      final List<StyleModel> styleModels = enabledStyles.map((s) => s.toStyleModel()).toList();
      final List<Map<String, dynamic>> stylesJsonList = styleModels.map((s) => s.toJson()).toList();

      final String newStylesStr = json.encode(stylesJsonList);
      final String oldStylesStr = cachedStylesList != null ? json.encode(cachedStylesList) : '';

      if (newStylesStr != oldStylesStr || !_hasLoadedTrending) {
        _trendingStyles = styleModels;
        _hasLoadedTrending = true;
        await _cacheService.cacheData(_trendingCacheKey, stylesJsonList);
        debugPrint("[DynamicStyleManager] Cached trending styles updated.");

        _isTrendingLoading = false;
        notifyListeners();
      } else {
        debugPrint("[DynamicStyleManager] Backend trending styles match cache.");
        if (_isTrendingLoading) {
          _isTrendingLoading = false;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("[DynamicStyleManager] Error fetching trending styles: $e");
      if (_isTrendingLoading) {
        _isTrendingLoading = false;
        notifyListeners();
      }
      // Offline fallback: continue displaying the cached version
    }
  }

  /// Lazy-loads "Recommended For You" (the personalized feed from
  /// RecommendationService). Mirrors [loadTrendingStyles]'s cache-first,
  /// TTL, and in-flight-dedup behavior, with two differences: a shorter 2h
  /// TTL (personalization should feel responsive to a fresh favorite/
  /// creation) and no client-side re-sort, since the backend's ranking is
  /// the whole point.
  Future<void> loadRecommendedStyles() async {
    if (_activeRecommendedFetch != null) {
      debugPrint("[DynamicStyleManager] Deduplicating request: awaiting active future for recommended styles");
      return _activeRecommendedFetch;
    }

    final fetchFuture = _loadRecommendedStylesInternal();
    _activeRecommendedFetch = fetchFuture;

    try {
      await fetchFuture;
    } finally {
      _activeRecommendedFetch = null;
    }
  }

  Future<void> _loadRecommendedStylesInternal() async {
    final hasStylesInMemory = _recommendedStyles.isNotEmpty;

    final cachedStylesList = await _cacheService.getCachedData(_recommendedCacheKey);
    final List<StyleModel> loadedFromCache = [];

    if (cachedStylesList is List) {
      for (final sJson in cachedStylesList) {
        if (sJson is Map) {
          loadedFromCache.add(StyleModel.fromJson(sJson as Map<String, dynamic>));
        }
      }
      if (loadedFromCache.isNotEmpty && !hasStylesInMemory) {
        _recommendedStyles = loadedFromCache;
        _hasLoadedRecommended = true;
        notifyListeners();
        debugPrint("[DynamicStyleManager] Loaded ${loadedFromCache.length} recommended styles from cache.");
      }
    }

    // Recommended Cache TTL: 2 hours (7200000 ms) - shorter than Trending's
    // 6h, since this depends on the user's own activity. FavoritesManager/
    // CreationsManager also force-invalidate this cache directly on every
    // favorite/creation change instead of waiting the TTL out.
    final int? timestamp = await _cacheService.getCacheTimestamp(_recommendedCacheKey);
    final bool isCacheValid = timestamp != null &&
        (DateTime.now().millisecondsSinceEpoch - timestamp) < 7200000;

    if (isCacheValid && cachedStylesList != null) {
      debugPrint("[DynamicStyleManager] Recommended styles cache still valid. Skipping API call.");
      if (!_hasLoadedRecommended) {
        _hasLoadedRecommended = true;
        notifyListeners();
      }
      return;
    }

    final showLoading = _recommendedStyles.isEmpty;
    if (showLoading) {
      _isRecommendedLoading = true;
      notifyListeners();
    }

    try {
      final styles = await _apiService.getRecommendedStyles();
      // No re-sort: unlike Trending/category lists (admin-controlled
      // sortOrder), this ranking comes entirely from RecommendationService -
      // Flutter must render it in the order the backend returns it.
      final List<StyleModel> styleModels = styles.map((s) => s.toStyleModel()).toList();
      final List<Map<String, dynamic>> stylesJsonList = styleModels.map((s) => s.toJson()).toList();

      final String newStylesStr = json.encode(stylesJsonList);
      final String oldStylesStr = cachedStylesList != null ? json.encode(cachedStylesList) : '';

      if (newStylesStr != oldStylesStr || !_hasLoadedRecommended) {
        _recommendedStyles = styleModels;
        _hasLoadedRecommended = true;
        await _cacheService.cacheData(_recommendedCacheKey, stylesJsonList);
        debugPrint("[DynamicStyleManager] Cached recommended styles updated.");

        _isRecommendedLoading = false;
        notifyListeners();
      } else {
        debugPrint("[DynamicStyleManager] Backend recommended styles match cache.");
        if (_isRecommendedLoading) {
          _isRecommendedLoading = false;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("[DynamicStyleManager] Error fetching recommended styles: $e");
      if (_isRecommendedLoading) {
        _isRecommendedLoading = false;
        notifyListeners();
      }
      // Offline fallback: continue displaying the cached version
    }
  }

  /// Clears the Recommended section's cache and in-memory state so the next
  /// [loadRecommendedStyles] call hits the network immediately instead of
  /// waiting out the 2h TTL. Called by FavoritesManager/CreationsManager
  /// whenever the user's favorite/creation history changes, since that's
  /// exactly the signal RecommendationService ranks on.
  Future<void> invalidateRecommendedCache() async {
    _hasLoadedRecommended = false;
    _recommendedStyles = [];
    await _cacheService.clearCache(_recommendedCacheKey);
    notifyListeners();
  }

  /// Loads "You may also like" for a given anchor style (Style Details).
  /// Unlike Recommended/Trending this isn't a manager-wide section - each
  /// caller gets its own cached list back directly, scoped to that anchor
  /// style, with a 6h TTL (same as Trending) since it only changes when
  /// admin tagging changes, not per-user behavior.
  Future<List<StyleModel>> loadSimilarStyles(String styleId, {int limit = 10}) async {
    final String cacheKey = 'styles_cache_similar_$styleId';
    final cachedStylesList = await _cacheService.getCachedData(cacheKey);

    final int? timestamp = await _cacheService.getCacheTimestamp(cacheKey);
    final bool isCacheValid = timestamp != null &&
        (DateTime.now().millisecondsSinceEpoch - timestamp) < 21600000;

    if (isCacheValid && cachedStylesList is List) {
      return cachedStylesList
          .whereType<Map>()
          .map((sJson) => StyleModel.fromJson(sJson as Map<String, dynamic>))
          .toList();
    }

    try {
      final styles = await _apiService.getSimilarStyles(styleId, limit: limit);
      final List<StyleModel> styleModels = styles.map((s) => s.toStyleModel()).toList();
      final List<Map<String, dynamic>> stylesJsonList = styleModels.map((s) => s.toJson()).toList();
      await _cacheService.cacheData(cacheKey, stylesJsonList);
      return styleModels;
    } catch (e) {
      debugPrint("[DynamicStyleManager] Error fetching similar styles for $styleId: $e");
      if (cachedStylesList is List) {
        // Offline fallback: serve stale cache rather than nothing.
        return cachedStylesList
            .whereType<Map>()
            .map((sJson) => StyleModel.fromJson(sJson as Map<String, dynamic>))
            .toList();
      }
      return [];
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
      final String cacheKey = 'styles_cache_${cat.id}';
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
        debugPrint('[DynamicStyleManager] Error reading cache during favorites check for category ${cat.id}: $e');
      }
    }
    return favorites;
  }

  Future<void> _loadStylesForCategoryInternal(String categoryId) async {
    var catIdx = _categories.indexWhere((c) => c.id == categoryId);
    if (catIdx == -1) return;

    final hasStylesInMemory = _categories[catIdx].styles.isNotEmpty;
    final String cacheKey = 'styles_cache_$categoryId';
    
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
        debugPrint("[DynamicStyleManager] Loaded ${loadedFromCache.length} styles from cache for category $categoryId.");
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
      debugPrint("[DynamicStyleManager] Styles cache valid for category $categoryId. Skipping API call.");
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
        debugPrint("[DynamicStyleManager] Cached styles updated for category $categoryId.");

        _loadingCategoryIds.remove(categoryId);
        notifyListeners();
      } else {
        debugPrint("[DynamicStyleManager] Backend styles match cache for category $categoryId.");
        if (_loadingCategoryIds.remove(categoryId)) {
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("[DynamicStyleManager] Error fetching styles for category $categoryId: $e");
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

    // Trending is refreshed unconditionally, just like an already-active
    // category's styles below - pull-to-refresh must not be gated by the 6h
    // TTL, so a style the admin just flagged/unflagged shows up immediately.
    try {
      final styles = await _apiService.getTrendingStyles();
      final enabledStyles = styles.where((s) => s.isEnabled).toList();
      enabledStyles.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      final List<StyleModel> styleModels = enabledStyles.map((s) => s.toStyleModel()).toList();
      final List<Map<String, dynamic>> stylesJsonList = styleModels.map((s) => s.toJson()).toList();

      final String newStylesStr = json.encode(stylesJsonList);
      final oldCachedList = await _cacheService.getCachedData(_trendingCacheKey);
      final String oldStylesStr = oldCachedList != null ? json.encode(oldCachedList) : '';

      if (newStylesStr != oldStylesStr || _trendingStyles.isEmpty) {
        _trendingStyles = styleModels;
        _hasLoadedTrending = true;
        await _cacheService.cacheData(_trendingCacheKey, stylesJsonList);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("[DynamicStyleManager] Error refreshing trending styles: $e");
    }

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
          final String cacheKey = 'styles_cache_$catId';
          final oldCatsJson = await _cacheService.getCachedData(cacheKey);
          final String oldStylesStr = oldCatsJson != null ? json.encode(oldCatsJson) : '';

          if (newStylesStr != oldStylesStr || _categories[catIdx].styles.isEmpty) {
            _categories[catIdx] = _categories[catIdx].copyWith(styles: styleModels);
            await _cacheService.cacheData(cacheKey, stylesJsonList);
            notifyListeners();
          }
        }
      } catch (e) {
        debugPrint("[DynamicStyleManager] Error refreshing active category $catId: $e");
      }
    }
  }

  // Preserve signatures to prevent compilation issues elsewhere
  Future<void> save() async {}
  Future<void> addCategory(String name) async {}
  Future<void> deleteCategory(String categoryId) async {}
  Future<void> addStyle(String categoryId, StyleModel style) async {}
  Future<void> deleteStyle(String categoryId, String styleId) async {}
  Future<void> toggleTrending(String categoryId, String styleId) async {}
}
