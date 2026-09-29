import 'package:home_widget/home_widget.dart';

import 'widget_refresher.dart';

/// A Kotlin receiver teljes neve (a manifestben ezzel szerepel).
const departuresWidgetReceiver =
    'hu.seyuyo.indulj.widget.DeparturesWidgetReceiver';

/// A Kotlin `SnapshotReader` ezt a kulcsot olvassa.
String snapshotKey(int widgetId) => 'snapshot_$widgetId';

/// `WidgetStore` a `home_widget` plugin fölött.
class HomeWidgetStore implements WidgetStore {
  const HomeWidgetStore();

  /// A plugin a `shortClassName`-et adja (pl. `.widget.DeparturesWidgetReceiver`),
  /// ezért a végződésre szűrünk.
  @override
  Future<List<int>> installedWidgetIds() async => [
    for (final w in await HomeWidget.getInstalledWidgets())
      if (w.androidClassName?.endsWith('.DeparturesWidgetReceiver') ?? false)
        ?w.androidWidgetId,
  ];

  @override
  Future<String?> readSnapshot(int widgetId) =>
      HomeWidget.getWidgetData<String>(snapshotKey(widgetId));

  @override
  Future<void> saveSnapshot(int widgetId, String json) =>
      HomeWidget.saveWidgetData<String>(snapshotKey(widgetId), json);

  @override
  Future<void> redraw() =>
      HomeWidget.updateWidget(qualifiedAndroidName: departuresWidgetReceiver);
}
