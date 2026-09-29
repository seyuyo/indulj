import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indulj/app/providers.dart';
import 'package:indulj/domain/models.dart';
import 'package:indulj/features/favorites/favorites_notifier.dart';
import 'package:indulj/features/favorites/favorites_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<FavoritesRepository> _repo([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  return FavoritesRepository(await SharedPreferences.getInstance());
}

const _oktogon = StopGroup(
  id: '1',
  name: 'Oktogon',
  stopIds: ['BKK_F01081', 'BKK_F01082'],
  routeFilter: {'BKK_3040', 'BKK_3060'},
);
const _home = StopGroup(id: '2', name: 'Otthon', stopIds: ['BKK_CSF01082']);

void main() {
  test('empty storage gives no groups', () async {
    expect((await _repo()).load(), isEmpty);
  });

  test('round trip keeps every field, including a null filter', () async {
    final repo = await _repo();
    await repo.save([_oktogon, _home]);

    final loaded = repo.load();
    expect(loaded.map((g) => g.id), ['1', '2']);
    expect(loaded[0].name, 'Oktogon');
    expect(loaded[0].stopIds, _oktogon.stopIds);
    expect(loaded[0].routeFilter, {'BKK_3040', 'BKK_3060'});
    expect(loaded[1].routeFilter, isNull);
  });

  test('corrupt data gives an empty list instead of a crash', () async {
    for (final raw in ['not json', '[1,2]', '{"v":1,"groups":[{"id":1}]}']) {
      final repo = await _repo({FavoritesRepository.storageKey: raw});
      expect(repo.load(), isEmpty, reason: raw);
    }
  });

  test('unknown schema version gives an empty list', () async {
    final repo = await _repo({
      FavoritesRepository.storageKey: '{"v":99,"groups":[]}',
    });
    expect(repo.load(), isEmpty);
  });

  test('more than three groups cannot be saved', () async {
    final repo = await _repo();
    final four = [
      for (var i = 0; i < 4; i++) StopGroup(id: '$i', name: '$i', stopIds: []),
    ];
    expect(() => repo.save(four), throwsArgumentError);
  });

  group('FavoritesNotifier', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
    });
    tearDown(() => container.dispose());

    test('upsert adds, then replaces by id; remove deletes', () async {
      final notifier = container.read(favoritesProvider.notifier);
      await notifier.upsert(_oktogon);
      await notifier.upsert(_home);
      await notifier.upsert(_oktogon.copyWith(name: 'Oktogon M'));

      expect(container.read(favoritesProvider).map((g) => g.name), [
        'Oktogon M',
        'Otthon',
      ]);
      expect(notifier.byId('2')?.name, 'Otthon');

      await notifier.remove('1');
      expect(container.read(favoritesProvider).map((g) => g.id), ['2']);
      expect(notifier.byId('1'), isNull);
    });

    test('persists across containers', () async {
      await container.read(favoritesProvider.notifier).upsert(_home);
      final prefs = container.read(sharedPreferencesProvider);
      final fresh = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(fresh.dispose);

      expect(fresh.read(favoritesProvider).single.name, 'Otthon');
    });

    test('a fourth group is rejected', () async {
      final notifier = container.read(favoritesProvider.notifier);
      for (var i = 0; i < 3; i++) {
        await notifier.upsert(StopGroup(id: '$i', name: '$i', stopIds: []));
      }
      expect(notifier.canAdd, isFalse);
      await expectLater(
        notifier.upsert(const StopGroup(id: 'x', name: 'x', stopIds: [])),
        throwsStateError,
      );
    });
  });
}
