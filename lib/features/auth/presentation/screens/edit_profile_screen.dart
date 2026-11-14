import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../widgets/auth_scaffold.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen(
      {required this.initialName, required this.initialPhone, super.key});

  final String initialName;
  final String initialPhone;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).updateProfile(
            displayName: _nameController.text,
            phoneNumber: _phoneController.text,
          );
      if (mounted) {
        final uid = ref.read(authRepositoryProvider).currentUser?.uid;
        if (uid != null) ref.invalidate(userProfileProvider(uid));
        Navigator.of(context).pop();
        showAuthMessage(context, 'Đã cập nhật hồ sơ.');
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
      title: 'Chỉnh sửa hồ sơ',
      subtitle: 'Cập nhật thông tin hiển thị trong tài khoản.',
      showBackButton: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTextField(
              controller: _nameController,
              label: 'Tên hiển thị',
              icon: Icons.person_outline,
              validator: (value) => (value?.trim().length ?? 0) < 2
                  ? 'Tên cần có ít nhất 2 ký tự.'
                  : null,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _phoneController,
              label: 'Số điện thoại (không bắt buộc)',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (value) {
                final phone = value?.trim() ?? '';
                if (phone.isNotEmpty &&
                    !RegExp(r'^\+?[0-9 .()-]{8,20}$').hasMatch(phone)) {
                  return 'Số điện thoại chưa đúng định dạng.';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            AuthPrimaryButton(
                label: 'Lưu thay đổi', onPressed: _save, loading: _loading),
          ],
        ),
      ),
    );
  }
}
