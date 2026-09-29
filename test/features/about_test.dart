import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indulj/features/about/about_screen.dart';

void main() {
  testWidgets('shows the CC BY 4.0 attribution and opens licenses', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));

    expect(find.textContaining('BKK FUTÁR'), findsWidgets);
    expect(find.textContaining('CC BY 4.0'), findsWidgets);
    expect(find.textContaining('opendata.bkk.hu'), findsWidgets);

    await tester.tap(find.text('Licencek'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  test('registers the BKK data license', () async {
    registerDataLicense();
    final entries = await LicenseRegistry.licenses.toList();
    final bkk = entries.where(
      (e) => e.packages.contains('BKK FUTÁR nyílt adatok'),
    );
    expect(bkk, isNotEmpty);
    expect(
      bkk.first.paragraphs.map((p) => p.text).join('\n'),
      contains('creativecommons.org/licenses/by/4.0'),
    );
  });
}
