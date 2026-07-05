import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/style_model.dart';

class CategoryModel {
  final String id;
  final String name;
  final List<StyleModel> styles;

  CategoryModel({
    required this.id,
    required this.name,
    required this.styles,
  });

  CategoryModel copyWith({
    String? id,
    String? name,
    List<StyleModel>? styles,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      styles: styles ?? this.styles,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'styles': styles.map((s) => s.toJson()).toList(),
      };

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      styles: (json['styles'] as List<dynamic>?)
              ?.map((s) => StyleModel.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class DynamicStyleManager extends ChangeNotifier {
  List<CategoryModel> _categories = [];
  bool _isInitialized = false;

  List<CategoryModel> get categories => List.unmodifiable(_categories);
  bool get isInitialized => _isInitialized;

  /// Get the directory file path for storage
  Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/dynamic_styles_v2.json');
  }

  /// Initialize and load styles from storage, or seed with initial values
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = json.decode(content);
        _categories = jsonList.map((c) => CategoryModel.fromJson(c)).toList();
      } else {
        // Seed default styles on first run
        _categories = _getDefaultCategories();
        await save();
      }
    } catch (e) {
      debugPrint("Error loading dynamic styles: $e");
      _categories = _getDefaultCategories();
    }
    _isInitialized = true;
    notifyListeners();
  }

  /// Save state to local JSON file
  Future<void> save() async {
    try {
      final file = await _localFile;
      final content = json.encode(_categories.map((c) => c.toJson()).toList());
      await file.writeAsString(content);
    } catch (e) {
      debugPrint("Error saving dynamic styles: $e");
    }
  }

  /// Add a new category
  Future<void> addCategory(String name) async {
    final id = name.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    // Prevent duplicate IDs
    if (_categories.any((c) => c.id == id)) return;

    _categories.add(CategoryModel(
      id: id,
      name: name,
      styles: [],
    ));
    await save();
    notifyListeners();
  }

  /// Delete a category
  Future<void> deleteCategory(String categoryId) async {
    _categories.removeWhere((c) => c.id == categoryId);
    await save();
    notifyListeners();
  }

  /// Add a style to a category
  Future<void> addStyle(String categoryId, StyleModel style) async {
    final index = _categories.indexWhere((c) => c.id == categoryId);
    if (index == -1) return;

    final category = _categories[index];
    final updatedStyles = List<StyleModel>.from(category.styles)..add(style);
    _categories[index] = category.copyWith(styles: updatedStyles);

    await save();
    notifyListeners();
  }

  /// Delete a style from a category
  Future<void> deleteStyle(String categoryId, String styleId) async {
    final index = _categories.indexWhere((c) => c.id == categoryId);
    if (index == -1) return;

    final category = _categories[index];
    final updatedStyles = List<StyleModel>.from(category.styles)
      ..removeWhere((s) => s.id == styleId);
    _categories[index] = category.copyWith(styles: updatedStyles);

    await save();
    notifyListeners();
  }

  /// Toggle trending status for a style
  Future<void> toggleTrending(String categoryId, String styleId) async {
    final catIndex = _categories.indexWhere((c) => c.id == categoryId);
    if (catIndex == -1) return;

    final category = _categories[catIndex];
    final styleIndex = category.styles.indexWhere((s) => s.id == styleId);
    if (styleIndex == -1) return;

    final style = category.styles[styleIndex];
    final updatedStyle = StyleModel(
      id: style.id,
      name: style.name,
      imagePath: style.imagePath,
      imageUrl: style.imageUrl,
      isFavorite: style.isFavorite,
      isTrending: !style.isTrending,
      description: style.description,
      prompt: style.prompt,
      sortOrder: style.sortOrder,
      examples: style.examples,
    );

    final updatedStyles = List<StyleModel>.from(category.styles);
    updatedStyles[styleIndex] = updatedStyle;
    _categories[catIndex] = category.copyWith(styles: updatedStyles);

    await save();
    notifyListeners();
  }

  /// Helper to get default initial categories list
  List<CategoryModel> _getDefaultCategories() {
    return [
      CategoryModel(
        id: 'trending',
        name: 'Trending Styles',
        styles: [
          const StyleModel(
            id: 'arabic',
            name: 'Arabic Style',
            imagePath: 'assets/images/style_arabic.jpg',
            isTrending: true,
            description: 'A cinematic Arabic-inspired visual style with dramatic lighting, bold colors and vintage aesthetics.',
            examples: ['assets/images/style_arabic.jpg', 'assets/images/style_stussy.jpg', 'assets/images/style_90s.jpg', 'assets/images/style_ps2.jpg'],
          ),
          const StyleModel(
            id: 'stussy',
            name: 'Stussy Style',
            imagePath: 'assets/images/style_stussy.jpg',
            isTrending: true,
            description: 'Urban street-fashion inspired aesthetic featuring high-contrast graphics, grainy filters, and skate culture vibes.',
            examples: ['assets/images/style_stussy.jpg', 'assets/images/style_uzi.jpg', 'assets/images/style_90s.jpg', 'assets/images/style_toon.jpg'],
          ),
          const StyleModel(
            id: '90s',
            name: '90s Style',
            imagePath: 'assets/images/style_90s.jpg',
            isTrending: true,
            description: 'Nostalgic retro analog look with warm color grading, chromatic aberration, and classic film grain.',
            examples: ['assets/images/style_90s.jpg', 'assets/images/style_ps2.jpg', 'assets/images/style_stussy.jpg', 'assets/images/style_arabic.jpg'],
          ),
          const StyleModel(
            id: 'toon',
            name: 'Toon Style',
            imagePath: 'assets/images/style_toon.jpg',
            isTrending: true,
            description: 'Whimsical 3D animated character design style with soft clay rendering and vibrant, friendly colors.',
            examples: ['assets/images/style_toon.jpg', 'assets/images/style_uzi.jpg', 'assets/images/style_stussy.jpg', 'assets/images/style_ps2.jpg'],
          ),
          const StyleModel(
            id: 'ps2',
            name: 'PS2 Style',
            imagePath: 'assets/images/style_ps2.jpg',
            isTrending: true,
            description: 'Nostalgic low-poly early 2000s console rendering with low-res textures, scanlines, and nostalgic gaming vibes.',
            examples: ['assets/images/style_ps2.jpg', 'assets/images/style_90s.jpg', 'assets/images/style_uzi.jpg', 'assets/images/style_arabic.jpg'],
          ),
          const StyleModel(
            id: 'uzi',
            name: 'Uzi Style',
            imagePath: 'assets/images/style_uzi.jpg',
            isTrending: true,
            description: 'Cyberpunk hip-hop fusion style with glowing neon overlays, dark undertones, and bold futuristic elements.',
            examples: ['assets/images/style_uzi.jpg', 'assets/images/style_toon.jpg', 'assets/images/style_stussy.jpg', 'assets/images/style_ps2.jpg'],
          ),
        ],
      ),
      CategoryModel(
        id: 'couples',
        name: 'Couples Styles',
        styles: [
          const StyleModel(
            id: 'couple_romantic',
            name: 'Romantic Glow',
            imagePath: 'assets/images/style_90s.jpg',
            isPro: true,
            description: 'Soft warm tones, bokeh lights, and a dreamy haze that wraps two people in golden-hour intimacy.',
            examples: ['assets/images/style_90s.jpg', 'assets/images/style_arabic.jpg', 'assets/images/style_toon.jpg', 'assets/images/style_stussy.jpg'],
          ),
          const StyleModel(
            id: 'couple_anime',
            name: 'Anime Duo',
            imagePath: 'assets/images/style_toon.jpg',
            isPro: true,
            description: 'Transform your couple photo into a vibrant anime scene with cherry blossoms and cel-shaded lines.',
            examples: ['assets/images/style_toon.jpg', 'assets/images/style_90s.jpg', 'assets/images/style_uzi.jpg', 'assets/images/style_ps2.jpg'],
          ),
          const StyleModel(
            id: 'couple_vintage',
            name: 'Vintage Pair',
            imagePath: 'assets/images/style_stussy.jpg',
            isPro: true,
            description: 'Old Hollywood glamour with sepia washes, soft vignettes, and classic film-stock grain for two.',
            examples: ['assets/images/style_stussy.jpg', 'assets/images/style_90s.jpg', 'assets/images/style_arabic.jpg', 'assets/images/style_ps2.jpg'],
          ),
          const StyleModel(
            id: 'couple_comic',
            name: 'Comic Love',
            imagePath: 'assets/images/style_uzi.jpg',
            isPro: true,
            description: 'Bold pop-art comic panels with halftone dots, speech bubbles, and vivid superhero-poster colors.',
            examples: ['assets/images/style_uzi.jpg', 'assets/images/style_toon.jpg', 'assets/images/style_stussy.jpg', 'assets/images/style_90s.jpg'],
          ),
        ],
      ),
      CategoryModel(
        id: 'fantasy',
        name: 'Fantasy Styles',
        styles: [
          const StyleModel(
            id: 'fantasy_elf',
            name: 'Elven Portrait',
            imagePath: 'assets/images/style_arabic.jpg',
            isPro: true,
            description: 'Enchanted forest lighting with pointed-ear overlays, mystical runes, and ethereal bloom effects.',
            examples: ['assets/images/style_arabic.jpg', 'assets/images/style_toon.jpg', 'assets/images/style_ps2.jpg', 'assets/images/style_uzi.jpg'],
          ),
          const StyleModel(
            id: 'fantasy_dragon',
            name: 'Dragon Rider',
            imagePath: 'assets/images/style_uzi.jpg',
            isPro: true,
            description: 'Epic cinematic composition with fire-breathing dragon silhouettes, smoldering embers, and dark skies.',
            examples: ['assets/images/style_uzi.jpg', 'assets/images/style_arabic.jpg', 'assets/images/style_stussy.jpg', 'assets/images/style_ps2.jpg'],
          ),
          const StyleModel(
            id: 'fantasy_wizard',
            name: 'Wizard Academy',
            imagePath: 'assets/images/style_ps2.jpg',
            isPro: true,
            description: 'Magical school aesthetic with floating candles, spell particles, enchanted robes, and gothic arches.',
            examples: ['assets/images/style_ps2.jpg', 'assets/images/style_toon.jpg', 'assets/images/style_90s.jpg', 'assets/images/style_stussy.jpg'],
          ),
          const StyleModel(
            id: 'fantasy_fairy',
            name: 'Fairy Garden',
            imagePath: 'assets/images/style_toon.jpg',
            isPro: true,
            description: 'Whimsical miniature world with glowing wings, flower crowns, soft pastel palette, and sparkle dust.',
            examples: ['assets/images/style_toon.jpg', 'assets/images/style_90s.jpg', 'assets/images/style_arabic.jpg', 'assets/images/style_uzi.jpg'],
          ),
        ],
      ),
      CategoryModel(
        id: 'vintage',
        name: 'Vintage Styles',
        styles: [
          const StyleModel(
            id: 'vintage_polaroid',
            name: 'Polaroid',
            imagePath: 'assets/images/style_90s.jpg',
            isPro: true,
            description: 'Instant-camera look with white borders, faded colors, light leaks, and that authentic throwback feel.',
            examples: ['assets/images/style_90s.jpg', 'assets/images/style_stussy.jpg', 'assets/images/style_arabic.jpg', 'assets/images/style_toon.jpg'],
          ),
          const StyleModel(
            id: 'vintage_film',
            name: 'Film Noir',
            imagePath: 'assets/images/style_ps2.jpg',
            isPro: true,
            description: 'Classic black-and-white detective era with harsh shadows, venetian blinds light, and cigarette smoke.',
            examples: ['assets/images/style_ps2.jpg', 'assets/images/style_90s.jpg', 'assets/images/style_uzi.jpg', 'assets/images/style_arabic.jpg'],
          ),
          const StyleModel(
            id: 'vintage_70s',
            name: '70s Retro',
            imagePath: 'assets/images/style_stussy.jpg',
            isPro: true,
            description: 'Groovy sunburnt tones, oversaturated oranges and browns, disco shimmer, and grainy 35mm texture.',
            examples: ['assets/images/style_stussy.jpg', 'assets/images/style_90s.jpg', 'assets/images/style_toon.jpg', 'assets/images/style_uzi.jpg'],
          ),
          const StyleModel(
            id: 'vintage_daguerreotype',
            name: 'Daguerreotype',
            imagePath: 'assets/images/style_arabic.jpg',
            isPro: true,
            description: 'The earliest photographic process look with silvered surfaces, mirror-like sheen, and antique framing.',
            examples: ['assets/images/style_arabic.jpg', 'assets/images/style_ps2.jpg', 'assets/images/style_90s.jpg', 'assets/images/style_stussy.jpg'],
          ),
        ],
      ),
      CategoryModel(
        id: 'moody',
        name: 'Moody Styles',
        styles: [
          const StyleModel(
            id: 'dark_gothic',
            name: 'Gothic',
            imagePath: 'assets/images/style_uzi.jpg',
            isPro: true,
            description: 'Dark cathedral aesthetic with deep blacks, crimson accents, ornate architecture, and vampiric allure.',
            examples: ['assets/images/style_uzi.jpg', 'assets/images/style_ps2.jpg', 'assets/images/style_arabic.jpg', 'assets/images/style_stussy.jpg'],
          ),
          const StyleModel(
            id: 'dark_grunge',
            name: 'Grunge',
            imagePath: 'assets/images/style_stussy.jpg',
            isPro: true,
            description: 'Raw 90s Seattle grunge with torn paper textures, desaturated palette, heavy grain, and rebel energy.',
            examples: ['assets/images/style_stussy.jpg', 'assets/images/style_uzi.jpg', 'assets/images/style_90s.jpg', 'assets/images/style_ps2.jpg'],
          ),
          const StyleModel(
            id: 'dark_horror',
            name: 'Horror',
            imagePath: 'assets/images/style_ps2.jpg',
            isPro: true,
            description: 'Creepy atmospheric horror with VHS static, distorted faces, eerie green tint, and found-footage feel.',
            examples: ['assets/images/style_ps2.jpg', 'assets/images/style_uzi.jpg', 'assets/images/style_stussy.jpg', 'assets/images/style_toon.jpg'],
          ),
          const StyleModel(
            id: 'dark_shadow',
            name: 'Shadow Art',
            imagePath: 'assets/images/style_arabic.jpg',
            isPro: true,
            description: 'Dramatic silhouette art with deep contrast, rim lighting, smoke effects, and cinematic mystery.',
            examples: ['assets/images/style_arabic.jpg', 'assets/images/style_uzi.jpg', 'assets/images/style_ps2.jpg', 'assets/images/style_90s.jpg'],
          ),
        ],
      ),
      CategoryModel(
        id: 'arabic',
        name: 'Arabic Styles',
        styles: [
          const StyleModel(
            id: 'syrian',
            name: 'Syrian Style',
            imagePath: 'assets/images/style_arabic.jpg',
            isTrending: true,
            description: 'A dramatic Arabic portrait look with red veils, grain, bold contrast, and editorial poster energy.',
            examples: ['assets/images/style_arabic.jpg', 'assets/images/style_90s.jpg', 'assets/images/style_stussy.jpg', 'assets/images/style_ps2.jpg'],
          ),
          const StyleModel(
            id: 'arab_style',
            name: 'Arab Style',
            imagePath: 'assets/images/style_90s.jpg',
            isTrending: true,
            description: 'A monochrome heritage-inspired portrait style with wrapped fabric, harsh texture, and cinematic light.',
            examples: ['assets/images/style_90s.jpg', 'assets/images/style_arabic.jpg', 'assets/images/style_uzi.jpg', 'assets/images/style_ps2.jpg'],
          ),
          const StyleModel(
            id: 'mor_style',
            name: 'Mor Style',
            imagePath: 'assets/images/style_stussy.jpg',
            description: 'A skull-and-keffiyeh poster aesthetic with sharp graphic texture and rugged desert tones.',
            examples: ['assets/images/style_stussy.jpg', 'assets/images/style_arabic.jpg', 'assets/images/style_90s.jpg', 'assets/images/style_uzi.jpg'],
          ),
          const StyleModel(
            id: 'eyes',
            name: 'Eyes Style',
            imagePath: 'assets/images/style_ps2.jpg',
            description: 'A mysterious veiled portrait treatment focused on eyes, muted film grain, and soft shadow.',
            examples: ['assets/images/style_ps2.jpg', 'assets/images/style_arabic.jpg', 'assets/images/style_90s.jpg', 'assets/images/style_toon.jpg'],
          ),
        ],
      ),
      CategoryModel(
        id: 'more',
        name: 'More Styles',
        styles: [
          const StyleModel(
            id: 'oil_paint',
            name: 'Oil Paint',
            imagePath: 'assets/images/style_toon.jpg',
            description: 'Classic expressive brush strokes and rich textures of renaissance and modern oil paintings.',
            examples: ['assets/images/style_toon.jpg', 'assets/images/style_uzi.jpg', 'assets/images/style_stussy.jpg', 'assets/images/style_ps2.jpg'],
          ),
          const StyleModel(
            id: 'vaporwave',
            name: 'Vaporwave',
            imagePath: 'assets/images/style_uzi.jpg',
            description: 'Surreal retro-futuristic aesthetic with neon pinks, cyans, glitch effects, and 80s mall culture motifs.',
            examples: ['assets/images/style_uzi.jpg', 'assets/images/style_toon.jpg', 'assets/images/style_stussy.jpg', 'assets/images/style_ps2.jpg'],
          ),
          const StyleModel(
            id: 'noir',
            name: 'Noir Style',
            imagePath: 'assets/images/style_ps2.jpg',
            description: 'Dramatic high-contrast black and white cinematic lighting with moody atmospheres and mystery.',
            examples: ['assets/images/style_ps2.jpg', 'assets/images/style_90s.jpg', 'assets/images/style_uzi.jpg', 'assets/images/style_arabic.jpg'],
          ),
          const StyleModel(
            id: 'anime',
            name: 'Anime Style',
            imagePath: 'assets/images/style_toon.jpg',
            description: 'Vibrant hand-drawn Japanese animation style with clean line-art and gorgeous sky backdrops.',
            examples: ['assets/images/style_toon.jpg', 'assets/images/style_uzi.jpg', 'assets/images/style_stussy.jpg', 'assets/images/style_ps2.jpg'],
          ),
          const StyleModel(
            id: 'cyberpunk',
            name: 'Cyberpunk',
            imagePath: 'assets/images/style_arabic.jpg',
            description: 'Dystopian high-tech, low-life metropolis aesthetics with rain-slicked streets and neon illumination.',
            examples: ['assets/images/style_arabic.jpg', 'assets/images/style_stussy.jpg', 'assets/images/style_90s.jpg', 'assets/images/style_ps2.jpg'],
          ),
          const StyleModel(
            id: 'renaissance',
            name: 'Renaissance',
            imagePath: 'assets/images/style_stussy.jpg',
            description: 'Masterful dramatic chiaroscuro lighting and classical portraiture composition of the high renaissance.',
            examples: ['assets/images/style_stussy.jpg', 'assets/images/style_uzi.jpg', 'assets/images/style_90s.jpg', 'assets/images/style_toon.jpg'],
          ),
        ],
      ),
    ];
  }
}
