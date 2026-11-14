import 'package:cloud_firestore/cloud_firestore.dart';

/// Private profile data stored at `/users/{uid}` (`MOD-05`).
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
    return UserProfile(
      uid: uid,
      email: (data['email'] as String?) ?? '',
      displayName: (data['ten_hien_thi'] as String?) ?? '',
      photoUrl: data['anh_dai_dien_url'] as String?,
      phoneNumber: data['so_dien_thoai'] as String?,
      emailVerified: data['email_da_xac_thuc'] as bool? ?? false,
      createdAt: createdAtValue is Timestamp ? createdAtValue.toDate() : null,
    );
  }
}
