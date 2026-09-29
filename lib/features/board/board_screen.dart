import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/futar/futar_error.dart';
import '../../domain/departure_board.dart';
import '../../domain/models.dart';
import '../common/error_text.dart';
import '../common/route_badge.dart';
import '../favorites/favorites_notifier.dart';
import 'board_notifier.dart';

/// Élő indulási tábla: 30 mp-enként frissül, háttérben szünetel.
class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key, required this.groupId});

  final String groupId;

  static const fetchInterval = Duration(seconds: 30);

  /// A „3 perc" feliratok lekérés nélküli újraszámolása.
  static const tickInterval = Duration(seconds: 15);

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  late final AppLifecycleListener _lifecycle;
  Timer? _fetchTimer;
  Timer? _tickTimer;

  BoardNotifier get _notifier =>
      ref.read(boardProvider(widget.groupId).notifier);

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: _stop, onShow: _start);
    _start();
  }

  @override
  void dispose() {
    _stop();
    _lifecycle.dispose();
    super.dispose();
  }

  void _start() {
    _stop();
    _fetchTimer = Timer.periodic(
      BoardScreen.fetchInterval,
      (_) => _notifier.refresh(),
    );
    _tickTimer = Timer.periodic(BoardScreen.tickInterval, (_) {
      if (mounted) setState(() {});
    });
    // Build közben nem módosíthatunk providert.
    Future.microtask(() {
      if (mounted) _notifier.refresh();
    });
  }

  void _stop() {
    _fetchTimer?.cancel();
    _tickTimer?.cancel();
    _fetchTimer = _tickTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(favoritesProvider);
    final group = groups.where((g) => g.id == widget.groupId).firstOrNull;
    final state = ref.watch(boardProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(title: Text(group?.name ?? '')),
      body: RefreshIndicator(
        onRefresh: _notifier.refresh,
        child: group == null
            ? const _Scrollable(
                child: StatusMessage(
                  icon: Icons.delete_outline,
                  title: 'A csoport már nem létezik',
                ),
              )
            : BoardView(
                state: state,
                routeFilter: group.routeFilter,
                nowMs: ref.watch(clockProvider).nowMs(),
                offsetOf: ref.watch(utcOffsetProvider),
                onRetry: _notifier.refresh,
              ),
      ),
    );
  }
}

/// A tábla tartalma egy [BoardState]-ből. Külön widget a tesztelhetőségért.
class BoardView extends StatelessWidget {
  const BoardView({
    super.key,
    required this.state,
    required this.routeFilter,
    required this.nowMs,
    required this.offsetOf,
    required this.onRetry,
  });

  final BoardState state;
  final Set<String>? routeFilter;

  /// A telefon órája; a szerver-eltérést a pillanatkép alapján korrigáljuk.
  final int nowMs;
  final UtcOffsetOf offsetOf;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final snapshot = state.snapshot;
    final error = state.error;

    if (snapshot == null) {
      if (error != null) {
        final e = describeError(error);
        return _Scrollable(
          child: StatusMessage(
            icon: e.icon,
            title: e.title,
            detail: e.detail,
            actionLabel: 'Újra',
            onAction: onRetry,
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    final correctedNow = nowMs + snapshot.serverOffsetMs;
    final rows = buildBoard(
      snapshot.result.departures,
      nowMs: correctedNow,
      offsetOf: offsetOf,
      routeFilter: routeFilter,
    );
    final alerts = <Alert>[
      for (final id in snapshot.result.stopAlertIds)
        ?snapshot.result.alerts[id],
    ];
    final updated = formatLocalTime(snapshot.fetchedAtMs, offsetOf);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (error != null) _StaleBanner(error: error, updated: updated),
        for (final alert in alerts) _AlertTile(alert: alert),
        if (rows.isEmpty)
          const StatusMessage(
            icon: Icons.schedule,
            title: 'Nincs indulás 60 percen belül',
          )
        else
          for (final row in rows)
            _DepartureTile(row: row, alerts: snapshot.result.alerts),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'frissítve $updated',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _DepartureTile extends StatelessWidget {
  const _DepartureTile({required this.row, required this.alerts});

  final BoardRow row;
  final Map<String, Alert> alerts;

  @override
  Widget build(BuildContext context) {
    final d = row.departure;
    final theme = Theme.of(context);
    final tripAlerts = <Alert>[for (final id in d.alertIds) ?alerts[id]];
    return ListTile(
      leading: RouteBadge(
        label: d.routeShortName,
        color: d.routeColor,
        textColor: d.routeTextColor,
      ),
      title: Text(d.headsign, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: tripAlerts.isEmpty
          ? null
          : Text(
              tripAlerts.first.header,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      onTap: tripAlerts.isEmpty
          ? null
          : () => _showAlert(context, tripAlerts.first),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tripAlerts.isNotEmpty)
            Icon(Icons.warning_amber, color: theme.colorScheme.error, size: 18),
          if (row.delayMin case final delay?)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                '+$delay',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 8),
          if (d.isRealtime)
            Tooltip(
              message: 'Valós idejű',
              child: Icon(
                Icons.sensors,
                size: 14,
                color: theme.colorScheme.primary,
              ),
            ),
          const SizedBox(width: 4),
          Text(row.label, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: ListTile(
        leading: Icon(Icons.warning_amber, color: scheme.onErrorContainer),
        title: Text(
          alert.header,
          style: TextStyle(color: scheme.onErrorContainer),
        ),
        onTap: () => _showAlert(context, alert),
      ),
    );
  }
}

void _showAlert(BuildContext context, Alert alert) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(alert.header),
    content: SingleChildScrollView(child: Text(alert.description)),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Bezár'),
      ),
    ],
  ),
);

class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.error, required this.updated});

  final FutarError error;
  final String updated;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final e = describeError(error);
    return Material(
      color: scheme.surfaceContainerHighest,
      child: ListTile(
        leading: Icon(e.icon),
        title: Text('Elavult · frissítve $updated'),
        subtitle: Text(e.title),
      ),
    );
  }
}

/// Hibaállapotban is húzható legyen a frissítéshez.
class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(child: child),
      ),
    ),
  );
}
