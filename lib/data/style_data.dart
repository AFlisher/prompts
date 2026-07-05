import '../models/style_model.dart';

class StyleData {
  static List<StyleModel> _arabicStyles = _defaultArabicStyles;
  static List<StyleModel> _trendingStyles = _defaultTrendingStyles;
  static List<StyleModel> _moreStyles = _defaultMoreStyles;
  static List<StyleModel> _couplesStyles = _defaultCouplesStyles;
  static List<StyleModel> _fantasyStyles = _defaultFantasyStyles;
  static List<StyleModel> _vintageStyles = _defaultVintageStyles;
  static List<StyleModel> _darkMoodyStyles = _defaultDarkMoodyStyles;

  static List<StyleModel> get arabicStyles => _arabicStyles;
  static List<StyleModel> get trendingStyles => _trendingStyles;
  static List<StyleModel> get moreStyles => _moreStyles;
  static List<StyleModel> get couplesStyles => _couplesStyles;
  static List<StyleModel> get fantasyStyles => _fantasyStyles;
  static List<StyleModel> get vintageStyles => _vintageStyles;
  static List<StyleModel> get darkMoodyStyles => _darkMoodyStyles;

  static List<StyleModel> get allStyles => [
        ..._trendingStyles,
        ..._moreStyles,
        ..._couplesStyles,
        ..._fantasyStyles,
        ..._vintageStyles,
        ..._darkMoodyStyles,
      ];

  static void updateStyles({
    List<StyleModel>? arabicStyles,
    List<StyleModel>? trendingStyles,
    List<StyleModel>? moreStyles,
    List<StyleModel>? couplesStyles,
    List<StyleModel>? fantasyStyles,
    List<StyleModel>? vintageStyles,
    List<StyleModel>? darkMoodyStyles,
  }) {
    if (arabicStyles != null) _arabicStyles = arabicStyles;
    if (trendingStyles != null) _trendingStyles = trendingStyles;
    if (moreStyles != null) _moreStyles = moreStyles;
    if (couplesStyles != null) _couplesStyles = couplesStyles;
    if (fantasyStyles != null) _fantasyStyles = fantasyStyles;
    if (vintageStyles != null) _vintageStyles = vintageStyles;
    if (darkMoodyStyles != null) _darkMoodyStyles = darkMoodyStyles;
  }

  static const _defaultArabicStyles = [
    StyleModel(
      id: 'syrian',
      name: 'Syrian Style',
      imagePath: 'assets/images/style_arabic.jpg',
      isTrending: true,
      description:
          'A dramatic Arabic portrait look with red veils, grain, bold contrast, and editorial poster energy.',
      examples: [
        'assets/images/style_arabic.jpg',
        'assets/images/style_90s.jpg',
        'assets/images/style_stussy.jpg',
        'assets/images/style_ps2.jpg',
      ],
    ),
    StyleModel(
      id: 'arab_style',
      name: 'Arab Style',
      imagePath: 'assets/images/style_90s.jpg',
      isTrending: true,
      description:
          'A monochrome heritage-inspired portrait style with wrapped fabric, harsh texture, and cinematic light.',
      examples: [
        'assets/images/style_90s.jpg',
        'assets/images/style_arabic.jpg',
        'assets/images/style_uzi.jpg',
        'assets/images/style_ps2.jpg',
      ],
    ),
    StyleModel(
      id: 'mor_style',
      name: 'Mor Style',
      imagePath: 'assets/images/style_stussy.jpg',
      description:
          'A skull-and-keffiyeh poster aesthetic with sharp graphic texture and rugged desert tones.',
      examples: [
        'assets/images/style_stussy.jpg',
        'assets/images/style_arabic.jpg',
        'assets/images/style_90s.jpg',
        'assets/images/style_uzi.jpg',
      ],
    ),
    StyleModel(
      id: 'eyes',
      name: 'Eyes Style',
      imagePath: 'assets/images/style_ps2.jpg',
      description:
          'A mysterious veiled portrait treatment focused on eyes, muted film grain, and soft shadow.',
      examples: [
        'assets/images/style_ps2.jpg',
        'assets/images/style_arabic.jpg',
        'assets/images/style_90s.jpg',
        'assets/images/style_toon.jpg',
      ],
    ),
    StyleModel(
      id: 'don',
      name: 'Don Style',
      imagePath: 'assets/images/style_uzi.jpg',
      description:
          'A confident travel-photo look with uniform details, candid flash, and bold social avatar framing.',
      examples: [
        'assets/images/style_uzi.jpg',
        'assets/images/style_stussy.jpg',
        'assets/images/style_arabic.jpg',
        'assets/images/style_toon.jpg',
      ],
    ),
    StyleModel(
      id: 'pixels_arabic',
      name: 'Pixels Style',
      imagePath: 'assets/images/style_toon.jpg',
      description:
          'A pixel-art Arabic character style with simplified shapes, blocky texture, and retro game charm.',
      examples: [
        'assets/images/style_toon.jpg',
        'assets/images/style_ps2.jpg',
        'assets/images/style_arabic.jpg',
        'assets/images/style_90s.jpg',
      ],
    ),
  ];

