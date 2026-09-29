// Domain-modellek. Tiszta Dart: nincs Flutter import. Minden idő UTC epoch ms.

/// Kedvenc megállócsoport: több `stopId` (peron vagy állomás) együtt.
class StopGroup {
  const StopGroup({
    required this.id,
    required this.name,
    required this.stopIds,
    this.routeFilter,
  });

  final String id;
  final String name;
  final List<String> stopIds;

  /// `routeId`-k; null = minden járat.
  final Set<String>? routeFilter;

  StopGroup copyWith({String? name, Set<String>? Function()? routeFilter}) =>
      StopGroup(
        id: id,
        name: name ?? this.name,
        stopIds: stopIds,
        routeFilter: routeFilter == null ? this.routeFilter : routeFilter(),
      );
}

class Departure {
  const Departure({
    required this.routeId,
    required this.routeShortName,
    required this.headsign,
    required this.tripId,
    required this.stopId,
    required this.routeColor,
    required this.routeTextColor,
    required this.scheduledAtMs,
    this.predictedAtMs,
    this.alertIds = const [],
  });

  final String routeId, routeShortName, headsign, tripId, stopId;

  /// ARGB.
  final int routeColor, routeTextColor;
  final int scheduledAtMs;

  /// Valós idejű előrejelzés, ha van.
  final int? predictedAtMs;
  final List<String> alertIds;

  bool get isRealtime => predictedAtMs != null;
  int get effectiveAtMs => predictedAtMs ?? scheduledAtMs;
}

class Stop {
  const Stop({
    required this.id,
    required this.name,
    this.lat,
    this.lon,
    this.code,
    this.direction,
    this.isStation = false,
    this.routeIds = const [],
    this.routeShortNames = const [],
  });

  final String id;
  final String name;
  final double? lat;
  final double? lon;
  final String? code;
  final String? direction;

  /// Több peront összefogó „stop-area".
  final bool isStation;
  final List<String> routeIds;

  /// A megállót érintő járatok rövid neve (pl. `4`, `6`), duplikátum nélkül.
  final List<String> routeShortNames;
}

class Alert {
  const Alert({
    required this.id,
    required this.header,
    required this.description,
    this.startMs,
    this.endMs,
    this.routeIds = const [],
    this.stopIds = const [],
  });

  final String id;
  final String header;
  final String description;
  final int? startMs;
  final int? endMs;
  final List<String> routeIds;
  final List<String> stopIds;
}

class DeparturesResult {
  const DeparturesResult({
    required this.serverTimeMs,
    required this.departures,
    this.stopAlertIds = const [],
    this.alerts = const {},
  });

  /// A válasz `currentTime`-ja; ebből számoljuk az óraeltérést.
  final int? serverTimeMs;
  final List<Departure> departures;

  /// Megálló-szintű zavarok (nem egy járathoz kötöttek).
  final List<String> stopAlertIds;
  final Map<String, Alert> alerts;
}
