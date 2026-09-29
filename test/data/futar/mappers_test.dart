import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:indulj/data/futar/dto/envelope.dart';
import 'package:indulj/data/futar/mappers.dart';

FutarEnvelope _fixture(String name) => FutarEnvelope.fromJson(
  jsonDecode(File('test/fixtures/$name.json').readAsStringSync()),
);

/// Minimális arrivals-válasz egyetlen stopTime-mal és hozzá tartozó referenciákkal.
FutarEnvelope _arrivals(
  List<Map<String, Object?>> stopTimes, {
  Map<String, Object?> route = const {
    'id': 'BKK_3040',
    'shortName': '4',
    'color': 'FFD800',
    'textColor': '000000',
  },
  Map<String, Object?> extraEntry = const {},
}) => FutarEnvelope.fromJson({
  'currentTime': 1790683286850,
  'version': 4,
  'status': 'OK',
  'code': 200,
  'text': 'OK',
  'data': {
    'entry': {'stopId': 'S1', 'stopTimes': stopTimes, ...extraEntry},
    'references': {
      'routes': {route['id']! as String: route},
      'trips': {
        'T1': {'id': 'T1', 'routeId': route['id'], 'tripHeadsign': 'Trip fej'},
      },
    },
  },
});

Map<String, Object?> _stopTime([Map<String, Object?> overrides = const {}]) => {
  'stopId': 'S1',
  'tripId': 'T1',
  'stopHeadsign': 'Széll Kálmán tér M',
  'arrivalTime': 1790683200,
  'departureTime': 1790683260,
  'alertIds': <String>[],
  ...overrides,
};

