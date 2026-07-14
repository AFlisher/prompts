import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/style_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import 'style_details_screen.dart';
import '../main.dart';
import '../widgets/style_card.dart';

class AllStylesScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleDarkMode;
  final String title;
  final List<StyleModel>? styles;

  const AllStylesScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
    this.title = 'All Styles',
    this.styles,
  });

  @override
  State<AllStylesScreen> createState() => _AllStylesScreenState();
}

class _AllStylesScreenState extends State<AllStylesScreen> {
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
    final bgColor = _isDark ? AppTheme.black : AppTheme.lightBackground;
    final textColor = _isDark ? AppTheme.white : AppTheme.black;
    final styles = widget.styles ??
        StyleProvider.of(context)
            .categories
            .expand((c) => c.styles)
            .toList();
    // Matches the SliverGrid below: crossAxisCount 2, 20px padding each
    // side, 12px crossAxisSpacing.
    final cardWidth = (MediaQuery.sizeOf(context).width - 40 - 12) / 2;

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
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            color: _isDark ? AppTheme.white : AppTheme.black,
                            size: 16),
                      ),
                    ),
                    const SizedBox(width: 25),
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.55,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final style = styles[index];
                    final heroTag = 'all_styles_${style.id}';
                    return StyleCard(
                      style: style,
                      isDarkMode: _isDark,
                      onTap: () => _openDetails(context, style, heroTag),
                      cardWidth: cardWidth,
                      heroTag: heroTag,
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

  void _openDetails(BuildContext context, StyleModel style, String heroTag) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StyleDetailsScreen(
          style: style,
          isDarkMode: _isDark,
          onToggleDarkMode: _toggleDark,
          heroTag: heroTag,
        ),
      ),
    );
  }
}

