import 'package:flutter_test/flutter_test.dart';
import 'package:rue_pos/main.dart';

void main() {
  testWidgets('smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RuePOS());
  });
}
