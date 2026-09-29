import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:indulj/data/futar/futar_api_client.dart';
import 'package:indulj/widget_bridge/widget_refresher.dart';

String fixture(String name) =>
    File('test/fixtures/$name.json').readAsStringSync();

/// A fixture `currentTime`-ja: a tesztóra ehhez igazítható.
int fixtureServerTime(String name) =>
    (jsonDecode(fixture(name)) as Map<String, Object?>)['currentTime']! as int;

http.Response jsonResponse(String body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(body), status);

/// `MockClient`-re épülő API-kliens, ami számolja a kéréseket.
class CountingApi {
  CountingApi(this.handler);

  FutureOr<http.Response> Function(http.Request request) handler;
  final requests = <Uri>[];

  late final client = FutarApiClient(
    apiKey: 'test-key',
    client: MockClient((req) async {
      requests.add(req.url);
      return handler(req);
    }),
  );
}

/// Memóriában tartott widget-tár.
class FakeWidgetStore implements WidgetStore {
  FakeWidgetStore([this.installed = const []]);

  List<int> installed;
  final snapshots = <int, String>{};
  var redraws = 0;

  @override
  Future<List<int>> installedWidgetIds() async => installed;

  @override
  Future<String?> readSnapshot(int widgetId) async => snapshots[widgetId];

  @override
  Future<void> saveSnapshot(int widgetId, String json) async =>
      snapshots[widgetId] = json;

  @override
  Future<void> redraw() async => redraws++;
}
