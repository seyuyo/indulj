import 'json_read.dart';

/// `data.references`: ID szerint kulcsolt referenciatérképek.
class ReferencesDto {
  const ReferencesDto({
    required this.routes,
    required this.trips,
    required this.stops,
    required this.alerts,
  });

  factory ReferencesDto.fromJson(JsonMap? json) {
    final map = json ?? const {};
    return ReferencesDto(
      routes: mapOfMaps(
        map,
        'routes',
      ).map((k, v) => MapEntry(k, RouteDto.fromJson(v))),
      trips: mapOfMaps(
        map,
        'trips',
      ).map((k, v) => MapEntry(k, TripDto.fromJson(v))),
      stops: mapOfMaps(
        map,
        'stops',
      ).map((k, v) => MapEntry(k, StopDto.fromJson(v))),
      alerts: mapOfMaps(
        map,
        'alerts',
      ).map((k, v) => MapEntry(k, AlertDto.fromJson(v))),
    );
  }

  final Map<String, RouteDto> routes;
  final Map<String, TripDto> trips;
  final Map<String, StopDto> stops;
  final Map<String, AlertDto> alerts;
}

class RouteDto {
  const RouteDto({
    required this.id,
    this.shortName,
    this.color,
    this.textColor,
    this.type,
  });

  factory RouteDto.fromJson(JsonMap json) => RouteDto(
    id: reqString(json, 'id'),
    shortName: optString(json, 'shortName'),
    color: optString(json, 'color'),
    textColor: optString(json, 'textColor'),
    type: optString(json, 'type'),
  );

  final String id;
  final String? shortName;

  /// Hex RGB, pl. `FFD800`.
  final String? color;
  final String? textColor;
  final String? type;
}

class TripDto {
  const TripDto({required this.id, this.routeId, this.tripHeadsign});

  factory TripDto.fromJson(JsonMap json) => TripDto(
    id: reqString(json, 'id'),
    routeId: optString(json, 'routeId'),
    tripHeadsign: optString(json, 'tripHeadsign'),
  );

  final String id;
  final String? routeId;
  final String? tripHeadsign;
}

class StopDto {
  const StopDto({
    required this.id,
    required this.name,
    this.lat,
    this.lon,
    this.code,
    this.direction,
    this.locationType,
    this.routeIds = const [],
  });

  factory StopDto.fromJson(JsonMap json) => StopDto(
    id: reqString(json, 'id'),
    name: optString(json, 'name') ?? '',
    lat: optDouble(json, 'lat'),
    lon: optDouble(json, 'lon'),
    code: optString(json, 'code'),
    direction: optString(json, 'direction'),
    locationType: optInt(json, 'locationType'),
    routeIds: stringList(json, 'routeIds'),
  );

  final String id;
  final String name;
  final double? lat;
  final double? lon;
  final String? code;
  final String? direction;

  /// 0 = megálló (peron), 1 = állomás / stop-area.
  final int? locationType;
  final List<String> routeIds;
}

class AlertDto {
  const AlertDto({
    required this.id,
    this.start,
    this.end,
    this.header,
    this.description,
    this.routeIds = const [],
    this.stopIds = const [],
  });

  factory AlertDto.fromJson(JsonMap json) => AlertDto(
    id: reqString(json, 'id'),
    start: optInt(json, 'start'),
    end: optInt(json, 'end'),
    header: TranslatedStringDto.fromJson(optMap(json, 'header')),
    description: TranslatedStringDto.fromJson(optMap(json, 'description')),
    routeIds: stringList(json, 'routeIds'),
    stopIds: stringList(json, 'stopIds'),
  );

  final String id;

  /// Epoch másodperc.
  final int? start;
  final int? end;
  final TranslatedStringDto? header;
  final TranslatedStringDto? description;
  final List<String> routeIds;
  final List<String> stopIds;
}

/// `{"translations": {"hu": …, "en": …}, "someTranslation": …}`
class TranslatedStringDto {
  const TranslatedStringDto({required this.translations, this.some});

  static TranslatedStringDto? fromJson(JsonMap? json) {
    if (json == null) return null;
    final translations = (optMap(json, 'translations') ?? const {}).map(
      (k, v) => MapEntry(
        k,
        v is String ? v : throw FormatException('translations.$k: $v'),
      ),
    );
    return TranslatedStringDto(
      translations: translations,
      some: optString(json, 'someTranslation'),
    );
  }

  final Map<String, String> translations;
  final String? some;

  String get hungarianOrAny => translations['hu'] ?? some ?? '';
}
