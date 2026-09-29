import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/providers.dart';
import 'features/favorites/favorites_notifier.dart';
import 'features/favorites/home_screen.dart';
import 'features/widget_config/widget_config_screen.dart';
import 'widget_bridge/background_entry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  int? configureWidgetId;
  if (defaultTargetPlatform == TargetPlatform.android) {
    configureWidgetId = int.tryParse(
      await HomeWidget.initiallyLaunchedFromHomeWidgetConfigure() ?? '',
    );
    unawaited(registerWidgetBackgroundWork());
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: InduljApp(configureWidgetId: configureWidgetId),
    ),
  );
}

class InduljApp extends ConsumerStatefulWidget {
  const InduljApp({super.key, this.configureWidgetId});

  /// Ha a widget felrakása nyitotta meg az appot, ennek a widgetnek az ID-je.
  final int? configureWidgetId;

  @override
  ConsumerState<InduljApp> createState() => _InduljAppState();
}

class _InduljAppState extends ConsumerState<InduljApp> {
  @override
  void initState() {
    super.initState();
    // Az app megnyitásakor a widgetek is frissülnek (SPEC 2.).
    if (widget.configureWidgetId == null) _refreshWidgets();
  }

  void _refreshWidgets() {
    ref.read(widgetRefresherProvider).refreshAll().catchError((Object e) {
      // A widget frissítése nem akaszthatja meg az appot.
      debugPrint('Widget-frissítés sikertelen: ${e.runtimeType}');
    });
  }

  @override
  Widget build(BuildContext context) {
    // Csoport módosítása vagy törlése után a widgetek is frissülnek.
    ref.listen(favoritesProvider, (_, _) => _refreshWidgets());

    final seed = const Color(0xFF009EE3);
    return MaterialApp(
      title: 'Indulj',
      theme: ThemeData(colorSchemeSeed: seed),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark),
      home: widget.configureWidgetId == null
          ? const HomeScreen()
          : WidgetConfigScreen(widgetId: widget.configureWidgetId!),
    );
  }
}
