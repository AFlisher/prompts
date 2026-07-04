import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/style_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

class UploadScreen extends StatefulWidget {
  final StyleModel style;
  final bool isDarkMode;
  final VoidCallback? onToggleDarkMode;

  const UploadScreen({
    super.key,
    required this.style,
    required this.isDarkMode,
    this.onToggleDarkMode,
  });

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  late bool _isDark;
  String? _selectedImagePath;
  bool _isGenerating = false;
  double _generationProgress = 0.0;
  String _generationStatus = 'Uploading photo...';
  bool _generationComplete = false;
  Timer? _generationTimer;

  @override
  void initState() {
    super.initState();
    _isDark = widget.isDarkMode;
  }

  void _toggleDark() {
    setState(() => _isDark = !_isDark);
    widget.onToggleDarkMode?.call();
  }

  final List<String> _mockGallery = [
    'assets/images/style_stussy.jpg',
    'assets/images/style_90s.jpg',
    'assets/images/style_toon.jpg',
    'assets/images/style_ps2.jpg',
    'assets/images/style_uzi.jpg',
    'assets/images/style_arabic.jpg',
  ];

  void _selectMockImage(String path) {
    HapticFeedback.lightImpact();
    setState(() => _selectedImagePath = path);
  }

  void _startGeneration() {
    if (_selectedImagePath == null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isGenerating = true;
      _generationProgress = 0.0;
      _generationStatus = 'Uploading photo...';
    });

