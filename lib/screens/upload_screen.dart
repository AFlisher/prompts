import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/style_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../main.dart';
import '../data/creations_manager.dart';
import '../utils/gallery_saver.dart';
import '../widgets/success_hud.dart';
import 'image_preview_screen.dart';
import 'paywall_screen.dart';
import '../utils/image_helper.dart';
import '../data/credit_manager.dart';
import '../services/api_service.dart';
import '../widgets/watch_ad_button.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/dynamic_style_form.dart';
import '../widgets/status_bar_style.dart';

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

/// The requirement line shown under "Crop & adjust" for multi-image styles:
/// tells the user exactly how many photos to upload and tracks progress.
/// Never shown for classic 1/1 styles (the UI is self-explanatory there).
String imageRequirementLabel({
  required int minImages,
  required int maxImages,
  required int selectedCount,
}) {
  final String requirement;
  if (minImages == maxImages) {
    requirement = 'Upload $minImages photos';
  } else if (minImages <= 1) {
    requirement = 'Upload up to $maxImages photos';
  } else {
    requirement = 'Upload at least $minImages photos (up to $maxImages)';
  }
  return '$requirement · $selectedCount of $maxImages added';
}

/// How many image cards the upload screen shows for a style: always at least
/// [minImages] so required slots are visible up front, plus one empty "add"
/// slot while the user is under [maxImages]. A 1/1 style therefore renders
/// exactly one card - the pre-multi-image behavior.
int visibleImageSlots({
  required int minImages,
  required int maxImages,
  required int selectedCount,
}) {
  final base = selectedCount + 1 > minImages ? selectedCount + 1 : minImages;
  final capped = base > maxImages ? maxImages : base;
  return capped < 1 ? 1 : capped;
}

class _UploadScreenState extends State<UploadScreen> {
  late bool _isDark;
  final List<String> _selectedImagePaths = [];
  bool _isGenerating = false;
  double _generationProgress = 0.0;
  String _generationStatus = 'Uploading photo...';
  bool _generationComplete = false;
  Timer? _generationTimer;
  bool _isCheckingBalance = false;

  // Dynamic prompt-template inputs for this style (empty for classic styles).
  final GlobalKey<FormState> _fieldsFormKey = GlobalKey<FormState>();
  Map<String, dynamic> _fieldValues = {};
  bool _fieldsValid = true;

  @override
  void initState() {
    super.initState();
    _isDark = widget.isDarkMode;
  }

  void _toggleDark() {
    setState(() => _isDark = !_isDark);
    widget.onToggleDarkMode?.call();
  }

  int get _minImages => widget.style.minImages;
  int get _maxImages => widget.style.maxImages;

