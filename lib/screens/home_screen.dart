import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/style_model.dart';
import '../widgets/app_header.dart';
import '../widgets/search_bar_widget.dart' as custom;
import 'style_details_screen.dart';
import 'all_styles_screen.dart';
import '../main.dart';
import '../data/dynamic_style_manager.dart';
import '../widgets/style_card.dart';
import '../widgets/floating_nav_bar_metrics.dart';

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleDarkMode;

  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  String _searchQuery = '';
  late final AnimationController _headerAnimController;
  late final Animation<double> _headerFadeAnim;

  List<StyleModel> _filterStyles(List<StyleModel> list) {
    if (_searchQuery.isEmpty) return list;
    return list
        .where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerFadeAnim = CurvedAnimation(
      parent: _headerAnimController,
      curve: Curves.easeOut,
    );
    _headerAnimController.forward();

    // Trigger initialization on widget mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final styleManager = StyleProvider.read(context);
        if (styleManager.categories.isEmpty && !styleManager.isLoading) {
          styleManager.fetchCategories();
        }
      }
    });
  }

  @override
  void dispose() {
    _headerAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? AppTheme.black : AppTheme.lightBackground;
    final textColor = isDark ? AppTheme.white : AppTheme.black;

    final styleManager = StyleProvider.of(context);
    final categories = styleManager.categories;
    final isLoading = styleManager.isLoading;
    final error = styleManager.error;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.accentPurple,
          backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.white,
          onRefresh: () async {
            await Future.wait([
              styleManager.fetchFromApi(),
              CreditProvider.of(context).fetchWallet(),
            ]);
          },
          child: FadeTransition(
            opacity: _headerFadeAnim,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(26, 12, 26, 0),
                    child: AppHeader(
                      isDarkMode: isDark,
                      onToggleDarkMode: widget.onToggleDarkMode,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(38, 20, 38, 0),
                    child: custom.SearchBar(
                      onChanged: (q) => setState(() => _searchQuery = q),
                    ),
                  ),
                ),

                // Trending always renders first, ahead of every category
                // section below - it's a dynamic view over isTrending
                // styles, not a category itself, so it isn't part of
                // `categories` and doesn't participate in category ordering.
                SliverToBoxAdapter(
                  child: _TrendingSectionWidget(
                    textColor: textColor,
                    isDark: isDark,
                    sectionBuilder: (ctx, title, styles, txtColor, dark, loading) {
                      return _buildHorizontalSection(
                        title: title,
                        styles: styles,
                        textColor: txtColor,
                        isDark: dark,
                        isLoading: loading,
                      );
                    },
                  ),
                ),

                // Conditional UI based on API State
                if (isLoading && categories.isEmpty)
                  const SliverToBoxAdapter(
                    child: Column(
                      children: [
                        StyleRowSkeleton(),
                        StyleRowSkeleton(),
                        StyleRowSkeleton(),
                      ],
                    ),
                  )
                else if (error != null && categories.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              error,
                              style: const TextStyle(color: Colors.red, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => styleManager.fetchFromApi(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentPurple,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text('Retry', style: TextStyle(color: Colors.white)),
                            )
                          ],
                        ),
                      ),
                    ),
                  )
                else if (categories.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Text(
                          'No categories found.',
                          style: TextStyle(color: AppTheme.mediumGray, fontSize: 15),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final category = categories[index];
                        return _CategorySectionWidget(
                          category: category,
                          styleManager: styleManager,
                          textColor: textColor,
                          isDark: isDark,
                          sectionBuilder: (ctx, title, styles, txtColor, dark, loading) {
                            return _buildHorizontalSection(
                              title: title,
                              styles: styles,
                              textColor: txtColor,
                              isDark: dark,
                              isLoading: loading,
                            );
                          },
                        );
                      },
                      childCount: categories.length,
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: SizedBox(
                    height: FloatingNavBarMetrics.scrollClearance,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalSection({
    required String title,
    required List<StyleModel> styles,
    required Color textColor,
    required bool isDark,
    required bool isLoading,
  }) {
    final filtered = _filterStyles(styles);
    // Only collapse when a search query excludes every loaded style — a
    // category with no styles loaded yet (LRU eviction, in-flight lazy
    // load) must still render its header.
    if (styles.isNotEmpty && filtered.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 12),
          child: _SectionHeader(
            title: title,
            textColor: textColor,
            onSeeAll: () => _openAllStyles(title, styles),
          ),
        ),
        if (isLoading && filtered.isEmpty)
          const StyleRowSkeleton()
        else if (filtered.isNotEmpty)
          SizedBox(
            height: 250,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final style = filtered[index];
                // Namespaced by section title (not just style id): a
                // trending style renders in both this row and its own
                // category row at once, and Hero requires unique tags
                // among simultaneously-mounted widgets in the same route.
                final heroTag = 'home_${title}_${style.id}';
                return SizedBox(
                  width: 135,
                  child: StyleCard(
                    style: style,
                    isDarkMode: isDark,
                    onTap: () => _onStyleTapped(style, heroTag),
                    cardWidth: 135,
                    heroTag: heroTag,
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 20),
              itemCount: filtered.length,
              cacheExtent: 1000,
            ),
          ),
      ],
    );
  }

  void _openAllStyles(String title, List<StyleModel> styles) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AllStylesScreen(
          isDarkMode: widget.isDarkMode,
          onToggleDarkMode: widget.onToggleDarkMode,
          title: title,
          styles: styles,
        ),
      ),
    );
  }

  void _onStyleTapped(StyleModel style, String heroTag) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StyleDetailsScreen(
          style: style,
          isDarkMode: widget.isDarkMode,
          onToggleDarkMode: widget.onToggleDarkMode,
          heroTag: heroTag,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color textColor;
  final VoidCallback onSeeAll;

  const _SectionHeader({
    required this.title,
    required this.textColor,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 310;

        return Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: AppTheme.accentPink,
              size: compact ? 24 : 30,
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: compact ? 18 : 20,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 2,
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSeeAll,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    compact ? 'See' : 'See All',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.78),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: textColor, size: 17),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Renders the dynamic "Trending Styles" section using the exact same
/// [Widget Function] section builder as a normal category - one UI to
/// maintain, no separate Trending design. Unlike [_CategorySectionWidget]
/// this isn't backed by a [CategoryModel]: it reads
/// [DynamicStyleManager.trendingStyles], collapsing entirely once loaded if
/// no style is currently marked trending (rather than showing an empty
/// header forever).
class _TrendingSectionWidget extends StatefulWidget {
  final Color textColor;
  final bool isDark;
  final Widget Function(BuildContext, String, List<StyleModel>, Color, bool, bool) sectionBuilder;

  const _TrendingSectionWidget({
    required this.textColor,
    required this.isDark,
    required this.sectionBuilder,
  });

  @override
  State<_TrendingSectionWidget> createState() => _TrendingSectionWidgetState();
}

class _TrendingSectionWidgetState extends State<_TrendingSectionWidget> {
  @override
  void initState() {
    super.initState();
    StyleProvider.read(context).loadTrendingStyles();
  }

  @override
  Widget build(BuildContext context) {
    // Watch styleManager to rebuild when trending styles update (e.g. an
    // admin toggles a style's Trending switch and the app later refreshes).
    final styleManager = StyleProvider.of(context);

    final styles = styleManager.trendingStyles;
    final isLoading = styleManager.isTrendingLoading;

    if (styleManager.hasLoadedTrending && styles.isEmpty) {
      return const SizedBox.shrink();
    }

    return widget.sectionBuilder(
      context,
      'Trending Styles',
      styles,
      widget.textColor,
      widget.isDark,
      isLoading,
    );
  }
}

class _CategorySectionWidget extends StatefulWidget {
  final CategoryModel category;
  final DynamicStyleManager styleManager;
  final Color textColor;
  final bool isDark;
  final Widget Function(BuildContext, String, List<StyleModel>, Color, bool, bool) sectionBuilder;

  const _CategorySectionWidget({
    required this.category,
    required this.styleManager,
    required this.textColor,
    required this.isDark,
    required this.sectionBuilder,
  });

  @override
  State<_CategorySectionWidget> createState() => _CategorySectionWidgetState();
}

class _CategorySectionWidgetState extends State<_CategorySectionWidget> {
  @override
  void initState() {
    super.initState();
    _loadStyles();
  }

  @override
  void didUpdateWidget(covariant _CategorySectionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.category.id != oldWidget.category.id) {
      _loadStyles();
    }
  }

  void _loadStyles() {
    widget.styleManager.loadStylesForCategory(widget.category.id);
  }

  @override
  Widget build(BuildContext context) {
    // Watch styleManager to rebuild when categories or styles update
    final styleManager = StyleProvider.of(context);
    
    // Always fetch the freshest category instance from state manager to avoid holding stale state
    final category = styleManager.categories.firstWhere(
      (c) => c.id == widget.category.id,
      orElse: () => widget.category,
    );

    final isLoading = styleManager.isCategoryLoading(category.id);
    final styles = category.styles;

    // Auto-reload if this category's styles have never been resolved yet (or,
    // for a future LRU eviction, if it gets reset back to unloaded). Keyed on
    // hasLoadedStyles rather than styles.isEmpty so a category that's
    // genuinely empty (loaded, confirmed zero styles) doesn't reload forever.
    if (!category.hasLoadedStyles && !isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadStyles();
        }
      });
    }

    return widget.sectionBuilder(
      context,
      category.name,
      styles,
      widget.textColor,
      widget.isDark,
      isLoading,
    );
  }
}
