import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indulj/app/providers.dart';
import 'package:indulj/core/clock.dart';
import 'package:indulj/domain/models.dart';
import 'package:indulj/features/common/route_badge.dart';
import 'package:indulj/features/favorites/group_editor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

const _fixture = 'arrivals_oktogon_day';

RouteRef _r(String id, String name) =>
    RouteRef(id: id, shortName: name, color: 0xFFFFD800, textColor: 0xFF000000);

void main() {
  testWidgets('offers known stop routes plus currently running ones', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = CountingApi((_) => jsonResponse(fixture(_fixture)));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          futarApiClientProvider.overrideWithValue(api.client),
          clockProvider.overrideWithValue(
            FakeClock(fixtureServerTime(_fixture)),
          ),
        ],
        child: MaterialApp(
          home: GroupEditorScreen.create(
            stops: [
              Stop(
                id: 'BKK_F01081',
                name: 'Oktogon M',
                routes: [_r('BKK_3060', '6'), _r('BKK_3040', '4')],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final badges = tester
        .widgetList<RouteBadge>(find.byType(RouteBadge))
        .map((b) => b.label)
        .toList();
    // A 4 és a 6 a keresésből jön, a 4-6 a fixture induló járataiból.
    expect(badges, containsAllInOrder(['4', '6']));
    expect(badges, contains('4-6'));
    expect(badges.toSet(), hasLength(badges.length));
  });
}
