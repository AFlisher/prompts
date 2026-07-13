import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCacheService {
  /// Helper to get the correct timestamp key format
  String _getTimestampKey(String key) {
    if (key.startsWith('styles_cache_')) {
      return 'styles_timestamp_${key.replaceFirst('styles_cache_', '')}';
    }
    return '${key}_timestamp';
  }

  /// Save any JSON-serializable data (Map, List, String, int, etc.)
  Future<void> cacheData(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonStr = json.encode(data);
      await prefs.setString(key, jsonStr);
      
      // Automatically save cache timestamp for the key
      final String timestampKey = _getTimestampKey(key);
      await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[LocalCacheService] Error caching data for key $key: $e');
    }
  }

  /// Get cached JSON-decoded data
  Future<dynamic> getCachedData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        return json.decode(jsonStr);
      }
    } catch (e) {
      debugPrint('[LocalCacheService] Error reading cached data for key $key: $e');
    }
    return null;
  }

  /// Get cache timestamp in milliseconds since epoch
  Future<int?> getCacheTimestamp(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_getTimestampKey(key));
    } catch (e) {
      debugPrint('[LocalCacheService] Error reading cache timestamp for key $key: $e');
    }
    return null;
  }

  /// Clear cache for a specific key
  Future<void> clearCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      await prefs.remove(_getTimestampKey(key));
    } catch (e) {
      debugPrint('[LocalCacheService] Error clearing cache for key $key: $e');
    }
  }
}
