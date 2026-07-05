import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  final bool isDarkMode;

  const EditProfileScreen({super.key, required this.isDarkMode});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late bool _isDark;

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
                    'Edit Profile',
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
              // Avatar
              Center(
                child: GestureDetector(
                  onTap: () => HapticFeedback.selectionClick(),
                  child: Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.accentPurple,
                              Color(0xFF3B82F6),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: const Center(
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
                      Positioned(
                        bottom: 0,
                        right: -2,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppTheme.accentPurple,
                            shape: BoxShape.circle,
                            border: Border.all(color: bgColor, width: 2.5),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Name
              _buildField(
                label: 'Name',
                value: 'Ahmed',
                surfaceColor: surfaceColor,
                textColor: textColor,
              ),
              const SizedBox(height: 10),
              _buildField(
                label: 'Username',
                value: '@ahmed',
                surfaceColor: surfaceColor,
                textColor: textColor,
              ),
              const SizedBox(height: 10),
              _buildField(
                label: 'Email',
                value: 'ahmed@example.com',
                surfaceColor: surfaceColor,
                textColor: textColor,
              ),
              const SizedBox(height: 10),
              _buildField(
                label: 'Bio',
                value: 'Pro Member · AI Style Explorer',
                surfaceColor: surfaceColor,
                textColor: textColor,
                multiline: true,
              ),
              const SizedBox(height: 28),
              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String value,
    required Color surfaceColor,
    required Color textColor,
    bool multiline = false,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.mediumGray,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            maxLines: multiline ? 3 : 1,
            decoration: InputDecoration(
              hintText: value,
              hintStyle: TextStyle(
                color: textColor.withValues(alpha: 0.6),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
