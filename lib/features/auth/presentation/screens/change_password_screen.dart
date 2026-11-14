import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../widgets/auth_scaffold.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).changePassword(
            currentPassword: _currentController.text,
            newPassword: _newController.text,
          );
      if (mounted) {
        Navigator.of(context).pop();
        showAuthMessage(context, 'Đã đổi mật khẩu.');
      }
    } catch (error) {
      if (mounted) showAuthMessage(context, error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Đổi mật khẩu',
      subtitle: 'Nhập mật khẩu hiện tại để xác minh tài khoản.',
      showBackButton: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTextField(
              controller: _currentController,
              label: 'Mật khẩu hiện tại',
              icon: Icons.lock_outline,
              obscureText: true,
              validator: (value) => value == null || value.isEmpty
                  ? 'Nhập mật khẩu hiện tại.'
                  : null,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _newController,
              label: 'Mật khẩu mới',
              icon: Icons.lock_reset_outlined,
              obscureText: true,
              validator: (value) => (value?.length ?? 0) < 6
                  ? 'Mật khẩu cần có ít nhất 6 ký tự.'
                  : null,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _confirmController,
              label: 'Nhập lại mật khẩu mới',
              icon: Icons.lock_reset_outlined,
              obscureText: true,
              validator: (value) => value != _newController.text
                  ? 'Mật khẩu nhập lại chưa khớp.'
                  : null,
            ),
            const SizedBox(height: 24),
            AuthPrimaryButton(
                label: 'Cập nhật mật khẩu',
                onPressed: _changePassword,
                loading: _loading),
          ],
        ),
      ),
    );
  }
}
