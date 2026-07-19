import 'style_field.dart';

class StyleModel {
  final String id;
  final String name;
  final String imagePath;
  final String imageUrl;

  /// ~320x400 WebP browsing thumbnail. Null/empty until the backend has
  /// generated one (see [displayThumbnail] for the browsing-safe fallback).
  final String? thumbnailUrl;
  final bool isFavorite;
  final bool isTrending;
  final String description;
  final String prompt;
  final int sortOrder;
  final List<String> examples;
  final int creditCost;

  final bool isPro;

  /// Dynamic input fields the user must fill before generating with this style.
  /// Empty for classic styles (no placeholders) - fully backward compatible.
  final List<StyleField> fields;

  /// How many source photos the user must/can select (defaults 1/1, so
  /// classic single-image styles keep their exact current behavior).
  final int minImages;
  final int maxImages;

  const StyleModel({
    required this.id,
    required this.name,
    required this.imagePath,
    this.imageUrl = '',
    this.thumbnailUrl,
    this.isFavorite = false,
    this.isTrending = false,
    this.isPro = false,
    this.description = '',
    this.prompt = '',
    this.sortOrder = 0,
    this.examples = const [],
    this.creditCost = 1,
    this.fields = const [],
    this.minImages = 1,
    this.maxImages = 1,
  });

  /// Prefer remote URL when available; falls back to bundled asset path.
  String get displayImage => imageUrl.isNotEmpty ? imageUrl : imagePath;

  /// The small, browsing-optimized image every grid/list/card should render.
  /// Falls back to [displayImage] when no thumbnail exists yet (e.g. a style
  /// created before the thumbnail system, or before the backfill script has
  /// reached it) - so a browsing screen never has nothing to show.
  String get displayThumbnail =>
      (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) ? thumbnailUrl! : displayImage;

  StyleModel copyWith({bool? isFavorite, bool? isPro, int? creditCost}) {
    return StyleModel(
      id: id,
      name: name,
      imagePath: imagePath,
      imageUrl: imageUrl,
      thumbnailUrl: thumbnailUrl,
      isFavorite: isFavorite ?? this.isFavorite,
      isTrending: isTrending,
      isPro: isPro ?? this.isPro,
      description: description,
      prompt: prompt,
      sortOrder: sortOrder,
      examples: examples,
      creditCost: creditCost ?? this.creditCost,
      fields: fields,
      minImages: minImages,
      maxImages: maxImages,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
      'imageUrl': imageUrl,
      'thumbnailUrl': thumbnailUrl,
      'isFavorite': isFavorite,
      'isTrending': isTrending,
      'isPro': isPro,
      'description': description,
      'prompt': prompt,
      'sortOrder': sortOrder,
      'examples': examples,
      'creditCost': creditCost,
      'fields': fields.map((f) => f.toJson()).toList(),
      'minImages': minImages,
      'maxImages': maxImages,
    };
  }

  factory StyleModel.fromJson(Map<String, dynamic> json) {
    return StyleModel(
      id: json['id'] as String,
      name: json['name'] as String,
      imagePath: json['imagePath'] as String,
      imageUrl: (json['imageUrl'] as String?) ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      isFavorite: (json['isFavorite'] as bool?) ?? false,
      isTrending: (json['isTrending'] as bool?) ?? false,
      isPro: (json['isPro'] as bool?) ?? false,
      description: (json['description'] as String?) ?? '',
      prompt: (json['prompt'] as String?) ?? '',
      sortOrder: (json['sortOrder'] as int?) ?? 0,
      examples: (json['examples'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      creditCost: (json['creditCost'] as num?)?.toInt() ?? 1,
      fields: StyleField.listFromJson(json['fields']),
      minImages: (json['minImages'] as num?)?.toInt() ?? 1,
      maxImages: (json['maxImages'] as num?)?.toInt() ?? 1,
    );
  }
}
