import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'privacy_screen.dart';
import '../main.dart';
import 'paywall_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool isDarkMode;

  const ProfileScreen({super.key, required this.isDarkMode});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late bool _isDark;

  @override
  void initState() {
    super.initState();
    _isDark = widget.isDarkMode;
  }

  void _openEditProfile() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(isDarkMode: _isDark),
      ),
    );
  }

  void _openNotifications() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(isDarkMode: _isDark),
      ),
    );
  }

  void _openPrivacy() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrivacyScreen(isDarkMode: _isDark),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final bgColor = _isDark ? AppTheme.black : AppTheme.white;
    final textColor = _isDark ? AppTheme.white : AppTheme.black;
    final surfaceColor = _isDark ? AppTheme.darkCard : AppTheme.lightGray;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile',
                style: TextStyle(
                  color: textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 28),

              // Avatar & name
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.accentPurple, Color(0xFF3B82F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Center(
                        child: Text(
                          'A',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Ahmed',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Credits: ${CreditProvider.of(context).credits} · ✨ AI Style Explorer',
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
                    value: '0',
                    isDark: _isDark,
                    textColor: textColor,
                    surface: surfaceColor,
                  ),
                  const SizedBox(width: 12),
                  _StatTile(
                    label: 'Favorites',
                    value: '0',
                    isDark: _isDark,
                    textColor: textColor,
                    surface: surfaceColor,
                  ),
                  const SizedBox(width: 12),
                  _StatTile(
                    label: 'Styles Used',
                    value: '0',
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
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaywallScreen(isDarkMode: _isDark),
                    ),
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
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                isDark: _isDark,
                textColor: textColor,
                surface: surfaceColor,
                onTap: _openNotifications,
              ),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
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
                  HapticFeedback.lightImpact();
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
                            colors: [AppTheme.accentPurple, Color(0xFFE735F6)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
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
                  HapticFeedback.lightImpact();
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: _isDark ? AppTheme.darkCard : AppTheme.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: Text(
                        'Sign Out',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      content: Text(
                        'Are you sure you want to sign out?',
                        style: TextStyle(color: AppTheme.mediumGray),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: AppTheme.mediumGray),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                              (route) => false,
                            );
                          },
                          child: const Text(
                            'Sign Out',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
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

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.textColor,
    required this.surface,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.accentPurple, Color(0xFFE735F6)],
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
