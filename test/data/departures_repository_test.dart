import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:indulj/core/clock.dart';
import 'package:indulj/core/result.dart';
import 'package:indulj/data/departures_repository.dart';
import 'package:indulj/data/futar/futar_error.dart';

import '../support/fakes.dart';

void main() {
  const name = 'arrivals_oktogon_day';
  late CountingApi api;
  late FakeClock clock;
  late DeparturesRepository repo;

  setUp(() {
    api = CountingApi((_) => jsonResponse(fixture(name)));
    clock = FakeClock(fixtureServerTime(name) + 1500);
    repo = DeparturesRepository(api: api.client, clock: clock);
  });

  DeparturesSnapshot ok(Result<DeparturesSnapshot, FutarError> r) =>
      switch (r) {
        Ok(:final value) => value,
        Err(:final error) => fail('expected Ok, got $error'),
      };

  test('computes the server clock offset and fetch time', () async {
    final snap = ok(await repo.fetch(['A']));

    expect(snap.serverOffsetMs, -1500);
    expect(snap.fetchedAtMs, clock.nowMs());
    expect(snap.result.departures, isNotEmpty);
  });

  test('never calls the API more often than every 30 s', () async {
    final first = ok(await repo.fetch(['A', 'B']));
    clock.advance(const Duration(seconds: 29));
    final second = ok(await repo.fetch(['B', 'A'])); // más sorrend, ugyanaz

    expect(api.requests, hasLength(1));
    expect(identical(first, second), isTrue);

    clock.advance(const Duration(seconds: 1));
    await repo.fetch(['A', 'B']);
    expect(api.requests, hasLength(2));
  });

  test('different stop sets are throttled separately', () async {
    await repo.fetch(['A']);
    await repo.fetch(['B']);

    expect(api.requests, hasLength(2));
  });

  test('concurrent calls share one request', () async {
    final gate = Completer<void>();
    api.handler = (_) async {
      await gate.future;
      return jsonResponse(fixture(name));
    };

    final a = repo.fetch(['A']);
    final b = repo.fetch(['A']);
    gate.complete();
    await Future.wait([a, b]);

    expect(api.requests, hasLength(1));
  });

  test('network errors do not count, retry is immediate', () async {
    api.handler = (_) => throw const SocketException('offline');
    expect(await repo.fetch(['A']), isA<Err<Object?, FutarError>>());

    api.handler = (_) => jsonResponse(fixture(name));
    ok(await repo.fetch(['A']));

    expect(api.requests, hasLength(2));
  });

  test('server errors are throttled too', () async {
    api.handler = (_) => http.Response('down', 503);
    await repo.fetch(['A']);
    clock.advance(const Duration(seconds: 10));
    final again = await repo.fetch(['A']);

    expect(api.requests, hasLength(1));
    expect(
      again,
      isA<Err<DeparturesSnapshot, FutarError>>().having(
        (e) => e.error,
        'error',
        isA<HttpError>(),
      ),
    );
  });

  test('a server error after success keeps serving the good data', () async {
    final good = ok(await repo.fetch(['A']));
    clock.advance(const Duration(seconds: 31));
    api.handler = (_) => http.Response('down', 503);

    expect(await repo.fetch(['A']), isA<Err<Object?, FutarError>>());
    clock.advance(const Duration(seconds: 5));
    expect(identical(ok(await repo.fetch(['A'])), good), isTrue);
    expect(api.requests, hasLength(2));
  });
}