  void _startGeneration() async {
    if (_selectedImagePaths.length < _minImages) return;

    // Gate on the dynamic form: surface validation messages and stop if any
    // required/typed field is invalid, so we never call the paid endpoint
    // (which would reject it server-side anyway) with bad input.
    if (widget.style.fields.isNotEmpty) {
      final formOk = _fieldsFormKey.currentState?.validate() ?? true;
      if (!formOk || !_fieldsValid) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please complete the required fields before generating.')),
        );
        return;
      }
    }

    final creditManager = CreditProvider.of(context);
    
    setState(() {
      _isCheckingBalance = true;
    });

    try {
      // 1. Fetch current wallet balance from backend
      await creditManager.fetchWallet();
    } catch (e) {
      debugPrint("Error checking wallet balance: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingBalance = false;
        });
      }
    }

    if (!mounted) return;

    // 2. If balance >= style cost, proceed to actual generation
    if (creditManager.balance >= widget.style.creditCost) {
      _startGenerationActual(creditManager);
    } else {
      // 3. Otherwise, prompt Not Enough Credits bottom sheet
      _showNotEnoughCreditsSheet(context, creditManager, widget.style.creditCost);
    }
  }

  void _startGenerationActual(CreditManager creditManager) async {
    final apiService = ApiService();

    HapticFeedback.mediumImpact();
    setState(() {
      _isGenerating = true;
      _generationProgress = 0.0;
      _generationStatus = 'Uploading photo...';
    });

    // Start local progress bar simulation for smooth UI rendering
    _generationTimer?.cancel();
    _generationTimer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
      if (!mounted || !_isGenerating) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_generationProgress < 0.9) {
          _generationProgress += 0.02;
        }
        if (_generationProgress >= 0.25 && _generationProgress < 0.5) {
          _generationStatus = 'Analyzing facial features...';
        } else if (_generationProgress >= 0.5 && _generationProgress < 0.75) {
          _generationStatus =
              'Applying ${widget.style.name.replaceAll(' Style', '')} style layers...';
        } else if (_generationProgress >= 0.75 && _generationProgress < 0.9) {
          _generationStatus = 'Refining shadows and details...';
        }
      });
    });

    try {
      // 4. Trigger backend generation pipeline which validates and deducts balance
      final generatedImageUrl = await apiService.generateStyleImage(
        List<String>.from(_selectedImagePaths),
        widget.style.id,
        fieldValues: _fieldValues,
      );

      // Cancel local animation timer and sync wallet stats from server
      _generationTimer?.cancel();
      await creditManager.fetchWallet();

      if (mounted) {
        setState(() {
          _generationProgress = 1.0;
          _isGenerating = false;
          _generationComplete = true;
          _generationStatus = 'Success';
        });
        HapticFeedback.heavyImpact();

        // Add to creations
        final creationsManager = CreationsProvider.of(context);
        creationsManager.addCreation(
          CreationItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            styleId: widget.style.id,
            styleName: widget.style.name,
            imagePath: generatedImageUrl,
            originalImagePath:
                _selectedImagePaths.isNotEmpty ? _selectedImagePaths.first : null,
            createdAt: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      debugPrint("[Generation] API Error: $e");
      _generationTimer?.cancel();
      
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });

        if (e is ApiException) {
          if (e.code == 'INSUFFICIENT_BALANCE') {
            _showNotEnoughCreditsSheet(context, creditManager, widget.style.creditCost);
          } else if (e.code == 'PROVIDER_UNAVAILABLE') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Image generation is temporarily unavailable.\nPlease try again later.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Generation failed: ${e.message}'),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              ),
            );
          }
        } else {
          // Fallback for non-ApiException errors (e.g. network failures) that
          // carry no structured code.
          final errorMsg = e.toString();
          final errorMsgLower = errorMsg.toLowerCase();
          if (errorMsgLower.contains('insufficient balance') || errorMsgLower.contains('credits')) {
            _showNotEnoughCreditsSheet(context, creditManager, widget.style.creditCost);
          } else if (errorMsgLower.contains('temporarily unavailable')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Image generation is temporarily unavailable.\nPlease try again later.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Generation failed: ${errorMsg.replaceAll('Exception: ', '')}'),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              ),
            );
          }
        }
      }
    }
  }

  void _showNotEnoughCreditsSheet(BuildContext context, CreditManager creditManager, int requiredCredits) {
    showAppBottomSheet(
      context,
      isDarkMode: _isDark,
      isScrollControlled: true,
      contentBuilder: (context) {
        return _NotEnoughCreditsSheet(
          isDarkMode: _isDark,
          creditManager: creditManager,
          requiredCredits: requiredCredits,
          onBuyCreditsTap: () {
            Navigator.pop(context); // Close the bottom sheet
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PaywallScreen(isDarkMode: _isDark),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _generationTimer?.cancel();
    super.dispose();
  }

  void _saveToGallery() async {
    HapticFeedback.mediumImpact();

    final savedPath = await GallerySaver.saveImage(
      assetPath: widget.style.imagePath,
    );

    if (!mounted) return;

    if (savedPath != null) {
      HapticFeedback.vibrate();
      SuccessHUD.show(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save image. Check storage permissions.'),
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
        body: Stack(
          children: [
            if (!_generationComplete)
              SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppHeader(
                        isDarkMode: _isDark,
                        onToggleDarkMode: _toggleDark,
                      ),
                      const SizedBox(height: 16),
                      _PageTitleRow(
                        textColor: textColor,
                        onBack: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(height: 16),
                      _PhotoActionCard(
                        isDark: _isDark,
                        icon: Icons.camera_alt_outlined,
                        title: 'Take a photo',
                        subtitle: 'click here to use your camera to take pic',
                        onTap: () => _showCameraPicker(),
                      ),
                      const SizedBox(height: 16),
                      _PhotoActionCard(
                        isDark: _isDark,
                        icon: Icons.image_outlined,
                        title: 'Upload photo',
                        subtitle: 'click here to upload pic from your gallery',
                        onTap: () => _showGalleryPicker(),
                      ),
                      const SizedBox(height: 24),
                      _SectionTitle(text: 'Crop & adjust', color: textColor),
                      if (_maxImages > 1) ...[
                        const SizedBox(height: 6),
                        Text(
                          imageRequirementLabel(
                            minImages: _minImages,
                            maxImages: _maxImages,
                            selectedCount: _selectedImagePaths.length,
                          ),
                          style: const TextStyle(
                            color: AppTheme.mediumGray,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // One tile per slot: filled tiles preview their image
                      // (tap to replace, X to remove); empty tiles invite the
                      // next photo. Single-image styles keep one full-width
                      // card; multi-image styles lay square tiles out two per
                      // row so the slots read as a set, not stacked boxes.
                      LayoutBuilder(builder: (context, constraints) {
                        final slots = visibleImageSlots(
                          minImages: _minImages,
                          maxImages: _maxImages,
                          selectedCount: _selectedImagePaths.length,
                        );
                        final multi = _maxImages > 1;
                        final tileWidth = multi
                            ? (constraints.maxWidth - 14) / 2
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            for (int slot = 0; slot < slots; slot++)
                              SizedBox(
                                width: tileWidth,
                                child: GestureDetector(
                                  onTap: () => _showGalleryPicker(slot: slot),
                                  child: _CropPreview(
                                    isDark: _isDark,
                                    compact: multi,
                                    label: multi ? 'Photo ${slot + 1}' : null,
                                    imagePath: slot < _selectedImagePaths.length
                                        ? _selectedImagePaths[slot]
                                        : null,
                                    onClear: slot < _selectedImagePaths.length
                                        ? () {
                                            HapticFeedback.lightImpact();
                                            setState(() => _selectedImagePaths
                                                .removeAt(slot));
                                          }
                                        : null,
                                  ),
                                ),
                              ),
                          ],
                        );
                      }),
                      if (widget.style.fields.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _SectionTitle(text: 'Customize', color: textColor),
                        const SizedBox(height: 16),
                        DynamicStyleForm(
                          fields: widget.style.fields,
                          formKey: _fieldsFormKey,
                          isDarkMode: _isDark,
                          onChanged: (values, isValid) {
                            _fieldValues = values;
                            if (isValid != _fieldsValid && mounted) {
                              setState(() => _fieldsValid = isValid);
                            } else {
                              _fieldsValid = isValid;
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            if (_generationComplete)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ImagePreviewScreen(
                                assetPath: widget.style.imagePath,
                                title: widget.style.name,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          height: 380,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                            boxShadow: AppTheme.heavyShadow,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                buildStyleImage(
                                  widget.style.displayImage,
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  bottom: 16,
                                  right: 16,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                                        SizedBox(width: 4),
                                        Text(
                                          'Tap to zoom',
                                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
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
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _saveToGallery,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          ),
                          minimumSize: const Size(double.infinity, 0),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.download_rounded),
                            SizedBox(width: 8),
                            Text('Save to Gallery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _generationComplete = false;
                                  _selectedImagePaths.clear();
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: textColor,
                                side: BorderSide(
                                  color: _isDark ? Colors.white24 : Colors.black12,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 18),
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
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                CreationsProvider.of(context).setTab(1); // Set active tab to creations
                                Navigator.popUntil(context, (route) => route.isFirst);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _isDark ? AppTheme.white : AppTheme.black,
                                foregroundColor:
                                    _isDark ? AppTheme.black : AppTheme.white,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusMedium),
                                ),
                              ),
                              child: const Text(
                                'View Creations',
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
                left: 24,
                right: 24,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _GenerateStyleButton(
                      enabled: _selectedImagePaths.length >= _minImages,
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
                                color: AppTheme.accentPink,
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
            if (_isCheckingBalance)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.75),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.accentPurple),
                        SizedBox(height: 16),
                        Text(
                          'Checking balance...',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Stores a picked image. A tapped card passes its [slot] (replace);
  /// the top action buttons pass none, filling the next free slot - or, when
  /// the style is full, replacing the last image (which for a classic 1/1
  /// style is exactly the old "picking again replaces the photo" behavior).
  void _setPickedImage(String path, {int? slot}) {
    setState(() {
      if (slot != null && slot < _selectedImagePaths.length) {
        _selectedImagePaths[slot] = path;
      } else if (_selectedImagePaths.length < _maxImages) {
        _selectedImagePaths.add(path);
      } else {
        _selectedImagePaths[_selectedImagePaths.length - 1] = path;
      }
    });
  }

  Future<void> _showCameraPicker({int? slot}) async {
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(source: ImageSource.camera);
      if (xFile != null) {
        HapticFeedback.lightImpact();
        _setPickedImage(xFile.path, slot: slot);
      }
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied') {
        _showPermissionDeniedSnackBar(
          'Camera access denied',
          'Please enable camera permission in your device Settings to take photos.',
        );
      } else {
        _showPermissionDeniedSnackBar(
          'Camera error',
          'Could not open the camera. Please try again.',
        );
      }
    }
  }

  Future<void> _showGalleryPicker({int? slot}) async {
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(source: ImageSource.gallery);
      if (xFile != null) {
        HapticFeedback.lightImpact();
        _setPickedImage(xFile.path, slot: slot);
      }
    } on PlatformException catch (e) {
      if (e.code == 'photo_access_denied') {
        _showPermissionDeniedSnackBar(
          'Gallery access denied',
          'Please enable photo library permission in your device Settings to upload photos.',
        );
      } else {
        _showPermissionDeniedSnackBar(
          'Gallery error',
          'Could not open the gallery. Please try again.',
        );
      }
    }
  }

  void _showPermissionDeniedSnackBar(String title, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: AppTheme.darkSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        duration: const Duration(seconds: 4),
      ),
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
            child: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 16),
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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

/// Rounded-rect dashed outline for the empty photo tiles - reads as an
/// inviting drop-target rather than a hard empty box.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    const dash = 7.0;
    const gap = 5.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0.8, 0.8, size.width - 1.6, size.height - 1.6),
        Radius.circular(radius),
      ));

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _CropPreview extends StatelessWidget {
  final bool isDark;
  final String? imagePath;
  final VoidCallback? onClear;

  /// Compact mode: the square half-width tile used by multi-image styles.
  final bool compact;

  /// Small chip naming the slot ("Photo 1") - multi-image styles only.
  final String? label;

  const _CropPreview({
    required this.isDark,
    required this.imagePath,
    this.onClear,
    this.compact = false,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final radius = AppTheme.radiusLarge;
    final emptyFill = isDark
        ? AppTheme.darkCard
        : AppTheme.accentPurple.withValues(alpha: 0.045);
    final dashColor = isDark
        ? Colors.white.withValues(alpha: 0.30)
        : AppTheme.accentPurple.withValues(alpha: 0.45);

    Widget labelChip() => Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );

    if (imagePath == null) {
      return Container(
        height: compact ? 180 : 280,
        width: double.infinity,
        decoration: BoxDecoration(
          color: emptyFill,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: CustomPaint(
          painter: _DashedBorderPainter(color: dashColor, radius: radius),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: compact ? 52 : 68,
                      height: compact ? 52 : 68,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppTheme.accentPurple, AppTheme.accentPink],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_photo_alternate_rounded,
                        color: Colors.white,
                        size: compact ? 26 : 32,
                      ),
                    ),
                    SizedBox(height: compact ? 10 : 14),
                    Text(
                      compact ? 'Add photo' : 'Add your photo',
                      style: TextStyle(
                        color: isDark ? Colors.white : AppTheme.black,
                        fontSize: compact ? 13.5 : 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Tap to choose from your gallery',
                        style: TextStyle(
                          color: AppTheme.mediumGray,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (label != null) labelChip(),
            ],
          ),
        ),
      );
    }

    return Container(
      height: compact ? 180 : 280,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: _buildFilled(labelChip),
      ),
    );
  }

  Widget _buildFilled(Widget Function() labelChip) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(File(imagePath!), fit: BoxFit.cover),
        if (label != null) labelChip(),
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
                const SizedBox(width: 24),
                const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
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
                const SizedBox(width: 52 ),
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

class _NotEnoughCreditsSheet extends StatelessWidget {
  final bool isDarkMode;
  final CreditManager creditManager;
  final VoidCallback onBuyCreditsTap;
  final int requiredCredits;

  const _NotEnoughCreditsSheet({
    required this.isDarkMode,
    required this.creditManager,
    required this.onBuyCreditsTap,
    this.requiredCredits = 1,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? AppTheme.white : AppTheme.black;
    final secondaryTextColor = AppTheme.mediumGray;

    return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Star icon badge
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accentPurple.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.stars_rounded,
                color: AppTheme.accentPurple,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Not Enough Credits',
              style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),

            // Description
            Text(
              'You need $requiredCredits ${requiredCredits == 1 ? 'credit' : 'credits'} to generate this image.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: secondaryTextColor,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onBuyCreditsTap,
                icon: const Icon(Icons.credit_card_rounded, color: Colors.white, size: 20),
                label: const Text(
                  'Buy Credits',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            AnimatedBuilder(
              animation: creditManager,
              builder: (context, _) {
                if (creditManager.dailyLimitReached) return const SizedBox.shrink();

                return Column(
                  children: [
                    WatchAdButton(
                      creditManager: creditManager,
                      onRewarded: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),

            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: secondaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
  }
}

