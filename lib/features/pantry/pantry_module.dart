import 'package:flutter/material.dart';
import 'presentation/screens/pantry_home_screen.dart';

/// Entry point cho phân hệ MOD-01: Quản lý Kho Thực phẩm
class PantryModule {
  const PantryModule._();

  static const String route = '/pantry';

  static Widget buildHomeScreen() {
    return const PantryHomeScreen();
  }
}