  static const _defaultTrendingStyles = [
    StyleModel(
      id: 'arabic',
      name: 'Arabic Style',
      imagePath: 'assets/images/style_arabic.jpg',
      isTrending: true,
      description:
          'A cinematic Arabic-inspired visual style with dramatic lighting, bold colors and vintage aesthetics.',
      examples: [
        'assets/images/style_arabic.jpg',
        'assets/images/style_stussy.jpg',
        'assets/images/style_90s.jpg',
        'assets/images/style_ps2.jpg',
      ],
    ),
    StyleModel(
      id: 'stussy',
      name: 'Stussy Style',
      imagePath: 'assets/images/style_stussy.jpg',
      isTrending: true,
      description:
          'Urban street-fashion inspired aesthetic featuring high-contrast graphics, grainy filters, and skate culture vibes.',
      examples: [
        'assets/images/style_stussy.jpg',
        'assets/images/style_uzi.jpg',
        'assets/images/style_90s.jpg',
        'assets/images/style_toon.jpg',
      ],
    ),
    StyleModel(
      id: '90s',
      name: '90s Style',
      imagePath: 'assets/images/style_90s.jpg',
      isTrending: true,
      description:
          'Nostalgic retro analog look with warm color grading, chromatic aberration, and classic film grain.',
      examples: [
        'assets/images/style_90s.jpg',
        'assets/images/style_ps2.jpg',
        'assets/images/style_stussy.jpg',
        'assets/images/style_arabic.jpg',
      ],
    ),
    StyleModel(
      id: 'toon',
      name: 'Toon Style',
      imagePath: 'assets/images/style_toon.jpg',
      isTrending: true,
      description:
          'Whimsical 3D animated character design style with soft clay rendering and vibrant, friendly colors.',
      examples: [
        'assets/images/style_toon.jpg',
        'assets/images/style_uzi.jpg',
        'assets/images/style_stussy.jpg',
        'assets/images/style_ps2.jpg',
      ],
    ),
    StyleModel(
      id: 'ps2',
      name: 'PS2 Style',
      imagePath: 'assets/images/style_ps2.jpg',
      isTrending: true,
      description:
          'Nostalgic low-poly early 2000s console rendering with low-res textures, scanlines, and nostalgic gaming vibes.',
      examples: [
        'assets/images/style_ps2.jpg',
        'assets/images/style_90s.jpg',
        'assets/images/style_uzi.jpg',
        'assets/images/style_arabic.jpg',
      ],
    ),
    StyleModel(
      id: 'uzi',
      name: 'Uzi Style',
      imagePath: 'assets/images/style_uzi.jpg',
      isTrending: true,
      description:
          'Cyberpunk hip-hop fusion style with glowing neon overlays, dark undertones, and bold futuristic elements.',
      examples: [
        'assets/images/style_uzi.jpg',
        'assets/images/style_toon.jpg',
        'assets/images/style_stussy.jpg',
        'assets/images/style_ps2.jpg',
      ],
    ),
    StyleModel(
      id: 'minecraft',
      name: 'Minecraft Style',
      imagePath: 'assets/images/style_toon.jpg',
      isTrending: true,
      description:
          'Blocky, retro-voxel pixel art aesthetic reminiscent of classic sandbox building games.',
      examples: [
        'assets/images/style_toon.jpg',
        'assets/images/style_stussy.jpg',
        'assets/images/style_90s.jpg',
        'assets/images/style_ps2.jpg',
      ],
    ),
    StyleModel(
      id: 'pixels',
      name: 'Pixels Style',
      imagePath: 'assets/images/style_ps2.jpg',
      isTrending: true,
      description:
          'Charming 8-bit retro pixel style, rendering scenes into beautifully simplified mosaic graphics.',
      examples: [
        'assets/images/style_ps2.jpg',
        'assets/images/style_uzi.jpg',
        'assets/images/style_90s.jpg',
        'assets/images/style_toon.jpg',
      ],
    ),
    StyleModel(
      id: 'sticky',
      name: 'Sticky Style',
      imagePath: 'assets/images/style_90s.jpg',
      isTrending: true,
      description:
          'Creative cutout paper sticker collage style with thick white outlines and vibrant pop-art elements.',
      examples: [
        'assets/images/style_90s.jpg',
        'assets/images/style_ps2.jpg',
        'assets/images/style_stussy.jpg',
        'assets/images/style_arabic.jpg',
      ],
    ),
  ];

