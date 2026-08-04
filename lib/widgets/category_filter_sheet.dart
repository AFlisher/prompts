import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/dynamic_style_manager.dart';
import '../services/haptic_service.dart';
import 'app_bottom_sheet.dart';

/// Opens the multi-select category picker. Returns the applied set of
/// category ids on "Apply", or null if the sheet was dismissed (back
/// gesture/tap-outside) without applying - callers should leave the active
/// filter untouched in that case.
Future<Set<String>?> showCategoryFilterSheet(
  BuildContext context, {
  required bool isDarkMode,
  required List<CategoryModel> categories,
  required Set<String> initialSelectedIds,
}) {
  return showAppBottomSheet<Set<String>>(
    context,
    isDarkMode: isDarkMode,
    isScrollControlled: true,
    contentBuilder: (ctx) => _CategoryFilterSheetContent(
      isDarkMode: isDarkMode,
      categories: categories,
      initialSelectedIds: initialSelectedIds,
    ),
  );
}

class _CategoryFilterSheetContent extends StatefulWidget {
  final bool isDarkMode;
  final List<CategoryModel> categories;
  final Set<String> initialSelectedIds;

  const _CategoryFilterSheetContent({
    required this.isDarkMode,
    required this.categories,
    required this.initialSelectedIds,
  });

  @override
  State<_CategoryFilterSheetContent> createState() => _CategoryFilterSheetContentState();
}

class _CategoryFilterSheetContentState extends State<_CategoryFilterSheetContent> {
  // Local draft selection - the real DynamicStyleManager filter only updates
  // when "Apply" is pressed, so Cancel/back-gesture/tap-outside leaves the
  // active filter untouched.
  late Set<String> _draftSelected;
  final TextEditingController _categorySearchController = TextEditingController();
  String _categorySearch = '';

  @override
  void initState() {
    super.initState();
    _draftSelected = Set.from(widget.initialSelectedIds);
  }

  @override
  void dispose() {
    _categorySearchController.dispose();
    super.dispose();
  }

  List<CategoryModel> get _filteredCategories {
    if (_categorySearch.isEmpty) return widget.categories;
    final q = _categorySearch.toLowerCase();
    return widget.categories.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  void _toggle(String categoryId) {
    HapticService.selection();
    setState(() {
      if (!_draftSelected.remove(categoryId)) {
        _draftSelected.add(categoryId);
      }
    });
  }

  void _reset() {
    if (_draftSelected.isEmpty) return;
    HapticService.light();
    setState(() => _draftSelected.clear());
  }

  void _apply() {
    HapticService.medium();
    Navigator.pop(context, _draftSelected);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDarkMode ? AppTheme.white : AppTheme.black;
    final fieldBg = widget.isDarkMode ? AppTheme.black : AppTheme.lightGray;
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.45;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filter by Category',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _categorySearchController,
          onChanged: (v) => setState(() => _categorySearch = v),
          style: TextStyle(fontSize: 14, color: textColor),
          decoration: InputDecoration(
            hintText: 'Search categories...',
            hintStyle: const TextStyle(fontSize: 14, color: AppTheme.mediumGray),
            prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.mediumGray, size: 20),
            filled: true,
            fillColor: fieldBg,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxListHeight),
          child: _filteredCategories.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No categories match "$_categorySearch"',
                      style: const TextStyle(color: AppTheme.mediumGray, fontSize: 13),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    alignment: Alignment.topLeft,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final category in _filteredCategories)
                          _CategoryChip(
                            label: category.name,
                            selected: _draftSelected.contains(category.id),
                            isDarkMode: widget.isDarkMode,
                            onTap: () => _toggle(category.id),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _reset,
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor,
                  side: BorderSide(
                    color: widget.isDarkMode ? Colors.white24 : Colors.black12,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                ),
                child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Apply (${_draftSelected.length})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unselectedBg = isDarkMode ? AppTheme.darkCard : AppTheme.lightGray;
    final unselectedText = isDarkMode ? AppTheme.white : AppTheme.black;

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      avatar: selected ? const Icon(Icons.check_rounded, size: 18, color: Colors.white) : null,
      labelStyle: TextStyle(
        color: selected ? Colors.white : unselectedText,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      backgroundColor: unselectedBg,
      selectedColor: AppTheme.accentPurple,
      side: BorderSide(
        color: selected
            ? Colors.transparent
            : (isDarkMode ? Colors.white12 : Colors.black12),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
