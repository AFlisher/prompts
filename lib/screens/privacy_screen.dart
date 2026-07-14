import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/press_scale.dart';

class PrivacyScreen extends StatefulWidget {
  final bool isDarkMode;

  const PrivacyScreen({super.key, required this.isDarkMode});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  late bool _isDark;
  bool _analyticsEnabled = true;
  bool _personalizationEnabled = true;

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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                  Text(
                    'Privacy',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(color: textColor),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _LinkTile(
                icon: Icons.shield_rounded,
                label: 'Privacy Policy',
                isDark: _isDark,
                textColor: textColor,
                surfaceColor: surfaceColor,
                onTap: () => _showNotYetAvailable('Privacy Policy'),
              ),
              const SizedBox(height: 10),
              _LinkTile(
                icon: Icons.description_outlined,
                label: 'Terms of Service',
                isDark: _isDark,
                textColor: textColor,
                surfaceColor: surfaceColor,
                onTap: () => _showNotYetAvailable('Terms of Service'),
              ),
              const SizedBox(height: 10),
              _LinkTile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete Account',
                isDark: _isDark,
                textColor: Colors.redAccent,
                surfaceColor: surfaceColor,
                onTap: () => _showNotYetAvailable('Delete Account'),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'DATA PREFERENCES',
                  style: TextStyle(
                    color: AppTheme.mediumGray,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _ToggleTile(
                icon: Icons.analytics_rounded,
                label: 'Usage Analytics',
                subtitle: 'Help us improve the app',
                value: _analyticsEnabled,
                isDarkMode: _isDark,
                surfaceColor: surfaceColor,
                textColor: textColor,
                onChanged: (v) => setState(() => _analyticsEnabled = v),
              ),
              const SizedBox(height: 10),
              _ToggleTile(
                icon: Icons.tune_rounded,
                label: 'Personalization',
                subtitle: 'Tailored style recommendations',
                value: _personalizationEnabled,
                isDarkMode: _isDark,
                surfaceColor: surfaceColor,
                textColor: textColor,
                onChanged: (v) => setState(() => _personalizationEnabled = v),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // No real Delete Account / Privacy Policy / Terms of Service destinations
  // exist yet (see LEGAL_REQUIREMENTS.md - a release blocker); this matches
  // Paywall's footer-link pattern of an honest placeholder rather than a
  // dead tap target with no feedback at all.
  void _showNotYetAvailable(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label is not available yet.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final Color textColor;
  final Color surfaceColor;
  final VoidCallback onTap;

  const _LinkTile({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.textColor,
    required this.surfaceColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
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

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final bool isDarkMode;
  final Color surfaceColor;
  final Color textColor;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.isDarkMode,
    required this.surfaceColor,
    required this.textColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accentPurple, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.mediumGray,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.accentPurple,
            activeTrackColor: AppTheme.accentPurple.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}
