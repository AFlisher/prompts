import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/press_scale.dart';
import '../main.dart';
import '../services/profile_service.dart';
import '../services/haptic_service.dart';
import '../services/feedback_prompt_service.dart';
import '../utils/page_transitions.dart';
import '../widgets/status_bar_style.dart';
import 'legal_document_screen.dart';

class PrivacyScreen extends StatefulWidget {
  final bool isDarkMode;

  const PrivacyScreen({super.key, required this.isDarkMode});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  late bool _isDark;
  bool _personalizationEnabled = true;
  bool _hapticFeedbackEnabled = HapticService.enabled;
  bool _askForRatingEnabled = FeedbackPromptService.askEnabled;
  final _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    _isDark = widget.isDarkMode;
    _personalizationEnabled =
        ProfileProvider.read(context).profile?.personalizationEnabled ?? true;
  }

  void _onHapticFeedbackChanged(bool value) {
    setState(() => _hapticFeedbackEnabled = value);
    HapticService.setEnabled(value);
    // Fires only if the toggle just turned ON (setEnabled updates the flag
    // synchronously first), giving immediate confirmation without needing a
    // special case for the off-state.
    HapticService.selection();
  }

  void _onAskForRatingChanged(bool value) {
    setState(() => _askForRatingEnabled = value);
    FeedbackPromptService.setAskEnabled(value);
    HapticService.selection();
  }

  Future<void> _onPersonalizationChanged(bool value) async {
    final previous = _personalizationEnabled;
    setState(() => _personalizationEnabled = value);
    HapticService.selection();

    try {
      final updated =
          await _profileService.updateProfile(personalizationEnabled: value);
      if (!mounted) return;
      ProfileProvider.read(context).updateProfile(updated);
    } catch (_) {
      if (!mounted) return;
      setState(() => _personalizationEnabled = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save this setting. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDark ? AppTheme.black : AppTheme.lightBackground;
    final textColor = _isDark ? AppTheme.white : AppTheme.black;
    final surfaceColor = _isDark ? AppTheme.darkCard : AppTheme.lightGray;

    return StatusBarStyle(
      isDark: _isDark,
      child: Scaffold(
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
                        HapticService.light();
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
                  onTap: () => _openLegalDocument(
                    title: 'Privacy Policy',
                    sections: LegalDocuments.privacyPolicy,
                  ),
                ),
                const SizedBox(height: 10),
                _LinkTile(
                  icon: Icons.description_outlined,
                  label: 'Terms of Service',
                  isDark: _isDark,
                  textColor: textColor,
                  surfaceColor: surfaceColor,
                  onTap: () => _openLegalDocument(
                    title: 'Terms of Service',
                    sections: LegalDocuments.termsOfService,
                  ),
                ),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
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
                  icon: Icons.tune_rounded,
                  label: 'Personalization',
                  subtitle: 'Tailored style recommendations',
                  value: _personalizationEnabled,
                  isDarkMode: _isDark,
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                  onChanged: _onPersonalizationChanged,
                ),
                const SizedBox(height: 10),
                _ToggleTile(
                  icon: Icons.vibration_rounded,
                  label: 'Haptic Feedback',
                  subtitle: 'Subtle vibration on key actions',
                  value: _hapticFeedbackEnabled,
                  isDarkMode: _isDark,
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                  onChanged: _onHapticFeedbackChanged,
                ),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'FEEDBACK',
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
                  icon: Icons.star_rounded,
                  label: 'Ask me to rate generated images',
                  subtitle: 'Occasionally prompt for feedback after a generation',
                  value: _askForRatingEnabled,
                  isDarkMode: _isDark,
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                  onChanged: _onAskForRatingChanged,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openLegalDocument({
    required String title,
    required List<LegalSection> sections,
  }) {
    Navigator.push(
      context,
      fadeSlidePageRoute(
        (_) => LegalDocumentScreen(
          isDarkMode: _isDark,
          title: title,
          lastUpdated: LegalDocuments.lastUpdated,
          sections: sections,
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
        HapticService.light();
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
            const Icon(
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
