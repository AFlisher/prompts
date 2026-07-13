import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/style_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import 'style_details_screen.dart';
import '../main.dart';
import '../data/dynamic_style_manager.dart';
import '../widgets/style_card.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        StyleProvider.read(context).loadStylesForCategory('arabic');
      }
    });
  }

  void _toggleDark() {
    setState(() => _isDark = !_isDark);
    widget.onToggleDarkMode();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDark ? AppTheme.black : AppTheme.lightBackground;
    final textColor = _isDark ? AppTheme.white : AppTheme.black;

    final styleManager = StyleProvider.of(context);
    final categories = styleManager.categories;
    final arabicCategory = categories.firstWhere(
      (c) => c.id == 'arabic',
      orElse: () => CategoryModel(id: 'arabic', name: 'Arabic Styles', styles: []),
    );
    final styles = arabicCategory.styles;
    final isCategoryLoading = styleManager.isCategoryLoading('arabic');

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
                      'Arabic Styles',
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
            if (isCategoryLoading && styles.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.accentPurple),
                ),
              )
            else if (styles.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No styles found.',
                    style: TextStyle(color: AppTheme.mediumGray, fontSize: 15),
                  ),
                ),
              )
            else
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
                      return StyleCard(
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

