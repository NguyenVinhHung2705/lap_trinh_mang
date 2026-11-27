import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_colors.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_scaffold.dart';
import 'auth_gate_screen.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _loading = false;

  Future<void> _sendAgain() async {
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).sendEmailVerification();
      if (mounted) showAuthMessage(context, 'Đã gửi lại email xác thực.');
    } catch (error) {
      if (mounted) showAuthMessage(context, error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkVerification() async {
    setState(() => _loading = true);
    try {
      final verified =
          await ref.read(authRepositoryProvider).refreshEmailVerification();
      if (!mounted) return;
      if (verified) {
        ref.invalidate(authStateProvider);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const AuthGateScreen()),
          (_) => false,
        );
      } else {
        showAuthMessage(
            context, 'Email chưa được xác thực. Hãy kiểm tra hộp thư đến.');
      }
    } catch (error) {
      if (mounted) showAuthMessage(context, error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) {
      ref.invalidate(authStateProvider);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const AuthGateScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authRepositoryProvider).currentUser?.email ?? '';
    return AuthScaffold(
      title: 'Xác thực email',
      subtitle:
          'Chúng tôi đã gửi liên kết xác thực đến $email. Xác thực email để tiếp tục.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.mark_email_read_outlined,
                    color: AppColors.primary, size: 28),
                SizedBox(width: 12),
                Expanded(
                    child: Text(
                        'Nếu chưa thấy email, hãy kiểm tra thư mục spam.')),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AuthPrimaryButton(
              label: 'Tôi đã xác thực',
              onPressed: _checkVerification,
              loading: _loading),
          const SizedBox(height: 8),
          TextButton(
              onPressed: _loading ? null : _sendAgain,
              child: const Text('Gửi lại email xác thực')),
          TextButton(
              onPressed: _loading ? null : _signOut,
              child: const Text('Đăng xuất')),
        ],
      ),
    );
  }
}
