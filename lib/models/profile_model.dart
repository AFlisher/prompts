class Profile {
  final String id;
  final String? fullName;
  final String? email;
  final String? avatarUrl;
  final String? bio;
  final String? provider;
  final DateTime? createdAt;
  final bool personalizationEnabled;

  Profile({
    required this.id,
    this.fullName,
    this.email,
    this.avatarUrl,
    this.bio,
    this.provider,
    this.createdAt,
    this.personalizationEnabled = true,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      provider: json['provider'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      personalizationEnabled: json['personalization_enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'avatar_url': avatarUrl,
      'bio': bio,
      'provider': provider,
      'created_at': createdAt?.toIso8601String(),
      'personalization_enabled': personalizationEnabled,
    };
  }
}
