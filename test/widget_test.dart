import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chikabooks_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // 실제 앱의 이름을 테스트하도록 수정
    await tester.pumpWidget(const ChikabooksApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
