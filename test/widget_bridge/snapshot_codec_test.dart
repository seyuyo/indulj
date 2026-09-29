import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:indulj/data/departures_repository.dart';
import 'package:indulj/data/futar/futar_error.dart';
import 'package:indulj/domain/models.dart';
import 'package:indulj/widget_bridge/snapshot_codec.dart';

// A tesztek a mintákat test/fixtures/snapshots alá is kiírják: ezeket olvassa
// a Kotlin SnapshotReaderTest. A CI ellenőrzi, hogy a kiírt fájlok egyeznek
// a commitolttal (git diff --exit-code).

const _min = 60 * 1000;
const _t0 = 1790683200000; // 2026-09-29 14:00 (Budapest)

Departure _dep(
  String route,
  int at, {
  int? predicted,
  List<String> alerts = const [],
}) => Departure(
  routeId: 'BKK_$route',
  routeShortName: route,
  headsign: route == '4' ? 'Széll Kálmán tér M' : 'Újbuda-központ M',
  tripId: 'T$route$at',
  stopId: 'S',
  routeColor: 0xFFFFD800,
  routeTextColor: 0xFF000000,
  scheduledAtMs: at,
  predictedAtMs: predicted,
  alertIds: alerts,
);

DeparturesSnapshot _data(
  List<Departure> deps, {
  List<String> stopAlerts = const [],
}) => DeparturesSnapshot(
  result: DeparturesResult(
    serverTimeMs: _t0,
    departures: deps,
    stopAlertIds: stopAlerts,
  ),
  fetchedAtMs: _t0 + 1200,
  serverOffsetMs: -1200,
);

const _group = StopGroup(id: 'g', name: 'Oktogon', stopIds: ['S']);

void _writeFixture(String name, String json) {
  final pretty = const JsonEncoder.withIndent('  ').convert(jsonDecode(json));
  File('test/fixtures/snapshots/$name.json')
    ..createSync(recursive: true)
    ..writeAsStringSync('$pretty\n');
}

