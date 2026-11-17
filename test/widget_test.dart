// Basic Flutter widget smoke test for Smart Food Life.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_food_life/main.dart';

void main() {
  testWidgets('SmartFoodLifeApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: SmartFoodLifeApp(),
      ),
    );

    // Verify the app root is pumped.
    expect(find.byType(SmartFoodLifeApp), findsOneWidget);
  });
}
