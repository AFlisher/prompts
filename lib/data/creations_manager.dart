import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';
import '../services/local_cache_service.dart';
import '../utils/image_delivery.dart';

class CreationItem {
  final String id;
  final String styleId;
  final String styleName;
  final String imagePath; // The resulting styled photo asset path

  /// ~320x400 WebP browsing thumbnail of [imagePath]. Null for creations made
  /// before the thumbnail system existed, or migrated from the pre-backend
  /// local-only store - callers should fall back to [imagePath] in that case
  /// (see [displayThumbnail]).
  final String? thumbnailUrl;
  final String? originalImagePath; // The user's input photo file path
  final DateTime createdAt;

  CreationItem({
    required this.id,
    required this.styleId,
    required this.styleName,
    required this.imagePath,
    this.thumbnailUrl,
    this.originalImagePath,
    required this.createdAt,
  });

  /// The small, browsing-optimized image every grid/list card should render.
  /// Falls back to the full [imagePath] when no thumbnail exists yet.
  String get displayThumbnail =>
      (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) ? thumbnailUrl! : imagePath;

  Map<String, dynamic> toJson() => {
        'id': id,
        'styleId': styleId,
        'styleName': styleName,
        'imagePath': imagePath,
        'thumbnailUrl': thumbnailUrl,
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
      thumbnailUrl: json['thumbnailUrl'] as String?,
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

  /// Sprint 2 / B-6. Injectable so the pagination logic can be tested without
  /// a backend - the same test-seam convention PaywallScreen.fetchPacksOverride
  /// and ImageGenerationService.debugProviderOverride already use. Defaults to
  /// a real ApiService, so app code is unchanged.
  CreationsManager({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;
  final LocalCacheService _cacheService = LocalCacheService();
  static const String _migratedFlagKey = 'creations_migrated_v1';

  // A new/removed creation is exactly the signal RecommendationService ranks
  // "Recommended For You" on - clearing this cache key (DynamicStyleManager's,
  // not this manager's own) forces the next Home screen load to fetch fresh
  // recommendations instead of serving a stale one from before the change.
  static const String _recommendedCacheKey = 'styles_cache_recommended';

  // ─── Sprint 2 / B-6: cursor pagination ────────────────────────────────────
  //
  // The backend has always paginated this endpoint; nothing read the cursor, so
  // the gallery stopped at the 50 most recent images with no indication that
  // older ones existed. These three fields are the whole client half.
  String? _nextCursor;
  bool _hasMore = false;
  bool _isLoadingMore = false;

  List<CreationItem> get creations => List.unmodifiable(_creations);
  int get currentTab => _currentTab;
  bool get isInitialized => _isInitialized;

  /// True when the server reported further pages. Drives the list footer.
  bool get hasMore => _hasMore;

  /// True while [loadMore] is in flight. Prevents the scroll listener firing a
  /// second request for the same page.
  bool get isLoadingMore => _isLoadingMore;

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

  /// Reloads the first page from the backend, discarding any pages already
  /// scrolled into. Sprint 2 / B-6: this is the "start over" half of
  /// pagination, and the only way a deletion made on another device
  /// disappears here.
  Future<void> refresh() => _syncWithBackend();

  Future<void> _syncWithBackend() async {
    try {
      await _migrateLegacyCreationsIfNeeded();

      // The FIRST page replaces the local cache; later pages append. Replacing
      // on page one is what lets a deletion made on another device disappear
      // here, which appending would never achieve.
      final page = await _apiService.getCreationsPage();
      _creations = page.items.map((json) => CreationItem.fromJson(json)).toList();
      _nextCursor = page.nextCursor;
      _hasMore = page.hasMore;
      await save();
      notifyListeners();
    } catch (e) {
      debugPrint("[CreationsManager] Background sync failed, keeping local cache: $e");
    }
  }

  /// Sprint 2 / B-6. Appends the next page.
  ///
  /// Safe to call repeatedly and from a scroll listener: it returns
  /// immediately when there is nothing more to fetch or a fetch is already in
  /// flight, which is what stops a fling near the bottom firing five identical
  /// requests.
  ///
  /// A failure is deliberately quiet - it leaves `_hasMore` true so the next
  /// scroll retries, and keeps the pages already loaded rather than clearing
  /// the gallery over a dropped connection.
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _nextCursor == null) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _apiService.getCreationsPage(cursor: _nextCursor);

      // De-duplicate by id. A creation added locally between pages (the user
      // generated an image while scrolling) would otherwise appear twice: once
      // from the local insert, once from the server page that also contains it.
      final existing = _creations.map((c) => c.id).toSet();
      final incoming = page.items
          .map((json) => CreationItem.fromJson(json))
          .where((c) => !existing.contains(c.id));

      _creations.addAll(incoming);
      _nextCursor = page.nextCursor;
      _hasMore = page.hasMore;

      // Persisted so a relaunch shows everything already paged in rather than
      // silently dropping back to the first page.
      await save();
    } catch (e) {
      debugPrint("[CreationsManager] loadMore failed, keeping what is loaded: $e");
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// One-time upload of creations that were only ever recorded in the local
  /// JSON file, from before backend persistence existed. Guarded by a
  /// persisted flag so it only ever runs once per install.
  Future<void> _migrateLegacyCreationsIfNeeded() async {
    try {
      final alreadyMigrated = await _cacheService.getCachedData(_migratedFlagKey);
      if (alreadyMigrated == true) return;

      // SEC-8.1B-2: never repost a URL that points at our own backend.
      //
      // This sends locally-stored image URLs back to the server, where they
      // are written into creations.image_url verbatim. That is fine for the
      // legacy values it exists for (bundled asset paths and permanent public
      // object URLs), and wrong for a stable backend delivery URL: the column
      // is an object reference that erasure and reconciliation both resolve
      // against storage, so a row pointing at an API route would reference no
      // object at all. Filtering here means the migration path needs no
      // further change when delivery moves.
      final migratable =
          _creations.where((c) => !isBackendImageUrl(c.imagePath)).toList();

      if (migratable.isNotEmpty) {
        final payload = migratable
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
    unawaited(_cacheService.clearCache(_recommendedCacheKey));
  }

  Future<void> deleteCreation(String id) async {
    _creations.removeWhere((c) => c.id == id);
    await save();
    notifyListeners();
    unawaited(_cacheService.clearCache(_recommendedCacheKey));

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

  /// Wipes this account's creations on sign-out - both in memory and the
  /// on-device cache file. Deleting the file (not just resetting
  /// [isInitialized]) matters just as much as resetting the flag: [init]
  /// reads that file straight into memory *before* it syncs with the
  /// backend, so leaving Account A's file on disk would let it flash on
  /// screen for the next account the moment [init] runs again, even though
  /// the in-memory list was already cleared here.
  Future<void> clear() async {
    _creations = [];
    _nextCursor = null;
    _hasMore = false;
    _isLoadingMore = false;
    _currentTab = 0;
    _isInitialized = false;
    notifyListeners();

    try {
      final file = await _localFile;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint("[CreationsManager] Error deleting local creations cache: $e");
    }
  }
}
