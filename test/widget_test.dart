import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('basic material app renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('TelurKu Test Smoke'),
          ),
        ),
      ),
    );

    expect(find.text('TelurKu Test Smoke'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
