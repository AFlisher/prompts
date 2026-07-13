class Wallet {
  final int balance;
  final int adsProgress;
  final int generatedImages;
  final bool dailyLimitReached;

  Wallet({
    required this.balance,
    required this.adsProgress,
    required this.generatedImages,
    this.dailyLimitReached = false,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      adsProgress: (json['adsProgress'] as num?)?.toInt() ?? 0,
      generatedImages: (json['generatedImages'] as num?)?.toInt() ?? 0,
      dailyLimitReached: json['dailyLimitReached'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'balance': balance,
      'adsProgress': adsProgress,
      'generatedImages': generatedImages,
      'dailyLimitReached': dailyLimitReached,
    };
  }

  Wallet copyWith({
    int? balance,
    int? adsProgress,
    int? generatedImages,
    bool? dailyLimitReached,
  }) {
    return Wallet(
      balance: balance ?? this.balance,
      adsProgress: adsProgress ?? this.adsProgress,
      generatedImages: generatedImages ?? this.generatedImages,
      dailyLimitReached: dailyLimitReached ?? this.dailyLimitReached,
    );
  }
}

/// Response shape from POST /api/wallet/reward. Fields are optional because
/// the backend's shape varies by branch (e.g. dailyLimitReached is only
/// present when the daily free-credit limit was already hit).
class AdRewardResult {
  final bool rewarded;
  final bool dailyLimitReached;
  final int? balance;
  final int? adsProgress;

  AdRewardResult({
    required this.rewarded,
    this.dailyLimitReached = false,
    this.balance,
    this.adsProgress,
  });

  factory AdRewardResult.fromJson(Map<String, dynamic> json) {
    return AdRewardResult(
      rewarded: json['rewarded'] as bool? ?? false,
      dailyLimitReached: json['dailyLimitReached'] as bool? ?? false,
      balance: (json['balance'] as num?)?.toInt(),
      adsProgress: (json['adsProgress'] as num?)?.toInt(),
    );
  }
}

/// A single ledger entry from GET /api/wallet/history.
class WalletTransaction {
  final String id;
  final int amount;
  final String type; // 'reward' | 'purchase' | 'generation' | 'refund' | 'admin'
  final String? description;
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.amount,
    required this.type,
    this.description,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] as String,
      amount: (json['amount'] as num).toInt(),
      type: json['type'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
