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

class DynamicStyleManager extends ChangeNotifier {
  List<CategoryModel> _categories = [];
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

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

  // ---------------------------------------------------------------------
  // Trending section (GET /api/styles?trending=true)
  // ---------------------------------------------------------------------

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
      debugPrint("[DynamicStyleManager] Error fetching trending styles: $e");
      // Keep whatever was already displayed.
    } finally {
      _isTrendingLoading = false;
      _hasLoadedTrending = true;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------
  // Recommended For You section (GET /api/styles?recommended=true)
  // ---------------------------------------------------------------------

  List<StyleModel> _recommendedStyles = [];
  bool _isRecommendedLoading = false;
  bool _hasLoadedRecommended = false;
  Future<void>? _activeRecommendedFetch;

  List<StyleModel> get recommendedStyles => List.unmodifiable(_recommendedStyles);
  bool get isRecommendedLoading => _isRecommendedLoading;

  /// Same "loaded vs. genuinely empty" distinction as [hasLoadedTrending]:
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
    // Same mid-build guard as _loadTrendingStylesInternal.
    await Future<void>.microtask(() {});
    if (_isRecommendedLoading) notifyListeners();

    try {
      final styles = await _apiService.getRecommendedStyles();
      final enabled = styles.where((s) => s.isEnabled).toList();
      // Server-side ranking order is the whole point of this endpoint -
      // do not re-sort by sortOrder here.
      _recommendedStyles = enabled.map((s) => s.toStyleModel()).toList();
    } catch (e) {
      debugPrint("[DynamicStyleManager] Error fetching recommended styles: $e");
    } finally {
      _isRecommendedLoading = false;
      _hasLoadedRecommended = true;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------
  // Similar styles (GET /api/styles/:id/similar)
  // ---------------------------------------------------------------------

  /// Returns styles similar to [styleId], ranked server-side. Unlike the
  /// sections above this is per-anchor-style, so the result is handed back
  /// to the caller (Style Details keeps it in local widget state) instead of
  /// being stored on the manager. Errors degrade to an empty list, which
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

  // Preserve signatures to prevent compilation issues elsewhere
  Future<void> save() async {}
  Future<void> addCategory(String name) async {}
  Future<void> deleteCategory(String categoryId) async {}
  Future<void> addStyle(String categoryId, StyleModel style) async {}
  Future<void> deleteStyle(String categoryId, String styleId) async {}
  Future<void> toggleTrending(String categoryId, String styleId) async {}
}
