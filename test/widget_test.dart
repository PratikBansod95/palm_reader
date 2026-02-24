import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palm_reader/app.dart';

void main() {
  testWidgets('App boots', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: PalmDestinyApp()));
    expect(find.text('Palm Destiny'), findsOneWidget);
  });
}

