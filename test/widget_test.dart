// Basic Flutter widget test for AI Chat application.
//
// This test verifies that the application can be built and rendered.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_chat/app.dart';

void main() {
  testWidgets('App builds without errors', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app builds successfully.
    // The app will show either login screen or chat screen depending on auth state.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
