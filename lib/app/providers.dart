import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/clock.dart';
import '../core/env.dart';
import '../core/local_time.dart';
import '../data/departures_repository.dart';
import '../data/futar/futar_api_client.dart';
import '../data/location_service.dart';
import '../domain/departure_board.dart';
import '../features/favorites/favorites_repository.dart';

/// A `main`-ben (és a tesztekben) felülírandó.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider override'),
);

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final utcOffsetProvider = Provider<UtcOffsetOf>((ref) => deviceUtcOffsetMs);

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final futarApiClientProvider = Provider<FutarApiClient>(
  (ref) => FutarApiClient(
    client: ref.watch(httpClientProvider),
    apiKey: Env.futarApiKey,
  ),
);

final departuresRepositoryProvider = Provider<DeparturesRepository>(
  (ref) => DeparturesRepository(
    api: ref.watch(futarApiClientProvider),
    clock: ref.watch(clockProvider),
  ),
);

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(ref.watch(sharedPreferencesProvider)),
);

final locationServiceProvider = Provider<LocationService>(
  (ref) => const GeolocatorLocationService(),
);
