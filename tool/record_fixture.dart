// Élő Futár-válaszok rögzítése tesztfixture-nek.
//
//   dart run tool/record_fixture.dart arrivals <név> <stopId...>
//   dart run tool/record_fixture.dart search <név> <query>
//   dart run tool/record_fixture.dart nearby <név> <lat> <lon>
//
// A kulcsot az env.json-ból olvassa, és a mentett fájlból eltávolítja.
// A kérés URL-jét (benne a kulccsal) soha nem írja ki.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _base = 'https://futar.bkk.hu/api/query/v1/ws/otp/api/where';
const _usage = '''
Használat:
  dart run tool/record_fixture.dart arrivals <név> <stopId...>
  dart run tool/record_fixture.dart search <név> <query>
  dart run tool/record_fixture.dart nearby <név> <lat> <lon>''';

Future<void> main(List<String> args) async {
  if (args.length < 3) _fail(_usage);
  final [command, name, ...rest] = args;

  final key = _readKey();
  final Map<String, Object> params;
  final String endpoint;
  switch (command) {
    case 'arrivals':
      endpoint = 'arrivals-and-departures-for-stop';
      params = {
        'stopId': rest,
        'minutesBefore': '1',
        'minutesAfter': '60',
        'limit': '20',
      };
    case 'search':
      endpoint = 'search';
      params = {'query': rest.join(' ')};
    case 'nearby':
      if (rest.length != 2) _fail(_usage);
      endpoint = 'stops-for-location';
      params = {'lat': rest[0], 'lon': rest[1], 'radius': '300'};
    default:
      _fail(_usage);
  }

  final uri = Uri.parse('$_base/$endpoint').replace(
    queryParameters: {
      ...params,
      'includeReferences': 'true',
      'version': '4',
      'key': key,
    },
  );

  final http.Response response;
  try {
    response = await http.get(uri).timeout(const Duration(seconds: 10));
  } on Object catch (e) {
    _fail('Hálózati hiba: ${e.runtimeType}');
  }
  if (response.statusCode != 200) {
    _fail('HTTP ${response.statusCode}');
  }

  final body = utf8.decode(response.bodyBytes);
  final pretty = const JsonEncoder.withIndent(
    '  ',
  ).convert(jsonDecode(body)).replaceAll(key, 'REDACTED');
  if (pretty.contains(key)) _fail('A kulcs a kimenetben maradt, nem mentem.');

  final file = File('test/fixtures/${command}_$name.json');
  await file.parent.create(recursive: true);
  await file.writeAsString('$pretty\n');
  stdout.writeln('Mentve: ${file.path} (${pretty.length} karakter)');
}

String _readKey() {
  final file = File('env.json');
  if (!file.existsSync()) _fail('Nincs env.json a repó gyökerében.');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final key = json['FUTAR_API_KEY'];
  if (key is! String || key.isEmpty) _fail('Üres FUTAR_API_KEY.');
  return key;
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
