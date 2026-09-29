import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/providers.dart';
import 'features/board/board_screen.dart';
import 'features/favorites/favorites_notifier.dart';
import 'features/favorites/home_screen.dart';
import 'features/widget_config/widget_config_screen.dart';
import 'widget_bridge/background_entry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  int? configureWidgetId;
  Uri? initialWidgetLink;
  Stream<Uri?>? widgetLinks;
  if (defaultTargetPlatform == TargetPlatform.android) {
    configureWidgetId = int.tryParse(
      await HomeWidget.initiallyLaunchedFromHomeWidgetConfigure() ?? '',
    );
    initialWidgetLink = await HomeWidget.initiallyLaunchedFromHomeWidget();
    widgetLinks = HomeWidget.widgetClicked;
    unawaited(registerWidgetBackgroundWork());
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: InduljApp(
        configureWidgetId: configureWidgetId,
        initialWidgetLink: initialWidgetLink,
        widgetLinks: widgetLinks,
      ),
    ),
  );
}

class InduljApp extends ConsumerStatefulWidget {
  const InduljApp({
    super.key,
    this.configureWidgetId,
    this.initialWidgetLink,
    this.widgetLinks,
  });

  /// Ha a widget felrakása nyitotta meg az appot, ennek a widgetnek az ID-je.
  final int? configureWidgetId;

  /// `indulj://open?widget=<id>` vagy `indulj://alerts?widget=<id>`, ha a
  /// widgetre koppintás indította az appot.
  final Uri? initialWidgetLink;

  /// Widget-koppintások, miközben az app már fut.
  final Stream<Uri?>? widgetLinks;

  @override
  ConsumerState<InduljApp> createState() => _InduljAppState();
}

class _InduljAppState extends ConsumerState<InduljApp> {
  final _navigator = GlobalKey<NavigatorState>();
  StreamSubscription<Uri?>? _links;

  @override
  void initState() {
    super.initState();
    // Az app megnyitásakor a widgetek is frissülnek (SPEC 2.).
    if (widget.configureWidgetId == null) _refreshWidgets();
    _links = widget.widgetLinks?.listen(_openWidgetLink);
    if (widget.initialWidgetLink case final link?) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openWidgetLink(link),
      );
    }
  }

  @override
  void dispose() {
    _links?.cancel();
    super.dispose();
  }

  /// A widget csoportjának táblája; `alerts` esetén a zavarokkal.
  void _openWidgetLink(Uri? link) {
    if (link == null || link.scheme != 'indulj') return;
    final widgetId = int.tryParse(link.queryParameters['widget'] ?? '');
    if (widgetId == null) return;
    final groupId = ref.read(widgetRefresherProvider).groupOf(widgetId);
    final exists = ref.read(favoritesProvider).any((g) => g.id == groupId);
    final navigator = _navigator.currentState;
    if (groupId == null || !exists || navigator == null) return;
    navigator
      ..popUntil((route) => route.isFirst)
      ..push(
        MaterialPageRoute<void>(
          builder: (_) => BoardScreen(
            groupId: groupId,
            showAlertsOnLoad: link.host == 'alerts',
          ),
        ),
      );
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
      navigatorKey: _navigator,
      title: 'Indulj',
      theme: ThemeData(colorSchemeSeed: seed),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark),
      home: widget.configureWidgetId == null
          ? const HomeScreen()
          : WidgetConfigScreen(widgetId: widget.configureWidgetId!),
    );
  }
}
