import 'json_read.dart';

/// A Futár-válaszok közös burka.
class FutarEnvelope {
  const FutarEnvelope({
    required this.code,
    required this.currentTime,
    required this.status,
    required this.text,
    required this.version,
    required this.data,
  });

  factory FutarEnvelope.fromJson(Object? json) {
    final map = asJsonMap(json, 'response');
    return FutarEnvelope(
      code: reqInt(map, 'code'),
      currentTime: optInt(map, 'currentTime'),
      status: optString(map, 'status'),
      text: optString(map, 'text'),
      version: optInt(map, 'version'),
      data: optMap(map, 'data') ?? const {},
    );
  }

  final int code;

  /// Szerveridő, UTC epoch ms.
  final int? currentTime;
  final String? status;
  final String? text;
  final int? version;
  final JsonMap data;

  bool get isOk => code == 200 && (status == null || status == 'OK');
}
