import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException, User;

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
/// Auth credentials are managed by Firebase Auth. Profile rows are stored in
/// the Supabase `user_profiles` table, keyed by Firebase UID.
class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    SupabaseClient? supabaseClient,
    ImagePicker? imagePicker,
  })  : _customAuth = auth,
        _customSupabase = supabaseClient,
        _imagePicker = imagePicker ?? ImagePicker();

  final FirebaseAuth? _customAuth;
  final SupabaseClient? _customSupabase;
  final ImagePicker _imagePicker;

  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;
  SupabaseClient get _db => _customSupabase ?? Supabase.instance.client;

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
    return _db
        .from('user_profiles')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .map((rows) {
          if (rows.isEmpty) return null;
          return UserProfile.fromMap(uid, rows.first);
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
      if (user == null) {
        throw const AuthModuleException('Không tạo được tài khoản.');
      }

      try {
        await user.updateDisplayName(displayName.trim());
      } catch (_) {}

      final now = DateTime.now().toUtc().toIso8601String();
      await _db.from('user_profiles').upsert({
        'id': user.uid,
        'email': user.email,
        'display_name': displayName.trim(),
        'avatar_url': null,
        'email_verified': false,
        'created_at': now,
        'updated_at': now,
      });

      try {
        await user.sendEmailVerification();
      } catch (_) {
        // Gửi email xác thực là tùy chọn không bắt buộc làm gián đoạn đăng ký
      }

      return credential;
    } on FirebaseAuthException catch (error) {
      throw AuthModuleException(_authMessage(error.code, error.message));
    } on FirebaseException catch (error) {
      throw AuthModuleException(_firebaseMessage(error));
    } catch (error) {
      throw AuthModuleException(error.toString());
    }
  }

  Future<UserCredential> signIn(
      {required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        // Tự động kiểm tra và khởi tạo user_profiles nếu chưa có
        try {
          final existing = await _db
              .from('user_profiles')
              .select('id')
              .eq('id', user.uid)
              .maybeSingle();
          if (existing == null) {
            final now = DateTime.now().toUtc().toIso8601String();
            await _db.from('user_profiles').upsert({
              'id': user.uid,
              'email': user.email,
              'display_name': user.displayName ?? (user.email?.split('@').first ?? 'Người dùng'),
              'avatar_url': user.photoURL,
              'phone_number': user.phoneNumber,
              'email_verified': user.emailVerified,
              'created_at': now,
              'updated_at': now,
            });
          }
        } catch (_) {
          // Tránh chặn đăng nhập nếu bảng chưa sẵn sàng
        }
      }
      return credential;
    } on FirebaseAuthException catch (error) {
      throw AuthModuleException(_authMessage(error.code, error.message));
    } catch (error) {
      throw AuthModuleException(error.toString());
    }
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthModuleException('Bạn chưa đăng nhập.');
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw AuthModuleException(_authMessage(error.code, error.message));
    }
  }

  Future<bool> refreshEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final refreshedUser = _auth.currentUser;
    final verified = refreshedUser?.emailVerified ?? false;
    if (verified) {
      await _db.from('user_profiles').upsert({
        'id': refreshedUser!.uid,
        'email_verified': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
    return verified;
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthModuleException(_authMessage(error.code, error.message));
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
      throw AuthModuleException(_authMessage(error.code, error.message));
    }
  }

  Future<void> updateProfile(
      {required String displayName, String? phoneNumber}) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthModuleException('Bạn chưa đăng nhập.');
    try {
      await user.updateDisplayName(displayName.trim());
      await _db.from('user_profiles').upsert({
        'id': user.uid,
        'email': user.email,
        'display_name': displayName.trim(),
        'phone_number': _normalizedOptional(phoneNumber),
        'email_verified': user.emailVerified,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } on FirebaseAuthException catch (error) {
      throw AuthModuleException(_authMessage(error.code, error.message));
    } catch (error) {
      throw AuthModuleException(error.toString());
    }
  }

  /// Picks an image from the gallery and returns the existing avatar URL.
  ///
  /// Firebase Storage has been removed. The avatar upload is stubbed out —
  /// it validates the picked image but returns the user's current photoURL
  /// (or a placeholder) instead of uploading to a storage bucket.
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

      // Storage upload is stubbed — keep existing photo URL or placeholder.
      final url = user.photoURL ?? 'https://via.placeholder.com/150';
      await user.updatePhotoURL(url);
      await _db.from('user_profiles').upsert({
        'id': user.uid,
        'avatar_url': url,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return url;
    } catch (error) {
      if (error is AuthModuleException) rethrow;
      throw AuthModuleException(error.toString());
    }
  }

  /// Signs out this device and lets Firebase clear its persisted local session.
  /// Global refresh-token revocation requires a trusted server/Admin SDK and is
  /// intentionally not attempted from the client application.
  Future<void> signOut() => _auth.signOut();

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

  static String _authMessage(String code, [String? detailMessage]) => switch (code) {
        'invalid-email' => 'Email không đúng định dạng.',
        'email-already-in-use' => 'Email này đã được đăng ký. Bạn có thể đăng nhập.',
        'weak-password' => 'Mật khẩu cần có ít nhất 6 ký tự.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Email hoặc mật khẩu chưa chính xác.',
        'user-disabled' => 'Tài khoản đã bị vô hiệu hóa.',
        'too-many-requests' => 'Bạn thao tác quá nhiều lần. Hãy thử lại sau ít phút.',
        'requires-recent-login' => 'Vui lòng đăng nhập lại rồi thử lần nữa.',
        'network-request-failed' => 'Không có kết nối mạng. Hãy kiểm tra kết nối WiFi/4G.',
        'operation-not-allowed' =>
          'Phương thức đăng nhập Email/Password chưa được kích hoạt trên Firebase Console. Vui lòng vào Firebase Console > Authentication > Sign-in method và bật Email/Password.',
        'app-not-authorized' =>
          'Ứng dụng chưa được cấp quyền (Kiểm tra SHA-1 trên Firebase Console).',
        'channel-error' => 'Vui lòng điền đầy đủ email và mật khẩu hợp lệ.',
        _ => detailMessage != null && detailMessage.isNotEmpty
            ? '$detailMessage (Mã lỗi: $code)'
            : 'Không thể hoàn tất thao tác tài khoản (Mã lỗi: $code). Hãy thử lại.',
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
