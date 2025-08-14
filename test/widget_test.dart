// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coloring_book/app.dart';
import 'package:coloring_book/config/api_config.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    // Initialize API config for testing
    await ApiConfig.initialize();
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: ColoringBookApp()));
    await tester.pumpAndSettle();

    // Just verify the app builds successfully
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
