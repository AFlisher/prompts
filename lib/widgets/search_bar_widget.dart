import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

const Duration _kThemeTransitionDuration = Duration(milliseconds: 280);
const Curve _kThemeTransitionCurve = Curves.easeInOutCubic;

class SearchBar extends StatefulWidget {
  final bool isDark;
  final ValueChanged<String>? onChanged;

  const SearchBar({super.key, required this.isDark, this.onChanged});

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  final TextEditingController _controller = TextEditingController();
  bool _isFocused = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Clears the field, immediately drops the active search filter (Home
  /// treats an empty query as "no filter" - see _filterStyles), and returns
  /// Home to its default sections. Deliberately doesn't touch focus: tapping
  /// this button lives inside the TextField's own suffixIcon, so Flutter
  /// never unfocuses the field for it - the keyboard stays up if the user
  /// keeps typing right after.
  void _clearSearch() {
    _controller.clear();
    widget.onChanged?.call('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    // Light Mode: a dark bar (matching the top capsule's own always-dark
    // look) floating on the cream page. Dark Mode: instead of a dark
    // surface blending into the dark page, this deliberately inverts to the
    // Light Theme's own cream/off-white background (never pure white) - the
    // same color the whole app already uses as its light-mode page
    // background, just reused here. Every foreground piece below inverts
    // the same way, so the bar always reads correctly against its own
    // background regardless of theme.
    final surfaceColor = isDark ? AppTheme.lightBackground : AppTheme.black;
    final fg = isDark ? AppTheme.black : Colors.white;
    final focusedBorderColor =
        isDark ? AppTheme.black.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.2);

    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: AnimatedContainer(
        duration: _kThemeTransitionDuration,
        curve: _kThemeTransitionCurve,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(
            color: _isFocused ? focusedBorderColor : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: _isFocused ? AppTheme.themeAwareShadow(isDark) : [],
        ),
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: fg),
          duration: _kThemeTransitionDuration,
          curve: _kThemeTransitionCurve,
          builder: (context, textColor, _) => TextField(
            controller: _controller,
            onChanged: (value) {
              widget.onChanged?.call(value);
              setState(() {});
            },
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
            decoration: InputDecoration(
              hintText: 'Search aesthetics, vibes, eras...',
              hintStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: AppTheme.mediumGray,
              ),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 16, right: 10),
                child: Icon(
                  Icons.search_rounded,
                  color: AppTheme.mediumGray,
                  size: 22,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0),
              suffixIcon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: _controller.text.isNotEmpty
                    ? GestureDetector(
                        key: const ValueKey('clear-search-button'),
                        onTap: _clearSearch,
                        child: const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: Icon(
                            Icons.close_rounded,
                            color: AppTheme.mediumGray,
                            size: 18,
                          ),
                        ),
                      )
                    : null,
              ),
              suffixIconConstraints: const BoxConstraints(minWidth: 0),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
