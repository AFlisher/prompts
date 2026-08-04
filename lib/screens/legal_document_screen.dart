import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/status_bar_style.dart';
import '../services/haptic_service.dart';

/// A simple in-app reader for the app's legal documents (Privacy Policy /
/// Terms of Service), opened from PrivacyScreen's link tiles.
///
/// The documents are rendered in-app rather than launched as external URLs
/// because no hosted legal pages exist yet (see LEGAL_REQUIREMENTS.md - the
/// project deliberately avoids inventing placeholder URLs). The hosted,
/// publicly reachable versions required for app store submission remain
/// tracked there; this screen makes the in-app links genuinely functional
/// in the meantime. Header layout and spacing intentionally mirror
/// PrivacyScreen so navigation between the two feels seamless.
class LegalDocumentScreen extends StatelessWidget {
  final bool isDarkMode;
  final String title;
  final String lastUpdated;
  final List<LegalSection> sections;

  const LegalDocumentScreen({
    super.key,
    required this.isDarkMode,
    required this.title,
    required this.lastUpdated,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? AppTheme.black : AppTheme.lightBackground;
    final textColor = isDarkMode ? AppTheme.white : AppTheme.black;

    return StatusBarStyle(
      isDark: isDarkMode,
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
                            color: isDarkMode ? AppTheme.white : AppTheme.black,
                          ),
                        ),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            color: isDarkMode ? AppTheme.white : AppTheme.black,
                            size: 16),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .displayLarge
                            ?.copyWith(color: textColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Last updated: $lastUpdated',
                  style: const TextStyle(
                    color: AppTheme.mediumGray,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                for (final section in sections) ...[
                  Text(
                    section.heading,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    section.body,
                    style: const TextStyle(
                      color: AppTheme.mediumGray,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LegalSection {
  final String heading;
  final String body;

  const LegalSection(this.heading, this.body);
}

/// The documents themselves, written to match what the app actually does
/// today (Supabase auth/storage, photo upload for AI styling, AdMob
/// rewarded ads, credit wallet, personalization toggle) - not a generic
/// template. Review before store submission (see LEGAL_REQUIREMENTS.md).
abstract class LegalDocuments {
  static const String lastUpdated = 'July 16, 2026';

  static const List<LegalSection> privacyPolicy = [
    LegalSection(
      'What We Collect',
      'When you create an account we store your email address and display '
          'name (from email sign-up or Google Sign-In). Using the app, we '
          'process the photos you upload for styling in order to generate '
          'your requested image, and we store the resulting generated '
          'images, your credit balance and transaction history, and your '
          'app preferences such as dark mode and personalization.',
    ),
    LegalSection(
      'How Your Photos Are Used',
      'Photos you upload are sent to our servers solely to process your '
          'requested AI image generation. Your original uploaded photo is '
          'not permanently stored in StyliAI\'s own database or storage. To '
          'generate your styled image, it is securely transmitted to our AI '
          'service provider (OpenAI); our AI service provider processes '
          'uploaded images solely for the purpose of fulfilling your '
          'request. Generated results are saved to your account so they '
          'appear in My Creations. We do not use your photos for anything '
          'else.',
    ),
    LegalSection(
      'Advertising',
      'StyliAI shows rewarded ads through Google AdMob to let you earn free '
          'credits. AdMob may process device advertising identifiers under '
          'Google\'s own privacy policies. We do not share your photos or '
          'account details with advertisers.',
    ),
    LegalSection(
      'Personalization',
      'Style recommendations ("Recommended For You", "You may also like") '
          'are ranked using your favorites and creation history. You can '
          'turn this off at any time in Privacy > Personalization; when '
          'disabled, your history is not used for recommendations.',
    ),
    LegalSection(
      'Where Your Data Is Stored',
      'Account authentication and image files are handled by Supabase, and '
          'app data is processed by our backend service. Data is retained '
          'while your account is active.',
    ),
    LegalSection(
      'Sharing',
      'We do not sell your personal data. Information is shared only with '
          'the service providers named above, and only as needed to operate '
          'the app.',
    ),
    LegalSection(
      'Contact',
      'Questions about this policy or your data? Contact us at '
          'support@styliai.app.',
    ),
  ];

  static const List<LegalSection> termsOfService = [
    LegalSection(
      'Your Account',
      'You must provide accurate information when creating an account and '
          'keep your sign-in credentials secure. Your account is personal '
          'to you.',
    ),
    LegalSection(
      'Credits & Purchases',
      'Generating styled images costs credits. Credits can be earned '
          'through rewarded ads or acquired via credit packs. Credits are '
          'consumed when a generation runs and have no cash value. Abusing '
          'the credit system (for example, attempting to bypass daily '
          'reward limits) may lead to suspension.',
    ),
    LegalSection(
      'Acceptable Use',
      'Only upload photos you own or have permission to use. Do not upload '
          'or generate unlawful, infringing, or harmful content, and do not '
          'attempt to disrupt or misuse the service.',
    ),
    LegalSection(
      'Your Content',
      'You keep the rights to the photos you upload and the images you '
          'generate. You grant StyliAI permission to process and store them '
          'as needed to provide the service to you.',
    ),
    LegalSection(
      'Service Availability',
      'StyliAI is provided "as is". Features, styles, and pricing may '
          'change, and we do not guarantee uninterrupted availability.',
    ),
    LegalSection(
      'Termination',
      'We may suspend or terminate accounts that violate these terms.',
    ),
    LegalSection(
      'Contact',
      'Questions about these terms? Contact us at support@styliai.app.',
    ),
  ];
}
