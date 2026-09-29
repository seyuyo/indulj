import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indulj/app/providers.dart';
import 'package:indulj/core/clock.dart';
import 'package:indulj/features/board/board_screen.dart';
import 'package:indulj/features/favorites/favorites_repository.dart';
import 'package:indulj/main.dart';
import 'package:indulj/widget_bridge/widget_refresher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/budapest_time.dart';
import '../support/fakes.dart';

const _fixture = 'arrivals_oktogon_day';

Future<void> _start(
  WidgetTester tester, {
  Stream<Uri?>? links,
  Uri? initial,
}) async {
  SharedPreferences.setMockInitialValues({
    FavoritesRepository.storageKey:
        '{"v":1,"groups":[{"id":"g1","name":"Oktogon",'
        '"stopIds":["BKK_F01081","BKK_F01082"]}]}',
    WidgetRefresher.groupKey(7): 'g1',
  });
  final prefs = await SharedPreferences.getInstance();
  final api = CountingApi((_) => jsonResponse(fixture(_fixture)));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        futarApiClientProvider.overrideWithValue(api.client),
        clockProvider.overrideWithValue(FakeClock(fixtureServerTime(_fixture))),
        utcOffsetProvider.overrideWithValue(budapestOffsetMs),
        widgetStoreProvider.overrideWithValue(FakeWidgetStore()),
      ],
      child: InduljApp(widgetLinks: links, initialWidgetLink: initial),
    ),
  );
}

Future<void> _leaveBoard(WidgetTester tester) async {
  // Az időzítők leállnak, ha a tábla bezárul.
  await tester.pageBack();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tapping the widget body opens its group board', (tester) async {
    final links = StreamController<Uri?>();
    addTearDown(links.close);
    await _start(tester, links: links.stream);

    links.add(Uri.parse('indulj://open?widget=7'));
    await tester.pumpAndSettle();

    expect(find.byType(BoardScreen), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await _leaveBoard(tester);
  });

  testWidgets('tapping the alert icon shows the alert text', (tester) async {
    await _start(tester, initial: Uri.parse('indulj://alerts?widget=7'));
    await tester.pumpAndSettle();

    expect(find.byType(BoardScreen), findsOneWidget);
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(
        of: dialog,
        matching: find.text('nem közlekedik a teljes vonalon'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining('A 4-es és a 6-os villamos'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Bezár'));
    await tester.pumpAndSettle();
    await _leaveBoard(tester);
  });

  testWidgets('unknown widgets and foreign links are ignored', (tester) async {
    final links = StreamController<Uri?>();
    addTearDown(links.close);
    await _start(tester, links: links.stream);

    links
      ..add(Uri.parse('indulj://open?widget=99'))
      ..add(Uri.parse('https://example.com/?widget=7'))
      ..add(null);
    await tester.pumpAndSettle();

    expect(find.byType(BoardScreen), findsNothing);
  });
}
