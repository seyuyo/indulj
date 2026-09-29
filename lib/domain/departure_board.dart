// Tiszta indulás-logika (SPEC 6.). Nincs Flutter import, nincs DateTime.now():
// a „most"-ot a hívó adja, már óraeltéréssel korrigálva.

import '../core/clock.dart';
import 'models.dart';

/// UTC epoch ms → az adott pillanatban érvényes helyi UTC-eltolás (ms).
typedef UtcOffsetOf = int Function(int utcMs);

const _secondMs = 1000;
const _minuteMs = 60 * _secondMs;

/// Ennyivel az indulás után még mutatjuk a járatot.
const departedGraceMs = 30 * _secondMs;

/// A szerveróra és a telefon órájának különbsége a lekérés pillanatában.
int serverOffsetMs({required int serverTimeMs, required int localNowMs}) =>
    serverTimeMs - localNowMs;

/// A telefon órája, a szerverhez igazítva.
int correctedNowMs(Clock clock, int serverOffsetMs) =>
    clock.nowMs() + serverOffsetMs;

/// Szűr (elment járatok, járatszűrő), duplikátum-mentesít `(tripId, stopId)`
/// szerint, és `effectiveAt` szerint rendez.
List<Departure> selectDepartures(
  List<Departure> departures, {
  required int nowMs,
  Set<String>? routeFilter,
}) {
  final seen = <(String, String)>{};
  final result = [
    for (final d in departures)
      if (d.effectiveAtMs >= nowMs - departedGraceMs &&
          (routeFilter == null || routeFilter.contains(d.routeId)) &&
          seen.add((d.tripId, d.stopId)))
        d,
  ];
  // Stabil rendezés: azonos időpontnál az eredeti sorrend marad.
  final indexed = result.indexed.toList()
    ..sort((a, b) {
      final byTime = a.$2.effectiveAtMs.compareTo(b.$2.effectiveAtMs);
      return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
    });
  return [for (final (_, d) in indexed) d];
}

/// „most" 60 mp alatt, „N perc" 60 perc alatt, különben helyi „HH:mm".
String departureLabel(int atMs, int nowMs, UtcOffsetOf offsetOf) {
  final diff = atMs - nowMs;
  if (diff < _minuteMs) return 'most';
  if (diff < 60 * _minuteMs) return '${diff ~/ _minuteMs} perc';
  return formatLocalTime(atMs, offsetOf);
}

/// UTC epoch ms → helyi „HH:mm".
String formatLocalTime(int utcMs, UtcOffsetOf offsetOf) {
  final local = DateTime.fromMillisecondsSinceEpoch(
    utcMs + offsetOf(utcMs),
    isUtc: true,
  );
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}

/// Késés egész percben, ha legalább 60 mp; sietést nem jelzünk.
int? delayMinutes(Departure d) {
  final predicted = d.predictedAtMs;
  if (predicted == null) return null;
  final late = predicted - d.scheduledAtMs;
  return late >= _minuteMs ? late ~/ _minuteMs : null;
}

class BoardRow {
  const BoardRow({
    required this.departure,
    required this.label,
    required this.delayMin,
  });

  final Departure departure;
  final String label;
  final int? delayMin;
}

/// A tábla sorai: kiválasztás + felirat + késés.
List<BoardRow> buildBoard(
  List<Departure> departures, {
  required int nowMs,
  required UtcOffsetOf offsetOf,
  Set<String>? routeFilter,
}) => [
  for (final d in selectDepartures(
    departures,
    nowMs: nowMs,
    routeFilter: routeFilter,
  ))
    BoardRow(
      departure: d,
      label: departureLabel(d.effectiveAtMs, nowMs, offsetOf),
      delayMin: delayMinutes(d),
    ),
];
