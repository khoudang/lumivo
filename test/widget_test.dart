import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumivo/app/app.dart';

void main() {
  testWidgets('LumivoApp smoke test renders dashboard and brand', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: LumivoApp()));
    await tester.pumpAndSettle();

    expect(find.text('LUMIVO'), findsOneWidget);
    expect(find.text('Welcome home ✦'), findsOneWidget);
  });
}
