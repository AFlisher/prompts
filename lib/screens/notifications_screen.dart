import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/status_bar_style.dart';
import '../main.dart';
import '../data/notifications_manager.dart';
import '../models/notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  final bool isDarkMode;

  const NotificationsScreen({super.key, required this.isDarkMode});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late bool _isDark;

  @override
  void initState() {
    super.initState();
    _isDark = widget.isDarkMode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // No-op when the app-startup load already succeeded.
      NotificationsProvider.read(context).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDark ? AppTheme.black : AppTheme.lightBackground;
    final textColor = _isDark ? AppTheme.white : AppTheme.black;
    final surfaceColor = _isDark ? AppTheme.darkCard : AppTheme.lightGray;

    final manager = NotificationsProvider.of(context);

    return StatusBarStyle(
      isDark: _isDark,
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: RefreshIndicator(
            color: AppTheme.accentPurple,
            onRefresh: () => NotificationsProvider.read(context).fetch(),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _isDark ? AppTheme.white : AppTheme.black,
                              ),
                            ),
                            child: Icon(Icons.arrow_back_ios_new_rounded,
                                color: _isDark ? AppTheme.white : AppTheme.black,
                                size: 16),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Notifications',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(color: textColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _openSettings(textColor),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.settings_rounded,
                              color: textColor,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ..._buildBodySlivers(manager, textColor, surfaceColor),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBodySlivers(
    NotificationsManager manager,
    Color textColor,
    Color surfaceColor,
  ) {
    if (manager.isLoading && !manager.hasLoaded) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentPurple),
            ),
          ),
        ),
      ];
    }

    if (manager.errorMessage != null && !manager.hasLoaded) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Failed to load notifications',
                  style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pull down to try again.',
                  style: TextStyle(color: AppTheme.mediumGray, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    final notifications = manager.notifications;
    if (notifications.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none_rounded,
                    color: AppTheme.mediumGray.withValues(alpha: 0.6), size: 48),
                const SizedBox(height: 16),
                Text(
                  'No notifications yet',
                  style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "You're all caught up.",
                  style: TextStyle(color: AppTheme.mediumGray, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    // Group into the same Today / This Week / Earlier sections the static
    // design used.
    final now = DateTime.now();
    final today = <AppNotification>[];
    final thisWeek = <AppNotification>[];
    final earlier = <AppNotification>[];
    for (final n in notifications) {
      final created = n.createdAt;
      if (created != null &&
          created.year == now.year &&
          created.month == now.month &&
          created.day == now.day) {
        today.add(n);
      } else if (created != null && now.difference(created).inDays < 7) {
        thisWeek.add(n);
      } else {
        earlier.add(n);
      }
    }

    final slivers = <Widget>[];
    void addSection(String title, List<AppNotification> items) {
      if (items.isEmpty) return;
      if (slivers.isNotEmpty) {
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));
      }
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.mediumGray,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < items.length; i++) {
        if (i > 0) {
          slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 10)));
        }
        final n = items[i];
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _NotificationItem(
                icon: _iconFor(n.type),
                iconColor: _colorFor(n.type),
                title: n.title,
                subtitle: n.body,
                time: _relativeTime(n.createdAt),
                isDark: _isDark,
                surfaceColor: surfaceColor,
                textColor: textColor,
                isUnread: !n.isRead,
                onTap: n.isRead
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        NotificationsProvider.read(context).markRead(n.id);
                      },
              ),
            ),
          ),
        );
      }
    }

    addSection('Today', today);
    addSection('This Week', thisWeek);
    addSection('Earlier', earlier);
    return slivers;
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'welcome':
        return Icons.person_outline_rounded;
      case 'generation':
        return Icons.auto_awesome_rounded;
      case 'credits':
        return Icons.stars_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'welcome':
        return AppTheme.accentBlue;
      case 'generation':
        return AppTheme.accentPurple;
      case 'credits':
        return Colors.amber;
      default:
        return AppTheme.accentPink;
    }
  }

  String _relativeTime(DateTime? createdAt) {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _openSettings(Color textColor) {
    HapticFeedback.selectionClick();
    showAppBottomSheet(
      context,
      isDarkMode: _isDark,
      contentBuilder: (context) => _NotificationSettingsSheet(textColor: textColor),
    );
  }
}

class _NotificationSettingsSheet extends StatefulWidget {
  final Color textColor;

  const _NotificationSettingsSheet({required this.textColor});

  @override
  State<_NotificationSettingsSheet> createState() =>
      _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState
    extends State<_NotificationSettingsSheet> {
  bool _push = true;
  bool _email = true;
  bool _promotions = false;
  bool _tips = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Notification Settings',
          style: TextStyle(
            color: widget.textColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
        _SheetToggle(
          label: 'Push Notifications',
          value: _push,
          textColor: widget.textColor,
          onChanged: (v) => setState(() => _push = v),
        ),
        const SizedBox(height: 16),
        _SheetToggle(
          label: 'Email Notifications',
          value: _email,
          textColor: widget.textColor,
          onChanged: (v) => setState(() => _email = v),
        ),
        const SizedBox(height: 16),
        _SheetToggle(
          label: 'Promotions',
          value: _promotions,
          textColor: widget.textColor,
          onChanged: (v) => setState(() => _promotions = v),
        ),
        const SizedBox(height: 16),
        _SheetToggle(
          label: 'Tips & Tricks',
          value: _tips,
          textColor: widget.textColor,
          onChanged: (v) => setState(() => _tips = v),
        ),
      ],
    );
  }
}

class _SheetToggle extends StatelessWidget {
  final String label;
  final bool value;
  final Color textColor;
  final ValueChanged<bool> onChanged;

  const _SheetToggle({
    required this.label,
    required this.value,
    required this.textColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppTheme.accentPurple,
          activeTrackColor: AppTheme.accentPurple.withValues(alpha: 0.4),
        ),
      ],
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;
  final bool isDark;
  final Color surfaceColor;
  final Color textColor;
  final bool isUnread;
  final VoidCallback? onTap;

  const _NotificationItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isDark,
    required this.surfaceColor,
    required this.textColor,
    this.isUnread = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: isUnread
              ? Border.all(
                  color: AppTheme.accentPurple.withValues(alpha: 0.3),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        time,
                        style: const TextStyle(
                          color: AppTheme.mediumGray,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.mediumGray,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
