import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';
import '../../data/models/user_profile.dart';

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final userProfileProvider =
    StreamProvider.family<UserProfile?, String>((ref, uid) {
  return ref.watch(authRepositoryProvider).watchProfile(uid);
});
