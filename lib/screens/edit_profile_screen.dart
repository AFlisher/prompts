import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_sheet.dart';
import '../main.dart';
import '../services/profile_service.dart';

class EditProfileScreen extends StatefulWidget {
  final bool isDarkMode;

  const EditProfileScreen({super.key, required this.isDarkMode});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late bool _isDark;
  File? _profileImage;
  bool _isSaving = false;

  final _nameController = TextEditingController();
  final _bioController = TextEditingController(text: 'AI Style Explorer ✨');

  @override
  void initState() {
    super.initState();
    _isDark = widget.isDarkMode;

    // Prefill name controller from the single source of truth ProfileProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ProfileProvider.of(context).profile;
      if (profile != null) {
        _nameController.text = profile.fullName ?? '';
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    HapticFeedback.selectionClick();
    Navigator.pop(context); // Close bottom sheet
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _profileImage = File(picked.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not pick image: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showImageSourceSheet() {
    HapticFeedback.mediumImpact();
    final textColor = _isDark ? Colors.white : AppTheme.black;

    showAppBottomSheet(
      context,
      isDarkMode: _isDark,
      contentBuilder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Change Profile Photo',
              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ImageSourceTile(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  isDark: _isDark,
                  onTap: () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ImageSourceTile(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  isDark: _isDark,
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ),
            ],
          ),
          if (_profileImage != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                setState(() => _profileImage = null);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              label: const Text('Remove Photo', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      final profileService = ProfileService();
      final profileManager = ProfileProvider.of(context);

      String? newAvatarUrl;
      if (_profileImage != null) {
        // 1. Upload compressed avatar to storage and retrieve updated db profile
        final updatedProfile = await profileService.uploadAvatar(_profileImage!);
        newAvatarUrl = updatedProfile.avatarUrl;
      }

      // 2. Update remaining fields (Full Name) in database
      final finalProfile = await profileService.updateProfile(
        fullName: _nameController.text.trim(),
        avatarUrl: newAvatarUrl,
      );

      // 3. Immediately refresh every screen displaying the avatar (single source of truth)
      profileManager.updateProfile(finalProfile);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.accentPurple,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save profile: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDark ? AppTheme.black : AppTheme.white;
    final textColor = _isDark ? AppTheme.white : AppTheme.black;
    final surfaceColor = _isDark ? AppTheme.darkCard : AppTheme.lightGray;

    final profile = ProfileProvider.of(context).profile;
    final displayName = (profile?.fullName ?? '').trim().isNotEmpty
        ? profile!.fullName!.trim()
        : 'Ahmed';
    final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: textColor),
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          color: textColor, size: 16),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Edit Profile',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: textColor),
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // Profile Photo
              Center(
                child: GestureDetector(
                  onTap: _showImageSourceSheet,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: _profileImage == null && (profile?.avatarUrl == null || profile!.avatarUrl!.trim().isEmpty)
                              ? const LinearGradient(
                                  colors: [AppTheme.accentPurple, AppTheme.accentBlue],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          borderRadius: BorderRadius.circular(30),
                          image: _profileImage != null
                              ? DecorationImage(
                                  image: FileImage(_profileImage!),
                                  fit: BoxFit.cover,
                                )
                              : (profile?.avatarUrl != null && profile!.avatarUrl!.trim().isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(profile.avatarUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null),
                        ),
                        child: _profileImage == null && (profile?.avatarUrl == null || profile!.avatarUrl!.trim().isEmpty)
                            ? Center(
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: -4,
                        right: -4,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.accentPurple, AppTheme.accentPink],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: bgColor, width: 2.5),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Tap to change photo',
                  style: TextStyle(color: AppTheme.mediumGray, fontSize: 12),
                ),
              ),
              const SizedBox(height: 36),

              // Editable Fields
              _buildEditableField(
                label: 'Full Name',
                controller: _nameController,
                icon: Icons.person_outline_rounded,
                surfaceColor: surfaceColor,
                textColor: textColor,
              ),
              const SizedBox(height: 12),
              _buildEditableField(
                label: 'Bio',
                controller: _bioController,
                icon: Icons.edit_note_rounded,
                surfaceColor: surfaceColor,
                textColor: textColor,
                multiline: true,
              ),
              const SizedBox(height: 12),

              // Email — Read-only static label (cannot be changed)
              _buildStaticEmailField(
                surfaceColor: surfaceColor,
                textColor: textColor,
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.accentPurple, AppTheme.accentPink],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentPurple.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required Color surfaceColor,
    required Color textColor,
    bool multiline = false,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.mediumGray,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(icon, color: AppTheme.mediumGray, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: multiline ? 3 : 1,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStaticEmailField({
    required Color surfaceColor,
    required Color textColor,
  }) {
    String displayEmail = 'ahmed@example.com';
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && user.email != null) {
        displayEmail = user.email!;
      }
    } catch (_) {
      // Supabase is not initialized in widget test environment
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isDark ? Colors.white10 : Colors.black12,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Email Address',
                style: TextStyle(
                  color: AppTheme.mediumGray,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Cannot be changed',
                  style: TextStyle(
                    color: AppTheme.accentPurple,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.mail_outline_rounded, color: AppTheme.mediumGray.withValues(alpha: 0.6), size: 18),
              const SizedBox(width: 10),
              Text(
                displayEmail,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.45),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(Icons.lock_outline_rounded, color: AppTheme.mediumGray.withValues(alpha: 0.4), size: 16),
            ],
          ),
        ],
      ),
    );
  }
}

// Bottom sheet image source tile
class _ImageSourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _ImageSourceTile({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightGray,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.accentPurple, AppTheme.accentPink],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.black,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
