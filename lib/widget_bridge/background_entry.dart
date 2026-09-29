import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../core/clock.dart';
import '../core/env.dart';
import '../data/futar/futar_api_client.dart';
import 'widget_bridge.dart';
import 'widget_refresher.dart';

// Háttér-belépési pontok: saját isolate-ban futnak, az app nélkül. A kulcs
// fordítási idejű konstans (--dart-define), így itt is elérhető.

const periodicRefreshTask = 'widget-refresh';

/// `indulj://refresh?id=<widgetId>` — a widget ⟳ gombja.
Uri refreshUri(int widgetId) => Uri(
  scheme: 'indulj',
  host: 'refresh',
  queryParameters: {'id': '$widgetId'},
);

/// A `home_widget` interaktivitási callbackje.
@pragma('vm:entry-point')
Future<void> onWidgetInteraction(Uri? uri) async {
  if (uri == null || uri.host != 'refresh') return;
  final id = int.tryParse(uri.queryParameters['id'] ?? '');
  await _withRefresher((r) => id == null ? r.refreshAll() : r.refresh(id));
}

/// A WorkManager periodikus feladata (15 perc).
@pragma('vm:entry-point')
void workmanagerDispatcher() {
  Workmanager().executeTask((task, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    await _withRefresher((r) => r.refreshAll());
    return true;
  });
}

Future<void> _withRefresher(
  Future<void> Function(WidgetRefresher refresher) action,
) async {
  final client = http.Client();
  try {
    await action(
      WidgetRefresher(
        api: FutarApiClient(client: client, apiKey: Env.futarApiKey),
        clock: const SystemClock(),
        prefs: await SharedPreferences.getInstance(),
        store: const HomeWidgetStore(),
      ),
    );
  } finally {
    client.close();
  }
}

/// Az app indulásakor: háttér-callback és periodikus feladat regisztrálása.
Future<void> registerWidgetBackgroundWork() async {
  await HomeWidget.registerInteractivityCallback(onWidgetInteraction);
  await Workmanager().initialize(workmanagerDispatcher);
  await Workmanager().registerPeriodicTask(
    periodicRefreshTask,
    periodicRefreshTask,
    frequency: const Duration(minutes: 15),
    // Hálózat nélkül is fusson: offline a widget így újrarajzolódik, a már
    // elment sorok eltűnnek, 20 perc után pedig „elavult" lesz (SPEC 8./2.).
    constraints: Constraints(networkType: NetworkType.notRequired),
    // `update`: a korábban (más feltétellel) regisztrált feladat is frissül.
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );
}
