import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/result.dart';
import '../../data/futar/futar_error.dart';
import '../../data/location_service.dart';
import '../../domain/models.dart';
import '../common/error_text.dart';
import '../favorites/group_editor_screen.dart';

/// Megállók keresése névre vagy közelség alapján, és kijelölésük egy
/// új kedvenc csoporthoz.
class StopSearchScreen extends ConsumerStatefulWidget {
  const StopSearchScreen({super.key});

  @override
  ConsumerState<StopSearchScreen> createState() => _StopSearchScreenState();
}

sealed class _SearchState {
  const _SearchState();
}

class _Idle extends _SearchState {
  const _Idle();
}

class _Loading extends _SearchState {
  const _Loading();
}

class _Results extends _SearchState {
  const _Results(this.stops, {required this.nearby});
  final List<Stop> stops;
  final bool nearby;
}

class _Failed extends _SearchState {
  const _Failed(
    this.icon,
    this.title,
    this.detail, {
    this.openSettings = false,
  });
  final IconData icon;
  final String title;
  final String detail;
  final bool openSettings;
}

class _StopSearchScreenState extends ConsumerState<StopSearchScreen> {
  final _query = TextEditingController();
  final _selected = <String, Stop>{};
  _SearchState _state = const _Idle();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  // Csak beküldésre keresünk, gépelésenként nem (API-terhelés).
  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.length < 2) return;
    FocusScope.of(context).unfocus();
    setState(() => _state = const _Loading());
    final result = await ref.read(futarApiClientProvider).searchStops(query);
    if (!mounted) return;
    setState(() => _state = _fromApi(result, nearby: false));
  }

  Future<void> _nearby() async {
    setState(() => _state = const _Loading());
    final location = await ref.read(locationServiceProvider).current();
    if (!mounted) return;
    switch (location) {
      case LocationFound(:final lat, :final lon):
        final result = await ref
            .read(futarApiClientProvider)
            .stopsNearby(lat, lon);
        if (!mounted) return;
        setState(() => _state = _fromApi(result, nearby: true));
      case LocationDenied():
        setState(
          () => _state = const _Failed(
            Icons.location_disabled,
            'Nincs helyengedély',
            'A közeli megállókhoz engedélyezd a helymeghatározást.',
          ),
        );
      case LocationDeniedForever():
        setState(
          () => _state = const _Failed(
            Icons.location_disabled,
            'A helyengedély le van tiltva',
            'A beállításokban engedélyezheted újra.',
            openSettings: true,
          ),
        );
      case LocationServiceOff():
        setState(
          () => _state = const _Failed(
            Icons.location_off,
            'A helymeghatározás ki van kapcsolva',
            'Kapcsold be a telefon helyszolgáltatását.',
          ),
        );
      case LocationUnavailable():
        setState(
          () => _state = const _Failed(
            Icons.location_searching,
            'Nem sikerült meghatározni a helyzetet',
            'Próbáld újra, vagy keress név alapján.',
          ),
        );
    }
  }

  _SearchState _fromApi(
    Result<List<Stop>, FutarError> result, {
    required bool nearby,
  }) => switch (result) {
    Ok(:final value) => _Results(value, nearby: nearby),
    Err(:final error) => () {
      final e = describeError(error);
      return _Failed(e.icon, e.title, e.detail);
    }(),
  };

  void _toggle(Stop stop) => setState(() {
    if (_selected.remove(stop.id) == null) _selected[stop.id] = stop;
  });

  void _next() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            GroupEditorScreen.create(stops: _selected.values.toList()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Megállók kiválasztása')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _query,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: 'Megálló neve',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: 'Keresés',
                        icon: const Icon(Icons.search),
                        onPressed: _search,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Közeli megállók',
                  icon: const Icon(Icons.near_me),
                  onPressed: _nearby,
                ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
      bottomNavigationBar: _selected.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: _next,
                  child: Text('Tovább (${_selected.length} kijelölve)'),
                ),
              ),
            ),
    );
  }

  Widget _body() => switch (_state) {
    _Idle() => const StatusMessage(
      icon: Icons.search,
      title: 'Keress megállót',
      detail:
          'Írd be a nevét, vagy nézd meg a közelieket. Több peront is '
          'kijelölhetsz egy csoportba.',
    ),
    _Loading() => const Center(child: CircularProgressIndicator()),
    _Failed(:final icon, :final title, :final detail, :final openSettings) =>
      StatusMessage(
        icon: icon,
        title: title,
        detail: detail,
        actionLabel: openSettings ? 'Beállítások' : null,
        onAction: openSettings
            ? ref.read(locationServiceProvider).openSettings
            : null,
      ),
    _Results(stops: []) => const StatusMessage(
      icon: Icons.search_off,
      title: 'Nincs találat',
    ),
    _Results(:final stops) => ListView.builder(
      itemCount: stops.length,
      itemBuilder: (context, i) {
        final stop = stops[i];
        return CheckboxListTile(
          value: _selected.containsKey(stop.id),
          onChanged: (_) => _toggle(stop),
          title: Text(stop.name),
          subtitle: Text(stopSubtitle(stop)),
          secondary: _StopIcon(stop),
        );
      },
    ),
  };
}

/// „Állomás, minden peron · M1, 4" vagy „4, 6 · ÉK irányba".
String stopSubtitle(Stop stop) {
  final routes = stop.routeShortNames.take(8).join(', ');
  if (stop.isStation) {
    return ['Állomás, minden peron', if (routes.isNotEmpty) routes].join(' · ');
  }
  final bearing = compassLabel(stop.direction);
  return [
    if (routes.isNotEmpty) routes,
    if (bearing != null) '$bearing irányba',
  ].join(' · ');
}

/// A Futár `direction` mezője fokban (−180…180, 0 = észak).
double? bearingDegrees(String? direction) => double.tryParse(direction ?? '');

/// Égtáj a haladási irányhoz, pl. `DK`. Nyíl-karaktert nem használunk:
/// egyes gyártók (Samsung) emojiként rajzolják, szöveges jelzővel is.
String? compassLabel(String? direction) {
  final degrees = bearingDegrees(direction);
  if (degrees == null) return null;
  const names = ['É', 'ÉK', 'K', 'DK', 'D', 'DNy', 'Ny', 'ÉNy'];
  return names[(((degrees % 360) + 22.5) ~/ 45) % 8];
}

/// Állomásnál csomópont-ikon, peronnál a haladási irányba forgatott nyíl.
class _StopIcon extends StatelessWidget {
  const _StopIcon(this.stop);

  final Stop stop;

  @override
  Widget build(BuildContext context) {
    if (stop.isStation) return const Icon(Icons.hub);
    final degrees = bearingDegrees(stop.direction);
    if (degrees == null) return const Icon(Icons.place);
    return Transform.rotate(
      angle: degrees * math.pi / 180,
      child: const Icon(Icons.navigation),
    );
  }
}
