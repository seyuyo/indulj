import 'package:shared_preferences/shared_preferences.dart';

import '../core/clock.dart';
import '../core/result.dart';
import '../data/departures_repository.dart';
import '../data/futar/futar_api_client.dart';
import '../features/favorites/favorites_repository.dart';
import 'snapshot_codec.dart';

/// A widgetek adattára (a `home_widget` plugin fölött; tesztben hamis).
abstract interface class WidgetStore {
  Future<List<int>> installedWidgetIds();
  Future<String?> readSnapshot(int widgetId);
  Future<void> saveSnapshot(int widgetId, String json);

  /// Újrarajzoltatja az összes widgetet.
  Future<void> redraw();
}

/// Lekérés → pillanatkép → widget. Az appból és a háttér-isolate-ból is
/// hívjuk, ezért nem használ Riverpodot, és minden állapota a prefs-ben van.
class WidgetRefresher {
  WidgetRefresher({
    required FutarApiClient api,
    required Clock clock,
    required SharedPreferences prefs,
    required WidgetStore store,
  }) : _repo = DeparturesRepository(api: api, clock: clock),
       _clock = clock,
       _prefs = prefs,
       _store = store;

  final DeparturesRepository _repo;
  final Clock _clock;
  final SharedPreferences _prefs;
  final WidgetStore _store;

  /// A háttér-isolate nem él tovább: a 30 mp-es korlát a prefs-ben van.
  static const minInterval = Duration(seconds: 30);

  static String groupKey(int widgetId) => 'widget_group_$widgetId';
  static String lastFetchKey(int widgetId) => 'widget_last_fetch_$widgetId';

  String? groupOf(int widgetId) => _prefs.getString(groupKey(widgetId));

  /// Widget ↔ csoport párosítás (configure), majd azonnali frissítés.
  Future<void> assign(int widgetId, String groupId) async {
    await _prefs.setString(groupKey(widgetId), groupId);
    await _prefs.remove(lastFetchKey(widgetId));
    await refresh(widgetId);
  }

  Future<void> refreshAll() async {
    for (final id in await _store.installedWidgetIds()) {
      await _refreshOne(id);
    }
    await _store.redraw();
  }

  Future<void> refresh(int widgetId) async {
    await _refreshOne(widgetId);
    await _store.redraw();
  }

  Future<void> _refreshOne(int widgetId) async {
    // Egy másik isolate (app / háttér) is írhatta.
    await _prefs.reload();

    final groupId = groupOf(widgetId);
    final group = FavoritesRepository(
      _prefs,
    ).load().where((g) => g.id == groupId).firstOrNull;
    if (group == null) {
      await _save(
        widgetId,
        snapshotWithError(null, groupName: '', error: WidgetError.noGroup),
      );
      return;
    }

    final now = _clock.nowMs();
    final last = _prefs.getInt(lastFetchKey(widgetId));
    if (last != null && now - last < minInterval.inMilliseconds) {
      return; // csak újrarajzolás
    }

    final result = await _repo.fetch(group.stopIds);
    switch (result) {
      case Ok(:final value):
        await _prefs.setInt(lastFetchKey(widgetId), now);
        await _save(widgetId, buildSnapshot(group, value));
      case Err(:final error):
        final errorKind = widgetErrorOf(error);
        // A hálózati hiba nem ért el a szerverig: nem számít kérésnek.
        if (errorKind != WidgetError.network) {
          await _prefs.setInt(lastFetchKey(widgetId), now);
        }
        await _save(
          widgetId,
          snapshotWithError(
            await _previous(widgetId),
            groupName: group.name,
            error: errorKind,
          ),
        );
    }
  }

  Future<WidgetSnapshot?> _previous(int widgetId) async {
    final raw = await _store.readSnapshot(widgetId);
    if (raw == null) return null;
    try {
      return decodeSnapshot(raw);
    } on FormatException {
      return null;
    }
  }

  Future<void> _save(int widgetId, WidgetSnapshot snapshot) =>
      _store.saveSnapshot(widgetId, encodeSnapshot(snapshot));
}
