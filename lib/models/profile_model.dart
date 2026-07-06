class Profile {
  final String id;
  final String? fullName;
  final String? email;
  final String? avatarUrl;
  final int credits;
  final DateTime? createdAt;

  Profile({
    required this.id,
    this.fullName,
    this.email,
    this.avatarUrl,
    required this.credits,
    this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      credits: json['credits'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'avatar_url': avatarUrl,
      'credits': credits,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
