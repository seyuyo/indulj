import '../../domain/models.dart';
import 'dto/entries_dto.dart';
import 'dto/envelope.dart';
import 'dto/json_read.dart';
import 'dto/references_dto.dart';

// DTO → domain leképezés. Hibás adatszerkezetnél FormatException-t dob.

const defaultRouteColor = 0xFF757575;
const defaultRouteTextColor = 0xFFFFFFFF;

DeparturesResult mapArrivals(FutarEnvelope env) {
  final entry = ArrivalsEntryDto.fromJson(
    asJsonMap(env.data['entry'], 'entry'),
  );
  final refs = _references(env);

  final departures = <Departure>[];
  for (final st in entry.stopTimes) {
    // A törölt járat nem indul; a widgeten nem mutatjuk.
    if (st.canceled) continue;
    final scheduled = st.departureTime ?? st.arrivalTime;
    if (scheduled == null) continue;
    final predicted = st.predictedDepartureTime ?? st.predictedArrivalTime;

    final trip = refs.trips[st.tripId];
    final route = refs.routes[trip?.routeId];
    departures.add(
      Departure(
        routeId: route?.id ?? trip?.routeId ?? '',
        routeShortName: route?.shortName ?? '?',
        headsign: st.stopHeadsign ?? trip?.tripHeadsign ?? '',
        tripId: st.tripId,
        stopId: st.stopId,
        routeColor: _argb(route?.color, defaultRouteColor),
        routeTextColor: _argb(route?.textColor, defaultRouteTextColor),
        scheduledAtMs: scheduled * 1000,
        predictedAtMs: predicted == null ? null : predicted * 1000,
        alertIds: st.alertIds,
      ),
    );
  }

  return DeparturesResult(
    serverTimeMs: env.currentTime,
    departures: departures,
    stopAlertIds: entry.alertIds,
    alerts: refs.alerts.map((id, a) => MapEntry(id, _alert(a))),
  );
}

/// A keresés találatai az API sorrendjében.
List<Stop> mapSearch(FutarEnvelope env) {
  final entry = SearchEntryDto.fromJson(asJsonMap(env.data['entry'], 'entry'));
  final stops = _references(env).stops;
  return [
    for (final id in entry.stopIds)
      if (stops[id] case final stop?) _stop(stop),
  ];
}

List<Stop> mapNearby(FutarEnvelope env) =>
    mapList(env.data, 'list').map((j) => _stop(StopDto.fromJson(j))).toList();

ReferencesDto _references(FutarEnvelope env) =>
    ReferencesDto.fromJson(optMap(env.data, 'references'));

Stop _stop(StopDto s) => Stop(
  id: s.id,
  name: s.name,
  lat: s.lat,
  lon: s.lon,
  code: s.code,
  direction: s.direction,
  isStation: s.locationType == 1,
  routeIds: s.routeIds,
);

Alert _alert(AlertDto a) => Alert(
  id: a.id,
  header: a.header?.hungarianOrAny ?? '',
  description: a.description?.hungarianOrAny ?? '',
  startMs: a.start == null ? null : a.start! * 1000,
  endMs: a.end == null ? null : a.end! * 1000,
  routeIds: a.routeIds,
  stopIds: a.stopIds,
);

/// `FFD800` → `0xFFFFD800`; `80FFD800` (ARGB) változatlanul.
int _argb(String? hex, int fallback) {
  if (hex == null) return fallback;
  final value = int.tryParse(hex, radix: 16);
  return switch (hex.length) {
    6 when value != null => 0xFF000000 | value,
    8 when value != null => value,
    _ => fallback,
  };
}
