import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/futar/dto/json_read.dart';
import '../../domain/models.dart';

/// Legfeljebb ennyi kedvenc csoport lehet (SPEC 1.).
const maxFavoriteGroups = 3;

/// A kedvenc csoportok tárolása egyetlen verziózott JSON-kulcsban.
class FavoritesRepository {
  FavoritesRepository(this._prefs);

  static const storageKey = 'favorites';
  static const schemaVersion = 1;

  final SharedPreferences _prefs;

  /// Sérült vagy ismeretlen verziójú adatnál üres lista, nem kivétel.
  List<StopGroup> load() {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return const [];
    try {
      return decodeGroups(raw);
    } on FormatException {
      return const [];
    }
  }

  Future<void> save(List<StopGroup> groups) async {
    if (groups.length > maxFavoriteGroups) {
      throw ArgumentError('Legfeljebb $maxFavoriteGroups csoport lehet.');
    }
    await _prefs.setString(storageKey, encodeGroups(groups));
  }
}

String encodeGroups(List<StopGroup> groups) => jsonEncode({
  'v': FavoritesRepository.schemaVersion,
  'groups': [
    for (final g in groups)
      {
        'id': g.id,
        'name': g.name,
        'stopIds': g.stopIds,
        if (g.routeFilter != null) 'routeFilter': g.routeFilter!.toList(),
      },
  ],
});

/// FormatException, ha a JSON sérült vagy más verziójú.
List<StopGroup> decodeGroups(String raw) {
  final json = asJsonMap(jsonDecode(raw), 'favorites');
  final version = optInt(json, 'v');
  if (version != FavoritesRepository.schemaVersion) {
    throw FormatException('favorites: unknown version $version');
  }
  return [
    for (final g in mapList(json, 'groups'))
      StopGroup(
        id: reqString(g, 'id'),
        name: reqString(g, 'name'),
        stopIds: stringList(g, 'stopIds'),
        routeFilter: g['routeFilter'] == null
            ? null
            : stringList(g, 'routeFilter').toSet(),
      ),
  ];
}
