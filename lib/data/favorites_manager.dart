import 'package:flutter/foundation.dart';

/// Central manager that tracks which style IDs are favorited.
/// Uses a ChangeNotifier so widgets can listen and rebuild when favorites change.
class FavoritesManager extends ChangeNotifier {
  final Set<String> _favoriteIds = {};

  /// Returns an unmodifiable view of all favorited style IDs.
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);

  /// Whether the given style ID is currently favorited.
  bool isFavorite(String id) => _favoriteIds.contains(id);

  /// Toggle the favorite state of a style. Returns the new state.
  bool toggleFavorite(String id) {
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
      notifyListeners();
      return false;
    } else {
      _favoriteIds.add(id);
      notifyListeners();
      return true;
    }
  }
}
