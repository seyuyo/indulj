// Élő smoke-teszt a valódi API ellen. Alapból nem fut:
//   flutter test --tags live --dart-define-from-file=env.json
@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:indulj/core/env.dart';
import 'package:indulj/core/result.dart';
import 'package:indulj/data/futar/futar_api_client.dart';

void main() {
  final skip = Env.futarApiKey.isEmpty
      ? 'Nincs FUTAR_API_KEY (--dart-define-from-file=env.json)'
      : null;

  late http.Client httpClient;
  late FutarApiClient client;
  setUp(() {
    httpClient = http.Client();
    client = FutarApiClient(client: httpClient, apiKey: Env.futarApiKey);
  });
  tearDown(() => httpClient.close());

  test('search → departures round trip (Oktogon)', () async {
    final stops = switch (await client.searchStops('Oktogon')) {
      Ok(:final value) => value,
      Err(:final error) => fail('search: $error'),
    };
    final platformIds = stops
        .where((s) => !s.isStation)
        .map((s) => s.id)
        .take(2)
        .toList();
    expect(platformIds, isNotEmpty);

    final result = switch (await client.departures(platformIds)) {
      Ok(:final value) => value,
      Err(:final error) => fail('departures: $error'),
    };
    expect(result.serverTimeMs, isNotNull);
  }, skip: skip);

  test('nearby stops around Oktogon', () async {
    final result = await client.stopsNearby(47.5054, 19.0636);
    expect(result, isA<Ok<Object?, Object>>());
  }, skip: skip);
}
