import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/haptic_service.dart';
import 'app_bottom_sheet.dart';
import 'star_rating_input.dart';

/// Result of the post-generation feedback sheet. [submitted] is true only
/// when the user pressed Submit with a rating selected - [rating]/[comment]
/// are only meaningful then. [dontAskAgain] reflects the checkbox state
/// regardless of Submit vs Skip, since it's an independent preference.
class GenerationFeedbackSheetResult {
  final bool submitted;
  final int? rating;
  final String? comment;
  final bool dontAskAgain;

  const GenerationFeedbackSheetResult({
    required this.submitted,
    this.rating,
    this.comment,
    required this.dontAskAgain,
  });
}

/// Shows the post-generation feedback bottom sheet. Returns null if
/// dismissed via back gesture/tap-outside (callers should treat that the
/// same as Skip, with no preference change) - otherwise a
/// [GenerationFeedbackSheetResult] from either the Submit or Skip button.
Future<GenerationFeedbackSheetResult?> showGenerationFeedbackSheet(
  BuildContext context, {
  required bool isDarkMode,
}) {
  return showAppBottomSheet<GenerationFeedbackSheetResult>(
    context,
    isDarkMode: isDarkMode,
    isScrollControlled: true,
    contentBuilder: (ctx) => _GenerationFeedbackSheetContent(isDarkMode: isDarkMode),
  );
}

class _GenerationFeedbackSheetContent extends StatefulWidget {
  final bool isDarkMode;

  const _GenerationFeedbackSheetContent({required this.isDarkMode});

  @override
  State<_GenerationFeedbackSheetContent> createState() => _GenerationFeedbackSheetContentState();
}

class _GenerationFeedbackSheetContentState extends State<_GenerationFeedbackSheetContent> {
  int _rating = 0;
  bool _dontAskAgain = false;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _toggleDontAskAgain(bool? value) {
    HapticService.selection();
    setState(() => _dontAskAgain = value ?? false);
  }

  void _skip() {
    HapticService.light();
    Navigator.pop(
      context,
      GenerationFeedbackSheetResult(submitted: false, dontAskAgain: _dontAskAgain),
    );
  }

  void _submit() {
    if (_rating == 0) return;
    HapticService.medium();
    final comment = _commentController.text.trim();
    Navigator.pop(
      context,
      GenerationFeedbackSheetResult(
        submitted: true,
        rating: _rating,
        comment: comment.isEmpty ? null : comment,
        dontAskAgain: _dontAskAgain,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDarkMode ? AppTheme.white : AppTheme.black;
    final fieldBg = widget.isDarkMode ? AppTheme.black : AppTheme.lightGray;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🎉 How do you like this result?',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: StarRatingInput(
            value: _rating,
            onChanged: (value) => setState(() => _rating = value),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _commentController,
          maxLines: 3,
          style: TextStyle(fontSize: 14, color: textColor),
          decoration: InputDecoration(
            hintText: 'Add a comment (optional)',
            hintStyle: const TextStyle(fontSize: 14, color: AppTheme.mediumGray),
            filled: true,
            fillColor: fieldBg,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _toggleDontAskAgain(!_dontAskAgain),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Checkbox(
                value: _dontAskAgain,
                onChanged: _toggleDontAskAgain,
                activeColor: AppTheme.accentPurple,
              ),
              Expanded(
                child: Text(
                  "Don't ask me again",
                  style: TextStyle(fontSize: 13, color: textColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _skip,
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor,
                  side: BorderSide(
                    color: widget.isDarkMode ? Colors.white24 : Colors.black12,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                ),
                child: const Text('Skip', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _rating > 0 ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentPurple,
                  disabledBackgroundColor: AppTheme.accentPurple.withValues(alpha: 0.4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  elevation: 0,
                ),
                child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
