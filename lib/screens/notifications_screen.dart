import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_sheet.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDark ? AppTheme.black : AppTheme.lightBackground;
    final textColor = _isDark ? AppTheme.white : AppTheme.black;
    final surfaceColor = _isDark ? AppTheme.darkCard : AppTheme.lightGray;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
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
            // Today section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text(
                  'Today',
                  style: TextStyle(
                    color: AppTheme.mediumGray,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _NotificationItem(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: AppTheme.accentPurple,
                  title: 'New Style Available',
                  subtitle: 'Check out the newly added Cyberpunk style',
                  time: '2m ago',
                  isDark: _isDark,
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _NotificationItem(
                  icon: Icons.favorite_rounded,
                  iconColor: Colors.redAccent,
                  title: 'Style Liked',
                  subtitle: 'Your creation with Toon Style got 15 likes',
                  time: '1h ago',
                  isDark: _isDark,
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            // This Week section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text(
                  'This Week',
                  style: TextStyle(
                    color: AppTheme.mediumGray,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _NotificationItem(
                  icon: Icons.person_outline_rounded,
                  iconColor: AppTheme.accentBlue,
                  title: 'Welcome to StyliAI',
                  subtitle: 'Start exploring styles and transform your photos',
                  time: '3d ago',
                  isDark: _isDark,
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _NotificationItem(
                  icon: Icons.tips_and_updates_rounded,
                  iconColor: AppTheme.accentPink,
                  title: 'Pro Tip',
                  subtitle: 'Try using natural lighting for better AI results',
                  time: '5d ago',
                  isDark: _isDark,
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                  isUnread: true,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