  static const _defaultMoreStyles = [
    StyleModel(
      id: 'uzi_more',
      name: 'Uzi Style',
      imagePath: 'assets/images/style_uzi.jpg',
      description:
          'Cyberpunk hip-hop fusion style with glowing neon overlays, dark undertones, and bold futuristic elements.',
      examples: [
        'assets/images/style_uzi.jpg',
        'assets/images/style_toon.jpg',
        'assets/images/style_stussy.jpg',
        'assets/images/style_ps2.jpg',
      ],
    ),
    StyleModel(
      id: 'sticky_more',
      name: 'Sticky Style',
      imagePath: 'assets/images/style_90s.jpg',
      description:
          'Creative cutout paper sticker collage style with thick white outlines and vibrant pop-art elements.',
      examples: [
        'assets/images/style_90s.jpg',
        'assets/images/style_ps2.jpg',
        'assets/images/style_stussy.jpg',
        'assets/images/style_arabic.jpg',
      ],
    ),
    StyleModel(
      id: 'oil_paint',
      name: 'Oil Paint',
      imagePath: 'assets/images/style_toon.jpg',
      description:
          'Classic expressive brush strokes and rich textures of renaissance and modern oil paintings.',
      examples: [
        'assets/images/style_toon.jpg',
        'assets/images/style_uzi.jpg',
        'assets/images/style_stussy.jpg',
        'assets/images/style_ps2.jpg',
      ],
    ),
    StyleModel(
      id: 'vaporwave',
      name: 'Vaporwave',
      imagePath: 'assets/images/style_uzi.jpg',
      description:
          'Surreal retro-futuristic aesthetic with neon pinks, cyans, glitch effects, and 80s mall culture motifs.',
      examples: [
        'assets/images/style_uzi.jpg',
        'assets/images/style_toon.jpg',
        'assets/images/style_stussy.jpg',
        'assets/images/style_ps2.jpg',
      ],
    ),
    StyleModel(
      id: 'noir',
      name: 'Noir Style',
      imagePath: 'assets/images/style_ps2.jpg',
      description:
          'Dramatic high-contrast black and white cinematic lighting with moody atmospheres and mystery.',
      examples: [
        'assets/images/style_ps2.jpg',
        'assets/images/style_90s.jpg',
        'assets/images/style_uzi.jpg',
        'assets/images/style_arabic.jpg',
      ],
    ),
    StyleModel(
      id: 'anime',
      name: 'Anime Style',
      imagePath: 'assets/images/style_toon.jpg',
      description:
          'Vibrant hand-drawn Japanese animation style with clean line-art and gorgeous sky backdrops.',
      examples: [
        'assets/images/style_toon.jpg',
        'assets/images/style_uzi.jpg',
        'assets/images/style_stussy.jpg',
        'assets/images/style_ps2.jpg',
      ],
    ),
    StyleModel(
      id: 'cyberpunk',
      name: 'Cyberpunk',
      imagePath: 'assets/images/style_arabic.jpg',
      description:
          'Dystopian high-tech, low-life metropolis aesthetics with rain-slicked streets and neon illumination.',
      examples: [
        'assets/images/style_arabic.jpg',
        'assets/images/style_stussy.jpg',
        'assets/images/style_90s.jpg',
        'assets/images/style_ps2.jpg',
      ],
    ),
    StyleModel(
      id: 'renaissance',
      name: 'Renaissance',
      imagePath: 'assets/images/style_stussy.jpg',
      description:
          'Masterful dramatic chiaroscuro lighting and classical portraiture composition of the high renaissance.',
      examples: [
        'assets/images/style_stussy.jpg',
        'assets/images/style_uzi.jpg',
        'assets/images/style_90s.jpg',
        'assets/images/style_toon.jpg',
      ],
    ),
  ];

