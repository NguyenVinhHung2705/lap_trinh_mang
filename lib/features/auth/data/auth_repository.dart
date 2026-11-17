import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'models/user_profile.dart';

/// Vietnamese-facing error for account and authentication operations.
class AuthModuleException implements Exception {
  const AuthModuleException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Firebase Authentication and user-scoped profile access (`MOD-05`).
///
/// Auth credentials are never written to Firestore. Profile documents are
/// scoped to `/users/{uid}` so each account can access only its own profile.
class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    ImagePicker? imagePicker,
  })  : _customAuth = auth,
        _customFirestore = firestore,
        _customStorage = storage,
        _imagePicker = imagePicker ?? ImagePicker();

  final FirebaseAuth? _customAuth;
  final FirebaseFirestore? _customFirestore;
  final FirebaseStorage? _customStorage;
  final ImagePicker _imagePicker;

  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;
  FirebaseStorage get _storage => _customStorage ?? FirebaseStorage.instance;

  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  Stream<User?> authStateChanges() {
    try {
      return _auth.authStateChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  Stream<UserProfile?> watchProfile(String uid) {
    return _profileDocument(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      return snapshot.exists && data != null
          ? UserProfile.fromMap(uid, data)
          : null;
    });
  }

  Future<UserCredential> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null)
        throw const AuthModuleException('Không tạo được tài khoản.');

      await user.updateDisplayName(displayName.trim());
      await _profileDocument(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'ten_hien_thi': displayName.trim(),
        'anh_dai_dien_url': null,
        'so_dien_thoai': null,
        'email_da_xac_thuc': false,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      await user.sendEmailVerification();
      return credential;
    } on FirebaseAuthException catch (error) {
      throw AuthModuleException(_authMessage(error.code));
    } on FirebaseException catch (error) {
      throw AuthModuleException(_firebaseMessage(error));
    }
  }

  Future<UserCredential> signIn(
      {required String email, required String password}) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthModuleException(_authMessage(error.code));
    }
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthModuleException('Bạn chưa đăng nhập.');
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw AuthModuleException(_authMessage(error.code));
    }
  }

  Future<bool> refreshEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final refreshedUser = _auth.currentUser;
    final verified = refreshedUser?.emailVerified ?? false;
    if (verified) {
      await _profileDocument(refreshedUser!.uid).set({
        'email_da_xac_thuc': true,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    return verified;
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthModuleException(_authMessage(error.code));
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthModuleException(
          'Không tìm thấy tài khoản đang đăng nhập.');
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (error) {
      throw AuthModuleException(_authMessage(error.code));
    }
  }

  Future<void> updateProfile(
      {required String displayName, String? phoneNumber}) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthModuleException('Bạn chưa đăng nhập.');
    try {
      await user.updateDisplayName(displayName.trim());
      await _profileDocument(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'ten_hien_thi': displayName.trim(),
        'so_dien_thoai': _normalizedOptional(phoneNumber),
        'email_da_xac_thuc': user.emailVerified,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (error) {
      throw AuthModuleException(_authMessage(error.code));
    } on FirebaseException catch (error) {
      throw AuthModuleException(_firebaseMessage(error));
    }
  }

  Future<String?> chooseAndUploadAvatar() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthModuleException('Bạn chưa đăng nhập.');
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (image == null) return null;

    try {
      final mimeType = image.mimeType ?? _mimeTypeFromName(image.name);
      if (mimeType == null) {
        throw const AuthModuleException(
          'Không xác định được định dạng ảnh đại diện.',
        );
      }
      if (!const {'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType)) {
        throw const AuthModuleException(
            'Ảnh đại diện cần ở định dạng JPG, PNG hoặc WebP.');
      }
      if (await image.length() > 5 * 1024 * 1024) {
        throw const AuthModuleException(
            'Ảnh đại diện không được lớn hơn 5 MB.');
      }
      final extension = mimeType.split('/').last;
      final reference =
          _storage.ref('users/${user.uid}/avatar/profile.$extension');
      await reference.putFile(
        File(image.path),
        SettableMetadata(contentType: mimeType),
      );
      final url = await reference.getDownloadURL();
      await user.updatePhotoURL(url);
      await _profileDocument(user.uid).set({
        'anh_dai_dien_url': url,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return url;
    } on FirebaseException catch (error) {
      throw AuthModuleException(_firebaseMessage(error));
    }
  }

  /// Signs out this device and lets Firebase clear its persisted local session.
  /// Global refresh-token revocation requires a trusted server/Admin SDK and is
  /// intentionally not attempted from the client application.
  Future<void> signOut() => _auth.signOut();

  DocumentReference<Map<String, dynamic>> _profileDocument(String uid) =>
      _firestore.collection('users').doc(uid);

  static String? _normalizedOptional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _mimeTypeFromName(String name) {
    final extension = name.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };
  }

  static String _authMessage(String code) => switch (code) {
        'invalid-email' => 'Email không đúng định dạng.',
        'email-already-in-use' => 'Email này đã được đăng ký.',
        'weak-password' => 'Mật khẩu cần có ít nhất 6 ký tự.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Email hoặc mật khẩu chưa chính xác.',
        'user-disabled' => 'Tài khoản đã bị vô hiệu hóa.',
        'too-many-requests' => 'Bạn thao tác quá nhiều lần. Hãy thử lại sau.',
        'requires-recent-login' => 'Vui lòng đăng nhập lại rồi thử lần nữa.',
        'network-request-failed' => 'Không có kết nối mạng. Hãy thử lại.',
        'operation-not-allowed' =>
          'Phương thức này chưa được bật trong Firebase.',
        _ => 'Không thể hoàn tất thao tác tài khoản. Hãy thử lại.',
      };

  static String _firebaseMessage(FirebaseException error) =>
      switch (error.code) {
        'permission-denied' => 'Bạn không có quyền cập nhật dữ liệu này.',
        'unauthenticated' => 'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại.',
        'object-not-found' => 'Không tìm thấy tệp ảnh.',
        'canceled' => 'Đã hủy chọn ảnh.',
        _ => error.message ?? 'Không thể lưu dữ liệu. Hãy thử lại.',
      };
}
