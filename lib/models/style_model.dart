class StyleModel {
  final String id;
  final String name;
  final String imagePath;
  final String imageUrl;
  final bool isFavorite;
  final bool isTrending;
  final String description;
  final String prompt;
  final int sortOrder;
  final List<String> examples;

  final bool isPro;

  const StyleModel({
    required this.id,
    required this.name,
    required this.imagePath,
    this.imageUrl = '',
    this.isFavorite = false,
    this.isTrending = false,
    this.isPro = false,
    this.description = '',
    this.prompt = '',
    this.sortOrder = 0,
    this.examples = const [],
  });

  /// Prefer remote URL when available; falls back to bundled asset path.
  String get displayImage => imageUrl.isNotEmpty ? imageUrl : imagePath;

  StyleModel copyWith({bool? isFavorite, bool? isPro}) {
    return StyleModel(
      id: id,
      name: name,
      imagePath: imagePath,
      imageUrl: imageUrl,
      isFavorite: isFavorite ?? this.isFavorite,
      isTrending: isTrending,
      isPro: isPro ?? this.isPro,
      description: description,
      prompt: prompt,
      sortOrder: sortOrder,
      examples: examples,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
      'imageUrl': imageUrl,
      'isFavorite': isFavorite,
      'isTrending': isTrending,
      'isPro': isPro,
      'description': description,
      'prompt': prompt,
      'sortOrder': sortOrder,
      'examples': examples,
    };
  }

  factory StyleModel.fromJson(Map<String, dynamic> json) {
    return StyleModel(
      id: json['id'] as String,
      name: json['name'] as String,
      imagePath: json['imagePath'] as String,
      imageUrl: (json['imageUrl'] as String?) ?? '',
      isFavorite: (json['isFavorite'] as bool?) ?? false,
      isTrending: (json['isTrending'] as bool?) ?? false,
      isPro: (json['isPro'] as bool?) ?? false,
      description: (json['description'] as String?) ?? '',
      prompt: (json['prompt'] as String?) ?? '',
      sortOrder: (json['sortOrder'] as int?) ?? 0,
      examples: (json['examples'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
    );
  }
}