  // ── Couples Styles ──────────────────────────────────────────────
  static const _defaultCouplesStyles = [
    StyleModel(
      id: 'couple_romantic',
      name: 'Romantic Glow',
      imagePath: 'assets/images/style_90s.jpg',
      description:
          'Soft warm tones, bokeh lights, and a dreamy haze that wraps two people in golden-hour intimacy.',
      examples: [
        'assets/images/style_90s.jpg',
        'assets/images/style_arabic.jpg',
        'assets/images/style_toon.jpg',
        'assets/images/style_stussy.jpg',
      ],
    ),
    StyleModel(
      id: 'couple_anime',
      name: 'Anime Duo',
      imagePath: 'assets/images/style_toon.jpg',
      description:
          'Transform your couple photo into a vibrant anime scene with cherry blossoms and cel-shaded lines.',
      examples: [
        'assets/images/style_toon.jpg',
        'assets/images/style_90s.jpg',
        'assets/images/style_uzi.jpg',
        'assets/images/style_ps2.jpg',
      ],
    ),
    StyleModel(
      id: 'couple_vintage',
      name: 'Vintage Pair',
      imagePath: 'assets/images/style_stussy.jpg',
      description:
          'Old Hollywood glamour with sepia washes, soft vignettes, and classic film-stock grain for two.',
      examples: [
        'assets/images/style_stussy.jpg',
        'assets/images/style_90s.jpg',
        'assets/images/style_arabic.jpg',
        'assets/images/style_ps2.jpg',
      ],
    ),
    StyleModel(
      id: 'couple_comic',
      name: 'Comic Love',
      imagePath: 'assets/images/style_uzi.jpg',
      description:
          'Bold pop-art comic panels with halftone dots, speech bubbles, and vivid superhero-poster colors.',
      examples: [
        'assets/images/style_uzi.jpg',
        'assets/images/style_toon.jpg',
        'assets/images/style_stussy.jpg',
        'assets/images/style_90s.jpg',
      ],
    ),
  ];

  // ── Fantasy Styles ──────────────────────────────────────────────
  static const _defaultFantasyStyles = [
    StyleModel(
      id: 'fantasy_elf',
      name: 'Elven Portrait',
      imagePath: 'assets/images/style_arabic.jpg',
      description:
          'Enchanted forest lighting with pointed-ear overlays, mystical runes, and ethereal bloom effects.',
      examples: [
        'assets/images/style_arabic.jpg',
        'assets/images/style_toon.jpg',
        'assets/images/style_ps2.jpg',
        'assets/images/style_uzi.jpg',
      ],
    ),
    StyleModel(
      id: 'fantasy_dragon',
      name: 'Dragon Rider',
      imagePath: 'assets/images/style_uzi.jpg',
      description:
          'Epic cinematic composition with fire-breathing dragon silhouettes, smoldering embers, and dark skies.',
      examples: [
        'assets/images/style_uzi.jpg',
        'assets/images/style_arabic.jpg',
        'assets/images/style_stussy.jpg',
        'assets/images/style_ps2.jpg',
      ],
    ),
    StyleModel(
      id: 'fantasy_wizard',
      name: 'Wizard Academy',
      imagePath: 'assets/images/style_ps2.jpg',
      description:
          'Magical school aesthetic with floating candles, spell particles, enchanted robes, and gothic arches.',
      examples: [
        'assets/images/style_ps2.jpg',
        'assets/images/style_toon.jpg',
        'assets/images/style_90s.jpg',
        'assets/images/style_stussy.jpg',
      ],
    ),
    StyleModel(
      id: 'fantasy_fairy',
      name: 'Fairy Garden',
      imagePath: 'assets/images/style_toon.jpg',
      description:
          'Whimsical miniature world with glowing wings, flower crowns, soft pastel palette, and sparkle dust.',
      examples: [
        'assets/images/style_toon.jpg',
        'assets/images/style_90s.jpg',
        'assets/images/style_arabic.jpg',
        'assets/images/style_uzi.jpg',
      ],
    ),
  ];

