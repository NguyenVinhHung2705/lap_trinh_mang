
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'features/home/presentation/screens/home_dashboard_screen.dart';
import 'features/pantry/pantry_module.dart';
import 'features/shopping/shopping_module.dart';
import 'features/recipe/recipe_module.dart';
import 'features/meal_plan/meal_plan_module.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/auth/presentation/screens/sign_in_screen.dart';
import 'shared/theme/app_colors.dart';

Future<void> main() async {
  // Đảm bảo Flutter binding đã sẵn sàng
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase trước khi chạy ứng dụng
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Gieo dữ liệu hạt giống ban đầu cho công thức nếu Cloud Firestore trống
  RecipeModule.repository.seedInitialRecipesIfEmpty().ignore();

  // Khởi chạy ứng dụng sau khi Firebase đã sẵn sàng
  runApp(
    const ProviderScope(
      child: SmartFoodLifeApp(),
    ),
  );
}

class SmartFoodLifeApp extends ConsumerWidget {
  const SmartFoodLifeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLocalMode = ref.watch(isLocalModeProvider);
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'Smart Food Life',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
        ),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
      ),
      home: isLocalMode
          ? const MainNavigationShell()
          : authState.when(
              data: (user) {
                if (user != null) {
                  return const MainNavigationShell();
                }
                return const SignInScreen();
              },
              loading: () => const Scaffold(
                backgroundColor: AppColors.background,
                body: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (_, __) => const SignInScreen(),
            ),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() =>
      _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0; // Mặc định mở Trang chủ (Dashboard)

  void _onNavigateTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  late final List<Widget> _screens = [
    // 0. Trang chủ (Dashboard tổng quan)
    HomeDashboardScreen(onNavigateTab: _onNavigateTab),

    // 1. Kho thực phẩm (MOD-01)
    PantryModule.buildHomeScreen(),

    // 2. Mua sắm (MOD-02)
    ShoppingModule.buildShoppingScreen(),

    // 3. Công thức nấu ăn (MOD-03)
    RecipeModule.buildRecipeListScreen(),

    // 4. Kế hoạch bữa ăn (MOD-04)
    MealPlanModule.buildCalendarScreen(),
  ];

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
