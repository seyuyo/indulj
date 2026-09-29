// Toleráns JSON-olvasók: ismeretlen mező nem hiba, hiányzó (vagy null)
// opcionális mező null / üres, rossz típus viszont FormatException.

typedef JsonMap = Map<String, Object?>;

JsonMap asJsonMap(Object? value, [String what = 'value']) {
  if (value is Map<String, Object?>) return value;
  throw FormatException('$what: expected object, got ${value.runtimeType}');
}

T? _opt<T>(JsonMap json, String key) {
  final value = json[key];
  if (value == null || value is T) return value as T?;
  throw FormatException('$key: expected $T, got ${value.runtimeType}');
}

T _req<T extends Object>(JsonMap json, String key) =>
    _opt<T>(json, key) ?? (throw FormatException('$key: missing'));

String? optString(JsonMap json, String key) => _opt<String>(json, key);
String reqString(JsonMap json, String key) => _req<String>(json, key);
bool? optBool(JsonMap json, String key) => _opt<bool>(json, key);
double? optDouble(JsonMap json, String key) => _opt<num>(json, key)?.toDouble();

int? optInt(JsonMap json, String key) {
  final value = _opt<num>(json, key);
  if (value == null || value is int) return value as int?;
  if (value == value.truncate()) return value.toInt();
  throw FormatException('$key: expected int, got $value');
}

int reqInt(JsonMap json, String key) =>
    optInt(json, key) ?? (throw FormatException('$key: missing'));

JsonMap? optMap(JsonMap json, String key) {
  final value = json[key];
  return value == null ? null : asJsonMap(value, key);
}

List<String> stringList(JsonMap json, String key) =>
    (_opt<List<Object?>>(json, key) ?? const []).map((e) {
      if (e is String) return e;
      throw FormatException('$key: expected string item, got $e');
    }).toList();

List<JsonMap> mapList(JsonMap json, String key) =>
    (_opt<List<Object?>>(json, key) ?? const [])
        .map((e) => asJsonMap(e, key))
        .toList();

/// ID szerint kulcsolt objektumtérkép (pl. `references.routes`).
Map<String, JsonMap> mapOfMaps(JsonMap json, String key) =>
    (optMap(json, key) ?? const {}).map(
      (k, v) => MapEntry(k, asJsonMap(v, '$key.$k')),
    );
