import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';
import '../../data/models/user_profile.dart';

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository());

/// Quản lý chế độ trải nghiệm Local / Khách (không bắt buộc đăng nhập Firebase)
final isLocalModeProvider = StateProvider<bool>((ref) => false);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// UID hiện tại của người dùng, hoặc mock UID nếu ở chế độ Local / Khách
final currentUserIdProvider = Provider<String>((ref) {
  final isLocal = ref.watch(isLocalModeProvider);
  if (isLocal) return 'mock_user_nguyen_van_dinh';
  final user = ref.watch(authStateProvider).value;
  return user?.uid ?? 'mock_user_nguyen_van_dinh';
});

final userProfileProvider =
    StreamProvider.family<UserProfile?, String>((ref, uid) {
  return ref.watch(authRepositoryProvider).watchProfile(uid);
});
