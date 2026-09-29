import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/result.dart';
import '../../domain/models.dart';
import 'dto/envelope.dart';
import 'futar_error.dart';
import 'mappers.dart';

/// A BKK FUTÁR API három használt végpontja (`otp` dialektus).
///
/// A hívási gyakoriságot (≥ 30 mp) a hívó felelőssége betartani.
class FutarApiClient {
  FutarApiClient({
    required http.Client client,
    required String apiKey,
    Uri? baseUri,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client,
       _apiKey = apiKey,
       _baseUri = baseUri ?? defaultBaseUri;

  static final defaultBaseUri = Uri.parse(
    'https://futar.bkk.hu/api/query/v1/ws/otp/api/where/',
  );

  /// A fixture-ök ezzel a verzióval készültek (lásd DECISIONS.md).
  static const apiVersion = '4';

  final http.Client _client;
  final String _apiKey;
  final Uri _baseUri;
  final Duration timeout;

  Future<Result<DeparturesResult, FutarError>> departures(
    List<String> stopIds, {
    int minutesBefore = 1,
    int minutesAfter = 60,
    int limit = 20,
  }) => _get('arrivals-and-departures-for-stop', {
    'stopId': stopIds,
    'minutesBefore': '$minutesBefore',
    'minutesAfter': '$minutesAfter',
    'limit': '$limit',
  }, mapArrivals);

  Future<Result<List<Stop>, FutarError>> searchStops(String query) =>
      _get('search', {'query': query}, mapSearch);

  Future<Result<List<Stop>, FutarError>> stopsNearby(
    double lat,
    double lon, {
    int radius = 300,
  }) => _get('stops-for-location', {
    'lat': '$lat',
    'lon': '$lon',
    'radius': '$radius',
  }, mapNearby);

  Future<Result<T, FutarError>> _get<T>(
    String endpoint,
    Map<String, Object> params,
    T Function(FutarEnvelope) map,
  ) async {
    final uri = _baseUri
        .resolve(endpoint)
        .replace(
          queryParameters: {
            ...params,
            'includeReferences': 'true',
            'version': apiVersion,
            'key': _apiKey,
          },
        );

    final http.Response response;
    try {
      response = await _client.get(uri).timeout(timeout);
    } on TimeoutException {
      return const Err(NetworkError('TimeoutException'));
    } on SocketException {
      return const Err(NetworkError('SocketException'));
    } on http.ClientException {
      return const Err(NetworkError('ClientException'));
    }

    if (response.statusCode != 200) {
      return Err(HttpError(response.statusCode));
    }

    try {
      final env = FutarEnvelope.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)),
      );
      if (!env.isOk) return Err(ApiError(env.code, env.text));
      return Ok(map(env));
    } on FormatException catch (e) {
      // A FormatException `source`-a a teljes válasz lehet; csak az üzenet kell.
      return Err(ParseError(e.message));
    }
  }
}
