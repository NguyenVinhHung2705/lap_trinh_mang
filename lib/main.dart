import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/pantry/pantry_module.dart';
import 'features/pantry/shared/pantry_colors.dart';
import 'features/meal_plan/meal_plan_module.dart';

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
  int _currentIndex = 1; // Mặc định mở ngay tab KHO THỰC PHẨM của Nguyễn Văn Định

  final List<Widget> _screens = [
    // 0. Trang chủ
    const Center(child: Text('Trang chủ (Dashboard tổng quan)', style: TextStyle(fontSize: 16))),
    // 1. Kho thực phẩm (MOD-01 - Nguyễn Văn Định)
    PantryModule.buildHomeScreen(),
    // 2. Mua sắm (MOD-02)
    const Center(child: Text('Mua sắm (MOD-02 - Đang phát triển)', style: TextStyle(fontSize: 16))),
    // 3. Công thức (MOD-03)
    const Center(child: Text('Công thức nấu ăn (MOD-03 - Đang phát triển)', style: TextStyle(fontSize: 16))),
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
            label: 'Kho (Định)',
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
