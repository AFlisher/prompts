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

  const StyleModel({
    required this.id,
    required this.name,
    required this.imagePath,
    this.imageUrl = '',
    this.isFavorite = false,
    this.isTrending = false,
    this.description = '',
    this.prompt = '',
    this.sortOrder = 0,
    this.examples = const [],
  });

  /// Prefer remote URL when available; falls back to bundled asset path.
  String get displayImage => imageUrl.isNotEmpty ? imageUrl : imagePath;

  StyleModel copyWith({bool? isFavorite}) {
    return StyleModel(
      id: id,
      name: name,
      imagePath: imagePath,
      imageUrl: imageUrl,
      isFavorite: isFavorite ?? this.isFavorite,
      isTrending: isTrending,
      description: description,
      prompt: prompt,
      sortOrder: sortOrder,
      examples: examples,
    );
  }
}