void main() {
  group('fixtures', () {
    test('arrivals_oktogon_day maps to departures', () {
      final env = _fixture('arrivals_oktogon_day');
      final result = mapArrivals(env);

      expect(result.serverTimeMs, env.currentTime);
      expect(result.departures, hasLength(20));
      expect(result.departures.where((d) => d.isRealtime), hasLength(14));
      for (final d in result.departures) {
        expect(d.routeShortName, isNotEmpty);
        expect(d.routeId, startsWith('BKK_'));
        expect(d.headsign, isNotEmpty);
        expect(d.stopId, anyOf('BKK_F01081', 'BKK_F01082'));
        // mp → ms: a szerveridő környékén kell lennie (±2 óra)
        expect(
          (d.scheduledAtMs - env.currentTime!).abs(),
          lessThan(2 * 3600 * 1000),
        );
        expect(d.routeColor >>> 24, 0xFF);
      }
    });

    test('arrivals_oktogon_day carries the stop-level alert', () {
      final result = mapArrivals(_fixture('arrivals_oktogon_day'));

      expect(result.stopAlertIds, ['BKK_bkkinfo-149022']);
      final alert = result.alerts['BKK_bkkinfo-149022']!;
      expect(alert.header, 'nem közlekedik a teljes vonalon');
      expect(alert.startMs, 1790560800000);
      expect(alert.endMs, 1795388340000);
    });

    test('search_oktogon maps to stops in API order', () {
      final stops = mapSearch(_fixture('search_oktogon'));

      expect(stops, isNotEmpty);
      expect(stops.first.id, 'BKK_CSF01082');
      expect(stops.first.name, 'Oktogon');
      expect(stops.first.isStation, isTrue);
      expect(stops.where((s) => !s.isStation), isNotEmpty);
      final platform = stops.firstWhere((s) => s.id == 'BKK_F01081');
      expect(platform.routeShortNames, ['4', '4-6', '6']);
      expect(platform.direction, '137');
    });

    test('nearby_oktogon maps to stops with coordinates', () {
      final stops = mapNearby(_fixture('nearby_oktogon'));

      expect(stops, isNotEmpty);
      for (final s in stops) {
        expect(s.lat, closeTo(47.505, 0.01));
        expect(s.lon, closeTo(19.064, 0.01));
      }
      expect(stops.expand((s) => s.routeShortNames), isNotEmpty);
    });
  });

  group('arrivals edge cases', () {
    test('converts seconds to ms and uses departure over arrival', () {
      final d = mapArrivals(_arrivals([_stopTime()])).departures.single;

      expect(d.scheduledAtMs, 1790683260000);
      expect(d.predictedAtMs, isNull);
      expect(d.isRealtime, isFalse);
      expect(d.effectiveAtMs, 1790683260000);
    });

    test('falls back to arrivalTime when departureTime is missing', () {
      final d = mapArrivals(
        _arrivals([
          _stopTime({'departureTime': null}),
        ]),
      ).departures.single;

      expect(d.scheduledAtMs, 1790683200000);
    });

    test('uses predicted departure, then predicted arrival', () {
      final both = mapArrivals(
        _arrivals([
          _stopTime({
            'predictedArrivalTime': 1790683300,
            'predictedDepartureTime': 1790683320,
          }),
        ]),
      ).departures.single;
      final arrivalOnly = mapArrivals(
        _arrivals([
          _stopTime({'predictedArrivalTime': 1790683300}),
        ]),
      ).departures.single;

      expect(both.predictedAtMs, 1790683320000);
      expect(both.effectiveAtMs, 1790683320000);
      expect(arrivalOnly.predictedAtMs, 1790683300000);
    });

    test('drops canceled trips and rows without any time', () {
      final result = mapArrivals(
        _arrivals([
          _stopTime({'canceled': true}),
          _stopTime({'arrivalTime': null, 'departureTime': null}),
          _stopTime(),
        ]),
      );

      expect(result.departures, hasLength(1));
    });

    test('route data and colors come from references', () {
      final d = mapArrivals(_arrivals([_stopTime()])).departures.single;

      expect(d.routeId, 'BKK_3040');
      expect(d.routeShortName, '4');
      expect(d.routeColor, 0xFFFFD800);
      expect(d.routeTextColor, 0xFF000000);
    });

    test('missing colors fall back to neutral defaults', () {
      final d = mapArrivals(
        _arrivals([_stopTime()], route: {'id': 'R', 'shortName': '9'}),
      ).departures.single;

      expect(d.routeColor, defaultRouteColor);
      expect(d.routeTextColor, defaultRouteTextColor);
    });

    test('headsign falls back to trip headsign', () {
      final d = mapArrivals(
        _arrivals([
          _stopTime({'stopHeadsign': null}),
        ]),
      ).departures.single;

      expect(d.headsign, 'Trip fej');
    });

    test('unknown fields are ignored', () {
      final result = mapArrivals(
        _arrivals(
          [
            _stopTime({'brandNewField': 42}),
          ],
          extraEntry: {'somethingElse': <String, Object?>{}},
        ),
      );

      expect(result.departures, hasLength(1));
    });

    test('empty stopTimes gives empty departures', () {
      final result = mapArrivals(_arrivals([]));

      expect(result.departures, isEmpty);
      expect(result.stopAlertIds, isEmpty);
      expect(result.alerts, isEmpty);
    });

    test('wrong field type is a FormatException', () {
      expect(
        () => mapArrivals(
          _arrivals([
            _stopTime({'departureTime': 'soon'}),
          ]),
        ),
        throwsFormatException,
      );
    });
  });

  group('envelope', () {
    test('non-map body is a FormatException', () {
      expect(() => FutarEnvelope.fromJson([1, 2]), throwsFormatException);
    });

    test('error envelope without data parses', () {
      final env = FutarEnvelope.fromJson({
        'code': 401,
        'status': 'UNAUTHORIZED',
        'text': 'Invalid key',
        'currentTime': 1,
      });

      expect(env.code, 401);
      expect(env.isOk, isFalse);
      expect(env.data, isEmpty);
    });
  });
}
