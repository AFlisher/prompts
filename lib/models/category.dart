class Category {
  final String id;
  final String name;
  final bool isEnabled;
  final int sortOrder;

  Category({
    required this.id,
    required this.name,
    required this.isEnabled,
    required this.sortOrder,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isEnabled: json['isEnabled'] as bool? ?? true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isEnabled': isEnabled,
      'sortOrder': sortOrder,
    };
  }
}
