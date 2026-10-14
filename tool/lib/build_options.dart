import 'package:args/args.dart';

/// Build steps are opt-out; release bundles are never installed on a device.
class BuildOptions {
  BuildOptions(List<String> arguments) : results = parser.parse(arguments);

  final ArgResults results;

  static ArgParser get parser => ArgParser()
    ..addFlag(
      'assets',
      abbr: 'a',
      defaultsTo: true,
      help: 'Refresh SQL assets and the test database.',
    )
    ..addFlag(
      'build',
      abbr: 'b',
      defaultsTo: true,
      help: 'Build and validate a release APK (or AAB with --release).',
    )
    ..addFlag(
      'install',
      abbr: 'i',
      defaultsTo: true,
      help: 'Install the validated APK on the selected Android device.',
    )
    ..addOption(
      'device',
      abbr: 'd',
      help: 'Android device serial to install onto.',
    )
    ..addFlag(
      'release',
      abbr: 'r',
      help: 'Build and validate an AAB for release/; disables installation.',
    )
    ..addOption(
      'previous-artifact',
      help: 'Override the automatically preserved upgrade baseline APK/AAB.',
    )
    ..addFlag(
      'clean',
      defaultsTo: true,
      help: 'Clean project outputs before compiling; always validate.',
    )
    ..addFlag('help', abbr: 'h', help: 'Show usage.');

  bool get assets => results['assets'] as bool;
  bool get build => results['build'] as bool;
  bool get install => !release && (results['install'] as bool);
  bool get release => results['release'] as bool;
  bool get clean => results['clean'] as bool;
  bool get help => results['help'] as bool;
  String? get device => results['device'] as String?;
  String? get previousArtifact => results['previous-artifact'] as String?;

  void validate() {
    if (release && !build) {
      throw const FormatException(
        '--release requires a build; remove --no-build.',
      );
    }
    if (results.rest.isNotEmpty) {
      throw FormatException('Unexpected arguments: ${results.rest.join(' ')}');
    }
  }
}
