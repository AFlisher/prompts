import 'style_model.dart';
import 'style_field.dart';

class Style {
  final String id;
  final String name;
  final String categoryId;
  final String prompt;
  final String? negativePrompt;
  final int creditCost;
  final String coverImage;

  /// ~320x400 WebP browsing thumbnail. Null for styles the backfill/upload
  /// pipeline hasn't generated one for yet - callers should fall back to
  /// [coverImage] in that case (see [StyleModel.displayThumbnail]).
  final String? coverImageThumbnail;
  final bool isTrending;
  final bool isPremium;
  final bool isEnabled;
  final int sortOrder;
  final List<StyleField> fields;

  /// How many source photos this style needs (defaults 1/1 - classic
  /// single-image styles and older backend responses are unaffected).
  final int minImages;
  final int maxImages;

  Style({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.prompt,
    this.negativePrompt,
    required this.creditCost,
    required this.coverImage,
    this.coverImageThumbnail,
    required this.isTrending,
    required this.isPremium,
    required this.isEnabled,
    required this.sortOrder,
    this.fields = const [],
    this.minImages = 1,
    this.maxImages = 1,
  });

  factory Style.fromJson(Map<String, dynamic> json) {
    return Style(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      categoryId: json['categoryId'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      negativePrompt: json['negativePrompt'] as String?,
      creditCost: (json['creditCost'] as num?)?.toInt() ?? 1,
      coverImage: json['coverImage'] as String? ?? '',
      coverImageThumbnail: json['coverImageThumbnail'] as String?,
      isTrending: json['isTrending'] as bool? ?? false,
      isPremium: json['isPremium'] as bool? ?? false,
      isEnabled: json['isEnabled'] as bool? ?? true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      fields: StyleField.listFromJson(json['fields']),
      minImages: (json['minImages'] as num?)?.toInt() ?? 1,
      maxImages: (json['maxImages'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'categoryId': categoryId,
      'prompt': prompt,
      'negativePrompt': negativePrompt,
      'creditCost': creditCost,
      'coverImage': coverImage,
      'coverImageThumbnail': coverImageThumbnail,
      'isTrending': isTrending,
      'isPremium': isPremium,
      'isEnabled': isEnabled,
      'sortOrder': sortOrder,
      'fields': fields.map((f) => f.toJson()).toList(),
      'minImages': minImages,
      'maxImages': maxImages,
    };
  }

  /// Helper to convert backend Style to legacy UI StyleModel.
  StyleModel toStyleModel() {
    return StyleModel(
      id: id,
      name: name,
      imagePath: coverImage,
      imageUrl: coverImage,
      thumbnailUrl: coverImageThumbnail,
      isTrending: isTrending,
      isPro: isPremium,
      prompt: prompt,
      sortOrder: sortOrder,
      description: prompt,
      examples: const [],
      creditCost: creditCost,
      fields: fields,
      minImages: minImages,
      maxImages: maxImages,
    );
  }
}
