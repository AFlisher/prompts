import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../theme/app_button_styles.dart';
import '../widgets/app_icon_dialog.dart';
import '../widgets/press_scale.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import '../services/haptic_service.dart';
import 'privacy_screen.dart';
import 'change_password_screen.dart';
import '../main.dart';
import 'paywall_screen.dart';
import 'wallet_history_screen.dart';
import '../services/auth_service.dart';
import '../widgets/floating_nav_bar_metrics.dart';
import '../utils/page_transitions.dart';

class ProfileScreen extends StatefulWidget {
  final bool isDarkMode;

  const ProfileScreen({super.key, required this.isDarkMode});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late bool _isDark;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _isDark = widget.isDarkMode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ProfileProvider.read(context).loadProfile();
      // No-op if already loaded; covers signing in after the app-startup
      // load ran while signed out, so the badge is correct on first open.
      NotificationsProvider.read(context).init();
    });
  }

  void _openEditProfile() {
    HapticService.light();
    Navigator.push(
      context,
      fadeSlidePageRoute((_) => EditProfileScreen(isDarkMode: _isDark)),
    );
  }

  void _openNotifications() {
    HapticService.light();
    Navigator.push(
      context,
      fadeSlidePageRoute((_) => NotificationsScreen(isDarkMode: _isDark)),
    );
  }

  void _openPrivacy() {
    HapticService.light();
    Navigator.push(
      context,
      fadeSlidePageRoute((_) => PrivacyScreen(isDarkMode: _isDark)),
    );
  }

  void _openChangePassword() {
    HapticService.light();
    Navigator.push(
      context,
      fadeSlidePageRoute((_) => ChangePasswordScreen(isDarkMode: _isDark)),
    );
  }

  void _openWalletHistory() {
    HapticService.light();
    Navigator.push(
      context,
      fadeSlidePageRoute((_) => WalletHistoryScreen(isDarkMode: _isDark)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDark ? AppTheme.black : AppTheme.lightBackground;
    final textColor = _isDark ? AppTheme.white : AppTheme.black;
    final surfaceColor = _isDark ? AppTheme.darkCard : AppTheme.lightGray;

    final profileManager = ProfileProvider.of(context);
    final profile = profileManager.profile;

    // .of(context) subscribes this screen to both managers, so the stats
    // row rebuilds automatically the moment a favorite is toggled or a
    // creation is added/removed anywhere else in the app - no separate
    // fetch needed, both lists are already loaded for their own screens.
    final favoritesCount = FavoritesProvider.of(context).favoriteIds.length;
    final creations = CreationsProvider.of(context).creations;
    final usedStylesCount =
        creations.map((c) => c.styleId).where((id) => id.isNotEmpty).toSet().length;

    if (profileManager.isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentPurple),
          ),
        ),
      );
    }

    if (profileManager.errorMessage != null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Failed to load profile',
                  style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  profileManager.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.mediumGray, fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => profileManager.loadProfile(force: true),
                  style: AppButtonStyles.primary(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Determine the user's name display
    final displayName = (profile?.fullName ?? '').trim().isNotEmpty
        ? profile!.fullName!.trim()
        : 'Ahmed';

    // Get initials for standard avatar placeholder
    final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            20,
            24,
            20,
            32 + FloatingNavBarMetrics.scrollClearance,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(color: textColor),
              ),
              const SizedBox(height: 28),

              // Avatar & name
              Center(
                child: Column(
                  children: [
                    profile?.avatarUrl != null && profile!.avatarUrl!.trim().isNotEmpty
                        ? Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              image: DecorationImage(
                                image: CachedNetworkImageProvider(profile.avatarUrl!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        : Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.accentPurple, AppTheme.accentBlue],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                    const SizedBox(height: 14),
                    Text(
                      displayName,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      // The saved Bio (editable in Edit Profile), falling
                      // back to the previous static tagline when unset.
                      'Credits: ${CreditProvider.of(context).credits} · ✨ ${(profile?.bio ?? '').trim().isNotEmpty ? profile!.bio!.trim() : 'AI Style Explorer'}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.mediumGray,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Stats row
              Row(
                children: [
                  _StatTile(
                    label: 'Creations',
                    value: '${creations.length}',
                    isDark: _isDark,
                    textColor: textColor,
                    surface: surfaceColor,
                  ),
                  const SizedBox(width: 12),
                  _StatTile(
                    label: 'Favorites',
                    value: '$favoritesCount',
                    isDark: _isDark,
                    textColor: textColor,
                    surface: surfaceColor,
                  ),
                  const SizedBox(width: 12),
                  _StatTile(
                    label: 'Styles Used',
                    value: '$usedStylesCount',
                    isDark: _isDark,
                    textColor: textColor,
                    surface: surfaceColor,
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Buy Credits Card
              _ProBannerCard(
                isDarkMode: _isDark,
                onTap: () {
                  HapticService.light();
                  Navigator.push(
                    context,
                    fadeSlidePageRoute((_) => PaywallScreen(isDarkMode: _isDark)),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Settings tiles
              _SettingsTile(
                icon: Icons.person_outline_rounded,
                label: 'Edit Profile',
                isDark: _isDark,
                textColor: textColor,
                surface: surfaceColor,
                onTap: _openEditProfile,
              ),
              if (profile?.provider == 'email') ...[
                const SizedBox(height: 10),
                _SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  label: 'Change Password',
                  isDark: _isDark,
                  textColor: textColor,
                  surface: surfaceColor,
                  onTap: _openChangePassword,
                ),
              ],
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.receipt_long_rounded,
                label: 'Transaction History',
                isDark: _isDark,
                textColor: textColor,
                surface: surfaceColor,
                onTap: _openWalletHistory,
              ),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.notifications_none_rounded,
                label: 'Notifications',
                isDark: _isDark,
                textColor: textColor,
                surface: surfaceColor,
                onTap: _openNotifications,
                // .of subscribes this screen to the manager, so the badge
                // clears itself the moment notifications are read.
                badgeCount: NotificationsProvider.of(context).unreadCount,
              ),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.privacy_tip_rounded,
                label: 'Privacy',
                isDark: _isDark,
                textColor: textColor,
                surface: surfaceColor,
                onTap: _openPrivacy,
              ),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                label: 'Help & Support',
                isDark: _isDark,
                textColor: textColor,
                surface: surfaceColor,
                onTap: () {
                  HapticService.light();
                  showAboutDialog(
                    context: context,
                    applicationName: 'StyliAI',
                    applicationVersion: '1.0.0',
                    applicationIcon: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.accentPurple, AppTheme.accentPink],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Contact us at support@styliai.app',
                        style: TextStyle(color: AppTheme.mediumGray, fontSize: 13),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.logout_rounded,
                label: 'Sign Out',
                isDark: _isDark,
                textColor: Colors.redAccent,
                surface: surfaceColor,
                onTap: () {
                  HapticService.light();
                  showAppIconDialog(
                    context,
                    icon: Icons.logout_rounded,
                    iconColor: Colors.redAccent,
                    title: 'Sign Out',
                    message: 'Are you sure you want to sign out?',
                    isDarkMode: _isDark,
                    secondaryLabel: 'Cancel',
                    primaryLabel: 'Sign Out',
                    primaryColor: Colors.redAccent,
                    onPrimaryPressed: () async {
                      HapticService.heavy();
                      profileManager.clear();
                      NotificationsProvider.read(context).clear();
                      await _authService.signOut();
                      if (mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final Color textColor;
  final Color surface;

  const _StatTile({
    required this.label,
    required this.value,
    required this.isDark,
    required this.textColor,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.mediumGray,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final Color textColor;
  final Color surface;
  final VoidCallback? onTap;

  /// Unread-count badge (e.g. Notifications). Hidden when 0.
  final int badgeCount;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.textColor,
    required this.surface,
    this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (badgeCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentPurple,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.mediumGray,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProBannerCard extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onTap;

  const _ProBannerCard({required this.isDarkMode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.accentPurple, AppTheme.accentPink],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentPurple.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.token_rounded, color: Colors.white, size: 28),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Purchase Credits Pack',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Top-up credits to generate stunning AI photos',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }
}
