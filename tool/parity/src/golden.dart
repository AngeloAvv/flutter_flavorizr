/*
 * Copyright (c) 2026 Angelo Cassano
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

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
    if (!exists) {
      throw StateError(
        'No golden in ${directory.path}: record one first with '
        '`dart run tool/parity.dart record`.',
      );
    }
    final recorded = metadata;

    // Fail before the slow part: a mismatch makes the comparison meaningless.
    final flutter = await runner.flutterVersion();
    if (flutter != recorded.flutterVersion) {
      throw StateError(
        'The golden was recorded with Flutter ${recorded.flutterVersion}, '
        'but this is Flutter $flutter. Use the recorded version (see .fvmrc) '
        'or record the golden again.',
      );
    }
    if (runner.fixtureSha256 != recorded.fixtureSha256) {
      throw StateError(
        'The golden was recorded with another fixture (flavorizr.yaml or its '
        'files). Record the golden again.',
      );
    }

    final actual = Directory.systemTemp.createTempSync('flavorizr_actual_');
    try {
      await runner.run(source, actual);
      return compareTrees(tree, actual, whitelist: whitelist);
    } finally {
      actual.deleteSync(recursive: true);
    }
  }
}
