import 'dart:io';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/check_coverage.dart <lcov.info> <floor>',
    );
    exitCode = 64;
    return;
  }

  final source = File(args[0]);
  final floor = double.tryParse(args[1]);
  if (!source.existsSync() || floor == null) {
    stderr.writeln('Coverage file or numeric floor is invalid.');
    exitCode = 64;
    return;
  }

  var found = 0;
  var hit = 0;
  for (final line in source.readAsLinesSync()) {
    if (line.startsWith('LF:')) {
      found += int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      hit += int.parse(line.substring(3));
    }
  }

  if (found == 0) {
    stderr.writeln('No line coverage records found in ${source.path}.');
    exitCode = 1;
    return;
  }

  final percent = hit * 100 / found;
  stdout.writeln(
    'Line coverage: $hit/$found = ${percent.toStringAsFixed(2)}% '
    '(floor ${floor.toStringAsFixed(2)}%)',
  );
  if (percent < floor) exitCode = 1;
}
