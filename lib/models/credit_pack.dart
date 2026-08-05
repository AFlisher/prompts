class CreditPack {
  final String id;
  final String name;
  final int credits;

  /// The price as the ADMIN typed it, e.g. "$4.99".
  ///
  /// Sprint 2 / B-3: this is a catalogue label, not a price the user is
  /// charged. Once a pack is backed by a real store SKU the authoritative
  /// price is the localised one the store returns (`ProductDetails.price`),
  /// which is in the buyer's own currency and reflects regional pricing and
  /// tax. The paywall prefers that and falls back to this only when the store
  /// has no matching product.
  final String priceDisplay;

  final String? badge;
  final String? description;

  /// Sprint 2 / B-3: the store SKU this pack maps to.
  ///
  /// Null until an operator creates the product in the Play Console / App
  /// Store Connect and sets it here — which is the state every seeded pack is
  /// in today. A pack with no productId cannot be purchased, and the paywall
  /// says so rather than offering a button that cannot work.
  final String? productId;

  CreditPack({
    required this.id,
    required this.name,
    required this.credits,
    required this.priceDisplay,
    this.badge,
    this.description,
    this.productId,
  });

  /// True when this pack is backed by a store product.
  bool get isPurchasable => productId != null && productId!.isNotEmpty;

  factory CreditPack.fromJson(Map<String, dynamic> json) {
    return CreditPack(
      id: json['id'] as String,
      name: json['name'] as String,
      credits: (json['credits'] as num).toInt(),
      priceDisplay: json['priceDisplay'] as String,
      badge: json['badge'] as String?,
      description: json['description'] as String?,
      productId: json['productId'] as String?,
    );
  }
}
