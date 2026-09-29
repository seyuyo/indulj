import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:indulj/core/result.dart';
import 'package:indulj/data/futar/futar_api_client.dart';
import 'package:indulj/data/futar/futar_error.dart';

const _key = 'secret-test-key';

String _fixture(String name) =>
    File('test/fixtures/$name.json').readAsStringSync();

http.Response _utf8(String body, [int status = 200]) => http.Response.bytes(
  utf8.encode(body),
  status,
  headers: {'content-type': 'application/json'},
);

({FutarApiClient client, List<Uri> requests}) _clientReturning(
  FutureOr<http.Response> Function(http.Request) handler, {
  Duration timeout = const Duration(seconds: 10),
}) {
  final requests = <Uri>[];
  final client = FutarApiClient(
    client: MockClient((req) async {
      requests.add(req.url);
      return handler(req);
    }),
    apiKey: _key,
    timeout: timeout,
  );
  return (client: client, requests: requests);
}

T _ok<T>(Result<T, FutarError> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final error) => fail('expected Ok, got $error'),
};

FutarError _err<T>(Result<T, FutarError> result) => switch (result) {
  Ok() => fail('expected Err'),
  Err(:final error) => error,
};

void main() {
  group('requests', () {
    test('departures sends all stopIds and fixed parameters', () async {
      final t = _clientReturning(
        (_) => _utf8(_fixture('arrivals_oktogon_day')),
      );

      _ok(await t.client.departures(['BKK_F01081', 'BKK_F01082']));

      final uri = t.requests.single;
      expect(uri.host, 'futar.bkk.hu');
      expect(
        uri.path,
        '/api/query/v1/ws/otp/api/where/arrivals-and-departures-for-stop',
      );
      expect(uri.queryParametersAll['stopId'], ['BKK_F01081', 'BKK_F01082']);
      expect(uri.queryParameters, containsPair('minutesBefore', '1'));
      expect(uri.queryParameters, containsPair('minutesAfter', '60'));
      expect(uri.queryParameters, containsPair('limit', '20'));
      expect(uri.queryParameters, containsPair('includeReferences', 'true'));
      expect(uri.queryParameters, containsPair('version', '4'));
      expect(uri.queryParameters, containsPair('key', _key));
    });

    test('searchStops sends the query', () async {
      final t = _clientReturning((_) => _utf8(_fixture('search_oktogon')));

      final stops = _ok(await t.client.searchStops('Oktogon'));

      expect(stops.first.name, 'Oktogon');
      expect(t.requests.single.path, endsWith('/search'));
      expect(t.requests.single.queryParameters['query'], 'Oktogon');
    });

    test('stopsNearby sends coordinates and radius', () async {
      final t = _clientReturning((_) => _utf8(_fixture('nearby_oktogon')));

      final stops = _ok(await t.client.stopsNearby(47.5054, 19.0636));

      expect(stops, isNotEmpty);
      final q = t.requests.single.queryParameters;
      expect(t.requests.single.path, endsWith('/stops-for-location'));
      expect(q['lat'], '47.5054');
      expect(q['lon'], '19.0636');
      expect(q['radius'], '300');
    });
  });

  group('success', () {
    test('departures maps the fixture and keeps server time', () async {
      final t = _clientReturning(
        (_) => _utf8(_fixture('arrivals_oktogon_day')),
      );

      final result = _ok(await t.client.departures(['BKK_F01081']));

      expect(result.departures, hasLength(20));
      expect(result.serverTimeMs, isNotNull);
    });

    test('decodes UTF-8 even without charset header', () async {
      final t = _clientReturning(
        (_) =>
            http.Response.bytes(utf8.encode(_fixture('search_oktogon')), 200),
      );

      final stops = _ok(await t.client.searchStops('Oktogon'));

      expect(stops.map((s) => s.name), everyElement(isNot(contains('Ã'))));
    });
  });

  group('errors', () {
    test('HTTP 401 is an unauthorized HttpError', () async {
      final t = _clientReturning(
        (_) => http.Response('Invalid API key. Please register', 401),
      );

      final error = _err(await t.client.searchStops('x'));

      expect(error, isA<HttpError>().having((e) => e.status, 'status', 401));
      expect((error as HttpError).isUnauthorized, isTrue);
    });

    test('HTTP 500 is an HttpError', () async {
      final t = _clientReturning((_) => http.Response('oops', 500));

      expect(
        _err(await t.client.departures(['S'])),
        isA<HttpError>().having((e) => e.isUnauthorized, 'unauth', isFalse),
      );
    });

    test('envelope error code is an ApiError', () async {
      final t = _clientReturning(
        (_) => _utf8(
          jsonEncode({
            'code': 404,
            'status': 'NOT_FOUND',
            'text': 'No such stop',
            'currentTime': 1,
          }),
        ),
      );

      expect(
        _err(await t.client.departures(['S'])),
        isA<ApiError>()
            .having((e) => e.code, 'code', 404)
            .having((e) => e.text, 'text', 'No such stop'),
      );
    });

    test('invalid JSON is a ParseError', () async {
      final t = _clientReturning((_) => _utf8('<html>nope</html>'));

      expect(_err(await t.client.searchStops('x')), isA<ParseError>());
    });

    test('wrong structure is a ParseError', () async {
      final t = _clientReturning(
        (_) => _utf8(
          jsonEncode({
            'code': 200,
            'status': 'OK',
            'data': {'entry': 'not an object'},
          }),
        ),
      );

      expect(_err(await t.client.departures(['S'])), isA<ParseError>());
    });

    test('socket failure is a NetworkError', () async {
      final t = _clientReturning(
        (_) => throw const SocketException('failed host lookup'),
      );

      expect(_err(await t.client.searchStops('x')), isA<NetworkError>());
    });

    test('client exception is a NetworkError', () async {
      final t = _clientReturning(
        (req) => throw http.ClientException('Connection closed', req.url),
      );

      expect(_err(await t.client.searchStops('x')), isA<NetworkError>());
    });

    test('timeout is a NetworkError', () async {
      final t = _clientReturning(
        (_) => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 10),
      );

      expect(
        _err(await t.client.searchStops('x')),
        isA<NetworkError>().having((e) => e.kind, 'kind', 'TimeoutException'),
      );
    });

    test('no error ever mentions the key', () async {
      final handlers = <FutureOr<http.Response> Function(http.Request)>[
        (req) => throw http.ClientException('failed: ${req.url}', req.url),
        (req) => throw SocketException('failed: ${req.url}'),
        (_) => http.Response('Invalid key $_key', 401),
        (_) => _utf8('{"code": 500, "text": "bad", "currentTime": 1}'),
        (_) => _utf8('not json $_key'),
      ];
      for (final handler in handlers) {
        final t = _clientReturning(handler);
        final error = _err(await t.client.searchStops('x'));
        expect(error.toString(), isNot(contains(_key)));
        expect(error.toString(), isNot(contains('futar.bkk.hu')));
      }
    });
  });
}