void main() {
  final normal = buildSnapshot(
    _group,
    _data([
      _dep('6', _t0 + 5 * _min),
      _dep('4', _t0 + _min, predicted: _t0 + 3 * _min),
      _dep('4', _t0 - 5 * _min), // már elment
    ]),
  );

  group('buildSnapshot', () {
    test('uses the board selection: filtered, sorted, delay', () {
      expect(normal.groupName, 'Oktogon');
      expect(normal.fetchedAtMs, _t0 + 1200);
      expect(normal.serverOffsetMs, -1200);
      expect(normal.departures.map((d) => d.route), ['4', '6']);
      final first = normal.departures.first;
      expect(first.atMs, _t0 + 3 * _min);
      expect(first.realtime, isTrue);
      expect(first.delayMin, 2);
      expect(normal.departures[1].delayMin, isNull);
      expect(normal.hasAlerts, isFalse);
      expect(normal.error, isNull);
    });

    test('respects the route filter and the row limit', () {
      final many = [for (var i = 0; i < 12; i++) _dep('4', _t0 + i * _min)];
      final s = buildSnapshot(
        const StopGroup(
          id: 'g',
          name: 'x',
          stopIds: ['S'],
          routeFilter: {'BKK_6'},
        ),
        _data([...many, _dep('6', _t0 + 2 * _min)]),
      );
      expect(s.departures.map((d) => d.route), ['6']);
      expect(
        buildSnapshot(_group, _data(many)).departures,
        hasLength(snapshotMaxDepartures),
      );
    });

    test('flags stop-level and trip-level alerts', () {
      expect(
        buildSnapshot(_group, _data([], stopAlerts: ['A'])).hasAlerts,
        isTrue,
      );
      expect(
        buildSnapshot(
          _group,
          _data([
            _dep('4', _t0 + _min, alerts: ['A']),
          ]),
        ).hasAlerts,
        isTrue,
      );
    });
  });

  group('errors', () {
    test('keep the previous rows and time', () {
      final s = snapshotWithError(
        normal,
        groupName: 'Oktogon',
        error: WidgetError.network,
      );
      expect(s.departures, hasLength(2));
      expect(s.fetchedAtMs, normal.fetchedAtMs);
      expect(s.error, WidgetError.network);
    });

    test('without previous data are empty and never fetched', () {
      final s = snapshotWithError(
        null,
        groupName: 'Oktogon',
        error: WidgetError.unauthorized,
      );
      expect(s.departures, isEmpty);
      expect(s.fetchedAtMs, 0);
    });

    test('map from API errors', () {
      expect(widgetErrorOf(const NetworkError('x')), WidgetError.network);
      expect(widgetErrorOf(const HttpError(401)), WidgetError.unauthorized);
      expect(widgetErrorOf(const HttpError(503)), WidgetError.server);
      expect(widgetErrorOf(const ApiError(500, null)), WidgetError.server);
      expect(widgetErrorOf(const ParseError('x')), WidgetError.server);
    });
  });

  group('codec', () {
    test('round trip keeps every field', () {
      final back = decodeSnapshot(encodeSnapshot(normal));
      expect(back.groupName, normal.groupName);
      expect(back.fetchedAtMs, normal.fetchedAtMs);
      expect(back.serverOffsetMs, normal.serverOffsetMs);
      expect(back.hasAlerts, normal.hasAlerts);
      expect(back.error, isNull);
      expect(back.departures, hasLength(2));
      final d = back.departures.first;
      expect(d.route, '4');
      expect(d.bg, 0xFFFFD800);
      expect(d.fg, 0xFF000000);
      expect(d.headsign, 'Széll Kálmán tér M');
      expect(d.atMs, _t0 + 3 * _min);
      expect(d.realtime, isTrue);
      expect(d.delayMin, 2);
    });

    test('schema matches SPEC 5 field names', () {
      final json = jsonDecode(encodeSnapshot(normal)) as Map<String, Object?>;
      expect(json.keys, [
        'v',
        'groupName',
        'fetchedAtMs',
        'serverOffsetMs',
        'departures',
        'hasAlerts',
        'error',
      ]);
      expect(json['v'], 1);
      final d = (json['departures']! as List<Object?>).first! as Map;
      expect(d['bg'], 'FFFFD800');
      expect(d['fg'], 'FF000000');
    });

    test('error round trip, unknown error name becomes server', () {
      final s = snapshotWithError(
        normal,
        groupName: 'x',
        error: WidgetError.noGroup,
      );
      expect(decodeSnapshot(encodeSnapshot(s)).error, WidgetError.noGroup);
      expect(
        decodeSnapshot('{"v":1,"error":"somethingNew"}').error,
        WidgetError.server,
      );
    });

    test('other versions and garbage are FormatExceptions', () {
      expect(() => decodeSnapshot('{"v":2}'), throwsFormatException);
      expect(() => decodeSnapshot('nope'), throwsFormatException);
    });

    test('missing optional fields get defaults', () {
      final s = decodeSnapshot('{"v":1,"departures":[{"atMs":5}]}');
      expect(s.groupName, '');
      expect(s.fetchedAtMs, 0);
      expect(s.departures.single.route, '?');
      expect(s.departures.single.fg, 0xFFFFFFFF);
    });
  });

  test('writes the shared fixtures for the Kotlin reader', () {
    final fixtures = {
      'normal': encodeSnapshot(normal),
      'empty': encodeSnapshot(buildSnapshot(_group, _data([]))),
      'error_network': encodeSnapshot(
        snapshotWithError(
          normal,
          groupName: 'Oktogon',
          error: WidgetError.network,
        ),
      ),
      'error_unauthorized': encodeSnapshot(
        snapshotWithError(
          null,
          groupName: 'Oktogon',
          error: WidgetError.unauthorized,
        ),
      ),
      'no_group': encodeSnapshot(
        snapshotWithError(null, groupName: '', error: WidgetError.noGroup),
      ),
      // Kézzel írt esetek: a jövőbeli verzió és a hiányos v1.
      'future_version': '{"v":2,"groupName":"Oktogon","rows":[]}',
      'missing_fields':
          '{"v":1,"groupName":"Oktogon","fetchedAtMs":$_t0,'
          '"departures":[{"route":"4","atMs":${_t0 + _min}}]}',
    };
    fixtures.forEach(_writeFixture);

    for (final name in fixtures.keys) {
      expect(File('test/fixtures/snapshots/$name.json').existsSync(), isTrue);
    }
  });
}
