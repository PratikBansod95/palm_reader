import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palm_reader/app.dart';

void main() {
  testWidgets('App boots to onboarding', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: PalmDestinyApp()));
    await tester.pump();
    expect(find.text('Palm Destiny'), findsOneWidget);
    expect(find.text('Continue ->'), findsOneWidget);
  });
}
