import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import 'favorites_repository.dart';

final favoritesProvider = NotifierProvider<FavoritesNotifier, List<StopGroup>>(
  FavoritesNotifier.new,
);

class FavoritesNotifier extends Notifier<List<StopGroup>> {
  @override
  List<StopGroup> build() => ref.watch(favoritesRepositoryProvider).load();

  bool get canAdd => state.length < maxFavoriteGroups;

  StopGroup? byId(String id) {
    for (final g in state) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// Új csoportnál hozzáfűz, meglévőnél (azonos id) helyben cserél.
  Future<void> upsert(StopGroup group) async {
    final index = state.indexWhere((g) => g.id == group.id);
    final next = [...state];
    if (index == -1) {
      if (!canAdd) throw StateError('Legfeljebb $maxFavoriteGroups csoport.');
      next.add(group);
    } else {
      next[index] = group;
    }
    await ref.read(favoritesRepositoryProvider).save(next);
    state = next;
  }

  Future<void> remove(String id) async {
    final next = [...state]..removeWhere((g) => g.id == id);
    await ref.read(favoritesRepositoryProvider).save(next);
    state = next;
  }
}
