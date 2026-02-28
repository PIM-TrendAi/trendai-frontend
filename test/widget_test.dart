import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendai_flutter/main.dart';

void main() {
  testWidgets('TrendAI app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: TrendAIApp()),
    );
    expect(find.byType(MaterialApp), findsNothing); // uses MaterialApp.router
  });
}
