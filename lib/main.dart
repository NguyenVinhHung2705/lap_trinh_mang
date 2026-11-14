import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/meal_plan/meal_plan_module.dart';
import 'features/pantry/pantry_module.dart';
import 'features/recipe/recipe_module.dart';
import 'features/shopping/shopping_module.dart';
import 'shared/theme/app_colors.dart';

void main() {
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
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0; // Mặc định mở Trang chủ hoặc có thể chuyển tab tự do

  final List<Widget> _screens = [
    // 0. Trang chủ
    const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.eco_rounded, size: 64, color: AppColors.primary),
                SizedBox(height: 16),
                Text(
                  'Smart Food Life',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Ứng dụng Quản lý Thực phẩm Cá nhân\nChọn các tab bên dưới để sử dụng từng phân hệ:',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
                SizedBox(height: 20),
                Text(
                  '• Kho thực phẩm (Định)\n• Mua sắm (Hưng)\n• Công thức (Hy)\n• Kế hoạch bữa ăn (Khởi)',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    // 1. Kho thực phẩm (MOD-01 - Nguyễn Văn Định)
    PantryModule.buildHomeScreen(),
    // 2. Mua sắm (MOD-02 - Nguyễn Vĩnh Hưng)
    ShoppingModule.buildShoppingScreen(),
    // 3. Công thức (MOD-03 - Nguyễn Khang Hy)
    RecipeModule.buildRecipeListScreen(),
    // 4. Kế hoạch bữa ăn (MOD-04 - Hồ Nguyên Khởi)
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
