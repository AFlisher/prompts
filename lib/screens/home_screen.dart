import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/style_model.dart';
import '../data/style_data.dart';
import '../widgets/app_header.dart';
import '../widgets/search_bar_widget.dart' as custom;
import 'arabic_styles_screen.dart';
import 'style_details_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleDarkMode;
  final ValueChanged<int>? onNavigate;

  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
    this.onNavigate,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  String _searchQuery = '';
  late final AnimationController _headerAnimController;
  late final Animation<double> _headerFadeAnim;

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
  }

  @override
  void dispose() {
    _headerAnimController.dispose();
    super.dispose();
  }

  List<StyleModel> get _filteredTrending {
    if (_searchQuery.isEmpty) return StyleData.trendingStyles;
    return StyleData.trendingStyles
        .where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  List<StyleModel> get _filteredMore {
    if (_searchQuery.isEmpty) return StyleData.moreStyles;
    return StyleData.moreStyles
        .where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? AppTheme.black : AppTheme.white;
    final textColor = isDark ? AppTheme.white : AppTheme.black;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _headerFadeAnim,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(26, 12, 26, 0),
                  child: AppHeader(
                    isDarkMode: isDark,
                    onToggleDarkMode: widget.onToggleDarkMode,
                    onMenuSelected: _onMenuSelected,
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(26, 20, 26, 10),
                  child: _SectionHeader(
                    title: 'Trending Styles',
                    textColor: textColor,
                    onSeeAll: _openArabicStyles,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 278,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final style = _filteredTrending[index];
                      return _HomeStyleCard(
                        style: style,
                        width: index == 0 ? 198 : 154,
                        onTap: () => _onStyleTapped(style),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 26),
                    itemCount: _filteredTrending.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(26, 18, 26, 10),
                  child: _SectionHeader(
                    title: 'More Styles',
                    textColor: textColor,
                    onSeeAll: () {},
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 188,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(26, 0, 26, 28),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final style = _filteredMore[index];
                      return _HomeStyleCard(
                        style: style,
                        width: 154,
                        compact: true,
                        onTap: () => _onStyleTapped(style),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemCount: _filteredMore.length,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onMenuSelected(String value) {
    switch (value) {
      case 'Saved':
        widget.onNavigate?.call(2);
        break;
      case 'Styles':
        _openArabicStyles();
        break;
      case 'Mine':
        widget.onNavigate?.call(1);
        break;
      default:
        widget.onNavigate?.call(0);
    }
  }

  void _openArabicStyles() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArabicStylesScreen(
          isDarkMode: widget.isDarkMode,
          onToggleDarkMode: widget.onToggleDarkMode,
        ),
      ),
    );
  }

  void _onStyleTapped(StyleModel style) {
    HapticFeedback.lightImpact();
    if (style.id == 'arabic') {
      _openArabicStyles();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StyleDetailsScreen(
          style: style,
          isDarkMode: widget.isDarkMode,
          onToggleDarkMode: widget.onToggleDarkMode,
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
              Icons.auto_awesome,
              color: const Color(0xFFE735F6),
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

class _HomeStyleCard extends StatefulWidget {
  final StyleModel style;
  final double width;
  final bool compact;
  final VoidCallback onTap;

  const _HomeStyleCard({
    required this.style,
    required this.width,
    required this.onTap,
    this.compact = false,
  });

  @override
  State<_HomeStyleCard> createState() => _HomeStyleCardState();
}

class _HomeStyleCardState extends State<_HomeStyleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.white : AppTheme.black;
    final imageHeight = widget.compact ? 118.0 : 228.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 110),
        child: SizedBox(
          width: widget.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: widget.width,
                  height: imageHeight,
                  child: Image.asset(
                    widget.style.imagePath,
                    fit: BoxFit.cover,
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
                      fontSize: widget.compact ? 13 : 15,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
