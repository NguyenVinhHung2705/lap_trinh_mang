import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_colors.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_scaffold.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Tài khoản'),
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              color: AppColors.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: AppColors.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primaryTint,
                      child: Icon(Icons.person_pin, size: 48, color: AppColors.primary),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tài khoản Khách / Local',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bạn đang dùng ứng dụng ở chế độ Local (Offline). Dữ liệu được lưu trong bộ nhớ tạm của thiết bị.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.login),
                        label: const Text('Đăng nhập bằng Firebase',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SignInScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.person_add_outlined, color: AppColors.primary),
                        label: const Text('Đăng ký tài khoản mới',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            )),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SignUpScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      icon: const Icon(Icons.logout, color: AppColors.statusDanger, size: 18),
                      label: const Text('Thoát chế độ Local',
                          style: TextStyle(color: AppColors.statusDanger)),
                      onPressed: () {
                        ref.read(isLocalModeProvider.notifier).state = false;
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final profile = ref.watch(userProfileProvider(user.uid));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tài khoản'),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: () async {
              try {
                await ref.read(authRepositoryProvider).signOut();
                ref.read(isLocalModeProvider.notifier).state = false;
                ref.invalidate(authStateProvider);
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              } catch (error) {
                if (context.mounted) showAuthMessage(context, error.toString());
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: profile.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (error, _) =>
            Center(child: Text('Không tải được hồ sơ: $error')),
        data: (data) {
          final displayName = data?.displayName.isNotEmpty == true
              ? data!.displayName
              : (user.displayName?.isNotEmpty == true
                  ? user.displayName!
                  : 'Người dùng');
          final photoUrl = data?.photoUrl ?? user.photoURL;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                color: AppColors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: AppColors.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: AppColors.primaryTint,
                            backgroundImage: photoUrl == null
                                ? null
                                : NetworkImage(photoUrl),
                            child: photoUrl == null
                                ? const Icon(Icons.person,
                                    size: 42, color: AppColors.primary)
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: IconButton.filled(
                              tooltip: 'Đổi ảnh đại diện',
                              onPressed: () async {
                                try {
                                  final url = await ref
                                      .read(authRepositoryProvider)
                                      .chooseAndUploadAvatar();
                                  if (url != null)
                                    ref.invalidate(
                                        userProfileProvider(user.uid));
                                } catch (error) {
                                  if (context.mounted)
                                    showAuthMessage(context, error.toString());
                                }
                              },
                              icon: const Icon(Icons.camera_alt_outlined,
                                  size: 18),
                              style: IconButton.styleFrom(
                                  backgroundColor: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(displayName,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(user.email ?? '',
                          style:
                              const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 10),
                      Chip(
                        avatar: Icon(
                          user.emailVerified
                              ? Icons.verified
                              : Icons.info_outline,
                          size: 18,
                          color: user.emailVerified
                              ? AppColors.statusSuccess
                              : AppColors.statusWarning,
                        ),
                        label: Text(user.emailVerified
                            ? 'Email đã xác thực'
                            : 'Email chưa xác thực'),
                        backgroundColor: user.emailVerified
                            ? AppColors.statusSuccessTint
                            : AppColors.statusWarningTint,
                        side: BorderSide.none,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _ProfileAction(
                icon: Icons.edit_outlined,
                title: 'Chỉnh sửa hồ sơ',
                subtitle: 'Tên hiển thị và số điện thoại',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => EditProfileScreen(
                            initialName: displayName,
                            initialPhone: data?.phoneNumber ?? '',
                          )),
                ),
              ),
              _ProfileAction(
                icon: Icons.lock_reset_outlined,
                title: 'Đổi mật khẩu',
                subtitle: 'Xác minh mật khẩu hiện tại trước khi đổi',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const ChangePasswordScreen()),
                ),
              ),
              _ProfileAction(
                icon: Icons.logout,
                title: 'Đăng xuất',
                subtitle: 'Đăng xuất tài khoản trên thiết bị này',
                onTap: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  ref.invalidate(authStateProvider);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
