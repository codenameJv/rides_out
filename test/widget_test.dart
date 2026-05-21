import 'package:flutter_test/flutter_test.dart';
import 'package:rides_out/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RidesOutApp());
    await tester.pump();
    expect(find.text('Rides Out'), findsOneWidget);
  });
}
