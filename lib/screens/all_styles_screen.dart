import 'package:flutter/material.dart';
import '../models/style_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import 'style_details_screen.dart';
import '../main.dart';
import '../data/dynamic_style_manager.dart';
import '../widgets/style_card.dart';
import '../widgets/status_bar_style.dart';
import '../services/haptic_service.dart';

/// The "View All" destination for every horizontal preview row on Home
/// (a category, Trending, or Recommended For You).
///
/// Three ways to reach this screen, in priority order:
///  1. [categoryId] set - the live, production "View All" path. Renders
///     straight from [DynamicStyleManager.categoryCatalog] (the exact same
///     lazy-loaded, 6h-cached data Home's own preview row already holds - no
///     extra network round trip on open) and stays live: a pull-to-refresh
///     here, or a change made anywhere else in the app that updates this
///     category, is reflected without leaving/reopening the screen.
///  2. [styles] set (no [categoryId]) - a frozen snapshot, used by Trending
///     and Recommended For You, which aren't backed by a single category and
///     have no single id to subscribe to.
///  3. Neither set - legacy fallback, every loaded category's styles
///     flattened together.
class AllStylesScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleDarkMode;
  final String title;
  final List<StyleModel>? styles;
  final String? categoryId;

  const AllStylesScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
    this.title = 'All Styles',
    this.styles,
    this.categoryId,
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

    final categoryId = widget.categoryId;
    if (categoryId != null) {
      // Defensive only - in the normal Home "See All" flow the category is
      // already loaded by the time this screen can be reached (Home's own
      // preview row won't offer "See All" until it has more than a
      // preview's worth of styles). This only matters for a deep link
      // straight into this screen, mirroring the same
      // load-if-not-already-loaded pattern _CategorySectionWidget uses on
      // Home.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final styleManager = StyleProvider.read(context);
        final category = _findCategory(styleManager.categories, categoryId);
        if (category == null || (!category.hasLoadedStyles && !styleManager.isCategoryLoading(categoryId))) {
          styleManager.loadStylesForCategory(categoryId);
        }
      });
    }
  }

  void _toggleDark() {
    setState(() => _isDark = !_isDark);
    widget.onToggleDarkMode();
  }

  @override
  Widget build(BuildContext context) {
    final categoryId = widget.categoryId;
    if (categoryId != null) {
      return _buildLiveCategoryScaffold(context, categoryId);
    }

    // Home's "See All" for Trending/Recommended always passes an explicit
    // (already-filtered) snapshot list - only the neither-provided fallback
    // path below needs to read the live category catalog.
    if (widget.styles != null) {
      return _buildScaffold(context, widget.styles!);
    }
    // .read(), not .of(): reactivity is handled by the ListenableBuilder
    // below, scoped to categoryCatalog specifically so a Trending/
    // Recommended/Filters change never rebuilds this screen.
    final styleManager = StyleProvider.read(context);
    return ListenableBuilder(
      listenable: styleManager.categoryCatalog,
      builder: (context, _) => _buildScaffold(
        context,
        styleManager.categories.expand((c) => c.styles).toList(),
      ),
    );
  }

  /// The live, cache-backed "View All" path for a single category - see the
  /// class doc for why this is the priority-1 mode.
  Widget _buildLiveCategoryScaffold(BuildContext context, String categoryId) {
    final styleManager = StyleProvider.read(context);
    return ListenableBuilder(
      listenable: styleManager.categoryCatalog,
      builder: (context, _) {
        final category = _findCategory(styleManager.categories, categoryId);
        final isLoading = styleManager.isCategoryLoading(categoryId);
        final styles = category?.styles ?? const <StyleModel>[];
        // "Still resolving" only while nothing is on screen yet - once any
        // styles are showing (from cache or a prior load), a background
        // refresh must never blank the grid out from under the user.
        final showLoadingState = styles.isEmpty && (isLoading || category == null || !category.hasLoadedStyles);

        return _buildScaffold(
          context,
          styles,
          isLoading: showLoadingState,
          onRefresh: () => styleManager.loadStylesForCategory(categoryId, forceRefresh: true),
        );
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    List<StyleModel> styles, {
    bool isLoading = false,
    Future<void> Function()? onRefresh,
  }) {
    final bgColor = _isDark ? AppTheme.black : AppTheme.lightBackground;
    final textColor = _isDark ? AppTheme.white : AppTheme.black;
    // Matches the SliverGrid below: crossAxisCount 2, 20px padding each
    // side, 12px crossAxisSpacing.
    final cardWidth = (MediaQuery.sizeOf(context).width - 40 - 12) / 2;

    Widget contentSliver;
    if (isLoading) {
      contentSliver = _buildSkeletonGrid(cardWidth);
    } else if (styles.isEmpty) {
      contentSliver = SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyStylesState(isDark: _isDark),
      );
    } else {
      contentSliver = SliverPadding(
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
      );
    }

    Widget body = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
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
                    HapticService.light();
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
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                // Only shown once styles have actually resolved - a bare "0
                // styles" or count while still loading reads as broken, not
                // informative.
                if (!isLoading && styles.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      '${styles.length}',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.5),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        contentSliver,
      ],
    );

    if (onRefresh != null) {
      body = RefreshIndicator(
        color: AppTheme.accentPurple,
        backgroundColor: _isDark ? AppTheme.darkSurface : AppTheme.white,
        onRefresh: onRefresh,
        child: body,
      );
    }

    return StatusBarStyle(
      isDark: _isDark,
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(child: body),
      ),
    );
  }

  Widget _buildSkeletonGrid(double cardWidth) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
          childAspectRatio: 0.55,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => StyleCardSkeleton(cardWidth: cardWidth),
          childCount: 6,
        ),
      ),
    );
  }

  void _openDetails(BuildContext context, StyleModel style, String heroTag) {
    HapticService.selection();
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

/// Manual lookup instead of `Iterable.firstOrNull` (a `package:collection`
/// extension not among this project's direct dependencies) to avoid adding
/// a new dependency for one call site.
CategoryModel? _findCategory(List<CategoryModel> categories, String id) {
  for (final category in categories) {
    if (category.id == id) return category;
  }
  return null;
}

/// Shown when a category has genuinely resolved to zero styles (disabled by
/// an admin, or a brand-new category with nothing added yet) - distinct from
/// the loading skeleton, which covers "still resolving."
class _EmptyStylesState extends StatelessWidget {
  final bool isDark;

  const _EmptyStylesState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppTheme.white : AppTheme.black;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : AppTheme.lightGray,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
              child: const Icon(
                Icons.style_outlined,
                color: AppTheme.mediumGray,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No styles here yet',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check back soon - new styles are added regularly.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.mediumGray, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
