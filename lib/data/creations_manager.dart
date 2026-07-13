import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';
import '../services/local_cache_service.dart';

class CreationItem {
  final String id;
  final String styleId;
  final String styleName;
  final String imagePath; // The resulting styled photo asset path
  final String? originalImagePath; // The user's input photo file path
  final DateTime createdAt;

  CreationItem({
    required this.id,
    required this.styleId,
    required this.styleName,
    required this.imagePath,
    this.originalImagePath,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'styleId': styleId,
        'styleName': styleName,
        'imagePath': imagePath,
        'originalImagePath': originalImagePath,
        'createdAt': createdAt.toIso8601String(),
      };

  /// Accepts both the local-JSON-file shape ('imagePath') and the backend
  /// API's shape ('imageUrl') for the same field, so this one factory can
  /// parse either source. styleId is tolerated as missing/null - the
  /// backend's FK is ON DELETE SET NULL, since a style being deleted later
  /// must never delete a user's own creation history.
  factory CreationItem.fromJson(Map<String, dynamic> json) {
    return CreationItem(
      id: json['id'] as String,
      styleId: (json['styleId'] as String?) ?? '',
      styleName: json['styleName'] as String,
      imagePath: (json['imagePath'] as String?) ?? (json['imageUrl'] as String?) ?? '',
      originalImagePath: json['originalImagePath'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class CreationsManager extends ChangeNotifier {
  List<CreationItem> _creations = [];
  int _currentTab = 0;
  bool _isInitialized = false;
  bool shouldSaveToFile = true;
  bool shouldSyncWithBackend = true;

  final ApiService _apiService = ApiService();
  final LocalCacheService _cacheService = LocalCacheService();
  static const String _migratedFlagKey = 'creations_migrated_v1';

  List<CreationItem> get creations => List.unmodifiable(_creations);
  int get currentTab => _currentTab;
  bool get isInitialized => _isInitialized;

  Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/user_creations_v1.json');
  }

  /// Loads the on-device cache immediately (instant, offline-tolerant UI),
  /// then reconciles with the backend in the background - the backend is the
  /// durable, cross-device source of truth, but the local file means the
  /// Creations screen never has to wait on a network round-trip to show
  /// something.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> data = json.decode(content);
        _creations = data.map((item) => CreationItem.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint("Error loading creations: $e");
    }
    _isInitialized = true;
    notifyListeners();

    if (shouldSyncWithBackend) {
      unawaited(_syncWithBackend());
    }
  }

  Future<void> _syncWithBackend() async {
    try {
      await _migrateLegacyCreationsIfNeeded();

      final remote = await _apiService.getCreations();
      _creations = remote.map((json) => CreationItem.fromJson(json)).toList();
      await save();
      notifyListeners();
    } catch (e) {
      debugPrint("[CreationsManager] Background sync failed, keeping local cache: $e");
    }
  }

  /// One-time upload of creations that were only ever recorded in the local
  /// JSON file, from before backend persistence existed. Guarded by a
  /// persisted flag so it only ever runs once per install.
  Future<void> _migrateLegacyCreationsIfNeeded() async {
    try {
      final alreadyMigrated = await _cacheService.getCachedData(_migratedFlagKey);
      if (alreadyMigrated == true) return;

      if (_creations.isNotEmpty) {
        final payload = _creations
            .map((c) => {
                  'styleId': c.styleId.isEmpty ? null : c.styleId,
                  'styleName': c.styleName,
                  'imageUrl': c.imagePath,
                  'createdAt': c.createdAt.toIso8601String(),
                })
            .toList();
        await _apiService.migrateCreations(payload);
      }

      await _cacheService.cacheData(_migratedFlagKey, true);
    } catch (e) {
      debugPrint("[CreationsManager] Legacy creation migration failed, will retry next sync: $e");
      // Deliberately don't set the flag - retried on the next sync.
    }
  }

  Future<void> save() async {
    if (!shouldSaveToFile) return;
    try {
      final file = await _localFile;
      final content = json.encode(_creations.map((c) => c.toJson()).toList());
      await file.writeAsString(content);
    } catch (e) {
      debugPrint("Error saving creations: $e");
    }
  }

  /// A creation is only ever recorded server-side, automatically, right
  /// after a successful generation - this just reflects it locally
  /// immediately so the Creations screen doesn't wait on the next background
  /// sync to show it.
  Future<void> addCreation(CreationItem item) async {
    _creations.insert(0, item); // Newest first
    await save();
    notifyListeners();
  }

  Future<void> deleteCreation(String id) async {
    _creations.removeWhere((c) => c.id == id);
    await save();
    notifyListeners();

    if (shouldSyncWithBackend) {
      // Best-effort: a failure here just means this row reappears on the
      // next background sync, which is self-healing.
      unawaited(_apiService.deleteCreation(id).catchError((e) {
        debugPrint("[CreationsManager] Failed to delete creation on backend: $e");
      }));
    }
  }

  void setTab(int index) {
    if (_currentTab != index) {
      _currentTab = index;
      notifyListeners();
    }
  }
}
