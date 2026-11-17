import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_colors.dart';
import '../providers/auth_providers.dart';
import 'profile_screen.dart';
import 'sign_in_screen.dart';
import 'verify_email_screen.dart';

/// Routes users according to their Firebase Authentication state.
class AuthGateScreen extends ConsumerWidget {
  const AuthGateScreen({super.key, this.authenticatedBuilder});

  final WidgetBuilder? authenticatedBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      loading: () => const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (error, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined,
                    size: 40, color: AppColors.statusDanger),
                const SizedBox(height: 12),
                Text('Không thể kiểm tra phiên đăng nhập.\n$error',
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(authStateProvider),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (user) {
        if (user == null) return const SignInScreen();
        return authenticatedBuilder?.call(context) ?? const ProfileScreen();
      },
    );
  }
}
