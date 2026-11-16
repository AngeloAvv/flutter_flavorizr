import 'pbxproj_normalizer.dart';

final _timestamp = RegExp(
  r'\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?',
);

/// Removes the non-deterministic parts of a generated file so that two runs of
/// the same flavorizr version produce byte-identical output.
class Normalizer {
  const Normalizer();

  /// Normalizes [content], the text of the file at [relativePath].
  String normalize(String relativePath, String content) {
    final stripped = content.replaceAll(_timestamp, '<TIMESTAMP>');

    if (relativePath.endsWith('.pbxproj')) {
      return normalizePbxproj(stripped);
    }
    if (relativePath == 'pubspec.yaml') {
      return stripped.replaceAll(_flavorizrDependency, '');
    }

    return stripped;
  }
}

/// The `flutter_flavorizr` dev dependency, with its `path:` lines if any:
/// it records where the tested flavorizr comes from, not what it produced.
final _flavorizrDependency = RegExp(
  r'^  flutter_flavorizr:.*\n(?:    .*\n)*',
  multiLine: true,
);
