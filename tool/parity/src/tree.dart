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

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'normalizer.dart';

/// Files and folders that depend on the machine or on the day the project was
/// generated rather than on flavorizr, relative to the project root.
const defaultIgnore = [
  '.dart_tool/**',
  'build/**',
  '.git/**',
  '**/.gitignore',
  '.flutter-plugins*',
  '.packages',
  'pubspec.lock',
  '.tmp/**',
  'assets.tmp.zip',
  '**/ephemeral/**',
  'ios/Flutter/Generated.xcconfig',
  'ios/Flutter/flutter_export_environment.sh',
  'android/local.properties',
  // Lists the SDK of the machine that generated the project.
  '.idea/libraries/Dart_SDK.xml',
  'android/.gradle/**',
  'android/.kotlin/**',
];

/// Copies [source] into [destination] with every file normalized.
///
/// * text files go through [Normalizer];
/// * binary files are replaced by a `<name>.sha256` marker, so the golden
///   stays reviewable and small;
/// * files matching [ignore] are skipped.
void normalizeTree(
  Directory source,
  Directory destination, {
  Normalizer normalizer = const Normalizer(),
  List<String> ignore = defaultIgnore,
}) {
  final ignored = ignore.map(globToRegExp).toList();

  final files = source.listSync(recursive: true, followLinks: false)
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final entity in files.whereType<File>()) {
    final relative = p.posix.joinAll(
      p.split(p.relative(entity.path, from: source.path)),
    );
    if (ignored.any((pattern) => pattern.hasMatch(relative))) continue;

    final bytes = entity.readAsBytesSync();
    final target = p.join(destination.path, p.joinAll(relative.split('/')));

    String? text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      text = null;
    }

    final output = File(text == null ? '$target.sha256' : target)
      ..createSync(recursive: true);
    output.writeAsStringSync(
      text == null
          ? '${sha256.convert(bytes)}\n'
          : normalizer.normalize(relative, text),
    );
  }
}

/// Translates a glob (`*` within a segment, `**` across segments) to a
/// [RegExp] anchored on the whole relative path.
RegExp globToRegExp(String glob) {
  final buffer = StringBuffer('^');
  for (var i = 0; i < glob.length; i++) {
    final char = glob[i];
    if (char == '*') {
      if (i + 1 < glob.length && glob[i + 1] == '*') {
        i++;
        if (i + 1 < glob.length && glob[i + 1] == '/') {
          // `**/` is any number of whole folders, possibly none.
          buffer.write('(?:.*/)?');
          i++;
        } else {
          buffer.write('.*');
        }
      } else {
        buffer.write('[^/]*');
      }
    } else {
      buffer.write(RegExp.escape(char));
    }
  }
  buffer.write(r'$');
  return RegExp(buffer.toString());
}
