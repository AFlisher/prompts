import 'dart:async';
import 'package:flutter/material.dart';
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
import '../services/haptic_service.dart';
import '../widgets/category_filter_sheet.dart';

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
  // A ValueNotifier, not a setState-driving String field: writing to it
  // never rebuilds this State's own build() (Scaffold/AppHeader/filter
  // button/RefreshIndicator), so those stay completely stable while typing.
  // Only the narrow subtrees that explicitly listen via
  // ValueListenableBuilder below - each section's own filtered row, and the
  // whole-list-vs-empty-state decision - react to it.
  final ValueNotifier<String> _searchQuery = ValueNotifier<String>('');
  late final AnimationController _headerAnimController;
  late final Animation<double> _headerFadeAnim;

  List<StyleModel> _filterStyles(List<StyleModel> list, String query) {
    if (query.isEmpty) return list;
    return list
        .where((s) => s.name.toLowerCase().contains(query.toLowerCase()))
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
    _searchQuery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // .read(), not .of(): DynamicStyleManager itself never fires its own
    // notifyListeners() anymore (see dynamic_style_manager.dart) - each
    // slice (categoryCatalog/categoryFilter/trending/recommended) notifies
    // independently. This whole build() only needs categoryCatalog and
    // categoryFilter, wired up via the ListenableBuilder below, so a
    // Trending or Recommended change never re-runs it.
    final styleManager = StyleProvider.read(context);
    return ListenableBuilder(
      listenable: Listenable.merge([styleManager.categoryCatalog, styleManager.categoryFilter]),
      builder: (context, _) => _buildHomeContent(context, styleManager),
    );
  }

  Widget _buildHomeContent(BuildContext context, DynamicStyleManager styleManager) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? AppTheme.black : AppTheme.lightBackground;
    final textColor = isDark ? AppTheme.white : AppTheme.black;

    final categories = styleManager.categories;
    final isLoading = styleManager.isLoading;
    final error = styleManager.error;
    final selectedCategoryIds = styleManager.selectedCategoryFilterIds;
    final isCategoryFiltered = selectedCategoryIds.isNotEmpty;
    final visibleCategories = isCategoryFiltered
        ? categories.where((c) => selectedCategoryIds.contains(c.id)).toList()
        : categories;

    // Trending/Recommended are cross-category views (deliberately not part
    // of `categories` - see the comments on their section widgets below),
    // so they're hidden entirely once a category filter narrows the screen
    // to specific categories rather than showing off-scope styles.
    final showTrendingAndRecommended = !isCategoryFiltered;

    // The "normal" content - Recommended + Trending + (loading/error/empty-
    // categories/category list) - built here from search-independent state
    // only (categories/loading/error/filters). Passed as the `child:` of the
    // ValueListenableBuilder below, so as long as the aggregate search result
    // stays non-empty (the common case), this exact widget instance is
    // reused untouched across every keystroke - only each section's own
    // nested ValueListenableBuilder (see _buildHorizontalSection) reacts to
    // repaint its own filtered row.
    Widget mainContent;
    if (isLoading && categories.isEmpty) {
      mainContent = const SliverToBoxAdapter(
        child: Column(
          children: [
            StyleRowSkeleton(),
            StyleRowSkeleton(),
            StyleRowSkeleton(),
          ],
        ),
      );
    } else if (error != null && categories.isEmpty) {
      mainContent = SliverFillRemaining(
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
      );
    } else if (categories.isEmpty) {
      mainContent = const SliverFillRemaining(
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
      );
    } else {
      mainContent = SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final category = visibleCategories[index];
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
          childCount: visibleCategories.length,
        ),
      );
    }

    // Recommended and Trending, built once from search-independent state.
    // Each is handed to its own ValueListenableBuilder below as an
    // identity-stable `child:`, so as long as the aggregate search result
    // stays non-empty (the common case) these exact widget instances are
    // reused untouched across every keystroke - only each section's own
    // nested ValueListenableBuilder (see _buildHorizontalSection) reacts to
    // repaint its own filtered row.
    final recommendedContent = SliverToBoxAdapter(
      child: _RecommendedSectionWidget(
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
    );
    final trendingContent = SliverToBoxAdapter(
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
    );

    // Shared by all three reactive slivers below - the aggregate decision of
    // whether the *entire* Recommended/Trending/category-list region should
    // be replaced by the unified _EmptySearchState. Pure list-filtering over
    // already-in-memory data (no widget rebuilding), so recomputing it on
    // every keystroke is cheap.
    bool showEmptySearchStateFor(String query) {
      final isSearchingOrFiltering = query.isNotEmpty || isCategoryFiltered;
      final stillLoadingRelevantSections = visibleCategories.any(
            (c) => !c.hasLoadedStyles || styleManager.isCategoryLoading(c.id),
          ) ||
          (showTrendingAndRecommended && !styleManager.hasLoadedTrending) ||
          (showTrendingAndRecommended && !styleManager.hasLoadedRecommended);
      final hasAnyMatch = visibleCategories.any(
            (c) => _filterStyles(c.styles, query).isNotEmpty,
          ) ||
          (showTrendingAndRecommended &&
              _filterStyles(styleManager.trendingStyles, query).isNotEmpty) ||
          (showTrendingAndRecommended &&
              _filterStyles(styleManager.recommendedStyles, query).isNotEmpty);
      return isSearchingOrFiltering &&
          categories.isNotEmpty &&
          !stillLoadingRelevantSections &&
          !hasAnyMatch;
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.accentPurple,
          backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.white,
          onRefresh: () async {
            // .read(), not .of(): this is the only place HomeScreen touches
            // CreditManager at all (AppHeader renders the balance via its
            // own, separately-scoped subscription) - .of() here would
            // subscribe this whole screen (search, filters, every category/
            // trending/recommended section) to rebuild on every credit
            // change anywhere in the app (every generation, every ad
            // reward), for a value this screen never actually renders.
            await Future.wait([
              styleManager.fetchFromApi(),
              CreditProvider.read(context).fetchWallet(),
            ]);
            HapticService.medium();
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: custom.SearchBar(
                            isDark: isDark,
                            // Writes straight to the notifier - no setState,
                            // so HomeScreen itself never rebuilds from typing.
                            onChanged: (q) => _searchQuery.value = q,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _FilterButton(
                          isDark: isDark,
                          activeCount: selectedCategoryIds.length,
                          onTap: () => _openCategoryFilterSheet(context, styleManager),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isCategoryFiltered)
                  SliverToBoxAdapter(
                    child: _SelectedFilterChipsRow(
                      isDark: isDark,
                      categories: categories,
                      selectedIds: selectedCategoryIds,
                      onRemove: styleManager.removeCategoryFilter,
                      onClearAll: styleManager.clearCategoryFilters,
                    ),
                  ),

                // Recommended and Trending each independently hide themselves
                // (not just their own per-section empty check) once the
                // *aggregate* search result across every section is empty -
                // _EmptySearchState below is then the only thing shown. As
                // long as showEmptySearchStateFor(query) doesn't flip,
                // ValueListenableBuilder hands back the exact same
                // `recommendedContent`/`trendingContent` instance on every
                // keystroke, so typing never touches these widgets.
                if (showTrendingAndRecommended)
                  ValueListenableBuilder<String>(
                    valueListenable: _searchQuery,
                    builder: (context, query, child) {
                      if (showEmptySearchStateFor(query)) {
                        return const SliverToBoxAdapter(child: SizedBox.shrink());
                      }
                      return child!;
                    },
                    child: recommendedContent,
                  ),
                if (showTrendingAndRecommended)
                  ValueListenableBuilder<String>(
                    valueListenable: _searchQuery,
                    builder: (context, query, child) {
                      if (showEmptySearchStateFor(query)) {
                        return const SliverToBoxAdapter(child: SizedBox.shrink());
                      }
                      return child!;
                    },
                    child: trendingContent,
                  ),

                // The category list (or loading/error/empty-categories
                // fallback) vs. the unified _EmptySearchState - same
                // identity-stable `child:` pattern as above.
                ValueListenableBuilder<String>(
                  valueListenable: _searchQuery,
                  builder: (context, query, child) {
                    if (showEmptySearchStateFor(query)) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptySearchState(isDark: isDark),
                      );
                    }
                    return child!;
                  },
                  child: mainContent,
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
    // Reacts to search on its own, directly - the section widget that calls
    // this (_CategorySectionWidget/_TrendingSectionWidgetState/
    // _RecommendedSectionWidgetState) never needs to know the search query
    // exists, so typing never re-runs *their* build() (and therefore never
    // re-touches their own styleManager lookups / lazy-load triggers) - only
    // this innermost callback (header visibility + the filtered row itself,
    // i.e. exactly the "search results") re-renders per keystroke.
    return ValueListenableBuilder<String>(
      valueListenable: _searchQuery,
      builder: (context, query, _) {
        final filtered = _filterStyles(styles, query);
        // Only collapse when a search query excludes every loaded style — a
        // category with no styles loaded yet (LRU eviction, in-flight lazy
        // load) must still render its header.
        if (styles.isNotEmpty && filtered.isEmpty) return const SizedBox.shrink();
        // Isolates each section (a Category row, Trending, or Recommended
        // For You) as its own compositing layer. Each is backed by its own
        // independent StatefulWidget/lazy fetch (_CategorySectionWidget,
        // _TrendingSectionWidgetState, _RecommendedSectionWidgetState), so
        // without this, one section finishing its own load could force
        // nearby sections' already-settled layers to repaint too.
        return RepaintBoundary(
          child: Column(
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
                    // The row's height (250) is only ~2px taller than a card's
                    // own content (200 image + 8 gap + 40 title = 248),
                    // leaving no room for StyleCard's shadow to paint before
                    // ListView's default hard-edge viewport clip cuts it off.
                    // The shadow itself never affects layout/scroll extent
                    // either way, so disabling the clip here just lets it
                    // bleed a few px past the row's nominal bounds instead of
                    // being invisibly clipped.
                    clipBehavior: Clip.none,
                    itemBuilder: (context, index) {
                      final style = filtered[index];
                      // Namespaced by section title (not just style id): a
                      // trending style renders in both this row and its own
                      // category row at once, and Hero requires unique tags
                      // among simultaneously-mounted widgets in the same
                      // route.
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
          ),
        );
      },
    );
  }

  void _openAllStyles(String title, List<StyleModel> styles) {
    HapticService.selection();
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
    HapticService.selection();
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

  Future<void> _openCategoryFilterSheet(
    BuildContext context,
    DynamicStyleManager styleManager,
  ) async {
    HapticService.light();
    // styleManager.categories is already cached/loaded by this point (Home
    // fetches it on mount) - the sheet never issues its own category fetch.
    final applied = await showCategoryFilterSheet(
      context,
      isDarkMode: widget.isDarkMode,
      categories: styleManager.categories,
      initialSelectedIds: styleManager.selectedCategoryFilterIds,
    );
    // null means dismissed without pressing Apply - leave the filter as-is.
    if (applied != null) {
      styleManager.setCategoryFilters(applied);
    }
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

/// Renders the "Recommended For You" section, powered entirely by
/// RecommendationService (GET /api/styles?recommended=true) - this widget
/// does no ranking of its own, it only decides whether to render at all.
/// Mounted above [_TrendingSectionWidget]. Stays hidden (not just empty) in
/// every case the feature is meant to be invisible: personalization off,
/// anonymous, or not enough favorite/creation history yet to personalize
/// from - the backend already encodes all of that as an empty list, so a
/// single "hasLoaded && styles.isEmpty" check covers every case without
/// Flutter needing to know *why* it's empty.
class _RecommendedSectionWidget extends StatefulWidget {
  final Color textColor;
  final bool isDark;
  final Widget Function(BuildContext, String, List<StyleModel>, Color, bool, bool) sectionBuilder;

  const _RecommendedSectionWidget({
    required this.textColor,
    required this.isDark,
    required this.sectionBuilder,
  });

  @override
  State<_RecommendedSectionWidget> createState() => _RecommendedSectionWidgetState();
}

class _RecommendedSectionWidgetState extends State<_RecommendedSectionWidget> {
  @override
  void initState() {
    super.initState();
    // Belt-and-suspenders alongside the server-side enforcement in
    // styleController: don't even issue the request when the toggle is off,
    // rather than relying solely on the backend returning [].
    if (ProfileProvider.read(context).profile?.personalizationEnabled ?? true) {
      StyleProvider.read(context).loadRecommendedStyles();
    }
  }

  @override
  Widget build(BuildContext context) {
    final personalizationEnabled =
        ProfileProvider.of(context).profile?.personalizationEnabled ?? true;
    if (!personalizationEnabled) {
      return const SizedBox.shrink();
    }

    // .read(), not .of(): only the `recommended` slice below is what this
    // section actually needs to react to - a Trending/Categories/Filters
    // change must never rebuild it.
    final styleManager = StyleProvider.read(context);
    return ListenableBuilder(
      listenable: styleManager.recommended,
      builder: (context, _) {
        final styles = styleManager.recommendedStyles;
        final isLoading = styleManager.isRecommendedLoading;

        if (styleManager.hasLoadedRecommended && styles.isEmpty) {
          return const SizedBox.shrink();
        }

        return widget.sectionBuilder(
          context,
          'Recommended For You',
          styles,
          widget.textColor,
          widget.isDark,
          isLoading,
        );
      },
    );
  }
}

class _TrendingSectionWidgetState extends State<_TrendingSectionWidget> {
  @override
  void initState() {
    super.initState();
    StyleProvider.read(context).loadTrendingStyles();
  }

  @override
  Widget build(BuildContext context) {
    // .read(), not .of(): listen to the `trending` slice specifically (via
    // ListenableBuilder below) so a Categories/Recommended/Filters change
    // never rebuilds this section - only trending refreshing (e.g. an admin
    // toggles a style's Trending switch and the app later refreshes) does.
    final styleManager = StyleProvider.read(context);
    return ListenableBuilder(
      listenable: styleManager.trending,
      builder: (context, _) {
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
      },
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
    // Listens to categoryCatalog specifically (not the whole styleManager -
    // already had direct access to it via widget.styleManager, no context
    // lookup needed either way), so a Trending/Recommended/Filters change
    // never rebuilds a category section.
    return ListenableBuilder(
      listenable: widget.styleManager.categoryCatalog,
      builder: (context, _) {
        // Always fetch the freshest category instance from state manager to
        // avoid holding stale state.
        final category = widget.styleManager.categories.firstWhere(
          (c) => c.id == widget.category.id,
          orElse: () => widget.category,
        );

        final isLoading = widget.styleManager.isCategoryLoading(category.id);
        final styles = category.styles;

        // Auto-reload if this category's styles have never been resolved yet
        // (or, for a future LRU eviction, if it gets reset back to
        // unloaded). Keyed on hasLoadedStyles rather than styles.isEmpty so
        // a category that's genuinely empty (loaded, confirmed zero styles)
        // doesn't reload forever.
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
      },
    );
  }
}

/// Opens the category picker sheet. Shows a small badge with the active
/// filter count so the button itself communicates filter state without
/// needing the chips row visible (e.g. while scrolled past it).
class _FilterButton extends StatelessWidget {
  final bool isDark;
  final int activeCount;
  final VoidCallback onTap;

  const _FilterButton({
    required this.isDark,
    required this.activeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = activeCount > 0;
    // The active (accent purple) state is a selection state, not a theme
    // one, and stays identical in both themes. Inactive: this now mirrors
    // the search bar and top capsule exactly - Light Mode is a dark
    // (AppTheme.black) control, Dark Mode deliberately inverts to the Light
    // Theme's own cream/off-white background (never pure white) - so all
    // three controls read as one consistent, unified surface regardless of
    // theme.
    final bg = isActive
        ? AppTheme.accentPurple
        : (isDark ? AppTheme.lightBackground : AppTheme.black);
    final iconColor = isActive ? Colors.white : (isDark ? AppTheme.black : Colors.white);
    final borderColor = isActive
        ? Colors.transparent
        : (isDark ? Colors.black12 : Colors.white12);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(color: borderColor),
          boxShadow: AppTheme.themeAwareShadow(isDark),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: iconColor),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
              builder: (context, color, _) =>
                  Icon(Icons.tune_rounded, color: color, size: 22),
            ),
            if (isActive)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  decoration: const BoxDecoration(
                    color: AppTheme.accentPink,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$activeCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The removable-chip row shown below the search bar once at least one
/// category filter is active. Resolves ids to names against the live
/// `categories` list (rather than caching names in the filter set itself)
/// so a category rename is reflected immediately without extra state.
class _SelectedFilterChipsRow extends StatelessWidget {
  final bool isDark;
  final List<CategoryModel> categories;
  final Set<String> selectedIds;
  final ValueChanged<String> onRemove;
  final VoidCallback onClearAll;

  const _SelectedFilterChipsRow({
    required this.isDark,
    required this.categories,
    required this.selectedIds,
    required this.onRemove,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppTheme.white : AppTheme.black;
    final selected = categories.where((c) => selectedIds.contains(c.id)).toList();
    if (selected.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(38, 14, 26, 0),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.none,
          itemCount: selected.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            if (index == selected.length) {
              return GestureDetector(
                onTap: () {
                  HapticService.light();
                  onClearAll();
                },
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: Text(
                    'Clear All',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              );
            }

            final category = selected[index];
            return InputChip(
              key: ValueKey(category.id),
              label: Text(category.name),
              onDeleted: () {
                HapticService.light();
                onRemove(category.id);
              },
              deleteIcon: const Icon(Icons.close_rounded, size: 16),
              deleteIconColor: Colors.white,
              labelStyle: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: AppTheme.accentPurple,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            );
          },
        ),
      ),
    );
  }
}

/// The unified "nothing matched" state shown when an active search and/or
/// category filter excludes every style, instead of the previous behavior
/// of every section silently collapsing to a blank scroll area.
class _EmptySearchState extends StatelessWidget {
  final bool isDark;

  const _EmptySearchState({required this.isDark});

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
                Icons.search_off_rounded,
                color: AppTheme.mediumGray,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No styles found',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try a different search term or adjust your category filters.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.mediumGray, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
