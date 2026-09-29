import 'package:flutter_test/flutter_test.dart';
import 'package:indulj/domain/models.dart';

void main() {
  group('StopGroup.copyWith', () {
    const group = StopGroup(
      id: '1',
      name: 'Oktogon',
      stopIds: ['A'],
      routeFilter: {'R4'},
    );

    test('keeps unspecified fields', () {
      final copy = group.copyWith(name: 'Új név');

      expect(copy.id, '1');
      expect(copy.name, 'Új név');
      expect(copy.stopIds, ['A']);
      expect(copy.routeFilter, {'R4'});
    });

    test('can clear the route filter explicitly', () {
      expect(group.copyWith(routeFilter: () => null).routeFilter, isNull);
      expect(group.copyWith(routeFilter: () => {'R6'}).routeFilter, {'R6'});
    });
  });
}
