import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/result.dart';
import '../../data/departures_repository.dart';
import '../../data/futar/futar_error.dart';
import '../favorites/favorites_notifier.dart';

class BoardState {
  const BoardState({this.snapshot, this.error, this.loading = false});

  /// Az utolsó sikeres lekérés; hiba esetén is megmarad.
  final DeparturesSnapshot? snapshot;

  /// Az utolsó lekérés hibája; sikeres lekérés törli.
  final FutarError? error;
  final bool loading;
}

/// Egy csoport indulási táblája. A frissítés ütemezése a képernyő dolga;
/// a 30 mp-es alsó korlátot a [DeparturesRepository] tartja.
final boardProvider = NotifierProvider.autoDispose
    .family<BoardNotifier, BoardState, String>(BoardNotifier.new);

class BoardNotifier extends Notifier<BoardState> {
  BoardNotifier(this.groupId);

  final String groupId;

  @override
  BoardState build() => const BoardState(loading: true);

  Future<void> refresh() async {
    final group = ref.read(favoritesProvider.notifier).byId(groupId);
    if (group == null) return;
    state = BoardState(
      snapshot: state.snapshot,
      error: state.error,
      loading: true,
    );
    final result = await ref
        .read(departuresRepositoryProvider)
        .fetch(group.stopIds);
    if (!ref.mounted) return;
    state = switch (result) {
      Ok(:final value) => BoardState(snapshot: value),
      Err(:final error) => BoardState(snapshot: state.snapshot, error: error),
    };
  }
}
