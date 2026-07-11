import 'style_model.dart';

class Style {
  final String id;
  final String name;
  final String categoryId;
  final String prompt;
  final String? negativePrompt;
  final int creditCost;
  final String coverImage;
  final bool isTrending;
  final bool isPremium;
  final bool isEnabled;
  final int sortOrder;

  Style({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.prompt,
    this.negativePrompt,
    required this.creditCost,
    required this.coverImage,
    required this.isTrending,
    required this.isPremium,
    required this.isEnabled,
    required this.sortOrder,
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
      isTrending: json['isTrending'] as bool? ?? false,
      isPremium: json['isPremium'] as bool? ?? false,
      isEnabled: json['isEnabled'] as bool? ?? true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
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
      'isTrending': isTrending,
      'isPremium': isPremium,
      'isEnabled': isEnabled,
      'sortOrder': sortOrder,
    };
  }

  /// Helper to convert backend Style to legacy UI StyleModel.
  StyleModel toStyleModel() {
    return StyleModel(
      id: id,
      name: name,
      imagePath: coverImage,
      imageUrl: coverImage,
      isTrending: isTrending,
      isPro: isPremium,
      prompt: prompt,
      sortOrder: sortOrder,
      description: prompt,
      examples: const [],
      creditCost: creditCost,
    );
  }
}
