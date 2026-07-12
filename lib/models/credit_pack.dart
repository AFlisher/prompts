class CreditPack {
  final String id;
  final String name;
  final int credits;
  final String priceDisplay;
  final String? badge;
  final String? description;

  CreditPack({
    required this.id,
    required this.name,
    required this.credits,
    required this.priceDisplay,
    this.badge,
    this.description,
  });

  factory CreditPack.fromJson(Map<String, dynamic> json) {
    return CreditPack(
      id: json['id'] as String,
      name: json['name'] as String,
      credits: (json['credits'] as num).toInt(),
      priceDisplay: json['priceDisplay'] as String,
      badge: json['badge'] as String?,
      description: json['description'] as String?,
    );
  }
}
