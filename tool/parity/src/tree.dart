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
  '.flutter-plugins*',
  '.packages',
  'pubspec.lock',
  '.tmp/**',
  'assets.tmp.zip',
  '**/ephemeral/**',
  'ios/Flutter/Generated.xcconfig',
  'ios/Flutter/flutter_export_environment.sh',
  'android/local.properties',
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
        buffer.write('.*');
        i++;
        if (i + 1 < glob.length && glob[i + 1] == '/') i++;
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
