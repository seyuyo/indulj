import 'package:flutter_test/flutter_test.dart';
import 'package:indulj/domain/models.dart';
import 'package:indulj/features/stop_search/stop_search_screen.dart';

void main() {
  test('compassLabel maps Futár degrees to 8 directions', () {
    expect(compassLabel('0'), '↑ É');
    expect(compassLabel('48'), '↗ ÉK');
    expect(compassLabel('137'), '↘ DK');
    expect(compassLabel('-44'), '↖ ÉNy');
    expect(compassLabel('-133'), '↙ DNy');
    expect(compassLabel('180'), '↓ D');
    expect(compassLabel(''), isNull);
    expect(compassLabel(null), isNull);
  });

  test('stopSubtitle for a platform shows routes and bearing', () {
    const stop = Stop(
      id: 'BKK_F01081',
      name: 'Oktogon M',
      direction: '137',
      routeShortNames: ['4', '4-6', '6'],
    );
    expect(stopSubtitle(stop), '4, 4-6, 6 · ↘ DK');
  });

  test('stopSubtitle for a station says it covers all platforms', () {
    const stop = Stop(
      id: 'BKK_CSF01082',
      name: 'Oktogon',
      isStation: true,
      routeShortNames: ['M1', '4'],
    );
    expect(stopSubtitle(stop), 'Állomás, minden peron · M1, 4');
  });

  test('stopSubtitle without data is empty', () {
    expect(stopSubtitle(const Stop(id: 'x', name: 'x')), '');
  });
}
