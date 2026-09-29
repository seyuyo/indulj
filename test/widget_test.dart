import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indulj/app/providers.dart';
import 'package:indulj/core/clock.dart';
import 'package:indulj/features/favorites/favorites_repository.dart';
import 'package:indulj/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/budapest_time.dart';
import 'support/fakes.dart';

const _fixture = 'arrivals_oktogon_day';

Future<CountingApi> _startApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();
  final api = CountingApi((_) => jsonResponse(fixture(_fixture)));
  final clock = FakeClock(fixtureServerTime(_fixture));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(instance),
        futarApiClientProvider.overrideWithValue(api.client),
        clockProvider.overrideWithValue(clock),
        utcOffsetProvider.overrideWithValue(budapestOffsetMs),
        widgetStoreProvider.overrideWithValue(FakeWidgetStore()),
      ],
      child: const InduljApp(),
    ),
  );
  return api;
}

void main() {
  testWidgets('first start shows the empty favorites state', (tester) async {
    final api = await _startApp(tester);

    expect(find.text('Még nincs kedvenc megállód'), findsOneWidget);
    expect(api.requests, isEmpty);
  });

  testWidgets('a saved group opens a live board from the API', (tester) async {
    final api = await _startApp(
      tester,
      prefs: {
        FavoritesRepository.storageKey:
            '{"v":1,"groups":[{"id":"1","name":"Oktogon",'
            '"stopIds":["BKK_F01081","BKK_F01082"]}]}',
      },
    );

    await tester.tap(find.text('Oktogon'));
    await tester.pumpAndSettle();

    expect(api.requests, hasLength(1));
    expect(api.requests.single.queryParametersAll['stopId'], [
      'BKK_F01081',
      'BKK_F01082',
    ]);
    // Megálló-szintű zavar a fixture-ből, és valós idejű sorok késéssel.
    expect(find.text('nem közlekedik a teljes vonalon'), findsOneWidget);
    expect(find.text('Újbuda-központ M'), findsWidgets);
    expect(find.text('most'), findsOneWidget);
    expect(find.text('+2'), findsWidgets);

    // A 30 mp-es időzítő újrahív, de a repository korlátja miatt az óra
    // léptetése nélkül nincs új kérés.
    await tester.pump(const Duration(seconds: 31));
    expect(api.requests, hasLength(1));

    // Kilépéskor az időzítők leállnak (különben a teszt elbukna).
    await tester.pageBack();
    await tester.pumpAndSettle();
  });
}
