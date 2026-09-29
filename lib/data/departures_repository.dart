import '../core/clock.dart';
import '../core/result.dart';
import '../domain/departure_board.dart';
import '../domain/models.dart';
import 'futar/futar_api_client.dart';
import 'futar/futar_error.dart';

/// Egy sikeres lekérés eredménye a lekérés idejével és az óraeltéréssel.
class DeparturesSnapshot {
  const DeparturesSnapshot({
    required this.result,
    required this.fetchedAtMs,
    required this.serverOffsetMs,
  });

  final DeparturesResult result;

  /// A telefon órája szerint (a „frissítve HH:mm" felirathoz).
  final int fetchedAtMs;
  final int serverOffsetMs;
}

/// Az indulások lekérése megállókészletenként, **legfeljebb 30 mp-enként**.
///
/// Gyakoribb kérésre az utolsó eredményt adja vissza hívás nélkül.
/// A hálózati hiba (nem ért el a szerverig) nem számít kérésnek.
class DeparturesRepository {
  DeparturesRepository({
    required FutarApiClient api,
    required Clock clock,
    this.minInterval = const Duration(seconds: 30),
  }) : _api = api,
       _clock = clock;

  final FutarApiClient _api;
  final Clock _clock;
  final Duration minInterval;

  final _last = <String, (int, Result<DeparturesSnapshot, FutarError>)>{};
  final _inFlight = <String, Future<Result<DeparturesSnapshot, FutarError>>>{};

  Future<Result<DeparturesSnapshot, FutarError>> fetch(List<String> stopIds) {
    final key = ([...stopIds]..sort()).join(',');
    if (_inFlight[key] case final pending?) return pending;

    if (_last[key] case (
      final at,
      final result,
    ) when _clock.nowMs() - at < minInterval.inMilliseconds) {
      return Future.value(result);
    }

    // Blokk-törzs kell: a `remove` a Future-t adná vissza, és a
    // `whenComplete` saját magára várna.
    final future = _fetch(key, stopIds).whenComplete(() {
      _inFlight.remove(key);
    });
    return _inFlight[key] = future;
  }

  Future<Result<DeparturesSnapshot, FutarError>> _fetch(
    String key,
    List<String> stopIds,
  ) async {
    final requestedAt = _clock.nowMs();
    final result = await _api.departures(stopIds);
    final receivedAt = _clock.nowMs();

    final Result<DeparturesSnapshot, FutarError> mapped = switch (result) {
      Ok(:final value) => Ok(
        DeparturesSnapshot(
          result: value,
          fetchedAtMs: receivedAt,
          serverOffsetMs: value.serverTimeMs == null
              ? 0
              : serverOffsetMs(
                  serverTimeMs: value.serverTimeMs!,
                  localNowMs: receivedAt,
                ),
        ),
      ),
      Err(:final error) => Err(error),
    };

    switch (mapped) {
      case Err(error: NetworkError()):
        break; // nem ért el a szerverig: azonnal újrapróbálható
      case Err():
        // Szerverhiba után is várunk, de ha volt jó adat, azt adjuk vissza.
        final previous = _last[key]?.$2;
        _last[key] = (
          requestedAt,
          previous is Ok<DeparturesSnapshot, FutarError> ? previous : mapped,
        );
      case Ok():
        _last[key] = (requestedAt, mapped);
    }
    return mapped;
  }
}