  // ── Vintage Styles ──────────────────────────────────────────────
  static const _defaultVintageStyles = [
    StyleModel(
      id: 'vintage_polaroid',
      name: 'Polaroid',
      imagePath: 'assets/images/style_90s.jpg',
      description:
          'Instant-camera look with white borders, faded colors, light leaks, and that authentic throwback feel.',
      examples: [
        'assets/images/style_90s.jpg',
        'assets/images/style_stussy.jpg',
        'assets/images/style_arabic.jpg',
        'assets/images/style_toon.jpg',
      ],
    ),
    StyleModel(
      id: 'vintage_film',
      name: 'Film Noir',
      imagePath: 'assets/images/style_ps2.jpg',
      description:
          'Classic black-and-white detective era with harsh shadows, venetian blinds light, and cigarette smoke.',
      examples: [
        'assets/images/style_ps2.jpg',
        'assets/images/style_90s.jpg',
        'assets/images/style_uzi.jpg',
        'assets/images/style_arabic.jpg',
      ],
    ),
    StyleModel(
      id: 'vintage_70s',
      name: '70s Retro',
      imagePath: 'assets/images/style_stussy.jpg',
      description:
          'Groovy sunburnt tones, oversaturated oranges and browns, disco shimmer, and grainy 35mm texture.',
      examples: [
        'assets/images/style_stussy.jpg',
        'assets/images/style_90s.jpg',
        'assets/images/style_toon.jpg',
        'assets/images/style_uzi.jpg',
      ],
    ),
    StyleModel(
      id: 'vintage_daguerreotype',
      name: 'Daguerreotype',
      imagePath: 'assets/images/style_arabic.jpg',
      description:
          'The earliest photographic process look with silvered surfaces, mirror-like sheen, and antique framing.',
      examples: [
        'assets/images/style_arabic.jpg',
        'assets/images/style_ps2.jpg',
        'assets/images/style_90s.jpg',
        'assets/images/style_stussy.jpg',
      ],
    ),
  ];

  // ── Dark & Moody Styles ─────────────────────────────────────────
  static const _defaultDarkMoodyStyles = [
    StyleModel(
      id: 'dark_gothic',
      name: 'Gothic',
      imagePath: 'assets/images/style_uzi.jpg',
      description:
          'Dark cathedral aesthetic with deep blacks, crimson accents, ornate architecture, and vampiric allure.',
      examples: [
        'assets/images/style_uzi.jpg',
        'assets/images/style_ps2.jpg',
        'assets/images/style_arabic.jpg',
        'assets/images/style_stussy.jpg',
      ],
    ),
    StyleModel(
      id: 'dark_grunge',
      name: 'Grunge',
      imagePath: 'assets/images/style_stussy.jpg',
      description:
          'Raw 90s Seattle grunge with torn paper textures, desaturated palette, heavy grain, and rebel energy.',
      examples: [
        'assets/images/style_stussy.jpg',
        'assets/images/style_uzi.jpg',
        'assets/images/style_90s.jpg',
        'assets/images/style_ps2.jpg',
      ],
    ),
    StyleModel(
      id: 'dark_horror',
      name: 'Horror',
      imagePath: 'assets/images/style_ps2.jpg',
      description:
          'Creepy atmospheric horror with VHS static, distorted faces, eerie green tint, and found-footage feel.',
      examples: [
        'assets/images/style_ps2.jpg',
        'assets/images/style_uzi.jpg',
        'assets/images/style_stussy.jpg',
        'assets/images/style_toon.jpg',
      ],
    ),
    StyleModel(
      id: 'dark_shadow',
      name: 'Shadow Art',
      imagePath: 'assets/images/style_arabic.jpg',
      description:
          'Dramatic silhouette art with deep contrast, rim lighting, smoke effects, and cinematic mystery.',
      examples: [
        'assets/images/style_arabic.jpg',
        'assets/images/style_uzi.jpg',
        'assets/images/style_ps2.jpg',
        'assets/images/style_90s.jpg',
      ],
    ),
  ];
}
