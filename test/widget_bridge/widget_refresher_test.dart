import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:indulj/core/clock.dart';
import 'package:indulj/features/favorites/favorites_repository.dart';
import 'package:indulj/widget_bridge/snapshot_codec.dart';
import 'package:indulj/widget_bridge/widget_refresher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

const _fixture = 'arrivals_oktogon_day';
const _groups =
    '{"v":1,"groups":[{"id":"g1","name":"Oktogon",'
    '"stopIds":["BKK_F01081","BKK_F01082"]}]}';

void main() {
  late CountingApi api;
  late FakeClock clock;
  late FakeWidgetStore store;
  late SharedPreferences prefs;

  Future<WidgetRefresher> refresher({
    Map<String, Object> extra = const {},
  }) async {
    SharedPreferences.setMockInitialValues({
      FavoritesRepository.storageKey: _groups,
      ...extra,
    });
    prefs = await SharedPreferences.getInstance();
    return WidgetRefresher(
      api: api.client,
      clock: clock,
      prefs: prefs,
      store: store,
    );
  }

  WidgetSnapshot snapshot(int id) => decodeSnapshot(store.snapshots[id]!);

  setUp(() {
    api = CountingApi((_) => jsonResponse(fixture(_fixture)));
    clock = FakeClock(fixtureServerTime(_fixture));
    store = FakeWidgetStore([7]);
  });

  test('assign stores the group and writes a fresh snapshot', () async {
    final r = await refresher();
    await r.assign(7, 'g1');

    expect(r.groupOf(7), 'g1');
    expect(api.requests, hasLength(1));
    final s = snapshot(7);
    expect(s.groupName, 'Oktogon');
    expect(s.error, isNull);
    expect(s.departures, isNotEmpty);
    expect(s.departures.length, lessThanOrEqualTo(snapshotMaxDepartures));
    expect(s.hasAlerts, isTrue); // az Oktogon-fixture-ben van zavar
    expect(store.redraws, 1);
  });

  test('a widget without a group shows noGroup, no API call', () async {
    final r = await refresher();
    await r.refresh(7);

    expect(snapshot(7).error, WidgetError.noGroup);
    expect(api.requests, isEmpty);
  });

  test('a deleted group turns into noGroup', () async {
    final r = await refresher(extra: {WidgetRefresher.groupKey(7): 'gone'});
    await r.refresh(7);

    expect(snapshot(7).error, WidgetError.noGroup);
  });

  test('never calls the API twice within 30 s, even across isolates', () async {
    final first = await refresher();
    await first.assign(7, 'g1');

    // Új példány = új háttér-isolate: a korlát a prefs-ből jön.
    clock.advance(const Duration(seconds: 29));
    final second = WidgetRefresher(
      api: api.client,
      clock: clock,
      prefs: prefs,
      store: store,
    );
    await second.refresh(7);
    expect(api.requests, hasLength(1));
    expect(store.redraws, 2); // újrarajzolás igen

    clock.advance(const Duration(seconds: 1));
    await second.refresh(7);
    expect(api.requests, hasLength(2));
  });

  test('network error keeps old rows, and retry is allowed at once', () async {
    final r = await refresher();
    await r.assign(7, 'g1');
    final good = snapshot(7);

    clock.advance(const Duration(seconds: 31));
    api.handler = (_) => throw const SocketException('offline');
    final r2 = WidgetRefresher(
      api: api.client,
      clock: clock,
      prefs: prefs,
      store: store,
    );
    await r2.refresh(7);

    final s = snapshot(7);
    expect(s.error, WidgetError.network);
    expect(s.departures.length, good.departures.length);
    expect(s.fetchedAtMs, good.fetchedAtMs);

    await r2.refresh(7); // hálózati hiba nem számít kérésnek
    expect(api.requests, hasLength(3));
  });

  test('invalid key is unauthorized and throttled', () async {
    api.handler = (_) => http.Response('Invalid API key', 401);
    final r = await refresher(extra: {WidgetRefresher.groupKey(7): 'g1'});
    await r.refresh(7);

    expect(snapshot(7).error, WidgetError.unauthorized);
    expect(snapshot(7).departures, isEmpty);

    await r.refresh(7);
    expect(api.requests, hasLength(1));
  });

  test('refreshAll covers every installed widget, then redraws once', () async {
    store.installed = [7, 8];
    final r = await refresher(
      extra: {
        WidgetRefresher.groupKey(7): 'g1',
        WidgetRefresher.groupKey(8): 'g1',
      },
    );
    await r.refreshAll();

    expect(store.snapshots.keys, unorderedEquals([7, 8]));
    expect(store.redraws, 1);
  });

  test('schedules future redraws from every widget, sorted', () async {
    store.installed = [7, 8];
    final r = await refresher(
      extra: {
        WidgetRefresher.groupKey(7): 'g1',
        WidgetRefresher.groupKey(8): 'g1',
      },
    );
    await r.refreshAll();

    final now = clock.nowMs();
    expect(store.scheduled, isNotEmpty);
    expect(store.scheduled.every((t) => t > now), isTrue);
    expect(store.scheduled, orderedEquals([...store.scheduled]..sort()));
    // Két azonos csoportú widget ugyanazokat az időpontokat adja: nincs dupla.
    expect(store.scheduled.toSet(), hasLength(store.scheduled.length));
    expect(
      store.scheduled.length,
      lessThanOrEqualTo(WidgetRefresher.maxScheduledRedraws),
    );
    expect(
      store.scheduled,
      contains(
        decodeSnapshot(store.snapshots[7]!).fetchedAtMs + 20 * 60000 + 1000,
      ),
    );
  });

  test('a corrupt previous snapshot is ignored on error', () async {
    api.handler = (_) => http.Response('down', 503);
    final r = await refresher(extra: {WidgetRefresher.groupKey(7): 'g1'});
    store.snapshots[7] = 'garbage';
    await r.refresh(7);

    expect(snapshot(7).error, WidgetError.server);
    expect(snapshot(7).departures, isEmpty);
  });
}
