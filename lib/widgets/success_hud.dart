import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reserved for one specific kind of moment: a big, singular "your file is
/// now on your device" confirmation after saving a generated image to the
/// gallery (currently: Upload, Creations, and Image Preview's save actions).
/// Every other confirmation or error in the app - form saves, toggles,
/// share links, permission failures - uses a [SnackBar] instead, since
/// those are secondary acknowledgements that shouldn't interrupt the
/// screen the way this full-screen HUD does.
class SuccessHUD {
  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (ctx) {
        // Auto dismiss after 1300 milliseconds
        Future.delayed(const Duration(milliseconds: 1300), () {
          if (ctx.mounted) {
            Navigator.of(ctx).pop();
          }
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  )
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: Colors.greenAccent,
                    size: 48,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Saved successfully!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
