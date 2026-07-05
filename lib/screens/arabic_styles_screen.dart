import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/style_data.dart';
import '../models/style_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import 'style_details_screen.dart';
import '../main.dart';
import '../data/dynamic_style_manager.dart';

class ArabicStylesScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleDarkMode;

  const ArabicStylesScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  State<ArabicStylesScreen> createState() => _ArabicStylesScreenState();
}

class _ArabicStylesScreenState extends State<ArabicStylesScreen> {
  late bool _isDark;

  @override
  void initState() {
    super.initState();
    _isDark = widget.isDarkMode;
  }

  void _toggleDark() {
    setState(() => _isDark = !_isDark);
    widget.onToggleDarkMode();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDark ? AppTheme.black : AppTheme.white;
    final textColor = _isDark ? AppTheme.white : AppTheme.black;

    final categories = StyleProvider.of(context).categories;
    final arabicCategory = categories.firstWhere(
      (c) => c.id == 'arabic',
      orElse: () => CategoryModel(id: 'arabic', name: 'Arabic Styles', styles: []),
    );
    final styles = arabicCategory.styles;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(26, 12, 26, 0),
                child: AppHeader(
                  isDarkMode: _isDark,
                  onToggleDarkMode: _toggleDark,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 22, 18),
                child: Row(
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
                    const SizedBox(width: 25),
                    Text(
                      'Arabic Styles',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.menu_rounded, color: textColor, size: 24),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 26),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 9,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final style = styles[index];
                    return _ArabicStyleTile(
                      style: style,
                      isDarkMode: _isDark,
                      onTap: () => _openDetails(context, style),
                    );
                  },
                  childCount: styles.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetails(BuildContext context, StyleModel style) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StyleDetailsScreen(
          style: style,
          isDarkMode: _isDark,
          onToggleDarkMode: _toggleDark,
        ),
      ),
    );
  }
}

class _ArabicStyleTile extends StatefulWidget {
  final StyleModel style;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _ArabicStyleTile({
    required this.style,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  State<_ArabicStyleTile> createState() => _ArabicStyleTileState();
}

class _ArabicStyleTileState extends State<_ArabicStyleTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDarkMode ? AppTheme.white : AppTheme.black;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        scale: _pressed ? 0.96 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  widget.style.imagePath,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: AppTheme.lightGray,
                      child: const Icon(Icons.image_outlined),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.style.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDarkMode;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border:
              Border.all(color: isDarkMode ? AppTheme.white : AppTheme.black),
        ),
        child: Icon(icon,
            color: isDarkMode ? AppTheme.white : AppTheme.black, size: 16),
      ),
    );
  }
}
