// Sorlefedettség-küszöb ellenőrzése egy könyvtárra, a `flutter test --coverage`
// által írt coverage/lcov.info alapján.
//
//   dart run tool/check_coverage.dart lib/domain 95
import 'dart:io';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('Használat: dart run tool/check_coverage.dart <dir> <min%>');
    exit(2);
  }
  final prefix = args[0].replaceAll(r'\', '/');
  final minPercent = double.parse(args[1]);

  final lcov = File('coverage/lcov.info');
  if (!lcov.existsSync()) {
    stderr.writeln('Nincs coverage/lcov.info — előbb: flutter test --coverage');
    exit(2);
  }

  var file = '';
  var found = 0, hit = 0;
  final perFile = <String, (int, int)>{};
  for (final line in lcov.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      file = line.substring(3).replaceAll(r'\', '/');
    } else if (line.startsWith('DA:') && file.contains(prefix)) {
      final count = int.parse(line.substring(3).split(',')[1]);
      found++;
      if (count > 0) hit++;
      final (f, h) = perFile[file] ?? (0, 0);
      perFile[file] = (f + 1, h + (count > 0 ? 1 : 0));
    }
  }

  if (found == 0) {
    stderr.writeln('Nincs lefedettségi adat ehhez: $prefix');
    exit(1);
  }
  for (final MapEntry(key: f, value: (all, covered)) in perFile.entries) {
    stdout.writeln('  ${(100 * covered / all).toStringAsFixed(1)}%  $f');
  }
  final percent = 100 * hit / found;
  stdout.writeln('$prefix: ${percent.toStringAsFixed(1)}% ($hit/$found sor)');
  if (percent < minPercent) {
    stderr.writeln('A lefedettség a küszöb ($minPercent%) alatt van.');
    exit(1);
  }
}
