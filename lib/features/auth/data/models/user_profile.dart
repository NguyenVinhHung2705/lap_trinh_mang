/// Private profile data stored in `user_profiles` table (`MOD-05`).
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.phoneNumber,
    this.emailVerified = false,
    this.createdAt,
  });

  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? phoneNumber;
  final bool emailVerified;
  final DateTime? createdAt;

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    final createdAtValue = data['created_at'];
    DateTime? parsedCreatedAt;
    if (createdAtValue is String) {
      parsedCreatedAt = DateTime.tryParse(createdAtValue);
    } else if (createdAtValue is DateTime) {
      parsedCreatedAt = createdAtValue;
    }

    return UserProfile(
      uid: uid,
      email: (data['email'] as String?) ?? '',
      displayName: (data['display_name'] as String?) ?? '',
      photoUrl: data['avatar_url'] as String?,
      phoneNumber: data['phone_number'] as String?,
      emailVerified: data['email_verified'] as bool? ?? false,
      createdAt: parsedCreatedAt,
    );
  }
}
