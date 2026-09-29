import 'package:flutter_test/flutter_test.dart';
import 'package:indulj/main.dart';

void main() {
  testWidgets('app starts', (tester) async {
    await tester.pumpWidget(const InduljApp());
    expect(find.text('Indulj'), findsOneWidget);
  });
}
