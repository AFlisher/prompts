import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SearchBar extends StatefulWidget {
  final ValueChanged<String>? onChanged;

  const SearchBar({super.key, this.onChanged});

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.lightGray,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(
            color: _isFocused
                ? (isDark
                    ? AppTheme.white.withValues(alpha: 0.2)
                    : AppTheme.black.withValues(alpha: 0.15))
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: _isFocused
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: TextField(
          controller: _controller,
          onChanged: (value) {
            widget.onChanged?.call(value);
            setState(() {});
          },
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isDark ? AppTheme.white : AppTheme.black,
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
            suffixIcon: _controller.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _controller.clear();
                      widget.onChanged?.call('');
                      setState(() {});
                    },
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
            suffixIconConstraints: const BoxConstraints(minWidth: 0),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }
}