    _generationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _generationProgress += 0.025;
        if (_generationProgress >= 0.25 && _generationProgress < 0.5) {
          _generationStatus = 'Analyzing facial features...';
        } else if (_generationProgress >= 0.5 && _generationProgress < 0.75) {
          _generationStatus =
              'Applying ${widget.style.name.replaceAll(' Style', '')} style layers...';
        } else if (_generationProgress >= 0.75 && _generationProgress < 0.95) {
          _generationStatus = 'Refining shadows and details...';
        } else if (_generationProgress >= 1.0) {
          _generationProgress = 1.0;
          _isGenerating = false;
          _generationComplete = true;
          timer.cancel();
          HapticFeedback.heavyImpact();
        }
      });
    });
  }

  @override
  void dispose() {
    _generationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDark ? AppTheme.black : AppTheme.white;
    final textColor = _isDark ? AppTheme.white : AppTheme.black;
    final surfaceColor = _isDark ? AppTheme.darkCard : AppTheme.lightGray;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          if (!_generationComplete)
            SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(26, 12, 26, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppHeader(
                      isDarkMode: _isDark,
                      onToggleDarkMode: _toggleDark,
                    ),
                    const SizedBox(height: 18),
                    _PageTitleRow(
                      textColor: textColor,
                      onBack: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 18),
                    _PhotoActionCard(
                      isDark: _isDark,
                      icon: Icons.camera_alt_outlined,
                      title: 'Take a photo',
                      subtitle: 'click here to use your camera to take pic',
                      onTap: _showCameraPicker,
                    ),
                    const SizedBox(height: 14),
                    _PhotoActionCard(
                      isDark: _isDark,
                      icon: Icons.image_outlined,
                      title: 'Upload photo',
                      subtitle: 'click here to upload pic from your gallery',
                      onTap: _showGalleryPicker,
                    ),
                    const SizedBox(height: 22),
                    _SectionTitle(text: 'Crop & adjust', color: textColor),
                    const SizedBox(height: 12),
                    _CropPreview(
                      isDark: _isDark,
                      imagePath: _selectedImagePath,
                      onClear: _selectedImagePath != null
                          ? () {
                              HapticFeedback.lightImpact();
                              setState(() => _selectedImagePath = null);
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ),

          if (_generationComplete)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 380,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        boxShadow: AppTheme.heavyShadow,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        child: Image.asset(
                          widget.style.imagePath,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Generation Complete!',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Successfully applied ${widget.style.name} to your photo.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 36),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _generationComplete = false;
                                _selectedImagePath = null;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textColor,
                              side: BorderSide(
                                color: _isDark ? Colors.white24 : Colors.black12,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusMedium),
                              ),
                            ),
                            child: const Text(
                              'Create Another',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              Navigator.popUntil(context, (route) => route.isFirst);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _isDark ? AppTheme.white : AppTheme.black,
                              foregroundColor:
                                  _isDark ? AppTheme.black : AppTheme.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusMedium),
                              ),
                            ),
                            child: const Text(
                              'Go to Home',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          if (!_generationComplete && !_isGenerating)
            Positioned(
              left: 26,
              right: 26,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _GenerateStyleButton(
                    enabled: _selectedImagePath != null,
                    isDark: _isDark,
                    onTap: _startGeneration,
                  ),
                ),
              ),
            ),

          if (_isGenerating)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.85),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: Stack(
                        children: [
                          Center(
                            child: CircularProgressIndicator(
                              value: _generationProgress,
                              color: const Color(0xFFEC4899),
                              strokeWidth: 4,
                            ),
                          ),
                          const Center(
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Generating... ${(_generationProgress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _generationStatus,
                      style: const TextStyle(
                        color: AppTheme.mediumGray,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showGalleryPicker() => _showMockSheet('Select Photo from Gallery');

  void _showCameraPicker() => _showMockSheet('Take Photo with Camera');

  void _showMockSheet(String title) {
    final bgColor = _isDark ? AppTheme.darkCard : AppTheme.white;
    final textColor = _isDark ? AppTheme.white : AppTheme.black;

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: textColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select one of the local mock assets to simulate picking an image:',
                  style: TextStyle(color: AppTheme.mediumGray, fontSize: 13),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _mockGallery.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          _selectMockImage(_mockGallery[index]);
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              _mockGallery[index],
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PageTitleRow extends StatelessWidget {
  final Color textColor;
  final VoidCallback onBack;

  const _PageTitleRow({
    required this.textColor,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: textColor, width: 1.5),
            ),
            child: Icon(Icons.arrow_back, color: textColor, size: 16),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Choose photo',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w900,
                shadows: _MetallicStyles.textShadow,
              ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final Color color;

  const _SectionTitle({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
            shadows: _MetallicStyles.textShadow,
          ),
    );
  }
}

class _PhotoActionCard extends StatefulWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PhotoActionCard({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_PhotoActionCard> createState() => _PhotoActionCardState();
}

class _PhotoActionCardState extends State<_PhotoActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? AppTheme.white : AppTheme.black;
    final subtitleColor =
        widget.isDark ? Colors.grey[400]! : const Color(0xFF4A4A4A);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          decoration: _MetallicStyles.cardDecoration(isDark: widget.isDark),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? AppTheme.darkSurface
                      : const Color(0xFFF8F8F8),
                  border: Border.all(color: textColor, width: 1.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(widget.icon, color: textColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w900,
                            shadows: _MetallicStyles.textShadow,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: subtitleColor,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CropPreview extends StatelessWidget {
  final bool isDark;
  final String? imagePath;
  final VoidCallback? onClear;

  const _CropPreview({
    required this.isDark,
    required this.imagePath,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppTheme.white : AppTheme.black;
    final emptyFill = isDark ? const Color(0xFF3A3A3A) : const Color(0xFF9E9E9E);
    final placeholderColor =
        isDark ? Colors.grey[500]! : const Color(0xFFEEEEEE);

    return Container(
      height: 280,
      width: double.infinity,
      decoration: BoxDecoration(
        color: imagePath == null ? emptyFill : null,
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 6,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      child: imagePath == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: placeholderColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.image_outlined,
                    color: isDark ? Colors.grey[700] : const Color(0xFFBDBDBD),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'No photo added yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isDark ? Colors.grey[400] : const Color(0xFF757575),
                        fontWeight: FontWeight.w800,
                        shadows: _MetallicStyles.textShadow,
                      ),
                ),
              ],
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(imagePath!, fit: BoxFit.cover),
                if (onClear != null)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: onClear,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _GenerateStyleButton extends StatefulWidget {
  final bool enabled;
  final bool isDark;
  final VoidCallback onTap;

  const _GenerateStyleButton({
    required this.enabled,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_GenerateStyleButton> createState() => _GenerateStyleButtonState();
}

class _GenerateStyleButtonState extends State<_GenerateStyleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        opacity: widget.enabled ? 1 : 0.45,
        duration: const Duration(milliseconds: 200),
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1,
          duration: const Duration(milliseconds: 100),
          child: Container(
            height: 58,
            decoration: _MetallicStyles.buttonDecoration(isDark: widget.isDark),
            child: Row(
              children: [
                const SizedBox(width: 26),
                const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
                Expanded(
                  child: Text(
                    'Generate Style',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          shadows: _MetallicStyles.textShadow,
                        ),
                  ),
                ),
                const SizedBox(width: 52),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetallicStyles {
  static const textShadow = [
    Shadow(
      color: Color(0x66000000),
      blurRadius: 3,
      offset: Offset(1, 1),
    ),
  ];

  static BoxDecoration cardDecoration({required bool isDark}) {
    if (isDark) {
      return BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4A4A4A),
            Color(0xFF2E2E2E),
            Color(0xFF525252),
            Color(0xFF383838),
          ],
          stops: [0.0, 0.35, 0.65, 1.0],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.white, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 6,
            offset: const Offset(2, 3),
          ),
        ],
      );
    }

    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFF0F0F0),
          Color(0xFFD4D4D4),
          Color(0xFFFAFAFA),
          Color(0xFFC8C8C8),
        ],
        stops: [0.0, 0.35, 0.65, 1.0],
      ),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: AppTheme.black, width: 1.2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.32),
          blurRadius: 6,
          offset: const Offset(2, 3),
        ),
      ],
    );
  }

  static BoxDecoration buttonDecoration({required bool isDark}) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [
                Color(0xFF5A5A5A),
                Color(0xFF1A1A1A),
                Color(0xFF6E6E6E),
                Color(0xFF303030),
              ]
            : const [
                Color(0xFFECECEC),
                Color(0xFF8A8A8A),
                Color(0xFFF5F5F5),
                Color(0xFF707070),
              ],
        stops: const [0.0, 0.3, 0.55, 1.0],
      ),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(
        color: isDark ? Colors.white54 : AppTheme.black,
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.38),
          blurRadius: 8,
          offset: const Offset(2, 4),
        ),
      ],
    );
  }
}
