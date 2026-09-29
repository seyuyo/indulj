import 'json_read.dart';

/// `arrivals-and-departures-for-stop` → `data.entry`.
class ArrivalsEntryDto {
  const ArrivalsEntryDto({required this.stopTimes, required this.alertIds});

  factory ArrivalsEntryDto.fromJson(JsonMap json) => ArrivalsEntryDto(
    stopTimes: mapList(json, 'stopTimes').map(StopTimeDto.fromJson).toList(),
    alertIds: stringList(json, 'alertIds'),
  );

  final List<StopTimeDto> stopTimes;

  /// Megálló-szintű zavarok.
  final List<String> alertIds;
}

/// Egy indulás; minden idő epoch másodpercben.
class StopTimeDto {
  const StopTimeDto({
    required this.stopId,
    required this.tripId,
    this.stopHeadsign,
    this.arrivalTime,
    this.departureTime,
    this.predictedArrivalTime,
    this.predictedDepartureTime,
    this.canceled = false,
    this.alertIds = const [],
  });

  factory StopTimeDto.fromJson(JsonMap json) => StopTimeDto(
    stopId: reqString(json, 'stopId'),
    tripId: reqString(json, 'tripId'),
    stopHeadsign: optString(json, 'stopHeadsign'),
    arrivalTime: optInt(json, 'arrivalTime'),
    departureTime: optInt(json, 'departureTime'),
    predictedArrivalTime: optInt(json, 'predictedArrivalTime'),
    predictedDepartureTime: optInt(json, 'predictedDepartureTime'),
    canceled: optBool(json, 'canceled') ?? false,
    alertIds: stringList(json, 'alertIds'),
  );

  final String stopId;
  final String tripId;
  final String? stopHeadsign;
  final int? arrivalTime;
  final int? departureTime;
  final int? predictedArrivalTime;
  final int? predictedDepartureTime;
  final bool canceled;
  final List<String> alertIds;
}

/// `search` → `data.entry`.
class SearchEntryDto {
  const SearchEntryDto({required this.stopIds});

  factory SearchEntryDto.fromJson(JsonMap json) =>
      SearchEntryDto(stopIds: stringList(json, 'stopIds'));

  final List<String> stopIds;
}
