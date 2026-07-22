import 'package:flutter_test/flutter_test.dart';
import 'package:pacify/main.dart';

void main() {
  testWidgets('shows the cadence detector', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Cadence Detector'), findsOneWidget);
    expect(find.text('Press the button to start'), findsOneWidget);
  });
}
