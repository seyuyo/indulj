import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indulj/data/departures_repository.dart';
import 'package:indulj/data/futar/futar_error.dart';
import 'package:indulj/domain/models.dart';
import 'package:indulj/features/board/board_notifier.dart';
import 'package:indulj/features/board/board_screen.dart';

import '../support/budapest_time.dart';

final _now = budapest(2026, 9, 29, 14, 0);
const _min = 60 * 1000;

Departure _dep(String route, String headsign, int at, {int? predicted}) =>
    Departure(
      routeId: 'BKK_$route',
      routeShortName: route,
      headsign: headsign,
      tripId: 'T_$route$at',
      stopId: 'S',
      routeColor: 0xFFFFD800,
      routeTextColor: 0xFF000000,
      scheduledAtMs: at,
      predictedAtMs: predicted,
    );

DeparturesSnapshot _snapshot(
  List<Departure> departures, {
  List<String> stopAlertIds = const [],
  Map<String, Alert> alerts = const {},
  int serverOffsetMs = 0,
}) => DeparturesSnapshot(
  result: DeparturesResult(
    serverTimeMs: _now,
    departures: departures,
    stopAlertIds: stopAlertIds,
    alerts: alerts,
  ),
  fetchedAtMs: _now,
  serverOffsetMs: serverOffsetMs,
);

Future<void> _pump(
  WidgetTester tester,
  BoardState state, {
  Set<String>? routeFilter,
  VoidCallback? onRetry,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: BoardView(
        state: state,
        routeFilter: routeFilter,
        nowMs: _now,
        offsetOf: budapestOffsetMs,
        onRetry: onRetry ?? () {},
      ),
    ),
  ),
);

void main() {
  testWidgets('loading without data shows a spinner', (tester) async {
    await _pump(tester, const BoardState(loading: true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('rows are sorted, labelled, and show delay', (tester) async {
    await _pump(
      tester,
      BoardState(
        snapshot: _snapshot([
          _dep('6', 'Móricz Zsigmond körtér M', _now + 8 * _min),
          _dep(
            '4',
            'Széll Kálmán tér M',
            _now + _min,
            predicted: _now + 3 * _min,
          ),
          _dep('105', 'Apor Vilmos tér', _now + 75 * _min),
        ]),
      ),
    );

    final headsigns = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((t) => ((t.title! as Text).data))
        .toList();
    expect(headsigns, [
      'Széll Kálmán tér M',
      'Móricz Zsigmond körtér M',
      'Apor Vilmos tér',
    ]);
    expect(find.text('3 perc'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    expect(find.text('8 perc'), findsOneWidget);
    expect(find.text('15:15'), findsOneWidget);
    expect(find.text('frissítve 14:00'), findsOneWidget);
  });

  testWidgets('route filter hides other routes', (tester) async {
    await _pump(
      tester,
      BoardState(
        snapshot: _snapshot([
          _dep('4', 'Széll Kálmán tér M', _now + _min),
          _dep('105', 'Apor Vilmos tér', _now + 2 * _min),
        ]),
      ),
      routeFilter: {'BKK_4'},
    );

    expect(find.text('Széll Kálmán tér M'), findsOneWidget);
    expect(find.text('Apor Vilmos tér'), findsNothing);
  });

  testWidgets('server clock offset is applied to labels', (tester) async {
    // A szerver 2 perccel előrébb jár: a 3 perc múlva induló csak 1 perc.
    await _pump(
      tester,
      BoardState(
        snapshot: _snapshot([
          _dep('4', 'Széll Kálmán tér M', _now + 3 * _min),
        ], serverOffsetMs: 2 * _min),
      ),
    );

    expect(find.text('1 perc'), findsOneWidget);
  });

  testWidgets('empty list has its own message', (tester) async {
    await _pump(tester, BoardState(snapshot: _snapshot([])));
    expect(find.text('Nincs indulás 60 percen belül'), findsOneWidget);
  });

  testWidgets('no network without data offers retry', (tester) async {
    var retried = 0;
    await _pump(
      tester,
      const BoardState(error: NetworkError('SocketException')),
      onRetry: () => retried++,
    );

    expect(find.text('Nincs internetkapcsolat'), findsOneWidget);
    await tester.tap(find.text('Újra'));
    expect(retried, 1);
  });

  testWidgets('invalid key has its own message', (tester) async {
    await _pump(tester, const BoardState(error: HttpError(401)));
    expect(find.text('Érvénytelen API-kulcs'), findsOneWidget);
  });

  testWidgets('other errors have a generic message', (tester) async {
    await _pump(tester, const BoardState(error: HttpError(503)));
    expect(find.text('A BKK szervere nem válaszol'), findsOneWidget);
    expect(find.textContaining('503'), findsOneWidget);
  });

  testWidgets('error with old data keeps rows and shows stale banner', (
    tester,
  ) async {
    await _pump(
      tester,
      BoardState(
        snapshot: _snapshot([_dep('4', 'Széll Kálmán tér M', _now + _min)]),
        error: const NetworkError('SocketException'),
      ),
    );

    expect(find.text('Elavult · frissítve 14:00'), findsOneWidget);
    expect(find.text('Nincs internetkapcsolat'), findsOneWidget);
    expect(find.text('Széll Kálmán tér M'), findsOneWidget);
  });

  testWidgets('stop alert shows a banner that opens the details', (
    tester,
  ) async {
    await _pump(
      tester,
      BoardState(
        snapshot: _snapshot(
          [_dep('4', 'Széll Kálmán tér M', _now + _min)],
          stopAlertIds: ['A1'],
          alerts: {
            'A1': const Alert(
              id: 'A1',
              header: 'Pótlóbusz',
              description: 'A 4-es villamos helyett pótlóbusz jár.',
            ),
          },
        ),
      ),
    );

    await tester.tap(find.text('Pótlóbusz'));
    await tester.pumpAndSettle();
    expect(find.text('A 4-es villamos helyett pótlóbusz jár.'), findsOneWidget);
  });
}
