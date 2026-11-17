import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/auth_module.dart';
import 'features/meal_plan/meal_plan_module.dart';
import 'features/pantry/pantry_module.dart';
import 'features/recipe/recipe_module.dart';
import 'features/shopping/shopping_module.dart';
import 'shared/theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }
  runApp(
    const ProviderScope(
      child: SmartFoodLifeApp(),
    ),
  );
}

class SmartFoodLifeApp extends StatelessWidget {
  const SmartFoodLifeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Food Life',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
      ),
      routes: AuthModule.routes,
      home: AuthModule.buildGate(
        authenticatedBuilder: (_) => const MainNavigationShell(),
      ),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      _HomeDashboardTab(
        onNavigateTab: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      PantryModule.buildHomeScreen(),
      ShoppingModule.buildShoppingScreen(),
      RecipeModule.buildRecipeListScreen(),
      MealPlanModule.buildCalendarScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.kitchen_outlined),
            activeIcon: Icon(Icons.kitchen),
            label: 'Kho',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'Mua sắm',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Công thức',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Kế hoạch',
          ),
        ],
      ),
    );
  }
}

class _HomeDashboardTab extends ConsumerWidget {
  const _HomeDashboardTab({required this.onNavigateTab});

  final ValueChanged<int> onNavigateTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;
    final displayName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!
        : (user?.email?.split('@').first ?? 'Người dùng');
    final email = user?.email ?? 'Chưa đăng nhập';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.eco_rounded, color: AppColors.primary, size: 28),
            SizedBox(width: 8),
            Text(
              'Smart Food Life',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.account_circle_outlined,
              color: AppColors.primary,
              size: 28,
            ),
            tooltip: 'Hồ sơ tài khoản (MOD-05)',
            onPressed: () => AuthModule.openProfile(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Thẻ hồ sơ người dùng
            Card(
              color: AppColors.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusCard),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primaryTint,
                      backgroundImage: user?.photoURL != null
                          ? NetworkImage(user!.photoURL!)
                          : null,
                      child: user?.photoURL == null
                          ? const Icon(Icons.person, color: AppColors.primary, size: 30)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Xin chào, $displayName!',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.radiusBadge),
                        ),
                      ),
                      onPressed: () => AuthModule.openProfile(context),
                      child: const Text('Hồ sơ'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Tiêu đề phân hệ
            const Text(
              'Phân hệ chức năng',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Chọn phân hệ bên dưới hoặc dùng thanh điều hướng đáy:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),

            _buildModuleCard(
              context: context,
              icon: Icons.kitchen_outlined,
              iconColor: const Color(0xFF2563EB),
              badgeText: 'MOD-01',
              title: 'Kho Thực Phẩm',
              subtitle: 'Quản lý tồn kho, lô hàng nhập & hạn sử dụng (FEFO)',
              author: 'Nguyễn Văn Định',
              onTap: () => onNavigateTab(1),
            ),
            const SizedBox(height: 12),

            _buildModuleCard(
              context: context,
              icon: Icons.shopping_cart_outlined,
              iconColor: const Color(0xFFF59E0B),
              badgeText: 'MOD-02',
              title: 'Danh Sách Mua Sắm',
              subtitle: 'Lập danh sách cần mua, đánh dấu và đồng bộ vào kho',
              author: 'Nguyễn Vĩnh Hưng',
              onTap: () => onNavigateTab(2),
            ),
            const SizedBox(height: 12),

            _buildModuleCard(
              context: context,
              icon: Icons.menu_book_outlined,
              iconColor: const Color(0xFF8B5CF6),
              badgeText: 'MOD-03',
              title: 'Công Thức Nấu Ăn',
              subtitle: 'Tra cứu công thức, tự động co giãn theo khẩu phần',
              author: 'Nguyễn Khang Hy',
              onTap: () => onNavigateTab(3),
            ),
            const SizedBox(height: 12),

            _buildModuleCard(
              context: context,
              icon: Icons.calendar_month_outlined,
              iconColor: AppColors.primary,
              badgeText: 'MOD-04',
              title: 'Kế Hoạch Bữa Ăn',
              subtitle: 'Lịch ăn 7 ngày, hoàn tất bữa & trừ kho FEFO nguyên tử',
              author: 'Hồ Nguyên Khởi',
              onTap: () => onNavigateTab(4),
            ),
            const SizedBox(height: 12),

            _buildModuleCard(
              context: context,
              icon: Icons.manage_accounts_outlined,
              iconColor: const Color(0xFF0D9488),
              badgeText: 'MOD-05',
              title: 'Tài Khoản & Hồ Sơ',
              subtitle: 'Đăng nhập, xác thực email, đổi mật khẩu & cập nhật ảnh đại diện',
              author: 'Bùi Thị Quỳnh Như',
              onTap: () => AuthModule.openProfile(context),
            ),
            const SizedBox(height: 20),

            // Thông tin đồ án
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(AppColors.radiusCard),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.school_outlined, size: 20, color: AppColors.primaryDark),
                      SizedBox(width: 8),
                      Text(
                        'Đồ án Lập trình mạng - 23CT1',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'GVHD: TS. Đặng Hùng Vĩ\nNhóm 5 thành viên đã tích hợp đầy đủ 5 phân hệ trên nền tảng Firebase Firestore + Auth.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String badgeText,
    required String title,
    required String subtitle,
    required String author,
    required VoidCallback onTap,
  }) {
    return Card(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppColors.radiusInput),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(AppColors.radiusBadge),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: iconColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Phụ trách: $author',
                      style: TextStyle(
                        fontSize: 11,
                        color: iconColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
