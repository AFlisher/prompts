import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

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
                      child: Icon(Icons.arrow_back,
                          color: _isDark ? AppTheme.white : AppTheme.black,
                          size: 16),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Privacy',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
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
              ),
              const SizedBox(height: 10),
              _LinkTile(
                icon: Icons.description_outlined,
                label: 'Terms of Service',
                isDark: _isDark,
                textColor: textColor,
                surfaceColor: surfaceColor,
              ),
              const SizedBox(height: 10),
              _LinkTile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete Account',
                isDark: _isDark,
                textColor: Colors.redAccent,
                surfaceColor: surfaceColor,
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
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final Color textColor;
  final Color surfaceColor;

  const _LinkTile({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.textColor,
    required this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
