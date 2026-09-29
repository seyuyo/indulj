import 'package:indulj/core/clock.dart';
import 'package:indulj/domain/departure_board.dart';
import 'package:indulj/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/budapest_time.dart';

const _min = 60 * 1000;

Departure _dep({
  String route = 'R4',
  String trip = 'T1',
  String stop = 'S1',
  required int at,
  int? predicted,
}) => Departure(
  routeId: route,
  routeShortName: route,
  headsign: 'Széll Kálmán tér M',
  tripId: trip,
  stopId: stop,
  routeColor: 0xFFFFD800,
  routeTextColor: 0xFF000000,
  scheduledAtMs: at,
  predictedAtMs: predicted,
);

String _label(int at, int now) => departureLabel(at, now, budapestOffsetMs);

void main() {
  group('budapest test helper', () {
    test('summer and winter offsets', () {
      expect(budapestOffsetMs(budapest(2026, 7, 1, 12, 0)), 2 * 60 * _min);
      expect(budapestOffsetMs(budapest(2026, 12, 1, 12, 0)), 60 * _min);
    });
  });

  group('clock offset', () {
    test('serverOffsetMs is server minus local', () {
      expect(serverOffsetMs(serverTimeMs: 1000, localNowMs: 2200), -1200);
      expect(serverOffsetMs(serverTimeMs: 5000, localNowMs: 2000), 3000);
    });

    test('correctedNowMs applies the offset to the clock', () {
      final clock = FakeClock(10000);
      expect(correctedNowMs(clock, -1200), 8800);
      expect(correctedNowMs(clock, 3000), 13000);
    });

    test('a fast phone clock does not hide a departure', () {
      // A telefon 2 percet siet; a szerver szerint az indulás még 1 perc múlva van.
      final server = budapest(2026, 9, 29, 14, 0);
      final phone = FakeClock(server + 2 * _min);
      final offset = serverOffsetMs(
        serverTimeMs: server,
        localNowMs: phone.nowMs(),
      );
      final now = correctedNowMs(phone, offset);
      final d = _dep(at: server + _min);

      expect(selectDepartures([d], nowMs: now), [d]);
      expect(_label(d.effectiveAtMs, now), '1 perc');
    });
  });

  group('selectDepartures', () {
    final now = budapest(2026, 9, 29, 14, 0);

    test('drops departures more than 30 s in the past', () {
      final gone = _dep(trip: 'a', at: now - 31 * 1000);
      final edge = _dep(trip: 'b', at: now - 30 * 1000);
      final future = _dep(trip: 'c', at: now + _min);

      expect(selectDepartures([gone, edge, future], nowMs: now), [
        edge,
        future,
      ]);
    });

    test('uses the prediction, not the schedule', () {
      final lateBus = _dep(
        trip: 'a',
        at: now - 2 * _min,
        predicted: now + _min,
      );
      final earlyTram = _dep(
        trip: 'b',
        at: now + 5 * _min,
        predicted: now - _min,
      );

      expect(selectDepartures([lateBus, earlyTram], nowMs: now), [lateBus]);
    });

    test('sorts by effective time', () {
      final a = _dep(trip: 'a', at: now + 10 * _min);
      final b = _dep(trip: 'b', at: now + 20 * _min, predicted: now + 2 * _min);
      final c = _dep(trip: 'c', at: now + 5 * _min);

      expect(selectDepartures([a, b, c], nowMs: now), [b, c, a]);
    });

    test('applies the route filter; null means all routes', () {
      final four = _dep(route: '4', trip: 'a', at: now + _min);
      final six = _dep(route: '6', trip: 'b', at: now + 2 * _min);
      final bus = _dep(route: '105', trip: 'c', at: now + 3 * _min);

      expect(
        selectDepartures([four, six, bus], nowMs: now, routeFilter: {'4', '6'}),
        [four, six],
      );
      expect(selectDepartures([four, six, bus], nowMs: now), hasLength(3));
    });

    test('deduplicates by (tripId, stopId), keeping the first', () {
      final first = _dep(trip: 'a', stop: 'S1', at: now + _min);
      final dupe = _dep(trip: 'a', stop: 'S1', at: now + 2 * _min);
      final otherStop = _dep(trip: 'a', stop: 'S2', at: now + 3 * _min);

      expect(selectDepartures([first, dupe, otherStop], nowMs: now), [
        first,
        otherStop,
      ]);
    });

    test('empty input gives empty output', () {
      expect(selectDepartures([], nowMs: now), isEmpty);
    });
  });

  group('departureLabel', () {
    final now = budapest(2026, 9, 29, 14, 21);

    test('under 60 s is "most", including just-departed', () {
      expect(_label(now, now), 'most');
      expect(_label(now + 59 * 1000, now), 'most');
      expect(_label(now - 20 * 1000, now), 'most');
    });

    test('under 60 minutes is whole minutes, rounded down', () {
      expect(_label(now + 60 * 1000, now), '1 perc');
      expect(_label(now + 3 * _min + 59 * 1000, now), '3 perc');
      expect(_label(now + 59 * _min + 59 * 1000, now), '59 perc');
    });

    test('60 minutes or more is local HH:mm', () {
      expect(_label(now + 60 * _min, now), '15:21');
      expect(_label(budapest(2026, 9, 29, 16, 5), now), '16:05');
    });
  });

  group('midnight', () {
    test('departures after midnight sort after late-evening ones', () {
      final now = budapest(2026, 9, 29, 23, 50);
      final lateEvening = _dep(trip: 'a', at: budapest(2026, 9, 29, 23, 55));
      final afterMidnight = _dep(trip: 'b', at: budapest(2026, 9, 30, 0, 10));
      final nightBus = _dep(trip: 'c', at: budapest(2026, 9, 30, 1, 30));

      final selected = selectDepartures([
        nightBus,
        afterMidnight,
        lateEvening,
      ], nowMs: now);

      expect(selected, [lateEvening, afterMidnight, nightBus]);
      expect(selected.map((d) => _label(d.effectiveAtMs, now)), [
        '5 perc',
        '20 perc',
        '01:30',
      ]);
    });

    test('a departure exactly at midnight is 00:00', () {
      final now = budapest(2026, 9, 29, 22, 30);
      expect(_label(budapest(2026, 9, 30, 0, 0), now), '00:00');
    });
  });

  group('daylight saving', () {
    test('spring forward (2026-03-29): 01:55 CET then 03:05 CEST', () {
      final now = budapest(2026, 3, 29, 0, 0);
      final beforeJump = _dep(
        trip: 'a',
        at: budapest(2026, 3, 29, 1, 55, offsetHours: 1),
      );
      final afterJump = _dep(
        trip: 'b',
        at: budapest(2026, 3, 29, 3, 5, offsetHours: 2),
      );

      // A két indulás közt valójában csak 10 perc telik el.
      expect(afterJump.scheduledAtMs - beforeJump.scheduledAtMs, 10 * _min);
      final selected = selectDepartures([afterJump, beforeJump], nowMs: now);
      expect(selected, [beforeJump, afterJump]);
      expect(selected.map((d) => _label(d.effectiveAtMs, now)), [
        '01:55',
        '03:05',
      ]);
    });

    test('spring forward: minutes count real time across the jump', () {
      final now = budapest(2026, 3, 29, 1, 55, offsetHours: 1);
      final at = budapest(2026, 3, 29, 3, 5, offsetHours: 2);
      expect(_label(at, now), '10 perc');
    });

    test('fall back (2026-10-25): both 02:30s, in real order', () {
      final now = budapest(2026, 10, 25, 0, 0);
      final first = _dep(
        trip: 'a',
        at: budapest(2026, 10, 25, 2, 30, offsetHours: 2),
      );
      final second = _dep(
        trip: 'b',
        at: budapest(2026, 10, 25, 2, 30, offsetHours: 1),
      );

      expect(second.scheduledAtMs - first.scheduledAtMs, 60 * _min);
      final selected = selectDepartures([second, first], nowMs: now);
      expect(selected, [first, second]);
      expect(selected.map((d) => _label(d.effectiveAtMs, now)), [
        '02:30',
        '02:30',
      ]);
    });

    test('fall back: minutes count real time across the repeat', () {
      final now = budapest(2026, 10, 25, 2, 50, offsetHours: 2);
      final at = budapest(2026, 10, 25, 2, 10, offsetHours: 1);
      expect(_label(at, now), '20 perc');
    });
  });

  group('delayMinutes', () {
    const at = 1790000000000;

    test('no prediction means no badge', () {
      expect(delayMinutes(_dep(at: at)), isNull);
    });

    test('under 60 s late means no badge', () {
      expect(delayMinutes(_dep(at: at, predicted: at + 59 * 1000)), isNull);
    });

    test('whole minutes late, rounded down', () {
      expect(delayMinutes(_dep(at: at, predicted: at + 60 * 1000)), 1);
      expect(delayMinutes(_dep(at: at, predicted: at + 2 * _min + 50000)), 2);
    });

    test('running early is not shown', () {
      expect(delayMinutes(_dep(at: at, predicted: at - 3 * _min)), isNull);
    });
  });

  group('buildBoard', () {
    test('combines selection, labels and delays', () {
      final now = budapest(2026, 9, 29, 14, 0);
      final late = _dep(
        route: '4',
        trip: 'a',
        at: now + _min,
        predicted: now + 3 * _min,
      );
      final onTime = _dep(route: '6', trip: 'b', at: now + 2 * _min);
      final filtered = _dep(route: '105', trip: 'c', at: now + _min);
      final gone = _dep(route: '4', trip: 'd', at: now - 5 * _min);

      final rows = buildBoard(
        [late, onTime, filtered, gone],
        nowMs: now,
        offsetOf: budapestOffsetMs,
        routeFilter: {'4', '6'},
      );

      expect(rows.map((r) => r.departure), [onTime, late]);
      expect(rows.map((r) => r.label), ['2 perc', '3 perc']);
      expect(rows.map((r) => r.delayMin), [null, 2]);
    });
  });
}
