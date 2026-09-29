import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indulj/app/providers.dart';
import 'package:indulj/core/clock.dart';
import 'package:indulj/features/favorites/favorites_repository.dart';
import 'package:indulj/main.dart';
import 'package:indulj/widget_bridge/snapshot_codec.dart';
import 'package:indulj/widget_bridge/widget_refresher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

const _fixture = 'arrivals_oktogon_day';

void main() {
  testWidgets('configure launch picks a group and finishes', (tester) async {
    SharedPreferences.setMockInitialValues({
      FavoritesRepository.storageKey:
          '{"v":1,"groups":[{"id":"g1","name":"Oktogon","stopIds":["S"]},'
          '{"id":"g2","name":"Otthon","stopIds":["T"]}]}',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = FakeWidgetStore([42]);
    final api = CountingApi((_) => jsonResponse(fixture(_fixture)));
    var finished = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          futarApiClientProvider.overrideWithValue(api.client),
          clockProvider.overrideWithValue(
            FakeClock(fixtureServerTime(_fixture)),
          ),
          widgetStoreProvider.overrideWithValue(store),
          finishWidgetConfigureProvider.overrideWithValue(() async {
            finished++;
          }),
        ],
        child: const InduljApp(configureWidgetId: 42),
      ),
    );

    expect(find.text('Mit mutasson a widget?'), findsOneWidget);
    await tester.tap(find.text('Otthon'));
    // Mentés közben pörgő látszik (élesben ekkor bezárul az Activity),
    // ezért nem pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(prefs.getString(WidgetRefresher.groupKey(42)), 'g2');
    expect(decodeSnapshot(store.snapshots[42]!).groupName, 'Otthon');
    expect(api.requests.single.queryParameters['stopId'], 'T');
    expect(finished, 1);
  });

  testWidgets('without groups it offers to create one', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          widgetStoreProvider.overrideWithValue(FakeWidgetStore()),
        ],
        child: const MaterialApp(home: _Config()),
      ),
    );

    expect(find.text('Még nincs kedvenc csoportod'), findsOneWidget);
    await tester.tap(find.text('Megálló hozzáadása'));
    await tester.pumpAndSettle();
    expect(find.text('Megállók kiválasztása'), findsOneWidget);
  });
}

class _Config extends StatelessWidget {
  const _Config();

  @override
  Widget build(BuildContext context) => const InduljApp(configureWidgetId: 1);
}
