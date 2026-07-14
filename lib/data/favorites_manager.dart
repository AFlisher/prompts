import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/local_cache_service.dart';

/// Central manager that tracks which style IDs are favorited.
/// Uses a ChangeNotifier so widgets can listen and rebuild when favorites change.
///
/// Local-cache-first, background-synced with the backend (the same pattern
/// already used for categories/styles): [init] loads the last-known set from
/// SharedPreferences instantly for a fast, offline-tolerant UI, then
/// reconciles with the backend in the background - the backend is the
/// durable, cross-device source of truth. [toggleFavorite] stays synchronous
/// and optimistic (no call-site changes needed elsewhere in the app), but now
/// also persists locally right away and fires the matching backend call in
/// the background, reverting on failure.
class FavoritesManager extends ChangeNotifier {
  final Set<String> _favoriteIds = {};
  bool _isInitialized = false;
  bool shouldSyncWithBackend = true;

  final ApiService _apiService = ApiService();
  final LocalCacheService _cacheService = LocalCacheService();
  static const String _cacheKey = 'favorites_cache';

  // Favoriting/unfavoriting a style is exactly the signal
  // RecommendationService ranks "Recommended For You" on - clearing this
  // cache key (DynamicStyleManager's, not this manager's own) forces the
  // next Home screen load to fetch fresh recommendations instead of
  // serving a stale one from before the change.
  static const String _recommendedCacheKey = 'styles_cache_recommended';

  /// Returns an unmodifiable view of all favorited style IDs.
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);
  bool get isInitialized => _isInitialized;

  /// Whether the given style ID is currently favorited.
  bool isFavorite(String id) => _favoriteIds.contains(id);

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final cached = await _cacheService.getCachedData(_cacheKey);
      if (cached is List) {
        _favoriteIds
          ..clear()
          ..addAll(cached.map((id) => id as String));
      }
    } catch (e) {
      debugPrint("[FavoritesManager] Error loading cached favorites: $e");
    }
    _isInitialized = true;
    notifyListeners();

    if (shouldSyncWithBackend) {
      unawaited(_syncWithBackend());
    }
  }

  Future<void> _syncWithBackend() async {
    try {
      final remoteIds = await _apiService.getFavorites();
      _favoriteIds
        ..clear()
        ..addAll(remoteIds);
      await _saveToCache();
      notifyListeners();
    } catch (e) {
      debugPrint("[FavoritesManager] Background sync failed, keeping local cache: $e");
    }
  }

  Future<void> _saveToCache() async {
    await _cacheService.cacheData(_cacheKey, _favoriteIds.toList());
  }

  /// Toggle the favorite state of a style. Returns the new state.
  bool toggleFavorite(String id) {
    final bool nowFavorited;
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
      nowFavorited = false;
    } else {
      _favoriteIds.add(id);
      nowFavorited = true;
    }
    notifyListeners();
    unawaited(_saveToCache());
    unawaited(_cacheService.clearCache(_recommendedCacheKey));

    if (shouldSyncWithBackend) {
      unawaited(_syncToggleToBackend(id, nowFavorited));
    }

    return nowFavorited;
  }

  Future<void> _syncToggleToBackend(String id, bool nowFavorited) async {
    try {
      if (nowFavorited) {
        await _apiService.addFavorite(id);
      } else {
        await _apiService.removeFavorite(id);
      }
    } catch (e) {
      debugPrint("[FavoritesManager] Failed to sync favorite toggle to backend, reverting: $e");
      // Revert the optimistic change so local state doesn't drift from the
      // backend; the next full sync would otherwise permanently disagree.
      if (nowFavorited) {
        _favoriteIds.remove(id);
      } else {
        _favoriteIds.add(id);
      }
      notifyListeners();
      unawaited(_saveToCache());
    }
  }
}
