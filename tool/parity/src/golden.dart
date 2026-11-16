import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'differ.dart';
import 'runner.dart';

/// A recorded golden on disk:
///
/// ```text
/// <golden>/parity.json   what it was generated with
/// <golden>/tree/...      the normalized project
/// ```
class Golden {
  const Golden(this.directory);

  final Directory directory;

  File get _metadataFile => File(p.join(directory.path, 'parity.json'));

  Directory get tree => Directory(p.join(directory.path, 'tree'));

  bool get exists => _metadataFile.existsSync();

  GoldenMetadata get metadata => GoldenMetadata.fromJson(
    jsonDecode(_metadataFile.readAsStringSync()) as Map<String, Object?>,
  );

  /// Generates [source] and stores the result as this golden.
  Future<void> record(ParityRunner runner, FlavorizrSource source) async {
    final metadata = await runner.run(source, tree);
    _metadataFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(metadata.toJson())}\n',
    );
  }

  /// Generates [source] and compares it with this golden.
  ///
  /// Throws a [StateError] if the golden was recorded with another Flutter
  /// version or another fixture, since the comparison would be meaningless.
  Future<ParityReport> check(
    ParityRunner runner,
    FlavorizrSource source, {
    Whitelist whitelist = const Whitelist.empty(),
  }) async {
    final recorded = metadata;

    final flutter = await runner.flutterVersion();
    if (flutter != recorded.flutterVersion) {
      throw StateError(
        'The golden was recorded with Flutter ${recorded.flutterVersion}, '
        'but this is Flutter $flutter. Use the recorded version (see .fvmrc) '
        'or record the golden again.',
      );
    }

    final actual = Directory.systemTemp.createTempSync('flavorizr_actual_');
    try {
      final current = await runner.run(source, actual);
      if (current.fixtureSha256 != recorded.fixtureSha256) {
        throw StateError(
          'The golden was recorded with another flavorizr.yaml fixture. '
          'Record the golden again.',
        );
      }
      return compareTrees(tree, actual, whitelist: whitelist);
    } finally {
      actual.deleteSync(recursive: true);
    }
  }
}
