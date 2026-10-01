import 'package:flutter_test/flutter_test.dart';
import 'package:art_haven_new/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app widget actually loaded onto the screen
    expect(find.byType(MyApp), findsOneWidget);
  });
}
