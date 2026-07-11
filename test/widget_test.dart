// Smoke test for Bachelor's Kitchen app.

import 'package:flutter_test/flutter_test.dart';

import 'package:bachelors_kitchen/main.dart';

void main() {
  testWidgets('App boots and shows the home title', (WidgetTester tester) async {
    await tester.pumpWidget(const BachelorsKitchenApp());
    await tester.pump();
    expect(find.text("Bachelor's Kitchen"), findsWidgets);
  });
}
