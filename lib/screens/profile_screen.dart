import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  final bool isDarkMode;

  const ProfileScreen({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? AppTheme.black : AppTheme.white;
    final textColor = isDarkMode ? AppTheme.white : AppTheme.black;
    final surfaceColor = isDarkMode ? AppTheme.darkCard : AppTheme.lightGray;

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
                      'Pro Member · ✨ AI Style Explorer',
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
                    isDark: isDarkMode,
                    textColor: textColor,
                    surface: surfaceColor,
                  ),
                  const SizedBox(width: 12),
                  _StatTile(
                    label: 'Favorites',
                    value: '0',
                    isDark: isDarkMode,
                    textColor: textColor,
                    surface: surfaceColor,
                  ),
                  const SizedBox(width: 12),
                  _StatTile(
                    label: 'Styles Used',
                    value: '0',
                    isDark: isDarkMode,
                    textColor: textColor,
                    surface: surfaceColor,
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Settings tiles
              _SettingsTile(
                icon: Icons.person_outline_rounded,
                label: 'Edit Profile',
                isDark: isDarkMode,
                textColor: textColor,
                surface: surfaceColor,
              ),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                isDark: isDarkMode,
                textColor: textColor,
                surface: surfaceColor,
              ),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy',
                isDark: isDarkMode,
                textColor: textColor,
                surface: surfaceColor,
              ),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                label: 'Help & Support',
                isDark: isDarkMode,
                textColor: textColor,
                surface: surfaceColor,
              ),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.logout_rounded,
                label: 'Sign Out',
                isDark: isDarkMode,
                textColor: Colors.redAccent,
                surface: surfaceColor,
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

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.textColor,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
