import 'dart:convert';

import '../data/departures_repository.dart';
import '../data/futar/dto/json_read.dart';
import '../data/futar/futar_error.dart';
import '../domain/departure_board.dart';
import '../domain/models.dart';

// A widget-pillanatkép (SPEC 5.): a Dart írja, a Kotlin `SnapshotReader`
// olvassa. Sémaváltás = verzióemelés + Kotlin olvasó + codec-teszt, egy
// commitban. A két oldal szerződését a test/fixtures/snapshots fájlok védik.

const snapshotVersion = 1;

/// Ennyi sort írunk ki; a widget legfeljebb 4-et mutat, a többi tartalék
/// arra az időre, amíg a már elment sorokat a Kotlin elrejti.
const snapshotMaxDepartures = 8;

enum WidgetError { network, unauthorized, server, noGroup }

class WidgetDeparture {
  const WidgetDeparture({
    required this.route,
    required this.bg,
    required this.fg,
    required this.headsign,
    required this.atMs,
    required this.realtime,
    this.delayMin,
  });

  final String route;

  /// ARGB.
  final int bg, fg;
  final String headsign;

  /// Várható indulás, UTC epoch ms (előrejelzés, ha van).
  final int atMs;
  final bool realtime;
  final int? delayMin;
}

class WidgetSnapshot {
  const WidgetSnapshot({
    required this.groupName,
    required this.fetchedAtMs,
    required this.serverOffsetMs,
    required this.departures,
    this.hasAlerts = false,
    this.error,
  });

  final String groupName;

  /// Az utolsó sikeres lekérés ideje (telefonóra); 0 = még soha.
  final int fetchedAtMs;
  final int serverOffsetMs;
  final List<WidgetDeparture> departures;
  final bool hasAlerts;
  final WidgetError? error;
}

/// Sikeres lekérésből: ugyanaz a kiválasztás, mint az app táblájában.
WidgetSnapshot buildSnapshot(StopGroup group, DeparturesSnapshot data) {
  final now = data.fetchedAtMs + data.serverOffsetMs;
  final selected = selectDepartures(
    data.result.departures,
    nowMs: now,
    routeFilter: group.routeFilter,
  ).take(snapshotMaxDepartures).toList();
  return WidgetSnapshot(
    groupName: group.name,
    fetchedAtMs: data.fetchedAtMs,
    serverOffsetMs: data.serverOffsetMs,
    departures: [
      for (final d in selected)
        WidgetDeparture(
          route: d.routeShortName,
          bg: d.routeColor,
          fg: d.routeTextColor,
          headsign: d.headsign,
          atMs: d.effectiveAtMs,
          realtime: d.isRealtime,
          delayMin: delayMinutes(d),
        ),
    ],
    hasAlerts:
        data.result.stopAlertIds.isNotEmpty ||
        selected.any((d) => d.alertIds.isNotEmpty),
  );
}

/// Hibánál az előző pillanatkép sorai megmaradnak, csak a hiba változik.
WidgetSnapshot snapshotWithError(
  WidgetSnapshot? previous, {
  required String groupName,
  required WidgetError error,
}) => WidgetSnapshot(
  groupName: groupName,
  fetchedAtMs: previous?.fetchedAtMs ?? 0,
  serverOffsetMs: previous?.serverOffsetMs ?? 0,
  departures: previous?.departures ?? const [],
  hasAlerts: previous?.hasAlerts ?? false,
  error: error,
);

WidgetError widgetErrorOf(FutarError error) => switch (error) {
  NetworkError() => WidgetError.network,
  HttpError(isUnauthorized: true) => WidgetError.unauthorized,
  _ => WidgetError.server,
};

String encodeSnapshot(WidgetSnapshot s) => jsonEncode({
  'v': snapshotVersion,
  'groupName': s.groupName,
  'fetchedAtMs': s.fetchedAtMs,
  'serverOffsetMs': s.serverOffsetMs,
  'departures': [
    for (final d in s.departures)
      {
        'route': d.route,
        'bg': _hex(d.bg),
        'fg': _hex(d.fg),
        'headsign': d.headsign,
        'atMs': d.atMs,
        'realtime': d.realtime,
        'delayMin': d.delayMin,
      },
  ],
  'hasAlerts': s.hasAlerts,
  'error': s.error?.name,
});

/// FormatException, ha sérült vagy más verziójú.
WidgetSnapshot decodeSnapshot(String raw) {
  final json = asJsonMap(jsonDecode(raw), 'snapshot');
  final version = optInt(json, 'v');
  if (version != snapshotVersion) {
    throw FormatException('snapshot: unsupported version $version');
  }
  final error = optString(json, 'error');
  return WidgetSnapshot(
    groupName: optString(json, 'groupName') ?? '',
    fetchedAtMs: optInt(json, 'fetchedAtMs') ?? 0,
    serverOffsetMs: optInt(json, 'serverOffsetMs') ?? 0,
    departures: [
      for (final d in mapList(json, 'departures'))
        WidgetDeparture(
          route: optString(d, 'route') ?? '?',
          bg: _parseHex(optString(d, 'bg')),
          fg: _parseHex(optString(d, 'fg'), 0xFFFFFFFF),
          headsign: optString(d, 'headsign') ?? '',
          atMs: reqInt(d, 'atMs'),
          realtime: optBool(d, 'realtime') ?? false,
          delayMin: optInt(d, 'delayMin'),
        ),
    ],
    hasAlerts: optBool(json, 'hasAlerts') ?? false,
    error: error == null
        ? null
        : WidgetError.values.where((e) => e.name == error).firstOrNull ??
              WidgetError.server,
  );
}

String _hex(int argb) =>
    (argb & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0').toUpperCase();

int _parseHex(String? hex, [int fallback = 0xFF757575]) =>
    hex == null ? fallback : int.tryParse(hex, radix: 16) ?? fallback;

/// Ennyi idő után „elavult" a widget (a Kotlin `WidgetDisplay` is ezt használja).
const snapshotStaleAfterMs = 20 * 60 * 1000;

/// Az indulás után ennyi ideig „indul" a felirat, utána a sor eltűnik.
const departingGraceMs = 30 * 1000;

/// Mikor kell a widgetet (lekérés nélkül) újrarajzolni, a telefon órája
/// szerint: az első [rows] sor indulásakor („indul") és 30 mp-cel utána
/// (a következő sor lesz az első), valamint amikor elavul.
List<int> redrawTimesMs(WidgetSnapshot s, {int rows = 3}) => [
  for (final d in s.departures.take(rows)) ...[
    d.atMs - s.serverOffsetMs,
    d.atMs - s.serverOffsetMs + departingGraceMs,
  ],
  if (s.fetchedAtMs > 0) s.fetchedAtMs + snapshotStaleAfterMs + 1000,
];
