import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'tree.dart';

/// Where flavorizr comes from: a pub.dev version (`2.6.0`) or the path of a
/// checkout.
class FlavorizrSource {
  const FlavorizrSource(this.spec);

  final String spec;

  bool get isPath => Directory(spec).existsSync();

  String get label => isPath ? 'path:${p.canonicalize(spec)}' : spec;

  List<String> get pubAddArgs => isPath
      ? ['pub', 'add', 'dev:flutter_flavorizr', '--path', p.canonicalize(spec)]
      : ['pub', 'add', 'dev:flutter_flavorizr:$spec'];
}

/// What a recorded golden was generated with.
class GoldenMetadata {
  const GoldenMetadata({
    required this.flutterVersion,
    required this.flavorizr,
    required this.fixtureSha256,
  });

  factory GoldenMetadata.fromJson(Map<String, Object?> json) => GoldenMetadata(
    flutterVersion: json['flutterVersion'] as String,
    flavorizr: json['flavorizr'] as String,
    fixtureSha256: json['fixtureSha256'] as String,
  );

  final String flutterVersion;
  final String flavorizr;
  final String fixtureSha256;

  Map<String, Object?> toJson() => {
    'flutterVersion': flutterVersion,
    'flavorizr': flavorizr,
    'fixtureSha256': fixtureSha256,
  };
}

/// Creates a fresh Flutter project, flavorizes it with a given flavorizr and
/// writes the normalized result.
class ParityRunner {
  const ParityRunner({
    required this.fixture,
    this.flutter = 'flutter',
    this.flavorizrArgs = const ['-f'],
  });

  /// The `flavorizr.yaml` copied in the generated project.
  final File fixture;

  /// The Flutter executable.
  final String flutter;

  /// The arguments of `flutter pub run flutter_flavorizr`.
  final List<String> flavorizrArgs;

  static const platforms = 'android,ios,macos,linux,windows';

  /// Runs [source] on a fresh project and writes the normalized project into
  /// [output]. Returns what the output was generated with.
  Future<GoldenMetadata> run(FlavorizrSource source, Directory output) async {
    final workspace = Directory.systemTemp.createTempSync('flavorizr_parity_');
    try {
      final project = Directory(p.join(workspace.path, 'parity_app'))
        ..createSync();

      await _flutter(project, [
        'create',
        '--project-name=parity_app',
        '--org=com.example',
        '--platforms=$platforms',
        '.',
      ]);
      fixture.copySync(p.join(project.path, 'flavorizr.yaml'));
      await _flutter(project, source.pubAddArgs);
      await _copyAssets(project);
      await _flutter(project, [
        'pub',
        'run',
        'flutter_flavorizr',
        ...flavorizrArgs,
      ]);

      if (output.existsSync()) output.deleteSync(recursive: true);
      normalizeTree(project, output);

      return GoldenMetadata(
        flutterVersion: await flutterVersion(),
        flavorizr: source.label,
        fixtureSha256: sha256.convert(fixture.readAsBytesSync()).toString(),
      );
    } finally {
      workspace.deleteSync(recursive: true);
    }
  }

  /// The version of the Flutter SDK in use.
  Future<String> flutterVersion() async {
    final result = await Process.run(flutter, ['--version', '--machine']);
    if (result.exitCode != 0) {
      throw ProcessException(flutter, ['--version'], '${result.stderr}');
    }
    final json = jsonDecode(result.stdout as String) as Map<String, Object?>;
    return json['frameworkVersion'] as String;
  }

  /// flavorizr downloads its dummy assets by default; offline we hand them
  /// over from the package itself, the way the CI of this repository does.
  Future<void> _copyAssets(Directory project) async {
    final configFile = File(
      p.join(project.path, '.dart_tool', 'package_config.json'),
    );
    final config =
        jsonDecode(configFile.readAsStringSync()) as Map<String, Object?>;
    final package = (config['packages'] as List)
        .cast<Map<String, Object?>>()
        .firstWhere((package) => package['name'] == 'flutter_flavorizr');

    // `rootUri` is either absolute or relative to the package config.
    final root = Directory.fromUri(
      configFile.uri.resolve(package['rootUri'] as String),
    );

    _copy(
      Directory(p.join(root.path, 'assets')),
      Directory(p.join(project.path, '.tmp')),
    );
  }

  void _copy(Directory from, Directory to) {
    to.createSync(recursive: true);
    for (final entity in from.listSync(followLinks: false)) {
      final target = p.join(to.path, p.basename(entity.path));
      if (entity is Directory) {
        _copy(entity, Directory(target));
      } else if (entity is File) {
        entity.copySync(target);
      }
    }
  }

  Future<void> _flutter(Directory workingDirectory, List<String> args) async {
    final result = await Process.run(
      flutter,
      args,
      workingDirectory: workingDirectory.path,
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        flutter,
        args,
        '${result.stdout}\n${result.stderr}',
        result.exitCode,
      );
    }
  }
}
