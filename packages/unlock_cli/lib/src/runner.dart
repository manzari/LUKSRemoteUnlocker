import 'package:args/args.dart';
import 'package:unlock_core/unlock_core.dart';

const String executableName = 'luks-unlock';
const String cliVersion = '0.1.0';

const int exitUsage = 64;

ArgParser buildParser() => ArgParser()
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.')
  ..addFlag('version', negatable: false, help: 'Print the version.');

String usage(ArgParser parser) =>
    'Usage: $executableName [options]\n\n'
    'Unlocks LUKS-encrypted servers waiting at the Dropbear pre-boot prompt.\n\n'
    '${parser.usage}';

int runCli(
  List<String> arguments, {
  required StringSink out,
  required StringSink err,
}) {
  final parser = buildParser();
  final ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (e) {
    err
      ..writeln(e.message)
      ..writeln()
      ..writeln(usage(parser));
    return exitUsage;
  }
  if (results.flag('version')) {
    out.writeln('$executableName $cliVersion (unlock_core $unlockCoreVersion)');
    return 0;
  }
  out.writeln(usage(parser));
  return 0;
}
