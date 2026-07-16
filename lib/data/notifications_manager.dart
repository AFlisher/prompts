import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../services/api_service.dart';

/// Central manager for the in-app notification feed and its unread count
/// (the badge on Profile's Notifications tile). ChangeNotifier so widgets
/// rebuild the moment a notification is read anywhere - same pattern as
/// FavoritesManager/CreditManager.
class NotificationsManager extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  /// Test seams, mirroring PaywallScreen.fetchPacksOverride: let widget
  /// tests supply canned backend behavior instead of real HTTP.
  Future<({List<AppNotification> notifications, int unreadCount})> Function()?
      fetchOverride;
  Future<int> Function(String id)? markReadOverride;

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  List<AppNotification> get notifications =>
      List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;

  /// App-startup load so the Profile badge is correct before the
  /// Notifications screen is ever opened. Quietly tolerates being called
  /// while signed out - the fetch just fails and leaves the empty state.
  Future<void> init() async {
    if (_hasLoaded || _isLoading) return;
    await fetch();
  }

  Future<void> fetch() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = fetchOverride != null
          ? await fetchOverride!()
          : await _apiService.getNotifications();
      _notifications = result.notifications;
      _unreadCount = result.unreadCount;
      _hasLoaded = true;
    } catch (e) {
      debugPrint('[NotificationsManager] Failed to load notifications: $e');
      _errorMessage = 'Could not load notifications.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Optimistically marks one notification read (list + badge update
  /// immediately), reverting if the backend call fails - the same
  /// optimistic-with-revert convention used across the app.
  Future<void> markRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index == -1 || _notifications[index].isRead) return;

    final previousNotifications = _notifications;
    final previousUnread = _unreadCount;
    _notifications = [..._notifications];
    _notifications[index] = _notifications[index].copyWith(isRead: true);
    _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
    notifyListeners();

    try {
      final unread = markReadOverride != null
          ? await markReadOverride!(id)
          : await _apiService.markNotificationRead(id);
      _unreadCount = unread;
      notifyListeners();
    } catch (e) {
      debugPrint('[NotificationsManager] Failed to mark notification read, reverting: $e');
      _notifications = previousNotifications;
      _unreadCount = previousUnread;
      notifyListeners();
    }
  }

  /// Wipes feed state on sign-out so the next account never sees the
  /// previous user's notifications or badge.
  void clear() {
    _notifications = [];
    _unreadCount = 0;
    _hasLoaded = false;
    _errorMessage = null;
    notifyListeners();
  }
}
